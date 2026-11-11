import 'dart:math' as math;

import '../models/armory.dart';
import 'boss_gear_rules.dart';
import 'element_rules.dart';
import 'materials.dart';
import 'stat_rules.dart';

/// 장비 부위 6칸
enum EquipSlot { weapon, head, body, hands, feet, accessory }

/// 장비 등급 (이름 색: 흰색 · 초록 · 파랑 · 보라 · 주황)
enum EquipGrade { white, green, blue, purple, orange }

/// 장비 종류 (만들 수 있는 것). 이름은 저장 기록의 키라 바꾸지 않는다.
enum EquipBase {
  dagger,
  staff,
  cap,
  armor,
  gloves,
  boots,
  fangNecklace,
  wardenCharm,
  // 11-11 #31
  hornDagger,
  boarArmor,
  rabbitBoots,
  tuskNecklace,
  // 11-11 #82 보스 장비 6세트 (무기·머리·몸·장갑·신발·장신구)
  wardenWeapon, wardenHead, wardenBody, wardenHands, wardenFeet, wardenAcc,
  flameWeapon, flameHead, flameBody, flameHands, flameFeet, flameAcc,
  frostWeapon, frostHead, frostBody, frostHands, frostFeet, frostAcc,
  groveWeapon, groveHead, groveBody, groveHands, groveFeet, groveAcc,
  nightWeapon, nightHead, nightBody, nightHands, nightFeet, nightAcc,
  stormWeapon, stormHead, stormBody, stormHands, stormFeet, stormAcc,
}

/// 장비 하나의 기본 정보와 제작법
class EquipBaseInfo {
  const EquipBaseInfo({
    required this.id,
    required this.name,
    required this.slot,
    required this.recipe,
    this.manaStones = 0,
    this.attack = 0,
    this.reduce = 0,
    this.maxHp = 0,
    this.skillFaster = 0,
    this.crit = 0,
    this.evade = 0,
    this.job,
    required this.asset,
  });

  final EquipBase id;
  final String name;
  final EquipSlot slot;

  /// 재료 (마석 빼고)
  final Map<MaterialId, int> recipe;
  final int manaStones;

  /// 기본 능력 (흰색 +0 기준, 비율): 공격 +, 받는 피해 -, 최대 HP +
  final double attack;
  final double reduce;
  final double maxHp;

  /// 정령의 일격 충전이 이만큼 빨라진다 (틱)
  final int skillFaster;

  /// 치명타 확률·회피 확률 (+%p, 11-11)
  final double crit;
  final double evade;

  /// 어울리는 직업 (직업이 생기면 능력 +20%, 지금은 데이터만)
  final String? job;

  /// assets/images/<asset>.png
  final String asset;

  String get statLabel => [
        if (attack > 0) '공격 +${_pct(attack)}%',
        if (reduce > 0) '받는 피해 -${_pct(reduce)}%',
        if (maxHp > 0) '최대 HP +${_pct(maxHp)}%',
        if (skillFaster > 0) '일격 충전 하나 빨리',
        if (crit > 0) '치명타 +${_pct(crit)}%p',
        if (evade > 0) '회피 +${_pct(evade)}%p',
      ].join(', ');
}

String _pct(double r) {
  final v = r * 100;
  return v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
}

/// 장비가 전투에 주는 힘 (입은 것 모두 더한 값)
class GearBonus {
  const GearBonus({
    this.attack = 0,
    this.reduce = 0,
    this.maxHp = 0,
    this.skillFaster = 0,
    this.crit = 0,
    this.evade = 0,
    this.stats = Stats.zero,
    this.attackElement,
    this.guardElements = const {},
    this.attackLevel = 0,
    this.guardLevels = const {},
    this.sets = SetBonus.none,
  });

  /// 보스 장비 세트 효과 (11-11 #82)
  final SetBonus sets;

  /// 무기의 공격 속성 (11-11 #63)
  final Element? attackElement;

  /// 방어구·장신구의 방어 속성
  final Set<Element> guardElements;

  /// 속성 강화 단계 (11-11 #74, 숨김)
  final int attackLevel;
  final Map<Element, int> guardLevels;

  final double attack;
  final double reduce;
  final double maxHp;
  final int skillFaster;
  final double crit;
  final double evade;

  /// 추가 능력 (힘·민첩·지능·체력·행운)
  final Stats stats;

  static const none = GearBonus();
}

/// 대장간·장비 규칙 (제안서 5장, 11-10 확정)
class EquipmentRules {
  EquipmentRules._();

