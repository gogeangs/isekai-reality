part of '../app_controller.dart';

/// 채집·채집 도구 (묶음 21: [AppController] 에서 나눔. 상태 칸은 본체에 있다)
extension HarvestOps on AppController {

  HarvestState get harvest => _harvest;

  Future<void> _saveHarvest(HarvestState h) async {
    _harvest = h;
    await _saveJson(AppController._harvestKey, h.toJson());
    _notify();
  }

  /// 지도에 보이는 채집 자리 (지금 위치 둘레 3km)
  List<HarvestSpot> get harvestSpots {
    if (inTutorial) return const []; // 묶음 18 #150
    // 묶음 28 #181: 막 열린 채집 자리 하나는 그날 내 가까이에 (안내 자리)
    final spots = _baseHarvestSpots();
    final guides = _guideHarvestSpots();
    final path = [..._pathFindSpots(), ..._skySpots(), ..._breadSpots(), ..._regionMatSpots()];
    if (guides.isEmpty && path.isEmpty) return spots;
    return [...path, ...guides, ...spots];
  }

  /// 길 찾기(탐험가): 쓴 자리 둘레 150~400m에 나에게만 보이는 채집 자리 하나와 보물 상자 하나
  List<HarvestSpot> _pathFindSpots() {
    if (!skillTimedOn(JobSkill.pathFind)) return const [];
    final m = _jobs.marks;
    final lat = m['pathFindLat'], lng = m['pathFindLng'];
    final until = _jobs.timed[JobSkill.pathFind.name];
    if (lat == null || lng == null || until == null) return const [];
    final key = until.millisecondsSinceEpoch;
    final rng = math.Random(key);
    final from = GeoPoint(lat / 1e6, lng / 1e6);
    GeoPoint around() {
      final d = 150 + rng.nextDouble() * 250;
      final b = rng.nextDouble() * 2 * math.pi;
      return GeoPoint(from.lat + d * math.cos(b) / 111320,
          from.lng + d * math.sin(b) / (111320 * math.cos(from.lat * math.pi / 180)));
    }

    const kinds = [
      HarvestKind.herb,
      HarvestKind.ore,
      HarvestKind.wood,
      HarvestKind.flower,
      HarvestKind.mushroom,
      HarvestKind.gem,
    ];
    final open = [
      for (final k in kinds)
        if (_legacyGates || _harvestAll || player.level.level >= HarvestRules.openLevel(k))
          k,
    ];
    final spotPoint = around(), chestPoint = around();
    return [
      if (open.isNotEmpty)
        HarvestSpot(
            id: 'pf-spot-$key',
            kind: open[rng.nextInt(open.length)],
            point: spotPoint),
      if (m['pfChestOpened'] != key % 1000000000)
        HarvestSpot(id: 'pf-chest-$key', kind: HarvestKind.relic, point: chestPoint),
    ];
  }

  /// 길 찾기 보물 상자인지 (도구 없이 연다)
  bool isTreasure(HarvestSpot s) =>
      s.id.startsWith('pf-chest-') || _isSkyChest(s) || _isRegionMat(s);

  /// 방금 연 보물 상자의 금화
  int get lastTreasureGold => _lastTreasureGold;

  /// 보물 상자를 연다: 금화와 재료 (한 번)
  Future<Map<MaterialId, int>?> openTreasure(HarvestSpot s) => _serial(() async {
        if (!isTreasure(s)) return null;
        final fix = _lastFix;
        if (fix == null || s.point.distanceTo(fix.point) > HarvestRules.reachM) {
          return null;
        }
        // 묶음 49 #235: 무가 찾은 하늘 상자
        if (_isSkyChest(s)) return _openSky(s);
        // 묶음 58: 등불 켠 지역 재료
        if (_isRegionMat(s)) return _openRegionMat(s);
        final key = int.tryParse(s.id.substring('pf-chest-'.length));
        if (key == null || _jobs.marks['pfChestOpened'] == key % 1000000000) {
          return null;
        }
        final gold = 50 + _random.nextInt(101);
        const pool = [
          MaterialId.herb,
          MaterialId.butterflyDust,
          MaterialId.waterJelly,
          MaterialId.essence,
          MaterialId.roughGem,
        ];
        final mats = <MaterialId, int>{};
        for (var i = 0; i < 2; i++) {
          final k = pool[_random.nextInt(pool.length)];
          mats[k] = (mats[k] ?? 0) + 1;
        }
        await _grant(gold, 0, mats);
        await _saveJobs(_jobs.copyWith(
            marks: {..._jobs.marks, 'pfChestOpened': key % 1000000000}));
        _lastTreasureGold = gold;
        _notify();
        return mats;
      });

