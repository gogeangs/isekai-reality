import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/models/vitals.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';

/// 걸음 읽기를 원하는 때까지 붙잡아 둘 수 있는 건강 앱
class _GateHealth implements HealthSource {
  Completer<void>? gate;
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<int> stepsBetween(DateTime start, DateTime end) async {
    final g = gate;
    if (g != null) await g.future;
    return 4321;
  }
}

void main() {
  final t0 = DateTime(2026, 11, 14, 10);

  Expedition expedition(
          {required Duration arriveIn,
          required Duration returnIn,
          bool? cleared,
          bool? back}) =>
      Expedition(
        spawnId: 'test-spawn',
        monster: MonsterId.ashSlime.name,
        lat: 37.3219,
        lng: 126.8309,
        distanceM: 300,
        mpCost: 3,
        startedAt: t0.subtract(const Duration(minutes: 1)),
        arriveAt: t0.add(arriveIn),
        returnAt: t0.add(returnIn),
        cleared: cleared,
        back: back,
      );

  /// 기존 사용자 (Lv.10쯤, 마석 넉넉)
  InMemoryRecordStore veteran() => InMemoryRecordStore(
        profile: const PlayerProfile(name: '하루'),
        history: [
          DailyRecord(
            date: DateTime(2026, 11, 13),
            gains: const {Wallet.exp: 2500, Wallet.manaStone: 40},
          ),
        ],
      );

  group('#167 원정 보상이 걸음 읽기에 덮이지 않는다', () {
    test('걸음 읽기가 늦게 끝나는 사이 바로 돌아오기 → 마석·결과 기록이 남는다', () async {
      var now = t0;
      final store = veteran();
      await store.saveVitals(Vitals(expeditions: [
        expedition(
            arriveIn: const Duration(minutes: 5),
            returnIn: const Duration(minutes: 10)),
      ]));
      final health = _GateHealth();
      final c = AppController(store: store, health: health, clock: () => now)
        ..mailSources = const [];
      await c.init();
      final ex = c.activeExpeditions.single;
      final exp0 = c.player.totalExp;
      final mana0 = c.player.manaStones;
      final cost = c.rushCost(ex);

      health.gate = Completer<void>();
      final syncing = c.sync(); // 걸음 읽기에서 멈춰 있다
      await Future<void>.delayed(Duration.zero);
      now = t0.add(const Duration(minutes: 1));
      expect(await c.rushExpedition(ex), isTrue);
      final done = c.finishedExpeditions.single;
      health.gate!.complete();
      await syncing;

      final today = c.player.today!;
      expect(today.steps, 4321); // 걸음은 합쳐지고
      expect(today.spends[Wallet.manaStone], cost); // 마석 쓴 기록도 남는다
      expect(c.player.manaStones, mana0 - cost + (done.reward[Wallet.manaStone] ?? 0));
      if (done.cleared == true) {
        expect(today.purifiedSpawnIds, contains('test-spawn'));
        expect(c.player.totalExp, exp0 + (done.reward['exp'] ?? 0));
      } else if (done.escaped) {
        expect(today.fledSpawnIds, contains('test-spawn'));
      }
    });

    test('기록 쓰기는 한 줄로: 동시에 고쳐도 둘 다 남는다', () async {
      final c = AppController(
        store: veteran(),
        health: FakeHealthSource(stepsByDay: const {}),
        clock: () => t0,
      )..mailSources = const [];
      await c.init();
      final gold0 = c.player.gold;
      await Future.wait([
        c.sellManaStones(1),
        c.sellManaStones(1),
      ]);
      expect(c.player.gold, greaterThan(gold0));
      expect(c.player.today!.spends[Wallet.manaStone], 2);
    });
  });

  group('#172 결과는 도착할 때, 결과 카드는 돌아온 뒤', () {
    test('도착 → 결과·보상 저장(돌아오는 중), 돌아옴 → 결과 카드, 한 번만', () async {
      var now = t0;
      final store = veteran();
      await store.saveVitals(Vitals(expeditions: [
        expedition(
            arriveIn: const Duration(minutes: 5),
            returnIn: const Duration(minutes: 10)),
      ]));
      final c = AppController(
          store: store,
          health: FakeHealthSource(stepsByDay: const {}),
          clock: () => now)
        ..mailSources = const [];
      await c.init();
      expect(c.activeExpeditions.single.decided, isFalse);

      now = t0.add(const Duration(minutes: 6)); // 도착
      await c.refreshVitals();
      final ex = c.activeExpeditions.single; // 아직 돌아오는 중
      expect(ex.decided, isTrue);
      expect(c.finishedExpeditions, isEmpty);
      final exp1 = c.player.totalExp;
      if (ex.cleared == true) {
        expect(c.player.today!.purifiedSpawnIds, contains('test-spawn'));
        expect(c.todaySpawns.any((s) => s.id == 'test-spawn'), isFalse);
      }

      now = t0.add(const Duration(minutes: 11)); // 돌아옴
      await c.refreshVitals();
      expect(c.activeExpeditions, isEmpty);
      expect(c.finishedExpeditions.single.cleared, ex.cleared);
      expect(c.player.totalExp, exp1); // 다시 정하지 않는다
      await c.acknowledgeExpedition();
      expect(c.finishedExpeditions, isEmpty);
    });

    test('바로 돌아오기로 도착·돌아옴이 한꺼번에 지나도 한 번만', () async {
      var now = t0;
      final store = veteran();
      await store.saveVitals(Vitals(expeditions: [
        expedition(
            arriveIn: const Duration(minutes: 5),
            returnIn: const Duration(minutes: 10)),
      ]));
      final c = AppController(
          store: store,
          health: FakeHealthSource(stepsByDay: const {}),
          clock: () => now)
        ..mailSources = const [];
      await c.init();
      final exp0 = c.player.totalExp;
      expect(await c.rushExpedition(c.activeExpeditions.single), isTrue);
      final done = c.finishedExpeditions.single;
      expect(c.player.totalExp, exp0 + (done.reward['exp'] ?? 0));
      await c.refreshVitals();
      expect(c.player.totalExp, exp0 + (done.reward['exp'] ?? 0));
    });

    test('예전 기록: 결과가 있는 원정은 돌아온 것, 도착했지만 결과 없는 원정은 열 때 정함',
        () async {
      final old = Expedition.fromJson({
        ...expedition(
                arriveIn: const Duration(minutes: -5),
                returnIn: const Duration(minutes: -1),
                cleared: true)
            .toJson()
          ..remove('back'),
      });
      expect(old.back, isTrue);
      expect(old.finished, isTrue);

      final store = veteran();
      final arrivedJson = expedition(
              arriveIn: const Duration(minutes: -2),
              returnIn: const Duration(minutes: 3))
          .toJson()
        ..remove('back');
      await store.saveVitals(Vitals(expeditions: [
        Expedition.fromJson(arrivedJson),
      ]));
      final c = AppController(
          store: store,
          health: FakeHealthSource(stepsByDay: const {}),
          clock: () => t0)
        ..mailSources = const [];
      await c.init();
      final ex = c.activeExpeditions.single;
      expect(ex.decided, isTrue); // 열 때 바로 정함
      expect(ex.back, isFalse); // 결과 카드는 돌아온 뒤
    });

    test('튜토리얼 원정: 도착해도 튜토리얼은 돌아올 때 끝 (Lv.2)', () async {
      var now = t0;
      final c = AppController(
        store: InMemoryRecordStore(),
        health: FakeHealthSource(stepsByDay: const {}),
        clock: () => now,
      )..mailSources = const [];
      await c.init();
      await c.awaken(name: '하루', look: HeroLook.male);
      await c.finishIntro();
      final first = c.tutorialSpawn!;
      final battle = c.startFieldBattle(first)!;
      battle.runToEnd(useSkills: true);
      await c.finishFieldBattle(first, battle);
      await c.tutorialBagSeen();
      expect(await c.sendSpirit(c.tutorialSpawn!), ExpeditionCheck.ok);
      now = t0.add(const Duration(minutes: 3)); // 도착(편도 2분), 돌아오기 전
      await c.refreshVitals();
      expect(c.activeExpeditions.single.decided, isTrue);
      expect(c.inTutorial, isTrue);
      now = t0.add(const Duration(minutes: 5));
      await c.refreshVitals();
      expect(c.inTutorial, isFalse);
      expect(c.player.level.level, 2);
    });
  });

  test('#168 하늘 슬라임은 도감 첫 칸, 칭호 개수는 그대로', () {
    final codex = Monsters.codex;
    expect(codex.first.id, MonsterId.slime);
    expect(codex.length, Monsters.all.length + 1);
    expect(Monsters.all.any((m) => m.id == MonsterId.slime), isFalse);
    expect(Monsters.inCodex(MonsterId.slime), isTrue);
    expect(Monsters.inCodex(MonsterId.roughWaterSpirit), isFalse);
    expect(Monsters.info(MonsterId.slime).habitat, '처음 만나는 곳');
  });
}
