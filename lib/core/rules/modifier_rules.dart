import 'dart:math' as math;

import 'materials.dart';
import 'monsters.dart';

/// 몬스터 수식어 등급 (이름 색: 없음 흰색, 일반 초록, 희귀 파랑, 전설 주황)
enum ModGrade { none, common, rare, legend }

/// 몬스터 수식어 (11-10 #21). 이름은 저장 기록의 키라 바꾸지 않는다.
enum ModifierId {
  // 공통
  hungry,
  sturdy,
  nimble,
  giant,
  enraged,
  venomous,
  pack,
  golden,
  ancient,
  // 슬라임
  sticky,
  splitting,
  // 큰쥐
  plagued,
  squeaky,
  // 그림자 나비
  bewitching,
  nightglow,
  // 혼래빗 (11-11)
  thickHorn,
  lightning,
  // 아기 와일드 보어 (11-11)
  charging,
  chieftain,
}

class ModifierInfo {
  const ModifierInfo(
    this.id,
    this.name,
    this.grade,
    this.behavior, {
    this.monster,
    this.hp = 1,
    this.attack = 1,
    this.defense = 1,
    this.speed = 1,
    this.expBonus = 0,
    this.extraManaStones = 0,
    this.extraGold = 0,
    this.extraMaterials = 0,
    this.rareGuaranteed = false,
    this.special,
    this.specialChance = 0,
    this.extraFoes = 0,
    this.bonusMaterial,
  });

  final ModifierId id;

  /// 이름 앞에 붙는 말 (예: 굶주린)
  final String name;
  final ModGrade grade;

  /// 행동 설명 (도감·전투 화면)
  final String behavior;

  /// 이 몬스터 전용 수식어 (공통이면 null)
  final MonsterId? monster;

  /// 능력치 배수
  final double hp, attack, defense, speed;

  /// 보상: 경험치 +%, 마석·금화 추가, 재료 +개, 귀한 재료 확정, 특수 재료 확률
  final double expBonus;
  final int extraManaStones;
  final int extraGold;
  final int extraMaterials;
  final bool rareGuaranteed;
  final MaterialId? special;
  final double specialChance;

  /// 함께 나오는 몬스터 수 (무리 지은 2~3마리는 [ModifierRules.foeCount] 가 정한다)
  final int extraFoes;

  /// 확정으로 하나 더 주는 재료 (뿔이 굵은 → 작은 뿔 등)
  final MaterialId? bonusMaterial;
}

/// 수식어 확률·능력치·보상 (제안서 2장, 11-10 확정)
class ModifierRules {
  ModifierRules._();

