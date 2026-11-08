import '../models/daily_record.dart';
import 'rule_constants.dart';

/// 페이즈 1에서 각성할 수 있는 직업 4종
enum Job { explorer, knight, sage, cleric }

extension JobName on Job {
  String get koreanName => switch (this) {
        Job.explorer => '탐험가',
        Job.knight => '기사',
        Job.sage => '현자',
        Job.cleric => '성직자',
      };
}

class JobRules {
  JobRules._();

  static bool isAwakeningDay(int daysSinceAwakening) =>
      daysSinceAwakening == RuleConstants.jobAwakeningDay;

  /// 첫 7일의 기록으로 직업 점수를 매긴다 (0.0 ~ 1.0).
  ///
  /// 걸음 수를 사람마다 다른 목표에 비춰 보기 때문에,
  /// 평소 적게 걷는 사람도 탐험가·기사가 될 수 있다.
  static Map<Job, double> scores(List<DailyRecord> firstWeek) {
    if (firstWeek.isEmpty) {
      return {for (final j in Job.values) j: 0};
    }
    final days = firstWeek.length;

    // 탐험가: 목표 대비 평균 걸음 (목표의 1.5배면 만점)
    final avgGoalRatio = firstWeek
            .map((d) => d.steps / d.stepGoal)
            .reduce((a, b) => a + b) /
        days;
    final explorer = _clamp(avgGoalRatio / 1.5);

    // 기사: 목표의 2배 이상 걸은 날 (7일 중 4일이면 만점)
    final doubleDays =
        firstWeek.where((d) => d.steps >= d.stepGoal * 2).length;
    final knight = _clamp(doubleDays / 4);

    // 현자: 하루 평균 30분 공부·독서면 만점
    final totalStudy =
        firstWeek.fold<int>(0, (s, d) => s + d.studyMinutes);
    final sage = _clamp(totalStudy / (30 * days));

    // 성직자: 7시간 이상 잔 날의 비율
    final goodSleep = firstWeek.where((d) => d.sleptWell).length;
    final cleric = _clamp(goodSleep / days);

    return {
      Job.explorer: explorer,
      Job.knight: knight,
      Job.sage: sage,
      Job.cleric: cleric,
    };
  }

  /// 가장 점수가 높은 직업. 같으면 탐험가 → 기사 → 현자 → 성직자 순.
  static Job awaken(List<DailyRecord> firstWeek) {
    final s = scores(firstWeek);
    var best = Job.explorer;
    for (final job in Job.values) {
      if (s[job]! > s[best]!) best = job;
    }
    return best;
  }

  static double _clamp(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
}
