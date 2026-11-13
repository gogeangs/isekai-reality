import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/battle/field_battle_screen.dart';
import 'package:isekai_reality/features/bulssi/bulssi_bubble.dart';
import 'package:isekai_reality/features/tutorial/targets.dart';
import 'package:isekai_reality/features/tutorial/tutorial_layer.dart';

void main() {
  final t0 = DateTime(2026, 11, 13, 10);

  Future<AppController> newPlayer(DateTime Function() clock) async {
    final c = AppController(
      store: InMemoryRecordStore(),
      health: FakeHealthSource(stepsByDay: const {}),
      clock: clock,
    )..mailSources = const [];
    await c.init();
    await c.awaken(name: '하루', look: HeroLook.female);
    return c;
  }

  group('#150 첫 장면에서 멈추지 않는다', () {
    test('연출 단계에서 껐다 켜면 첫 전투부터 (일반 사냥 기록은 그대로)', () async {
      final store = InMemoryRecordStore(
        profile: const PlayerProfile(name: '하루'),
        json: {
          'tutorial': {'step': TutorialStep.intro.index},
          'gates': {'legacy': false, 'seen': <String>[]},
        },
      );
      final c = AppController(
        store: store,
        health: FakeHealthSource(stepsByDay: const {}),
        clock: () => t0,
      )..mailSources = const [];
      await c.init();
      expect(c.tutorialStep, TutorialStep.hunt);
      expect(c.tutorialSpawn?.id, AppController.tutorialHuntId);
      expect((await store.loadJson('tutorial'))?['step'], TutorialStep.hunt.index);
    });

    test('튜토리얼 중에는 튜토리얼 몬스터만 (일반 몬스터·채집·상인 숨김)', () async {
      final c = await newPlayer(() => t0);
      await c.finishIntro();
      expect(c.todaySpawns.map((s) => s.id), [AppController.tutorialHuntId]);
      expect(c.todaySpawns.single.monster, MonsterId.slime);
      expect(c.harvestSpots, isEmpty);
      expect(c.merchantHere, isFalse);
      await c.skipTutorial();
      expect(c.todaySpawns.length, greaterThan(1));
    });

    testWidgets('연출은 버튼 없이 저절로 첫 전투로 넘어간다', (tester) async {
      var done = 0;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: IsekaiIntro(onDone: () async => done++))));
      String line() => tester.widget<BulssiBubble>(find.byType(BulssiBubble)).line;
      expect(line(), isNot(contains('바로 옆')));
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 400));
      expect(line(), contains('바로 옆에 뭔가 있어'));
      expect(find.byType(ElevatedButton), findsNothing);
      await tester.pump(const Duration(seconds: 3));
      expect(done, 1);
    });
  });

  group('#151 바로 돌아오기', () {
    test('마석 개수: 남은 10분마다 1개, 1~6개', () {
      expect(VitalRules.rushCost(30), 1);
      expect(VitalRules.rushCost(600), 1);
      expect(VitalRules.rushCost(601), 2);
      expect(VitalRules.rushCost(25 * 60), 3);
      expect(VitalRules.rushCost(5 * 3600), 6);
    });

    test('튜토리얼: 첫 몬스터 마석 1개로 바로 돌아와 Lv.2', () async {
      var now = t0;
      final c = await newPlayer(() => now);
      await c.finishIntro();
      final first = c.tutorialSpawn!;
      final battle = c.startFieldBattle(first)!;
      battle.runToEnd(useSkills: true);
      await c.finishFieldBattle(first, battle);
      expect(c.player.manaStones, greaterThanOrEqualTo(1));
      await c.tutorialBagSeen();
      final second = c.tutorialSpawn!;
      expect(await c.sendSpirit(second), ExpeditionCheck.ok);
      final ex = c.activeExpeditions.single;
      expect(c.rushCost(ex), 1);
      expect(c.canRushByAd(ex), isFalse); // 튜토리얼은 마석만
      expect(await c.rushExpedition(ex), isTrue);
      expect(c.player.today!.spends[Wallet.manaStone], 1);
      expect(c.activeExpeditions, isEmpty);
      expect(c.player.level.level, 2);
      expect(c.inTutorial, isFalse);
    });

    test('마석이 모자라면 돌아오지 않는다', () async {
      var now = t0;
      final c = AppController(
        store: InMemoryRecordStore(profile: const PlayerProfile(name: '하루')),
        health: FakeHealthSource(stepsByDay: const {}),
        clock: () => now,
      )..mailSources = const [];
      await c.init();
      final spawn = c.todaySpawns.first;
      if (await c.sendSpirit(spawn) != ExpeditionCheck.ok) return;
      final ex = c.activeExpeditions.single;
      if (c.player.manaStones >= c.rushCost(ex)) return;
      expect(await c.rushExpedition(ex), isFalse);
      expect(c.activeExpeditions, isNotEmpty);
    });
  });

  testWidgets('#148 튜토리얼: 누를 곳 하나만 밝게, 누르면 첫 전투', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    late AppController c;
    await tester.runAsync(() async {
      c = await newPlayer(() => t0);
      await c.finishIntro();
    });
    await tester.pumpWidget(IsekaiRealityApp(controller: c));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(TutorialLayer), findsOneWidget);
    String line() =>
        tester.widget<BulssiBubble>(find.byKey(const Key('tutorialLine'))).line;
    expect(line(), '바로 옆에 뭔가 있어! 눌러 봐!');
    expect(find.byKey(const Key('spotlightHole')), findsOneWidget);
    expect(find.byKey(const Key('fingerHint')), findsOneWidget);
    // 아래 메뉴는 눌리지 않는다
    await tester.tap(find.text('마을'), warnIfMissed: false);
    await tester.pump();
    expect(line(), '바로 옆에 뭔가 있어! 눌러 봐!');
    await tester.tap(find.byKey(const Key('spotlightHole')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(FieldBattleScreen), findsOneWidget);
  });

  testWidgets('#151 바로 돌아오기 창: 마석 버튼·모자라면 안내', (tester) async {
    late AppController c;
    await tester.runAsync(() async {
      c = await newPlayer(() => t0);
      await c.finishIntro();
      final first = c.tutorialSpawn!;
      final battle = c.startFieldBattle(first)!;
      battle.runToEnd(useSkills: true);
      await c.finishFieldBattle(first, battle);
      await c.tutorialBagSeen();
      await c.sendSpirit(c.tutorialSpawn!);
    });
    await tester.pumpWidget(IsekaiRealityApp(controller: c));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
        tester.widget<BulssiBubble>(find.byKey(const Key('tutorialLine'))).line,
        contains('나를 누르면 서두를 수 있어'));
    await tester.pump();
    await tester.pump();
    // ignore: avoid_print
    print('strip=${find.byKey(const Key('expeditionStrip')).evaluate().length} '
        'rect=${rectOf(tutorialStripKey)} ctx=${tutorialStripKey.currentContext}');
    await tester.tap(find.byKey(const Key('spotlightHole')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('rushSheet')), findsOneWidget);
    expect(find.byKey(const Key('rushMana')), findsOneWidget);
    expect(find.byKey(const Key('rushAd')), findsNothing);
  });
}
