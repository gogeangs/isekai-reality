// 묶음 76: #307 직업별 주인공 그림 · #310 · #315 방패 · #316 부화장 · #317 간식 그림 · #338 막기 버튼
// · #339 프로필 두 줄 · #340 직업 고르기 · #341 직업 주 스탯

import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/storage/record_store.dart' show HeroLook;
import 'package:isekai_reality/features/battle/battle_view.dart';
import 'package:isekai_reality/features/jobs/guild_screen.dart';
import 'package:isekai_reality/features/jobs/job_picker.dart';
import 'package:isekai_reality/features/profile/profile_screen.dart';
import 'package:isekai_reality/features/status/stat_screen.dart';
import 'package:isekai_reality/features/village/hatchery.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'support/village_seed.dart';

class _Fixed implements Random {
  _Fixed(this.v);
  double v;
  @override
  double nextDouble() => v;
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
}

Future<AppController> _job(String job, {int level = 20, Map<String, dynamic> extra = const {}}) =>
    startVillage(level, farewell: true, more: {
      'jobs': {'awakened': true, 'v57': true, 'main': job, 'owned': [job]},
      ...extra,
    });

void _phone(WidgetTester t, {bool big = false}) {
  t.view.physicalSize = big ? const Size(1290, 2796) : const Size(750, 1334);
  t.view.devicePixelRatio = big ? 3 : 2;
  addTearDown(t.view.reset);
}

