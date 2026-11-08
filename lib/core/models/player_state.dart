import '../rules/rules.dart';
import 'daily_record.dart';

/// 기록(history)에서 계산한 플레이어의 현재 상태.
///
/// 상태는 저장하지 않고 매번 기록에서 다시 계산한다.
/// 그래서 규칙 숫자를 바꿔도 과거 기록으로 바로 다시 계산된다.
class PlayerState {
  PlayerState._({
    required this.name,
    required this.history,
    required this.totalExp,
    required this.level,
    required this.stats,
    required this.titles,
    required this.job,
    required this.gauge,
    required this.dailyExp,
    required this.crystals,
  });

  /// [history] 는 날짜순이며 마지막 기록이 오늘이다.
  factory PlayerState.fromHistory({
    required String name,
    required List<DailyRecord> history,
  }) {
    var totalExp = 0;
    var streak = 0;
    DateTime? previous;
    var restedLastNight = false;
    final dailyExp = <DailyExpBreakdown>[];
    for (final day in history) {
      final continuous =
          previous != null && day.date.difference(previous).inDays == 1;
      streak = day.openedApp ? (continuous ? streak + 1 : 1) : 0;
      final exp = ExpRules.forDay(day,
          consecutiveDays: streak,
          restedLastNight: continuous && restedLastNight);
      restedLastNight = day.restedAtInn;
      dailyExp.add(exp);
      totalExp += exp.total;
      previous = day.date;
    }
    final level = LevelRules.fromTotalExp(totalExp);
    final stats = StatRules.fromHistory(history);
    final job = history.length >= RuleConstants.jobAwakeningDay
        ? JobRules.awaken(history.take(RuleConstants.jobAwakeningDay).toList())
        : null;
    final today = history.isEmpty ? null : history.last;
    final carried = DungeonGaugeRules.carriedIntoLastDay([
      for (final d in history)
        (
          date: d.date,
          steps: d.steps,
          goal: d.stepGoal,
          extra: TownRules.spareKeysOn(d),
          runs: d.dungeonRuns.length,
        ),
    ]);

    return PlayerState._(
      name: name,
      history: history,
      totalExp: totalExp,
      level: level,
      stats: stats,
      titles: TitleRules.earned(history, level.level),
      job: job,
      gauge: DungeonGaugeRules.today(
        steps: today?.steps ?? 0,
        stepGoal: today?.stepGoal,
        extraKeys: today == null ? 0 : TownRules.spareKeysOn(today),
        carriedKeys: carried,
        keysUsedToday: today?.dungeonRuns.length ?? 0,
      ),
      dailyExp: dailyExp,
      crystals: TownRules.crystals(history),
    );
  }

  final String name;
  final List<DailyRecord> history;
  final int totalExp;
  final LevelProgress level;
  final Stats stats;
  final Set<TitleId> titles;

  /// 7일째 전에는 null
  final Job? job;

  final DungeonGaugeState gauge;

  /// [history] 와 같은 순서의 하루 경험치 내역
  final List<DailyExpBreakdown> dailyExp;

  /// 가진 정화 결정 (잡화상 돈)
  final int crystals;

  DailyRecord? get today => history.isEmpty ? null : history.last;
}
