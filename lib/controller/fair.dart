part of '../app_controller.dart';

/// 묶음 61 #250: 부정 이용 막기 — 다른 사람과 얽히는 곳(파티 · 길드 · 거래소 · 순위 · 공성전)에만.
/// 혼자 하는 플레이(레벨 · 사냥 · 여정 · 이야기 · 혼자 걷는 걸음)는 그대로 둔다.
/// - 손으로 입력한 걸음은 함께하는 걸음에서 뺌
/// - 가짜 위치가 잡힌 동안은 「함께 있어요」 칸을 보내지 않음 (띠 한 번)
/// - 하루 걸음 · 최대 시간당 걸음을 함께 보냄 (서버 의심 목록에서 참고만)
extension FairOps on AppController {
  int _manualOf(DailyRecord r) => r.counters[AppController.manualStepsKey] ?? 0;

  /// 손으로 입력한 걸음을 뺀 오늘 걸음 (함께하는 기능)
  int get socialTodaySteps {
    final t = player.today;
    if (t == null) return 0;
    return math.max(0, t.steps - _manualOf(t));
  }

  /// 손으로 입력한 걸음을 뺀 지금까지 걸음 (4막 「길드에서 걸은 걸음」)
  int get _socialTotalSteps => _history.fold<int>(0, (t, r) => t + math.max(0, r.steps - _manualOf(r)));

  /// 가짜 위치가 최근 10분 안에 잡혔는지
  bool get mockLocation {
    final m = _mockAt;
    return m != null && _clock().difference(m) < const Duration(minutes: 10);
  }

  /// 띠 한 번: 「가짜 위치가 켜져 있어 친구와 함께하는 기능에는 반영되지 않아요」
  static const String mockLine = '가짜 위치가 켜져 있어 친구와 함께하는 기능에는 반영되지 않아요';

  bool takeMockBanner() {
    if (!_mockBannerPending) return false;
    _mockBannerPending = false;
    return true;
  }

  void _noteFix(LocationFix fix) {
    if (!fix.mocked) return;
    _mockAt = _clock();
    if (!_mockBannerShown) {
      _mockBannerShown = true;
      _mockBannerPending = true;
    }
  }

  /// 오늘 가장 많이 걸은 한 시간 (30분마다 다시 셈, 손 입력 뺌)
  Future<int> _maxHourSteps() async {
    final now = _clock();
    final day = DailyRecord.dayKeyOf(now);
    final c = _maxHourCache;
    if (c != null && c.day == day && now.difference(c.at) < const Duration(minutes: 30)) return c.max;
    var best = 0;
    try {
      for (var h = 0; h <= now.hour; h++) {
        final a = DateTime(now.year, now.month, now.day, h, 0, 1);
        final b = DateTime(now.year, now.month, now.day, h + 1);
        final n = await health.autoStepsBetween(a, b.isAfter(now) ? now : b);
        if (n > best) best = n;
      }
    } catch (_) {
      // 건강 앱을 못 읽으면 0
    }
    _maxHourCache = (day: day, at: now, max: best);
    return best;
  }

  /// 함께하는 기능에 보내는 걸음 · 표시
  Future<Map<String, dynamic>> _socialSteps() async {
    final t = player.today;
    return {
      'steps': socialTodaySteps,
      'maxHour': await _maxHourSteps(),
      'manual': t == null ? 0 : _manualOf(t),
      if (mockLocation) 'mock': true,
    };
  }
}
