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
      (!_jobs.awakened || _jobs.repick) &&
      player.level.level >= JobRules.awakenLevel &&
      !farewellPending &&
      !inTutorial;

  Future<void> _saveJobs(JobState j) async {
    _jobs = j;
    await _saveJson(AppController._jobsKey, j.toJson());
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
    // 묶음 77 #345: 잿빛 사냥꾼 = 2막 잿빛 분신 모두 + 잿빛 몬스터 500마리
    var ashKills = 0;
    for (final d in _history) {
      d.huntCounts.forEach((k, v) {
        if (k.startsWith('ash')) ashKills += v;
      });
    }
    if (ash > 0 &&
        _act2.beaten >= Act2Rules.avatars.length &&
        ashKills >= JobPairRules.ashHunterKills) {
      out.add(JobId.ashHunter);
    }
    final masters = Mastery.values
        .where((m) => masteryStage(m) == MasteryStage.master)
        .length;
    if (masters >= JobPairRules.allCrafterMasters) out.add(JobId.allCrafter);
    // 묶음 57 #249: 탐험형 히든 (게임엔 조건을 보여 주지 않음)
    // 묶음 77 #347: 탐험가 · 순례자는 장소 기능이 생길 때까지 열지 않음 (조건은 남겨 둠)
    var relics = 0, dungeons = 0, errands = 0;
    for (final d in _history) {
      relics += d.counters['relicDug'] ?? 0;
      dungeons += d.dungeonRuns.where((r) => r.cleared).length;
      errands += d.counters['errandDone'] ?? 0; // 조합 의뢰 · 마을 사람 쪽지 모두
    }
    if (relics >= JobPairRules.archaeologistRelics) out.add(JobId.archaeologist);
    if (dungeons >= JobPairRules.adventurerDungeons && errands >= JobPairRules.adventurerQuests) {
      out.add(JobId.adventurer);
    }
    return out;
  }

  /// 길드 「곧 열릴 것 같은 직업」 (#192): 아직 없는 기본·복합 직업 중 가까운 2~3개
  List<JobId> get nearJobs => JobRules.nearJobs(masteryOf, _jobs.ownedJobs);

  /// 지금 조건을 채운 직업
  /// 묶음 85 #416: 돋보기를 끄면 감정 직업은 이미 가진 사람만
  Set<JobId> get unlockedJobs => {
        ...JobPairRules.combat,
        for (final j in JobPairRules.craft)
          if (!JobPairRules.lensHidden(j) || _jobs.ownedJobs.contains(j)) j,
        for (final j in _hiddenJobs)
          if (JobPairRules.hidden.contains(j) && (!JobPairRules.lensHidden(j) || _jobs.ownedJobs.contains(j))) j,
        // 예전 기록에서 열려 있던 히든은 열린 채로
        for (final j in _jobs.ownedJobs)
          if (JobPairRules.hidden.contains(j) && !JobPairRules.placeJobs.contains(j)) j,
      };

  /// 추천 직업 (묶음 57): 가장 높은 큰 숙련도 → 직업. 전투면 무기로, 걷기·탐험이면 다음 숙련도
  JobId get recommendedJob {
    final byValue = [...Mastery.values]..sort((a, b) => masteryOf(b).compareTo(masteryOf(a)));
    return JobPairRules.recommend(
        byValue, MasteryRules.weaponKind(_armory.wornIn(EquipSlot.weapon)?.base));
  }

  /// 묶음 76 #340: 추천 이유 한 문장 (recommendedJob 과 같은 기준)
  String get recommendReason {
    final byValue = [...Mastery.values]..sort((a, b) => masteryOf(b).compareTo(masteryOf(a)));
    final weapon = MasteryRules.weaponKind(_armory.wornIn(EquipSlot.weapon)?.base);
    for (final m in byValue) {
      switch (m) {
        case Mastery.smith:
          return '지금까지 대장일을 가장 많이 했어요';
        case Mastery.harvest:
          return '지금까지 채집을 가장 많이 했어요';
        case Mastery.alchemy:
          return '지금까지 물약을 가장 많이 했어요';
        case Mastery.appraise:
          if (!LensRules.lensOn) continue;
          return '지금까지 감정을 가장 많이 했어요';
        case Mastery.trade:
          return '지금까지 장사와 의뢰를 가장 많이 했어요';
        case Mastery.spirit:
          return '지금까지 정령 · 펫과 가장 많이 함께했어요';
        case Mastery.combat:
          final w = MasteryRules.weaponLabels[weapon];
          return w == null
              ? '지금까지 전투를 가장 많이 했어요'
              : '지금까지 전투를 가장 많이 했고, ${josa(w, '을/를')} 들고 있어요';
        case Mastery.walk:
          continue;
      }
    }
    return '지금까지 전투를 가장 많이 했어요';
  }

  /// 직업 고르기 목록: 추천이 맨 위, 그다음 전투 · 생산 · (열린) 히든
  List<JobId> get jobChoices {
    final open = unlockedJobs;
    final rec = recommendedJob;
    return [
      rec,
      for (final j in JobPairRules.all)
        if (open.contains(j) && j != rec) j,
    ];
  }

  /// 견습은 개편(묶음 57)으로 없어짐
  bool get jobStartsApprentice => false;

  /// 얻은 직업 (얻은 순서, 새것이 맨 위)
  List<JobId> get ownedJobs => [
        for (final s in _jobs.owned.reversed)
          if (JobRules.parse(s) case final j?) j,
      ];

  JobId? get mainJob => _jobs.mainJob;

  /// 묶음 76 #307: 주인공 그림 직업 이름 ('warrior' …, 직업 각성 전이면 null)
  String? get heroJobArt => JobRules.heroArtJob(mainJob)?.name;
  List<JobId> get subJobs => _jobs.subJobs;
  bool get jobApprentice => _jobs.apprentice;
  /// 묶음 57: 보조는 한 칸
  /// 묶음 77 #357: Lv.20부터 (그 전엔 보조 · 이명 · 각인이라는 말도 보이지 않음)
  int get subJobSlots => player.level.level >= JobPairRules.subJobLevel ? 1 : 0;
  bool get subJobsOpen => subJobSlots > 0;

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
        final again = _jobs.awakened && _jobs.repick;
        if (_jobs.awakened && !again) return false;
        final open = unlockedJobs;
        if (!open.contains(main)) return false;
        final owned = <String>[
          for (final j in JobPairRules.all)
            if (open.contains(j)) j.name,
        ];
        final s = [
          for (final x in subs)
            if (x != main && open.contains(x)) x.name,
        ].take(1).toList();
        final today = player.today;
        await _saveJobs(_jobs.copyWith(
          awakened: true,
          owned: owned,
          main: main.name,
          subs: s,
          apprentice: false,
          repick: false,
          clearMp: !again,
          stepsDay: again ? null : today?.dayKey,
          stepsCounted: again ? null : today?.steps ?? 0,
        ));
        await _checkPair();
        await _checkSkillPage();
        await _npcUse(Npc.sera);
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
    await _npcUse(Npc.sera);
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
      for (final j in JobPairRules.all)
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

  /// 방금 꺼낸 직업 소식의 문장 그림 (묶음 35, 숙련 스킬 띠면 null)
  String? get jobNoticeArt => _jobNoticeArt;

  /// 위쪽 띠로 알릴 새 직업 소식 (한 번 꺼내면 지운다)
  String? takeJobNotice() {
    _jobNoticeArt = null;
    if (_jobs.newJobs.isEmpty) return null;
    // 직업 소식 먼저, 숙련 스킬 띠는 그다음
    var i = _jobs.newJobs.indexWhere((n) => !n.startsWith('ms:'));
    if (i < 0) i = 0;
    final first = _jobs.newJobs[i];
    _jobs = _jobs.copyWith(newJobs: [..._jobs.newJobs]..removeAt(i));
    unawaited(_saveJson(AppController._jobsKey, _jobs.toJson()));
    if (first.startsWith('ms:')) {
      // 'ms:<개수>:<이름>'
      final parts = first.split(':');
      final n = int.tryParse(parts[1]) ?? 1;
      final name = parts.sublist(2).join(':');
      return n > 1
          ? '숙련 스킬을 익혔어요 · $name 외 ${n - 1}개'
          : '숙련 스킬을 익혔어요 · $name';
    }
    if (first == 'deep') {
      final s = subJobs.isEmpty ? null : subJobs.first;
      _jobNoticeArt = s == null ? null : 'assets/images/job_${s.name}.webp';
      return '보조 각인 2단계 — 이명이 더 깊어졌어요';
    }
    if (first.startsWith('pair:')) {
      final p = JobPairRules.specialById(first.substring(5));
      _jobNoticeArt = p == null ? null : 'assets/images/${TitleRules.asset(TitleRules.pairTitles.firstWhere((t) => t.name.toLowerCase() == 'pair${p.id.toLowerCase()}'))}.webp';
      return p == null ? null : '숨은 이명을 찾았어요 · ${p.name}';
    }
    if (first.startsWith('done:')) {
      final j = JobRules.parse(first.substring(5));
      _jobNoticeArt = j == null ? null : 'assets/images/job_${j.name}.webp';
      return j == null ? null : '견습을 마쳤어요 · 이제 ${JobRules.info(j).name}예요!';
    }
    final j = JobRules.parse(first);
    _jobNoticeArt = j == null ? null : 'assets/images/job_${j.name}.webp';
    return j == null ? null : '새 직업을 얻었어요 · ${JobRules.info(j).name}';
  }

  bool get hasJobNotice => _jobs.newJobs.isNotEmpty;

  // ───────────── 고유 기술 세기

  /// 직업 [j] 의 고유 기술 세기 (0 없음 · 보조·견습 ½ · 주 1)
  double jobTrait(JobId j) {
    if (!_jobs.awakened) return 0;
    // 묶음 57: 숨은 특별 짝이면 옛 직업 고유 기술이 주 직업처럼
    final sp = activePair;
    if (sp != null && sp.legacy == j) return JobRules.mainTrait;
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
  int get jobMpMax => (JobRules.maxMp((combatStats + gear.stats).intellect) *
          (1 + JobPairRules.mageMp * jobTrait(JobId.mage)))
      .round();

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
    final gain = (jobMpMax *
            JobRules.mpPerUnit *
            (1 + JobPairRules.mageMpFill * jobTrait(JobId.mage)) *
            units)
        .round();
    await _saveJobs(_jobs.copyWith(
      mp: math.min(jobMpMax, jobMp + gain),
      stepsDay: day,
      stepsCounted: counted + units * JobRules.mpStepUnit,
    ));
  }

  // ───────────── 직업 스킬 (묶음 31 #195·#196: 트리·포인트·단계)

  /// 배운 단계 (0 = 아직). 얻은 직업의 ① 공격 스킬은 적어도 Lv.1 · 산 스킬북도 적어도 Lv.1
  int skillLevel(JobSkill s) {
    final lv = _jobs.levelOf(s.name);
    if (lv > 0) return lv;
    if (JobRules.isCommon(s)) return _jobs.books.contains(s.name) ? 1 : 0;
    if (activePair?.skill == s) return 1; // 묶음 57: 특별 짝 스킬 (포인트 밖)
    final j = JobRules.jobOf(s);
    return _jobs.awakened &&
            _jobs.ownedJobs.contains(j) &&
            JobRules.info(j).skills.isNotEmpty &&
            JobRules.firstOf(j) == s
        ? 1
        : 0;
  }

  /// 묶음 86 #431: 한 주머니 — Lv.15부터 레벨마다 3점. 주 · 보조 · 직업 숙련 · 공용 스킬에 나눠 씀
  int get skillPointsTotal =>
      _jobs.awakened ? JobRules.pointsFor(player.level.level) : 0;

  /// 배운 단계 중 포인트로 올린 몫 (각 직업 ① · 받은 스킬 · 산 스킬북의 첫 단계는 빼고)
  int _paidOf(String k, int lv) {
    final s = JobRules.parseSkill(k);
    if (s == null || lv <= 0) return 0;
    final freeFirst = _jobs.free.contains(k) ||
        (JobRules.isCommon(s) ? _jobs.books.contains(k) : JobRules.firstOf(JobRules.jobOf(s)) == s);
    return freeFirst ? lv - 1 : lv;
  }

  /// [job] 에 쓴 포인트 (스킬 + 직업 숙련)
  int skillPointsSpentOn(JobId job) {
    var n = 0;
    _jobs.learned.forEach((k, lv) {
      final s = JobRules.parseSkill(k);
      if (s == null || JobRules.isCommon(s) || JobRules.jobOf(s) != job) return;
      n += _paidOf(k, lv);
    });
    return n + _jobs.drillOf(job);
  }

  /// 공용 스킬에 쓴 포인트
  int get skillPointsSpentCommon {
    var n = 0;
    _jobs.learned.forEach((k, lv) {
      final s = JobRules.parseSkill(k);
      if (s != null && JobRules.isCommon(s)) n += _paidOf(k, lv);
    });
    return n;
  }

  /// 주머니에서 쓴 포인트 모두
  int get skillPointsSpentAll {
    var n = 0;
    _jobs.learned.forEach((k, lv) => n += _paidOf(k, lv));
    _jobs.drill.forEach((_, v) => n += v);
    return n;
  }

  /// 남은 포인트 (한 주머니)
  int get skillPointsLeft => math.max(0, skillPointsTotal - skillPointsSpentAll);

  /// 예전 이름 — 이제 직업과 상관없이 같은 주머니
  int skillPointsLeftOn(JobId job) => skillPointsLeft;
  int get skillPointsSpent => skillPointsSpentAll;

  /// 배우거나(0 → 1) 한 단계 올릴 수 있는지 (트리 없이 원하는 순서대로)
  bool canRaiseSkill(JobSkill s) {
    if (!_jobs.awakened) return false;
    if (JobRules.isCommon(s)) {
      if (!_jobs.books.contains(s.name)) return false;
    } else {
      final job = JobRules.jobOf(s);
      if (!_jobs.ownedJobs.contains(job)) return false;
      if (job != mainJob && !subJobs.contains(job)) return false;
    }
    final lv = skillLevel(s);
    return lv < JobRules.maxSkillLevel &&
        JobRules.levelOpen(lv + 1, player.level.level) &&
        skillPointsLeft > 0;
  }

  /// 묶음 85 #414: 다음 단계가 레벨로 잠겨 있으면 열리는 레벨 (아니면 null)
  int? skillLockedAt(JobSkill s) {
    final lv = skillLevel(s);
    if (lv >= JobRules.maxSkillLevel) return null;
    return JobRules.levelOpen(lv + 1, player.level.level) ? null : JobRules.levelOpensAt(lv + 1);
  }

  /// 묶음 85 #414: 직업 숙련 (넣은 포인트 · 스킬 세기 배율)
  int jobDrill(JobId j) => _jobs.drillOf(j);
  double jobDrillPower(JobId j) => 1 + JobRules.drillPer * jobDrill(j);

  /// 묶음 86 #423: 그 직업 스킬을 내 레벨에서 열린 가장 높은 단계까지 모두 올렸는지 (직업 숙련이 열림)
  bool jobSkillsMaxed(JobId j) {
    final skills = JobRules.info(j).skills;
    final top = JobRules.openMaxLevel(player.level.level);
    return skills.isNotEmpty && skills.every((s) => skillLevel(s) >= top);
  }

  bool canRaiseDrill(JobId j) =>
      _jobs.awakened &&
      _jobs.ownedJobs.contains(j) &&
      (j == mainJob || subJobs.contains(j)) &&
      jobSkillsMaxed(j) &&
      jobDrill(j) < JobRules.drillMax &&
      skillPointsLeft > 0;

  Future<bool> raiseDrill(JobId j) async {
    if (!canRaiseDrill(j)) return false;
    await _saveJobs(_jobs.copyWith(drill: {..._jobs.drill, j.name: jobDrill(j) + 1}));
    return true;
  }

  /// 묶음 86 #423: 새 단계가 열렸는데 직업 숙련에 점수가 있으면 한 줄 (Lv.25 · 35). 알림 뒤 null
  String? takeDrillNotice() {
    final lv = player.level.level;
    final top = JobRules.openMaxLevel(lv);
    if (top <= 3 || _jobs.drill.values.every((v) => v <= 0)) return null;
    final key = 'drillOpen$top';
    if ((_jobs.marks[key] ?? 0) > 0) return null;
    _jobs = _jobs.copyWith(marks: {..._jobs.marks, key: 1});
    unawaited(_saveJobs(_jobs));
    return '$top단계가 열렸어요 · 다시 나누기로 옮길 수 있어요';
  }

  /// 묶음 85 #414: 빨간 점 — 스킬을 아직 올릴 수 있을 때만 (직업 숙련 줄은 점을 띄우지 않음)
  bool skillRaisableOn(JobId j) =>
      _jobs.awakened && JobRules.info(j).skills.any(canRaiseSkill);

  /// 묶음 86 #431: 주머니에 남은 포인트가 있고 올릴 곳(직업 · 공용 스킬)이 있을 때
  bool get skillRaisable =>
      [if (mainJob != null) mainJob!, ...subJobs].any(skillRaisableOn) || commonSkills.any(canRaiseSkill);

  /// 포인트 1점으로 배우기·강화
  Future<bool> raiseSkill(JobSkill s) async {
    if (!canRaiseSkill(s)) return false;
    final was = skillLevel(s);
    await _saveJobs(_jobs.copyWith(
        learned: {..._jobs.learned, s.name: was + 1}));
    if (was == 0 && JobRules.skill(s).isBattle) await _fillLoadout('job:${s.name}');
    await _npcUse(Npc.sera);
    return true;
  }

  /// 처음 상태 (각 직업 ① · 받은 스킬 · 산 스킬북 Lv.1)
  Map<String, int> get _baseLearned => {
        for (final j in _jobs.ownedJobs)
          if (JobRules.info(j).skills.isNotEmpty) JobRules.firstOf(j).name: 1,
        for (final f in _jobs.free) f: 1,
        for (final b in _jobs.books) b: 1,
      };

  /// 다시 나누기 (언제든 무료): 모든 직업 · 직업 숙련 · 공용 스킬에 쓴 포인트를 한꺼번에 돌려받는다
  Future<void> resetSkills() async {
    final keep = _baseLearned;
    final pending = [
      for (final p in _jobs.pending)
        if (keep.containsKey(p) || JobRules.parseSkill(p) == null) p,
    ];
    await _saveJobs(_jobs.copyWith(learned: keep, pending: pending, drill: const {}));
  }

  /// 묶음 86 #431: 예전 계정(직업마다 따로 받던 포인트)이 주머니보다 많이 썼으면 모두 돌려받은 상태로
  Future<void> _fitSkillPool() async {
    if (!_jobs.awakened || skillPointsSpentAll <= skillPointsTotal) return;
    await resetSkills();
  }

  // ───────────── 묶음 86 #425: 조합 스킬북 (공용 스킬)

  /// 산 스킬북의 공용 스킬
  List<JobSkill> get commonSkills => [
        for (final (s, _) in JobRules.books)
          if (_jobs.books.contains(s.name)) s,
      ];

  bool hasBook(JobSkill s) => _jobs.books.contains(s.name);

  /// 스킬북 사기 (Lv.15 각성 뒤 · 한 권 한 번만). 금화가 모자라면 false
  Future<bool> buyBook(JobSkill s) => _serial(() async {
        if (!_jobs.awakened || !JobRules.isCommon(s) || hasBook(s)) return false;
        final price = JobRules.bookPrice(s);
        if (player.gold < price) return false;
        final t = await _todayRecord();
        await _save(t.copyWith(spends: DailyRecord.addCounts(t.spends, {Wallet.gold: price})));
        await _saveJobs(_jobs.copyWith(
          books: [..._jobs.books, s.name],
          learned: {..._jobs.learned, s.name: math.max(1, _jobs.levelOf(s.name))},
        ));
        if (JobRules.skill(s).isBattle) await _fillLoadout('job:${s.name}');
        _notify();
        return true;
      });

  /// 공용 생활 스킬 단계 (안 샀으면 0)
  int commonLevel(JobSkill s) => hasBook(s) ? skillLevel(s) : 0;

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
      if (activePair?.skill case final s?) (s, false),
      for (final s in commonSkills) (s, false),
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
  /// 묶음 75 #325: 스킬 숙련도 — 장인이면 MP −10% (스킬 포인트 단계와 곱해서)
  int skillCost(JobSkill s, {bool? sub}) {
    final base = JobRules.skillCost(s,
        sub: sub ?? _isSub(s),
        level: math.max(1, skillLevel(s)),
        half: s != JobSkill.artisanIntuition &&
            _jobs.hasPending(JobSkill.artisanIntuition));
    final f = skillFrac(s.name);
    if (f <= 0 || base <= 0) return base;
    return math.max(1, (base * (1 - MasteryRules.skillMpMax * f)).round());
  }

  /// 공격·전투 스킬 세기 (단계마다 더 세짐). 묶음 75 #325: 장인이면 +10%
  /// 묶음 85 #414: 직업 숙련 1점마다 +1%
  double skillPower(JobSkill s) =>
      JobRules.levelPower(math.max(1, skillLevel(s))) *
      (1 + MasteryRules.skillPowerMax * skillFrac(s.name)) *
      (JobRules.isCommon(s) ? 1.0 : jobDrillPower(JobRules.jobOf(s)));

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
    await _npcTally(NpcTally.jobSkill); // 묶음 42: 세라 부탁
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
          case JobSkill.sproutCare:
            if (sproutToday) return SkillUse.already;
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
            if (s == JobSkill.farSight) {
              _farSightSeen = {for (final x in todaySpawns) x.id};
            }
            await _saveJobs(_jobs.copyWith(
              timed: {..._jobs.timed, s.name: now.add(info.duration!)},
              marks: marks,
            ));
            _spotsKey = null;
          case SkillMode.instant:
            await _instantSkill(s);
          case SkillMode.battle:
          case SkillMode.passive:
            break;
        }
        await _skillUsedOnce(s); // 묶음 75 #325
        _notify();
        return SkillUse.ok;
      });

  Future<void> _instantSkill(JobSkill s) async {
    final now = _clock();
    switch (s) {
      case JobSkill.sproutCare:
        await _saveJobs(_jobs.copyWith(marks: {..._jobs.marks, 'sproutDay': sproutDayNum}));
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

  /// 묶음 57 새싹 돌보기: 오늘 약초밭이 덜 걸어도 자람
  int get sproutDayNum {
    final t = _clock();
    return t.year * 10000 + t.month * 100 + t.day;
  }

  bool get sproutToday => _jobs.marks['sproutDay'] == sproutDayNum;

  /// 큰 짐 보따리를 오늘 썼는지 (오늘 하루 가방 칸 더)
  bool get bigPackToday =>
      _jobs.marks['bigPackDay'] ==
      int.parse(DailyRecord.dayKeyOf(_clock()).replaceAll('-', ''));

  /// 오늘 늘어난 가방 칸
  int get jobBagSlots => bigPackToday ? JobRules.bigPackSlots : 0;

  /// 묶음 72 #305: 어제 큰 짐 보따리로 늘었던 칸이 오늘 끝났는지 (가방이 칸보다 많을 때 까닭)
  bool get bigPackEnded {
    final y = _clock().subtract(const Duration(days: 1));
    return !bigPackToday &&
        _jobs.marks['bigPackDay'] == int.parse(DailyRecord.dayKeyOf(y).replaceAll('-', ''));
  }

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
        await _skillUsedOnce(s); // 묶음 75 #325
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
    if (fourSlots) {
      // 묶음 85 #420: 칸 자리를 지킴 (빈 칸 '') · 강타 · 방어 태세도 넣을 수 있음
      set.addAll(const [baseBash, baseStance]);
      return [for (var i = 0; i < 2; i++) i < _jobs.loadout.length && set.contains(_jobs.loadout[i]) ? _jobs.loadout[i] : ''];
    }
    return [
      for (final x in _jobs.loadout)
        if (set.contains(x)) x,
    ].take(2).toList();
  }

  // ───────────── 묶음 85 #420: 각성 뒤 칸 4개 (칸 1 · 2 + 강타 · 방어 태세 자리였던 칸 3 · 4) + 펫

  static const String baseBash = 'base:bash';
  static const String baseStance = 'base:stance';

  /// 각성 뒤에만 칸 4개
  bool get fourSlots => _jobs.awakened;

  /// 칸 3 · 4 ('' = 비어 있음)
  List<String> get battleExtra {
    if (!fourSlots) return const [];
    if (_jobs.extra.isEmpty) return const [baseBash, baseStance];
    final ok = {...loadoutChoices, baseBash, baseStance};
    return [for (var i = 0; i < 2; i++) i < _jobs.extra.length && ok.contains(_jobs.extra[i]) ? _jobs.extra[i] : ''];
  }

  /// 칸 1~4 (각성 뒤 · 빈 칸은 '')
  List<String> get battleSlots {
    final a = battleLoadout;
    return [a.isNotEmpty ? a[0] : '', a.length > 1 ? a[1] : '', ...battleExtra];
  }

  /// 전투 화면 버튼 줄 (각성 뒤): 칸 3 · 칸 4 (예전 강타 · 방어 태세 자리) · 칸 1 · 칸 2. 각성 전 null
  List<String>? get battleBar {
    if (!fourSlots) return null;
    final s = battleSlots;
    return [s[2], s[3], s[0], s[1]];
  }

  /// 전투 화면(실시간)의 직업 스킬 — 각성 뒤엔 칸 4개 모두
  List<(JobSkill, int, double)> get battleBarJobSlots => [
        for (final e in fourSlots ? battleSlots : battleLoadout)
          if (e.startsWith('job:'))
            if (JobRules.parseSkill(e.substring(4)) case final s?)
              (s, skillCost(s), skillPower(s) * jobStatRatio(s)),
      ];

  /// 전투 화면의 직업 스킬 칸: (스킬, MP, 단계 세기)
  List<(JobSkill, int, double)> get battleJobSlots => [
        for (final e in battleLoadout)
          if (e.startsWith('job:'))
            if (JobRules.parseSkill(e.substring(4)) case final s?)
              (s, skillCost(s), skillPower(s) * jobStatRatio(s)),
      ];

  /// 묶음 76 #341: 이 스킬 직업의 주 스탯 바탕 / 힘 바탕 (장비 · 버프 스탯 더한 값).
  /// 보조 직업 스킬은 보조 직업의 주 스탯 — 스킬이 속한 직업으로 정해진다
  double jobStatRatio(JobSkill s) => JobRules.statRatio(
      // 묶음 77 #341: 숨은 이명 전용 스킬은 주 직업의 주 스탯
      JobRules.mainStat(
          (activePair?.skill == s || JobRules.isCommon(s)) && mainJob != null ? mainJob! : JobRules.jobOf(s)),
      level: player.level.level,
      stats: combatStats + gear.stats);

  /// 지금 주 직업의 주 스탯 (없으면 null)
  StatKind? get mainJobStat => mainJob == null ? null : JobRules.mainStat(mainJob!);
  StatKind? get subJobStat => subJob == null ? null : JobRules.mainStat(subJob!);

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
    if (fourSlots) {
      // 묶음 85 #420: 칸 4개 — 같은 스킬은 두 칸에 못 넣음 (이미 있으면 서로 바꿈)
      final all = [...battleSlots];
      if (entry != null) {
        final other = all.indexOf(entry);
        if (other >= 0 && other != i) all[other] = all[i];
      }
      all[i] = entry ?? '';
      await _saveJobs(_jobs.copyWith(loadout: all.sublist(0, 2), extra: all.sublist(2, 4)));
      return;
    }
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
    if (fourSlots) {
      final all = [...battleSlots];
      final at = all.indexOf('');
      if (all.contains(entry) || at < 0) return;
      all[at] = entry;
      await _saveJobs(_jobs.copyWith(loadout: all.sublist(0, 2), extra: all.sublist(2, 4)));
      return;
    }
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
      _tourHold.contains('skill') ||
      _jobs.pageOpen &&
      !_jobs.pageIntro &&
      !inTutorial &&
      pendingLevelUp == null &&
      !farewellPending &&
      !jobAwakenPending;

  Future<void> markSkillIntro() async {
    endTour('skill');
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
    return r;
  }

  /// 바람 따라 걷기: 쓴 자리 둘레 1.5km 안의 안 가 본 장소 이름이 보인다
  bool placeRevealed(GamePlace place) {
    if (!skillTimedOn(JobSkill.windWalk)) return false;
    final lat = _jobs.marks['windWalkLat'], lng = _jobs.marks['windWalkLng'];
    if (lat == null || lng == null) return false;
    return place.point.distanceTo(GeoPoint(lat / 1e6, lng / 1e6)) <= 1500;
  }

  /// 수식어(희귀) 몬스터가 붙는 몫 (행운)
  double get modLuckBonus => StatRules.modifierBonus(combatStats);

  /// 먼 눈을 쓰는 동안 더 붙는 희귀 몫 (묶음 31 확인 답: 새로 나타나는 몬스터에만)
  double get farSightBonus => skillTimedOn(JobSkill.farSight)
      ? JobRules.farSightRare * skillPower(JobSkill.farSight)
      : 0;

  /// 먼 눈: 쓸 때 이미 있던 몬스터는 그대로, 그 뒤 새로 나타나는 몬스터만 희귀가 더 자주
  List<FieldSpawn> _withFarSight(List<FieldSpawn> list) {
    final bonus = farSightBonus;
    if (bonus <= 0) {
      _farSightSeen = null;
      return list;
    }
    final seen = _farSightSeen ??= {for (final s in list) s.id};
    final lv = player.level.level;
    return [
      for (final s in list)
        seen.contains(s.id) || s.id == guideSpawn?.id
            ? s
            : FieldSpawn(
                id: s.id,
                monster: s.monster,
                point: s.point,
                modifiers: ModifierRules.roll(s.id, s.monster, lv,
                    bonus: modLuckBonus + bonus)),
    ];
  }

  /// 먼 눈: 이 몬스터를 지도에 눈에 띄게 (희귀·전설 수식어)
  bool spotsSpecial(FieldSpawn s) =>
      (skillTimedOn(JobSkill.farSight) && s.grade.index >= ModGrade.rare.index) ||
      // 묶음 57 마력 감지: 속성을 띤 몬스터
      (skillTimedOn(JobSkill.manaSense) && Monsters.info(s.monster).element != null);

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
    // 묶음 45 #232: 세라의 방패 문장 → 보스 큰 공격 막기가 조금 쉬워짐
    if (hasRelic(Npc.sera)) b.guardEase = NpcSmallRules.crestGuard;
    // 묶음 86 #425: 공용 스킬 단계 · 튼튼한 몸 (최대 HP)
    for (final c in commonSkills) {
      b.commonLevels[c] = skillLevel(c);
    }
    // 묶음 31 #198: 전투 칸에 낀 숙련 스킬 (스킬 페이지가 열린 뒤)
    if (_jobs.pageOpen) {
      for (final e in fourSlots ? battleSlots : battleLoadout) {
        if (e.startsWith('mastery:')) {
          final m = Mastery.values.where((x) => 'mastery:${x.name}' == e);
          b.masteryActives.addAll(m);
        }
      }
    }
    // 묶음 57 #244: 이그니스(드래곤)와 함께면 시작할 때 불 한 번
    if (_heroWith(PetSpecies.dragon)) b.openingFire = PetRules.dragonOpening;
    // 묶음 58: 3막 이름 있는 장비 (숨김) — 모모의 화관 · 아르벨의 단검 · 루시의 빛꽃 · 왕의 망토
    bool worn(EquipBase x) => _armory.items.any((i) => i.base == x && _armory.isWorn(i));
    if (worn(EquipBase.uniqMomoWreath)) {
      b.regenChance = RegionRules.momoWreathRegen;
      b.regenRatio = RegionRules.momoWreathRatio;
    }
    if (worn(EquipBase.uniqArbelDagger)) b.boundBoost = RegionRules.arbelBound;
    if (worn(EquipBase.uniqLucyFlower)) b.allyRegenChance = RegionRules.lucyFlowerAllyRegen;
    if (worn(EquipBase.uniqKingCloak)) b.potionShare = RegionRules.kingCloakPotion;
    // 묶음 59 「등불 수호단」 6개: 가끔 등불 빛 (숨김)
    b.lanternBurst = gear.sets.lanternBurst;
    b.lanternBurstMult = GuildRules.set6BurstMult;
    if (!_jobs.awakened) return b;
    // 묶음 82 #392: 자동 마시기 MP 기준 (직업 MP는 앱이 가짐)
    b
      ..autoMp = _alc.autoMp
      ..jobMpMax = jobMpMax
      ..jobMpNow = (() => jobMp)
      ..onJobMp = ((g) => unawaited(_setJobMp(math.min(jobMpMax, jobMp + g))))
      ..onAutoMpChanged = ((v) => unawaited(setAutoUse(mpPercent: v)));
    b.weaponEnhance = _armory.wornIn(EquipSlot.weapon)?.enhance ?? 0;
    b.artisanSubs = subJobs.length;
    b.nightTime = JobRules.isNight(_clock());
    b.lowHpBoost = JobRules.warriorLowHp * jobTrait(JobId.warrior);
    b.ashBoost = JobRules.ashDamage * jobTrait(JobId.ashHunter);
    b.healBoost = JobRules.healerHeal * math.max(jobTrait(JobId.healer), jobTrait(JobId.priest));
    _withJob57(b);
    return b;
  }

  /// 묶음 57 #249: 새 전투 직업 고유 기술 · 보조 각인 · 특별 짝 · 잘 맞는 무기 (숨은 규칙)
  void _withJob57(Battle b) {
    final w = jobTrait(JobId.warrior);
    if (w > 0) {
      b.bashBoost = JobPairRules.warriorBash * w;
      b.bashFast = w >= 1;
    }
    b.extraEvade += JobPairRules.rogueDodge * jobTrait(JobId.rogue);
    final k = jobTrait(JobId.knight);
    if (k > 0) {
      b.takenMult *= 1 - JobPairRules.knightGuard * k;
      b.guardEase *= 1 + JobPairRules.knightBlock * k;
    }
    if (preferredWeaponOn) b.dealMult *= 1 + JobPairRules.preferredWeapon;
    // 보조 각인 (전투 주일 때 싸움에 붙음)
    double im(JobId j) => imprintOf(j, combat: true);
    if (im(JobId.warrior) > 0) b.lowHpBoost += 0.10 * im(JobId.warrior);
    if (im(JobId.archer) > 0) b.firstStrike = true;
    if (im(JobId.mage) > 0 && b.attackElement == null) b.dealMult *= 1 + 0.05 * im(JobId.mage);
    if (im(JobId.priest) > 0) b.lifeSteal = 0.05 * im(JobId.priest);
    if (im(JobId.rogue) > 0) {
      b.doubleHit = 0.12 * im(JobId.rogue);
      if (_random.nextDouble() < 0.25 * im(JobId.rogue)) b.extraLoot = true;
    }
    if (im(JobId.knight) > 0) {
      b.takenMult *= 1 - 0.06 * im(JobId.knight);
      b.guardEase *= 1 + 0.10 * im(JobId.knight);
    }
    if (im(JobId.blacksmith) > 0) b.dealMult *= 1 + 0.01 * b.weaponEnhance * im(JobId.blacksmith);
    if (im(JobId.alchemist) > 0) {
      b.skillDot = true;
      b.healBoost += 0.10 * im(JobId.alchemist);
    }
    if (im(JobId.herbalist) > 0) b.bindChance = 0.06 * im(JobId.herbalist);
    if (im(JobId.appraiser) > 0) b.weakBoost = 0.15 * im(JobId.appraiser);
    if (im(JobId.merchant) > 0) b.goldBonus = true;
    if (im(JobId.tamer) > 0) b.petAssist = 0.20 * im(JobId.tamer);
    if (im(JobId.nightWalker) > 0 && b.nightTime) b.dealMult *= 1 + 0.08 * im(JobId.nightWalker);
    if (im(JobId.gateHeir) > 0) b.ashBoost += 0.08 * im(JobId.gateHeir);
    if (im(JobId.ashHunter) > 0) b.ashBoost += 0.10 * im(JobId.ashHunter);
    if (im(JobId.archaeologist) > 0) b.relicBlock = 0.15 * im(JobId.archaeologist);
    if (im(JobId.allCrafter) > 0) b.dealMult *= 1 + 0.04 * im(JobId.allCrafter);
    if (im(JobId.explorer) > 0 && (huntTotals[b.foe.monster] ?? 0) == 0) {
      b.dealMult *= 1 + 0.10 * im(JobId.explorer);
    }
    if (im(JobId.adventurer) > 0 && b.foe.isBoss) b.dealMult *= 1 + 0.06 * im(JobId.adventurer);
    // 숨은 특별 짝 (새로 생긴 셋)
    switch (activePair?.id) {
      case 'paladin':
        b.paladin = true;
      case 'nightThief':
        b.nightThief = true;
        if (b.nightTime) b.extraLoot = true;
      case 'ranger':
        b.firstStrike = true;
      case 'spellblade':
        b.spellblade = true;
      case 'sage':
        b.sage = true;
        b.weakBoost += Battle.sageWeak;
      default:
        break;
    }
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
    // 묶음 86 #425: 공용 스킬 「흥정」 → 잡화상 값 조금 싸게 (산 값 일부를 돌려받음)
    final hg = commonLevel(JobSkill.bookHaggle);
    if (hg > 0) cut += JobRules.haggleCut(hg);
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

  /// 방금 순례자가 작은 선물을 찾았는지 (한 번 알려 주고 false)
  bool takeJobFind() {
    final v = _jobFind;
    _jobFind = false;
    return v;
  }
}
