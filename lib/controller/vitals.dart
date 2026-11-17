part of '../app_controller.dart';

/// HP·정령 MP·여관 휴식 (묶음 21: [AppController] 에서 나눔. 상태 칸은 본체에 있다)
extension VitalsOps on AppController {

  /// 전투용 최대 HP (장비 포함)
  int get maxHp {
    final p = player;
    return Battle.playerMaxHpWith(
        level: p.level.level, stats: combatStats, gear: gear);
  }

  /// 지금 HP (전투 사이에 이어진다. 0이면 싸울 수 없다)
  int get hp => math.min(maxHp, _vitals.hp ?? maxHp);

  /// 기력 (정령·펫이 원정에 쓴다, #183)
  int get mp => math.min(mpMax, _vitals.mp ?? mpMax);

  /// 기력 최대치: 기본 60 + 펫 보너스 (지능은 빠짐, #183). 저장된 값이 더 크면
  /// [mp] 가 새 최대치까지만 보여 준다.
  int get mpMax => StatRules.maxMp() + PetRules.mpMaxBonus(_pets.pets.length);

  /// 시간당 MP 회복 (두 번째 펫부터 +2, 11-11 #38)
  int get mpRegenPerHour =>
      RuleConstants.mpRegenPerHour + PetRules.mpRegenBonus(_pets.pets.length);

  /// 여관에서 쉬는 중이면 체크인 시각
  DateTime? get restStartedAt => _vitals.restStartedAt;
  bool get resting => _vitals.restStartedAt != null;

  /// 휴식이 얼마나 지났는지 (0 → 1)
  double get restProgress => resting
      ? TownRules.restProgress(_vitals.restStartedAt!, _clock())
      : 0;

  /// 휴식이 끝나기까지 남은 시간
  Duration get restLeft => resting
      ? TownRules.restLeft(_vitals.restStartedAt!, _clock())
      : Duration.zero;

  /// 진행 중이거나 결과를 아직 보지 않은 원정 (펫마다 하나, 11-11 #38)
  List<Expedition> get expeditions => _vitals.expeditions;

  /// 데리고 다니는 동료(정령 또는 동행 펫)의 원정
  Expedition? get expedition {
    final uid = farewellDone ? companionPet?.uid : null;
    for (final e in _vitals.expeditions) {
      if (e.petUid == uid) return e;
    }
    return null;
  }

  /// 묶음 25 #166: 지도·상태 정령 배지의 원정 대사 (원정 중이 아니면 null)
  String? get expeditionTalk => BulssiLines.expedition(expedition,
      playerName: _profile.name.trim(), now: now);

  /// 배지를 눌러 「서두를까?」로 바로 돌아오기를 열 원정 (정령 원정, 돌아오는 중까지)
  Expedition? get rushableExpedition {
    if (inTutorial) return null;
    final ex = expedition;
    if (ex == null || ex.finished || ex.petUid != null) return null;
    return ex;
  }

  /// 아직 돌아오지 않은 원정
  List<Expedition> get activeExpeditions =>
      [for (final e in _vitals.expeditions) if (!e.finished) e];

  /// 돌아와서 결과를 기다리는 원정 (여러 개가 한꺼번에 끝날 수 있다)
  List<Expedition> get finishedExpeditions =>
      [for (final e in _vitals.expeditions) if (e.finished) e];

  /// 원정 중인 펫 uid (정령은 null)
  bool isAway(String? petUid) =>
      _vitals.expeditions.any((e) => e.petUid == petUid);

  /// 다음 HP 회복까지 남은 걸음
  int get stepsToNextHeal => VitalRules.stepsToNextHeal(
      player.today?.steps ?? 0,
      _vitals.stepsDay == player.today?.dayKey ? _vitals.stepsCounted : 0);

