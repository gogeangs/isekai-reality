import 'alchemy_rules.dart';
import 'element_rules.dart';
import 'materials.dart';
import 'monsters.dart';

/// 공방 변환 종류 (11-11 #74, 제안서 5 확정)
enum ConvertKind { upgrade, exchange, refine, decompose }

extension ConvertKindLabel on ConvertKind {
  String get label => switch (this) {
        ConvertKind.upgrade => '상위 변환',
        ConvertKind.exchange => '같은 등급 교환',
        ConvertKind.refine => '마석 정제',
        ConvertKind.decompose => '분해',
      };
}

/// 변환 하나: 넣는 것 → 나오는 것, 금화, 걸리는 시간
class ConvertPlan {
  const ConvertPlan({
    required this.kind,
    required this.give,
    required this.get,
    this.giveManaStones = 0,
    this.getManaStones = 0,
    this.gold = 0,
    this.minutes = 0,
    this.givePotion,
  });

  final ConvertKind kind;
  final Map<MaterialId, int> give;
  final Map<MaterialId, int> get;
  final int giveManaStones;
  final int getManaStones;
  final int gold;

  /// 0이면 바로 끝난다 (분해)
  final int minutes;

  /// 분해하는 공방 물약 키
  final String? givePotion;
}

/// 공방 변환 규칙 (누구나, 금화와 시간이 든다)
class ConvertRules {
  ConvertRules._();

  /// 상위 변환: 같은 재료 3 → 그 몬스터의 귀한 재료 1 (금화 10, 10분)
  static const int upgradeCount = 3;
  static const int upgradeGold = 10;
  static const int upgradeMinutes = 10;

  /// 같은 등급 교환: 2 → 고른 것 1 (일반 금화 10·5분, 귀한 금화 30·15분)
  static const int exchangeCount = 2;
  static const int exchangeGoldCommon = 10;
  static const int exchangeGoldRare = 30;
  static const int exchangeMinutesCommon = 5;
  static const int exchangeMinutesRare = 15;

  /// 마석 정제: 마석 3 + 그 속성 코어 1 → 속성 마석 1 (금화 20, 20분)
  static const int refineManaStones = 3;
  static const int refineGold = 20;
  static const int refineMinutes = 20;

  /// 분해: 물약 1 → 약초 1 (좋음·최상은 마석 1 더), 귀한 재료 1 → 마석 2,
  /// 일반 재료 5 → 마석 1. 금화 없이 바로.
  static const int decomposeCommonCount = 5;
  static const int decomposeRareStones = 2;

  /// 연금술사 우대 (직업 각성 뒤 열림): 상위 변환 3 → 2, 20%로 1개 더, 시간 절반
  static const int alchemistUpgradeCount = 2;
  static const double alchemistBonusChance = 0.20;
  static const double alchemistTime = 0.5;

  /// 몬스터가 떨어뜨리는 일반 재료 → 그 몬스터의 귀한 재료
  static final Map<MaterialId, MaterialId> upgradeMap = () {
    final m = <MaterialId, MaterialId>{};
    for (final id in MonsterId.values) {
      final d = LootRules.dropsOf(id);
      for (final c in d.common) {
        m.putIfAbsent(c, () => d.rare);
      }
    }
    return m;
  }();

  /// 교환할 수 있는 일반 재료·귀한 재료 (몬스터 재료)
  static List<MaterialId> get commons => upgradeMap.keys.toList();
  static List<MaterialId> get rares => {...upgradeMap.values}.toList();

  static bool isRare(MaterialId m) => Materials.info(m).rare;

  static ConvertPlan? upgrade(MaterialId from) {
    final to = upgradeMap[from];
    if (to == null) return null;
    return ConvertPlan(
      kind: ConvertKind.upgrade,
      give: {from: upgradeCount},
      get: {to: 1},
      gold: upgradeGold,
      minutes: upgradeMinutes,
    );
  }

  static ConvertPlan? exchange(MaterialId from, MaterialId to) {
    if (from == to) return null;
    final rare = rares.contains(from);
    final ok = rare ? rares.contains(to) : commons.contains(from) && commons.contains(to);
    if (!ok) return null;
    return ConvertPlan(
      kind: ConvertKind.exchange,
      give: {from: exchangeCount},
      get: {to: 1},
      gold: rare ? exchangeGoldRare : exchangeGoldCommon,
      minutes: rare ? exchangeMinutesRare : exchangeMinutesCommon,
    );
  }

  static ConvertPlan refine(Element e) => ConvertPlan(
        kind: ConvertKind.refine,
        give: {Materials.elementCore(e): 1},
        giveManaStones: refineManaStones,
        get: {Materials.elementStone(e): 1},
        gold: refineGold,
        minutes: refineMinutes,
      );

  /// 재료 분해 (일반은 5개, 귀한 것은 1개씩)
  static ConvertPlan decomposeMaterial(MaterialId m) {
    final rare = isRare(m);
    return ConvertPlan(
      kind: ConvertKind.decompose,
      give: {m: rare ? 1 : decomposeCommonCount},
      get: const {},
      getManaStones: rare ? decomposeRareStones : 1,
    );
  }

  /// 공방 물약 분해 (수상한 물약도 약초 1)
  static ConvertPlan decomposePotion(String key) {
    final q = AlchemyRules.parseKey(key)?.quality ?? PotionQuality.normal;
    return ConvertPlan(
      kind: ConvertKind.decompose,
      give: const {},
      givePotion: key,
      get: const {MaterialId.herb: 1},
      getManaStones: q == PotionQuality.normal ? 0 : 1,
    );
  }
}
