// 밸런스 점검: 걷는 양이 다른 세 유형이 2주 동안 어떻게 성장하는지
// 실제 게임 규칙 코드로 계산해 build/reports/balance.md 에 적는다.
//
// 테스트 자체는 "기획 목표 범위 안인지"만 느슨하게 확인한다.

import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/core/format.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/models/player_state.dart';
import 'package:isekai_reality/core/rules/rules.dart';

class Persona {
  const Persona({
    required this.name,
    required this.description,
    required this.goal,
    required this.steps,
    required this.sleep,
    required this.study,
    required this.fieldMonsters,
    required this.newPlaceDays,
    required this.revisitEvery,
    required this.dungeonShare,
  });

  final String name;
  final String description;
  final int goal;
  final (int, int) steps; // 하루 걸음 범위
  final (int, int) sleep; // 수면(분) 범위
  final (int, int) study; // 공부(분) 범위
  final (int, int) fieldMonsters; // 하루 필드 몬스터 정화 수 범위
  final Set<int> newPlaceDays; // 새 장소를 처음 간 날 (1부터)
  final int revisitEvery; // 며칠마다 다시 방문 (0 = 안 함)

  /// 열쇠를 쓰는 비율 (1.0 = 생긴 열쇠를 모두 그날 씀)
  final double dungeonShare;
}

const personas = [
  Persona(
    name: '적게 걷는 사람',
    description: '목표 3,000보, 하루 2,800~4,500보, 수면 5시간 반~7시간, 공부 거의 안 함',
    goal: 3000,
    steps: (2800, 4500),
    sleep: (330, 420),
    study: (0, 10),
    fieldMonsters: (0, 1),
    newPlaceDays: {2, 9},
    revisitEvery: 0,
    dungeonShare: 1,
  ),
  Persona(
    name: '보통',
    description: '목표 5,000보, 하루 4,500~7,500보, 수면 6시간 반~7시간 반, 공부 10~30분',
    goal: 5000,
    steps: (4500, 7500),
    sleep: (390, 460),
    study: (10, 30),
    fieldMonsters: (1, 3),
    newPlaceDays: {1, 3, 6},
    revisitEvery: 2,
    dungeonShare: 1,
  ),
  Persona(
    name: '많이 걷는 사람',
    description: '목표 8,000보, 하루 8,000~13,000보, 수면 7~8시간, 공부 20~60분',
    goal: 8000,
    steps: (8000, 13000),
    sleep: (420, 480),
    study: (20, 60),
    fieldMonsters: (3, 5),
    newPlaceDays: {1, 2, 4},
    revisitEvery: 1,
    dungeonShare: 1,
  ),
];

class DayRow {
  DayRow(this.day, this.steps, this.runs, this.wins, this.winsNoSkill, this.exp,
      this.level);
  final int day;
  final int steps;
  final int runs;
  final int wins;
  final int winsNoSkill;
  final int exp;
  final int level;
}

class Result {
  Result(this.persona, this.rows, this.history, this.finalState);
  final Persona persona;
  final List<DayRow> rows;
  final List<DailyRecord> history;
  final PlayerState finalState;

  int levelOn(int day) => rows[day - 1].level;
  int get runs => rows.fold(0, (s, r) => s + r.runs);
  int get wins => rows.fold(0, (s, r) => s + r.wins);
  int get winsNoSkill => rows.fold(0, (s, r) => s + r.winsNoSkill);
  double get avgExp => rows.fold(0, (s, r) => s + r.exp) / rows.length;
}

int _between(Random r, (int, int) range) =>
    range.$1 + r.nextInt(range.$2 - range.$1 + 1);

Result simulate(Persona p, {int days = 14, int seed = 7}) {
  final rng = Random(seed);
  final battleRng = Random(seed + 100);
  final start = DateTime(2026, 11, 1);
  final history = <DailyRecord>[];
  final rows = <DayRow>[];

  for (var d = 1; d <= days; d++) {
    final isNew = p.newPlaceDays.contains(d);
    final revisit = !isNew &&
        p.revisitEvery > 0 &&
        d > p.newPlaceDays.reduce(min) &&
        d % p.revisitEvery == 0;
    var today = DailyRecord(
      date: start.add(Duration(days: d - 1)),
      steps: _between(rng, p.steps),
      sleepMinutes: _between(rng, p.sleep),
      studyMinutes: _between(rng, p.study),
      stepGoal: p.goal,
      fieldMonstersPurified: _between(rng, p.fieldMonsters),
      newPlacesVisited: isNew ? 1 : 0,
      placesRevisited: revisit ? 1 : 0,
    );

    // 열쇠가 있는 만큼(하루 경험치 인정 4회까지) 던전을 연다
    var wins = 0;
    var winsNoSkill = 0;
    var runs = 0;
    while (true) {
      final state =
          PlayerState.fromHistory(name: p.name, history: [...history, today]);
      final keys = state.gauge.keysAvailable;
      if (keys <= 0 ||
          today.dungeonRuns.length >= RuleConstants.maxDungeonRunsPerDay ||
          runs >= (state.gauge.keysEarnedToday * p.dungeonShare).ceil() + 3) {
        break;
      }
      final level = state.level.level;
      final seedForRun = battleRng.nextInt(1 << 30);
      Battle make() => Battle.forPlayer(
            level: level,
            stats: state.stats,
            floors: BattleRules.dungeonFloors(
                level: level, atGate: false, rng: Random(seedForRun)),
            rng: Random(seedForRun + 1),
          );
      final withSkill = make().runToEnd(useSkills: true);
      final noSkill = make().runToEnd();
      final cleared = withSkill.phase == BattlePhase.cleared;
      if (cleared) wins++;
      if (noSkill.phase == BattlePhase.cleared) winsNoSkill++;
      runs++;
      today = today.copyWith(
          dungeonRuns: [...today.dungeonRuns, DungeonRun(cleared: cleared)]);
    }
    today = today.copyWith(questsCompleted: QuestRules.completedCount(today));
    history.add(today);

    final state = PlayerState.fromHistory(name: p.name, history: history);
    rows.add(DayRow(d, today.steps, runs, wins, winsNoSkill,
        state.dailyExp.last.total, state.level.level));
  }
  return Result(p, rows, history,
      PlayerState.fromHistory(name: p.name, history: history));
}

