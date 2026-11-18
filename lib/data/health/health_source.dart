/// 걸음을 읽는 곳. 실제 기기는 [DeviceHealthSource],
/// 테스트와 예시 화면은 [FakeHealthSource] 를 쓴다.
abstract class HealthSource {
  /// 읽기 권한을 요청한다. 허용되면 true.
  Future<bool> requestPermission();

  /// [start] 부터 [end] 까지의 걸음 수
  Future<int> stepsBetween(DateTime start, DateTime end);

  /// 묶음 61 #250: 건강 앱에 손으로 입력한 걸음을 뺀 걸음 (함께하는 기능에만 씀).
  /// 가려 읽지 못하는 곳은 그대로 [stepsBetween]
  Future<int> autoStepsBetween(DateTime start, DateTime end) => stepsBetween(start, end);
}

/// 정해진 값을 돌려주는 가짜 건강 데이터 (테스트·예시용)
class FakeHealthSource extends HealthSource {
  FakeHealthSource({
    this.granted = true,
    Map<String, int>? stepsByDay,
    Map<String, int>? stepsAfter8pmByDay,
    Map<String, int>? windowSteps,
    Map<String, int>? manualByDay,
  })  : stepsByDay = stepsByDay ?? {},
        stepsAfter8pmByDay = stepsAfter8pmByDay ?? {},
        windowSteps = windowSteps ?? {},
        manualByDay = manualByDay ?? {};

  /// 손으로 입력한 걸음 (하루, 키 'yyyy-mm-dd')
  final Map<String, int> manualByDay;

  @override
  Future<int> autoStepsBetween(DateTime start, DateTime end) async {
    final all = await stepsBetween(start, end);
    // 하루 전체를 물을 때만 손 입력을 뺌 (시간 창은 그대로)
    if (start.hour == 0 && start.minute == 0 && start.second == 0) {
      final m = manualByDay[keyOf(start)] ?? 0;
      return all - m < 0 ? 0 : all - m;
    }
    return all;
  }

  /// 시간 창 걸음 (시작이 정각 1초인 창, 키 'yyyy-mm-dd@시'). 없으면 0
  final Map<String, int> windowSteps;

  final bool granted;

  /// 키는 'yyyy-mm-dd'
  final Map<String, int> stepsByDay;
  final Map<String, int> stepsAfter8pmByDay;

  static String keyOf(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Future<bool> requestPermission() async => granted;

  @override
  Future<int> stepsBetween(DateTime start, DateTime end) async {
    final key = keyOf(start);
    if (start.second == 1) return windowSteps['$key@${start.hour}'] ?? 0;
    // 저녁 8시부터 묻는 경우는 '저녁 걸음'으로 본다
    if (start.hour >= 20) return stepsAfter8pmByDay[key] ?? 0;
    return stepsByDay[key] ?? 0;
  }
}
