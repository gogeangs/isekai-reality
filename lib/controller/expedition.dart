part of '../app_controller.dart';

/// 정령 원정·바로 돌아오기 (묶음 21: [AppController] 에서 나눔. 상태 칸은 본체에 있다)
extension ExpeditionOps on AppController {

  // ───────────── 바로 돌아오기 (묶음 18 #151)

  /// 마석 개수: 남은 시간 10분마다 1개(시작한 10분도 1개), 최대 6개. 튜토리얼은 1개
  int rushCost(Expedition ex) {
    if (AppController.isTutorialSpawn(ex.spawnId)) return 1;
    final left = ex.returnAt.difference(_clock()).inSeconds;
    return VitalRules.rushCost(left);
  }

  bool canRush(Expedition ex) =>
      !ex.finished && ex.returnAt.isAfter(_clock());

  bool canRushByAd(Expedition ex) =>
      adsReady &&
      canRush(ex) &&
      !AppController.isTutorialSpawn(ex.spawnId) &&
      !ex.adUsed.contains('rush');

  /// 마석(또는 광고)으로 지금 바로 돌아오게 한다. 성공하면 true
  Future<bool> rushExpedition(Expedition ex, {bool byAd = false}) =>
      _serial(() async {
    if (!canRush(ex)) return false;
    if (byAd) {
      if (!canRushByAd(ex) || !await _watchAd('expedition_rush')) return false;
    } else {
      final cost = rushCost(ex);
      if (player.manaStones < cost) return false;
      final today = await _todayRecord();
      await _save(today.copyWith(
          spends: DailyRecord.addCounts(
              today.spends, {Wallet.manaStone: cost})));
    }
    final now = _clock();
    // 묶음 23 #172: 광고를 보는 사이 도착해 결과가 정해졌을 수 있다 → 지금 기록으로
    final cur = _latestExpedition(ex);
    final done = cur.shortened(cur.returnAt.difference(now), now,
        ad: byAd ? 'rush' : null);
    _vitals = _vitals.copyWith(expeditions: [
      for (final e in _vitals.expeditions)
        e.spawnId == ex.spawnId && e.petUid == ex.petUid ? done : e,
    ]);
    await store.saveVitals(_vitals);
    unawaited(notifier?.cancel(_notifyIdFor(ex.petUid)));
    await refreshVitals();
    _notify();
    return true;
  });

  /// 원정 보상 두 배 (기본 보상만, 펫이 더 가져온 것은 빼고)
  bool canDoubleExpedition(Expedition ex) =>
      adsReady &&
      ex.cleared == true &&
      !AppController.isTutorialSpawn(ex.spawnId) &&
      ex.baseReward.isNotEmpty &&
      !ex.adUsed.contains('double');

  Future<bool> adDoubleExpedition(Expedition ex) =>
      _serial(() async {
    if (!canDoubleExpedition(ex) || !await _watchAd('expedition_double')) {
      return false;
    }
    final b = ex.baseReward;
    final mats = <MaterialId, int>{
      for (final e in b.entries)
        if (Materials.byName(e.key) case final m?) m: e.value,
    };
    await _grant(b[Wallet.gold] ?? 0, b[Wallet.manaStone] ?? 0, mats);
    final exp = b['exp'] ?? 0;
    if (exp > 0) {
      final today = await _todayRecord();
      await _save(today.copyWith(
          gains: {...today.gains, 'exp': (today.gains['exp'] ?? 0) + exp}));
    }
    _markAd(ex, 'double');
    await store.saveVitals(_vitals);
    _notify();
    return true;
  });

  /// 저장된 지금 원정 (화면이 들고 있던 것은 오래됐을 수 있다)
  Expedition _latestExpedition(Expedition ex) {
    for (final e in _vitals.expeditions) {
      if (e.spawnId == ex.spawnId && e.petUid == ex.petUid) return e;
    }
    return ex;
  }

  void _markAd(Expedition ex, String ad) {
    _vitals = _vitals.copyWith(expeditions: [
      for (final e in _vitals.expeditions)
        e.spawnId == ex.spawnId && e.petUid == ex.petUid
            ? e.copy(adUsed: {...e.adUsed, ad})
            : e,
    ]);
  }

