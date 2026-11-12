import 'materials.dart';
import 'monsters.dart';
import 'stat_rules.dart';
import 'element_rules.dart';
import 'town_rules.dart';

/// 물약 종류 (11-11 #57). 이름은 저장 키라 바꾸지 않는다.
enum PotionId {
  // 잡화상에도 있는 물약 (공방에서 만들면 같은 물건이 가방에)
  healSmall,
  manaSmall,
  heal,
  mana,
  spiritPotion,
  // 공방에서만
  healBig,
  antidote,
  burnSalve,
  clearEye,
  strength,
  agility,
  intellect,
  vitality,
  luck,
  resistFire,
  resistWater,
  resistWind,
  resistEarth,
  resistLight,
  resistDark,
  callMonsters,
  callModified,
  plenty,
  // 11-11 #63 새 속성 저항
  resistIce,
  resistThunder,
  resistMetal,
  resistPoison,
  // 11-11 #74 공격 속성 물약 10종 · 걸음 물약 · 녹이는 물약
  weaponFire,
  weaponWater,
  weaponWind,
  weaponEarth,
  weaponLight,
  weaponDark,
  weaponIce,
  weaponThunder,
  weaponMetal,
  weaponPoison,
  steps,
  thaw,
  // 11-11 C1 회복·MP 물약 3~5등급 (공방 레시피로만, 처음엔 숨김)
  heal3,
  heal4,
  heal5,
  mana3,
  mana4,
  mana5,
}

enum PotionKind { heal, mana, care, buff, resist, special, weapon }

/// 동시에 걸리는 물약 종류 (11-11 #74): 종류마다 하나씩
enum PotionSlot { battle, element, explore }

extension PotionSlotLabel on PotionSlot {
  String get label => switch (this) {
        PotionSlot.battle => '전투',
        PotionSlot.element => '속성',
        PotionSlot.explore => '탐험',
      };
}

/// 물약 품질 (11-11 #74). 판정 점수는 숨기고 등급만 보여 준다.
enum PotionQuality { normal, good, best }

extension PotionQualityInfo on PotionQuality {
  String get label => switch (this) {
        PotionQuality.normal => '보통',
        PotionQuality.good => '좋음',
        PotionQuality.best => '최상',
      };

  /// 가방 키 꼬리표 ('' · '*' · '**'). 예전 「완벽한 조제」('*')는 좋음.
  String get suffix => switch (this) {
        PotionQuality.normal => '',
        PotionQuality.good => '*',
        PotionQuality.best => '**',
      };

  /// 효과·지속 배율
  double get mult => switch (this) {
        PotionQuality.normal => 1,
        PotionQuality.good => 1.25,
        PotionQuality.best => 1.5,
      };
}

class PotionInfo {
  const PotionInfo({
    required this.id,
    required this.name,
    required this.kind,
    required this.description,
    required this.recipe,
    required this.minutes,
    this.yields = 1,
    this.public = false,
    this.shopItem,
    this.hpRatio = 0,
    this.mpRatio = 0,
    this.stat,
    this.element,
    this.duration = Duration.zero,
    this.battles = 0,
    this.steps = 0,
    this.icon,
  });

  /// 그림 이름을 따로 정한 물약 (등급 물약: potion_heal_3 등)
  final String? icon;

  /// 지속: 전투 N번 (전투·속성 물약, 11-11 #74)
  final int battles;

  /// 지속: N보 (걸음 물약)
  final int steps;

  /// 동시에 걸리는 종류 (바로 듣는 물약은 null)
  PotionSlot? get slot => switch (kind) {
        PotionKind.buff => PotionSlot.battle,
        PotionKind.resist || PotionKind.weapon => PotionSlot.element,
        _ => switch (id) {
            PotionId.steps || PotionId.callMonsters || PotionId.plenty =>
              PotionSlot.explore,
            _ => null,
          },
      };

  final PotionId id;
  final String name;
  final PotionKind kind;
  final String description;

  /// 재료 (완벽한 조제 순서). 같은 재료가 여러 번 나올 수 있다.
  final List<MaterialId> recipe;

  /// 끓이는 시간 (분)
  final int minutes;
  final int yields;

  /// 처음부터 레시피 책에 있는지 (작은 회복·작은 마나)
  final bool public;

  /// 잡화상 물건과 같은 물약이면 그 물건 (보통 조제는 그 물건으로 가방에)
  final ShopItem? shopItem;

