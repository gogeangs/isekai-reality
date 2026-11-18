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
    // 묶음 31: 단골 손님 → 하루 개수를 넘겨 산 거면 이번에 쓴다
    final i = TownRules.info(item);
    final starExtra = _shopExtra(item) - (skillPending(JobSkill.regular) ? 1 : 0);
    if (TownRules.boughtInLimit(_history, item) > i.perLimit + starExtra) {
      await _consumeSkill(JobSkill.regular);
    }
    // 묶음 31: 물약 상인 물약 도매 · 대흥정 → 산 값 일부를 돌려받는다 (숨김)
    final back = await _jobBuyRefund(i.price,
        potion: i.hpRatio > 0 || i.mpRatio > 0 || i.jobMpRatio > 0);
    if (back > 0) {
      final t = await _todayRecord();
      await _save(t.copyWith(
          gains: DailyRecord.addCounts(t.gains, {Wallet.gold: back})));
    }
    // 묶음 42 #226: 미나와 단짝이면 산 값 일부를 돌려받음 (숨김)
    final mina = minaRefund(i.price);
    if (mina > 0) {
      final t = await _todayRecord();
      await _save(t.copyWith(
          gains: DailyRecord.addCounts(t.gains, {Wallet.gold: mina})));
    }
    // 묶음 57: 사냥 활은 사자마자 장비로
    if (item == ShopItem.basicBow) {
      await _giveEquipOrMail(
          EquipItem(uid: 'eq${_armory.nextId}', base: EquipBase.bow, grade: EquipGrade.white));
      await _saveArmory(_armory.copyWith(nextId: _armory.nextId + 1));
    }
    await _shopTraded();
    await _npcUse(Npc.mina);
    // 묶음 27 #176: 잡화상 거래 1건마다 장사·의뢰 숙련도
    await gainMastery(Mastery.trade, MasteryRules.tradeOnce);
    return PurchaseCheck.ok;
  });

  /// 살 수 있는지 (가방 칸까지 본다)
  /// 잡화상에 보이는 물건 (묶음 16 #144: 감정 돋보기는 Lv.6에 열린다)
  List<ShopItemInfo> get shopItems => [
        for (final i in TownRules.items)
          if ((i.item != ShopItem.raceLens || featureOpen(Feature.lens)) &&
              // 묶음 30: 마나 물약은 직업 각성 뒤에만 (그 전엔 MP가 없다)
              (i.jobMpRatio <= 0 || jobsOpen) &&
              // 묶음 54: 잡화상 ★2 물건 · ★3 그날 특별한 물건
              (!TownRules.star2Items.contains(i.item) || _star(Building.shop, 2)) &&
              (!TownRules.specials.contains(i.item) ||
                  (_star(Building.shop, 3) &&
                      TownRules.specialOf(DailyRecord.dayKeyOf(_clock())) == i.item)))
            i,
      ];

  /// 묶음 54: 잡화상 ★3 → 하루 살 수 있는 개수 +1 (특별한 물건은 그대로 하나)
  int _shopExtra(ShopItem item) =>
      (skillPending(JobSkill.regular) ? 1 : 0) +
      (_star(Building.shop, 3) && !TownRules.specials.contains(item)
          ? BuildingRules.shopExtraLimit
          : 0);

  PurchaseCheck canBuy(ShopItem item, {bool? hasLocation}) {
    final mat = TownRules.info(item).material;
    final have = mat != null
        ? player.materialExact(mat)
        : TownRules.bagItems.contains(item)
            ? bagCount(item)
            : -1;
    return TownRules.canBuy(_history, item,
        hasLocation: hasLocation ?? _lastFix != null,
        level: player.level.level,
        bagRoom: have < 0 || _roomFor(have),
        extraLimit: _shopExtra(item));
  }

  /// 묶음 41 #227: 이번 기간(오늘·이번 주)에 더 살 수 있는 개수 (단골 손님 몫 포함)
  int shopLeft(ShopItem item) {
    final i = TownRules.info(item);
    final extra = _shopExtra(item);
    return math.max(
        0, i.perLimit + extra - TownRules.boughtInLimit(_history, item));
  }

  /// 묶음 41 #227: 한 번에 살 수 있는 가장 많은 개수
  /// (남은 개수 · 금화 · 가방 빈칸 중 가장 적은 수). 살 수 없으면 0
  int shopMaxBuy(ShopItem item, {bool? hasLocation}) {
    if (canBuy(item, hasLocation: hasLocation) != PurchaseCheck.ok) return 0;
    final i = TownRules.info(item);
    var n = math.min(shopLeft(item), player.gold ~/ math.max(1, i.price));
    // 가방에 들어가는 물건은 칸을 본다 (같은 칸에 [BagRules.stackMax] 개까지)
    final mat = i.material;
    if (mat != null || TownRules.bagItems.contains(item)) {
      var have = mat != null ? player.materialExact(mat) : bagCount(item);
      var free = bagFree;
      var fit = 0;
      while (fit < n) {
        final stacks = have > 0 && have % BagRules.stackMax != 0;
        if (!stacks) {
          if (free <= 0) break;
          free--;
        }
        have++;
        fit++;
      }
      n = fit;
    }
    return math.max(0, n);
  }

  /// 묶음 41 #227: [n] 개를 한 번에 산다 (규칙은 하나씩 살 때와 같다).
  /// 산 개수와 마지막 판정을 돌려준다.
  Future<(int, PurchaseCheck)> buyMany(ShopItem item, int n) async {
    var bought = 0;
    var last = PurchaseCheck.ok;
    for (var k = 0; k < n; k++) {
      last = await buy(item);
      if (last != PurchaseCheck.ok) break;
      bought++;
    }
    return (bought, last);
  }

  /// [have] 개 있는 것에 하나 더 넣을 자리가 있는지
  bool _roomFor(int have) =>
      (have > 0 && have % BagRules.stackMax != 0) || bagFree > 0;

  /// 가방 칸 수
  int get bagCapacity => BagRules.capacity(
      goldExpansions: _bag.goldExpansions,
      extraSlots: _bag.extraSlots,
      singleSlots: _bag.singleSlots) +
      jobBagSlots +
      npcBagSlots; // 묶음 42: 미나의 짐 주머니

  /// 쓰고 있는 칸 (예전 저장본은 칸보다 많을 수 있다. 그래도 다 남긴다)
  int get bagUsed => BagRules.usedSlots(
        materials: player.materials,
        items: {
          for (final i in TownRules.bagItems)
            if (bagCount(i) > 0) i: bagCount(i),
        },
        armory: _armory,
        // 묶음 69 #282: 품는 중인 알은 가방 칸에서 뺌
        eggs: _pets.eggs.where((e) => e.incubatedAt == null).length,
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
  Future<bool> expandBag({bool byAd = false}) async {
    // 광고는 잠금 밖에서 본다 (보는 동안 다른 저장을 막지 않게)
    if (byAd &&
        (bagExpandCost == null ||
            !bagSlotByAd ||
            !await _watchAd('bag_slot'))) {
      return false;
    }
    return _serial(() async {
    final cost = bagExpandCost;
    if (cost == null) return false;
    if (!byAd) {
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
}
