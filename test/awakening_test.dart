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

  testWidgets('각성 화면: 도입 → 정령 고르기 → 이름 → 각성 장면 → 상태창',
      (tester) async {
    // 실제 휴대폰 크기 (430 × 932)
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final controller = AppController(
      store: InMemoryRecordStore(),
      health: FakeHealthSource(granted: false),
      clock: () => now,
    );
    await tester.pumpWidget(IsekaiRealityApp(controller: controller));
    await controller.init();
    await tester.pump();

    await tester.pumpAndSettle();
    expect(find.text('오늘도 별일 없는 하루였어.'), findsOneWidget);
    // 화면을 누르면 다음 대사, 건너뛰기로 정령 고르기까지
    await tester.tapAt(const Offset(200, 600));
    await tester.pumpAndSettle();
    expect(find.text('…어? 화면이 왜 이래?'), findsOneWidget);
    await tester.tap(find.text('건너뛰기 ›'));
    await tester.pumpAndSettle();

    // 정령 고르기: 물의 정령
    expect(find.text('함께할 정령'), findsOneWidget);
    await tester.tap(find.text('물의 정령'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('이 정령과 함께하기'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('이 정령과 함께하기'));
    await tester.pumpAndSettle();

    // 정령 이름: 기본값 '이슬'
    expect(find.text('정령의 이름'), findsOneWidget);
    expect(find.widgetWithText(TextField, '이슬'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('이 이름으로'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('이 이름으로'));
    await tester.pumpAndSettle();

    // 동의: 필수 3개를 체크해야 다음으로
    expect(find.text('시작하기 전에'), findsOneWidget);
    final checks = find.byType(Checkbox);
    expect(checks, findsNWidgets(4));
    await tester.tap(checks.at(0));
    await tester.tap(checks.at(1));
    await tester.tap(checks.at(3));
    await tester.pump();
    await tester.scrollUntilVisible(find.text('동의하고 다음'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('동의하고 다음'));
    await tester.pump();

    expect(find.text('당신의 각성'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '하루');
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('다음'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();

    // 각성 장면: 고른 정령이 함께 있다
    expect(find.textContaining('아르카의 빛을 되찾으러 가자'), findsOneWidget);
    await tester.tap(find.text('깨어나기'));
    await tester.pump();
    await tester.pump();

    expect(controller.needsAwakening, isFalse);
    expect(controller.profile.spiritKind, SpiritKind.water);
    expect(controller.profile.spiritName, '이슬');
    expect(find.textContaining('Lv.'), findsOneWidget);
  });
}
