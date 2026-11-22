part of '../app_controller.dart';

/// 부탁을 끝낸 결과 (사연 대사 창 · 특별 보상 화면)
class NpcRequestDone {
  const NpcRequestDone(
      {required this.request, required this.got, this.special});

  final NpcRequest request;

  /// 받은 것 글 ('금화 100' 등)
  final List<String> got;

  /// 4번째 부탁의 특별 보상
  final NpcSpecial? special;
}

/// 부탁 할 일 하나의 진행
class NpcStepProgress {
  const NpcStepProgress(this.step, this.have);

  final NpcRequestStep step;
  final int have;

  bool get done => have >= step.need;
  int get shown => have.clamp(0, step.need);
}

/// 마을 사람 부탁 · 사연 · 친해지기 (묶음 42 #226).
/// 친해지기 점수·단계는 화면에 보이지 않는다 — 대사와 부탁으로만 느낀다.
extension NpcOps on AppController {
  NpcState get npcState => _npc;

  // ───────────── 친해지기

  int favorPoints(Npc n) => _npc.pointsOf(n.name);

  FavorStage favorStage(Npc n) => NpcRules.stageOf(favorPoints(n));

  /// 단짝인지 (단짝 혜택)
  bool _bestWith(Npc n) => favorStage(n) == FavorStage.best;

  /// 그 마을 사람의 시설이 열렸는지
  bool npcHomeOpen(Npc n) => switch (n) {
        Npc.marta || Npc.mina => true,
        Npc.dorgun => featureOpen(Feature.smithy),
        Npc.hart => featureOpen(Feature.board),
        Npc.eliel => featureOpen(Feature.alchemy),
        Npc.sera => jobsOpen,
        Npc.lumi => shelterOpen,
        Npc.garen => facilityOpen('training'),
        Npc.popo => facilityOpen('garden'),
        Npc.lian => tavernOpen,
        Npc.barkan => marketOpen,
      };

  /// 오늘 칸 (날이 바뀌면 들른 사람·쓴 횟수를 비움)
  NpcState get _npcToday {
    final day = DailyRecord.dayKeyOf(_clock());
    return _npc.day == day
        ? _npc
        : _npc.copyWith(day: day, visited: const [], uses: const {});
  }

  /// 시설에 들름 (하루 한 번)
  Future<void> _npcVisit(Npc n) async {
    if (!_npcReady || !npcHomeOpen(n)) return;
    final s = _npcToday;
    if (s.visited.contains(n.name)) {
      if (!identical(s, _npc)) await _saveNpc(s);
      return;
    }
    await _addFavor(n, NpcRules.visitPoints,
        base: s.copyWith(visited: [...s.visited, n.name]));
  }

  /// 시설을 씀 (하루 [NpcRules.usesPerDay] 번까지)
  Future<void> _npcUse(Npc n) async {
    if (!_npcReady || !npcHomeOpen(n)) return;
    final s = _npcToday;
    final used = s.uses[n.name] ?? 0;
    if (used >= NpcRules.usesPerDay) {
      if (!identical(s, _npc)) await _saveNpc(s);
      return;
    }
    await _addFavor(n, NpcRules.usePoints,
        base: s.copyWith(uses: {...s.uses, n.name: used + 1}));
    // 묶음 45 #231: 미나 — 오늘 잡화상에서 여러 번 거래했을 때
    if (n == Npc.mina && used + 1 == NpcRules.usesPerDay) await _smallTrigger(Npc.mina);
  }

  /// 점수를 더하고, 단계가 오르면 작은 선물 우편 한 통
  Future<void> _addFavor(Npc n, int pts, {NpcState? base}) async {
    var s = base ?? _npc;
    final before = NpcRules.stageOf(s.pointsOf(n.name));
    final after = NpcRules.stageOf(s.pointsOf(n.name) + pts);
    s = s.copyWith(points: {...s.points, n.name: s.pointsOf(n.name) + pts});
    final shown = s.shown[n.name] ?? 0;
    if (after.index > before.index && after.index > shown) {
      s = s.copyWith(shown: {...s.shown, n.name: after.index});
      await _saveNpc(s);
      final l = NpcRules.letters[n]?[after];
      if (l != null) {
        await _sendMail(MailItem(
          id: 'favor_${n.name}_${after.name}',
          kind: MailKind.letter,
          from: VillageRules.npc(n).name,
          title: l.title,
          body: l.body,
          gifts: l.gifts,
          sentAt: _clock(),
        ));
      }
      return;
    }
    await _saveNpc(s);
  }

