import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/geo/geo.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/models/player_state.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/location/location_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';

class _Location implements LocationSource {
  final _c = StreamController<LocationFix>.broadcast();
  void emit(LocationFix f) => _c.add(f);
  @override
  Future<bool> requestPermission() async => true;
  @override
  Stream<LocationFix> fixes() => _c.stream;
}

DailyRecord _day(int d,
        {List<DungeonRun> runs = const [],
        int field = 0,
        List<String> bought = const [],
        bool rested = false,
        int? sleep,
        int steps = 0}) =>
    DailyRecord(
      date: DateTime(2026, 11, d),
      dungeonRuns: runs,
      fieldMonstersPurified: field,
      shopPurchases: bought,
      restedAtInn: rested,
      sleepMinutes: sleep,
      steps: steps,
      stepGoal: 8000,
    );

void main() {
  group('정화 결정', () {
    test('던전 정화 3개, 실패 1개, 필드 몬스터 1개 (하루 5마리까지)', () {
      final r = _day(2,
          runs: const [
            DungeonRun(cleared: true),
            DungeonRun(cleared: false),
          ],
          field: 7);
      expect(TownRules.crystalsEarnedOn(r), 3 + 1 + 5);
    });

    test('산 물건 값만큼 빠진다', () {
      final history = [
        _day(2, runs: List.filled(5, const DungeonRun(cleared: true))),
        _day(3, bought: ['bulssiPotion', 'magicLens']),
      ];
      expect(TownRules.crystals(history), 15 - 5 - 6);
    });
  });

  group('잡화상', () {
    final rich = _day(2, runs: List.filled(10, const DungeonRun(cleared: true)));

    test('하루 1개 물건은 다음 날 다시 살 수 있다', () {
      expect(
          TownRules.canBuy([rich, _day(3, bought: ['bulssiPotion'])],
              ShopItem.bulssiPotion),
          PurchaseCheck.limitReached);
      expect(
          TownRules.canBuy(
              [rich, _day(3, bought: ['bulssiPotion']), _day(4)],
              ShopItem.bulssiPotion),
          PurchaseCheck.ok);
    });

    test('여분의 열쇠는 월요일에 시작하는 주마다 1개', () {
      // 2026-11-02 월 ~ 11-08 일, 11-09 월
      final h = [rich, _day(3, bought: ['spareKey']), _day(8)];
      expect(TownRules.canBuy(h, ShopItem.spareKey),
          PurchaseCheck.limitReached);
      expect(TownRules.canBuy([...h, _day(9)], ShopItem.spareKey),
          PurchaseCheck.ok);
    });

    test('결정이 모자라면 살 수 없다, 돋보기는 위치가 있어야 한다', () {
      expect(TownRules.canBuy([_day(2)], ShopItem.bulssiPotion),
          PurchaseCheck.notEnoughCrystals);
      expect(TownRules.canBuy([rich], ShopItem.magicLens, hasLocation: false),
          PurchaseCheck.needsLocation);
    });

    test('여분의 열쇠는 그날 열쇠에 더해지고 다음 날로 넘어간다', () {
      final today = PlayerState.fromHistory(name: '하루', history: [
        _day(2, steps: 2600, bought: ['spareKey']),
      ]);
      expect(today.gauge.keysAvailable, 2);

      final next = PlayerState.fromHistory(name: '하루', history: [
        _day(2, steps: 2600, bought: ['spareKey']),
        _day(3),
      ]);
      expect(next.gauge.keysAvailable, 2);
    });
  });

  group('여관', () {
    test('저녁 6시 ~ 11시에만 체크인', () {
      expect(TownRules.innOpen(DateTime(2026, 11, 8, 17, 59)), isFalse);
      expect(TownRules.innOpen(DateTime(2026, 11, 8, 18)), isTrue);
      expect(TownRules.innOpen(DateTime(2026, 11, 8, 22, 59)), isTrue);
      expect(TownRules.innOpen(DateTime(2026, 11, 8, 23)), isFalse);
    });

    test('체크인한 다음 날 7시간 이상 자면 경험치 +10', () {
      PlayerState of(List<DailyRecord> h) =>
          PlayerState.fromHistory(name: '하루', history: h);

      final good = of([_day(2, rested: true), _day(3, sleep: 430)]);
      expect(good.dailyExp.last.innRest, RuleConstants.innRestExp);

      final short = of([_day(2, rested: true), _day(3, sleep: 380)]);
      expect(short.dailyExp.last.innRest, 0);

      final noRest = of([_day(2), _day(3, sleep: 430)]);
      expect(noRest.dailyExp.last.innRest, 0);

      // 하루를 건너뛰면 보너스 없음
      final gap = of([_day(2, rested: true), _day(4, sleep: 430)]);
      expect(gap.dailyExp.last.innRest, 0);
    });
  });

  group('기록', () {
    Future<AppController> start(DateTime now,
        {List<DailyRecord> history = const [], LocationSource? location}) async {
      final c = AppController(
        store: InMemoryRecordStore(
          profile: const PlayerProfile(name: '하루', stepGoal: 8000),
          history: history,
        ),
        health: FakeHealthSource(stepsByDay: {'2026-11-08': 2600}),
        location: location,
        clock: () => now,
      );
      await c.init();
      return c;
    }

    final rich = DailyRecord(
        date: DateTime(2026, 11, 7),
        stepGoal: 8000,
        dungeonRuns: List.filled(10, const DungeonRun(cleared: true)));

    test('여분의 열쇠를 사면 열쇠가 늘고 결정이 줄어든다', () async {
      final c = await start(DateTime(2026, 11, 8, 14), history: [rich]);
      expect(c.player.gauge.keysAvailable, 1);
      final before = c.player.crystals;

      expect(await c.buy(ShopItem.spareKey), PurchaseCheck.ok);
      expect(c.player.gauge.keysAvailable, 2);
      expect(c.player.crystals, before - 15);
      expect(await c.buy(ShopItem.spareKey), PurchaseCheck.limitReached);
    });

    test('불씨 물약을 마신 날은 던전 스킬이 빨리 찬다', () async {
      final c = await start(DateTime(2026, 11, 8, 14), history: [rich]);
      expect(c.startDungeon()!.skillChargeTicks, RuleConstants.skillChargeTicks);
      await c.buy(ShopItem.bulssiPotion);
      expect(c.startDungeon()!.skillChargeTicks,
          RuleConstants.potionSkillChargeTicks);
    });

    test('마법 돋보기는 지금 위치 주변 안개를 걷는다', () async {
      final loc = _Location();
      final c = await start(DateTime(2026, 11, 8, 14),
          history: [rich], location: loc);
      expect(await c.buy(ShopItem.magicLens), PurchaseCheck.needsLocation);

      loc.emit(const LocationFix(
          point: GeoPoint(37.3100, 126.8300), speedMps: 1.2));
      await Future<void>.delayed(Duration.zero);
      final before = c.revealedCells.length;
      expect(await c.buy(ShopItem.magicLens), PurchaseCheck.ok);
      expect(c.revealedCells.length, greaterThan(before + 4));
    });

    test('여관 체크인은 저녁에만, 하루 한 번', () async {
      final day = await start(DateTime(2026, 11, 8, 14));
      expect(await day.restAtInn(), isFalse);

      final night = await start(DateTime(2026, 11, 8, 21));
      expect(await night.restAtInn(), isTrue);
      expect(night.history.last.restedAtInn, isTrue);
      expect(await night.restAtInn(), isFalse);
    });

    test('대표 칭호는 얻은 칭호만 고를 수 있고 저장된다', () async {
      final store = InMemoryRecordStore(
        profile: const PlayerProfile(name: '하루', stepGoal: 8000),
        history: [rich],
      );
      final c = AppController(
        store: store,
        health: FakeHealthSource(stepsByDay: {'2026-11-08': 2600}),
        clock: () => DateTime(2026, 11, 8, 14),
      );
      await c.init();
      expect(c.player.titles, contains(TitleId.firstSteps));
      expect(await c.setEquippedTitle(TitleId.lakeFriend), isFalse);
      expect(await c.setEquippedTitle(TitleId.firstSteps), isTrue);
      expect(c.equippedTitle, TitleId.firstSteps);
      expect((await store.loadProfile())!.equippedTitle, 'firstSteps');
    });

    test('산 물건과 체크인은 저장했다 되살려도 같다', () {
      final r = DailyRecord(
          date: DateTime(2026, 11, 8),
          shopPurchases: const ['spareKey', 'magicLens'],
          restedAtInn: true);
      final back = DailyRecord.fromJson(r.toJson());
      expect(back.shopPurchases, ['spareKey', 'magicLens']);
      expect(back.restedAtInn, isTrue);
    });
  });

  testWidgets('상태창에서 잡화상에 들어가 물약을 산다', (tester) async {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final c = AppController.demo(clock: () => DateTime(2026, 11, 8, 20));
    await tester.pumpWidget(IsekaiRealityApp(controller: c));
    await c.init();
    await tester.pump();

    final shop = find.text('잡화상');
    await tester.scrollUntilVisible(shop, 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(shop);
    await tester.pumpAndSettle();
    expect(find.textContaining('정화 결정'), findsWidgets);

    final crystals = c.player.crystals;
    await tester.tap(find.text('5개'));
    await tester.pumpAndSettle();
    expect(c.player.crystals, crystals - 5);
    expect(find.text('오늘 샀어요'), findsOneWidget);
  });
}
