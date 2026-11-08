import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/rules/rules.dart';

DailyRecord day(
  int index, {
  int steps = 0,
  int stepsAfter8pm = 0,
  int? sleep,
  int study = 0,
  int goal = 5000,
  List<DungeonRun> runs = const [],
  int monsters = 0,
  int newPlaces = 0,
  int revisits = 0,
  int quests = 0,
}) =>
    DailyRecord(
      date: DateTime(2026, 11, 1).add(Duration(days: index)),
      steps: steps,
      stepsAfter8pm: stepsAfter8pm,
      sleepMinutes: sleep,
      studyMinutes: study,
      stepGoal: goal,
      dungeonRuns: runs,
      fieldMonstersPurified: monsters,
      newPlacesVisited: newPlaces,
      placesRevisited: revisits,
      questsCompleted: quests,
    );

void main() {
  group('레벨', () {
    test('Lv.12 → 13 에는 375가 필요하다', () {
      expect(LevelRules.expRequiredFor(12), 375);
      expect(LevelRules.expRequiredFor(13), 400);
    });

    test('Lv.10 까지 누적 1,800, Lv.13 까지 누적 2,850', () {
      expect(LevelRules.totalExpToReach(10), 1800);
      expect(LevelRules.totalExpToReach(13), 2850);
    });

    test('누적 경험치로 레벨과 진행도를 계산한다', () {
      final p = LevelRules.fromTotalExp(LevelRules.totalExpToReach(12) + 260);
      expect(p.level, 12);
      expect(p.expIntoLevel, 260);
      expect(p.expToNext, 375);
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
        study: 300,
        quests: 5,
      ));
      expect(b.dungeon, 200); // 4회
      expect(b.fieldMonster, 75); // 5마리
      expect(b.exploration, 90); // 3곳
      expect(b.study, 60); // 2시간
      expect(b.quest, 60); // 3개
    });

    test('수면 경험치', () {
      expect(ExpRules.sleepExp(430), 30);
      expect(ExpRules.sleepExp(390), 15);
      expect(ExpRules.sleepExp(300), 0);
      expect(ExpRules.sleepExp(null), 0);
    });

    test('7일째마다 연속 접속 보너스', () {
      expect(ExpRules.streakBonus(7), 100);
      expect(ExpRules.streakBonus(14), 100);
      expect(ExpRules.streakBonus(6), 0);
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
        day(0, steps: 16000, sleep: 450, study: 120), // 목표 달성, 잘 잠
        day(1, steps: 15000, sleep: 380, study: 90), // 목표 달성
        day(2, steps: 2000, sleep: 480), // 잘 잠
      ];
      final s = StatRules.fromHistory(history);
      expect(s.vitality, 11); // 33,000보
      expect(s.agility, 12);
      expect(s.wisdom, 11); // 210분
      expect(s.spirit, 12);
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

    test('레벨 칭호', () {
      expect(TitleRules.earned([], 10),
          containsAll([TitleId.awakened, TitleId.lanternKeeper]));
    });
  });

  group('직업 각성', () {
    test('공부를 많이 하면 현자', () {
      final week = List.generate(
          7, (i) => day(i, steps: 3000, sleep: 360, study: 60));
      expect(JobRules.awaken(week), Job.sage);
    });

    test('적게 걷는 사람도 목표의 2배를 자주 걸으면 기사', () {
      final week = List.generate(
          7, (i) => day(i, steps: i < 4 ? 6000 : 1000, goal: 3000));
      expect(JobRules.awaken(week), Job.knight);
    });

    test('잠을 규칙적으로 자면 성직자', () {
      final week = List.generate(7, (i) => day(i, steps: 2000, sleep: 450));
      expect(JobRules.awaken(week), Job.cleric);
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
}