  /// 단계가 오르면 그 사람 새 대사 2줄이 평소 대사에 섞인다
  List<String> npcStageLines(Npc n) => NpcRules.linesAt(n, favorStage(n));

  // ───────────── 부탁이 세는 일

  Future<void> _npcTally(String key, [int n = 1]) async {
    if (!_npcReady || n <= 0) return;
    await _saveNpc(_npc.copyWith(tally: {..._npc.tally, key: (_npc.tally[key] ?? 0) + n}));
    // 묶음 45 #231: 내 행동에 따라 마을 사람 작은 부탁
    final who = switch (key) {
      NpcTally.newPlace => Npc.mina,
      NpcTally.brew || NpcTally.newRecipe => Npc.eliel,
      NpcTally.guildErrand => Npc.hart,
      NpcTally.dungeon || NpcTally.clone => Npc.sera,
      NpcTally.hatch => Npc.lumi,
      _ => null,
    };
    if (who != null) await _smallTrigger(who);
    // 묶음 51 #229: 바르칸 — 나무·광석을 캘 때
    if (key == NpcTally.gatherOf('wood') || key == NpcTally.gatherOf('ore')) {
      await _smallTrigger(Npc.barkan);
    }
    // 묶음 45 #232: 전용 퀘스트 다음 단계
    await _advanceRelics();
  }

  /// 여관 휴식: 받은 부탁의 연속 휴식 날 + 오늘 3,000보 걷고 쉬기
  Future<void> _npcRested() async {
    if (!_npcReady) return;
    final day = DailyRecord.dayKeyOf(_clock());
    final a = _npc.active[Npc.marta.name];
    if (a != null && !a.innDays.contains(day)) {
      await _saveNpc(_npc.copyWith(active: {
        ..._npc.active,
        Npc.marta.name: a.copyWith(innDays: [...a.innDays, day]),
      }));
    }
    if ((player.today?.steps ?? 0) >= 3000) await _npcTally(NpcTally.rest3k);
  }

  // ───────────── 부탁

  /// 부탁을 보여 주지 않는 때 (튜토리얼·기능 안내 중)
  bool get _requestsQuiet => inTutorial || guideTourActive;

  /// 지금 받을 수 있는 부탁 (없으면 null)
  NpcRequest? requestOffer(Npc n) {
    if (!_npcReady || _requestsQuiet || !npcHomeOpen(n)) return null;
    if (_npc.active.containsKey(n.name)) return null;
    final r = NpcRules.at(n, _npc.doneOf(n.name));
    if (r == null) return null;
    if (favorStage(n).index < r.stage.index) return null;
    if (player.level.level < r.level) return null;
    return r;
  }

  /// 받은 부탁 (없으면 null)
  NpcRequest? requestActive(Npc n) {
    final a = _npc.active[n.name];
    return a == null ? null : NpcRules.at(n, a.index);
  }

  /// 받은 부탁의 할 일마다 진행
  List<NpcStepProgress> requestProgress(Npc n) {
    final a = _npc.active[n.name];
    final r = requestActive(n);
    if (a == null || r == null) return const [];
    return [for (final s in r.steps) NpcStepProgress(s, _stepHave(s, a))];
  }

  /// 받은 부탁을 다 했는지 (「다 했어요」)
  bool requestReady(Npc n) {
    final p = requestProgress(n);
    return p.isNotEmpty && p.every((x) => x.done);
  }

  /// 마을 건물 이름표 「!」: 받을 부탁이 있거나 다 한 부탁이 있으면
  bool npcAttention(Npc n) =>
      !_requestsQuiet && (requestOffer(n) != null || requestReady(n));

  /// 상태 탭 의뢰 칸: 받은 부탁들
  List<(Npc, NpcRequest, List<NpcStepProgress>)> get activeRequests => [
        for (final n in Npc.values)
          if (requestActive(n) case final r?) (n, r, requestProgress(n)),
      ];

