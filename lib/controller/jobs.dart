part of '../app_controller.dart';

/// 스킬을 쓴 결과
enum SkillUse { ok, notEnoughMp, cannot, already }

/// 직업 각성·새 MP·직업 스킬 (묶음 30 #55·#183).
/// 수치는 모두 숨은 규칙. 화면에는 MP 막대·숫자와 스킬 비용만.
extension JobOps on AppController {
  JobState get jobState => _jobs;

  /// 직업 각성을 마쳤는지 (길드·직업·MP·마나 물약이 보인다)
  bool get jobsOpen => _jobs.awakened;

  /// Lv.15 직업 각성을 보여 줄 때인지 (이별 컷신이 먼저)
  bool get jobAwakenPending =>
      !_jobs.awakened &&
      player.level.level >= JobRules.awakenLevel &&
      !farewellPending &&
      !inTutorial;

  Future<void> _saveJobs(JobState j) async {
    _jobs = j;
    await store.saveJson(AppController._jobsKey, j.toJson());
    _notify();
  }

  // ───────────── 열린 직업

  /// 숨은 직업 조건 (묶음 31 #193: 밤 걸음 누적 · 정령+첫 펫 날 수와 첫 펫 친밀도)
  Set<JobId> get _hiddenJobs {
    final out = <JobId>{};
    var night = 0;
    var ash = 0;
    for (final d in _history) {
      night += d.nightSteps;
      ash += d.counters['ashClone'] ?? 0;
    }
    if (night >= JobRules.nightWalkerSteps) out.add(JobId.nightWalker);
    final spiritDays = spiritMemory?.days ?? (farewellDone ? 0 : awakenedDays);
    final first = firstPet;
    var petDays = 0;
    if (first != null) {
      final b = first.bornAt, now = _clock();
      petDays = DateTime(now.year, now.month, now.day)
              .difference(DateTime(b.year, b.month, b.day))
              .inDays +
          1;
    }
    if (first != null &&
        first.bond >= PetRules.maxBond &&
        spiritDays + petDays >= JobRules.gateHeirDays) {
      out.add(JobId.gateHeir);
    }
    if (ash > 0) out.add(JobId.ashHunter);
    final masters = Mastery.values
        .where((m) => masteryStage(m) == MasteryStage.master)
        .length;
    if (masters >= 4) out.add(JobId.allCrafter);
    return out;
  }

  /// 길드 「곧 열릴 것 같은 직업」 (#192): 아직 없는 기본·복합 직업 중 가까운 2~3개
  List<JobId> get nearJobs => JobRules.nearJobs(masteryOf, _jobs.ownedJobs);

  /// 지금 조건을 채운 직업
  Set<JobId> get unlockedJobs =>
      JobRules.unlocked(masteryStage, hidden: _hiddenJobs);

  /// 가장 높은 큰 숙련도
  Mastery get _topMasteryOrSmith {
    var best = Mastery.combat;
    var v = -1.0;
    for (final m in Mastery.values) {
      final x = masteryOf(m);
      if (x > v) {
        v = x;
        best = m;
      }
    }
    return best;
  }

  /// 추천 직업: 가장 높은 큰 숙련도의 기본 직업
  JobId get recommendedJob => JobRules.basicOf(_topMasteryOrSmith);

  /// 직업 고르기 목록: 추천이 맨 위. 열린 직업이 없으면 추천 직업 하나(견습)
  List<JobId> get jobChoices {
    final open = unlockedJobs;
    if (open.isEmpty) return [recommendedJob];
    final rec = recommendedJob;
    return [
      if (open.contains(rec)) rec,
      for (final j in JobId.values)
        if (open.contains(j) && j != rec) j,
    ];
  }

  /// 견습으로 시작해야 하는지 (열린 직업이 없음)
  bool get jobStartsApprentice => unlockedJobs.isEmpty;

  /// 얻은 직업 (얻은 순서, 새것이 맨 위)
  List<JobId> get ownedJobs => [
        for (final s in _jobs.owned.reversed)
          if (JobRules.parse(s) case final j?) j,
      ];

  JobId? get mainJob => _jobs.mainJob;
  List<JobId> get subJobs => _jobs.subJobs;
  bool get jobApprentice => _jobs.apprentice;
  int get subJobSlots => JobRules.subSlots(player.level.level);

  /// 화면에 보이는 주 직업 이름 (견습이면 「견습 ○○」)
  String? get mainJobLabel {
    final j = mainJob;
    if (j == null || !jobsOpen) return null;
    final n = JobRules.info(j).name;
    return _jobs.apprentice ? '견습 $n' : n;
  }

  /// 길드 목록에서 처음 보는 직업인지 (한 번 빛남)
  bool jobIsNew(JobId j) => !_jobs.seen.contains(j.name);

  Future<void> markJobsSeen() async {
    final all = {..._jobs.seen, ..._jobs.owned};
    if (all.length == _jobs.seen.length) return;
    await _saveJobs(_jobs.copyWith(seen: all.toList()));
  }

  /// Lv.15 직업 각성: 주 직업 하나와 보조 직업(없어도 됨)을 고른다. MP 가득
  Future<bool> awakenJob(JobId main, {List<JobId> subs = const []}) =>
      _serial(() async {
        if (_jobs.awakened) return false;
        final open = unlockedJobs;
        final apprentice = open.isEmpty;
        if (!apprentice && !open.contains(main)) return false;
        if (apprentice && main != recommendedJob) return false;
        final owned = <String>[
          for (final j in JobId.values)
            if (open.contains(j)) j.name,
          if (apprentice) main.name,
        ];
        final s = [
          for (final x in subs)
            if (x != main && open.contains(x)) x.name,
        ].take(subJobSlots).toList();
        final today = player.today;
        await _saveJobs(_jobs.copyWith(
          awakened: true,
          owned: owned,
          main: main.name,
          subs: s,
          apprentice: apprentice,
          clearMp: true,
          stepsDay: today?.dayKey,
          stepsCounted: today?.steps ?? 0,
        ));
        await _checkSkillPage();
        return true;
      });

