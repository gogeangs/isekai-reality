import '../models/daily_record.dart';
import 'rule_constants.dart';
import 'town_rules.dart';

enum TitleId {
  firstSteps,
  persistentTraveler,
  morningSpiritFriend,
  bookwormSage, // 이름은 '도감의 현자' (저장된 칭호와 맞추려고 id는 그대로)
  forcedMarchKnight,
  nightWalker,
  awakened,
  lanternKeeper,
  // 탐험 칭호 (2026-11-09)
  gateKeeper,
  lakeFriend,
  townLight,
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
    TitleInfo(TitleId.morningSpiritFriend, '아침 정령의 친구', '여관에서 일주일 내내 쉬기'),
    TitleInfo(TitleId.bookwormSage, '도감의 현자', '도감의 몬스터를 모두 정화하기'),
    TitleInfo(TitleId.forcedMarchKnight, '강행군의 기사', '하루에 아주 많이 걷기'),
    TitleInfo(TitleId.nightWalker, '밤길의 산책자', '저녁 8시 이후에 걷기'),
    TitleInfo(TitleId.awakened, '각성자', 'Lv.5 달성'),
    TitleInfo(TitleId.lanternKeeper, '등불지기', 'Lv.10 달성'),
    TitleInfo(TitleId.gateKeeper, '미궁의 문지기', '미궁 입구 다섯 곳 가 보기'),
    TitleInfo(TitleId.lakeFriend, '호수의 친구', '정령의 물가에 다섯 번 놀러 가기'),
    TitleInfo(TitleId.townLight, '동네의 빛', '안개 300칸 걷기'),
  ];

  /// 탐험 칭호가 보는 장소 id 머리말 (lib/features/map/ansan_area.dart)
  static const String gatePrefix = 'gate_';
  static const String lakePrefix = 'lake_';

  /// 대표 칭호: 플레이어가 고른 칭호가 있고 얻은 칭호면 그것,
  /// 아니면 '끈기의 여행자' → 가장 나중 칭호 순으로 자동.
  static TitleId? equipped(Set<TitleId> earned, {TitleId? chosen}) {
    if (chosen != null && earned.contains(chosen)) return chosen;
    if (earned.contains(TitleId.persistentTraveler)) {
      return TitleId.persistentTraveler;
    }
    for (final t in all.reversed) {
      if (earned.contains(t.id)) return t.id;
    }
    return null;
  }

  static TitleId? parse(String? name) {
    for (final t in TitleId.values) {
      if (t.name == name) return t;
    }
    return null;
  }

  static TitleInfo info(TitleId id) => all.firstWhere((t) => t.id == id);

  /// 날짜순으로 정렬된 [history] 와 현재 [level] 로 얻은 칭호를 계산한다
  /// [revealedCells] 안개를 걷은 칸 수 (탐험 기록은 하루 기록 밖에 있다)
  static Set<TitleId> earned(
    List<DailyRecord> history,
    int level, {
    int revealedCells = 0,
  }) {
    final result = <TitleId>{};

    final totalSteps = history.fold<int>(0, (s, d) => s + d.steps);
    final species = <String>{for (final d in history) ...d.purifiedMonsterIds};

    if (totalSteps >= RuleConstants.firstStepsThreshold) {
      result.add(TitleId.firstSteps);
    }
    if (_longestStreak(history, (d) => d.stepGoalAchieved) >=
        RuleConstants.persistentTravelerDays) {
      result.add(TitleId.persistentTraveler);
    }
    final restStreaks = TownRules.restStreaks(history);
    if (restStreaks.isNotEmpty &&
        restStreaks.reduce((a, b) => a > b ? a : b) >=
            RuleConstants.morningSpiritDays) {
      result.add(TitleId.morningSpiritFriend);
    }
    if (species.length >= RuleConstants.codexSageSpecies) {
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

    final visited = <String>{for (final d in history) ...d.visitedPlaceIds};
    final gates = visited.where((id) => id.startsWith(gatePrefix)).length;
    if (gates >= RuleConstants.gateKeeperGates) result.add(TitleId.gateKeeper);
    final lakeDays = history
        .where((d) => d.visitedPlaceIds.any((id) => id.startsWith(lakePrefix)))
        .length;
    if (lakeDays >= RuleConstants.lakeFriendVisits) {
      result.add(TitleId.lakeFriend);
    }
    if (revealedCells >= RuleConstants.brightTownCells) {
      result.add(TitleId.townLight);
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
