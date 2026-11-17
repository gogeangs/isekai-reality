/// 건물 레벨업 기록 (묶음 54). 따로 저장한다 ('buildings'). 예전 기록엔 없으니 없으면 모두 ★1.
class BuildingState {
  const BuildingState({
    this.stars = const {},
    this.fixing = const {},
    this.reveal = const [],
    this.innExpUntil,
    this.trainExtraDay,
  });

  /// 건물 이름 → 다 고친 단계 (없으면 ★1)
  final Map<String, int> stars;

  /// 고치는 중인 건물 → 다 고쳐지는 때
  final Map<String, DateTime> fixing;

  /// 다 고쳤지만 마을에서 레벨업 연출을 아직 안 본 건물
  final List<String> reveal;

  /// 여관 ★3: 쉬고 일어난 뒤 경험치를 조금 더 받는 때까지
  final DateTime? innExpUntil;

  /// 훈련장 ★2: 하루 훈련을 한 번 더 한 날 ('yyyy-mm-dd')
  final String? trainExtraDay;

  int starOf(String name) => stars[name] ?? 1;

  BuildingState copyWith({
    Map<String, int>? stars,
    Map<String, DateTime>? fixing,
    List<String>? reveal,
    DateTime? innExpUntil,
    String? trainExtraDay,
  }) =>
      BuildingState(
        stars: stars ?? this.stars,
        fixing: fixing ?? this.fixing,
        reveal: reveal ?? this.reveal,
        innExpUntil: innExpUntil ?? this.innExpUntil,
        trainExtraDay: trainExtraDay ?? this.trainExtraDay,
      );

  Map<String, dynamic> toJson() => {
        'v': 1,
        if (stars.isNotEmpty) 'stars': stars,
        if (fixing.isNotEmpty)
          'fixing': {for (final e in fixing.entries) e.key: e.value.toIso8601String()},
        if (reveal.isNotEmpty) 'reveal': reveal,
        if (innExpUntil != null) 'innExpUntil': innExpUntil!.toIso8601String(),
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
        innExpUntil: j['innExpUntil'] is String
            ? DateTime.tryParse(j['innExpUntil'] as String)
            : null,
        trainExtraDay: j['trainExtraDay'] as String?,
      );
}
