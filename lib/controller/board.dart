part of '../app_controller.dart';

/// 의뢰 게시판 (묶음 21: [AppController] 에서 나눔. 상태 칸은 본체에 있다)
extension BoardOps on AppController {

  /// 지금 시각의 게시판 (날짜가 바뀌었거나 기다리던 의뢰가 올라왔으면 반영)
  BoardState get board => BoardRules.refresh(_board, _clock());

  Future<void> _saveBoard(BoardState b) async {
    _board = b;
    await store.saveJson(AppController._boardKey, b.toJson());
    _notify();
  }

  /// 수시 의뢰 진행 (수락한 뒤로 센 수)
  int errandProgress(int slot) {
    final s = board.slots[slot];
    final t = BoardRules.template(s.templateId);
    final today = player.today;
    if (t == null || !s.accepted || today == null) return 0;
    return BoardRules.progress(t, today, s.baseline);
  }

  Future<void> acceptErrand(int slot) =>
      _serial(() async {
    final b = board;
    final s = b.slots[slot];
    final t = BoardRules.template(s.templateId);
    if (t == null || s.accepted) return;
    final today = await _todayRecord();
    final slots = [...b.slots];
    slots[slot] = ErrandSlot(
      templateId: t.id,
      accepted: true,
      baseline: BoardRules.counterValue(today, t.counter),
    );
    await _saveBoard(b.copyWith(slots: slots));
  });

  /// 받을 수 있는 의뢰 보상 수 (묶음 16 #130 마을 탭 빨간 점)
  int get questRewardsReady {
    var n = 0;
    final b = board;
    for (var i = 0; i < b.slots.length; i++) {
      final s = b.slots[i];
      final t = BoardRules.template(s.templateId);
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
    final t = BoardRules.template(s.templateId);
    if (t == null || !s.accepted || errandProgress(slot) < t.target) {
      return false;
    }
    await _grant(t.gold, t.manaStones, t.materials);
    await _count('errandDone');
    await _maybeNote(AlchemyRules.noteFromErrand);
    final slots = [...b.slots];
    slots[slot] =
        ErrandSlot(readyAt: _clock().add(BoardRules.errandCooldown));
    await _saveBoard(b.copyWith(slots: slots, doneToday: b.doneToday + 1));
    return true;
  });

  /// 수시 의뢰를 포기한다 (보상 없이, 2시간 뒤 새 의뢰)
  Future<void> abandonErrand(int slot) async {
    final b = board;
    final slots = [...b.slots];
    slots[slot] =
        ErrandSlot(readyAt: _clock().add(BoardRules.errandCooldown));
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
      await _grant(u.quest.gold, 0, const {});
    } else {
      await _grant(u.quest.gold, 0, {u.rare: 1});
    }
    await _count('urgentDone');
    await _maybeNote(AlchemyRules.noteFromErrand);
    await _saveBoard(b.copyWith(urgentDone: true));
    return true;
  });

  /// 오늘 기록의 수 하나를 늘린다 (생활 보너스·의뢰용)
  Future<void> _count(String key, [int n = 1]) async {
    final today = await _todayRecord();
    await _save(today.copyWith(
        counters: DailyRecord.addCounts(today.counters, {key: n})));
  }

  Future<void> _grant(
      int gold, int manaStones, Map<MaterialId, int> materials) async {
    final fit = _fitBag(materials);
    final today = await _todayRecord();
    await _save(today.copyWith(
      gains: DailyRecord.addCounts(
          today.gains,
          HuntReward.ledger(
              extraManaStones: manaStones,
              gold: gold + fit.gold,
              materials: fit.kept)),
    ));
  }
}
