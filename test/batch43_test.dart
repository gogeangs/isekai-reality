// 묶음 43 #228: 마을 새 건물 「훈련장」 — 가렌 · 연습 · 하루 훈련 · 펫 훈련 · 시련

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/features/records/records_screen.dart';
import 'package:isekai_reality/features/village/training_screen.dart';
import 'package:isekai_reality/features/village/village_screen.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'support/village_seed.dart';

int _exp(AppController c) =>
    c.player.history.fold<int>(0, (t, r) => t + (r.gains['exp'] ?? 0));

void main() {
  test('규칙: 하루 훈련 3판 · 시련은 판이 갈수록 강해짐 · 5·10·15판 보상', () {
    final d = TrainingRules.dailyFoes(13);
    expect(d, hasLength(3));
    expect(d.map((f) => f.monster),
        [MonsterId.dummy, MonsterId.trainingGolem, MonsterId.trainingGolem]);
    expect(d[2].maxHp, greaterThan(d[1].maxHp));
    final t1 = TrainingRules.trialFoe(13, 1), t11 = TrainingRules.trialFoe(13, 11);
    expect(t11.maxHp, greaterThan(t1.maxHp));
    expect(t11.attack, greaterThan(t1.attack));
    expect(TrainingRules.trialFoe(13, 5).monster, MonsterId.trainingGolem);
    expect(TrainingRules.trialMarks, [5, 10, 15]);
    // 훈련 몬스터는 지도·도감에 안 나옴
    for (final m in [
      MonsterId.dummy,
      MonsterId.dummyHard,
      MonsterId.dummyElement,
      MonsterId.trainingGolem,
    ]) {
      expect(Monsters.inCodex(m), isFalse);
      expect(Monsters.all.any((x) => x.id == m), isFalse);
    }
    // 가렌: 마을 사람 · 이름은 각성자·펫 이름으로 못 씀
    expect(VillageRules.npc(Npc.garen).name, '가렌');
    expect(VillageRules.npc(Npc.garen).role, '훈련 교관');
    expect(VillageRules.npc(Npc.garen).first,
        '하르트 녀석이 말한 각성자가 너로군! 자세부터 보자!');
    expect(NpcRules.of(Npc.garen), hasLength(4));
    expect(NpcRules.of(Npc.garen).last.special?.title, TitleId.npcGaren);
    expect(TitleRules.info(TitleId.npcGaren).name, '문지기 기사단의 후예');
    expect(TitleRules.info(TitleId.trialEndurer).name, '시련을 견딘 자');
    expect(EquipmentRules.info(EquipBase.garenBand).attack, greaterThan(0));
  });

  test('공사 중 규칙: Lv.10 터 닦기 · 11 뼈대 · 12 거의 완성 · 13 열림', () async {
    for (final (lv, stage) in [(9, 1), (10, 1), (11, 2), (12, 3)]) {
      final c = await startVillage(lv, village: {'seen': ['intro']});
      expect(c.buildStage('training'), stage, reason: 'Lv.$lv');
      expect(c.trainingOpen, isFalse);
      expect(c.trainingIntroPending, isFalse);
    }
    final c = await startVillage(13, village: {'seen': ['intro']});
    expect(c.trainingOpen, isTrue);
    expect(c.buildStage('training'), isNull);
    expect(c.npcHomeOpen(Npc.garen), isTrue);
  });

  test('예전 기록 Lv.13 이상: 완공 연출 없이 열림 + 「새로 열렸어요」 카드 한 번', () async {
    final c = await startVillage(14,
        farewell: true, village: {'seen': ['intro', 'farewell', 'shelterCard']});
    expect(c.builtPending, isEmpty);
    expect(c.trainingIntroPending, isTrue);
    await c.markTrainingIntro();
    expect(c.trainingIntroPending, isFalse);
  });

  test('이번 빌드 뒤 Lv.13이 되면 완공 연출 (한 번)', () async {
    final c = await startVillage(13, village: {
      'seen': ['intro', 'v43', 'v44', 'built:smithy', 'built:board', 'built:alchemy'],
    });
    expect(c.builtPending, ['training']);
    expect(c.villageMoment, '훈련장이 다 지어졌어!');
    await c.markBuilt(['training']);
    expect(c.builtPending, isEmpty);
  });

  test('연습: 허수아비는 쓰러지지 않고 때리지 않음 · HP 그대로 · 강타·방어 태세·스킬 셈', () async {
    final c = await startVillage(13,
        farewell: true, village: {'seen': ['intro', 'farewell']});
    final hp = c.hp, exp = _exp(c);
    final b = c.startPractice(DummyKind.element, element: Element.water)!;
    expect(b.practice, isTrue);
    expect(b.foe.element, Element.water);
    for (var i = 0; i < 60; i++) {
      if (b.bashReady) b.useBash();
      if (b.stanceReady) b.useStance();
      if (b.skillReady) b.useSkill();
      b.tick();
    }
    expect(b.isOver, isFalse);
    expect(b.foeHp, b.foe.maxHp);
    expect(b.playerHp, b.playerMaxHp);
    expect(b.practiceDealt, greaterThan(0));
    expect(b.bashes, greaterThan(0));
    expect(b.stances, greaterThan(0));
    expect(b.skillsUsed, greaterThan(0));
    await c.finishPractice(b);
    expect(c.hp, hp);
    expect(_exp(c), exp);
    expect(c.npcState.tally[NpcTally.practiceBash], 1);
    expect(c.npcState.tally[NpcTally.practiceStance], 1);
    expect(c.npcState.tally[NpcTally.practiceSkill], 1);
  });

  test('하루 훈련: 하루 한 번 · 넘긴 판까지 금화·숙련도 · 경험치 없음 · HP 그대로', () async {
    final c = await startVillage(13,
        farewell: true, village: {'seen': ['intro', 'farewell']});
    expect(c.trainingDailyPending, isTrue);
    final hp = c.hp, exp = _exp(c), gold = c.player.gold;
    final b = (await c.startDailyTraining())!;
    expect(await c.startDailyTraining(), isNull);
    expect(c.trainingDailyPending, isFalse);
    // 두 판 넘기고 세 번째에서 짐
    b.floor = 2;
    b.phase = BattlePhase.failed;
    final r = await c.finishDailyTraining(b);
    expect(r.cleared, 2);
    expect(c.player.gold, greaterThan(gold));
    expect(_exp(c), exp);
    expect(c.hp, hp);
    expect(c.npcState.tally[NpcTally.dailyTraining], 1);
  });

  test('펫 훈련: 8시간 · 그동안 동행·원정 못 씀 · 끝나면 펫 경험치 + 알림 한 번 · 하루 한 번', () async {
    var now = vt0;
    final c = await startVillage(13,
        farewell: true,
        village: {'seen': ['intro', 'farewell']},
        clock: () => now);
    expect(c.companionPet?.uid, 'p1');
    final exp0 = c.pets.pets.first.exp;
    expect(await c.startPetTraining('p1'), isTrue);
    expect(c.petInTraining('p1'), isTrue);
    expect(c.companionPet, isNull);
    expect(c.petTrainingLeft('p1'), const Duration(hours: 8));
    expect(await c.startPetTraining('p1'), isFalse);
    now = vt0.add(const Duration(hours: 8, minutes: 1));
    await c.refreshVitals();
    expect(c.petInTraining('p1'), isFalse);
    expect(c.pets.pets.first.exp, greaterThan(exp0));
    expect(c.takePetTrainedNotice(), '부엉');
    expect(c.takePetTrainedNotice(), isNull);
    expect(c.companionPet?.uid, 'p1');
    expect(c.npcState.tally[NpcTally.petTraining], 1);
    // 오늘은 이미 함
    expect(c.petTrainedToday, isTrue);
    expect(await c.startPetTraining('p1'), isFalse);
  });

  test('시련: 하루 한 번 · 이번 주 최고 · 5·10·15판 보상 · 처음 15판 칭호', () async {
    final c = await startVillage(16,
        farewell: true, village: {'seen': ['intro', 'farewell']});
    final stones = c.player.manaStones;
    final b = (await c.startTrial())!;
    expect(await c.startTrial(), isNull);
    b.floor = 16;
    b.phase = BattlePhase.failed;
    final r = await c.finishTrial(b);
    expect(r.floors, 16);
    expect(r.marks, [5, 10, 15]);
    expect(r.title, isTrue);
    expect(r.newBest, isTrue);
    expect(c.trialBestThisWeek, 16);
    expect(c.trialEver, 16);
    expect(c.trialMarksThisWeek, [5, 10, 15]);
    expect(c.player.manaStones, greaterThan(stones));
    expect(c.player.titles, contains(TitleId.trialEndurer));
    expect(c.npcState.tally[NpcTally.trial10], 1);
  });

  testWidgets('마을: 훈련장 이름표 · 오늘 하루 훈련 전 은은한 점 · 들어가면 가렌', (tester) async {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    late AppController c;
    await tester.runAsync(() async => c = await startVillage(13,
        farewell: true, village: {'seen': ['intro', 'farewell']}));
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => TopNoticeHost(child: child!),
        home: Scaffold(body: VillageScreen(controller: c))));
    await tester.pump();
    expect(find.byKey(const Key('tag_training')), findsOneWidget);
    expect(find.byKey(const Key('soft_training')), findsOneWidget);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => TopNoticeHost(child: child!),
        home: TrainingScreen(controller: c)));
    await tester.pump();
    expect(find.byKey(const Key('npc_garen')), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      expect(find.byKey(Key('trainingTab_$i')), findsOneWidget);
    }
    expect(find.byKey(const Key('dummy_element')), findsOneWidget);
    await tester.pump(const Duration(seconds: 9));
  });

  testWidgets('기록 탭: 시련 최고 기록 한 줄', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: RecordsScreen(
      player: (await tester.runAsync(() => startVillage(13)))!.player,
      embedded: true,
      trial: (week: 7, ever: 12),
    ))));
    await tester.pump();
    await tester.scrollUntilVisible(find.byKey(const Key('trialRecords')), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const Key('trialRecords')), findsOneWidget);
    await tester.pump(const Duration(seconds: 9));
  });
}
