import '../../core/models/daily_record.dart';
import '../../core/rules/rules.dart';

/// 건강 앱 연동 전까지 화면을 확인하기 위한 2주치 예시 기록.
/// 마지막 날이 '오늘'이며, 목업과 같은 6,400보 · 7시간 10분 수면 · 공부 10분이다.
class DemoData {
  DemoData._();

  static List<DailyRecord> twoWeeks({DateTime? today}) {
    final end = today ?? DateTime.now();
    const steps = [
      6200, 5400, 9100, 4800, 7300, 5600, 10400,
      9200, 6100, 11400, 8300, 7500, 10200, 6400,
    ];
    const sleep = [
      430, 400, 445, 380, 440, 470, 425,
      432, 390, 468, 414, 444, 486, 430,
    ];
    const study = [
      20, 0, 45, 30, 10, 60, 0,
      30, 0, 45, 20, 60, 15, 10,
    ];

    final records = <DailyRecord>[];
    for (var i = 0; i < 14; i++) {
      final isToday = i == 13;
      final keys = DungeonGaugeRules.keysEarnedFromSteps(steps[i]);
      final base = DailyRecord(
        date: DateTime(end.year, end.month, end.day)
            .subtract(Duration(days: 13 - i)),
        steps: steps[i],
        stepsAfter8pm: i.isEven ? 3200 : 800,
        sleepMinutes: sleep[i],
        studyMinutes: study[i],
        stepGoal: 8000,
        // 오늘은 아직 던전을 열지 않은 상태 (열쇠 2개 보유)
        dungeonRuns: isToday
            ? const []
            : List.generate(
                keys,
                (k) => DungeonRun(cleared: k != 2, atGate: k == 0),
              ),
        fieldMonstersPurified: isToday ? 0 : 2,
        newPlacesVisited: i < 5 ? 2 : (i.isEven ? 1 : 0),
        placesRevisited: 1,
      );
      records.add(base.copyWith(
        questsCompleted: QuestRules.completedCount(base),
      ));
    }
    return records;
  }
}
