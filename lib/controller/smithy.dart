part of '../app_controller.dart';

/// 대장간·장비·보스 장비 (묶음 21: [AppController] 에서 나눔. 상태 칸은 본체에 있다)
extension SmithyOps on AppController {

  /// 가진 장비와 입은 장비
  Armory get armory => _armory;

  /// 입은 장비의 힘
  GearBonus get gear => EquipmentRules.bonusOf(_armory.worn);

  Future<void> _saveArmory(Armory a) async {
    _armory = a;
    await store.saveJson(AppController._armoryKey, a.toJson());
    // 최대 HP가 바뀌었을 수 있다
    await refreshVitals();
    _notify();
  }

  /// 첫 무기는 공짜 (묶음 16 #141): 새로 시작한 사람이 무기를 아직 안 가졌을 때 한 번
  bool get firstWeaponFree =>
      !_legacyGates &&
      featureOpen(Feature.smithy) &&
      !gotGift(Gift.firstWeapon) &&
      !_armory.items.any(
          (i) => EquipmentRules.info(i.base).slot == EquipSlot.weapon);

  bool _isFreeCraft(EquipBase base, MaterialId? rare) =>
      rare == null &&
      firstWeaponFree &&
      EquipmentRules.info(base).slot == EquipSlot.weapon &&
      !EquipmentRules.isBossGear(base);

  /// 만들 수 있는지 (재료·마석). [rare] 는 더 넣을 귀한 재료.
  CraftCheck canCraft(EquipBase base, {MaterialId? rare}) {
    final info = EquipmentRules.info(base);
    final p = player;
    if (_isFreeCraft(base, rare)) {
      return bagFree <= 0 ? CraftCheck.bagFull : CraftCheck.ok;
    }
    for (final e in info.recipe.entries) {
      if (p.materialCount(e.key) < e.value) return CraftCheck.materials;
    }
    if (rare != null) {
      final need = (info.recipe[rare] ?? 0) + 1;
      if (p.materialCount(rare) < need) return CraftCheck.materials;
    }
    if (p.manaStones < info.manaStones) return CraftCheck.manaStones;
    if (bagFree <= 0) return CraftCheck.bagFull;
    return CraftCheck.ok;
  }

  /// 대장간에서 장비를 만든다. 만든 장비를 돌려준다 (못 만들면 null).
  Future<EquipItem?> craft(EquipBase base, {MaterialId? rare}) =>
      _serial(() async {
    if (canCraft(base, rare: rare) != CraftCheck.ok) return null;
    final info = EquipmentRules.info(base);
    final free = _isFreeCraft(base, rare);
    final used = free
        ? <String, int>{}
        : <String, int>{
            for (final e in info.recipe.entries) e.key.name: e.value,
            if (rare != null) rare.name: (info.recipe[rare] ?? 0) + 1,
          };
    if (free) {
      await _markGift(Gift.firstWeapon);
    } else {
      final today = await _todayRecord();
      await _save(today.copyWith(
        spends: DailyRecord.addCounts(today.spends, {
          ...used,
          if (info.manaStones > 0) Wallet.manaStone: info.manaStones,
        }),
      ));
    }
    final a = _armory;
    final grade =
        EquipmentRules.rollGrade(_random, rare: rare != null, crafts: a.crafts);
    final item = EquipItem(
      uid: 'eq${a.nextId}',
      base: base,
      grade: grade,
      extras: EquipmentRules.rollExtras(grade, _random),
      materialsUsed: used,
    );
    await _saveArmory(a.copyWith(
      items: [...a.items, item],
      crafts: a.crafts + 1,
      nextId: a.nextId + 1,
    ));
    return item;
  });

  // ───────────── 보스 장비 만들기 (11-11 #82)

  /// 대장장이 직업 (#55 직업 각성 뒤 열림, 지금은 늘 false)
  bool get blacksmith => false;

  /// 이 세트의 보스를 잡아 봤는지 (못 잡은 보스의 세트는 그림자로 숨김)
  bool bossSetOpen(BossSet s) =>
      purifiedEver.contains(BossGearRules.info(s).boss);

  /// 이 부위를 이미 만든 적이 있는지 (가진 것 중에)
  bool hasBossPart(EquipBase base) => _armory.items.any((i) => i.base == base);

