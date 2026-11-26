import 'dart:math' as math;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/pet_state.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/features/codex/codex_page.dart';
import 'package:isekai_reality/features/village/garden_screen.dart';

import 'support/village_seed.dart';

/// 묶음 85: 레벨 난이도 · 물약 재료 · 스킬 5단계 · 쪽지 · 하늘 계단 · 실패 손실 · 머리 위 HP ·
/// 칸 3 · 4 · 첫 펫 보내기 · 도감은 프로필 · 가방 · 약초밭 · 돋보기 끄기
Map<String, dynamic> awakened({String main = 'warrior', List<String> owned = const ['warrior'], Map<String, dynamic> extra = const {}}) => {
      'jobs': {
        'awakened': true,
        'v57': true,
        'v31': true,
        'pageOpen': true,
        'pageIntro': true,
        'main': main,
        'owned': owned,
        ...extra,
      },
    };

void main() {
  group('#408 레벨 난이도', () {
    test('Lv.11부터 1.5%씩 · Lv.10까지 그대로', () {
      expect(BattleRules.levelMult(5), 1);
      expect(BattleRules.levelMult(10), 1);
      expect(BattleRules.levelMult(11), closeTo(1.015, 1e-9));
      expect(BattleRules.levelMult(30), closeTo(1.3, 1e-9));
    });

    test('새 기준(주 스탯 3/5 · 보통 장비)이 더 세다', () {
      for (final l in [11, 21, 30]) {
        expect(BattleRules.baselineAttack(l), greaterThan(BattleRules.evenAttack(l)));
      }
    });
  });

  group('#413 단계 몬스터도 물약 재료', () {
    test('숲 → 슬라임 젤리 · 물가 → 물 젤리 · 밤 → 나비 가루 · 40% 안팎', () {
      final tierDay = FieldMonsterRules.tierMonsters.firstWhere((m) => !LootRules.nightTier(m));
      final rng = math.Random(7);
      var got = 0;
      const n = 4000;
      for (var i = 0; i < n; i++) {
        final d = LootRules.field(tierDay, rng, land: LandKind.forest);
        if ((d[MaterialId.slimeJelly] ?? 0) > 0) got++;
      }
      expect(got / n, inInclusiveRange(0.33, 0.5));
      expect(LootRules.potionMatFor(tierDay, LandKind.water, rng), MaterialId.waterJelly);
      expect(LootRules.potionMatFor(MonsterId.vampireBat, LandKind.forest, rng), MaterialId.butterflyDust);
      expect(LootRules.codexPotionMats(MonsterId.vampireBat), [MaterialId.butterflyDust]);
    });
  });

  group('#414 스킬 5단계 · 직업 숙련', () {
    test('세기 1.75 · 2.0 · 4단계 Lv.25 · 5단계 Lv.35', () {
      expect(JobRules.levelPower(4), 1.75);
      expect(JobRules.levelPower(5), 2.0);
      expect(JobRules.levelOpensAt(4), 25);
      expect(JobRules.levelOpensAt(5), 35);
      expect(JobRules.levelMpCut(5), 0.5);
    });

    test('Lv.24: 3단계에서 멈춤 · Lv.35: 5단계까지 · 다 올리면 직업 숙련 · 다시 나누면 돌려받음', () async {
      final low = await startVillage(24, farewell: true, more: awakened());
      final s = JobRules.info(JobId.warrior).skills.first;
      for (var i = 0; i < 2; i++) {
        expect(await low.raiseSkill(s), isTrue);
      }
      expect(low.skillLevel(s), 3);
      expect(low.canRaiseSkill(s), isFalse);
      expect(low.skillLockedAt(s), 25);

      final c = await startVillage(50, farewell: true, more: awakened());
      for (final k in JobRules.info(JobId.warrior).skills) {
        while (c.canRaiseSkill(k)) {
          await c.raiseSkill(k);
        }
        expect(c.skillLevel(k), 5);
      }
      expect(c.jobSkillsMaxed(JobId.warrior), isTrue);
      // 스킬은 더 못 올림 → 빨간 점 없음 (포인트가 남아도)
      expect(c.skillPointsLeftOn(JobId.warrior), greaterThan(0));
      expect(c.skillRaisable, isFalse);
      final before = c.skillPower(s);
      expect(await c.raiseDrill(JobId.warrior), isTrue);
      expect(c.jobDrill(JobId.warrior), 1);
      expect(c.skillPower(s), closeTo(before * 1.01, 1e-9));
      while (c.canRaiseDrill(JobId.warrior)) {
        await c.raiseDrill(JobId.warrior);
      }
      expect(c.jobDrill(JobId.warrior), lessThanOrEqualTo(JobRules.drillMax));
      await c.resetSkills();
      expect(c.jobDrill(JobId.warrior), 0);
      expect(c.skillPointsLeftOn(JobId.warrior), JobRules.pointsFor(50));
    });
  });

  group('#418 레시피 쪽지', () {
    test('연금술사 · 각성 전은 그대로 · 다른 직업은 1/3', () async {
      final pre = await startVillage(12, farewell: true);
      expect(pre.notesOften, isTrue);
      final alc = await startVillage(20, farewell: true, more: awakened(main: 'alchemist', owned: ['alchemist']));
      expect(alc.notesOften, isTrue);
      final war = await startVillage(20, farewell: true, more: awakened());
      expect(war.notesOften, isFalse);
      expect(AlchemyRules.noteOtherShare, closeTo(1 / 3, 1e-9));
      expect(JobRules.info(JobId.alchemist).trait, contains('레시피 쪽지를 더 자주 찾아요'));
    });
  });

  test('#405 하늘 세트 실패 손실 = 새 값의 1/3', () {
    final loss = {
      for (final (b, _, _) in BossGearRules.skySet.parts) EquipmentRules.info(b).slot: BossGearRules.failLossOf(b).shards,
    };
    expect(loss, {
      EquipSlot.weapon: 4,
      EquipSlot.body: 3,
      EquipSlot.head: 2,
      EquipSlot.accessory: 2,
      EquipSlot.hands: 1,
      EquipSlot.feet: 1,
    });
  });

  group('#420 각성 뒤 칸 3 · 4', () {
    test('각성 전: 그대로 (칸 2개 · 강타 · 방어 태세 고정)', () async {
      final c = await startVillage(12, farewell: true);
      expect(c.fourSlots, isFalse);
      expect(c.battleBar, isNull);
    });

    test('각성 뒤: 기본 강타 · 방어 태세 · 같은 스킬은 두 칸에 못 넣음', () async {
      final c = await startVillage(20, farewell: true, more: awakened());
      expect(c.fourSlots, isTrue);
      expect(c.battleExtra, ['base:bash', 'base:stance']);
      expect(c.battleBar!.take(2), ['base:bash', 'base:stance']);
      // 칸 1에 강타를 넣으면 칸 3과 맞바꿈
      final before = c.battleSlots;
      await c.setLoadout(0, 'base:bash');
      expect(c.battleSlots[0], 'base:bash');
      expect(c.battleSlots[2], before[0]);
      expect(c.battleSlots.where((e) => e == 'base:bash'), hasLength(1));
      // 칸 4를 비움
      await c.setLoadout(3, null);
      expect(c.battleSlots[3], '');
      expect(c.battleBar![1], '');
    });
  });

  group('#409 첫 펫 보내기', () {
    Future<AppController> twoPets({bool away = false}) => startVillage(15, more: {
          'pets': PetState(
            pets: [
              Pet(uid: 'p1', species: PetSpecies.owl, name: '부엉', bornAt: DateTime(2026, 11, 1)),
              Pet(uid: 'p2', species: PetSpecies.blackCat, name: '나비', bornAt: DateTime(2026, 11, 3)),
            ],
            companion: 'p1',
            firstPet: 'p1',
            firstSpiritName: '불씨',
            farewellAt: DateTime(2026, 11, 2),
          ).toJson(),
        });

    test('첫 펫도 보낼 수 있음 · 첫 펫 기록은 남음 · 말하는 펫은 데리고 다니는 펫', () async {
      final c = await twoPets();
      expect(c.isFirstPet('p1'), isTrue);
      expect(c.releaseBlock('p1'), isNull);
      expect(await c.releasePet('p1'), isTrue);
      expect(c.pets.firstPet, 'p1');
      expect(c.firstPet, isNull);
      expect(c.companionPet?.uid, 'p2');
      expect(c.voicePet?.name, '나비');
      expect(c.companionName, '나비');
      expect(c.farewellPending, isFalse);
      expect(c.firstSpiritName, '불씨');
      // 마지막 한 마리
      expect(c.releaseBlock('p2'), '마지막 한 마리는 보낼 수 없어요');
      expect(await c.releasePet('p2'), isFalse);
    });
  });

  group('#416 돋보기 끄기', () {
    test('Lv.10이어도 돋보기 안 열림 · 직업 고르기 · 곧 열릴 직업에 감정 직업 없음', () async {
      expect(LensRules.lensOn, isFalse);
      final c = await startVillage(15, farewell: true);
      expect(c.featureOpen(Feature.lens), isFalse);
      expect(c.jobChoices, isNot(contains(JobId.appraiser)));
      expect(c.nearJobs.where(JobPairRules.lensJobs.contains), isEmpty);
      expect(JobPairRules.craftShown(const {}), isNot(contains(JobId.appraiser)));
      expect(JobPairRules.craftShown(const {JobId.appraiser}), contains(JobId.appraiser));
      expect(JobPairRules.visibleSpecials.map((p) => p.id), isNot(contains('sage')));
      expect(JobPairRules.visibleSpecials.map((p) => p.id), isNot(contains('jeweler')));
    });

    test('이미 감정사인 사람은 그대로', () async {
      final c = await startVillage(20, farewell: true, more: awakened(main: 'appraiser', owned: ['appraiser']));
      expect(c.mainJob, JobId.appraiser);
      expect(c.unlockedJobs, contains(JobId.appraiser));
    });
  });

  test('#411 약초밭 씨앗마다 그림', () {
    String a(MaterialId? seed, int stage) => GardenScreen.plotAsset(GardenPlotView(slot: 0, seed: seed, walked: stage == 2 ? 10 : stage == 1 ? 6 : 0, need: 10));
    expect(a(null, 0), contains('garden_plot_empty'));
    expect(a(MaterialId.herbSeed, 2), contains('ready_herb'));
    expect(a(MaterialId.flowerSeed, 2), endsWith('garden_plot_ready.webp'));
    expect(a(MaterialId.sporeSeed, 2), contains('ready_mushroom'));
    expect(a(MaterialId.glowSeed, 2), contains('ready_glow'));
    expect(a(MaterialId.sporeSeed, 1), contains('grow_mushroom'));
    expect(a(MaterialId.herbSeed, 1), endsWith('garden_plot_grow.webp'));
  });

  testWidgets('#419 아래 탭 4개 · 프로필 도감 버튼 · 빨간 점', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    late AppController c;
    await tester.runAsync(() async {
      c = await startVillage(12, farewell: true, more: {
        'feel': {'codexSeen': <String>[], 'codexNoticed': <String>[]},
      });
    });
    await tester.pumpWidget(IsekaiRealityApp(controller: c));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('nav_3')), findsOneWidget);
    expect(find.byKey(const Key('nav_4')), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('#419 도감 화면은 뒤로 가기', (tester) async {
    late AppController c;
    await tester.runAsync(() async => c = await startVillage(12, farewell: true));
    await tester.pumpWidget(MaterialApp(home: CodexPage(controller: c)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('codexPage')), findsOneWidget);
    expect(find.text('도감'), findsWidgets);
    await tester.pump(const Duration(seconds: 9));
  });
}