  int _stepHave(NpcRequestStep s, ActiveRequest a) {
    switch (s.kind) {
      case RequestStepKind.tally:
        return (_npc.tally[s.key] ?? 0) - (a.base[s.key] ?? 0);
      case RequestStepKind.deliver:
        final mats = NpcRules.matsOf(s);
        if (s.distinct) {
          return mats.where((m) => player.materialExact(m) > 0).length;
        }
        return mats.fold<int>(0, (t, m) => t + player.materialExact(m));
      case RequestStepKind.daySteps:
        return _daysSince(a.day).fold<int>(0, (t, r) => math.max(t, r.steps));
      case RequestStepKind.dawnSteps:
        return _daysSince(a.day).fold<int>(0, (t, r) => math.max(t, r.dawnSteps));
      case RequestStepKind.stepsSince:
        return _daysSince(a.day).fold<int>(0, (t, r) => t + r.steps) - a.steps;
      case RequestStepKind.innStreak:
        return _longestRun(a.innDays);
      case RequestStepKind.allClones:
        return _act2.beaten;
      case RequestStepKind.adultPet:
        return _pets.pets.any((p) => p.adult) ? 1 : 0;
      case RequestStepKind.clone:
        if (a.clonesDone) return s.need;
        return (_npc.tally[NpcTally.clone] ?? 0) - (a.base[NpcTally.clone] ?? 0);
      case RequestStepKind.dayStreak:
        return _longestRun([
          for (final r in _daysSince(a.day))
            if (r.steps >= s.min) r.dayKey,
        ]);
    }
  }

  List<DailyRecord> _daysSince(String day) => [
        for (final r in _history)
          if (r.dayKey.compareTo(day) >= 0) r,
      ];

  /// 날짜 목록에서 가장 긴 연속 날 수
  static int _longestRun(List<String> days) {
    final ds = {
      for (final d in days)
        if (DateTime.tryParse(d) case final t?) DateTime(t.year, t.month, t.day),
    }.toList()
      ..sort();
    var best = 0, run = 0;
    DateTime? prev;
    for (final d in ds) {
      run = prev != null && d.difference(prev).inHours.round() == 24 ? run + 1 : 1;
      best = math.max(best, run);
      prev = d;
    }
    return best;
  }

  /// 부탁을 받는다 (받은 뒤부터 센다)
  Future<bool> acceptRequest(Npc n) => _serial(() async {
        final r = requestOffer(n);
        if (r == null) return false;
        final today = player.today;
        final a = ActiveRequest(
          index: r.index,
          day: DailyRecord.dayKeyOf(_clock()),
          base: {
            for (final s in r.steps)
              if (s.kind == RequestStepKind.tally) s.key: _npc.tally[s.key] ?? 0,
            if (r.steps.any((s) => s.kind == RequestStepKind.clone))
              NpcTally.clone: _npc.tally[NpcTally.clone] ?? 0,
          },
          steps: today?.steps ?? 0,
          clonesDone: _act2.beaten >= Act2Rules.avatars.length,
        );
        await _saveNpc(_npc.copyWith(active: {..._npc.active, n.name: a}));
        return true;
      });

