part of '../app_controller.dart';

/// HP·정령 MP·여관 휴식 (묶음 21: [AppController] 에서 나눔. 상태 칸은 본체에 있다)
extension VitalsOps on AppController {

  /// 전투용 최대 HP (장비 포함)
  int get maxHp {
    final p = player;
    final base = Battle.playerMaxHpWith(
        level: p.level.level, stats: combatStats, gear: gear);
    // 묶음 81 #373: 여관 ★3 — 가득 찬 뒤 일어나면 잠시 최대가 조금 늘어요 (숨김)
    return innBoostOn ? (base * InnRules.star3Max).round() : base;
  }

  /// 지금 HP (전투 사이에 이어진다. 0이면 싸울 수 없다)
  int get hp => math.min(maxHp, _vitals.hp ?? maxHp);

  /// 기력 (정령·펫이 원정에 쓴다, #183)
  int get mp => math.min(mpMax, _vitals.mp ?? mpMax);

  /// 기력 최대치: 기본 60 + 펫 보너스 (지능은 빠짐, #183). 저장된 값이 더 크면
  /// [mp] 가 새 최대치까지만 보여 준다.
  /// 묶음 66 #270: 60 + 2 × (레벨 − 1) + 펫 보너스
  int get mpMax {
    final base = VitalRules.levelMp(player.level.level) + PetRules.mpMaxBonus(_pets.pets.length);
    return innBoostOn ? (base * InnRules.star3Max).round() : base;
  }

  /// 시간당 MP 회복: 레벨 기력의 1/6 + 펫 보너스 (두 번째 펫부터 +2, 11-11 #38). 소수는 분 단위로 셈
  double get mpRegenPerHour =>
      VitalRules.levelMpPerHour(player.level.level) + PetRules.mpRegenBonus(_pets.pets.length);

  /// 여관에서 쉬는 중이면 체크인 시각
  DateTime? get restStartedAt => _vitals.restStartedAt;
  bool get resting => _vitals.restStartedAt != null;

  // ───────────── 여관 (묶음 81 #373 · #371: 있는 동안 시간당 20%씩, 상한 없음)

  /// 원정 나간 펫이 있어 여관 회복이 멈췄는지 (밖의 회복은 그대로)
  bool get innPaused {
    final now = _clock();
    return _vitals.expeditions.any((e) => now.isBefore(e.returnAt)) ||
        _vitals.trips.any((t) => !t.done(now));
  }

  /// 여관 회복 속도 (★2 · 마르타 단짝, 숨김)
  double get innSpeed => InnRules.speed(star2: _star(Building.inn, 2), martaBest: _bestWith(Npc.marta));

  /// HP · 기력 · (각성 뒤) MP가 모두 가득
  bool get innFull => hp >= maxHp && mp >= mpMax && (!jobsOpen || jobMp >= jobMpMax);

  /// 광고 보고 바로 회복 (가득이거나 원정 중이면 없음, 한 번 체크인에 두 번)
  bool get canInnAd =>
      adsReady && resting && !innPaused && !innFull && _vitals.restAds < InnRules.adsPerRest;

  /// 원정 나간 구간 (여관 회복이 멈추는 때)
  List<(DateTime, DateTime)> get _awaySpans => [
        for (final e in _vitals.expeditions) (e.startedAt, e.returnAt),
        for (final t in _vitals.trips) (t.startedAt, t.returnAt),
      ];