  final double hpRatio;
  final double mpRatio;

  /// 버프 스탯 (+5)
  final StatKind? stat;

  /// 저항 속성 (-30%)
  final Element? element;

  /// 버프·저항·풍요 지속 시간
  final Duration duration;

  /// 잡화상에도 있는 물약은 잡화상 그림을 같이 쓴다
  String get asset => shopItem != null
      ? 'assets/images/${TownRules.info(shopItem!).icon}.webp'
      : icon != null
          ? 'assets/images/$icon.webp'
          : 'assets/images/potion_${id.name}.webp';

  /// 재료 종류·개수 (순서 없이)
  Map<MaterialId, int> get counts {
    final m = <MaterialId, int>{};
    for (final r in recipe) {
      m[r] = (m[r] ?? 0) + 1;
    }
    return m;
  }
}

/// 연금술 규칙 (제안서 3 확정 값)
class AlchemyRules {
  AlchemyRules._();

  /// 가마솥에 넣는 재료 최대 수
  static const int maxIngredients = 5;

  /// 완벽한 조제: 효과·지속 시간 +25% (11-11 #74부터 「좋음」 품질)
  static const double perfectBonus = 0.25;

  // ───────────── 11-11 #74 품질·지속 (숨은 규칙)

  /// 전투·속성 물약 지속 (보통)
  static const int battleCount = 5;

  /// 탐험 물약 지속 (보통)
  static const Duration exploreDuration = Duration(minutes: 30);

  /// 걸음 물약: 3,000보 동안 던전 게이지 1.5배
  static const int stepCap = 3000;
  static const double stepBoost = 0.5;

  /// 유인 물약: 채집 자리 1.5배
  static const double lureHarvest = 1.5;

  /// 독·불·얼음 공격 물약: 내 공격이 15%로 상태 이상
  static const double weaponInflict = 0.15;

  /// 품질 점수: 순서가 레시피와 같으면 +2, 귀한·가공 재료가 들어가면 +1,
  /// 연금술사 숙련도 +0~2 (직업 각성 전에는 0). 0~1 보통, 2 좋음, 3 이상 최상.
  static PotionQuality quality(
      {required bool perfect, required List<MaterialId> put, int mastery = 0}) {
    var score = mastery;
    if (perfect) score += 2;
    if (put.any((m) => Materials.info(m).rare || Materials.info(m).processed)) {
      score += 1;
    }
    return score >= 3
        ? PotionQuality.best
        : score == 2
            ? PotionQuality.good
            : PotionQuality.normal;
  }

  /// 가방 키 → 물약·품질 ('healBig**' → healBig, 최상). 수상한 물약은 null.
  static ({PotionId id, PotionQuality quality})? parseKey(String key) {
    if (key.startsWith('?:')) return null;
    var n = 0;
    while (n < key.length && key[key.length - 1 - n] == '*') {
      n++;
    }
    final id = byName(key.substring(0, key.length - n));
    if (id == null) return null;
    return (
      id: id,
      quality: n >= 2
          ? PotionQuality.best
          : n == 1
              ? PotionQuality.good
              : PotionQuality.normal
    );
  }

  static String keyOf(PotionId id, PotionQuality q) => '${id.name}${q.suffix}';

  /// 공격 속성 물약의 속성
  static PotionId weaponOf(Element e) => switch (e) {
        Element.fire => PotionId.weaponFire,
        Element.water => PotionId.weaponWater,
        Element.wind => PotionId.weaponWind,
        Element.earth => PotionId.weaponEarth,
        Element.light => PotionId.weaponLight,
        Element.dark => PotionId.weaponDark,
        Element.ice => PotionId.weaponIce,
        Element.thunder => PotionId.weaponThunder,
        Element.metal => PotionId.weaponMetal,
        Element.poison => PotionId.weaponPoison,
      };

  /// 수상한 물약: 10분, 1개
  static const int suspiciousMinutes = 10;

  /// 전투 한 번에 마실 수 있는 물약
  static const int perBattle = 3;

  /// 동시에 걸리는 버프·저항 (11-11 #74부터는 종류마다 하나: [PotionSlot])
  static const int maxBuffs = 1;
  static const int maxResists = 1;

  static const int buffStat = 5;
  static const double resistCut = 0.30;

