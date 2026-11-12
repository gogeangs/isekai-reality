/// 가방 확장 (11-11 #48). 예전에 5칸 묶음으로 늘린 횟수, 한 칸씩 연 칸(묶음 15 #106),
/// 다른 방법(보상 등)으로 늘린 칸을 따로 둔다. 이미 연 칸은 그대로 남는다.
class BagState {
  const BagState(
      {this.goldExpansions = 0, this.extraSlots = 0, this.singleSlots = 0});

  /// 예전에 금화로 늘린 횟수 (한 번에 5칸)
  final int goldExpansions;

  /// 금화 말고 다른 방법으로 늘린 칸
  final int extraSlots;

  /// 한 칸씩 연 칸 (금화 또는 광고)
  final int singleSlots;

  BagState copyWith({int? goldExpansions, int? extraSlots, int? singleSlots}) =>
      BagState(
        goldExpansions: goldExpansions ?? this.goldExpansions,
        extraSlots: extraSlots ?? this.extraSlots,
        singleSlots: singleSlots ?? this.singleSlots,
      );

  Map<String, dynamic> toJson() => {
        'goldExpansions': goldExpansions,
        'extraSlots': extraSlots,
        'singleSlots': singleSlots,
      };

  factory BagState.fromJson(Map<String, dynamic> j) => BagState(
        goldExpansions: (j['goldExpansions'] as num?)?.toInt() ?? 0,
        extraSlots: (j['extraSlots'] as num?)?.toInt() ?? 0,
        singleSlots: (j['singleSlots'] as num?)?.toInt() ?? 0,
      );
}