  /// 새로 열린 채집 자리를 그날 가까이(50~150m)에 하나씩 (#179처럼 그날 고정)
  List<HarvestSpot> _guideHarvestSpots() {
    if (_legacyGates || _lastFix == null) return const [];
    final day = DailyRecord.dayKeyOf(_clock());
    final pending = pendingFeatureIntro;
    final out = <HarvestSpot>[];
    for (final (f, kind) in const [
      (Feature.alchemy, HarvestKind.herb),
      (Feature.ore, HarvestKind.ore),
      (Feature.wood, HarvestKind.wood),
      (Feature.relic, HarvestKind.relic),
    ]) {
      final id = 'guide-${kind.name}';
      final pinned = _pinsDay == day && _pins.containsKey(id);
      if (!featureOpen(f) || (pending != f && !pinned)) continue;
      final p = _pinned(id, (h) => _clearSpotNear(h, near: true));
      if (p != null) out.add(HarvestSpot(id: id, kind: kind, point: p));
    }
    return out;
  }

  List<HarvestSpot> _baseHarvestSpots() {
    final center = _lastFix?.point ?? fallbackCenter;
    if (center == null) return const [];
    final lure = lureActive;
    final night = HarvestRules.isNight(_clock());
    final key = '${(center.lat * 1000).round()}_${(center.lng * 1000).round()}'
        '${lure ? 'L' : ''}${night ? 'N' : ''}${lands == null ? '' : 'P'}'
        'r${harvestMapRadius.round()}a${jobTrait(JobId.archaeologist)}'
        '${_legacyGates ? '' : 'v${player.level.level}${_harvestTutorial ? 'T' : ''}'}';
    if (key != _spotsKey) {
      _spotsKey = key;
      _spotsCache = HarvestRules.spotsAround(center,
          // 묶음 30: 약초꾼·길 찾기로 더 멀리 보이면 그만큼 더 둘러본다
          radiusM: math.max(HarvestRules.radiusM, harvestMapRadius + 100),
          roads: roads,
          exclusions: exclusions,
          places: area.places,
          excluded: area.isExcluded,
          density: lure ? AlchemyRules.lureHarvest : 1,
          night: night,
          land: lands?.kindAt);
      // 묶음 16 #143: 새로 시작한 사람은 Lv.5에 채집이 열리고, 처음엔 꽃·버섯 자리만
      if (!_legacyGates) {
        final lv = player.level.level;
        _spotsCache = lv < 5
            ? const []
            : [
                if (_harvestTutorial && _lastFix != null)
                  HarvestSpot(
                      id: 'tutorial-harvest',
                      kind: HarvestKind.flower,
                      // 묶음 26 #179: 처음 정한 자리에 고정
                      // 묶음 33 #199: 내 위치(화살표)와 겹치지 않게 25~40m 빈자리
                      point: _pinned('tutorial-harvest', _clearSpotNear) ??
                          _clearSpotNear(_lastFix!.point)),
                // 묶음 28 #181: 도구별로 레벨마다 나눠 연다 (업데이트 때 Lv.7 이상이던 사람은 모두)
                for (final x in _spotsCache)
                  if (_harvestAll || lv >= HarvestRules.openLevel(x.kind)) x,
              ];
      }
      // 묶음 31: 고고학자 옛 길 아는 자 → 꽃·버섯 자리 몇 곳이 고대 유물 자리로 (숨김)
      final at = jobTrait(JobId.archaeologist);
      if (at > 0 &&
          (_legacyGates ||
              _harvestAll ||
              player.level.level >= HarvestRules.openLevel(HarvestKind.relic))) {
        _spotsCache = [
          for (final x in _spotsCache)
            (x.kind == HarvestKind.flower || x.kind == HarvestKind.mushroom) &&
                    (x.id.codeUnits.fold<int>(7, (a, b) => (a * 31 + b) & 0xffff) %
                            100) <
                        (100 * 0.25 * JobRules.archaeologistRelic * at)
                ? HarvestSpot(id: x.id, kind: HarvestKind.relic, point: x.point)
                : x,
        ];
      }
    }
    return _spotsCache;
  }

