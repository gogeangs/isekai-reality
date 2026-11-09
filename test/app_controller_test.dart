import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/models/player_state.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';

void main() {
  final now = DateTime(2026, 11, 8, 21, 30); // 일요일 저녁 9시 반

  test('건강 앱에서 오늘 걸음·저녁 걸음·지난밤 수면을 읽어 저장한다', () async {
    final store = InMemoryRecordStore(
        profile: const PlayerProfile(name: '하루', stepGoal: 5000));
    final controller = AppController(
      store: store,
      health: FakeHealthSource(
        stepsByDay: {'2026-11-08': 6400},
        stepsAfter8pmByDay: {'2026-11-08': 1200},
        sleepByDay: {'2026-11-08': 430},
      ),
      clock: () => now,
    );
    await controller.init();

    final today = controller.history.last;
    expect(today.dayKey, '2026-11-08');
    expect(today.steps, 6400);
    expect(today.stepsAfter8pm, 1200);
    expect(today.sleepMinutes, 430);
    expect(today.stepGoal, RuleConstants.defaultStepGoal);
    expect(today.questsCompleted, 2); // 수면, 걸음 완료 / 공부 미완료
    // 걸음 열쇠 2개 + 목표 달성 보너스 1개
    expect(controller.player.gauge.keysAvailable, 3);
    expect(controller.player.gauge.goalBonusKey, isTrue);

    final saved = await store.loadHistory();
    expect(saved.single.steps, 6400);
  });

  test('공부 기록은 저장되고 퀘스트에 반영된다', () async {
    final store = InMemoryRecordStore(profile: const PlayerProfile(name: '하루'));
    final controller = AppController(
      store: store,
      health: FakeHealthSource(sleepByDay: {'2026-11-08': 300}),
      clock: () => now,
    );
    await controller.init();
    await controller.logStudy(30);

    final saved = (await store.loadHistory()).last;
    expect(saved.studyMinutes, 30);
    expect(saved.questsCompleted, 1);
  });

  test('어제 기록은 하루 전체 걸음으로 마감한다', () async {
    final store = InMemoryRecordStore(
      profile: const PlayerProfile(name: '하루'),
      history: [DailyRecord(date: DateTime(2026, 11, 7), steps: 3000)],
    );
    final controller = AppController(
      store: store,
      health: FakeHealthSource(stepsByDay: {'2026-11-07': 9000}),
      clock: () => now,
    );
    await controller.init();

    final yesterday = (await store.loadHistory()).first;
    expect(yesterday.steps, 9000);
  });

  test('건강 앱 권한이 없으면 걸음은 0이고 게임 기록은 그대로다', () async {
    final store = InMemoryRecordStore(profile: const PlayerProfile(name: '하루'));
    final controller = AppController(
      store: store,
      health: FakeHealthSource(granted: false, stepsByDay: {'2026-11-08': 9999}),
      clock: () => now,
    );
    await controller.init();
    expect(controller.healthGranted, isFalse);
    expect(controller.history.last.steps, 0);
  });

  test('남은 열쇠는 다음 날로 넘어가고, 하루를 건너뛰면 사라진다', () {
    final history = [
      DailyRecord(
        date: DateTime(2026, 11, 6),
        steps: 10000,
        dungeonRuns: const [DungeonRun(cleared: true)],
      ), // 4개 얻고 1개 사용 → 3개 이월
      DailyRecord(date: DateTime(2026, 11, 7), steps: 0),
    ];
    final p = PlayerState.fromHistory(name: '하루', history: history);
    expect(p.gauge.keysAvailable, 3);

    final skipped = [
      history.first,
      DailyRecord(date: DateTime(2026, 11, 8), steps: 0),
    ];
    final q = PlayerState.fromHistory(name: '하루', history: skipped);
    expect(q.gauge.keysAvailable, 0);
  });

  test('하루 기록은 JSON 으로 저장했다 되살려도 같다', () {
    final r = DailyRecord(
      date: DateTime(2026, 11, 8),
      steps: 6400,
      stepsAfter8pm: 1200,
      sleepMinutes: 430,
      studyMinutes: 10,
      stepGoal: 8000,
      dungeonRuns: const [DungeonRun(cleared: true, atGate: true)],
      fieldMonstersPurified: 2,
      newPlacesVisited: 1,
      placesRevisited: 1,
      questsCompleted: 1,
    );
    final back = DailyRecord.fromJson(r.toJson());
    expect(back.toJson(), r.toJson());
  });
}
