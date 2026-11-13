part of '../app_controller.dart';

/// 승객(차량 이동) 확인 (묶음 21: [AppController] 에서 나눔. 상태 칸은 본체에 있다)
extension DriveOps on AppController {

  /// 차량 속도 감지 상태
  DriveMode get driveMode => _drive.mode;

  /// 승객이라고 답하고 차로 이동하는 중 (보상 제한)
  bool get passengerMode => _drive.mode == DriveMode.passenger;

  /// 화면을 가리는 중 (묻기·안전 운전)
  bool get driveBlocked =>
      _drive.mode == DriveMode.asking || _drive.mode == DriveMode.driving;

  Future<void> _saveDrive(DriveState d) async {
    _drive = d;
    await store.saveJson(AppController._driveKey, d.toJson());
    _notify();
  }

  /// 최근 10초 동안 멈춰 있는지
  bool get standingStill {
    if (_lastFix == null) return false;
    final m = _lastMovingAt;
    return m == null || _clock().difference(m) >= HarvestRules.stillFor;
  }

  Future<void> _watchSpeed(LocationFix fix) async {
    final now = _clock();
    if (fix.speedMps > HarvestRules.stillSpeedMps) _lastMovingAt = now;
    if (fix.speedMps >= DriveRules.carSpeedMps) {
      _slowSince = null;
      _fastSince ??= now;
      if (_drive.mode == DriveMode.none &&
          now.difference(_fastSince!) >= DriveRules.carFor) {
        // 차에 타기 전까지 걸은 걸음은 먼저 센다
        await _petSteps();
        await _checkWalkEvents();
        await _saveDrive(_drive.copyWith(mode: DriveMode.asking, askedAt: now));
      }
    } else {
      _fastSince = null;
      if (fix.speedMps < DriveRules.endSpeedMps) {
        _slowSince ??= now;
        if (_drive.mode != DriveMode.none &&
            now.difference(_slowSince!) >= DriveRules.endAfter) {
          await _endTrip();
        }
      } else {
        _slowSince = null;
      }
    }
    // 묻는 화면에 답이 없으면 안전 운전 화면
    if (_drive.mode == DriveMode.asking &&
        _drive.askedAt != null &&
        now.difference(_drive.askedAt!) >= DriveRules.askTimeout) {
      await _saveDrive(_drive.copyWith(mode: DriveMode.driving));
    }
  }

  Future<void> _endTrip() async {
    if (passengerMode) {
      // 차 안에서 늘어난 걸음은 주머니·펫 경험치에 넣지 않는다
      await _petSteps();
      await _checkWalkEvents();
    }
    await _saveDrive(_drive.copyWith(mode: DriveMode.none));
  }

  /// 「승객이에요」/「운전 중이에요」
  Future<void> answerDrive({required bool passenger}) => _saveDrive(
      _drive.copyWith(mode: passenger ? DriveMode.passenger : DriveMode.driving));

  /// 오래 답이 없을 때 (화면에서 부른다)
  Future<void> driveTimeout() async {
    if (_drive.mode == DriveMode.asking) {
      await _saveDrive(_drive.copyWith(mode: DriveMode.driving));
    }
  }
}
