import '../rules/harvest_rules.dart';

/// 채집 (11-11 #56). 따로 저장한다 ('harvest').
class HarvestState {
  const HarvestState({
    this.tools = const {},
    this.granted = false,
    this.spots = const {},
    this.total = 0,
  });

  /// 도구 이름 → 내구도
  final Map<String, int> tools;

  /// 처음 채집할 때 기본 도구 4개를 받았는지
  final bool granted;

  /// 자리 id → 남은 횟수
  final Map<String, SpotCharge> spots;

  /// 지금까지 채집한 횟수
  final int total;

  int durability(HarvestTool t) => tools[t.name] ?? 0;

  bool hasTool(HarvestTool t) => tools.containsKey(t.name);

  int chargesOf(String spotId, DateTime now) =>
      spots[spotId]?.current(now) ?? HarvestRules.maxCharges;

  HarvestState copyWith({
    Map<String, int>? tools,
    bool? granted,
    Map<String, SpotCharge>? spots,
    int? total,
  }) =>
      HarvestState(
        tools: tools ?? this.tools,
        granted: granted ?? this.granted,
        spots: spots ?? this.spots,
        total: total ?? this.total,
      );

  /// 가득 찬 자리는 지운다 (저장 크기를 줄인다)
  HarvestState pruned(DateTime now) => copyWith(spots: {
        for (final e in spots.entries)
          if (e.value.current(now) < HarvestRules.maxCharges) e.key: e.value,
      });

  Map<String, dynamic> toJson() => {
        'tools': tools,
        'granted': granted,
        'spots': {for (final e in spots.entries) e.key: e.value.toJson()},
        'total': total,
      };

  factory HarvestState.fromJson(Map<String, dynamic> j) => HarvestState(
        tools: {
          for (final e in ((j['tools'] as Map?) ?? const {}).entries)
            e.key as String: (e.value as num).toInt(),
        },
        granted: j['granted'] as bool? ?? false,
        spots: {
          for (final e in ((j['spots'] as Map?) ?? const {}).entries)
            if (SpotCharge.fromJson(e.value) case final c?) e.key as String: c,
        },
        total: (j['total'] as num?)?.toInt() ?? 0,
      );
}
