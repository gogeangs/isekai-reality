import '../rules/element_rules.dart';
import '../rules/harvest_rules.dart';

/// 채집 (11-11 #56, #83). 따로 저장한다 ('harvest').
class HarvestState {
  const HarvestState({
    this.tools = const {},
    this.granted = false,
    this.spots = const {},
    this.total = 0,
    this.tiers = const {},
    this.elements = const {},
    this.streak = 0,
    this.perfects = const {},
    this.relics = 0,
  });

  /// 도구 이름 → 내구도
  final Map<String, int> tools;

  /// 처음 채집할 때 기본 도구를 받았는지
  final bool granted;

  /// 자리 id → 남은 횟수
  final Map<String, SpotCharge> spots;

  /// 지금까지 채집한 횟수
  final int total;

  /// 도구 이름 → 등급 (11-11 #83, 없으면 돌)
  final Map<String, int> tiers;

  /// 도구 이름 → 입힌 속성 (11-11 #83)
  final Map<String, String> elements;

  /// 미니게임 완벽 연속 (숨김, 끊기면 0)
  final int streak;

  /// 자리 종류 → 완벽 횟수 (숨김, 많이 쌓이면 빠른 채집도 「좋음」)
  final Map<String, int> perfects;

  /// 고대 유물을 캔 횟수 (이야기를 하나씩 연다)
  final int relics;

  ToolTier tierOf(HarvestTool t) =>
      ToolTier.values[(tiers[t.name] ?? 0).clamp(0, ToolTier.values.length - 1)];

  Element? elementOf(HarvestTool t) => ElementRules.parse(elements[t.name]);

  /// 내구도. 새로 생긴 도구(붓)는 받은 적이 없어도 새것으로 친다.
  int durability(HarvestTool t) =>
      tools[t.name] ?? HarvestRules.toolMaxFor(tierOf(t));

  bool hasTool(HarvestTool t) => tools.containsKey(t.name);

  bool mastered(HarvestKind k) =>
      (perfects[k.name] ?? 0) >= HarvestRules.masteryPerfects;

  int chargesOf(String spotId, DateTime now) =>
      spots[spotId]?.current(now) ?? HarvestRules.maxCharges;

  HarvestState copyWith({
    Map<String, int>? tools,
    bool? granted,
    Map<String, SpotCharge>? spots,
    int? total,
    Map<String, int>? tiers,
    Map<String, String>? elements,
    int? streak,
    Map<String, int>? perfects,
    int? relics,
  }) =>
      HarvestState(
        tools: tools ?? this.tools,
        granted: granted ?? this.granted,
        spots: spots ?? this.spots,
        total: total ?? this.total,
        tiers: tiers ?? this.tiers,
        elements: elements ?? this.elements,
        streak: streak ?? this.streak,
        perfects: perfects ?? this.perfects,
        relics: relics ?? this.relics,
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
        if (tiers.isNotEmpty) 'tiers': tiers,
        if (elements.isNotEmpty) 'elements': elements,
        if (streak > 0) 'streak': streak,
        if (perfects.isNotEmpty) 'perfects': perfects,
        if (relics > 0) 'relics': relics,
      };

  factory HarvestState.fromJson(Map<String, dynamic> j) {
    Map<String, int> ints(Object? raw) => {
          for (final e in ((raw as Map?) ?? const {}).entries)
            e.key as String: (e.value as num).toInt(),
        };
    return HarvestState(
      tools: ints(j['tools']),
      granted: j['granted'] as bool? ?? false,
      spots: {
        for (final e in ((j['spots'] as Map?) ?? const {}).entries)
          if (SpotCharge.fromJson(e.value) case final c?) e.key as String: c,
      },
      total: (j['total'] as num?)?.toInt() ?? 0,
      tiers: ints(j['tiers']),
      elements: {
        for (final e in ((j['elements'] as Map?) ?? const {}).entries)
          e.key as String: '${e.value}',
      },
      streak: (j['streak'] as num?)?.toInt() ?? 0,
      perfects: ints(j['perfects']),
      relics: (j['relics'] as num?)?.toInt() ?? 0,
    );
  }
}
