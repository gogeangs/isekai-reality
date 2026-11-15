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
  });

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
      };

  factory JobState.fromJson(Map<String, dynamic> j) {
    List<String> strings(Object? v) =>
        [for (final s in (v as List?) ?? const []) '$s'];
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
      marks: {
        for (final e in ((j['marks'] as Map?) ?? const {}).entries)
          if (e.value is num) '${e.key}': (e.value as num).toInt(),
      },
    );
  }
}
