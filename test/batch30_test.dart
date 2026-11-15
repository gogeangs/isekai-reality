import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/models/job_state.dart';
import 'package:isekai_reality/core/models/pet_state.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';

void main() {
  final t0 = DateTime(2026, 11, 15, 10);

  Future<AppController> start(InMemoryRecordStore store,
      {int steps = 0, int night = 0}) async {
    final c = AppController(
      store: store,
      health: FakeHealthSource(
          stepsByDay: {if (steps > 0) '2026-11-15': steps},
          stepsAfter8pmByDay: {if (night > 0) '2026-11-01': night}),
      clock: () => t0,
    )..mailSources = const [];
    await c.init();
    return c;
  }

  final born = DateTime(2026, 11, 1);
  final pets = PetState(
    farewellAt: born,
    firstSpiritName: '불씨',
    firstSpiritKind: 'fire',
    pets: [Pet(uid: 'pet1', species: PetSpecies.owl, name: '부엉', bornAt: born)],
    companion: 'pet1',
    firstPet: 'pet1',
    nextId: 2,
  );

  InMemoryRecordStore account(int level,
          {Map<String, double> big = const {},
          JobState? jobs,
          int steps = 0,
          int night = 0}) =>
      InMemoryRecordStore(
        profile: const PlayerProfile(name: '하루', lastSeenLevel: 99),
        history: [
          DailyRecord(date: DateTime(2026, 11, 1), stepsAfter8pm: night),
          DailyRecord(
            date: DateTime(2026, 11, 14),
            gains: {'exp': LevelRules.totalExpToReach(level)},
          ),
          if (steps > 0)
            DailyRecord(date: DateTime(2026, 11, 15), steps: steps),
        ],
        json: {
          'tutorial': {'step': TutorialStep.done.index},
          'pets': pets.toJson(),
          'mastery': {'big': big},
          if (jobs != null) 'jobs': jobs.toJson(),
        },
      );

  group('직업 규칙', () {
    test('24가지: 기본 8 · 복합 12 · 숨은 4, 스킬 칸 4/2, 첫 스킬 하나씩', () {
      expect(JobRules.jobs, hasLength(24));
      final kinds = [for (final j in JobRules.jobs) j.kind];
      expect(kinds.where((k) => k == JobKind.basic), hasLength(8));
      expect(kinds.where((k) => k == JobKind.complex), hasLength(12));
      expect(kinds.where((k) => k == JobKind.hidden), hasLength(4));
      var slots = 0;
      final skills = <JobSkill>{};
      for (final j in JobRules.jobs) {
        expect(JobRules.info(j.id), same(j));
        expect(j.skills, hasLength(j.kind == JobKind.basic ? 4 : 2));
        // 묶음 31: 직업을 얻으면 ① 공격 스킬만 열린다
        skills.add(JobRules.firstOf(j.id));
        expect(JobRules.skill(JobRules.firstOf(j.id)).attack, isTrue);
        slots += j.skills.length;
        // 화면 문구에 숫자·% 없음
        expect(RegExp(r'[0-9%]').hasMatch(j.trait), isFalse, reason: j.name);
      }
      expect(slots, 64);
      expect(skills, hasLength(24));
      for (final s in JobRules.skills) {
        expect(JobRules.skill(s.id), same(s));
        // 묶음 31 확인 답: 「30분 동안」 같은 지속 시간은 보여도 됨 (숨은 배율·확률만 숨김)
        expect(RegExp(r'[0-9%]').hasMatch(s.text.replaceAll(RegExp(r'\d+분 동안'), '')), isFalse, reason: s.name);
      }
    });

    test('MP·슬롯·비용', () {
      expect(JobRules.maxMp(10), 50);
      expect(JobRules.maxMp(25), 80);
      expect(JobRules.maxMp(40), 110);
      expect(JobRules.subSlots(14), 0);
      expect(JobRules.subSlots(15), 1);
      expect(JobRules.subSlots(20), 2);
      expect(JobRules.skillCost(JobSkill.rush), 20);
      expect(JobRules.skillCost(JobSkill.rush, sub: true), 30);
      expect(JobRules.skillCost(JobSkill.focusForge, sub: true), 45);
      expect(JobRules.skillCost(JobSkill.runeCarve, sub: true), 60);
      expect(JobRules.skillCost(JobSkill.focusForge, half: true), 15);
    });

    test('열림: 기본은 능숙한, 복합은 둘 다 숙련된', () {
      MasteryStage Function(Mastery) st(Map<Mastery, MasteryStage> m) =>
          (x) => m[x] ?? MasteryStage.clumsy;
      expect(JobRules.unlocked(st({})), isEmpty);
      expect(JobRules.unlocked(st({Mastery.smith: MasteryStage.familiar})),
          isEmpty);
      expect(JobRules.unlocked(st({Mastery.smith: MasteryStage.skilled})),
          {JobId.blacksmith});
      expect(
          JobRules.unlocked(st({
            Mastery.smith: MasteryStage.expert,
            Mastery.combat: MasteryStage.skilled,
          })),
          {JobId.blacksmith, JobId.warrior});
      expect(
          JobRules.unlocked(st({
            Mastery.smith: MasteryStage.expert,
            Mastery.combat: MasteryStage.expert,
          })),
          containsAll([JobId.blacksmith, JobId.warrior, JobId.weaponsmith]));
    });

    test('마나 물약 레시피는 다른 물약과 겹치지 않음', () {
      final seen = <String>{};
      for (final p in AlchemyRules.all) {
        final k = (p.counts.entries.map((e) => '${e.key.name}${e.value}').toList()
              ..sort())
            .join('+');
        expect(seen.add(k), isTrue, reason: p.name);
      }
      expect(AlchemyRules.info(PotionId.jobManaSmall).shopItem,
          ShopItem.jobManaSmall);
      expect(TownRules.info(ShopItem.jobManaSmall).name, '작은 마나 물약');
      expect(TownRules.info(ShopItem.jobMana).name, '마나 물약');
      expect(TownRules.info(ShopItem.manaSmall).name, '작은 기력 물약');
    });
  });

  group('Lv.15 직업 각성', () {
    test('Lv.14: 직업·MP·길드·마나 물약 없음', () async {
      final c = await start(account(14, big: {'smith': 50}));
      expect(c.jobAwakenPending, isFalse);
      expect(c.jobsOpen, isFalse);
      expect(c.jobSkills, isEmpty);
      expect(c.shopItems.any((i) => i.item == ShopItem.jobManaSmall), isFalse);
      expect(c.knownRecipes.contains(PotionId.jobManaSmall), isFalse);
      expect(c.mainJobLabel, isNull);
    });

    test('Lv.15: 추천 맨 위 → 주 직업 + 보조 1칸 → MP 가득, 한 번만', () async {
      final store = account(15, big: {
        'smith': 50,
        'combat': 130,
        'trade': 15,
      });
      final c = await start(store);
      expect(c.jobAwakenPending, isTrue);
      expect(c.recommendedJob, JobId.warrior);
      expect(c.jobChoices.first, JobId.warrior);
      expect(c.jobChoices, containsAll([JobId.warrior, JobId.blacksmith]));
      expect(c.jobChoices, isNot(contains(JobId.merchant)));
      expect(c.subJobSlots, 1);
      expect(await c.awakenJob(JobId.warrior,
          subs: [JobId.blacksmith, JobId.warrior]), isTrue);
      expect(c.jobsOpen, isTrue);
      expect(c.mainJob, JobId.warrior);
      expect(c.subJobs, [JobId.blacksmith]);
      expect(c.jobApprentice, isFalse);
      expect(c.jobMp, c.jobMpMax);
      expect(c.jobTrait(JobId.warrior), 1);
      expect(c.jobTrait(JobId.blacksmith), 0.5);
      expect(c.jobGrowth(Mastery.combat), 1.5);
      expect(c.jobGrowth(Mastery.smith), 1.2);
      expect(c.jobGrowth(Mastery.trade), 1);
      expect(c.mainJobLabel, '전사');
      // 다시 열어도 한 번만
      final again = await start(store);
      expect(again.jobAwakenPending, isFalse);
      expect(again.mainJob, JobId.warrior);
      // 같은 직업 두 칸 안 됨
      expect(await again.setSubJob(0, JobId.warrior), isFalse);
      expect(again.shopItems.any((i) => i.item == ShopItem.jobManaSmall), isTrue);
    });

    test('열린 직업이 없으면 견습, 조건을 채우면 견습이 떨어짐', () async {
      final c = await start(account(15, big: {'alchemy': 12}));
      expect(c.jobStartsApprentice, isTrue);
      expect(c.jobChoices, [JobId.alchemist]);
      expect(await c.awakenJob(JobId.alchemist), isTrue);
      expect(c.jobApprentice, isTrue);
      expect(c.mainJobLabel, '견습 연금술사');
      expect(c.jobTrait(JobId.alchemist), 0.5);
      await c.gainMastery(Mastery.alchemy, 20); // ×1.5
      expect(c.masteryStage(Mastery.alchemy), MasteryStage.skilled);
      expect(c.jobApprentice, isFalse);
      expect(c.takeJobNotice(), contains('견습을 마쳤어요'));
    });

    test('숙련도가 오르면 새 직업 + 띠 + 첫 펫 한마디', () async {
      final c = await start(account(15, big: {'combat': 50}));
      await c.awakenJob(JobId.warrior);
      expect(c.ownedJobs, [JobId.warrior]);
      await c.gainMastery(Mastery.trade, 40);
      expect(c.ownedJobs.first, JobId.merchant);
      expect(c.takeJobNotice(), '새 직업을 얻었어요 · 상인');
      expect(c.masteryState.pending.any((l) => l.contains('상인')), isTrue);
    });

    test('Lv.20 보조 2칸, 길드에서 주 직업 바꾸면 자리를 맞바꿈', () async {
      final c = await start(account(20, big: {
        'combat': 50,
        'smith': 50,
        'trade': 50,
      }));
      expect(c.subJobSlots, 2);
      await c.awakenJob(JobId.warrior,
          subs: [JobId.blacksmith, JobId.merchant]);
      expect(c.subJobs, [JobId.blacksmith, JobId.merchant]);
      await c.setMainJob(JobId.merchant);
      expect(c.mainJob, JobId.merchant);
      expect(c.subJobs, [JobId.blacksmith, JobId.warrior]);
    });

    test('숨은 직업: 저녁 걸음 5만 보 → 밤의 산책자', () async {
      final c = await start(account(15, night: 50000), night: 50000);
      expect(c.unlockedJobs, contains(JobId.nightWalker));
    });

    test('스킬: MP 깎임, 보조 1.5배, 모자라면 notEnoughMp, 써 둔 상태는 다시 열어도 유지',
        () async {
      final store = account(15, big: {'combat': 50, 'harvest': 50});
      final c = await start(store);
      await c.awakenJob(JobId.herbalist, subs: [JobId.warrior]);
      final max = c.jobMpMax;
      // 묶음 31: 처음엔 ①만. 포인트로 풍요의 손길을 배운다
      expect(c.skillsAt(const [SkillPlace.harvest]), isEmpty);
      expect(await c.raiseSkill(JobSkill.bountyTouch), isTrue);
      expect(c.skillsAt(const [SkillPlace.harvest]).single.$1,
          JobSkill.bountyTouch);
      expect(await c.useJobSkill(JobSkill.bountyTouch), SkillUse.ok);
      expect(c.jobMp, max - 20);
      expect(c.skillPending(JobSkill.bountyTouch), isTrue);
      expect(await c.useJobSkill(JobSkill.bountyTouch), SkillUse.already);
      expect(c.skillCost(JobSkill.rush, sub: true), 30);
      expect(await c.payBattleSkill(JobSkill.rush), isTrue);
      expect(c.jobMp, max - 50);
      final again = await start(store);
      expect(again.skillPending(JobSkill.bountyTouch), isTrue);
      expect(again.jobMp, max - 50);
      while (again.jobMp >= 30) {
        await again.payBattleSkill(JobSkill.rush);
      }
      expect(await again.useJobSkill(JobSkill.pathFind), SkillUse.cannot);
    });

    test('걸음 1,000보마다 MP 10%, 레벨업 가득', () async {
      final store = account(15, big: {'combat': 50});
      final c = await start(store);
      await c.awakenJob(JobId.warrior);
      while (c.jobMp >= 20) {
        await c.payBattleSkill(JobSkill.rush);
      }
      final low = c.jobMp;
      final walked = await start(account(15,
          big: {'combat': 50},
          steps: 3000,
          jobs: c.jobState.copyWith(stepsDay: '2026-11-15', stepsCounted: 0)),
          steps: 3000);
      await walked.refreshVitals();
      expect(walked.jobMp, low + (walked.jobMpMax * 0.3).round());
      await walked.levelUpHeal();
      expect(walked.jobMp, walked.jobMpMax);
    });

    test('전투 스킬: 돌진·급소 사격·치유의 빛·철벽', () {
      final b = Battle.forPlayer(
        level: 15,
        stats: Stats.all(10),
        floors: const [
          Foe(monster: MonsterId.slime, maxHp: 100000, attack: 1),
        ],
        startHp: 100,
      );
      expect(b.useJobSkill(JobSkill.rush), isTrue);
      expect(b.lastDealt, greaterThan(0));
      expect(b.useJobSkill(JobSkill.vitalStrike), isTrue);
      expect(b.lastCrit, isTrue);
      expect(b.useJobSkill(JobSkill.healingLight), isTrue);
      expect(b.playerHp, greaterThan(100));
      expect(b.useJobSkill(JobSkill.ironWall), isTrue);
      expect(b.useJobSkill(JobSkill.ironWall), isFalse);
      expect(b.useJobSkill(JobSkill.focusForge), isFalse);
    });
  });
}
