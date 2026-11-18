part of '../app_controller.dart';

/// 의뢰 게시판 (묶음 21: [AppController] 에서 나눔. 상태 칸은 본체에 있다)
extension BoardOps on AppController {

  /// 지금 시각의 게시판 (날짜가 바뀌었거나 기다리던 의뢰가 올라왔으면 반영)
  BoardState get board =>
      BoardRules.refresh(_board, _clock(),
          npcs: _openNpcNames, regions: _boardRegions, extra: boardExtraSlots);

  /// 묶음 58: 지역 의뢰가 붙는 곳 — 3막이 열리면 발드린, 그 밖은 등불을 켠 지역
  List<String> get _boardRegions => [
        if (act3Open) 'baldrin',
        if (act3Open)
          for (final r in RegionRules.all)
            if (regionLit(r.region)) r.prefix,
      ];

  Future<void> _saveBoard(BoardState b) async {
    _board = b;
    await store.saveJson(AppController._boardKey, b.toJson());
    _notify();
  }

  /// 수시 의뢰 진행 (수락한 뒤로 센 수)
  int errandProgress(int slot) {
    final s = board.slots[slot];
    final t = BoardRules.template(s.templateId, level: player.level.level);
    final today = player.today;
    if (t == null || !s.accepted || today == null) return 0;
    return BoardRules.progress(t, today, s.baseline);
  }

  Future<void> acceptErrand(int slot) =>
      _serial(() async {
    final b = board;
    final s = b.slots[slot];
    final t = BoardRules.template(s.templateId, level: player.level.level);
    if (t == null || s.accepted) return;
    final today = await _todayRecord();
    final slots = [...b.slots];
    slots[slot] = ErrandSlot(
      templateId: t.id,
      accepted: true,
      baseline: BoardRules.counterValue(today, t.counter),
    );
    await _saveBoard(b.copyWith(slots: slots));
    await _npcUse(Npc.hart);
  });

  /// 받을 수 있는 의뢰 보상 수 (묶음 16 #130 마을 탭 빨간 점)
  int get questRewardsReady {
    var n = 0;
    final b = board;
    for (var i = 0; i < b.slots.length; i++) {
      final s = b.slots[i];
      final t = BoardRules.template(s.templateId, level: player.level.level);
      if (t != null && s.accepted && errandProgress(i) >= t.target) n++;
    }
    final u = urgent;
    if (u != null &&
        b.urgentAccepted &&
        !b.urgentDone &&
        urgentProgress >= u.quest.target) {
      n++;
    }
    return n;
  }

  /// 다 한 수시 의뢰의 보상을 받는다. 2시간 뒤 새 의뢰가 올라온다.
  Future<bool> claimErrand(int slot) =>
      _serial(() async {
    final b = board;
    final s = b.slots[slot];
    final t = BoardRules.template(s.templateId, level: player.level.level);
    if (t == null || !s.accepted || errandProgress(slot) < t.target) {
      return false;
    }
    final slots = [...b.slots];
    slots[slot] =
        ErrandSlot(readyAt: _clock().add(_errandCooldown));
    // 묶음 45 #231: 마을 사람 쪽지 → 그 사람 친밀도 + 경험치 조금 (금화 없음)
    if (t.npc != null) {
      await _count('errandDone');
      await _saveBoard(b.copyWith(slots: slots, doneToday: b.doneToday + 1));
      await _boardNoteDone(t);
      return true;
    }
    await _grant(await _knackGold(errandGold(t.gold)), t.manaStones, t.materials,
        over: BagOver.mail, title: '의뢰 보상: ${t.title}');
    // 묶음 53: 3막 지역 의뢰 → 모집권
    if (t.tickets > 0) {
      _act3 = _act3.copyWith(tickets: _act3.tickets + t.tickets);
      await _saveAct3();
    }
    await _count('errandDone');
    await gainMastery(Mastery.trade, MasteryRules.errandDone);
    await _maybeNote(AlchemyRules.noteFromErrand);
    await _saveBoard(b.copyWith(slots: slots, doneToday: b.doneToday + 1));
    await _npcUse(Npc.hart);
    await _npcTally(NpcTally.guildErrand);
    return true;
  });

