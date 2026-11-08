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

/// 페이즈 1의 일일 퀘스트 3개: 수면 · 걸음 · 공부
class QuestRules {
  QuestRules._();

  static const int studyQuestMinutes = 30;

  static List<QuestProgress> forDay(DailyRecord record) => [
        QuestProgress(
          title: '7시간 자기',
          current: record.sleepMinutes ?? 0,
          target: RuleConstants.sleepGoodMinutes,
          unit: '분',
        ),
        QuestProgress(
          title: '${_comma(record.stepGoal)}보 걷기',
          current: record.steps,
          target: record.stepGoal,
          unit: '보',
        ),
        QuestProgress(
          title: '공부·독서 $studyQuestMinutes분',
          current: record.studyMinutes,
          target: studyQuestMinutes,
          unit: '분',
        ),
      ];

  static int completedCount(DailyRecord record) =>
      forDay(record).where((q) => q.completed).length;

  static String _comma(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
}
