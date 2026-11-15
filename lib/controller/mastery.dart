part of '../app_controller.dart';

/// 숨은 숙련도 (묶음 27 #176): 쌓기 · 효과 · 대사 · 칭호.
/// 숫자·막대는 화면에 보이지 않는다. 대사와 칭호로만 느낀다.
extension MasteryOps on AppController {
  MasteryState get masteryState => _mastery;

  /// 큰 숙련도 값 (걷기·탐험은 기록에서 바로 센다)
  double masteryOf(Mastery m) => m == Mastery.walk
      ? MasteryRules.walkFrom(_history)
      : _mastery.bigOf(m.name);

  MasteryStage masteryStage(Mastery m) => MasteryRules.stageOf(masteryOf(m));

  /// 세부 숙련도 값
  double masteryDetail(String key) => _mastery.detailOf(key);

  /// 큰 숙련도 효과 비율 (0~1)
  double _bigFrac(Mastery m) => MasteryRules.fraction(masteryOf(m));

  /// 세부 숙련도 효과 비율 (0~1)
  double _detailFrac(String key) =>
      MasteryRules.fraction(masteryDetail(key), detail: true);

  /// 숙련도 대사를 말하는 쪽 (한 곳에서 고른다).
  /// 지금은 함께 다니는 동료(정령, Lv.11 이별 뒤엔 첫 펫) — 배지 그림도 같은 동료다.
  String get masteryVoice => companionName;

  /// 첫 펫이 말할 때 떠난 정령 이름 (정령술 대사만 첫 펫용 문구로, 묶음 29 #182)
  String? get _departed => firstPet != null ? firstSpiritName : null;

  // ───────────── 효과 (숨은 규칙, 단계마다 조금씩)

  /// 지금 든 무기 종류
  String? get _weaponKind =>
      MasteryRules.weaponKind(_armory.wornIn(EquipSlot.weapon)?.base);

  /// 전투 피해 배율: 그 무기 · 그 몬스터 (몬스터는 필드 전투만)
  double combatPower({MonsterId? monster}) {
    final w = _weaponKind;
    var p = 1.0;
    if (w != null) {
      p *= 1 +
          MasteryRules.weaponDamage *
              _detailFrac(MasteryRules.weaponKey(w));
    }
    if (monster != null) {
      p *= 1 +
          MasteryRules.monsterDamage *
              _detailFrac(MasteryRules.monsterKey(monster));
    }
    return p;
  }

  /// 그 장비 종류를 만들 때 좋은 등급(파랑) +%p
  double smithGradeBonus(EquipBase base) => math.max(
      _mastery.smithFloor ?? 0,
      MasteryRules.smithBluePoints *
          _detailFrac(MasteryRules.smithKey(MasteryRules.smithKind(base))));

  /// 예전 규칙(만든 장비 10개마다 +1%p, 최대 10)으로 센 바닥값
  double get _legacySmithFloor =>
      EquipmentRules.masteryBonus(_armory.crafts).toDouble();

  /// 그 장비 수리비 (조금 덜)
  int masteryRepairCost(EquipItem item) {
    final base = EquipmentRules.repairCost(item);
    final f = _detailFrac(MasteryRules.smithKey(MasteryRules.smithKind(item.base)));
    if (f <= 0 || base <= 0) return base;
    return math.max(1, (base * (1 - MasteryRules.smithRepairCut * f)).round());
  }

  /// 확률 [chance] 로 한 번 굴린다. 효과가 없으면(0) 굴리지도 않는다 (다른 결과를 흔들지 않게)
  bool _masteryRoll(double chance) =>
      chance > 0 && _random.nextDouble() < chance;

  /// 원정 MP·시간 배율 (정령술)
  double get spiritMpFactor => 1 - MasteryRules.spiritMpCut * _bigFrac(Mastery.spirit);
  double get spiritTimeFactor =>
      1 - MasteryRules.spiritTimeCut * _bigFrac(Mastery.spirit);

