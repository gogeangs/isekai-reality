import 'element_rules.dart';
import 'mastery_rules.dart';
import 'monsters.dart';

/// 직업 전용 규칙 (11-11 #74). 직업 각성(#55)이 생기기 전에는 데이터만 있고
/// 화면에는 「직업 각성 뒤 열림」으로 잠가 둔다.

/// 연금술사 숙련도 단계
enum AlchemistRank { apprentice, skilled, artisan, master }

extension AlchemistRankInfo on AlchemistRank {
  String get label => switch (this) {
        AlchemistRank.apprentice => '견습',
        AlchemistRank.skilled => '숙련',
        AlchemistRank.artisan => '장인',
        AlchemistRank.master => '대가',
      };

  /// 이 단계에 필요한 숙련도 점수
  int get need => switch (this) {
        AlchemistRank.apprentice => 0,
        AlchemistRank.skilled => 100,
        AlchemistRank.artisan => 400,
        AlchemistRank.master => 1000,
      };

  /// 품질 점수 보너스
  int get qualityBonus => switch (this) {
        AlchemistRank.apprentice => 0,
        AlchemistRank.skilled => 1,
        AlchemistRank.artisan => 1,
        AlchemistRank.master => 2,
      };

  /// 끓는 시간 배율
  double get brewTime => switch (this) {
        AlchemistRank.apprentice || AlchemistRank.skilled => 1,
        AlchemistRank.artisan => 0.8,
        AlchemistRank.master => 0.6,
      };
}

/// 연금술사 전용 능력
enum AlchemistAbility { recipeSave, twoBottles, throwPotion, threeBottles, masterPotions }

class AlchemistAbilityInfo {
  const AlchemistAbilityInfo(this.id, this.label, this.level, this.rank);

  final AlchemistAbility id;
  final String label;

  /// 열리는 캐릭터 레벨
  final int level;
  final AlchemistRank rank;
}

class AlchemistRules {
  AlchemistRules._();

  /// 숙련도 점수: 물약 끓이기 3, 변환·정제 1, 최상 품질 +2
  static const int brewPoints = 3;
  static const int convertPoints = 1;
  static const int bestBonusPoints = 2;

  /// 물약 투척: 전투 한 번에 1번, 속성 피해 ×2 + 상태 이상
  static const int throwsPerBattle = 1;
  static const double throwMultiplier = 2;

  /// 대가 물약
  static const double reviveHp = 0.5; // 부활 물약: 쓰러지면 HP 50%로 한 번
  static const double expElixir = 1.5; // 경험의 영약: 30분 경험치 ×1.5
  static const Duration expElixirTime = Duration(minutes: 30);

  /// 호문쿨루스 연결: 데리고 다니면 끓기·변환 시간 -20%.
  /// 속성 마석을 먹이면 속성이 생기고, 바꾸려면 다른 속성 마석 3개.
  static const double homunculusTime = 0.8;
  static const int homunculusChangeStones = 3;

  static const List<AlchemistAbilityInfo> abilities = [
    AlchemistAbilityInfo(AlchemistAbility.recipeSave, '순서 기록·레시피 저장', 15,
        AlchemistRank.apprentice),
    AlchemistAbilityInfo(
        AlchemistAbility.twoBottles, '한 번에 2병', 20, AlchemistRank.skilled),
    AlchemistAbilityInfo(AlchemistAbility.throwPotion, '전투에서 물약 투척', 25,
        AlchemistRank.skilled),
    AlchemistAbilityInfo(
        AlchemistAbility.threeBottles, '한 번에 3병', 30, AlchemistRank.artisan),
    AlchemistAbilityInfo(AlchemistAbility.masterPotions,
        '대가 물약 (부활 물약 · 경험의 영약)', 40, AlchemistRank.master),
  ];

  static AlchemistRank rankOf(int points) {
    var r = AlchemistRank.apprentice;
    for (final x in AlchemistRank.values) {
      if (points >= x.need) r = x;
    }
    return r;
  }

  /// 호문쿨루스에게 속성 마석을 먹였을 때 생기는 속성 (바꾸려면 3개)
  static Element? homunculusElement(Element? now, Element fed, int count) {
    if (now == null) return count >= 1 ? fed : null;
    if (now == fed) return now;
    return count >= homunculusChangeStones ? fed : now;
  }
}