  /// 길드에서 주 직업 바꾸기 (언제든 무료). 보조에 있던 직업이면 자리를 맞바꾼다
  Future<bool> setMainJob(JobId j) async {
    if (!_jobs.ownedJobs.contains(j)) return false;
    final old = mainJob;
    if (old == j) return true;
    final subs = [
      for (final s in _jobs.subs)
        if (s == j.name) ...[if (old != null) old.name] else s,
    ];
    await _saveJobs(_jobs.copyWith(main: j.name, subs: subs));
    return true;
  }

  /// 보조 슬롯 [i] 에 [j] (null 이면 비움). 같은 직업은 두 칸에 둘 수 없다
  Future<bool> setSubJob(int i, JobId? j) async {
    if (i < 0 || i >= subJobSlots) return false;
    if (j != null && (!_jobs.ownedJobs.contains(j) || j == mainJob)) {
      return false;
    }
    final subs = [..._jobs.subs];
    while (subs.length <= i) {
      subs.add('');
    }
    if (j != null && subs.contains(j.name) && subs[i] != j.name) return false;
    subs[i] = j?.name ?? '';
    await _saveJobs(_jobs.copyWith(
        subs: [for (final s in subs) if (s.isNotEmpty) s]));
    return true;
  }

  /// 숙련도가 오르면 새 직업이 열리고, 견습이 떨어진다
  Future<void> _checkJobs() async {
    if (!_jobs.awakened) return;
    final open = unlockedJobs;
    final owned = {..._jobs.owned};
    final fresh = [
      for (final j in JobId.values)
        if (open.contains(j) && !owned.contains(j.name)) j,
    ];
    var apprentice = _jobs.apprentice;
    final notes = [..._jobs.newJobs];
    if (apprentice && mainJob != null && open.contains(mainJob)) {
      apprentice = false;
      notes.add('done:${mainJob!.name}');
    }
    if (fresh.isEmpty && apprentice == _jobs.apprentice) return;
    for (final j in fresh) {
      notes.add(j.name);
      _mastery = _mastery.copyWith(pending: [
        ..._mastery.pending,
        JobRules.newJobLine(JobRules.info(j).name),
      ]);
    }
    if (fresh.isNotEmpty) unawaited(_saveMastery());
    await _saveJobs(_jobs.copyWith(
      owned: [..._jobs.owned, for (final j in fresh) j.name],
      apprentice: apprentice,
      newJobs: notes,
    ));
  }

  /// 위쪽 띠로 알릴 새 직업 소식 (한 번 꺼내면 지운다)
  String? takeJobNotice() {
    if (_jobs.newJobs.isEmpty) return null;
    // 직업 소식 먼저, 숙련 스킬 띠는 그다음
    var i = _jobs.newJobs.indexWhere((n) => !n.startsWith('ms:'));
    if (i < 0) i = 0;
    final first = _jobs.newJobs[i];
    _jobs = _jobs.copyWith(newJobs: [..._jobs.newJobs]..removeAt(i));
    unawaited(store.saveJson(AppController._jobsKey, _jobs.toJson()));
    if (first.startsWith('ms:')) {
      // 'ms:<개수>:<이름>'
      final parts = first.split(':');
      final n = int.tryParse(parts[1]) ?? 1;
      final name = parts.sublist(2).join(':');
      return n > 1
          ? '숙련 스킬을 익혔어요 · $name 외 ${n - 1}개'
          : '숙련 스킬을 익혔어요 · $name';
    }
    if (first.startsWith('done:')) {
      final j = JobRules.parse(first.substring(5));
      return j == null ? null : '견습을 마쳤어요 · 이제 ${JobRules.info(j).name}예요!';
    }
    final j = JobRules.parse(first);
    return j == null ? null : '새 직업을 얻었어요 · ${JobRules.info(j).name}';
  }

  bool get hasJobNotice => _jobs.newJobs.isNotEmpty;

  // ───────────── 고유 기술 세기

  /// 직업 [j] 의 고유 기술 세기 (0 없음 · 보조·견습 ½ · 주 1)
  double jobTrait(JobId j) {
    if (!_jobs.awakened) return 0;
    if (_jobs.main == j.name) {
      return _jobs.apprentice ? JobRules.apprenticeTrait : JobRules.mainTrait;
    }
    if (_jobs.subs.contains(j.name)) {
      final all = _jobs.main == JobId.allCrafter.name ||
          _jobs.subs.contains(JobId.allCrafter.name);
      return all ? JobRules.mainTrait : JobRules.subTrait;
    }
    return 0;
  }

  /// 숙련도가 쌓이는 배율 (주 ×1.5 · 보조 ×1.2)
  double jobGrowth(Mastery m) {
    if (!_jobs.awakened) return 1;
    var g = 1.0;
    final main = mainJob;
    if (main != null && JobRules.info(main).masteries.contains(m)) {
      g = JobRules.mainGrowth;
    }
    for (final s in subJobs) {
      if (JobRules.info(s).masteries.contains(m)) {
        g = math.max(g, JobRules.subGrowth);
      }
    }
    return g;
  }

  /// [chance] 에 직업 세기를 곱해 한 번 굴린다 (0이면 굴리지 않음)
  bool _jobRoll(JobId j, double chance) {
    final t = jobTrait(j);
    return t > 0 && _random.nextDouble() < chance * t;
  }

  // ───────────── 새 MP

  /// 최대 MP = 30 + 지능 × 2
  int get jobMpMax => JobRules.maxMp((combatStats + gear.stats).intellect);

  int get jobMp => math.min(jobMpMax, math.max(0, _jobs.mp ?? jobMpMax));

  Future<void> _setJobMp(int v) =>
      _saveJobs(_jobs.copyWith(mp: v.clamp(0, jobMpMax)));

