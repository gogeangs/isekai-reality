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
  });

  /// [history] 는 날짜순이며 마지막 기록이 오늘이다.
  factory PlayerState.fromHistory({
    required String name,
    required List<DailyRecord> history,
  }) {
    var totalExp = 0;
    var streak = 0;
    DateTime? previous;
    for (final day in history) {
      final continuous =
          previous != null && day.date.difference(previous).inDays == 1;
      streak = day.openedApp ? (continuous ? streak + 1 : 1) : 0;
      totalExp += ExpRules.forDay(day, consecutiveDays: streak).total;
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
        (date: d.date, steps: d.steps, runs: d.dungeonRuns.length),
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
        carriedKeys: carried,
        keysUsedToday: today?.dungeonRuns.length ?? 0,
      ),
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

  DailyRecord? get today => history.isEmpty ? null : history.last;
}
