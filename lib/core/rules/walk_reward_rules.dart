/// 묶음 65 (2/2) #252 많이 걸은 날 · #254 높은 레벨 경험치 (숫자는 화면에 안 보임)
///
/// 지금까지 1만 보를 넘긴 걸음은 보상이 없었다(열쇠는 하루 4개 = 1만 보까지).
/// 예전 기록은 그대로 두려고 [since] 날부터의 기록에만 붙인다.
class WalkRewardRules {
  WalkRewardRules._();

  /// 이날부터의 하루 기록에 붙는다 (그 전 기록 · 레벨은 그대로)
  static final DateTime since = DateTime(2026, 11, 19);

  static bool applies(DateTime day) => !DateTime(day.year, day.month, day.day).isBefore(since);

  /// 1만 보를 넘긴 걸음부터
  static const int from = 10000;

  /// 2,500보마다
  static const int every = 2500;

  /// 하루 2만 보까지 (4번)
  static const int until = 20000;

  static const int maxPerDay = (until - from) ~/ every;

  /// 발자국 경험치 한 번
  static const int footprintExp = 25;

  /// 열쇠 조각 두 개 = 열쇠 하나
  static const int shardsPerKey = 2;

  /// 1만 보를 넘긴 2,500보마다 하나 (발자국 · 열쇠 조각 같은 수)
  static int steps2500(int steps, DateTime day) {
    if (!applies(day) || steps <= from) return 0;
    final n = ((steps > until ? until : steps) - from) ~/ every;
    return n < 0 ? 0 : (n > maxPerDay ? maxPerDay : n);
  }

  /// 그날 발자국 경험치
  static int footprintExpOn(int steps, DateTime day) => steps2500(steps, day) * footprintExp;

  /// 다음 발자국 · 조각까지 모은 걸음 (2만 보를 넘겼으면 null)
  static int? intoNext(int steps) {
    if (steps < from || steps >= until) return null;
    return (steps - from) % every;
  }

  // ───────────── 걸음 상자

  /// 그날 1만2천 · 1만5천 · 2만 보 → 동 · 은 · 금
  static const List<int> chestSteps = [12000, 15000, 20000];
  static const List<String> chestNames = ['동빛 걸음 상자', '은빛 걸음 상자', '금빛 걸음 상자'];
  static const List<String> chestArt = [
    'assets/images/chest_partyBronze.webp',
    'assets/images/chest_partySilver.webp',
    'assets/images/chest_partyGold.webp',
  ];

  /// 그날 받은 상자 단계 (0 동 · 1 은 · 2 금)
  static List<int> chestsOn(int steps, DateTime day) => [
        if (applies(day))
          for (var i = 0; i < chestSteps.length; i++)
            if (steps >= chestSteps[i]) i,
      ];

  /// 상자를 연 표시 (연 날 기록 counters): 'stepChest@20261120:1'
  static String openedKey(DateTime day, int tier) =>
      'stepChest@${day.year}${day.month.toString().padLeft(2, '0')}${day.day.toString().padLeft(2, '0')}:$tier';

  /// 상자 금화 (단계별 범위, 숨김)
  static const List<(int, int)> chestGold = [(60, 100), (120, 180), (220, 320)];

  /// 그 지역 재료 몇 개 (단계별)
  static const List<int> chestMats = [2, 3, 5];

  /// 은 · 금 상자에 가끔 돋보기 · 물약 (숨김)
  static const List<double> chestItemChance = [0, 0.35, 0.7];

  // ───────────── #254 높은 레벨 경험치

  /// Lv.21부터 모든 경험치 × (1 + 0.03 × (레벨 − 21))
  static const int highFrom = 21;
  static const double highStep = 0.03;

  static double levelMult(int level) => level <= highFrom ? 1 : 1 + highStep * (level - highFrom);
}