  /// 여관 휴식·레벨업에 가득
  Future<void> _fillJobMp() async {
    if (!_jobs.awakened || _jobs.mp == null) return;
    await _saveJobs(_jobs.copyWith(clearMp: true));
  }

  /// 걸으면 1,000보마다 최대 MP의 10%
  Future<void> _jobSteps() async {
    if (!_jobs.awakened) return;
    final today = player.today;
    if (today == null) return;
    final day = today.dayKey;
    final counted = _jobs.stepsDay == day ? _jobs.stepsCounted : 0;
    if (passengerMode) {
      if (_jobs.stepsDay != day || counted < today.steps) {
        await _saveJobs(_jobs.copyWith(
            stepsDay: day, stepsCounted: math.max(counted, today.steps)));
      }
      return;
    }
    final units = (today.steps - counted) ~/ JobRules.mpStepUnit;
    if (units <= 0) {
      if (_jobs.stepsDay != day) {
        await _saveJobs(_jobs.copyWith(stepsDay: day, stepsCounted: 0));
      }
      return;
    }
    final gain = (jobMpMax * JobRules.mpPerUnit * units).round();
    await _saveJobs(_jobs.copyWith(
      mp: math.min(jobMpMax, jobMp + gain),
      stepsDay: day,
      stepsCounted: counted + units * JobRules.mpStepUnit,
    ));
  }

  // ───────────── 직업 스킬 (묶음 31 #195·#196: 트리·포인트·단계)

  /// 배운 단계 (0 = 아직). 얻은 직업의 ① 공격 스킬은 적어도 Lv.1
  int skillLevel(JobSkill s) {
    final lv = _jobs.levelOf(s.name);
    if (lv > 0) return lv;
    final j = JobRules.jobOf(s);
    return _jobs.awakened &&
            _jobs.ownedJobs.contains(j) &&
            JobRules.firstOf(j) == s
        ? 1
        : 0;
  }

  /// 받은 스킬 포인트 (Lv.15부터 레벨마다 2점)
  int get skillPointsTotal =>
      _jobs.awakened ? JobRules.pointsFor(player.level.level) : 0;

  /// 쓴 포인트 (각 직업 ①·포인트 없이 받은 스킬의 첫 단계는 빼고)
  int get skillPointsSpent {
    var n = 0;
    _jobs.learned.forEach((k, lv) {
      final s = JobRules.parseSkill(k);
      if (s == null || lv <= 0) return;
      final freeFirst =
          JobRules.firstOf(JobRules.jobOf(s)) == s || _jobs.free.contains(k);
      n += freeFirst ? lv - 1 : lv;
    });
    return n;
  }

  int get skillPointsLeft => math.max(0, skillPointsTotal - skillPointsSpent);

  /// 트리에서 배우거나(0 → 1) 한 단계 올릴 수 있는지
  bool canRaiseSkill(JobSkill s) {
    if (!_jobs.awakened) return false;
    if (!_jobs.ownedJobs.contains(JobRules.jobOf(s))) return false;
    final lv = skillLevel(s);
    if (lv >= JobRules.maxSkillLevel || skillPointsLeft <= 0) return false;
    return lv > 0 || JobRules.canLearn(s, skillLevel);
  }

  /// 포인트 1점으로 배우기·강화
  Future<bool> raiseSkill(JobSkill s) async {
    if (!canRaiseSkill(s)) return false;
    final was = skillLevel(s);
    await _saveJobs(_jobs.copyWith(
        learned: {..._jobs.learned, s.name: was + 1}));
    if (was == 0 && JobRules.skill(s).isBattle) await _fillLoadout('job:${s.name}');
    return true;
  }

  /// 다시 나누기 (언제든 무료): 쓴 포인트를 모두 돌려받는다. 각 직업 ①·받은 스킬은 Lv.1로 남음
  Future<void> resetSkills() async {
    final keep = <String, int>{
      for (final j in _jobs.ownedJobs) JobRules.firstOf(j).name: 1,
      for (final f in _jobs.free) f: 1,
    };
    final pending = [
      for (final p in _jobs.pending)
        if (keep.containsKey(p) || JobRules.parseSkill(p) == null) p,
    ];
    await _saveJobs(_jobs.copyWith(learned: keep, pending: pending));
  }

  /// 지금 쓸 수 있는 스킬 (주·보조 직업에서 배운 것). (스킬, 보조인지)
  List<(JobSkill, bool)> get jobSkills {
    if (!_jobs.awakened) return const [];
    return [
      if (mainJob case final m?)
        for (final s in JobRules.info(m).skills)
          if (skillLevel(s) > 0) (s, false),
      for (final j in subJobs)
        for (final s in JobRules.info(j).skills)
          if (skillLevel(s) > 0) (s, true),
    ];
  }

  /// [places] 에서 쓰는 스킬 (전투 스킬은 전투 칸으로만)
  List<(JobSkill, bool)> skillsAt(Iterable<SkillPlace> places) {
    final set = places.toSet();
    final night = JobRules.isNight(_clock());
    return [
      for (final x in jobSkills)
        if (set.contains(JobRules.skill(x.$1).place) &&
            (JobRules.skill(x.$1).place != SkillPlace.nightMap || night))
          x,
    ];
  }

  bool _isSub(JobSkill s) {
    final mine = jobSkills.where((x) => x.$1 == s).toList();
    return mine.isNotEmpty && mine.every((x) => x.$2);
  }

  /// 이 스킬을 지금 쓰면 드는 MP (보조 1.5배, 생활 스킬은 단계마다 덜, 장인의 직감이면 절반)
  int skillCost(JobSkill s, {bool? sub}) => JobRules.skillCost(s,
      sub: sub ?? _isSub(s),
      level: math.max(1, skillLevel(s)),
      half: s != JobSkill.artisanIntuition &&
          _jobs.hasPending(JobSkill.artisanIntuition));

