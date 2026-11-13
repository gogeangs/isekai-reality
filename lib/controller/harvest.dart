part of '../app_controller.dart';

/// 채집·채집 도구 (묶음 21: [AppController] 에서 나눔. 상태 칸은 본체에 있다)
extension HarvestOps on AppController {

  HarvestState get harvest => _harvest;

  Future<void> _saveHarvest(HarvestState h) async {
    _harvest = h;
    await store.saveJson(AppController._harvestKey, h.toJson());
    _notify();
  }

  /// 지도에 보이는 채집 자리 (지금 위치 둘레 3km)
  List<HarvestSpot> get harvestSpots {
    if (inTutorial) return const []; // 묶음 18 #150
    final center = _lastFix?.point ?? fallbackCenter;
    if (center == null) return const [];
    final lure = lureActive;
    final night = HarvestRules.isNight(_clock());
    final key = '${(center.lat * 1000).round()}_${(center.lng * 1000).round()}'
        '${lure ? 'L' : ''}${night ? 'N' : ''}${lands == null ? '' : 'P'}'
        '${_legacyGates ? '' : 'v${player.level.level}${_harvestTutorial ? 'T' : ''}'}';
    if (key != _spotsKey) {
      _spotsKey = key;
      _spotsCache = HarvestRules.spotsAround(center,
          roads: roads,
          exclusions: exclusions,
          places: area.places,
          excluded: area.isExcluded,
          density: lure ? AlchemyRules.lureHarvest : 1,
          night: night,
          land: lands?.kindAt);
      // 묶음 16 #143: 새로 시작한 사람은 Lv.5에 채집이 열리고, 처음엔 꽃·버섯 자리만
      if (!_legacyGates) {
        final lv = player.level.level;
        _spotsCache = lv < 5
            ? const []
            : [
                if (_harvestTutorial && _lastFix != null)
                  HarvestSpot(
                      id: 'tutorial-harvest',
                      kind: HarvestKind.flower,
                      point: GeoPoint(_lastFix!.point.lat + 0.00008,
                          _lastFix!.point.lng + 0.00006)),
                for (final x in _spotsCache)
                  if (lv >= 7 ||
                      x.kind == HarvestKind.flower ||
                      x.kind == HarvestKind.mushroom)
                    x,
              ];
      }
    }
    return _spotsCache;
  }

  /// 마지막으로 받은 위치
  GeoPoint? get lastPoint => _lastFix?.point;

  /// 가까이 있는 채집 자리 (40m 안)
  HarvestSpot? get nearbyHarvest {
    final fix = _lastFix;
    if (fix == null) return null;
    HarvestSpot? best;
    double? bd;
    for (final s in harvestSpots) {
      final d = s.point.distanceTo(fix.point);
      if (d <= HarvestRules.reachM && (bd == null || d < bd)) {
        best = s;
        bd = d;
      }
    }
    return best;
  }

  int harvestCharges(HarvestSpot s) => _harvest.chargesOf(s.id, _clock());

  /// 다음 하나가 차기까지
  Duration? harvestRefill(HarvestSpot s) =>
      _harvest.spots[s.id]?.untilNext(_clock());

  /// 도구 내구도 (처음 채집 전에는 새 도구로 친다)
  /// 묶음 23: 도구를 가지고 있을 때만 센다 (없으면 0, 「도구 필요」 규칙)
  int toolDurability(HarvestTool t) =>
      _harvest.granted ? _harvest.durability(t) : 0;

  /// 도구 최대 내구도 (등급에 따라)
  int toolMaxOf(HarvestTool t) => HarvestRules.toolMaxFor(_harvest.tierOf(t));

  ToolTier toolTier(HarvestTool t) => _harvest.tierOf(t);
  Element? toolElement(HarvestTool t) => _harvest.elementOf(t);

  /// 미니게임이 쉬워지는 정도 (도구 등급, 숨김)
  int harvestEase(HarvestKind k) =>
      _harvest.tierOf(HarvestRules.info(k).tool).index;

  /// 채집가 직업 (#55 각성 뒤, 지금은 늘 false. 규칙만 준비)
  bool get gatherer => false;

  /// 도구를 다음 등급으로 (대장간: 곡괭이·도끼, 공방: 낫·낚싯대·붓)
  CraftCheck canUpgradeTool(HarvestTool t) {
    final cost = HarvestRules.upgradeCost(_harvest.tierOf(t));
    if (cost == null) return CraftCheck.maxed;
    final p = player;
    for (final e in cost.mats.entries) {
      if (p.materialCount(e.key) < e.value) return CraftCheck.materials;
    }
    if (p.gold < cost.gold) return CraftCheck.gold;
    return CraftCheck.ok;
  }

  Future<bool> upgradeTool(HarvestTool t) async {
    if (canUpgradeTool(t) != CraftCheck.ok) return false;
    final tier = _harvest.tierOf(t);
    final cost = HarvestRules.upgradeCost(tier)!;
    final today = await _todayRecord();
    await _save(today.copyWith(
        spends: DailyRecord.addCounts(today.spends, {
      for (final e in cost.mats.entries) e.key.name: e.value,
      Wallet.gold: cost.gold,
    })));
    final next = ToolTier.values[tier.index + 1];
    await _saveHarvest(_harvest.copyWith(
      tiers: {..._harvest.tiers, t.name: next.index},
      // 새 도구라 내구도를 다 채운다
      tools: {..._harvest.tools, t.name: HarvestRules.toolMaxFor(next)},
    ));
    return true;
  }

