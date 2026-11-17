part of '../app_controller.dart';

/// 정령 이별·펫·정령 편지 (묶음 21: [AppController] 에서 나눔. 상태 칸은 본체에 있다)
extension PetsOps on AppController {

  PetState get pets => _pets;

  /// 정령이 떠났는지 (Lv.11)
  bool get farewellDone => _pets.farewellDone;

  /// 데리고 다니는 펫 (정령이 떠나기 전에는 null)
  /// 묶음 43 #228: 훈련장에서 훈련 중인 펫은 동행·던전에 안 나온다
  Pet? get companionPet => _pets.farewellDone &&
          !petInTraining(_pets.companion)
      ? _pets.companionPet
      : null;

  /// 빛 조각에서 태어난 첫 펫 (묶음 29 #182). 이 펫만 말을 한다
  Pet? get firstPet {
    final uid = _pets.firstPet;
    return uid == null ? null : _pets.byUid(uid);
  }

  /// 말풍선·배지에 나오는 펫: 첫 펫, 없으면 데리고 다니는 펫 (예전 이별 뒤 아직 컷신 전)
  Pet? get voicePet => firstPet ?? companionPet;

  /// 말풍선·원정에 나오는 동료 이름 (정령 또는 첫 펫)
  String get companionName => voicePet?.name ?? _profile.spiritName;

  /// 처음 함께한 정령 이름 (떠난 뒤 프로필·기록에)
  String get firstSpiritName => _pets.firstSpiritName ?? _profile.spiritName;

  Future<void> _savePets(PetState p) async {
    _pets = p;
    await store.saveJson(AppController._petsKey, p.toJson());
    _notify();
  }

  /// 이별 컷신·첫 펫을 보여 줄 때인지 (묶음 29 #182): Lv.11 이상, 아직 첫 펫이 없음.
  /// 정령이 아직 함께면 정령 원정이 끝난 뒤에. 예전 이별을 이미 본 계정도 한 번.
  bool get farewellPending =>
      _pets.firstPet == null &&
      player.level.level >= PetRules.farewellLevel &&
      (_pets.farewellDone || _vitals.expeditions.isEmpty);

  /// 첫 펫 종류: 숨은 속성 점수(mainElement) — 바람 까마귀 · 어둠 검은 고양이 ·
  /// 독 두꺼비 · 빛 부엉이 · 불 꼬마 도마뱀, 그 밖이거나 없으면 호문쿨루스
  PetSpecies get firstPetSpecies => PetRules.firstPetFrom(elementScores,
      alchemyTop: alchemyIsTop);

  /// 큰 숙련도 중 연금술이 1등인지 (묶음 32 #189: 첫 펫·알 호문쿨루스)
  bool get alchemyIsTop => _topMastery() == Mastery.alchemy;

  /// 기운 공명 (묶음 32 #191): 펫 속성 = 내 주 속성
  bool petResonant(Pet p) => PetRules.resonant(p.species, mainElement);

  /// 원정 보내기 창 「잘 맞아요」 (묶음 32 #188): 그 목표에 특기가 맞는 펫 · 공명 펫.
  /// 물가 → 두꺼비 · 밤 → 검은 고양이 · 먼 목표 → 까마귀 · 강한 몬스터 → 부엉이 ·
  /// 먼 원정·기력이 많이 드는 원정 → 꼬마 도마뱀. 호문쿨루스는 표시 없이 무난
  bool petSuits(Pet p, FieldSpawn spawn) {
    if (petResonant(p)) return true;
    final route = routeFor(spawn);
    final from = _lastFix?.point;
    final dist = route?.lengthM ?? (from == null ? 0.0 : from.distanceTo(spawn.point));
    final far = dist >= PetRules.farM;
    return switch (p.species) {
      PetSpecies.toad => _waterside(route),
      PetSpecies.blackCat => FieldMonsterRules.isNight(_clock()),
      PetSpecies.crow => far,
      PetSpecies.owl => spawn.modifiers.isNotEmpty,
      PetSpecies.lizard =>
        far || VitalRules.expeditionCost(dist) >= PetRules.costlyMp,
      PetSpecies.homunculus => false,
      // 묶음 33 #185 희귀 펫
      PetSpecies.kelpie => _waterside(route),
      PetSpecies.griffin => far,
      PetSpecies.drake =>
        far || VitalRules.expeditionCost(dist) >= PetRules.costlyMp,
      PetSpecies.direwolf =>
        spawn.modifiers.isNotEmpty || Monsters.info(spawn.monster).isBoss,
      PetSpecies.mimic || PetSpecies.golem => false,
      // 묶음 49 #235 영웅 펫
      PetSpecies.wolf || PetSpecies.stag => far,
      PetSpecies.whale => _waterside(route) ||
          VitalRules.expeditionCost(dist) >= PetRules.costlyMp,
      PetSpecies.panther => FieldMonsterRules.isNight(_clock()),
      PetSpecies.phoenix || PetSpecies.turtle =>
        spawn.modifiers.isNotEmpty || Monsters.info(spawn.monster).isBoss,
      // 묶음 57 #244 전설 펫
      PetSpecies.pegasus || PetSpecies.unicorn => far,
      PetSpecies.leviathan => _waterside(route) ||
          VitalRules.expeditionCost(dist) >= PetRules.costlyMp,
      PetSpecies.nightmare => FieldMonsterRules.isNight(_clock()),
      PetSpecies.dragon || PetSpecies.behemoth =>
        spawn.modifiers.isNotEmpty || Monsters.info(spawn.monster).isBoss,
    };
  }

