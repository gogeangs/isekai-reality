part of '../app_controller.dart';

/// 던전·필드 전투·전투 설정·패배 (묶음 21: [AppController] 에서 나눔. 상태 칸은 본체에 있다)
extension BattleOps on AppController {

  // ───────────────────────────────────────────── 던전 · 필드 몬스터

  /// 지금 싸울 수 있는지. 차량 속도로 움직이는 중에는 전투하지 않는다.
  bool get canFightNow {
    final fix = _lastFix;
    return fix == null || ExplorationRules.countsAsExploring(fix);
  }

  /// 지금 미궁 입구 근처인지 (던전 보상 1.5배, 장소 전용 몬스터)
  bool get atGate {
    final fix = _lastFix;
    if (fix == null) return false;
    return ExplorationRules.placesInReach(area, fix.point)
        .any((p) => p.kind == PlaceKind.labyrinthGate);
  }

  /// 오늘 경험치를 받을 수 있는 던전 횟수가 남았는지
  bool get dungeonExpLeftToday =>
      (player.today?.dungeonRuns.length ?? 0) <
      RuleConstants.maxDungeonRunsPerDay;

  /// 던전을 연다. 열쇠가 없거나 이동 중이면 null.
  /// 열쇠는 전투가 끝날 때([finishDungeon]) 쓴다. 중간에 나가면 쓰지 않는다.
  /// HP가 0이면 싸울 수 없다 (여관에서 쉬거나 물약·걷기로 채운다).
  /// 여관에서 쉬는 중이었다면 싸우는 순간 휴식이 끝난다 (화면에서 먼저 묻는다).
  Battle? startDungeon() {
    final p = player;
    if (p.gauge.keysAvailable <= 0 || !canFightNow || hp <= 0) return null;
    _stopResting();
    return Battle.forPlayer(
      level: p.level.level,
      stats: combatStats,
      floors: BattleRules.dungeonFloors(
          level: p.level.level, atGate: atGate, rng: _random, day: _clock()),
      rng: _random,
      startHp: hp,
      skillChargeTicks: _skillTicks(p),
      gear: gear,
      petSkill: companionPet?.info.skill,
      petAdult: companionPet?.adult ?? false,
      potions: battlePotions,
      autoHp: _alc.autoHp,
      autoCure: _alc.autoCure,
      resist: activeResists,
      skillElement: companionPet?.element,
      mainElement: mainElement,
      weaponPotion: weaponPotionElement,
      telegraphs: true,
      heroSkills: true,
    );
  }

  int _skillTicks(PlayerState p) {
    final ex = expedition;
    if (ex != null && !ex.finished) {
      return Battle.skillUnavailable; // 동료가 원정을 가 있다
    }
    return TownRules.potionActive(p.today)
        ? RuleConstants.potionSkillChargeTicks
        : RuleConstants.skillChargeTicks;
  }

  /// 전투가 끝났거나 중간에 나왔을 때 남은 HP를 저장한다
  Future<void> keepBattleHp(Battle battle) async {
    await _consumeBattlePotions(battle);
    _vitals = _vitals.copyWith(hp: battle.playerHp, lastMaxHp: maxHp);
    await store.saveVitals(_vitals);
    _notify();
  }

  /// 던전이 끝났을 때 결과를 기록한다. 받은 경험치를 돌려준다.
  Future<int> finishDungeon(Battle battle, {required bool atGate}) async {
    if (!battle.isOver) return 0;
    await keepBattleHp(battle);
    await _wear(EquipmentRules.dungeonWear);
    await _spendBattleBuffs();
    final today = await _todayRecord();
    final run = DungeonRun(
        cleared: battle.phase == BattlePhase.cleared, atGate: atGate);
    var exp = today.dungeonRuns.length < RuleConstants.maxDungeonRunsPerDay
        ? ExpRules.dungeonRunExp(run)
        : 0;
    var mana = run.cleared
        ? RuleConstants.crystalsPerDungeonClear
        : RuleConstants.crystalsPerDungeonFail;
    // 지친 상태 (11-11 #75): 경험치·마석 -20% (숨김)
    final tiredExp = tired ? exp - _tiredCut(exp) : 0;
    final tiredMana = tired ? mana - _tiredCut(mana) : 0;
    exp -= tiredExp;
    mana -= tiredMana;
    if (run.cleared && _pets.farewellDone) {
      await _maybeEgg(PetRules.dungeonEggChance, 'dungeon');
    }
    if (run.cleared) await _maybeNote(AlchemyRules.noteFromDungeon);
    final loot = LootRules.dungeon(
        cleared: run.cleared, rng: _random, boss: battle.floors.last.monster);
    // 던전 전용 재료 (11-11 #59)
    GatherRules.dungeon(run.cleared, _random)
        .forEach((k, v) => loot[k] = (loot[k] ?? 0) + v);
    final fit = _fitBag(loot);
    final mats = fit.kept;
    await _save(today.copyWith(
      dungeonRuns: [...today.dungeonRuns, run],
      purifiedMonsterIds: _addMonsters(today, battle.purified),
      huntCounts: _addCounts(today, battle.purified),
      gains: DailyRecord.addCounts(today.gains,
          HuntReward.ledger(materials: mats, gold: fit.gold)),
      counters: DailyRecord.addCounts(today.counters, {
        if (FieldMonsterRules.isNight(_clock()))
          'nightHunts': battle.purified.length,
        ..._elementCounters(battle.purified),
        if (tiredExp > 0) TownRules.tiredExpKey: tiredExp,
        if (tiredMana > 0) TownRules.tiredManaKey: tiredMana,
      }),
    ));
    if (!run.cleared) await _defeated();
    if (companionPet != null && battle.purified.isNotEmpty) {
      await _givePetExp(
          companionPet!.uid, PetRules.expPerHunt * battle.purified.length);
    }
    _lastReward = HuntReward(
      exp: exp,
      manaStones: mana,
      gold: fit.gold,
      materials: mats,
    );
    return exp;
  }

