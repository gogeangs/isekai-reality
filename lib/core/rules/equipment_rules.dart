import 'dart:math' as math;

import '../models/armory.dart';
import 'act3_rules.dart';
import 'baldrin_rules.dart';
import 'boss_gear_rules.dart';
import 'element_rules.dart';
import 'materials.dart';
import 'guild_rules.dart';
import 'region_rules.dart';
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
  // 묶음 19 첫 무기 5종: 검·도끼·창 기본형 (단검·지팡이와 함께)
  ironSword, woodAxe, ironSpear,
  // 묶음 34 2막: 「잿빛 왕의 유품」 (분신·본체를 처음 쓰러뜨리면)
  ashWeapon, ashCrown, ashBody, ashHands, ashFeet, ashAcc,
  // 묶음 50 #146: 「하이랜드 수호 기사」 (대장간 보스 장비 탭, 하늘 재료)
  skyWeapon, skyHead, skyBody, skyHands, skyFeet, skyAcc,
  // 묶음 42 #226: 마을 사람 4번째 부탁의 특별 보상 (대장간에서 만들 수 없다)
  martaScarf, seraBadge, garenBand,
  // 묶음 51 #242: 리안의 배낭 매듭 (걸을 때 기력이 조금 더 빨리 참)
  lianKnot,
  // 묶음 52 #243: 3막 지역 1 「발드린 문지기」 (저쪽 몬스터가 떨어뜨림, 만들 수 없음)
  baldrinWeapon, baldrinHead, baldrinBody, baldrinHands, baldrinFeet, baldrinAcc,
  // 묶음 53 #243: 지역 1 이름 있는 장비 셋 · 지역 무기 「관문의 빛 창」
  uniqVolkHelm, uniqTeoSpear, uniqWindPendant, baldrinSpear,
  // 묶음 56 #236: 파티 보스 세트 「동행」 (보스 재료로 대장간에서)
  partyWeapon, partyHead, partyBody, partyHands, partyFeet, partyAcc,
  // 묶음 57 #249: 플레이어 무기 「활」 (Lv.15부터 대장간 · 잡화상)
  bow,
  // 묶음 57 #243: 3막 지역 2~5 일반 장비 6부위 · 이름 있는 장비 3 · 지역 무기
  seleniaWeapon, seleniaHead, seleniaBody, seleniaHands, seleniaFeet, seleniaAcc,
  uniqGrumHammer, uniqBlackLantern, uniqStardustBoots, seleniaAxe,
  elowinWeapon, elowinHead, elowinBody, elowinHands, elowinFeet, elowinAcc,
  uniqMomoWreath, uniqArbelDagger, uniqElderHeart, elowinStaff,
  morvalWeapon, morvalHead, morvalBody, morvalHands, morvalFeet, morvalAcc,
  uniqLucyFlower, uniqKingCloak, uniqMoonFang, morvalSword,
  aurelWeapon, aurelHead, aurelBody, aurelHands, aurelFeet, aurelAcc,
  uniqTeoCloak, uniqNaomiStaff, uniqPhoenixCharm, aurelBow,
  // 묶음 59 #246: 길드 상점 「등불 수호단」 6부위
  lanternWeapon, lanternHead, lanternBody, lanternHands, lanternFeet, lanternAcc,
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
    this.speed = 0,
    this.trait,
    this.job,
    required this.asset,
  });

  /// 먼저 치기 (빠르기 비율, 숨김)
  final double speed;

  /// 첫 무기 고르기에서 보여 주는 성격 한 줄 (수치 대신)
  final String? trait;

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
        if (crit < 0) '치명타 조금 낮음',
        if (speed > 0) '먼저 침',
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
    this.speed = 0,
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

  /// 먼저 치기 (빠르기 비율)
  final double speed;

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
      trait: '가볍고 날렵하게 찔러요',
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
      trait: '스킬 게이지가 빨리 차올라요',
      job: '현자',
      asset: 'equip_staff',
    ),
    // 묶음 19 첫 무기: 장비 아이콘이 오기 전에는 전투용 무기 그림으로
    EquipBaseInfo(
      id: EquipBase.ironSword,
      name: '철 검',
      slot: EquipSlot.weapon,
      recipe: {MaterialId.ironShard: 3, MaterialId.ratHide: 1},
      manaStones: 3,
      attack: 0.08,
      trait: '고르게 잘 베어요',
      job: '기사',
      asset: 'equip_sword',
    ),
    EquipBaseInfo(
      id: EquipBase.woodAxe,
      name: '나무꾼 도끼',
      slot: EquipSlot.weapon,
      recipe: {MaterialId.ironShard: 2, MaterialId.twig: 2},
      manaStones: 3,
      attack: 0.10,
      crit: -0.03,
      trait: '느리지만 한 방이 세요',
      job: '기사',
      asset: 'equip_axe',
    ),
    EquipBaseInfo(
      id: EquipBase.ironSpear,
      name: '철 창',
      slot: EquipSlot.weapon,
      recipe: {MaterialId.ironShard: 2, MaterialId.twig: 1, MaterialId.ratHide: 1},
      manaStones: 3,
      attack: 0.07,
      speed: 0.15,
      trait: '길게 먼저 찔러요',
      job: '기사',
      asset: 'equip_spear',
    ),
    // 묶음 57 #249: 기본 활 (Lv.15부터)
    EquipBaseInfo(
      id: EquipBase.bow,
      name: '사냥 활',
      slot: EquipSlot.weapon,
      recipe: {MaterialId.twig: 2, MaterialId.ratHide: 1, MaterialId.ironShard: 1},
      manaStones: 3,
      attack: 0.07,
      crit: 0.04,
      trait: '멀리서 먼저 쏴요',
      job: '궁수',
      asset: 'weapon_bow',
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

  /// 묶음 57: 활은 Lv.15부터 대장간에 보임
  static const int bowLevel = 15;
  static bool shownAt(EquipBase b, int level) => b != EquipBase.bow || level >= bowLevel;

  static final Map<EquipBase, EquipBaseInfo> _byId = {
    for (final e in all) e.id: e,
    for (final e in BossGearRules.infos) e.id: e,
    for (final e in npcGear) e.id: e,
    for (final e in Act3Rules.gearInfos) e.id: e,
    for (final e in BaldrinRules.gearInfos) e.id: e,
    for (final e in RegionRules.gearInfos) e.id: e,
    for (final e in GuildRules.gearInfos) e.id: e,
  };

  /// 마을 사람 특별 보상 장비 (묶음 42 #226, 만들 수 없다)
  static const List<EquipBaseInfo> npcGear = [
    EquipBaseInfo(
      id: EquipBase.martaScarf,
      name: '마르타의 손뜨개 목도리',
      slot: EquipSlot.accessory,
      recipe: {},
      maxHp: 0.08,
      asset: 'equip_martaScarf',
    ),
    EquipBaseInfo(
      id: EquipBase.seraBadge,
      name: '세라의 휘장',
      slot: EquipSlot.accessory,
      recipe: {},
      attack: 0.04,
      reduce: 0.03,
      asset: 'equip_seraBadge',
    ),
    // 묶음 43 #228: 가렌의 훈련 완장 (공격 조금)
    EquipBaseInfo(
      id: EquipBase.garenBand,
      name: '가렌의 훈련 완장',
      slot: EquipSlot.accessory,
      recipe: {},
      attack: 0.05,
      asset: 'equip_garenBand',
    ),
    // 묶음 51 #242: 리안의 배낭 매듭 (효과는 걸을 때 기력, 숨은 값)
    EquipBaseInfo(
      id: EquipBase.lianKnot,
      name: '리안의 배낭 매듭',
      slot: EquipSlot.accessory,
      recipe: {},
      maxHp: 0.03,
      asset: 'equip_lianKnot',
    ),
  ];

  /// 마을 사람 특별 보상 장비인지
  static bool isNpcGear(EquipBase id) => npcGear.any((e) => e.id == id);

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
  /// [bonus] 가 있으면 그 값(%p)을 파랑에 더한다 (묶음 27 #176: 그 장비 종류의 대장일 숙련도).
  /// 없으면 예전 규칙(만든 장비 10개마다 +1%p)
  static List<double> gradeChances(
      {required bool rare, int crafts = 0, double? bonus}) {
    final c = rare
        ? [30.0, 40.0, 22.0, 6.5, 1.5]
        : [60.0, 28.0, 10.0, 1.8, 0.2];
    final mastery = bonus ?? math.min(10, crafts ~/ 10).toDouble();
    c[0] -= mastery;
    c[2] += mastery;
    return c;
  }

  static int masteryBonus(int crafts) => math.min(10, crafts ~/ 10);

  static EquipGrade rollGrade(math.Random rng,
      {required bool rare, int crafts = 0, double? bonus}) {
    final c = gradeChances(rare: rare, crafts: crafts, bonus: bonus);
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
    var atk = 0.0, red = 0.0, hp = 0.0, crit = 0.0, eva = 0.0, spd = 0.0;
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
      spd += base.speed;
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
      speed: spd,
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

  /// 묶음 40 #221: 새로 만들 장비(흰색 +0)와 지금 그 부위에 입은 장비의 비교 한 줄.
  /// 좋아지면 (true, '공격 +2%'), 나빠지면 (false, '공격 -1%'). 입은 게 없으면 빈 목록.
  static List<(bool, String)> compareWith(EquipBase base, EquipItem worn) {
    final a = info(base);
    final b = info(worn.base);
    final pa = gradeMultiplier(EquipGrade.white);
    final pb = power(worn);
    final out = <(bool, String)>[];
    void num(String label, double mine, double theirs, String unit,
        {bool lowerIsBetter = false}) {
      final d = ((mine - theirs) * 1000).round() / 1000;
      if (d.abs() < 0.0005) return;
      final up = d > 0;
      final v = _pct(d.abs());
      if (lowerIsBetter) {
        out.add((up, '$label ${up ? '-' : '+'}$v$unit'));
      } else {
        out.add((up, '$label ${up ? '+' : '-'}$v$unit'));
      }
    }

    num('공격', a.attack * pa, b.attack * pb, '%');
    num('받는 피해', a.reduce * pa, b.reduce * pb, '%', lowerIsBetter: true);
    num('최대 HP', a.maxHp * pa, b.maxHp * pb, '%');
    num('치명타', a.crit * (a.crit > 0 ? pa : 1), b.crit * (b.crit > 0 ? pb : 1), '%p');
    num('회피', a.evade * pa, b.evade * pb, '%p');
    if ((a.skillFaster > 0) != (b.skillFaster > 0)) {
      out.add(a.skillFaster > 0 ? (true, '일격 충전 빨리') : (false, '일격 충전 빨리 없음'));
    }
    if ((a.speed > 0) != (b.speed > 0)) {
      out.add(a.speed > 0 ? (true, '먼저 침') : (false, '먼저 치기 없음'));
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
