part of '../app_controller.dart';

/// 걸음 주머니·길가 발견·떠돌이 상인 (묶음 21: [AppController] 에서 나눔. 상태 칸은 본체에 있다)
extension GatherOps on AppController {

  GatherState get gather => _gather;

  Future<void> _saveGather(GatherState g) async {
    _gather = g;
    await store.saveJson(AppController._gatherKey, g.toJson());
    _notify();
  }

  /// 걸음 주머니·무작위 이벤트를 걸음에 맞춰 만든다 (앱을 열 때·화면을 볼 때)
  Future<void> _checkWalkEvents() async {
    final today = player.today;
    if (today == null || !walkEvents) return;
    final now = _clock();
    var g = _gather;
    if (g.day != today.dayKey) {
      g = g.copyWith(
          day: today.dayKey,
          pouchesGiven: 0,
          stepsChecked: 0,
          findsToday: 0,
          merchantToday: 0);
    }
    // 승객 모드 (11-11 #61): 차 안에서 늘어난 걸음은 주머니·발견에 세지 않는다
    if (passengerMode) {
      g = g.copyWith(
          pouchesGiven: math.max(g.pouchesGiven, GatherRules.pouchesFor(today.steps)),
          stepsChecked: today.steps -
              (today.steps - g.stepsChecked) % GatherRules.findSteps);
    }
    // 걸음 주머니
    final due = GatherRules.pouchesFor(today.steps);
    var newPouch = false;
    if (due > g.pouchesGiven) {
      g = g.copyWith(
          pouches: g.pouches + (due - g.pouchesGiven), pouchesGiven: due);
      newPouch = true;
    }
    // 길가의 발견 · 떠돌이 상인
    var notifyFind = false, notifyMerchant = false;
    var checked = g.stepsChecked;
    while (today.steps - checked >= GatherRules.findSteps) {
      checked += GatherRules.findSteps;
      final open = g.findUntil != null && g.findUntil!.isAfter(now);
      if (!open &&
          g.findsToday < GatherRules.findsPerDay &&
          _random.nextDouble() < GatherRules.findChance) {
        g = g.copyWith(
            findUntil: now.add(GatherRules.findValid),
            findsToday: g.findsToday + 1);
        notifyFind = true;
      }
      if (checked % GatherRules.merchantSteps < GatherRules.findSteps &&
          g.merchantToday < GatherRules.merchantPerDay &&
          _random.nextDouble() < GatherRules.merchantChance) {
        // 상인은 내 근처(60~120m)에 선다 (11-11 #84)
        final here = _lastFix?.point ?? fallbackCenter;
        final at = here == null
            ? null
            : AppController._merchantSpot(here, 60 + _random.nextDouble() * 60,
                _random.nextDouble() * math.pi * 2);
        g = g.copyWith(
          merchantUntil: now.add(GatherRules.merchantStay),
          merchantToday: g.merchantToday + 1,
          merchantLat: at?.lat,
          merchantLng: at?.lng,
          sold: const [],
          offers: {
            for (final e in GatherRules.offers(_random).entries)
              e.key.name: e.value,
          },
          noteOffer: _random.nextDouble() < GatherRules.noteOfferChance,
        );
        notifyMerchant = true;
      }
    }
    g = g.copyWith(stepsChecked: checked);
    if (g.toJson().toString() != _gather.toJson().toString()) await _saveGather(g);
    if (newPouch) _newPouch = true;
    final quiet = GatherRules.quietHour(now) || !g.notify;
    if (notifyFind && !quiet) {
      unawaited(notifier?.schedule(NotifyId.find, now.add(const Duration(seconds: 2)),
          '길가에서 반짝이는 것을 발견했어!', '30분 안에 열어 보면 받을 수 있어요.'));
    }
    if (notifyMerchant && !quiet) {
      unawaited(notifier?.schedule(
          NotifyId.merchant,
          now.add(const Duration(seconds: 2)),
          '떠돌이 상인이 나타났어!',
          '20분 동안만 귀한 재료를 팔아요.'));
    }
  }
  bool takeNewPouch() {
    final v = _newPouch;
    _newPouch = false;
    return v;
  }