  /// 여관 휴식 시간 줄이기: 광고 한 번에 1시간 (줄어든 만큼 HP·MP가 바로 더 찬다)
  bool get canShortenRest => adsReady && resting && restLeft > Duration.zero;

  Future<bool> adShortenRest() =>
      _serial(() async {
    if (!canShortenRest || !await _watchAd('rest_shorten')) return false;
    final at = _vitals.restStartedAt;
    if (at == null) return false;
    _vitals = _vitals.copyWith(
        restStartedAt: at.subtract(const Duration(hours: 1)));
    await store.saveVitals(_vitals);
    unawaited(notifier?.schedule(
      NotifyId.rest,
      _vitals.restStartedAt!.add(const Duration(hours: RuleConstants.restHours)),
      '푹 쉬었어요',
      'HP와 $companionName의 MP가 가득 찼어요. 앱을 열어 휴식 보너스를 받으세요!',
    ));
    await refreshVitals();
    return true;
  });

  /// 가방이 가득 차 금화로 바꾼 값 (알림을 띄우고 0으로)
  int takeBagOverflow() {
    final g = _bagOverflow;
    _bagOverflow = 0;
    return g;
  }

  int get pendingBagOverflow => _bagOverflow;

  ({Map<MaterialId, int> kept, int gold}) _fitBag(
      Map<MaterialId, int> incoming) {
    if (incoming.isEmpty) return (kept: incoming, gold: 0);
    final fit = BagRules.fit(
        incoming: incoming, have: player.materials, freeSlots: bagFree);
    _bagOverflow += fit.gold;
    return fit;
  }

  /// 재료를 버린다
  Future<bool> discardMaterial(MaterialId m, int n) =>
      _serial(() async {
    if (n <= 0 || player.materialCount(m) < n) return false;
    final today = await _todayRecord();
    await _save(today.copyWith(
        spends: DailyRecord.addCounts(today.spends, {m.name: n})));
    return true;
  });

  /// 가방 물건을 버린다
  Future<bool> discardItem(ShopItem item, int n) =>
      _serial(() async {
    if (n <= 0 || bagCount(item) < n) return false;
    await _count(TownRules.dropKey(item), n);
    return true;
  });

  /// 입지 않은 장비를 버린다
  Future<bool> discardEquip(String uid) =>
      _serial(() async {
    final item = _armory.byUid(uid);
    if (item == null || _armory.isWorn(item)) return false;
    await _saveArmory(_armory.copyWith(
        items: [for (final i in _armory.items) if (i.uid != uid) i]));
    return true;
  });

  /// 잡화상에서 재료를 판다
  Future<bool> sellMaterial(MaterialId m, int n) =>
      _serial(() async {
    if (n <= 0 || player.materialCount(m) < n) return false;
    final today = await _todayRecord();
    await _save(today.copyWith(
      spends: DailyRecord.addCounts(today.spends, {m.name: n}),
      gains: DailyRecord.addCounts(
          today.gains, {Wallet.gold: n * BagRules.materialPrice(m)}),
    ));
    return true;
  });

  /// 잡화상에서 가방 물건을 판다 (산 값의 절반)
  Future<bool> sellItem(ShopItem item, int n) =>
      _serial(() async {
    if (n <= 0 || bagCount(item) < n) return false;
    final today = await _todayRecord();
    await _save(today.copyWith(
      counters: DailyRecord.addCounts(
          today.counters, {TownRules.dropKey(item): n}),
      gains: DailyRecord.addCounts(
          today.gains, {Wallet.gold: n * BagRules.itemPrice(item)}),
    ));
    return true;
  });

  /// 잡화상에서 입지 않은 장비를 판다
  Future<bool> sellEquip(String uid) =>
      _serial(() async {
    final item = _armory.byUid(uid);
    if (item == null || _armory.isWorn(item)) return false;
    final today = await _todayRecord();
    await _save(today.copyWith(
      gains: DailyRecord.addCounts(
          today.gains, {Wallet.gold: BagRules.equipPrice(item)}),
    ));
    await _saveArmory(_armory.copyWith(
        items: [for (final i in _armory.items) if (i.uid != uid) i]));
    return true;
  });

