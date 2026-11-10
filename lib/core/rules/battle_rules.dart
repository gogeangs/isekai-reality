import 'dart:math' as math;

import 'monsters.dart';
import 'rule_constants.dart';
import 'stat_rules.dart';

/// 전투에 나오는 몬스터 한 마리 (층마다 하나)
class Foe {
  const Foe({required this.monster, required this.maxHp, required this.attack});

  final MonsterId monster;
  final int maxHp;
  final int attack;

  MonsterInfo get info => Monsters.info(monster);
  bool get isBoss => info.isBoss;
}

class BattleRules {
  BattleRules._();

  static int attackOf(int combatPower) =>
      math.max(1, combatPower ~/ RuleConstants.attackDivisor);

  /// 이 레벨에서 '보통으로 생활한 사람'의 스탯.
  /// 레벨이 오를 즈음 하루가 지난다고 보고, 하루에 스탯 합계가 1.5쯤 오른다.
  static Stats expectedStats(int level) {
    final days = math.max(0, level - 1);
    const s = RuleConstants.statStartValue;
    return Stats(
      vitality: s + days ~/ 6,
      agility: s + days * 3 ~/ 4,
      wisdom: s + days ~/ 8,
      spirit: s + days ~/ 2,
    );
  }

  static int expectedCombatPower(int level) =>
      StatRules.combatPower(level: level, stats: expectedStats(level));

  static int expectedMaxHp(int level) =>
      StatRules.battleMaxHp(level: level, stats: expectedStats(level));

  /// 던전 4층: 일반 3층 + 마지막 보스(미궁 문지기).
  /// 미궁 입구에서 열면 일반 층이 모두 미궁 박쥐(장소 전용 몬스터).
  static List<Foe> dungeonFloors({
    required int level,
    required bool atGate,
    required math.Random rng,
  }) {
    final atk = attackOf(expectedCombatPower(level));
    final hp = expectedMaxHp(level);
    final floorAttack =
        math.max(1, (hp / RuleConstants.dungeonHpBudgetTicks).round());
    // 11-10: 던전의 일반 층은 미궁 박쥐 (돌정령은 정령계라 뺐다)
    const commons = [MonsterId.labyrinthBat];

    return [
      for (var i = 0; i < 3; i++)
        Foe(
          monster: atGate
              ? MonsterId.labyrinthBat
              : commons[rng.nextInt(commons.length)],
          maxHp: atk * RuleConstants.floorHitsToClear,
          attack: floorAttack,
        ),
      Foe(
        monster: MonsterId.labyrinthWarden,
        maxHp: atk * RuleConstants.bossHitsToClear,
        attack: (floorAttack * RuleConstants.bossAttackMultiplier).round(),
      ),
    ];
  }

  /// 지도에서 만나는 필드 몬스터 한 마리 (가볍게 사냥)
  static Foe fieldFoe({required int level, required MonsterId monster}) {
    final atk = attackOf(expectedCombatPower(level));
    final hp = expectedMaxHp(level);
    return Foe(
      monster: monster,
      maxHp: atk * RuleConstants.fieldHitsToClear,
      attack: math.max(1, (hp / RuleConstants.fieldHpBudgetTicks).round()),
    );
  }
}

enum BattlePhase {
  /// 싸우는 중
  fighting,

  /// 이번 층을 정화했다 (다음 틱에 다음 층으로)
  floorCleared,

  /// 모든 층을 정화했다
  cleared,

  /// 체력이 다 떨어졌다 (아무것도 잃지 않는다)
  failed,
}

/// 자동 전투. 화면은 일정 간격으로 [tick] 을 부르고, 스킬 버튼은 [useSkill].
///
/// 1틱마다 각성자가 먼저 공격하고, 몬스터가 남아 있으면 반격한다.
/// 피해량은 ±10% 흔들린다. 체력은 층이 바뀌어도 이어진다.
class Battle {
  Battle({
    required this.playerMaxHp,
    required this.playerAttack,
    required List<Foe> floors,
    math.Random? rng,
    this.skillChargeTicks = RuleConstants.skillChargeTicks,
    int? startHp,
  })  : floors = List.unmodifiable(floors),
        _rng = rng ?? math.Random(),
        playerHp = math.min(playerMaxHp, math.max(0, startHp ?? playerMaxHp)),
        foeHp = floors.first.maxHp;

