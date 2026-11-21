part of '../battle_rules.dart';

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
