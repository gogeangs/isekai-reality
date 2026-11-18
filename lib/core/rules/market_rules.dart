import 'dart:convert';
import 'dart:math' as math;

import '../models/armory.dart';
import 'bag_rules.dart';
import 'equipment_rules.dart';
import 'materials.dart';
import 'region_rules.dart';
import 'town_rules.dart';

/// 거래소에 올리는 것 (묶음 58 #229)
enum MarketKind { mat, equip, item, egg }

extension MarketKindLabel on MarketKind {
  String get label => switch (this) {
        MarketKind.mat => '재료',
        MarketKind.equip => '장비',
        MarketKind.item => '물약',
        MarketKind.egg => '알',
      };
}

/// 거래소 규칙 (묶음 58 #229). 돈이라 값 · 시세 · 수수료는 숫자로 보여 줌.
/// 서버(firebase/functions/src/market.js)도 같은 값을 [catalogJson] 으로 받아 다시 확인한다.
abstract final class MarketRules {
  /// 한 사람이 한 번에 올려 둘 수 있는 칸
  static const int slots = 5;

  /// 값을 정해 올린 물건이 기다리는 시간 · 경매 시간
  static const int fixedHours = 48;
  static const int auctionHours = 24;

  /// 팔리면 떼는 수수료 (바르칸과 단짝이면 조금 덜)
  static const double feeRate = 0.10;
  static const double feeRateBest = 0.07;

  /// 올릴 때 드는 금화: 값의 2% (가장 적게 10) · 바르칸의 상단 인장이 있으면 절반
  static const double listRate = 0.02;
  static const int listMin = 10;
  static const double sealListMult = 0.5;

  /// 값 한도: 잡화상에 파는 값(하나) × 이 배율 사이 (현금 거래 막기)
  static const double minMult = 0.5;
  static const double maxMult = 6.0;

  /// 경매 다음 입찰은 지금 값의 5% 이상 (가장 적게 1)
  static const double bidStep = 0.05;

  /// 알 하나의 기준 값 (잡화상엔 못 팖)
  static const int eggBase = 150;

  /// 한 번에 올리는 개수 (재료 · 물약)
  static const int maxQty = 99;

  static int listFee(int price, {bool seal = false}) {
    final f = math.max(listMin, (price * listRate).round());
    return seal ? math.max(1, (f * sealListMult).round()) : f;
  }

  static int saleFee(int price, {bool best = false}) =>
      (price * (best ? feeRateBest : feeRate)).round();

  static int nextBid(int current, {required int start, bool hasBid = true}) =>
      hasBid ? current + math.max(1, (current * bidStep).ceil()) : start;

  // ───────────── 사고팔 수 있는 것

  /// 사고팔 수 있는 장비 (만들거나 몬스터가 떨어뜨리는 보통 장비).
  /// 보스 장비 · 잿빛 왕의 유품 · 마을 사람 특별 보상 · 첫 무기(받은 선물) · 지역 무기 · 이름 있는 장비는 안 됨
  static final Set<EquipBase> equipBases = {
    EquipBase.dagger,
    EquipBase.staff,
    EquipBase.cap,
    EquipBase.armor,
    EquipBase.gloves,
    EquipBase.boots,
    EquipBase.fangNecklace,
    EquipBase.wardenCharm,
    EquipBase.hornDagger,
    EquipBase.boarArmor,
    EquipBase.rabbitBoots,
    EquipBase.tuskNecklace,
    EquipBase.bow,
    EquipBase.baldrinWeapon,
    EquipBase.baldrinHead,
    EquipBase.baldrinBody,
    EquipBase.baldrinHands,
    EquipBase.baldrinFeet,
    EquipBase.baldrinAcc,
    for (final r in RegionRules.all) ...r.gear,
  };

  /// 사고팔 수 있는 가방 물건: 잡화상 물약만 (회복 · 기력 · 직업 기력). 공방 물약은 아직 안 됨
  static bool itemTradable(ShopItem i) {
    final info = TownRules.info(i);
    return TownRules.bagItems.contains(i) &&
        (info.hpRatio > 0 || info.mpRatio > 0 || info.jobMpRatio > 0);
  }

  static bool equipTradable(EquipItem e) => equipBases.contains(e.base);

  // ───────────── 값

  /// 하나의 기준 값 (잡화상에 파는 값)
  static int base(MarketKind k, String key, {EquipItem? equip}) => switch (k) {
        MarketKind.mat => switch (Materials.byName(key)) {
            final m? => BagRules.materialPrice(m),
            null => 0,
          },
        MarketKind.item => switch (ShopItem.values.where((i) => i.name == key).firstOrNull) {
            final i? => BagRules.itemPrice(i),
            null => 0,
          },
        MarketKind.equip => equip == null ? 0 : BagRules.equipPrice(equip),
        MarketKind.egg => eggBase,
      };

  static int minPrice(int base, int qty) => math.max(1, (base * qty * minMult).ceil());
  static int maxPrice(int base, int qty) => math.max(1, (base * qty * maxMult).floor());

  /// 서버가 함께 쓰는 표 (tool: test/batch58_test.dart 가 firebase/functions/src/market_catalog.json 과 같은지 확인)
  static String catalogJson() {
    final mats = {
      for (final m in Materials.all) m.id.name: BagRules.materialPrice(m.id),
    };
    final items = {
      for (final i in ShopItem.values)
        if (itemTradable(i)) i.name: BagRules.itemPrice(i),
    };
    // 잡화상에서 사면 재료가 되는 물건 (서버가 재료 개수를 셀 때)
    final shopMats = {
      for (final i in ShopItem.values)
        if (TownRules.info(i).material case final m?) i.name: m.name,
    };
    final out = {
      'slots': slots,
      'fixedHours': fixedHours,
      'auctionHours': auctionHours,
      'feeRate': feeRate,
      'feeRateBest': feeRateBest,
      'listRate': listRate,
      'listMin': listMin,
      'sealListMult': sealListMult,
      'minMult': minMult,
      'maxMult': maxMult,
      'bidStep': bidStep,
      'eggBase': eggBase,
      'maxQty': maxQty,
      'equipGradeBase': {
        for (final g in EquipGrade.values)
          g.name: BagRules.equipPrice(EquipItem(uid: '_', base: EquipBase.cap, grade: g)),
      },
      'equipBases': [for (final b in EquipBase.values) if (equipBases.contains(b)) b.name],
      'equipNames': {
        for (final b in EquipBase.values)
          if (equipBases.contains(b)) b.name: EquipmentRules.info(b).name,
      },
      'mats': mats,
      'matNames': {for (final m in Materials.all) m.id.name: m.name},
      'items': items,
      'itemNames': {
        for (final i in ShopItem.values)
          if (itemTradable(i)) i.name: TownRules.info(i).name,
      },
      'shopMats': shopMats,
    };
    return '${const JsonEncoder.withIndent('  ').convert(out)}\n';
  }
}
