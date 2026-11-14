import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/geo/geo.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/models/vitals.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/tutorial/feature_tour.dart';
import 'package:isekai_reality/features/tutorial/targets.dart';

void main() {
  final t0 = DateTime(2026, 11, 13, 10);
  const home = GeoPoint(37.3219, 126.8309);

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
      {DateTime Function()? clock}) async {
    final c = AppController(
      store: store,
      health: FakeHealthSource(stepsByDay: const {}),
      clock: clock ?? () => t0,
    )..mailSources = const [];
    await c.init();
    return c;
  }

  group('#179 안내 몬스터 자리', () {
    test('안내가 시작될 때 한 번 정하고, 걸어도·다시 켜도 그대로 (25~40m)', () async {
      final store = grown(3, seen: const ['stats', 'smithy', 'freeWeapon']);
      final c = await start(store);
      expect(c.pendingFeatureIntro, Feature.board);
      await c.handleFix(const LocationFix(point: home));
      c.guideHunt = true;
      final p = c.guideSpawn!.point;
      final d = p.distanceTo(home);
      expect(d, inInclusiveRange(24, 41));
      await c.handleFix(
          const LocationFix(point: GeoPoint(37.3225, 126.8315), speedMps: 1));
      expect(c.guideSpawn!.point.lat, p.lat);
      expect(c.guideSpawn!.point.lng, p.lng);
      expect(c.guideMapTarget?.id, AppController.guideHuntId);

      final again = await start(store);
      again.guideHunt = true;
      expect(again.guideSpawn!.point.lat, p.lat);
    });

    test('원정 목표와 겹치지 않는 쪽으로', () async {
      // 바로 북쪽 32m 에 원정 목표가 있다
      final north = GeoPoint(home.lat + 32 / 111320, home.lng);
      final store = grown(3, seen: const ['stats', 'smithy', 'freeWeapon']);
      await store.saveVitals(Vitals(expeditions: [
        Expedition(
          spawnId: 'x',
          monster: MonsterId.ashSlime.name,
          lat: north.lat,
          lng: north.lng,
          distanceM: 32,
          mpCost: 1,
          startedAt: t0,
          arriveAt: t0.add(const Duration(minutes: 30)),
          returnAt: t0.add(const Duration(minutes: 60)),
        ),
      ]));
      final c = await start(store);
      await c.handleFix(const LocationFix(point: home));
      c.guideHunt = true;
      final p = c.guideSpawn!.point;
      expect(p.distanceTo(north), greaterThanOrEqualTo(22));
      expect(p.distanceTo(home), inInclusiveRange(24, 41));
    });

    test('튜토리얼 첫 몬스터도 처음 자리에 고정', () async {
      final c = AppController(
        store: InMemoryRecordStore(),
        health: FakeHealthSource(stepsByDay: const {}),
        clock: () => t0,
      )..mailSources = const [];
      await c.init();
      await c.awaken(name: '하루', look: HeroLook.male);
      await c.finishIntro();
      await c.handleFix(const LocationFix(point: home));
      final p = c.tutorialSpawn!.point;
      await c.handleFix(
          const LocationFix(point: GeoPoint(37.3230, 126.8320), speedMps: 1));
      expect(c.tutorialSpawn!.point.lat, p.lat);
      expect(c.tutorialSpawn!.point.lng, p.lng);
    });
  });

  group('#173 안내 중 스크롤', () {
    testWidgets('어둠막 위에서 끌면 아래 목록이 굴러가고, 누르기는 막힌다', (tester) async {
      tester.view.physicalSize = const Size(750, 1334);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final scroll = ScrollController();
      var tapped = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Stack(children: [
          ListView(controller: scroll, children: [
            for (var i = 0; i < 60; i++)
              ListTile(title: Text('줄 $i'), onTap: () => tapped++),
          ]),
          const HoleSpotlight(hole: Rect.fromLTWH(20, 20, 100, 40)),
        ])),
      ));
      await tester.pump();
      await tester.dragFrom(const Offset(200, 500), const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 500));
      expect(scroll.offset, greaterThan(100));
      await tester.tapAt(const Offset(200, 400));
      await tester.pump();
      expect(tapped, 0);
    });

    for (final (label, size, dpr) in const [
      ('작은 iPhone', Size(750, 1334), 2.0),
      ('Android', Size(1080, 2400), 2.625),
    ]) {
      testWidgets('$label: 무기를 고르면 「만들기 (무료)」가 화면 안에 보이고 눌린다',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = dpr;
        tester.view.padding = FakeViewPadding(bottom: 34 * dpr);
        addTearDown(tester.view.reset);
        final screen = size / dpr;
        late AppController c;
        await tester.runAsync(() async => c = await start(grown(2)));
        expect(c.pendingFeatureIntro, Feature.smithy);
        await tester.pumpWidget(IsekaiRealityApp(controller: c));
        Future<void> settle() async {
          for (var i = 0; i < 8; i++) {
            await tester.pump(const Duration(milliseconds: 200));
          }
        }

        await settle();
        await tester.tap(find.byKey(const Key('tourButton')));
        await settle();
        await tester.tapAt(rectOf(tutorialNavKeys[3])!.center);
        await settle();
        Scrollable.ensureVisible(
            tester.element(find.byKey(const Key('facility_smithy'))),
            alignment: 0.5);
        await settle();
        await tester.tap(find.byKey(const Key('facility_smithy')));
        await settle();
        Scrollable.ensureVisible(
            tester.element(find.byKey(const Key('firstWeapon_ironSpear'))),
            alignment: 0.5);
        await settle();
        await tester.tap(find.byKey(const Key('firstWeapon_ironSpear')));
        await settle();
        await settle();
        final craft =
            tester.getRect(find.byKey(const Key('firstWeaponCraft')));
        expect(craft.top, greaterThanOrEqualTo(0));
        expect(craft.bottom, lessThanOrEqualTo(screen.height - 34));
        await tester.tap(find.byKey(const Key('firstWeaponCraft')),
            warnIfMissed: false);
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)));
        await settle();
        expect(find.byKey(const Key('equipNow')), findsOneWidget);
        await tester.pump(const Duration(seconds: 9));
      });
    }
  });
}