  /// 시간·걸음에 따라 HP·MP를 채우고, 끝난 휴식과 원정을 마무리한다.
  /// 앱을 열 때, 화면을 볼 때 부른다.
  Future<void> refreshVitals() =>
      _serial(() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      await _refreshVitals();
      // 묶음 43 #228: 끝난 펫 훈련
      await _settlePetTraining();
      // 묶음 45 #232: 걸으면 듣는 전용 아이템 · 전용 퀘스트 다음 단계
      await _relicWalk();
      await _advanceRelics();
      // 묶음 49 #235: 여명 — 이른 아침 걸음으로 HP·기력
      await _heroWalk();
      // 묶음 50 #146: 걸음으로 하늘 깃털 · 다음 섬 알림
      await _highlandWalk();
      // 묶음 51: 고기 스튜 · 리안의 배낭 매듭 · 바르칸의 동전 주머니
      await _tavernWalk();
      // 묶음 52 #243: 3막 — 다음 지역 길 · 여정 기력 · 모집권
      await _act3Walk();
      // 묶음 45 #231: 마르타 — 하루 8,000보를 넘긴 날 (하루 한 번)
      final today = player.today;
      if (today != null &&
          today.steps >= NpcSmallRules.martaSteps &&
          !_village.contains('walk8k:${today.dayKey}')) {
        _village = {
          for (final k in _village)
            if (!k.startsWith('walk8k:')) k,
        };
        await _markVillage(['walk8k:${today.dayKey}']);
        await _smallTrigger(Npc.marta);
      }
    } catch (e, st) {
      // 묶음 16 #124: 시간에 따른 갱신이 실패해도 앱은 계속 (오류만 남긴다)
      await _logStartError(e, st);
    } finally {
      _refreshing = false;
    }
  });

  Future<void> _refreshVitals() async {
    final now = _clock();
    final p = player;
    final max = maxHp;
    var v = _vitals;
    var changed = false;

    // 처음이거나 레벨이 올라 최대 HP가 늘었으면 그만큼 지금 HP도 늘린다
    var curHp = v.hp ?? max;
    final lastMax = v.lastMaxHp;
    if (lastMax != max) {
      if (lastMax != null && max > lastMax) curHp += max - lastMax;
      curHp = math.min(curHp, max);
      v = v.copyWith(hp: curHp, lastMaxHp: max);
      changed = true;
    }

    // 걷기 회복: 1,000보마다 10%
    final today = p.today;
    if (today != null) {
      final counted = v.stepsDay == today.dayKey ? v.stepsCounted : 0;
      final (healed, used) = VitalRules.regenHpFromSteps(
        hp: curHp,
        maxHp: max,
        stepsToday: today.steps,
        stepsCounted: counted,
      );
      if (healed != curHp || used != counted || v.stepsDay != today.dayKey) {
        curHp = healed;
        v = v.copyWith(hp: healed, stepsDay: today.dayKey, stepsCounted: used);
        changed = true;
      }
    }

    // MP 자연 회복
    final (newMp, newAt) =
        VitalRules.regenMp(v.mp ?? mpMax, v.mpAt ?? now, now,
            max: mpMax, perHour: mpRegenPerHour);
    if (newMp != v.mp || newAt != v.mpAt) {
      v = v.copyWith(mp: newMp, mpAt: newAt);
      changed = true;
    }

    // 쉬는 동안: 시작할 때 HP·MP에서 가득까지 시간에 맞춰 고르게 (묶음 15 #107)
    final restAt = v.restStartedAt;
    if (restAt != null && !TownRules.restDone(restAt, now)) {
      final f = TownRules.restProgress(restAt, now);
      final hp0 = v.restHp0 ?? curHp;
      final mp0 = v.restMp0 ?? (v.mp ?? mpMax);
      final hpNow = math.max(curHp, TownRules.restFill(hp0, max, f));
      final mpNow = math.max(v.mp ?? mpMax, TownRules.restFill(mp0, mpMax, f));
      if (hpNow != curHp ||
          mpNow != (v.mp ?? mpMax) ||
          v.restHp0 == null ||
          v.restMp0 == null) {
        curHp = hpNow;
        v = v.copyWith(
            hp: hpNow, mp: mpNow, mpAt: now, restHp0: hp0, restMp0: mp0);
        changed = true;
      }
    }

    // 여관 휴식이 끝났으면 HP·MP를 모두 채우고 기록한다
    if (restAt != null && TownRules.restDone(restAt, now)) {
      v = v.copyWith(
          hp: max, mp: mpMax, mpAt: now, clearRest: true);
      _vitals = v;
      await store.saveVitals(v);
      await _fillJobMp(); // 묶음 30: 새 MP도 가득
      _justRested = true;
      // 묶음 54: 여관 ★3 → 쉬고 나면 잠시 경험치 조금 더
      await _innRested();
      // 묶음 45 #231: 마르타 — 여관에서 쉬고 일어날 때
      await _smallTrigger(Npc.marta);
      final rec = await _todayRecord();
      // 묶음 42 #226: 마르타와 단짝이면 휴식 보너스 경험치 조금 더 (숨김)
      final bonus = martaRestBonus;
      await store.upsert(_withQuests(rec.copyWith(
          restsCompleted: rec.restsCompleted + 1,
          gains: bonus > 0
              ? DailyRecord.addCounts(rec.gains, {Wallet.exp: bonus})
              : null)));
      _history = await store.loadHistory();
    }

    _vitals = v;
    if (changed) await store.saveVitals(v);

    // 묶음 23 #172: 도착하면 싸움 결과를 정하고(기록·보상 저장), 돌아오면 결과 카드.
    // 바로 돌아오기 등으로 둘이 한꺼번에 지나도 결과는 한 번만 정한다
    for (final ex in [...v.expeditions]) {
      if (!ex.decided && !now.isBefore(ex.arriveAt)) {
        await _resolveExpedition(ex);
      }
    }
    var backNow = false;
    final arrived = <Expedition>[];
    for (final ex in [..._vitals.expeditions]) {
      if (ex.decided && !ex.back && !now.isBefore(ex.returnAt)) {
        backNow = true;
        arrived.add(ex);
      }
    }
    if (backNow) {
      _vitals = _vitals.copyWith(expeditions: [
        for (final e in _vitals.expeditions)
          arrived.any((a) => a.spawnId == e.spawnId && a.petUid == e.petUid)
              ? e.returned()
              : e,
      ]);
      await store.saveVitals(_vitals);
      // 튜토리얼 원정은 돌아왔을 때 Lv.2
      for (final ex in arrived) {
        if (ex.spawnId == AppController.tutorialExpeditionId &&
            ex.cleared == true) {
          await _tutorialPurified(ex.spawnId);
        }
      }
    }
    await _mailExpiredBoard();
    await _checkLetters();
    await _checkMail();
    await _petSteps();
    await _jobSteps();
    await _checkAura();
    await _checkBoardEggs();
    // 묶음 48 #230: 주간 의뢰를 모두 끝낸 주 → 빛나는 씨앗
    await _checkGardenGlow();
    await _checkWalkEvents();
    // 묶음 54: 다 고친 건물
    await _settleBuildings();
    _notify();
  }

  /// 방금 휴식을 마쳤는지 (화면에서 한 번 알려 주고 [clearJustRested])
  bool get justRested => _justRested;
  void clearJustRested() {
    _justRested = false;
    _notify();
  }

  /// 여관에 체크인한다. 언제든, 하루 여러 번. 이미 쉬는 중이면 false.
  Future<bool> restAtInn() =>
      _serial(() async {
    if (resting) return false;
    await refreshVitals();
    final now = _clock();
    // 묶음 54: 여관 ★2 → 쉬는 시간이 짧아짐 (처음부터 조금 쉰 것으로, 숨김)
    final start = _star(Building.inn, 2)
        ? now.subtract(const Duration(hours: RuleConstants.restHours) *
            BuildingRules.innHead)
        : now;
    _vitals = _vitals.copyWith(
        restStartedAt: start, restHp0: hp, restMp0: mp);
    await store.saveVitals(_vitals);
    // 여관에 들르면 지친 상태가 바로 풀린다 (11-11 #75)
    if (_tiredUntil != null) await _setTired(null);
    // 묶음 42 #226: 마르타 친해지기 · 부탁 (연속 휴식 · 걷고 와서 쉬기)
    await _npcUse(Npc.marta);
    await _npcRested();
    unawaited(notifier?.schedule(
      NotifyId.rest,
      start.add(const Duration(hours: RuleConstants.restHours)),
      '푹 쉬었어요',
      'HP와 $companionName의 기력이 가득 찼어요. 앱을 열어 휴식 보너스를 받으세요!',
    ));
    _notify();
    return true;
  });

  /// 휴식을 그만둔다 (보상 없이). 그때까지 찬 HP·기력은 그대로 (묶음 15 #107)
  Future<void> stopResting() =>
      _serial(() async {
    if (!resting) return;
    await refreshVitals();
    if (!resting) return;
    _stopResting();
    await store.saveVitals(_vitals);
    _notify();
  });
}
