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

  /// 묶음 59: 예전 계정 — 공짜 첫 무기를 받았는데 「받은 선물」 표시가 없으면, 재료를 안 쓰고 만든
  /// 가장 오래된 무기 하나에 표시 (한 번)
  Future<void> _markFirstWeaponGift() async {
    if (!gotGift(Gift.firstWeapon) || _armory.items.any((i) => i.gift)) return;
    if (_village.contains('giftMarked')) return;
    int no(EquipItem i) => int.tryParse(i.uid.replaceFirst('eq', '')) ?? 1 << 30;
    final cands = [
      for (final i in _armory.items)
        if (i.slot == EquipSlot.weapon && i.materialsUsed.isEmpty && !EquipmentRules.isBossGear(i.base)) i,
    ]..sort((a, b) => no(a).compareTo(no(b)));
    if (cands.isNotEmpty) {
      final g = cands.first;
      await _saveArmory(_armory.copyWith(items: [
        for (final i in _armory.items) i.uid == g.uid ? i.copyWith(gift: true) : i,
      ]));
    }
    await _markVillage(['giftMarked']);
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
    // 묶음 48: 첫 무기 무료(Lv.3 안내)는 가방이 가득해도 만들 수 있게 — 안내가 막히지 않게,
    // 만들자마자 입으면 칸을 차지하지 않는다
    if (_isFreeCraft(base, rare)) return CraftCheck.ok;
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
    // 묶음 31: 명장의 손길 → 좋은 등급이 나오기 쉬움 · 명검 벼리기(무기) → 추가 능력치 하나 더 (숨김)
    final isWeapon = info.slot == EquipSlot.weapon;
    final touch = await _consumeSkill(JobSkill.masterTouch);
    final blade = isWeapon && await _consumeSkill(JobSkill.masterBlade);
    final grade =
        // 묶음 27 #176: 그 장비 종류의 대장일 숙련도만큼 좋은 등급이 조금 더 (숨김)
        EquipmentRules.rollGrade(_random,
            rare: rare != null,
            bonus: smithGradeBonus(base) +
                (touch
                    ? JobRules.masterTouchGrade *
                        skillPower(JobSkill.masterTouch)
                    : 0));
    final extras = EquipmentRules.rollExtras(grade, _random);
    if (blade) {
      final keys = [
        for (final k in EquipmentRules.statKeys)
          if (!extras.containsKey(k)) k,
      ];
      if (keys.isNotEmpty) {
        extras[keys[_random.nextInt(keys.length)]] =
            1 + _random.nextInt(2 + skillLevel(JobSkill.masterBlade));
      }
    }
    // 묶음 30: 룬 대장장이 → 가끔 속성이 붙음 (숨김)
    final rune = _jobRoll(JobId.runesmith, JobRules.runesmithElement)
        ? Element.values[_random.nextInt(Element.values.length)]
        : null;
    final item = EquipItem(
      uid: 'eq${a.nextId}',
      base: base,
      grade: grade,
      extras: extras,
      materialsUsed: used,
      element: rune,
      // 묶음 59: 공짜 첫 무기는 받은 선물 (거래소에 못 올림)
      gift: free,
    );
    await _saveArmory(a.copyWith(
      items: [...a.items, item],
      crafts: a.crafts + 1,
      nextId: a.nextId + 1,
    ));
    await gainMastery(Mastery.smith, MasteryRules.craft,
        details: [MasteryRules.smithKey(MasteryRules.smithKind(base))]);
    await _npcUse(Npc.dorgun);
    return item;
  });

  // ───────────── 보스 장비 만들기 (11-11 #82)

  /// 예전(11-11 #82) 대장장이 직업 규칙(보스 장비 비용·실패 절반). 묶음 30 직업 각성의
  /// 대장장이 고유 기술과는 따로라 지금은 끔
  bool get blacksmith => false;

  /// 방금 강화 실패가 무사했는지 (대장장이·집중 단조)
  bool get lastEnhanceSafe => _lastEnhanceSafe;

  /// 이 세트의 보스를 잡아 봤는지 (못 잡은 보스의 세트는 그림자로 숨김)
  bool bossSetOpen(BossSet s) => switch (s) {
        // 묶음 50: 하이랜드 수호자를 하나라도 쓰러뜨리면
        BossSet.sky => _highland.beaten.isNotEmpty,
        // 묶음 56: 파티 보스 재료가 하나라도 생기면
        BossSet.party => PartyRules.bosses
            .any((b) => player.materialCount(PartyRules.bossMat(b)) > 0 || _armory.items.any((i) => BossGearRules.setOf(i.base) == BossSet.party)),
        _ => purifiedEver.contains(BossGearRules.info(s).boss),
      };

  /// 이 부위를 이미 만든 적이 있는지 (가진 것 중에)
  bool hasBossPart(EquipBase base) => _armory.items.any((i) => i.base == base);

  CraftCheck canCraftBoss(EquipBase base) {
    final set = BossGearRules.setOf(base);
    if (set == null || !bossSetOpen(set) || set == BossSet.ash) {
      return CraftCheck.materials;
    }
    final c = BossGearRules.partCost(base, blacksmith: blacksmith);
    final p = player;
    for (final e in c.mats.entries) {
      if (p.materialCount(e.key) < e.value) return CraftCheck.materials;
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
    final c = BossGearRules.partCost(base, blacksmith: blacksmith);
    final failed = _random.nextDouble() < BossGearRules.failChance(blacksmith: blacksmith);
    final today = await _todayRecord();
    if (failed) {
      final loss = BossGearRules.failLoss(slot, blacksmith: blacksmith);
      await _save(today.copyWith(
        spends: DailyRecord.addCounts(today.spends, {
          BossGearRules.shardOf(base).name: loss.shards,
          Wallet.gold: loss.gold,
        }),
      ));
      return BossCraftResult(
          line: BossGearRules.failLines[_random.nextInt(BossGearRules.failLines.length)]);
    }
    final used = <String, int>{
      for (final e in c.mats.entries) e.key.name: e.value,
    };
    await _save(today.copyWith(
      spends: DailyRecord.addCounts(today.spends, {...used, Wallet.gold: c.gold}),
    ));
    final a = _armory;
    final grade = EquipmentRules.rollGrade(_random,
        rare: true, bonus: smithGradeBonus(base));
    final item = EquipItem(
      uid: 'eq${a.nextId}',
      base: base,
      grade: grade,
      extras: EquipmentRules.rollExtras(grade, _random),
      materialsUsed: used,
      element: set.id == BossSet.sky
          ? HighlandRules.partElement(slot)
          : set.element,
    );
    await _saveArmory(a.copyWith(
      items: [...a.items, item],
      crafts: a.crafts + 1,
      nextId: a.nextId + 1,
    ));
    await gainMastery(Mastery.smith, MasteryRules.craft,
        details: [MasteryRules.smithKey(MasteryRules.smithKind(base))]);
    await _npcUse(Npc.dorgun);
    return BossCraftResult(item: item);
  });

  /// 집중 단조로 오르는 성공률 (단계마다 조금 더)
  double get focusForgeBoost =>
      JobRules.focusForgeChance * skillPower(JobSkill.focusForge);

  /// 화면에 보이는 강화 성공률 (집중 단조를 써 두면 오른 값)
  double enhanceChanceShown(int to) => math.min(
      1.0,
      EquipmentRules.enhanceChance(to) +
          _smithEnhance +
          (skillPending(JobSkill.focusForge) ? focusForgeBoost : 0));

  /// 묶음 54: 대장간 ★3 → 강화가 조금 쉬워짐 (화면 %에도)
  double get _smithEnhance =>
      _star(Building.smithy, 3) ? BuildingRules.smithEnhance : 0;

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
  /// [whetstone]: 도르군의 숫돌로 꼭 성공 (묶음 42 #226)
  Future<bool?> enhance(String uid, {bool whetstone = false}) =>
      _serial(() async {
    final item = _armory.byUid(uid);
    if (item == null || canEnhance(item) != CraftCheck.ok) return null;
    final sure = whetstone && whetstones > 0;
    if (sure) await _useWhetstone();
    final to = item.enhance + 1;
    final cost = EquipmentRules.enhanceCost(to);
    final today = await _todayRecord();
    await _save(today.copyWith(
      spends: DailyRecord.addCounts(today.spends,
          {Wallet.manaStone: cost.manaStones, Wallet.gold: cost.gold}),
    ));
    // 묶음 31 #193: 집중 단조 → 성공률이 오르고(화면 %에도), 실패해도 무사 (쓴 마석·금화를 돌려받음)
    final focus = await _consumeSkill(JobSkill.focusForge);
    final ok = sure ||
        _random.nextDouble() <
            EquipmentRules.enhanceChance(to) +
                _smithEnhance +
                (focus ? focusForgeBoost : 0);
    var safe = false;
    if (!ok && focus) {
      safe = true;
      final t = await _todayRecord();
      await _save(t.copyWith(
        gains: DailyRecord.addCounts(t.gains,
            {Wallet.manaStone: cost.manaStones, Wallet.gold: cost.gold}),
      ));
    }
    _lastEnhanceSafe = safe;
    await _saveArmory(_armory.replace(item.copyWith(
      enhance: ok ? to : item.enhance,
      enhanceManaSpent: item.enhanceManaSpent + (safe ? 0 : cost.manaStones),
    )));
    // 숙련도는 쌓이지만 강화 성공률에는 넣지 않는다 (화면 「성공 ○○%」와 같게)
    await gainMastery(Mastery.smith, MasteryRules.enhance,
        details: [MasteryRules.smithKey(MasteryRules.smithKind(item.base))]);
    await _npcUse(Npc.dorgun);
    await _npcTally(NpcTally.enhance);
    // 묶음 45 #231: 도르군 — 강화에 성공했을 때
    if (ok) await _smallTrigger(Npc.dorgun);
    return ok;
  });

  /// 내구도를 다 고친다
  Future<bool> repair(String uid) =>
      _serial(() async {
    final item = _armory.byUid(uid);
    if (item == null) return false;
    final cost = masteryRepairCost(item);
    if (cost <= 0 || player.gold < cost) return false;
    final today = await _todayRecord();
    await _save(today.copyWith(
      spends: DailyRecord.addCounts(today.spends, {Wallet.gold: cost}),
    ));
    await _saveArmory(_armory.replace(
        item.copyWith(durability: EquipmentRules.maxDurability)));
    await gainMastery(Mastery.smith, MasteryRules.repair,
        details: [MasteryRules.smithKey(MasteryRules.smithKind(item.base))]);
    await _npcUse(Npc.dorgun);
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
    // 묶음 32 #189: 대장간에서 속성을 부여하면(입히기·바꾸기) 그 속성 점수 (룬 새기기는 아님)
    if ((act == SmithAction.apply || act == SmithAction.change) && to != null) {
      await _gainElement(to, ElementRules.imbueScore);
    }
    await _npcUse(Npc.dorgun);
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
    await _npcUse(Npc.dorgun);
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

  /// 싸울 때마다 입은 장비의 내구도가 준다 (대장장이 튼튼한 손: 가끔 닳지 않음)
  Future<void> _wear(int n) async {
    final worn = _armory.worn;
    if (worn.isEmpty) return;
    if (_jobRoll(JobId.blacksmith, JobRules.blacksmithWear)) return;
    var a = _armory;
    var broke = false;
    for (final item in worn) {
      final d = math.max(0, item.durability - n);
      if (d == 0 && item.durability > 0) broke = true;
      a = a.replace(item.copyWith(durability: d));
    }
    _armory = a;
    await store.saveJson(AppController._armoryKey, a.toJson());
    // 묶음 45 #231: 도르군 — 장비 내구도가 0이 됐을 때
    if (broke) await _smallTrigger(Npc.dorgun);
  }
}
