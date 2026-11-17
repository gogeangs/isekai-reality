part of '../app_controller.dart';

/// 약초밭에서 거둔 결과
class GardenHarvest {
  const GardenHarvest(this.material, this.count);

  final MaterialId material;
  final int count;
}

/// 약초밭 한 칸 (화면용)
class GardenPlotView {
  const GardenPlotView({required this.slot, this.seed, this.walked = 0, this.need = 0});

  final int slot;

  /// 심은 씨앗 (빈 칸이면 null)
  final MaterialId? seed;

  /// 심은 뒤 걸은 걸음 · 다 자라는 데 드는 걸음
  final int walked;
  final int need;

  bool get empty => seed == null;
  bool get ready => seed != null && walked >= need;

  /// 「약 ○보 더」 (100보 단위로 올림)
  int get left => ready ? 0 : (((need - walked) + 99) ~/ 100) * 100;

  /// 0 새싹 · 1 자람 · 2 다 자람
  int get stage => GardenRules.stageOf(walked, need);
}

/// 마을 새 건물 「약초밭」 (묶음 48 #230): 씨앗을 심으면 그 뒤에 걸은 걸음으로 자란다.
/// 한 걸음이 밭 모든 칸에 함께 닿고, 시간으로는 자라지 않는다. 다 자란 것은 거둘 때까지 그대로.
extension GardenOps on AppController {
  GardenState get garden => _garden;

  /// Lv.9에 열림
  bool get gardenOpen => player.level.level >= GardenRules.openLevel;

  /// 밭 칸 수 (포포 부탁을 끝낼수록 3 → 6)
  int get gardenPlotCount => GardenRules.plotsFor(_npc.doneOf(Npc.popo.name));

  /// 포포의 이슬병
  bool get _dew => hasRelic(Npc.popo);

  /// 심은 날부터 걸은 걸음 (심을 때 그날 걸음은 뺀다)
  int _walkedSince(GardenPlot p) => math.max(
      0, _daysSince(p.day).fold<int>(0, (t, r) => t + r.steps) - p.steps);

  GardenPlotView plotView(int slot) {
    final p = _garden.plots[slot];
    final seed = p == null ? null : Materials.byName(p.seed);
    if (p == null || seed == null) return GardenPlotView(slot: slot);
    return GardenPlotView(
      slot: slot,
      seed: seed,
      walked: _walkedSince(p),
      need: GardenRules.need(seed, dew: _dew),
    );
  }

  List<GardenPlotView> get gardenPlots =>
      [for (var i = 0; i < gardenPlotCount; i++) plotView(i)];

  /// 다 자란 칸 수 (마을 건물·이름표 빨간 점)
  int get gardenReady =>
      gardenOpen ? gardenPlots.where((p) => p.ready).length : 0;

  /// 가방에 있는 씨앗 (심을 수 있는 것)
  Map<MaterialId, int> get seedPouch => {
        for (final s in GardenRules.seeds)
          if (player.materialCount(s.seed) > 0) s.seed: player.materialCount(s.seed),
      };

  /// 씨앗을 심는다 (가방에서 하나 쓴다)
  Future<bool> plantSeed(int slot, MaterialId seed) => _serial(() async {
        if (!gardenOpen || !GardenRules.isSeed(seed)) return false;
        if (slot < 0 || slot >= gardenPlotCount || _garden.plots.containsKey(slot)) {
          return false;
        }
        if (player.materialCount(seed) <= 0) return false;
        final today = await _todayRecord();
        await _save(today.copyWith(
            spends: DailyRecord.addCounts(today.spends, {seed.name: 1})));
        await _saveGarden(_garden.copyWith(plots: {
          ..._garden.plots,
          slot: GardenPlot(
              seed: seed.name, day: today.dayKey, steps: player.today?.steps ?? today.steps),
        }));
        await _npcUse(Npc.popo);
        return true;
      });

  /// 다 자란 칸을 거둔다: 그 재료 2개(채집 숙련도·포포 단짝이면 가끔 하나 더) ·
  /// 채집 숙련도 · 대지 속성 점수
  Future<GardenHarvest?> harvestPlot(int slot) => _serial(() async {
        final v = plotView(slot);
        final seed = v.seed;
        if (!gardenOpen || seed == null || !v.ready) return null;
        final m = GardenRules.yieldOf(seed, _clock().month);
        var n = GardenRules.harvestCount;
        if (_masteryRoll(GardenRules.masteryExtra * _bigFrac(Mastery.harvest))) n++;
        if (_bestWith(Npc.popo) && _random.nextDouble() < GardenRules.popoExtra) n++;
        await _saveGarden(_garden.copyWith(
          plots: {..._garden.plots}..remove(slot),
          harvested: _garden.harvested + 1,
        ));
        await _grant(0, 0, {m: n});
        await gainMastery(Mastery.harvest, GardenRules.masteryOnce);
        await _gainElement(Element.earth, GardenRules.earthScore);
        await _npcTally(NpcTally.gardenHarvest);
        if (seed == MaterialId.glowSeed) await _npcTally(NpcTally.gardenGlow);
        await _npcUse(Npc.popo);
        // 묶음 45 #231: 포포 작은 부탁 — 밭을 거둘 때
        await _smallTrigger(Npc.popo);
        return GardenHarvest(m, n);
      });