  /// 공격·전투 스킬 세기 (단계마다 더 세짐)
  double skillPower(JobSkill s) => JobRules.levelPower(math.max(1, skillLevel(s)));

  bool skillPending(JobSkill s) => _jobs.hasPending(s);
  bool skillTimedOn(JobSkill s) => _jobs.timedOn(s, _clock());

  /// 시간 스킬 남은 시간
  Duration? skillLeft(JobSkill s) {
    final u = _jobs.timed[s.name];
    if (u == null) return null;
    final left = u.difference(_clock());
    return left.isNegative ? null : left;
  }

  /// MP를 쓴다 (장인의 직감은 여기서 한 번 쓰고 지운다)
  Future<bool> _paySkill(JobSkill s, bool sub) async {
    final cost = skillCost(s, sub: sub);
    if (jobMp < cost) return false;
    final half = s != JobSkill.artisanIntuition &&
        _jobs.hasPending(JobSkill.artisanIntuition);
    await _saveJobs(_jobs.copyWith(
      mp: jobMp - cost,
      pending: half
          ? [
              for (final p in _jobs.pending)
                if (p != JobSkill.artisanIntuition.name) p,
            ]
          : null,
    ));
    return true;
  }

  /// 스킬을 쓴다 (「이번 ○○」·시간 스킬·바로 일어나는 스킬). 고르기가 필요한
  /// 스킬은 따로 부른다 (응급 수리·룬 새기기·광택 내기·의뢰 협상·간식 주머니·추적)
  Future<SkillUse> useJobSkill(JobSkill s) => _serial(() async {
        final mine = jobSkills.where((x) => x.$1 == s).toList();
        if (mine.isEmpty) return SkillUse.cannot;
        final sub = mine.every((x) => x.$2);
        final info = JobRules.skill(s);
        if (info.mode == SkillMode.battle) return SkillUse.cannot;
        if (info.mode == SkillMode.next && _jobs.hasPending(s)) {
          return SkillUse.already;
        }
        if (info.mode == SkillMode.timed && skillTimedOn(s)) {
          return SkillUse.already;
        }
        // 바로 일어나는 스킬은 쓸 수 있을 때만
        switch (s) {
          case JobSkill.cheer:
            if (!activeExpeditions.any((e) => e.petUid != null && !e.back)) {
              return SkillUse.cannot;
            }
          case JobSkill.lightResonance:
            if (!farewellDone || mp >= mpMax) return SkillUse.cannot;
          case JobSkill.eggWarm:
            if (!_pets.eggs.any((e) => e.incubatedAt != null && !eggReady(e))) {
              return SkillUse.cannot;
            }
          case JobSkill.firstAid:
            if (hp >= maxHp) return SkillUse.cannot;
          case JobSkill.bigPack:
            if (bigPackToday) return SkillUse.already;
          default:
            break;
        }
        if (jobMp < skillCost(s, sub: sub)) return SkillUse.notEnoughMp;
        await _paySkill(s, sub);
        final now = _clock();
        switch (info.mode) {
          case SkillMode.next:
            await _saveJobs(_jobs.copyWith(pending: [..._jobs.pending, s.name]));
          case SkillMode.timed:
            final marks = {..._jobs.marks};
            if (s == JobSkill.blessedSteps) {
              marks['blessedFrom'] = player.today?.steps ?? 0;
              marks['blessedGiven'] = 0;
            }
            if (s == JobSkill.runTogether) {
              marks['runFrom'] = player.today?.steps ?? 0;
              marks['runGiven'] = 0;
            }
            final here = _lastFix?.point ?? fallbackCenter;
            if (here != null) {
              marks['${s.name}Lat'] = (here.lat * 1e6).round();
              marks['${s.name}Lng'] = (here.lng * 1e6).round();
            }
            await _saveJobs(_jobs.copyWith(
              timed: {..._jobs.timed, s.name: now.add(info.duration!)},
              marks: marks,
            ));
            _spotsKey = null;
          case SkillMode.instant:
            await _instantSkill(s);
          case SkillMode.battle:
            break;
        }
        _notify();
        return SkillUse.ok;
      });

  Future<void> _instantSkill(JobSkill s) async {
    final now = _clock();
    switch (s) {
      case JobSkill.cheer:
        // 원정 간 펫의 남은 시간 절반
        _vitals = _vitals.copyWith(expeditions: [
          for (final e in _vitals.expeditions)
            e.petUid != null && !e.back
                ? e.shortened(e.returnAt.difference(now) ~/ 2, now)
                : e,
        ]);
        await store.saveVitals(_vitals);
      case JobSkill.lightResonance:
        final add = (mpMax * JobRules.resonance * skillPower(s)).round();
        _vitals = _vitals.copyWith(mp: math.min(mpMax, mp + add), mpAt: now);
        await store.saveVitals(_vitals);
      case JobSkill.eggWarm:
        // 품은 알 하나의 남은 부화 시간 절반 (광고와 따로)
        var done = false;
        await _savePets(_pets.copyWith(eggs: [
          for (final e in _pets.eggs)
            if (!done && e.incubatedAt != null && !eggReady(e))
              () {
                done = true;
                final left =
                    e.incubatedAt!.add(PetRules.hatchTime).difference(now);
                return e.incubate(e.incubatedAt!.subtract(left ~/ 2));
              }()
            else
              e,
        ]));
      case JobSkill.firstAid:
        final add = (maxHp * JobRules.firstAid).round();
        _vitals =
            _vitals.copyWith(hp: math.min(maxHp, hp + add), lastMaxHp: maxHp);
        await store.saveVitals(_vitals);
      case JobSkill.bigPack:
        await _saveJobs(_jobs.copyWith(marks: {
          ..._jobs.marks,
          'bigPackDay': int.parse(DailyRecord.dayKeyOf(now).replaceAll('-', '')),
        }));
      default:
        break;
    }
  }

