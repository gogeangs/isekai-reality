// 묶음 52: 3막 다리 너머 탐험 틀 (#243) — 열리는 때 · 다리 장면 · 걸음 · 동료 · 지역 1 필드 사냥

import 'dart:math' as math;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/act2_state.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/models/pet_state.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/act3/act3_screen.dart';
import 'package:isekai_reality/features/act3/ally_screens.dart';
import 'package:isekai_reality/features/village/tavern_screen.dart';
import 'package:isekai_reality/theme/top_notice.dart';

final t0 = DateTime(2026, 11, 17, 10);
final todayKey = FakeHealthSource.keyOf(t0);

/// 결말을 보고 만남까지 지난 계정 (Lv.[level])
InMemoryRecordStore account({int level = 21, bool meet = true, bool king = true}) =>
    InMemoryRecordStore(
      profile: const PlayerProfile(
          name: '하루', spiritName: '불씨', spiritKind: SpiritKind.water, lastSeenLevel: 99),
      history: [
        DailyRecord(date: DateTime(2026, 11, 1), gains: {
          Wallet.exp: LevelRules.totalExpToReach(level),
          Wallet.gold: 2000,
        }),
      ],
      json: {
        'tutorial': {'step': TutorialStep.done.index},
        'gates': {
          'legacy': false,
          'v28': true,
          'seen': [for (final f in Feature.values) f.name],
        },
        'village': {
          'seen': [
            'intro',
            'farewell',
            'lit',
            'shelterCard',
            'trainingCard',
            'gardenCard',
            'market',
            if (meet) 'meet',
            for (final n in Npc.values) 'met:${n.name}',
          ],
        },
        'act2': Act2State(
                beaten: king ? 5 : 3,
                kingPhase: king ? 5 : 0,
                kingDone: king,
                endingSeen: king,
                announced: 6)
            .toJson(),
        'pets': PetState(
          pets: [
            Pet(uid: 'p1', species: PetSpecies.owl, name: '부엉', bornAt: DateTime(2026, 10, 1)),
          ],
          companion: 'p1',
          firstPet: 'p1',
          firstSpiritName: '불씨',
          farewellAt: DateTime(2026, 10, 2),
        ).toJson(),
      },
    );

Future<(AppController, FakeHealthSource)> start(InMemoryRecordStore s,
    {int steps = 1000, int seed = 7}) async {
  final h = FakeHealthSource(stepsByDay: {todayKey: steps});
  final c = AppController(
    store: s,
    health: h,
    clock: () => t0,
    random: math.Random(seed),
  )..mailSources = const [];
  await c.init();
  return (c, h);
}

/// 싸움을 끝까지 (동료 스킬은 차면 누름)
void runOut(Battle b) {
  for (var i = 0; i < 4000 && !b.isOver; i++) {
    b.tick();
    for (var k = 0; k < b.allies.length; k++) {
      if (b.allies[k].ready) b.useAllySkill(k);
    }
  }
}

