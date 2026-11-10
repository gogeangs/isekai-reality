import 'dart:math' as math;

import 'alchemy_rules.dart';
import 'element_rules.dart';
import 'equipment_rules.dart';
import 'job_rules.dart';
import 'modifier_rules.dart';
import 'pet_rules.dart';
import 'monsters.dart';
import 'rule_constants.dart';
import 'stat_rules.dart';

/// 전투에 나오는 몬스터 한 마리 (층마다 하나)
class Foe {
  const Foe({
    required this.monster,
    required this.maxHp,
    required this.attack,
    this.mods = const [],
    this.defense = 1,
    this.speed = 1,
    this.small = false,
  });

  final MonsterId monster;
  final int maxHp;
  final int attack;

  /// 수식어 (11-10 #21, 필드 몬스터만)
  final List<ModifierId> mods;

  /// 방어 배수: 각성자가 주는 피해를 이만큼 나눈다
  final double defense;

  /// 속도 배수: 각성자보다 빠르면 먼저 친다
  final double speed;

  /// 분열해서 나온 작은 몬스터
  final bool small;

  MonsterInfo get info => Monsters.info(monster);
  bool get isBoss => info.isBoss;
  MonsterTrait get trait => info.trait;

  /// 화면에 보이는 이름 (수식어 포함)
  String get name => small
      ? '작은 ${info.name}'
      : ModifierRules.displayName(monster, mods);

  ModGrade get grade => ModifierRules.gradeOf(mods);

  bool has(ModifierId m) => mods.contains(m);
}

class BattleRules {
  BattleRules._();

  /// 이 레벨에서 '포인트를 고르게 나눈 각성자'의 스탯 (11-11 #50).
  /// 레벨마다 포인트 5를 다섯 스탯에 하나씩 나눈 것으로 본다. 몬스터는 이 기준으로 강해진다.
  static Stats expectedStats(int level) =>
      Stats.all(StatRules.start + math.max(0, level - 1));

  /// 기준 각성자의 공격
  static int expectedAttack(int level) =>
      StatRules.attack(level: level, stats: expectedStats(level));

  static int expectedMaxHp(int level) =>
      StatRules.battleMaxHp(level: level, stats: expectedStats(level));

