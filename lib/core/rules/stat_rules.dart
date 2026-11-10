import 'dart:math' as math;

import '../models/daily_record.dart';
import 'rule_constants.dart';

/// 다섯 가지 스탯 (11-11 #50). 쌓이기만 하고 줄지 않는다.
///
/// 레벨업 포인트를 직접 나누는 것이 거의 전부이고, 생활 활동이 아주 작은 보너스로
/// 더해진다. 어떤 활동이 어떤 스탯을 올리는지는 게임 안에서 알려 주지 않는다.
class Stats {
  const Stats({
    this.strength = 0,
    this.agility = 0,
    this.intellect = 0,
    this.vitality = 0,
    this.luck = 0,
  });

  /// 힘: 물리 공격
  final int strength;

  /// 민첩: 속도(먼저 공격)·회피
  final int agility;

  /// 지능: 마법 공격(정령의 일격)·MP
  final int intellect;

  /// 체력: HP·방어
  final int vitality;

  /// 행운: 치명타·드롭·수식어 몬스터
  final int luck;

  static const zero = Stats();

  int get total => strength + agility + intellect + vitality + luck;

  Stats operator +(Stats o) => Stats(
        strength: strength + o.strength,
        agility: agility + o.agility,
        intellect: intellect + o.intellect,
        vitality: vitality + o.vitality,
        luck: luck + o.luck,
      );

  Stats operator -(Stats o) => Stats(
        strength: strength - o.strength,
        agility: agility - o.agility,
        intellect: intellect - o.intellect,
        vitality: vitality - o.vitality,
        luck: luck - o.luck,
      );

  int of(StatKind k) => switch (k) {
        StatKind.strength => strength,
        StatKind.agility => agility,
        StatKind.intellect => intellect,
        StatKind.vitality => vitality,
        StatKind.luck => luck,
      };

  Stats withValue(StatKind k, int v) => Stats(
        strength: k == StatKind.strength ? v : strength,
        agility: k == StatKind.agility ? v : agility,
        intellect: k == StatKind.intellect ? v : intellect,
        vitality: k == StatKind.vitality ? v : vitality,
        luck: k == StatKind.luck ? v : luck,
      );

  /// 모든 스탯에 같은 값
  static Stats all(int v) =>
      Stats(strength: v, agility: v, intellect: v, vitality: v, luck: v);

  Map<String, int> toJson() => {
        for (final k in StatKind.values)
          if (of(k) != 0) k.name: of(k),
      };

  factory Stats.fromJson(Map<String, dynamic>? j) {
    var s = Stats.zero;
    for (final k in StatKind.values) {
      final v = (j?[k.name] as num?)?.toInt();
      if (v != null) s = s.withValue(k, v);
    }
    return s;
  }

  @override
  bool operator ==(Object o) =>
      o is Stats &&
      o.strength == strength &&
      o.agility == agility &&
      o.intellect == intellect &&
      o.vitality == vitality &&
      o.luck == luck;

  @override
  int get hashCode => Object.hash(strength, agility, intellect, vitality, luck);
}

enum StatKind { strength, agility, intellect, vitality, luck }

extension StatKindInfo on StatKind {
  String get label => switch (this) {
        StatKind.strength => '힘',
        StatKind.agility => '민첩',
        StatKind.intellect => '지능',
        StatKind.vitality => '체력',
        StatKind.luck => '행운',
      };

  /// 분배 화면에 보이는 역할 (어떤 활동으로 오르는지는 말하지 않는다)
  String get role => switch (this) {
        StatKind.strength => '물리 공격',
        StatKind.agility => '먼저 공격·회피',
        StatKind.intellect => '정령의 일격·MP',
        StatKind.vitality => 'HP·받는 피해',
        StatKind.luck => '치명타·귀한 재료·수식어 몬스터',
      };

  /// 예전 이름 (장비 추가 능력 키를 옮길 때)
  static StatKind? parse(String key) => switch (key) {
        'strength' => StatKind.strength,
        'agility' => StatKind.agility,
        'intellect' || 'wisdom' => StatKind.intellect,
        'vitality' => StatKind.vitality,
        'luck' || 'spirit' => StatKind.luck,
        _ => null,
      };
}

/// 생활 보너스가 오른 한 번 (정령 대사용)
class LifeBonusStep {
  const LifeBonusStep(this.kind);
  final StatKind kind;
}

class StatRules {
  StatRules._();

  /// 모든 스탯의 시작 값
  static const int start = RuleConstants.statStartValue;

  /// 레벨이 오를 때마다 받는 포인트
  static const int pointsPerLevel = 5;

  /// Lv.[level] 까지 받은 포인트
  static int pointsFor(int level) => math.max(0, level - 1) * pointsPerLevel;

  /// 초기화 가격: 처음 1번 무료, 그다음 금화 100 × 횟수 (최대 1,000)
  static int resetCost(int resetsDone) =>
      resetsDone == 0 ? 0 : math.min(1000, 100 * resetsDone);

  /// 아직 나누지 않은 포인트는 전투에서 고르게 나눈 것처럼 친다
  static Stats evenShare(int points) {
    if (points <= 0) return Stats.zero;
    final each = points ~/ StatKind.values.length;
    var rest = points % StatKind.values.length;
    var s = Stats.all(each);
    for (final k in StatKind.values) {
      if (rest == 0) break;
      s = s.withValue(k, s.of(k) + 1);
      rest--;
    }
    return s;
  }

