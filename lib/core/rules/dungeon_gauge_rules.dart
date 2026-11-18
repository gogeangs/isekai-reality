import 'rule_constants.dart';
import 'walk_reward_rules.dart';

/// 오늘의 던전 게이지와 열쇠 상태
class DungeonGaugeState {
  const DungeonGaugeState({
    required this.keysAvailable,
    required this.keysEarnedToday,
    required this.stepsIntoNextKey,
    required this.stepsPerKey,
    required this.dailyKeyLimitReached,
    this.goalBonusKey = false,
    this.stepsToGoal,
    this.shards = 0,
    this.shardsToday = 0,
    this.shardKeysToday = 0,
    this.shardInto,
  });

  /// 지금 쓸 수 있는 열쇠 수 (이월 + 오늘 획득 − 사용)
  final int keysAvailable;
  final int keysEarnedToday;

  /// 다음 열쇠까지 모은 걸음 (예: 1,400 / 2,500)
  final int stepsIntoNextKey;
  final int stepsPerKey;

  /// 오늘 획득 한도(4개)에 도달하면 게이지를 멈추고 쉬라고 안내한다
  final bool dailyKeyLimitReached;

  /// 오늘 자기 걸음 목표를 채워 받은 보너스 열쇠 (하루 1개, 걸음 한도와 별도)
  final bool goalBonusKey;

  /// 보너스 열쇠까지 남은 걸음 (목표가 없거나 이미 채웠으면 null)
  final int? stepsToGoal;

  /// 묶음 65 #252: 지금 가진 열쇠 조각 (열쇠가 차 있으면 조각으로 보관)
  final int shards;

  /// 오늘 1만 보를 넘겨 얻은 조각 (하루 4개)
  final int shardsToday;

  /// 오늘 조각 두 개가 맞물려 된 열쇠
  final int shardKeysToday;

  /// 다음 조각까지 모은 걸음 (1만 보 전 · 2만 보 뒤는 null)
  final int? shardInto;

  double get ratio =>
      dailyKeyLimitReached ? 1 : stepsIntoNextKey / stepsPerKey;
}

class DungeonGaugeRules {
  DungeonGaugeRules._();

  /// 걸음으로 얻는 열쇠 (2,500보마다 1개, 하루 4개까지)
  static int keysEarnedFromSteps(int steps) {
    final keys = steps ~/ RuleConstants.stepsPerKey;
    return keys > RuleConstants.maxKeysEarnedPerDay
        ? RuleConstants.maxKeysEarnedPerDay
        : keys;
  }

  /// 하루에 얻는 열쇠 전부: 걸음 열쇠 + 자기 목표를 채운 날 보너스 1개
  /// [bonusSteps] 는 걸음 물약(11-11 #74)으로 더 찬 게이지 (목표 보너스에는 세지 않는다)
  static int keysEarnedForDay(int steps, {int? stepGoal, int bonusSteps = 0}) {
    final bonus = stepGoal != null && stepGoal > 0 && steps >= stepGoal
        ? RuleConstants.goalBonusKeys
        : 0;
    return keysEarnedFromSteps(steps + bonusSteps) + bonus;
  }

