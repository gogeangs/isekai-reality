import 'element_rules.dart';
import 'harvest_rules.dart';
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

// ═════════════════════════════ 직업 각성 (묶음 30 #55 · 묶음 31 #193~#198)
//
// Lv.15에 숨은 숙련도(#176)를 바탕으로 직업을 고른다. 직업마다 저절로 되는 고유 기술
// 하나 + 스킬 트리(기본 ①→②·③→④, 복합·숨은 ①→②). ①은 공격 스킬(직업을 얻으면 열림),
// 나머지는 Lv.15부터 레벨마다 2점씩 받는 스킬 포인트로 연다·강화한다(Lv.1~3).
// 숙련도 단계마다 숙련 스킬(패시브 24 · 액티브 8)이 생긴다. 화면에 배수·%·확률 없음.

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
  // 묶음 57 #249: 새 전투 직업 (궁수 = 옛 사냥꾼 · 사제 = 옛 치유사 · 기사 = 옛 마수 기사 자리)
  archer,
  mage,
  priest,
  rogue,
  knight,
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

/// 직업 스킬 (이름은 저장 키. 묶음 30 스킬 이름은 그대로 두고 더한다)
enum JobSkill {
  // 대장장이
  hotHammer, focusForge, masterTouch, quickRepair,
  // 채집가
  thornVine, bountyTouch, harvestSense, rootPull,
  // 연금술사
  potionThrow, quickBrew, recipeHunch, instantBrew,
  // 전사
  rush, ironWall, warCry, drill,
  // 탐험가
  galeSlash, pathFind, farSight, windWalk,
  // 감정사
  weakStab, trueEye, wideView, memoryRead,
  // 조련사
  chargeOrder, cheer, snackPouch, eggWarm,
  // 상인
  coinToss, bargain, knack, regular,
  // 복합 (① 공격 · ② 생활)
  masterSlash, masterBlade,
  runeBurst, runeCarve,
  gemShard, polish,
  healingLight, firstAid,
  vitalStrike, track,
  relicLight, excavate,
  blessedStrike, blessedSteps,
  bundleSwing, bigPack,
  counterSlash, negotiate,
  jointAttack, runTogether,
  windBlade, longRoad,
  poisonFlask, specialSale,
  // 숨은
  shadowSlash, moonWalk,
  gatekeeperLight, lightResonance,
  ashPurge, ashTrack,
  artisanCombo, artisanIntuition,
  // 묶음 57 #249: 새 스킬 32
  cleave, lastStand, // 전사
  rapidShot, trapArrow, starfallArrow, // 궁수
  elementBolt, manaShield, elementBurst, grandMagic, manaSense, // 마법사
  aegis, purify, holyLight, miracle, // 사제
  ambush, steal, poisonBlade, smokeBomb, shadowFlurry, lockpick, // 도적
  shieldBash, guard, taunt, lanceCharge, paladinOath, // 기사
  anvilDrop, acidFlask, pollenCloud, dazzleLens, scaleWeight, whistleSignal, // 생산 두 번째 공격
  sproutCare, // 채집가
}

/// 스킬이 어떻게 걸리는지
enum SkillMode {
  /// 쓰면 그 일을 할 때 한 번 (「준비됨」으로 보이고 앱을 꺼도 남음)
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
      {this.mode = SkillMode.next, this.duration, this.attack = false});

  final JobSkill id;
  final String name;
  final SkillPlace place;

  /// 숫자 없는 한 줄 설명
  final String text;

  /// 주 직업 · Lv.1 로 쓸 때 MP
  final int mp;
  final SkillMode mode;
  final Duration? duration;

  /// ① 공격 스킬 (몬스터에게 피해)
  final bool attack;

  bool get isBattle => place == SkillPlace.battle;
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

  /// 스킬 트리: 기본 ①②③④ · 복합·숨은 ①②
  final List<JobSkill> skills;

  List<JobSkill> get openSkills => skills;
}

/// 숙련 스킬 (#197): 큰 숙련도 8가지 × 단계 4개. 익숙한·능숙한·장인은 패시브,
/// 숙련된은 액티브 공격(MP 없이 몇 턴마다)
class MasterySkillInfo {
  const MasterySkillInfo(this.mastery, this.stage, this.name, this.text,
      {this.active = false});

  final Mastery mastery;
  final MasteryStage stage;
  final String name;
  final String text;
  final bool active;

  String get key => '${mastery.name}:${stage.name}';
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

  // ───────────── 스킬 포인트·레벨 (#195·#196, 숨은 값)

  /// Lv.15부터 레벨이 오를 때마다 2점 (Lv.15 = 2점)
  static int pointsFor(int level) =>
      level >= awakenLevel ? 2 * (level - awakenLevel + 1) : 0;
  static const int pointsPerLevel = 2;

  static const int maxSkillLevel = 3;

  /// 공격·전투 스킬은 단계마다 더 세짐 (Lv.2 ×1.25 · Lv.3 ×1.5)
  static double levelPower(int lv) => 1 + 0.25 * (lv - 1).clamp(0, 2);

  /// 생활 스킬은 단계마다 MP 덜 듦 (Lv.2 -15% · Lv.3 -30%)
  static double levelMpCut(int lv) => 1 - 0.15 * (lv - 1).clamp(0, 2);

  /// 트리에서 [s] 를 배우려면 먼저 무엇이 있어야 하는지
  /// 기본: ① → ②·③, ② 또는 ③이 Lv.2 → ④ / 복합·숨은: ① → ②
  static bool canLearn(JobSkill s, int Function(JobSkill) levelOf) {
    final j = jobOf(s);
    final i = info(j).skills.indexOf(s);
    final tree = info(j).skills;
    if (i == 0) return true;
    if (levelOf(tree[0]) <= 0) return false;
    if (i < 3) return true;
    return levelOf(tree[1]) >= 2 || levelOf(tree[2]) >= 2;
  }

  /// 스킬의 직업
  static JobId jobOf(JobSkill s) =>
      jobs.firstWhere((j) => j.skills.contains(s)).id;

  /// 그 직업의 ① 공격 스킬
  static JobSkill firstOf(JobId j) => info(j).skills.first;