  /// 플레이어 상태로 전투를 만든다
  factory Battle.forPlayer({
    required int level,
    required Stats stats,
    required List<Foe> floors,
    math.Random? rng,
    int skillChargeTicks = RuleConstants.skillChargeTicks,
    int? startHp,
  }) {
    return Battle(
      startHp: startHp,
      playerMaxHp: StatRules.battleMaxHp(level: level, stats: stats),
      playerAttack:
          BattleRules.attackOf(StatRules.combatPower(level: level, stats: stats)),
      floors: floors,
      rng: rng,
      skillChargeTicks: skillChargeTicks,
    );
  }

  final int playerMaxHp;
  final int playerAttack;
  final List<Foe> floors;
  final math.Random _rng;

  /// 스킬이 다 차는 데 걸리는 틱 (정령 물약을 마신 날은 더 짧다).
  /// [skillUnavailable] 이면 정령이 원정을 가서 스킬을 쓸 수 없다.
  final int skillChargeTicks;

  /// 정령이 원정 중이라 '정령의 일격'을 쓸 수 없는 전투
  static const int skillUnavailable = 1 << 30;
  bool get skillDisabled => skillChargeTicks >= skillUnavailable;

  int playerHp;
  int foeHp;
  int floor = 0;
  int skillCharge = 0;
  int ticks = 0;
  BattlePhase phase = BattlePhase.fighting;

  /// 마지막으로 준 피해와 받은 피해 (화면 연출용)
  int lastDealt = 0;
  int lastTaken = 0;
  bool lastWasSkill = false;

  Foe get foe => floors[floor];
  bool get isOver =>
      phase == BattlePhase.cleared || phase == BattlePhase.failed;
  bool get skillReady =>
      phase == BattlePhase.fighting &&
      skillCharge >= skillChargeTicks;
  double get skillRatio =>
      (skillCharge / skillChargeTicks).clamp(0, 1).toDouble();

  /// 정화한 몬스터 (층 순서)
  List<MonsterId> get purified => [
        for (var i = 0; i < floors.length; i++)
          if (i < floor ||
              (i == floor &&
                  (phase == BattlePhase.floorCleared ||
                      phase == BattlePhase.cleared)))
            floors[i].monster,
      ];

  int _vary(int base) {
    final factor = 0.9 + _rng.nextDouble() * 0.2;
    return math.max(1, (base * factor).round());
  }

  void tick() {
    if (isOver) return;
    if (phase == BattlePhase.floorCleared) {
      floor++;
      foeHp = foe.maxHp;
      phase = BattlePhase.fighting;
      lastDealt = 0;
      lastTaken = 0;
      lastWasSkill = false;
      return;
    }
    ticks++;
    lastWasSkill = false;
    lastDealt = _vary(playerAttack);
    _hitFoe(lastDealt);
    lastTaken = 0;
    if (phase != BattlePhase.fighting) return;

    lastTaken = _vary(foe.attack);
    playerHp = math.max(0, playerHp - lastTaken);
    if (playerHp == 0) {
      phase = BattlePhase.failed;
      return;
    }
    if (skillCharge < skillChargeTicks) skillCharge++;
  }

  /// 스킬 '불씨의 일격'. 충전이 다 됐을 때만 쓸 수 있다.
  bool useSkill() {
    if (!skillReady) return false;
    skillCharge = 0;
    lastWasSkill = true;
    lastDealt = _vary(playerAttack * RuleConstants.skillDamageMultiplier);
    lastTaken = 0;
    _hitFoe(lastDealt);
    return true;
  }

  void _hitFoe(int damage) {
    foeHp = math.max(0, foeHp - damage);
    if (foeHp > 0) return;
    phase = floor == floors.length - 1
        ? BattlePhase.cleared
        : BattlePhase.floorCleared;
  }

  /// 끝까지 자동으로 진행한다 (테스트·밸런스 확인용).
  /// [useSkills] 가 true 면 충전될 때마다 스킬을 쓴다.
  Battle runToEnd({bool useSkills = false, int maxTicks = 1000}) {
    var guard = 0;
    while (!isOver && guard++ < maxTicks) {
      if (useSkills && skillReady) {
        useSkill();
      } else {
        tick();
      }
    }
    return this;
  }
}