  /// 친밀도 오르는 양 (공명이면 1.5배, 조련사 교감이면 더, 소수는 확률로)
  int _bondGain(Pet p, int n) {
    if (n <= 0) return n;
    var x = n.toDouble();
    if (petResonant(p)) x *= PetRules.resonanceBond;
    x *= 1 + JobRules.tamerBond * jobTrait(JobId.tamer);
    x *= lumiBond; // 묶음 42 #226: 루미와 단짝이면 친밀도 더 (숨김)
    final whole = x.floor();
    return whole + (_random.nextDouble() < x - whole ? 1 : 0);
  }

  /// 이별 컷신 끝: 빛 조각에서 첫 펫이 태어난다. 가방의 알은 그대로 (이때 보인다).
  /// 이미 펫이 있으면 하나 더, 동행은 새 첫 펫. 정령 저장 값은 지우지 않는다.
  Future<Pet> completeFarewell(String name) async {
    final now = _clock();
    final p = _pets;
    final existing = firstPet;
    if (existing != null) return existing;
    final species = firstPetSpecies;
    final pet = Pet(
      uid: 'pet${p.nextId}',
      species: species,
      name: name.trim().isEmpty ? PetRules.info(species).name : name.trim(),
      bornAt: now,
    );
    final first = !p.farewellDone;
    await _savePets(p.copyWith(
      pets: [...p.pets, pet],
      companion: pet.uid,
      firstPet: pet.uid,
      nextId: p.nextId + 1,
      farewellAt: first ? now : null,
      firstSpiritName: first ? _profile.spiritName : null,
      firstSpiritKind: first ? _profile.spiritKind.name : null,
      // 태어난 뒤 걸음부터 센다
      stepsDay: first ? player.today?.dayKey : null,
      stepsCounted: first ? player.today?.steps ?? 0 : null,
      // 이별 전에 이미 지나간 날의 편지는 보내지 않는다
      skippedLetters: first
          ? [
              for (final l in PetRules.letters)
                if (_letterDue(l)) l.id,
            ]
          : null,
    ));
    // 묶음 34: Lv.12 이상이면 이별 뒤 바로 잿빛 틈 한마디
    _checkAct2();
    return pet;
  }

  /// 기록 탭 「○○와의 추억」: 처음 만난 날 · 함께한 날 수 · 함께 잡은 몬스터 수.
  /// 정령이 떠나기 전에는 null
  ({DateTime met, int days, int monsters})? get spiritMemory {
    final at = _pets.farewellAt;
    if (at == null || _history.isEmpty) return null;
    final met = _history.first.date;
    final end = DateTime(at.year, at.month, at.day);
    var monsters = 0;
    for (final d in _history) {
      if (d.date.isAfter(end)) break;
      monsters += d.huntCounts.isNotEmpty
          ? d.huntCounts.values.fold<int>(0, (a, b) => a + b)
          : d.purifiedMonsterIds.length;
    }
    final days =
        end.difference(DateTime(met.year, met.month, met.day)).inDays + 1;
    return (met: met, days: math.max(1, days), monsters: monsters);
  }