  /// 팔 때 금화 (장사·의뢰)
  int tradeGold(int gold) {
    final f = _bigFrac(Mastery.trade);
    if (f <= 0 || gold <= 0) return gold;
    return (gold * (1 + MasteryRules.tradeGold * f)).round();
  }

  /// 의뢰 보상 금화 (장사·의뢰)
  int errandGold(int gold) {
    final f = _bigFrac(Mastery.trade);
    if (f <= 0 || gold <= 0) return gold;
    return (gold * (1 + MasteryRules.errandGold * f)).round();
  }

  /// 감정 재료·쪽지 확률 (감정)
  double appraiseChance(double c) =>
      MasteryRules.scaled(c, _bigFrac(Mastery.appraise), MasteryRules.appraiseBonus);

  /// #183: Lv.15 전 지능의 숨은 몫 (감정 드문 결과·연금술 결과). Lv.15 부터는 새 MP 로
  double get intellectCraft => player.level.level < 15
      ? StatRules.intellectCraftBonus(combatStats)
      : 0;

  /// 새 장소 보너스 경험치 (걷기·탐험)
  int get placeBonusExp =>
      (RuleConstants.newPlaceExp * MasteryRules.walkPlaceExp * _bigFrac(Mastery.walk))
          .round();

  /// 오늘 걸음에 붙는 열쇠 게이지 보너스 걸음 (걷기·탐험). 기록 'masteryGauge' 로 한 번씩만
  Future<void> _walkGaugeBonus() async {
    final f = _bigFrac(Mastery.walk);
    if (f <= 0 || _history.isEmpty) return;
    final today = _history.last;
    final target = (today.steps * MasteryRules.walkGauge * f).floor();
    final given = today.counters['masteryGauge'] ?? 0;
    if (target <= given) return;
    await _save(today.copyWith(
        counters: DailyRecord.addCounts(today.counters,
            {'masteryGauge': target - given, 'gaugeBonus': target - given})));
  }

  // ───────────── 쌓기

  /// 큰 숙련도 [m] 에 [amount] 를, 세부 [details] 에 1씩 더한다.
  /// 단계가 오르면 대사·칭호를 한 번 남긴다.
  Future<void> gainMastery(Mastery m, double amount,
      {List<String> details = const [], double detailAmount = 1}) async {
    if (amount <= 0 && details.isEmpty) return;
    var s = _mastery;
    if (m != Mastery.walk && amount > 0) {
      s = s.copyWith(big: {...s.big, m.name: s.bigOf(m.name) + amount});
    }
    if (details.isNotEmpty) {
      final d = {...s.detail};
      for (final k in details) {
        d[k] = (d[k] ?? 0) + detailAmount;
      }
      s = s.copyWith(detail: d);
    }
    _mastery = s;
    await _afterMastery();
  }

  /// 단계 대사·장인 한마디·칭호·성향 바뀜을 살핀다
  Future<void> _afterMastery() async {
    var s = _mastery;
    final lines = <String>[...s.pending];
    final announced = {...s.announced};
    final titles = <TitleId>[];
    for (final m in Mastery.values) {
      final st = masteryStage(m);
      final before = announced[m.name] ?? 0;
      if (st.index > before) {
        // 한 번에 여러 단계가 오르면 마지막 단계 대사만
        final line = MasteryRules.stageLine(m, st, departed: _departed);
        if (line != null) lines.add(line);
        announced[m.name] = st.index;
      }
      for (final x in [MasteryStage.expert, MasteryStage.master]) {
        if (st.index >= x.index) titles.add(MasteryRules.titleAt(m, x)!);
      }
    }
    final masters = [...s.masters];
    s.detail.forEach((k, v) {
      if (masters.contains(k)) return;
      if (MasteryRules.stageOf(v, detail: true) == MasteryStage.master) {
        masters.add(k);
        final line = MasteryRules.masterLine(k);
        if (line != null) lines.add(line);
      }
    });
    // 가장 높은 큰 숙련도가 바뀌면 성향 대사
    final top = _topMastery();
    var leanAt = s.leanAt;
    if (top != null &&
        s.top != null &&
        top.name != s.top &&
        MasteryRules.leanReady(masteryOf(top))) {
      lines.add(MasteryRules.leanLine(top, departed: _departed));
      leanAt = _clock();
    }
    _mastery = s.copyWith(
      pending: lines,
      announced: announced,
      masters: masters,
      top: top?.name ?? s.top,
      leanAt: leanAt,
    );
    await _grantMasteryTitles(titles);
    await _saveMastery();
  }

