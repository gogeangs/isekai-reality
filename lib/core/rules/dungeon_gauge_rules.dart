import 'rule_constants.dart';

/// 오늘의 던전 게이지와 열쇠 상태
class DungeonGaugeState {
  const DungeonGaugeState({
    required this.keysAvailable,
    required this.keysEarnedToday,
    required this.stepsIntoNextKey,
    required this.stepsPerKey,
    required this.dailyKeyLimitReached,
  });

  /// 지금 쓸 수 있는 열쇠 수 (이월 + 오늘 획득 − 사용)
  final int keysAvailable;
  final int keysEarnedToday;

  /// 다음 열쇠까지 모은 걸음 (예: 1,400 / 2,500)
  final int stepsIntoNextKey;
  final int stepsPerKey;

  /// 오늘 획득 한도(4개)에 도달하면 게이지를 멈추고 쉬라고 안내한다
  final bool dailyKeyLimitReached;

  double get ratio =>
      dailyKeyLimitReached ? 1 : stepsIntoNextKey / stepsPerKey;
}

class DungeonGaugeRules {
  DungeonGaugeRules._();

  static int keysEarnedFromSteps(int steps) {
    final keys = steps ~/ RuleConstants.stepsPerKey;
    return keys > RuleConstants.maxKeysEarnedPerDay
        ? RuleConstants.maxKeysEarnedPerDay
        : keys;
  }

  /// [carriedKeys] 어제에서 넘어온 열쇠, [keysUsedToday] 오늘 쓴 열쇠
  static DungeonGaugeState today({
    required int steps,
    int carriedKeys = 0,
    int keysUsedToday = 0,
  }) {
    final carried = carriedKeys > RuleConstants.maxKeysCarryOver
        ? RuleConstants.maxKeysCarryOver
        : carriedKeys;
    final earned = keysEarnedFromSteps(steps);
    final limitReached = earned >= RuleConstants.maxKeysEarnedPerDay;
    final available = carried + earned - keysUsedToday;

    return DungeonGaugeState(
      keysAvailable: available < 0 ? 0 : available,
      keysEarnedToday: earned,
      stepsIntoNextKey:
          limitReached ? 0 : steps % RuleConstants.stepsPerKey,
      stepsPerKey: RuleConstants.stepsPerKey,
      dailyKeyLimitReached: limitReached,
    );
  }

  /// 하루가 끝날 때 다음 날로 넘어가는 열쇠 수
  static int carryOverToTomorrow(DungeonGaugeState endOfDay) {
    return endOfDay.keysAvailable > RuleConstants.maxKeysCarryOver
        ? RuleConstants.maxKeysCarryOver
        : endOfDay.keysAvailable;
  }
}