  /// 「다 했어요」: 재료를 가져가고, 보상 · 점수 · 사연 한 조각 (4번째면 칭호 + 특별 보상)
  Future<NpcRequestDone?> completeRequest(Npc n) => _serial(() async {
        final r = requestActive(n);
        if (r == null || !requestReady(n)) return null;
        // 가져가는 재료 (몬스터 재료 3종은 종류마다 하나, 많이 가진 것부터)
        final take = <MaterialId, int>{};
        for (final s in r.steps) {
          if (s.kind != RequestStepKind.deliver) continue;
          final mats = [...NpcRules.matsOf(s)]
            ..sort((x, y) =>
                (Materials.isHerb(x) && Materials.isHerb(y)) ? Materials.herbGroup.indexOf(x).compareTo(Materials.herbGroup.indexOf(y)) : player.materialExact(y).compareTo(player.materialExact(x)));
          var left = s.need;
          for (final m in mats) {
            if (left <= 0) break;
            final have = player.materialExact(m) - (take[m] ?? 0);
            if (have <= 0) continue;
            final k = s.distinct ? 1 : math.min(have, left);
            take[m] = (take[m] ?? 0) + k;
            left -= k;
          }
        }
        if (take.isNotEmpty) {
          final today = await _todayRecord();
          await _save(today.copyWith(
              spends: DailyRecord.addCounts(
                  today.spends, {for (final e in take.entries) e.key.name: e.value})));
        }
        final got = await _applyGifts(r.gifts, title: '마을 사람 부탁 보상');
        final sp = r.special;
        if (sp != null) {
          got.addAll(await _grantSpecial(sp));
          final today = await _todayRecord();
          await _save(today.copyWith(
              counters: DailyRecord.addCounts(
                  today.counters, {TitleRules.npcCounter(sp.title): 1})));
        }
        await _saveNpc(_npc.copyWith(
          active: {..._npc.active}..remove(n.name),
          done: {..._npc.done, n.name: _npc.doneOf(n.name) + 1},
        ));
        await _addFavor(n, NpcRules.requestPoints);
        // 묶음 48 #230: 포포 2·3번 부탁은 약초밭 칸이 늘어남 (4번은 특별 보상에 적힘)
        if (n == Npc.popo && (r.index == 1 || r.index == 2)) {
          got.add('약초밭 $gardenPlotCount칸째');
        }
        return NpcRequestDone(request: r, got: got, special: sp);
      });

  Future<List<String>> _grantSpecial(NpcSpecial sp) async {
    switch (sp.kind) {
      case NpcSpecialKind.scarf:
        await _grantNpcGear(EquipBase.martaScarf);
      case NpcSpecialKind.badge:
        await _grantNpcGear(EquipBase.seraBadge);
      case NpcSpecialKind.band:
        await _grantNpcGear(EquipBase.garenBand);
      case NpcSpecialKind.pouch:
        await _saveNpc(_npc.copyWith(perks: {..._npc.perks, 'minaPouch'}.toList()));
      case NpcSpecialKind.nest:
        await _saveNpc(_npc.copyWith(perks: {..._npc.perks, 'lumiNest'}.toList()));
      case NpcSpecialKind.whetstone:
        await _saveNpc(_npc.copyWith(whetstones: _npc.whetstones + 1));
      case NpcSpecialKind.dawnLight:
        final a = _alc;
        await _saveAlc(a
            .copyWith(discovered: {...a.discovered, PotionId.dawnLight.name}.toList())
            .add(AlchemyRules.keyOf(PotionId.dawnLight, PotionQuality.normal), 1));
      case NpcSpecialKind.keys:
        return _applyGifts(const {'item:spareKey': 3}, title: '마을 사람 특별 보상');
      case NpcSpecialKind.knot:
        await _grantNpcGear(EquipBase.lianKnot);
      case NpcSpecialKind.seal:
        await _saveNpc(_npc.copyWith(perks: {..._npc.perks, 'barkanSeal'}.toList()));
      case NpcSpecialKind.garden:
        // 묶음 48 #230: 밭 6칸째(부탁 수로 정해짐) + 빛나는 씨앗 2
        final got = await _applyGifts({MaterialId.glowSeed.name: 2},
            title: '마을 사람 특별 보상');
        return ['약초밭 ${GardenRules.maxPlots}칸째', ...got];
    }
    return [sp.name];
  }

  /// 묶음 47 #240: 가방이 가득하면 우편함에 맡긴다
  Future<void> _grantNpcGear(EquipBase base) async {
    final a = _armory;
    await _saveArmory(a.copyWith(nextId: a.nextId + 1));
    await _giveEquipOrMail(
        EquipItem(uid: 'eq${a.nextId}', base: base, grade: EquipGrade.white),
        title: '마을 사람 특별 보상');
  }

  // ───────────── 특별 보상 (계속 듣는 것)

  /// 미나의 짐 주머니: 가방 칸
  int get npcBagSlots =>
      _npc.perks.contains('minaPouch') ? NpcRules.pouchSlots : 0;

  /// 루미의 둥지 장식이 있는지 (알이 조금 더 빨리)
  bool get hasLumiNest => _npc.perks.contains('lumiNest');

  /// 도르군의 숫돌 수
  int get whetstones => _npc.whetstones;

