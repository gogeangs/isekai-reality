import 'dart:math' as math;

import 'boss_gear_rules.dart';
import 'equipment_rules.dart';
import 'modifier_rules.dart';
import 'monsters.dart';

/// 묶음 77 #337: 인간형 몬스터 전용 장비.
/// 지도 Lv.11 단계부터 나오는 인간형 13종이 드물게 떨어뜨린다 (Lv.1~10 몬스터는 재료만).
/// 대장간에서 강화 · 수리 · 속성은 되지만 만들 수는 없다. 팔기 · 거래 됨.
class MonGearRules {
  MonGearRules._();

  /// 몬스터 → 장비
  static const Map<MonsterId, EquipBase> byMonster = {
    MonsterId.goblinRaider: EquipBase.monGoblinDagger,
    MonsterId.koboldMiner: EquipBase.monKoboldHelm,
    MonsterId.orcMerc: EquipBase.monOrcAxe,
    MonsterId.wildLizardman: EquipBase.monLizardNecklace,
    MonsterId.skeletonGuard: EquipBase.monSkeletonBoots,
    MonsterId.ogre: EquipBase.monOgreBracers,
    MonsterId.livingArmor: EquipBase.monArmorChest,
    MonsterId.doppelganger: EquipBase.monDoppelHood,
    MonsterId.clockworkKnight: EquipBase.monClockSpear,
    MonsterId.centaur: EquipBase.monCentaurBow,
    MonsterId.naga: EquipBase.monNagaBangle,
    MonsterId.dullahan: EquipBase.monDullahanCloak,
    MonsterId.deathKnight: EquipBase.monDeathSword,
  };

  static EquipBase? gearOf(MonsterId m) => byMonster[m];

  static MonsterId? monsterOf(EquipBase b) {
    for (final e in byMonster.entries) {
      if (e.value == b) return e.key;
    }
    return null;
  }

  /// 몬스터가 지도에 처음 나오는 단계 (2 Lv.11~ · 3 Lv.21~ · 4 Lv.31~ · 5 Lv.50~)
  static int tierOf(MonsterId m) => switch (m) {
        MonsterId.goblinRaider || MonsterId.koboldMiner => 2,
        MonsterId.orcMerc || MonsterId.wildLizardman || MonsterId.skeletonGuard => 3,
        MonsterId.ogre || MonsterId.livingArmor => 4,
        _ => 5,
      };

  // ───────────── 떨어뜨릴 확률 (숨은 값)

  /// 보통 3% · 희귀 수식어 8% · 전설 수식어 20%
  static double dropChance(ModGrade g) => switch (g) {
        ModGrade.legend => 0.20,
        ModGrade.rare => 0.08,
        _ => 0.03,
      };

  /// 그날 같은 몬스터 6마리째부터 확률 절반
  static const int sameMonsterFull = 5;
  static double chanceFor(ModGrade g, {required int sameToday}) =>
      dropChance(g) * (sameToday >= sameMonsterFull ? 0.5 : 1);

  /// 등급: 흰 60 · 초록 30 · 파랑 10 (%)
  static EquipGrade rollGrade(math.Random rng) {
    final r = rng.nextDouble();
    if (r < 0.60) return EquipGrade.white;
    if (r < 0.90) return EquipGrade.green;
    return EquipGrade.blue;
  }

  // ───────────── 힘: 같은 단계 대장간 장비의 0.9배 + 작은 특성

  /// 같은 단계 대장간 장비 (보스 장비 기본값 × 단계 배율)
  static double tierMult(int tier) => switch (tier) {
        2 => 1.0,
        3 => 1.15,
        4 => 1.3,
        _ => 1.45,
      };

  static const double powerShare = 0.9;

  static EquipBaseInfo _g(EquipBase id, String name, EquipSlot slot, MonsterId m,
      {double attackMul = 1, double crit = 0, double evade = 0, double speed = 0, int skillFaster = 0,
      double extraHp = 0, double extraReduce = 0, double extraAttack = 0, required String trait}) {
    final b = BossGearRules.baseStat(slot);
    final k = tierMult(tierOf(m)) * powerShare;
    double r(double v) => (v * 1000).round() / 1000;
    return EquipBaseInfo(
      id: id,
      name: name,
      slot: slot,
      recipe: const {},
      attack: r(b.attack * k * attackMul + extraAttack),
      reduce: r(b.reduce * k + extraReduce),
      maxHp: r(b.maxHp * k + extraHp),
      crit: crit,
      evade: evade,
      speed: speed,
      skillFaster: skillFaster,
      trait: trait,
      asset: 'equip_${id.name}',
    );
  }

  static final List<EquipBaseInfo> infos = [
    _g(EquipBase.monGoblinDagger, '고블린의 굽은 단검', EquipSlot.weapon, MonsterId.goblinRaider,
        crit: 0.03, trait: '급소를 잘 노려요'),
    _g(EquipBase.monKoboldHelm, '코볼트의 촛불 투구', EquipSlot.head, MonsterId.koboldMiner,
        evade: 0.015, trait: '어둠 속에서도 잘 보여요'),
    _g(EquipBase.monOrcAxe, '오크의 넓적 도끼', EquipSlot.weapon, MonsterId.orcMerc,
        attackMul: 1.08, crit: -0.02, trait: '느리지만 묵직해요'),
    _g(EquipBase.monLizardNecklace, '리저드맨 이빨 목걸이', EquipSlot.accessory, MonsterId.wildLizardman,
        crit: 0.02, trait: '이빨처럼 날카로워요'),
    _g(EquipBase.monSkeletonBoots, '해골 문지기의 쇠 장화', EquipSlot.feet, MonsterId.skeletonGuard,
        extraReduce: 0.01, trait: '무겁고 단단해요'),
    _g(EquipBase.monOgreBracers, '오우거의 쇠 손보호대', EquipSlot.hands, MonsterId.ogre,
        extraAttack: 0.02, trait: '주먹에 힘이 실려요'),
    _g(EquipBase.monArmorChest, '빈 갑주의 흉갑', EquipSlot.body, MonsterId.livingArmor,
        extraHp: 0.03, trait: '쓰러져도 다시 일어날 것처럼 버텨요'),
    _g(EquipBase.monDoppelHood, '도플갱어의 그림자 두건', EquipSlot.head, MonsterId.doppelganger,
        evade: 0.02, trait: '그림자처럼 스쳐 피해요'),
    _g(EquipBase.monClockSpear, '태엽 기사의 톱니 창', EquipSlot.weapon, MonsterId.clockworkKnight,
        speed: 0.10, trait: '태엽처럼 먼저 찔러요'),
    _g(EquipBase.monCentaurBow, '켄타우로스의 덩굴 장궁', EquipSlot.weapon, MonsterId.centaur,
        crit: 0.03, speed: 0.05, trait: '멀리서 먼저 쏴요'),
    _g(EquipBase.monNagaBangle, '나가의 금 팔찌', EquipSlot.accessory, MonsterId.naga,
        skillFaster: 1, trait: '일격 충전이 조금 빨라요'),
    _g(EquipBase.monDullahanCloak, '듀라한의 검은 망토', EquipSlot.body, MonsterId.dullahan,
        evade: 0.02, trait: '어둠에 몸을 숨겨요'),
    _g(EquipBase.monDeathSword, '데스나이트의 대검', EquipSlot.weapon, MonsterId.deathKnight,
        attackMul: 1.05, crit: 0.04, trait: '한 방이 무거워요'),
  ];

  /// 얻은 적 있는 표시 (마을 표시 열쇠)
  static String foundKey(EquipBase b) => 'monGear:${b.name}';
}
