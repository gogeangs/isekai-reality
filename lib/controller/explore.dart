part of '../app_controller.dart';

/// 탐험·장소 (묶음 21: [AppController] 에서 나눔. 상태 칸은 본체에 있다)
extension ExploreOps on AppController {

  /// 위치를 받았는지
  bool get hasLocation => _lastFix != null;

  /// 위치를 쓸 수 없는 상태 (권한 거부 등). 위치 기능이 없는 기기(시험)는 false
  bool get locationDenied =>
      location != null && _locationAsked && !_locationGranted;

  /// 「다시 시도」: 위치 권한을 다시 묻고 위치를 받는다
  Future<void> retryLocation() async {
    try {
      await _startExploring().timeout(const Duration(seconds: 10));
    } catch (_) {}
    _notify();
  }

  Future<void> _startExploring() async {
    final source = location;
    if (source == null) return;
    _locationGranted = await source.requestPermission();
    _locationAsked = true;
    if (!_locationGranted) return;
    await _locationSub?.cancel();
    _locationSub = source.fixes().listen(handleFix);
  }

  /// 위치가 바뀔 때: 가까운 장소를 방문으로 기록한다 (안개는 11-10에 없앴다)
  Future<void> handleFix(LocationFix fix) =>
      _serial(() async {
    _lastFix = fix;
    await _watchSpeed(fix);
    if (ExplorationRules.countsAsExploring(fix)) {
      for (final place in ExplorationRules.placesInReach(area, fix.point)) {
        await _visitPlace(place);
      }
    }
    _notify();
  });

  void clearDiscovery() {
    _lastDiscovery = null;
    _notify();
  }

  Future<void> _visitPlace(GamePlace place) async {
    final now = _clock();
    if (_history.isEmpty ||
        _history.last.dayKey != DailyRecord.dayKeyOf(now)) {
      await sync(); // 자정이 지났으면 오늘 기록부터 만든다
    }
    final today = _history.last;
    if (today.visitedPlaceIds.contains(place.id)) return;

    final visitedBefore = _history
        .sublist(0, _history.length - 1)
        .any((r) => r.visitedPlaceIds.contains(place.id));
    final updated = today.copyWith(
      visitedPlaceIds: [...today.visitedPlaceIds, place.id],
      newPlacesVisited:
          visitedBefore ? today.newPlacesVisited : today.newPlacesVisited + 1,
      placesRevisited:
          visitedBefore ? today.placesRevisited + 1 : today.placesRevisited,
    );
    await store.upsert(updated);
    _history = await store.loadHistory();
    if (!visitedBefore) _lastDiscovery = place;
  }
}
