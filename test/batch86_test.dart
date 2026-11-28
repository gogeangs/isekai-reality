import 'dart:math' as math;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/features/jobs/skill_screen.dart';

import 'batch85_test.dart' show awakened;
import 'support/village_seed.dart';

/// 묶음 86: 밸런스 · 한 주머니 포인트 · 직업 숙련 · 스킬북 · 직업 바꾸기 · 스킬 한 화면 · 화면 손질
Future<AppController> job(int level,
        {String main = 'warrior', List<String> owned = const ['warrior'], List<String> subs = const [], int gold = 0}) =>
    startVillage(level,
        farewell: true,
        gains: {if (gold > 0) 'gold': gold},
        more: awakened(main: main, owned: owned, extra: {'subs': subs}));

/// 묶음 86: 스킬 화면은 전투 칸이 위에 붙어 있어 가운데로 보이게
Future<void> showMid(WidgetTester tester, Finder f) async {
  await tester.runAsync(() => Scrollable.ensureVisible(tester.element(f), alignment: 0.5));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  group('A 밸런스', () {
    test('#421 하이랜드 바람 28 · 20 · 13', () {
      expect([for (final f in SkyWalkRules.floors) f.wind], [28, 20, 13]);
    });

    test('#422 고르게 · 장비 없는 계정도 Lv.11~15 던전 절반 넘게 · Lv.16부터는 그대로', () {
      for (final lv in [11, 13, 15]) {
        var clears = 0;
        for (var s = 0; s < 40; s++) {
          final b = Battle.forPlayer(
                  level: lv,
                  stats: BattleRules.expectedStats(lv),
                  rng: math.Random(s),
                  floors: BattleRules.dungeonFloors(level: lv, atGate: false, rng: math.Random(s)))
              .runToEnd();
          if (b.phase == BattlePhase.cleared) clears++;
        }
        expect(clears / 40, greaterThanOrEqualTo(0.5), reason: 'Lv.$lv');
      }
      expect(BattleRules.dungeonAttack(16), BattleRules.expectedAttack(16));
      expect(BattleRules.dungeonAttack(10), BattleRules.expectedAttack(10));
    });

    test('#424 단계 몬스터 레시피 재료 (숲 토끼 고기 · 작은 엄니 / 밤 잠의 가루 / 희귀 수식어 황금빛 토끼털)', () {
      final day = FieldMonsterRules.tierMonsters.firstWhere((m) => !LootRules.nightTier(m));
      expect(LootRules.tierRecipeMats(day, LandKind.forest), [MaterialId.rabbitMeat, MaterialId.smallTusk]);
      expect(LootRules.tierRecipeMats(day, LandKind.city), isEmpty);
      expect(LootRules.tierRecipeMats(MonsterId.vampireBat, LandKind.forest), [MaterialId.sleepPowder]);
      expect(LootRules.tierRecipeMats(day, LandKind.city, rareMod: true), [MaterialId.goldenRabbitFur]);
      final rng = math.Random(3);
      var got = 0;
      for (var i = 0; i < 3000; i++) {
        final d = LootRules.field(day, rng, land: LandKind.forest);
        if ((d[MaterialId.rabbitMeat] ?? 0) + (d[MaterialId.smallTusk] ?? 0) > 0) got++;
      }
      expect(got / 3000, inInclusiveRange(0.10, 0.22));
      expect(LootRules.codexTierRecipeMats(day), contains(MaterialId.goldenRabbitFur));
    });

    test('#427 가방 한 칸 값 상한 없음', () {
      expect(BagRules.slotCost(19), 2170);
      expect(BagRules.slotCost(20), 2380);
      expect(BagRules.slotCost(30), 5030);
    });
  });

  group('B 스킬 · 직업', () {
    test('#431 한 주머니: Lv.15 = 3점 · 레벨마다 3 · 주 · 보조가 같은 주머니', () async {
      expect(JobRules.pointsFor(15), 3);
      expect(JobRules.pointsFor(20), 18);
      final c = await job(20, owned: ['warrior', 'mage'], subs: ['mage']);
      expect(c.skillPointsLeft, 18);
      final w = JobRules.info(JobId.warrior).skills[1];
      final m = JobRules.info(JobId.mage).skills[1];
      expect(await c.raiseSkill(w), isTrue);
      expect(await c.raiseSkill(m), isTrue);
      expect(c.skillPointsLeft, 16);
      expect(c.skillPointsLeftOn(JobId.warrior), 16);
      await c.resetSkills();
      expect(c.skillPointsLeft, 18);
    });

    test('#423 직업 숙련: Lv.15~24 = 3단계까지 다 올리면 열림 · Lv.25에 4단계 열리면 한 줄', () async {
      final c = await job(24);
      final skills = JobRules.info(JobId.warrior).skills;
      expect(c.jobSkillsMaxed(JobId.warrior), isFalse);
      for (final s in skills) {
        while (c.skillLevel(s) < 3 && c.canRaiseSkill(s)) {
          await c.raiseSkill(s);
        }
      }
      // 6스킬 × 3 − 1 = 17점 (Lv.24 = 30점)
      expect(c.jobSkillsMaxed(JobId.warrior), isTrue);
      expect(await c.raiseDrill(JobId.warrior), isTrue);
      expect(c.jobDrill(JobId.warrior), 1);
      expect(c.takeDrillNotice(), isNull); // 아직 Lv.24
    });

    test('#425 스킬북: 금화로 사면 Lv.1 · 주머니로 올림 · 다시 나누기에도 Lv.1로 남음', () async {
      final poor = await job(20);
      expect(await poor.buyBook(JobSkill.bookFirstAid), isFalse);
      final c = await job(20, gold: 5000);
      final gold = c.player.gold;
      expect(await c.buyBook(JobSkill.bookFirstAid), isTrue);
      expect(c.player.gold, gold - 600);
      expect(await c.buyBook(JobSkill.bookFirstAid), isFalse, reason: '한 권 한 번만');
      expect(c.skillLevel(JobSkill.bookFirstAid), 1);
      expect(c.commonSkills, [JobSkill.bookFirstAid]);
      expect(c.loadoutChoices, contains('job:bookFirstAid'));
      expect(await c.raiseSkill(JobSkill.bookFirstAid), isTrue);
      expect(c.skillLevel(JobSkill.bookFirstAid), 2);
      expect(c.skillPointsLeft, 17);
      await c.resetSkills();
      expect(c.skillLevel(JobSkill.bookFirstAid), 1);
      expect(c.skillPointsLeft, 18);
      // 튼튼한 몸 → 최대 HP
      final hp = c.maxHp;
      expect(await c.buyBook(JobSkill.bookSturdy), isTrue);
      expect(c.maxHp, greaterThan(hp));
    });

    test('#425 전투 공용 스킬: 응급 처치 · 두 번 베기 · 정화의 빛 · 급소 노리기', () {
      Battle b() => Battle(
            playerMaxHp: 1000,
            playerAttack: 50,
            floors: [const Foe(monster: MonsterId.giantRat, maxHp: 100000, attack: 1)],
            rng: math.Random(1),
            heroSkills: true,
          );
      final a = b()..playerHp = 500;
      a.commonLevels[JobSkill.bookFirstAid] = 2;
      expect(a.useJobSkill(JobSkill.bookFirstAid), isTrue);
      expect(a.playerHp, 750);
      final d = b();
      expect(d.useJobSkill(JobSkill.bookDoubleSlash), isTrue);
      expect(d.lastDealt, greaterThan(0));
      final p = b()..poisonTurns = 3;
      p.commonLevels[JobSkill.bookPurify] = 2;
      expect(p.useJobSkill(JobSkill.bookPurify), isTrue);
      expect(p.poisonTurns, 0);
      expect(p.immuneTurns, 2);
      final k = b();
      expect(k.useJobSkill(JobSkill.bookAimCrit), isTrue);
      expect(k.lastCrit, isTrue);
    });

    test('#432 주 직업 바꾸기: 레벨 × 500 · 보조 비워짐 · 포인트 돌아옴', () async {
      final c = await job(20, owned: ['warrior', 'mage', 'archer'], subs: ['mage'], gold: 20000);
      await c.raiseSkill(JobRules.info(JobId.warrior).skills[1]);
      await c.raiseSkill(JobRules.info(JobId.mage).skills[1]);
      expect(c.skillPointsLeft, 16);
      final plan = c.planChange(JobId.archer, JobId.mage);
      expect(plan.gold, 10000);
      expect(plan.clearedSub, JobId.mage);
      expect(plan.points, 2);
      final gold = c.player.gold;
      expect(await c.changeJobs(JobId.archer, JobId.mage), JobChange.ok);
      expect(c.mainJob, JobId.archer);
      expect(c.subJob, isNull);
      expect(c.player.gold, gold - 10000);
      expect(c.skillPointsLeft, 18);
      expect(c.skillLevel(JobRules.info(JobId.warrior).skills[1]), 0);
      // 비어 있는 보조 칸에 넣기는 무료
      expect(c.planChange(JobId.archer, JobId.mage).gold, 0);
      expect(await c.changeJobs(JobId.archer, JobId.mage), JobChange.ok);
      expect(c.subJob, JobId.mage);
      // 보조 바꾸기 · 빼기: 레벨 × 250
      expect(c.planChange(JobId.archer, JobId.warrior).gold, 5000);
      expect(c.planChange(JobId.archer, null).gold, 5000);
      expect(await c.removeSubJob(), JobChange.ok);
      expect(c.subJob, isNull);
    });

    test('#432 금화가 모자라면 못 바꿈', () async {
      final c = await job(20, owned: ['warrior', 'archer']);
      expect(await c.changeJobs(JobId.archer, null), JobChange.noGold);
      expect(c.mainJob, JobId.warrior);
    });

    testWidgets('#433 스킬 한 화면: 탭 없음 · 포인트 · 전투 칸 · 칩 · 공용 · 숙련 · 「칸에」', (tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      late AppController c;
      await tester.runAsync(() async {
        c = await job(20, gold: 5000);
        await c.buyBook(JobSkill.bookDoubleSlash);
        await c.setLoadout(0, null);
        await c.setLoadout(1, null);
      });
      await tester.pumpWidget(MaterialApp(home: SkillScreen(controller: c)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('skillTab_1')), findsNothing);
      expect(find.byKey(const Key('skillPointsLeft')), findsOneWidget);
      expect(find.byKey(const Key('skillChip_common')), findsOneWidget);
      expect(find.byKey(const Key('skillSlot_3')), findsOneWidget);
      expect(find.byType(KindTag), findsWidgets);
      // 공용 칸으로 가서 「칸에」 → 칸 1
      await tester.tap(find.byKey(const Key('skillChip_common')));
      await tester.pump(const Duration(milliseconds: 500));
      await showMid(tester, find.byKey(const Key('skillToSlot_bookDoubleSlash')));
      await tester.tap(find.byKey(const Key('skillToSlot_bookDoubleSlash')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('skillSlot_0')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      expect(c.battleSlots[0], 'job:bookDoubleSlash');
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('C 화면 손질', () {
    test('#429 다 끓은 가마솥이 있으면 연금술 공방 점', () async {
      final c = await startVillage(12, more: {
        'alchemy': {
          'brews': {
            '0': {
              'put': ['herb', 'herb', 'slimeJelly'],
              'startedAt': DateTime(2026, 11, 16, 8).toIso8601String(),
              'readyAt': DateTime(2026, 11, 16, 9).toIso8601String(),
            },
          },
        },
      });
      expect(c.alchemyReady, isTrue);
    });
  });
}
