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
    required this.gauge,
    required this.dailyExp,
    required this.manaStones,
    required this.gold,
    required this.materials,
  });

  /// [history] 는 날짜순이며 마지막 기록이 오늘이다.
  factory PlayerState.fromHistory({
    required String name,
    required List<DailyRecord> history,
  }) {
    var totalExp = 0;
    final restStreaks = TownRules.restStreaks(history);
    final dailyExp = <DailyExpBreakdown>[];
    for (var i = 0; i < history.length; i++) {
      final exp = ExpRules.forDay(history[i],
          restStreak: restStreaks[i],
          weeklyDone: BoardRules.weeklyCompletedOn(history, i));
      dailyExp.add(exp);
      totalExp += exp.total;
    }
    final level = LevelRules.fromTotalExp(totalExp);
    final stats = StatRules.fromHistory(history);
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
      gauge: DungeonGaugeRules.today(
        steps: today?.steps ?? 0,
        stepGoal: today?.stepGoal,
        extraKeys: today == null ? 0 : TownRules.spareKeysOn(today),
        carriedKeys: carried,
        keysUsedToday: today?.dungeonRuns.length ?? 0,
      ),
      dailyExp: dailyExp,
      manaStones: TownRules.manaStones(history),
      gold: TownRules.gold(history),
      materials: TownRules.materials(history),
    );
  }

  final String name;
  final List<DailyRecord> history;
  final int totalExp;
  final LevelProgress level;
  final Stats stats;
  final Set<TitleId> titles;

  final DungeonGaugeState gauge;

  /// [history] 와 같은 순서의 하루 경험치 내역
  final List<DailyExpBreakdown> dailyExp;

  /// 가진 마석 (몬스터가 떨어뜨림. 팔면 금화, 제작·강화에 씀)
  final int manaStones;

  /// 가진 금화 (잡화상 돈)
  final int gold;

  /// 가진 재료
  final Map<MaterialId, int> materials;

  int materialCount(MaterialId id) => materials[id] ?? 0;

  DailyRecord? get today => history.isEmpty ? null : history.last;

  /// 오늘까지 이어진 연속 휴식 일수
  int get restStreak => TownRules.currentRestStreak(history);

  /// 전투용 최대 HP
  int get maxHp => StatRules.battleMaxHp(level: level.level, stats: stats);
}
