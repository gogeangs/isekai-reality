import '../rules/job_rules.dart';

/// 직업 각성·새 MP·직업 스킬 (묶음 30 #55·#183). 따로 저장한다 ('jobs').
class JobState {
  const JobState({
    this.awakened = false,
    this.owned = const [],
    this.seen = const [],
    this.main,
    this.subs = const [],
    this.apprentice = false,
    this.mp,
    this.stepsDay,
    this.stepsCounted = 0,
    this.pending = const [],
    this.timed = const {},
    this.discountDay,
    this.newJobs = const [],
    this.gaugeDay,
    this.gaugeGiven = 0,
    this.marks = const {},
    this.learned = const {},
    this.free = const [],
    this.loadout = const [],
    this.v31 = false,
    this.pageOpen = false,
    this.pageIntro = false,
    this.masteryShown = const {},
    this.v57 = false,
    this.repick = false,
    this.changes = 0,
    this.pairs = const [],
  });

  // ───────────── 묶음 57 #249 직업 개편

  /// 개편 저장 방식으로 옮겼는지
  final bool v57;

  /// 주·보조를 대가 없이 다시 골라야 하는지 (개편 전 각성 계정, 「직업이 새로 정리됐어요」)
  final bool repick;

  /// 직업을 바꾼 횟수 (첫 번째는 무료)
  final int changes;

  /// 찾은 특별 짝 (id)
  final List<String> pairs;

  // ───────────── 묶음 31 #195~#198

  /// 배운 직업 스킬과 단계 (1~3). ① 공격 스킬은 직업을 얻으면 Lv.1
  final Map<String, int> learned;

  /// 포인트 없이 받은 스킬 (각 직업 ①, 예전 각성 계정이 쓰던 스킬). 다시 나누기에도 남음
  final List<String> free;

  /// 전투 화면 스킬 칸 2개 ('job:<스킬>' · 'mastery:<숙련도>')
  final List<String> loadout;

  /// 묶음 31 저장 방식으로 옮겼는지
  final bool v31;

  /// 스킬 페이지가 열렸는지 (첫 숙련된 또는 Lv.15 각성), 「새로 열렸어요」 안내를 마쳤는지
  final bool pageOpen;
  final bool pageIntro;

  /// 숙련 스킬을 알린 단계 (큰 숙련도 → 단계 번호)
  final Map<String, int> masteryShown;

  int levelOf(String skill) => learned[skill] ?? 0;

  /// 그 밖의 작은 기록 (축복의 발걸음을 쓴 때의 걸음 등)
  final Map<String, int> marks;

  /// Lv.15 직업 고르기를 마쳤는지
  final bool awakened;

  /// 얻은 직업 (얻은 순서)
  final List<String> owned;

  /// 길드 목록에서 본 직업 (처음 보는 직업은 한 번 빛남)
  final List<String> seen;

  final String? main;
  final List<String> subs;

  /// 주 직업이 견습인지 (조건을 채우면 떨어진다)
  final bool apprentice;

  /// 새 MP (null 이면 가득)
  final int? mp;

  /// 걸음으로 MP를 채운 날과 그날 센 걸음
  final String? stepsDay;
  final int stepsCounted;

  /// 써 둔 「이번 ○○」 스킬 (그 일을 할 때 한 번)
  final List<String> pending;

  /// 시간 스킬이 끝나는 때
  final Map<String, DateTime> timed;

  /// 상인 하루 한 번 할인을 쓴 날
  final String? discountDay;

  /// 아직 알리지 않은 새 직업
  final List<String> newJobs;

  /// 걸음 게이지 보너스(탐험가·축복의 발걸음)를 준 날과 준 걸음
  final String? gaugeDay;
  final int gaugeGiven;

  JobId? get mainJob => JobRules.parse(main);
  List<JobId> get subJobs => [
        for (final s in subs)
          if (JobRules.parse(s) case final j?) j,
      ];
  Set<JobId> get ownedJobs => {
        for (final s in owned)
          if (JobRules.parse(s) case final j?) j,
      };

  bool hasPending(JobSkill s) => pending.contains(s.name);

  bool timedOn(JobSkill s, DateTime now) {
    final u = timed[s.name];
    return u != null && now.isBefore(u);
  }

