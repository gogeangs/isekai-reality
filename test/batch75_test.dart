// 묶음 75: 알 등급 · 쪽지 한도 · 보스 장비 대장장이 · 연습 기록 · 스킬 숙련도 · 칭호 조사 · 우편 · 프로필 사진

import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/mail_state.dart';
import 'package:isekai_reality/core/models/pet_state.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/features/jobs/skill_screen.dart';
import 'package:isekai_reality/features/mail/mail_screen.dart';
import 'package:isekai_reality/features/profile/avatar_picker.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'support/village_seed.dart';

Battle _battle() => Battle(
      playerMaxHp: 1000,
      playerAttack: 10,
      floors: const [Foe(monster: MonsterId.ashSlime, maxHp: 100000, attack: 1)],
      rng: Random(1),
      heroSkills: true,
    );

MailItem _mail(int i, {Map<String, int> gifts = const {}, bool claimed = false}) => MailItem(
      id: 'm$i',
      kind: MailKind.reward,
      from: '하르트',
      title: '편지 $i',
      gifts: gifts,
      sentAt: vt0.subtract(Duration(hours: i)),
      expiresAt: vt0.add(const Duration(days: 20)),
      claimed: claimed,
    );

void main() {
  group('#334 알 등급', () {
    test('등급 · 열쇠 · 값', () {
      expect(EggGrade.ofKey('egg'), EggGrade.common);
      expect(EggGrade.ofKey('egg:legend'), EggGrade.legend);
      expect(EggGrade.ofKey('egg:nope'), isNull);
      expect(EggGrade.hero.key, 'egg:hero');
      expect([for (final g in EggGrade.values) g.price], [150, 500, 1500, 4000]);
    });

    test('알은 저장될 때 등급을 함께 남김', () {
      const e = PetEgg(id: 'e1', source: 'field', grade: EggGrade.rare);
      expect(PetEgg.fromJson(e.toJson()).grade, EggGrade.rare);
    });

    test('잡화상에서 알 팔기: 등급 값 · 품는 중인 알은 못 팖', () async {
      final c = await startVillage(14, farewell: true, more: {
        'pets': PetState(
          pets: [Pet(uid: 'p1', species: PetSpecies.owl, name: '부엉', bornAt: DateTime(2026, 11, 1))],
          companion: 'p1',
          firstPet: 'p1',
          firstSpiritName: '불씨',
          farewellAt: DateTime(2026, 11, 2),
          eggs: const [
            PetEgg(id: 'e1', source: 'field', grade: EggGrade.hero),
            PetEgg(id: 'e2', source: 'field'),
          ],
        ).toJson(),
      });
      final egg = c.pets.eggs.first;
      final gold = c.player.gold;
      expect(await c.sellEgg(egg.id), isTrue);
      expect(c.player.gold - gold, EggGrade.hero.price);
      expect(c.pets.eggs.where((e) => e.id == egg.id), isEmpty);
    });
  });

  test('#326 쪽지 확률', () {
    expect(AlchemyRules.noteFromErrand, 0.03);
    expect(AlchemyRules.noteFromRoadside, 0.03);
    expect(AlchemyRules.noteFromPouch, 0.01);
    expect(AlchemyRules.noteFromLegend, 0.30);
  });

  group('#325 스킬 숙련도', () {
    test('단계 · 비율 · 단계 말 · 한마디', () {
      expect(MasteryRules.skillStage(9.9), MasteryStage.clumsy);
      expect(MasteryRules.skillStage(10), MasteryStage.familiar);
      expect(MasteryRules.skillStage(120), MasteryStage.expert);
      expect(MasteryRules.skillStage(300), MasteryStage.master);
      expect(MasteryRules.skillFraction(40), 0.5);
      expect(MasteryRules.skillStageWord(MasteryStage.clumsy), isNull);
      expect(MasteryRules.skillStageWord(MasteryStage.master), '장인');
      expect(MasteryRules.skillUpLine('강타', MasteryStage.familiar), '강타가 손에 익었어!');
      expect(MasteryRules.skillUpLine('강타', MasteryStage.master), '이제 강타는 눈 감고도 하겠다!');
      expect(MasteryRules.cutTicks(6, 1), 5);
      expect(MasteryRules.cutTicks(8, 1), 7);
      expect(MasteryRules.cutTicks(6, 0.25), 6);
    });

    test('전투에서 쓴 스킬을 셈 (펫 스킬은 빼기)', () {
      final b = _battle();
      for (var i = 0; i < 10; i++) {
        b.tick();
      }
      expect(b.useBash(), isTrue);
      expect(b.useStance(), isTrue);
      expect(b.skillUses, {'bash': 1, 'stance': 1});
    });

    test('실제로 쓴 한 번 = 1 · 연습 0.2 · 스킬마다 하루 2까지 · 장인이면 대기 −10%', () async {
      final c = await startVillage(14);
      await c.gainSkillUses({'bash': 9});
      expect(c.skillStageOf('bash'), MasteryStage.clumsy);
      await c.gainSkillUses({'bash': 1});
      expect(c.skillStageOf('bash'), MasteryStage.familiar);
      // 연습: 0.2씩, 하루 2까지
      expect(await c.gainSkillUses({'stance': 5}, practice: true), isFalse);
      expect(c.skillMastery('stance'), 1.0);
      expect(await c.gainSkillUses({'stance': 20}, practice: true), isTrue);
      expect(c.skillMastery('stance'), 2.0);
      expect(await c.gainSkillUses({'stance': 3}, practice: true), isTrue);
      expect(c.skillMastery('stance'), 2.0);
      // 장인
      await c.gainSkillUses({'bash': 290});
      expect(c.skillStageOf('bash'), MasteryStage.master);
      final b = _battle();
      c.setupSkillMastery(b);
      expect(b.bashNeed, 5);
      expect(b.stanceNeed, Battle.stanceTicks);
      // 숙련 스킬은 힘 +10% · 대기 −10%
      await c.gainSkillUses({'m_smith': 300});
      final b2 = _battle();
      c.setupSkillMastery(b2);
      expect(b2.masteryPower[Mastery.smith], closeTo(1.1, 1e-9));
      expect(b2.masteryNeedOf(Mastery.smith), 6);
      // 단계 한마디는 정령 대사로
      expect(c.masteryState.pending, contains('이제 강타는 눈 감고도 하겠다!'));
      // 장인 목록 · 칭호와는 따로
      expect(c.masteryState.masters.where((k) => k.startsWith('skill:')), isEmpty);
    });

    test('직업 스킬: 장인이면 MP −10% · 힘 +10%', () async {
      final c = await startVillage(30, more: {
        'jobs': {'awakened': true, 'main': 'warrior', 'owned': ['warrior'], 'levels': {'ironWall': 1}},
      });
      final s = JobSkill.ironWall;
      final cost = c.skillCost(s), power = c.skillPower(s);
      await c.gainSkillUses({s.name: 300});
      expect(c.skillPower(s), closeTo(power * 1.1, 1e-9));
      expect(c.skillCost(s), max(1, (cost * 0.9).round()));
    });

    testWidgets('스킬 화면: 단계 말 · 장인 금테', (tester) async {
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      late AppController c;
      await tester.runAsync(() async {
        c = await startVillage(14);
        await c.gainSkillUses({'bash': 300, 'stance': 12});
      });
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => TopNoticeHost(child: child!),
          home: SkillScreen(controller: c)));
      await tester.pump();
      expect(find.byKey(const Key('skillMaster_bash')), findsOneWidget);
      // 묶음 78 #363: 단계 말은 버튼을 누르면 아래 설명에
      await tester.tap(find.byKey(const Key('battleFixed_strike')));
      await tester.pump();
      expect(find.textContaining('장인'), findsWidgets);
      await tester.tap(find.byKey(const Key('battleFixed_guard')));
      await tester.pump();
      expect(find.textContaining('익숙한'), findsWidgets);
      expect(find.byKey(const Key('skillMaster_stance')), findsNothing);
    });
  });

  test('#332 짝 칭호 설명 조사', () {
    expect(TitleRules.earnedLine(TitleId.pairRunesmith), contains('「룬 대장장이」를 찾았어요'));
    expect(TitleRules.earnedLine(TitleId.pairWeaponsmith), contains('「무기 장인」을 찾았어요'));
    expect(TitleRules.earnedLine(TitleId.pairRanger), contains('「레인저」를 찾았어요'));
    expect(TitleRules.earnedLine(TitleId.pairNightThief), contains('「밤의 도둑」을 찾았어요'));
  });

  group('#333 · #336 우편', () {
    test('선물 칸: 일부만 받으면 받은 것은 흐리게 · 다 받으면 모두 흐리게', () {
      final m = _mail(1, gifts: {'gold': 100, 'herb': 3})
          .copyWith(taken: {'egg:rare': 1});
      final cells = giftCells(m);
      expect([for (final x in cells) (x.key, x.taken)],
          [('gold', false), ('herb', false), ('egg:rare', true)]);
      final done = m.copyWith(claimed: true);
      expect(giftCells(done).every((x) => x.taken), isTrue);
      expect(MailItem.fromJson(m.toJson())!.taken, {'egg:rare': 1});
    });

    test('쪽 번호: 많으면 「1 … 4 5 6 … 12」', () {
      expect(MailPager.marks(0, 3), [0, 1, 2]);
      expect(MailPager.marks(4, 12), [0, null, 3, 4, 5, null, 11]);
      expect(MailPager.marks(0, 12), [0, 1, 2, 3, null, 11]);
      expect(MailPager.marks(11, 12), [0, null, 8, 9, 10, 11]);
    });

    testWidgets('한 쪽 15통 · 쪽 바꾸기 · 선물 통 → 가까운 쪽 · 1쪽뿐이면 줄 없음', (tester) async {
      tester.view.physicalSize = const Size(750, 1334);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      late AppController c;
      await tester.runAsync(() async {
        c = await startVillage(14, more: {
          'mail': MailState(mails: [
            for (var i = 0; i < 40; i++)
              _mail(i, gifts: i == 33 ? const {'gold': 50} : const {}, claimed: i != 33),
          ]).toJson(),
        });
      });
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => TopNoticeHost(child: child!),
          home: MailScreen(controller: c)));
      await tester.pump();
      expect(find.byKey(const Key('mailPager')), findsOneWidget);
      expect(find.byKey(const Key('mailRow_m0')), findsOneWidget);
      expect(find.byKey(const Key('mailRow_m15')), findsNothing);
      await tester.tap(find.byKey(const Key('mailPage_3')));
      await tester.pump();
      expect(find.byKey(const Key('mailRow_m30')), findsOneWidget);
      await tester.tap(find.byKey(const Key('mailPage_1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('mailGiftJump')));
      await tester.pump();
      expect(find.byKey(const Key('mailRow_m30')), findsOneWidget);
      await tester.scrollUntilVisible(find.byKey(const Key('mailRow_m33')), 60,
          scrollable: find.descendant(
              of: find.byKey(const Key('mailScroll')), matching: find.byType(Scrollable)));
      expect(find.byKey(const Key('mailGiftMark')), findsOneWidget);
    });
  });

  group('#335 프로필 사진', () {
    test('그림 있는 칭호 목록이 파일과 맞음', () {
      for (final s in kTitleArt) {
        expect(File('assets/images/$s.webp').existsSync(), isTrue, reason: s);
      }
    });

    test('고를 수 있는 것 · 저장 · 떠나보낸 펫이면 주인공 얼굴', () async {
      final c = await startVillage(14, farewell: true);
      expect(c.avatarFace, 'portrait_male');
      final pets = c.avatarChoices(AvatarTab.pet);
      expect(pets.single.key, 'pet:p1');
      await c.setAvatar('pet:p1');
      expect(c.avatarFace, pets.single.face);
      await c.setAvatar('pet:gone');
      expect(c.avatarFace, 'portrait_male');
      await c.setAvatar('title:nope');
      expect(c.avatarFace, 'portrait_male');
      expect(kFaceStem.hasMatch('../x'), isFalse);
    });

    testWidgets('「프로필 사진」 창: 탭 · 4칸 · 지금 것 ✓ · 누르면 바로', (tester) async {
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      late AppController c;
      await tester.runAsync(() async => c = await startVillage(14, farewell: true));
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: SizedBox(height: 600, child: AvatarPicker(controller: c)))));
      await tester.pump();
      expect(find.byKey(const Key('avatar_hero')), findsOneWidget);
      expect(find.byKey(const Key('avatarOn')), findsOneWidget);
      await tester.tap(find.byKey(const Key('avatarTab_pet')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('avatar_pet:p1')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
      expect(c.avatarKey, 'pet:p1');
      expect(find.byKey(const Key('avatarOn')), findsOneWidget);
    });
  });
}