  /// 큰 짐 보따리를 오늘 썼는지 (오늘 하루 가방 칸 더)
  bool get bigPackToday =>
      _jobs.marks['bigPackDay'] ==
      int.parse(DailyRecord.dayKeyOf(_clock()).replaceAll('-', ''));

  /// 오늘 늘어난 가방 칸
  int get jobBagSlots => bigPackToday ? JobRules.bigPackSlots : 0;

  /// 전투 스킬: MP만 쓴다 (효과는 전투가 낸다). 쓸 수 없으면 false
  Future<bool> payBattleSkill(JobSkill s) async {
    final mine = jobSkills.where((x) => x.$1 == s).toList();
    if (mine.isEmpty) return false;
    final ok = await _paySkill(s, mine.every((x) => x.$2));
    // 금화 던지기: 금화가 조금 든다 (전투 안에서 날아간 금화)
    if (ok && s == JobSkill.coinToss) {
      final t = await _todayRecord();
      final g = math.min(player.gold, JobRules.coinTossGold.round());
      if (g > 0) {
        await _save(t.copyWith(
            spends: DailyRecord.addCounts(t.spends, {Wallet.gold: g})));
      }
    }
    return ok;
  }

  /// 써 둔 「이번 ○○」 스킬을 한 번 쓴다 (있었으면 true)
  Future<bool> _consumeSkill(JobSkill s) async {
    if (!_jobs.hasPending(s)) return false;
    await _saveJobs(_jobs.copyWith(pending: [
      for (final p in _jobs.pending)
        if (p != s.name) p,
    ]));
    return true;
  }

  /// 고르기가 필요한 스킬: MP를 쓰고 일을 한다
  Future<SkillUse> _paidAction(JobSkill s, Future<bool> Function() act) =>
      _serial(() async {
        final mine = jobSkills.where((x) => x.$1 == s).toList();
        if (mine.isEmpty) return SkillUse.cannot;
        final sub = mine.every((x) => x.$2);
        if (jobMp < skillCost(s, sub: sub)) return SkillUse.notEnoughMp;
        if (!await act()) return SkillUse.cannot;
        await _paySkill(s, sub);
        _notify();
        return SkillUse.ok;
      });

  /// 룬 새기기: 코어 없이 금화 100으로 장비에 원하는 속성 (실패 없음, 이미 있으면 바꿈).
  /// 내 속성 점수는 오르지 않는다
  Future<SkillUse> runeCarve(String uid, Element e) =>
      _paidAction(JobSkill.runeCarve, () async {
        final item = _armory.byUid(uid);
        if (item == null || item.element == e) return false;
        if (player.gold < JobRules.runeCarveGold) return false;
        final t = await _todayRecord();
        await _save(t.copyWith(
            spends: DailyRecord.addCounts(
                t.spends, {Wallet.gold: JobRules.runeCarveGold})));
        await _saveArmory(_armory.replace(
            item.copyWith(element: e, elementLevel: item.elementLevel)));
        return true;
      });

  /// 광택 내기 ①: MP를 쓰고 새 능력치를 굴려 돌려준다 (아직 바꾸지 않음)
  Future<Map<String, int>?> polishRoll(String uid) async {
    Map<String, int>? out;
    final r = await _paidAction(JobSkill.polish, () async {
      final item = _armory.byUid(uid);
      if (item == null ||
          EquipmentRules.info(item.base).slot != EquipSlot.accessory) {
        return false;
      }
      out = EquipmentRules.rollExtras(item.grade, _random);
      return true;
    });
    return r == SkillUse.ok ? out : null;
  }

  /// 광택 내기 ②: 이전 값 / 새 값 중 고른 것을 남긴다
  Future<void> polishKeep(String uid, Map<String, int> extras) async {
    final item = _armory.byUid(uid);
    if (item == null) return;
    await _saveArmory(_armory.replace(item.copyWith(extras: extras)));
  }

  /// 예전 이름 (묶음 30): 바로 바꾼다
  Future<SkillUse> polishAccessory(String uid) async {
    final r = await polishRoll(uid);
    if (r == null) return SkillUse.cannot;
    await polishKeep(uid, r);
    return SkillUse.ok;
  }

  /// 의뢰 협상: 길드 의뢰 하나를 다른 의뢰로
  Future<SkillUse> negotiateErrand(int slot) =>
      _paidAction(JobSkill.negotiate, () => _swapGuildErrand(slot));

  /// 응급 수리: 장비 하나를 수리비 없이 바로
  Future<SkillUse> quickRepair(String uid) =>
      _paidAction(JobSkill.quickRepair, () async {
        final item = _armory.byUid(uid);
        if (item == null || item.durability >= EquipmentRules.maxDurability) {
          return false;
        }
        await _saveArmory(_armory.replace(
            item.copyWith(durability: EquipmentRules.maxDurability)));
        return true;
      });

  /// 간식 주머니: 펫 하나 친밀도 크게
  Future<SkillUse> snackPouch(String uid) =>
      _paidAction(JobSkill.snackPouch, () async {
        final pet = _pets.byUid(uid);
        if (pet == null || pet.bond >= PetRules.maxBond) return false;
        await _savePets(_pets.replace(pet.copyWith(
            bond: math.min(PetRules.maxBond,
                pet.bond + (JobRules.snackBond * skillPower(JobSkill.snackPouch)).round()))));
        return true;
      });

  /// 추적: 도감에서 만난 몬스터 하나가 잠시 뒤 근처에 (30분 동안)
  Future<SkillUse> trackMonster(MonsterId m) =>
      _paidAction(JobSkill.track, () async {
        if (!purifiedEver.contains(m)) return false;
        final here = _lastFix?.point ?? fallbackCenter;
        if (here == null) return false;
        final p = _clearSpotNear(here, near: true);
        final until = _clock().add(const Duration(minutes: 30));
        await _saveJobs(_jobs.copyWith(
          timed: {..._jobs.timed, JobSkill.track.name: until},
          marks: {
            ..._jobs.marks,
            'trackMonster': m.index,
            'trackLat': (p.lat * 1e6).round(),
            'trackLng': (p.lng * 1e6).round(),
          },
        ));
        return true;
      });

