import '../models/daily_record.dart';
import 'rule_constants.dart';

enum TitleId {
  firstSteps,
  persistentTraveler,
  morningSpiritFriend,
  bookwormSage,
  forcedMarchKnight,
  nightWalker,
  awakened,
  lanternKeeper,
}

class TitleInfo {
  const TitleInfo(this.id, this.name, this.hint);

  final TitleId id;
  final String name;

  /// 잠긴 칭호에 보여 줄 힌트
  final String hint;
}

class TitleRules {
  TitleRules._();

  static const List<TitleInfo> all = [
    TitleInfo(TitleId.firstSteps, '첫 걸음', '처음으로 걸어 보기'),
    TitleInfo(TitleId.persistentTraveler, '끈기의 여행자', '일주일 내내 목표 달성'),
    TitleInfo(TitleId.morningSpiritFriend, '아침 정령의 친구', '일주일 동안 푹 자기'),
    TitleInfo(TitleId.bookwormSage, '책벌레 현자', '10시간 동안 읽기'),
    TitleInfo(TitleId.forcedMarchKnight, '강행군의 기사', '하루에 아주 많이 걷기'),
    TitleInfo(TitleId.nightWalker, '밤길의 산책자', '저녁 8시 이후에 걷기'),
    TitleInfo(TitleId.awakened, '각성자', 'Lv.5 달성'),
    TitleInfo(TitleId.lanternKeeper, '등불지기', 'Lv.10 달성'),
  ];

  static TitleInfo info(TitleId id) => all.firstWhere((t) => t.id == id);

  /// 날짜순으로 정렬된 [history] 와 현재 [level] 로 얻은 칭호를 계산한다
  static Set<TitleId> earned(List<DailyRecord> history, int level) {
    final result = <TitleId>{};

    final totalSteps = history.fold<int>(0, (s, d) => s + d.steps);
    final totalStudy = history.fold<int>(0, (s, d) => s + d.studyMinutes);

    if (totalSteps >= RuleConstants.firstStepsThreshold) {
      result.add(TitleId.firstSteps);
    }
    if (_longestStreak(history, (d) => d.stepGoalAchieved) >=
        RuleConstants.persistentTravelerDays) {
      result.add(TitleId.persistentTraveler);
    }
    if (_longestStreak(history, (d) => d.sleptWell) >=
        RuleConstants.morningSpiritDays) {
      result.add(TitleId.morningSpiritFriend);
    }
    if (totalStudy >= RuleConstants.bookwormStudyMinutes) {
      result.add(TitleId.bookwormSage);
    }
    if (history.any((d) => d.steps >= RuleConstants.forcedMarchSteps)) {
      result.add(TitleId.forcedMarchKnight);
    }
    final nightDays = history
        .where((d) => d.stepsAfter8pm >= RuleConstants.nightWalkSteps)
        .length;
    if (nightDays >= RuleConstants.nightWalkDays) {
      result.add(TitleId.nightWalker);
    }
    if (level >= RuleConstants.awakenedLevel) result.add(TitleId.awakened);
    if (level >= RuleConstants.lanternKeeperLevel) {
      result.add(TitleId.lanternKeeper);
    }
    return result;
  }

  static int _longestStreak(
    List<DailyRecord> history,
    bool Function(DailyRecord) test,
  ) {
    var best = 0;
    var current = 0;
    for (final day in history) {
      current = test(day) ? current + 1 : 0;
      if (current > best) best = current;
    }
    return best;
  }
}