  Future<void> _useWhetstone() async {
    if (_npc.whetstones <= 0) return;
    await _saveNpc(_npc.copyWith(whetstones: _npc.whetstones - 1));
  }

  // ───────────── 단짝 혜택 (숨은 값)


  /// 미나: 산 값 일부를 돌려받음
  int minaRefund(int price) {
    if (!_bestWith(Npc.mina) || price <= 0) return 0;
    final x = price * NpcRules.minaRefund;
    final whole = x.floor();
    return whole + (_random.nextDouble() < x - whole ? 1 : 0);
  }

  /// 도르군: 수리비
  int dorgunRepair(int cost) => _bestWith(Npc.dorgun) && cost > 1
      ? math.max(1, (cost * NpcRules.dorgunRepair).round())
      : cost;

  /// 엘리엘: 가끔 재료 하나 덜
  bool get _elielSaves =>
      _bestWith(Npc.eliel) && _random.nextDouble() < NpcRules.elielSave;

  /// 하르트: 의뢰 금화
  int hartGold(int gold) =>
      _bestWith(Npc.hart) && gold > 0 ? (gold * NpcRules.hartGold).round() : gold;

  /// 세라: 숙련도 조금 빨리
  double get seraMastery => _bestWith(Npc.sera) ? NpcRules.seraMastery : 1;

  /// 루미: 펫 친밀도 더
  double get lumiBond => _bestWith(Npc.lumi) ? NpcRules.lumiBond : 1;

  /// 가렌: 하루 훈련 금화 더 (묶음 43)
  double get garenGold => _bestWith(Npc.garen) ? TrainingRules.garenGold : 1;

  // ───────────── 기록 탭 「마을 사람 이야기」

  /// 만난 사람마다 사연 4조각 (아직 못 본 조각은 null)
  List<(Npc, List<String?>)> get npcStories => [
        for (final n in Npc.values)
          if (_village.contains('met:${n.name}'))
            (
              n,
              [
                for (final (i, r) in NpcRules.of(n).indexed)
                  i < _npc.doneOf(n.name) ? r.story : null,
              ],
            ),
      ];

  // ───────────── 저장 · 예전 기록

  Future<void> _saveNpc(NpcState s) async {
    _npc = s;
    await store.saveJson(AppController._npcKey, s.toJson());
    _notify();
  }

  /// 처음이면 지금까지 기록으로 시작 점수를 어림잡는다 (선물 우편은 몰아 보내지 않음)
  Future<void> _loadNpc() async {
    final j = await store.loadJson(AppController._npcKey);
    if (j != null) {
      _npc = NpcState.fromJson(j);
      _npcReady = true;
      return;
    }
    final rests = _history.fold<int>(
        0, (t, r) => t + r.restsCompleted + (r.restedAtInn ? 1 : 0));
    final errands = _history.fold<int>(
        0,
        (t, r) =>
            t + (r.counters['errandDone'] ?? 0) + (r.counters['urgentDone'] ?? 0));
    final shops = _history.fold<int>(
        0, (t, r) => t + r.goldPurchases.length + (r.counters[QuestRules.shopTradeKey] ?? 0));
    final seed = <Npc, num>{
      Npc.marta: rests * 2,
      Npc.mina: shops,
      Npc.dorgun: _armory.crafts * 2 + _mastery.bigOf(Mastery.smith.name) / 2,
      Npc.eliel: _mastery.bigOf(Mastery.alchemy.name),
      Npc.hart: errands * 2,
      Npc.sera: jobsOpen ? 5 : 0,
      Npc.lumi: shelterOpen ? _pets.pets.length * 3 : 0,
      Npc.garen: 0,
      Npc.popo: 0,
      Npc.lian: 0,
      Npc.barkan: 0,
    };
    final pts = <String, int>{
      for (final e in seed.entries)
        if (npcHomeOpen(e.key) && e.value > 0)
          e.key.name: math.min(NpcRules.seedMax, e.value.round()),
    };
    _npc = NpcState(points: pts, shown: {
      for (final e in pts.entries) e.key: NpcRules.stageOf(e.value).index,
    });
    _npcReady = true;
    await store.saveJson(AppController._npcKey, _npc.toJson());
  }
}
