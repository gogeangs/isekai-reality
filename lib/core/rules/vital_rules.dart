import 'dart:math' as math;

import 'rule_constants.dart';

/// HP · 정령 MP · 정령 원정의 계산 (시간과 걸음에 따라 바뀌는 값)
class VitalRules {
  VitalRules._();

  /// 원정 바로 돌아오기 마석 (묶음 18 #151, 숫자 계산은 화면에 보이지 않음):
  /// 남은 시간 10분마다 1개 (시작한 10분도 1개), 최소 1 · 최대 6
  static int rushCost(int secondsLeft) =>
      ((math.max(0, secondsLeft) + 599) ~/ 600).clamp(1, 6);

  // ───────────────────────── MP

  /// [mpAt] 부터 [now] 까지 저절로 찬 MP. (새 MP, 새 기준 시각)
  /// 가득 차면 기준 시각을 지금으로 옮겨, 쓰고 난 뒤부터 다시 센다.
  static (int, DateTime) regenMp(int mp, DateTime mpAt, DateTime now,
      {int max = RuleConstants.mpMax,
      int perHour = RuleConstants.mpRegenPerHour}) {
    if (mp >= max || now.isBefore(mpAt)) return (math.min(mp, max), now);
    final minutesPerPoint = 60 / perHour; // 기본 6분에 1
    final minutes = now.difference(mpAt).inSeconds / 60;
    final gained = (minutes / minutesPerPoint).floor();
    if (gained <= 0) return (mp, mpAt);
    final next = mp + gained;
    if (next >= max) return (max, now);
    return (
      next,
      mpAt.add(Duration(seconds: (gained * minutesPerPoint * 60).round())),
    );
  }

  /// MP가 가득 찰 때까지 남은 시간
  static Duration mpFullIn(int mp,
      {int max = RuleConstants.mpMax, int perHour = RuleConstants.mpRegenPerHour}) {
    final missing = max - mp;
    if (missing <= 0) return Duration.zero;
    return Duration(minutes: (missing * 60 / perHour).ceil());
  }

  // ───────────────────────── HP

  /// 걸음 [stepsToday] 중 아직 회복에 쓰지 않은 만큼 HP를 채운다.
  /// 1,000보마다 최대 HP의 10%. (새 HP, 새로 쓴 걸음)
  static (int, int) regenHpFromSteps({
    required int hp,
    required int maxHp,
    required int stepsToday,
    required int stepsCounted,
  }) {
    final delta = stepsToday - stepsCounted;
    if (delta < RuleConstants.hpRegenSteps) return (hp, stepsCounted);
    final chunks = delta ~/ RuleConstants.hpRegenSteps;
    final heal = (maxHp * RuleConstants.hpRegenRatio).round() * chunks;
    return (
      math.min(maxHp, hp + heal),
      stepsCounted + chunks * RuleConstants.hpRegenSteps,
    );
  }

  /// 다음 HP 회복까지 남은 걸음
  static int stepsToNextHeal(int stepsToday, int stepsCounted) {
    final into = (stepsToday - stepsCounted) % RuleConstants.hpRegenSteps;
    return RuleConstants.hpRegenSteps - into;
  }

  // ───────────────────────── 정령 원정

  /// 거리 [distanceM] 를 다녀오는 데 드는 MP (100m마다 2, 최소 2)
  static int expeditionCost(double distanceM) =>
      math.max(1, (distanceM / 100).ceil()) * RuleConstants.expeditionMpPer100m;

  /// 한쪽 길에 걸리는 시간 (1km마다 10분, 최소 3분)
  static Duration expeditionOneWay(double distanceM) {
    final minutes = distanceM / 1000 * RuleConstants.expeditionMinutesPerKm;
    final m = math.max(RuleConstants.expeditionMinMinutes.toDouble(), minutes);
    return Duration(seconds: (m * 60).round());
  }
}