  /// 마지막으로 받은 위치
  GeoPoint? get lastPoint => _lastFix?.point;

  /// 가까이 있는 채집 자리 (40m 안)
  HarvestSpot? get nearbyHarvest {
    final fix = _lastFix;
    if (fix == null) return null;
    HarvestSpot? best;
    double? bd;
    for (final s in harvestSpots) {
      final d = s.point.distanceTo(fix.point);
      if (d <= HarvestRules.reachM && (bd == null || d < bd)) {
        best = s;
        bd = d;
      }
    }
    return best;
  }

  int harvestCharges(HarvestSpot s) =>
      _harvest.chargesOf(s.id, _clock(), recharge: _spotRecharge);

  /// 다음 하나가 차기까지
  Duration? harvestRefill(HarvestSpot s) =>
      _harvest.spots[s.id]?.untilNext(_clock(), recharge: _spotRecharge);

  /// 도구 내구도 (처음 채집 전에는 새 도구로 친다)
  /// 묶음 23: 도구를 가지고 있을 때만 센다 (없으면 0, 「도구 필요」 규칙)
  int toolDurability(HarvestTool t) =>
      _harvest.granted ? _harvest.durability(t) : 0;

  /// 도구 최대 내구도 (등급에 따라)
  int toolMaxOf(HarvestTool t) => HarvestRules.toolMaxFor(_harvest.tierOf(t));

  ToolTier toolTier(HarvestTool t) => _harvest.tierOf(t);
  Element? toolElement(HarvestTool t) => _harvest.elementOf(t);

  /// 미니게임이 쉬워지는 정도 (도구 등급, 숨김)
  int harvestEase(HarvestKind k) =>
      _harvest.tierOf(HarvestRules.info(k).tool).index;

  /// 묶음 46 #233: 같은 종류에서 완벽이 이어진 수 (불꽃 아이콘, 숫자는 안 보임)
  int harvestKindStreak(HarvestKind k) => _harvest.kindStreak[k.name] ?? 0;

  /// 묶음 46 #234: 이 미니게임을 처음 하는지 (처음만 큰 설명)
  bool harvestGameFirst(HarvestKind k) => !_harvest.gamesSeen.contains(k.name);

  Future<void> markHarvestGameSeen(HarvestKind k) async {
    if (!harvestGameFirst(k)) return;
    await _saveHarvest(
        _harvest.copyWith(gamesSeen: [..._harvest.gamesSeen, k.name]));
  }

  /// 채집가 직업 (#55 각성 뒤, 지금은 늘 false. 규칙만 준비)
  bool get gatherer => false;

  /// 도구를 다음 등급으로 (묶음 70: 모두 대장간)
  CraftCheck canUpgradeTool(HarvestTool t) {
    final cost = HarvestRules.upgradeCost(_harvest.tierOf(t));
    if (cost == null) return CraftCheck.maxed;
    final p = player;
    for (final e in cost.mats.entries) {
      if (p.materialCount(e.key) < e.value) return CraftCheck.materials;
    }
    if (p.gold < cost.gold) return CraftCheck.gold;
    return CraftCheck.ok;
  }

  Future<bool> upgradeTool(HarvestTool t) =>
      _serial(() async {
    if (canUpgradeTool(t) != CraftCheck.ok) return false;
    final tier = _harvest.tierOf(t);
    final cost = HarvestRules.upgradeCost(tier)!;
    final today = await _todayRecord();
    await _save(today.copyWith(
        spends: DailyRecord.addCounts(today.spends, {
      for (final e in cost.mats.entries) e.key.name: e.value,
      Wallet.gold: cost.gold,
    })));
    final next = ToolTier.values[tier.index + 1];
    await _saveHarvest(_harvest.copyWith(
      tiers: {..._harvest.tiers, t.name: next.index},
      // 새 도구라 내구도를 다 채운다
      tools: {..._harvest.tools, t.name: HarvestRules.toolMaxFor(next)},
    ));
    return true;
  });