  static const List<EquipBaseInfo> all = [
    EquipBaseInfo(
      id: EquipBase.dagger,
      name: '철 단검',
      slot: EquipSlot.weapon,
      recipe: {MaterialId.ironShard: 3, MaterialId.ratHide: 1},
      manaStones: 3,
      attack: 0.08,
      job: '기사',
      asset: 'equip_dagger',
    ),
    EquipBaseInfo(
      id: EquipBase.staff,
      name: '나무 지팡이',
      slot: EquipSlot.weapon,
      recipe: {MaterialId.twig: 2, MaterialId.butterflyDust: 2},
      manaStones: 3,
      attack: 0.06,
      skillFaster: 1,
      job: '현자',
      asset: 'equip_staff',
    ),
    EquipBaseInfo(
      id: EquipBase.cap,
      name: '가죽 모자',
      slot: EquipSlot.head,
      recipe: {MaterialId.ratHide: 2},
      manaStones: 1,
      reduce: 0.03,
      asset: 'equip_cap',
    ),
    EquipBaseInfo(
      id: EquipBase.armor,
      name: '가죽 갑옷',
      slot: EquipSlot.body,
      recipe: {MaterialId.ratHide: 4, MaterialId.batWing: 1},
      manaStones: 3,
      reduce: 0.06,
      asset: 'equip_armor',
    ),
    EquipBaseInfo(
      id: EquipBase.gloves,
      name: '가죽 장갑',
      slot: EquipSlot.hands,
      recipe: {MaterialId.ratHide: 2, MaterialId.slimeJelly: 1},
      reduce: 0.02,
      asset: 'equip_gloves',
    ),
    EquipBaseInfo(
      id: EquipBase.boots,
      name: '가죽 장화',
      slot: EquipSlot.feet,
      recipe: {MaterialId.ratHide: 2, MaterialId.slimeJelly: 1},
      reduce: 0.02,
      asset: 'equip_boots',
    ),
    EquipBaseInfo(
      id: EquipBase.fangNecklace,
      name: '박쥐 송곳니 목걸이',
      slot: EquipSlot.accessory,
      recipe: {MaterialId.batWing: 2},
      manaStones: 2,
      maxHp: 0.05,
      asset: 'equip_fang_necklace',
    ),
    EquipBaseInfo(
      id: EquipBase.hornDagger,
      name: '뿔 단검',
      slot: EquipSlot.weapon,
      recipe: {MaterialId.smallHorn: 3, MaterialId.ironShard: 1},
      manaStones: 3,
      attack: 0.07,
      crit: 0.03,
      job: '기사',
      asset: 'equip_horn_dagger',
    ),
    EquipBaseInfo(
      id: EquipBase.boarArmor,
      name: '멧돼지 가죽 갑옷',
      slot: EquipSlot.body,
      recipe: {MaterialId.toughHide: 3, MaterialId.ratHide: 2},
      manaStones: 3,
      reduce: 0.07,
      asset: 'equip_boar_armor',
    ),
    EquipBaseInfo(
      id: EquipBase.rabbitBoots,
      name: '토끼발 장화',
      slot: EquipSlot.feet,
      recipe: {
        MaterialId.toughHide: 1,
        MaterialId.smallHorn: 1,
        MaterialId.slimeJelly: 1,
      },
      reduce: 0.02,
      evade: 0.02,
      asset: 'equip_rabbit_boots',
    ),
    EquipBaseInfo(
      id: EquipBase.tuskNecklace,
      name: '엄니 목걸이',
      slot: EquipSlot.accessory,
      recipe: {MaterialId.smallTusk: 1, MaterialId.batWing: 1},
      manaStones: 3,
      maxHp: 0.06,
      attack: 0.02,
      asset: 'equip_tusk_necklace',
    ),
    EquipBaseInfo(
      id: EquipBase.wardenCharm,
      name: '문지기의 부적',
      slot: EquipSlot.accessory,
      recipe: {MaterialId.wardenShard: 2},
      manaStones: 5,
      maxHp: 0.08,
      asset: 'equip_stone_charm',
    ),
  ];

  static EquipBaseInfo info(EquipBase id) => _byId[id]!;

  static final Map<EquipBase, EquipBaseInfo> _byId = {
    for (final e in all) e.id: e,
    for (final e in BossGearRules.infos) e.id: e,
  };

  /// 보스 장비인지 (11-11 #82)
  static bool isBossGear(EquipBase id) => BossGearRules.setOf(id) != null;

  static EquipBase? baseByName(String name) {
    for (final b in EquipBase.values) {
      if (b.name == name) return b;
    }
    return null;
  }

  static String slotLabel(EquipSlot s) => switch (s) {
        EquipSlot.weapon => '무기',
        EquipSlot.head => '머리',
        EquipSlot.body => '몸',
        EquipSlot.hands => '장갑',
        EquipSlot.feet => '신발',
        EquipSlot.accessory => '장신구',
      };