  CraftCheck canCraftBoss(EquipBase base) {
    final set = BossGearRules.setOf(base);
    if (set == null || !bossSetOpen(set)) return CraftCheck.materials;
    final info = BossGearRules.info(set);
    final c = BossGearRules.cost(EquipmentRules.info(base).slot,
        blacksmith: blacksmith);
    final p = player;
    if (p.materialCount(MaterialId.bossShard) < c.shards ||
        p.materialCount(info.material) < c.mats) {
      return CraftCheck.materials;
    }
    if (p.gold < c.gold) return CraftCheck.gold;
    if (bagFree <= 0) return CraftCheck.bagFull;
    return CraftCheck.ok;
  }

  /// 보스 장비를 만든다. 실패하면 금화 절반과 조각 일부를 잃고 전용 재료는 돌려받는다.
  /// 처음부터 그 보스 속성이 입혀져 있다 (일반 장비처럼 바꾸기·추출·강화 가능).
  Future<BossCraftResult?> craftBoss(EquipBase base) =>
      _serial(() async {
    if (canCraftBoss(base) != CraftCheck.ok) return null;
    final set = BossGearRules.info(BossGearRules.setOf(base)!);
    final slot = EquipmentRules.info(base).slot;
    final c = BossGearRules.cost(slot, blacksmith: blacksmith);
    final failed = _random.nextDouble() < BossGearRules.failChance(blacksmith: blacksmith);
    final today = await _todayRecord();
    if (failed) {
      final loss = BossGearRules.failLoss(slot, blacksmith: blacksmith);
      await _save(today.copyWith(
        spends: DailyRecord.addCounts(today.spends, {
          MaterialId.bossShard.name: loss.shards,
          Wallet.gold: loss.gold,
        }),
      ));
      return BossCraftResult(
          line: BossGearRules.failLines[_random.nextInt(BossGearRules.failLines.length)]);
    }
    final used = <String, int>{
      MaterialId.bossShard.name: c.shards,
      set.material.name: c.mats,
    };
    await _save(today.copyWith(
      spends: DailyRecord.addCounts(today.spends, {...used, Wallet.gold: c.gold}),
    ));
    final a = _armory;
    final grade = EquipmentRules.rollGrade(_random, rare: true, crafts: a.crafts);
    final item = EquipItem(
      uid: 'eq${a.nextId}',
      base: base,
      grade: grade,
      extras: EquipmentRules.rollExtras(grade, _random),
      materialsUsed: used,
      element: set.element,
    );
    await _saveArmory(a.copyWith(
      items: [...a.items, item],
      crafts: a.crafts + 1,
      nextId: a.nextId + 1,
    ));
    return BossCraftResult(item: item);
  });

  /// 강화할 수 있는지
  CraftCheck canEnhance(EquipItem item) {
    if (item.enhance >= EquipmentRules.maxEnhance) return CraftCheck.maxed;
    final cost = EquipmentRules.enhanceCost(item.enhance + 1);
    final p = player;
    if (p.manaStones < cost.manaStones) return CraftCheck.manaStones;
    if (p.gold < cost.gold) return CraftCheck.gold;
    return CraftCheck.ok;
  }

  /// 강화한다. 성공하면 true. 실패해도 장비는 그대로 (비용만 쓴다).
  Future<bool?> enhance(String uid) =>
      _serial(() async {
    final item = _armory.byUid(uid);
    if (item == null || canEnhance(item) != CraftCheck.ok) return null;
    final to = item.enhance + 1;
    final cost = EquipmentRules.enhanceCost(to);
    final today = await _todayRecord();
    await _save(today.copyWith(
      spends: DailyRecord.addCounts(today.spends,
          {Wallet.manaStone: cost.manaStones, Wallet.gold: cost.gold}),
    ));
    final ok = _random.nextDouble() < EquipmentRules.enhanceChance(to);
    await _saveArmory(_armory.replace(item.copyWith(
      enhance: ok ? to : item.enhance,
      enhanceManaSpent: item.enhanceManaSpent + cost.manaStones,
    )));
    return ok;
  });

