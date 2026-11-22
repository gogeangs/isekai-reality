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
  Future<bool> allocateStats(Stats add) =>
      _serial(() async {
    if (add.total <= 0 || add.total > unspentPoints) return false;
    for (final k in StatKind.values) {
      if (add.of(k) < 0) return false;
    }
    _alloc = _alloc.copyWith(allocated: _alloc.allocated + add);
    await _saveJson(AppController._statsKey, _alloc.toJson());
    await refreshVitals();
    _notify();
    return true;
  });

  /// 포인트로 올린 값만 되돌린다 (생활 보너스는 그대로). 금화가 모자라면 false.
  Future<bool> resetStats() =>
      _serial(() async {
    if (_alloc.allocated.total == 0) return false;
    final cost = statResetCost;
    if (player.gold < cost) return false;
    if (cost > 0) {
      final today = await _todayRecord();
      await _save(today.copyWith(
          spends: DailyRecord.addCounts(today.spends, {Wallet.gold: cost})));
    }
    _alloc = _alloc.copyWith(allocated: Stats.zero, resets: _alloc.resets + 1);
    await _saveJson(AppController._statsKey, _alloc.toJson());
    await refreshVitals();
    _notify();
    return true;
  });

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
    await _saveJson(AppController._statsKey, _alloc.toJson());
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

  /// 속성 점수 (화면에 숫자로 보여 주지 않는다). 묶음 32: 예전 기록에서 한 번 센 몫을 더한다
  Map<Element, double> get elementScores {
    final out = ElementRules.scoresFrom(_history);
    _elementSeed.forEach((e, v) => out[e] = (out[e] ?? 0) + v);
    return out;
  }

  /// 묶음 32 #189: 속성 점수를 더한다 (오늘 기록 counters 'el:<속성>', 10배)
  Future<void> _gainElement(Element e, double pts) async {
    if (pts <= 0) return;
    final today = await _todayRecord();
    await _save(today.copyWith(
        counters: DailyRecord.addCounts(
            today.counters, {'el:${e.name}': (pts * 10).round()})));
    await _checkAura();
  }

  /// 주 속성이 처음 생기거나 바뀌면 첫 펫(이별 전엔 정령) 한마디 (숙련도 대사 자리)
  Future<void> _checkAura() async {
    if (!_masteryReady) return;
    final main = mainElement;
    if (main == null || main.name == _auraAnnounced) return;
    _auraAnnounced = main.name;
    _mastery = _mastery.copyWith(
        pending: [..._mastery.pending, ElementRules.auraLine(main)]);
    await _saveMastery();
    await _saveAura();
    _notify();
  }

  Future<void> _saveAura() => _saveJson(AppController._auraKey, {
        'v32': true,
        if (_auraAnnounced != null) 'main': _auraAnnounced,
        'seed': {for (final e in _elementSeed.entries) e.key.name: e.value},
      });

  /// 묶음 32 처음 열 때: 남은 기록(채집·물약·장비)으로 새 쌓이는 곳을 한 번 센다.
  /// 이때 주 속성이 생기거나 바뀌어도 대사 없이 (프로필만)
  Future<void> _seedAura() async {
    final seed = <Element, double>{};
    void add(Element e, double v) {
      if (v > 0) seed[e] = (seed[e] ?? 0) + v;
    }

    // 채집 (숙련도 세부 기록: 광석·보석 → 금속, 약초·나무 → 대지), 물가는 완벽 채집 수
    add(Element.metal,
        masteryDetail(MasteryRules.harvestKey('ore')) * ElementRules.oreScore);
    add(
        Element.earth,
        (masteryDetail(MasteryRules.harvestKey('herb')) +
                masteryDetail(MasteryRules.harvestKey('wood'))) *
            ElementRules.woodScore);
    add(Element.water,
        (_harvest.perfects[HarvestKind.water.name] ?? 0) * ElementRules.waterScore);
    // 속성 물약 (연금술 세부 기록)
    for (final p in AlchemyRules.all) {
      final e = p.element;
      if (e == null) continue;
      add(e, masteryDetail(MasteryRules.potionKey(p.id)) * ElementRules.potionScore);
    }
    // 대장간에서 속성을 입힌 장비 (보스 장비는 처음부터 속성이 있어 뺌)
    for (final i in _armory.items) {
      final e = i.element;
      if (e == null || BossGearRules.setOf(i.base) != null) continue;
      add(e, ElementRules.imbueScore);
    }
    _elementSeed = seed;
    _auraAnnounced = mainElement?.name;
    await _saveAura();
  }

  /// 주 속성 (점수 1위, 30점부터)
  Element? get mainElement => ElementRules.mainOf(elementScores);
}