void main() {
  group('#307 직업별 주인공 그림', () {
    test('표: 전투 6 · 생산 · 히든은 가까운 전투 직업 · 직업 없음은 null', () {
      expect(JobRules.heroArtJob(null), isNull);
      for (final j in JobRules.combatArtJobs) {
        expect(JobRules.heroArtJob(j), j);
      }
      expect(JobRules.heroArtJob(JobId.blacksmith), JobId.warrior);
      expect(JobRules.heroArtJob(JobId.allCrafter), JobId.warrior);
      expect(JobRules.heroArtJob(JobId.herbalist), JobId.archer);
      expect(JobRules.heroArtJob(JobId.ashHunter), JobId.archer);
      expect(JobRules.heroArtJob(JobId.alchemist), JobId.mage);
      expect(JobRules.heroArtJob(JobId.archaeologist), JobId.mage);
      expect(JobRules.heroArtJob(JobId.pilgrim), JobId.priest);
      expect(JobRules.heroArtJob(JobId.merchant), JobId.rogue);
      expect(JobRules.heroArtJob(JobId.nightWalker), JobId.rogue);
      expect(JobRules.heroArtJob(JobId.tamer), JobId.knight);
      expect(JobRules.heroArtJob(JobId.gateHeir), JobId.knight);
      for (final j in JobId.values) {
        final a = JobRules.heroArtJob(j)!;
        for (final f in ['hero_${a.name}_male', 'hero_${a.name}_attack_female']) {
          expect(File('assets/images/$f.webp').existsSync(), isTrue, reason: f);
        }
      }
    });

    test('주 직업을 바꾸면 그림 직업도 바로', () async {
      final c = await _job('alchemist');
      expect(c.heroJobArt, 'mage');
      final none = await startVillage(14);
      expect(none.heroJobArt, isNull);
    });

    testWidgets('전투: 대기 = 직업 그림 1칸, 승리 · 지침은 그대로', (tester) async {
      await tester.pumpWidget(const MaterialApp(
          home: Column(children: [
        SizedBox(height: 200, child: HeroSprite(look: HeroLook.female, pose: HeroPose.idle, job: 'archer')),
        SizedBox(height: 200, child: HeroSprite(look: HeroLook.male, pose: HeroPose.attack, job: 'mage', frame: 3)),
        SizedBox(height: 100, child: HeroSprite(look: HeroLook.male, pose: HeroPose.victory, job: 'mage')),
      ])));
      final assets = [
        for (final e in find.byType(Image).evaluate())
          ((e.widget as Image).image as AssetImage).assetName,
      ];
      expect(assets, [
        'assets/images/hero_archer_attack_female.webp',
        'assets/images/hero_mage_attack_male.webp',
        'assets/images/hero_victory_male.webp',
      ]);
      expect(find.byKey(const Key('heroFrame_0')), findsOneWidget);
      expect(find.byKey(const Key('heroFrame_3')), findsOneWidget);
    });
  });

  group('#341 직업 주 스탯', () {
    test('표 · 복합은 첫 짝 · 바탕 비율', () {
      expect(JobRules.mainStat(JobId.warrior), StatKind.strength);
      expect(JobRules.mainStat(JobId.blacksmith), StatKind.strength);
      expect(JobRules.mainStat(JobId.knight), StatKind.vitality);
      expect(JobRules.mainStat(JobId.tamer), StatKind.vitality);
      expect(JobRules.mainStat(JobId.archer), StatKind.agility);
      expect(JobRules.mainStat(JobId.herbalist), StatKind.agility);
      for (final j in [JobId.mage, JobId.priest, JobId.alchemist, JobId.appraiser]) {
        expect(JobRules.mainStat(j), StatKind.intellect, reason: j.name);
      }
      expect(JobRules.mainStat(JobId.rogue), StatKind.luck);
      expect(JobRules.mainStat(JobId.merchant), StatKind.luck);
      expect(JobRules.info(JobId.mage).mainStat, StatKind.intellect);
      for (final j in JobId.values) {
        JobRules.mainStat(j); // 모든 직업에 값이 있음
      }
      const s = Stats(strength: 10, intellect: 30);
      // (2.5×20 + 5×30) / (2.5×20 + 5×10) = 200 / 100
      expect(JobRules.statRatio(StatKind.intellect, level: 20, stats: s), 2.0);
      expect(JobRules.statRatio(StatKind.strength, level: 20, stats: s), 1.0);
    });

    test('같은 Lv 마법사: 지능을 올리면 스킬 세기가 오름 · 강타 · 기본 공격은 힘 그대로', () async {
      final c = await _job('mage', level: 30, extra: {
        'jobs': {'awakened': true, 'v57': true, 'main': 'mage', 'owned': ['mage'], 'loadout': ['job:${JobRules.firstOf(JobId.mage).name}']},
      });
      final s = JobRules.firstOf(JobId.mage);
      final before = c.battleJobSlots.single.$3;
      final want = JobRules.statRatio(StatKind.intellect, level: c.player.level.level, stats: c.combatStats + c.gear.stats);
      expect(before, closeTo(c.skillPower(s) * want, 1e-9));
      expect(await c.allocateStats(const Stats(intellect: 3)), isTrue);
      expect(c.battleJobSlots.single.$3, greaterThan(before));
    });

    test('돌격 명령 · 휘파람 신호도 주 스탯 바탕 (정령의 일격 비율 대신)', () {
      final b = Battle(
        playerMaxHp: 1000,
        playerAttack: 100,
        skillDamage: 99999,
        floors: const [Foe(monster: MonsterId.ashSlime, maxHp: 1000000, attack: 1)],
        rng: _Fixed(0.5),
        heroSkills: true,
      );
      final hp = b.foeHp;
      expect(b.useJobSkill(JobSkill.chargeOrder, power: 1), isTrue);
      final dealt = hp - b.foeHp;
      expect(dealt, lessThan(1000), reason: '정령의 일격 값(99999)과 상관없이 공격 바탕 × 배율');
    });

    testWidgets('스탯 분배 화면: 주 직업 스탯 줄 금테 + 「마법사 스킬」', (tester) async {
      _phone(tester, big: true);
      late AppController c;
      await tester.runAsync(() async => c = await _job('mage', extra: {
            'jobs': {'awakened': true, 'v57': true, 'main': 'mage', 'owned': ['mage', 'merchant'], 'subs': ['merchant']},
          }));
      await tester.pumpWidget(MaterialApp(home: StatScreen(controller: c)));
      await tester.pump();
      expect(find.text('마법사 스킬'), findsOneWidget);
      expect(find.byKey(const Key('statJob_intellect')), findsOneWidget);
      if (c.subJob == JobId.merchant) {
        expect(find.text('보조 · 상인 스킬'), findsOneWidget);
      }
    });

    testWidgets('조합 직업 요약에 「잘 맞는 스탯」', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: JobSummary(job: JobId.knight))));
      expect(find.text('잘 맞는 스탯 · 체력'), findsOneWidget);
    });
  });

  group('#338 막기 버튼', () {
    testWidgets('경고 동안 「방어 태세」 자리에 「막기!」 · 다른 버튼은 쉼 · 무대 글은 아래', (tester) async {
      _phone(tester);
      final b = Battle(
        playerMaxHp: 100000,
        playerAttack: 30,
        floors: const [Foe(monster: MonsterId.fireSlimeKing, maxHp: 100000, attack: 10)],
        rng: _Fixed(0.5),
        telegraphs: true,
        heroSkills: true,
      );
      b.tick();
      b.tick();
      expect(b.strongNext, isTrue);
      b.bashCharge = Battle.bashTicks;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: BattleView(battle: b, onFinished: () {}, tickInterval: const Duration(seconds: 30))))));
      await tester.pump();
      expect(find.byKey(const Key('guardButton')), findsOneWidget);
      expect(find.byKey(const Key('stanceButton')), findsNothing);
      expect(find.text('아래 「막기!」를 눌러요'), findsOneWidget);
      // 강타를 눌러도 강타는 나가지 않고 막기로만
      await tester.tap(find.byKey(const Key('bashButton')));
      await tester.pump();
      expect(b.bashes, 0);
      expect(find.text('막기 준비!'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 31));
    });
  });

  testWidgets('#339 프로필 위 칸: 함께하는 펫 · 처음 함께한 정령 줄 없음', (tester) async {
    _phone(tester, big: true);
    late AppController c;
    await tester.runAsync(() async => c = await startVillage(14, farewell: true));
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => TopNoticeHost(child: child!), home: ProfileScreen(controller: c)));
    await tester.pump();
    expect(find.textContaining('함께하는 펫 · '), findsNothing);
    expect(find.textContaining('처음 함께한 정령 · '), findsNothing);
  });

  testWidgets('#316 부화장: 빈 둥지 하나면 안내 글은 판 가운데 아래 한 줄 (안 잘림)', (tester) async {
    _phone(tester);
    late AppController c;
    await tester.runAsync(() async => c = await startVillage(11, farewell: true));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Padding(padding: const EdgeInsets.all(12), child: HatcheryPanel(controller: c)))));
    await tester.pump();
    final t = tester.widget<Text>(find.byKey(const Key('nestEmptyLine')));
    expect(t.data, '알을 얻으면 여기서 품어요');
    expect(t.overflow, isNot(TextOverflow.ellipsis));
    expect(tester.takeException(), isNull);
  });

  group('#340 직업 고르기', () {
    Future<AppController> merchant() => startVillage(15, farewell: true, more: {
          'mastery': {
            'big': {'trade': 50.0, 'combat': 5.0},
          },
        });

    testWidgets('추천 상인 · 생산 탭으로 열림 · 고르면 바로 바뀜 · 보조 단계 없이 시작', (tester) async {
      _phone(tester);
      late AppController c;
      await tester.runAsync(() async => c = await merchant());
      expect(c.recommendedJob, JobId.merchant);
      expect(c.recommendReason, '지금까지 장사와 의뢰를 가장 많이 했어요');
      await tester.pumpWidget(MaterialApp(home: JobAwakenScreen(controller: c)));
      await tester.pump();
      await tester.tap(find.byKey(const Key('jobAwakenGo')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('jobPick_merchant')), findsOneWidget);
      expect(find.byKey(const Key('jobRecRibbon_merchant')), findsOneWidget);
      expect(find.byKey(const Key('jobTabDot_combat')), findsNothing);
      expect(find.text('상인으로 시작할래요'), findsOneWidget);
      expect(find.text('✦ 추천 이유 · 지금까지 장사와 의뢰를 가장 많이 했어요'), findsOneWidget);
      // 전투 탭 · 궁수
      await tester.tap(find.byKey(const Key('jobTabCombat')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('jobPick_archer')));
      await tester.pump();
      expect(find.byKey(const Key('jobPreviewHero_archer')), findsOneWidget);
      expect(find.text('잘 맞는 스탯 · 민첩'), findsOneWidget);
      expect(find.text('잘 맞는 무기 · 활'), findsOneWidget);
      expect(find.textContaining('✦ 추천은 상인'), findsOneWidget);
      expect(find.text('궁수로 시작할래요'), findsOneWidget);
      // 스킬 아이콘 → 아래 칸
      final first = JobRules.firstOf(JobId.archer);
      await tester.ensureVisible(find.byKey(Key('jobSkill_${first.name}')));
      await tester.tap(find.byKey(Key('jobSkill_${first.name}')));
      await tester.pump();
      expect(find.byKey(const Key('jobSkillDetail')), findsOneWidget);
      expect(find.text('처음부터 열려요'), findsOneWidget);
      // 「추천은 …」 띠 → 추천 직업 + 그 탭
      await tester.ensureVisible(find.byKey(const Key('jobRecBand')));
      await tester.tap(find.byKey(const Key('jobRecBand')));
      await tester.pump();
      expect(find.text('상인으로 시작할래요'), findsOneWidget);
      await tester.tap(find.byKey(const Key('jobPickMain')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 500));
      expect(c.mainJob, JobId.merchant);
      expect(c.subJobs, isEmpty);
      expect(find.byKey(const Key('jobAwakenDone')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 2));
    });

    test('쓰는 곳 칩 글', () {
      expect(skillPlaceLabel(SkillPlace.lens), '감정 렌즈');
    });
  });
}
