part of '../app_controller.dart';

/// 정령 이별·펫·정령 편지 (묶음 21: [AppController] 에서 나눔. 상태 칸은 본체에 있다)
extension PetsOps on AppController {

  PetState get pets => _pets;

  /// 정령이 떠났는지 (Lv.11)
  bool get farewellDone => _pets.farewellDone;

  /// 데리고 다니는 펫 (정령이 떠나기 전에는 null)
  Pet? get companionPet => _pets.farewellDone ? _pets.companionPet : null;

  /// 말풍선·원정에 나오는 동료 이름 (정령 또는 데리고 다니는 펫)
  String get companionName => companionPet?.name ?? _profile.spiritName;

  /// 처음 함께한 정령 이름 (떠난 뒤 프로필·기록에)
  String get firstSpiritName => _pets.firstSpiritName ?? _profile.spiritName;

  Future<void> _savePets(PetState p) async {
    _pets = p;
    await store.saveJson(AppController._petsKey, p.toJson());
    _notify();
  }

  /// 이별 연출을 보여 줄 때인지: Lv.11 이상, 아직 함께, 정령 원정이 없음
  bool get farewellPending =>
      !_pets.farewellDone &&
      player.level.level >= PetRules.farewellLevel &&
      _vitals.expeditions.isEmpty;

  /// 정령 짝 펫 (첫 펫 확률을 조금 올린다)
  PetSpecies get _favoredSpecies => switch (_profile.spiritKind) {
        SpiritKind.fire => PetSpecies.lizard,
        SpiritKind.water => PetSpecies.toad,
        SpiritKind.plant => PetSpecies.owl,
      };

  /// 이별 때 깨어날 펫 (연출에서 한 번 뽑아 이름을 짓게 한다)
  PetSpecies rollFirstPet() => PetRules.rollSpecies(_random,
      favored: _favoredSpecies, element: mainElement);

  /// 이별 때 가방에 알이 있었는지 (없으면 정령이 선물 알을 남긴다)
  bool get hasEggForFarewell => _pets.eggs.isNotEmpty;

  /// 정령이 떠나고 첫 펫이 태어난다. 가방의 알 하나를 쓰고, 없으면 선물 알.
  Future<Pet> completeFarewell(PetSpecies species, String name) async {
    final now = _clock();
    final p = _pets;
    final eggs = [...p.eggs];
    if (eggs.isNotEmpty) eggs.removeAt(0);
    final pet = Pet(
      uid: 'pet${p.nextId}',
      species: species,
      name: name.trim().isEmpty ? PetRules.info(species).name : name.trim(),
      bornAt: now,
    );
    await _savePets(p.copyWith(
      eggs: eggs,
      pets: [...p.pets, pet],
      companion: pet.uid,
      farewellAt: now,
      firstSpiritName: _profile.spiritName,
      firstSpiritKind: _profile.spiritKind.name,
      nextId: p.nextId + 1,
      // 태어난 뒤 걸음부터 센다
      stepsDay: player.today?.dayKey,
      stepsCounted: player.today?.steps ?? 0,
      // 이별 전에 이미 지나간 날의 편지는 보내지 않는다
      skippedLetters: [
        for (final l in PetRules.letters)
          if (_letterDue(l)) l.id,
      ],
    ));
    return pet;
  }

  /// 확률로 알 하나 (Lv.11 전에는 한 번만, 정령이 떠난 뒤에는 [chance])
  Future<bool> _maybeEgg(double chance, String source) async {
    if (_random.nextDouble() >= chance) return false;
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
    if (_pets.eggs.any((e) => e.incubatedAt != null)) return false;
    final now = _clock();
    await _savePets(_pets.copyWith(eggs: [
      for (final e in _pets.eggs) e.id == eggId ? e.incubate(now) : e,
    ]));
    unawaited(notifier?.schedule(NotifyId.hatch, now.add(PetRules.hatchTime),
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
  Future<bool> hatchNow(String eggId, {required bool useMana}) async {
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
    return true;
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
    final s = species ??
        PetRules.rollSpecies(_random, element: ElementRules.parse(egg.element));
    final pet = Pet(
      uid: 'pet${p.nextId}',
      species: s,
      name: name.trim().isEmpty ? PetRules.info(s).name : name.trim(),
      bornAt: _clock(),
    );
    await _savePets(p.copyWith(
      eggs: [for (final e in p.eggs) if (e.id != eggId) e],
      pets: [...p.pets, pet],
      nextId: p.nextId + 1,
    ));
    return pet;
  }

  /// 펫 경험치·친밀도를 더한다
  Future<void> _givePetExp(String uid, int exp, {int bond = 0}) async {
    final pet = _pets.byUid(uid);
    if (pet == null) return;
    await _savePets(_pets.replace(pet.copyWith(
      exp: pet.exp + exp,
      bond: math.min(PetRules.maxBond, pet.bond + bond),
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
    await _savePets(_pets
        .replace(pet.copyWith(exp: pet.exp + gained * PetRules.expPer100Steps))
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
    for (var k = given; k < due; k++) {
      p = p.copyWith(
        eggs: [...p.eggs, PetEgg(id: 'egg${p.nextId}', source: 'board', element: mainElement?.name)],
        nextId: p.nextId + 1,
        boardEggWeeks: [...p.boardEggWeeks, fullWeeks[(k + 1) * 2 - 1]],
      );
    }
    await _savePets(p);
    _newEgg = true;
  }

  /// 데리고 다닐 펫을 고른다
  Future<void> setCompanion(String uid) async {
    if (_pets.byUid(uid) == null) return;
    await _savePets(_pets.copyWith(companion: uid));
  }

  /// 펫 이름을 바꾼다 (무료)
  Future<void> renamePet(String uid, String name) async {
    final pet = _pets.byUid(uid);
    if (pet == null || name.trim().isEmpty) return;
    await _savePets(_pets.replace(pet.copyWith(name: name.trim())));
  }

  /// 재료를 먹이로 준다 (일반 +3, 귀한 +15, 친밀도 +1)
  Future<bool> feedMaterial(String uid, MaterialId m) async {
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
  }

  /// 펫 간식을 준다 (동행 펫이 아니어도)
  Future<bool> feedSnack(String uid) async {
    final pet = _pets.byUid(uid);
    if (pet == null || bagCount(ShopItem.bulssiPotion) <= 0) return false;
    final today = await _todayRecord();
    await _save(today.copyWith(
        itemsUsed: [...today.itemsUsed, ShopItem.bulssiPotion.name]));
    await _givePetExp(uid, PetRules.expSnack, bond: PetRules.bondPerSnack);
    return true;
  }

  /// 자연으로 돌려보낸다: 마석 (5 + 레벨 × 2) + 좋아하던 재료 3개.
  /// 마지막 한 마리와 원정 중인 펫은 돌려보낼 수 없다.
  Future<bool> releasePet(String uid) async {
    final pet = _pets.byUid(uid);
    if (pet == null || _pets.pets.length <= 1 || isAway(uid)) return false;
    await _grant(0, PetRules.releaseMana(pet.level),
        {pet.info.favorite: PetRules.releaseMaterials});
    final rest = [for (final p in _pets.pets) if (p.uid != uid) p];
    await _savePets(PetState.fromJson({
      ..._pets.toJson(),
      'pets': [for (final p in rest) p.toJson()],
      'companion': _pets.companion == uid ? rest.first.uid : _pets.companion,
    }));
    return true;
  }

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
