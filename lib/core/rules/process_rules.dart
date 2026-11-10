import 'materials.dart';

/// 재료 가공 하나 (11-11 #59)
class ProcessRecipe {
  const ProcessRecipe({
    required this.id,
    required this.output,
    required this.inputs,
    required this.gold,
    required this.label,
    this.smithy = false,
    this.anyOf = const [],
    this.anyCount = 0,
    this.count = 1,
  });

  /// 만들어지는 개수
  final int count;

  final String id;
  final MaterialId output;

  /// 정해진 재료 (재료 → 개수)
  final Map<MaterialId, int> inputs;

  /// 「아무거나」 재료 (젤리 아무거나 5개)
  final List<MaterialId> anyOf;
  final int anyCount;

  final int gold;
  final String label;

  /// 대장간 가공이면 true, 공방 가공이면 false
  final bool smithy;
}

class ProcessRules {
  ProcessRules._();

  static const jellies = [
    MaterialId.slimeJelly,
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

  static const List<ProcessRecipe> all = [
    ProcessRecipe(
        id: 'ingot',
        output: MaterialId.ironIngot,
        inputs: {MaterialId.ironShard: 3},
        gold: 10,
        label: '철 조각 3 + 금화 10',
        smithy: true),
    ProcessRecipe(
        id: 'wood',
        output: MaterialId.hardWood,
        inputs: {MaterialId.twig: 4},
        gold: 10,
        label: '나뭇가지 4 + 금화 10',
        smithy: true),
    ProcessRecipe(
        id: 'leatherRat',
        output: MaterialId.tannedLeather,
        inputs: {MaterialId.ratHide: 3},
        gold: 10,
        label: '쥐 가죽 3 + 금화 10',
        smithy: true),
    ProcessRecipe(
        id: 'leatherBoar',
        output: MaterialId.tannedLeather,
        inputs: {MaterialId.toughHide: 2},
        gold: 10,
        label: '질긴 가죽 2 + 금화 10',
        smithy: true),
    ProcessRecipe(
        id: 'extract',
        output: MaterialId.herbExtract,
        inputs: {MaterialId.herb: 5},
        gold: 10,
        label: '약초 5 + 금화 10'),
    ProcessRecipe(
        id: 'essence',
        output: MaterialId.essence,
        inputs: {},
        anyOf: jellies,
        anyCount: 5,
        gold: 20,
        label: '젤리 아무거나 5 (많은 것부터) + 금화 20'),
    ProcessRecipe(
        id: 'glowFire',
        output: MaterialId.glowFireCore,
        inputs: {MaterialId.fireCore: 3},
        gold: 50,
        label: '불꽃 코어 3 + 금화 50'),
    ProcessRecipe(
        id: 'glowWater',
        output: MaterialId.glowWaterCore,
        inputs: {MaterialId.waterCore: 3},
        gold: 50,
        label: '물방울 코어 3 + 금화 50'),
    ProcessRecipe(
        id: 'glowWind',
        output: MaterialId.glowWindCore,
        inputs: {MaterialId.windCore: 3},
        gold: 50,
        label: '바람 코어 3 + 금화 50'),
    ProcessRecipe(
        id: 'glowEarth',
        output: MaterialId.glowEarthCore,
        inputs: {MaterialId.earthCore: 3},
        gold: 50,
        label: '대지 코어 3 + 금화 50'),
    ProcessRecipe(
        id: 'glowLight',
        output: MaterialId.glowLightCore,
        inputs: {MaterialId.lightCore: 3},
        gold: 50,
        label: '빛의 코어 3 + 금화 50'),
    ProcessRecipe(
        id: 'glowShadow',
        output: MaterialId.glowShadowCore,
        inputs: {MaterialId.shadowCore: 3},
        gold: 50,
        label: '그림자 코어 3 + 금화 50'),
    // 11-11 #56 채집 귀한 재료 → 가공 재료 2개
    ProcessRecipe(
        id: 'manaOre',
        output: MaterialId.ironIngot,
        inputs: {MaterialId.manaOre: 1},
        gold: 10,
        count: 2,
        smithy: true,
        label: '마력 광석 1 + 금화 10 → 철 주괴 2'),
    ProcessRecipe(
        id: 'sturdyKnot',
        output: MaterialId.hardWood,
        inputs: {MaterialId.sturdyKnot: 1},
        gold: 10,
        count: 2,
        smithy: true,
        label: '튼튼한 옹이 1 + 금화 10 → 단단한 목재 2'),
    ProcessRecipe(
        id: 'dewHerb',
        output: MaterialId.herbExtract,
        inputs: {MaterialId.dewHerb: 1},
        gold: 10,
        count: 2,
        label: '이슬 맺힌 약초 1 + 금화 10 → 약초 진액 2'),
    ProcessRecipe(
        id: 'riverPearl',
        output: MaterialId.essence,
        inputs: {MaterialId.riverPearl: 1},
        gold: 10,
        count: 2,
        label: '강의 진주 1 + 금화 10 → 정제 에센스 2'),
    ProcessRecipe(
        id: 'glowIce',
        output: MaterialId.glowIceCore,
        inputs: {MaterialId.iceCore: 3},
        gold: 50,
        label: '얼음 코어 3 + 금화 50'),
    ProcessRecipe(
        id: 'glowThunder',
        output: MaterialId.glowThunderCore,
        inputs: {MaterialId.thunderCore: 3},
        gold: 50,
        label: '번개 코어 3 + 금화 50'),
    ProcessRecipe(
        id: 'glowMetal',
        output: MaterialId.glowMetalCore,
        inputs: {MaterialId.metalCore: 3},
        gold: 50,
        label: '금속 코어 3 + 금화 50'),
    ProcessRecipe(
        id: 'glowPoison',
        output: MaterialId.glowPoisonCore,
        inputs: {MaterialId.poisonCore: 3},
        gold: 50,
        label: '독 코어 3 + 금화 50'),
  ];

  /// 가진 재료로 쓸 것 (아무거나 재료는 많은 것부터). 모자라면 null.
  static Map<MaterialId, int>? use(
      ProcessRecipe r, Map<MaterialId, int> have) {
    for (final e in r.inputs.entries) {
      if ((have[e.key] ?? 0) < e.value) return null;
    }
    final out = {...r.inputs};
    if (r.anyCount > 0) {
      final pool = [
        for (final m in r.anyOf)
          if ((have[m] ?? 0) > 0) m,
      ]..sort((a, b) => (have[b] ?? 0).compareTo(have[a] ?? 0));
      var need = r.anyCount;
      for (final m in pool) {
        if (need <= 0) break;
        final take = (have[m]! < need) ? have[m]! : need;
        out[m] = (out[m] ?? 0) + take;
        need -= take;
      }
      if (need > 0) return null;
    }
    return out;
  }
}
