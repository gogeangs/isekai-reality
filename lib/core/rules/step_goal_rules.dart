import '../models/daily_record.dart';
import 'rule_constants.dart';

class StepGoalRules {
  StepGoalRules._();

  /// 첫 3일의 평균 걸음으로 맞춤 목표를 제안한다.
  /// 500보 단위로 내림하고, 3,000 ~ 10,000보 사이로 맞춘다.
  /// 3일이 안 됐으면 null.
  static int? suggestInitialGoal(List<DailyRecord> firstDays) {
    if (firstDays.length < RuleConstants.adaptiveObserveDays) return null;
    final sample = firstDays.take(RuleConstants.adaptiveObserveDays);
    final avg = sample.fold<int>(0, (s, d) => s + d.steps) ~/
        RuleConstants.adaptiveObserveDays;
    final rounded = (avg ~/ 500) * 500;
    return _clampGoal(rounded);
  }

  /// 최근 기록이 연속으로 목표를 달성했으면 올린 목표를 제안한다.
  /// 올리지 않아도 불이익은 없다. 제안할 게 없으면 null.
  static int? suggestRaise(List<DailyRecord> recentDays, int currentGoal) {
    if (recentDays.length < RuleConstants.raiseSuggestStreak) return null;
    final lastDays = recentDays.sublist(
        recentDays.length - RuleConstants.raiseSuggestStreak);
    final allAchieved = lastDays.every((d) => d.steps >= currentGoal);
    if (!allAchieved || currentGoal >= RuleConstants.maxStepGoal) return null;
    return _clampGoal(currentGoal + RuleConstants.raiseSuggestAmount);
  }

  static int _clampGoal(int goal) {
    if (goal < RuleConstants.minStepGoal) return RuleConstants.minStepGoal;
    if (goal > RuleConstants.maxStepGoal) return RuleConstants.maxStepGoal;
    return goal;
  }
}
