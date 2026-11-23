// 개발용: 기록 날 수(history)에 따라 지도 · 탭 옮기기가 얼마나 무거워지는지 잰다.
// flutter test test/tool/perf_history.dart  (CI 대상 아님)
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/geo/geo.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/models/pet_state.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';

const home = GeoPoint(37.3219, 126.8309);

Future<AppController> account(int days, DateTime Function() clock) async {
  final last = clock();
  final hist = [
    for (var d = days - 1; d >= 0; d--)
      DailyRecord(
        date: DateTime(last.year, last.month, last.day - d),
        steps: 7000 + (d * 311) % 5000,
        stepsAfter8pm: 1200,
        stepsMorning: 1500,
        dungeonRuns: const [DungeonRun(cleared: true), DungeonRun(cleared: true), DungeonRun(cleared: false)],
        fieldMonstersPurified: 25,
        questsCompleted: 4,
        purifiedMonsterIds: [for (var k = 0; k < 25; k++) MonsterId.values[(k * 7 + d) % 40].name],
        purifiedSpawnIds: [for (var k = 0; k < 25; k++) 'sp$d-$k'],
        huntCounts: {for (var k = 0; k < 10; k++) MonsterId.values[k].name: 2},
        gains: {
          'exp': d == days - 1 ? LevelRules.totalExpToReach(22) : 400,
          'gold': 900,
          'herb': 6,
          'slimeJelly': 4,
          'ironOre': 3,
        },
        spends: const {'gold': 300, 'herb': 2},
        counters: const {'expeditionWin': 3, 'skySoldier': 1, 'board:daily': 3},
      ),
  ];
  final store = InMemoryRecordStore(
    profile: const PlayerProfile(name: '하루', spiritName: '불씨', spiritKind: SpiritKind.water, lastSeenLevel: 99),
    history: hist,
    json: {
      'tutorial': {'step': TutorialStep.done.index},
      'gates': {'legacy': false, 'v28': true, 'seen': [for (final f in Feature.values) f.name]},
      'jobs': {'awakened': true, 'v57': true, 'v31': true, 'main': 'warrior', 'owned': ['warrior']},
      'pets': PetState(
        pets: [Pet(uid: 'p1', species: PetSpecies.owl, name: '부엉', bornAt: DateTime(2026, 11, 1))],
        companion: 'p1',
        firstPet: 'p1',
        firstSpiritName: '불씨',
        farewellAt: DateTime(2026, 11, 2),
      ).toJson(),
    },
  );
  final c = AppController(store: store, health: FakeHealthSource(stepsByDay: const {}), clock: clock)
    ..mailSources = const [];
  await c.init();
  return c;
}

void main() {
  for (final days in [1, 10, 25, 45]) {
    testWidgets('history $days', (tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      var now = DateTime(2026, 11, 23, 10);
      late AppController c;
      await tester.runAsync(() async {
        c = await account(days, () => now);
        await c.handleFix(const LocationFix(point: home));
      });
      final sw = Stopwatch()..start();
      for (var i = 0; i < 200; i++) {
        c.player;
      }
      final playerUs = sw.elapsedMicroseconds / 200;
      var frames = 0;
      SchedulerBinding.instance.addPersistentFrameCallback((_) => frames++);
      await tester.pumpWidget(IsekaiRealityApp(controller: c));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      // 걷기 20초 (1초마다 위치)
      frames = 0;
      var pumpMs = 0;
      for (var k = 0; k < 20; k++) {
        await tester.runAsync(() async {
          now = now.add(const Duration(seconds: 1));
          await c.handleFix(LocationFix(point: GeoPoint(home.lat + k * 0.0000125, home.lng)));
        });
        final p = Stopwatch()..start();
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        pumpMs += p.elapsedMilliseconds;
      }
      final walk = pumpMs;
      // 탭 옮기기
      final t0 = Stopwatch()..start();
      for (final t in ['상태', '가방', '마을', '지도', '상태', '지도']) {
        final f = find.text(t);
        if (f.evaluate().isEmpty) continue;
        await tester.tap(f.last, warnIfMissed: false);
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }
      // ignore: avoid_print
      print('HIST days=$days level=${c.player.level.level} player=${playerUs.toStringAsFixed(0)}us walk20s=${walk}ms frames=$frames tabs=${t0.elapsedMilliseconds}ms');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  }
}
