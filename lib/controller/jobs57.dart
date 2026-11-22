part of '../app_controller.dart';

/// 직업 바꾸기 결과
enum JobChange { ok, noToken, noGold, same, cannot }

/// 바꾸기 전 미리보기
class JobPreview {
  const JobPreview(this.name, this.imprint, {this.special = false, this.free = false});

  /// 짝 이름 (특별 짝이면 「???」)
  final String name;
  final String? imprint;

  /// 특별 짝 (반짝임만)
  final bool special;

  /// 이번 바꾸기가 무료인지 (첫 번째)
  final bool free;
}

/// 묶음 57 #249: 직업 개편 — 주 1 + 보조 1, 짝 이름 · 보조 각인 · 숨은 특별 짝, 전직의 증표
extension Job57Ops on AppController {
  /// 지금 짝이 숨은 특별 짝이면
  SpecialPair? get activePair =>
      _jobs.awakened ? JobPairRules.specialOf(mainJob, subJobs.isEmpty ? null : subJobs.first) : null;

  JobId? get subJob => subJobs.isEmpty ? null : subJobs.first;

  /// 짝 이름 (프로필 칭호 자리에도)
  String? get pairName {
    final m = mainJob;
    if (m == null || !_jobs.awakened) return null;
    return JobPairRules.pairName(m, subJob);
  }

  /// 보조 각인 한 줄 (보조가 없으면 null)
  String? get imprintLine {
    final m = mainJob, s = subJob;
    if (m == null || s == null) return null;
    return JobPairRules.imprintLine(m, s);
  }

  /// 보조 각인 세기: 보조가 [sub] 이고 주가 [combat] 쪽이면 (Lv.20 2단계에 더 셈). 아니면 0
  double imprintOf(JobId sub, {required bool combat}) {
    final m = mainJob;
    if (m == null || subJob != sub) return 0;
    if (JobPairRules.combatMain(m) != combat) return 0;
    return JobPairRules.imprintPower(player.level.level);
  }

  /// Lv.20 보조 각인 2단계
  bool get imprintDeep => player.level.level >= JobPairRules.imprintDeepLevel;

  /// 찾은 특별 짝
  List<SpecialPair> get foundPairs => [
        for (final id in _jobs.pairs)
          if (JobPairRules.specialById(id) case final p?) p,
      ];

  // ───────────── 전직의 증표

