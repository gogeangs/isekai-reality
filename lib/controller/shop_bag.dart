part of '../app_controller.dart';

/// 여관·잡화상·가방 칸 (묶음 21: [AppController] 에서 나눔. 상태 칸은 본체에 있다)
extension ShopBagOps on AppController {

  // ───────────────────────────────────────────── 여관 · 잡화상 (앱 안 시설)

  /// 잡화상에서 물건을 산다. 사지 못하면 그 이유를 돌려준다.
  Future<PurchaseCheck> buy(ShopItem item) =>
      _serial(() async {
    final today = await _todayRecord();
    final fix = _lastFix;
    await refreshVitals();
    final check = canBuy(item, hasLocation: fix != null);
    if (check != PurchaseCheck.ok) return check;

    await _save(today.copyWith(
      goldPurchases: [...today.goldPurchases, item.name],
    ));
    return PurchaseCheck.ok;
  });

  /// 살 수 있는지 (가방 칸까지 본다)
  /// 잡화상에 보이는 물건 (묶음 16 #144: 감정 돋보기는 Lv.6에 열린다)
  List<ShopItemInfo> get shopItems => [
        for (final i in TownRules.items)
          if (i.item != ShopItem.raceLens || featureOpen(Feature.lens)) i,
      ];

  PurchaseCheck canBuy(ShopItem item, {bool? hasLocation}) {
    final mat = TownRules.info(item).material;
    final have = mat != null
        ? player.materialCount(mat)
        : TownRules.bagItems.contains(item)
            ? bagCount(item)
            : -1;
    return TownRules.canBuy(_history, item,
        hasLocation: hasLocation ?? _lastFix != null,
        level: player.level.level,
        bagRoom: have < 0 || _roomFor(have));
  }

  /// [have] 개 있는 것에 하나 더 넣을 자리가 있는지
  bool _roomFor(int have) =>
      (have > 0 && have % BagRules.stackMax != 0) || bagFree > 0;

  /// 가방 칸 수
  int get bagCapacity => BagRules.capacity(
      goldExpansions: _bag.goldExpansions,
      extraSlots: _bag.extraSlots,
      singleSlots: _bag.singleSlots);

  /// 쓰고 있는 칸 (예전 저장본은 칸보다 많을 수 있다. 그래도 다 남긴다)
  int get bagUsed => BagRules.usedSlots(
        materials: player.materials,
        items: {
          for (final i in TownRules.bagItems)
            if (bagCount(i) > 0) i: bagCount(i),
        },
        armory: _armory,
        eggs: _pets.eggs.length,
        extraStacks: [..._alc.potions.values, ..._extraBagCounts()],
      );

  /// 빈칸 (넘치면 0)
  int get bagFree => math.max(0, bagCapacity - bagUsed);

  /// 다음 한 칸 가격 (더 늘릴 수 없으면 null). 묶음 15 #106: 한 칸씩, 열수록 오른다
  int? get bagExpandCost => bagCapacity >= BagRules.maxSlots
      ? null
      : BagRules.slotCost(_bag.singleSlots);

  /// 다음 칸을 광고로도 열 수 있는지 (한 칸씩 연 것 중 첫째·둘째 칸)
  bool get bagSlotByAd =>
      bagExpandCost != null && _bag.singleSlots < BagRules.adSlots;

  /// 가방을 한 칸 늘린다. [byAd] 면 광고를 끝까지 본 뒤 (첫째·둘째 칸만)
  Future<bool> expandBag({bool byAd = false}) =>
      _serial(() async {
    final cost = bagExpandCost;
    if (cost == null) return false;
    if (byAd) {
      if (!bagSlotByAd || !await _watchAd('bag_slot')) return false;
    } else {
      if (player.gold < cost) return false;
      final today = await _todayRecord();
      await _save(today.copyWith(
          spends: DailyRecord.addCounts(today.spends, {Wallet.gold: cost})));
    }
    _bag = _bag.copyWith(singleSlots: _bag.singleSlots + 1);
    await store.saveJson(AppController._bagKey, _bag.toJson());
    _notify();
    return true;
  });
}
