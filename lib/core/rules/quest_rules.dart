import '../models/daily_record.dart';
import 'rule_constants.dart';

/// 일일 퀘스트 하나의 진행 상태
class QuestProgress {
  const QuestProgress({
    required this.title,
    required this.current,
    required this.target,
    required this.unit,
  });

  final String title;
  final int current;
  final int target;

  /// 화면에 붙일 단위 (예: '보', '분')
  final String unit;

  bool get completed => current >= target;
  double get ratio => target == 0 ? 1 : (current / target).clamp(0, 1).toDouble();
}

/// 일일 퀘스트 3개: 걸음 · 던전 · 필드 몬스터
/// (11-10 수면·공부 대신, 같은 날 안개를 없애며 '새 안개 걷기'를 '던전 1번 열기'로)
class QuestRules {
  QuestRules._();

  /// 상인 「발 넓은 상인」이 붙인 네 번째 의뢰 (그날 기록에 1)
  static const String quest4Key = 'quest4';

  /// 그날 잡화상에서 사고판 횟수
  static const String shopTradeKey = 'shopTrade';

  /// 그날 의뢰 수 (보통 3, 상인이면 4)
  static int perDay(DailyRecord r) =>
      RuleConstants.questsPerDay + ((r.counters[quest4Key] ?? 0) > 0 ? 1 : 0);

  static List<QuestProgress> forDay(DailyRecord record) => [
        QuestProgress(
          title: '${_comma(record.stepGoal)}보 걷기',
          current: record.steps,
          target: record.stepGoal,
          unit: '보',
        ),
        QuestProgress(
          title: '던전 1번 열기',
          current: record.dungeonRuns.length,
          target: 1,
          unit: '번',
        ),
        QuestProgress(
          title: '필드 몬스터 1마리 사냥',
          current: record.fieldMonstersPurified,
          target: 1,
          unit: '마리',
        ),
        if ((record.counters[quest4Key] ?? 0) > 0)
          QuestProgress(
            title: '잡화상 거래 1번',
            current: record.counters[shopTradeKey] ?? 0,
            target: 1,
            unit: '번',
          ),
      ];

  static int completedCount(DailyRecord record) =>
      forDay(record).where((q) => q.completed).length;

  /// 퀘스트 하나를 마치면 받는 경험치
  static int get rewardExp => RuleConstants.questExp;

  /// 3개를 모두 마치면 더 받는 경험치
  static int get allDoneBonusExp => RuleConstants.questAllBonusExp;

  static bool allDone(DailyRecord r) => r.questsCompleted >= perDay(r);

  /// 3개를 모두 마친 날이 며칠째 이어지는지 (보상 없이 표시만, 11-10 결정).
  /// 오늘을 아직 다 못 했으면 어제까지 이어진 일수.
  static int allDoneStreak(List<DailyRecord> history) {
    if (history.isEmpty) return 0;
    var i = history.length - 1;
    if (!allDone(history[i])) i--;
    var n = 0;
    DateTime? prev;
    for (; i >= 0; i--) {
      final r = history[i];
      if (!allDone(r)) break;
      final d = DateTime(r.date.year, r.date.month, r.date.day);
      if (prev != null && prev.difference(d).inDays != 1) break;
      prev = d;
      n++;
    }
    return n;
  }

  static String _comma(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
}
