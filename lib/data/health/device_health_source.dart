import 'package:health/health.dart';

import 'health_source.dart';

/// 아이폰 건강 앱(HealthKit)과 안드로이드 헬스 커넥트에서 걸음만 읽는다.
/// 읽기만 하고, 건강 앱에 쓰지는 않는다.
class DeviceHealthSource implements HealthSource {
  final Health _health = Health();
  bool _configured = false;

  static const List<HealthDataType> _types = [
    HealthDataType.STEPS,
  ];

  Future<void> _configure() async {
    if (_configured) return;
    await _health.configure(); // 안드로이드는 헬스 커넥트만 지원 (health 11 이상)
    _configured = true;
  }

  @override
  Future<bool> requestPermission() async {
    await _configure();
    final permissions = _types.map((_) => HealthDataAccess.READ).toList();
    final has =
        await _health.hasPermissions(_types, permissions: permissions) ?? false;
    if (has) return true;
    return _health.requestAuthorization(_types, permissions: permissions);
  }

  @override
  Future<int> stepsBetween(DateTime start, DateTime end) async {
    await _configure();
    return await _health.getTotalStepsInInterval(start, end) ?? 0;
  }
}