  /// 길가의 발견이 열려 있는지
  bool get findOpen =>
      _gather.findUntil != null && _gather.findUntil!.isAfter(_clock());

  /// 떠돌이 상인이 있는지
  bool get merchantHere =>
      !inTutorial && // 묶음 18 #150
      _gather.merchantUntil != null &&
      _gather.merchantUntil!.isAfter(_clock());

  /// 떠돌이 상인이 선 자리 (없으면 null). 예전 기록처럼 자리가 없으면 내 위치.
  GeoPoint? get merchantPoint {
    if (!merchantHere) return null;
    final g = _gather;
    if (g.merchantLat != null && g.merchantLng != null) {
      return GeoPoint(g.merchantLat!, g.merchantLng!);
    }
    return _lastFix?.point ?? fallbackCenter;
  }

  /// 상인이 떠나기까지 남은 분 (없으면 0)
  int get merchantMinutesLeft => merchantHere
      ? (_gather.merchantUntil!.difference(_clock()).inSeconds + 59) ~/ 60
      : 0;

  /// 이번 상인에게서 이미 샀는지 ([m] 이 null 이면 레시피 쪽지)
  bool merchantSold(MaterialId? m) => _gather.sold.contains(m?.name ?? 'note');
  void requestMapFocus(GeoPoint p) {
    _mapFocus = p;
    _notify();
  }

  GeoPoint? takeMapFocus() {
    final p = _mapFocus;
    _mapFocus = null;
    return p;
  }

  /// 걸음 주머니를 연다
  Future<({Map<MaterialId, int> mats, int gold, bool note})?> openPouch() async {
    if (_gather.pouches <= 0) return null;
    final r = GatherRules.openPouch(_random);
    await _saveGather(_gather.copyWith(pouches: _gather.pouches - 1));
    await _grant(r.gold, 0, r.mats);
    if (r.note) await _savePets(_pets.copyWith(recipeNotes: _pets.recipeNotes + 1));
    return r;
  }

  /// 길가의 발견을 연다 (30분이 지나면 null)
  Future<({Map<MaterialId, int> mats, int gold, bool note})?> openFind() async {
    if (!findOpen) return null;
    final r = GatherRules.openFind(_random);
    await _saveGather(_gather.copyWith(clearFind: true));
    await _grant(r.gold, 0, r.mats);
    if (r.note) await _savePets(_pets.copyWith(recipeNotes: _pets.recipeNotes + 1));
    return r;
  }

  /// 떠돌이 상인에게서 산다 ([m] 이 null 이면 레시피 쪽지)
  Future<bool> buyFromMerchant(MaterialId? m) async {
    if (!merchantHere) return false;
    final price = m == null
        ? (_gather.noteOffer ? GatherRules.notePrice : null)
        : _gather.offers[m.name];
    if (price == null || player.gold < price || merchantSold(m)) return false;
    final today = await _todayRecord();
    await _save(today.copyWith(
        spends: DailyRecord.addCounts(today.spends, {Wallet.gold: price})));
    // 한 번만 살 수 있다: 팔린 것은 「팔렸어요」로 남긴다 (11-11 #84)
    if (m == null) {
      await _savePets(_pets.copyWith(recipeNotes: _pets.recipeNotes + 1));
    } else {
      await _grant(0, 0, {m: 1});
    }
    await _saveGather(
        _gather.copyWith(sold: [..._gather.sold, m?.name ?? 'note']));
    return true;
  }

  /// 걸을 때 알림 켜고 끄기 (설정)
  Future<void> setWalkNotify(bool on) => _saveGather(_gather.copyWith(notify: on));
}
