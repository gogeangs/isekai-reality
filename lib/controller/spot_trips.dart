part of '../app_controller.dart';

/// 묶음 81 #375: 잿빛 틈 · 하이랜드 섬도 원정으로.
/// 펫이 가서 그 자리에서 기다리면(잿빛 틈 30분 · 섬은 질 때까지 중 짧은 쪽) 걸어서 닿은 것처럼 싸울 수 있다.
/// 싸우면(이기든 지든) 또는 기다림이 끝나면 가는 시간만큼 걸려 돌아온다. 기력은 돌려주지 않는다.

/// 원정 보내기 계획 (잿빛 틈 · 섬)
class TripPlan {
  const TripPlan({
    required this.check,
    this.distanceM = 0,
    this.mpCost = 0,
    this.oneWay = Duration.zero,
    this.petUid,
    this.tooLate = false,
  });

  final ExpeditionCheck check;
  final double distanceM;
  final int mpCost;
  final Duration oneWay;
  final String? petUid;

  /// 하이랜드: 가는 시간 안에 섬이 짐
  final bool tooLate;

  bool get ok => check == ExpeditionCheck.ok && !tooLate;
}

extension SpotTripOps on AppController {
  /// 잿빛 틈에서 기다리는 시간
  static const Duration riftWait = Duration(minutes: 30);

  /// 아직 돌아오지 않은 그 자리 원정 (없으면 null)
  SpotTrip? tripTo(String kind) {
    final now = _clock();
    for (final t in _vitals.trips) {
      if (t.kind == kind && !t.done(now)) return t;
    }
    return null;
  }

  /// 펫이 잿빛 틈 · 섬에서 기다리는 중 (걸어서 닿은 것처럼 싸울 수 있음)
  bool tripWaiting(String kind) => tripTo(kind)?.waiting(_clock()) ?? false;

  /// 지금 그 자리 (잿빛 틈: 날짜:분신 · 섬: 섬:지는 때). 자리가 없으면 null
  String? _tripKey(String kind) {
    if (kind == 'rift') {
      final a = nextAvatar;
      if (a == null || riftPoint == null) return null;
      return '${_act2.riftDay}:${a.index}';
    }
    final s = skyIsland;
    if (s == null) return null;
    return '${s.isle.index}:${s.until.toIso8601String()}';
  }

  GeoPoint? _tripPoint(String kind) => kind == 'rift' ? riftPoint : skyIsland?.point;

  /// 잿빛 틈 · 섬에 보낼 수 있는지 · 기력 · 가는 시간
  TripPlan planTrip(String kind, {String? petUid}) {
    final to = _tripPoint(kind);
    final from = _lastFix?.point;
    if (from == null) return const TripPlan(check: ExpeditionCheck.needsLocation);
    if (to == null || !farewellDone) return const TripPlan(check: ExpeditionCheck.busy);
    final pet = petUid == null ? null : _pets.byUid(petUid);
    if (pet == null) return const TripPlan(check: ExpeditionCheck.busy);
    final dist = from.distanceTo(to);
    final (cost, base) = _expeditionCostTime(dist, pet);
    final oneWay = _vitals.compassReady ? base ~/ 2 : base;
    final ExpeditionCheck check;
    if (tripTo(kind) != null || isAway(pet.uid)) {
      check = ExpeditionCheck.busy;
    } else if (_pets.isTired(pet.uid, _clock())) {
      check = ExpeditionCheck.tired;
    } else if (petInTraining(pet.uid)) {
      check = ExpeditionCheck.training;
    } else if (mp < cost) {
      check = ExpeditionCheck.notEnoughMp;
    } else {
      check = ExpeditionCheck.ok;
    }
    final s = skyIsland;
    final late = kind == 'sky' && s != null && !_clock().add(oneWay).isBefore(s.until);
    return TripPlan(
        check: check, distanceM: dist, mpCost: cost, oneWay: oneWay, petUid: pet.uid, tooLate: late);
  }

  /// 잿빛 틈 · 섬에 원정을 보낼 수 있는 상태인지 (걸어서 이미 들어갔으면 · 닫혔으면 · 이미 보냈으면 없음)
  bool canOfferTrip(String kind) {
    if (!farewellDone || _pets.pets.isEmpty) return false;
    if (tripTo(kind) != null) return false;
    if (kind == 'rift') return nextAvatar != null && !riftClosedToday && !atRift && riftPoint != null;
    final s = skyIsland;
    return s != null && !s.cleared && !s.climbed && !atSkyIsland;
  }