  /// 마석 [count] 개를 금화로 판다 (1개에 금화 10). 모자라면 false.
  Future<bool> sellManaStones(int count) =>
      _serial(() async {
    final today = await _todayRecord();
    if (!TownRules.canSell(_history, count)) return false;
    await _save(today.copyWith(
      spends: DailyRecord.addCounts(today.spends, {Wallet.manaStone: count}),
      gains: DailyRecord.addCounts(today.gains,
          {Wallet.gold: count * RuleConstants.goldPerManaStone}),
    ));
    return true;
  });

  /// 가방에 든 개수
  int bagCount(ShopItem item) => TownRules.bagCount(_history, item);

  UseCheck canUse(ShopItem item) {
    // 정령이 떠난 뒤 정령 물약은 펫 간식: 여러 개 줘도 된다
    if (item == ShopItem.bulssiPotion && farewellDone) {
      if (bagCount(item) <= 0) return UseCheck.none;
      return companionPet == null ? UseCheck.none : UseCheck.ok;
    }
    return TownRules.canUse(_history, item,
        hpFull: hp >= maxHp,
        mpFull: mp >= mpMax,
        compassReady: _vitals.compassReady);
  }

  /// 물건 이름 (정령이 떠난 뒤 정령 물약은 「펫 간식」)
  String itemName(ShopItem item) =>
      item == ShopItem.bulssiPotion && farewellDone
          ? '펫 간식'
          : TownRules.info(item).name;

  String itemDescription(ShopItem item) =>
      item == ShopItem.bulssiPotion && farewellDone
          ? '데리고 다니는 펫에게 주면 펫 경험치 +${PetRules.expSnack}, '
              '친밀도 +${PetRules.bondPerSnack}. 준 날은 던전 스킬이 빨리 차요.'
          : TownRules.info(item).description;

  /// 원정 나침반을 써 두었는지 (다음 원정 이동 시간 절반)
  bool get compassReady => _vitals.compassReady;

  /// 가방에서 물약을 꺼내 마신다
  Future<UseCheck> useItem(ShopItem item) =>
      _serial(() async {
    await refreshVitals();
    final check = canUse(item);
    if (check != UseCheck.ok) return check;
    final info = TownRules.info(item);
    if (info.hpRatio > 0) {
      _vitals = _vitals.copyWith(
          hp: math.min(maxHp, hp + (maxHp * info.hpRatio).round()),
          lastMaxHp: maxHp);
    }
    if (info.mpRatio > 0) {
      _vitals = _vitals.copyWith(
          mp: math.min(mpMax, mp + (mpMax * info.mpRatio).round()));
    }
    if (item == ShopItem.expeditionCompass) {
      _vitals = _vitals.copyWith(compassReady: true);
    }
    if (item == ShopItem.bulssiPotion && companionPet != null) {
      final pet = companionPet!;
      await _savePets(_pets.replace(pet.copyWith(
        exp: pet.exp + PetRules.expSnack,
        bond: math.min(PetRules.maxBond, pet.bond + PetRules.bondPerSnack),
      )));
    }
    await store.saveVitals(_vitals);
    final today = await _todayRecord();
    await _save(today.copyWith(itemsUsed: [...today.itemsUsed, item.name]));
    return UseCheck.ok;
  });

  /// 게임 시계 (테스트에서는 고정 시각)
  DateTime get now => _clock();

  String? _routeKey(FieldSpawn spawn) {
    final from = _lastFix?.point;
    if (from == null) return null;
    // 50m 안에서 움직인 것은 같은 출발점으로 본다
    return '${spawn.id}@${(from.lat / 0.0005).round()},${(from.lng / 0.0005).round()}';
  }

  /// 찾아 둔 원정 길 (아직 찾는 중이거나 위치를 모르면 null)
  ExpeditionRoute? routeFor(FieldSpawn spawn) {
    final k = _routeKey(spawn);
    return k == null ? null : _routes[k];
  }

