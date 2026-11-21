import 'dart:math' as math;

import 'act2_rules.dart';
import 'act3_rules.dart';
import 'alchemy_rules.dart';
import 'boss_gear_rules.dart';
import 'element_rules.dart';
import 'equipment_rules.dart';
import 'highland_rules.dart';
import 'job_rules.dart';
import 'mastery_rules.dart';
import 'modifier_rules.dart';
import 'pet_rules.dart';
import 'monsters.dart';
import 'rule_constants.dart';
import 'stat_rules.dart';

part 'battle_rules/allies.dart';

part 'battle_rules/special_moves.dart';

part 'battle_rules/skills.dart';

part 'battle_rules/turns.dart';

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
    this.forceElement,
    this.move,
    this.reveal,
    this.sky,
    this.tint,
    this.label,
  });

  /// 묶음 60: 화면에 보이는 이름을 바꿈 (공성전 수비대 = 길드원 이름)
  final String? label;

  /// 묶음 50 #146: 하이랜드 수호자의 특별한 공격
  final SkyMove? sky;

  /// 묶음 50 #146: 그림에 살짝 입히는 색 (석상 병사는 섬 속성 색, ARGB)
  final int? tint;

  /// 묶음 34: 몬스터 속성 대신 쓰는 속성 (잿빛 군주는 감정 단계마다 바뀐다)
  final Element? forceElement;

  /// 묶음 34: 분신·본체 단계의 특별한 공격
  final AshMove? move;

  /// 묶음 34: 잿빛 군주 얼굴이 드러난 정도 (0 안개 ~ 1 얼굴)
  final double? reveal;

  /// 이 몬스터의 속성
  Element? get element => forceElement ?? info.element;

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
  String get name => label ?? (small
      ? '작은 ${info.name}'
      : ModifierRules.displayName(monster, mods));

  ModGrade get grade => ModifierRules.gradeOf(mods);

  bool has(ModifierId m) => mods.contains(m);
}

/// 묶음 52 #243: 3막 동료 한 명 (각성자 옆에서 자동으로 싸우고, 끼운 스킬 버튼 하나)
class BattleAlly {
  BattleAlly({
    required this.id,
    required this.name,
    required this.maxHp,
    required this.attack,
    this.skill,
    this.chargeTicks = Act3Rules.allyCharge,
    this.crit = 0,
    this.element,
    this.heal = 0,
    this.ash = 0,
    this.elementBonus,
  }) : hp = maxHp;

  final String id;
  final String name;
  final int maxHp;
  int hp;
  final int attack;

  /// 끼운 스킬 (없으면 버튼 없음)
  final AllySkillInfo? skill;
  final int chargeTicks;
  int charge = 0;

  /// 치명타 확률 · 공격 속성(마법사) · 회복 배율 더 · 잿빛에게 피해 더 · 잘 다루는 속성
  final double crit;
  final Element? element;
  final double heal;
  final double ash;
  final Element? elementBonus;

  /// 자기 공격 세짐 · 자기 받는 피해 줄어듦 · 대신 맞기 (남은 턴)
  int selfAtkTurns = 0;
  int guardTurns = 0;
  int tauntTurns = 0;

  /// 쓰러졌다가 일어났는지 (기적은 한 번)
  bool revived = false;

  /// 이번 틱에 준 피해 · 받은 피해 (화면 연출용)
  int lastDealt = 0;
  int lastTaken = 0;

