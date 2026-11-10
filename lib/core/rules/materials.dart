import 'dart:math' as math;

import 'monsters.dart';

/// 몬스터가 떨어뜨리거나 잡화상에서 사는 재료 (11-10 #20, 대장간 제작에 쓴다).
/// 이름은 저장된 기록의 키라 바꾸지 않는다.
enum MaterialId {
  slimeJelly,
  slimeCore,
  ratHide,
  glossyFur,
  batWing,
  batFang,
  butterflyDust,
  sleepPowder,
  wardenShard,
  labyrinthCore,
  ironShard,
  twig,
  poisonGland,
  // 11-11 #31·#40·#35
  rabbitMeat,
  smallHorn,
  goldenRabbitFur,
  boarMeat,
  toughHide,
  smallTusk,
  fireJelly,
  fireCore,
  waterJelly,
  waterCore,
  windJelly,
  windCore,
  mudJelly,
  earthCore,
  lightJelly,
  lightCore,
  darkJelly,
  shadowCore,
  herb,
}

class MaterialInfo {
  const MaterialInfo(this.id, this.name, this.description, {this.rare = false});

  final MaterialId id;
  final String name;
  final String description;

  /// 귀한 재료: 제작할 때 하나 더 넣으면 좋은 등급이 잘 나온다
  final bool rare;

  /// assets/images/<asset>.png (그림이 없으면 아이콘으로 대신)
  String get asset => 'assets/images/mat_${id.name}.png';
}

/// 지갑의 키: 마석·금화 (재료는 [MaterialId] 이름)
class Wallet {
  Wallet._();
  static const manaStone = 'manaStone';
  static const gold = 'gold';

  /// 수식어·속성 몬스터로 더 받은 경험치 (11-11)
  static const exp = 'exp';
}

class Materials {
  Materials._();