  /// 확률로 알 하나 (Lv.11 전에는 한 번만, 정령이 떠난 뒤에는 [chance])
  Future<bool> _maybeEgg(double chance, String source) async {
    if (_random.nextDouble() >= chance) return false;
    // 묶음 47 #240: 정령이 떠난 뒤 가방이 가득하면 알은 우편함에 (팔 수 없어 잃지 않게).
    // 떠나기 전 숨은 알은 그대로 (보이지 않아서)
    if (_pets.farewellDone && bagFree <= 0) {
      await _mailBagRest(const {'egg': 1}, title: '알 하나');
      _notify();
      return true;
    }
    final p = _pets;
    await _savePets(p.copyWith(
      eggs: [...p.eggs, PetEgg(id: 'egg${p.nextId}', source: source, element: mainElement?.name)],
      firstEggFound: true,
      nextId: p.nextId + 1,
    ));
    _newEgg = true;
    return true;
  }

  Future<void> _rollFieldEgg(ModGrade grade) async {
    if (!_pets.farewellDone) {
      if (_pets.firstEggFound || _pets.eggs.isNotEmpty) return;
      await _maybeEgg(PetRules.firstEggChance, 'field');
      return;
    }
    await _maybeEgg(PetRules.fieldEggChance(grade), 'field');
  }

  /// 방금 알을 얻었는지 (한 번 알려 주고 false)
  bool takeNewEgg() {
    final v = _newEgg;
    _newEgg = false;
    return v;
  }

  /// 알을 품는다 (정령이 떠난 뒤에만, 한 번에 하나)
  Future<bool> incubateEgg(String eggId) async {
    if (!_pets.farewellDone) return false;
    // 묶음 54: 펫 쉼터 ★3 → 알 두 개를 함께
    if (!canIncubateMore) return false;
    if (_pets.eggs.any((e) => e.id == eggId && e.incubatedAt != null)) return false;
    final now = _clock();
    // 묶음 42 #226: 루미의 둥지 장식 → 알이 조금 더 빨리 깨어남 (품은 때를 앞당겨 둠)
    final at = hasLumiNest
        ? now.subtract(PetRules.hatchTime * NpcRules.nestFaster)
        : now;
    await _savePets(_pets.copyWith(eggs: [
      for (final e in _pets.eggs) e.id == eggId ? e.incubate(at) : e,
    ]));
    await _npcUse(Npc.lumi);
    unawaited(notifier?.schedule(NotifyId.hatch, at.add(PetRules.hatchTime),
        '알이 깨어나려 해요', '가방에서 알을 확인하고 이름을 지어 주세요!'));
    return true;
  }

  /// 품은 알이 다 되었는지
  bool eggReady(PetEgg e) =>
      e.incubatedAt != null &&
      !_clock().isBefore(e.incubatedAt!.add(PetRules.hatchTime));

  PetEgg? get readyEgg {
    for (final e in _pets.eggs) {
      if (eggReady(e)) return e;
    }
    return null;
  }

  int hatchManaCost(PetEgg e) => e.incubatedAt == null
      ? 0
      : PetRules.hatchManaCost(e.incubatedAt!, _clock());
  int hatchGoldCost(PetEgg e) => e.incubatedAt == null
      ? 0
      : PetRules.hatchGoldCost(e.incubatedAt!, _clock());

  /// 마석이나 금화로 바로 깨운다
  Future<bool> hatchNow(String eggId, {required bool useMana}) =>
      _serial(() async {
    PetEgg? egg;
    for (final e in _pets.eggs) {
      if (e.id == eggId) egg = e;
    }
    if (egg == null || egg.incubatedAt == null) return false;
    final cost = useMana ? hatchManaCost(egg) : hatchGoldCost(egg);
    if (useMana ? player.manaStones < cost : player.gold < cost) return false;
    if (cost > 0) {
      final today = await _todayRecord();
      await _save(today.copyWith(
          spends: DailyRecord.addCounts(today.spends,
              {useMana ? Wallet.manaStone : Wallet.gold: cost})));
    }
    final done = _clock().subtract(PetRules.hatchTime);
    await _savePets(_pets.copyWith(eggs: [
      for (final e in _pets.eggs) e.id == eggId ? e.incubate(done) : e,
    ]));
    unawaited(notifier?.cancel(NotifyId.hatch));
    await _npcUse(Npc.lumi);
    return true;
  });

  /// 광고로 남은 시간 절반 (알 하나에 한 번, 묶음 32 #187)
  bool canAdHalveEgg(PetEgg e) =>
      adsReady &&
      e.incubatedAt != null &&
      !e.adHalved &&
      !eggReady(e);