  /// 의뢰 협상(묶음 30): 아직 받지 않았거나 받은 길드 의뢰 하나를 다른 의뢰로
  Future<bool> _swapGuildErrand(int slot) async {
    final b = board;
    if (slot < 0 || slot >= b.slots.length) return false;
    final cur = b.slots[slot].templateId;
    if (cur == null) return false;
    final taken = {for (final s in b.slots) s.templateId};
    final choices = [
      for (final t in BoardRules.errands)
        if (!taken.contains(t.id)) t,
    ];
    if (choices.isEmpty) return false;
    final pick = choices[_random.nextInt(choices.length)];
    final slots = [...b.slots];
    slots[slot] = ErrandSlot(templateId: pick.id);
    await _saveBoard(b.copyWith(slots: slots));
    return true;
  }

  /// 수시 의뢰를 포기한다 (보상 없이, 2시간 뒤 새 의뢰)
  Future<void> abandonErrand(int slot) async {
    final b = board;
    final slots = [...b.slots];
    slots[slot] =
        ErrandSlot(readyAt: _clock().add(_errandCooldown));
    await _saveBoard(b.copyWith(slots: slots));
  }

  int get urgentProgress {
    final u = urgent;
    final today = player.today;
    if (u == null || !board.urgentAccepted || today == null) return 0;
    return BoardRules.progress(u.quest, today, board.urgentBaseline);
  }

  Future<void> acceptUrgent() =>
      _serial(() async {
    final u = urgent;
    if (u == null || board.urgentAccepted) return;
    final today = await _todayRecord();
    await _saveBoard(board.copyWith(
      urgentAccepted: true,
      urgentBaseline: BoardRules.counterValue(today, u.quest.counter),
    ));
    await _npcUse(Npc.hart);
  });

  Future<bool> claimUrgent() =>
      _serial(() async {
    final u = urgent;
    final b = board;
    if (u == null || !b.urgentAccepted || b.urgentDone) return false;
    if (urgentProgress < u.quest.target) return false;
    if (u.prize == UrgentPrize.key) {
      final today = await _todayRecord();
      await _save(today.copyWith(
          counters: DailyRecord.addCounts(today.counters, {'bonusKeys': 1})));
      await _grant(await _knackGold(errandGold(u.quest.gold)), 0, const {});
    } else {
      await _grant(await _knackGold(errandGold(u.quest.gold)), 0, {u.rare: 1},
          over: BagOver.mail, title: '긴급 의뢰 보상');
    }
    await _count('urgentDone');
    await gainMastery(Mastery.trade, MasteryRules.errandDone);
    await _maybeNote(AlchemyRules.noteFromErrand);
    await _saveBoard(b.copyWith(urgentDone: true));
    await _npcUse(Npc.hart);
    await _npcTally(NpcTally.urgent);
    return true;
  });

  /// 오늘 기록의 수 하나를 늘린다 (생활 보너스·의뢰용)
  Future<void> _count(String key, [int n = 1]) async {
    final today = await _todayRecord();
    await _save(today.copyWith(
        counters: DailyRecord.addCounts(today.counters, {key: n})));
  }

  /// 금화·마석은 늘 받고, 재료는 가방에 들어가는 만큼.
  /// 묶음 47 #240: 남는 재료는 [over] 대로 (의뢰 보상은 우편함)
  Future<void> _grant(int gold, int manaStones, Map<MaterialId, int> materials,
      {BagOver over = BagOver.hold, String? title}) async {
    final kept = await _fitBag(materials, over: over, title: title);
    final today = await _todayRecord();
    await _save(today.copyWith(
      gains: DailyRecord.addCounts(
          today.gains,
          HuntReward.ledger(
              extraManaStones: manaStones, gold: gold, materials: kept)),
    ));
  }
}
