import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/geo/geo.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/models/job_state.dart';
import 'package:isekai_reality/core/models/pet_state.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';

void main() {
  final t0 = DateTime(2026, 11, 15, 10);

  Future<AppController> start(InMemoryRecordStore store) async {
    final c = AppController(
      store: store,
      health: FakeHealthSource(stepsByDay: const {}),
      clock: () => t0,
    )..mailSources = const [];
    await c.init();
    return c;
  }

  final born = DateTime(2026, 11, 1);
  PetState pets({int bond = 0, DateTime? petBorn}) => PetState(
        farewellAt: born,
        firstSpiritName: '불씨',
        firstSpiritKind: 'fire',
        pets: [
          Pet(
              uid: 'pet1',
              species: PetSpecies.owl,
              name: '부엉',
              bond: bond,
              bornAt: petBorn ?? born),
        ],
        companion: 'pet1',
        firstPet: 'pet1',
        nextId: 2,
      );

  InMemoryRecordStore account(int level,
          {Map<String, double> big = const {},
          Map<String, dynamic>? jobs,
          PetState? pet,
          List<DailyRecord> extra = const []}) =>
      InMemoryRecordStore(
        profile: const PlayerProfile(name: '하루', lastSeenLevel: 99),
        history: [
          ...extra,
          DailyRecord(
            date: DateTime(2026, 11, 14),
            gains: {'exp': LevelRules.totalExpToReach(level)},
          ),
        ],
        json: {
          'tutorial': {'step': TutorialStep.done.index},
          'pets': (pet ?? pets()).toJson(),
          'mastery': {'big': big},
          if (jobs != null) 'jobs': jobs,
        },
      );

  group('#195 #196 고유 스킬 규칙', () {
    test('포인트: Lv.15부터 레벨마다 2점', () {
      expect(JobRules.pointsFor(14), 0);
      expect(JobRules.pointsFor(15), 2);
      expect(JobRules.pointsFor(16), 4);
      expect(JobRules.pointsFor(20), 12);
    });

    test('트리: 기본 ① → ②·③, ②나 ③ Lv.2 → ④ / 복합 ① → ②', () {
      final lv = <JobSkill, int>{};
      int of(JobSkill s) => lv[s] ?? 0;
      expect(JobRules.canLearn(JobSkill.focusForge, of), isFalse);
      lv[JobSkill.hotHammer] = 1;
      expect(JobRules.canLearn(JobSkill.focusForge, of), isTrue);
      expect(JobRules.canLearn(JobSkill.masterTouch, of), isTrue);
      expect(JobRules.canLearn(JobSkill.quickRepair, of), isFalse);
      lv[JobSkill.masterTouch] = 2;
      expect(JobRules.canLearn(JobSkill.quickRepair, of), isTrue);
      lv[JobSkill.masterSlash] = 1;
      expect(JobRules.canLearn(JobSkill.masterBlade, of), isTrue);
    });

    test('설명에 숫자 없음, 단계마다 세기·MP', () {
      for (final s in JobRules.skills) {
        // 묶음 31 확인 답: 「30분 동안」 같은 지속 시간은 보여도 됨 (숨은 배율·확률만 숨김)
        expect(RegExp(r'[0-9%×]').hasMatch(s.text.replaceAll(RegExp(r'\d+분 동안'), '')), isFalse, reason: s.name);
      }
      expect(JobRules.levelPower(1), 1);
      expect(JobRules.levelPower(3), greaterThan(JobRules.levelPower(2)));
      expect(JobRules.skillCost(JobSkill.focusForge, level: 3),
          lessThan(JobRules.skillCost(JobSkill.focusForge)));
      // 공격 스킬은 단계가 올라도 MP 그대로 (더 세짐)
      expect(JobRules.skillCost(JobSkill.rush, level: 3),
          JobRules.skillCost(JobSkill.rush));
      expect(JobRules.info(JobId.herbalist).name, '채집가');
    });
  });

  group('#197 숙련 스킬', () {
    test('8 × 4 = 32 (패시브 24 · 액티브 8), 숫자 없음', () {
      expect(JobRules.masterySkills, hasLength(32));
      expect(JobRules.masterySkills.where((x) => x.active), hasLength(8));
      for (final x in JobRules.masterySkills) {
        expect(x.active, x.stage == MasteryStage.expert, reason: x.name);
        expect(RegExp(r'[0-9%×]').hasMatch(x.text), isFalse, reason: x.name);
      }
      // 새 패시브가 앞 단계를 바꾼다
      expect(
          JobRules.masterySkillsAt(Mastery.smith, MasteryStage.master)
              .map((x) => x.name),
          ['장인의 손', '망치 내려치기']);
      expect(JobRules.masterySkillsAt(Mastery.smith, MasteryStage.clumsy),
          isEmpty);
    });

    test('액티브는 MP 없이 몇 턴마다', () {
      final b = Battle.forPlayer(
        level: 10,
        stats: Stats.all(10),
        floors: const [
          Foe(monster: MonsterId.slime, maxHp: 100000, attack: 1),
        ],
        heroSkills: true,
      )..masteryActives.add(Mastery.combat);
      expect(b.masteryReady(Mastery.combat), isFalse);
      for (var i = 0; i < JobRules.masteryActiveTicks; i++) {
        b.tick();
      }
      expect(b.masteryReady(Mastery.combat), isTrue);
      final hp = b.foeHp;
      expect(b.useMasterySkill(Mastery.combat), isTrue);
      expect(b.foeHp, lessThan(hp));
      expect(b.masteryReady(Mastery.combat), isFalse);
    });
  });

  group('#198 스킬 페이지', () {
    test('숙련된이 없고 Lv.15 전: 닫혀 있음 → 첫 숙련된에 열림 + 띠 + 첫 칸', () async {
      final c = await start(account(10, big: {'combat': 100}));
      expect(c.skillPageOpen, isFalse);
      expect(c.skillIntroPending, isFalse);
      await c.gainMastery(Mastery.combat, 30);
      expect(c.masteryStage(Mastery.combat), MasteryStage.expert);
      expect(c.skillPageOpen, isTrue);
      expect(c.skillIntroPending, isTrue);
      expect(c.battleLoadout, ['mastery:combat']);
      expect(c.masterySkillsOwned.map((x) => x.name),
          containsAll(['매서운 손', '연속 베기']));
      expect(c.takeJobNotice(), '숙련 스킬을 익혔어요 · 몸에 밴 자세 외 2개');
      await c.markSkillIntro();
      expect(c.skillIntroPending, isFalse);
    });

    test('예전 기록: 다음에 열 때 한꺼번에 (띠 하나, 카드 한 번)', () async {
      final store = account(12, big: {'smith': 130, 'harvest': 50});
      final c = await start(store);
      expect(c.skillPageOpen, isTrue);
      expect(c.skillIntroPending, isTrue);
      final n = c.takeJobNotice();
      expect(n, startsWith('숙련 스킬을 익혔어요'));
      expect(c.takeJobNotice(), isNull);
      await c.markSkillIntro();
      final again = await start(store);
      expect(again.skillIntroPending, isFalse);
      expect(again.takeJobNotice(), isNull);
    });

    test('각성: ①만 Lv.1, 포인트로 배우고 강화, 다시 나누기는 무료', () async {
      final c = await start(account(16, big: {'smith': 50, 'combat': 50}));
      await c.awakenJob(JobId.blacksmith, subs: [JobId.warrior]);
      expect(c.skillPageOpen, isTrue);
      expect(c.skillLevel(JobSkill.hotHammer), 1);
      expect(c.skillLevel(JobSkill.rush), 1);
      expect(c.skillLevel(JobSkill.focusForge), 0);
      expect(c.skillPointsLeft, 4);
      expect(c.canRaiseSkill(JobSkill.quickRepair), isFalse);
      expect(await c.raiseSkill(JobSkill.focusForge), isTrue);
      expect(await c.raiseSkill(JobSkill.focusForge), isTrue);
      expect(c.skillLevel(JobSkill.focusForge), 2);
      expect(await c.raiseSkill(JobSkill.quickRepair), isTrue);
      expect(await c.raiseSkill(JobSkill.hotHammer), isTrue);
      expect(c.skillLevel(JobSkill.hotHammer), 2);
      expect(c.skillPointsLeft, 0);
      expect(await c.raiseSkill(JobSkill.masterTouch), isFalse);
      // 전투 칸: 주 직업 ① 먼저
      expect(c.battleLoadout.first, 'job:hotHammer');
      expect(c.battleJobSlots.first.$3, greaterThan(1));
      await c.resetSkills();
      expect(c.skillPointsLeft, 4);
      expect(c.skillLevel(JobSkill.hotHammer), 1);
      expect(c.skillLevel(JobSkill.focusForge), 0);
      // 칸 바꾸기
      await c.setLoadout(0, 'job:rush');
      expect(c.battleLoadout.first, 'job:rush');
      await c.setLoadout(1, null);
      expect(c.battleLoadout, ['job:rush']);
    });

    test('예전 각성 계정: 쓰던 스킬은 포인트 없이 Lv.1, ① 더, 빠진 스킬은 MP 돌려줌',
        () async {
      final store = account(17,
          big: {'smith': 50},
          jobs: const JobState(
            awakened: true,
            owned: ['blacksmith', 'warrior'],
            main: 'blacksmith',
            subs: ['warrior'],
            mp: 10,
            pending: ['focusForge', 'oldThing'],
          ).toJson());
      final c = await start(store);
      expect(c.skillLevel(JobSkill.focusForge), 1);
      expect(c.skillLevel(JobSkill.hotHammer), 1);
      expect(c.skillLevel(JobSkill.warCry), 1); // 힘의 일격 → 전투 함성
      expect(c.skillPointsLeft, JobRules.pointsFor(17));
      expect(c.skillPending(JobSkill.focusForge), isTrue);
      expect(c.jobState.pending, isNot(contains('oldThing')));
      expect(c.jobMp, 30);
      expect(c.jobState.v31, isTrue);
      // 다시 열어도 한 번만
      final again = await start(store);
      expect(again.jobMp, 30);
      expect(again.skillPointsLeft, JobRules.pointsFor(17));
      await again.resetSkills();
      expect(again.skillLevel(JobSkill.focusForge), 1);
    });
  });

  group('#193 #194 직업 다듬기', () {
    test('숨은 직업 조건: 밤 걸음 · 정령+첫 펫 날 수와 친밀도', () async {
      final night = await start(account(15, extra: [
        DailyRecord(date: DateTime(2026, 11, 1), stepsNight: 50000),
      ]));
      expect(night.unlockedJobs, contains(JobId.nightWalker));
      final weak = await start(account(15,
          pet: pets(bond: 99, petBorn: DateTime(2026, 9, 1)),
          extra: [DailyRecord(date: DateTime(2026, 8, 1))]));
      expect(weak.unlockedJobs, isNot(contains(JobId.gateHeir)));
      final heir = await start(account(15,
          pet: pets(bond: 100, petBorn: DateTime(2026, 9, 1)),
          extra: [DailyRecord(date: DateTime(2026, 8, 1))]));
      expect(heir.unlockedJobs, contains(JobId.gateHeir));
    });

    test('상인: 오늘의 의뢰 하나 더 (잡화상 거래)', () {
      final r = DailyRecord(
          date: DateTime(2026, 11, 15),
          counters: const {'quest4': 1, 'shopTrade': 1});
      final q = QuestRules.forDay(r);
      expect(q, hasLength(4));
      expect(q.last.title, '잡화상 거래 1번');
      expect(q.last.completed, isTrue);
      expect(QuestRules.perDay(r), 4);
      expect(QuestRules.forDay(DailyRecord(date: DateTime(2026, 11, 15))),
          hasLength(3));
    });

    test('강화 성공률: 집중 단조를 써 두면 화면 %도 오름', () async {
      final c = await start(account(16, big: {'smith': 50}));
      await c.awakenJob(JobId.blacksmith);
      await c.raiseSkill(JobSkill.focusForge);
      final before = c.enhanceChanceShown(10);
      expect(await c.useJobSkill(JobSkill.focusForge), SkillUse.ok);
      expect(c.enhanceChanceShown(10), greaterThan(before));
    });
  });

  group('묶음 31 확인 답', () {
    test('먼 눈: 30분 동안 희귀 수식어 몬스터가 더 자주 + 지도에 눈에 띄게', () async {
      final c = await start(account(16, big: {'walk': 50}));
      await c.awakenJob(JobId.explorer);
      expect(await c.raiseSkill(JobSkill.farSight), isTrue);
      final before = c.modLuckBonus;
      expect(await c.useJobSkill(JobSkill.farSight), SkillUse.ok);
      expect(c.modLuckBonus, greaterThan(before));
      const rare = FieldSpawn(
          id: 'x',
          monster: MonsterId.slime,
          point: GeoPoint(37.32, 126.83),
          modifiers: [ModifierId.golden]);
      expect(c.spotsSpecial(rare), rare.grade.index >= ModGrade.rare.index);
      expect(JobRules.skill(JobSkill.farSight).text, '30분 동안 특별한 몬스터를 찾아내요');
    });
  });

  group('#192 숙련도 빠르기·길드 힌트', () {
    test('앞으로 쌓이는 양', () {
      expect(MasteryRules.appraiseOnce, 3);
      expect(MasteryRules.brew, 2);
      expect(MasteryRules.craft, 2);
      expect(MasteryRules.enhance, 2);
      expect(MasteryRules.repair, 2);
      expect(MasteryRules.expeditionWin, 2);
      expect(MasteryRules.expeditionLoss, 1);
    });

    test('곧 열릴 것 같은 직업: 숨은 직업 없이 2~3개, 숫자 없는 문구', () {
      final near = JobRules.nearJobs(
          (m) => m == Mastery.smith ? 35 : (m == Mastery.combat ? 30 : 0),
          const {JobId.warrior});
      expect(near.length, inInclusiveRange(2, 3));
      expect(near.first, JobId.blacksmith);
      for (final j in near) {
        expect(JobRules.info(j).kind, isNot(JobKind.hidden));
        expect(RegExp(r'[0-9]').hasMatch(JobRules.hintLine(j)), isFalse);
      }
      expect(JobRules.hintLine(JobId.weaponsmith), '대장일과 전투를 더 해 보세요');
    });
  });
}