  /// 펫을 보낸다. 기력은 보내는 순간 쓴다
  Future<ExpeditionCheck> sendTrip(String kind, String petUid) => _serial(() async {
        final plan = planTrip(kind, petUid: petUid);
        if (!plan.ok) return plan.tooLate ? ExpeditionCheck.busy : plan.check;
        final key = _tripKey(kind);
        final to = _tripPoint(kind);
        final pet = _pets.byUid(petUid);
        if (key == null || to == null || pet == null) return ExpeditionCheck.busy;
        final now = _clock();
        await _consumeSkill(JobSkill.longRoad);
        final arrive = now.add(plan.oneWay);
        var wait = arrive.add(riftWait);
        final s = skyIsland;
        if (kind == 'sky' && s != null && s.until.isBefore(wait)) wait = s.until;
        final trip = SpotTrip(
          kind: kind,
          key: key,
          petUid: pet.uid,
          petName: pet.name,
          lat: to.lat,
          lng: to.lng,
          distanceM: plan.distanceM,
          mpCost: plan.mpCost,
          startedAt: now,
          arriveAt: arrive,
          oneWaySec: plan.oneWay.inSeconds,
          waitUntil: wait,
        );
        _vitals = _vitals.copyWith(
          mp: mp - plan.mpCost,
          mpAt: mp >= mpMax ? now : _vitals.mpAt,
          trips: [..._vitals.trips.where((t) => t.kind != kind), trip],
          compassReady: false,
        );
        await store.saveVitals(_vitals);
        unawaited(notifier?.schedule(NotifyId.trip, arrive, tripArrivedLine(trip), '싸우러 가자'));
        _notify();
        return ExpeditionCheck.ok;
      });

  /// 「○○가 잿빛 틈에 닿았어! 싸우러 가자」
  static String tripArrivedLine(SpotTrip t) =>
      '${josa(t.petName, '이/가')} ${t.kind == 'rift' ? '잿빛 틈' : '하늘 섬 아래'}에 닿았어!';

  /// 닿았지만 아직 알리지 않은 원정 (앱 안 위쪽 띠)
  SpotTrip? get tripArrivedUnseen {
    final now = _clock();
    for (final t in _vitals.trips) {
      if (!t.arrivalSeen && t.waiting(now)) return t;
    }
    return null;
  }

  Future<void> markTripArrivalSeen(SpotTrip t) async {
    _vitals = _vitals.copyWith(trips: [
      for (final x in _vitals.trips) x.kind == t.kind ? x.copy(arrivalSeen: true) : x,
    ]);
    await store.saveVitals(_vitals);
    _notify();
  }

  /// 싸움이 끝나면(이기든 지든): 펫은 돌아오는 길
  Future<void> _tripFought(String kind) async {
    final now = _clock();
    final t = tripTo(kind);
    if (t == null || !t.waiting(now)) return;
    _vitals = _vitals.copyWith(trips: [
      for (final x in _vitals.trips) x.kind == kind ? x.copy(foughtAt: now) : x,
    ]);
    await store.saveVitals(_vitals);
  }

  /// 돌아온 원정 · 자리가 바뀐 원정을 정리한다 (refreshVitals 에서)
  bool _settleTrips() {
    if (_vitals.trips.isEmpty) return false;
    final now = _clock();
    final keep = [
      for (final t in _vitals.trips)
        if (!t.done(now)) t,
    ];
    if (keep.length == _vitals.trips.length) return false;
    _vitals = _vitals.copyWith(trips: keep);
    return true;
  }

  /// 그 펫이 잿빛 틈 · 섬에 나가 있는지
  bool _onTrip(String? uid) {
    if (uid == null) return false;
    final now = _clock();
    return _vitals.trips.any((t) => t.petUid == uid && !t.done(now));
  }

  /// 그 펫이 돌아오기까지 (잿빛 틈 · 섬)
  Duration? _tripLeft(String uid) {
    final now = _clock();
    for (final t in _vitals.trips) {
      if (t.petUid == uid && !t.done(now)) return t.returnAt.difference(now);
    }
    return null;
  }
}
