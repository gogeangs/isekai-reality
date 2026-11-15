/// 숨은 숙련도 저장본 (묶음 27 #176, 저장 키 'mastery').
///
/// 큰 숙련도(걷기·탐험 빼고, 걷기는 기록에서 바로 센다)와 세부 숙련도를 행동 횟수로 센다.
/// 줄어들지 않는다.
class MasteryState {
  const MasteryState({
    this.big = const {},
    this.detail = const {},
    this.announced = const {},
    this.masters = const [],
    this.pending = const [],
    this.top,
    this.leanAt,
    this.quietTitles = const [],
    this.smithFloor,
  });

  /// 대장간 좋은 등급 보너스 바닥값(%p). 예전 「만든 장비 10개마다 +1%p」로 센 값을
  /// 처음 한 번 저장해 두고, 장비 종류 숙련도 보너스와 비교해 큰 쪽을 쓴다 (11-15 결정)
  final double? smithFloor;

  /// 큰 숙련도 이름 → 쌓인 값
  final Map<String, double> big;

  /// 세부 숙련도 열쇠('weapon:sword', 'monster:slime', 'smith:head' …) → 쌓인 값
  final Map<String, double> detail;

  /// 큰 숙련도마다 알려 준 단계 (대사는 한 번만)
  final Map<String, int> announced;

  /// 장인이 됐다고 알려 준 세부 숙련도
  final List<String> masters;

  /// 아직 말하지 않은 대사 (먼저 들어온 것부터)
  final List<String> pending;

  /// 지난번에 알려 준 가장 높은 큰 숙련도
  final String? top;

  /// 마지막으로 성향 대사를 한 때
  final DateTime? leanAt;

  /// 축하 창 없이 위쪽 띠로만 알릴 칭호 (예전 기록 시작 값으로 얻은 것)
  final List<String> quietTitles;

  double bigOf(String name) => big[name] ?? 0;
  double detailOf(String key) => detail[key] ?? 0;

  MasteryState copyWith({
    Map<String, double>? big,
    Map<String, double>? detail,
    Map<String, int>? announced,
    List<String>? masters,
    List<String>? pending,
    String? top,
    DateTime? leanAt,
    List<String>? quietTitles,
    double? smithFloor,
  }) =>
      MasteryState(
        big: big ?? this.big,
        detail: detail ?? this.detail,
        announced: announced ?? this.announced,
        masters: masters ?? this.masters,
        pending: pending ?? this.pending,
        top: top ?? this.top,
        leanAt: leanAt ?? this.leanAt,
        quietTitles: quietTitles ?? this.quietTitles,
        smithFloor: smithFloor ?? this.smithFloor,
      );

  Map<String, dynamic> toJson() => {
        'big': big,
        'detail': detail,
        'announced': announced,
        'masters': masters,
        'pending': pending,
        if (top != null) 'top': top,
        if (leanAt != null) 'leanAt': leanAt!.toIso8601String(),
        'quietTitles': quietTitles,
        if (smithFloor != null) 'smithFloor': smithFloor,
      };

  static Map<String, double> _nums(Object? j) => {
        for (final e in ((j as Map?) ?? const {}).entries)
          if (e.value is num) '${e.key}': (e.value as num).toDouble(),
      };

  factory MasteryState.fromJson(Map<String, dynamic> j) => MasteryState(
        big: _nums(j['big']),
        detail: _nums(j['detail']),
        announced: {
          for (final e in ((j['announced'] as Map?) ?? const {}).entries)
            if (e.value is num) '${e.key}': (e.value as num).toInt(),
        },
        masters: [for (final x in (j['masters'] as List?) ?? const []) '$x'],
        pending: [for (final x in (j['pending'] as List?) ?? const []) '$x'],
        top: j['top'] as String?,
        leanAt: j['leanAt'] == null
            ? null
            : DateTime.tryParse(j['leanAt'] as String),
        quietTitles: [
          for (final x in (j['quietTitles'] as List?) ?? const []) '$x'
        ],
        smithFloor: (j['smithFloor'] as num?)?.toDouble(),
      );
}