  /// 내구도를 다 고친다
  Future<bool> repair(String uid) =>
      _serial(() async {
    final item = _armory.byUid(uid);
    if (item == null) return false;
    final cost = EquipmentRules.repairCost(item);
    if (cost <= 0 || player.gold < cost) return false;
    final today = await _todayRecord();
    await _save(today.copyWith(
      spends: DailyRecord.addCounts(today.spends, {Wallet.gold: cost}),
    ));
    await _saveArmory(_armory.replace(
        item.copyWith(durability: EquipmentRules.maxDurability)));
    return true;
  });

  /// 대장간 장비 속성 작업 (11-11 #74, NPC 도르군).
  /// 실패하면 금화만 잃고 빛나는 속성 코어는 돌려받는다. 장비와 원래 속성은 그대로.
  Future<SmithResult> smith(String uid, SmithAction act, {Element? to}) =>
      _serial(() async {
    final item = _armory.byUid(uid);
    if (item == null) return SmithResult.cannot;
    final el = item.element;
    final coreEl = switch (act) {
      SmithAction.apply || SmithAction.change => to,
      SmithAction.extract || SmithAction.upgrade => el,
    };
    final ok = switch (act) {
      SmithAction.apply => el == null && to != null,
      SmithAction.change => el != null && to != null && to != el,
      SmithAction.extract => el != null,
      SmithAction.upgrade => el != null && item.elementLevel < SmithRules.maxLevel,
    };
    if (!ok || coreEl == null) return SmithResult.cannot;
    final core = EquipmentRules.imbueCore(coreEl);
    final gold = SmithRules.gold(act);
    final cores = SmithRules.cores(act);
    if (player.gold < gold || player.materialCount(core) < cores) {
      return SmithResult.cannot;
    }
    final failed = _random.nextDouble() <
        SmithRules.failChance(act, level: item.elementLevel);
    final today = await _todayRecord();
    await _save(today.copyWith(
      spends: DailyRecord.addCounts(today.spends, {
        Wallet.gold: gold,
        if (!failed && cores > 0) core.name: cores,
      }),
    ));
    if (failed) return SmithResult.failed;
    switch (act) {
      case SmithAction.apply:
        await _saveArmory(_armory.replace(item.copyWith(element: to, elementLevel: 0)));
      case SmithAction.change:
        await _saveArmory(_armory.replace(item.copyWith(element: to)));
      case SmithAction.extract:
        await _saveArmory(_armory.replace(item.copyWith(clearElement: true)));
        await _grant(0, 0, {core: 1});
      case SmithAction.upgrade:
        await _saveArmory(_armory.replace(
            item.copyWith(elementLevel: item.elementLevel + 1)));
    }
    return SmithResult.ok;
  });

  /// 분해한다 (재료 절반과 마석 1, 강화 마석 절반을 돌려받는다)
  Future<bool> disassemble(String uid) =>
      _serial(() async {
    final item = _armory.byUid(uid);
    if (item == null) return false;
    final back = EquipmentRules.salvage(item);
    await _grant(0, back.manaStones, back.materials);
    final a = _armory;
    await _saveArmory(a.copyWith(
      items: [for (final i in a.items) if (i.uid != uid) i],
      equipped: {
        for (final e in a.equipped.entries)
          if (e.value != uid) e.key: e.value,
      },
    ));
    return true;
  });

  /// 입는다 (같은 부위의 장비는 벗는다)
  Future<void> equip(String uid) =>
      _serial(() async {
    final item = _armory.byUid(uid);
    if (item == null) return;
    await _saveArmory(
        _armory.copyWith(equipped: {..._armory.equipped, item.slot: uid}));
  });

  Future<void> unequip(EquipSlot slot) =>
      _serial(() async {
    await _saveArmory(_armory.copyWith(equipped: {
      for (final e in _armory.equipped.entries)
        if (e.key != slot) e.key: e.value,
    }));
  });

  /// 싸울 때마다 입은 장비의 내구도가 준다
  Future<void> _wear(int n) async {
    final worn = _armory.worn;
    if (worn.isEmpty) return;
    var a = _armory;
    for (final item in worn) {
      a = a.replace(item.copyWith(
          durability: math.max(0, item.durability - n)));
    }
    _armory = a;
    await store.saveJson(AppController._armoryKey, a.toJson());
  }
}
