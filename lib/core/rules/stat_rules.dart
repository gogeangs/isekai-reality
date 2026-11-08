import '../models/daily_record.dart';
import 'rule_constants.dart';

/// 네 가지 스탯. 쌓이기만 하고 줄지 않는다.
class Stats {
  const Stats({
    required this.vitality,
    required this.agility,
    required this.wisdom,
    required this.spirit,
  });

  /// 체력: 누적 걸음
  final int vitality;

  /// 민첩: 걸음 목표 달성한 날 수
  final int agility;

  /// 지력: 누적 공부·독서 시간
  final int wisdom;

  /// 정신: 7시간 이상 잔 날 수
  final int spirit;

  int get total => vitality + agility + wisdom + spirit;
}

class StatRules {
  StatRules._();

  static Stats fromHistory(List<DailyRecord> history) {
    const start = RuleConstants.statStartValue;
    var totalSteps = 0;
    var goalDays = 0;
    var totalStudy = 0;
    var goodSleepDays = 0;

    for (final day in history) {
      totalSteps += day.steps;
      totalStudy += day.studyMinutes;
      if (day.stepGoalAchieved) goalDays++;
      if (day.sleptWell) goodSleepDays++;
    }

    return Stats(
      vitality: start + totalSteps ~/ RuleConstants.vitalityStepsPerPoint,
      agility: start + goalDays,
      wisdom: start + totalStudy ~/ RuleConstants.wisdomStudyMinutesPerPoint,
      spirit: start + goodSleepDays,
    );
  }

  /// 전투력: 레벨과 스탯을 합친 값. 던전·필드 전투의 기준이 된다.
  static int combatPower({required int level, required Stats stats}) {
    return level * 10 + stats.total * 5;
  }

  /// 전투용 체력. 걸음 수와 헷갈리지 않도록 다른 크기의 숫자를 쓴다.
  static int battleMaxHp({required int level, required Stats stats}) {
    // 예: Lv.12, 체력 12 → 600 + 600 + 300 = 1,500 (목업과 같은 값)
    return 600 + level * 50 + stats.vitality * 25;
  }
}
