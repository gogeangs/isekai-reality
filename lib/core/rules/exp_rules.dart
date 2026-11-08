import '../models/daily_record.dart';
import 'rule_constants.dart';

/// 하루 경험치의 내역
class DailyExpBreakdown {
  const DailyExpBreakdown({
    required this.dungeon,
    required this.fieldMonster,
    required this.exploration,
    required this.sleep,
    required this.study,
    required this.quest,
    required this.streakBonus,
  });

  final int dungeon;
  final int fieldMonster;
  final int exploration;
  final int sleep;
  final int study;
  final int quest;
  final int streakBonus;

  int get total =>
      dungeon + fieldMonster + exploration + sleep + study + quest + streakBonus;
}

class ExpRules {
  ExpRules._();

  /// 던전 한 번의 경험치 (미궁 입구 보너스 포함, 반올림)
  static int dungeonRunExp(DungeonRun run) {
    final base = run.cleared
        ? RuleConstants.dungeonClearExp
        : RuleConstants.dungeonFailExp;
    if (!run.atGate) return base;
    return (base * RuleConstants.gateBonusMultiplier).round();
  }

  static int sleepExp(int? sleepMinutes) {
    final m = sleepMinutes ?? 0;
    if (m >= RuleConstants.sleepGoodMinutes) return RuleConstants.sleepGoodExp;
    if (m >= RuleConstants.sleepOkMinutes) return RuleConstants.sleepOkExp;
    return 0;
  }

  static int studyExp(int studyMinutes) {
    final raw = (studyMinutes ~/ 10) * RuleConstants.studyExpPerTenMinutes;
    return raw > RuleConstants.maxStudyExpPerDay
        ? RuleConstants.maxStudyExpPerDay
        : raw;
  }

  /// [consecutiveDays] 는 오늘을 포함한 연속 접속 일수
  static int streakBonus(int consecutiveDays) {
    if (consecutiveDays > 0 &&
        consecutiveDays % RuleConstants.streakBonusEveryDays == 0) {
      return RuleConstants.streakBonusExp;
    }
    return 0;
  }

  /// 하루 기록으로 경험치 내역을 계산한다.
  ///
  /// 걸음은 경험치를 직접 주지 않는다. 걸음은 던전 열쇠가 되고,
  /// 던전에서 경험치를 얻는다.
  static DailyExpBreakdown forDay(
    DailyRecord record, {
    int consecutiveDays = 0,
  }) {
    final runs = record.dungeonRuns
        .take(RuleConstants.maxDungeonRunsPerDay)
        .toList(); // 하루 최대 4회까지 경험치 인정
    final dungeon = runs.fold<int>(0, (sum, r) => sum + dungeonRunExp(r));

    final monsters = record.fieldMonstersPurified >
            RuleConstants.maxFieldMonstersPerDay
        ? RuleConstants.maxFieldMonstersPerDay
        : record.fieldMonstersPurified;

    final newPlaces =
        record.newPlacesVisited > RuleConstants.maxNewPlacesPerDay
            ? RuleConstants.maxNewPlacesPerDay
            : record.newPlacesVisited;

    final quests = record.questsCompleted > RuleConstants.questsPerDay
        ? RuleConstants.questsPerDay
        : record.questsCompleted;

    return DailyExpBreakdown(
      dungeon: dungeon,
      fieldMonster: monsters * RuleConstants.fieldMonsterExp,
      exploration: newPlaces * RuleConstants.newPlaceExp +
          record.placesRevisited * RuleConstants.revisitPlaceExp,
      sleep: sleepExp(record.sleepMinutes),
      study: studyExp(record.studyMinutes),
      quest: quests * RuleConstants.questExp,
      streakBonus: streakBonus(consecutiveDays),
    );
  }
}
