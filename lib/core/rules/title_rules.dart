import 'element_rules.dart';
import '../models/daily_record.dart';
import 'monsters.dart';
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
  // 속성 칭호 (11-11 #63): 그 속성 점수가 높으면. 얻기 전에는 보이지 않는다
  elFire,
  elWater,
  elWind,
  elEarth,
  elLight,
  elDark,
  elIce,
  elThunder,
  elMetal,
  elPoison,
}

class TitleInfo {
  const TitleInfo(this.id, this.name, this.hint);

  final TitleId id;
  final String name;

  /// 잠긴 칭호에 보여 줄 힌트
  final String hint;
}

const _el0 = '불꽃을 닮은 자';
const _el1 = '물결을 닮은 자';
const _el2 = '바람을 닮은 자';
const _el3 = '대지를 닮은 자';
const _el4 = '빛을 닮은 자';
const _el5 = '어둠을 닮은 자';
const _el6 = '서리를 닮은 자';
const _el7 = '번개를 닮은 자';
const _el8 = '강철을 닮은 자';
const _el9 = '독초를 닮은 자';

class TitleRules {
  TitleRules._();

  /// 도감에 보이는 칭호. 장소 칭호(미궁의 문지기·호수의 친구)는
  /// 전국 확대로 장소를 빼면서 숨겼다 (11-10, 장소를 다시 넣을 때 되살림).
  static List<TitleInfo> get all => [
        for (final t in _all)
          if (!hidden.contains(t.id)) t,
      ];

  static const Set<TitleId> hidden = {
    TitleId.gateKeeper,
    TitleId.lakeFriend,
    ...elementTitles,
  };

  /// 속성 칭호 (Element 순서와 같다)
  static const List<TitleId> elementTitles = [
    TitleId.elFire,
    TitleId.elWater,
    TitleId.elWind,
    TitleId.elEarth,
    TitleId.elLight,
    TitleId.elDark,
    TitleId.elIce,
    TitleId.elThunder,
    TitleId.elMetal,
    TitleId.elPoison,
  ];

  /// 프로필에 보이는 칭호: 보통 칭호 + 얻은 속성 칭호
  static List<TitleInfo> visible(Set<TitleId> earned) => [
        ...all,
        for (final t in elementTitles)
          if (earned.contains(t)) info(t),
      ];

  static const List<TitleInfo> _all = [
    TitleInfo(TitleId.firstSteps, '첫 걸음', '처음으로 걸어 보기'),
    TitleInfo(TitleId.persistentTraveler, '끈기의 여행자', '일주일 내내 목표 달성'),
    TitleInfo(TitleId.morningSpiritFriend, '아침 정령의 친구', '여관에서 일주일 내내 쉬기'),
    TitleInfo(TitleId.bookwormSage, '도감의 현자', '몬스터 7종을 모두 사냥하기 (속성 슬라임은 빼고)'),
    TitleInfo(TitleId.forcedMarchKnight, '강행군의 기사', '하루에 아주 많이 걷기'),
    TitleInfo(TitleId.nightWalker, '밤길의 산책자', '저녁 8시 이후에 걷기'),
    TitleInfo(TitleId.awakened, '각성자', 'Lv.5 달성'),
    TitleInfo(TitleId.lanternKeeper, '등불지기', 'Lv.10 달성'),
    TitleInfo(TitleId.gateKeeper, '미궁의 문지기', '미궁 입구 다섯 곳 가 보기'),
    TitleInfo(TitleId.lakeFriend, '호수의 친구', '정령의 물가에 다섯 번 놀러 가기'),
    TitleInfo(TitleId.townLight, '동네의 빛', '필드 몬스터 30마리 사냥하기'),
    TitleInfo(TitleId.elFire, _el0, '숨은 칭호'),
    TitleInfo(TitleId.elWater, _el1, '숨은 칭호'),
    TitleInfo(TitleId.elWind, _el2, '숨은 칭호'),
    TitleInfo(TitleId.elEarth, _el3, '숨은 칭호'),
    TitleInfo(TitleId.elLight, _el4, '숨은 칭호'),
    TitleInfo(TitleId.elDark, _el5, '숨은 칭호'),
    TitleInfo(TitleId.elIce, _el6, '숨은 칭호'),
    TitleInfo(TitleId.elThunder, _el7, '숨은 칭호'),
    TitleInfo(TitleId.elMetal, _el8, '숨은 칭호'),
    TitleInfo(TitleId.elPoison, _el9, '숨은 칭호'),
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

  static TitleInfo info(TitleId id) => _all.firstWhere((t) => t.id == id);

  /// 날짜순으로 정렬된 [history] 와 현재 [level] 로 얻은 칭호를 계산한다
  static Set<TitleId> earned(List<DailyRecord> history, int level) {
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
    // 11-10: 지금 도감의 몬스터를 모두 사냥했거나, 예전 6종을 모두 정화했으면
    // 11-11: 속성 슬라임은 빼고 7종 (무속성 슬라임 포함)
    final active = {
      for (final m in Monsters.all)
        if (!m.slimeKind) m.id.name,
    };
    const oldSix = {
      'ashSlime', 'labyrinthBat', 'roughWaterSpirit',
      'shadowButterfly', 'lostStoneSpirit', 'labyrinthWarden',
    };
    if (species.containsAll(active) || species.containsAll(oldSix)) {
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
    // 속성 칭호 (11-11 #63)
    ElementRules.scoresFrom(history).forEach((e, v) {
      if (v >= ElementRules.titleScore) {
        result.add(elementTitles[Element.values.indexOf(e)]);
      }
    });
    final monsters =
        history.fold<int>(0, (s, d) => s + d.fieldMonstersPurified);
    if (monsters >= RuleConstants.townLightMonsters) {
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