  // ───────────────────────── 생활 보너스 (숨겨진 규칙)

  /// 기록으로 계산한 생활 보너스 (시작 값 10은 빼고)
  static Stats lifeBonus(List<DailyRecord> history) {
    var hunts = 0, nightHunts = 0, goalDays = 0, morningDays = 0;
    var questsAndFinds = 0, expeditionWins = 0, steps = 0;
    var restSevens = 0, loginThirties = 0, rareHunts = 0;
    var revenges = 0, urgents = 0;
    final seen = <String>{};
    var restStreak = 0, login = 0;
    DateTime? prev;
    for (final d in history) {
      hunts += d.huntCounts.isNotEmpty
          ? d.huntCounts.values.fold<int>(0, (a, b) => a + b)
          : d.purifiedMonsterIds.length;
      nightHunts += d.counters['nightHunts'] ?? 0;
      if (d.stepGoalAchieved) goalDays++;
      if (d.stepsMorning >= 1000) morningDays++;
      questsAndFinds += d.questsCompleted + (d.counters['errandDone'] ?? 0);
      for (final m in d.purifiedMonsterIds) {
        if (seen.add(m)) questsAndFinds++;
      }
      expeditionWins += d.counters['expeditionWin'] ?? 0;
      steps += d.steps;
      rareHunts += d.counters['rarePlus'] ?? 0;
      revenges += d.counters['revenge'] ?? 0;
      urgents += d.counters['urgentDone'] ?? 0;

      final continuous = prev != null &&
          DateTime(d.date.year, d.date.month, d.date.day)
                  .difference(DateTime(prev.year, prev.month, prev.day))
                  .inDays ==
              1;
      restStreak = d.rested ? (continuous && restStreak > 0 ? restStreak + 1 : 1) : 0;
      if (restStreak > 0 && restStreak % 7 == 0) restSevens++;
      login = d.openedApp ? (continuous ? login + 1 : 1) : 0;
      if (login > 0 && login % 30 == 0) loginThirties++;
      prev = d.date;
    }
    return Stats(
      strength: hunts ~/ 500 + nightHunts ~/ 100,
      agility: goalDays ~/ 30 + morningDays ~/ 15,
      intellect: questsAndFinds ~/ 100 + expeditionWins ~/ 50,
      vitality: steps ~/ 300000 + restSevens,
      luck: loginThirties + rareHunts ~/ 20 + revenges ~/ 5 + urgents ~/ 5,
    );
  }

  /// 시작 값 + 생활 보너스 (포인트로 올린 값은 빼고)
  static Stats fromHistory(List<DailyRecord> history) =>
      Stats.all(start) + lifeBonus(history);

  // ───────────────────────── 전투

  /// 물리 공격 = 2.5 × 레벨 + 5 × 힘
  static int attack({required int level, required Stats stats}) =>
      math.max(1, (2.5 * level + 5 * stats.strength).round());

  /// 정령의 일격 한 번 = (2.5 × 레벨 + 5 × 지능) × 4
  static int skillDamage({required int level, required Stats stats}) =>
      math.max(1, ((2.5 * level + 5 * stats.intellect) *
              RuleConstants.skillDamageMultiplier)
          .round());

  /// 최대 HP = 600 + 50 × 레벨 + 25 × 체력
  static int battleMaxHp({required int level, required Stats stats}) =>
      600 + level * 50 + stats.vitality * 25;

  /// 받는 피해 줄이기: 체력 10을 넘는 1마다 0.5% (최대 25%)
  static double vitalityReduce(Stats s) =>
      (math.max(0, s.vitality - start) * 0.005).clamp(0.0, 0.25).toDouble();

  /// 속도: 민첩 10을 넘는 1마다 1%
  static double speed(Stats s) => 1 + math.max(0, s.agility - start) * 0.01;

  /// 회피: 민첩 10을 넘는 1마다 0.4%p (최대 25%)
  static double evade(Stats s) =>
      (math.max(0, s.agility - start) * 0.004).clamp(0.0, 0.25).toDouble();

  /// 치명타: 5% + 행운 10을 넘는 1마다 0.5%p (최대 40%), 피해 ×1.5
  static double crit(Stats s) =>
      (0.05 + math.max(0, s.luck - start) * 0.005).clamp(0.0, 0.40).toDouble();
  static const double critMultiplier = 1.5;

  /// 귀한 재료 확률 더하기: 행운 10을 넘는 1마다 +0.2%p (최대 +10%p)
  static double rareDropBonus(Stats s) =>
      (math.max(0, s.luck - start) * 0.002).clamp(0.0, 0.10).toDouble();

  /// 수식어 몬스터 더하기: 행운 10을 넘는 1마다 +0.1%p (최대 +5%p)
  static double modifierBonus(Stats s) =>
      (math.max(0, s.luck - start) * 0.001).clamp(0.0, 0.05).toDouble();

  /// 최대 MP: 60 + 지능 10을 넘는 1마다 1
  static int maxMp(Stats s) =>
      RuleConstants.mpMax + math.max(0, s.intellect - start);

  /// 예전 이름: 전투력 (던전 입구에 보여 주는 숫자). 공격·HP를 합친 대략의 힘.
  static int combatPower({required int level, required Stats stats}) =>
      level * 10 + stats.total * 5;
}
