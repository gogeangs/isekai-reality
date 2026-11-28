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

/// 묶음 86: 스킬 화면은 전투 칸이 위에 붙어 있어 가운데로 보이게
Future<void> showMid(WidgetTester tester, Finder f) async {
  await tester.runAsync(() => Scrollable.ensureVisible(tester.element(f), alignment: 0.5));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  // 묶음 86 #433: 스킬 화면은 탭 없이 한 화면 — 아래 시험은 새 화면에 맞춤
  group('#363 전투 칸', () {
    testWidgets('전투 칸 4개 + 펫 · 「칸에」 → 칸 누르기 · 늘 있는 버튼 설명', (tester) async {
      _phone(tester);
      late AppController c;
      await tester.runAsync(() async => c = await _job('warrior', learned: {'cleave': 1}));
      await tester.pumpWidget(_host(SkillScreen(controller: c)));
      await tester.pump();
      for (final k in ['skillSlot_2', 'skillSlot_3', 'skillSlot_0', 'skillSlot_1', 'battleFixed_pet']) {
        expect(find.byKey(Key(k)), findsOneWidget, reason: k);
      }
      expect(find.byKey(const Key('battleSlotHint')), findsOneWidget);
      await tester.tap(find.byKey(const Key('battleFixed_pet')));
      await tester.pump();
      expect(find.byKey(const Key('battleSlotToast')), findsOneWidget);
      // 칸 1에 내려베기 넣기 (다른 칸에 있으면 옮김)
      await showMid(tester, find.byKey(const Key('skillToSlot_cleave')));
      await tester.tap(find.byKey(const Key('skillToSlot_cleave')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('skillSlot_0')));
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(c.battleLoadout.first, 'job:cleave');
      expect(c.battleSlots.where((e) => e == 'job:cleave'), hasLength(1));
      expect(find.byKey(const Key('battleSlotToast')), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('#364 고유 스킬', () {
    testWidgets('남은 포인트 · 바로 강화 · 펼침 Lv 칸 · 잠김 「Lv.25에 열려요」', (tester) async {
      _phone(tester);
      late AppController c;
      await tester.runAsync(() async => c = await _job('warrior', learned: {'cleave': 3, 'ironWall': 1}));
      await tester.pumpWidget(_host(SkillScreen(controller: c, tab: 1)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('skillPointsLeft')), findsOneWidget);
      expect(find.byKey(const Key('skillLocked_cleave')), findsOneWidget);
      expect(find.text('Lv.25에\n열려요'), findsWidgets);
      final before = c.skillPointsLeft;
      await showMid(tester, find.byKey(const Key('skillRaise_ironWall')));
      await tester.tap(find.byKey(const Key('skillRaise_ironWall')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      expect(c.skillLevel(JobSkill.ironWall), 2);
      expect(c.skillPointsLeft, before - 1);
      await showMid(tester, find.byKey(const Key('jobSkillTile_cleave')));
      await tester.tap(find.byKey(const Key('jobSkillTile_cleave')));
      await tester.pump();
      expect(find.byKey(const Key('skillOpen_cleave')), findsOneWidget);
      expect(find.byKey(const Key('skillToSlot_cleave')), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('보조 직업 칸은 Lv.20 보조가 있을 때만', (tester) async {
      _phone(tester);
      late AppController a;
      late AppController b;
      await tester.runAsync(() async {
        a = await _job('warrior', level: 18);
        b = await _job('warrior', level: 22, subs: ['mage']);
      });
      await tester.pumpWidget(_host(SkillScreen(key: const ValueKey('a'), controller: a)));
      await tester.pump();
      expect(find.byKey(const Key('skillChip_sub')), findsNothing);
      await tester.pumpWidget(_host(SkillScreen(key: const ValueKey('b'), controller: b)));
      await tester.pump();
      expect(find.byKey(const Key('skillChip_sub')), findsOneWidget);
      expect(find.byKey(const Key('skillTraitHalf')), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
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

    testWidgets('숙련 카드 · 높은 단계 먼저 · 장인 금테 · 숙련된 「칸에」', (tester) async {
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
      // 묶음 86 #433: 숙련은 + 버튼 없이 막대 · 「숙련된」 공격 스킬은 「칸에」
      expect(find.byKey(const Key('skillMaster_m_smith')), findsOneWidget);
      expect(find.byKey(const Key('masteryBar_smith')), findsOneWidget);
      expect(find.text('주 직업 숙련 1.5배'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('masteryRow_combat')));
      expect(find.byKey(const Key('masteryToSlot_combat')), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
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