  static const List<MaterialInfo> all = [
    MaterialInfo(MaterialId.slimeJelly, '슬라임 젤리', '말랑한 젤리. 장갑·장화를 만들 때 써요.'),
    MaterialInfo(MaterialId.slimeCore, '슬라임 코어', '슬라임 속의 단단한 구슬.', rare: true),
    MaterialInfo(MaterialId.ratHide, '쥐 가죽', '질긴 가죽. 가죽 장비의 기본 재료예요.'),
    MaterialInfo(MaterialId.glossyFur, '윤기 나는 쥐털', '반들반들 빛나는 털.', rare: true),
    MaterialInfo(MaterialId.batWing, '박쥐 날개', '얇고 가벼운 날개. 갑옷·목걸이에 써요.'),
    MaterialInfo(MaterialId.batFang, '박쥐 송곳니', '뾰족한 송곳니.', rare: true),
    MaterialInfo(MaterialId.butterflyDust, '나비 비늘가루', '반짝이는 가루. 지팡이에 써요.'),
    MaterialInfo(MaterialId.sleepPowder, '잠의 가루', '맡으면 졸음이 오는 가루.', rare: true),
    MaterialInfo(MaterialId.wardenShard, '문지기의 돌조각', '미궁 문지기의 몸에서 떨어진 돌.'),
    MaterialInfo(MaterialId.labyrinthCore, '미궁 핵', '미궁의 힘이 뭉친 결정.', rare: true),
    MaterialInfo(MaterialId.ironShard, '철 조각', '무기를 만들 때 써요. 잡화상에서 팔아요.'),
    MaterialInfo(MaterialId.twig, '나뭇가지', '지팡이를 만들 때 써요. 잡화상에서 팔아요.'),
    MaterialInfo(MaterialId.poisonGland, '독샘', '독을 품은 몬스터에게서 나와요.', rare: true),
    MaterialInfo(MaterialId.rabbitMeat, '토끼 고기', '혼래빗 고기. 나중에 요리에 써요.'),
    MaterialInfo(MaterialId.smallHorn, '작은 뿔', '혼래빗의 뿔. 뿔 단검을 만들어요.'),
    MaterialInfo(MaterialId.goldenRabbitFur, '황금빛 토끼털', '금빛으로 반짝이는 털.', rare: true),
    MaterialInfo(MaterialId.boarMeat, '멧돼지 고기', '아기 와일드 보어 고기. 나중에 요리에 써요.'),
    MaterialInfo(MaterialId.toughHide, '질긴 가죽', '멧돼지의 두꺼운 가죽. 갑옷에 좋아요.'),
    MaterialInfo(MaterialId.smallTusk, '작은 엄니', '멧돼지의 엄니.', rare: true),
    MaterialInfo(MaterialId.fireJelly, '불꽃 젤리', '따끈한 젤리. 모아 두는 재료예요.'),
    MaterialInfo(MaterialId.fireCore, '불꽃 코어', '불꽃 슬라임의 코어.', rare: true),
    MaterialInfo(MaterialId.waterJelly, '물 젤리', '촉촉한 젤리. 모아 두는 재료예요.'),
    MaterialInfo(MaterialId.waterCore, '물방울 코어', '물 슬라임의 코어.', rare: true),
    MaterialInfo(MaterialId.windJelly, '바람 젤리', '가벼운 젤리. 모아 두는 재료예요.'),
    MaterialInfo(MaterialId.windCore, '바람 코어', '바람 슬라임의 코어.', rare: true),
    MaterialInfo(MaterialId.mudJelly, '진흙 젤리', '묵직한 젤리. 모아 두는 재료예요.'),
    MaterialInfo(MaterialId.earthCore, '대지 코어', '대지 슬라임의 코어.', rare: true),
    MaterialInfo(MaterialId.lightJelly, '빛 젤리', '반짝이는 젤리. 모아 두는 재료예요.'),
    MaterialInfo(MaterialId.lightCore, '빛의 코어', '빛 슬라임의 코어.', rare: true),
    MaterialInfo(MaterialId.darkJelly, '어둠 젤리', '그림자 같은 젤리. 모아 두는 재료예요.'),
    MaterialInfo(MaterialId.shadowCore, '그림자 코어', '어둠 슬라임의 코어.', rare: true),
    MaterialInfo(MaterialId.herb, '약초', '회복 물약 재료. 잡화상에서 팔아요.'),
  ];

  static MaterialInfo info(MaterialId id) => all.firstWhere((m) => m.id == id);

  static MaterialId? byName(String name) {
    for (final m in MaterialId.values) {
      if (m.name == name) return m;
    }
    return null;
  }

  /// 귀한 재료 (제작에 더 넣을 수 있는 것)
  static List<MaterialId> get rares => [
        for (final m in all)
          if (m.rare) m.id,
      ];
}

/// 사냥 보상 (결과 화면에 보여 준다)
class HuntReward {
  const HuntReward({
    this.exp = 0,
    this.manaStones = 0,
    this.gold = 0,
    this.materials = const {},
  });

  final int exp;
  final int manaStones;
  final int gold;
  final Map<MaterialId, int> materials;

  bool get isEmpty =>
      exp == 0 && manaStones == 0 && gold == 0 && materials.isEmpty;

  /// '마석 +1 · 슬라임 젤리 +1' 처럼 (경험치 빼고)
  String get itemsLabel => [
        if (manaStones > 0) '마석 +$manaStones',
        if (gold > 0) '금화 +$gold',
        for (final e in materials.entries)
          '${Materials.info(e.key).name} +${e.value}',
      ].join(' · ');

  /// 기록에 더할 지갑 변화 (마석은 규칙으로 계산하는 몫을 뺀 '추가'만)
  static Map<String, int> ledger(
      {int extraManaStones = 0, int gold = 0, Map<MaterialId, int>? materials}) {
    return {
      if (extraManaStones > 0) Wallet.manaStone: extraManaStones,
      if (gold > 0) Wallet.gold: gold,
      for (final e in (materials ?? const {}).entries)
        if (e.value > 0) e.key.name: e.value,
    };
  }
}

