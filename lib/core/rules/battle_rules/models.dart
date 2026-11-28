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
    this.tint,
    this.label,
  });

  /// 묶음 60: 화면에 보이는 이름을 바꿈 (공성전 수비대 = 길드원 이름)
  final String? label;

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
  /// 레벨마다 포인트 5를 다섯 스탯에 하나씩 나눈 것으로 본다.
  /// 묶음 85 #408: 몬스터 세기는 아래 [baselineStats] (주 스탯 몰아주기 + 보통 장비) 기준. 이 값은
  /// 「처음 사람 보호」와 속도 비교에만 쓴다.
  static Stats expectedStats(int level) =>
      Stats.all(StatRules.start + math.max(0, level - 1));

  // ───────────── 묶음 85 #408: 새 기준 각성자 · 레벨 배수 (숨은 값)

  /// 레벨마다 포인트 5 중 주 스탯(힘)에 이만큼, 나머지는 네 스탯에 고르게
  static const int baselineMain = 3;

  /// 새 기준 각성자 스탯 (힘에 몰아줌)
  static Stats baselineStats(int level) {
    final pts = math.max(0, level - 1);
    final rest = StatRules.start + pts * (StatRules.pointsPerLevel - baselineMain) ~/ 4;
    return Stats(
      strength: StatRules.start + pts * baselineMain,
      agility: rest,
      intellect: rest,
      vitality: rest,
      luck: rest,
    );
  }

  /// 보통 갖출 장비: 만들 수 있는 기본 장비 중 부위마다 가장 좋은 것 · 파랑 등급 · +3 강화.
  /// Lv.1 은 장비 없음 → Lv.10 까지 조금씩 갖춘다
  static const int baselineEnhance = 3;
  static double get _gearPower =>
      EquipmentRules.gradeMultiplier(EquipGrade.blue) * (1 + EquipmentRules.enhanceStep * baselineEnhance);
  static double _bestOf(EquipSlot s, double Function(EquipBaseInfo) f) {
    var best = 0.0;
    for (final e in EquipmentRules.all) {
      if (e.slot == s && f(e) > best) best = f(e);
    }
    return best;
  }

  static final double baselineGearAttack = _bestOf(EquipSlot.weapon, (e) => e.attack) * _gearPower;
  static final double baselineGearReduce = [EquipSlot.head, EquipSlot.body, EquipSlot.hands, EquipSlot.feet]
          .fold<double>(0, (t, s) => t + _bestOf(s, (e) => e.reduce)) *
      _gearPower;
  static final double baselineGearHp = _bestOf(EquipSlot.accessory, (e) => e.maxHp) * _gearPower;
  static double gearRamp(int level) => ((level - 1) / 9).clamp(0.0, 1.0);

  /// 새 기준 각성자의 공격 · 최대 HP · 받는 피해 배율 (펫 · 직업 · 세트 없이)
  static int baselineAttack(int level) => math.max(1,
      (StatRules.attack(level: level, stats: baselineStats(level)) * (1 + baselineGearAttack * gearRamp(level))).round());
  static int baselineMaxHp(int level) =>
      (StatRules.battleMaxHp(level: level, stats: baselineStats(level)) * (1 + baselineGearHp * gearRamp(level))).round();
  static double baselineTaken(int level) =>
      (1 - baselineGearReduce * gearRamp(level)) * (1 - StatRules.vitalityReduce(baselineStats(level)));

  /// 레벨 배수: Lv.11부터 몬스터 HP · 공격 × (1 + 0.015 × (레벨 − 10))
  static const double levelStep = 0.015;
  static double levelMult(int level) => level <= 10 ? 1 : 1 + levelStep * (level - 10);

  /// 새 기준 각성자가 필드 몬스터(보통)를 쓰러뜨리는 공격 수 (레벨 배수 전)
  static const double baselineHits = 4.7;

  /// 처음 사람 보호: 고르게 나누고 장비 없는 사람이 필드 몬스터를 이만큼 안쪽에 (Lv.10까지, 그 뒤 풀림)
  static double protectHits(int level) => level <= 10 ? 7.5 : 7.5 + 0.6 * (level - 10);

  /// 처음 사람 보호: 고르게 · 장비 없는 사람이 받는 피해가 예전보다 이만큼까지만 (Lv.10까지 그대로)
  static double protectTaken(int level) => level <= 10 ? 1.0 : 1.0 + 0.04 * (level - 10);

  /// 고르게 나눈 · 장비 없는 각성자의 공격 · 최대 HP (예전 기준, 보호에만)
  static int evenAttack(int level) => StatRules.attack(level: level, stats: expectedStats(level));
  static int evenMaxHp(int level) => StatRules.battleMaxHp(level: level, stats: expectedStats(level));

  /// 몬스터 세기 기준값 (필드 몬스터 HP = 이 값 × [RuleConstants.fieldHitsToClear] × 몬스터 배수).
  /// 묶음 85 #408: 새 기준 각성자 · 레벨 배수 · 처음 사람 보호. 튜토리얼(Lv.1~2)은 예전 그대로
  static int expectedAttack(int level) {
    if (level <= 2) return evenAttack(level);
    final want = baselineAttack(level) * levelMult(level) * baselineHits / RuleConstants.fieldHitsToClear;
    final cap = evenAttack(level) * protectHits(level) / RuleConstants.fieldHitsToClear;
    return math.max(1, math.min(want, cap).round());
  }

  /// 몬스터 공격 기준값 (필드 몬스터 공격 = 이 값 ÷ [RuleConstants.fieldHpBudgetTicks] × 몬스터 배수).
  /// 새 기준 각성자의 「버티는 HP」(최대 HP ÷ 받는 피해 배율) × 레벨 배수, 처음 사람 보호
  static int expectedMaxHp(int level) {
    if (level <= 2) return evenMaxHp(level);
    final want = baselineMaxHp(level) / baselineTaken(level) * levelMult(level);
    final cap = evenMaxHp(level) * protectTaken(level);
    return math.max(1, math.min(want, cap).round());
  }

  /// 묶음 86 #422: 던전만 Lv.11~15 처음 사람 보호를 더 넓게 (고르게 · 장비 없는 사람도 절반 넘게 깸).
  /// Lv.16부터는 #408 그대로
  static const int dungeonProtectTo = 15;
  static double dungeonProtectHits(int level) => 7.5 + dungeonHitStep * (level - 10);
  static double dungeonProtectTaken(int level) => 1.0 + dungeonTakenStep * (level - 10);
  static const double dungeonHitStep = 0.25;
  static const double dungeonTakenStep = 0.015;

  static int dungeonAttack(int level) {
    final base = expectedAttack(level);
    if (level <= 10 || level > dungeonProtectTo) return base;
    final cap = evenAttack(level) * dungeonProtectHits(level) / RuleConstants.fieldHitsToClear;
    return math.max(1, math.min(base.toDouble(), cap).round());
  }

  static int dungeonMaxHp(int level) {
    final base = expectedMaxHp(level);
    if (level <= 10 || level > dungeonProtectTo) return base;
    final cap = evenMaxHp(level) * dungeonProtectTaken(level);
    return math.max(1, math.min(base.toDouble(), cap).round());
  }

  /// 던전 4층: 일반 3층 + 마지막 보스(미궁 문지기).
  /// 미궁 입구에서 열면 일반 층이 모두 미궁 박쥐(장소 전용 몬스터).
  static List<Foe> dungeonFloors({
    required int level,
    required bool atGate,
    required math.Random rng,
    DateTime? day,
  }) {
    final atk = dungeonAttack(level);
    final hp = dungeonMaxHp(level);
    // 묶음 85 #408: 던전은 층이 길어 레벨 배수가 HP · 공격 둘 다에 붙으면 두 번 세진다 → 공격 쪽은 한 번만
    final floorAttack = math.max(
        1, (hp / RuleConstants.dungeonHpBudgetTicks / levelMult(level)).round());
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
    this.jobMpRatio = 0,
  });

  /// 묶음 82 #392: 직업 MP 마나 물약 (최대의 이만큼)
  final double jobMpRatio;

  /// 'shop:healSmall' · 'alc:healBig*' 처럼 가방에서 뺄 때 쓰는 키
  final String key;
  final String name;
  final int count;
  final double hpRatio;
  final CureKind? cure;
}
