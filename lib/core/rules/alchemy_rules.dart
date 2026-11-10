import 'materials.dart';
import 'monsters.dart';
import 'stat_rules.dart';
import 'town_rules.dart';

/// 속성 (저항 물약, 속성 슬라임의 공격)
enum Element { fire, water, wind, earth, light, dark }

extension ElementName on Element {
  String get label => switch (this) {
        Element.fire => '불꽃',
        Element.water => '물',
        Element.wind => '바람',
        Element.earth => '대지',
        Element.light => '빛',
        Element.dark => '어둠',
      };
}

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
}

enum PotionKind { heal, mana, care, buff, resist, special }

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
  });

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

  String get asset => 'assets/images/potion_${id.name}.png';

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

  /// 완벽한 조제: 효과·지속 시간 +25%
  static const double perfectBonus = 0.25;

  /// 수상한 물약: 10분, 1개
  static const int suspiciousMinutes = 10;

  /// 전투 한 번에 마실 수 있는 물약
  static const int perBattle = 3;

  /// 동시에 걸리는 버프·저항
  static const int maxBuffs = 2;
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
  static Element? elementOf(MonsterId m) => switch (m) {
        MonsterId.fireSlime => Element.fire,
        MonsterId.waterSlime => Element.water,
        MonsterId.windSlime => Element.wind,
        MonsterId.earthSlime => Element.earth,
        MonsterId.lightSlime => Element.light,
        MonsterId.darkSlime => Element.dark,
        _ => null,
      };

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

  static const _thirty = Duration(minutes: 30);
  static const _hour = Duration(hours: 1);

  static const List<PotionInfo> all = [
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
      description: '정령 물약 (정령이 떠난 뒤에는 펫 간식).',
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
      description: '30분 동안 힘 +5.',
      recipe: [
        MaterialId.boarMeat,
        MaterialId.boarMeat,
        MaterialId.fireJelly,
        MaterialId.herb,
      ],
      minutes: 30,
      stat: StatKind.strength,
      duration: _thirty,
    ),
    PotionInfo(
      id: PotionId.agility,
      name: '민첩의 물약',
      kind: PotionKind.buff,
      description: '30분 동안 민첩 +5.',
      recipe: [MaterialId.windJelly, MaterialId.windJelly, MaterialId.rabbitMeat],
      minutes: 30,
      stat: StatKind.agility,
      duration: _thirty,
    ),
    PotionInfo(
      id: PotionId.intellect,
      name: '지능의 물약',
      kind: PotionKind.buff,
      description: '30분 동안 지능 +5.',
      recipe: [
        MaterialId.butterflyDust,
        MaterialId.butterflyDust,
        MaterialId.lightJelly,
      ],
      minutes: 30,
      stat: StatKind.intellect,
      duration: _thirty,
    ),
    PotionInfo(
      id: PotionId.vitality,
      name: '체력의 물약',
      kind: PotionKind.buff,
      description: '30분 동안 체력 +5.',
      recipe: [
        MaterialId.toughHide,
        MaterialId.mudJelly,
        MaterialId.mudJelly,
        MaterialId.herb,
      ],
      minutes: 30,
      stat: StatKind.vitality,
      duration: _thirty,
    ),
    PotionInfo(
      id: PotionId.luck,
      name: '행운의 물약',
      kind: PotionKind.buff,
      description: '30분 동안 행운 +5.',
      recipe: [MaterialId.goldenRabbitFur, MaterialId.lightJelly, MaterialId.herb],
      minutes: 60,
      stat: StatKind.luck,
      duration: _thirty,
    ),
    PotionInfo(
      id: PotionId.resistFire,
      name: '불꽃 저항 물약',
      kind: PotionKind.resist,
      description: '30분 동안 불꽃 몬스터에게 받는 피해 -30%.',
      recipe: [
        MaterialId.fireCore,
        MaterialId.fireJelly,
        MaterialId.fireJelly,
        MaterialId.herb,
      ],
      minutes: 60,
      element: Element.fire,
      duration: _thirty,
    ),
    PotionInfo(
      id: PotionId.resistWater,
      name: '물 저항 물약',
      kind: PotionKind.resist,
      description: '30분 동안 물 몬스터에게 받는 피해 -30%.',
      recipe: [
        MaterialId.waterCore,
        MaterialId.waterJelly,
        MaterialId.waterJelly,
        MaterialId.herb,
      ],
      minutes: 60,
      element: Element.water,
      duration: _thirty,
    ),
    PotionInfo(
      id: PotionId.resistWind,
      name: '바람 저항 물약',
      kind: PotionKind.resist,
      description: '30분 동안 바람 몬스터에게 받는 피해 -30%.',
      recipe: [
        MaterialId.windCore,
        MaterialId.windJelly,
        MaterialId.windJelly,
        MaterialId.herb,
      ],
      minutes: 60,
      element: Element.wind,
      duration: _thirty,
    ),
    PotionInfo(
      id: PotionId.resistEarth,
      name: '대지 저항 물약',
      kind: PotionKind.resist,
      description: '30분 동안 대지 몬스터에게 받는 피해 -30%.',
      recipe: [
        MaterialId.earthCore,
        MaterialId.mudJelly,
        MaterialId.mudJelly,
        MaterialId.herb,
      ],
      minutes: 60,
      element: Element.earth,
      duration: _thirty,
    ),
    PotionInfo(
      id: PotionId.resistLight,
      name: '빛 저항 물약',
      kind: PotionKind.resist,
      description: '30분 동안 빛 몬스터에게 받는 피해 -30%.',
      recipe: [
        MaterialId.lightCore,
        MaterialId.lightJelly,
        MaterialId.lightJelly,
        MaterialId.herb,
      ],
      minutes: 60,
      element: Element.light,
      duration: _thirty,
    ),
    PotionInfo(
      id: PotionId.resistDark,
      name: '어둠 저항 물약',
      kind: PotionKind.resist,
      description: '30분 동안 어둠 몬스터에게 받는 피해 -30%.',
      recipe: [
        MaterialId.shadowCore,
        MaterialId.darkJelly,
        MaterialId.darkJelly,
        MaterialId.herb,
      ],
      minutes: 60,
      element: Element.dark,
      duration: _thirty,
    ),
    PotionInfo(
      id: PotionId.callMonsters,
      name: '부르는 물약',
      kind: PotionKind.special,
      description: '내 둘레 500m에 몬스터 5마리가 더 나와요 (하루 1번).',
      recipe: [
        MaterialId.ratHide,
        MaterialId.darkJelly,
        MaterialId.darkJelly,
        MaterialId.sleepPowder,
      ],
      minutes: 60,
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
      description: '1시간 동안 사냥할 때마다 재료 +1, 귀한 재료 확률 ×1.5.',
      recipe: [MaterialId.smallTusk, MaterialId.goldenRabbitFur, MaterialId.essence],
      minutes: 60,
      duration: _hour,
    ),
  ];
}