  /// 도구에 속성을 입힌다: 빛나는 속성 코어 1개 + 금화 100 (11-11 #83, #63과 같다).
  /// 그 속성의 귀한 재료가 더 잘 나온다 (숨김).
  Future<bool> imbueTool(HarvestTool t, Element e) =>
      _serial(() async {
    final core = EquipmentRules.imbueCore(e);
    if (player.materialCount(core) < 1 || player.gold < EquipmentRules.imbueGold) {
      return false;
    }
    final today = await _todayRecord();
    await _save(today.copyWith(
        spends: DailyRecord.addCounts(today.spends,
            {core.name: 1, Wallet.gold: EquipmentRules.imbueGold})));
    await _saveHarvest(
        _harvest.copyWith(elements: {..._harvest.elements, t.name: e.name}));
    return true;
  });

  HarvestCheck canHarvest(HarvestSpot s, {bool minigame = false}) {
    if (isTreasure(s)) return HarvestCheck.empty;
    final fix = _lastFix;
    if (fix == null || s.point.distanceTo(fix.point) > HarvestRules.reachM) {
      return HarvestCheck.far;
    }
    if (driveBlocked) return HarvestCheck.passenger;
    if (harvestCharges(s) <= 0) return HarvestCheck.empty;
    if (harvestNeedsTool) return HarvestCheck.noTool;
    if (!minigame) return HarvestCheck.ok;
    if (passengerMode) return HarvestCheck.passenger;
    if (!standingStill) return HarvestCheck.moving;
    if (toolDurability(s.info.tool) <= 0) return HarvestCheck.noTool;
    return HarvestCheck.ok;
  }

