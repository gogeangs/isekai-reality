part of '../app_controller.dart';

/// 스탯·속성 점수 (묶음 21: [AppController] 에서 나눔. 상태 칸은 본체에 있다)
extension StatsOps on AppController {

  /// 포인트로 올린 값
  Stats get allocatedStats => _alloc.allocated;

  /// 지금까지 받은 포인트 중 아직 나누지 않은 것
  int get unspentPoints =>
      math.max(0, StatRules.pointsFor(player.level.level) - _alloc.allocated.total);

  /// 화면에 보이는 스탯 (시작 값 + 생활 보너스 + 포인트). 합계만 보여 준다.
  Stats get shownStats => player.stats + _alloc.allocated;

  /// 전투에 쓰는 스탯: 아직 나누지 않은 포인트는 고르게 나눈 것처럼 친다
  Stats get combatStats =>
      shownStats + StatRules.evenShare(unspentPoints) + buffStats;

  /// 초기화 비용 (처음 1번 무료)
  int get statResetCost => StatRules.resetCost(_alloc.resets);
  int get statResets => _alloc.resets;

  /// 포인트를 나눈다. [add] 의 합이 남은 포인트보다 많으면 false.
  Future<bool> allocateStats(Stats add) async {
    if (add.total <= 0 || add.total > unspentPoints) return false;
    for (final k in StatKind.values) {
      if (add.of(k) < 0) return false;
    }
    _alloc = _alloc.copyWith(allocated: _alloc.allocated + add);
    await store.saveJson(AppController._statsKey, _alloc.toJson());
    await refreshVitals();
    _notify();
    return true;
  }

  /// 포인트로 올린 값만 되돌린다 (생활 보너스는 그대로). 금화가 모자라면 false.
  Future<bool> resetStats() async {
    if (_alloc.allocated.total == 0) return false;
    final cost = statResetCost;
    if (player.gold < cost) return false;
    if (cost > 0) {
      final today = await _todayRecord();
      await _save(today.copyWith(
          spends: DailyRecord.addCounts(today.spends, {Wallet.gold: cost})));
    }
    _alloc = _alloc.copyWith(allocated: Stats.zero, resets: _alloc.resets + 1);
    await store.saveJson(AppController._statsKey, _alloc.toJson());
    await refreshVitals();
    _notify();
    return true;
  }

  /// 생활 보너스가 올라서 정령이 할 한 줄 (이유는 말하지 않는다). 없으면 null.
  String? get lifeBonusLine {
    final seen = _alloc.seenLife;
    if (seen == null) return null;
    final now = StatRules.lifeBonus(_history);
    for (final k in StatKind.values) {
      if (now.of(k) > seen.of(k)) return AppController._lifeLines[k];
    }
    return null;
  }

  /// 상태 화면에 보여 줄 생활 보너스 한 줄. 한 번 보여 주면 알려 준 것으로 기록하고
  /// 이번에 앱을 켜 둔 동안만 남긴다.
  String? get statusLifeLine {
    final line = lifeBonusLine;
    if (line != null && line != _shownLifeLine) {
      _shownLifeLine = line;
      Future.microtask(acknowledgeLifeBonus);
    }
    return _shownLifeLine;
  }

  /// 정령 한 줄을 보여 줬을 때
  Future<void> acknowledgeLifeBonus() async {
    _alloc = _alloc.copyWith(seenLife: StatRules.lifeBonus(_history));
    await store.saveJson(AppController._statsKey, _alloc.toJson());
    _notify();
  }

  // ───────────────────────────────────────────── 속성 점수 (11-11 #63, 숨김)

  /// 사냥한 몬스터로 오르는 속성 점수 (기록 counters 'el:fire' 에 10배로 적는다)
  Map<String, int> _elementCounters(List<MonsterId> monsters) {
    final out = <String, int>{};
    final weapon = gear.attackElement;
    for (final m in monsters) {
      ElementRules.huntScore(Monsters.info(m).element, weapon).forEach((e, v) {
        out['el:${e.name}'] = (out['el:${e.name}'] ?? 0) + (v * 10).round();
      });
    }
    return out;
  }

  /// 속성 점수 (화면에 숫자로 보여 주지 않는다)
  Map<Element, double> get elementScores => ElementRules.scoresFrom(_history);

  /// 주 속성 (점수 1위, 30점부터)
  Element? get mainElement => ElementRules.mainOf(elementScores);
}