  Future<bool> adHalveEgg(String eggId) async {
    PetEgg? egg;
    for (final e in _pets.eggs) {
      if (e.id == eggId) egg = e;
    }
    if (egg == null || !canAdHalveEgg(egg) || !await _watchAd('egg_half')) {
      return false;
    }
    return _serial(() async {
      final now = _clock();
      var changed = false;
      final eggs = [
        for (final e in _pets.eggs)
          if (e.id == eggId && e.incubatedAt != null && !e.adHalved)
            () {
              changed = true;
              final left = e.incubatedAt!.add(PetRules.hatchTime).difference(now);
              return e.incubate(e.incubatedAt!.subtract(left ~/ 2),
                  adHalved: true);
            }()
          else
            e,
      ];
      if (!changed) return false;
      await _savePets(_pets.copyWith(eggs: eggs));
      for (final e in eggs) {
        if (e.id == eggId) {
          unawaited(notifier?.schedule(NotifyId.hatch,
              e.incubatedAt!.add(PetRules.hatchTime),
              '알이 깨어나려 해요', '가방에서 알을 확인하고 이름을 지어 주세요!'));
        }
      }
      return true;
    });
  }

  /// 다 된 알에서 펫이 태어난다. 펫이 6마리면 null.
  Future<Pet?> hatch(String eggId, String name, {PetSpecies? species}) async {
    final p = _pets;
    if (p.pets.length >= PetRules.maxPets) return null;
    PetEgg? egg;
    for (final e in p.eggs) {
      if (e.id == eggId) egg = e;
    }
    if (egg == null || !eggReady(egg)) return null;
    // 묶음 49 #235: Lv.15부터 아주 드물게 영웅 펫 (안 나오면 다음 알부터 조금씩 오름)
    final heroOn = player.level.level >= PetRules.heroLevel;
    // 묶음 57 #244: Lv.21(3막)부터 아주 드물게 전설 펫 (전설 → 영웅 → 희귀 → 일반)
    final legendOn = player.level.level >= PetRules.legendLevel;
    final s = species ??
        PetRules.rollSpecies(_random,
            element: ElementRules.parse(egg.element),
            alchemyTop: alchemyIsTop,
            heroChance: heroOn ? PetRules.heroChance(p.heroMiss) : 0,
            legendChance: legendOn ? PetRules.legendChance(p.legendMiss) : 0);
    final legend = PetRules.isLegend(s);
    final hero = PetRules.isHero(s) || legend;
    final pet = Pet(
      uid: 'pet${p.nextId}',
      species: s,
      // 영웅 펫은 정해진 이름으로 (펫 탭에서 바꿀 수 있음)
      // 묶음 51: 마을 사람 이름(리안 등)은 펫 이름으로 쓰지 않는다
      name: hero
          ? PetRules.heroName(s)
          : name.trim().isEmpty || npcNameReserved(name)
              ? PetRules.info(s).name
              : name.trim(),
      bornAt: _clock(),
    );
    await _savePets(p.copyWith(
      eggs: [for (final e in p.eggs) if (e.id != eggId) e],
      pets: [...p.pets, pet],
      nextId: p.nextId + 1,
      heroMiss: PetRules.isHero(s) ? 0 : (heroOn && species == null && !legend ? p.heroMiss + 1 : p.heroMiss),
      legendMiss: legend ? 0 : (legendOn && species == null ? p.legendMiss + 1 : p.legendMiss),
    ));
    await _npcTally(NpcTally.hatch);
    return pet;
  }

  /// 묶음 30: 조련사 → 펫 성장, 문지기의 후계자 → 첫 펫 성장 (숨김)
  int _petGrowth(String uid, int exp) {
    if (exp <= 0) return exp;
    var f = 1 + JobRules.tamerGrowth * jobTrait(JobId.tamer);
    if (uid == _pets.firstPet) {
      f += JobRules.gateHeirGrowth * jobTrait(JobId.gateHeir);
    }
    return (exp * f).round();
  }

  /// 펫 경험치·친밀도를 더한다
  Future<void> _givePetExp(String uid, int exp, {int bond = 0}) async {
    final pet = _pets.byUid(uid);
    if (pet == null) return;
    await _savePets(_pets.replace(pet.copyWith(
      exp: pet.exp + _petGrowth(uid, exp),
      bond: math.min(PetRules.maxBond, pet.bond + _bondGain(pet, bond)),
    )));
  }