  /// 채집한다. [grade] 가 quick 이면 빠른 채집, 아니면 미니게임 결과.
  /// [rare]: 묶음 46 미니게임이 정한 귀한 재료 (true 꼭 · false 없음 · null 보통처럼)
  Future<Map<MaterialId, int>?> harvestAt(HarvestSpot s, HarvestGrade grade,
          {bool? rare}) =>
      _serial(() async {
    final minigame = grade != HarvestGrade.quick;
    // 묶음 31: 채집 감각 → 잠시 동안 「좋음」이 가끔 「완벽」으로 (숨김)
    if (grade == HarvestGrade.good &&
        skillTimedOn(JobSkill.harvestSense) &&
        _random.nextDouble() <
            0.5 * skillPower(JobSkill.harvestSense)) {
      grade = HarvestGrade.perfect;
    }
    if (canHarvest(s, minigame: minigame) != HarvestCheck.ok) return null;
    if (s.id == 'tutorial-harvest') {
      // 채집 안내 끝: 다음부터는 보통 자리만
      _harvestTutorial = false;
      _spotsKey = null;
    }
    final now = _clock();
    var h = _harvest;
    if (!h.granted) {
      h = h.copyWith(granted: true, tools: {
        for (final t in HarvestTool.values) t.name: toolMaxOf(t),
      });
    }
    final charge = h.spots[s.id] ??
        SpotCharge(charges: HarvestRules.maxCharges, at: now);
    final tool = s.info.tool;
    // 한 종류에서 완벽을 많이 쌓았으면 빠른 채집도 「좋음」 (11-11 #83, 숨김)
    final effective =
        !minigame && h.mastered(s.kind) ? HarvestGrade.good : grade;
    final streak = !minigame
        ? h.streak
        : grade == HarvestGrade.perfect
            ? h.streak + 1
            : 0;
    final rolled = HarvestRules.yieldOf(s.kind, effective, _random,
        factor: passengerMode ? 0.5 : 1,
        tier: h.tierOf(tool),
        streak: grade == HarvestGrade.perfect ? h.streak : 0,
        element: h.elementOf(tool),
        month: now.month,
        forceRare: minigame ? rare : null,
        land: lands?.kindAt(s.point),
        night: HarvestRules.isNight(now));
    // 묶음 27 #176: 그 종류(약초·광석·나무) 채집 숙련도 → 가끔 하나 더, 도구가 가끔 안 닳음 (숨김)
    final hk = MasteryRules.harvestKind(s.kind);
    final hf = hk == null ? 0.0 : _detailFrac(MasteryRules.harvestKey(hk));
    final mats = {...rolled};
    if (mats.isNotEmpty && _masteryRoll(MasteryRules.harvestExtra * hf)) {
      final k = mats.keys.first;
      mats[k] = mats[k]! + 1;
    }
    final keepTool =
        minigame && _masteryRoll(MasteryRules.harvestToolSave * hf);
    final relic = s.kind == HarvestKind.relic;
    // 묶음 30·31: 풍요의 손길 → 이번 채집 두 배 / 발굴 → 귀한 유물 재료 꼭 /
    // 보석 세공사 → 보석을 가끔 하나 더 / 뿌리째 캐기 → 남은 횟수를 쓰지 않음 (숨김)
    if (mats.isNotEmpty) {
      if (relic) {
        if (await _consumeSkill(JobSkill.excavate)) {
          final r = HarvestRules.info(s.kind).rare;
          mats[r] = math.max(1, mats[r] ?? 0);
        }
      } else if (await _consumeSkill(JobSkill.bountyTouch)) {
        for (final k in [...mats.keys]) {
          mats[k] = mats[k]! * 2;
        }
      }
      final gems = [
        for (final k in mats.keys)
          if (k.name.startsWith('gem') || k == MaterialId.roughGem) k,
      ];
      if (gems.isNotEmpty && _jobRoll(JobId.jeweler, JobRules.jewelerGem)) {
        mats[gems.first] = mats[gems.first]! + 1;
      }
    }
    // 길 찾기 자리: 귀한 재료가 꼭
    if (s.id.startsWith('pf-spot-') && mats.isNotEmpty) {
      final r = HarvestRules.info(s.kind).rare;
      mats[r] = math.max(1, mats[r] ?? 0);
    }
    // 묶음 48 #230: 약초밭이 열린 뒤 약초·꽃·버섯 채집에서 가끔 그 자리의 씨앗
    // 묶음 54: 버섯 수프 → 그날 채집할 때 가끔 하나 더 (숨김)
    if (mats.isNotEmpty &&
        mealOn(Meal.mushroomSoup) &&
        _random.nextDouble() < BuildingRules.soupExtra) {
      final k = mats.keys.first;
      mats[k] = mats[k]! + 1;
    }
    // 묶음 57 #244: 고르(베히모스)와 함께면 채집할 때 가끔 하나 더 (마레는 묶음 58부터 물가를 걸을 때 — _mareWalk)
    // 묶음 57 #249: 숲의 각인(생산 주 + 보조 채집가) → 가끔 하나 더 (숨김)
    if (mats.isNotEmpty) {
      final more = (_heroWith(PetSpecies.behemoth) ? PetRules.behemothExtra : 0) +
          0.12 * imprintOf(JobId.herbalist, combat: false);
      if (more > 0 && _random.nextDouble() < more) {
        final k = mats.keys.first;
        mats[k] = mats[k]! + 1;
      }
    }
    final seed = mats.isNotEmpty ? _rollGatherSeed(s.kind) : null;
    if (seed != null) mats[seed] = (mats[seed] ?? 0) + 1;
    final keepCharge = await _consumeSkill(JobSkill.rootPull);
    h = h.copyWith(
      spots: keepCharge
          ? h.spots
          : {...h.spots, s.id: charge.use(now, recharge: _spotRecharge)},
      tools: minigame && !keepTool
          ? {...h.tools, tool.name: math.max(0, h.durability(tool) - 1)}
          : h.tools,
      total: h.total + 1,
      streak: streak,
      perfects: grade == HarvestGrade.perfect
          ? {...h.perfects, s.kind.name: (h.perfects[s.kind.name] ?? 0) + 1}
          : h.perfects,
      relics: relic ? h.relics + 1 : h.relics,
      // 묶음 46 #233: 같은 종류 완벽 연속 (불꽃)
      kindStreak: minigame
          ? {
              ...h.kindStreak,
              s.kind.name: grade == HarvestGrade.perfect
                  ? (h.kindStreak[s.kind.name] ?? 0) + 1
                  : 0,
            }
          : h.kindStreak,
    ).pruned(now);
    // 묶음 13 C8: 유물 이야기는 보류. 이야기 칸만 비우고 유물·재료는 그대로
    _lastRelicLore = relic && HarvestRules.relicLore.isNotEmpty
        ? HarvestRules.relicLore[(h.relics - 1) % HarvestRules.relicLore.length]
        : null;
    // 묶음 28 #181: 고대 유물을 처음 세 번 캘 때 예언 조각 하나씩 (차례대로)
    _lastProphecy = null;
    if (relic && _prophecy < HarvestRules.prophecy.length) {
      _lastProphecy = _prophecy;
      _prophecy++;
      await _saveJson(AppController._prophecyKey, {'got': _prophecy});
    }
    await _saveHarvest(h);
    await _grant(0, 0, mats);
    // 묶음 42 #226: 마르타·엘리엘 부탁 (물가 · 고대 유물)
    if (s.kind == HarvestKind.water) await _npcTally(NpcTally.water);
    // 묶음 45 #231: 작은 부탁 · 게시판 쪽지 (채집 모두 · 종류별)
    await _npcTally(NpcTally.gather);
    await _npcTally(NpcTally.gatherOf(s.kind.name));
    await _count('harvest');
    if (relic) await _npcTally(NpcTally.relic);
    if (seed != null) {
      await _npcTally(NpcTally.seedFound);
      await _seeSeeds([seed]);
    }
    await gainMastery(Mastery.harvest, MasteryRules.harvestOnce,
        details: [if (hk != null) MasteryRules.harvestKey(hk)]);
    if (relic) {
      final today = await _todayRecord();
      await _save(today.copyWith(
          counters: DailyRecord.addCounts(today.counters, {'relicDug': 1})));
    }
    // 묶음 32 #189: 물가 → 물, 광석 → 금속, 나무·약초 → 대지 (숨은 속성 점수)
    switch (s.kind) {
      case HarvestKind.water:
        await _gainElement(Element.water, ElementRules.waterScore);
      case HarvestKind.ore || HarvestKind.gem:
        await _gainElement(Element.metal, ElementRules.oreScore);
      case HarvestKind.wood || HarvestKind.herb:
        await _gainElement(Element.earth, ElementRules.woodScore);
      default:
        break;
    }
    return mats;
  });

