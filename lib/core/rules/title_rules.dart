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
  // 보스 칭호 (11-11 #75): 처음 잡으면. 얻기 전에는 보이지 않는다
  bossWarden,
  bossFireKing,
  bossFrostWolf,
  bossTreant,
  bossBatQueen,
  bossGriffin,
  // 11-11 #83: 고대 유물을 다섯 번 캐면 (얻기 전엔 숨김)
  relicHunter,
  // 숨은 숙련도 (묶음 27 #176): 큰 숙련도 숙련된 · 장인
  smithAdept,
  smithMaster,
  harvestAdept,
  harvestMaster,
  alchemyAdept,
  alchemyMaster,
  combatAdept,
  combatMaster,
  walkAdept,
  walkMaster,
  appraiseAdept,
  appraiseMaster,
  spiritAdept,
  spiritMaster,
  tradeAdept,
  tradeMaster,
  // 묶음 34 2막: 분신 다섯 · 본체를 처음 쓰러뜨리면 (얻기 전엔 숨김)
  ashRage,
  ashSorrow,
  ashGreed,
  ashFear,
  ashLonely,
  ashBridge,
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

  /// 얻은 이유 한 줄 (칭호 축하 연출, 11-11 #85)
  static String earnedLine(TitleId t) {
    final i = elementTitles.indexOf(t);
    if (i >= 0) {
      return '${Element.values[i].label} 속성과 오래 함께했어요';
    }
    return switch (t) {
      TitleId.firstSteps => '처음으로 걸었어요',
      TitleId.persistentTraveler => '일주일 내내 걸음 목표를 이뤘어요',
      TitleId.morningSpiritFriend => '일주일 내내 여관에서 쉬었어요',
      TitleId.bookwormSage => '도감의 몬스터를 모두 사냥했어요',
      TitleId.forcedMarchKnight => '하루에 아주 많이 걸었어요',
      TitleId.nightWalker => '저녁 8시가 넘어서도 걸었어요',
      TitleId.awakened => 'Lv.5에 올랐어요',
      TitleId.lanternKeeper => 'Lv.10에 올랐어요',
      TitleId.gateKeeper => '미궁 입구 다섯 곳을 가 봤어요',
      TitleId.lakeFriend => '정령의 물가에 다섯 번 놀러 갔어요',
      TitleId.townLight => '필드 몬스터 30마리를 사냥했어요',
      TitleId.bossWarden => '미궁 문지기를 처음 쓰러뜨렸어요',
      TitleId.bossFireKing => '불꽃 슬라임 왕을 처음 쓰러뜨렸어요',
      TitleId.bossFrostWolf => '서리 늑대왕을 처음 쓰러뜨렸어요',
      TitleId.bossTreant => '숲의 고목 정령을 처음 달랬어요',
      TitleId.bossBatQueen => '그림자 박쥐 여왕을 처음 쓰러뜨렸어요',
      TitleId.bossGriffin => '천둥 그리폰을 처음 쓰러뜨렸어요',
      TitleId.relicHunter => '고대 유물을 다섯 번 발굴했어요',
      TitleId.smithAdept || TitleId.smithMaster => '대장간 일에 익숙해졌어요',
      TitleId.harvestAdept || TitleId.harvestMaster => '채집에 익숙해졌어요',
      TitleId.alchemyAdept || TitleId.alchemyMaster => '물약 끓이기에 익숙해졌어요',
      TitleId.combatAdept || TitleId.combatMaster => '싸움에 익숙해졌어요',
      TitleId.walkAdept || TitleId.walkMaster => '정말 많이 걷고 찾아다녔어요',
      TitleId.appraiseAdept || TitleId.appraiseMaster => '감정에 익숙해졌어요',
      TitleId.spiritAdept || TitleId.spiritMaster => '원정 보내기에 익숙해졌어요',
      TitleId.tradeAdept || TitleId.tradeMaster => '장사와 의뢰에 익숙해졌어요',
      TitleId.ashRage => '잿불의 분노를 잠재웠어요',
      TitleId.ashSorrow => '잿비의 슬픔을 달랬어요',
      TitleId.ashGreed => '잿금의 탐욕을 끊어 냈어요',
      TitleId.ashFear => '잿그림자의 두려움을 이겨 냈어요',
      TitleId.ashLonely => '잿바람의 외로움을 안아 줬어요',
      TitleId.ashBridge => '잿빛 군주를 멈추고 문을 다리로 바꿨어요',
      _ => '새 칭호를 얻었어요',
    };
  }

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
    ...bossTitles,
    TitleId.relicHunter,
    ...masteryTitles,
    ...ashTitles,
  };

  /// 2막 칭호 (묶음 34)와 그 몬스터: 처음 쓰러뜨리면
  static const Map<TitleId, MonsterId> ashTitleMonsters = {
    TitleId.ashRage: MonsterId.ashRage,
    TitleId.ashSorrow: MonsterId.ashSorrow,
    TitleId.ashGreed: MonsterId.ashGreed,
    TitleId.ashFear: MonsterId.ashFear,
    TitleId.ashLonely: MonsterId.ashLonely,
    TitleId.ashBridge: MonsterId.ashKing,
  };
  static const List<TitleId> ashTitles = [
    TitleId.ashRage,
    TitleId.ashSorrow,
    TitleId.ashGreed,
    TitleId.ashFear,
    TitleId.ashLonely,
    TitleId.ashBridge,
  ];

  /// 숨은 숙련도 칭호 (묶음 27 #176). 기록 counters 'mtitle:<이름>' 으로 얻는다
  static const List<TitleId> masteryTitles = [
    TitleId.smithAdept,
    TitleId.smithMaster,
    TitleId.harvestAdept,
    TitleId.harvestMaster,
    TitleId.alchemyAdept,
    TitleId.alchemyMaster,
    TitleId.combatAdept,
    TitleId.combatMaster,
    TitleId.walkAdept,
    TitleId.walkMaster,
    TitleId.appraiseAdept,
    TitleId.appraiseMaster,
    TitleId.spiritAdept,
    TitleId.spiritMaster,
    TitleId.tradeAdept,
    TitleId.tradeMaster,
  ];

  /// 숙련도 칭호를 얻었다는 기록 칸
  static String masteryCounter(TitleId t) => 'mtitle:${t.name}';

  /// 보스 칭호와 그 보스
  static const Map<TitleId, MonsterId> bossTitleMonsters = {
    TitleId.bossWarden: MonsterId.labyrinthWarden,
    TitleId.bossFireKing: MonsterId.fireSlimeKing,
    TitleId.bossFrostWolf: MonsterId.frostWolfKing,
    TitleId.bossTreant: MonsterId.ancientTreant,
    TitleId.bossBatQueen: MonsterId.shadowBatQueen,
    TitleId.bossGriffin: MonsterId.thunderGriffin,
  };
  static const List<TitleId> bossTitles = [
    TitleId.bossWarden,
    TitleId.bossFireKing,
    TitleId.bossFrostWolf,
    TitleId.bossTreant,
    TitleId.bossBatQueen,
    TitleId.bossGriffin,
  ];

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
        for (final t in bossTitles)
          if (earned.contains(t)) info(t),
        if (earned.contains(TitleId.relicHunter)) info(TitleId.relicHunter),
        for (final t in masteryTitles)
          if (earned.contains(t)) info(t),
        for (final t in ashTitles)
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
    TitleInfo(TitleId.bossWarden, '문지기를 넘은 자', '숨은 칭호'),
    TitleInfo(TitleId.bossFireKing, '불꽃왕 사냥꾼', '숨은 칭호'),
    TitleInfo(TitleId.bossFrostWolf, '서리를 깨뜨린 자', '숨은 칭호'),
    TitleInfo(TitleId.bossTreant, '숲을 달래는 자', '숨은 칭호'),
    TitleInfo(TitleId.bossBatQueen, '밤을 밝힌 자', '숨은 칭호'),
    TitleInfo(TitleId.bossGriffin, '하늘을 가른 자', '숨은 칭호'),
    TitleInfo(TitleId.relicHunter, '옛 이야기를 캔 자', '숨은 칭호'),
    TitleInfo(TitleId.smithAdept, '견습 대장장이', '대장간 일을 꾸준히'),
    TitleInfo(TitleId.smithMaster, '장인 대장장이', '대장간 일의 장인'),
    TitleInfo(TitleId.harvestAdept, '약초꾼', '채집을 꾸준히'),
    TitleInfo(TitleId.harvestMaster, '대지의 손', '채집의 장인'),
    TitleInfo(TitleId.alchemyAdept, '견습 연금술사', '물약을 꾸준히'),
    TitleInfo(TitleId.alchemyMaster, '물약 장인', '연금술의 장인'),
    TitleInfo(TitleId.combatAdept, '노련한 사냥꾼', '싸움을 꾸준히'),
    TitleInfo(TitleId.combatMaster, '전장의 장인', '싸움의 장인'),
    TitleInfo(TitleId.walkAdept, '길잡이', '걷고 찾아다니기를 꾸준히'),
    TitleInfo(TitleId.walkMaster, '대륙을 걷는 자', '걷기와 탐험의 장인'),
    TitleInfo(TitleId.appraiseAdept, '견습 감정사', '감정을 꾸준히'),
    TitleInfo(TitleId.appraiseMaster, '진실의 눈', '감정의 장인'),
    TitleInfo(TitleId.spiritAdept, '정령의 벗', '원정을 꾸준히'),
    TitleInfo(TitleId.spiritMaster, '정령과 하나 된 자', '정령술의 장인'),
    TitleInfo(TitleId.tradeAdept, '떠돌이 상인', '장사와 의뢰를 꾸준히'),
    TitleInfo(TitleId.tradeMaster, '길드의 해결사', '장사와 의뢰의 장인'),
    TitleInfo(TitleId.ashRage, '분노를 잠재운 자', '숨은 칭호'),
    TitleInfo(TitleId.ashSorrow, '슬픔을 달랜 자', '숨은 칭호'),
    TitleInfo(TitleId.ashGreed, '탐욕을 끊은 자', '숨은 칭호'),
    TitleInfo(TitleId.ashFear, '두려움을 이긴 자', '숨은 칭호'),
    TitleInfo(TitleId.ashLonely, '외로움을 안아 준 자', '숨은 칭호'),
    TitleInfo(TitleId.ashBridge, '다리를 놓은 자', '숨은 칭호'),
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
        // 11-11 #75 요일 보스는 빼고 (미궁 문지기는 그대로)
        if (!m.slimeKind && (!m.isBoss || m.id == MonsterId.labyrinthWarden))
          m.id.name,
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
    // 보스 칭호 (11-11 #75): 그 보스를 처음 잡으면
    bossTitleMonsters.forEach((t, m) {
      if (species.contains(m.name)) result.add(t);
    });
    // 묶음 34 2막: 분신·본체를 처음 쓰러뜨리면
    ashTitleMonsters.forEach((t, m) {
      if (species.contains(m.name)) result.add(t);
    });
    final relics = history.fold<int>(0, (s, d) => s + (d.counters['relicDug'] ?? 0));
    if (relics >= 5) result.add(TitleId.relicHunter);
    // 숨은 숙련도 칭호 (묶음 27 #176)
    for (final t in masteryTitles) {
      final k = masteryCounter(t);
      if (history.any((d) => (d.counters[k] ?? 0) > 0)) result.add(t);
    }
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