  // ───────────── 전투 칸 2개 (#198)

  /// 전투 칸에 끼울 수 있는 것: 'job:<스킬>' (주·보조 직업 전투 스킬) · 'mastery:<숙련도>'
  List<String> get loadoutChoices => [
        for (final (s, _) in jobSkills)
          if (JobRules.skill(s).isBattle) 'job:${s.name}',
        for (final m in Mastery.values)
          if (masteryStage(m).index >= MasteryStage.expert.index)
            'mastery:${m.name}',
      ];

  /// 전투 칸 2개 (아직 고른 적이 없으면 저절로 채운 값)
  List<String> get battleLoadout {
    final ok = loadoutChoices;
    if (_jobs.loadout.isEmpty) return ok.take(2).toList();
    final set = ok.toSet();
    return [
      for (final x in _jobs.loadout)
        if (set.contains(x)) x,
    ].take(2).toList();
  }

  /// 전투 화면의 직업 스킬 칸: (스킬, MP, 단계 세기)
  List<(JobSkill, int, double)> get battleJobSlots => [
        for (final e in battleLoadout)
          if (e.startsWith('job:'))
            if (JobRules.parseSkill(e.substring(4)) case final s?)
              (s, skillCost(s), skillPower(s)),
      ];

  /// 숙련 스킬을 썼을 때: 장사·의뢰(동전 튕기기)는 금화가 조금 든다
  Future<void> payMasterySkill(Mastery m) async {
    if (m != Mastery.trade) return;
    final t = await _todayRecord();
    final g = math.min(player.gold, 5);
    if (g <= 0) return;
    await _save(
        t.copyWith(spends: DailyRecord.addCounts(t.spends, {Wallet.gold: g})));
  }

  /// 스킬 페이지에서 칸 [i] 에 [entry] 를 끼운다 (null 이면 비움)
  Future<void> setLoadout(int i, String? entry) async {
    final cur = [...battleLoadout];
    while (cur.length < 2) {
      cur.add('');
    }
    if (entry != null) {
      final other = cur.indexOf(entry);
      if (other >= 0 && other != i) cur[other] = cur[i];
    }
    cur[i] = entry ?? '';
    await _saveJobs(_jobs.copyWith(loadout: cur));
  }

  /// 새로 얻은 전투 스킬 [entry] 를 빈 칸에 (고른 적이 없으면 저절로 채워짐)
  Future<void> _fillLoadout([String? entry]) async {
    if (entry == null || _jobs.loadout.isEmpty) return;
    final cur = [...battleLoadout];
    if (cur.contains(entry) || cur.length >= 2) return;
    cur.add(entry);
    await _saveJobs(_jobs.copyWith(loadout: cur));
  }

  // ───────────── 스킬 페이지 열기 (#198) · 숙련 스킬 (#197)

  /// 스킬 페이지가 열렸는지 (첫 「숙련된」 또는 Lv.15 각성 중 먼저)
  bool get skillPageOpen => _jobs.pageOpen;

  /// 「새로 열렸어요」 카드·손가락 안내를 보여 줄 때인지
  bool get skillIntroPending =>
      _jobs.pageOpen &&
      !_jobs.pageIntro &&
      !inTutorial &&
      pendingLevelUp == null &&
      !farewellPending &&
      !jobAwakenPending;

  Future<void> markSkillIntro() async {
    if (_jobs.pageIntro) return;
    await _saveJobs(_jobs.copyWith(pageIntro: true));
  }

  /// 지금 가진 숙련 스킬 (패시브는 가장 높은 단계 하나, 숙련된 이상이면 액티브)
  List<MasterySkillInfo> get masterySkillsOwned => [
        for (final m in Mastery.values)
          ...JobRules.masterySkillsAt(m, masteryStage(m)),
      ];

  /// 스킬 페이지가 열리는지 · 숙련 스킬을 새로 익혔는지 살핀다 (단계가 오를 때)
  Future<void> _checkSkillPage({bool quiet = false}) async {
    if (!_masteryReady || !_jobs.v31) return;
    final stages = {for (final m in Mastery.values) m.name: masteryStage(m).index};
    final open = _jobs.pageOpen ||
        _jobs.awakened ||
        stages.values.any((v) => v >= MasteryStage.expert.index);
    final notes = [..._jobs.newJobs];
    final before = {..._jobs.masteryShown};
    var changed = open != _jobs.pageOpen;
    if (open) {
      final fresh = <String>[];
      for (final m in Mastery.values) {
        final was = _jobs.masteryShown[m.name] ?? 0;
        final st = stages[m.name]!;
        for (var i = was + 1; i <= st; i++) {
          fresh.add(JobRules.masterySkill(m, MasteryStage.values[i]).name);
        }
      }
      if (fresh.isNotEmpty) {
        changed = true;
        // 처음 열릴 때·예전 기록은 하나로 모아서
        if (!_jobs.pageOpen || quiet || fresh.length > 1) {
          notes.add('ms:${fresh.length}:${fresh.first}');
        } else {
          notes.add('ms:1:${fresh.first}');
        }
      }
    }
    if (!changed) return;
    await _saveJobs(_jobs.copyWith(
      pageOpen: open,
      masteryShown: open ? stages : _jobs.masteryShown,
      newJobs: notes,
    ));
    if (open && _jobs.loadout.isNotEmpty) {
      for (final m in Mastery.values) {
        final was = MasteryStage.values[
            math.min(MasteryStage.values.length - 1, before[m.name] ?? 0)];
        if (was.index < MasteryStage.expert.index &&
            stages[m.name]! >= MasteryStage.expert.index) {
          await _fillLoadout('mastery:${m.name}');
        }
      }
    }
  }