  /// 이 스킬을 쓰는 MP (보조 1.5배·올림, 생활 스킬은 단계마다 덜, 장인의 직감이면 절반)
  static const double subSkillCost = 1.5;
  static int skillCost(JobSkill s,
      {bool sub = false, bool half = false, int level = 1}) {
    final i = skill(s);
    var c = i.mp.toDouble();
    if (!i.attack && !i.isBattle) c = (c * levelMpCut(level)).roundToDouble();
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
  static const double blacksmithWear = 0.5; // 튼튼한 손: 내구도가 덜 닳는 확률
  static const double herbalistSight = 0.5; // 채집 자리가 더 멀리서
  static const double alchemistTime = 0.25; // 센 불: 끓는 시간 덜
  static const double warriorLowHp = 0.10; // HP 절반 아래 피해
  static const double explorerPlace = 0.20; // 새 장소 보상
  static const double explorerGauge = 0.10; // 처음 가는 길 열쇠 게이지
  static const int appraiserExtra = 1; // 밝은 눈: 하루 감정 +1
  static const double tamerGrowth = 0.20; // 펫 성장
  static const double tamerBond = 0.5; // 펫 친밀도 더 (확률로 +1)
  static const int merchantQuests = 1; // 발 넓은 상인: 오늘의 의뢰 +1
  static const double weaponsmithPerLevel = 0.015; // 강화 단계마다 피해
  static const double runesmithElement = 0.15;
  static const double jewelerGrade = 10; // 보석 장비 좋은 등급 %p
  static const double jewelerGem = 0.20; // 보석 채집 하나 더
  static const double healerHeal = 0.25;
  static const double hunterSpawns = 0.5; // 사냥감 냄새: 주변 몬스터 더 (마리 수 배율)
  static const double archaeologistRelic = 0.5; // 옛 길: 유물 자리 더
  static const int pilgrimVisits = 3; // 순례의 길: 일주일에 3번 넘게 간 곳
  static const int peddlerSteps = 5000;
  static const double peddlerGold = 0.10;
  static const double adventurerReward = 0.15;
  static const double adventurerDungeon = 0.15;
  static const double beastKnightDamage = 0.08;
  static const double pathfinderFarM = 2000; // 먼 곳의 보물
  static const double pathfinderReward = 0.5; // 이기면 재료 더 (확률)
  static const double potionMerchantGold = 0.30; // 물약 판매(특가 판매와 함께)
  static const double potionWholesale = 0.20; // 물약 도매: 싸게 삼
  static const double nightDamage = 0.10;
  static const double gateHeirGrowth = 0.30;
  static const double gateHeirMp = 0.10;
  static const double ashDamage = 0.10;

  // ───────────── 직업 스킬 수치 (숨은 규칙, Lv.1 기준)
  static const double focusForgeChance = 0.15; // 집중 단조: 성공 확률 더 (%p)
  static const double masterTouchGrade = 25; // 명장의 손길: 좋은 등급 %p
  static const double healingLight = 0.30;
  static const double ashPurge = 3.0;
  static const double bargain = 0.20;
  static const double longRoad = 0.50;
  static const double specialSale = 2.0;
  static const double resonance = 0.30;
  static const double blessedSteps = 1.5;
  static const int runeCarveGold = 100;
  static const int snackBond = 20;
  static const double firstAid = 0.25;
  static const int bigPackSlots = 5;
  static const double drillExp = 0.25;
  static const double runTogether = 1.0; // 함께 달리기: 걸음 펫 경험치 두 배
  static const double coinTossGold = 10;
  static const double farSightRare = 0.05; // 먼 눈: 희귀 수식어 몫 더 (30분)

  // ───────────── 숨은 직업 조건
  static const int nightWalkerSteps = 50000;
  static const int gateHeirDays = 60;

  /// 밤 (오후 7시 ~ 새벽 6시)
  static bool isNight(DateTime t) => HarvestRules.isNight(t); // 묶음 69: 밤은 19~6시 하나로

  /// 잿빛 몬스터인지
  static bool isAsh(MonsterId m) => m.name.startsWith('ash');

  static const List<JobInfo> jobs = [
    JobInfo(JobId.blacksmith, '대장장이', JobKind.basic, [Mastery.smith],
        // 묶음 75 #322: 보스 장비는 대장장이만
        '내가 만들거나 고친 장비가 천천히 닳아요 · 보스 장비를 만들 수 있어요',
        [JobSkill.hotHammer, JobSkill.anvilDrop, JobSkill.focusForge, JobSkill.masterTouch, JobSkill.quickRepair, JobSkill.masterBlade, JobSkill.runeCarve]),
    JobInfo(JobId.herbalist, '채집가', JobKind.basic, [Mastery.harvest],
        '채집 자리가 더 멀리서 보여요',
        [JobSkill.thornVine, JobSkill.pollenCloud, JobSkill.bountyTouch, JobSkill.harvestSense, JobSkill.rootPull, JobSkill.sproutCare]),
    JobInfo(JobId.alchemist, '연금술사', JobKind.basic, [Mastery.alchemy],
        '가마솥이 더 빨리 끓어요',
        [JobSkill.potionThrow, JobSkill.acidFlask, JobSkill.quickBrew, JobSkill.recipeHunch, JobSkill.instantBrew, JobSkill.specialSale]),
    JobInfo(JobId.warrior, '전사', JobKind.basic, [Mastery.combat],
        '강타가 더 세고 더 빨리 차요',
        [JobSkill.rush, JobSkill.cleave, JobSkill.warCry, JobSkill.ironWall, JobSkill.lastStand, JobSkill.drill]),
    JobInfo(JobId.explorer, '탐험가', JobKind.basic, [Mastery.walk],
        '새 장소와 처음 가는 길에서 더 얻어요',
        [JobSkill.galeSlash, JobSkill.pathFind, JobSkill.farSight, JobSkill.windWalk, JobSkill.longRoad]),
    JobInfo(JobId.appraiser, '감정사', JobKind.basic, [Mastery.appraise],
        '하루에 감정을 한 번 더 할 수 있어요',
        [JobSkill.weakStab, JobSkill.dazzleLens, JobSkill.trueEye, JobSkill.wideView, JobSkill.memoryRead, JobSkill.polish]),
    JobInfo(JobId.tamer, '조련사', JobKind.basic, [Mastery.spirit],
        '펫이 빨리 자라고 빨리 친해져요',
        [JobSkill.chargeOrder, JobSkill.whistleSignal, JobSkill.cheer, JobSkill.snackPouch, JobSkill.eggWarm]),
    JobInfo(JobId.merchant, '상인', JobKind.basic, [Mastery.trade],
        '오늘의 의뢰가 하나 더 붙어요',
        [JobSkill.coinToss, JobSkill.scaleWeight, JobSkill.bargain, JobSkill.knack, JobSkill.regular, JobSkill.bigPack]),
    JobInfo(JobId.weaponsmith, '무기 장인', JobKind.complex,
        [Mastery.smith, Mastery.combat], '강화한 무기일수록 더 세게 싸워요',
        [JobSkill.masterSlash]),
    JobInfo(JobId.runesmith, '룬 대장장이', JobKind.complex,
        [Mastery.smith, Mastery.alchemy], '장비를 만들 때 가끔 속성이 붙어요',
        []),
    JobInfo(JobId.jeweler, '보석 세공사', JobKind.complex,
        [Mastery.smith, Mastery.appraise], '보석을 쓰는 장비가 좋은 등급으로 잘 나오고, 보석을 더 캐요',
        [JobSkill.gemShard]),
    JobInfo(JobId.healer, '치유사', JobKind.complex,
        [Mastery.harvest, Mastery.alchemy], '회복 물약이 더 많이 채워 줘요',
        []),
    JobInfo(JobId.hunter, '사냥꾼', JobKind.complex,
        [Mastery.combat, Mastery.harvest], '주변에 사냥감이 더 많이 보여요',
        []),
    JobInfo(JobId.archaeologist, '고고학자', JobKind.complex,
        [Mastery.appraise, Mastery.harvest], '고대 유물 자리를 더 자주 찾아요',
        [JobSkill.relicLight, JobSkill.excavate]),
    JobInfo(JobId.pilgrim, '순례자', JobKind.complex,
        [Mastery.walk, Mastery.appraise], '자주 가는 곳에 다시 가면 작은 선물이 있어요',
        [JobSkill.blessedStrike, JobSkill.blessedSteps]),
    JobInfo(JobId.peddler, '행상인', JobKind.complex,
        [Mastery.trade, Mastery.walk], '많이 걸은 날은 더 비싸게 팔아요',
        [JobSkill.bundleSwing]),
    JobInfo(JobId.adventurer, '모험가', JobKind.complex,
        [Mastery.combat, Mastery.trade], '조합·긴급 의뢰와 던전 보상이 늘어요',
        [JobSkill.counterSlash, JobSkill.negotiate]),
    JobInfo(JobId.beastKnight, '마수 기사', JobKind.complex,
        [Mastery.combat, Mastery.spirit], '펫과 함께 싸우면 더 세져요',
        [JobSkill.jointAttack]),
    JobInfo(JobId.pathfinder, '길잡이', JobKind.complex,
        [Mastery.walk, Mastery.spirit], '먼 곳 원정에서 이기면 더 가져와요',
        []),
    JobInfo(JobId.potionMerchant, '물약 상인', JobKind.complex,
        [Mastery.alchemy, Mastery.trade], '잡화상에서 물약을 싸게 사요',
        [JobSkill.poisonFlask]),
    JobInfo(JobId.nightWalker, '밤의 산책자', JobKind.hidden, [],
        '밤에 만나는 몬스터에게 더 세요', [JobSkill.shadowSlash, JobSkill.moonWalk]),
    JobInfo(JobId.gateHeir, '문지기의 후계자', JobKind.hidden, [],
        '첫 펫이 빨리 자라고 원정 기력을 덜 써요',
        [JobSkill.gatekeeperLight, JobSkill.lightResonance]),
    JobInfo(JobId.ashHunter, '잿빛 사냥꾼', JobKind.hidden, [],
        '잿빛 몬스터에게 더 세요', [JobSkill.ashPurge, JobSkill.ashTrack]),
    JobInfo(JobId.allCrafter, '만물 장인', JobKind.hidden, [],
        '보조 직업의 고유 기술도 온전히 써요',
        [JobSkill.artisanCombo, JobSkill.artisanIntuition]),
    // 묶음 57 #249: 새 전투 직업
    JobInfo(JobId.archer, '궁수', JobKind.basic, [Mastery.combat],
        '주변에 사냥감이 더 많이 보여요',
        [JobSkill.vitalStrike, JobSkill.rapidShot, JobSkill.trapArrow, JobSkill.windBlade, JobSkill.starfallArrow, JobSkill.track]),
    JobInfo(JobId.mage, '마법사', JobKind.basic, [Mastery.combat],
        'MP가 더 많고 걸을 때 더 빨리 차요',
        [JobSkill.elementBolt, JobSkill.manaShield, JobSkill.elementBurst, JobSkill.runeBurst, JobSkill.grandMagic, JobSkill.manaSense]),
    JobInfo(JobId.priest, '사제', JobKind.basic, [Mastery.combat],
        '회복 물약이 더 많이 채워 줘요',
        [JobSkill.healingLight, JobSkill.aegis, JobSkill.purify, JobSkill.holyLight, JobSkill.miracle, JobSkill.firstAid]),
    JobInfo(JobId.rogue, '도적', JobKind.basic, [Mastery.combat],
        '몬스터 공격을 가끔 피해요',
        [JobSkill.ambush, JobSkill.steal, JobSkill.poisonBlade, JobSkill.smokeBomb, JobSkill.shadowFlurry, JobSkill.lockpick]),
    JobInfo(JobId.knight, '기사', JobKind.basic, [Mastery.combat],
        '받는 피해가 조금 줄고 막기가 쉬워요',
        [JobSkill.shieldBash, JobSkill.guard, JobSkill.taunt, JobSkill.lanceCharge, JobSkill.paladinOath, JobSkill.runTogether]),
  ];

  static JobInfo info(JobId id) => jobs[id.index];

  /// 묶음 76 #307: 직업별 주인공 그림 (전투 6직업). 생산 · 히든 직업은 분신 그림과 같은 짝으로
  /// 가까운 전투 직업 그림 (전용 그림이 오면 이 표만 바꾼다). 직업이 없으면 null (맨손 새 주인공)
  static const List<JobId> combatArtJobs = [
    JobId.warrior, JobId.archer, JobId.mage, JobId.priest, JobId.rogue, JobId.knight,
  ];

  static JobId? heroArtJob(JobId? j) => switch (j) {
        null => null,
        JobId.warrior || JobId.blacksmith || JobId.adventurer || JobId.allCrafter ||
        JobId.weaponsmith => JobId.warrior,
        JobId.archer || JobId.herbalist || JobId.explorer || JobId.ashHunter ||
        JobId.hunter || JobId.pathfinder => JobId.archer,
        JobId.mage || JobId.alchemist || JobId.appraiser || JobId.archaeologist ||
        JobId.runesmith || JobId.jeweler || JobId.potionMerchant => JobId.mage,
        JobId.priest || JobId.pilgrim || JobId.healer => JobId.priest,
        JobId.rogue || JobId.merchant || JobId.nightWalker || JobId.peddler => JobId.rogue,
        JobId.knight || JobId.tamer || JobId.gateHeir || JobId.beastKnight => JobId.knight,
      };

  static JobId? parse(String? name) {
    for (final j in JobId.values) {
      if (j.name == name) return j;
    }
    return null;
  }

  static JobSkill? parseSkill(String? name) {
    for (final s in JobSkill.values) {
      if (s.name == name) return s;
    }
    return null;
  }

  static const _b = SkillPlace.battle;
  static const _min30 = Duration(minutes: 30);
  static const _hour = Duration(hours: 1);

  static const List<JobSkillInfo> skills = [
    // 대장장이
    JobSkillInfo(JobSkill.hotHammer, '달군 망치', _b,
        '크게 내리쳐 방어를 깨요. 잠시 더 큰 피해를 받게 돼요', 20,
        mode: SkillMode.battle, attack: true),
    JobSkillInfo(JobSkill.focusForge, '집중 단조', SkillPlace.smithyEnhance,
        '이번 강화가 성공하기 쉬워지고, 실패해도 무사해요', 30),
    JobSkillInfo(JobSkill.masterTouch, '명장의 손길', SkillPlace.smithyCraft,
        '이번 장비가 한 단계 좋은 등급으로 나오기 쉬워요', 40),
    JobSkillInfo(JobSkill.quickRepair, '응급 수리', SkillPlace.smithyWork,
        '장비 하나를 수리비 없이 바로 고쳐요', 20, mode: SkillMode.instant),
    // 채집가
    JobSkillInfo(JobSkill.thornVine, '가시덩굴', _b,
        '두 턴 동안 묶고 조금씩 피해를 줘요', 20,
        mode: SkillMode.battle, attack: true),
    JobSkillInfo(JobSkill.bountyTouch, '풍요의 손길', SkillPlace.harvest,
        '이번 채집이 풍성해져요', 20),
    JobSkillInfo(JobSkill.harvestSense, '채집 감각', SkillPlace.map,
        '30분 동안 완벽하게 캐기 쉬워요', 20,
        mode: SkillMode.timed, duration: _min30),
    JobSkillInfo(JobSkill.rootPull, '뿌리째 캐기', SkillPlace.harvest,
        '이번 채집은 그 자리 남은 횟수를 쓰지 않아요', 30),
    // 연금술사
    JobSkillInfo(JobSkill.potionThrow, '물약 투척', _b,
        '몬스터가 약한 속성의 물약이 터져요', 20,
        mode: SkillMode.battle, attack: true),
    JobSkillInfo(JobSkill.quickBrew, '풍성한 가마솥', SkillPlace.alchemy,
        '이번에 만드는 물약이 하나 더 나와요', 20),
    JobSkillInfo(JobSkill.recipeHunch, '레시피 직감', SkillPlace.alchemy,
        '이번 실험에서 새 레시피를 찾기 쉬워요', 30),
    JobSkillInfo(JobSkill.instantBrew, '즉석 연성', SkillPlace.alchemy,
        '이번 물약은 끓는 시간 없이 바로 완성돼요', 30),
    // 전사
    JobSkillInfo(JobSkill.rush, '돌진', _b, '먼저 달려들어 크게 쳐요', 20,
        mode: SkillMode.battle, attack: true),
    JobSkillInfo(JobSkill.ironWall, '철벽', _b,
        '잠시 받는 피해가 크게 줄고 막기가 넉넉해져요', 20,
        mode: SkillMode.battle),
    JobSkillInfo(JobSkill.warCry, '전투 함성', _b,
        '잠시 공격이 세지고 강타도 더 빨리 차요', 10,
        mode: SkillMode.battle),
    JobSkillInfo(JobSkill.drill, '단련', SkillPlace.map,
        '30분 동안 사냥 경험치와 전투 숙련이 더 쌓여요', 20,
        mode: SkillMode.timed, duration: _min30),
    // 탐험가
    JobSkillInfo(JobSkill.galeSlash, '질풍 베기', _b,
        '빠르게 치고 잠시 몸을 피해요', 10,
        mode: SkillMode.battle, attack: true),
    JobSkillInfo(JobSkill.pathFind, '길 찾기', SkillPlace.map,
        '30분 동안 나에게만 보이는 채집 자리와 보물 상자가 근처에 생겨요', 20,
        mode: SkillMode.timed, duration: _min30),
    JobSkillInfo(JobSkill.farSight, '먼 눈', SkillPlace.map,
        '30분 동안 특별한 몬스터를 찾아내요', 20,
        mode: SkillMode.timed, duration: _min30),
    JobSkillInfo(JobSkill.windWalk, '바람 따라 걷기', SkillPlace.map,
        '30분 동안 주변의 안 가 본 장소가 지도에 보여요', 20,
        mode: SkillMode.timed, duration: _min30),
    // 감정사
    JobSkillInfo(JobSkill.weakStab, '약점 찌르기', _b,
        '몬스터가 약한 곳을 찔러 크게 다치게 해요', 20,
        mode: SkillMode.battle, attack: true),
    JobSkillInfo(JobSkill.trueEye, '진실의 눈', SkillPlace.lens,
        '이번 감정에서 귀한 재료가 꼭 나와요', 30),
    JobSkillInfo(JobSkill.wideView, '넓은 시야', SkillPlace.lens,
        '30분 동안 돋보기가 더 넓게 봐요', 20,
        mode: SkillMode.timed, duration: _min30),
    JobSkillInfo(JobSkill.memoryRead, '기억 읽기', SkillPlace.lens,
        '이번 감정에서 레시피 쪽지가 꼭 나와요', 30),
    // 조련사
    JobSkillInfo(JobSkill.chargeOrder, '돌격 명령', _b,
        '펫이 바로 달려들어 공격하고 펫 게이지가 조금 차요', 10,
        mode: SkillMode.battle, attack: true),
    JobSkillInfo(JobSkill.cheer, '응원', SkillPlace.petExpedition,
        '원정 간 펫이 서둘러 돌아와요', 20, mode: SkillMode.instant),
    JobSkillInfo(JobSkill.snackPouch, '간식 주머니', SkillPlace.anywhere,
        '펫 하나와 크게 친해져요', 20, mode: SkillMode.instant),
    JobSkillInfo(JobSkill.eggWarm, '알 품기', SkillPlace.anywhere,
        '품은 알이 깨어나기까지 남은 시간이 절반이 돼요', 30,
        mode: SkillMode.instant),
    // 상인
    JobSkillInfo(JobSkill.coinToss, '금화 던지기', _b,
        '금화를 던져 크게 맞혀요. 금화가 조금 들어요', 10,
        mode: SkillMode.battle, attack: true),
    JobSkillInfo(JobSkill.bargain, '대흥정', SkillPlace.shop,
        '이번 거래 하나를 싸게 사거나 비싸게 팔아요', 20),
    JobSkillInfo(JobSkill.knack, '수완', SkillPlace.board,
        '이번 의뢰 하나의 금화 보상이 두 배가 돼요', 20),
    JobSkillInfo(JobSkill.regular, '단골 손님', SkillPlace.shop,
        '하루 개수가 정해진 물건을 오늘 하나 더 살 수 있어요', 30),
    // 복합
    JobSkillInfo(JobSkill.masterSlash, '명검 베기', _b,
        '무기로 크게 베어요. 강화한 무기일수록 더 세요', 20,
        mode: SkillMode.battle, attack: true),
    JobSkillInfo(JobSkill.masterBlade, '명검 벼리기', SkillPlace.smithyCraft,
        '이번 무기에 추가 능력치가 하나 더 붙어요', 30),
    JobSkillInfo(JobSkill.runeBurst, '룬 폭발', _b,
        '장비의 속성으로 크게 터뜨려요', 30,
        mode: SkillMode.battle, attack: true),
    JobSkillInfo(JobSkill.runeCarve, '룬 새기기', SkillPlace.smithyWork,
        '코어 없이 금화로 장비에 원하는 속성을 새겨요', 40,
        mode: SkillMode.instant),
    JobSkillInfo(JobSkill.gemShard, '보석 파편', _b,
        '보석 조각을 날려 다치게 하고 가끔 멈춰 세워요', 20,
        mode: SkillMode.battle, attack: true),
    JobSkillInfo(JobSkill.polish, '광택 내기', SkillPlace.smithyWork,
        '장신구 능력치를 다시 굴리고, 이전 것과 새것 중 골라요', 30,
        mode: SkillMode.instant),
    JobSkillInfo(JobSkill.healingLight, '치유의 빛', _b,
        '빛으로 다치게 하고 그만큼 내 HP를 채워요', 20,
        mode: SkillMode.battle, attack: true),
    JobSkillInfo(JobSkill.firstAid, '응급 처치', SkillPlace.map,
        '그 자리에서 HP를 조금 채워요', 20, mode: SkillMode.instant),
    JobSkillInfo(JobSkill.vitalStrike, '조준 사격', _b, '꼭 급소를 맞혀요', 10,
        mode: SkillMode.battle, attack: true),
    JobSkillInfo(JobSkill.track, '추적', SkillPlace.map,
        '도감에서 만난 몬스터 하나가 잠시 뒤 근처에 나타나요', 20,
        mode: SkillMode.instant),
    JobSkillInfo(JobSkill.relicLight, '고대 유물의 빛', _b,
        '다치게 하고 다음 강한 공격을 막아 줘요', 20,
        mode: SkillMode.battle, attack: true),
    JobSkillInfo(JobSkill.excavate, '발굴', SkillPlace.relic,
        '이번 고대 유물에서 귀한 재료가 꼭 나와요', 30),
    JobSkillInfo(JobSkill.blessedStrike, '축복의 일격', _b,
        '다치게 하고 몇 턴 동안 HP가 조금씩 차요', 20,
        mode: SkillMode.battle, attack: true),
    JobSkillInfo(JobSkill.blessedSteps, '축복의 발걸음', SkillPlace.map,
        '30분 동안 걸음 게이지가 빨리 차요', 20,
        mode: SkillMode.timed, duration: _min30),
    JobSkillInfo(JobSkill.bundleSwing, '짐 보따리 휘두르기', _b,
        '보따리로 후려쳐 가끔 놀라 멈추게 해요', 10,
        mode: SkillMode.battle, attack: true),
    JobSkillInfo(JobSkill.bigPack, '큰 짐 보따리', SkillPlace.anywhere,
        '오늘 하루 가방 칸이 늘어나요', 20, mode: SkillMode.instant),
    JobSkillInfo(JobSkill.counterSlash, '반격 베기', _b,
        '바로 치고, 다음에 받는 공격 일부를 돌려줘요', 20,
        mode: SkillMode.battle, attack: true),
    JobSkillInfo(JobSkill.negotiate, '의뢰 협상', SkillPlace.board,
        '조합 의뢰 하나를 다른 의뢰로 바꿔요', 10, mode: SkillMode.instant),
    JobSkillInfo(JobSkill.jointAttack, '합동 돌격', _b,
        '나와 펫이 함께 공격하고 펫 게이지가 조금 차요', 20,
        mode: SkillMode.battle, attack: true),
    JobSkillInfo(JobSkill.runTogether, '함께 달리기', SkillPlace.map,
        '30분 동안 동행 펫과 걸으면 펫이 더 자라고 더 친해져요', 20,
        mode: SkillMode.timed, duration: _min30),
    JobSkillInfo(JobSkill.windBlade, '바람 화살', _b,
        '바람을 실어 쏘고 잠시 더 빨라져요', 20,
        mode: SkillMode.battle, attack: true),
    JobSkillInfo(JobSkill.longRoad, '먼 길 안내', SkillPlace.expeditionSend,
        '이번 원정을 더 멀리 보낼 수 있어요', 20),
    JobSkillInfo(JobSkill.poisonFlask, '독 물약 뿌리기', _b,
        '독을 뿌려 몇 턴 동안 계속 다치게 해요', 10,
        mode: SkillMode.battle, attack: true),
    JobSkillInfo(JobSkill.specialSale, '특가 판매', SkillPlace.shop,
        '이번 물약 판매 값이 크게 올라요', 20),
    // 숨은
    JobSkillInfo(JobSkill.shadowSlash, '그림자 베기', _b,
        '그림자로 베고 한 턴 몸을 숨겨요. 밤에는 더 세요', 20,
        mode: SkillMode.battle, attack: true),
    JobSkillInfo(JobSkill.moonWalk, '달빛 걸음', SkillPlace.nightMap,
        '1시간 동안 주변에 밤 몬스터가 더 나타나요', 20,
        mode: SkillMode.timed, duration: _hour),
    JobSkillInfo(JobSkill.gatekeeperLight, '문지기의 빛', _b,
        '빛의 막으로 나를 지키고, 잿빛 몬스터를 크게 다치게 해요', 30,
        mode: SkillMode.battle, attack: true),
    JobSkillInfo(JobSkill.lightResonance, '빛의 공명', SkillPlace.anywhere,
        '펫의 기력을 채워 줘요', 30, mode: SkillMode.instant),
    JobSkillInfo(JobSkill.ashPurge, '잿빛 정화', _b,
        '잿빛 몬스터의 보호를 깨고 크게 다치게 해요', 30,
        mode: SkillMode.battle, attack: true),
    JobSkillInfo(JobSkill.ashTrack, '잿빛 추적', SkillPlace.map,
        '1시간 동안 주변에 잿빛 몬스터가 더 나타나요', 20,
        mode: SkillMode.timed, duration: _hour),
    JobSkillInfo(JobSkill.artisanCombo, '장인의 연타', _b,
        '내 직업 수만큼 여러 번 쳐요', 20,
        mode: SkillMode.battle, attack: true),
    JobSkillInfo(JobSkill.artisanIntuition, '장인의 직감', SkillPlace.anywhere,
        '다음에 쓰는 스킬 MP가 줄어요', 10),
    // ───── 묶음 57 #249: 새 스킬 32
    JobSkillInfo(JobSkill.cleave, '내려베기', _b, '온 힘으로 내려베어 크게 다치게 해요', 20,
        mode: SkillMode.battle, attack: true),
    JobSkillInfo(JobSkill.lastStand, '결사의 일격', _b, 'HP가 낮을수록 아주 세게 쳐요', 30,
        mode: SkillMode.battle, attack: true),
    JobSkillInfo(JobSkill.rapidShot, '속사', _b, '빠르게 두 번 쏴요', 20,
        mode: SkillMode.battle, attack: true),
    JobSkillInfo(JobSkill.trapArrow, '덫 화살', _b, '맞히고 몬스터를 한 턴 멈춰 세워요', 20,
        mode: SkillMode.battle, attack: true),
    JobSkillInfo(JobSkill.starfallArrow, '별똥별 화살', _b, '다치지 않은 몬스터에게 아주 큰 피해를 줘요', 30,
        mode: SkillMode.battle, attack: true),
    JobSkillInfo(JobSkill.elementBolt, '속성 화살', _b, '몬스터가 약한 속성으로 쏴요', 20,
        mode: SkillMode.battle, attack: true),
    JobSkillInfo(JobSkill.manaShield, '마력 보호막', _b, '다음 공격 한 번을 막아요', 20,
        mode: SkillMode.battle),
    JobSkillInfo(JobSkill.elementBurst, '속성 폭발', _b, '몬스터가 그 속성에 약하면 크게 터져요', 30,
        mode: SkillMode.battle, attack: true),
    JobSkillInfo(JobSkill.grandMagic, '대마법', _b, '큰 속성 마법을 터뜨려요', 40,
        mode: SkillMode.battle, attack: true),
    JobSkillInfo(JobSkill.manaSense, '마력 감지', SkillPlace.map,
        '30분 동안 속성을 띤 몬스터와 귀한 재료 자리가 지도에 눈에 띄어요', 20,
        mode: SkillMode.timed, duration: _min30),
    JobSkillInfo(JobSkill.aegis, '가호', _b, '잠시 받는 피해가 줄어요', 20, mode: SkillMode.battle),
    JobSkillInfo(JobSkill.purify, '정화', _b, '나쁜 효과를 지우고 HP를 조금 채워요', 20,
        mode: SkillMode.battle),
    JobSkillInfo(JobSkill.holyLight, '성스러운 빛', _b, '빛으로 다치게 하고, 잿빛 몬스터에게는 더 세요', 30,
        mode: SkillMode.battle, attack: true),
    JobSkillInfo(JobSkill.miracle, '기적', _b, 'HP를 크게 채우고, 이번 싸움에서 쓰러져도 한 번 버텨요', 40,
        mode: SkillMode.battle),
    JobSkillInfo(JobSkill.ambush, '기습', _b, '연달아 두 번 찔러요', 20,
        mode: SkillMode.battle, attack: true),
    JobSkillInfo(JobSkill.steal, '훔치기', _b, '찌르고, 이기면 전리품이 하나 더 나와요', 20,
        mode: SkillMode.battle, attack: true),
    JobSkillInfo(JobSkill.poisonBlade, '독 바르기', _b, '독 묻은 칼로 베어 몇 턴 동안 계속 다치게 해요', 20,
        mode: SkillMode.battle, attack: true),
    JobSkillInfo(JobSkill.smokeBomb, '연막', _b, '몬스터의 다음 공격이 빗나가요', 10, mode: SkillMode.battle),
    JobSkillInfo(JobSkill.shadowFlurry, '그림자 연격', _b, '빠르게 다섯 번 베어요', 40,
        mode: SkillMode.battle, attack: true),
    JobSkillInfo(JobSkill.lockpick, '자물쇠 따기', SkillPlace.anywhere,
        '다음에 여는 보물 상자나 던전 상자에서 하나 더 나와요', 20),
    JobSkillInfo(JobSkill.shieldBash, '방패 치기', _b, '방패로 쳐서 다치게 하고 몬스터를 잠시 약하게 해요', 20,
        mode: SkillMode.battle, attack: true),
    JobSkillInfo(JobSkill.guard, '수호', _b, '다음 강한 공격을 막고 되받아쳐요', 20, mode: SkillMode.battle),
    JobSkillInfo(JobSkill.taunt, '도발', _b, '잠시 맞을 때마다 되받아쳐요', 20, mode: SkillMode.battle),
    JobSkillInfo(JobSkill.lanceCharge, '창 돌격', _b, '창을 앞세워 돌격해 크게 찌르고 먼저 움직여요', 30,
        mode: SkillMode.battle, attack: true),
    JobSkillInfo(JobSkill.paladinOath, '성기사의 맹세', _b, '빛의 막을 두르고 잠시 맞을 때마다 되받아쳐요', 40,
        mode: SkillMode.battle),
    JobSkillInfo(JobSkill.anvilDrop, '모루 내려찍기', _b, '모루로 내려찍어 크게 다치게 하고 가끔 멈춰 세워요', 20,
        mode: SkillMode.battle, attack: true),
    JobSkillInfo(JobSkill.acidFlask, '산성 플라스크', _b, '방어를 녹이고 몇 턴 동안 계속 다치게 해요', 20,
        mode: SkillMode.battle, attack: true),
    JobSkillInfo(JobSkill.pollenCloud, '꽃가루 날리기', _b, '다치게 하고 몬스터의 다음 공격이 잘 빗나가게 해요', 20,
        mode: SkillMode.battle, attack: true),
    JobSkillInfo(JobSkill.dazzleLens, '눈부신 렌즈', _b, '돋보기로 빛을 모아 쏴 다치게 하고 한 턴 멈춰 세워요', 20,
        mode: SkillMode.battle, attack: true),
    JobSkillInfo(JobSkill.scaleWeight, '저울추 던지기', _b, '저울추로 크게 맞히고, 이기면 금화가 조금 더 나와요', 20,
        mode: SkillMode.battle, attack: true),
    JobSkillInfo(JobSkill.whistleSignal, '휘파람 신호', _b, '펫이 두 번 연달아 공격하고 펫 게이지가 조금 차요', 20,
        mode: SkillMode.battle, attack: true),
    JobSkillInfo(JobSkill.sproutCare, '새싹 돌보기', SkillPlace.anywhere,
        '오늘 약초밭이 조금 빨리 자라요', 20, mode: SkillMode.instant),
  ];

  static final Map<JobSkill, JobSkillInfo> _skillById = {
    for (final s in skills) s.id: s,
  };
  static JobSkillInfo skill(JobSkill s) => _skillById[s]!;

  /// 묶음 30 에서 빠진 스킬 (예전 저장 키 → 같은 자리 새 스킬. 없으면 null)
  static JobSkill? legacySkill(String name) => switch (name) {
        'powerStrike' => JobSkill.warCry, // 힘의 일격 → 전투 함성
        'wanderingMarket' => JobSkill.bigPack, // 떠돌이 장터 → 큰 짐 보따리
        _ => parseSkill(name),
      };

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

  /// 길드 「곧 열릴 것 같은 직업」 (#192): 아직 없는 기본·복합 직업 중 조건에
  /// 가장 가까운 것 2~3개. [value] 는 큰 숙련도 값 (화면엔 숫자 없음)
  static List<JobId> nearJobs(double Function(Mastery) value,
      Set<JobId> owned) {
    double need(JobInfo j) {
      final goal = j.kind == JobKind.basic
          ? MasteryRules.bigSteps[MasteryStage.skilled.index]
          : MasteryRules.bigSteps[MasteryStage.expert.index];
      var left = 0.0;
      for (final m in j.masteries) {
        left += (goal - value(m)).clamp(0, goal) / goal;
      }
      return left / j.masteries.length;
    }

    final list = [
      for (final j in jobs)
        if (j.kind != JobKind.hidden && !owned.contains(j.id)) j,
    ]..sort((a, b) => need(a).compareTo(need(b)));
    return [for (final j in list.take(3)) j.id];
  }

  /// 힌트 문구: 「대장일과 전투를 더 해 보세요」
  static String hintLine(JobId j) {
    final ms = info(j).masteries.map((m) => m.label).toList();
    if (ms.length == 1) return '${josaOf(ms.first, '을/를')} 더 해 보세요';
    return '${josaOf(ms.first, '와/과')} ${josaOf(ms.last, '을/를')} 더 해 보세요';
  }

  /// 묶음 54: 조합 ★2 → 더 자세한 힌트 (숙련도마다 얼마나 왔는지, 숫자 없이)
  /// 「대장일은 거의 다 왔어요 · 전투는 아직 갈 길이 멀어요」
  static String detailLine(JobId j, double Function(Mastery) value) {
    final ji = info(j);
    final goal = ji.kind == JobKind.basic
        ? MasteryRules.bigSteps[MasteryStage.skilled.index]
        : MasteryRules.bigSteps[MasteryStage.expert.index];
    String how(Mastery m) {
      final left = (goal - value(m)).clamp(0, goal) / goal;
      return left <= 0
          ? '충분해요'
          : left < 0.25
              ? '거의 다 왔어요'
              : left < 0.6
                  ? '절반쯤 왔어요'
                  : '아직 갈 길이 멀어요';
    }

    return [for (final m in ji.masteries) '${josaOf(m.label, '은/는')} ${how(m)}']
        .join(' · ');
  }

  /// 큰 숙련도의 기본 직업
  static JobId basicOf(Mastery m) =>
      jobs.firstWhere((j) => j.kind == JobKind.basic && j.masteries.single == m).id;

  /// 첫 펫 한마디
  static const String awakenLine = '이제 너만의 길을 찾을 때야. 조합에 가 보자!';
  static String newJobLine(String job) => '새 길이 열렸어! $job, 조합에서 확인해 봐.';

  // ───────────── 숙련 스킬 (#197)

  /// 액티브 숙련 스킬이 차는 턴 (강타처럼, MP 없음)
  static const int masteryActiveTicks = 7;

  static const List<MasterySkillInfo> masterySkills = [
    // 대장일
    MasterySkillInfo(Mastery.smith, MasteryStage.familiar, '손에 익은 망치', '장비를 만들 때 좋은 등급이 조금 더 잘 나와요'),
    MasterySkillInfo(Mastery.smith, MasteryStage.skilled, '고른 담금질', '장비가 좋은 등급으로 더 잘 나오고 수리비가 덜 들어요'),
    MasterySkillInfo(Mastery.smith, MasteryStage.expert, '망치 내려치기', '묵직하게 내려쳐 크게 다치게 해요', active: true),
    MasterySkillInfo(Mastery.smith, MasteryStage.master, '장인의 손', '장비가 아주 좋은 등급으로 잘 나오고 수리비가 많이 덜 들어요'),
    // 채집
    MasterySkillInfo(Mastery.harvest, MasteryStage.familiar, '눈썰미', '채집할 때 가끔 하나 더 나와요'),
    MasterySkillInfo(Mastery.harvest, MasteryStage.skilled, '가벼운 손', '하나 더 나오기 쉽고 도구가 가끔 닳지 않아요'),
    MasterySkillInfo(Mastery.harvest, MasteryStage.expert, '덩굴 채찍', '덩굴로 때려 잠시 묶어 둬요', active: true),
    MasterySkillInfo(Mastery.harvest, MasteryStage.master, '숲의 손', '채집이 늘 넉넉하고 도구가 잘 닳지 않아요'),
    // 연금술
    MasterySkillInfo(Mastery.alchemy, MasteryStage.familiar, '약초 다루기', '물약이 가끔 하나 더 나와요'),
    MasterySkillInfo(Mastery.alchemy, MasteryStage.skilled, '고른 불', '물약이 더 잘 나오고 재료를 가끔 아껴요'),
    MasterySkillInfo(Mastery.alchemy, MasteryStage.expert, '불꽃 플라스크', '불꽃 병을 던져 태워요', active: true),
    MasterySkillInfo(Mastery.alchemy, MasteryStage.master, '연금술의 경지', '물약이 넉넉히 나오고 재료를 자주 아껴요'),
    // 전투
    MasterySkillInfo(Mastery.combat, MasteryStage.familiar, '몸에 밴 자세', '익숙한 무기와 몬스터에게 조금 더 세요'),
    MasterySkillInfo(Mastery.combat, MasteryStage.skilled, '매서운 손', '익숙한 상대에게 더 세고 재료를 가끔 더 얻어요'),
    MasterySkillInfo(Mastery.combat, MasteryStage.expert, '연속 베기', '여러 번 빠르게 베어요', active: true),
    MasterySkillInfo(Mastery.combat, MasteryStage.master, '역전의 용사', '익숙한 상대에게 아주 세고 재료를 자주 더 얻어요'),
    // 걷기·탐험
    MasterySkillInfo(Mastery.walk, MasteryStage.familiar, '가벼운 발', '걸음 게이지와 새 장소 보상이 조금 늘어요'),
    MasterySkillInfo(Mastery.walk, MasteryStage.skilled, '먼 길의 발', '걸음 게이지와 새 장소 보상이 더 늘어요'),
    MasterySkillInfo(Mastery.walk, MasteryStage.expert, '도약 차기', '뛰어올라 차고 먼저 움직여요', active: true),
    MasterySkillInfo(Mastery.walk, MasteryStage.master, '방랑자의 발걸음', '걸음 게이지와 새 장소 보상이 많이 늘어요'),
    // 감정
    MasterySkillInfo(Mastery.appraise, MasteryStage.familiar, '살피는 눈', '감정에서 재료·쪽지가 조금 더 잘 나와요'),
    MasterySkillInfo(Mastery.appraise, MasteryStage.skilled, '꿰뚫는 눈', '감정에서 재료·쪽지가 더 잘 나와요'),
    MasterySkillInfo(Mastery.appraise, MasteryStage.expert, '꿰뚫는 일격', '약점을 찔러 다치게 해요', active: true),
    MasterySkillInfo(Mastery.appraise, MasteryStage.master, '진실을 보는 눈', '감정에서 재료·쪽지가 아주 잘 나와요'),
    // 정령술
    MasterySkillInfo(Mastery.spirit, MasteryStage.familiar, '호흡 맞추기', '원정 기력과 시간이 조금 덜 들어요'),
    MasterySkillInfo(Mastery.spirit, MasteryStage.skilled, '통하는 마음', '원정 기력과 시간이 더 덜 들어요'),
    MasterySkillInfo(Mastery.spirit, MasteryStage.expert, '빛 구슬', '빛 구슬을 날려 다치게 해요', active: true),
    MasterySkillInfo(Mastery.spirit, MasteryStage.master, '하나 된 마음', '원정 기력과 시간이 많이 덜 들어요'),
    // 장사·의뢰
    MasterySkillInfo(Mastery.trade, MasteryStage.familiar, '셈이 빠른', '팔 때 금화와 의뢰 금화가 조금 늘어요'),
    MasterySkillInfo(Mastery.trade, MasteryStage.skilled, '단골 만들기', '팔 때 금화와 의뢰 금화가 더 늘어요'),
    MasterySkillInfo(Mastery.trade, MasteryStage.expert, '동전 튕기기', '동전을 튕겨 맞혀요. 금화가 조금 들어요', active: true),
    MasterySkillInfo(Mastery.trade, MasteryStage.master, '이름난 상인', '팔 때 금화와 의뢰 금화가 많이 늘어요'),
  ];

  static MasterySkillInfo masterySkill(Mastery m, MasteryStage s) =>
      masterySkills.firstWhere((x) => x.mastery == m && x.stage == s);

  static MasterySkillInfo masteryActive(Mastery m) =>
      masterySkill(m, MasteryStage.expert);

  static MasterySkillInfo? masterySkillByKey(String key) {
    for (final x in masterySkills) {
      if (x.key == key) return x;
    }
    return null;
  }

  /// 지금 단계에서 가진 숙련 스킬: 가장 높은 패시브 하나(앞 단계는 새 것으로 바뀜) +
  /// 숙련된 이상이면 액티브
  static List<MasterySkillInfo> masterySkillsAt(Mastery m, MasteryStage st) {
    if (st == MasteryStage.clumsy) return const [];
    final passive = st == MasteryStage.expert ? MasteryStage.skilled : st;
    return [
      masterySkill(m, passive),
      if (st.index >= MasteryStage.expert.index) masteryActive(m),
    ];
  }
}

/// 조사 붙이기 (규칙 파일에서 쓰는 작은 도움)
String josaOf(String word, String pair) {
  final parts = pair.split('/');
  final swap = pair == '와/과';
  final withB = swap ? parts[1] : parts[0];
  final without = swap ? parts[0] : parts[1];
  final c = word.runes.last;
  final b = (c >= 0xAC00 && c <= 0xD7A3) ? (c - 0xAC00) % 28 : 0;
  return '$word${b == 0 ? without : withB}';
}
