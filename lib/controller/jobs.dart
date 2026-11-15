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

  /// 숨은 직업 조건
  Set<JobId> get _hiddenJobs {
    final out = <JobId>{};
    var night = 0;
    var ash = 0;
    for (final d in _history) {
      night += d.stepsAfter8pm;
      ash += d.counters['ashClone'] ?? 0;
    }
    if (night >= JobRules.nightWalkerSteps) out.add(JobId.nightWalker);
    final days = spiritMemory?.days ?? (farewellDone ? 0 : awakenedDays);
    if (days >= JobRules.gateHeirDays) out.add(JobId.gateHeir);
    if (ash > 0) out.add(JobId.ashHunter);
    final masters = Mastery.values
        .where((m) => masteryStage(m) == MasteryStage.master)
        .length;
    if (masters >= 4) out.add(JobId.allCrafter);
    return out;
  }

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
    final first = _jobs.newJobs.first;
    _jobs = _jobs.copyWith(newJobs: _jobs.newJobs.sublist(1));
    unawaited(store.saveJson(AppController._jobsKey, _jobs.toJson()));
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

  // ───────────── 직업 스킬

  /// 지금 쓸 수 있는 스킬 (주 직업 · 보조 직업의 첫 스킬). (스킬, 보조인지)
  List<(JobSkill, bool)> get jobSkills {
    if (!_jobs.awakened) return const [];
    return [
      if (mainJob case final m?)
        for (final s in JobRules.info(m).openSkills) (s, false),
      for (final j in subJobs)
        for (final s in JobRules.info(j).openSkills) (s, true),
    ];
  }

  /// [places] 에서 쓰는 스킬
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

  /// 이 스킬을 지금 쓰면 드는 MP (보조 1.5배, 장인의 직감이면 절반)
  int skillCost(JobSkill s, {bool sub = false}) => JobRules.skillCost(s,
      sub: sub,
      half: s != JobSkill.artisanIntuition &&
          _jobs.hasPending(JobSkill.artisanIntuition));

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
  /// 스킬(룬 새기기·광택 내기·의뢰 협상)은 따로 부른다.
  Future<SkillUse> useJobSkill(JobSkill s) => _serial(() async {
        final mine = jobSkills.where((x) => x.$1 == s).toList();
        if (mine.isEmpty) return SkillUse.cannot;
        final sub = mine.every((x) => x.$2);
        final info = JobRules.skill(s);
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
            if (s == JobSkill.moonWalk) {
              final here = _lastFix?.point ?? fallbackCenter;
              if (here != null) {
                marks['moonLat'] = (here.lat * 1e6).round();
                marks['moonLng'] = (here.lng * 1e6).round();
              }
            }
            await _saveJobs(_jobs.copyWith(
              timed: {..._jobs.timed, s.name: now.add(info.duration!)},
              marks: marks,
            ));
            if (s == JobSkill.pathFind) _spotsKey = null;
          case SkillMode.instant:
            await _instantSkill(s);
          case SkillMode.battle:
            break;
        }
        _notify();
        return SkillUse.ok;
      });

  Future<void> _instantSkill(JobSkill s) async {
    switch (s) {
      case JobSkill.cheer:
        // 원정 간 펫의 남은 시간 절반
        final now = _clock();
        _vitals = _vitals.copyWith(expeditions: [
          for (final e in _vitals.expeditions)
            e.petUid != null && !e.back
                ? e.shortened(e.returnAt.difference(now) ~/ 2, now)
                : e,
        ]);
        await store.saveVitals(_vitals);
      case JobSkill.lightResonance:
        final add = (mpMax * JobRules.resonance).round();
        _vitals = _vitals.copyWith(
            mp: math.min(mpMax, mp + add), mpAt: _clock());
        await store.saveVitals(_vitals);
      default:
        break;
    }
  }

  /// 전투 스킬: MP만 쓴다 (효과는 전투가 낸다). 쓸 수 없으면 false
  Future<bool> payBattleSkill(JobSkill s) async {
    final mine = jobSkills.where((x) => x.$1 == s).toList();
    if (mine.isEmpty) return false;
    return _paySkill(s, mine.every((x) => x.$2));
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

  /// 룬 새기기: 장비 하나에 원하는 속성 (실패 없음, 코어·금화 없이)
  Future<SkillUse> runeCarve(String uid, Element e) =>
      _paidAction(JobSkill.runeCarve, () async {
        final item = _armory.byUid(uid);
        if (item == null || item.element == e) return false;
        await _saveArmory(_armory.replace(
            item.copyWith(element: e, elementLevel: item.elementLevel)));
        return true;
      });

  /// 광택 내기: 장신구 하나의 능력치를 다시 굴림
  Future<SkillUse> polishAccessory(String uid) =>
      _paidAction(JobSkill.polish, () async {
        final item = _armory.byUid(uid);
        if (item == null ||
            EquipmentRules.info(item.base).slot != EquipSlot.accessory) {
          return false;
        }
        await _saveArmory(_armory.replace(item.copyWith(
            extras: EquipmentRules.rollExtras(item.grade, _random))));
        return true;
      });

  /// 의뢰 협상: 길드 의뢰 하나를 다른 의뢰로
  Future<SkillUse> negotiateErrand(int slot) =>
      _paidAction(JobSkill.negotiate, () => _swapGuildErrand(slot));

  /// 떠돌이 장터: MP만 쓰고 화면이 파는 창을 연다
  Future<SkillUse> openWanderingMarket() =>
      _paidAction(JobSkill.wanderingMarket, () async => true);

  // ───────────── 고유 기술·스킬이 쓰이는 곳 (숨은 규칙)

  /// 지도에 채집 자리를 보여 주는 거리 (약초꾼·길 찾기)
  double get harvestMapRadius {
    var r = HarvestRules.mapRadiusM *
        (1 + JobRules.herbalistSight * jobTrait(JobId.herbalist));
    if (skillTimedOn(JobSkill.pathFind)) r *= 2;
    return r;
  }

  /// 전투 피해 배율 (무기 장인·마수 기사·밤의 산책자)
  double get jobPower {
    if (!_jobs.awakened) return 1;
    var p = 1.0;
    if (_armory.wornIn(EquipSlot.weapon) != null) {
      p *= 1 + JobRules.weaponsmithDamage * jobTrait(JobId.weaponsmith);
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
    if (!_jobs.awakened) return b;
    b.lowHpBoost = JobRules.warriorLowHp * jobTrait(JobId.warrior);
    b.ashBoost = JobRules.ashDamage * jobTrait(JobId.ashHunter);
    b.healBoost = JobRules.healerHeal * jobTrait(JobId.healer);
    return b;
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

  /// 산 값에서 돌려받는 금화 (상인 하루 한 번 · 대흥정)
  Future<int> _jobBuyRefund(int price) async {
    if (!_jobs.awakened || price <= 0) return 0;
    var cut = 0.0;
    final day = DailyRecord.dayKeyOf(_clock());
    final t = jobTrait(JobId.merchant);
    if (t > 0 && _jobs.discountDay != day) {
      cut += JobRules.merchantDiscount * t;
      await _saveJobs(_jobs.copyWith(discountDay: day));
    }
    if (await _consumeSkill(JobSkill.bargain)) cut += JobRules.bargain;
    return (price * math.min(0.6, cut)).round();
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

  /// 새 장소를 찾았을 때 (탐험가 보상 · 순례자 숨은 물건)
  Future<void> _jobNewPlace() async {
    if (!_jobs.awakened || _history.isEmpty) return;
    final t = jobTrait(JobId.explorer);
    final today = _history.last;
    final add = <String, int>{};
    if (t > 0) {
      final exp = (RuleConstants.newPlaceExp * JobRules.explorerPlace * t).round();
      if (exp > 0) add[Wallet.exp] = exp;
    }
    if (_jobRoll(JobId.pilgrim, JobRules.pilgrimFind)) {
      const finds = [
        MaterialId.herb,
        MaterialId.butterflyDust,
        MaterialId.waterJelly,
        MaterialId.essence,
      ];
      add[finds[_random.nextInt(finds.length)].name] = 1;
      _jobFind = true;
    }
    if (add.isEmpty) return;
    await _save(today.copyWith(
        gains: DailyRecord.addCounts(today.gains, add)));
  }

  /// 방금 순례자가 숨은 물건을 찾았는지 (한 번 알려 주고 false)
  bool takeJobFind() {
    final v = _jobFind;
    _jobFind = false;
    return v;
  }
}
