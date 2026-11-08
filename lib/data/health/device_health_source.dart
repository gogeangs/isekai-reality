import 'package:health/health.dart';

import 'health_source.dart';

/// 아이폰 건강 앱(HealthKit)과 안드로이드 헬스 커넥트에서 읽는다.
/// 읽기만 하고, 건강 앱에 쓰지는 않는다.
class DeviceHealthSource implements HealthSource {
  final Health _health = Health();
  bool _configured = false;

  static const List<HealthDataType> _types = [
    HealthDataType.STEPS,
    HealthDataType.SLEEP_ASLEEP,
  ];

  Future<void> _configure() async {
    if (_configured) return;
    await _health.configure(useHealthConnectIfAvailable: true);
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

  @override
  Future<int?> sleepMinutesForNightBefore(DateTime day) async {
    await _configure();
    final noon = DateTime(day.year, day.month, day.day, 12);
    final points = await _health.getHealthDataFromTypes(
      types: const [HealthDataType.SLEEP_ASLEEP],
      startTime: noon.subtract(const Duration(hours: 24)),
      endTime: noon,
    );
    if (points.isEmpty) return null;

    // 같은 구간이 여러 앱에서 중복 기록될 수 있어 시작·끝 시각으로 걸러 낸다
    final seen = <String>{};
    var minutes = 0;
    for (final p in points) {
      final key = '${p.dateFrom.toIso8601String()}|${p.dateTo.toIso8601String()}';
      if (!seen.add(key)) continue;
      minutes += p.dateTo.difference(p.dateFrom).inMinutes;
    }
    return minutes;
  }
}
