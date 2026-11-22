/// 건물 레벨업 기록 (묶음 54). 따로 저장한다 ('buildings'). 예전 기록엔 없으니 없으면 모두 ★1.
class BuildingState {
  const BuildingState({
    this.stars = const {},
    this.fixing = const {},
    this.reveal = const [],
    this.innBoostUntil,
    this.trainExtraDay,
  });

  /// 건물 이름 → 다 고친 단계 (없으면 ★1)
  final Map<String, int> stars;

  /// 고치는 중인 건물 → 다 고쳐지는 때
  final Map<String, DateTime> fixing;

  /// 다 고쳤지만 마을에서 레벨업 연출을 아직 안 본 건물
  final List<String> reveal;

  /// 여관 ★3 (묶음 81 #373): 가득 찬 뒤 일어나 HP · 기력 최대가 조금 늘어난 때까지
  final DateTime? innBoostUntil;

  /// 훈련장 ★2: 하루 훈련을 한 번 더 한 날 ('yyyy-mm-dd')
  final String? trainExtraDay;

  int starOf(String name) => stars[name] ?? 1;

  BuildingState copyWith({
    Map<String, int>? stars,
    Map<String, DateTime>? fixing,
    List<String>? reveal,
    DateTime? innBoostUntil,
    String? trainExtraDay,
  }) =>
      BuildingState(
        stars: stars ?? this.stars,
        fixing: fixing ?? this.fixing,
        reveal: reveal ?? this.reveal,
        innBoostUntil: innBoostUntil ?? this.innBoostUntil,
        trainExtraDay: trainExtraDay ?? this.trainExtraDay,
      );

  Map<String, dynamic> toJson() => {
        'v': 1,
        if (stars.isNotEmpty) 'stars': stars,
        if (fixing.isNotEmpty)
          'fixing': {for (final e in fixing.entries) e.key: e.value.toIso8601String()},
        if (reveal.isNotEmpty) 'reveal': reveal,
        if (innBoostUntil != null) 'innBoostUntil': innBoostUntil!.toIso8601String(),
        if (trainExtraDay != null) 'trainExtraDay': trainExtraDay,
      };

  static BuildingState fromJson(Map<String, dynamic> j) => BuildingState(
        stars: {
          for (final e in ((j['stars'] as Map?) ?? const {}).entries)
            if (e.value is num) '${e.key}': (e.value as num).toInt().clamp(1, 3),
        },
        fixing: {
          for (final e in ((j['fixing'] as Map?) ?? const {}).entries)
            if (e.value is String && DateTime.tryParse(e.value as String) != null)
              '${e.key}': DateTime.parse(e.value as String),
        },
        reveal: [
          for (final x in (j['reveal'] as List?) ?? const [])
            if (x is String) x,
        ],
        innBoostUntil: j['innBoostUntil'] is String
            ? DateTime.tryParse(j['innBoostUntil'] as String)
            : null,
        trainExtraDay: j['trainExtraDay'] as String?,
      );
}
