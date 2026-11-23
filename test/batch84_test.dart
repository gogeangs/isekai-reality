import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/geo/geo.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/models/pet_state.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/codex/codex_screen.dart';
import 'package:isekai_reality/features/town/bag_tab.dart';
import 'package:isekai_reality/features/village/board_screen.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'support/village_seed.dart';

/// 묶음 84: 느려짐(#400) · 숨은 알(#397) · 하늘 돌 값(#398) · 도감 · 상태 · 게시판 정리
const _home = GeoPoint(37.3219, 126.8309);

/// [days] 날 기록이 있는 계정 (날마다 던전 · 사냥 · 재료)
Future<AppController> longAccount(int days, DateTime Function() clock, {Map<String, dynamic> more = const {}}) async {
  final last = clock();
  final store = InMemoryRecordStore(
    profile: const PlayerProfile(name: '하루', spiritName: '불씨', spiritKind: SpiritKind.water, lastSeenLevel: 99),
    history: [
      for (var d = days - 1; d >= 0; d--)
        DailyRecord(
          date: DateTime(last.year, last.month, last.day - d),
          steps: 7000,
          dungeonRuns: const [DungeonRun(cleared: true), DungeonRun(cleared: true)],
          fieldMonstersPurified: 20,
          purifiedMonsterIds: [for (var k = 0; k < 20; k++) MonsterId.values[(k * 7 + d) % 40].name],
          gains: {'exp': d == days - 1 ? LevelRules.totalExpToReach(20) : 300, 'gold': 800, 'herb': 5},
          counters: const {'expeditionWin': 2},
        ),
    ],
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
      ...more,
    },
  );
  final c = AppController(store: store, health: FakeHealthSource(stepsByDay: const {}), clock: clock)
    ..mailSources = const [];
  await c.init();
  return c;
}

