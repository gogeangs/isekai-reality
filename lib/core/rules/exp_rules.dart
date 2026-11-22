import '../models/daily_record.dart';
import 'rule_constants.dart';
import 'board_rules.dart';
import 'quest_rules.dart';
import 'town_rules.dart';
import 'walk_reward_rules.dart';

/// 하루 경험치의 내역
class DailyExpBreakdown {
  const DailyExpBreakdown({
    required this.dungeon,
    required this.fieldMonster,
    required this.quest,
    this.questAll = 0,
    this.weekly = 0,
    this.footprint = 0,
  });

  final int dungeon;
  final int fieldMonster;
  final int quest;

  /// 일일 퀘스트 3개를 모두 마친 날의 추가 보상
  final int questAll;

  /// 그날 마친 주간 의뢰 보상 (11-10 #26)
  final int weekly;

  /// 묶음 65 #252: 1만 보를 넘긴 2,500보마다 (하루 2만 보까지)
  final int footprint;

  /// 묶음 65 #254: 높은 레벨 배율을 칸마다 곱한 내역 (배율은 화면에 안 보임)
  DailyExpBreakdown scaled(double m) => m == 1
      ? this
      : DailyExpBreakdown(
          dungeon: (dungeon * m).round(),
          fieldMonster: (fieldMonster * m).round(),
          quest: (quest * m).round(),
          questAll: (questAll * m).round(),
          weekly: (weekly * m).round(),
          footprint: (footprint * m).round(),
        );

  int get total =>
      dungeon +
      fieldMonster +
      quest +
      questAll +
      weekly +
      footprint;
}

class ExpRules {
  ExpRules._();

  /// 던전 한 번의 경험치
  static int dungeonRunExp(DungeonRun run) {
    final base = run.cleared
        ? RuleConstants.dungeonClearExp
        : RuleConstants.dungeonFailExp;
    return base; // 묶음 81 #380: 미궁 입구 1.5배 없음
  }

  /// 하루 기록으로 경험치 내역을 계산한다.
  ///
  /// 걸음은 경험치를 직접 주지 않는다. 걸음은 던전 열쇠가 되고,
  /// 던전에서 경험치를 얻는다. 공부·수면은 2026-11-10에 뺐다.
  ///
  /// 묶음 80 #367: 여관 휴식 보너스 · 연속 휴식 보상은 없앰 (여관은 HP · MP · 기력만)
  /// [weeklyDone] 는 그날 새로 마친 주간 의뢰 수
  static DailyExpBreakdown forDay(DailyRecord record,
      {int weeklyDone = 0}) {
    final runs = record.dungeonRuns; // 묶음 70 #296: 하루 던전 기록 전부
    final dungeon = runs.fold<int>(0, (sum, r) => sum + dungeonRunExp(r));

    // 11-11 #69: 5마리 뒤로는 보상이 줄어든다 (숨은 규칙)
    final monsters = RuleConstants.fieldUnits(record.fieldMonstersPurified);

    final perDay = QuestRules.perDay(record);
    final quests = record.questsCompleted > perDay
        ? perDay
        : record.questsCompleted;

    return DailyExpBreakdown(
      dungeon: dungeon,
      fieldMonster: (monsters *
                  RuleConstants.fieldMonsterExp *
                  (TownRules.incenseActive(record)
                      ? RuleConstants.incenseExpMultiplier
                      : 1))
              .round() +
          (record.gains['exp'] ?? 0) -
          (record.counters[TownRules.tiredExpKey] ?? 0),
      quest: quests * RuleConstants.questExp,
      questAll: quests >= perDay
          ? RuleConstants.questAllBonusExp
          : 0,
      weekly: weeklyDone * BoardRules.weeklyExp,
      footprint: WalkRewardRules.footprintExpOn(record.steps, record.date),
    );
  }
}
