/// 마법 돋보기 감정 기록 (11-11 #60). 따로 저장한다 ('lens'). 사진은 저장하지 않는다.
class LensState {
  const LensState({
    this.seen = const [],
    this.counts = const {},
    this.day,
    this.rewardedToday = 0,
  });

  /// 한 번이라도 감정된 종족 (도감 「종족」)
  final List<String> seen;

  /// 종족별 감정된 횟수
  final Map<String, int> counts;

  /// [rewardedToday] 를 센 날 ('yyyy-mm-dd')
  final String? day;

  /// 오늘 보상을 받은 감정 횟수
  final int rewardedToday;

  LensState copyWith({
    List<String>? seen,
    Map<String, int>? counts,
    String? day,
    int? rewardedToday,
  }) =>
      LensState(
        seen: seen ?? this.seen,
        counts: counts ?? this.counts,
        day: day ?? this.day,
        rewardedToday: rewardedToday ?? this.rewardedToday,
      );

  Map<String, dynamic> toJson() => {
        'seen': seen,
        'counts': counts,
        'day': day,
        'rewardedToday': rewardedToday,
      };

  factory LensState.fromJson(Map<String, dynamic> j) => LensState(
        seen: [for (final s in (j['seen'] as List?) ?? const []) s as String],
        counts: {
          for (final e in ((j['counts'] as Map?) ?? const {}).entries)
            e.key as String: (e.value as num).toInt(),
        },
        day: j['day'] as String?,
        rewardedToday: (j['rewardedToday'] as num?)?.toInt() ?? 0,
      );
}