  /// 묶음 31 처음 열 때: 이미 각성한 계정은 쓰던 스킬을 Lv.1로 그대로(포인트 없이) +
  /// 각 직업 ①. 빠지는 스킬을 써 둔 게 있으면 MP를 돌려준다
  Future<void> _migrateSkills31() async {
    if (_jobs.v31) return;
    var j = _jobs;
    if (j.awakened) {
      final free = <String>{};
      for (final job in [j.mainJob, ...j.subJobs]) {
        if (job == null) continue;
        final old = _oldFirstSkill(job);
        final now = old == null ? null : JobRules.legacySkill(old);
        if (now != null && JobRules.firstOf(job) != now) free.add(now.name);
      }
      var refund = 0;
      final pending = <String>[];
      for (final p in j.pending) {
        if (JobRules.parseSkill(p) == null) {
          refund += 20;
        } else {
          pending.add(p);
        }
      }
      j = j.copyWith(
        learned: {
          for (final job in j.ownedJobs) JobRules.firstOf(job).name: 1,
          for (final f in free) f: 1,
        },
        free: free.toList(),
        pending: pending,
        mp: refund > 0 ? math.min(jobMpMax, (j.mp ?? jobMpMax) + refund) : null,
      );
    }
    _jobs = j.copyWith(v31: true);
    await _saveJobs(_jobs);
    await _checkSkillPage(quiet: true);
  }

  /// 묶음 30 에서 직업마다 쓰던 스킬 이름
  String? _oldFirstSkill(JobId j) => const {
        JobId.blacksmith: 'focusForge',
        JobId.herbalist: 'bountyTouch',
        JobId.alchemist: 'quickBrew',
        JobId.warrior: 'powerStrike',
        JobId.explorer: 'pathFind',
        JobId.appraiser: 'trueEye',
        JobId.tamer: 'cheer',
        JobId.merchant: 'bargain',
        JobId.weaponsmith: 'masterBlade',
        JobId.runesmith: 'runeCarve',
        JobId.jeweler: 'polish',
        JobId.healer: 'healingLight',
        JobId.hunter: 'vitalStrike',
        JobId.archaeologist: 'excavate',
        JobId.pilgrim: 'blessedSteps',
        JobId.peddler: 'wanderingMarket',
        JobId.adventurer: 'negotiate',
        JobId.beastKnight: 'jointAttack',
        JobId.pathfinder: 'longRoad',
        JobId.potionMerchant: 'specialSale',
        JobId.nightWalker: 'moonWalk',
        JobId.gateHeir: 'lightResonance',
        JobId.ashHunter: 'ashPurge',
        JobId.allCrafter: 'artisanIntuition',
      }[j];

  // ───────────── 고유 기술·스킬이 쓰이는 곳 (숨은 규칙)

  /// 지도에 채집 자리를 보여 주는 거리 (채집가)
  double get harvestMapRadius {
    var r = HarvestRules.mapRadiusM *
        (1 + JobRules.herbalistSight * jobTrait(JobId.herbalist));
    if (skillTimedOn(JobSkill.farSight)) r *= 2;
    return r;
  }

  /// 바람 따라 걷기: 쓴 자리 둘레 1.5km 안의 안 가 본 장소 이름이 보인다
  bool placeRevealed(GamePlace place) {
    if (!skillTimedOn(JobSkill.windWalk)) return false;
    final lat = _jobs.marks['windWalkLat'], lng = _jobs.marks['windWalkLng'];
    if (lat == null || lng == null) return false;
    return place.point.distanceTo(GeoPoint(lat / 1e6, lng / 1e6)) <= 1500;
  }

  /// 먼 눈: 몬스터도 더 멀리 (지도에 보이는 거리 배율)
  double get monsterSightFactor => skillTimedOn(JobSkill.farSight) ? 2 : 1;

  /// 전투 피해 배율 (무기 장인·마수 기사·밤의 산책자)
  double get jobPower {
    if (!_jobs.awakened) return 1;
    var p = 1.0;
    final weapon = _armory.wornIn(EquipSlot.weapon);
    if (weapon != null) {
      // 묶음 31: 무기 장인 → 강화한 무기일수록 더 셈
      p *= 1 +
          JobRules.weaponsmithPerLevel *
              weapon.enhance *
              jobTrait(JobId.weaponsmith);
    }
    if (companionPet != null) {
      p *= 1 + JobRules.beastKnightDamage * jobTrait(JobId.beastKnight);
    }
    if (JobRules.isNight(_clock())) {
      p *= 1 + JobRules.nightDamage * jobTrait(JobId.nightWalker);
    }
    return p;
  }

  /// 전투에 직업 효과를 붙인다 (전사·잿빛 사냥꾼·치유사)
  Battle _withJob(Battle b) {
    // 묶음 31 #198: 전투 칸에 낀 숙련 스킬 (스킬 페이지가 열린 뒤)
    if (_jobs.pageOpen) {
      for (final e in battleLoadout) {
        if (e.startsWith('mastery:')) {
          final m = Mastery.values.where((x) => 'mastery:${x.name}' == e);
          b.masteryActives.addAll(m);
        }
      }
    }
    if (!_jobs.awakened) return b;
    b.weaponEnhance = _armory.wornIn(EquipSlot.weapon)?.enhance ?? 0;
    b.artisanSubs = subJobs.length;
    b.nightTime = JobRules.isNight(_clock());
    b.lowHpBoost = JobRules.warriorLowHp * jobTrait(JobId.warrior);
    b.ashBoost = JobRules.ashDamage * jobTrait(JobId.ashHunter);
    b.healBoost = JobRules.healerHeal * jobTrait(JobId.healer);
    return b;
  }

  /// 의뢰 금화 (수완: 이번 의뢰 두 배)
  Future<int> _knackGold(int gold) async {
    if (gold <= 0) return gold;
    return await _consumeSkill(JobSkill.knack) ? gold * 2 : gold;
  }