  /// 도구에 속성을 입힌다: 빛나는 속성 코어 1개 + 금화 100 (11-11 #83, #63과 같다).
  /// 그 속성의 귀한 재료가 더 잘 나온다 (숨김).
  Future<bool> imbueTool(HarvestTool t, Element e) async {
    final core = EquipmentRules.imbueCore(e);
    if (player.materialCount(core) < 1 || player.gold < EquipmentRules.imbueGold) {
      return false;
    }
    final today = await _todayRecord();
    await _save(today.copyWith(
        spends: DailyRecord.addCounts(today.spends,
            {core.name: 1, Wallet.gold: EquipmentRules.imbueGold})));
    await _saveHarvest(
        _harvest.copyWith(elements: {..._harvest.elements, t.name: e.name}));
    return true;
  }

  HarvestCheck canHarvest(HarvestSpot s, {bool minigame = false}) {
    final fix = _lastFix;
    if (fix == null || s.point.distanceTo(fix.point) > HarvestRules.reachM) {
      return HarvestCheck.far;
    }
    if (driveBlocked) return HarvestCheck.passenger;
    if (harvestCharges(s) <= 0) return HarvestCheck.empty;
    if (harvestNeedsTool) return HarvestCheck.noTool;
    if (!minigame) return HarvestCheck.ok;
    if (passengerMode) return HarvestCheck.passenger;
    if (!standingStill) return HarvestCheck.moving;
    if (toolDurability(s.info.tool) <= 0) return HarvestCheck.noTool;
    return HarvestCheck.ok;
  }

  /// 채집한다. [grade] 가 quick 이면 빠른 채집, 아니면 미니게임 결과.
  Future<Map<MaterialId, int>?> harvestAt(HarvestSpot s, HarvestGrade grade) async {
    final minigame = grade != HarvestGrade.quick;
    if (canHarvest(s, minigame: minigame) != HarvestCheck.ok) return null;
    if (s.id == 'tutorial-harvest') {
      // 채집 안내 끝: 다음부터는 보통 자리만
      _harvestTutorial = false;
      _spotsKey = null;
    }
    final now = _clock();
    var h = _harvest;
    if (!h.granted) {
      h = h.copyWith(granted: true, tools: {
        for (final t in HarvestTool.values) t.name: toolMaxOf(t),
      });
    }
    final charge = h.spots[s.id] ??
        SpotCharge(charges: HarvestRules.maxCharges, at: now);
    final tool = s.info.tool;
    // 한 종류에서 완벽을 많이 쌓았으면 빠른 채집도 「좋음」 (11-11 #83, 숨김)
    final effective =
        !minigame && h.mastered(s.kind) ? HarvestGrade.good : grade;
    final streak = !minigame
        ? h.streak
        : grade == HarvestGrade.perfect
            ? h.streak + 1
            : 0;
    final mats = HarvestRules.yieldOf(s.kind, effective, _random,
        factor: passengerMode ? 0.5 : 1,
        tier: h.tierOf(tool),
        streak: grade == HarvestGrade.perfect ? h.streak : 0,
        element: h.elementOf(tool),
        month: now.month);
    final relic = s.kind == HarvestKind.relic;
    h = h.copyWith(
      spots: {...h.spots, s.id: charge.use(now)},
      tools: minigame
          ? {...h.tools, tool.name: math.max(0, h.durability(tool) - 1)}
          : h.tools,
      total: h.total + 1,
      streak: streak,
      perfects: grade == HarvestGrade.perfect
          ? {...h.perfects, s.kind.name: (h.perfects[s.kind.name] ?? 0) + 1}
          : h.perfects,
      relics: relic ? h.relics + 1 : h.relics,
    ).pruned(now);
    // 묶음 13 C8: 유물 이야기는 보류. 이야기 칸만 비우고 유물·재료는 그대로
    _lastRelicLore = relic && HarvestRules.relicLore.isNotEmpty
        ? HarvestRules.relicLore[(h.relics - 1) % HarvestRules.relicLore.length]
        : null;
    await _saveHarvest(h);
    await _grant(0, 0, mats);
    if (relic) {
      final today = await _todayRecord();
      await _save(today.copyWith(
          counters: DailyRecord.addCounts(today.counters, {'relicDug': 1})));
    }
    return mats;
  }

  /// 방금 캔 고대 유물의 이야기 (없으면 null)
  String? get lastRelicLore => _lastRelicLore;

  /// 도구 수리: 금화 30 + 재료 1 (곡괭이·도끼는 대장간, 낫·낚싯대·붓은 공방)
  Future<bool> repairTool(HarvestTool t) async {
    if (!_harvest.granted || _harvest.durability(t) >= toolMaxOf(t)) {
      return false;
    }
    final m = HarvestRules.repairMaterial(t);
    if (player.gold < HarvestRules.repairGold || player.materialCount(m) <= 0) {
      return false;
    }
    final today = await _todayRecord();
    await _save(today.copyWith(
        spends: DailyRecord.addCounts(
            today.spends, {Wallet.gold: HarvestRules.repairGold, m.name: 1})));
    await _saveHarvest(_harvest.copyWith(
        tools: {..._harvest.tools, t.name: toolMaxOf(t)}));
    return true;
  }
}
