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
  });

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
  String get name => small
      ? '작은 ${info.name}'
      : ModifierRules.displayName(monster, mods);

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

  List<BattleAlly> get alliesUp => [for (final a in allies) if (!a.down) a];

  double get _allyFoeMult {
    var m = partyAtkTurns > 0 ? partyAtkMult : 1.0;
    if (lampTurns > 0 && (foeIsAsh || foe.element == Element.dark)) m *= lampMult;
    return m;
  }

  /// 동료 한 명의 보통 공격
  void _allyHit(BattleAlly a, double mult, {bool crit = false, Element? element}) {
    if (phase != BattlePhase.fighting || a.down) return;
    var d = _vary(a.attack) * mult * _allyFoeMult;
    if (a.selfAtkTurns > 0) d *= 1.5;
    if (a.ash > 0 && foeIsAsh) d *= 1 + a.ash;
    final el = element ?? a.element;
    if (el != null && a.elementBonus == el) d *= 1.15;
    if (crit || (a.crit > 0 && _rng.nextDouble() < a.crit)) d *= StatRules.critMultiplier;
    var dmg = math.max(1, d.round());
    if (foe.defense != 1) dmg = math.max(1, (dmg / foe.defense).round());
    if (foeBreakTurns > 0) dmg = (dmg * breakTaken).round();
    if (el != null) dmg = _elemental(dmg, el, level: 0);
    a.lastDealt += dmg;
    _hitFoe(dmg);
    _checkRage();
  }

  /// 동료들이 차례로 친다 (각성자 차례 뒤)
  void _alliesTurn() {
    for (final a in allies) {
      a.lastDealt = 0;
      a.lastTaken = 0;
      if (a.down || phase != BattlePhase.fighting) continue;
      final next = partyNext;
      _allyHit(a, next);
      if (a.charge < a.chargeTicks) a.charge++;
    }
    partyNext = 1;
  }

  /// 동료 스킬 (게이지가 차면 누름). 쓸 수 없으면 false
  bool useAllySkill(int i) {
    if (i < 0 || i >= allies.length || phase != BattlePhase.fighting) return false;
    final a = allies[i];
    final s = a.skill;
    if (!a.ready || s == null) return false;
    a.charge = 0;
    lastAllySkill = '${a.name} · ${s.name}!';
    lastEvent = lastAllySkill;
    switch (s.kind) {
      case AllySkillKind.hit:
        _allyHit(a, s.power);
      case AllySkillKind.hits:
        for (var k = 0; k < s.hits; k++) {
          _allyHit(a, s.power);
        }
      case AllySkillKind.crit:
        _allyHit(a, s.power, crit: true);
      case AllySkillKind.stun:
        _allyHit(a, s.power);
        _foeBound = true;
      case AllySkillKind.partyAtk:
        partyAtkTurns = s.turns;
        partyAtkMult = s.power;
        rallyTurns = math.max(rallyTurns, s.turns);
      case AllySkillKind.partyDef:
        partyDefTurns = s.turns;
        partyDefMult = s.power;
      case AllySkillKind.partyNext:
        partyNext = s.power;
        nextHitMult = math.max(nextHitMult, s.power);
      case AllySkillKind.lamp:
        lampTurns = s.turns;
        lampMult = s.power;
      case AllySkillKind.partyCount:
        final n = 1 + alliesUp.length;
        for (var k = 0; k < n; k++) {
          _allyHit(a, s.power);
        }
      case AllySkillKind.rally:
        partyAtkTurns = s.turns;
        partyAtkMult = s.power;
        partyDefTurns = s.turns;
        partyDefMult = 0.7;
        rallyTurns = math.max(rallyTurns, s.turns);
        if (heroSkills) bashCharge = bashTicks;
      case AllySkillKind.selfAtk:
        a.selfAtkTurns = s.turns;
      case AllySkillKind.lowHp:
        _allyHit(a, s.power * (1 + (1 - a.hp / a.maxHp) * 1.5));
      case AllySkillKind.fullHp:
        _allyHit(a, foeHp >= foe.maxHp ? s.power : s.power * 0.4);
      case AllySkillKind.element:
        _allyHit(a, s.power, element: a.element ?? a.elementBonus);
      case AllySkillKind.weak:
        final el = a.element ?? a.elementBonus;
        final e = foe.element;
        final weak = el != null && e != null && ElementRules.beats(el).contains(e);
        _allyHit(a, weak ? s.power : s.power * 0.45, element: el);
      case AllySkillKind.barrier:
        dodgeNext = true;
      case AllySkillKind.healOne:
        _healOne(s.power * (1 + a.heal));
      case AllySkillKind.healAll:
        _healAll(s.power * (1 + a.heal));
      case AllySkillKind.regen:
        regenTurns = math.max(regenTurns, s.turns);
      case AllySkillKind.cleanse:
        poisonTurns = 0;
        frozen = false;
        _healAll(0.05 * (1 + a.heal));
      case AllySkillKind.miracle:
        for (final x in allies) {
          if (x.down && !x.revived) {
            x.revived = true;
            x.hp = math.max(1, (x.maxHp * 0.3).round());
            break;
          }
        }
        _healAll(s.power * (1 + a.heal));
      case AllySkillKind.steal:
        _allyHit(a, s.power);
        extraLoot = true;
      case AllySkillKind.poison:
        _allyHit(a, 0.6);
        foeDotTurns = s.turns;
        foeDotRatio = s.power;
      case AllySkillKind.breakDef:
        _allyHit(a, s.power);
        foeBreakTurns = math.max(foeBreakTurns, 2);
      case AllySkillKind.taunt:
        a.tauntTurns = s.turns;
      case AllySkillKind.guardSelf:
        a.guardTurns = s.turns;
      case AllySkillKind.oath:
        shieldHits += 2;
        counterTurns = s.turns;
    }
    return true;
  }

  void _healOne(double ratio) {
    // 가장 많이 다친 쪽 (각성자 포함)
    BattleAlly? low;
    var lowRatio = playerHp / playerMaxHp;
    for (final x in alliesUp) {
      final r = x.hp / x.maxHp;
      if (r < lowRatio) {
        low = x;
        lowRatio = r;
      }
    }
    if (low == null) {
      final before = playerHp;
      playerHp = math.min(playerMaxHp, playerHp + (playerMaxHp * ratio).round());
      _healed(playerHp - before);
    } else {
      low.hp = math.min(low.maxHp, low.hp + (low.maxHp * ratio).round());
    }
  }

  void _healAll(double ratio) {
    final before = playerHp;
    playerHp = math.min(playerMaxHp, playerHp + (playerMaxHp * ratio).round());
    _healed(playerHp - before);
    for (final x in alliesUp) {
      x.hp = math.min(x.maxHp, x.hp + (x.maxHp * ratio).round());
    }
  }

  /// 몬스터 공격이 동료에게 갔으면 그 동료 (각성자면 null). 대신 맞는 동료가 먼저
  BattleAlly? _foeTarget() {
    final up = alliesUp;
    if (up.isEmpty) return null;
    for (final a in up) {
      if (a.tauntTurns > 0) return a;
    }
    if (_rng.nextDouble() >= Act3Rules.foeTargetsAlly) return null;
    return up[_rng.nextInt(up.length)];
  }

  /// 동료가 맞는다
  void _allyTaken(BattleAlly a, double atk) {
    var x = atk;
    if (partyDefTurns > 0) x *= partyDefMult;
    if (a.guardTurns > 0) x *= 0.4;
    final taken = _vary(math.max(1, x.round()));
    a.hp = math.max(0, a.hp - taken);
    a.lastTaken += taken;
    if (counterTurns > 0) _allyHit(a, 0.5);
  }

  /// 틱 끝: 동료 쪽 남은 턴
  void _alliesTickEnd() {
    if (partyAtkTurns > 0) partyAtkTurns--;
    if (partyDefTurns > 0) partyDefTurns--;
    if (lampTurns > 0) lampTurns--;
    if (counterTurns > 0) counterTurns--;
    for (final a in allies) {
      if (a.selfAtkTurns > 0) a.selfAtkTurns--;
      if (a.guardTurns > 0) a.guardTurns--;
      if (a.tauntTurns > 0) a.tauntTurns--;
      if (regenTurns > 0 && !a.down) {
        a.hp = math.min(a.maxHp, a.hp + math.max(1, (a.maxHp * 0.04).round()));
      }
    }
  }

  // ───────────── 하이랜드 수호자 (묶음 50 #146, 숨은 규칙)

  /// 회오리: 두 번씩 움직이는 남은 턴
  int whirlTurns = 0;

  /// 낙뢰: 떨어지기까지 남은 턴 (0이면 예고 없음)
  int boltIn = 0;

  /// 햇살 치유를 썼는지 (한 번만)
  bool sunHealed = false;

  /// 서리 갑옷 남은 턴 (받는 피해가 크게 줄어든다, 강타로 깬다)
  int frostTurns = 0;

  /// 낙뢰가 다가오는지 (화면 표시)
  bool get boltComing => boltIn > 0 && phase == BattlePhase.fighting;

  /// 서리 갑옷을 둘렀는지 (화면 표시)
  bool get frosted => frostTurns > 0 && phase == BattlePhase.fighting;

  void _clearSkyMoves() {
    whirlTurns = 0;
    boltIn = 0;
    sunHealed = false;
    frostTurns = 0;
  }

  /// 틱 처음: 하이랜드 수호자의 특별한 공격
  void _skyMove() {
    final m = foe.sky;
    if (m == null) return;
    final t = floorTicks;
    final line = HighlandRules.ofMove(m)?.moveLine;
    switch (m) {
      case SkyMove.whirl:
        if (whirlTurns <= 0 && t % HighlandRules.whirlEvery == 2) {
          whirlTurns = HighlandRules.whirlLength;
          lastMove = line;
        }
      case SkyMove.bolt:
        if (boltIn > 0) {
          boltIn--;
          if (boltIn == 0) _boltStrike();
        } else if (t % HighlandRules.boltEvery == 4) {
          boltIn = HighlandRules.boltDelay;
          lastMove = line;
        }
      case SkyMove.sunHeal:
        if (!sunHealed && foeHp < foe.maxHp * HighlandRules.sunHealBelow) {
          sunHealed = true;
          foeHp = math.min(foe.maxHp,
              foeHp + math.max(1, (foe.maxHp * HighlandRules.sunHeal).round()));
          lastMove = line;
        }
      case SkyMove.frostArmor:
        if (frostTurns <= 0 && t % HighlandRules.frostEvery == 1) {
          frostTurns = HighlandRules.frostLength;
          lastMove = line;
        }
      case SkyMove.wash:
        if (t % HighlandRules.washEvery == 3) {
          var any = false;
          while (_stealBuff()) {
            any = true;
          }
          if (any) lastMove = line;
        }
    }
  }

  /// 낙뢰가 떨어진다: 방어 태세면 거의 막는다
  void _boltStrike() {
    if (practice) return;
    var atk = foe.attack * HighlandRules.boltPower;
    final blocked = stanceTurns > 0;
    if (blocked) atk *= HighlandRules.boltBlocked;
    if (damageTaken != 1) atk *= damageTaken;
    if (skyTaken > 0) atk *= 1 - skyTaken;
    final taken = _vary(math.max(1, atk.round()));
    lastTaken += taken;
    playerHp = math.max(0, playerHp - taken);
    lastMove = blocked ? '방어 태세로 낙뢰를 막아 냈어요!' : '낙뢰가 떨어졌어요!';
    if (playerHp == 0 && !_revive()) phase = BattlePhase.failed;
  }

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

  /// 지금 스킬 버튼이 잠겼는지 (겁주기)
  bool get skillsLocked => skillLockTurns > 0 && phase == BattlePhase.fighting;

  /// 지금 펫이 고립됐는지
  bool get isolated => isolateTurns > 0 && phase == BattlePhase.fighting;

  void _clearAshMoves() {
    tearTurns = 0;
    skillLockTurns = 0;
    isolateTurns = 0;
    stolenTurns = 0;
    _rageStep = 0;
  }

  /// 틱 처음: 분신·본체 단계의 특별한 공격
  void _ashMove() {
    final m = foe.move;
    if (m == null) return;
    final t = floorTicks;
    final line = Act2Rules.ofMove(m)?.moveLine;
    switch (m) {
      case AshMove.rage:
        final step = ((1 - foeHp / foe.maxHp) * 3).floor().clamp(0, 2);
        if (step > _rageStep) {
          _rageStep = step;
          lastMove = line;
        }
      case AshMove.tears:
        if (tearTurns <= 0 && t % Act2Rules.tearsEvery == 3) {
          tearTurns = Act2Rules.tearsLength;
          lastMove = line;
        }
      case AshMove.steal:
        if (t % Act2Rules.stealEvery == 0 && _stealBuff()) {
          stolenTurns = Act2Rules.stolenLength;
          lastMove = line;
        }
      case AshMove.fear:
        if (heroSkills && t % Act2Rules.fearEvery == 2) {
          skillLockTurns = 1;
          lastMove = line;
        }
      case AshMove.isolate:
        if (isolateTurns <= 0 && t % Act2Rules.isolateEvery == 3) {
          isolateTurns = Act2Rules.isolateLength;
          lastMove = line;
        }
    }
  }

  /// 나에게 걸린 좋은 효과 하나를 없앤다 (있었으면 true)
  bool _stealBuff() {
    if (rallyTurns > 0) {
      rallyTurns = 0;
    } else if (wallTurns > 0) {
      wallTurns = 0;
    } else if (stanceTurns > 0) {
      stanceTurns = 0;
    } else if (regenTurns > 0) {
      regenTurns = 0;
    } else if (insightTurns > 0) {
      insightTurns = 0;
    } else if (shieldHits > 0) {
      shieldHits = 0;
    } else if (dodgeNext) {
      dodgeNext = false;
    } else if (blockNext) {
      blockNext = false;
    } else if (reflectNext) {
      reflectNext = false;
    } else {
      return false;
    }
    return true;
  }

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

  /// 쓴 횟수 (훈련장 부탁: 강타 · 방어 태세 · 스킬)
  int bashes = 0;
  int stances = 0;
  int skillsUsed = 0;

  int bashCharge = 0;
  int stanceCharge = 0;
  int stanceTurns = 0;

  bool get bashReady =>
      heroSkills &&
      phase == BattlePhase.fighting &&
      bashCharge >= bashTicks &&
      !skillsLocked;
  bool get stanceReady =>
      heroSkills &&
      phase == BattlePhase.fighting &&
      stanceCharge >= stanceTicks &&
      !skillsLocked;
  double get bashRatio => (bashCharge / bashTicks).clamp(0, 1).toDouble();
  double get stanceRatio => (stanceCharge / stanceTicks).clamp(0, 1).toDouble();

  /// 강타
  bool useBash() {
    if (!bashReady) return false;
    bashCharge = 0;
    lastWasSkill = false;
    lastEvent = '강타!';
    // 묶음 50: 강타로 서리 갑옷을 깬다
    if (frostTurns > 0) {
      frostTurns = 0;
      lastEvent = '강타! 서리 갑옷이 깨졌어요!';
    }
    var dmg = (_vary(playerAttack) * bashMultiplier).round();
    if (foe.defense != 1) dmg = math.max(1, (dmg / foe.defense).round());
    dmg = _elemental(dmg, weaponPotion ?? attackElement,
        level: weaponPotion != null ? 0 : attackLevel);
    lastDealt = dmg;
    lastTaken = 0;
    lastBash = true;
    bashes++;
    _hitFoe(dmg);
    _checkRage();
    return true;
  }

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

  /// 다음 보통 공격이 꼭 치명타
  bool nextCrit = false;

  /// 지금 몬스터가 잿빛 몬스터인지
  bool get foeIsAsh =>
      phase == BattlePhase.fighting && foe.monster.name.startsWith('ash');

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

  bool masteryReady(Mastery m) =>
      heroSkills &&
      phase == BattlePhase.fighting &&
      masteryActives.contains(m) &&
      (masteryCharge[m] ?? 0) >= JobRules.masteryActiveTicks &&
      !skillsLocked;

  double masteryRatio(Mastery m) =>
      ((masteryCharge[m] ?? 0) / JobRules.masteryActiveTicks)
          .clamp(0, 1)
          .toDouble();

  /// 몬스터가 약한 속성 하나 (없으면 null)
  Element? get _foeWeakTo {
    final e = foe.element;
    if (e == null) return null;
    final b = ElementRules.beats(e);
    return b.isEmpty ? null : b.first;
  }

  /// 스킬 한 번 치기
  int _strike(double mult,
      {Element? element, bool useElement = true, bool crit = false}) {
    var d = _vary(playerAttack) * mult;
    if (foeBreakTurns > 0) d *= breakTaken;
    if (rallyTurns > 0) d *= rallyAttack;
    if (ashBoost > 0 && foeIsAsh) d *= 1 + ashBoost;
    var dmg = math.max(1, d.round());
    if (crit) {
      dmg = (dmg * StatRules.critMultiplier).round();
      lastCrit = true;
    }
    if (foe.defense != 1) dmg = math.max(1, (dmg / foe.defense).round());
    if (useElement) {
      final el = element ?? weaponPotion ?? attackElement;
      dmg = _elemental(dmg, el,
          level: element == null && weaponPotion == null ? attackLevel : 0);
    }
    lastDealt += dmg;
    _hitFoe(dmg);
    _setOnHit(dmg);
    _checkRage();
    return dmg;
  }

  void _startSkill(String event) {
    lastWasSkill = false;
    lastBash = true;
    lastDealt = 0;
    lastTaken = 0;
    lastCrit = false;
    lastSuper = false;
    lastHealed = 0;
    lastEvent = event;
  }

  void _maybeStun(double chance) {
    if (phase == BattlePhase.fighting && _rng.nextDouble() < chance) {
      _foeBound = true;
      lastEvent = '${lastEvent ?? ''} 멈칫!'.trim();
    }
  }

  /// 직업 스킬을 쓴다 (MP는 앱이 따로 쓴다). [power] 는 스킬 단계 세기. 쓸 수 없으면 false
  bool useJobSkill(JobSkill s, {double power = 1}) {
    final ok = _useJobSkill(s, power: power);
    if (ok) skillsUsed++;
    return ok;
  }

  bool _useJobSkill(JobSkill s, {double power = 1}) {
    if (phase != BattlePhase.fighting || skillsLocked) return false;
    final p = power;
    switch (s) {
      case JobSkill.ironWall:
        if (wallTurns > 0) return false;
        _startSkill('철벽!');
        wallTurns = 3;
        return true;
      case JobSkill.warCry:
        if (rallyTurns > 0) return false;
        _startSkill('전투 함성!');
        rallyTurns = 3;
        return true;
      default:
        break;
    }
    switch (s) {
      case JobSkill.hotHammer:
        _startSkill('달군 망치!');
        _strike(2.0 * p);
        foeBreakTurns = 3;
      case JobSkill.thornVine:
        _startSkill('가시덩굴!');
        _strike(1.2 * p);
        foeBindTurns = 2;
        foeDotTurns = 2;
        foeDotRatio = 0.03;
      case JobSkill.potionThrow:
        _startSkill('물약 투척!');
        final w = _foeWeakTo;
        _strike((w == null ? 1.5 : 2.0) * p, element: w);
      case JobSkill.rush:
        _startSkill('돌진!');
        _strike(2.2 * p);
      case JobSkill.galeSlash:
        _startSkill('질풍 베기!');
        _strike(1.4 * p);
        dodgeNext = true;
      case JobSkill.weakStab:
        _startSkill('약점 찌르기!');
        final w = _foeWeakTo;
        _strike((w == null ? 1.4 : 1.8) * p, element: w);
      case JobSkill.chargeOrder:
        _startSkill('돌격 명령!');
        _strike(1.0 * p * skillDamage / math.max(1, playerAttack),
            element: skillElement, useElement: skillElement != null);
        skillCharge = math.min(skillChargeTicks, skillCharge + 2);
      case JobSkill.coinToss:
        _startSkill('금화 던지기!');
        _strike(2.0 * p);
      case JobSkill.masterSlash:
        _startSkill('명검 베기!');
        _strike((1.6 + 0.1 * weaponEnhance) * p);
      case JobSkill.runeBurst:
        _startSkill('룬 폭발!');
        _strike(2.2 * p, element: attackElement, useElement: true);
      case JobSkill.gemShard:
        _startSkill('보석 파편!');
        _strike(1.4 * p);
        _maybeStun(0.30);
      case JobSkill.healingLight:
        _startSkill('치유의 빛!');
        final d = _strike(1.2 * p, element: Element.light);
        final before = playerHp;
        playerHp = math.min(playerMaxHp, playerHp + d);
        _healed(playerHp - before);
      case JobSkill.vitalStrike:
        _startSkill('급소 사격!');
        _strike(1.0 * p, crit: true);
      case JobSkill.relicLight:
        _startSkill('고대 유물의 빛!');
        _strike(1.2 * p, element: Element.light);
        blockNext = true;
      case JobSkill.blessedStrike:
        _startSkill('축복의 일격!');
        _strike(1.2 * p);
        regenTurns = 3;
      case JobSkill.bundleSwing:
        _startSkill('짐 보따리 휘두르기!');
        _strike(1.3 * p);
        _maybeStun(0.30);
      case JobSkill.counterSlash:
        _startSkill('반격 베기!');
        _strike(1.3 * p);
        reflectNext = true;
      case JobSkill.jointAttack:
        _startSkill('합동 돌격!');
        _strike(1.0 * p);
        if (phase == BattlePhase.fighting) {
          _strike(1.0 * p * skillDamage / math.max(1, playerAttack),
              element: skillElement, useElement: skillElement != null);
        }
        skillCharge = math.min(skillChargeTicks, skillCharge + 2);
      case JobSkill.windBlade:
        _startSkill('바람 칼날!');
        _strike(1.5 * p, element: Element.wind);
        playerSpeed = math.max(playerSpeed, baseSpeed * 1.3);
      case JobSkill.poisonFlask:
        _startSkill('독 물약 뿌리기!');
        _strike(0.6 * p, element: Element.poison);
        foeDotTurns = 4;
        foeDotRatio = 0.03 * p;
      case JobSkill.shadowSlash:
        _startSkill('그림자 베기!');
        _strike((nightTime ? 1.8 : 1.4) * p, element: Element.dark);
        dodgeNext = true;
      case JobSkill.gatekeeperLight:
        _startSkill('문지기의 빛!');
        shieldHits += 3;
        _strike((foeIsAsh ? 3.0 : 1.2) * p, element: Element.light);
      case JobSkill.ashPurge:
        _startSkill('잿빛 정화!');
        _strike((foeIsAsh ? JobRules.ashPurge : 1.5) * p);
      case JobSkill.artisanCombo:
        _startSkill('장인의 연타!');
        for (var i = 0; i <= artisanSubs; i++) {
          if (phase != BattlePhase.fighting) break;
          _strike(0.8 * p);
        }
      default:
        return false;
    }
    return true;
  }

  /// 숙련 스킬 (MP 없이 몇 턴마다)
  bool useMasterySkill(Mastery m) {
    if (!masteryReady(m)) return false;
    skillsUsed++;
    masteryCharge[m] = 0;
    _startSkill('${JobRules.masteryActive(m).name}!');
    switch (m) {
      case Mastery.smith:
        _strike(2.4);
      case Mastery.harvest:
        _strike(1.3);
        foeBindTurns = math.max(foeBindTurns, 1);
      case Mastery.alchemy:
        _strike(1.5, element: Element.fire);
        foeBurnTurns = 3;
      case Mastery.combat:
        for (var i = 0; i < 3; i++) {
          if (phase != BattlePhase.fighting) break;
          _strike(0.6);
        }
      case Mastery.walk:
        _strike(1.5);
        playerSpeed = math.max(playerSpeed, baseSpeed * 1.3);
      case Mastery.appraise:
        final w = _foeWeakTo;
        _strike(w == null ? 1.4 : 1.6, element: w);
      case Mastery.spirit:
        _strike(1.8, element: Element.light);
      case Mastery.trade:
        _strike(1.5);
    }
    return true;
  }

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
    return math.max(1, d.round());
  }

  /// 방어 태세
  bool useStance() {
    if (!stanceReady) return false;
    stanceCharge = 0;
    stanceTurns = stanceLength;
    stances++;
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
        final before = playerHp;
        playerHp = math.min(playerMaxHp,
            playerHp + (playerMaxHp * p.hpRatio * (1 + healBoost)).round());
        _healed(playerHp - before);
    }
    _potionLeft[key] = potionLeft(key) - 1;
    potionsUsed[key] = (potionsUsed[key] ?? 0) + 1;
    lastEvent = '${p.name}!';
    return true;
  }

  /// 자동으로 마실 물약이 있으면 마신다
  void _autoDrink() {
    autoHealed = false;
    autoCured = false;
    if (isOver) return;
    final before = potionsDrunk;
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
      if (heals.isNotEmpty && drink(heals.first.key)) autoHealed = true;
    }
    if (!autoHealed && potionsDrunk > before) autoCured = true;
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

  /// 묶음 56: 이 턴이 지나면 끝 (파티 보스) · 그렇게 끝났는지
  int? tickLimit;
  bool timeUp = false;

  /// 지금 층 몬스터에게 준 피해 (파티 보스: 한 판에 준 피해)
  int get dealtToFoe => math.max(0, foe.maxHp - foeHp);

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
      skillCharge >= skillChargeTicks &&
      !isolated;
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
      foeBreakTurns = 0;
      foeBindTurns = 0;
      foeDotTurns = 0;
      enraged = false;
      _guard = null;
      lastDealt = 0;
      lastTaken = 0;
      lastWasSkill = false;
      lastEvent = null;
      _clearAshMoves();
      _clearSkyMoves();
      // 묶음 34: 잿빛 군주는 감정 단계가 바뀔 때 한 줄
      lastMove = foe.move == null ? null : Act2Rules.ofMove(foe.move!)?.kingLine;
      _prepareStrong();
      return;
    }
    ticks++;
    floorTicks++;
    // 묶음 56: 파티 보스 한 판은 정해진 턴까지 (그때까지 준 피해만 셈)
    if (tickLimit != null && ticks > tickLimit!) {
      timeUp = true;
      phase = BattlePhase.escaped;
      return;
    }
    lastWasSkill = false;
    lastBash = false;
    lastGuard = null;
    lastEvent = null;
    lastCrit = false;
    lastSuper = false;
    lastHealed = 0;
    lastMove = null;
    lastAllySkill = null;
    if (skillLockTurns > 0) skillLockTurns--;
    _ashMove();
    lastDealt = 0;
    lastTaken = 0;
    _skyMove();
    if (isOver) return;
    // 이번 틱의 몬스터 첫 공격이 예고된 강한 공격인지
    _strongNow = _strongNext;
    _strongNowMult = _strongNextMult;
    _strongNext = false;
    final f = foe;
    final foeFirst = f.has(ModifierId.hungry) ||
        f.speed * (enraged ? bossRageSpeed : 1) > playerSpeed;

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
    } else if (tearTurns > 0 && _rng.nextDouble() < Act2Rules.tearsMiss) {
      lastEvent = '빗나갔어요!';
    } else {
      var dmg = _jobHit(_vary(playerAttack));
      if (insightTurns > 0) {
        dmg = (dmg * (1 + PetRules.insightBonus(adult: petAdult))).round();
        insightTurns--;
      }
      if (nextCrit || (playerCrit > 0 && _rng.nextDouble() < playerCrit)) {
        nextCrit = false;
        dmg = (dmg * StatRules.critMultiplier).round();
        lastEvent = '치명타!';
        lastCrit = true;
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
      _setOnHit(dmg);
      _checkRage();
    }
    if (phase != BattlePhase.fighting) return;

    // 묶음 52 #243: 3막 동료들이 차례로 친다
    if (allies.isNotEmpty) {
      _alliesTurn();
      if (phase != BattlePhase.fighting) return;
    }

    if (!foeFirst) {
      _foeTurn();
      if (isOver) return;
      if (f.has(ModifierId.lightning) && floorTicks == 1) {
        _foeTurn();
        if (isOver) return;
      }
    }

    // 묶음 50 회오리: 그동안 한 번 더 움직인다
    if (whirlTurns > 0) {
      whirlTurns--;
      _foeTurn();
      if (isOver) return;
    }

    // 작은 불씨: 몬스터 화상 (최대 체력 2%)
    if (foeBurnTurns > 0) {
      foeBurnTurns--;
      _hitFoe(math.max(1, (f.maxHp * 0.02).round()));
      if (phase != BattlePhase.fighting) return;
    }

    // 묶음 31: 가시덩굴·독 물약 계속 피해
    if (foeDotTurns > 0) {
      foeDotTurns--;
      _hitFoe(math.max(1, (f.maxHp * foeDotRatio).round()));
      if (phase != BattlePhase.fighting) return;
    }

    // 묶음 34 눈물비: 그사이 스스로 회복
    if (tearTurns > 0) {
      tearTurns--;
      if (foeHp < f.maxHp) {
        foeHp = math.min(
            f.maxHp, foeHp + math.max(1, (f.maxHp * Act2Rules.tearsHeal).round()));
      }
    }
    if (stolenTurns > 0) stolenTurns--;
    // 물 슬라임: 매 턴 끝에 5% 회복
    if (f.trait == MonsterTrait.regen && foeHp < f.maxHp) {
      foeHp = math.min(f.maxHp, foeHp + math.max(1, (f.maxHp * 0.05).round()));
    }

    // 중독·화상
    if (poisonTurns > 0) {
      final p = math.max(
          1, (playerMaxHp * (weakPoisoned && !burning ? 0.01 : 0.02)).round());
      poisonTurns--;
      lastTaken += p;
      playerHp = math.max(0, playerHp - p);
      if (playerHp == 0 && !_revive()) {
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
    if (stanceTurns > 0) stanceTurns--;
    if (wallTurns > 0) wallTurns--;
    if (frostTurns > 0) frostTurns--;
    if (foeBreakTurns > 0) foeBreakTurns--;
    if (regenTurns > 0 && playerHp < playerMaxHp) {
      regenTurns--;
      final before = playerHp;
      playerHp = math.min(
          playerMaxHp, playerHp + math.max(1, (playerMaxHp * 0.04).round()));
      _healed(playerHp - before);
    } else if (regenTurns > 0) {
      regenTurns--;
    }
    // 고목 세트 6개: 매 턴 HP 조금 회복 (11-11 #82)
    if (setAbilities.contains(BossSetAbility.regrow) && playerHp < playerMaxHp) {
      final before = playerHp;
      playerHp = math.min(playerMaxHp,
          playerHp + math.max(1, (playerMaxHp * BossGearRules.regrowRatio).round()));
      _healed(playerHp - before);
      setProcs++;
    }
    _autoDrink();
    // 묶음 34 고립: 그동안 펫 게이지가 멈춘다
    if (isolateTurns > 0) {
      isolateTurns--;
    } else if (skillCharge < skillChargeTicks) {
      skillCharge++;
    }
    if (heroSkills) {
      if (bashCharge < bashTicks) bashCharge++;
      // 전투 함성: 강타가 더 빨리 참
      if (rallyTurns > 0 && bashCharge < bashTicks) bashCharge++;
      if (stanceCharge < stanceTicks) stanceCharge++;
      for (final m in masteryActives) {
        final c = masteryCharge[m] ?? 0;
        if (c < JobRules.masteryActiveTicks) masteryCharge[m] = c + 1;
      }
    }
    if (rallyTurns > 0) rallyTurns--;
    if (allies.isNotEmpty) _alliesTickEnd();
    _guard = null;
    _prepareStrong();
  }

  void _foeTurn() {
    if (practice) return;
    final f = foe;
    if (foeBindTurns > 0) {
      foeBindTurns--;
      lastEvent = '묶였어요!';
      return;
    }
    if (dodgeNext) {
      dodgeNext = false;
      lastEvent = '피했어요!';
      return;
    }
    if (blockNext && _strongNow) {
      blockNext = false;
      _strongNow = false;
      lastEvent = '막았다!';
      return;
    }
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
    // 11-11 #75: 예고한 강한 공격 (그 틱의 첫 공격만)
    final strong = _strongNow;
    if (strong) {
      atk *= _strongNowMult;
      _strongNow = false;
    }
    if (enraged) atk *= bossRageAttack;
    // 묶음 34: 분노 폭발 · 빼앗은 힘 · 유품 세트
    if (f.move == AshMove.rage) {
      atk *= 1 + Act2Rules.rageMax * (1 - foeHp / f.maxHp);
    }
    if (stolenTurns > 0) atk *= Act2Rules.stolenAttack;
    // 묶음 52 #243: 3막 동료가 있으면 가끔 동료를 노린다 (대신 맞는 동료가 먼저)
    if (allies.isNotEmpty) {
      final target = _foeTarget();
      if (target != null) {
        _allyTaken(target, atk);
        if (target.down) lastEvent = '동료가 쓰러졌어요!';
        return;
      }
    }
    if (ashTaken > 0 && foeIsAsh) atk *= 1 - ashTaken;
    if (skyTaken > 0 &&
        f.element != null &&
        HighlandRules.skyElements.contains(f.element)) {
      atk *= 1 - skyTaken;
    }
    if (stanceTurns > 0) atk *= stanceTaken;
    if (wallTurns > 0) atk *= wallTaken;
    if (partyDefTurns > 0) atk *= partyDefMult;
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
    final element = f.element;
    if (element != null && (resist[element] ?? 0) > 0) {
      atk *= 1 - resist[element]!;
    }
    if (element != null && elementGuard > 0) atk *= 1 - elementGuard;
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
    // 문지기 세트 6개: 돌 피부 (11-11 #82, 숨김)
    if (setAbilities.contains(BossSetAbility.stoneSkin) &&
        _rng.nextDouble() < BossGearRules.stoneSkinChance) {
      atk *= 0.5;
      setProcs++;
      lastEvent ??= '돌 피부!';
    }
    // 막기 (11-11 #75): 막기는 받는 피해 -60%, 완벽한 막기는 피해 없음 + 반격
    if (strong && _guard != null) {
      final g = _guard!;
      _guard = null;
      lastGuard = g;
      guards++;
      if (g == GuardResult.perfect) {
        lastEvent = '완벽한 막기!';
        final counterDmg = _vary(playerAttack);
        lastDealt = counterDmg;
        _hitFoe(counterDmg);
        _checkRage();
        if (guardFlash > 0) _maybeStun(guardFlash);
        return;
      }
      atk *= blockTaken;
      lastEvent = '막았다!';
      if (guardFlash > 0) _maybeStun(guardFlash);
    }
    final taken = _vary(math.max(1, atk.round()));
    lastTaken += taken;
    playerHp = math.max(0, playerHp - taken);
    // 반격 베기: 받은 공격 일부를 돌려줌
    if (reflectNext) {
      reflectNext = false;
      _hitFoe(math.max(1, (taken * 0.5).round()));
      if (phase != BattlePhase.fighting) return;
    }
    if ((f.has(ModifierId.venomous) ||
            f.has(ModifierId.plagued) ||
            f.trait == MonsterTrait.poison) &&
        immuneTurns <= 0 &&
        _rng.nextDouble() < 0.30) {
      poisonTurns = 3;
      burning = false;
      weakPoisoned = false;
      poisonedThisBattle = true;
      lastEvent = '중독!';
    } else if (f.trait == MonsterTrait.weakPoison &&
        immuneTurns <= 0 &&
        poisonTurns <= 0 &&
        _rng.nextDouble() < weakPoisonChance) {
      poisonTurns = 2;
      burning = false;
      weakPoisoned = true;
      poisonedThisBattle = true;
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
    if (playerHp == 0 && !_revive()) phase = BattlePhase.failed;
  }

  /// 묶음 49 #235: 엠버(잿불새)와 함께한 던전 — 쓰러지면 한 번 되살아남
  int revives = 0;

  /// 되살아난 횟수 (결과·시험용)
  int revived = 0;

  bool _revive() {
    if (revives <= 0) return false;
    revives--;
    revived++;
    playerHp = math.max(1, (playerMaxHp * PetRules.phoenixRevive).round());
    lastEvent = '엠버의 불꽃으로 되살아났어요!';
    return true;
  }

  /// 돌진하는: 이번 층에서 이미 돌진했는지
  bool _charged = false;

  /// 스킬 '불씨의 일격'. 충전이 다 됐을 때만 쓸 수 있다.
  bool useSkill() {
    if (!skillReady) return false;
    skillsUsed++;
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
      // 묶음 33 #185 희귀 펫
      case PetSkill.thunderClaw:
        if (_rng.nextDouble() < PetRules.thunderStun) {
          _foeBound = true;
          lastEvent = '멈칫!';
        }
      case PetSkill.frostBite:
        _foeFrozen = true;
        foeFreezes++;
        lastEvent = '얼었어요!';
      case PetSkill.flameBreath:
        foeBurnTurns = PetRules.flameTurns;
        lastEvent = '화상!';
      case PetSkill.tideWrap:
        _foeBound = true;
        final before = playerHp;
        playerHp = math.min(playerMaxHp,
            playerHp + math.max(1, (playerMaxHp * PetRules.tideHeal).round()));
        _healed(playerHp - before);
        lastEvent = '묶었어요!';
      case PetSkill.ambush:
        if (_rng.nextDouble() < PetRules.ambushChance(adult: petAdult)) {
          dmg = (dmg * PetRules.ambushMultiplier).round();
          lastEvent = '깜짝 물기!';
        }
      case PetSkill.stoneWall:
        shieldHits = PetRules.stoneWallHits(adult: petAdult);
        lastEvent = '돌 방벽!';
      // 묶음 49 #235 영웅 펫
      case PetSkill.galeFang:
        lastEvent = '질풍 송곳니!';
      case PetSkill.mossShell:
        shieldHits = PetRules.mossHits(adult: petAdult);
        lastEvent = '이끼 등딱지!';
      case PetSkill.shadowPounce:
        dmg = (dmg * StatRules.critMultiplier).round();
        lastEvent = '치명타!';
        if (_rng.nextDouble() < PetRules.pounceBind) {
          _foeBound = true;
          lastEvent = '덮쳐서 묶었어요!';
        }
      case PetSkill.tidalSong:
        _foeBound = true;
        final before = playerHp;
        playerHp = math.min(playerMaxHp,
            playerHp + math.max(1, (playerMaxHp * PetRules.songHeal).round()));
        _healed(playerHp - before);
        lastEvent = '고래 노래!';
      case PetSkill.rebirthFlame:
        foeBurnTurns = PetRules.rebirthTurns;
        lastEvent = '화상!';
      case PetSkill.dawnHalo:
        insightTurns = PetRules.insightTurns;
        final before = playerHp;
        playerHp = math.min(playerMaxHp,
            playerHp + math.max(1, (playerMaxHp * PetRules.haloHeal).round()));
        _healed(playerHp - before);
        lastEvent = '새벽 햇무리!';
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

  /// 큰쥐가 약하게 중독시킬 확률 (11-11 A4, 숨김)
  static const double weakPoisonChance = 0.10;

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
    var m = ElementRules.multiplier(attack, foe.element);
    if (noWeakness && m < 1) m = 1;
    if (m > 1 && level > 0) m = SmithRules.strongAt(level);
    var d = dmg * m;
    if (attack != null && attack == mainElement) d *= 1 + ElementRules.mainBonus;
    // 보스 장비 4개 세트: 그 속성 공격 강화 (11-11 #82)
    if (attack != null && setAttack[attack] != null) d *= 1 + setAttack[attack]!;
    // 잿빛 왕의 유품 (묶음 34)
    if (ashDealt > 0 && foeIsAsh) d *= 1 + ashDealt;
    if (m > 1) {
      lastEvent = superEffective;
      lastSuper = true;
    }
    if (m < 1) lastEvent = notEffective;
    return math.max(1, d.round());
  }

  static const superEffective = '효과가 굉장했다!';
  static const notEffective = '효과가 별로인 것 같다…';

  void _hitFoe(int damage) {
    if (practice) {
      practiceDealt += damage;
      return;
    }
    // 묶음 50 서리 갑옷: 받는 피해를 크게 줄인다 (화면 숫자도 줄인 값)
    if (frostTurns > 0) {
      final cut = math.max(1, (damage * HighlandRules.frostTaken).round());
      if (lastDealt >= damage) lastDealt -= damage - cut;
      damage = cut;
    }
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