  /// 가마솥: 처음 1개, 2번째 금화 500, 3번째 금화 1,500 + 미궁 석재 5
  static const int maxCauldrons = 3;
  static int? cauldronGold(int owned) => switch (owned) {
        1 => 500,
        2 => 1500,
        _ => null,
      };
  static int cauldronStone(int owned) => owned == 2 ? 5 : 0;

  /// 부르는 물약: 내 둘레 500m에 몬스터 5마리 (수식어 물약은 2마리, 희귀 이상 30%)
  static const double callRadiusM = 500;
  static const int callCount = 5;
  static const int callModCount = 2;
  static const double callModRareChance = 0.30;

  /// 레시피 쪽지 확률
  static const double noteFromErrand = 0.10;
  static const double noteFromDungeon = 0.08;
  static const double noteFromRare = 0.15;
  static const double noteFromLegend = 0.50;

  static PotionInfo info(PotionId id) => _byId[id]!;
  static final Map<PotionId, PotionInfo> _byId = {
    for (final p in all) p.id: p,
  };

  static PotionId? byName(String name) {
    for (final p in PotionId.values) {
      if (p.name == name) return p;
    }
    return null;
  }

  /// 속성 슬라임의 속성 (없으면 null)
  /// 몬스터의 속성 (무속성은 null). 11-11 #63부터 모든 몬스터에 속성이 있다.
  static Element? elementOf(MonsterId m) => Monsters.info(m).element;

  /// 넣은 재료(순서대로)로 무엇이 되는지. 맞는 레시피가 없으면 null (수상한 물약).
  static ({PotionId id, bool perfect})? match(List<MaterialId> put) {
    final counts = <MaterialId, int>{};
    for (final m in put) {
      counts[m] = (counts[m] ?? 0) + 1;
    }
    for (final p in all) {
      final c = p.counts;
      if (c.length != counts.length) continue;
      if (c.entries.every((e) => counts[e.key] == e.value)) {
        var same = p.recipe.length == put.length;
        for (var i = 0; same && i < put.length; i++) {
          if (p.recipe[i] != put[i]) same = false;
        }
        return (id: p.id, perfect: same);
      }
    }
    return null;
  }

  // ───────────── 수상한 물약: 재료 성질의 약한 효과

  /// 재료 성질: 스탯 (null 이면 HP)
  static StatKind? natureOf(MaterialId m) => switch (m) {
        MaterialId.fireJelly ||
        MaterialId.fireCore ||
        MaterialId.boarMeat ||
        MaterialId.smallTusk ||
        MaterialId.ironShard =>
          StatKind.strength,
        MaterialId.windJelly ||
        MaterialId.windCore ||
        MaterialId.batWing ||
        MaterialId.smallHorn =>
          StatKind.agility,
        MaterialId.darkJelly ||
        MaterialId.shadowCore ||
        MaterialId.butterflyDust ||
        MaterialId.sleepPowder ||
        MaterialId.slimeCore =>
          StatKind.intellect,
        MaterialId.mudJelly ||
        MaterialId.earthCore ||
        MaterialId.ratHide ||
        MaterialId.toughHide ||
        MaterialId.wardenShard =>
          StatKind.vitality,
        MaterialId.lightJelly ||
        MaterialId.lightCore ||
        MaterialId.glossyFur ||
        MaterialId.goldenRabbitFur ||
        MaterialId.labyrinthCore =>
          StatKind.luck,
        _ => null, // 물·약초·고기·젤리 → HP
      };

  /// 수상한 물약의 효과: (스탯, 값) 또는 (null, HP 비율 %). 가장 많이 넣은 성질, 같으면 먼저 넣은 것.
  static ({StatKind? stat, int amount}) suspiciousEffect(List<MaterialId> put) {
    final order = <String>[];
    final n = <String, int>{};
    for (final m in put) {
      final k = natureOf(m)?.name ?? 'hp';
      if (!n.containsKey(k)) order.add(k);
      n[k] = (n[k] ?? 0) + 1;
    }
    var best = order.first;
    for (final k in order) {
      if (n[k]! > n[best]!) best = k;
    }
    final count = n[best]!.clamp(1, 3);
    if (best == 'hp') return (stat: null, amount: 5 * count);
    return (
      stat: StatKind.values.firstWhere((s) => s.name == best),
      amount: count,
    );
  }

  static const Duration suspiciousDuration = Duration(minutes: 10);