  static String gradeLabel(EquipGrade g) => switch (g) {
        EquipGrade.white => '흰색',
        EquipGrade.green => '초록',
        EquipGrade.blue => '파랑',
        EquipGrade.purple => '보라',
        EquipGrade.orange => '주황',
      };

  // ───────────────────────── 등급

  /// 기본 능력 배수
  static double gradeMultiplier(EquipGrade g) => switch (g) {
        EquipGrade.white => 1.0,
        EquipGrade.green => 1.15,
        EquipGrade.blue => 1.3,
        EquipGrade.purple => 1.5,
        EquipGrade.orange => 1.8,
      };

  /// 수리 비용 배수
  static double repairMultiplier(EquipGrade g) => switch (g) {
        EquipGrade.white => 1.0,
        EquipGrade.green => 1.2,
        EquipGrade.blue => 1.5,
        EquipGrade.purple => 2.0,
        EquipGrade.orange => 3.0,
      };

  /// 등급 확률 (흰·초록·파랑·보라·주황, %). 귀한 재료를 넣으면 좋아진다.
  /// 제작 숙련도: 제작 10번마다 파랑 +1%p (최대 +10%p, 흰색에서 뺀다).
  static List<double> gradeChances({required bool rare, int crafts = 0}) {
    final c = rare
        ? [30.0, 40.0, 22.0, 6.5, 1.5]
        : [60.0, 28.0, 10.0, 1.8, 0.2];
    final mastery = math.min(10, crafts ~/ 10).toDouble();
    c[0] -= mastery;
    c[2] += mastery;
    return c;
  }

  static int masteryBonus(int crafts) => math.min(10, crafts ~/ 10);

  static EquipGrade rollGrade(math.Random rng,
      {required bool rare, int crafts = 0}) {
    final c = gradeChances(rare: rare, crafts: crafts);
    var u = rng.nextDouble() * 100;
    for (var i = 0; i < c.length; i++) {
      if (u < c[i]) return EquipGrade.values[i];
      u -= c[i];
    }
    return EquipGrade.white;
  }

  /// 추가 능력: 초록 1개(+1~2), 파랑 1~2개(+1~3), 보라 2개(+2~3), 주황 3개(+2~4).
  /// 힘·민첩·지능·체력·행운 중에서 무작위 (11-11 #50).
  static Map<String, int> rollExtras(EquipGrade g, math.Random rng) {
    final (count, lo, hi) = switch (g) {
      EquipGrade.white => (0, 0, 0),
      EquipGrade.green => (1, 1, 2),
      EquipGrade.blue => (1 + rng.nextInt(2), 1, 3),
      EquipGrade.purple => (2, 2, 3),
      EquipGrade.orange => (3, 2, 4),
    };
    final out = <String, int>{};
    for (var i = 0; i < count; i++) {
      final stat = statKeys[rng.nextInt(statKeys.length)];
      out[stat] = (out[stat] ?? 0) + lo + rng.nextInt(hi - lo + 1);
    }
    return out;
  }

  static final statKeys = [for (final k in StatKind.values) k.name];

  /// 예전 키(지력 wisdom → 지능, 정신 spirit → 행운)도 읽는다
  static String statName(String key) => StatKindInfo.parse(key)?.label ?? key;

  // ───────────────────────── 강화

  static const int maxEnhance = 10;

  /// 강화 한 단계마다 기본 능력 +8%
  static const double enhanceStep = 0.08;

  /// +[to] 로 올릴 때 성공 확률
  static double enhanceChance(int to) => switch (to) {
        <= 3 => 1.0,
        4 => 0.9,
        5 => 0.8,
        6 => 0.7,
        7 => 0.6,
        8 => 0.5,
        9 => 0.4,
        _ => 0.3,
      };

  /// +[to] 로 올리는 비용 (마석 n, 금화 20n)
  static ({int manaStones, int gold}) enhanceCost(int to) =>
      (manaStones: to, gold: 20 * to);

  // ───────────────────────── 내구도

  static const int maxDurability = 100;
  static const int fieldWear = 1;
  static const int dungeonWear = 2;

  /// 깎인 내구도를 다 고치는 금화 (1에 0.5 × 등급 배수, 올림)
  static int repairCost(EquipItem item) {
    final lost = maxDurability - item.durability;
    if (lost <= 0) return 0;
    return (lost * 0.5 * repairMultiplier(item.grade)).ceil();
  }

