part of '../app_controller.dart';

/// 튜토리얼(Lv.1~2)·기능 안내(Lv.3~6)·레벨 잠금 (묶음 21: [AppController] 에서 나눔. 상태 칸은 본체에 있다)
extension TutorialOps on AppController {

  /// 게시판 안내 중 「지도에서 깨기」: 바로 옆에 몬스터 하나
  FieldSpawn? get guideSpawn {
    if (!_guideHunt || inTutorial) return null;
    final center = _lastFix?.point ?? fallbackCenter;
    if (center == null) return null;
    final today = player.today;
    if (today?.purifiedSpawnIds.contains(AppController.guideHuntId) ?? false) return null;
    return FieldSpawn(
        id: AppController.guideHuntId,
        monster: MonsterId.slime,
        point: GeoPoint(center.lat + 0.00027, center.lng));
  }

  set guideHunt(bool on) {
    if (_guideHunt == on) return;
    _guideHunt = on;
    final s = guideSpawn;
    if (on && s != null) requestMapFocus(s.point);
    _notify();
  }

  /// 채집 안내 중: 바로 옆 꽃 자리 (위치가 없으면 null)
  HarvestSpot? get guideHarvestSpot {
    for (final s in harvestSpots) {
      if (s.id == 'tutorial-harvest') return s;
    }
    return null;
  }

  set guideHarvest(bool on) {
    if (_harvestTutorial == on) return;
    _harvestTutorial = on;
    _spotsKey = null;
    final s = on ? guideHarvestSpot : null;
    if (s != null) requestMapFocus(s.point);
    _notify();
  }

  /// 안내가 비출 지도 위 자리 (튜토리얼 몬스터 · 안내 몬스터 · 안내 꽃)
  ({String id, GeoPoint point})? get guideMapTarget {
    if (inTutorial) {
      final s = tutorialSpawn;
      return s == null ? null : (id: s.id, point: s.point);
    }
    final g = guideSpawn;
    if (g != null) return (id: g.id, point: g.point);
    if (_harvestTutorial) {
      final h = guideHarvestSpot;
      if (h != null) return (id: h.id, point: h.point);
    }
    return null;
  }

  /// 게시판 안내: 받은 의뢰가 없으면 첫 칸에 쉬운 의뢰를 붙인다
  Future<void> prepareGuideErrand() async {
    final b = board;
    if (b.doneToday > 0 || b.slots.any((s) => s.accepted)) return;
    if (b.slots.any((s) => s.templateId == BoardRules.guideErrand.id)) return;
    final slots = [...b.slots];
    if (slots.isEmpty) return;
    slots[0] = ErrandSlot(templateId: BoardRules.guideErrand.id);
    await _saveBoard(b.copyWith(slots: slots));
  }

  /// 채집 도구를 받았는지 (첫 채집 도구는 대장간에서 무료)
  bool get harvestToolsReady => _harvest.granted;

  /// 도구가 없어 채집할 수 없는지 (묶음 20: 새로 시작한 사람만. 기존 사용자는 그대로)
  /// 묶음 22: 모두 같은 규칙 (기존 사용자는 우편으로 한 벌을 받는다)
  bool get harvestNeedsTool => !_harvest.granted;

  /// 「새로 열렸어요」 카드를 이미 보여 줬는지 (한 번만, 묶음 22)
  bool featureAnnounced(Feature f) => _introsSeen.contains('opened:${f.name}');

  Future<void> markFeatureAnnounced(Feature f) async {
    if (featureAnnounced(f)) return;
    _introsSeen = {..._introsSeen, 'opened:${f.name}'};
    await _saveGates();
    _notify();
  }

  /// 지금까지 채집한 횟수
  int get harvestTotal => _harvest.total;

  /// 첫 채집 도구 만들기 (무료): 모든 기본 도구를 새것으로
  Future<bool> makeFirstTools() async {
    if (_harvest.granted || gotGift(Gift.firstTools)) return false;
    await _saveHarvest(_harvest.copyWith(granted: true, tools: {
      for (final t in HarvestTool.values) t.name: toolMaxOf(t),
    }));
    await _markGift(Gift.firstTools);
    _notify();
    return true;
  }