  /// 체크인해 있는 동안 [now] 까지 찬 만큼 (HP · 기력은 [v] 에, 직업 MP는 따로 돌려줌)
  (Vitals, int?) _innGain(Vitals v, DateTime now, int curHp) {
    final start = v.restStartedAt;
    if (start == null) return (v, null);
    final from = v.restAt ?? start;
    if (!now.isAfter(from)) return (v, null);
    final paused = InnRules.pausedWithin(from, now, _awaySpans);
    final eff = now.difference(from) - paused;
    final hours = eff.inSeconds / 3600;
    final sp = innSpeed;
    final carry = [...v.restCarry, 0.0, 0.0, 0.0];
    final hpMax = maxHp, mMax = mpMax;
    final curMp = math.min(mMax, v.mp ?? mMax);
    final (hAdd, hC) = InnRules.gain(hpMax, hours, carry[0], speed: sp);
    final (mAdd, mC) = InnRules.gain(mMax, hours, carry[1], speed: sp);
    final hpNow = math.min(hpMax, curHp + hAdd);
    final mpNow = math.min(mMax, curMp + mAdd);
    int? job;
    var jC = carry[2];
    if (_jobs.awakened) {
      final (jAdd, c) = InnRules.gain(jobMpMax, hours, carry[2], speed: sp);
      jC = c;
      final j = math.min(jobMpMax, jobMp + jAdd);
      if (j != jobMp) job = j;
      if (j >= jobMpMax) jC = 0;
    }
    return (
      v.copyWith(
        hp: hpNow,
        mp: mpNow,
        restAt: now,
        restCarry: [hpNow >= hpMax ? 0 : hC, mpNow >= mMax ? 0 : mC, jC],
        restSec: v.restSec + eff.inSeconds,
      ),
      job,
    );
  }

  /// 광고 보고 바로 회복: 최대치의 20%씩 바로 (HP · 기력 · MP)
  Future<bool> innAd() async {
    if (!canInnAd || !await _watchAd('inn_heal')) return false;
    return _serial(() async {
      await refreshVitals();
      if (!resting) return false;
      final hpMax = maxHp, mMax = mpMax;
      _vitals = _vitals.copyWith(
        hp: math.min(hpMax, hp + (hpMax * InnRules.adGain).round()),
        mp: math.min(mMax, mp + (mMax * InnRules.adGain).round()),
        restAds: _vitals.restAds + 1,
      );
      if (_jobs.awakened) {
        await _setJobMp(math.min(jobMpMax, jobMp + (jobMpMax * InnRules.adGain).round()));
      }
      await store.saveVitals(_vitals);
      await refreshVitals();
      _notify();
      return true;
    });
  }

  /// 가득 찰 때 알림 다시 예약 (원정 중이면 취소)
  void _scheduleInnFull() {
    if (!resting || innPaused || innFull || _vitals.restFullSeen) {
      if (_innNotifyAt != null) unawaited(notifier?.cancel(NotifyId.rest));
      _innNotifyAt = null;
      return;
    }
    final at = _clock().add(InnRules.untilFull([
      (hp, maxHp),
      (mp, mpMax),
      if (jobsOpen) (jobMp, jobMpMax),
    ], speed: innSpeed));
    if (_innNotifyAt != null && (at.difference(_innNotifyAt!).inSeconds).abs() < 60) return;
    _innNotifyAt = at;
    unawaited(notifier?.schedule(NotifyId.rest, at, '여관',
        jobsOpen ? 'HP · MP · 기력이 가득 찼어요' : 'HP · 기력이 가득 찼어요'));
  }

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
      _vitals.expeditions.any((e) => e.petUid == petUid) || _onTrip(petUid);

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
      // 묶음 56: 앱을 켜는 중(기록을 다 읽기 전)에는 여기까지만. 마을 · 주점 · 하이랜드 · 3막 기록을
      // 읽기 전에 저장하면 빈 기록으로 덮어쓴다 (예: 8,000보 넘긴 날 처음 켤 때 마을 기록이 지워짐)
      if (!_ready) return;
      // 묶음 43 #228: 끝난 펫 훈련
      await _settlePetTraining();
      // 묶음 45 #232: 걸으면 듣는 전용 아이템 · 전용 퀘스트 다음 단계
      await _relicWalk();
      await _advanceRelics();
      // 묶음 49 #235: 여명 — 이른 아침 걸음으로 HP·기력
      await _heroWalk();
      // 묶음 58: 마레 — 물가를 걸으면 가끔 귀한 재료
      await _mareWalk();
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

