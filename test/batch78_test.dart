// 묶음 78: #363 전투 칸 · #364 고유 · 숙련 스킬 · #359 조합 · #360 원정 목록 · #361 알 · #362 레시피 · #309 게시판

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/features/jobs/guild_screen.dart';
import 'package:isekai_reality/features/jobs/skill_screen.dart';
import 'package:isekai_reality/features/pets/egg_news.dart';
import 'package:isekai_reality/features/village/board_screen.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'support/npc_seed.dart';
import 'support/village_seed.dart';

Future<AppController> _job(String job,
        {int level = 18, List<String> subs = const [], Map<String, int> learned = const {}, Map<String, dynamic> more = const {}}) =>
    startVillage(level, farewell: true, more: {
      'jobs': {
        'awakened': true,
        'v57': true,
        'v31': true,
        'main': job,
        'owned': [job, ...subs],
        'subs': subs,
        if (learned.isNotEmpty) 'learned': learned,
      },
      ...more,
    });

void _phone(WidgetTester t) {
  t.view.physicalSize = const Size(1290, 2796);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
}

Widget _host(Widget child) => MaterialApp(builder: (context, c) => TopNoticeHost(child: c!), home: child);

void main() {
  group('#363 전투 칸', () {
    testWidgets('버튼 줄 5칸 · 칸 1 골라짐 · 넣기 한 줄 · 늘 있는 버튼 설명', (tester) async {
      _phone(tester);
      late AppController c;
      await tester.runAsync(() async => c = await _job('warrior', learned: {'cleave': 1}));
      await tester.pumpWidget(_host(SkillScreen(controller: c)));
      await tester.pump();
      // 묶음 85 #420: 각성 뒤엔 강타 · 방어 태세 자리가 칸 3 · 4
      for (final k in ['skillSlot_2', 'skillSlot_3', 'skillSlot_0', 'skillSlot_1', 'battleFixed_pet']) {
        expect(find.byKey(Key(k)), findsOneWidget, reason: k);
      }
      expect(find.byKey(const Key('battleSlotHint')), findsOneWidget);
      await tester.tap(find.byKey(const Key('skillSlot_1')));
      await tester.pump();
      expect(find.text('칸 2에 넣을 스킬'), findsOneWidget);
      // 안 배운 스킬은 「포인트로 열기」
      expect(find.text('포인트로 열기'), findsWidgets);
      await tester.tap(find.byKey(const Key('battleFixed_pet')));
      await tester.pump();
      expect(find.byKey(const Key('battleFixedChip')), findsOneWidget);
      // 칸 1에 내려베기 넣기 (칸 2와 바꿈)
      await tester.tap(find.byKey(const Key('skillSlot_0')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('battlePick_job:cleave')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('battlePut')));
      await tester.tap(find.byKey(const Key('battlePut')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(c.battleLoadout.first, 'job:cleave');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -800));
      await tester.pump();
      expect(find.byKey(const Key('battleSlotToast')), findsOneWidget);
    });
  });

  group('#364 고유 스킬', () {
    testWidgets('남은 포인트 배지 · 바로 강화 한 줄 · 펼침 Lv 칸 · MAX', (tester) async {
      _phone(tester);
      late AppController c;
      // 묶음 85 #414: 5단계까지 (Lv.18이면 3단계에서 「Lv.25에 열려요」)
      await tester.runAsync(() async => c = await _job('warrior', learned: {'cleave': 3, 'ironWall': 1}));
      await tester.pumpWidget(_host(SkillScreen(controller: c, tab: 1)));
      await tester.pump();
      expect(find.byKey(const Key('skillPointsLeft')), findsOneWidget);
      expect(find.byKey(const Key('skillLocked_cleave')), findsOneWidget);
      expect(find.text('Lv.25에\n열려요'), findsWidgets);
      final before = c.skillPointsLeftOn(JobId.warrior);
      await tester.ensureVisible(find.byKey(const Key('skillRaise_ironWall')));
      await tester.tap(find.byKey(const Key('skillRaise_ironWall')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      expect(c.skillLevel(JobSkill.ironWall), 2);
      expect(c.skillPointsLeftOn(JobId.warrior), before - 1);
      expect(find.byKey(const Key('skillToast')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('jobSkillTile_cleave')));
      await tester.tap(find.byKey(const Key('jobSkillTile_cleave')));
      await tester.pump();
      expect(find.byKey(const Key('skillOpen_cleave')), findsOneWidget);
      expect(find.byKey(const Key('skillToSlot_cleave')), findsOneWidget);
      await tester.tap(find.byKey(const Key('skillToSlot_cleave')));
      await tester.pump();
      expect(find.byKey(const Key('battleBar')), findsOneWidget);
    });

    testWidgets('Lv.15~19는 주/보조 탭 없음 · Lv.20 보조가 있으면 두 칸', (tester) async {
      _phone(tester);
      late AppController a;
      late AppController b;
      await tester.runAsync(() async {
        a = await _job('warrior', level: 18);
        b = await _job('warrior', level: 22, subs: ['mage']);
      });
      await tester.pumpWidget(_host(SkillScreen(key: const ValueKey('a'), controller: a, tab: 1)));
      await tester.pump();
      expect(find.byKey(const Key('skillJobView_1')), findsNothing);
      await tester.pumpWidget(_host(SkillScreen(key: const ValueKey('b'), controller: b, tab: 1)));
      await tester.pump();
      expect(find.byKey(const Key('skillJobView_1')), findsOneWidget);
    });
  });

  group('#364 숙련 스킬', () {
    test('막대 구간 · 단계 말 · 오르는 행동', () {
      expect(MasteryRules.segmentFill(0, 0), 0);
      expect(MasteryRules.segmentFill(5, 0), 0.5);
      expect(MasteryRules.segmentFill(10, 0), 1);
      expect(MasteryRules.segmentFill(10, 1), 0);
      expect(MasteryRules.stageLabel(MasteryStage.clumsy), '서툰');
      for (final m in Mastery.values) {
        expect(MasteryRules.howUp(m), isNotEmpty);
      }
    });

    testWidgets('늘 8줄 · 높은 단계 먼저 · 장인 배지 · 숙련된 줄 「전투 칸에 넣기」', (tester) async {
      _phone(tester);
      late AppController c;
      await tester.runAsync(() async => c = await _job('warrior', more: {
            'mastery': {'big': {'combat': 150.0, 'smith': 320.0}},
          }));
      await tester.pumpWidget(_host(SkillScreen(controller: c, tab: 2)));
      await tester.pump();
      // 묶음 85 #416: 돋보기를 끄면 「감정」 숙련은 숨김
      for (final m in Mastery.values) {
        expect(find.byKey(Key('masteryRow_${m.name}')), m == Mastery.appraise && !LensRules.lensOn ? findsNothing : findsOneWidget,
            reason: m.name);
      }
      expect(find.byKey(const Key('masteryBadge_smith')), findsOneWidget);
      expect(find.byKey(const Key('masteryDetail_smith')), findsOneWidget);
      expect(find.text('주 직업 숙련 1.5배'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('masteryRow_combat')));
      await tester.tap(find.byKey(const Key('masteryRow_combat')));
      await tester.pump();
      expect(find.byKey(const Key('masteryToSlot_combat')), findsOneWidget);
    });
  });

  group('#359 조합', () {
    testWidgets('세라 머리줄 · 지금 내 직업이에요', (tester) async {
      _phone(tester);
      late AppController c;
      await tester.runAsync(() async => c = await _job('warrior', level: 17));
      await tester.pumpWidget(_host(GuildScreen(controller: c)));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const Key('guildSeraLine')), findsOneWidget);
      expect(find.byKey(const Key('guildMine')), findsOneWidget);
      expect(find.byKey(const Key('jobAsMain')), findsNothing);
      await tester.tap(find.byKey(const Key('guildJob_mage')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('jobAsMain')), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('#361 알', () {
    test('확률 · 하루 1개', () async {
      expect(PetRules.fieldEggChance(ModGrade.none), 0.005);
      expect(PetRules.fieldEggChance(ModGrade.rare), 0.02);
      expect(PetRules.fieldEggChance(ModGrade.legend), 0.08);
      expect(PetRules.dungeonEggChance, 0.04);
      expect(PetRules.huntEggsPerDay, 1);
    });

    testWidgets('알 얻음 창: 그림 아래는 등급 이름', (tester) async {
      await tester.pumpWidget(const MaterialApp(
          home: Scaffold(body: EggGotBanner(grade: EggGrade.rare, farewell: true, nameOnly: true))));
      await tester.pump(const Duration(seconds: 2));
      expect(find.textContaining('얻었어요'), findsNothing);
    });
  });

  group('#309 게시판', () {
    testWidgets('넓은 카드 · 버튼 · 받은 의뢰는 아래 완료', (tester) async {
      _phone(tester);
      late AppController c;
      await tester.runAsync(() async => c = await startNpc(level: 14, todaySteps: {
            for (var d = 10; d <= 20; d++) '2026-11-${d.toString().padLeft(2, '0')}': 12000,
          }));
      await tester.pumpWidget(_host(BoardScreen(controller: c)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('boardTab_today')));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('questNote_')), findsWidgets);
      expect(find.byKey(const Key('questButton_던전으로'), skipOffstage: false), findsWidgets);
      expect(find.byKey(const Key('doneStamp')), findsWidgets);
      await tester.pump(const Duration(seconds: 6));
    });
  });
}