  /// 던전 4층: 일반 3층 + 마지막 보스(미궁 문지기).
  /// 미궁 입구에서 열면 일반 층이 모두 미궁 박쥐(장소 전용 몬스터).
  static List<Foe> dungeonFloors({
    required int level,
    required bool atGate,
    required math.Random rng,
  }) {
    final atk = expectedAttack(level);
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
  ///
  /// 몬스터마다 능력치 배수가 있다 (11-11: 혼래빗 빠름, 보어 단단함, 대지 슬라임 방어 등).
  static Foe fieldFoe({required int level, required MonsterId monster}) {
    final atk = expectedAttack(level);
    final hp = expectedMaxHp(level);
    final info = Monsters.info(monster);
    return Foe(
      monster: monster,
      maxHp: math.max(1, (atk * RuleConstants.fieldHitsToClear * info.hp).round()),
      attack: math.max(
          1, (hp / RuleConstants.fieldHpBudgetTicks * info.attack).round()),
      defense: info.defense,
      speed: info.speed,
    );
  }

  /// 수식어가 붙은 필드 몬스터 무리 (11-10 #21).
  /// 무리 지은은 같은 몬스터 2~3마리, 분열하는은 작은 슬라임 하나 더,
  /// 찍찍거리는은 보통 큰쥐 하나 더. 차례로 싸운다.
  static List<Foe> fieldFoes({
    required int level,
    required MonsterId monster,
    List<ModifierId> mods = const [],
    String spawnId = '',
  }) {
    final base = fieldFoe(level: level, monster: monster);
    if (mods.isEmpty) return [base];
    final (h, a, d, sp) = ModifierRules.multipliers(mods);
    final main = Foe(
      monster: monster,
      maxHp: math.max(1, (base.maxHp * h).round()),
      attack: math.max(1, (base.attack * a).round()),
      mods: mods,
      defense: base.defense * d,
      speed: base.speed * sp,
    );
    final packSize = mods.contains(ModifierId.pack)
        ? ModifierRules.foeCount(spawnId, [ModifierId.pack])
        : 1;
    return [
      for (var i = 0; i < packSize; i++) main,
      if (mods.contains(ModifierId.splitting))
        Foe(
          monster: monster,
          maxHp: math.max(1, base.maxHp ~/ 2),
          attack: math.max(1, base.attack ~/ 2),
          small: true,
        ),
      if (mods.contains(ModifierId.squeaky)) base,
    ];
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

  /// 황금빛 몬스터가 도망쳤다 (11-10)
  escaped,
}

/// 자동 전투. 화면은 일정 간격으로 [tick] 을 부르고, 스킬 버튼은 [useSkill].
///
/// 1틱마다 각성자가 먼저 공격하고, 몬스터가 남아 있으면 반격한다.
/// 피해량은 ±10% 흔들린다. 체력은 층이 바뀌어도 이어진다.
///
/// 수식어(11-10): 굶주린·빠른 몬스터는 먼저 치고, 날쌘은 피하고, 단단한은 웅크리고,
/// 분노한은 체력 절반 아래에서 세지고, 독은 3턴 동안 HP를 깎고, 고대의는 4턴마다 강타,
/// 황금빛은 3턴 안에 못 잡으면 도망친다. 홀리는은 각성자가 한 턴 쉬게 한다.
class Battle {
  Battle({
    required this.playerMaxHp,
    required this.playerAttack,
    required List<Foe> floors,
    math.Random? rng,
    this.skillChargeTicks = RuleConstants.skillChargeTicks,
    int? startHp,
    this.damageTaken = 1,
    int? skillDamage,
    this.playerCrit = 0,
    this.playerEvade = 0,
    double playerSpeed = 1,
    this.petSkill,
    this.petAdult = false,
    List<BattlePotion> potions = const [],
    this.autoHp = 0,
    this.autoCure = false,
    this.resist = const {},
    this.attackElement,
    this.skillElement,
    this.guardElements = const {},
    this.mainElement,
    this.attackLevel = 0,
    this.guardLevels = const {},
    this.weaponPotion,
  })  : floors = List.unmodifiable(floors),
        potions = {for (final p in potions) p.key: p},
        _potionLeft = {for (final p in potions) p.key: p.count},
        skillDamage =
            skillDamage ?? playerAttack * RuleConstants.skillDamageMultiplier,
        baseSpeed = playerSpeed,
        playerSpeed = playerSpeed,
        _rng = rng ?? math.Random(),
        playerHp = math.min(playerMaxHp, math.max(0, startHp ?? playerMaxHp)),
        foeHp = floors.first.maxHp;

  /// 플레이어 상태로 전투를 만든다. [gear] 는 입은 장비의 힘 (11-10 #27).
  /// 스탯 5종(11-11 #50): 힘 → 공격, 지능 → 정령의 일격, 체력 → HP·받는 피해,
  /// 민첩 → 속도·회피, 행운 → 치명타.
  factory Battle.forPlayer({
    required int level,
    required Stats stats,
    required List<Foe> floors,
    math.Random? rng,
    int skillChargeTicks = RuleConstants.skillChargeTicks,
    int? startHp,
    GearBonus gear = GearBonus.none,
    PetSkill? petSkill,
    bool petAdult = false,
    double power = 1,
    List<BattlePotion> potions = const [],
    int autoHp = 0,
    bool autoCure = false,
    Map<Element, double> resist = const {},
    Element? skillElement,
    Element? mainElement,
    Element? weaponPotion,
  }) {
    final all = stats + gear.stats;
    // 펫 스킬 (11-11 #38): 쪼기는 4틱에 찬다 (정령 물약·간식이 더 빠르면 그쪽)
    final petTicks = petSkill == null ? null : PetRules.skillChargeTicks(petSkill);
    final baseTicks = petTicks != null && skillChargeTicks < skillUnavailable
        ? math.min(skillChargeTicks, petTicks)
        : skillChargeTicks;
    final ticks = baseTicks >= skillUnavailable
        ? baseTicks
        : math.max(1, baseTicks - gear.skillFaster);
    // 정령의 일격은 ×4. 펫 스킬은 배율만큼
    final petScale = petSkill == null
        ? 1.0
        : PetRules.skillMultiplier(petSkill, adult: petAdult) /
            RuleConstants.skillDamageMultiplier;
    // [power]: 원정 펫 특기(부엉이·검은 고양이)의 전투력 배율
    final boost = (1 + gear.attack) * power;
    return Battle(
      startHp: startHp,
      playerMaxHp: playerMaxHpWith(level: level, stats: stats, gear: gear),
      playerAttack:
          math.max(1, (StatRules.attack(level: level, stats: all) * boost).round()),
      skillDamage: math.max(
          1,
          (StatRules.skillDamage(level: level, stats: all) * boost * petScale)
              .round()),
      petSkill: petSkill,
      petAdult: petAdult,
      potions: potions,
      autoHp: autoHp,
      autoCure: autoCure,
      resist: resist,
      attackElement: gear.attackElement,
      skillElement: skillElement,
      guardElements: gear.guardElements,
      mainElement: mainElement,
      attackLevel: gear.attackLevel,
      guardLevels: gear.guardLevels,
      weaponPotion: weaponPotion,
      floors: floors,
      rng: rng,
      skillChargeTicks: ticks,
      damageTaken: (1 - gear.reduce) * (1 - StatRules.vitalityReduce(all)),
      playerCrit: math.min(0.6, StatRules.crit(all) + gear.crit),
      playerEvade: math.min(0.4, StatRules.evade(all) + gear.evade),
      // 같은 레벨 기준 각성자보다 빠르면 1보다 크다 (몬스터 속도와 비교)
      playerSpeed: StatRules.speed(all) /
          StatRules.speed(BattleRules.expectedStats(level)),
    );
  }

  /// 장비를 입은 최대 HP
  static int playerMaxHpWith(
          {required int level, required Stats stats, GearBonus gear = GearBonus.none}) =>
      (StatRules.battleMaxHp(level: level, stats: stats + gear.stats) *
              (1 + gear.maxHp))
          .round();

  final int playerMaxHp;
  final int playerAttack;

  /// 데리고 다니는 펫의 던전 스킬 (없으면 정령의 일격)
  final PetSkill? petSkill;
  final bool petAdult;

  /// 혀로 묶기: 몬스터가 다음 차례를 쉰다
  bool _foeBound = false;

  /// 약점 간파: 남은 턴 동안 각성자 피해 증가
  int insightTurns = 0;

  /// 작은 불씨: 몬스터 화상 남은 턴
  int foeBurnTurns = 0;

  /// 작은 보호막: 남은 막는 횟수
  int shieldHits = 0;

  // ───────────── 물약 (11-11 #57)

  /// 가방에서 가져온 물약 (키 → 정보)
  final Map<String, BattlePotion> potions;
  final Map<String, int> _potionLeft;

  /// 이번 전투에서 마신 물약 (끝나면 가방에서 뺀다)
  final Map<String, int> potionsUsed = {};
  int get potionsDrunk => potionsUsed.values.fold(0, (a, b) => a + b);

  /// 자동 마시기: HP 이 % 아래면 회복 물약 (0이면 끔)
  final int autoHp;

  /// 자동 마시기: 중독·화상·눈부심 풀기
  final bool autoCure;

  /// 속성 저항 (그 속성 몬스터에게 받는 피해 감소)
  final Map<Element, double> resist;

  /// 각성자 공격 속성 (무기, 없으면 무속성)
  final Element? attackElement;

  /// 스킬 속성 (펫 속성. 정령의 일격은 무속성)
  final Element? skillElement;

  /// 방어 속성 (장비)
  final Set<Element> guardElements;

  /// 주 속성 (숨은 점수 1위)
  final Element? mainElement;

  /// 장비 속성 강화 단계 (11-11 #74, 숨김)
  final int attackLevel;
  final Map<Element, int> guardLevels;

  /// 공격 속성 물약 (11-11 #74): 무기 속성보다 먼저
  final Element? weaponPotion;

  /// 빙결 (11-11 #74 얼음 슬라임): 다음 내 차례를 쉰다
  bool frozen = false;

  /// 녹이는 물약을 마신 뒤 다시 얼지 않는 턴
  int freezeImmune = 0;

  /// 얼음 공격 물약으로 몬스터가 얼었는지 (다음 몬스터 차례를 쉰다)
  bool _foeFrozen = false;

  /// 이번 전투에서 몬스터를 얼린 횟수
  int foeFreezes = 0;

  /// 지금 걸린 것이 화상인지 (아니면 중독)
  bool burning = false;

  /// 해독제·연고를 마신 뒤 다시 안 걸리는 턴
  int immuneTurns = 0;

  /// 맑은 눈 물약: 이번 전투 동안 눈부심에 빗나가지 않는다
  bool clearEye = false;

  int potionLeft(String key) => _potionLeft[key] ?? 0;

  /// 물약을 마신다 (전투 한 번에 3개까지)
  bool drink(String key) {
    final p = potions[key];
    if (p == null || potionLeft(key) <= 0 || isOver) return false;
    if (potionsDrunk >= AlchemyRules.perBattle) return false;
    switch (p.cure) {
      case CureKind.poison:
        if (poisonTurns <= 0 || burning) return false;
        poisonTurns = 0;
        immuneTurns = 3;
      case CureKind.burn:
        if (poisonTurns <= 0 || !burning) return false;
        poisonTurns = 0;
        immuneTurns = 3;
      case CureKind.dazzle:
        if (clearEye) return false;
        clearEye = true;
      case CureKind.freeze:
        if (!frozen) return false;
        frozen = false;
        freezeImmune = 3;
      case null:
        if (p.hpRatio <= 0 || playerHp >= playerMaxHp) return false;
        playerHp = math.min(
            playerMaxHp, playerHp + (playerMaxHp * p.hpRatio).round());
    }
    _potionLeft[key] = potionLeft(key) - 1;
    potionsUsed[key] = (potionsUsed[key] ?? 0) + 1;
    lastEvent = '${p.name}!';
    return true;
  }

  /// 자동으로 마실 물약이 있으면 마신다
  void _autoDrink() {
    if (isOver) return;
    if (autoCure && poisonTurns > 0) {
      final kind = burning ? CureKind.burn : CureKind.poison;
      for (final p in potions.values) {
        if (p.cure == kind && drink(p.key)) break;
      }
    }
    if (autoCure && frozen) {
      for (final p in potions.values) {
        if (p.cure == CureKind.freeze && drink(p.key)) break;
      }
    }
    if (autoCure &&
        !clearEye &&
        floors[floor].trait == MonsterTrait.dazzle) {
      for (final p in potions.values) {
        if (p.cure == CureKind.dazzle && drink(p.key)) break;
      }
    }
    if (autoHp > 0 && playerHp * 100 < playerMaxHp * autoHp) {
      // 작은 것부터
      final heals = [
        for (final p in potions.values)
          if (p.cure == null && p.hpRatio > 0 && potionLeft(p.key) > 0) p,
      ]..sort((a, b) => a.hpRatio.compareTo(b.hpRatio));
      if (heals.isNotEmpty) drink(heals.first.key);
    }
  }

  /// 받는 피해 배수 (장비·체력으로 줄어든다)
  final double damageTaken;

  /// 정령의 일격 피해 (지능)
  final int skillDamage;

  /// 치명타·회피 확률 (행운·민첩·장비)
  final double playerCrit;
  final double playerEvade;

  /// 각성자 속도 (민첩, 같은 레벨 기준 1). 끈적한 슬라임에게 맞으면 0.8배.
  final double baseSpeed;
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
      phase == BattlePhase.cleared ||
      phase == BattlePhase.failed ||
      phase == BattlePhase.escaped;

  /// 이번 층에서 지난 턴 수
  int floorTicks = 0;

  /// 남은 중독 턴
  int poisonTurns = 0;

  double playerSpeed;

  /// 마지막 턴에 일어난 일 ('피했다!' 등, 화면 연출용). 없으면 null.
  String? lastEvent;
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
      floorTicks = 0;
      _charged = false;
      _foeBound = false;
      _foeFrozen = false;
      foeBurnTurns = 0;
      lastDealt = 0;
      lastTaken = 0;
      lastWasSkill = false;
      lastEvent = null;
      return;
    }
    ticks++;
    floorTicks++;
    lastWasSkill = false;
    lastEvent = null;
    lastDealt = 0;
    lastTaken = 0;
    final f = foe;
    final foeFirst = f.has(ModifierId.hungry) || f.speed > playerSpeed;

    if (foeFirst) {
      _foeTurn();
      if (isOver) return;
    }

    // 번개 같은: 첫 턴에 한 번 더 공격
    if (foeFirst && f.has(ModifierId.lightning) && floorTicks == 1) {
      _foeTurn();
      if (isOver) return;
    }

    // 각성자 차례
    if (frozen) {
      frozen = false;
      lastEvent = '얼어서 움직일 수 없어요!';
    } else if (f.has(ModifierId.bewitching) && _rng.nextDouble() < 0.25) {
      lastEvent = '홀렸어요!';
    } else if (f.has(ModifierId.nimble) && _rng.nextDouble() < 0.20) {
      lastEvent = '피했어요!';
    } else if (f.has(ModifierId.lightning) && _rng.nextDouble() < 0.25) {
      lastEvent = '피했어요!';
    } else if (f.trait == MonsterTrait.evade && _rng.nextDouble() < 0.15) {
      lastEvent = '피했어요!';
    } else if (f.trait == MonsterTrait.dazzle &&
        !clearEye &&
        _rng.nextDouble() < 0.25) {
      lastEvent = '눈부셔요!';
    } else {
      var dmg = _vary(playerAttack);
      if (insightTurns > 0) {
        dmg = (dmg * (1 + PetRules.insightBonus(adult: petAdult))).round();
        insightTurns--;
      }
      if (playerCrit > 0 && _rng.nextDouble() < playerCrit) {
        dmg = (dmg * StatRules.critMultiplier).round();
        lastEvent = '치명타!';
      }
      if (f.defense != 1) dmg = math.max(1, (dmg / f.defense).round());
      dmg = _elemental(dmg, weaponPotion ?? attackElement,
          level: weaponPotion != null ? 0 : attackLevel);
      if (f.has(ModifierId.sturdy) && _rng.nextDouble() < 0.20) {
        dmg = math.max(1, dmg ~/ 2);
        lastEvent = '웅크렸어요!';
      }
      lastDealt = dmg;
      _hitFoe(dmg);
      _inflict();
    }
    if (phase != BattlePhase.fighting) return;

    if (!foeFirst) {
      _foeTurn();
      if (isOver) return;
      if (f.has(ModifierId.lightning) && floorTicks == 1) {
        _foeTurn();
        if (isOver) return;
      }
    }

    // 작은 불씨: 몬스터 화상 (최대 체력 2%)
    if (foeBurnTurns > 0) {
      foeBurnTurns--;
      _hitFoe(math.max(1, (f.maxHp * 0.02).round()));
      if (phase != BattlePhase.fighting) return;
    }

    // 물 슬라임: 매 턴 끝에 5% 회복
    if (f.trait == MonsterTrait.regen && foeHp < f.maxHp) {
      foeHp = math.min(f.maxHp, foeHp + math.max(1, (f.maxHp * 0.05).round()));
    }

    // 중독·화상
    if (poisonTurns > 0) {
      final p = math.max(1, (playerMaxHp * 0.02).round());
      poisonTurns--;
      lastTaken += p;
      playerHp = math.max(0, playerHp - p);
      if (playerHp == 0) {
        phase = BattlePhase.failed;
        return;
      }
    }

    // 황금빛: 3턴 안에 못 잡으면 도망
    if (f.has(ModifierId.golden) && floorTicks >= 3) {
      phase = BattlePhase.escaped;
      lastEvent = '도망쳤어요!';
      return;
    }
    if (immuneTurns > 0) immuneTurns--;
    if (freezeImmune > 0) freezeImmune--;
    _autoDrink();
    if (skillCharge < skillChargeTicks) skillCharge++;
  }

