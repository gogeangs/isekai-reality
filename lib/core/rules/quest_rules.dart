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

/// 일일 퀘스트 3개: 걸음 · 새 안개 · 필드 몬스터 (2026-11-10, 수면·공부 대신)
class QuestRules {
  QuestRules._();

  static List<QuestProgress> forDay(DailyRecord record) => [
        QuestProgress(
          title: '${_comma(record.stepGoal)}보 걷기',
          current: record.steps,
          target: record.stepGoal,
          unit: '보',
        ),
        QuestProgress(
          title: '새 안개 ${RuleConstants.questNewCells}칸 걷기',
          current: record.newCellsRevealed,
          target: RuleConstants.questNewCells,
          unit: '칸',
        ),
        QuestProgress(
          title: '필드 몬스터 1마리 정화',
          current: record.fieldMonstersPurified,
          target: 1,
          unit: '마리',
        ),
      ];

  static int completedCount(DailyRecord record) =>
      forDay(record).where((q) => q.completed).length;

  static String _comma(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
}