  /// 방금 끝난 사냥·던전의 보상 (결과 화면에 보여 준다)
  HuntReward get lastReward => _lastReward;

  /// 오늘 아직 사냥하지 않은 필드 몬스터 (11-11 #69: 5마리 뒤에도 계속 나온다)
  List<FieldSpawn> get todaySpawns {
    final today = player.today;
    final done = {...?today?.purifiedSpawnIds, ...?today?.fledSpawnIds};
    for (final away in activeExpeditions) {
      done.add(away.spawnId);
    }
    // 묶음 18 #150: 튜토리얼 중에는 튜토리얼 몬스터만
    if (inTutorial) {
      return _tutorialSpawns(
              _lastFix?.point ?? fallbackCenter ?? area.bounds.center)
          .where((s) => !done.contains(s.id))
          .toList();
    }
    final center = _lastFix?.point ?? fallbackCenter;
    if (center == null) return const [];
    return FieldMonsterRules.spawnsFor(area, _clock(),
            center: center,
            roads: roads,
            exclusions: exclusions,
            level: player.level.level,
            luckBonus: StatRules.modifierBonus(combatStats),
            favored: ElementRules.challengers(mainElement),
            land: lands?.kindAt)
        .followedBy(calledSpawns) // 부르는 물약 (11-11 #57)
        .followedBy(_tutorialSpawns(center))
        .followedBy([if (guideSpawn != null) guideSpawn!])
        .where((s) => !done.contains(s.id))
        .toList();
  }

  /// 도감 펫 탭이 열렸는지 (묶음 15 #116): 정령과 이별한 뒤(알 부화가 가능해진 뒤)에만.
  /// 그 전에는 알이 있어도 숨긴다 (펫이 드러나지 않게)
  bool get petCodexOpen => _pets.farewellDone;

  /// 펫 탭에 새 표시 (아직 열어 보지 않았으면)
  bool get petCodexNew => petCodexOpen && !_petCodexSeen;

  /// 「새 도감이 열렸어요」를 아직 알리지 않았으면 true
  bool get petCodexToAnnounce => petCodexOpen && !_petCodexAnnounced;

  Future<void> markPetCodexSeen() async {
    if (_petCodexSeen) return;
    _petCodexSeen = true;
    await _saveFeel();
  }

  Future<void> markPetCodexAnnounced() async {
    if (_petCodexAnnounced) return;
    _petCodexAnnounced = true;
    await _saveFeel();
  }

  bool get vibrate => _vibrate;
  bool get sound => _sound;
  bool get fastBattle => _fastBattle;

  /// 처음 중독됐을 때 해독제 안내를 이미 보여 줬는지
  bool get poisonTipSeen => _poisonTipSeen;

  Future<void> _saveFeel() async {
    await store.saveJson(AppController._feelKey, {
      'vibrate': _vibrate,
      'sound': _sound,
      'fast': _fastBattle,
      'poisonTip': _poisonTipSeen,
      'petCodex': _petCodexSeen,
      'petCodexNotice': _petCodexAnnounced,
      'adPersonal': _adPersonal,
    });
    _notify();
  }
  bool? get adPersonal => _adPersonal;

  Future<void> setAdPersonal(bool on) async {
    _adPersonal = on;
    await _saveFeel();
    _notify();
  }

  Future<void> setVibrate(bool on) async {
    _vibrate = on;
    await _saveFeel();
  }

  Future<void> setSound(bool on) async {
    _sound = on;
    await _saveFeel();
  }

  Future<void> setFastBattle(bool on) async {
    _fastBattle = on;
    await _saveFeel();
  }

  Future<void> markPoisonTipSeen() async {
    if (_poisonTipSeen) return;
    _poisonTipSeen = true;
    await _saveFeel();
  }

  /// 지친 상태인지 (패배 뒤 1시간, 여관에 들르면 풀림). 경험치·마석이 줄어드는 정도는 숨김.
  bool get tired => _tiredUntil != null && _clock().isBefore(_tiredUntil!);

  /// 지친 상태가 풀리는 때
  DateTime? get tiredUntil => tired ? _tiredUntil : null;

  int _tiredCut(int v) => (v * RuleConstants.tiredRewardMultiplier).round();

  Future<void> _setTired(DateTime? until) async {
    _tiredUntil = until;
    await store.saveJson(
        AppController._tiredKey, {if (until != null) 'until': until.toIso8601String()});
  }

  /// 졌을 때: 입은 장비 내구도가 더 깎이고, 1시간 지친다 (겹치지 않고 시간만 다시).
  /// 금화·아이템은 잃지 않는다.
  Future<void> _defeated() async {
    await _wear(RuleConstants.defeatExtraWear);
    await _setTired(_clock().add(RuleConstants.tiredFor));
  }

  void _stopResting() {
    final restAt = _vitals.restStartedAt;
    if (restAt != null) {
      // 그때까지 찬 만큼은 그대로 가지고 간다 (묶음 15 #107)
      final f = TownRules.restProgress(restAt, _clock());
      final hp0 = _vitals.restHp0 ?? hp;
      final mp0 = _vitals.restMp0 ?? mp;
      _vitals = _vitals.copyWith(
          hp: math.max(hp, TownRules.restFill(hp0, maxHp, f)),
          mp: math.max(mp, TownRules.restFill(mp0, mpMax, f)),
          mpAt: _clock());
      _vitals = _vitals.copyWith(clearRest: true);
      unawaited(store.saveVitals(_vitals));
      unawaited(notifier?.cancel(NotifyId.rest));
    }
  }
}
