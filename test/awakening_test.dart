import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';

void main() {
  final now = DateTime(2026, 11, 8, 14);

  test('처음 실행이면 각성이 필요하고, 각성하면 프로필이 저장된다', () async {
    final store = InMemoryRecordStore();
    final controller = AppController(
      store: store,
      health: FakeHealthSource(stepsByDay: {'2026-11-08': 1200}),
      clock: () => now,
    );
    await controller.init();
    expect(controller.needsAwakening, isTrue);
    expect(controller.ready, isTrue);

    await controller.awaken(name: ' 하루 ', look: HeroLook.female);
    expect(controller.needsAwakening, isFalse);
    expect(controller.profile.name, '하루');
    expect(controller.profile.look, HeroLook.female);
    expect(controller.history.last.steps, 1200);

    final saved = await store.loadProfile();
    expect(saved!.name, '하루');
    expect(saved.lastSeenLevel, 1);
    expect(controller.pendingLevelUp, isNull);
  });

  test('레벨이 오르면 레벨업이 대기하고, 확인하면 사라진다', () async {
    // 경험치 150(던전 3번) 이면 Lv.2 (Lv.1 → 2 에 100 필요)
    final store = InMemoryRecordStore(
      profile: const PlayerProfile(name: '하루', lastSeenLevel: 1),
      history: [
        DailyRecord(
          date: DateTime(2026, 11, 8),
          dungeonRuns: const [
            DungeonRun(cleared: true),
            DungeonRun(cleared: true),
            DungeonRun(cleared: true),
          ],
        ),
      ],
    );
    final controller = AppController(
      store: store,
      health: FakeHealthSource(granted: false),
      clock: () => now,
    );
    await controller.init();
    expect(controller.pendingLevelUp, (from: 1, to: 2));

    await controller.acknowledgeLevelUp();
    expect(controller.pendingLevelUp, isNull);
    expect((await store.loadProfile())!.lastSeenLevel, 2);
  });

  test('확인한 레벨이 없는 예전 저장본은 연출 없이 지금 레벨부터 센다', () async {
    final controller = AppController.demo(clock: () => now);
    await controller.init();
    expect(controller.pendingLevelUp, isNull);
    expect(controller.profile.lastSeenLevel, controller.player.level.level);
  });

  testWidgets('각성 화면: 소개를 넘기고 이름을 넣어 깨어나면 상태창이 열린다',
      (tester) async {
    final controller = AppController(
      store: InMemoryRecordStore(),
      health: FakeHealthSource(granted: false),
      clock: () => now,
    );
    await tester.pumpWidget(IsekaiRealityApp(controller: controller));
    await controller.init();
    await tester.pump();

    expect(find.text('드디어 찾았다! 너구나, 탑이 고른 각성자.'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('다음'));
      await tester.pump();
    }
    await tester.tap(find.text('좋아!'));
    await tester.pump();

    expect(find.text('당신의 각성'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '하루');
    await tester.pump();
    await tester.ensureVisible(find.text('깨어나기'));
    await tester.tap(find.text('깨어나기'));
    await tester.pump();
    await tester.pump();

    expect(controller.needsAwakening, isFalse);
    expect(find.textContaining('Lv.'), findsOneWidget);
  });
}
