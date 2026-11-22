part of '../app_controller.dart';

/// 결말 뒤 (묶음 51): 다른 각성자와의 만남(#242) · 주점 · 리안 · 거래소 완공 · 바르칸(#229, 서버 전).
/// 순서 = 결말 뒤 첫 마을 방문: 탑 불꽃 → 만남 장면 → 주점 / 그다음 마을 방문: 거래소 완공 → 바르칸.
extension TavernOps on AppController {
  TavernState get tavern => _tavern;

  String get _tavernDay => DailyRecord.dayKeyOf(_clock());

  // ───────────── 만남 · 주점 · 거래소가 열리는 때

  /// 만남 장면을 보여 줄 때 (본체를 쓰러뜨리고 결말을 본 뒤, 마을 소개를 본 뒤, 한 번)
  bool get meetPending =>
      _act2.kingDone &&
      _act2.endingSeen &&
      _village.contains('intro') &&
      !_village.contains('meet') &&
      !inTutorial;

  /// 만남 장면의 마지막 줄을 넘겼을 때: 주점이 바로 열린다
  Future<void> markMeetSeen() => _markVillage(['meet']);

  bool get tavernOpen => _village.contains('meet');
  bool get marketOpen => _village.contains('market');

  /// 마을에 들어올 때마다: 만남을 본 다음 방문이면 거래소가 완공된다 (한 방문에 몰리지 않게)
  Future<void> villageVisit() async {
    if (!tavernOpen || marketOpen) return;
    await _markVillage(['market', 'barkanDay:$_tavernDay']);
  }

  /// 거래소가 완공된 날 미나 말풍선 (한 번)
  String? _takeMinaBarkan() {
    if (!marketOpen || _village.contains('minaBarkan')) return null;
    if (!_village.contains('barkanDay:$_tavernDay')) return null;
    unawaited(_markVillage(['minaBarkan']));
    return VillageRules.minaBarkan;
  }

  /// 「새로 열렸어요」 주점 카드 (한 번)
  bool get tavernIntroPending =>
      _tourHold.contains('tavern') ||
      tavernOpen &&
      !_village.contains('tavernCard') &&
      !inTutorial &&
      pendingFeatureIntro == null &&
      !skillIntroPending &&
      !farewellPending;

  Future<void> markTavernIntro() async {
    endTour('tavern');
    await _markVillage(['tavernCard']);
  }

  // ───────────── 한 끼 식사 (하루 한 번, 그날 자정까지 걸을 때만)

  /// 오늘 먹었는지
  bool get ateToday => _tavern.mealDay == _tavernDay;

  /// 오늘 먹은 끼니 (없으면 null)
  Meal? get todayMeal => ateToday ? _mealOf(_tavern.meal) : null;

  Meal? _mealOf(String? name) {
    for (final m in Meal.values) {
      if (m.name == name) return m;
    }
    return null;
  }

  /// 지금 효과가 있는 끼니. 리안과 단짝이면 다음 날 새벽까지 조금 더 (숨김)
  /// 묶음 54: 주점 ★3 → 다음 날 낮까지 (숨김)
  Meal? get activeMeal {
    final today = todayMeal;
    if (today != null) return today;
    final now = _clock();
    final until = _star(Building.tavern, 3)
        ? BuildingRules.mealUntilHour
        : _bestWith(Npc.lian)
            ? TavernRules.bestUntilHour
            : 0;
    if (now.hour >= until) return null;
    final yesterday =
        DailyRecord.dayKeyOf(DateTime(now.year, now.month, now.day - 1));
    return _tavern.mealDay == yesterday ? _mealOf(_tavern.meal) : null;
  }

  bool mealOn(Meal m) => activeMeal == m;

  /// 한 끼 값 (리안의 낡은 나침반이 있으면 조금 싸게)
  int mealPrice(Meal m) {
    final p = TavernRules.meal(m).price;
    return hasRelic(Npc.lian) ? (p * TavernRules.compassPrice).round() : p;
  }