  static const List<ModifierInfo> all = [
    ModifierInfo(ModifierId.hungry, '굶주린', ModGrade.common, '항상 먼저 공격해요',
        attack: 1.25, defense: 0.85, expBonus: 0.10),
    ModifierInfo(ModifierId.sturdy, '단단한', ModGrade.common,
        '20% 확률로 웅크려 그 턴 피해를 절반만 받아요',
        defense: 1.3, speed: 0.85, extraManaStones: 1),
    ModifierInfo(ModifierId.nimble, '날쌘', ModGrade.common, '공격을 20% 피해요',
        speed: 1.3, hp: 0.85, expBonus: 0.10),
    ModifierInfo(ModifierId.giant, '거대한', ModGrade.common, '느리지만 묵직해요',
        hp: 1.8, attack: 1.1, speed: 0.8, expBonus: 0.30, extraMaterials: 1),
    ModifierInfo(ModifierId.enraged, '분노한', ModGrade.rare,
        '체력이 절반 아래로 떨어지면 공격이 1.5배',
        attack: 1.2, expBonus: 0.50),
    ModifierInfo(ModifierId.venomous, '독을 품은', ModGrade.rare,
        '맞히면 30% 확률로 중독 (3턴, 매 턴 최대 HP 2%)',
        attack: 1.15, special: MaterialId.poisonGland, specialChance: 0.5),
    ModifierInfo(ModifierId.pack, '무리 지은', ModGrade.rare, '2~3마리가 함께 나와요',
        hp: 0.6, attack: 0.7),
    // 체력 0.4배: 보통 3번에 잡히는 체력 (그대로면 6번이라 늘 도망친다)
    ModifierInfo(ModifierId.golden, '황금빛', ModGrade.legend,
        '3턴 안에 못 잡으면 도망쳐요',
        hp: 0.4, speed: 1.6, extraManaStones: 5, extraGold: 50),
    ModifierInfo(ModifierId.ancient, '고대의', ModGrade.legend,
        '4턴마다 강타 (공격 2.5배)',
        hp: 1.6, attack: 1.6, defense: 1.6, speed: 1.6,
        expBonus: 1.0, rareGuaranteed: true),
    // 슬라임
    ModifierInfo(ModifierId.sticky, '끈적한', ModGrade.common,
        '맞으면 각성자 속도가 0.8배',
        monster: MonsterId.ashSlime, extraMaterials: 1),
    ModifierInfo(ModifierId.splitting, '분열하는', ModGrade.rare,
        '쓰러지면 작은 슬라임이 하나 더 나와요',
        monster: MonsterId.ashSlime, extraFoes: 1),
    // 큰쥐
    ModifierInfo(ModifierId.plagued, '병균 묻은', ModGrade.rare,
        '맞히면 30% 확률로 중독 (3턴, 매 턴 최대 HP 2%)',
        monster: MonsterId.giantRat,
        special: MaterialId.glossyFur,
        specialChance: 0.5),
    ModifierInfo(ModifierId.squeaky, '찍찍거리는', ModGrade.common,
        '동료 쥐를 한 마리 불러요',
        monster: MonsterId.giantRat, extraFoes: 1),
    // 그림자 나비
    ModifierInfo(ModifierId.bewitching, '홀리는', ModGrade.rare,
        '25% 확률로 각성자가 한 턴 쉬어 버려요',
        monster: MonsterId.shadowButterfly,
        special: MaterialId.sleepPowder,
        specialChance: 0.5),
    ModifierInfo(ModifierId.nightglow, '밤빛', ModGrade.common, '밤에 더 빛나요',
        monster: MonsterId.shadowButterfly, expBonus: 0.20),
    // 혼래빗
    ModifierInfo(ModifierId.thickHorn, '뿔이 굵은', ModGrade.common, '뿔로 세게 들이받아요',
        monster: MonsterId.hornRabbit,
        attack: 1.3,
        bonusMaterial: MaterialId.smallHorn),
    ModifierInfo(ModifierId.lightning, '번개 같은', ModGrade.rare,
        '첫 턴에 두 번 공격하고, 공격을 25% 피해요',
        monster: MonsterId.hornRabbit,
        expBonus: 0.50,
        special: MaterialId.goldenRabbitFur,
        specialChance: 0.5),
    // 아기 와일드 보어
    ModifierInfo(ModifierId.charging, '돌진하는', ModGrade.common, '첫 공격이 두 배로 아파요',
        monster: MonsterId.babyBoar, bonusMaterial: MaterialId.toughHide),
    ModifierInfo(ModifierId.chieftain, '우두머리', ModGrade.rare, '무리를 이끄는 덩치 큰 보어',
        monster: MonsterId.babyBoar,
        hp: 1.6,
        attack: 1.3,
        expBonus: 0.50,
        special: MaterialId.smallTusk,
        specialChance: 0.5),
  ];

  static ModifierInfo info(ModifierId id) => all.firstWhere((m) => m.id == id);

  static ModifierId? byName(String name) {
    for (final m in ModifierId.values) {
      if (m.name == name) return m;
    }
    return null;
  }

  // ───────────────────────── 확률

  /// 등급 확률 (없음, 일반, 희귀, 전설). 레벨마다 희귀 +0.3%p, 전설 +0.1%p,
  /// 일반은 그대로 25%, 없음이 그만큼 줄어든다. 상한 49/25/20/6.
  static (double, double, double, double) chances(int level) {
    final l = math.max(0, level - 1);
    final rare = math.min(0.20, 0.12 + 0.003 * l);
    final legend = math.min(0.06, 0.03 + 0.001 * l);
    const common = 0.25;
    return (1 - common - rare - legend, common, rare, legend);
  }

  /// 공통 수식어 대신 같은 등급의 몬스터 전용 수식어가 붙을 확률
  static const double specificChance = 0.30;

  /// 전설에 일반·희귀 하나가 더 붙을 확률
  static const double legendExtraChance = 0.50;

  /// 그 자리 몬스터의 수식어. 자리마다 같은 난수를 쓰고, 보는 사람의 레벨로 등급을 나눈다.
  /// 던전 몬스터(미궁 박쥐·문지기)에는 붙이지 않는다.
  ///
  /// [bonus] 는 행운으로 늘어나는 수식어 확률 (없음에서 빼서 희귀에 더한다, 11-11)
  static List<ModifierId> roll(String spawnId, MonsterId monster, int level,
      {double bonus = 0}) {
    // 던전 몬스터에는 붙이지 않는다 (던전은 이 함수를 부르지 않는다. 필드 박쥐는 붙음)
    if (monster == MonsterId.labyrinthWarden) return const [];
    final rng = math.Random(_stableHash('$spawnId|mod'));
    final u = rng.nextDouble();
    final (_, common, rare0, legend) = chances(level);
    final rare = rare0 + bonus;
    final ModGrade grade;
    if (u < legend) {
      grade = ModGrade.legend;
    } else if (u < legend + rare) {
      grade = ModGrade.rare;
    } else if (u < legend + rare + common) {
      grade = ModGrade.common;
    } else {
      return const [];
    }
    final first = _pick(grade, monster, rng);
    if (grade != ModGrade.legend || rng.nextDouble() >= legendExtraChance) {
      return [first];
    }
    // 전설 + 일반·희귀 하나 (일반 25 : 희귀 비율)
    final extraGrade = rng.nextDouble() < common / (common + rare)
        ? ModGrade.common
        : ModGrade.rare;
    return [first, _pick(extraGrade, monster, rng)];
  }

