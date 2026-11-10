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
import 'package:isekai_reality/data/notify/notifier.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/theme/ornaments.dart';

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
        List<String> goldBought = const [],
        int gold = 0,
        int rests = 0,
        int steps = 0}) =>
    DailyRecord(
      goldPurchases: goldBought,
      gains: gold > 0 ? {Wallet.gold: gold} : const {},
      date: DateTime(2026, 11, d),
      dungeonRuns: runs,
      fieldMonstersPurified: field,
      shopPurchases: bought,
      restsCompleted: rests,
      steps: steps,
      stepGoal: 8000,
    );

void main() {
  group('마석·금화', () {
    test('던전 클리어 3개, 실패 1개, 필드 몬스터 1개 (6마리째부터 절반)', () {
      final r = _day(2,
          runs: const [
            DungeonRun(cleared: true),
            DungeonRun(cleared: false),
          ],
          field: 7);
      expect(TownRules.crystalsEarnedOn(r), 3 + 1 + 6); // 5 + 2×0.5
    });

    test('예전에 결정으로 산 것은 마석으로 쓴 것으로 계산한다 (금화는 0)', () {
      final history = [
        _day(2, runs: List.filled(5, const DungeonRun(cleared: true))),
        _day(3, bought: ['bulssiPotion', 'magicLens']),
      ];
      expect(TownRules.manaStones(history), 15 - 5 - 6);
      expect(TownRules.gold(history), 0);
    });

    test('가격은 예전 결정 가격의 10배 금화', () {
      expect(TownRules.info(ShopItem.healSmall).price, 10);
      expect(TownRules.info(ShopItem.spareKey).price, 150);
      expect(TownRules.info(ShopItem.purifyIncense).price, 60);
      expect(TownRules.info(ShopItem.ironShard).price, 20);
      expect(TownRules.info(ShopItem.twig).price, 10);
    });

    test('금화로 산 것은 금화에서 빠지고, 철 조각은 재료로 들어간다', () {
      final history = [
        _day(2, gold: 100),
        _day(3, goldBought: ['healSmall', 'ironShard', 'ironShard']),
      ];
      expect(TownRules.gold(history), 100 - 10 - 40);
      expect(TownRules.materials(history), {MaterialId.ironShard: 2});
      expect(TownRules.bagCount(history, ShopItem.healSmall), 1);
    });

    test('마석 팔기: 쓴 마석만큼 줄고 금화가 는다', () {
      final history = [
        _day(2, runs: List.filled(2, const DungeonRun(cleared: true))),
        DailyRecord(
            date: DateTime(2026, 11, 3),
            spends: const {Wallet.manaStone: 4},
            gains: const {Wallet.gold: 40, 'ratHide': 2}),
      ];
      expect(TownRules.manaStones(history), 6 - 4);
      expect(TownRules.gold(history), 40);
      expect(TownRules.materials(history), {MaterialId.ratHide: 2});
      expect(TownRules.canSell(history, 2), isTrue);
      expect(TownRules.canSell(history, 3), isFalse);
    });
  });

  group('잡화상', () {
    final rich = _day(2,
        runs: List.filled(10, const DungeonRun(cleared: true)), gold: 1000);

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

    test('금화가 모자라면 살 수 없다', () {
      expect(TownRules.canBuy([_day(2)], ShopItem.bulssiPotion),
          PurchaseCheck.notEnoughCrystals);
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
    test('연속 휴식: 하루라도 비거나 안 쉬면 다시 1부터', () {
      final h = [
        _day(2, rests: 1),
        _day(3, rests: 2),
        _day(4),
        _day(5, rests: 1),
        _day(7, rests: 1), // 6일이 빠짐
      ];
      expect(TownRules.restStreaks(h), [1, 2, 0, 1, 1]);
    });

    test('오늘 아직 안 쉬었으면 어제까지의 연속을 보여 준다', () {
      final h = [_day(2, rests: 1), _day(3, rests: 1), _day(4)];
      expect(TownRules.currentRestStreak(h), 2);
    });

    test('7일 연속 쉬면 경험치 +70과 마석 +5', () {
      final h = List.generate(7, (i) => _day(2 + i, rests: 1));
      final p = PlayerState.fromHistory(name: '하루', history: h);
      expect(p.dailyExp.last.rest, RuleConstants.restBonusExp);
      expect(p.dailyExp.last.restStreak, 70);
      expect(p.dailyExp[2].restStreak, 30); // 3일째
      expect(TownRules.crystals(h), 5);
    });

    test('4시간이 지나야 휴식이 끝난다', () {
      final at = DateTime(2026, 11, 8, 14);
      expect(TownRules.restDone(at, DateTime(2026, 11, 8, 17, 59)), isFalse);
      expect(TownRules.restDone(at, DateTime(2026, 11, 8, 18)), isTrue);
      expect(TownRules.restLeft(at, DateTime(2026, 11, 8, 16)),
          const Duration(hours: 2));
    });
  });

  group('HP · MP 계산', () {
    test('걸음 1,000보마다 최대 HP의 10%', () {
      expect(
          VitalRules.regenHpFromSteps(
              hp: 0, maxHp: 1000, stepsToday: 2500, stepsCounted: 0),
          (200, 2000));
      expect(
          VitalRules.regenHpFromSteps(
              hp: 950, maxHp: 1000, stepsToday: 3100, stepsCounted: 2000),
          (1000, 3000));
    });

    test('MP는 6분에 1씩, 가득 차면 멈춘다', () {
      final t = DateTime(2026, 11, 8, 9);
      expect(VitalRules.regenMp(20, t, t.add(const Duration(hours: 1))).$1, 30);
      expect(VitalRules.regenMp(55, t, t.add(const Duration(hours: 2))).$1,
          RuleConstants.mpMax);
    });

    test('원정: 100m마다 MP 2, 1km마다 10분 (최소 3분)', () {
      expect(VitalRules.expeditionCost(1000), 20);
      expect(VitalRules.expeditionCost(250), 6);
      expect(VitalRules.expeditionOneWay(1000), const Duration(minutes: 10));
      expect(VitalRules.expeditionOneWay(100), const Duration(minutes: 3));
    });

    test('회복 물약은 레벨·하루 개수를 본다', () {
      final rich = _day(2,
        runs: List.filled(10, const DungeonRun(cleared: true)), gold: 1000);
      expect(TownRules.canBuy([rich], ShopItem.heal, level: 2),
          PurchaseCheck.levelTooLow);
      expect(TownRules.canBuy([rich], ShopItem.healSmall, level: 1),
          PurchaseCheck.ok);
      expect(
          TownRules.canBuy([
            _day(2,
                runs: List.filled(10, const DungeonRun(cleared: true)),
                bought: ['healSmall', 'healSmall', 'healSmall'])
          ], ShopItem.healSmall),
          PurchaseCheck.limitReached);
      expect(TownRules.canBuy([rich], ShopItem.manaSmall),
          PurchaseCheck.ok);
    });

    test('가방: 산 것은 쌓이고, 마시고 버리면 준다. 칸이 없으면 못 산다', () {
      final rich = _day(2,
          runs: List.filled(20, const DungeonRun(cleared: true)), gold: 1000);
      final d3 = DailyRecord(
        date: DateTime(2026, 11, 3),
        stepGoal: 8000,
        shopPurchases: const ['healSmall', 'healSmall'],
        itemsUsed: const ['healSmall'],
      );
      expect(TownRules.bagCount([rich, d3], ShopItem.healSmall), 1);
      expect(TownRules.canUse([rich, d3], ShopItem.healSmall), UseCheck.ok);
      expect(TownRules.canUse([rich, d3], ShopItem.healSmall, hpFull: true),
          UseCheck.alreadyFull);
      expect(TownRules.canUse([rich, d3], ShopItem.manaSmall), UseCheck.none);

      // 다음 날 2개 더 사면 3개. 이제 3개 제한은 없다
      final d4 = _day(4, bought: ['healSmall', 'healSmall']);
      expect(TownRules.bagCount([rich, d3, d4], ShopItem.healSmall), 3);
      expect(TownRules.canBuy([rich, d3, d4], ShopItem.healSmall),
          PurchaseCheck.ok);
      expect(TownRules.canBuy([rich, d3, d4], ShopItem.manaSmall, bagRoom: false),
          PurchaseCheck.bagFull);

      // 버린 것은 빠진다
      final d5 = DailyRecord(
          date: DateTime(2026, 11, 5),
          stepGoal: 8000,
          counters: {TownRules.dropKey(ShopItem.healSmall): 2});
      expect(TownRules.bagCount([rich, d3, d4, d5], ShopItem.healSmall), 1);
    });

    test('정령 물약은 마신 날 하루만 효과가 있다', () {
      final rich = _day(2,
        runs: List.filled(10, const DungeonRun(cleared: true)), gold: 1000);
      final d3 = DailyRecord(
        date: DateTime(2026, 11, 3),
        stepGoal: 8000,
        shopPurchases: const ['bulssiPotion', 'bulssiPotion'],
        itemsUsed: const ['bulssiPotion'],
      );
      expect(TownRules.potionActive(d3), isTrue);
      expect(TownRules.canUse([rich, d3], ShopItem.bulssiPotion),
          UseCheck.alreadyActive);
      expect(TownRules.potionActive(_day(4)), isFalse);
      expect(TownRules.canUse([rich, d3, _day(4)], ShopItem.bulssiPotion),
          UseCheck.ok);
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
        dungeonRuns: List.filled(10, const DungeonRun(cleared: true)),
        gains: const {Wallet.gold: 1000});

    test('여분의 열쇠를 사면 열쇠가 늘고 금화가 줄어든다', () async {
      final c = await start(DateTime(2026, 11, 8, 14), history: [rich]);
      expect(c.player.gauge.keysAvailable, 1);
      final before = c.player.gold;

      expect(await c.buy(ShopItem.spareKey), PurchaseCheck.ok);
      expect(c.player.gauge.keysAvailable, 2);
      expect(c.player.gold, before - 150);
      expect(await c.buy(ShopItem.spareKey), PurchaseCheck.limitReached);
    });

    test('불씨 물약을 마신 날은 던전 스킬이 빨리 찬다', () async {
      final c = await start(DateTime(2026, 11, 8, 14), history: [rich]);
      expect(c.startDungeon()!.skillChargeTicks, RuleConstants.skillChargeTicks);
      await c.buy(ShopItem.bulssiPotion);
      // 사기만 하면 가방에 들어가고, 마셔야 효과가 난다
      expect(c.startDungeon()!.skillChargeTicks, RuleConstants.skillChargeTicks);
      expect(c.bagCount(ShopItem.bulssiPotion), 1);
      expect(await c.useItem(ShopItem.bulssiPotion), UseCheck.ok);
      expect(c.bagCount(ShopItem.bulssiPotion), 0);
      expect(c.startDungeon()!.skillChargeTicks,
          RuleConstants.potionSkillChargeTicks);
    });

    test('마법 돋보기는 잡화상에서 뺐다 (11-10, 안개 없앰)', () {
      expect(TownRules.items.map((i) => i.item),
          isNot(contains(ShopItem.magicLens)));
      // 예전에 산 기록의 값은 그대로 계산한다
      expect(TownRules.info(ShopItem.magicLens).price, greaterThan(0));
    });

    test('여관: 언제든 체크인, 4시간 뒤 HP·MP 가득과 휴식 보너스', () async {
      var now = DateTime(2026, 11, 8, 14);
      final c = AppController(
        store: InMemoryRecordStore(
          profile: const PlayerProfile(name: '하루', stepGoal: 8000),
        ),
        health: FakeHealthSource(stepsByDay: {'2026-11-08': 2600}),
        clock: () => now,
      );
      await c.init();
      expect(await c.restAtInn(), isTrue);
      expect(c.resting, isTrue);
      expect(await c.restAtInn(), isFalse); // 이미 쉬는 중

      now = DateTime(2026, 11, 8, 17);
      await c.refreshVitals();
      expect(c.resting, isTrue);
      expect(c.restLeft, const Duration(hours: 1));

      now = DateTime(2026, 11, 8, 18, 1);
      await c.refreshVitals();
      expect(c.resting, isFalse);
      expect(c.justRested, isTrue);
      expect(c.history.last.restsCompleted, 1);
      expect(c.player.dailyExp.last.rest, RuleConstants.restBonusExp);

      // 같은 날 또 쉬어도 된다 (보너스는 하루 한 번)
      expect(await c.restAtInn(), isTrue);
      now = DateTime(2026, 11, 8, 22, 30);
      await c.refreshVitals();
      expect(c.history.last.restsCompleted, 2);
      expect(c.player.dailyExp.last.rest, RuleConstants.restBonusExp);
    });

    test('알림: 여관 체크인 4시간 뒤 예약, 그만 쉬면 취소', () async {
      final now = DateTime(2026, 11, 8, 14);
      final n = FakeNotifier();
      final c = AppController(
        store: InMemoryRecordStore(
          profile: const PlayerProfile(name: '하루', stepGoal: 8000),
        ),
        health: FakeHealthSource(stepsByDay: {'2026-11-08': 2600}),
        notifier: n,
        clock: () => now,
      );
      await c.init();
      await c.restAtInn();
      expect(n.scheduled[NotifyId.rest]?.$1, DateTime(2026, 11, 8, 18));
      await c.stopResting();
      expect(n.scheduled.containsKey(NotifyId.rest), isFalse);
    });

    test('HP는 전투 사이에 이어지고, 0이면 싸울 수 없고, 걸으면 찬다', () async {
      final health = FakeHealthSource(stepsByDay: {'2026-11-08': 2600});
      final c = AppController(
        store: InMemoryRecordStore(
          profile: const PlayerProfile(name: '하루', stepGoal: 8000),
          history: [rich],
        ),
        health: health,
        clock: () => DateTime(2026, 11, 8, 14),
      );
      await c.init();
      expect(c.hp, c.maxHp);

      final spawn = c.todaySpawns.first;
      final battle = c.startFieldBattle(spawn)!;
      battle.playerHp = 0;
      await c.finishFieldBattle(spawn, battle);
      expect(c.hp, 0);
      expect(c.startFieldBattle(spawn), isNull);
      expect(c.startDungeon(), isNull);

      final maxBefore = c.maxHp;
      health.stepsByDay['2026-11-08'] = 4700; // 2,000보 더
      await c.sync();
      // 레벨이 올라 최대 HP가 늘면 그만큼 더 찬다
      expect(c.hp,
          (c.maxHp * 0.1).round() * 2 + (c.maxHp - maxBefore));
      expect(c.startDungeon(), isNotNull);
    });

    test('회복 물약은 가방에 넣어 두었다가 마시면 HP가 찬다', () async {
      final c = await start(DateTime(2026, 11, 8, 14), history: [rich]);
      expect(await c.buy(ShopItem.healSmall), PurchaseCheck.ok);
      expect(c.bagCount(ShopItem.healSmall), 1);
      expect(await c.useItem(ShopItem.healSmall), UseCheck.alreadyFull);
      final spawn = c.todaySpawns.first;
      final battle = c.startFieldBattle(spawn)!;
      battle.playerHp = 0;
      await c.finishFieldBattle(spawn, battle);
      expect(c.hp, 0);
      expect(await c.useItem(ShopItem.healSmall), UseCheck.ok);
      expect(c.hp, (c.maxHp * 0.2).round());
      expect(c.bagCount(ShopItem.healSmall), 0);
      expect(await c.useItem(ShopItem.healSmall), UseCheck.none);
    });

    test('정화의 향: 피운 날은 필드 몬스터 경험치 1.5배', () async {
      final c = await start(DateTime(2026, 11, 8, 14), history: [rich]);
      expect(await c.buy(ShopItem.purifyIncense), PurchaseCheck.ok);
      expect(await c.useItem(ShopItem.purifyIncense), UseCheck.ok);
      expect(c.canUse(ShopItem.purifyIncense), UseCheck.none);
      final spawn = c.todaySpawns.first;
      final b = c.startFieldBattle(spawn)!..runToEnd();
      expect(await c.finishFieldBattle(spawn, b),
          (RuleConstants.fieldMonsterExp * 1.5).round());
      expect(c.player.dailyExp.last.fieldMonster,
          (RuleConstants.fieldMonsterExp * 1.5).round());
    });

    test('원정 나침반: 쓰면 다음 원정 하나만 이동 시간 절반', () async {
      final loc = _Location();
      final c = await start(DateTime(2026, 11, 8, 14),
          history: [rich], location: loc);
      final spawn = c.todaySpawns.first;
      loc.emit(LocationFix(
          point: GeoPoint(spawn.point.lat + 0.009, spawn.point.lng),
          speedMps: 1.2));
      await Future<void>.delayed(Duration.zero);
      final normal = c.planExpedition(spawn).oneWay;

      expect(await c.buy(ShopItem.expeditionCompass), PurchaseCheck.ok);
      expect(await c.useItem(ShopItem.expeditionCompass), UseCheck.ok);
      expect(c.compassReady, isTrue);
      expect(c.planExpedition(spawn).oneWay, normal ~/ 2);

      expect(await c.sendSpirit(spawn), ExpeditionCheck.ok);
      expect(c.compassReady, isFalse);
      final ex = c.expedition!;
      expect(ex.arriveAt.difference(ex.startedAt), normal ~/ 2);
    });

    test('정령 원정: MP로만 거리를 막고, MP를 쓰고, 돌아오면 정화', () async {
      var now = DateTime(2026, 11, 8, 14);
      final loc = _Location();
      final notifier = FakeNotifier();
      final c = AppController(
        store: InMemoryRecordStore(
          profile: const PlayerProfile(name: '하루', stepGoal: 8000),
          history: [rich],
        ),
        health: FakeHealthSource(stepsByDay: {'2026-11-08': 2600}),
        location: loc,
        notifier: notifier,
        clock: () => now,
      );
      await c.init();
      final spawn = c.todaySpawns.first;

      expect(c.planExpedition(spawn).check, ExpeditionCheck.needsLocation);

      // 몬스터 자리에서 400m쯤 떨어진 곳
      final away = GeoPoint(spawn.point.lat + 0.0036, spawn.point.lng);
      loc.emit(LocationFix(point: away, speedMps: 1.2));
      await Future<void>.delayed(Duration.zero);
      final plan = c.planExpedition(spawn);
      expect(plan.check, ExpeditionCheck.ok);
      expect(plan.mpCost, VitalRules.expeditionCost(plan.distanceM));

      final purifiedBefore = c.history.last.fieldMonstersPurified;
      expect(await c.sendSpirit(spawn), ExpeditionCheck.ok);
      expect(notifier.scheduled[NotifyId.expedition]?.$1,
          c.expedition!.returnAt);
      expect(c.mp, c.mpMax - plan.mpCost);
      expect(c.todaySpawns.any((s) => s.id == spawn.id), isFalse);
      expect(await c.sendSpirit(c.todaySpawns.first), ExpeditionCheck.busy);
      // 원정 중에는 정령의 일격을 쓸 수 없다
      expect(c.startDungeon()!.skillDisabled, isTrue);

      now = now.add(plan.oneWay * 2 + const Duration(minutes: 1));
      await c.refreshVitals();
      final ex = c.expedition!;
      expect(ex.finished, isTrue);
      expect(ex.cleared, isTrue);
      expect(c.history.last.fieldMonstersPurified, purifiedBefore + 1);
      await c.acknowledgeExpedition();
      expect(c.expedition, isNull);
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

    // 11-10: 잡화상은 마을 탭에서
    await tester.tap(find.text('마을'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('잡화상').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('금화'), findsWidgets);

    // 마석 1개를 팔면 금화 10
    final gold = c.player.gold;
    final stones = c.player.manaStones;
    await tester.tap(find.text('1개 팔기'));
    await tester.pumpAndSettle();
    expect(c.player.manaStones, stones - 1);
    expect(c.player.gold, gold + 10);

    // 정령 물약 = 예시 모드(Lv.14, 정령과 헤어짐)에서는 펫 간식
    await tester.scrollUntilVisible(find.text('펫 간식'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    final buy = find
        .descendant(
            of: find.ancestor(
                of: find.text('펫 간식'), matching: find.byType(OrnatePanel)),
            matching: find.text('50'))
        .first;
    await tester.ensureVisible(buy);
    await tester.pumpAndSettle();
    await tester.tap(buy);
    await tester.pumpAndSettle();
    expect(c.player.gold, gold + 10 - 50);
    await tester.scrollUntilVisible(
        find.textContaining('다시 살 수 있어요 · '), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('다시 살 수 있어요 · '), findsOneWidget);
  });
}
