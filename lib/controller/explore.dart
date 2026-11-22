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
  Future<void> handleFix(LocationFix fix) {
    _lastFix = fix; // 위치는 바로 (기록 저장만 줄 세운다)
    _noteFix(fix); // 묶음 61: 가짜 위치면 함께하는 기능에서 뺌
    // 묶음 56: 파티원이 가까이 있는지 (몇 분에 한 번, 100m 칸만)
    unawaited(partyNearPing());
    return _serial(() async {
    await _anchorNear(fix.point);
    await _riftOnFix(fix.point);
    await _watchSpeed(fix);
    // 묶음 81 #380: 「새 장소」 기능은 진행하지 않음 — 장소 방문 기록 · 경험치 · 숙련 · 부탁 셈 없음
    _notify();
  });
  }
}