  /// 원정 길을 찾는다. 길 조각을 받지 못했거나, 길이 이어지지 않거나,
  /// 직선의 3배를 넘으면 직선.
  Future<ExpeditionRoute> prepareRoute(FieldSpawn spawn) {
    final k = _routeKey(spawn);
    final from = _lastFix?.point;
    if (k == null || from == null) {
      return Future.value(ExpeditionRoute.straight(
          from ?? spawn.point, spawn.point));
    }
    if (_routes[k] case final r?) return Future.value(r);
    return _routeJobs[k] ??= () async {
      final to = spawn.point;
      final straight = from.distanceTo(to);
      ExpeditionRoute route;
      try {
        final keys = RouteGrid.tilesAround(from, to,
            marginM: math.min(1500.0, math.max(300.0, straight)));
        final loaded = await Future.wait([
          for (final key in keys)
            routeTiles.load(key).then((v) => MapEntry(key, v)),
        ]).timeout(const Duration(seconds: 15));
        final grid = RouteGrid({
          for (final e in loaded)
            if (e.value case final v?) e.key: v,
        });
        route = grid.tiles.isEmpty
            ? ExpeditionRoute.straight(from, to)
            : RouteFinder.find(grid, from, to);
      } catch (_) {
        route = ExpeditionRoute.straight(from, to);
      }
      _routes[k] = route;
      _routeJobs.remove(k);
      _notify();
      return route;
    }();
  }

  /// 원정을 보낼 수 있는 펫 (정령이 떠나기 전에는 비어 있다: 정령이 간다)
  List<Pet> get idlePets => [
        for (final p in _pets.pets)
          if (!isAway(p.uid)) p,
      ];

  /// 길에서 멀리 떨어진 물가 몬스터인지 (두꺼비 특기)
  bool _waterside(ExpeditionRoute? route) {
    if (route == null || !route.followsRoads || route.points.length < 3) {
      return false;
    }
    final pts = route.points;
    return pts[pts.length - 2].distanceTo(pts.last) > PetRules.watersideM;
  }

  /// [spawn] 으로 원정을 보낼 수 있는지 (거리·MP·시간 포함).
  /// 길을 찾아 두었으면 길 거리로, 아니면 직선 거리로 계산한다.
  /// [petUid] 는 보낼 펫 (정령이 떠난 뒤, 없으면 동행 펫).
  ExpeditionPlan planExpedition(FieldSpawn spawn, {String? petUid}) {
    // 튜토리얼 원정: 짧게, MP 걱정 없이 (묶음 15 #104)
    if (AppController.isTutorialSpawn(spawn.id)) {
      return ExpeditionPlan(
          activeExpeditions.any((e) => e.spawnId == spawn.id)
              ? ExpeditionCheck.busy
              : ExpeditionCheck.ok,
          distanceM: 250,
          mpCost: 0,
          oneWay: const Duration(minutes: 2), // 묶음 19 4-1: 서두르기를 보여 주려고 2분
          followsRoads: false,
          routeReady: true);
    }
    final from = _lastFix?.point;
    if (from == null) return const ExpeditionPlan(ExpeditionCheck.needsLocation);
    final pet = farewellDone
        ? (petUid == null ? companionPet : _pets.byUid(petUid))
        : null;
    final route = routeFor(spawn);
    final dist = route?.lengthM ?? from.distanceTo(spawn.point);
    final water = _waterside(route);
    var cost = VitalRules.expeditionCost(dist);
    var base = VitalRules.expeditionOneWay(dist);
    if (pet != null) {
      cost = math.max(
          1,
          (cost *
                  PetRules.mpFactor(pet.species,
                      adult: pet.adult, bond: pet.bond, waterside: water))
              .round());
      final t = PetRules.travelTimeFactor(pet.species,
              adult: pet.adult, bond: pet.bond) *
          PetRules.waterTimeFactor(pet.species,
              adult: pet.adult, bond: pet.bond, waterside: water);
      base = Duration(seconds: (base.inSeconds * t).round());
    }
    // 원정 나침반을 써 두었으면 이동 시간 절반
    final oneWay = _vitals.compassReady ? base ~/ 2 : base;
    ExpeditionCheck check;
    if (farewellDone && pet == null) {
      check = ExpeditionCheck.busy;
    } else if (isAway(pet?.uid)) {
      check = ExpeditionCheck.busy;
    } else if (activeExpeditions.any((e) => e.spawnId == spawn.id)) {
      check = ExpeditionCheck.busy;
    } else if (mp < cost) {
      // 안개 대신 MP로만 거리를 막는다 (11-10, 최대 MP 60 = 약 3km)
      check = ExpeditionCheck.notEnoughMp;
    } else {
      check = ExpeditionCheck.ok;
    }
    return ExpeditionPlan(check,
        distanceM: dist,
        mpCost: cost,
        oneWay: oneWay,
        followsRoads: route?.followsRoads ?? false,
        routeReady: route != null,
        petUid: pet?.uid);
  }