  /// 방금 캔 고대 유물의 이야기 (없으면 null)
  String? get lastRelicLore => _lastRelicLore;

  /// 방금 얻은 예언 조각 번호 (0~2, 없으면 null). 한 번 꺼내면 비운다
  int? takeProphecy() {
    final p = _lastProphecy;
    _lastProphecy = null;
    return p;
  }

  /// 모은 예언 조각 글귀 (기록 탭)
  List<String> get prophecyPieces => [
        for (var i = 0; i < _prophecy; i++) HarvestRules.prophecy[i].$1,
      ];

  /// 도구 수리: 금화 30 + 재료 1 (묶음 70 #302: 모두 대장간)
  Future<bool> repairTool(HarvestTool t) =>
      _serial(() async {
    if (!_harvest.granted || _harvest.durability(t) >= toolMaxOf(t)) {
      return false;
    }
    final m = HarvestRules.repairMaterial(t);
    if (player.gold < HarvestRules.repairGold || player.materialCount(m) <= 0) {
      return false;
    }
    final today = await _todayRecord();
    await _save(today.copyWith(
        spends: DailyRecord.addCounts(
            today.spends, {Wallet.gold: HarvestRules.repairGold, m.name: 1})));
    await _saveHarvest(_harvest.copyWith(
        tools: {..._harvest.tools, t.name: toolMaxOf(t)}));
    return true;
  });
}