  /// 한 번만 주는 선물을 이미 받았는지 (묶음 23)
  bool gotGift(String id) => _gifts.contains(id);

  Future<void> _markGift(String id) async {
    if (_gifts.contains(id)) return;
    _gifts = {..._gifts, id};
    await _saveGifts();
  }

  Future<void> _saveGifts() =>
      store.saveJson(AppController._giftsKey, {'got': _gifts.toList()});

  /// 지금 튜토리얼 단계 (끝났거나 기존 사용자면 [TutorialStep.done])
  TutorialStep get tutorialStep => TutorialStep.values[
      _tutorial.clamp(0, TutorialStep.values.length - 1)];

  bool get inTutorial => tutorialStep != TutorialStep.done;

  Future<void> _setTutorial(TutorialStep step) async {
    _tutorial = step.index;
    await store.saveJson(AppController._tutorialKey, {'step': _tutorial});
    _notify();
  }

  /// 튜토리얼 건너뛰기 (진행·물건은 그대로)
  Future<void> skipTutorial() => _setTutorial(TutorialStep.done);

  /// 가방을 열어 받은 것을 봤을 때
  Future<void> tutorialBagSeen() async {
    if (tutorialStep == TutorialStep.bag) {
      await _setTutorial(TutorialStep.expedition);
    }
  }

  /// 튜토리얼 몬스터: 첫째는 바로 옆(걸어갈 필요 없음), 둘째는 조금 떨어진 곳(정령 원정)
  /// 묶음 18 #148: 첫째는 내 위치 바로 위쪽(약 30m), 둘째는 걸어가기엔 조금 먼
  /// 위쪽(약 250m). 둘 다 화면 위쪽 절반에 오도록 북쪽에 둔다. #149 하늘 슬라임
  List<FieldSpawn> _tutorialSpawns(GeoPoint center) => switch (tutorialStep) {
        TutorialStep.hunt || TutorialStep.intro || TutorialStep.bag => [
            if (tutorialStep != TutorialStep.bag)
              FieldSpawn(
                  id: AppController.tutorialHuntId,
                  monster: MonsterId.slime,
                  point: GeoPoint(center.lat + 0.00027, center.lng)),
          ],
        TutorialStep.expedition => [
            FieldSpawn(
                id: AppController.tutorialExpeditionId,
                monster: MonsterId.slime,
                point: GeoPoint(center.lat + 0.0021, center.lng + 0.0008)),
          ],
        _ => const [],
      };

  /// 연출을 보고 「어? 바로 옆에 뭔가 있어!」를 눌렀을 때 (#140)
  Future<void> finishIntro() async {
    if (tutorialStep != TutorialStep.intro) return;
    await _setTutorial(TutorialStep.hunt);
    final s = tutorialSpawn;
    if (s != null) requestMapFocus(s.point);
  }

  /// 이번 묶음(16) 뒤에 새로 시작한 사람 (레벨 잠금·기능 안내를 받는 사람)
  bool get newGates => !_legacyGates;

  bool featureOpen(Feature f) =>
      _legacyGates || player.level.level >= AppController.featureLevel[f]!;

  /// 초반 재료만 떨어뜨리는지 (새로 시작한 사람 Lv.5까지, #129)
  bool get earlyLoot => !_legacyGates && player.level.level <= 5;

  /// 게시판 전체(주간·긴급)는 Lv.5부터 (새로 시작한 사람만)
  bool get boardFull => _legacyGates || player.level.level >= 5;

  /// 막 열린 기능의 안내 (레벨업 창 등을 닫은 뒤 한 번)
  Feature? get pendingFeatureIntro {
    if (_legacyGates || inTutorial || pendingLevelUp != null) return null;
    for (final f in Feature.values) {
      // 묶음 25 #165: 능력치 안내는 Lv.2 에서만 시작한다 (이미 Lv.3 이상이면 넘김)
      if (f == Feature.stats && player.level.level >= 3) continue;
      if (featureOpen(f) && !_introsSeen.contains(f.name)) return f;
    }
    return null;
  }