  /// 한 끼를 먹는다 (하루 한 번). 못 먹으면 false
  Future<bool> eatMeal(Meal m) => _serial(() async {
        if (!tavernOpen || ateToday) return false;
        if (!mealMenu.any((x) => x.id == m)) return false;
        final price = mealPrice(m);
        if (player.gold < price) return false;
        final today = await _todayRecord();
        await _save(today.copyWith(
            spends: DailyRecord.addCounts(today.spends, {Wallet.gold: price})));
        final day = _tavernDay;
        final p = player.today;
        // 먹기 전에 걸은 걸음은 세지 않는다 (걸을 때만 효과)
        _tavern = _tavern.copyWith(
          mealDay: day,
          meal: m.name,
          meals: _tavern.meals + 1,
          walkDay: day,
          walkSteps: _tavern.walkDay == day
              ? math.max(_tavern.walkSteps, p?.steps ?? 0)
              : (p?.steps ?? 0),
        );
        await _saveTavern();
        await _npcUse(Npc.lian);
        await _npcTally(NpcTally.meal);
        await _smallTrigger(Npc.lian);
        _notify();
        return true;
      });

  // ───────────── 소문판 (하루 한 번)

  bool get rumorHeardToday => _tavern.rumorDay == _tavernDay;

  String get todayRumor => TavernRules.rumorOf(_tavernDay);

  /// 오늘 소문을 듣는다 (하루 한 번, 들르기와 따로 시설 쓰기로 셈)
  Future<String> hearRumor() => _serial(() async {
        if (!rumorHeardToday) {
          _tavern = _tavern.copyWith(rumorDay: _tavernDay);
          await _saveTavern();
          await _npcUse(Npc.lian);
          await _smallTrigger(Npc.lian);
          _notify();
        }
        return todayRumor;
      });

  // ───────────── 걸을 때 효과 (고기 스튜 · 배낭 매듭 · 동전 주머니)

  bool get _wearsKnot =>
      _armory.worn.any((i) => i.base == EquipBase.lianKnot);

  Future<void> _tavernWalk() async {
    final today = player.today;
    if (today == null) return;
    final day = today.dayKey;
    final from = _tavern.walkDay == day ? _tavern.walkSteps : 0;
    final to = today.steps;
    if (to <= from && _tavern.walkDay == day) return;
    final stew = mealOn(Meal.stew);
    final knot = _wearsKnot;
    final purse = hasRelic(Npc.barkan);
    if (stew || knot) {
      final k = to ~/ 1000 - from ~/ 1000;
      final add = k *
          ((stew ? TavernRules.stewMp : 0) + (knot ? TavernRules.knotMp : 0));
      if (add > 0 && mp < mpMax) {
        _vitals = _vitals.copyWith(mp: math.min(mpMax, mp + add));
        await store.saveVitals(_vitals);
      }
    }
    if (purse) {
      final k = to ~/ TavernRules.purseSteps - from ~/ TavernRules.purseSteps;
      if (k > 0) await _grant(TavernRules.purseGold * k, 0, const {});
    }
    _tavern = _tavern.copyWith(walkDay: day, walkSteps: math.max(from, to));
    await _saveTavern();
  }

  // ───────────── 꿀빵: 그날 처음 자리 둘레에 채집 자리가 조금 더

  List<HarvestSpot> _breadSpots() {
    if (!mealOn(Meal.honeyBread)) return const [];
    final day = _tavernDay;
    final from = _nearDay == day ? _nearAnchor : _lastFix?.point;
    if (from == null) return const [];
    final rng = math.Random('meal-$day'.hashCode);
    const kinds = [
      HarvestKind.herb,
      HarvestKind.flower,
      HarvestKind.mushroom,
      HarvestKind.wood,
      HarvestKind.ore,
    ];
    final open = [
      for (final k in kinds)
        if (_legacyGates || _harvestAll || player.level.level >= HarvestRules.openLevel(k))
          k,
    ];
    if (open.isEmpty) return const [];
    return [
      for (var i = 0; i < TavernRules.breadSpots; i++)
        () {
          final d = TavernRules.breadMinM +
              rng.nextDouble() * (TavernRules.breadMaxM - TavernRules.breadMinM);
          final b = rng.nextDouble() * 2 * math.pi;
          return HarvestSpot(
            id: 'meal-$day-$i',
            kind: open[rng.nextInt(open.length)],
            point: GeoPoint(
                from.lat + d * math.cos(b) / 111320,
                from.lng +
                    d * math.sin(b) / (111320 * math.cos(from.lat * math.pi / 180))),
          );
        }(),
    ];
  }

  /// 매운 꼬치: 필드 사냥 경험치 배율 (숨김)
  double get _skewerExp => mealOn(Meal.skewer) ? TavernRules.skewerExp : 1;

  // ───────────── 바르칸의 상단 인장 (효과는 거래소가 열릴 때)

  bool get hasBarkanSeal => _npc.perks.contains('barkanSeal');

  Future<void> _saveTavern() =>
      _saveJson(AppController._tavernKey, _tavern.toJson());
}
