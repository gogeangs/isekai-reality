import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/bulssi/bulssi_bubble.dart';
import 'package:isekai_reality/features/codex/codex_screen.dart';
import 'package:isekai_reality/features/village/village_screen.dart';

void main() {
  final t0 = DateTime(2026, 11, 13, 10);

  Future<AppController> start(InMemoryRecordStore store) async {
    final c = AppController(
      store: store,
      health: FakeHealthSource(stepsByDay: const {}),
      clock: () => t0,
    )..mailSources = const [];
    await c.init();
    return c;
  }

  InMemoryRecordStore grown(int days, {List<String> seen = const []}) =>
      InMemoryRecordStore(
        profile: const PlayerProfile(name: '하루', lastSeenLevel: 99),
        history: [
          for (var i = days; i >= 1; i--)
            DailyRecord(
              date: DateTime(2026, 11, 13 - i),
              dungeonRuns: List.filled(4, const DungeonRun(cleared: true)),
            ),
        ],
        json: {
          'tutorial': {'step': TutorialStep.done.index},
          'gates': {'legacy': false, 'seen': seen},
        },
      );

  group('3 채집 도구 규칙 하나로', () {
    test('도구가 없는 기존 사용자: 우편으로 한 벌, 받으면 채집 가능, 다시 보내지 않음',
        () async {
      final store =
          InMemoryRecordStore(profile: const PlayerProfile(name: '하루'));
      final c = await start(store);
      expect(c.harvestNeedsTool, isTrue);
      final gift = c.giftMails.singleWhere((m) => m.id == 'toolsGift');
      expect(gift.gifts, {'tools': 1});
      final got = await c.claimMail(gift.id);
      expect(got, contains('채집 도구 한 벌'));
      expect(c.harvestToolsReady, isTrue);
      expect(c.harvestNeedsTool, isFalse);
      await c.refreshVitals();
      expect(c.allMails.where((m) => m.id == 'toolsGift').length, 1);
      // 다시 켜도 도구는 그대로
      final again = await start(store);
      expect(again.harvestToolsReady, isTrue);
    });

    test('도구를 이미 가진 기존 사용자는 우편을 받지 않고, 도구·재료 그대로', () async {
      final c = await start(InMemoryRecordStore(
        profile: const PlayerProfile(name: '하루'),
        json: {
          'harvest': {
            'granted': true,
            'tools': {'sickle': 7},
            'total': 12,
          },
        },
      ));
      expect(c.harvestNeedsTool, isFalse);
      expect(c.allMails.any((m) => m.id == 'toolsGift'), isFalse);
      expect(c.toolDurability(HarvestTool.sickle), 7);
      expect(c.harvestTotal, 12);
    });

    test('새로 시작한 사람은 우편 없이 대장간 무료 한 벌', () async {
      final c = await start(grown(5, seen: const ['smithy', 'freeWeapon', 'board']));
      expect(c.harvestNeedsTool, isTrue);
      expect(c.allMails.any((m) => m.id == 'toolsGift'), isFalse);
      expect(await c.makeFirstTools(), isTrue);
      expect(c.harvestNeedsTool, isFalse);
    });
  });

  test('2 「새로 열렸어요」는 한 번만 (껐다 켜도)', () async {
    final store = grown(2);
    final c = await start(store);
    expect(c.pendingFeatureIntro, Feature.smithy);
    expect(c.featureAnnounced(Feature.smithy), isFalse);
    await c.markFeatureAnnounced(Feature.smithy);
    final again = await start(store);
    expect(again.featureAnnounced(Feature.smithy), isTrue);
    // 안내 자체는 아직 남아 있다 (남은 단계부터)
    expect(again.pendingFeatureIntro, Feature.smithy);
  });

  group('1 마을·도감 정령 배지', () {
    void phone(WidgetTester tester) {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
    }

    testWidgets('마을: 위쪽 줄 대신 배지 + 말풍선, 접힌 뒤 배지를 누르면 다시', (tester) async {
      phone(tester);
      late AppController c;
      await tester.runAsync(() async => c = await start(
          InMemoryRecordStore(profile: const PlayerProfile(name: '하루'))));
      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: VillageScreen(controller: c))));
      await tester.pump();
      expect(find.byType(BulssiLine), findsNothing);
      expect(find.byKey(const Key('spiritBadge')), findsOneWidget);
      expect(find.byKey(const Key('spiritBubble')), findsOneWidget);
      await tester.pump(const Duration(seconds: 9));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('spiritBubble')), findsNothing);
      await tester.tap(find.byKey(const Key('spiritBadge')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('spiritBubble')), findsOneWidget);
      // 칸에 다시 들어오면 다시 말한다
      await tester.pump(const Duration(seconds: 9));
      await tester.pump(const Duration(milliseconds: 300));
      spiritTabVisits.value++;
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('spiritBubble')), findsOneWidget);
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('도감도 배지', (tester) async {
      phone(tester);
      await tester.pumpWidget(const MaterialApp(
          home: Scaffold(
              body: CodexScreen(purifiedMonsters: {}, huntCounts: {}))));
      await tester.pump();
      expect(find.byType(BulssiLine), findsNothing);
      expect(find.byType(SpiritBadgeRow), findsOneWidget);
      await tester.pump(const Duration(seconds: 9));
    });
  });

  testWidgets('4 거래소는 기존 사용자에게도 숨김', (tester) async {
    late AppController c;
    await tester.runAsync(() async => c = await start(
        InMemoryRecordStore(profile: const PlayerProfile(name: '하루'))));
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: VillageScreen(controller: c))));
    await tester.pump();
    expect(find.byKey(const Key('facility_market')), findsNothing);
    expect(find.byKey(const Key('facility_smithy')), findsOneWidget);
    await tester.pump(const Duration(seconds: 9));
  });
}