  /// 정령(또는 펫)을 보낸다. MP는 보내는 순간 쓴다.
  Future<ExpeditionCheck> sendSpirit(FieldSpawn spawn, {String? petUid}) =>
      _serial(() async {
    await refreshVitals();
    final route = AppController.isTutorialSpawn(spawn.id)
        ? ExpeditionRoute.straight(_lastFix?.point ?? spawn.point, spawn.point)
        : await prepareRoute(spawn);
    final plan = planExpedition(spawn, petUid: petUid);
    if (plan.check != ExpeditionCheck.ok) return plan.check;
    final pet = plan.petUid == null ? null : _pets.byUid(plan.petUid!);
    final now = _clock();
    // 승객 모드에서 보낸 원정은 보상 절반 (11-11 #61)
    if (passengerMode) {
      await _saveDrive(_drive.copyWith(
          passengerSpawns: [..._drive.passengerSpawns, spawn.id]));
    }
    final arrive = now.add(plan.oneWay);
    final ex = Expedition(
      spawnId: spawn.id,
      monster: spawn.monster.name,
      mods: [for (final m in spawn.modifiers) m.name],
      lat: spawn.point.lat,
      lng: spawn.point.lng,
      fromLat: _lastFix?.point.lat,
      fromLng: _lastFix?.point.lng,
      distanceM: plan.distanceM,
      mpCost: plan.mpCost,
      startedAt: now,
      arriveAt: arrive,
      returnAt: arrive.add(plan.oneWay),
      route: route.followsRoads
          ? [for (final p in route.points) (p.lat, p.lng)]
          : const [],
      petUid: pet?.uid,
      petName: pet?.name,
    );
    _vitals = _vitals.copyWith(
      mp: mp - plan.mpCost,
      mpAt: mp >= mpMax ? now : _vitals.mpAt,
      expeditions: [..._vitals.expeditions, ex],
      compassReady: false, // 나침반은 한 번 쓰면 끝
    );
    await store.saveVitals(_vitals);
    final today = await _todayRecord();
    await _save(today.copyWith(
        counters: DailyRecord.addCounts(today.counters, {'expedition': 1})));
    final who = pet?.name ?? _profile.spiritName;
    unawaited(notifier?.schedule(
      _notifyIdFor(pet?.uid),
      ex.returnAt,
      '${josa(who, '이/가')} 돌아왔어요',
      '${spawn.info.name} 원정 결과를 확인해 보세요!',
    ));
    _notify();
    return ExpeditionCheck.ok;
  });

  /// 원정 알림 id: 정령은 원래 id, 펫은 펫마다
  int _notifyIdFor(String? petUid) {
    if (petUid == null) return NotifyId.expedition;
    final i = _pets.pets.indexWhere((p) => p.uid == petUid);
    return 100 + (i < 0 ? 0 : i);
  }

  /// 원정 결과를 확인했을 때 (결과 카드를 닫으면). [ex] 가 없으면 끝난 원정 모두.
  Future<void> acknowledgeExpedition([Expedition? ex]) async {
    bool drop(Expedition e) =>
        e.finished &&
        (ex == null || (e.spawnId == ex.spawnId && e.petUid == ex.petUid));
    final keep = [
      for (final e in _vitals.expeditions)
        if (!drop(e)) e,
    ];
    if (keep.length == _vitals.expeditions.length) return;
    _vitals = _vitals.copyWith(expeditions: keep);
    await store.saveVitals(_vitals);
    _notify();
  }
  int get lastExpeditionExp => _lastExpeditionExp;

