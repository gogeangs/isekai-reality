// 묶음 77: #357 보조 직업 Lv.20 · #358 이명 · #356 조합 화면 · #341~#347 직업 규칙 · #342 그림
// · #352 · #348 · #353 · #355 · #354 · #350 · #351 칭호 연출 · #337 몬스터 전용 장비

import 'dart:io';

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/armory.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/features/codex/codex_screen.dart';
import 'package:isekai_reality/features/jobs/guild_screen.dart';
import 'package:isekai_reality/features/jobs/skill_icon.dart';
import 'package:isekai_reality/features/profile/title_celebration.dart';
import 'package:isekai_reality/features/smithy/equipment_view.dart';
import 'package:isekai_reality/features/status/status_cards.dart';

import 'support/village_seed.dart';

Future<AppController> _job(String job,
        {int level = 20, List<String> subs = const [], Map<String, dynamic> extra = const {}}) =>
    startVillage(level, farewell: true, more: {
      'jobs': {
        'awakened': true,
        'v57': true,
        'main': job,
        'owned': [job, ...subs],
        'subs': subs,
      },
      ...extra,
    });

void _phone(WidgetTester t, {bool big = false}) {
  t.view.physicalSize = big ? const Size(1290, 2796) : const Size(750, 1334);
  t.view.devicePixelRatio = big ? 3 : 2;
  addTearDown(t.view.reset);
}

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('#357 보조 직업 Lv.20 · 각인 2단계 Lv.30', () {
    test('규칙 값', () {
      expect(JobPairRules.subJobLevel, 20);
      expect(JobPairRules.imprintDeepLevel, 30);
      expect(JobPairRules.imprintPower(29), 1.0);
      expect(JobPairRules.imprintPower(30), 1.5);
      expect(JobRules.subSlots(19), 0);
      expect(JobRules.subSlots(20), 1);
      expect(JobRules.subSlots(60), 1);
    });

    test('Lv.19는 보조 칸 없음 · Lv.20은 한 칸 + 카드 차례', () async {
      final a = await _job('warrior', level: 19);
      expect(a.subJobSlots, 0);
      expect(a.subJobsOpen, isFalse);
      expect(a.subJobIntroPending, isFalse);
      final b = await _job('warrior', level: 20);
      expect(b.subJobSlots, 1);
      await b.markSkillIntro();
      expect(b.pendingFeatureIntro, isNull);
      expect(b.subJobIntroPending, isTrue);
      await b.markSubJobIntro();
      expect(b.subJobIntroPending, isFalse);
    });

    testWidgets('조합 Lv.17: 보조 · 이명 · 각인 말이 없음, 아래 판 「이 직업으로 바꾸기」', (tester) async {
      _phone(tester, big: true);
      final c = await _job('warrior', level: 17);
      await tester.pumpWidget(_host(GuildScreen(controller: c)));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byKey(const Key('guildSub0')), findsNothing);
      expect(find.byKey(const Key('guildImprint')), findsNothing);
      expect(find.textContaining('보조'), findsNothing);
      expect(find.textContaining('이명'), findsNothing);
      expect(find.textContaining('각인'), findsNothing);
      await tester.tap(find.byKey(const Key('guildJob_mage')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('이 직업으로 바꾸기'), findsOneWidget);
      expect(find.byKey(const Key('jobAsSub')), findsNothing);
    });

    testWidgets('조합 Lv.20: 빈 보조 칸이 빛남 (glowSub)', (tester) async {
      _phone(tester, big: true);
      final c = await _job('warrior', level: 20);
      await tester.pumpWidget(_host(GuildScreen(controller: c, glowSub: true)));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byKey(const Key('guildSub0')), findsOneWidget);
      expect(find.byKey(const Key('guildSubGlow')), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('#358 · #346 이명', () {
    test('보이는 글은 「이명」, 「짝」 없음', () {
      for (final t in TitleRules.pairTitles) {
        final i = TitleRules.info(t);
        expect(i.name.contains('짝'), isFalse, reason: i.name);
      }
      expect(JobPairRules.specials.any((p) => p.id == 'spellblade'), isTrue);
      expect(JobPairRules.specials.any((p) => p.id == 'sage'), isTrue);
    });

    test('마검사 · 현자 스킬과 칭호 그림', () {
      expect(JobRules.skill(JobSkill.spellbladeSlash).name, '마검 베기');
      expect(JobRules.skill(JobSkill.sageStrike).name, '현자의 일섬');
      for (final f in ['title_pair_spellblade', 'title_pair_sage', 'skill_spellbladeSlash', 'skill_sageStrike']) {
        expect(File('assets/images/$f.webp').existsSync(), isTrue, reason: f);
      }
    });

    test('#347 장소 직업은 고르기 · 히든에 안 보임', () {
      for (final id in ['peddler', 'pathfinder', 'ranger']) {
        expect(JobPairRules.visibleSpecials.any((p) => p.id == id), isFalse, reason: id);
      }
    });
  });

  group('#341 · #343 · #344 직업 규칙', () {
    test('히든 직업도 주 스탯이 표에 있음', () {
      for (final j in JobId.values) {
        expect(JobRules.mainStat(j), isNotNull, reason: j.name);
      }
      expect(JobRules.mainStat(JobId.archaeologist), StatKind.intellect);
      expect(JobRules.mainStat(JobId.nightWalker), StatKind.luck);
    });

    test('분신 상성은 두 직업씩, 같은 직업이 몰리지 않음', () {
      final count = <JobId, int>{};
      for (final l in ErbardRules.cloneWeakTo.values) {
        expect(l.length, 2);
        for (final j in l) {
          count[j] = (count[j] ?? 0) + 1;
        }
      }
      for (final e in count.entries) {
        expect(e.value, lessThanOrEqualTo(4), reason: e.key.name);
      }
    });
  });

  group('#342 · #348 그림', () {
    test('생산 직업은 자기 그림 (남녀 · 대기 · 공격)', () {
      for (final j in [JobId.blacksmith, JobId.alchemist, JobId.herbalist, JobId.appraiser, JobId.merchant, JobId.tamer]) {
        expect(JobRules.heroArtJob(j), j);
        for (final f in ['hero_${j.name}_male', 'hero_${j.name}_female', 'hero_${j.name}_attack_male', 'hero_${j.name}_attack_female']) {
          expect(File('assets/images/$f.webp').existsSync(), isTrue, reason: f);
        }
      }
    });

    test('생활 스킬 아이콘 30장이 모두 있음', () {
      expect(SkillArt.lifeArt.length, 30);
      for (final s in SkillArt.lifeArt) {
        expect(File('assets/images/skill_${s.name}.webp').existsSync(), isTrue, reason: s.name);
      }
    });

    test('「새로 열렸어요 · 스킬」 카드 그림: 주 직업 첫 스킬 그림이 모두 있음', () {
      for (final j in JobId.values) {
        final s = JobRules.info(j).skills;
        if (s.isEmpty) continue;
        final art = SkillArt.job(s.first).$2;
        expect(File('assets/images/$art.webp').existsSync(), isTrue, reason: '${j.name} $art');
      }
      expect(File('assets/images/icon_medal.webp').existsSync(), isTrue);
    });

    test('몬스터 전용 장비 그림 13장', () {
      for (final i in MonGearRules.infos) {
        expect(File('assets/images/${i.asset}.webp').existsSync(), isTrue, reason: i.asset);
      }
    });
  });

  group('#353 · #355 상태', () {
    testWidgets('스탯 · 스킬 카드: Lv.14는 스킬 칸 잠김 글', (tester) async {
      _phone(tester);
      final c = await startVillage(14, farewell: true);
      await tester.pumpWidget(_host(StatusCards(controller: c)));
      await tester.pump();
      expect(find.byKey(const Key('statsOpen')), findsOneWidget);
      expect(find.byKey(const Key('skillsOpen')), findsOneWidget);
      expect(find.byKey(const Key('skillsLocked')), findsOneWidget);
    });
  });

  group('#351 칭호 연출', () {
    test('등급: 보통 · 희귀 · 전설', () {
      expect(TitleRules.gradeOf(TitleId.pairSpellblade), TitleGrade.rare);
      expect(TitleRules.gradeOf(TitleId.guildLegend), TitleGrade.legend);
      expect(TitleRules.gradeOf(TitleId.basiliskSlayer), TitleGrade.rare);
      expect(TitleRules.gradeLabel(TitleGrade.legend), isNotEmpty);
      for (final t in TitleRules.legendTitles) {
        expect(TitleRules.gradeOf(t), TitleGrade.legend, reason: t.name);
      }
    });

    for (final (t, g) in [
      (TitleId.basiliskSlayer, TitleGrade.rare),
      (TitleId.guildLegend, TitleGrade.legend),
    ]) {
      testWidgets('끝 화면 · 누르면 건너뜀 (${g.name})', (tester) async {
        _phone(tester);
        final c = await startVillage(20, farewell: true);
        await tester.pumpWidget(_host(TitleCelebration(controller: c, title: t)));
        await tester.pump(const Duration(milliseconds: 100));
        // 아직 버튼이 보이지 않음 → 누르면 끝 화면
        await tester.tap(find.byKey(const Key('titleCelebration')), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byKey(Key('titleGrade_${g.name}')), findsOneWidget);
        expect(find.byKey(const Key('titleEquip')), findsOneWidget);
        expect(find.byKey(const Key('titleLegendLine')), g == TitleGrade.legend ? findsOneWidget : findsNothing);
        await tester.pumpWidget(const SizedBox());
      });
    }
  });

  group('#337 몬스터 전용 장비', () {
    test('13종 · 단계 대장간 0.9배 · 만들 수 없음', () {
      expect(MonGearRules.byMonster.length, 13);
      for (final m in MonGearRules.byMonster.keys) {
        expect(FieldMonsterRules.isTierMonster(m), isTrue, reason: m.name);
      }
      for (final i in MonGearRules.infos) {
        expect(i.recipe, isEmpty);
        expect(EquipmentRules.all.any((e) => e.id == i.id), isFalse);
        expect(i.trait, isNotNull);
      }
      final dagger = EquipmentRules.info(EquipBase.monGoblinDagger);
      expect(dagger.attack, closeTo(BossGearRules.baseStat(EquipSlot.weapon).attack * 0.9, 0.001));
      expect(MonGearRules.dropChance(ModGrade.none), 0.03);
      expect(MonGearRules.dropChance(ModGrade.rare), 0.08);
      expect(MonGearRules.dropChance(ModGrade.legend), 0.20);
      expect(MonGearRules.chanceFor(ModGrade.legend, sameToday: 5), 0.10);
      expect(MonGearRules.gearOf(MonsterId.giantRat), isNull);
    });

    test('떨어지면 가방에 · 도감 표시 · 결과 창용 한 번', () async {
      final c = await _job('warrior', level: 30);
      final before = c.armory.items.length;
      EquipItem? got;
      for (var i = 0; i < 40 && got == null; i++) {
        got = await c.rollMonGearForTest(MonsterId.orcMerc);
      }
      expect(got, isNotNull);
      expect(got!.base, EquipBase.monOrcAxe);
      expect([EquipGrade.white, EquipGrade.green, EquipGrade.blue], contains(got.grade));
      expect(c.armory.items.length, before + 1);
      expect(c.monGearFound(EquipBase.monOrcAxe), isTrue);
      expect(c.takeBattleMonGear()?.uid, got.uid);
      expect(c.takeBattleMonGear(), isNull);
    });

    testWidgets('결과 창 띠 · 도감 「떨어뜨리는 것」', (tester) async {
      _phone(tester);
      const item = EquipItem(uid: 'eq1', base: EquipBase.monDeathSword, grade: EquipGrade.blue);
      await tester.pumpWidget(_host(const Center(child: MonGearGotBanner(item: item))));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('데스나이트의 대검을 얻었어요!'), findsOneWidget);

      await tester.pumpWidget(_host(const CodexScreen(
          purifiedMonsters: {MonsterId.ogre}, huntCounts: {MonsterId.ogre: 3})));
      await tester.pump();
      await tester.tap(find.byKey(const Key('codexTile_ogre')).first, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('codexDrops')), findsOneWidget);
      expect(find.byKey(const Key('codexDropUnknown')), findsOneWidget);
    });
  });
}
