import '../models/daily_record.dart';
import 'rule_constants.dart';
import 'board_rules.dart';
import 'town_rules.dart';

/// 하루 경험치의 내역
class DailyExpBreakdown {
  const DailyExpBreakdown({
    required this.dungeon,
    required this.fieldMonster,
    required this.exploration,
    required this.quest,
    this.rest = 0,
    this.restStreak = 0,
    this.questAll = 0,
    this.weekly = 0,
  });

  final int dungeon;
  final int fieldMonster;
  final int exploration;
  final int quest;

  /// 여관 휴식을 마친 날의 보너스 (하루 한 번)
  final int rest;

  /// 연속 휴식 보너스 (3일·7일·14일째, 그 뒤 7일마다)
  final int restStreak;

  /// 일일 퀘스트 3개를 모두 마친 날의 추가 보상
  final int questAll;

  /// 그날 마친 주간 의뢰 보상 (11-10 #26)
  final int weekly;

  int get total =>
      dungeon +
      fieldMonster +
      exploration +
      quest +
      rest +
      restStreak +
      questAll +
      weekly;
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

  /// 하루 기록으로 경험치 내역을 계산한다.
  ///
  /// 걸음은 경험치를 직접 주지 않는다. 걸음은 던전 열쇠가 되고,
  /// 던전에서 경험치를 얻는다. 공부·수면은 2026-11-10에 뺐다.
  ///
  /// [restStreak] 는 오늘을 포함한 연속 휴식 일수 (오늘 쉬지 않았으면 0)
  /// [weeklyDone] 는 그날 새로 마친 주간 의뢰 수
  static DailyExpBreakdown forDay(DailyRecord record,
      {int restStreak = 0, int weeklyDone = 0}) {
    final runs = record.dungeonRuns
        .take(RuleConstants.maxDungeonRunsPerDay)
        .toList(); // 하루 최대 4회까지 경험치 인정
    final dungeon = runs.fold<int>(0, (sum, r) => sum + dungeonRunExp(r));

    // 11-11 #69: 5마리 뒤로는 보상이 줄어든다 (숨은 규칙)
    final monsters = RuleConstants.fieldUnits(record.fieldMonstersPurified);

    final newPlaces =
        record.newPlacesVisited > RuleConstants.maxNewPlacesPerDay
            ? RuleConstants.maxNewPlacesPerDay
            : record.newPlacesVisited;

    final quests = record.questsCompleted > RuleConstants.questsPerDay
        ? RuleConstants.questsPerDay
        : record.questsCompleted;

    return DailyExpBreakdown(
      dungeon: dungeon,
      fieldMonster: (monsters *
                  RuleConstants.fieldMonsterExp *
                  (TownRules.incenseActive(record)
                      ? RuleConstants.incenseExpMultiplier
                      : 1))
              .round() +
          (record.gains['exp'] ?? 0),
      exploration: newPlaces * RuleConstants.newPlaceExp +
          record.placesRevisited * RuleConstants.revisitPlaceExp,
      quest: quests * RuleConstants.questExp,
      rest: record.rested ? RuleConstants.restBonusExp : 0,
      restStreak: record.rested ? TownRules.restStreakReward(restStreak).$1 : 0,
      questAll: quests >= RuleConstants.questsPerDay
          ? RuleConstants.questAllBonusExp
          : 0,
      weekly: weeklyDone * BoardRules.weeklyExp,
    );
  }
}