String report(List<Result> results) {
  final b = StringBuffer()
    ..writeln('# 밸런스 점검 (자동 계산)')
    ..writeln()
    ..writeln('실제 게임 규칙 코드로 2주를 계산했습니다. 던전은 생긴 열쇠를 그날 모두 쓰고, '
        '충전될 때마다 스킬을 쓴다고 가정했습니다. 매일 앱을 연다고 봅니다.')
    ..writeln()
    ..writeln('## 요약')
    ..writeln()
    ..writeln('| 유형 | 7일째 | 14일째 | 하루 평균 경험치 | 던전 | 클리어 (스킬 씀) | 클리어 (스킬 안 씀) | 직업 |')
    ..writeln('| --- | --- | --- | --- | --- | --- | --- | --- |');
  for (final r in results) {
    b.writeln('| ${r.persona.name} | Lv.${r.levelOn(7)} | Lv.${r.levelOn(14)} | '
        '${r.avgExp.round()} | ${r.runs}회 | ${r.wins}회 | ${r.winsNoSkill}회 | '
        '${r.finalState.job?.koreanName ?? '-'} |');
  }
  b
    ..writeln()
    ..writeln('기획 목표: 2주 뒤 Lv.10~13, 하루 보통 150~250 경험치.');

  for (final r in results) {
    final totals = <String, int>{};
    for (final e in r.finalState.dailyExp) {
      totals.update('던전', (v) => v + e.dungeon, ifAbsent: () => e.dungeon);
      totals.update('필드 몬스터', (v) => v + e.fieldMonster,
          ifAbsent: () => e.fieldMonster);
      totals.update('탐험', (v) => v + e.exploration,
          ifAbsent: () => e.exploration);
      totals.update('수면', (v) => v + e.sleep, ifAbsent: () => e.sleep);
      totals.update('공부', (v) => v + e.study, ifAbsent: () => e.study);
      totals.update('퀘스트', (v) => v + e.quest, ifAbsent: () => e.quest);
      totals.update('연속 접속', (v) => v + e.streakBonus,
          ifAbsent: () => e.streakBonus);
    }
    final sum = totals.values.fold(0, (a, b) => a + b);
    final s = r.finalState.stats;
    b
      ..writeln()
      ..writeln('## ${r.persona.name}')
      ..writeln()
      ..writeln(r.persona.description)
      ..writeln()
      ..writeln('경험치 출처: ${totals.entries.map((e) => '${e.key} ${(e.value * 100 / sum).round()}%').join(' · ')}')
      ..writeln()
      ..writeln('14일째 스탯: 체력 ${s.vitality} · 민첩 ${s.agility} · 지력 ${s.wisdom} · 정신 ${s.spirit} '
          '(같은 레벨 기준값 합계 ${BattleRules.expectedStats(r.levelOn(14)).total}, 실제 합계 ${s.total}) · '
          '칭호 ${r.finalState.titles.length}개')
      ..writeln()
      ..writeln('| 날 | 걸음 | 던전 | 클리어 | 스킬 없이 | 경험치 | 레벨 |')
      ..writeln('| --- | --- | --- | --- | --- | --- | --- |');
    for (final row in r.rows) {
      b.writeln('| ${row.day} | ${comma(row.steps)} | ${row.runs} | ${row.wins} | '
          '${row.winsNoSkill} | ${row.exp} | Lv.${row.level} |');
    }
  }
  return b.toString();
}

void main() {
  test('밸런스 점검 보고서', () {
    final results = [for (final p in personas) simulate(p)];
    final text = report(results);
    File('build/reports/balance.md')
      ..createSync(recursive: true)
      ..writeAsStringSync(text);
    // ignore: avoid_print
    print(text);

    // 느슨한 확인: 2주 뒤 모두 Lv.6 이상, 많이 걸을수록 레벨이 높거나 같다
    expect(results.every((r) => r.levelOn(14) >= 6), isTrue);
    expect(results[2].levelOn(14), greaterThanOrEqualTo(results[0].levelOn(14)));
  });
}