  /// 돌아온 정령의 전투 결과를 정한다. 정령은 각성자의 전투력으로 싸우고
  /// 각성자의 HP는 쓰지 않는다. 지면 MP만 잃고, 몬스터는 그대로 남는다.
  Future<void> _resolveExpedition(Expedition ex) async {
    _resolving = true;
    try {
      await _resolveExpeditionInner(ex);
    } finally {
      _resolving = false;
    }
  }

  Future<void> _resolveExpeditionInner(Expedition ex) async {
    final monster = Monsters.byName(ex.monster) ?? MonsterId.ashSlime;
    final mods = [
      for (final n in ex.mods)
        if (ModifierRules.byName(n) case final m?) m,
    ];
    final p = player;
    final pet = ex.petUid == null ? null : _pets.byUid(ex.petUid!);
    final power = pet == null
        ? 1.0
        : PetRules.powerFactor(pet.species,
            adult: pet.adult,
            bond: pet.bond,
            night: FieldMonsterRules.isNight(ex.arriveAt));
    final battle = Battle.forPlayer(
      level: p.level.level,
      stats: combatStats,
      floors: BattleRules.fieldFoes(
          level: p.level.level,
          monster: monster,
          mods: mods,
          spawnId: ex.spawnId),
      rng: math.Random(ex.spawnId.hashCode),
      gear: gear,
      power: power,
      petSkill: pet?.info.skill,
      petAdult: pet?.adult ?? false,
      potions: battlePotions,
      autoHp: _alc.autoHp,
      autoCure: _alc.autoCure,
      resist: activeResists,
      skillElement: pet?.element,
      mainElement: mainElement,
      weaponPotion: weaponPotionElement,
    ).runToEnd(useSkills: true);
    await _consumeBattlePotions(battle);
    // 튜토리얼 원정은 실패하지 않는다
    final cleared =
        battle.phase == BattlePhase.cleared || AppController.isTutorialSpawn(ex.spawnId);
    final escaped =
        battle.phase == BattlePhase.escaped && !AppController.isTutorialSpawn(ex.spawnId);
    if (escaped) {
      final today = await _todayRecord();
      await _save(
          today.copyWith(fledSpawnIds: [...today.fledSpawnIds, ex.spawnId]));
    }
    final isNew = !purifiedEver.contains(monster);
    if (cleared) await _count('expeditionWin');
    _lastExpeditionExp = cleared
        ? await _recordFieldPurify(ex.spawnId, monster, GeoPoint(ex.lat, ex.lng),
            mods: mods, count: battle.floors.length)
        : 0;
    var r = _lastReward;
    final base = r; // 광고 두 배는 기본 보상만 (펫이 더 가져온 것 제외)
    if (cleared && pet != null) {
      // 호문쿨루스: 재료를 더 가져온다
      final extra = PetRules.extraMaterials(pet.species, _random,
          adult: pet.adult, bond: pet.bond);
      if (extra > 0 && r.exp > 0) {
        final more = <MaterialId, int>{};
        for (var i = 0; i < extra; i++) {
          LootRules.field(monster, _random, early: earlyLoot)
              .forEach((k, v) => more[k] = (more[k] ?? 0) + v);
        }
        await _grant(0, 0, more);
        final mats = {...r.materials};
        more.forEach((k, v) => mats[k] = (mats[k] ?? 0) + v);
        r = HuntReward(
            exp: r.exp, manaStones: r.manaStones, gold: r.gold, materials: mats);
      }
      await _givePetExp(pet.uid, PetRules.expPerExpedition);
    }
    final done = ex.withResult(cleared,
            escaped: escaped,
            newSpecies: cleared && isNew,
            reward: cleared
                ? {
                    if (r.exp > 0) 'exp': r.exp,
                    if (r.manaStones > 0) Wallet.manaStone: r.manaStones,
                    if (r.gold > 0) Wallet.gold: r.gold,
                    for (final e in r.materials.entries) e.key.name: e.value,
                  }
                : const {},
            baseReward: cleared
                ? {
                    if (base.exp > 0) 'exp': base.exp,
                    if (base.manaStones > 0) Wallet.manaStone: base.manaStones,
                    if (base.gold > 0) Wallet.gold: base.gold,
                    for (final e in base.materials.entries) e.key.name: e.value,
                  }
                : const {});
    _vitals = _vitals.copyWith(expeditions: [
      for (final e in _vitals.expeditions)
        e.spawnId == ex.spawnId && e.petUid == ex.petUid ? done : e,
    ]);
    await store.saveVitals(_vitals);
  }