  Mastery? _topMastery() {
    Mastery? best;
    var v = 0.0;
    for (final m in Mastery.values) {
      final x = masteryOf(m);
      if (x > v) {
        v = x;
        best = m;
      }
    }
    return best;
  }

  /// 숙련도 칭호를 기록에 남긴다 (얻으면 목록에 들어가고 축하 창은 지금 방식)
  Future<void> _grantMasteryTitles(List<TitleId> titles,
      {bool quiet = false}) async {
    if (titles.isEmpty || _history.isEmpty) return;
    final have = player.titles;
    final add = [for (final t in titles) if (!have.contains(t)) t];
    if (add.isEmpty) return;
    final today = await _todayRecord();
    await _save(today.copyWith(
        counters: DailyRecord.addCounts(today.counters,
            {for (final t in add) TitleRules.masteryCounter(t): 1})));
    if (quiet) {
      _mastery = _mastery.copyWith(
          quietTitles: [..._mastery.quietTitles, for (final t in add) t.name]);
    }
  }

  Future<void> _saveMastery() =>
      store.saveJson(AppController._masteryKey, _mastery.toJson());

  /// 축하 창 대신 위쪽 띠로만 알릴 칭호인지 (예전 기록 시작 값으로 얻은 것)
  bool titleIsQuiet(TitleId t) =>
      quietTitles || _mastery.quietTitles.contains(t.name);

  /// 걸음·장소가 늘었을 때 (걷기·탐험은 기록에서 바로 센다)
  Future<void> _checkWalkMastery() async {
    if (!_masteryReady) return;
    await _walkGaugeBonus();
    final st = masteryStage(Mastery.walk);
    if (st.index > (_mastery.announced[Mastery.walk.name] ?? 0)) {
      await _afterMastery();
    }
  }

  // ───────────── 대사 보여 주기

  /// 지도·상태 정령 배지에 섞을 숙련도 대사 (없으면 null).
  /// 쌓인 대사를 하나씩, 없으면 일주일에 한 번쯤 성향 대사. 한 줄은 10분 동안 남긴다.
  String? get masteryTalk {
    if (!_masteryReady || inTutorial) return null;
    final now = _clock();
    final shown = _shownMastery;
    if (shown != null && now.difference(shown.$2) < const Duration(minutes: 10)) {
      return shown.$1;
    }
    _shownMastery = null;
    final s = _mastery;
    if (s.pending.isNotEmpty) {
      final line = s.pending.first;
      _shownMastery = (line, now);
      _mastery = s.copyWith(pending: s.pending.sublist(1));
      unawaited(_saveMastery());
      return line;
    }
    final top = _topMastery();
    if (top != null &&
        MasteryRules.leanReady(masteryOf(top)) &&
        (s.leanAt == null ||
            now.difference(s.leanAt!) >= MasteryRules.leanEvery)) {
      final line = MasteryRules.leanLine(top, departed: _departed);
      _shownMastery = (line, now);
      _mastery = s.copyWith(leanAt: now, top: top.name);
      unawaited(_saveMastery());
      return line;
    }
    return null;
  }

  // ───────────── 처음 열 때 (예전 기록 시작 값)