  void _foeTurn() {
    final f = foe;
    if (_foeBound) {
      _foeBound = false;
      lastEvent = '묶였어요!';
      return;
    }
    if (_foeFrozen) {
      _foeFrozen = false;
      lastEvent = '얼어서 움직이지 못해요!';
      return;
    }
    if (playerEvade > 0 && _rng.nextDouble() < playerEvade) {
      lastEvent = '회피!';
      return;
    }
    var atk = f.attack.toDouble();
    if (f.has(ModifierId.enraged) && foeHp * 2 < f.maxHp) atk *= 1.5;
    if (f.has(ModifierId.charging) && !_charged) {
      atk *= 2;
      _charged = true;
      lastEvent = '돌진!';
    }
    if (f.has(ModifierId.ancient) && floorTicks % 4 == 0) {
      atk *= 2.5;
      lastEvent = '강타!';
    }
    if (damageTaken != 1) atk *= damageTaken;
    final element = AlchemyRules.elementOf(f.monster);
    if (element != null && (resist[element] ?? 0) > 0) {
      atk *= 1 - resist[element]!;
    }
    // 방어 속성 장비·주 속성 (11-11 #63, 숫자는 숨김)
    if (element != null) {
      if (guardElements.contains(element)) {
        atk *= SmithRules.guardAt(guardLevels[element] ?? 0);
      }
      if (element == mainElement) atk *= 1 - ElementRules.mainBonus;
    }
    if (shieldHits > 0) {
      atk *= 0.5;
      shieldHits--;
      lastEvent ??= '보호막!';
    }
    final taken = _vary(math.max(1, atk.round()));
    lastTaken += taken;
    playerHp = math.max(0, playerHp - taken);
    if ((f.has(ModifierId.venomous) ||
            f.has(ModifierId.plagued) ||
            f.trait == MonsterTrait.poison) &&
        immuneTurns <= 0 &&
        _rng.nextDouble() < 0.30) {
      poisonTurns = 3;
      burning = false;
      lastEvent = '중독!';
    }
    if (f.trait == MonsterTrait.freeze &&
        freezeImmune <= 0 &&
        !frozen &&
        playerHp > 0 &&
        _rng.nextDouble() < freezeChance) {
      frozen = true;
      lastEvent = '얼어붙었어요!';
    }
    if (f.trait == MonsterTrait.burn &&
        immuneTurns <= 0 &&
        _rng.nextDouble() < 0.30) {
      poisonTurns = 3;
      burning = true;
      lastEvent = '화상!';
    }
    // 어둠 슬라임: 때린 피해의 30% 회복
    if (f.trait == MonsterTrait.drain && foeHp < f.maxHp) {
      foeHp = math.min(f.maxHp, foeHp + math.max(1, (taken * 0.3).round()));
    }
    if (f.has(ModifierId.sticky)) playerSpeed = baseSpeed * 0.8;
    if (playerHp == 0) phase = BattlePhase.failed;
  }