void main() {
  group('#400 느려짐', () {
    test('내 상태는 기록이 바뀔 때만 다시 셈 (같은 기록이면 같은 값)', () async {
      var now = DateTime(2026, 11, 23, 10);
      final c = await longAccount(30, () => now);
      final p = c.player;
      final n = c.playerBuilds;
      for (var i = 0; i < 500; i++) {
        expect(identical(c.player, p), isTrue);
      }
      expect(c.playerBuilds, n);
      // 기록이 바뀌면 새로 셈
      final gold = p.gold;
      await c.store.upsert(c.history.last.copyWith(gains: DailyRecord.addCounts(c.history.last.gains, {'gold': 77})));
      await c.sync();
      expect(c.player.gold, gold + 77);
      expect(c.playerBuilds, greaterThan(n));
    });

    testWidgets('지도에 가만히 · 걸을 때 내 상태를 다시 세지 않음 · 알림은 위치마다 한 번쯤', (tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      var now = DateTime(2026, 11, 23, 10);
      late AppController c;
      await tester.runAsync(() async {
        c = await longAccount(30, () => now);
        await c.handleFix(const LocationFix(point: _home));
      });
      var notes = 0;
      c.addListener(() => notes++);
      await tester.pumpWidget(IsekaiRealityApp(controller: c));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final builds = c.playerBuilds;
      notes = 0;
      for (var i = 0; i < 100; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      // 가만히 10초: 다시 셈 없음 · 알림 거의 없음
      expect(c.playerBuilds, builds);
      expect(notes, lessThanOrEqualTo(3));
      // 1초마다 위치 10번: 알림은 위치마다 몇 번 안 됨
      notes = 0;
      for (var k = 0; k < 10; k++) {
        await tester.runAsync(() async {
          now = now.add(const Duration(seconds: 1));
          await c.handleFix(LocationFix(point: GeoPoint(_home.lat + k * 0.0000125, _home.lng)));
        });
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }
      expect(notes, lessThanOrEqualTo(30));
      expect(c.playerBuilds - builds, lessThanOrEqualTo(10));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('#397 이별 전 숨은 알', () {
    Future<AppController> withEgg({required bool farewell}) => startVillage(9,
        farewell: farewell,
        more: farewell
            ? null
            : {
                'pets': PetState(
                  eggs: const [PetEgg(id: 'egg1', source: 'field', grade: EggGrade.rare)],
                  firstEggFound: true,
                ).toJson(),
              });

    test('이별 전: 가방 · 부화장 · 거래소 · 칸 수 어디에도 안 보임', () async {
      final c = await withEgg(farewell: false);
      expect(c.pets.eggs, hasLength(1));
      expect(c.bagEggs, isEmpty);
      expect(bagEntries(c).whereType<EggEntry>(), isEmpty);
      expect(c.marketOwn(MarketKind.egg), isEmpty);
      expect(c.takeNewEgg(), isFalse);
    });

    test('이별 뒤: 가방에 보임', () async {
      final c = await startVillage(9,
          farewell: false,
          more: {
            'pets': PetState(
              eggs: const [PetEgg(id: 'egg1', source: 'field', grade: EggGrade.rare)],
              firstEggFound: true,
              farewellAt: DateTime(2026, 11, 2),
              pets: [Pet(uid: 'p1', species: PetSpecies.owl, name: '부엉', bornAt: DateTime(2026, 11, 1))],
              companion: 'p1',
              firstPet: 'p1',
              firstSpiritName: '불씨',
            ).toJson(),
          });
      expect(c.farewellDone, isTrue);
      expect(c.bagEggs, hasLength(1));
      expect(bagEntries(c).whereType<EggEntry>(), hasLength(1));
    });
  });

  test('#398 「하이랜드 수호 기사」 하늘 돌 1.5배 (합 43) · 결정 · 금화 그대로', () {
    final stones = {
      for (final s in EquipSlot.values) s: HighlandRules.partCost(s).mats[MaterialId.skyStone],
    };
    expect(stones, {
      EquipSlot.weapon: 12,
      EquipSlot.head: 6,
      EquipSlot.body: 9,
      EquipSlot.hands: 5,
      EquipSlot.feet: 5,
      EquipSlot.accessory: 6,
    });
    expect(stones.values.fold<int>(0, (a, b) => a + b!), 43);
    expect(HighlandRules.partCost(EquipSlot.weapon).gold, 800);
    expect(HighlandRules.partCost(EquipSlot.weapon).mats[MaterialId.stormCore], 2);
  });

  testWidgets('#401 도감 몬스터 탭: 희귀·전설 사냥 기록 판 없음', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: CodexScreen(purifiedMonsters: {MonsterId.ashSlime}, huntCounts: {}))));
    await tester.pump();
    expect(find.text('희귀·전설 사냥 기록'), findsNothing);
    await tester.pump(const Duration(seconds: 9));
  });

  group('#404 · #403 긴급 의뢰는 「오늘」 탭 안', () {
    DateTime urgentDay() {
      for (var i = 0; i < 400; i++) {
        final d = DateTime(2026, 11, 10).add(Duration(days: i));
        if (BoardRules.urgentFor(d) case final u?) {
          return DateTime(d.year, d.month, d.day, u.appearsAt.hour + 1);
        }
      }
      throw StateError('no urgent');
    }

    DateTime calmDay() {
      for (var i = 0; i < 400; i++) {
        final d = DateTime(2026, 11, 10).add(Duration(days: i));
        if (BoardRules.urgentFor(d) == null) return DateTime(d.year, d.month, d.day, 15);
      }
      throw StateError('no calm');
    }

    Future<void> open(WidgetTester tester, AppController c) async {
      tester.view.physicalSize = const Size(750, 1334);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => TopNoticeHost(child: child!),
          home: BoardScreen(controller: c)));
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('긴급 있는 날: 띠 없음 · 맨 앞 긴급 쪽지 · 오늘 점 · 일일 개수는 따로', (tester) async {
      final t = urgentDay();
      late AppController c;
      await tester.runAsync(() async => c = await startVillage(10, clock: () => t));
      expect(c.urgent, isNotNull);
      await open(tester, c);
      expect(find.byKey(const Key('urgentBand')), findsNothing);
      expect(find.byKey(const Key('urgentNote')), findsOneWidget);
      expect(find.text('긴급'), findsWidgets);
      expect(find.byWidgetPredicate((w) => w.key == const Key('boardTab_today')), findsOneWidget);
      // 오늘 탭 빨간 점 (아직 안 받음)
      expect(find.descendant(of: find.byKey(const Key('boardTab_today')), matching: find.byKey(const Key('boardTabDot'))),
          findsOneWidget);
      // 일일 개수: x/3 그대로
      expect(find.textContaining('/${QuestRules.forDay(c.player.today!).length}'), findsWidgets);
      // 누르면 양피지 (빨간 테두리 없이)
      await tester.tap(find.byKey(const Key('urgentNote')));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(find.text('긴급 의뢰예요. 오늘 자정까지만 붙어 있어요.'), findsOneWidget);
      await tester.tap(find.text('수락하기'));
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(const Duration(milliseconds: 300));
      expect(c.board.urgentAccepted, isTrue);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('긴급 없는 날: 쪽지 없음 · 점 없음', (tester) async {
      final t = calmDay();
      late AppController c;
      await tester.runAsync(() async => c = await startVillage(10, clock: () => t));
      expect(c.urgent, isNull);
      await open(tester, c);
      expect(find.byKey(const Key('urgentNote')), findsNothing);
      expect(find.descendant(of: find.byKey(const Key('boardTab_today')), matching: find.byKey(const Key('boardTabDot'))),
          findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });
  });
}