  /// [carriedKeys] 어제에서 넘어온 열쇠, [keysUsedToday] 오늘 쓴 열쇠
  static DungeonGaugeState today({
    required int steps,
    int? stepGoal,
    int extraKeys = 0,
    int carriedKeys = 0,
    int keysUsedToday = 0,
    int bonusSteps = 0,
    int shardsCarried = 0,
    int shardsToday = 0,
    int? shardInto,
  }) {
    final carried = carriedKeys > RuleConstants.maxKeysCarryOver
        ? RuleConstants.maxKeysCarryOver
        : carriedKeys;
    final gaugeSteps = steps + bonusSteps;
    final fromSteps = keysEarnedFromSteps(gaugeSteps);
    final earned =
        keysEarnedForDay(steps, stepGoal: stepGoal, bonusSteps: bonusSteps) +
            extraKeys;
    final limitReached = fromSteps >= RuleConstants.maxKeysEarnedPerDay;
    var available = carried + earned - keysUsedToday;
    // 묶음 65: 조각 두 개 → 열쇠 (넘어가는 열쇠 상한까지, 차 있으면 조각으로 보관)
    var pool = shardsCarried + shardsToday;
    var made = 0;
    while (pool >= WalkRewardRules.shardsPerKey && available < RuleConstants.maxKeysCarryOver) {
      pool -= WalkRewardRules.shardsPerKey;
      available++;
      made++;
    }

    return DungeonGaugeState(
      keysAvailable: available < 0 ? 0 : available,
      keysEarnedToday: earned,
      stepsIntoNextKey:
          limitReached ? 0 : gaugeSteps % RuleConstants.stepsPerKey,
      stepsPerKey: RuleConstants.stepsPerKey,
      dailyKeyLimitReached: limitReached,
      goalBonusKey: earned - extraKeys > fromSteps,
      stepsToGoal: stepGoal != null && stepGoal > 0 && steps < stepGoal
          ? stepGoal - steps
          : null,
      shards: pool,
      shardsToday: shardsToday,
      shardKeysToday: made,
      shardInto: shardInto,
    );
  }

  /// 날짜순 기록에서 마지막 날(오늘)로 넘어온 열쇠 수를 계산한다.
  /// 하루에 쓴 열쇠 수 = 그날 연 던전 수. 기록이 하루 이상 비면 이월은 사라진다.
  static int carriedIntoLastDay(
      List<({DateTime date, int steps, int? goal, int extra, int runs, int bonus})>
          days) {
    var carried = 0;
    for (var i = 0; i < days.length - 1; i++) {
      final gapDays = days[i + 1].date.difference(days[i].date).inDays;
      final left = carried +
          keysEarnedForDay(days[i].steps,
              stepGoal: days[i].goal, bonusSteps: days[i].bonus) +
          days[i].extra -
          days[i].runs;
      carried = gapDays == 1
          ? (left < 0
              ? 0
              : (left > RuleConstants.maxKeysCarryOver
                  ? RuleConstants.maxKeysCarryOver
                  : left))
          : 0;
    }
    return carried;
  }

  /// 묶음 65: 마지막 날(오늘)로 넘어온 열쇠 · 열쇠 조각. [shards] 는 [days] 와 같은 순서로 그날 얻은 조각.
  /// 조각은 날이 비어도 남고, 두 개가 모이면 넘어가는 열쇠 상한(3)까지 열쇠가 된다.
  static ({int keys, int shards}) carriedWithShards(
      List<({DateTime date, int steps, int? goal, int extra, int runs, int bonus})> days,
      List<int> shards) {
    var carried = 0, pool = 0;
    for (var i = 0; i < days.length - 1; i++) {
      final gapDays = days[i + 1].date.difference(days[i].date).inDays;
      var left = carried +
          keysEarnedForDay(days[i].steps, stepGoal: days[i].goal, bonusSteps: days[i].bonus) +
          days[i].extra -
          days[i].runs;
      pool += i < shards.length ? shards[i] : 0;
      while (pool >= WalkRewardRules.shardsPerKey && left < RuleConstants.maxKeysCarryOver) {
        pool -= WalkRewardRules.shardsPerKey;
        left++;
      }
      carried = gapDays == 1 ? (left < 0 ? 0 : (left > RuleConstants.maxKeysCarryOver ? RuleConstants.maxKeysCarryOver : left)) : 0;
    }
    return (keys: carried, shards: pool);
  }

  /// 하루가 끝날 때 다음 날로 넘어가는 열쇠 수
  static int carryOverToTomorrow(DungeonGaugeState endOfDay) {
    return endOfDay.keysAvailable > RuleConstants.maxKeysCarryOver
        ? RuleConstants.maxKeysCarryOver
        : endOfDay.keysAvailable;
  }
}