  /// 돌진하는: 이번 층에서 이미 돌진했는지
  bool _charged = false;

  /// 스킬 '불씨의 일격'. 충전이 다 됐을 때만 쓸 수 있다.
  bool useSkill() {
    if (!skillReady) return false;
    skillCharge = 0;
    lastWasSkill = true;
    lastEvent = null;
    var dmg = _vary(skillDamage);
    switch (petSkill) {
      case PetSkill.scratch:
        dmg = (dmg * StatRules.critMultiplier).round();
        lastEvent = '치명타!';
      case PetSkill.tongue:
        _foeBound = true;
        lastEvent = '묶었어요!';
      case PetSkill.insight:
        insightTurns = PetRules.insightTurns;
        lastEvent = '약점 간파!';
      case PetSkill.ember:
        foeBurnTurns = 3;
        lastEvent = '화상!';
      case PetSkill.shield:
        shieldHits = PetRules.shieldHits(adult: petAdult);
        lastEvent = '보호막!';
      case PetSkill.peck || null:
        break;
    }
    if (foe.defense != 1) dmg = math.max(1, (dmg / foe.defense).round());
    dmg = _elemental(dmg, skillElement);
    lastDealt = dmg;
    lastTaken = 0;
    _hitFoe(lastDealt);
    return true;
  }