  /// 동행 펫이 함께 걸은 걸음 (100보마다 경험치 1)
  Future<void> _petSteps() async {
    final pet = companionPet;
    final today = player.today;
    if (pet == null || today == null) return;
    final day = today.dayKey;
    final counted = _pets.stepsDay == day ? _pets.stepsCounted : 0;
    // 승객 모드 (11-11 #61): 차 안의 걸음은 펫 경험치에 세지 않는다
    if (passengerMode) {
      await _savePets(_pets.copyWith(
          stepsDay: day, stepsCounted: math.max(counted, today.steps)));
      return;
    }
    final gained = (today.steps - counted) ~/ 100;
    if (gained <= 0) {
      if (_pets.stepsDay != day) {
        await _savePets(_pets.copyWith(stepsDay: day, stepsCounted: 0));
      }
      return;
    }
    // 묶음 31: 함께 달리기 → 잠시 동안 걸음 경험치 두 배 + 조금 더 친해짐 (숨김)
    final run = skillTimedOn(JobSkill.runTogether);
    var exp = _petGrowth(pet.uid, gained * PetRules.expPer100Steps);
    var bond = pet.bond;
    if (run) {
      exp = (exp * (1 + JobRules.runTogether * skillPower(JobSkill.runTogether)))
          .round();
      bond = math.min(PetRules.maxBond, bond + gained ~/ 5);
    }
    await _savePets(_pets
        .replace(pet.copyWith(exp: pet.exp + exp, bond: bond))
        .copyWith(stepsDay: day, stepsCounted: counted + gained * 100));
  }

  /// 주간 의뢰를 모두 끝낸 주 2번마다 알 하나 (정령이 떠난 뒤)
  Future<void> _checkBoardEggs() async {
    final at = _pets.farewellAt;
    if (at == null || _history.isEmpty) return;
    final perWeek = BoardRules.weekly(const []).length;
    final done = <String, int>{};
    for (var i = 0; i < _history.length; i++) {
      final r = _history[i];
      if (r.date.isBefore(DateTime(at.year, at.month, at.day))) continue;
      final n = BoardRules.weeklyCompletedOn(_history, i);
      if (n <= 0) continue;
      final w = TownRules.weekStart(r.date).toIso8601String().substring(0, 10);
      done[w] = (done[w] ?? 0) + n;
    }
    final fullWeeks = [
      for (final e in done.entries)
        if (e.value >= perWeek) e.key,
    ]..sort();
    final due = fullWeeks.length ~/ PetRules.boardEggEveryWeeks;
    final given = _pets.boardEggWeeks.length;
    if (due <= given) return;
    var p = _pets;
    // 묶음 47 #240: 의뢰 보상 알은 가방이 가득하면 우편함에
    var free = bagFree;
    var mailed = 0;
    for (var k = given; k < due; k++) {
      final week = fullWeeks[(k + 1) * 2 - 1];
      if (free <= 0) {
        mailed++;
        p = p.copyWith(boardEggWeeks: [...p.boardEggWeeks, week]);
        continue;
      }
      free--;
      p = p.copyWith(
        eggs: [...p.eggs, PetEgg(id: 'egg${p.nextId}', source: 'board', element: mainElement?.name)],
        nextId: p.nextId + 1,
        boardEggWeeks: [...p.boardEggWeeks, week],
      );
    }
    if (mailed > 0) await _mailBagRest({'egg': mailed}, title: '주간 의뢰 보상 알');
    await _savePets(p);
    _newEgg = true;
  }

  /// 데리고 다닐 펫을 고른다
  Future<void> setCompanion(String uid) async {
    if (_pets.byUid(uid) == null || petInTraining(uid)) return;
    await _savePets(_pets.copyWith(companion: uid));
  }

  /// 펫 이름을 바꾼다 (무료)
  /// 이름을 바꿨으면 true. 마을 사람 이름(리안 등)은 쓸 수 없다 (묶음 51)
  Future<bool> renamePet(String uid, String name) async {
    final pet = _pets.byUid(uid);
    if (pet == null || name.trim().isEmpty || npcNameReserved(name) || NameRules.banned(name)) return false;
    await _savePets(_pets.replace(pet.copyWith(name: name.trim())));
    return true;
  }

  /// 마을 사람 이름인지 (각성자·펫 이름으로 못 씀)
  bool npcNameReserved(String name) =>
      VillageRules.npcs.any((n) => n.name == name.trim());