  Future<void> _loadMastery() async {
    final j = await store.loadJson(AppController._masteryKey);
    if (j != null) {
      _mastery = MasteryState.fromJson(j);
      _masteryReady = true;
      // 11-15: 바닥값이 없으면(iPhone 129 숙련도 저장본) 한 번 채운다
      if (_mastery.smithFloor == null) {
        _mastery = _mastery.copyWith(smithFloor: _legacySmithFloor);
        await _saveMastery();
      }
      return;
    }
    _mastery = _seedMastery();
    _masteryReady = true;
    // 채운 값으로 정해진 단계는 대사를 몰아 띄우지 않는다 (칭호만 조용히 위쪽 띠로)
    final announced = <String, int>{};
    final titles = <TitleId>[];
    for (final m in Mastery.values) {
      final st = masteryStage(m);
      announced[m.name] = st.index;
      for (final x in [MasteryStage.expert, MasteryStage.master]) {
        if (st.index >= x.index) titles.add(MasteryRules.titleAt(m, x)!);
      }
    }
    _mastery = _mastery.copyWith(
      announced: announced,
      masters: [
        for (final e in _mastery.detail.entries)
          if (MasteryRules.stageOf(e.value, detail: true) == MasteryStage.master)
            e.key,
      ],
      top: _topMastery()?.name,
      leanAt: _clock(),
      smithFloor: _legacySmithFloor,
    );
    await _grantMasteryTitles(titles, quiet: true);
    await _saveMastery();
  }

  /// 지금까지 한 횟수로 시작 값을 채운다
  MasteryState _seedMastery() {
    final big = <String, double>{};
    final detail = <String, double>{};
    void add(Map<String, double> m, String k, double v) {
      if (v > 0) m[k] = (m[k] ?? 0) + v;
    }

    // 대장일: 만든 장비 수, 가진 장비 종류별
    add(big, Mastery.smith.name, _armory.crafts.toDouble());
    for (final i in _armory.items) {
      add(detail, MasteryRules.smithKey(MasteryRules.smithKind(i.base)), 1);
    }
    // 채집: 채집 횟수, 완벽하게 캔 종류별
    add(big, Mastery.harvest.name, _harvest.total.toDouble());
    _harvest.perfects.forEach((k, n) {
      final kind = HarvestKind.values.where((x) => x.name == k).firstOrNull;
      final d = kind == null ? null : MasteryRules.harvestKind(kind);
      if (d != null) add(detail, MasteryRules.harvestKey(d), n.toDouble());
    });
    // 연금술: 끓인 횟수(연금술 점수로 어림), 알아낸 물약에 나눠서
    final brews = _alc.mastery ~/ AlchemistRules.brewPoints;
    add(big, Mastery.alchemy.name, brews.toDouble());
    final found = _alc.discovered;
    if (found.isNotEmpty && brews > 0) {
      final each = (brews / found.length).floorToDouble();
      for (final n in found) {
        final p = PotionId.values.where((x) => x.name == n).firstOrNull;
        if (p != null) add(detail, MasteryRules.potionKey(p), each);
      }
    }
    // 전투: 몬스터별 사냥 수 + 던전 클리어, 무기는 지금 무기에 사냥 수 절반쯤
    var hunts = 0;
    huntTotals.forEach((m, n) {
      hunts += n;
      add(detail, MasteryRules.monsterKey(m), n.toDouble());
    });
    final clears = _history.fold<int>(
        0, (s, d) => s + d.dungeonRuns.where((r) => r.cleared).length);
    add(big, Mastery.combat.name,
        hunts + clears * MasteryRules.dungeonClear);
    final w = _weaponKind;
    if (w != null) {
      add(detail, MasteryRules.weaponKey(w),
          MasteryRules.legacyWeaponShare(hunts));
    }
    // 감정: 앨범 사진 수
    add(big, Mastery.appraise.name, _lens.album.length.toDouble());
    // 정령술: 이긴 원정 1, 진 원정 0.5
    int counter(String k) =>
        _history.fold<int>(0, (s, d) => s + (d.counters[k] ?? 0));
    final wins = counter('expeditionWin');
    final sent = counter('expedition');
    add(big, Mastery.spirit.name,
        wins * MasteryRules.expeditionWin +
            math.max(0, sent - wins) * MasteryRules.expeditionLoss);
    // 장사·의뢰: 끝낸 의뢰
    add(big, Mastery.trade.name,
        (counter('errandDone') + counter('urgentDone')) *
            MasteryRules.errandDone);
    return MasteryState(big: big, detail: detail);
  }
}
