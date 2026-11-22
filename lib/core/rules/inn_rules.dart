import 'dart:math' as math;

/// 묶음 81 #373 · #371: 여관은 「있는 동안 조금씩」 — 체크인해 있는 동안(일어날 때까지)
/// HP · MP(각성 뒤) · 기력이 시간당 최대치의 20%씩 찬다(숨은 값). 4시간 상한 · 「다 쉼」 없음.
/// 원정 나간 펫이 있으면 여관 회복은 멈춘다(밖의 회복은 그대로).
class InnRules {
  InnRules._();

  /// 시간당 최대치의 몫 (빈 상태에서 5시간)
  static const double perHour = 0.2;

  /// 여관 ★2: 회복 속도
  static const double star2Speed = 1.25;

  /// 마르타 단짝: 회복 속도 (★2와 곱함)
  static const double martaSpeed = 1.1;

  /// 광고 보고 바로 회복: 한 번에 최대치의 20% (1시간치), 한 번 체크인에 두 번까지
  static const double adGain = 0.2;
  static const int adsPerRest = 2;

  /// 그날 쉰 것으로 보는 실제 회복 시간 (또는 셋 다 가득)
  static const Duration restedAfter = Duration(hours: 1);

  /// 여관 ★3: 가득 찬 뒤 일어나면 잠시 HP · 기력 최대가 조금 늘어요 (개발이 정한 값)
  static const double star3Max = 1.05;
  static const Duration star3For = Duration(hours: 2);

  /// 회복 속도 배율
  static double speed({bool star2 = false, bool martaBest = false}) =>
      (star2 ? star2Speed : 1) * (martaBest ? martaSpeed : 1);

  /// [hours] 동안 [max] 에서 얼마나 차는지. 소수는 [carry] 로 넘겨 다음에 더한다 → (더할 값, 남은 소수)
  static (int, double) gain(int max, double hours, double carry, {double speed = 1}) {
    if (max <= 0 || hours <= 0 || hours.isNaN) return (0, carry.isNaN ? 0 : carry);
    final raw = max * perHour * speed * hours + (carry.isNaN ? 0 : carry);
    final add = raw.floor();
    return (add, raw - add);
  }

  /// [from]~[to] 사이에서 [busy] 구간(원정 나간 동안)과 겹치는 시간
  static Duration pausedWithin(DateTime from, DateTime to, List<(DateTime, DateTime)> busy) {
    if (!to.isAfter(from)) return Duration.zero;
    final spans = <(DateTime, DateTime)>[
      for (final (a, b) in busy)
        if (b.isAfter(from) && a.isBefore(to))
          (a.isBefore(from) ? from : a, b.isAfter(to) ? to : b),
    ]..sort((x, y) => x.$1.compareTo(y.$1));
    var total = Duration.zero;
    DateTime? s;
    DateTime? e;
    for (final (a, b) in spans) {
      if (e == null || a.isAfter(e)) {
        if (s != null) total += e!.difference(s);
        s = a;
        e = b;
      } else if (b.isAfter(e)) {
        e = b;
      }
    }
    if (s != null) total += e!.difference(s);
    return total;
  }

  /// 지금 값에서 가득 차기까지 (멈추지 않는다고 볼 때). 이미 가득이면 zero
  static Duration untilFull(List<(int, int)> valueMax, {double speed = 1}) {
    var worst = 0.0;
    for (final (v, m) in valueMax) {
      if (m <= 0 || v >= m) continue;
      final h = (m - v) / (m * perHour * speed);
      worst = math.max(worst, h);
    }
    return Duration(seconds: (worst * 3600).ceil());
  }
}