  /// 얼음 슬라임이 얼릴 확률
  static const double freezeChance = 0.20;

  /// 공격 속성 물약의 상태 이상 (독·불: 3턴 동안 2%, 얼음: 다음 차례를 쉼)
  void _inflict() {
    final e = weaponPotion;
    if (e == null || phase != BattlePhase.fighting) return;
    if (e != Element.fire && e != Element.poison && e != Element.ice) return;
    if (_rng.nextDouble() >= AlchemyRules.weaponInflict) return;
    switch (e) {
      case Element.ice:
        _foeFrozen = true;
        foeFreezes++;
        lastEvent = '얼렸어요!';
      case Element.fire:
        foeBurnTurns = 3;
        lastEvent = '불태웠어요!';
      default:
        foeBurnTurns = 3;
        lastEvent = '중독시켰어요!';
    }
  }

  /// 속성 상성 (11-11 #63): 배율은 숨기고 문구로만 알린다.
  /// [level] 은 장비 속성 강화 단계 (11-11 #74): 강할 때 배율이 더 커진다.
  int _elemental(int dmg, Element? attack, {int level = 0}) {
    var m = ElementRules.multiplier(attack, AlchemyRules.elementOf(foe.monster));
    if (m > 1 && level > 0) m = SmithRules.strongAt(level);
    var d = dmg * m;
    if (attack != null && attack == mainElement) d *= 1 + ElementRules.mainBonus;
    if (m > 1) lastEvent = superEffective;
    if (m < 1) lastEvent = notEffective;
    return math.max(1, d.round());
  }

  static const superEffective = '효과가 굉장했다!';
  static const notEffective = '효과가 별로인 것 같다…';

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

/// 물약이 푸는 상태
enum CureKind { poison, burn, dazzle, freeze }

/// 전투에 가져가는 물약 한 종류
class BattlePotion {
  const BattlePotion({
    required this.key,
    required this.name,
    required this.count,
    this.hpRatio = 0,
    this.cure,
  });

  /// 'shop:healSmall' · 'alc:healBig*' 처럼 가방에서 뺄 때 쓰는 키
  final String key;
  final String name;
  final int count;
  final double hpRatio;
  final CureKind? cure;
}