/// 대장간 장비 속성 작업 (11-11 #74, 확정본)
enum SmithAction { apply, change, extract, upgrade }

extension SmithActionLabel on SmithAction {
  String get label => switch (this) {
        SmithAction.apply => '속성 입히기',
        SmithAction.change => '속성 바꾸기',
        SmithAction.extract => '속성 추출',
        SmithAction.upgrade => '속성 강화',
      };
}

class SmithRules {
  SmithRules._();

  /// 속성 강화 최대 단계 (1단계 = 입힌 상태, 강화 0~3)
  static const int maxLevel = 3;

  /// 금화 (NPC 도르군). 대장장이 직업은 절반.
  static int gold(SmithAction a, {bool blacksmith = false}) {
    final g = switch (a) {
      SmithAction.apply => 100,
      SmithAction.change => 150,
      SmithAction.extract => 80,
      SmithAction.upgrade => 200,
    };
    return blacksmith ? g ~/ 2 : g;
  }

  /// 들어가는 빛나는 속성 코어 (추출은 돌려받는다)
  static int cores(SmithAction a) => switch (a) {
        SmithAction.apply || SmithAction.change => 1,
        SmithAction.extract => 0,
        SmithAction.upgrade => 2,
      };

  /// 실패 확률 (숨김). [level] 은 지금 강화 단계 (0~2). 대장장이 직업은 절반.
  static double failChance(SmithAction a, {int level = 0, bool blacksmith = false}) {
    final f = switch (a) {
      SmithAction.apply || SmithAction.change => 0.25,
      SmithAction.extract => 0.0,
      SmithAction.upgrade => switch (level) {
          0 => 0.30,
          1 => 0.45,
          _ => 0.60,
        },
    };
    return blacksmith ? f / 2 : f;
  }

  /// 공격 속성의 강함 배율 (강화 단계마다 +0.1, 숨김)
  static double strongAt(int level) => ElementRules.strong + 0.1 * level;

  /// 방어 속성의 받는 피해 배율 (강화 단계마다 -0.05, 숨김)
  static double guardAt(int level) => ElementRules.guard - 0.05 * level;

  static const String failLine = '망치질이 빗나갔어요. 코어는 돌려드릴게요.';
}

// ═════════════════════════════ 직업 각성 (묶음 30 #55)
//
// Lv.15에 숨은 숙련도(#176)를 바탕으로 직업을 고른다. 고유 기술(저절로)과
// 직업 스킬(새 MP로 씀)이 있다. 화면에는 배수·%·확률을 보이지 않는다.

/// 직업 24가지: 기본 8 · 복합 12 · 숨은 4
enum JobId {
  // 기본
  blacksmith,
  herbalist,
  alchemist,
  warrior,
  explorer,
  appraiser,
  tamer,
  merchant,
  // 복합
  weaponsmith,
  runesmith,
  jeweler,
  healer,
  hunter,
  archaeologist,
  pilgrim,
  peddler,
  adventurer,
  beastKnight,
  pathfinder,
  potionMerchant,
  // 숨은
  nightWalker,
  gateHeir,
  ashHunter,
  allCrafter,
}

enum JobKind { basic, complex, hidden }

/// 직업 스킬을 쓰는 곳
enum SkillPlace {
  smithyEnhance,
  smithyCraft,
  smithyWork,
  harvest,
  relic,
  alchemy,
  battle,
  map,
  nightMap,
  lens,
  petExpedition,
  shop,
  board,
  expeditionSend,
  anywhere,
}

/// 첫 직업 스킬 24개 (직업마다 하나). 나머지 칸은 나중에
enum JobSkill {
  focusForge,
  bountyTouch,
  quickBrew,
  powerStrike,
  pathFind,
  trueEye,
  cheer,
  bargain,
  masterBlade,
  runeCarve,
  polish,
  healingLight,
  vitalStrike,
  excavate,
  blessedSteps,
  wanderingMarket,
  negotiate,
  jointAttack,
  longRoad,
  specialSale,
  moonWalk,
  lightResonance,
  ashPurge,
  artisanIntuition,
}