  Future<void> markFeatureIntro(Feature f) async {
    _introsSeen = {..._introsSeen, f.name};
    _harvestTutorial = false;
    _guideHunt = false;
    _spotsKey = null;
    await _saveGates();
    _notify();
  }

  Future<void> _saveGates() => store.saveJson(AppController._gatesKey, {
        'legacy': _legacyGates,
        'seen': _introsSeen.toList(),
        'hpTip': _hpTipShown,
      });

  /// 처음으로 HP가 절반 아래가 됐을 때 한 번 회복 팁 (#141)
  bool takeHpTip() {
    if (_hpTipShown || _legacyGates || maxHp <= 0 || hp * 2 >= maxHp) {
      return false;
    }
    _hpTipShown = true;
    unawaited(_saveGates());
    return true;
  }

  /// 튜토리얼 첫 몬스터 (지금 단계가 아니면 null)
  FieldSpawn? get tutorialSpawn {
    for (final s in todaySpawns) {
      if (AppController.isTutorialSpawn(s.id)) return s;
    }
    return null;
  }

  /// 튜토리얼 몬스터를 잡았을 때: 첫째 → 가방 보기, 둘째 → Lv.2 (두 마리째에 딱 오르게)
  Future<void> _tutorialPurified(String spawnId) async {
    if (spawnId == AppController.tutorialHuntId && tutorialStep == TutorialStep.hunt) {
      // 묶음 18 #151: 원정에서 바로 돌아오기에 쓸 마석 1개는 꼭 받는다
      if (player.manaStones < 1) await _grant(0, 1, const {});
      await _setTutorial(TutorialStep.bag);
    } else if (spawnId == AppController.tutorialExpeditionId) {
      final need = LevelRules.totalExpToReach(2) - _fullExp;
      if (need > 0) {
        final today = await _todayRecord();
        await _save(today.copyWith(
            gains: {...today.gains, 'exp': (today.gains['exp'] ?? 0) + need}));
      }
      await _setTutorial(TutorialStep.done);
    }
  }

  /// 지금 위치에서 만난 필드 몬스터 (없으면 null)
  FieldSpawn? get nearbySpawn {
    final fix = _lastFix;
    if (fix == null) return null;
    return FieldMonsterRules.encounter(
        area: area, spawns: todaySpawns, fix: fix, exclusions: exclusions);
  }

