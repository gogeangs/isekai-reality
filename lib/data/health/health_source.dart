/// 걸음과 수면을 읽는 곳. 실제 기기는 [DeviceHealthSource],
/// 테스트와 예시 화면은 [FakeHealthSource] 를 쓴다.
abstract class HealthSource {
  /// 읽기 권한을 요청한다. 허용되면 true.
  Future<bool> requestPermission();

  /// [start] 부터 [end] 까지의 걸음 수
  Future<int> stepsBetween(DateTime start, DateTime end);

  /// [day] 아침을 기준으로 한 '지난밤' 수면(분).
  /// 전날 낮 12시부터 그날 낮 12시 사이에 잔 시간을 더한다. 기록이 없으면 null.
  Future<int?> sleepMinutesForNightBefore(DateTime day);
}

/// 정해진 값을 돌려주는 가짜 건강 데이터 (테스트·예시용)
class FakeHealthSource implements HealthSource {
  FakeHealthSource({
    this.granted = true,
    Map<String, int>? stepsByDay,
    Map<String, int>? stepsAfter8pmByDay,
    Map<String, int>? sleepByDay,
  })  : stepsByDay = stepsByDay ?? {},
        stepsAfter8pmByDay = stepsAfter8pmByDay ?? {},
        sleepByDay = sleepByDay ?? {};

  final bool granted;

  /// 키는 'yyyy-mm-dd'
  final Map<String, int> stepsByDay;
  final Map<String, int> stepsAfter8pmByDay;
  final Map<String, int> sleepByDay;

  static String keyOf(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Future<bool> requestPermission() async => granted;

  @override
  Future<int> stepsBetween(DateTime start, DateTime end) async {
    final key = keyOf(start);
    // 저녁 8시부터 묻는 경우는 '저녁 걸음'으로 본다
    if (start.hour >= 20) return stepsAfter8pmByDay[key] ?? 0;
    return stepsByDay[key] ?? 0;
  }

  @override
  Future<int?> sleepMinutesForNightBefore(DateTime day) async =>
      sleepByDay[keyOf(day)];
}