/// 스킬이 어떻게 걸리는지
enum SkillMode {
  /// 쓰면 그 일을 할 때 한 번 (아이콘으로 보이고 앱을 꺼도 남음)
  next,

  /// 쓰면 일정 시간 동안
  timed,

  /// 바로 일어남 (고르기 창이 뜨는 것 포함)
  instant,

  /// 전투 화면 버튼
  battle,
}

class JobSkillInfo {
  const JobSkillInfo(this.id, this.name, this.place, this.text, this.mp,
      {this.mode = SkillMode.next, this.duration});

  final JobSkill id;
  final String name;
  final SkillPlace place;

  /// 숫자 없는 한 줄 설명
  final String text;

  /// 주 직업으로 쓸 때 MP
  final int mp;
  final SkillMode mode;
  final Duration? duration;
}

class JobInfo {
  const JobInfo(this.id, this.name, this.kind, this.masteries, this.trait,
      this.skills);

  final JobId id;
  final String name;
  final JobKind kind;

  /// 기본 1 · 복합 2 · 숨은 0
  final List<Mastery> masteries;

  /// 고유 기술 한 줄 (숫자 없이)
  final String trait;

  /// 스킬 칸: 기본 4 · 복합·숨은 2. 지금은 첫 칸만 (null 은 빈 칸, 화면에 안 보임)
  final List<JobSkill?> skills;

  List<JobSkill> get openSkills => [for (final s in skills) if (s != null) s];
}

class JobRules {
  JobRules._();

  /// 직업이 열리는 레벨
  static const int awakenLevel = 15;

  /// 보조 슬롯: Lv.15 1칸, Lv.20 2칸
  static int subSlots(int level) => level >= 20 ? 2 : (level >= awakenLevel ? 1 : 0);

  /// 숙련도가 쌓이는 배율 (주 · 보조)
  static const double mainGrowth = 1.5;
  static const double subGrowth = 1.2;

  /// 고유 기술 세기 (주 · 보조 · 견습)
  static const double mainTrait = 1.0;
  static const double subTrait = 0.5;
  static const double apprenticeTrait = 0.5;

  /// 보조 직업 스킬 MP 배율 (소수점 올림)
  static const double subSkillCost = 1.5;
  static int skillCost(JobSkill s, {bool sub = false, bool half = false}) {
    var c = skill(s).mp.toDouble();
    if (sub) c = (c * subSkillCost).ceilToDouble();
    if (half) c = (c / 2).ceilToDouble();
    return c.round();
  }

  // ───────────── 새 MP (#183)
  /// 최대 MP = 30 + 지능 × 2
  static int maxMp(int intellect) => 30 + intellect * 2;

  /// 걸으면 1,000보마다 최대 MP의 10%
  static const int mpStepUnit = 1000;
  static const double mpPerUnit = 0.10;

  // ───────────── 고유 기술 (장인 기준, 숨은 규칙)
  static const double blacksmithSafe = 0.25; // 강화 실패 때 가끔 무사
  static const double herbalistSight = 0.5; // 채집 자리가 더 멀리서
  static const double alchemistDouble = 0.10; // 물약이 가끔 2개
  static const double warriorLowHp = 0.10; // HP 절반 아래 피해
  static const double explorerPlace = 0.20; // 새 장소 보상
  static const double explorerGauge = 0.10; // 처음 가는 길 열쇠 게이지
  static const double appraiserRare = 0.30; // 드문 결과 확률 ×1.3
  static const double tamerTime = 0.15; // 펫 원정 시간 덜
  static const double tamerGrowth = 0.20; // 펫 성장
  static const double merchantDiscount = 0.30; // 하루 한 번 할인
  static const double weaponsmithDamage = 0.08;
  static const double runesmithElement = 0.15;
  static const double jewelerGrade = 10; // 장신구 좋은 등급 %p
  static const double healerHeal = 0.25;
  static const double hunterLoot = 0.20;
  static const int archaeologistExtra = 1;
  static const double pilgrimFind = 0.15;
  static const int peddlerSteps = 5000;
  static const double peddlerGold = 0.10;
  static const double adventurerReward = 0.15;
  static const double beastKnightDamage = 0.08;
  static const double pathfinderRange = 0.20;
  static const double potionMerchantGold = 0.30;
  static const double nightDamage = 0.10;
  static const double gateHeirGrowth = 0.30;
  static const double gateHeirMp = 0.10;
  static const double ashDamage = 0.10;