  Battle? startFieldBattle(FieldSpawn spawn) {
    if (!canFightNow || hp <= 0) return null;
    _stopResting();
    final p = player;
    return Battle.forPlayer(
      level: p.level.level,
      stats: combatStats,
      floors: BattleRules.fieldFoes(
          level: p.level.level,
          monster: spawn.monster,
          mods: spawn.modifiers,
          spawnId: spawn.id),
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

  /// 필드 전투가 끝났을 때. 잡으면 보상, 황금빛이 도망치면 오늘은 다시 나오지 않는다.
  Future<int> finishFieldBattle(FieldSpawn spawn, Battle battle) =>
      _serial(() async {
    await keepBattleHp(battle);
    if (battle.ticks > 0) {
      await _wear(EquipmentRules.fieldWear);
      await _spendBattleBuffs();
    }
    _lastReward = const HuntReward();
    if (battle.phase == BattlePhase.escaped) {
      final today = await _todayRecord();
      await _save(today.copyWith(
          fledSpawnIds: [...today.fledSpawnIds, spawn.id]));
      return 0;
    }
    if (battle.phase == BattlePhase.failed) {
      final today = await _todayRecord();
      if (!today.lostSpawnIds.contains(spawn.id)) {
        await _save(
            today.copyWith(lostSpawnIds: [...today.lostSpawnIds, spawn.id]));
      }
      await _defeated();
      return 0;
    }
    if (battle.phase != BattlePhase.cleared) return 0;
    return _recordFieldPurify(spawn.id, spawn.monster, spawn.point,
        mods: spawn.modifiers, count: battle.floors.length);
  });

  /// 필드 몬스터 정화를 기록한다 (직접 잡았든 정령이 잡았든 같다).
  /// 하루 5마리까지만 경험치·마석·재료를 준다.
  ///
  /// 수식어(11-10): 경험치 보너스, 마석·금화·재료 추가. 무리·분열·동료는 마리 수만큼
  /// 받지만 하루 5마리 제한에는 1마리로 센다.
  Future<int> _recordFieldPurify(
    String spawnId,
    MonsterId monster,
    GeoPoint point, {
    List<ModifierId> mods = const [],
    int count = 1,
  }) async {
    final today = await _todayRecord();
    _lastReward = const HuntReward();
    if (today.purifiedSpawnIds.contains(spawnId)) return 0;
    if (AppController.isTutorialSpawn(spawnId)) {
      final got = await _recordFieldPurifyInner(spawnId, monster, point,
          mods: mods, count: count, today: today);
      // 튜토리얼 원정은 도착할 때 기록하고, 다음 단계(Lv.2)는 돌아왔을 때 (#172)
      if (spawnId != AppController.tutorialExpeditionId) {
        await _tutorialPurified(spawnId);
      }
      return got;
    }
    return _recordFieldPurifyInner(spawnId, monster, point,
        mods: mods, count: count, today: today);
  }

  Future<int> _recordFieldPurifyInner(
    String spawnId,
    MonsterId monster,
    GeoPoint point, {
    required List<ModifierId> mods,
    required int count,
    required DailyRecord today,
  }) async {
    // 11-11 #69: 하루 5마리 뒤에도 사냥은 되고 경험치·마석만 줄어든다 (숨은 규칙)
    const paid = true;
    final n = today.fieldMonstersPurified;
    final factor = RuleConstants.fieldFactor(n + 1);
    final incense = TownRules.incenseActive(today)
        ? RuleConstants.incenseExpMultiplier
        : 1;
    // 규칙이 하루 기록에서 계산하는 몫 (이 마리 수만큼 늘어나는 것)
    int ruleExp(int c) =>
        (RuleConstants.fieldUnits(c) * RuleConstants.fieldMonsterExp * incense)
            .round();
    final baseExp = ruleExp(n + 1) - ruleExp(n);
    // 수식어·속성 보너스와 마리 수 (11-11: 기록에 남겨 경험치에 더한다)
    var exp = (RuleConstants.fieldMonsterExp *
            incense *
            factor *
            (ModifierRules.expMultiplier(mods) + Monsters.info(monster).expBonus) *
            count)
        .round();
    // 승객 모드 (11-11 #61): 사냥 보상 절반 (원정은 보낼 때 승객이었으면)
    final half = passengerMode || _drive.passengerSpawns.contains(spawnId);
    if (half) exp = exp ~/ 2;
    // 지친 상태 (11-11 #75, 숨김): 경험치 -20%
    final tiredNow = tired;
    final tiredExp = tiredNow ? exp - _tiredCut(exp) : 0;
    exp -= tiredExp;
    // 묶음 25 #171: Lv.5까지(잡는 순간 레벨) 필드 몬스터 경험치 두 배 (숨은 규칙)
    if (player.level.level <= 5) exp *= 2;
    // 기본 마석 1개는 규칙(하루 5마리)으로 계산하고, 나머지는 기록에 더한다
    final mats = <MaterialId, int>{};
    var extraMana = 0, gold = 0;
    if (paid) {
      for (var i = 0; i < count; i++) {
        LootRules.field(monster, _random,
                early: earlyLoot,
                rareBonus: StatRules.rareDropBonus(combatStats) +
                    (plentyActive ? LootRules.dropsOf(monster).chance * 0.5 : 0))
            .forEach((k, v) => mats[k] = (mats[k] ?? 0) + v);
        // 풍요의 물약: 재료 +1
        if (plentyActive) {
          final d = LootRules.dropsOf(monster);
          final extra = d.common[_random.nextInt(d.common.length)];
          mats[extra] = (mats[extra] ?? 0) + 1;
        }
      }
      final b = ModifierRules.bonus(monster, mods, _random);
      b.materials.forEach((k, v) => mats[k] = (mats[k] ?? 0) + v);
      extraMana = ((((count - 1) * RuleConstants.crystalsPerFieldMonster) +
                  b.manaStones) *
              factor)
          .floor();
      gold = b.gold;
      if (half) {
        for (final k in [...mats.keys]) {
          final v = mats[k]! ~/ 2;
          v > 0 ? mats[k] = v : mats.remove(k);
        }
        extraMana ~/= 2;
        gold ~/= 2;
      }
      // 가방이 가득하면 남는 재료는 금화로 (11-11 #48)
      final fit = _fitBag(mats);
      mats
        ..clear()
        ..addAll(fit.kept);
      gold += fit.gold;
    }
    final fieldMana = (RuleConstants.fieldUnits(n + 1) *
                RuleConstants.crystalsPerFieldMonster)
            .floor() -
        (RuleConstants.fieldUnits(n) * RuleConstants.crystalsPerFieldMonster)
            .floor() +
        extraMana;
    final tiredMana = tiredNow ? fieldMana - _tiredCut(fieldMana) : 0;
    final modKey = ModifierRules.recordInCodex(mods)
        ? ModifierRules.codexKey(monster, mods)
        : null;
    await _save(today.copyWith(
      fieldMonstersPurified: today.fieldMonstersPurified + 1,
      purifiedSpawnIds: [...today.purifiedSpawnIds, spawnId],
      purifiedMonsterIds: _addMonsters(today, [monster]),
      huntCounts: _addCounts(today, List.filled(count, monster)),
      gains: DailyRecord.addCounts(today.gains, {
        ...HuntReward.ledger(
            extraManaStones: extraMana, gold: gold, materials: mats),
        if (exp + tiredExp != baseExp) Wallet.exp: exp + tiredExp - baseExp,
      }),
      modHunts: modKey == null
          ? null
          : DailyRecord.addCounts(today.modHunts, {modKey: 1}),
      counters: DailyRecord.addCounts(today.counters, {
        if (mods.isNotEmpty) 'modded': 1,
        if (ModifierRules.gradeOf(mods).index >= ModGrade.rare.index)
          'rarePlus': 1,
        for (final m in mods) 'mod:${m.name}': 1,
        if (FieldMonsterRules.isNight(_clock())) 'nightHunts': count,
        if (today.lostSpawnIds.contains(spawnId)) 'revenge': 1,
        ..._elementCounters(List.filled(count, monster)),
        if (tiredExp > 0) TownRules.tiredExpKey: tiredExp,
        if (tiredMana > 0) TownRules.tiredManaKey: tiredMana,
      }),
    ));
    _lastReward = HuntReward(
      exp: exp,
      manaStones: fieldMana - tiredMana,
      gold: gold,
      materials: mats,
    );
    await _rollFieldEgg(ModifierRules.gradeOf(mods));
    switch (ModifierRules.gradeOf(mods)) {
      case ModGrade.rare:
        await _maybeNote(AlchemyRules.noteFromRare);
      case ModGrade.legend:
        await _maybeNote(AlchemyRules.noteFromLegend);
      default:
        break;
    }
    if (!_resolving && companionPet != null) {
      await _givePetExp(companionPet!.uid, PetRules.expPerHunt * count);
    }
    return exp;
  }

  /// 많이 사냥한 날 가끔 정령(펫)이 넌지시 (6마리째부터 세 번에 한 번, 숫자는 말하지 않는다)
  String? get tiredHuntLine {
    final n = player.today?.fieldMonstersPurified ?? 0;
    if (n <= RuleConstants.maxFieldMonstersPerDay || n % 3 != 0) return null;
    return '오늘은 많이 싸웠어. 좀 쉬어도 돼.';
  }
}