  JobState copyWith({
    bool? awakened,
    List<String>? owned,
    List<String>? seen,
    String? main,
    List<String>? subs,
    bool? apprentice,
    int? mp,
    bool clearMp = false,
    String? stepsDay,
    int? stepsCounted,
    List<String>? pending,
    Map<String, DateTime>? timed,
    String? discountDay,
    List<String>? newJobs,
    String? gaugeDay,
    int? gaugeGiven,
    Map<String, int>? marks,
    Map<String, int>? learned,
    List<String>? free,
    List<String>? loadout,
    bool? v31,
    bool? pageOpen,
    bool? pageIntro,
    Map<String, int>? masteryShown,
    bool? v57,
    bool? repick,
    int? changes,
    List<String>? pairs,
  }) =>
      JobState(
        awakened: awakened ?? this.awakened,
        owned: owned ?? this.owned,
        seen: seen ?? this.seen,
        main: main ?? this.main,
        subs: subs ?? this.subs,
        apprentice: apprentice ?? this.apprentice,
        mp: clearMp ? null : (mp ?? this.mp),
        stepsDay: stepsDay ?? this.stepsDay,
        stepsCounted: stepsCounted ?? this.stepsCounted,
        pending: pending ?? this.pending,
        timed: timed ?? this.timed,
        discountDay: discountDay ?? this.discountDay,
        newJobs: newJobs ?? this.newJobs,
        gaugeDay: gaugeDay ?? this.gaugeDay,
        gaugeGiven: gaugeGiven ?? this.gaugeGiven,
        marks: marks ?? this.marks,
        learned: learned ?? this.learned,
        free: free ?? this.free,
        loadout: loadout ?? this.loadout,
        v31: v31 ?? this.v31,
        pageOpen: pageOpen ?? this.pageOpen,
        pageIntro: pageIntro ?? this.pageIntro,
        masteryShown: masteryShown ?? this.masteryShown,
        v57: v57 ?? this.v57,
        repick: repick ?? this.repick,
        changes: changes ?? this.changes,
        pairs: pairs ?? this.pairs,
      );

  Map<String, dynamic> toJson() => {
        'awakened': awakened,
        'owned': owned,
        'seen': seen,
        if (main != null) 'main': main,
        'subs': subs,
        'apprentice': apprentice,
        if (mp != null) 'mp': mp,
        if (stepsDay != null) 'stepsDay': stepsDay,
        'stepsCounted': stepsCounted,
        'pending': pending,
        'timed': {
          for (final e in timed.entries) e.key: e.value.toIso8601String(),
        },
        if (discountDay != null) 'discountDay': discountDay,
        'newJobs': newJobs,
        if (gaugeDay != null) 'gaugeDay': gaugeDay,
        'gaugeGiven': gaugeGiven,
        'marks': marks,
        'learned': learned,
        'free': free,
        'loadout': loadout,
        'v31': v31,
        'pageOpen': pageOpen,
        'pageIntro': pageIntro,
        'masteryShown': masteryShown,
        'v57': v57,
        if (repick) 'repick': true,
        'changes': changes,
        'pairs': pairs,
      };

  factory JobState.fromJson(Map<String, dynamic> j) {
    List<String> strings(Object? v) =>
        [for (final s in (v as List?) ?? const []) '$s'];
    Map<String, int> ints(Object? v) => {
          for (final e in ((v as Map?) ?? const {}).entries)
            if (e.value is num) '${e.key}': (e.value as num).toInt(),
        };
    final t = (j['timed'] as Map?) ?? const {};
    return JobState(
      awakened: j['awakened'] == true,
      owned: strings(j['owned']),
      seen: strings(j['seen']),
      main: j['main'] as String?,
      subs: strings(j['subs']),
      apprentice: j['apprentice'] == true,
      mp: (j['mp'] as num?)?.toInt(),
      stepsDay: j['stepsDay'] as String?,
      stepsCounted: (j['stepsCounted'] as num?)?.toInt() ?? 0,
      pending: strings(j['pending']),
      timed: {
        for (final e in t.entries)
          if (DateTime.tryParse('${e.value}') case final d?) '${e.key}': d,
      },
      discountDay: j['discountDay'] as String?,
      newJobs: strings(j['newJobs']),
      gaugeDay: j['gaugeDay'] as String?,
      gaugeGiven: (j['gaugeGiven'] as num?)?.toInt() ?? 0,
      marks: ints(j['marks']),
      learned: ints(j['learned']),
      free: strings(j['free']),
      loadout: strings(j['loadout']),
      v31: j['v31'] == true,
      pageOpen: j['pageOpen'] == true,
      pageIntro: j['pageIntro'] == true,
      masteryShown: ints(j['masteryShown']),
      v57: j['v57'] == true,
      repick: j['repick'] == true,
      changes: (j['changes'] as num?)?.toInt() ?? 0,
      pairs: strings(j['pairs']),
    );
  }
}