  // ───────────── 직업 스킬 수치 (숨은 규칙)
  static const double powerStrike = 2.0;
  static const double healingLight = 0.30;
  static const double ashPurge = 3.0;
  static const double bargain = 0.20;
  static const double longRoad = 0.50;
  static const double specialSale = 2.0;
  static const double resonance = 0.30;
  static const double blessedSteps = 1.5;

  // ───────────── 숨은 직업 조건
  static const int nightWalkerSteps = 50000;
  static const int gateHeirDays = 60;

  /// 밤 (오후 7시 ~ 새벽 5시)
  static bool isNight(DateTime t) => t.hour >= 19 || t.hour < 5;

  /// 잿빛 몬스터인지
  static bool isAsh(MonsterId m) => m.name.startsWith('ash');

  static const List<JobInfo> jobs = [
    JobInfo(JobId.blacksmith, '대장장이', JobKind.basic, [Mastery.smith],
        '강화에 실패해도 가끔 무사해요', [JobSkill.focusForge, null, null, null]),
    JobInfo(JobId.herbalist, '약초꾼', JobKind.basic, [Mastery.harvest],
        '채집 자리가 더 멀리서 보여요', [JobSkill.bountyTouch, null, null, null]),
    JobInfo(JobId.alchemist, '연금술사', JobKind.basic, [Mastery.alchemy],
        '물약이 가끔 두 병 나와요', [JobSkill.quickBrew, null, null, null]),
    JobInfo(JobId.warrior, '전사', JobKind.basic, [Mastery.combat],
        '위험할수록 더 세게 싸워요', [JobSkill.powerStrike, null, null, null]),
    JobInfo(JobId.explorer, '탐험가', JobKind.basic, [Mastery.walk],
        '새 장소와 처음 가는 길에서 더 얻어요', [JobSkill.pathFind, null, null, null]),
    JobInfo(JobId.appraiser, '감정사', JobKind.basic, [Mastery.appraise],
        '돋보기로 드문 것을 더 잘 찾아요', [JobSkill.trueEye, null, null, null]),
    JobInfo(JobId.tamer, '조련사', JobKind.basic, [Mastery.spirit],
        '펫이 원정에서 빨리 돌아오고 빨리 자라요', [JobSkill.cheer, null, null, null]),
    JobInfo(JobId.merchant, '상인', JobKind.basic, [Mastery.trade],
        '하루 한 번 잡화상에서 싸게 사요', [JobSkill.bargain, null, null, null]),
    JobInfo(JobId.weaponsmith, '무기 장인', JobKind.complex,
        [Mastery.smith, Mastery.combat], '직접 만든 무기로 더 세게 싸워요',
        [JobSkill.masterBlade, null]),
    JobInfo(JobId.runesmith, '룬 대장장이', JobKind.complex,
        [Mastery.smith, Mastery.alchemy], '장비를 만들 때 가끔 속성이 붙어요',
        [JobSkill.runeCarve, null]),
    JobInfo(JobId.jeweler, '보석 세공사', JobKind.complex,
        [Mastery.smith, Mastery.appraise], '장신구가 좋은 등급으로 잘 나와요',
        [JobSkill.polish, null]),
    JobInfo(JobId.healer, '치유사', JobKind.complex,
        [Mastery.harvest, Mastery.alchemy], '회복 물약이 더 많이 채워 줘요',
        [JobSkill.healingLight, null]),
    JobInfo(JobId.hunter, '사냥꾼', JobKind.complex,
        [Mastery.combat, Mastery.harvest], '필드 몬스터 재료를 가끔 더 얻어요',
        [JobSkill.vitalStrike, null]),
    JobInfo(JobId.archaeologist, '고고학자', JobKind.complex,
        [Mastery.appraise, Mastery.harvest], '고대 유물에서 더 얻어요',
        [JobSkill.excavate, null]),
    JobInfo(JobId.pilgrim, '순례자', JobKind.complex,
        [Mastery.walk, Mastery.appraise], '새 장소에서 가끔 숨은 물건을 찾아요',
        [JobSkill.blessedSteps, null]),
    JobInfo(JobId.peddler, '행상인', JobKind.complex,
        [Mastery.trade, Mastery.walk], '많이 걸은 날은 더 비싸게 팔아요',
        [JobSkill.wanderingMarket, null]),
    JobInfo(JobId.adventurer, '모험가', JobKind.complex,
        [Mastery.combat, Mastery.trade], '길드·긴급 의뢰 보상이 늘어요',
        [JobSkill.negotiate, null]),
    JobInfo(JobId.beastKnight, '마수 기사', JobKind.complex,
        [Mastery.combat, Mastery.spirit], '펫과 함께 싸우면 더 세져요',
        [JobSkill.jointAttack, null]),
    JobInfo(JobId.pathfinder, '길잡이', JobKind.complex,
        [Mastery.walk, Mastery.spirit], '원정을 더 멀리 보낼 수 있어요',
        [JobSkill.longRoad, null]),
    JobInfo(JobId.potionMerchant, '물약 상인', JobKind.complex,
        [Mastery.alchemy, Mastery.trade], '물약을 비싸게 팔아요',
        [JobSkill.specialSale, null]),
    JobInfo(JobId.nightWalker, '밤의 산책자', JobKind.hidden, [],
        '밤에 만나는 몬스터에게 더 세요', [JobSkill.moonWalk, null]),
    JobInfo(JobId.gateHeir, '문지기의 후계자', JobKind.hidden, [],
        '첫 펫이 빨리 자라고 원정 기력을 덜 써요', [JobSkill.lightResonance, null]),
    JobInfo(JobId.ashHunter, '잿빛 사냥꾼', JobKind.hidden, [],
        '잿빛 몬스터에게 더 세요', [JobSkill.ashPurge, null]),
    JobInfo(JobId.allCrafter, '만물 장인', JobKind.hidden, [],
        '보조 직업의 고유 기술도 온전히 써요', [JobSkill.artisanIntuition, null]),
  ];