  /// 재료를 먹이로 준다 (일반 +3, 귀한 +15, 친밀도 +1)
  Future<bool> feedMaterial(String uid, MaterialId m) =>
      _serial(() async {
    final pet = _pets.byUid(uid);
    if (pet == null || player.materialCount(m) <= 0) return false;
    final today = await _todayRecord();
    await _save(today.copyWith(
        spends: DailyRecord.addCounts(today.spends, {m.name: 1})));
    final base =
        Materials.info(m).rare ? PetRules.expRareFood : PetRules.expCommonFood;
    // 같은 속성 재료는 경험치 1.5배 (11-11 #63)
    final same = pet.element != null && Materials.elementOf(m) == pet.element;
    await _givePetExp(
        uid, same ? (base * PetRules.sameElementFood).round() : base,
        bond: PetRules.bondPerFood);
    return true;
  });

  /// 펫 간식을 준다 (동행 펫이 아니어도)
  Future<bool> feedSnack(String uid) =>
      _serial(() async {
    final pet = _pets.byUid(uid);
    if (pet == null || bagCount(ShopItem.bulssiPotion) <= 0) return false;
    final today = await _todayRecord();
    await _save(today.copyWith(
        itemsUsed: [...today.itemsUsed, ShopItem.bulssiPotion.name]));
    await _givePetExp(uid, PetRules.expSnack, bond: PetRules.bondPerSnack);
    await _npcTally(NpcTally.snack);
    return true;
  });

  /// 자연으로 돌려보낸다: 마석 (5 + 레벨 × 2) + 좋아하던 재료 3개.
  /// 마지막 한 마리와 원정 중인 펫은 돌려보낼 수 없다.
  Future<bool> releasePet(String uid) =>
      _serial(() async {
    final pet = _pets.byUid(uid);
    if (pet == null || _pets.pets.length <= 1 || isAway(uid)) return false;
    // 묶음 29 #182: 빛 조각에서 태어난 첫 펫은 돌려보낼 수 없다
    if (uid == _pets.firstPet) return false;
    await _grant(0, PetRules.releaseMana(pet.level),
        {pet.info.favorite: PetRules.releaseMaterials});
    final rest = [for (final p in _pets.pets) if (p.uid != uid) p];
    await _savePets(PetState.fromJson({
      ..._pets.toJson(),
      'pets': [for (final p in rest) p.toJson()],
      'companion': _pets.companion == uid
          ? (_pets.firstPet ?? rest.first.uid)
          : _pets.companion,
    }));
    return true;
  });

  // ───────────── 정령 편지

  /// 각성한 날부터 며칠째인지 (첫날 = 1)
  int get awakenedDays {
    if (_history.isEmpty) return 0;
    final first = _history.first.date;
    final now = _clock();
    return DateTime(now.year, now.month, now.day)
            .difference(DateTime(first.year, first.month, first.day))
            .inDays +
        1;
  }

  bool _letterDue(LetterInfo l) =>
      (l.level != null && player.level.level >= l.level!) ||
      (l.days != null && awakenedDays >= l.days!);

  /// 새로 온 편지 (한 번 알려 주고 null)
  LetterInfo? takeNewLetter() {
    final l = _newLetter;
    _newLetter = null;
    return l;
  }

  LetterInfo? get pendingLetter => _newLetter;

  /// 받은 편지 (받은 순서)
  List<LetterInfo> get receivedLetters => [
        for (final id in _pets.letters)
          for (final l in PetRules.letters)
            if (l.id == id) l,
      ];

  Future<void> _checkLetters() async {
    if (!_pets.farewellDone) return;
    for (final l in PetRules.letters) {
      if (_pets.letters.contains(l.id) || _pets.skippedLetters.contains(l.id)) {
        continue;
      }
      if (!_letterDue(l)) continue;
      // 11-11 #65: 편지와 선물은 우편함으로 (편지 탭에 계속 남는다)
      await _sendMail(MailItem(
        id: 'spirit_${l.id}',
        kind: MailKind.letter,
        from: firstSpiritName,
        title: l.title,
        body: l.body,
        gifts: {
          if (l.gold > 0) Wallet.gold: l.gold,
          if (l.manaStones > 0) Wallet.manaStone: l.manaStones,
          if (l.snacks > 0) 'item:${ShopItem.bulssiPotion.name}': l.snacks,
          if (l.compasses > 0) 'item:${ShopItem.expeditionCompass.name}': l.compasses,
          if (l.recipeNotes > 0) 'note': l.recipeNotes,
          if (l.eggs > 0) 'egg': l.eggs,
        },
        sentAt: _clock(),
      ));
      await _savePets(_pets.copyWith(letters: [..._pets.letters, l.id]));
      _newLetter = l;
    }
  }
}
