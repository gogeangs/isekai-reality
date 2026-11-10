import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/rules/rules.dart';

DailyRecord day(
  int index, {
  int steps = 0,
  int stepsAfter8pm = 0,
  int goal = 5000,
  List<DungeonRun> runs = const [],
  int monsters = 0,
  int newPlaces = 0,
  int revisits = 0,
  int quests = 0,
  int rests = 0,
  List<String> monsterIds = const [],
}) =>
    DailyRecord(
      date: DateTime(2026, 11, 1).add(Duration(days: index)),
      steps: steps,
      stepsAfter8pm: stepsAfter8pm,
      stepGoal: goal,
      dungeonRuns: runs,
      fieldMonstersPurified: monsters,
      newPlacesVisited: newPlaces,
      placesRevisited: revisits,
      questsCompleted: quests,
      restsCompleted: rests,
      purifiedMonsterIds: monsterIds,
    );

void main() {
  group('레벨', () {
    test('Lv.12 → 13 에는 437이 필요하다 (11-10 주간 의뢰와 함께 5% 더 올림)', () {
      expect(LevelRules.expRequiredFor(12), 437);
      expect(LevelRules.expRequiredFor(13), 466);
    });

    test('Lv.10 까지 누적 2,106, Lv.13 까지 누적 3,330', () {
      expect(LevelRules.totalExpToReach(10), 2106);
      expect(LevelRules.totalExpToReach(13), 3330);
    });

    test('누적 경험치로 레벨과 진행도를 계산한다', () {
      final p = LevelRules.fromTotalExp(LevelRules.totalExpToReach(12) + 260);
      expect(p.level, 12);
      expect(p.expIntoLevel, 260);
      expect(p.expToNext, 437);
    });
  });

  group('경험치', () {
    test('미궁 입구에서 클리어하면 75, 실패하면 15', () {
      expect(ExpRules.dungeonRunExp(const DungeonRun(cleared: true, atGate: true)), 75);
      expect(ExpRules.dungeonRunExp(const DungeonRun(cleared: false, atGate: true)), 15);
      expect(ExpRules.dungeonRunExp(const DungeonRun(cleared: true)), 50);
    });

    test('걸음만으로는 경험치가 없다', () {
      expect(ExpRules.forDay(day(0, steps: 9000)).total, 0);
    });

    test('하루 상한이 지켜진다', () {
      final b = ExpRules.forDay(day(
        0,
        runs: List.filled(6, const DungeonRun(cleared: true)),
        monsters: 9,
        newPlaces: 5,
        quests: 5,
      ));
      expect(b.dungeon, 200); // 4회
      expect(b.fieldMonster, 75); // 5마리
      expect(b.exploration, 90); // 3곳
      expect(b.quest, 60); // 3개
    });

    test('여관 휴식을 마친 날은 하루 한 번 +20 (여러 번 쉬어도 같다)', () {
      expect(ExpRules.forDay(day(0, rests: 1)).rest, 20);
      expect(ExpRules.forDay(day(0, rests: 3)).rest, 20);
      expect(ExpRules.forDay(day(0)).rest, 0);
    });

    test('연속 휴식 보너스: 3일 30, 7일 70, 14일 100, 그 뒤 7일마다 100', () {
      expect(TownRules.restStreakReward(3), (30, 0));
      expect(TownRules.restStreakReward(7), (70, 5));
      expect(TownRules.restStreakReward(14), (100, 10));
      expect(TownRules.restStreakReward(21), (100, 10));
      expect(TownRules.restStreakReward(28), (100, 10));
      expect(TownRules.restStreakReward(10), (0, 0));
      expect(ExpRules.forDay(day(0, rests: 1), restStreak: 7).restStreak, 70);
    });
  });

  group('던전 게이지', () {
    test('6,400보 → 열쇠 2개, 다음 열쇠까지 1,400 / 2,500', () {
      final g = DungeonGaugeRules.today(steps: 6400);
      expect(g.keysEarnedToday, 2);
      expect(g.keysAvailable, 2);
      expect(g.stepsIntoNextKey, 1400);
    });

    test('하루 최대 4개 (10,000보)', () {
      final g = DungeonGaugeRules.today(steps: 13000);
      expect(g.keysEarnedToday, 4);
      expect(g.dailyKeyLimitReached, isTrue);
    });

    test('이월은 최대 3개', () {
      final g = DungeonGaugeRules.today(steps: 10000, carriedKeys: 1);
      expect(g.keysAvailable, 5);
      expect(DungeonGaugeRules.carryOverToTomorrow(g), 3);
    });

    test('자기 걸음 목표를 채운 날은 보너스 열쇠 1개 (걸음 한도와 별도)', () {
      final under = DungeonGaugeRules.today(steps: 4900, stepGoal: 5000);
      expect(under.keysEarnedToday, 1);
      expect(under.goalBonusKey, isFalse);
      expect(under.stepsToGoal, 100);

      final reached = DungeonGaugeRules.today(steps: 5000, stepGoal: 5000);
      expect(reached.keysEarnedToday, 3);
      expect(reached.goalBonusKey, isTrue);
      expect(reached.stepsToGoal, isNull);

      final max = DungeonGaugeRules.today(steps: 12000, stepGoal: 8000);
      expect(max.keysEarnedToday, 5);
      expect(max.dailyKeyLimitReached, isTrue);
    });

    test('보너스 열쇠도 다음 날로 넘어간다 (이월 최대 3개)', () {
      final carried = DungeonGaugeRules.carriedIntoLastDay([
        (date: DateTime(2026, 11, 1), steps: 3000, goal: 3000, extra: 0, runs: 0),
        (date: DateTime(2026, 11, 2), steps: 0, goal: 3000, extra: 0, runs: 0),
      ]);
      expect(carried, 2);
    });

    test('쓴 열쇠는 빠진다', () {
      final g = DungeonGaugeRules.today(steps: 6400, keysUsedToday: 1);
      expect(g.keysAvailable, 1);
    });
  });

  group('스탯', () {
    test('모든 스탯은 10에서 시작한다', () {
      final s = StatRules.fromHistory([]);
      expect([s.vitality, s.agility, s.wisdom, s.spirit], [10, 10, 10, 10]);
    });

    test('기록에 따라 오른다', () {
      final history = [
        // 목표 달성, 새 몬스터 2종, 새 장소 1곳, 휴식
        day(0,
            steps: 16000,
            monsterIds: ['ashSlime', 'labyrinthBat'],
            newPlaces: 1,
            rests: 1),
        // 목표 달성, 이미 본 몬스터
        day(1, steps: 15000, monsterIds: ['ashSlime']),
        day(2, steps: 2000, rests: 2), // 휴식
      ];
      final s = StatRules.fromHistory(history);
      expect(s.vitality, 11); // 33,000보
      expect(s.agility, 12);
      expect(s.wisdom, 13); // 새 몬스터 2 + 새 장소 1
      expect(s.spirit, 12); // 휴식한 날 2
    });

    test('7일 연속 접속할 때마다 정신 +1', () {
      expect(StatRules.fromHistory(List.generate(6, (i) => day(i))).spirit, 10);
      expect(StatRules.fromHistory(List.generate(7, (i) => day(i))).spirit, 11);
      expect(StatRules.fromHistory(List.generate(14, (i) => day(i))).spirit, 12);
    });

    test('전투 체력: Lv.12, 체력 12 → 1,500', () {
      const stats = Stats(vitality: 12, agility: 19, wisdom: 14, spirit: 18);
      expect(StatRules.battleMaxHp(level: 12, stats: stats), 1500);
    });
  });

  group('칭호', () {
    test('7일 연속 목표 달성 → 끈기의 여행자', () {
      final history = List.generate(7, (i) => day(i, steps: 5200));
      expect(TitleRules.earned(history, 1), contains(TitleId.persistentTraveler));
    });

    test('중간에 끊기면 얻지 못한다', () {
      final history = List.generate(
          7, (i) => day(i, steps: i == 3 ? 1000 : 5200));
      expect(TitleRules.earned(history, 1),
          isNot(contains(TitleId.persistentTraveler)));
    });

    test('여관에서 7일 연속 쉬면 아침 정령의 친구', () {
      final six = List.generate(6, (i) => day(i, rests: 1));
      expect(TitleRules.earned(six, 1),
          isNot(contains(TitleId.morningSpiritFriend)));
      expect(TitleRules.earned([...six, day(6, rests: 1)], 1),
          contains(TitleId.morningSpiritFriend));
    });

    test('도감의 몬스터를 모두 사냥하면 도감의 현자 (예전 6종도 인정)', () {
      final now = [
        for (final m in Monsters.all)
          if (!m.slimeKind) m.id.name,
      ];
      expect(now, hasLength(7));
      expect(TitleRules.earned([day(0, monsterIds: now.sublist(1))], 1),
          isNot(contains(TitleId.bookwormSage)));
      expect(TitleRules.earned([day(0, monsterIds: now)], 1),
          contains(TitleId.bookwormSage));
      const old = ['ashSlime', 'labyrinthBat', 'roughWaterSpirit',
          'shadowButterfly', 'lostStoneSpirit', 'labyrinthWarden'];
      expect(TitleRules.earned([day(0, monsterIds: old)], 1),
          contains(TitleId.bookwormSage));
      expect(TitleRules.info(TitleId.bookwormSage).name, '도감의 현자');
    });

    test('레벨 칭호', () {
      expect(TitleRules.earned([], 10),
          containsAll([TitleId.awakened, TitleId.lanternKeeper]));
    });

    DailyRecord visit(int i, List<String> ids) =>
        DailyRecord(date: DateTime(2026, 11, 1 + i), visitedPlaceIds: ids);

    test('서로 다른 미궁 입구 다섯 곳을 가면 미궁의 문지기', () {
      final four = [
        visit(0, ['gate_jungang', 'gate_gojan']),
        visit(1, ['gate_jungang', 'gate_choji', 'gate_ansan']),
      ];
      expect(TitleRules.earned(four, 1), isNot(contains(TitleId.gateKeeper)));
      expect(TitleRules.earned([...four, visit(2, ['gate_banwol'])], 1),
          contains(TitleId.gateKeeper));
    });

    test('호수를 서로 다른 5일 가면 호수의 친구', () {
      final four = [for (var i = 0; i < 4; i++) visit(i, ['lake_ansan'])];
      expect(TitleRules.earned(four, 1), isNot(contains(TitleId.lakeFriend)));
      expect(TitleRules.earned([...four, visit(9, ['lake_reed'])], 1),
          contains(TitleId.lakeFriend));
    });

    test('필드 몬스터를 30마리 정화하면 동네의 빛 (11-10, 안개 대신)', () {
      DailyRecord d(int day, int n) => DailyRecord(
          date: DateTime(2026, 11, day), stepGoal: 3000, fieldMonstersPurified: n);
      expect(TitleRules.earned([d(1, 5), d(2, 24)], 1),
          isNot(contains(TitleId.townLight)));
      expect(TitleRules.earned([d(1, 5), d(2, 25)], 1),
          contains(TitleId.townLight));
    });

    test('장소 칭호는 도감에서 숨긴다', () {
      final ids = TitleRules.all.map((t) => t.id);
      expect(ids, isNot(contains(TitleId.gateKeeper)));
      expect(ids, isNot(contains(TitleId.lakeFriend)));
      expect(TitleRules.info(TitleId.gateKeeper).name, '미궁의 문지기');
    });

    test('대표 칭호: 고른 것이 우선, 얻지 못했으면 자동', () {
      final earned = {TitleId.firstSteps, TitleId.nightWalker};
      expect(TitleRules.equipped(earned, chosen: TitleId.firstSteps),
          TitleId.firstSteps);
      expect(TitleRules.equipped(earned, chosen: TitleId.lakeFriend),
          TitleId.nightWalker);
      expect(TitleRules.equipped({}), isNull);
    });
  });

  group('걸음 목표', () {
    test('첫 3일 평균으로 제안, 500보 단위 내림', () {
      final days = [day(0, steps: 4100), day(1, steps: 4600), day(2, steps: 4300)];
      expect(StepGoalRules.suggestInitialGoal(days), 4000);
    });

    test('아무리 낮아도 3,000보', () {
      final days = List.generate(3, (i) => day(i, steps: 1200));
      expect(StepGoalRules.suggestInitialGoal(days), 3000);
    });

    test('3일 연속 달성하면 1,000보 올리기를 제안', () {
      final days = List.generate(3, (i) => day(i, steps: 5500));
      expect(StepGoalRules.suggestRaise(days, 5000), 6000);
      expect(StepGoalRules.suggestRaise(days.sublist(0, 2), 5000), isNull);
    });
  });

  group('일일 퀘스트 전체 완료 (11-10)', () {
    DailyRecord d(int day, int done) => DailyRecord(
        date: DateTime(2026, 11, day), stepGoal: 3000, questsCompleted: done);

    test('3개를 모두 마친 날은 경험치 +30 더', () {
      expect(ExpRules.forDay(d(5, 3)).questAll, RuleConstants.questAllBonusExp);
      expect(ExpRules.forDay(d(5, 2)).questAll, 0);
      expect(ExpRules.forDay(d(5, 3)).quest, 3 * RuleConstants.questExp);
    });

    test('연속 달성 일수: 오늘 못 했으면 어제까지, 빈 날이 있으면 끊긴다', () {
      expect(QuestRules.allDoneStreak([d(3, 3), d(4, 3), d(5, 3)]), 3);
      expect(QuestRules.allDoneStreak([d(3, 3), d(4, 3), d(5, 1)]), 2);
      expect(QuestRules.allDoneStreak([d(2, 3), d(4, 3), d(5, 3)]), 2);
      expect(QuestRules.allDoneStreak([d(4, 1), d(5, 1)]), 0);
    });
  });
}