  /// 분해하면 돌려받는 것: 넣은 재료의 절반(내림)과 마석 1, 강화에 쓴 마석의 절반
  static ({int manaStones, Map<MaterialId, int> materials}) salvage(
      EquipItem item) {
    final mats = <MaterialId, int>{};
    item.materialsUsed.forEach((k, v) {
      final id = Materials.byName(k);
      if (id != null && v ~/ 2 > 0) mats[id] = v ~/ 2;
    });
    return (manaStones: 1 + item.enhanceManaSpent ~/ 2, materials: mats);
  }

  // ───────────────────────── 능력

  /// 속성 부여 (11-11 #63): 빛나는 속성 코어 1개 + 금화 100
  static const int imbueGold = 100;

  static MaterialId imbueCore(Element e) => switch (e) {
        Element.fire => MaterialId.glowFireCore,
        Element.water => MaterialId.glowWaterCore,
        Element.wind => MaterialId.glowWindCore,
        Element.earth => MaterialId.glowEarthCore,
        Element.light => MaterialId.glowLightCore,
        Element.dark => MaterialId.glowShadowCore,
        Element.ice => MaterialId.glowIceCore,
        Element.thunder => MaterialId.glowThunderCore,
        Element.metal => MaterialId.glowMetalCore,
        Element.poison => MaterialId.glowPoisonCore,
      };

  /// 장비 하나의 배율 (등급·강화·내구도 반영)
  static double power(EquipItem item) {
    final m = gradeMultiplier(item.grade) * (1 + enhanceStep * item.enhance);
    return item.durability <= 0 ? m / 2 : m;
  }

  /// 입은 장비 모두의 힘
  static GearBonus bonusOf(Iterable<EquipItem> worn) {
    var atk = 0.0, red = 0.0, hp = 0.0, crit = 0.0, eva = 0.0;
    var faster = 0;
    var extra = Stats.zero;
    Element? atkEl;
    var atkLv = 0;
    final guards = <Element>{};
    final guardLv = <Element, int>{};
    for (final item in worn) {
      if (item.element != null) {
        if (item.slot == EquipSlot.weapon) {
          atkEl = item.element;
          atkLv = item.elementLevel;
        } else {
          guards.add(item.element!);
          final e = item.element!;
          if (item.elementLevel > (guardLv[e] ?? 0)) guardLv[e] = item.elementLevel;
        }
      }
      final base = EquipmentRules.info(item.base);
      final p = power(item);
      atk += base.attack * p;
      red += base.reduce * p;
      hp += base.maxHp * p;
      faster += base.skillFaster;
      crit += base.crit * p;
      eva += base.evade * p;
      final half = item.durability <= 0;
      item.extras.forEach((key, n) {
        final k = StatKindInfo.parse(key);
        if (k != null) extra = extra.withValue(k, extra.of(k) + (half ? n ~/ 2 : n));
      });
    }
    return GearBonus(
      attack: atk,
      reduce: math.min(0.6, red),
      maxHp: hp,
      skillFaster: faster,
      crit: crit,
      evade: eva,
      stats: extra,
      attackElement: atkEl,
      guardElements: guards,
      attackLevel: atkLv,
      guardLevels: guardLv,
      sets: SetBonus.of(worn),
    );
  }

  /// 장비 하나의 능력 글 (예: '공격 +9.2%')
  /// 장비 하나의 스탯 (11-11 묶음 13 A4: 스탯별로 보여 준다)
  static Map<StatKind, int> itemStats(EquipItem item) {
    final out = <StatKind, int>{};
    for (final e in item.extras.entries) {
      final k = StatKindInfo.parse(e.key);
      if (k != null) out[k] = (out[k] ?? 0) + e.value;
    }
    return out;
  }

  /// 스탯을 뺀 장비 능력 (공격·받는 피해·속성 …)
  static String itemEffectLabel(EquipItem item) =>
      itemStatLabel(item, withStats: false);

  static String itemStatLabel(EquipItem item, {bool withStats = true}) {
    final base = info(item.base);
    final p = power(item);
    return [
      if (base.attack > 0) '공격 +${_pct(base.attack * p)}%',
      if (base.reduce > 0) '받는 피해 -${_pct(base.reduce * p)}%',
      if (base.maxHp > 0) '최대 HP +${_pct(base.maxHp * p)}%',
      if (base.skillFaster > 0) '일격 충전 하나 빨리',
      if (base.crit > 0) '치명타 +${_pct(base.crit * p)}%p',
      if (base.evade > 0) '회피 +${_pct(base.evade * p)}%p',
      if (withStats)
        for (final e in item.extras.entries) '${statName(e.key)} +${e.value}',
      if (item.element != null)
        item.slot == EquipSlot.weapon
            ? '${item.element!.label} 속성 공격'
            : '${item.element!.label} 속성 방어',
    ].join(' · ');
  }
}