  /// 같은 조합은 같은 키 (순서 무시)
  static String comboKey(List<MaterialId> put) {
    final names = [for (final m in put) m.name]..sort();
    return names.join('+');
  }

  // ───────────── 물약 목록

  static final List<PotionInfo> all = [
    PotionInfo(
      id: PotionId.healSmall,
      name: '작은 회복 물약',
      kind: PotionKind.heal,
      description: 'HP가 20% 차요.',
      recipe: [MaterialId.herb, MaterialId.herb, MaterialId.slimeJelly],
      minutes: 10,
      yields: 3,
      public: true,
      shopItem: ShopItem.healSmall,
      hpRatio: 0.2,
    ),
    PotionInfo(
      id: PotionId.manaSmall,
      name: '작은 마나 물약',
      kind: PotionKind.mana,
      description: 'MP가 20% 차요.',
      recipe: [MaterialId.waterJelly, MaterialId.herb, MaterialId.butterflyDust],
      minutes: 10,
      yields: 3,
      public: true,
      shopItem: ShopItem.manaSmall,
      mpRatio: 0.2,
    ),
    PotionInfo(
      id: PotionId.heal,
      name: '회복 물약',
      kind: PotionKind.heal,
      description: 'HP가 40% 차요.',
      recipe: [
        MaterialId.herb,
        MaterialId.herb,
        MaterialId.herb,
        MaterialId.slimeJelly,
        MaterialId.slimeJelly,
      ],
      minutes: 20,
      yields: 2,
      shopItem: ShopItem.heal,
      hpRatio: 0.4,
    ),
    PotionInfo(
      id: PotionId.mana,
      name: '마나 물약',
      kind: PotionKind.mana,
      description: 'MP가 40% 차요.',
      recipe: [
        MaterialId.waterJelly,
        MaterialId.waterJelly,
        MaterialId.butterflyDust,
        MaterialId.butterflyDust,
      ],
      minutes: 20,
      yields: 2,
      shopItem: ShopItem.mana,
      mpRatio: 0.4,
    ),
    PotionInfo(
      id: PotionId.spiritPotion,
      name: '정령 물약',
      kind: PotionKind.special,
      description: '정령 물약.',
      recipe: [MaterialId.lightJelly, MaterialId.herb, MaterialId.rabbitMeat],
      minutes: 30,
      shopItem: ShopItem.bulssiPotion,
    ),
    PotionInfo(
      id: PotionId.healBig,
      name: '큰 회복 물약',
      kind: PotionKind.heal,
      description: 'HP가 70% 차요.',
      recipe: [MaterialId.herbExtract, MaterialId.waterCore, MaterialId.essence],
      minutes: 60,
      hpRatio: 0.7,
    ),
    PotionInfo(
      id: PotionId.antidote,
      name: '해독제',
      kind: PotionKind.care,
      description: '중독을 풀고 3턴 동안 다시 걸리지 않아요.',
      recipe: [MaterialId.poisonGland, MaterialId.herb, MaterialId.herb],
      minutes: 20,
      yields: 2,
    ),
    PotionInfo(
      id: PotionId.burnSalve,
      name: '화상 연고',
      kind: PotionKind.care,
      description: '화상을 풀고 3턴 동안 다시 걸리지 않아요.',
      recipe: [
        MaterialId.mudJelly,
        MaterialId.waterJelly,
        MaterialId.waterJelly,
        MaterialId.herb,
      ],
      minutes: 20,
      yields: 2,
    ),
    PotionInfo(
      id: PotionId.clearEye,
      name: '맑은 눈 물약',
      kind: PotionKind.care,
      description: '그 전투 동안 눈부심에 빗나가지 않아요.',
      recipe: [MaterialId.waterJelly, MaterialId.lightJelly, MaterialId.herb],
      minutes: 20,
      yields: 2,
    ),
    PotionInfo(
      id: PotionId.strength,
      name: '힘의 물약',
      kind: PotionKind.buff,
      description: '전투 5번 동안 힘 +5.',
      recipe: [
        MaterialId.boarMeat,
        MaterialId.boarMeat,
        MaterialId.fireJelly,
        MaterialId.herb,
      ],
      minutes: 30,
      stat: StatKind.strength,
      battles: battleCount,
    ),
    PotionInfo(
      id: PotionId.agility,
      name: '민첩의 물약',
      kind: PotionKind.buff,
      description: '전투 5번 동안 민첩 +5.',
      recipe: [MaterialId.windJelly, MaterialId.windJelly, MaterialId.rabbitMeat],
      minutes: 30,
      stat: StatKind.agility,
      battles: battleCount,
    ),
    PotionInfo(
      id: PotionId.intellect,
      name: '지능의 물약',
      kind: PotionKind.buff,
      description: '전투 5번 동안 지능 +5.',
      recipe: [
        MaterialId.butterflyDust,
        MaterialId.butterflyDust,
        MaterialId.lightJelly,
      ],
      minutes: 30,
      stat: StatKind.intellect,
      battles: battleCount,
    ),
    PotionInfo(
      id: PotionId.vitality,
      name: '체력의 물약',
      kind: PotionKind.buff,
      description: '전투 5번 동안 체력 +5.',
      recipe: [
        MaterialId.toughHide,
        MaterialId.mudJelly,
        MaterialId.mudJelly,
        MaterialId.herb,
      ],
      minutes: 30,
      stat: StatKind.vitality,
      battles: battleCount,
    ),
    PotionInfo(
      id: PotionId.luck,
      name: '행운의 물약',
      kind: PotionKind.buff,
      description: '전투 5번 동안 행운 +5.',
      recipe: [MaterialId.goldenRabbitFur, MaterialId.lightJelly, MaterialId.herb],
      minutes: 60,
      stat: StatKind.luck,
      battles: battleCount,
    ),
    PotionInfo(
      id: PotionId.resistFire,
      name: '불꽃 저항 물약',
      kind: PotionKind.resist,
      description: '전투 5번 동안 불꽃 몬스터에게 받는 피해 -30%.',
      recipe: [
        MaterialId.fireCore,
        MaterialId.fireJelly,
        MaterialId.fireJelly,
        MaterialId.herb,
      ],
      minutes: 60,
      element: Element.fire,
      battles: battleCount,
    ),
    PotionInfo(
      id: PotionId.resistWater,
      name: '물 저항 물약',
      kind: PotionKind.resist,
      description: '전투 5번 동안 물 몬스터에게 받는 피해 -30%.',
      recipe: [
        MaterialId.waterCore,
        MaterialId.waterJelly,
        MaterialId.waterJelly,
        MaterialId.herb,
      ],
      minutes: 60,
      element: Element.water,
      battles: battleCount,
    ),
    PotionInfo(
      id: PotionId.resistWind,
      name: '바람 저항 물약',
      kind: PotionKind.resist,
      description: '전투 5번 동안 바람 몬스터에게 받는 피해 -30%.',
      recipe: [
        MaterialId.windCore,
        MaterialId.windJelly,
        MaterialId.windJelly,
        MaterialId.herb,
      ],
      minutes: 60,
      element: Element.wind,
      battles: battleCount,
    ),
    PotionInfo(
      id: PotionId.resistEarth,
      name: '대지 저항 물약',
      kind: PotionKind.resist,
      description: '전투 5번 동안 대지 몬스터에게 받는 피해 -30%.',
      recipe: [
        MaterialId.earthCore,
        MaterialId.mudJelly,
        MaterialId.mudJelly,
        MaterialId.herb,
      ],
      minutes: 60,
      element: Element.earth,
      battles: battleCount,
    ),
    PotionInfo(
      id: PotionId.resistLight,
      name: '빛 저항 물약',
      kind: PotionKind.resist,
      description: '전투 5번 동안 빛 몬스터에게 받는 피해 -30%.',
      recipe: [
        MaterialId.lightCore,
        MaterialId.lightJelly,
        MaterialId.lightJelly,
        MaterialId.herb,
      ],
      minutes: 60,
      element: Element.light,
      battles: battleCount,
    ),
    PotionInfo(
      id: PotionId.resistDark,
      name: '어둠 저항 물약',
      kind: PotionKind.resist,
      description: '전투 5번 동안 어둠 몬스터에게 받는 피해 -30%.',
      recipe: [
        MaterialId.shadowCore,
        MaterialId.darkJelly,
        MaterialId.darkJelly,
        MaterialId.herb,
      ],
      minutes: 60,
      element: Element.dark,
      battles: battleCount,
    ),
    PotionInfo(
      id: PotionId.resistIce,
      name: '얼음 저항 물약',
      kind: PotionKind.resist,
      description: '전투 5번 동안 얼음 몬스터에게 받는 피해 -30%.',
      recipe: [
        MaterialId.iceCore,
        MaterialId.iceJelly,
        MaterialId.iceJelly,
        MaterialId.herb,
      ],
      minutes: 60,
      element: Element.ice,
      battles: battleCount,
    ),
    PotionInfo(
      id: PotionId.resistThunder,
      name: '번개 저항 물약',
      kind: PotionKind.resist,
      description: '전투 5번 동안 번개 몬스터에게 받는 피해 -30%.',
      recipe: [
        MaterialId.thunderCore,
        MaterialId.thunderJelly,
        MaterialId.thunderJelly,
        MaterialId.herb,
      ],
      minutes: 60,
      element: Element.thunder,
      battles: battleCount,
    ),
    PotionInfo(
      id: PotionId.resistMetal,
      name: '금속 저항 물약',
      kind: PotionKind.resist,
      description: '전투 5번 동안 금속 몬스터에게 받는 피해 -30%.',
      recipe: [
        MaterialId.metalCore,
        MaterialId.metalJelly,
        MaterialId.metalJelly,
        MaterialId.herb,
      ],
      minutes: 60,
      element: Element.metal,
      battles: battleCount,
    ),
    PotionInfo(
      id: PotionId.resistPoison,
      name: '독 저항 물약',
      kind: PotionKind.resist,
      description: '전투 5번 동안 독 몬스터에게 받는 피해 -30%.',
      recipe: [
        MaterialId.poisonCore,
        MaterialId.poisonJelly,
        MaterialId.poisonJelly,
        MaterialId.herb,
      ],
      minutes: 60,
      element: Element.poison,
      battles: battleCount,
    ),
    PotionInfo(
      id: PotionId.callMonsters,
      name: '유인 물약',
      kind: PotionKind.special,
      description: '내 둘레 500m에 몬스터 5마리가 더 나오고 (하루 1번), '
          '30분 동안 주변 채집 자리가 1.5배로 늘어요.',
      recipe: [
        MaterialId.ratHide,
        MaterialId.darkJelly,
        MaterialId.darkJelly,
        MaterialId.sleepPowder,
      ],
      minutes: 60,
      duration: exploreDuration,
    ),
    PotionInfo(
      id: PotionId.callModified,
      name: '수식어 부르는 물약',
      kind: PotionKind.special,
      description: '내 둘레 500m에 수식어 몬스터 2마리가 나와요 (하루 1번).',
      recipe: [MaterialId.shadowCore, MaterialId.sleepPowder, MaterialId.essence],
      minutes: 60,
    ),
    PotionInfo(
      id: PotionId.plenty,
      name: '풍요의 물약',
      kind: PotionKind.special,
      description: '30분 동안 사냥할 때마다 재료 +1, 귀한 재료 확률 ×1.5.',
      recipe: [MaterialId.smallTusk, MaterialId.goldenRabbitFur, MaterialId.essence],
      minutes: 60,
      duration: exploreDuration,
    ),
    // ───────────── 11-11 #74
    for (final e in Element.values)
      PotionInfo(
        id: _weaponIds[e.index],
        name: '${e.label} 공격 물약',
        kind: PotionKind.weapon,
        description: '전투 5번 동안 내 공격에 ${e.label} 속성이 붙어요 (무기 속성보다 먼저).'
            '${e == Element.fire || e == Element.poison || e == Element.ice ? ' 가끔 몬스터를 ${e == Element.fire ? '불태워요' : e == Element.poison ? '중독시켜요' : '얼려요'}.' : ''}',
        recipe: [
          _stones[e.index],
          _jellies[e.index],
          _jellies[e.index],
          MaterialId.essence,
        ],
        minutes: 60,
        element: e,
        battles: battleCount,
      ),
    PotionInfo(
      id: PotionId.steps,
      name: '걸음 물약',
      kind: PotionKind.special,
      description: '3,000보를 걷는 동안 던전 게이지가 1.5배로 빨리 차요.',
      recipe: [
        MaterialId.herbExtract,
        MaterialId.windJelly,
        MaterialId.windJelly,
        MaterialId.rabbitMeat,
      ],
      minutes: 40,
      steps: stepCap,
    ),
    // ───────────── 11-11 C1 회복·MP 물약 3~5등급 (잡화상·던전 보상에는 없음)
    PotionInfo(
      id: PotionId.heal3,
      name: '치유의 물약',
      kind: PotionKind.heal,
      description: 'HP가 55% 차요.',
      recipe: [
        MaterialId.herbExtract,
        MaterialId.slimeJelly,
        MaterialId.slimeJelly,
        MaterialId.dewHerb,
      ],
      minutes: 40,
      yields: 2,
      hpRatio: 0.55,
      icon: 'potion_heal_3',
    ),
    PotionInfo(
      id: PotionId.heal4,
      name: '생명의 물약',
      kind: PotionKind.heal,
      description: 'HP가 85% 차요.',
      recipe: [
        MaterialId.herbExtract,
        MaterialId.essence,
        MaterialId.lightCore,
        MaterialId.riverPearl,
      ],
      minutes: 60,
      hpRatio: 0.85,
      icon: 'potion_heal_4',
    ),
    PotionInfo(
      id: PotionId.heal5,
      name: '여명의 물약',
      kind: PotionKind.heal,
      description: 'HP가 가득 차요. 여명의 탑의 빛을 담은 물약.',
      recipe: [
        MaterialId.herbExtract,
        MaterialId.essence,
        MaterialId.riverPearl,
        MaterialId.glowLightCore,
        MaterialId.labyrinthCore,
      ],
      minutes: 120,
      hpRatio: 1.0,
      icon: 'potion_heal_5',
    ),
    PotionInfo(
      id: PotionId.mana3,
      name: '맑은 마나 물약',
      kind: PotionKind.mana,
      description: 'MP가 55% 차요.',
      recipe: [
        MaterialId.essence,
        MaterialId.waterJelly,
        MaterialId.waterJelly,
        MaterialId.butterflyDust,
      ],
      minutes: 40,
      yields: 2,
      mpRatio: 0.55,
      icon: 'potion_mana_3',
    ),
    PotionInfo(
      id: PotionId.mana4,
      name: '깊은 마나 물약',
      kind: PotionKind.mana,
      description: 'MP가 85% 차요.',
      recipe: [
        MaterialId.essence,
        MaterialId.waterCore,
        MaterialId.sleepPowder,
        MaterialId.riverPearl,
      ],
      minutes: 60,
      mpRatio: 0.85,
      icon: 'potion_mana_4',
    ),
    PotionInfo(
      id: PotionId.mana5,
      name: '여명의 마나 물약',
      kind: PotionKind.mana,
      description: 'MP가 가득 차요. 여명의 탑의 빛을 담은 물약.',
      recipe: [
        MaterialId.essence,
        MaterialId.essence,
        MaterialId.riverPearl,
        MaterialId.glowWaterCore,
        MaterialId.labyrinthCore,
      ],
      minutes: 120,
      mpRatio: 1.0,
      icon: 'potion_mana_5',
    ),
    PotionInfo(
      id: PotionId.thaw,
      name: '녹이는 물약',
      kind: PotionKind.care,
      description: '빙결을 풀고 3턴 동안 다시 얼지 않아요.',
      recipe: [MaterialId.fireJelly, MaterialId.fireJelly, MaterialId.herb],
      minutes: 20,
      yields: 2,
    ),
  ];

  // 위 목록을 const 로 두려고 Element 순서대로 적는다
  static const _weaponIds = [
    PotionId.weaponFire,
    PotionId.weaponWater,
    PotionId.weaponWind,
    PotionId.weaponEarth,
    PotionId.weaponLight,
    PotionId.weaponDark,
    PotionId.weaponIce,
    PotionId.weaponThunder,
    PotionId.weaponMetal,
    PotionId.weaponPoison,
  ];
  static const _stones = [
    MaterialId.stoneFire,
    MaterialId.stoneWater,
    MaterialId.stoneWind,
    MaterialId.stoneEarth,
    MaterialId.stoneLight,
    MaterialId.stoneDark,
    MaterialId.stoneIce,
    MaterialId.stoneThunder,
    MaterialId.stoneMetal,
    MaterialId.stonePoison,
  ];
  static const _jellies = [
    MaterialId.fireJelly,
    MaterialId.waterJelly,
    MaterialId.windJelly,
    MaterialId.mudJelly,
    MaterialId.lightJelly,
    MaterialId.darkJelly,
    MaterialId.iceJelly,
    MaterialId.thunderJelly,
    MaterialId.metalJelly,
    MaterialId.poisonJelly,
  ];
}
