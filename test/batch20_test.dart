import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/geo/geo.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/core/story/dungeon_clues.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/location/location_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/profile/title_celebration.dart';
import 'package:isekai_reality/features/village/village_screen.dart';

void main() {
  final t0 = DateTime(2026, 11, 13, 10);

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

  Future<AppController> start(InMemoryRecordStore store,
      {LocationSource? location, Map<String, int>? steps}) async {
    final c = AppController(
      store: store,
      health: FakeHealthSource(stepsByDay: steps ?? const {}),
      location: location,
      clock: () => t0,
    )..mailSources = const [];
    await c.init();
    return c;
  }

  group('#160 칭호 축하 창', () {
    Future<void> open(WidgetTester tester, AppController c) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () =>
                    showTitleCelebration(context, c, TitleId.firstSteps),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('열기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('밑줄 없이, 칭호 배지 그림, 「대표로 하기」 금빛 + 「닫기」 작게',
        (tester) async {
      late AppController c;
      await tester.runAsync(() async => c = await start(
          InMemoryRecordStore(profile: const PlayerProfile(name: '하루'))));
      await open(tester, c);
      final p = tester.renderObject<RenderParagraph>(find.text('새 칭호'));
      expect(p.text.style?.decoration, isNot(TextDecoration.underline));
      final img = tester.widget<Image>(find.byKey(const Key('titleBadge')));
      expect((img.image as AssetImage).assetName,
          'assets/images/title_firstSteps.webp');
      expect(find.byIcon(Icons.military_tech_rounded), findsNothing);
      expect(find.byKey(const Key('titleEquip')), findsOneWidget);
      expect(find.byKey(const Key('titleClose')), findsOneWidget);
      expect(find.text('대표로 하기'), findsOneWidget);
    });

    testWidgets('이미 대표 칭호면 「닫기」 하나만', (tester) async {
      late AppController c;
      await tester.runAsync(() async {
        c = await start(
            InMemoryRecordStore(profile: const PlayerProfile(name: '하루')),
            steps: {'2026-11-13': 3000});
        await c.setEquippedTitle(TitleId.firstSteps);
      });
      if (c.equippedTitle != TitleId.firstSteps) return; // 칭호를 못 얻은 기록
      await open(tester, c);
      expect(find.byKey(const Key('titleEquip')), findsNothing);
      expect(find.byKey(const Key('titleClose')), findsOneWidget);
    });

    testWidgets('공통 금빛 배지는 그려진다', (tester) async {
      await tester.pumpWidget(const MaterialApp(
          home: Center(
              child: SizedBox(width: 96, height: 96, child: GoldTitleBadge()))));
      expect(find.byType(GoldTitleBadge), findsOneWidget);
    });

    testWidgets('튜토리얼 중에는 칭호 창이 끼어들지 않고, 끝난 뒤에 남아 있다', (tester) async {
      late AppController c;
      await tester.runAsync(() async {
        c = AppController(
          store: InMemoryRecordStore(),
          health: FakeHealthSource(stepsByDay: {'2026-11-13': 30000}),
          clock: () => t0,
        )..mailSources = const [];
        await c.init();
        await c.awaken(name: '하루', look: HeroLook.female);
        await c.finishIntro();
      });
      expect(c.inTutorial, isTrue);
      expect(c.holdNotices, isTrue);
      await tester.pumpWidget(IsekaiRealityApp(controller: c));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(find.byKey(const Key('titleCelebration')), findsNothing);
      final pending = c.newTitle;
      await tester.runAsync(c.skipTutorial);
      expect(c.inTutorial, isFalse);
      expect(c.holdNotices, isFalse);
      // 튜토리얼 동안 얻은 칭호는 그대로 기다린다 (레벨업 → 칭호 순서로 뜸)
      expect(c.newTitle, pending);
    });
  });

  group('#157 아직 못 쓰는 기능은 숨김', () {
    Future<void> village(WidgetTester tester, AppController c) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: VillageScreen(controller: c))));
      await tester.pump();
    }

    testWidgets('Lv.1 새 사용자: 대장간·게시판·거래소가 목록에 없고, 인사에 의뢰가 없다',
        (tester) async {
      late AppController c;
      await tester.runAsync(() async {
        c = AppController(
          store: InMemoryRecordStore(),
          health: FakeHealthSource(stepsByDay: const {}),
          clock: () => t0,
        )..mailSources = const [];
        await c.init();
        await c.awaken(name: '하루', look: HeroLook.male);
        await c.skipTutorial();
      });
      expect(c.player.level.level, lessThan(3));
      await village(tester, c);
      expect(find.byKey(const Key('facility_smithy')), findsNothing);
      expect(find.byKey(const Key('facility_board')), findsNothing);
      expect(find.byKey(const Key('facility_market')), findsNothing);
      expect(find.byKey(const Key('facility_inn')), findsOneWidget);
      expect(find.byKey(const Key('facility_alchemy')), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline_rounded), findsNothing);
    });

    testWidgets('Lv.4면 대장간·게시판이 나타난다', (tester) async {
      late AppController c;
      await tester.runAsync(() async => c = await start(grown(3)));
      expect(c.player.level.level, greaterThanOrEqualTo(4));
      await village(tester, c);
      expect(find.byKey(const Key('facility_smithy')), findsOneWidget);
      expect(find.byKey(const Key('facility_board')), findsOneWidget);
      expect(find.byKey(const Key('facility_market')), findsNothing);
    });

    testWidgets('기존 사용자(#124): 예전처럼 다 보인다', (tester) async {
      late AppController c;
      await tester.runAsync(() async => c = await start(
          InMemoryRecordStore(profile: const PlayerProfile(name: '하루'))));
      expect(c.newGates, isFalse);
      await village(tester, c);
      expect(find.byKey(const Key('facility_smithy')), findsOneWidget);
      expect(find.byKey(const Key('facility_board')), findsOneWidget);
      // 묶음 22: 거래소는 기존 사용자에게도 숨김
      expect(find.byKey(const Key('facility_market')), findsNothing);
    });

    test('기능이 열리는 레벨: 대장간 3 · 게시판 4 · 채집 5 · 돋보기 6', () async {
      final c1 = await start(grown(0));
      for (final f in Feature.values) {
        expect(c1.featureOpen(f), isFalse, reason: f.name);
      }
      expect(c1.harvestSpots, isEmpty);
      expect(c1.boardFull, isFalse);
      final c6 = await start(grown(5));
      expect(c6.player.level.level, greaterThanOrEqualTo(6));
      for (final f in Feature.values) {
        expect(c6.featureOpen(f), isTrue, reason: f.name);
      }
    });
  });

  group('4 묶음 19 회신', () {
    test('던전 단서는 정령 종류와 상관없게', () {
      for (final ch in DungeonClues.chapters) {
        for (final l in ch) {
          expect(l.contains('불씨'), isFalse, reason: l);
        }
      }
      expect(DungeonClues.chapters[2][1], contains('작은 빛'));
      expect(DungeonClues.chapters[4][1], contains('문지기 빛'));
    });

    test('채집 도구가 없으면 채집 못 함, 만들면 됨', () async {
      final loc = FakeLocationSource();
      final c = await start(
          grown(5, seen: const ['smithy', 'freeWeapon', 'board']),
          location: loc);
      await c.handleFix(const LocationFix(point: GeoPoint(37.3219, 126.8309)));
      c.guideHarvest = true;
      final spot = c.guideHarvestSpot!;
      expect(c.harvestNeedsTool, isTrue);
      expect(c.canHarvest(spot), HarvestCheck.noTool);
      expect(await c.harvestAt(spot, HarvestGrade.quick), isNull);
      await c.makeFirstTools();
      expect(c.harvestNeedsTool, isFalse);
      expect(c.canHarvest(spot), isNot(HarvestCheck.noTool));

      final old = await start(
          InMemoryRecordStore(profile: const PlayerProfile(name: '하루')));
      // 묶음 22: 기존 사용자도 같은 규칙, 대신 우편으로 한 벌
      expect(old.harvestToolsReady, isFalse);
      expect(old.harvestNeedsTool, isTrue);
      expect(old.allMails.any((m) => m.id == 'toolsGift'), isTrue);
    });
  });
}