void main() {
  group('규칙', () {
    test('열리는 때 · 다리 장면 · 걸음 · 지역 1 장소', () {
      expect(Act3Rules.openLevel, 21);
      expect(Act3Rules.bridgeScene, hasLength(4));
      expect([for (final l in Act3Rules.bridgeScene) l.$1], ['lian', 'garen', 'pet', 'lian']);
      expect(Act3Rules.roadSteps, 50000);
      expect(Act3Rules.energyMax, 100);
      expect(Act3Rules.energyField, 5);
      expect(Act3Rules.energyFloor, 10);
      expect(Act3Rules.ticketSteps, 5000);
      expect(Act3Rules.ticketStepsPerDay, 2);
      expect(Act3Rules.regions, hasLength(5));
      expect([for (final r in Act3Rules.regions) r.level], [21, 23, 25, 27, 29]);
      final b = Act3Rules.region(Region.baldrin);
      expect(b.name, '발드린 관문');
      expect([for (final p in b.places) p.kind], [
        SpotKind.town,
        SpotKind.field,
        SpotKind.field,
        SpotKind.field,
        SpotKind.dungeon,
        SpotKind.hidden,
      ]);
      expect(Act3Rules.place('baldrin_windden')!.name, '???');
      expect(Act3Rules.place('baldrin_ashplain')!.monster, MonsterId.goblinRaider);
    });

    test('마법사 속성은 종족으로 · 8종족 6직업 · 스킬 4칸 · 확률 공개', () {
      expect(AllyRace.values, hasLength(8));
      expect(AllyJob.values, hasLength(6));
      expect(Act3Rules.mageElement, hasLength(8));
      expect(Act3Rules.mageElement.values.toSet(), hasLength(8));
      for (final j in AllyJob.values) {
        expect(Act3Rules.jobSkills(j), hasLength(4));
      }
      for (final s in StoryAlly.values) {
        expect(Act3Rules.story(s).skills, hasLength(4));
      }
      expect(Act3Rules.lockedByQuest(StoryAlly.garen, 3), isTrue);
      expect(Act3Rules.odds(), isNotEmpty);
      expect(Act3Rules.gearInfos, hasLength(6));
      expect({for (final g in Act3Rules.gearInfos) g.slot}, EquipSlot.values.toSet());
    });
  });

  group('열리는 때 (#124)', () {
    test('Lv.21 · 결말 · 만남을 지나야 다리가 열림', () async {
      final (low, _) = await start(account(level: 20));
      expect(low.act3Available, isFalse);
      final (noMeet, _) = await start(account(meet: false));
      expect(noMeet.act3Available, isFalse);
      final (noKing, _) = await start(account(king: false));
      expect(noKing.act3Available, isFalse);
      final (c, _) = await start(account());
      expect(c.act3Available, isTrue);
      expect(c.bridgeScenePending, isTrue);
      expect(c.act3Open, isFalse);
    });

    test('다리 장면을 끝내면: 리안 · 가렌 · 모집권 1 · 기력 가득', () async {
      final (c, _) = await start(account());
      await c.openAct3();
      expect(c.act3Open, isTrue);
      expect(c.bridgeScenePending, isFalse);
      expect([for (final a in c.allies) a.id], ['lian', 'garen']);
      expect([for (final a in c.partyAllies) a.name], ['리안', '가렌']);
      expect(c.allies.first.level, 20);
      expect(c.recruitTickets, 1);
      expect(c.journeyEnergy, 100);
      expect(c.road.steps, 0);
      expect(c.road.next!.name, isNotEmpty);
    });

    test('저장 뒤 다시 열어도 그대로 · 예전 기록엔 없음', () async {
      final s = account();
      final (c, _) = await start(s);
      await c.openAct3();
      final (again, _) = await start(s);
      expect(again.act3Open, isTrue);
      expect(again.allies, hasLength(2));
      final (fresh, _) = await start(account());
      expect(fresh.act3.opened, isFalse);
    });
  });

  group('걸음 · 싸움', () {
    test('열린 뒤 걸음만: 다음 지역 길 · 여정 기력 · 모집권 (하루 2장)', () async {
      final (c, h) = await start(account(), steps: 1000);
      await c.openAct3();
      final b = c.startAct3Fight('baldrin_ashplain');
      expect(b, isNotNull);
      expect(b!.allies, hasLength(2));
      expect(b.floors, hasLength(2));
      expect(c.journeyEnergy, 95);
      runOut(b);
      await c.finishAct3Fight(b);
      expect(c.journeyEnergy, 95);
      h.stepsByDay[todayKey] = 13500;
      await c.sync();
      await c.refreshVitals();
      expect(c.road.steps, 12500);
      expect(c.journeyEnergy, 100);
      expect(c.recruitTickets, 3);
      h.stepsByDay[todayKey] = 40000;
      await c.sync();
      await c.refreshVitals();
      expect(c.recruitTickets, 3, reason: '하루 2장까지');
      expect(c.road.steps, 39000);
    });

    test('필드 싸움: 이기면 경험치 · 금화 · 동료 경험치 · 일지 ①, 지면 기력만', () async {
      final (c, _) = await start(account());
      await c.openAct3();
      final gold = c.player.gold;
      final b = c.startAct3Fight('baldrin_ashplain')!;
      runOut(b);
      expect(b.isOver, isTrue);
      final r = await c.finishAct3Fight(b);
      if (r.won) {
        expect(r.exp, Act3Rules.fieldExp * 2);
        expect(c.player.gold, gold + r.gold);
        expect(c.act3.firstFight, isTrue);
        expect(c.journalMain.first.done, isTrue);
        expect(c.allies.first.exp + c.allies.first.level, greaterThan(20));
      } else {
        expect(c.player.gold, gold);
        expect(c.act3.firstFight, isFalse);
      }
    });

    test('기력이 모자라면 못 싸움 · 마을·던전·숨은 곳은 아직', () async {
      final (c, _) = await start(account());
      await c.openAct3();
      expect(c.canFieldFight('baldrin_town'), isFalse);
      expect(c.canFieldFight('baldrin_fort'), isFalse);
      expect(c.canFieldFight('baldrin_windden'), isFalse);
      for (var i = 0; i < 20; i++) {
        final b = c.startAct3Fight('baldrin_wallroad');
        if (b == null) break;
      }
      expect(c.journeyEnergy, lessThan(Act3Rules.energyField));
      expect(c.canFieldFight('baldrin_wallroad'), isFalse);
    });
  });

  group('동료', () {
    test('모집: 능력치 70~110% · 특성 1~2 · 한도 4 · 이름 바꾸기 · 내보내기', () async {
      final (c, _) = await start(account());
      await c.openAct3();
      expect(c.rosterLimit, 4);
      final a = await c.recruit();
      expect(a, isNotNull);
      expect(c.recruitTickets, 0);
      expect(c.nameless, hasLength(1));
      for (final s in a!.stats) {
        expect(s, inInclusiveRange(8, 15));
      }
      expect(a.traits.length, inInclusiveRange(1, 2));
      expect(await c.recruit(), isNull, reason: '모집권이 없음');
      expect(await c.renameAlly(a.id, '리안'), isFalse, reason: '마을 사람 이름');
      expect(await c.renameAlly(a.id, '바람'), isTrue);
      expect(c.nameless.single.name, '바람');
      await c.setParty(['lian', a.id]);
      expect([for (final p in c.partyAllies) p.id], ['lian', a.id]);
      final gold = c.player.gold;
      expect(await c.releaseAlly('lian'), isFalse, reason: '이야기 동료');
      expect(await c.releaseAlly(a.id), isTrue);
      expect(c.nameless, isEmpty);
      expect(c.player.gold, gold + Act3Rules.releaseGold);
      expect([for (final p in c.partyAllies) p.id], ['lian']);
    });

    test('스킬: ①은 처음부터, 포인트는 동료 레벨 2마다, 가렌 ④는 부탁 뒤', () async {
      final (c, _) = await start(account());
      await c.openAct3();
      final garen = c.act3.ally('garen')!;
      expect(garen.skills, [0]);
      expect(c.allyPoints(garen), 0);
      expect(c.canUnlockSkill(garen, 1), isFalse);
      expect(c.canUnlockSkill(garen, 3), isFalse);
    });
  });

  group('화면', () {
    testWidgets('다리 장면 4줄 → 3막 화면 (지도 · 일지 · 세계)', (tester) async {
      tester.view.physicalSize = const Size(750, 1334);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      late AppController c;
      await tester.runAsync(() async => c = (await start(account())).$1);
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => TopNoticeHost(child: child!),
          home: Scaffold(
              body: Builder(
                  builder: (context) => Center(
                        child: TextButton(
                            key: const Key('go'),
                            onPressed: () => openJourney(context, c),
                            child: const Text('go')),
                      )))));
      await tester.pump();
      await tester.tap(find.byKey(const Key('go')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byKey(const Key('bridgeScene')), findsOneWidget);
      for (var i = 0; i < Act3Rules.bridgeScene.length; i++) {
        await tester.tapAt(const Offset(180, 330));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pump(const Duration(milliseconds: 700));
      }
      expect(c.act3Open, isTrue);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(find.byKey(const Key('act3Screen')), findsOneWidget);
      expect(find.byKey(const Key('regionMap')), findsOneWidget);
      expect(find.byKey(const Key('place_baldrin_ashplain')), findsOneWidget);
      expect(find.byKey(const Key('act3Ally_lian')), findsOneWidget);
      await tester.tap(find.byKey(const Key('place_baldrin_ashplain')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const Key('placeFight')), findsOneWidget);
      await tester.tapAt(const Offset(180, 40));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const Key('act3Tab_1')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('questGo')), findsOneWidget);
      await tester.tap(find.byKey(const Key('act3Tab_2')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('region_baldrin')), findsOneWidget);
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('3막 싸움: 동료 둘이 함께 (HP 막대 · 스킬 버튼)', (tester) async {
      tester.view.physicalSize = const Size(750, 1334);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      late AppController c;
      await tester.runAsync(() async {
        c = (await start(account())).$1;
        await c.openAct3();
      });
      await tester.pumpWidget(MaterialApp(
          home: Act3BattleScreen(
              controller: c,
              placeId: 'baldrin_ashplain',
              tickInterval: const Duration(milliseconds: 50))));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const Key('battleAlly_0')), findsOneWidget);
      expect(find.byKey(const Key('battleAlly_1')), findsOneWidget);
      expect(find.byKey(const Key('allyHp_lian')), findsOneWidget);
      expect(c.journeyEnergy, 95);
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('주점 「동료」 탭: 데려가는 동료 · 모집 · 확률 · 자세히', (tester) async {
      tester.view.physicalSize = const Size(750, 1334);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      late AppController c;
      await tester.runAsync(() async {
        c = (await start(account())).$1;
        await c.openAct3();
      });
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => TopNoticeHost(child: child!),
          home: TavernScreen(controller: c, allyTab: true)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AllyTab), findsOneWidget);
      expect(find.byKey(const Key('partySlot_lian')), findsOneWidget);
      expect(find.byKey(const Key('allyRow_garen')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('recruitButton')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('recruitButton')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('recruitResult')), findsOneWidget);
      expect(c.nameless, hasLength(1));
      await tester.tap(find.text('좋아요'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const Key('tavernTab_0')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('tavernRumor')), findsOneWidget);

      await tester.pumpWidget(MaterialApp(
          home: AllyDetailScreen(controller: c, allyId: 'garen')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('allyGear')), findsOneWidget);
      expect(find.byKey(const Key('allySkill_3')), findsOneWidget);
      expect(find.byKey(const Key('allyRelease')), findsNothing);
      await tester.pump(const Duration(seconds: 9));
    });
  });
}