  static ModifierId _pick(ModGrade grade, MonsterId monster, math.Random rng) {
    // 속성 슬라임도 슬라임 전용 수식어를 받는다
    final asSlime = Monsters.info(monster).slimeKind ? MonsterId.ashSlime : monster;
    final specific = [
      for (final m in all)
        if (m.grade == grade && m.monster == asSlime) m.id,
    ];
    final common = [
      for (final m in all)
        if (m.grade == grade && m.monster == null) m.id,
    ];
    final useSpecific = specific.isNotEmpty && rng.nextDouble() < specificChance;
    final from = useSpecific || common.isEmpty ? specific : common;
    return from[rng.nextInt(from.length)];
  }

  // ───────────────────────── 이름

  /// 가장 높은 등급 (이름 색)
  static ModGrade gradeOf(List<ModifierId> mods) {
    var g = ModGrade.none;
    for (final m in mods) {
      final mg = info(m).grade;
      if (mg.index > g.index) g = mg;
    }
    return g;
  }

  /// '고대의 분노한 슬라임'처럼 수식어를 붙인 이름
  static String displayName(MonsterId monster, List<ModifierId> mods) => [
        for (final m in mods) info(m).name,
        Monsters.info(monster).name,
      ].join(' ');

  static String gradeLabel(ModGrade g) => switch (g) {
        ModGrade.none => '보통',
        ModGrade.common => '일반',
        ModGrade.rare => '희귀',
        ModGrade.legend => '전설',
      };

  /// 도감 '수식어' 칸에 따로 남기는지 (희귀·전설)
  static bool recordInCodex(List<ModifierId> mods) =>
      gradeOf(mods).index >= ModGrade.rare.index;

  /// 도감 기록 키 ('슬라임|ancient,enraged')
  static String codexKey(MonsterId monster, List<ModifierId> mods) =>
      '${monster.name}|${mods.map((m) => m.name).join(',')}';

  static (MonsterId, List<ModifierId>)? parseCodexKey(String key) {
    final parts = key.split('|');
    if (parts.length != 2) return null;
    final monster = Monsters.byName(parts[0]);
    if (monster == null) return null;
    final mods = <ModifierId>[];
    for (final n in parts[1].split(',')) {
      final id = byName(n);
      if (id != null) mods.add(id);
    }
    return (monster, mods);
  }

  // ───────────────────────── 전투

  /// 함께 싸우는 몬스터 수 (무리 지은 2~3, 분열하는·찍찍거리는 2)
  static int foeCount(String spawnId, List<ModifierId> mods) {
    var n = 1;
    for (final m in mods) {
      if (m == ModifierId.pack) {
        n += 1 + math.Random(_stableHash('$spawnId|pack')).nextInt(2);
      }
      n += info(m).extraFoes;
    }
    return n;
  }

  /// 능력치 배수의 곱 (hp, attack, defense, speed)
  static (double, double, double, double) multipliers(List<ModifierId> mods) {
    var hp = 1.0, atk = 1.0, def = 1.0, spd = 1.0;
    for (final m in mods) {
      final i = info(m);
      hp *= i.hp;
      atk *= i.attack;
      def *= i.defense;
      spd *= i.speed;
    }
    return (hp, atk, def, spd);
  }

  // ───────────────────────── 보상

  /// 경험치 배수 (1 + 보너스 합)
  static double expMultiplier(List<ModifierId> mods) =>
      1 + mods.fold<double>(0, (s, m) => s + info(m).expBonus);

  /// 수식어로 더 얻는 것 (마석·금화·재료). 마리 수만큼은 따로 곱한다.
  static ({int manaStones, int gold, Map<MaterialId, int> materials}) bonus(
    MonsterId monster,
    List<ModifierId> mods,
    math.Random rng,
  ) {
    var mana = 0, gold = 0;
    final mats = <MaterialId, int>{};
    final drops = LootRules.dropsOf(monster);
    final common = drops.common.first;
    final rare = drops.rare;
    for (final m in mods) {
      final i = info(m);
      mana += i.extraManaStones;
      gold += i.extraGold;
      if (i.extraMaterials > 0) {
        mats[common] = (mats[common] ?? 0) + i.extraMaterials;
      }
      if (i.rareGuaranteed) mats[rare] = 1;
      final bonus = i.bonusMaterial;
      if (bonus != null) mats[bonus] = (mats[bonus] ?? 0) + 1;
      final special = i.special;
      if (special != null && rng.nextDouble() < i.specialChance) {
        mats[special] = (mats[special] ?? 0) + 1;
      }
    }
    return (manaStones: mana, gold: gold, materials: mats);
  }

  /// 실행할 때마다 같은 값을 내는 문자열 해시 (FNV-1a 32비트)
  static int _stableHash(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }
}
