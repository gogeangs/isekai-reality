/// 가방 확장 (11-11 #48). 금화로 늘린 횟수와, 나중에 다른 방법(보상 등)으로 늘린 칸을 따로 둔다.
class BagState {
  const BagState({this.goldExpansions = 0, this.extraSlots = 0});

  /// 금화로 늘린 횟수 (한 번에 5칸)
  final int goldExpansions;

  /// 금화 말고 다른 방법으로 늘린 칸
  final int extraSlots;

  BagState copyWith({int? goldExpansions, int? extraSlots}) => BagState(
        goldExpansions: goldExpansions ?? this.goldExpansions,
        extraSlots: extraSlots ?? this.extraSlots,
      );

  Map<String, dynamic> toJson() =>
      {'goldExpansions': goldExpansions, 'extraSlots': extraSlots};

  factory BagState.fromJson(Map<String, dynamic> j) => BagState(
        goldExpansions: (j['goldExpansions'] as num?)?.toInt() ?? 0,
        extraSlots: (j['extraSlots'] as num?)?.toInt() ?? 0,
      );
}
