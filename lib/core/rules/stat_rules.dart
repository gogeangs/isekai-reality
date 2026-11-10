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

  /// 지력: 도감에 새 몬스터, 새 장소를 처음 발견한 수
  final int wisdom;

  /// 정신: 7일 연속 접속한 횟수 + 여관 휴식을 마친 날 수
  final int spirit;

  int get total => vitality + agility + wisdom + spirit;

  /// 장비 추가 능력을 더할 때
  Stats operator +(Stats o) => Stats(
        vitality: vitality + o.vitality,
        agility: agility + o.agility,
        wisdom: wisdom + o.wisdom,
        spirit: spirit + o.spirit,
      );
}

class StatRules {
  StatRules._();

  static Stats fromHistory(List<DailyRecord> history) {
    const start = RuleConstants.statStartValue;
    var totalSteps = 0;
    var goalDays = 0;
    var discoveries = 0;
    var restDays = 0;
    var loginStreaks = 0;
    final seenMonsters = <String>{};

    var streak = 0;
    DateTime? prev;
    for (final day in history) {
      totalSteps += day.steps;
      if (day.stepGoalAchieved) goalDays++;
      if (day.rested) restDays++;

      // 지력: 처음 보는 몬스터 + 처음 가 본 장소
      for (final m in day.purifiedMonsterIds) {
        if (seenMonsters.add(m)) discoveries++;
      }
      discoveries += day.newPlacesVisited;

      // 정신: 7일 연속 접속할 때마다 +1
      final continuous = prev != null &&
          DateTime(day.date.year, day.date.month, day.date.day)
                  .difference(DateTime(prev.year, prev.month, prev.day))
                  .inDays ==
              1;
      streak = day.openedApp ? (continuous ? streak + 1 : 1) : 0;
      if (streak > 0 && streak % RuleConstants.spiritLoginStreakDays == 0) {
        loginStreaks++;
      }
      prev = day.date;
    }

    return Stats(
      vitality: start + totalSteps ~/ RuleConstants.vitalityStepsPerPoint,
      agility: start + goalDays,
      wisdom: start + discoveries,
      spirit: start + loginStreaks + restDays,
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