  static JobInfo info(JobId id) => jobs[id.index];

  static JobId? parse(String? name) {
    for (final j in JobId.values) {
      if (j.name == name) return j;
    }
    return null;
  }

  static const List<JobSkillInfo> skills = [
    JobSkillInfo(JobSkill.focusForge, '집중 단조', SkillPlace.smithyEnhance,
        '이번 강화는 실패해도 무사해요', 30),
    JobSkillInfo(JobSkill.bountyTouch, '풍요의 손길', SkillPlace.harvest,
        '이번 채집이 풍성해져요', 20),
    JobSkillInfo(JobSkill.quickBrew, '연성 가속', SkillPlace.alchemy,
        '이번에 만드는 물약이 하나 더 나와요', 20),
    JobSkillInfo(JobSkill.powerStrike, '힘의 일격', SkillPlace.battle,
        '다음 공격이 아주 강해져요', 10, mode: SkillMode.battle),
    JobSkillInfo(JobSkill.pathFind, '길 찾기', SkillPlace.map,
        '잠시 동안 주변에 숨은 채집 자리가 보여요', 20,
        mode: SkillMode.timed, duration: Duration(minutes: 30)),
    JobSkillInfo(JobSkill.trueEye, '진실의 눈', SkillPlace.lens,
        '이번 감정은 드문 결과가 꼭 나와요', 30),
    JobSkillInfo(JobSkill.cheer, '응원', SkillPlace.petExpedition,
        '원정 간 펫이 서둘러 돌아와요', 20, mode: SkillMode.instant),
    JobSkillInfo(JobSkill.bargain, '대흥정', SkillPlace.shop,
        '이번 거래 하나를 싸게 사거나 비싸게 팔아요', 20),
    JobSkillInfo(JobSkill.masterBlade, '명검 벼리기', SkillPlace.smithyCraft,
        '이번 무기가 좋은 등급으로 나오기 쉬워요', 30),
    JobSkillInfo(JobSkill.runeCarve, '룬 새기기', SkillPlace.smithyWork,
        '장비 하나에 원하는 속성을 새겨요', 40, mode: SkillMode.instant),
    JobSkillInfo(JobSkill.polish, '광택 내기', SkillPlace.smithyWork,
        '장신구 하나의 능력치를 다시 굴려요', 30, mode: SkillMode.instant),
    JobSkillInfo(JobSkill.healingLight, '치유의 빛', SkillPlace.battle,
        'HP를 회복해요', 20, mode: SkillMode.battle),
    JobSkillInfo(JobSkill.vitalStrike, '급소 노리기', SkillPlace.battle,
        '다음 공격이 꼭 치명타', 10, mode: SkillMode.battle),
    JobSkillInfo(JobSkill.excavate, '발굴', SkillPlace.relic,
        '이번 고대 유물에서 귀한 재료가 꼭 나와요', 30),
    JobSkillInfo(JobSkill.blessedSteps, '축복의 발걸음', SkillPlace.map,
        '잠시 동안 걸음 게이지가 빨리 차요', 20,
        mode: SkillMode.timed, duration: Duration(minutes: 30)),
    JobSkillInfo(JobSkill.wanderingMarket, '떠돌이 장터', SkillPlace.anywhere,
        '마을에 가지 않고 그 자리에서 물건을 팔아요', 20,
        mode: SkillMode.instant),
    JobSkillInfo(JobSkill.negotiate, '의뢰 협상', SkillPlace.board,
        '길드 의뢰 하나를 다른 의뢰로 바꿔요', 10, mode: SkillMode.instant),
    JobSkillInfo(JobSkill.jointAttack, '합동 공격', SkillPlace.battle,
        '펫 스킬을 바로 채워요', 20, mode: SkillMode.battle),
    JobSkillInfo(JobSkill.longRoad, '먼 길 안내', SkillPlace.expeditionSend,
        '이번 원정을 더 멀리 보낼 수 있어요', 20),
    JobSkillInfo(JobSkill.specialSale, '특가 판매', SkillPlace.shop,
        '이번 물약 판매 값이 크게 올라요', 20),
    JobSkillInfo(JobSkill.moonWalk, '달빛 걸음', SkillPlace.nightMap,
        '잠시 동안 주변에 밤 몬스터가 더 나타나요', 20,
        mode: SkillMode.timed, duration: Duration(hours: 1)),
    JobSkillInfo(JobSkill.lightResonance, '빛의 공명', SkillPlace.anywhere,
        '펫의 기력을 채워 줘요', 30, mode: SkillMode.instant),
    JobSkillInfo(JobSkill.ashPurge, '잿빛 정화', SkillPlace.battle,
        '잿빛 몬스터의 보호를 깨고 큰 피해', 30, mode: SkillMode.battle),
    JobSkillInfo(JobSkill.artisanIntuition, '장인의 직감', SkillPlace.anywhere,
        '다음에 쓰는 스킬 MP가 줄어요', 10),
  ];

  static JobSkillInfo skill(JobSkill s) => skills[s.index];

  /// 열린 직업 (숨은 직업 조건은 [hidden] 으로 받는다)
  static Set<JobId> unlocked(MasteryStage Function(Mastery) stage,
      {Set<JobId> hidden = const {}}) {
    final out = <JobId>{...hidden};
    for (final j in jobs) {
      switch (j.kind) {
        case JobKind.basic:
          if (stage(j.masteries.single).index >= MasteryStage.skilled.index) {
            out.add(j.id);
          }
        case JobKind.complex:
          if (j.masteries.every(
              (m) => stage(m).index >= MasteryStage.expert.index)) {
            out.add(j.id);
          }
        case JobKind.hidden:
          break;
      }
    }
    return out;
  }

  /// 큰 숙련도의 기본 직업
  static JobId basicOf(Mastery m) =>
      jobs.firstWhere((j) => j.kind == JobKind.basic && j.masteries.single == m).id;

  /// 첫 펫 한마디
  static const String awakenLine = '이제 너만의 길을 찾을 때야. 길드에 가 보자!';
  static String newJobLine(String job) => '새 길이 열렸어! $job, 길드에서 확인해 봐.';
}