  /// 판 금화 (행상인·물약 상인·대흥정·특가 판매)
  Future<int> _jobSellGold(int gold, {bool potion = false}) async {
    if (!_jobs.awakened || gold <= 0) return gold;
    var g = gold.toDouble();
    if ((player.today?.steps ?? 0) > JobRules.peddlerSteps) {
      g *= 1 + JobRules.peddlerGold * jobTrait(JobId.peddler);
    }
    if (potion) {
      g *= 1 + JobRules.potionMerchantGold * jobTrait(JobId.potionMerchant);
      if (await _consumeSkill(JobSkill.specialSale)) g *= JobRules.specialSale;
    }
    if (await _consumeSkill(JobSkill.bargain)) g *= 1 + JobRules.bargain;
    return g.round();
  }

  /// 산 값에서 돌려받는 금화 (물약 상인 물약 도매 · 대흥정)
  Future<int> _jobBuyRefund(int price, {bool potion = false}) async {
    if (!_jobs.awakened || price <= 0) return 0;
    var cut = 0.0;
    if (potion) {
      cut += JobRules.potionWholesale * jobTrait(JobId.potionMerchant);
    }
    if (await _consumeSkill(JobSkill.bargain)) {
      cut += JobRules.bargain * skillPower(JobSkill.bargain);
    }
    return (price * math.min(0.6, cut)).round();
  }

  /// 오늘 붙는 네 번째 의뢰 (상인 발 넓은 상인) 표시를 오늘 기록에 남긴다
  Future<void> _jobQuests() async {
    if (!_jobs.awakened || _history.isEmpty) return;
    final today = _history.last;
    if (today.dayKey != DailyRecord.dayKeyOf(_clock())) return;
    final want =
        (JobRules.merchantQuests * jobTrait(JobId.merchant)).round() > 0;
    final has = (today.counters[QuestRules.quest4Key] ?? 0) > 0;
    if (!want || has) return;
    final r = today.copyWith(
        counters: {...today.counters, QuestRules.quest4Key: 1});
    await _save(r.copyWith(questsCompleted: QuestRules.completedCount(r)));
  }

  /// 잡화상 거래 1번 (네 번째 의뢰)
  Future<void> _shopTraded() async {
    final t = await _todayRecord();
    final r = t.copyWith(
        counters: DailyRecord.addCounts(t.counters, {QuestRules.shopTradeKey: 1}));
    await _save(r.copyWith(questsCompleted: QuestRules.completedCount(r)));
  }

  /// 걸음 게이지 보너스 (탐험가 · 축복의 발걸음)
  Future<void> _jobGauge() async {
    if (!_jobs.awakened || _history.isEmpty) return;
    final today = _history.last;
    final day = today.dayKey;
    final given = _jobs.gaugeDay == day ? _jobs.gaugeGiven : 0;
    var add = 0;
    var newGiven = given;
    // 탐험가: 새 장소를 찾은 날(처음 가는 길) 걸음 게이지 조금 더
    final t = jobTrait(JobId.explorer);
    if (t > 0 && today.newPlacesVisited > 0) {
      final target = (today.steps * JobRules.explorerGauge * t).floor();
      if (target > given) {
        add += target - given;
        newGiven = target;
      }
    }
    // 축복의 발걸음: 쓴 뒤 30분 동안 걸은 만큼 반 더
    var marks = _jobs.marks;
    final from = marks['blessedFrom'];
    if (from != null && skillTimedOn(JobSkill.blessedSteps)) {
      final extra = ((today.steps - from) * (JobRules.blessedSteps - 1)).floor();
      final before = marks['blessedGiven'] ?? 0;
      if (extra > before) {
        add += extra - before;
        marks = {...marks, 'blessedGiven': extra};
      }
    }
    if (add <= 0) return;
    await _save(today.copyWith(
        counters: DailyRecord.addCounts(
            today.counters, {'jobGauge': add, 'gaugeBonus': add})));
    await _saveJobs(
        _jobs.copyWith(gaugeDay: day, gaugeGiven: newGiven, marks: marks));
  }

  /// 새 장소를 찾았을 때 (탐험가 보상)
  Future<void> _jobNewPlace() async {
    if (!_jobs.awakened || _history.isEmpty) return;
    final t = jobTrait(JobId.explorer);
    final today = _history.last;
    if (t <= 0) return;
    final exp = (RuleConstants.newPlaceExp * JobRules.explorerPlace * t).round();
    if (exp <= 0) return;
    await _save(today.copyWith(
        gains: DailyRecord.addCounts(today.gains, {Wallet.exp: exp})));
  }

  /// 순례자 순례의 길: 일주일에 여러 번 간 곳에 다시 가면 작은 선물 (장소마다 하루 한 번)
  Future<void> _jobRevisit(String placeId) async {
    if (!_jobs.awakened || _history.isEmpty) return;
    final t = jobTrait(JobId.pilgrim);
    if (t <= 0) return;
    final today = _history.last;
    final from = today.date.subtract(const Duration(days: 6));
    final days = _history
        .where((r) =>
            !r.date.isBefore(DateTime(from.year, from.month, from.day)) &&
            r.visitedPlaceIds.contains(placeId))
        .length;
    if (days < JobRules.pilgrimVisits) return;
    if (t < 1 && _random.nextDouble() >= t) return;
    const finds = [
      MaterialId.herb,
      MaterialId.butterflyDust,
      MaterialId.waterJelly,
      MaterialId.essence,
    ];
    await _save(today.copyWith(
        gains: DailyRecord.addCounts(
            today.gains, {finds[_random.nextInt(finds.length)].name: 1})));
    _jobFind = true;
  }

  /// 방금 순례자가 작은 선물을 찾았는지 (한 번 알려 주고 false)
  bool takeJobFind() {
    final v = _jobFind;
    _jobFind = false;
    return v;
  }
}