  static int _dayNum(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  /// 걸음으로 받은 증표 (개편 뒤 주마다 5만 보마다 1장)
  int get _tokensEarned {
    final from = _jobs.marks['tokenFrom'];
    if (from == null) return 0;
    final weeks = <DateTime, int>{};
    for (final d in _history) {
      if (_dayNum(d.date) < from) continue;
      final w = TownRules.weekStart(d.date);
      weeks[w] = (weeks[w] ?? 0) + d.steps;
    }
    return weeks.values.fold(0, (t, s) => t + s ~/ JobPairRules.tokenSteps);
  }

  int get jobTokens => math.max(
      0, _tokensEarned + (_jobs.marks['tokensBought'] ?? 0) - (_jobs.marks['tokensUsed'] ?? 0));

  int get _weekNum => _dayNum(TownRules.weekStart(_clock()));

  /// 조합 상점: 이번 주에 샀는지
  bool get jobTokenBoughtThisWeek => _jobs.marks['tokenShopWeek'] == _weekNum;

  /// 조합 상점에서 증표 한 장 (주에 1장, 금화)
  Future<bool> buyJobToken() => _serial(() async {
        if (!_jobs.awakened || jobTokenBoughtThisWeek) return false;
        if (player.gold < JobPairRules.tokenShopGold) return false;
        final today = await _todayRecord();
        await _save(today.copyWith(
            spends: DailyRecord.addCounts(today.spends, {Wallet.gold: JobPairRules.tokenShopGold})));
        await _saveJobs(_jobs.copyWith(marks: {
          ..._jobs.marks,
          'tokensBought': (_jobs.marks['tokensBought'] ?? 0) + 1,
          'tokenShopWeek': _weekNum,
        }));
        return true;
      });

  // ───────────── 바꾸기

  bool get jobChangeFree => _jobs.changes == 0;

  /// 바꾸기 전 미리보기 (특별 짝이면 「???」와 반짝임만, 이미 찾은 짝은 이름)
  JobPreview jobPreview(JobId main, JobId? sub) {
    final sp = JobPairRules.specialOf(main, sub);
    final known = sp != null && _jobs.pairs.contains(sp.id);
    return JobPreview(
      sp != null && !known ? '???' : JobPairRules.pairName(main, sub),
      sub == null ? null : (sp != null && !known ? null : JobPairRules.imprintLine(main, sub)),
      special: sp != null,
      free: jobChangeFree,
    );
  }

  /// 주 · 보조를 바꾼다 (첫 번째는 무료, 그 뒤엔 증표 1 + 금화 100). 직업마다 키운 것은 그대로
  Future<JobChange> changeJobs(JobId main, JobId? sub) => _serial(() async {
        if (!_jobs.awakened || _jobs.repick) return JobChange.cannot;
        final open = unlockedJobs;
        if (!open.contains(main) || (sub != null && (!open.contains(sub) || sub == main))) {
          return JobChange.cannot;
        }
        if (main == mainJob && sub == subJob) return JobChange.same;
        final free = jobChangeFree;
        if (!free) {
          if (jobTokens < 1) return JobChange.noToken;
          if (player.gold < JobPairRules.changeGold) return JobChange.noGold;
          final today = await _todayRecord();
          await _save(today.copyWith(
              spends: DailyRecord.addCounts(today.spends, {Wallet.gold: JobPairRules.changeGold})));
        }
        final owned = {..._jobs.owned, main.name, if (sub != null) sub.name};
        // 전투 칸: 이제 못 쓰는 스킬은 빼고 다시 채움
        await _saveJobs(_jobs.copyWith(
          main: main.name,
          subs: [if (sub != null) sub.name],
          owned: [for (final j in JobPairRules.all) if (owned.contains(j.name)) j.name],
          changes: _jobs.changes + 1,
          loadout: const [],
          marks: free
              ? null
              : {..._jobs.marks, 'tokensUsed': (_jobs.marks['tokensUsed'] ?? 0) + 1},
        ));
        await _fillLoadout();
        await _checkPair();
        await _npcUse(Npc.sera);
        return JobChange.ok;
      });

  /// 처음 맞춘 특별 짝: 「새 짝을 찾았어요」 + 칭호
  Future<void> _checkPair() async {
    final sp = activePair;
    if (sp == null || _jobs.pairs.contains(sp.id)) return;
    await _saveJobs(_jobs.copyWith(
      pairs: [..._jobs.pairs, sp.id],
      newJobs: [..._jobs.newJobs, 'pair:${sp.id}'],
    ));
    final t = TitleRules.pairTitles.firstWhere((x) => x.name.toLowerCase() == 'pair${sp.id.toLowerCase()}');
    final today = await _todayRecord();
    await _save(today.copyWith(
        counters: DailyRecord.addCounts(today.counters, {TitleRules.skyCounter(t): 1})));
  }

  /// 세라의 특별 짝 힌트 (조합 ★2, 하루 한 줄). 다 찾았으면 null
  String? get seraPairHint {
    // 묶음 77 #357 · #347: Lv.20(보조 직업)부터 · 장소 관련 이명은 빼고
    if (!guildDetailHint || !_jobs.awakened || !subJobsOpen) return null;
    final left = [for (final p in JobPairRules.visibleSpecials) if (!_jobs.pairs.contains(p.id)) p];
    if (left.isEmpty) return null;
    final day = _dayNum(_clock());
    return JobPairRules.hintOf(left[day % left.length]);
  }

  /// 묶음 57 처음 열 때: 이미 각성한 계정은 직업을 비우고 주·보조를 대가 없이 다시 고름.
  /// 쓴 스킬 포인트는 모두 돌려줌. 히든은 옛 숨은 · 탐험형 직업으로 열었던 것만 열린 채로
  Future<void> _migrateJobs57() async {
    if (_jobs.v57) return;
    final from = _dayNum(_clock());
    if (!_jobs.awakened) {
      _jobs = _jobs.copyWith(v57: true, marks: {..._jobs.marks, 'tokenFrom': from});
      await _saveJson(AppController._jobsKey, _jobs.toJson());
      return;
    }
    final keep = <JobId>{
      for (final j in _jobs.ownedJobs)
        if (JobPairRules.legacyHiddenFrom[j] case final h?) h,
    };
    final owned = [
      for (final j in JobPairRules.all)
        if (JobPairRules.combat.contains(j) || JobPairRules.craft.contains(j) || keep.contains(j)) j.name,
    ];
    _jobs = JobState(
      awakened: true,
      v57: true,
      repick: true,
      owned: owned,
      seen: _jobs.seen,
      mp: _jobs.mp,
      stepsDay: _jobs.stepsDay,
      stepsCounted: _jobs.stepsCounted,
      timed: _jobs.timed,
      marks: {..._jobs.marks, 'tokenFrom': from},
      pageOpen: _jobs.pageOpen,
      pageIntro: _jobs.pageIntro,
      masteryShown: _jobs.masteryShown,
      v31: true,
    );
    await _saveJson(AppController._jobsKey, _jobs.toJson());
  }

  /// 「직업이 새로 정리됐어요」 다시 고르기인지
  bool get jobRepick => _jobs.repick;

  /// 잘 맞는 무기를 들었는지 (숨은 보너스)
  bool get preferredWeaponOn {
    final m = mainJob;
    if (m == null) return false;
    final k = MasteryRules.weaponKind(_armory.wornIn(EquipSlot.weapon)?.base);
    return k != null && JobPairRules.preferredWeapons(m).contains(k);
  }
}