  bool get down => hp <= 0;
  double get ratio => (charge / chargeTicks).clamp(0, 1).toDouble();
  bool get ready => !down && skill != null && charge >= chargeTicks;
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
    DateTime? day,
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
        monster: bossOf(day, atGate: atGate, rng: rng),
        maxHp: atk * RuleConstants.bossHitsToClear,
        attack: (floorAttack * RuleConstants.bossAttackMultiplier).round(),
      ),
    ];
  }

  /// 요일 보스 (11-11 #75). 강도는 모두 미궁 문지기와 같고 속성만 다르다.
  /// 월 문지기 · 화 불꽃 슬라임 왕 · 수 서리 늑대왕 · 목 숲의 고목 정령 ·
  /// 금 그림자 박쥐 여왕 · 토 천둥 그리폰 · 일 6종 중 무작위. 미궁 입구에서는 늘 문지기.
  static const List<MonsterId> weekBosses = [
    MonsterId.labyrinthWarden,
    MonsterId.fireSlimeKing,
    MonsterId.frostWolfKing,
    MonsterId.ancientTreant,
    MonsterId.shadowBatQueen,
    MonsterId.thunderGriffin,
  ];

  static MonsterId bossOf(DateTime? day,
      {required bool atGate, math.Random? rng}) {
    if (atGate || day == null) return MonsterId.labyrinthWarden;
    final w = day.weekday; // 1=월 … 7=일
    if (w == DateTime.sunday) {
      return weekBosses[(rng ?? math.Random()).nextInt(weekBosses.length)];
    }
    return weekBosses[w - 1];
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
    this.telegraphs = false,
    this.heroSkills = false,
    this.setAttack = const {},
    this.setAbilities = const {},
    this.ashDealt = 0,
    this.ashTaken = 0,
    this.guardFlash = 0,
    this.skyTaken = 0,
    this.allies = const [],
  })  : floors = List.unmodifiable(floors),
        potions = {for (final p in potions) p.key: p},
        _potionLeft = {for (final p in potions) p.key: p.count},
        skillDamage =
            skillDamage ?? playerAttack * RuleConstants.skillDamageMultiplier,
        baseSpeed = playerSpeed,
        playerSpeed = playerSpeed,
        _rng = rng ?? math.Random(),
        playerHp = math.min(playerMaxHp, math.max(0, startHp ?? playerMaxHp)),
        foeHp = floors.first.maxHp {
    _prepareStrong();
  }

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
    bool petResonant = false,
    double power = 1,
    List<BattlePotion> potions = const [],
    int autoHp = 0,
    bool autoCure = false,
    Map<Element, double> resist = const {},
    Element? skillElement,
    Element? mainElement,
    Element? weaponPotion,
    bool telegraphs = false,
    bool heroSkills = false,
    List<BattleAlly> allies = const [],
  }) {
    final all = stats + gear.stats;
    // 펫 스킬 (11-11 #38): 쪼기는 4틱에 찬다 (정령 물약·간식이 더 빠르면 그쪽)
    final petBase = petSkill == null ? null : PetRules.skillChargeTicks(petSkill);
    final petTicks =
        petBase == null ? null : math.max(1, petBase - gear.sets.petFaster);
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
      // 보스 장비 2개 세트 효과는 저항 물약과 더한다 (11-11 #82)
      resist: {
        ...resist,
        for (final e in gear.sets.resist.entries)
          e.key: math.min(0.6, (resist[e.key] ?? 0) + e.value),
      },
      setAttack: gear.sets.attack,
      setAbilities: gear.sets.abilities,
      ashDealt: gear.sets.ashDealt,
      ashTaken: gear.sets.ashTaken,
      guardFlash: gear.sets.guardFlash,
      skyTaken: gear.sets.skyTaken,
      attackElement: gear.attackElement,
      skillElement: skillElement,
      guardElements: gear.guardElements,
      mainElement: mainElement,
      attackLevel: gear.attackLevel,
      guardLevels: gear.guardLevels,
      weaponPotion: weaponPotion,
      telegraphs: telegraphs,
      heroSkills: heroSkills,
      allies: allies,
      floors: floors,
      rng: rng,
      skillChargeTicks: ticks,
      damageTaken: (1 - gear.reduce) * (1 - StatRules.vitalityReduce(all)),
      playerCrit: math.min(0.6, StatRules.crit(all) + gear.crit),
      playerEvade: math.min(0.4, StatRules.evade(all) + gear.evade),
      // 같은 레벨 기준 각성자보다 빠르면 1보다 크다 (몬스터 속도와 비교)
      playerSpeed: StatRules.speed(all) /
          StatRules.speed(BattleRules.expectedStats(level)) *
          (1 + gear.speed),
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

  // ───────────── 화면 연출용 (11-11 #81 1단계)

  /// 이번 차례 내 공격이 치명타였는지 / 약점(효과가 굉장했다)이었는지
  bool lastCrit = false;
  bool lastSuper = false;

  /// 이번 차례 회복한 HP (물약·고목 세트·흡혈). 화면에 초록 숫자로.
  int lastHealed = 0;

  /// 회복할 때마다 1씩 (화면이 초록 숫자를 새로 띄우는 신호)
  int heals = 0;

  void _healed(int n) {
    if (n <= 0) return;
    lastHealed += n;
    heals++;
  }

  /// 몬스터가 묶였는지·얼었는지 (상태 이상 표시)
  bool get foeBound => _foeBound;
  bool get foeFrozen => _foeFrozen;

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

  /// 자동 마시기: HP 이 % 아래면 회복 물약 (0이면 끔). 전투 중에도 바꿀 수 있다 (11-11 #93)
  int autoHp;

  /// 자동 마시기: 중독·화상·눈부심 풀기
  bool autoCure;

  /// 이번 틱에 자동으로 마신 물약 (전투 기록 한 줄, 11-11 #93)
  bool autoHealed = false;
  bool autoCured = false;

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

  // ───────────── 11-11 #75 막기 타이밍 · 내 스킬 · 보스 분노 (숫자는 숨김)

  /// 보스 장비 4개 세트 효과: 그 속성으로 공격할 때 피해 증가 (11-11 #82, 숨김)
  final Map<Element, double> setAttack;

  /// 보스 장비 6개 세트 효과: 고유 능력
  final Set<BossSetAbility> setAbilities;

  /// 6개 세트 능력이 발동한 횟수 (테스트·연출용)
  int setProcs = 0;

  void _setOnHit(int dealt) {
    if (setAbilities.isEmpty || phase != BattlePhase.fighting) return;
    for (final a in setAbilities) {
      if (phase != BattlePhase.fighting) return;
      switch (a) {
        case BossSetAbility.burn:
          if (_rng.nextDouble() < BossGearRules.burnChance) {
            foeBurnTurns = 3;
            setProcs++;
            lastEvent = '불태웠어요!';
          }
        case BossSetAbility.freeze:
          if (_rng.nextDouble() < BossGearRules.freezeChance) {
            _foeFrozen = true;
            foeFreezes++;
            setProcs++;
            lastEvent = '얼렸어요!';
          }
        case BossSetAbility.drain:
          final heal = math.max(1, (dealt * BossGearRules.drainRatio).round());
          if (playerHp < playerMaxHp) {
            final before = playerHp;
            playerHp = math.min(playerMaxHp, playerHp + heal);
            _healed(playerHp - before);
            setProcs++;
          }
        case BossSetAbility.chain:
          if (_rng.nextDouble() < BossGearRules.chainChance) {
            final extra = _elemental(_vary(playerAttack), weaponPotion ?? attackElement,
                level: weaponPotion != null ? 0 : attackLevel);
            lastDealt += extra;
            setProcs++;
            lastEvent = '연쇄 번개!';
            _hitFoe(extra);
          }
        case BossSetAbility.stoneSkin ||
              BossSetAbility.regrow ||
              BossSetAbility.ashBane ||
              BossSetAbility.skyKnight ||
              BossSetAbility.companion:
          break;
      }
    }
  }

  // ───────────── 2막 잿빛 군주 (묶음 34, 숨은 규칙. 화면에는 문장만)

  /// 잿빛 왕의 유품 세트: 잿빛 몬스터에게 주는 피해 증가 · 받는 피해 감소
  final double ashDealt;
  final double ashTaken;

  /// 묶음 53: 볼크의 금 간 투구 — 막을 때 적이 멈출 확률 (숨김)
  final double guardFlash;

  /// 묶음 50: 하이랜드 수호 기사 세트 4개 — 바람·번개·빛·얼음·물 공격에 받는 피해 감소
  final double skyTaken;

  // ───────────── 3막 동료 (묶음 52 #243, 숨은 규칙)

  final List<BattleAlly> allies;

  /// 아군 모두 공격 세짐 · 받는 피해 줄어듦 (남은 턴, 동료 스킬)
  int partyAtkTurns = 0;
  double partyAtkMult = 1;
  int partyDefTurns = 0;
  double partyDefMult = 1;

  /// 아군 모두 다음 공격 세짐 (배율, 1이면 없음)
  double partyNext = 1;

  /// 등불 들기: 빗나가지 않음 + 잿빛·어둠에게 피해 더 (남은 턴)
  int lampTurns = 0;
  double lampMult = 1;

  /// 되받아치기 (남은 턴)
  int counterTurns = 0;

  /// 이기면 전리품 하나 더 (훔치기)
  bool extraLoot = false;

  /// 이번 틱에 동료가 쓴 스킬 이름 (화면 띠)
  String? lastAllySkill;

  // ───────────── 하이랜드 수호자 (묶음 50 #146, 숨은 규칙)

  /// 회오리: 두 번씩 움직이는 남은 턴
  int whirlTurns = 0;

  /// 낙뢰: 떨어지기까지 남은 턴 (0이면 예고 없음)
  int boltIn = 0;

  /// 햇살 치유를 썼는지 (한 번만)
  bool sunHealed = false;

  /// 서리 갑옷 남은 턴 (받는 피해가 크게 줄어든다, 강타로 깬다)
  int frostTurns = 0;

  /// 이번 틱에 분신이 쓴 특별한 공격 문장 (없으면 null)
  String? lastMove;

  /// 눈물비 남은 턴 (내 공격이 가끔 빗나가고 몬스터가 회복)
  int tearTurns = 0;

  /// 겁주기: 스킬 버튼이 잠긴 남은 턴
  int skillLockTurns = 0;

  /// 고립: 펫 게이지가 멈춘 남은 턴
  int isolateTurns = 0;

  /// 빼앗기: 빼앗은 힘이 남은 턴 (몬스터 공격이 세다)
  int stolenTurns = 0;

  /// 분노 폭발 단계 (문장을 한 번씩만)
  int _rageStep = 0;

  /// 강한 공격을 예고하고 막기를 받는지 (화면이 있는 전투만. 원정 자동 전투는 false)
  final bool telegraphs;

  /// 내 스킬 2칸(강타·방어 태세)을 쓸 수 있는지
  final bool heroSkills;

  /// 다음 차례에 몬스터가 강한 공격을 한다 (화면은 예고 표시를 띄우고 막기를 받는다)
  bool get strongNext => _strongNext && phase == BattlePhase.fighting;
  bool _strongNext = false;
  double _strongNextMult = 1;

  /// 예고 문구 ('힘을 모은다!' 등)
  String? strongLabel;

  bool _strongNow = false;
  double _strongNowMult = 1;
  GuardResult? _guard;

  /// 마지막 막기 결과 (화면 연출용, 다음 틱에 지운다)
  GuardResult? lastGuard;

  /// 묶음 65: 강한 공격을 막지 못함 (화면 연출 fx_guardBreak, 다음 틱에 지운다)
  bool lastGuardBroken = false;

  /// 이번 전투에서 막은 횟수
  int guards = 0;

  /// 막기 (화면 아무 곳이나 탭). 예고 하나에 한 번만. 예고가 없으면 아무 일도 없다.
  bool guard({required bool perfect}) {
    if (!strongNext || _guard != null) return false;
    _guard = perfect ? GuardResult.perfect : GuardResult.block;
    return true;
  }

  /// 막기 판정 (실제 시간, 2배속이어도 같다): 예고 뒤 1.0초 안 = 막기, 그중 끝 0.3초 = 완벽한 막기
  static const Duration guardWindow = Duration(milliseconds: 1000);
  static const Duration perfectFrom = Duration(milliseconds: 700);

  /// [ease]: 묶음 45 #232 세라의 방패 문장 → 막기 판정이 넉넉해짐 (완벽한 막기 폭은 그대로 끝 0.3초)
  static GuardResult? judgeGuard(Duration sinceWarning, {double ease = 1}) {
    final window = guardWindow * ease;
    if (sinceWarning.isNegative || sinceWarning > window) return null;
    return sinceWarning >= window - (guardWindow - perfectFrom)
        ? GuardResult.perfect
        : GuardResult.block;
  }

  /// 막기 판정 배수 (세라의 방패 문장)
  double guardEase = 1;

  static const double strongPowerUp = 1.5; // 4턴마다 힘을 모은다
  static const double bossBigHit = 2.0; // 보스 3턴마다 큰 공격
  static const double blockTaken = 0.4; // 막기: 받는 피해 -60%
  static const double bossRageAttack = 1.3;
  static const double bossRageSpeed = 1.2;

  /// 다음 몬스터 차례가 강한 공격인지 정한다
  void _prepareStrong() {
    _strongNext = false;
    _strongNextMult = 1;
    strongLabel = null;
    if (!telegraphs || phase != BattlePhase.fighting) return;
    final f = foe;
    final next = floorTicks + 1;
    if (f.isBoss && next % 3 == 0) {
      _strongNext = true;
      _strongNextMult = bossBigHit;
      strongLabel = '큰 공격이 온다!';
    } else if (f.has(ModifierId.charging) && !_charged && next == 1) {
      _strongNext = true; // 돌진은 원래 ×2
      strongLabel = '돌진해 온다!';
    } else if (f.has(ModifierId.ancient) && next % 4 == 0) {
      _strongNext = true; // 강타는 원래 ×2.5
      strongLabel = '강타가 온다!';
    } else if (next % 4 == 0) {
      _strongNext = true;
      _strongNextMult = strongPowerUp;
      strongLabel = '힘을 모은다!';
    }
  }

  /// 보스 분노 (체력 절반 아래)
  bool enraged = false;

  /// 강타: 6턴마다, 보통 공격 ×2.5
  static const int bashTicks = 6;
  static const double bashMultiplier = 2.5;

  /// 방어 태세: 8턴마다, 3턴 동안 받는 피해 -40%
  static const int stanceTicks = 8;
  static const int stanceLength = 3;
  static const double stanceTaken = 0.6;

  /// 묶음 43 #228 훈련장 연습: 허수아비는 쓰러지지 않고 때리지 않는다. 준 피해를 모은다
  bool practice = false;
  int practiceDealt = 0;

  /// 묶음 75 #324: 연습 기록 — 가장 센 한 방 · 친 횟수 · 각성자 공격 수 · 치명타 수
  int practiceMax = 0;
  int practiceHits = 0;
  int practiceStrikes = 0;
  int practiceCrits = 0;

  /// 묶음 75 #324: 이번 틱 공격이 잘 안 들었는지 (속성 상성, 효과 좋음은 [lastSuper])
  bool lastResist = false;

  /// 쓴 횟수 (훈련장 부탁: 강타 · 방어 태세 · 스킬)
  int bashes = 0;
  int stances = 0;
  int skillsUsed = 0;

  int bashCharge = 0;
  int stanceCharge = 0;

  /// 묶음 75 #325: 스킬 숙련도 — 강타 · 방어 태세 · 숙련 스킬이 다 차는 턴 (장인이면 −10%)
  int bashNeed = bashTicks;
  int stanceNeed = stanceTicks;
  final Map<Mastery, int> masteryNeed = {};
  int masteryNeedOf(Mastery m) => masteryNeed[m] ?? JobRules.masteryActiveTicks;

  /// 묶음 75 #325: 숙련 스킬 힘 (장인이면 +10%, 강타 · 방어 태세는 대기만)
  final Map<Mastery, double> masteryPower = {};
  double _skillPower = 1;

  /// 묶음 75 #325: 이번 판에 쓴 스킬 (스킬 숙련도 열쇠 이름 → 횟수, 펫 스킬 빼기)
  final Map<String, int> skillUses = {};
  bool skillsCounted = false;
  void _used(String id) => skillUses[id] = (skillUses[id] ?? 0) + 1;
  int stanceTurns = 0;

  bool get bashReady =>
      heroSkills &&
      phase == BattlePhase.fighting &&
      bashCharge >= bashNeed &&
      !skillsLocked;
  bool get stanceReady =>
      heroSkills &&
      phase == BattlePhase.fighting &&
      stanceCharge >= stanceNeed &&
      !skillsLocked;

  /// 방금 강타를 썼는지 (연출용)
  bool lastBash = false;

  // ───────────── 직업 (묶음 30 #55, 숨은 규칙)

  /// 전사: HP가 절반 아래면 주는 피해 더
  double lowHpBoost = 0;

  /// 잿빛 사냥꾼: 잿빛 몬스터에게 피해 더
  double ashBoost = 0;

  /// 치유사: 회복 물약 회복량 더
  double healBoost = 0;

  /// 다음 보통 공격 피해 배율 (1이면 없음)
  double nextHitMult = 1;

  // ───────────── 묶음 57 #249 직업 개편 (숨은 규칙)

  /// 묶음 57 #244: 싸움을 시작할 때 뿜는 불 (공격력 배율, 0이면 없음)
  double openingFire = 0;

  /// 회피 더 (도적) · 받는 피해 배율 (기사 · 각인)
  double extraEvade = 0;
  double takenMult = 1;

  /// 전사 고유 기술: 강타가 더 세고 더 빨리 참
  double bashBoost = 0;
  bool bashFast = false;

  /// 주는 피해 배율 (잘 맞는 무기 · 각인 · 짝)
  double dealMult = 1;

  /// 공격할 때 HP가 조금씩 참 (사제 각인)
  double lifeSteal = 0;

  /// 가끔 두 번 침 (도적 각인)
  double doubleHit = 0;

  /// 가끔 덩굴로 묶음 (채집가 각인)
  double bindChance = 0;

  /// 약점 피해 더 (감정사 각인)
  double weakBoost = 0;

  /// 가끔 강한 공격을 막음 (고고학자 각인)
  double relicBlock = 0;

  /// 공격 스킬에 독 · 화상 (연금술사 각인)
  bool skillDot = false;

  /// 펫이 내 공격에 맞춰 같이 침 (조련사 각인)
  double petAssist = 0;

  /// 첫 차례 선공 · 치명타 더 (궁수 각인)
  bool firstStrike = false;

  /// 이기면 금화 더 (상인 각인 · 저울추 던지기)
  bool goldBonus = false;

  /// 가호: 받는 피해 줄이는 남은 턴
  int wardTurns = 0;
  static const double wardTaken = 0.7;

  /// 도발 · 성기사의 맹세: 맞을 때마다 되받아치는 남은 턴
  int tauntTurns = 0;

  /// 성기사 짝: 대신 맞을 때 HP 조금, 잿빛 몬스터에게 빛 피해
  bool paladin = false;

  /// 밤의 도둑 짝: 밤엔 훔치기가 꼭 되고 한 번 더 벰
  bool nightThief = false;

  /// 묶음 77 #346: 마검사 (강타에 속성 · 약점이면 더) · 현자 (약점 늘 보임 · 약점 피해 +15%)
  bool spellblade = false;
  static const double spellbladeWeak = 0.2;
  bool sage = false;
  static const double sageWeak = 0.15;

  /// 다음 보통 공격이 꼭 치명타
  bool nextCrit = false;

  // ───────────── 묶음 58: 3막 이름 있는 장비 (숨김)

  /// 매 턴 이 확률로 최대 HP의 [regenRatio] 만큼 참 (모모의 꽃 화관)
  double regenChance = 0;
  double regenRatio = 0;

  /// 묶인 적에게 주는 피해 더 (아르벨의 잎새 단검)
  double boundBoost = 0;

  /// 매 턴 이 확률로 동료 HP가 조금 참 (루시의 빛꽃)
  double allyRegenChance = 0;

  /// 회복 물약을 쓰면 동료도 이만큼 참 (왕의 나눔 망토, 동료 최대 HP 비율)
  double potionShare = 0;

  /// 묶음 59 「등불 수호단」 6개: 때리면 가끔 등불 빛이 터져 잿빛 몬스터에게 큰 피해
  double lanternBurst = 0;
  double lanternBurstMult = 2.0;

  /// 묶음 59 길드 레이드: 특별 공격 (보스 이름) · 약점 직업 피해 · 특별 공격 덜 받음
  String? raidBoss;

  /// 묶음 60: 몬스터 체력 숫자를 숨김 (공성전 · 야생 수비대 세기는 숨은 값)
  bool hideFoeNumbers = false;
  int raidSpecialEvery = 4;
  double raidTakenMult = 1;
  int raidShieldTurns = 0;
  int raidShellTurns = 0;
  static const double regenRatioAlly = 0.05;

  // ───────────── 스킬 두 갈래 (묶음 31 #195~#198, 숨은 규칙)

  /// 입은 무기 강화 단계 (명검 베기)
  int weaponEnhance = 0;

  /// 보조 직업 수 (장인의 연타)
  int artisanSubs = 0;

  /// 밤인지 (그림자 베기)
  bool nightTime = false;

  /// 방어가 깨진 남은 턴 (몬스터가 받는 피해 더)
  int foeBreakTurns = 0;
  static const double breakTaken = 1.3;

  /// 몬스터가 묶인 남은 몬스터 차례
  int foeBindTurns = 0;

  /// 몬스터에게 남은 계속 피해 (턴 · 최대 체력 비율)
  int foeDotTurns = 0;
  double foeDotRatio = 0;

  /// 철벽: 받는 피해 줄이는 남은 턴
  int wallTurns = 0;
  static const double wallTaken = 0.5;

  /// 전투 함성: 공격이 세지는 남은 턴 (강타도 빨리 참)
  int rallyTurns = 0;
  static const double rallyAttack = 1.3;

  /// 축복의 일격: HP가 조금씩 차는 남은 턴
  int regenTurns = 0;

  /// 다음 몬스터 공격을 피함
  bool dodgeNext = false;

  /// 다음 강한 공격을 막음
  bool blockNext = false;

  /// 다음에 받는 공격 일부를 돌려줌
  bool reflectNext = false;

  /// 전투 칸에 낀 숙련 스킬 (MP 없이 몇 턴마다)
  final Set<Mastery> masteryActives = {};
  final Map<Mastery, int> masteryCharge = {};

  // ───────────── 묶음 57 #236: 파티 보스 특기 (막기 예고와 함께, 보스마다 하나)

  /// 골렘 돌벽: 받는 피해가 줄어드는 남은 턴
  int stoneWallTurns = 0;
  int _specialTick = -1;

  /// 특기를 쓰는 간격 (턴)
  static const int partySpecialEvery = 5;

  /// 다음 막기에서 되받아칠지 (수호)
  bool _guardCounter = false;

  /// 쓰러져도 한 번 버팀 (기적)
  bool _miracleUsed = false;

  // ───────────── 호문쿨루스 원정 (묶음 32 #190, 숨은 규칙)

  /// 상성 약점 없음 (약함 배율 대신 1)
  bool noWeakness = false;

  /// 속성 몬스터에게 받는 피해 줄이기
  double elementGuard = 0;

  /// 보통 공격에 직업 효과를 붙인다
  int _jobHit(int dmg) {
    var d = dmg.toDouble();
    if (lowHpBoost > 0 && playerHp * 2 < playerMaxHp) d *= 1 + lowHpBoost;
    if (ashBoost > 0 && foeIsAsh) d *= 1 + ashBoost;
    if (foeBreakTurns > 0) d *= breakTaken;
    if (rallyTurns > 0) d *= rallyAttack;
    if (nextHitMult > 1) {
      d *= nextHitMult;
      nextHitMult = 1;
    }
    d *= dealMult;
    if (weakBoost > 0 && _foeWeakTo != null && _foeWeakTo == attackElement) d *= 1 + weakBoost;
    return math.max(1, d.round());
  }

  /// 방어 태세
  bool useStance() {
    if (!stanceReady) return false;
    stanceCharge = 0;
    stanceTurns = stanceLength;
    stances++;
    _used('stance');
    lastEvent = '방어 태세!';
    lastDealt = 0;
    lastTaken = 0;
    return true;
  }

  void _checkRage() {
    if (!foe.isBoss || enraged || phase != BattlePhase.fighting) return;
    if (foeHp * 2 < foe.maxHp) {
      enraged = true;
      lastEvent = '분노했다!';
    }
  }

  /// 빙결 (11-11 #74 얼음 슬라임): 다음 내 차례를 쉰다
  bool frozen = false;

  /// 묶음 69 #281: 바실리스크 — 돌로 굳음 (빙결처럼 한 차례 쉼, 문구만 다름)
  bool petrified = false;

  /// 도플갱어가 이미 내 공격을 따라 했는지
  bool _mirrored = false;

  /// 보름달 밤 (웨어울프가 더 셈)
  bool fullMoon = false;

  /// 녹이는 물약을 마신 뒤 다시 얼지 않는 턴
  int freezeImmune = 0;

  /// 얼음 공격 물약으로 몬스터가 얼었는지 (다음 몬스터 차례를 쉰다)
  bool _foeFrozen = false;

  /// 이번 전투에서 몬스터를 얼린 횟수
  int foeFreezes = 0;

  /// 지금 걸린 것이 화상인지 (아니면 중독)
  bool burning = false;

  /// 이번 중독이 약한 중독인지 (큰쥐, 11-11 A4)
  bool weakPoisoned = false;

  /// 이번 전투에서 처음 중독됐는지 (해독제 안내용)
  bool poisonedThisBattle = false;

  /// 해독제·연고를 마신 뒤 다시 안 걸리는 턴
  int immuneTurns = 0;

  /// 맑은 눈 물약: 이번 전투 동안 눈부심에 빗나가지 않는다
  bool clearEye = false;

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

  int playerHp;
  int foeHp;
  int floor = 0;
  int skillCharge = 0;
  int ticks = 0;
  BattlePhase phase = BattlePhase.fighting;

  /// 묶음 56: 이 턴이 지나면 끝 (파티 보스) · 그렇게 끝났는지
  int? tickLimit;
  bool timeUp = false;

  /// 마지막으로 준 피해와 받은 피해 (화면 연출용)
  int lastDealt = 0;
  int lastTaken = 0;
  bool lastWasSkill = false;

  /// 이번 층에서 지난 턴 수
  int floorTicks = 0;

  /// 남은 중독 턴
  int poisonTurns = 0;

  double playerSpeed;

  /// 마지막 턴에 일어난 일 ('피했다!' 등, 화면 연출용). 없으면 null.
  String? lastEvent;

  /// 묶음 49 #235: 엠버(잿불새)와 함께한 던전 — 쓰러지면 한 번 되살아남
  int revives = 0;

  /// 되살아난 횟수 (결과·시험용)
  int revived = 0;

  /// 돌진하는: 이번 층에서 이미 돌진했는지
  bool _charged = false;

  /// 얼음 슬라임이 얼릴 확률
  static const double freezeChance = 0.20;

  /// 묶음 69 #281 (숨김): 바실리스크 돌 굳히기 · 도플갱어 따라 하기 · 웨어울프 보름달
  static const double petrifyChance = 0.15;
  static const double mirrorShare = 0.8;
  static const double fullMoonAttack = 1.3;

  /// 큰쥐가 약하게 중독시킬 확률 (11-11 A4, 숨김)
  static const double weakPoisonChance = 0.10;

  static const superEffective = '효과가 굉장했다!';
  static const notEffective = '효과가 별로인 것 같다…';

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

/// 막기 결과 (11-11 #75)
enum GuardResult { block, perfect }

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