    // 묶음 81 #373: 여관에 있는 동안 시간당 20%씩 (원정 나간 동안은 멈춤, 상한 없음)
    if (v.restStartedAt != null) {
      final (nv, job) = _innGain(v, now, curHp);
      v = nv;
      curHp = v.hp ?? curHp;
      changed = true;
      if (job != null) await _setJobMp(job);
      final full = curHp >= max &&
          (v.mp ?? mpMax) >= mpMax &&
          (!_jobs.awakened || jobMp >= jobMpMax);
      // 그날 실제로 1시간 넘게 회복했거나 셋 다 가득 → 「쉬었다」 (체크인마다 하루 한 번)
      final day = DailyRecord.dayKeyOf(now);
      if (v.restCounted != day && (v.restSec >= InnRules.restedAfter.inSeconds || full)) {
        v = v.copyWith(restCounted: day);
        _vitals = v;
        await store.saveVitals(v);
        final rec = await _todayRecord();
        await store.upsert(_withQuests(rec.copyWith(restsCompleted: rec.restsCompleted + 1)));
        _history = await store.loadHistory();
        // 묶음 45 #231: 마르타 — 여관에서 쉬고 나서
        await _smallTrigger(Npc.marta);
      }
      if (full && !v.restFullSeen) {
        v = v.copyWith(restFullSeen: true);
        _justRested = true;
      }
    }

    _vitals = v;
    // 묶음 81 #375: 잿빛 틈 · 섬에서 돌아온 펫
    if (_settleTrips()) changed = true;
    if (changed) await store.saveVitals(_vitals);
    _scheduleInnFull();

    // 묶음 23 #172: 도착하면 싸움 결과를 정하고(기록·보상 저장), 돌아오면 결과 카드.
    // 바로 돌아오기 등으로 둘이 한꺼번에 지나도 결과는 한 번만 정한다
    // 묶음 82 #381: 도착 순서대로 (하나의 HP · MP를 나눠 씀)
    for (final ex in [...v.expeditions]..sort((a, b) => a.arriveAt.compareTo(b.arriveAt))) {
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
    // 묶음 54: 다 고친 건물 (기록을 다 읽은 뒤에만)
    if (_ready) await _settleBuildings();
    _notify();
  }

  /// 방금 휴식을 마쳤는지 (화면에서 한 번 알려 주고 [clearJustRested])
  bool get justRested => _justRested;
  void clearJustRested() {
    _justRested = false;
    _notify();
  }

  /// 여관에 체크인한다. 언제든, 하루 여러 번. 이미 쉬는 중이면 false.
  /// 묶음 81 #373: 일어나기 전까지 시간당 20%씩 (4시간 상한 없음)
  Future<bool> restAtInn() =>
      _serial(() async {
    if (resting) return false;
    await refreshVitals();
    final now = _clock();
    _vitals = _vitals.copyWith(restStartedAt: now, restAt: now);
    await store.saveVitals(_vitals);
    // 여관에 들르면 지친 상태가 바로 풀린다 (11-11 #75)
    if (_tiredUntil != null) await _setTired(null);
    // 묶음 42 #226: 마르타 친해지기 · 부탁 (연속 휴식 · 걷고 와서 쉬기)
    await _npcUse(Npc.marta);
    await _npcRested();
    _innNotifyAt = null;
    _scheduleInnFull();
    _notify();
    return true;
  });

  /// 일어나기. 그때까지 찬 HP·기력은 그대로 (묶음 15 #107).
  /// 묶음 81 #373: 여관 ★3 — 가득 찬 뒤 일어나면 잠시 HP · 기력 최대가 조금 늘어요
  Future<void> stopResting() =>
      _serial(() async {
    if (!resting) return;
    await refreshVitals();
    if (!resting) return;
    final full = innFull;
    _stopResting();
    await store.saveVitals(_vitals);
    if (full) await _innRested();
    _notify();
  });
}
