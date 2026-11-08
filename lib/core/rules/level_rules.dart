import 'rule_constants.dart';

/// 현재 레벨과 다음 레벨까지의 진행 상황
class LevelProgress {
  const LevelProgress({
    required this.level,
    required this.expIntoLevel,
    required this.expToNext,
  });

  final int level;

  /// 현재 레벨 안에서 모은 경험치 (예: 260)
  final int expIntoLevel;

  /// 이번 레벨에서 다음 레벨까지 필요한 전체 경험치 (예: 375)
  final int expToNext;

  double get ratio => expToNext == 0 ? 0 : expIntoLevel / expToNext;
}

class LevelRules {
  LevelRules._();

  /// Lv.[level] 에서 Lv.[level]+1 로 가는 데 필요한 경험치
  static int expRequiredFor(int level) {
    assert(level >= 1);
    return RuleConstants.levelBaseExp +
        RuleConstants.levelStepExp * (level - 1);
  }

  /// Lv.1 에서 Lv.[level] 에 도달하기까지 필요한 누적 경험치
  static int totalExpToReach(int level) {
    var total = 0;
    for (var l = 1; l < level; l++) {
      total += expRequiredFor(l);
    }
    return total;
  }

  /// 누적 경험치로 레벨과 진행 상황을 계산한다
  static LevelProgress fromTotalExp(int totalExp) {
    var level = 1;
    var remaining = totalExp < 0 ? 0 : totalExp;
    while (remaining >= expRequiredFor(level)) {
      remaining -= expRequiredFor(level);
      level++;
    }
    return LevelProgress(
      level: level,
      expIntoLevel: remaining,
      expToNext: expRequiredFor(level),
    );
  }
}