/// 몬스터가 떨어뜨리는 재료 (제안서 1장, 11-10 확정)
class LootRules {
  LootRules._();

  /// 귀한 재료가 나올 확률
  static const double rareChance = 0.10;

  /// 몬스터마다 재료(둘이면 반반 중 하나), 귀한 재료, 귀한 재료 확률
  static ({List<MaterialId> common, MaterialId rare, double chance}) dropsOf(
          MonsterId m) =>
      switch (m) {
        MonsterId.ashSlime =>
          (common: [MaterialId.slimeJelly], rare: MaterialId.slimeCore, chance: rareChance),
        MonsterId.fireSlime =>
          (common: [MaterialId.fireJelly], rare: MaterialId.fireCore, chance: rareChance),
        MonsterId.waterSlime =>
          (common: [MaterialId.waterJelly], rare: MaterialId.waterCore, chance: rareChance),
        MonsterId.windSlime =>
          (common: [MaterialId.windJelly], rare: MaterialId.windCore, chance: rareChance),
        MonsterId.earthSlime =>
          (common: [MaterialId.mudJelly], rare: MaterialId.earthCore, chance: rareChance),
        MonsterId.lightSlime =>
          (common: [MaterialId.lightJelly], rare: MaterialId.lightCore, chance: 0.15),
        MonsterId.darkSlime =>
          (common: [MaterialId.darkJelly], rare: MaterialId.shadowCore, chance: 0.15),
        MonsterId.giantRat =>
          (common: [MaterialId.ratHide], rare: MaterialId.glossyFur, chance: rareChance),
        MonsterId.hornRabbit => (
            common: [MaterialId.rabbitMeat, MaterialId.smallHorn],
            rare: MaterialId.goldenRabbitFur,
            chance: rareChance
          ),
        MonsterId.babyBoar => (
            common: [MaterialId.boarMeat, MaterialId.toughHide],
            rare: MaterialId.smallTusk,
            chance: rareChance
          ),
        MonsterId.labyrinthBat =>
          (common: [MaterialId.batWing], rare: MaterialId.batFang, chance: rareChance),
        MonsterId.shadowButterfly => (
            common: [MaterialId.butterflyDust],
            rare: MaterialId.sleepPowder,
            chance: rareChance
          ),
        MonsterId.labyrinthWarden => (
            common: [MaterialId.wardenShard],
            rare: MaterialId.labyrinthCore,
            chance: rareChance
          ),
        // 예전 정령 몬스터 (지금은 나오지 않음)
        MonsterId.roughWaterSpirit || MonsterId.lostStoneSpirit =>
          (common: [MaterialId.slimeJelly], rare: MaterialId.slimeCore, chance: rareChance),
      };

  /// 필드 몬스터 한 마리: 그 몬스터 재료 1 (+귀한 재료). [rareBonus] 는 행운 보너스.
  static Map<MaterialId, int> field(MonsterId m, math.Random rng,
      {double rareBonus = 0}) {
    final d = dropsOf(m);
    final common = d.common[rng.nextInt(d.common.length)];
    return {
      common: 1,
      if (rng.nextDouble() < d.chance + rareBonus) d.rare: 1,
    };
  }

  /// 던전 한 번: 클리어 박쥐 날개 2 + 문지기의 돌조각 1 (+미궁 핵 10%, 박쥐 송곳니 10%),
  /// 실패 박쥐 날개 1
  static Map<MaterialId, int> dungeon(
      {required bool cleared, required math.Random rng}) {
    if (!cleared) return {MaterialId.batWing: 1};
    return {
      MaterialId.batWing: 2,
      MaterialId.wardenShard: 1,
      if (rng.nextDouble() < rareChance) MaterialId.labyrinthCore: 1,
      if (rng.nextDouble() < rareChance) MaterialId.batFang: 1,
    };
  }
}