  // ───────────── 씨앗 얻기

  /// 처음 보는 씨앗이면 기록하고 포포 작은 부탁
  Future<void> _seeSeeds(Iterable<MaterialId> got) async {
    final fresh = [
      for (final m in got)
        if (GardenRules.isSeed(m) && !_garden.seenSeeds.contains(m.name)) m.name,
    ];
    if (fresh.isEmpty) return;
    await _saveGarden(_garden.copyWith(seenSeeds: [..._garden.seenSeeds, ...fresh]));
    if (gardenOpen) await _smallTrigger(Npc.popo);
  }

  /// 채집할 때 가끔 그 자리의 씨앗 (약초밭이 열린 뒤)
  MaterialId? _rollGatherSeed(HarvestKind k) {
    if (!gardenOpen) return null;
    final s = GardenRules.gatherSeed(k);
    if (s == null) return null;
    return _random.nextDouble() < GardenRules.gatherChance ? s : null;
  }

  // ───────────── 「새로 열렸어요」 카드 · 처음 씨앗

  /// 「새로 열렸어요」 약초밭 카드 (한 번만, 예전 Lv.9 이상 계정도)
  bool get gardenIntroPending =>
      gardenOpen &&
      !_village.contains('gardenCard') &&
      !inTutorial &&
      pendingFeatureIntro == null &&
      !skillIntroPending &&
      !farewellPending &&
      !shelterIntroPending &&
      !trainingIntroPending;

  /// 카드를 넘기면 포포가 씨앗을 나눠 준다 (한 번만)
  Future<void> markGardenIntro() async {
    await _markVillage(['gardenCard']);
    await _gardenStarter();
  }

  Future<void> _gardenStarter() => _serial(() async {
        if (_garden.starter || !gardenOpen) return;
        await _saveGarden(_garden.copyWith(
            starter: true,
            openWeek: _garden.openWeek ??
                DailyRecord.dayKeyOf(TownRules.weekStart(_clock()))));
        await _admitBag(GardenRules.starterSeeds,
            over: BagOver.mail, title: '포포가 나눠 준 씨앗');
        await _seeSeeds([MaterialId.herbSeed]);
      });

  /// 주간 의뢰를 모두 끝낸 주마다 빛나는 씨앗 하나 (약초밭이 열린 주부터, 우편함 아닌 가방에 —
  /// 가방이 가득하면 우편함)
  Future<void> _checkGardenGlow() async {
    final from = _garden.openWeek;
    if (!gardenOpen || from == null || _history.isEmpty) return;
    final perWeek = BoardRules.weekly(const []).length;
    final done = <String, int>{};
    for (var i = 0; i < _history.length; i++) {
      final r = _history[i];
      final w = DailyRecord.dayKeyOf(TownRules.weekStart(r.date));
      if (w.compareTo(from) < 0) continue;
      final n = BoardRules.weeklyCompletedOn(_history, i);
      if (n > 0) done[w] = (done[w] ?? 0) + n;
    }
    final due = [
      for (final e in done.entries)
        if (e.value >= perWeek && !_garden.glowWeeks.contains(e.key)) e.key,
    ];
    if (due.isEmpty) return;
    await _saveGarden(_garden.copyWith(glowWeeks: [..._garden.glowWeeks, ...due]));
    await _admitBag({MaterialId.glowSeed.name: GardenRules.weeklyGlow * due.length},
        over: BagOver.mail, title: '주간 의뢰 보상 · 빛나는 씨앗');
    await _seeSeeds([MaterialId.glowSeed]);
  }

  /// 예전 기록 Lv.9 이상: 약초밭은 완공 그림 그대로 (연출 없음, 카드는 한 번)
  Future<void> _migrateBuilt48() async {
    if (_village.contains('v48')) return;
    await _markVillage(['v48', if (gardenOpen) 'built:garden']);
  }

  Future<void> _saveGarden(GardenState g) async {
    _garden = g;
    await store.saveJson(AppController._gardenKey, g.toJson());
    _notify();
  }
}
