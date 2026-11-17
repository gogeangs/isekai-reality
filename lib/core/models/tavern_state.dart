/// 주점 기록 (묶음 51 #242). 따로 저장한다 ('tavern'). 예전 기록엔 없으니 없으면 처음부터.
class TavernState {
  const TavernState({
    this.mealDay,
    this.meal,
    this.rumorDay,
    this.walkDay,
    this.walkSteps = 0,
    this.meals = 0,
  });

  /// 한 끼 먹은 날 ('yyyy-mm-dd') · 고른 식사 (Meal 이름)
  final String? mealDay;
  final String? meal;

  /// 소문을 들은 날
  final String? rumorDay;

  /// 걸을 때 효과(스튜 · 배낭 매듭 · 동전 주머니)를 센 날 · 그날 걸음
  final String? walkDay;
  final int walkSteps;

  /// 지금까지 먹은 끼니 수
  final int meals;

  TavernState copyWith({
    String? mealDay,
    String? meal,
    String? rumorDay,
    String? walkDay,
    int? walkSteps,
    int? meals,
  }) =>
      TavernState(
        mealDay: mealDay ?? this.mealDay,
        meal: meal ?? this.meal,
        rumorDay: rumorDay ?? this.rumorDay,
        walkDay: walkDay ?? this.walkDay,
        walkSteps: walkSteps ?? this.walkSteps,
        meals: meals ?? this.meals,
      );

  Map<String, dynamic> toJson() => {
        'v': 1,
        if (mealDay != null) 'mealDay': mealDay,
        if (meal != null) 'meal': meal,
        if (rumorDay != null) 'rumorDay': rumorDay,
        if (walkDay != null) 'walkDay': walkDay,
        if (walkSteps > 0) 'walkSteps': walkSteps,
        if (meals > 0) 'meals': meals,
      };

  static TavernState fromJson(Map<String, dynamic> j) => TavernState(
        mealDay: j['mealDay'] as String?,
        meal: j['meal'] as String?,
        rumorDay: j['rumorDay'] as String?,
        walkDay: j['walkDay'] as String?,
        walkSteps: ((j['walkSteps'] as num?) ?? 0).toInt(),
        meals: ((j['meals'] as num?) ?? 0).toInt(),
      );
}