  /// 지금까지 정화한 몬스터 종류 (도감)
  Set<MonsterId> get purifiedEver => {
        for (final r in _history)
          for (final name in r.purifiedMonsterIds)
            if (Monsters.byName(name) case final id?) id,
      };

  Map<String, int> _addCounts(DailyRecord today, List<MonsterId> ids) {
    final m = {...today.huntCounts};
    for (final id in ids) {
      m[id.name] = (m[id.name] ?? 0) + 1;
    }
    return m;
  }

  /// 몬스터 종류별 사냥 수 (도감). 11-10 이전 기록은 사냥한 날 하루에 1마리로 센다.
  Map<MonsterId, int> get huntTotals {
    final totals = <MonsterId, int>{};
    for (final r in _history) {
      if (r.huntCounts.isNotEmpty) {
        r.huntCounts.forEach((name, n) {
          final id = Monsters.byName(name);
          if (id != null) totals[id] = (totals[id] ?? 0) + n;
        });
      } else {
        for (final name in r.purifiedMonsterIds) {
          final id = Monsters.byName(name);
          if (id != null) totals[id] = (totals[id] ?? 0) + 1;
        }
      }
    }
    return totals;
  }

  /// 도감 '수식어' 칸: 희귀·전설 수식어 몬스터별 사냥 수
  Map<String, int> get modHuntTotals {
    final m = <String, int>{};
    for (final r in _history) {
      r.modHunts.forEach((k, v) => m[k] = (m[k] ?? 0) + v);
    }
    return m;
  }

  List<String> _addMonsters(DailyRecord today, List<MonsterId> ids) => {
        ...today.purifiedMonsterIds,
        for (final id in ids) id.name,
      }.toList();

  Future<DailyRecord> _todayRecord() async {
    if (_history.isEmpty ||
        _history.last.dayKey != DailyRecord.dayKeyOf(_clock())) {
      await sync(); // 자정이 지났으면 오늘 기록부터 만든다
    }
    return _history.last;
  }

  Future<void> _save(DailyRecord record) async {
    await store.upsert(_withQuests(record));
    _history = await store.loadHistory();
    _notify();
  }

  DailyRecord? _find(DateTime day) {
    final key = DailyRecord.dayKeyOf(day);
    for (final r in _history) {
      if (r.dayKey == key) return r;
    }
    return null;
  }

  DailyRecord _withQuests(DailyRecord r) =>
      r.copyWith(questsCompleted: QuestRules.completedCount(r));

  Future<DailyRecord> _withHealth(
    DailyRecord record,
    DateTime dayStart,
    DateTime end,
  ) async {
    final steps = await health.stepsBetween(dayStart, end);
    final eightPm =
        DateTime(dayStart.year, dayStart.month, dayStart.day, 20);
    final after8 =
        end.isAfter(eightPm) ? await health.stepsBetween(eightPm, end) : 0;
    // 오전 5~8시 걸음 (숨은 생활 보너스)
    final five = DateTime(dayStart.year, dayStart.month, dayStart.day, 5);
    final eight = DateTime(dayStart.year, dayStart.month, dayStart.day, 8);
    final morning = end.isAfter(five)
        ? await health.stepsBetween(five, end.isBefore(eight) ? end : eight)
        : 0;
    var out = record.copyWith(
        steps: steps, stepsAfter8pm: after8, stepsMorning: morning);
    // 걸음 물약 (11-11 #74): 마신 뒤 걸은 걸음의 절반만큼 게이지가 더 찬다
    for (final b in _alc.buffs) {
      if (b.key != PotionId.steps.name || b.day != record.dayKey) continue;
      final walked = (steps - (b.stepsFrom ?? steps)).clamp(0, b.stepsCap ?? 0);
      final bonus = b.amount + (walked * AlchemyRules.stepBoost).round();
      if (bonus > TownRules.gaugeBonusOn(out)) {
        out = out.copyWith(counters: {...out.counters, 'gaugeBonus': bonus});
      }
    }
    return out;
  }
}
