import 'dart:math' as math;

import 'element_rules.dart';
import 'materials.dart';
import 'modifier_rules.dart';

/// 펫 등급: 일반 · 희귀(묶음 33 #185) · 영웅(묶음 49 #235)
enum PetGrade { common, rare, hero, legend }

/// 펫 종류. 이름은 저장 키라 바꾸지 않는다.
/// 희귀(아기 그리핀·다이어울프·드레이크·켈피·미믹·골렘), 전설(아기 페가수스·유니콘·
/// 키메라·바실리스크·드래곤·피닉스)은 나중에 여기에 더한다.
enum PetSpecies {
  crow,
  blackCat,
  toad,
  owl,
  lizard,
  homunculus,
  // 묶음 33 #185 희귀 펫
  griffin,
  direwolf,
  drake,
  kelpie,
  mimic,
  golem,
  // 묶음 49 #235 영웅 펫 (바람 · 모스 · 녹턴 · 무 · 엠버 · 여명)
  wolf,
  turtle,
  panther,
  whale,
  phoenix,
  stag,
  // 묶음 57 #244 전설 펫 (아스트라 · 고르 · 셰이드 · 마레 · 이그니스 · 루체)
  pegasus,
  behemoth,
  nightmare,
  leviathan,
  dragon,
  unicorn,
}

/// 펫의 던전 스킬 종류
enum PetSkill {
  peck,
  scratch,
  tongue,
  insight,
  ember,
  shield,
  // 묶음 33 #185 희귀 펫
  thunderClaw,
  frostBite,
  flameBreath,
  tideWrap,
  ambush,
  stoneWall,
  // 묶음 49 #235 영웅 펫
  galeFang,
  mossShell,
  shadowPounce,
  tidalSong,
  rebirthFlame,
  dawnHalo,
  // 묶음 57 #244 전설 펫
  starWing,
  quake,
  nightTerror,
  abyssTide,
  dragonFire,
  holyHorn,
}

class PetSpeciesInfo {
  const PetSpeciesInfo({
    required this.id,
    required this.name,
    required this.grade,
    required this.special,
    required this.specialAdult,
    required this.skill,
    required this.skillName,
    required this.skillText,
    required this.skillTextAdult,
    required this.favorite,
    this.element,
    this.walk,
  });

  /// 영웅 펫: 동행 중 걸을 때 함께하는 효과 (문장만, 묶음 49 #235)
  final String? walk;

  /// 기본 속성 (11-11 #63, 호문쿨루스는 무속성 null)
  final Element? element;

  final PetSpecies id;
  final String name;
  final PetGrade grade;

  /// 원정 특기 설명 (아기 / 성체)
  final String special;
  final String specialAdult;

  final PetSkill skill;
  final String skillName;
  final String skillText;
  final String skillTextAdult;

  /// 좋아하는 재료 (돌려보낼 때 남긴다)
  final MaterialId favorite;

  /// 묶음 70 #294: 하늘을 나는 펫 (원정은 곧장 직선, 길·물·막힌 곳을 따지지 않음)
  bool get flies => PetRules.flyers.contains(id);

  /// [awake]: 영웅 펫이 단짝(친밀도 100)이 되면 「각성 모습」 (묶음 49 #235)
  String asset({required bool adult, bool awake = false}) =>
      'assets/images/pet_${id.name}_${awake ? 'awake' : adult ? 'adult' : 'baby'}.webp';
}

/// 묶음 75 #334: 알 등급 (얻는 순간 정함)
enum EggGrade {
  common('알', 'pet_egg', 150),
  rare('희귀한 알', 'pet_egg_rare', 500),
  hero('영웅의 알', 'pet_egg_hero', 1500),
  legend('전설의 알', 'pet_egg_legend', 4000);

  const EggGrade(this.label, this.image, this.price);

  /// 이름 (정령이 떠나기 전 알은 「신비한 알」)
  final String label;

  /// 그림 (희귀 · 영웅 · 전설 그림이 오기 전엔 pet_egg)
  final String image;

  /// 잡화상에 팔 때 금화 (숨은 값)
  final int price;

  String get asset => 'assets/images/$image.webp';

  /// 우편 · 「가방이 가득 찼어요」 창의 키 ('egg' · 'egg:rare' …)
  String get key => this == common ? 'egg' : 'egg:$name';

  static EggGrade? ofKey(String k) {
    if (k == 'egg') return common;
    if (!k.startsWith('egg:')) return null;
    return values.asNameMap()[k.substring(4)];
  }
}

/// 펫 규칙 (11-11 제안서 3 확정 값)
class PetRules {
  PetRules._();

  static const int maxPets = 6;

  /// 묶음 70 #294: 하늘을 나는 펫
  static const Set<PetSpecies> flyers = {
    PetSpecies.crow,
    PetSpecies.owl,
    PetSpecies.griffin,
    PetSpecies.drake,
    PetSpecies.phoenix,
    PetSpecies.pegasus,
    PetSpecies.dragon,
  };
  static const int maxLevel = 20;

  /// 묶음 72 더하기: 전투 무대용 그림이 따로 있는 펫 (성체 · 각성일 때, 오른쪽을 봄)
  static const Set<PetSpecies> battleArt = {
    PetSpecies.golem,
    PetSpecies.mimic,
    PetSpecies.owl,
    PetSpecies.toad,
    PetSpecies.homunculus,
  };

  /// 묶음 72 더하기: 성체(· 각성) 그림이 왼쪽을 보는 펫 — 전투에서는 좌우를 뒤집어 몬스터 쪽을 보게
  static const Set<PetSpecies> facesLeft = {
    PetSpecies.blackCat,
    PetSpecies.crow,
    PetSpecies.direwolf,
    PetSpecies.dragon,
    PetSpecies.drake,
    PetSpecies.kelpie,
    PetSpecies.leviathan,
    PetSpecies.lizard,
    PetSpecies.nightmare,
    PetSpecies.pegasus,
    PetSpecies.phoenix,
    PetSpecies.stag,
    PetSpecies.unicorn,
    PetSpecies.whale,
    PetSpecies.wolf,
  };

  /// 전투 무대에 쓰는 그림 (아기는 그대로)
  static String battleAsset(PetSpecies s, {required bool adult, bool awake = false}) =>
      (adult || awake) && battleArt.contains(s)
          ? 'assets/images/pet_${s.name}_battle.webp'
          : info(s).asset(adult: adult, awake: awake);

  /// 전투 무대에서 좌우를 뒤집는지 (그림마다 보는 방향 표)
  static bool flipInBattle(PetSpecies s, {required bool adult, bool awake = false}) =>
      (adult || awake) && !battleArt.contains(s) && facesLeft.contains(s);

  /// 아기 → 성체
  static const int adultLevel = 10;

  /// 정령과 이별하는 레벨
  static const int farewellLevel = 11;

  /// 빛 조각에서 태어나는 첫 펫 (묶음 29 #182): 숨은 주 속성에 맞춰.
  /// 바람 까마귀 · 어둠 검은 고양이 · 독 두꺼비 · 빛 부엉이 · 불 꼬마 도마뱀,
  /// 그 밖이거나 아직 없으면 호문쿨루스
  /// 묶음 32 #189: ① 연금술이 큰 숙련도 1등이면 호문쿨루스 ② 아니면 펫이 있는 5속성
  /// (바람·어둠·독·빛·불) 중 가장 높은 점수(30점이 안 돼도) ③ 다섯 모두 0이면 호문쿨루스
  static PetSpecies firstPetFrom(Map<Element, double> scores,
      {bool alchemyTop = false}) {
    if (alchemyTop) return PetSpecies.homunculus;
    Element? best;
    var v = 0.0;
    for (final e in const [
      Element.wind,
      Element.dark,
      Element.poison,
      Element.light,
      Element.fire,
    ]) {
      final x = scores[e] ?? 0;
      if (x > v) {
        v = x;
        best = e;
      }
    }
    return firstPetFor(best);
  }

  static PetSpecies firstPetFor(Element? e) => switch (e) {
        Element.wind => PetSpecies.crow,
        Element.dark => PetSpecies.blackCat,
        Element.poison => PetSpecies.toad,
        Element.light => PetSpecies.owl,
        Element.fire => PetSpecies.lizard,
        _ => PetSpecies.homunculus,
      };

  // ───────────────────────── 알

  /// Lv.11 전 필드 사냥에서 이길 때마다 (한 번만)
  static const double firstEggChance = 0.04;

  /// Lv.11 이후 필드 사냥 (수식어 등급별)
  static double fieldEggChance(ModGrade grade) => switch (grade) {
        // 묶음 32 #186: 보통 몬스터 1% → 2%
        ModGrade.none || ModGrade.common => 0.02,
        ModGrade.rare => 0.05,
        ModGrade.legend => 0.20,
      };

  /// 던전 보스를 쓰러뜨렸을 때
  static const double dungeonEggChance = 0.10; // 묶음 32 #186: 5% → 10%

  /// 주간 의뢰를 모두 끝낸 주: 2주에 한 번 알
  static const int boardEggEveryWeeks = 2;

  /// 품은 뒤 저절로 부화하기까지
  static const Duration hatchTime = Duration(hours: 12);

  /// 묶음 35 지침: 원정에서 진 펫이 쉬는 시간 (그냥 두면 1시간, 쉼터에 두면 그때부터 15분)
  static const Duration tiredFor = Duration(hours: 1);
  static const Duration shelterRest = Duration(minutes: 15);

  /// 바로 부화: 남은 시간 1시간마다 (올림)
  static const int hatchManaPerHour = 2;
  static const int hatchGoldPerHour = 20;

  static int hoursLeft(DateTime startedAt, DateTime now) {
    final left = startedAt.add(hatchTime).difference(now);
    if (left <= Duration.zero) return 0;
    return (left.inSeconds / 3600).ceil();
  }

  static int hatchManaCost(DateTime startedAt, DateTime now) =>
      hoursLeft(startedAt, now) * hatchManaPerHour;
  static int hatchGoldCost(DateTime startedAt, DateTime now) =>
      hoursLeft(startedAt, now) * hatchGoldPerHour;

  /// 부화할 때 희귀 펫이 나올 확률 (묶음 33 #185, 숨은 값)
  static const double rareChance = 0.10;

  static const List<PetSpecies> commonSpecies = [
    PetSpecies.crow,
    PetSpecies.blackCat,
    PetSpecies.toad,
    PetSpecies.owl,
    PetSpecies.lizard,
    PetSpecies.homunculus,
  ];

  static const List<PetSpecies> rareSpecies = [
    PetSpecies.griffin,
    PetSpecies.direwolf,
    PetSpecies.drake,
    PetSpecies.kelpie,
    PetSpecies.mimic,
    PetSpecies.golem,
  ];

  static bool isRare(PetSpecies s) => info(s).grade == PetGrade.rare;

  // ───────────────────────── 영웅 펫 (묶음 49 #235, 숨은 값)

  static const List<PetSpecies> heroSpecies = [
    PetSpecies.wolf,
    PetSpecies.turtle,
    PetSpecies.panther,
    PetSpecies.whale,
    PetSpecies.phoenix,
    PetSpecies.stag,
  ];

  static bool isHero(PetSpecies s) => info(s).grade == PetGrade.hero;

  // ───────────────────────── 전설 펫 (묶음 57 #244, 숨은 값)

  static const List<PetSpecies> legendSpecies = [
    PetSpecies.pegasus,
    PetSpecies.behemoth,
    PetSpecies.nightmare,
    PetSpecies.leviathan,
    PetSpecies.dragon,
    PetSpecies.unicorn,
  ];

  static bool isLegend(PetSpecies s) => info(s).grade == PetGrade.legend;

  /// 3막(Lv.21)부터. 처음 0.3%, 안 나올 때마다 +0.1%p (최대 3%), 나오면 처음으로
  static const int legendLevel = 21;
  static const double legendBase = 0.003;
  static const double legendStep = 0.001;
  static const double legendMax = 0.03;
  static double legendChance(int misses) => math.min(legendMax, legendBase + legendStep * misses);

  static String legendName(PetSpecies s) => switch (s) {
        PetSpecies.pegasus => '아스트라',
        PetSpecies.behemoth => '고르',
        PetSpecies.nightmare => '셰이드',
        PetSpecies.leviathan => '마레',
        PetSpecies.dragon => '이그니스',
        PetSpecies.unicorn => '루체',
        _ => info(s).name,
      };

  /// 아스트라: 걸으면 3막 여정 기력이 조금 더 참 (걸음 단위마다 더하는 몫)
  static const double pegasusEnergy = 0.5;

  /// 고르: 채집할 때 가끔 하나 더
  static const double behemothExtra = 0.30;

  /// 마레: 물가 근처를 걸으면 가끔 귀한 재료 (하루 몇 번까지)
  static const double leviathanFind = 0.25;
  static const int leviathanPerDay = 3;

  /// 이그니스: 전투를 시작할 때 불을 한 번 뿜음 (공격력 배율 · 화상 턴)
  static const double dragonOpening = 1.5;
  static const int dragonOpeningBurn = 2;

  /// 이 레벨(직업 각성)부터 알에서 영웅 펫이 나옴
  static const int heroLevel = 15;

  /// 처음 1%, 안 나올 때마다 +0.5%p (최대 10%)
  static const double heroBase = 0.01;
  static const double heroStep = 0.005;
  static const double heroMax = 0.10;
  static double heroChance(int misses) =>
      math.min(heroMax, heroBase + heroStep * misses);

  /// 영웅 · 전설 펫의 정해진 이름 (펫 탭에서 바꿀 수 있음)
  static String heroName(PetSpecies s) => switch (s) {
        PetSpecies.pegasus ||
        PetSpecies.behemoth ||
        PetSpecies.nightmare ||
        PetSpecies.leviathan ||
        PetSpecies.dragon ||
        PetSpecies.unicorn =>
          legendName(s),
        PetSpecies.wolf => '바람',
        PetSpecies.turtle => '모스',
        PetSpecies.panther => '녹턴',
        PetSpecies.whale => '무',
        PetSpecies.phoenix => '엠버',
        PetSpecies.stag => '여명',
        _ => info(s).name,
      };

  /// 바람: 동행 중이면 원정 간 다른 펫이 조금 빨리 돌아옴 (이동 시간 배율)
  static const double wolfOthersTravel = 0.90;

  /// 모스: 동행 중이면 채집 자리가 조금 빨리 다시 참 (다시 차는 시간 배율)
  static const double turtleRecharge = 0.80;

  /// 녹턴: 밤에 동행하면 나에게만 보이는 몬스터 (그날 처음 자리 둘레)
  static const int pantherNightSpawns = 3;

  /// 무: 동행하고 그날 이만큼 걸으면 지도에 하늘에서 떨어진 재료 상자 하나 (하루 한 번)
  static const int whaleSkySteps = 2000;
  static const int whaleSkyGoldMin = 20, whaleSkyGoldMax = 60;

  /// 엠버: 동행 중이면 잿빛 몬스터를 찾아냄 (그날 처음 자리 둘레) + 던전에서 한 번 되살아남
  static const int phoenixAshSpawns = 2;
  static const double phoenixRevive = 0.30;

  /// 여명: 이른 아침(새벽 5~9시) 동행하며 1,000보마다 HP·기력 조금
  static const double stagHp = 0.04;
  static const int stagMp = 4;
  static bool isDawn(DateTime t) => t.hour >= 5 && t.hour < 9;

  /// 묶음 75 #334: 알을 얻는 순간 등급 (전설 → 영웅 → 희귀 → 일반, 확률이 없으면 굴리지 않음)
  static EggGrade rollEggGrade(math.Random rng, {double heroChance = 0, double legendChance = 0}) {
    if (legendChance > 0 && rng.nextDouble() < legendChance) return EggGrade.legend;
    if (heroChance > 0 && rng.nextDouble() < heroChance) return EggGrade.hero;
    if (rng.nextDouble() < rareChance) return EggGrade.rare;
    return EggGrade.common;
  }

  /// 묶음 75 #334: 그 등급 알에서 깨어날 펫 (주 속성 3배 · 연금술 1등 호문쿨루스 3배 그대로)
  static PetSpecies speciesOfGrade(math.Random rng, EggGrade grade,
      {PetSpecies? favored, Element? element, bool alchemyTop = false}) {
    final pool = [
      for (final s in switch (grade) {
        EggGrade.legend => legendSpecies,
        EggGrade.hero => heroSpecies,
        EggGrade.rare => rareSpecies,
        EggGrade.common => commonSpecies,
      }) ...[
        s,
        if (s == favored) s,
        if (element != null && info(s).element == element) ...[s, s],
        if (alchemyTop && s == PetSpecies.homunculus) ...[s, s],
      ],
    ];
    return pool[rng.nextInt(pool.length)];
  }

  /// 부화할 펫: [heroChance] 로 영웅 6종, 그다음 10%는 희귀 6종, 나머지는 일반 6종
  /// (각 1몫, 정령 짝은 2몫, 주 속성 펫 3배, 연금술 1등이면 호문쿨루스 3배)
  static PetSpecies rollSpecies(math.Random rng,
      {PetSpecies? favored,
      Element? element,
      bool alchemyTop = false,
      double heroChance = 0,
      double legendChance = 0}) {
    // 묶음 57: 전설 → 영웅 → 희귀 → 일반 순서 (확률이 없으면 굴리지도 않는다)
    final legend = legendChance > 0 && rng.nextDouble() < legendChance;
    // 영웅 확률이 없으면 굴리지도 않는다 (다른 결과를 흔들지 않게)
    final hero = !legend && heroChance > 0 && rng.nextDouble() < heroChance;
    final rare = !legend && !hero && rng.nextDouble() < rareChance;
    final pool = [
      for (final s in legend
          ? legendSpecies
          : hero
          ? heroSpecies
          : rare
              ? rareSpecies
              : commonSpecies) ...[
        s,
        if (s == favored) s,
        // 알을 얻을 때의 주 속성 (11-11 #63): 그 속성 펫이 3배
        if (element != null && info(s).element == element) ...[s, s],
        // 묶음 32 #189: 연금술이 큰 숙련도 1등이면 호문쿨루스 3배
        if (alchemyTop && s == PetSpecies.homunculus) ...[s, s],
      ],
    ];
    return pool[rng.nextInt(pool.length)];
  }

  /// 같은 속성 재료를 먹이면 경험치 1.5배 (11-11 #63)
  static const double sameElementFood = 1.5;

  // ───────────────────────── 공용 MP

  /// 두 번째 펫부터 한 마리마다 최대 MP +10, 시간당 회복 +2
  static int mpMaxBonus(int pets) => math.max(0, pets - 1) * 10;
  static int mpRegenBonus(int pets) => math.max(0, pets - 1) * 2;

  // ───────────────────────── 성장

  /// 다음 레벨까지 (50 × 지금 레벨)
  static int expToNext(int level) => 50 * level;

  /// 쌓인 경험치로 레벨 (1~20)
  static int levelFor(int exp) {
    var level = 1;
    var left = exp;
    while (level < maxLevel && left >= expToNext(level)) {
      left -= expToNext(level);
      level++;
    }
    return level;
  }

  /// 지금 레벨 안에서 쌓인 경험치
  static int expInto(int exp) {
    var level = 1;
    var left = exp;
    while (level < maxLevel && left >= expToNext(level)) {
      left -= expToNext(level);
      level++;
    }
    return left;
  }

  static const int expPer100Steps = 1;
  static const int expPerHunt = 5;
  static const int expPerExpedition = 10;
  static const int expCommonFood = 3;
  static const int expRareFood = 15;
  static const int expSnack = 40;

  static const int maxBond = 100;
  static const int bondPerFood = 1;
  static const int bondPerSnack = 5;

  /// 친밀도 100(단짝)이면 원정 특기 ×1.2. 기운 공명(#191)이면 효과 +10% (숨김)
  static double bondMultiplier(int bond, {bool resonant = false}) =>
      (bond >= maxBond ? 1.2 : 1.0) * (resonant ? resonanceBoost : 1.0);

  // ───────────────────────── 기운 공명 (묶음 32 #191, 숨은 값)

  /// 펫 속성이 내 주 속성과 같으면: 원정 특기·던전 스킬 효과 +10%
  static const double resonanceBoost = 1.10;

  /// 친밀도 오르는 양 1.5배 (먹이·간식)
  static const double resonanceBond = 1.5;

  static bool resonant(PetSpecies s, Element? main) =>
      main != null && info(s).element == main;

  // ───────────────────────── 호문쿨루스 (묶음 32 #190, 숨은 값)

  /// 원정 특기 문구 (#184)
  static const String homunculusSpecial =
      '원정에서 재료를 많이 가져오고, 어느 몬스터에게도 약하지 않아요. 함께 있으면 물약이 가끔 하나 더 나와요';

  /// 동행 중 연금술 물약이 가끔 하나 더 (연금술 숙련도·연금술사와 따로)
  static double homunculusBrew({required bool adult}) => adult ? 0.15 : 0.10;

  /// 이긴 원정에서 가끔 귀한 연금술 재료 (정제 에센스 계열)
  static const double homunculusEssence = 0.20;

  /// 원정에서 속성 몬스터에게 받는 피해 줄이기 (상성 약점도 없음)
  static double homunculusGuard({required bool adult}) => adult ? 0.15 : 0.10;

  /// 돌려보내기: 마석 (5 + 레벨 × 2) + 좋아하던 재료 3개
  static int releaseMana(int level) => 5 + level * 2;
  static const int releaseMaterials = 3;

  // ───────────────────────── 원정 특기

  /// 원정 이동 시간 배율 (까마귀)
  static double travelTimeFactor(PetSpecies s,
      {required bool adult, int bond = 0, bool resonant = false}) {
    final m = bondMultiplier(bond, resonant: resonant);
    return switch (s) {
      PetSpecies.crow => 1 - (adult ? 0.30 : 0.20) * m,
      // 묶음 33 #185: 그리핀 빨리, 켈피 다른 원정도 조금 빨리
      PetSpecies.griffin => 1 - (adult ? 0.35 : 0.25) * m,
      PetSpecies.kelpie => 1 - (adult ? 0.15 : 0.10) * m,
      // 묶음 49 #235 영웅 펫
      PetSpecies.wolf => 1 - (adult ? 0.40 : 0.30) * m,
      PetSpecies.stag => 1 - (adult ? 0.25 : 0.18) * m,
      // 묶음 57 #244 전설 펫
      PetSpecies.pegasus => 1 - (adult ? 0.50 : 0.40) * m,
      PetSpecies.unicorn => 1 - (adult ? 0.32 : 0.25) * m,
      _ => 1,
    };
  }

  /// 원정 MP 배율 (꼬마 도마뱀, 물가의 두꺼비)
  static double mpFactor(PetSpecies s,
      {required bool adult,
      int bond = 0,
      bool waterside = false,
      bool resonant = false}) {
    final m = bondMultiplier(bond, resonant: resonant);
    if (s == PetSpecies.lizard) return 1 - (adult ? 0.35 : 0.25) * m;
    if (s == PetSpecies.drake) return 1 - (adult ? 0.40 : 0.30) * m;
    if (s == PetSpecies.toad && waterside) return 1 - (adult ? 0.60 : 0.50) * m;
    if (s == PetSpecies.kelpie && waterside) {
      return 1 - (adult ? 0.70 : 0.60) * m;
    }
    // 묶음 49 #235 영웅 펫
    if (s == PetSpecies.whale) {
      return 1 - (waterside ? (adult ? 0.80 : 0.70) : (adult ? 0.45 : 0.35)) * m;
    }
    if (s == PetSpecies.phoenix) return 1 - (adult ? 0.35 : 0.25) * m;
    // 묶음 57 #244 전설 펫
    if (s == PetSpecies.leviathan) {
      return 1 - (waterside ? (adult ? 0.90 : 0.80) : (adult ? 0.55 : 0.45)) * m;
    }
    if (s == PetSpecies.dragon) return 1 - (adult ? 0.45 : 0.35) * m;
    return 1;
  }

  /// 물가 두꺼비의 이동 시간 배율
  static double waterTimeFactor(PetSpecies s,
          {required bool adult,
          int bond = 0,
          bool waterside = false,
          bool resonant = false}) =>
      s == PetSpecies.toad && waterside
          ? 1 - 0.30 * bondMultiplier(bond, resonant: resonant)
          : s == PetSpecies.kelpie && waterside
              ? 1 - 0.40 * bondMultiplier(bond, resonant: resonant)
              : (s == PetSpecies.whale || s == PetSpecies.leviathan) && waterside
                  ? 1 - (s == PetSpecies.leviathan ? 0.60 : 0.50) * bondMultiplier(bond, resonant: resonant)
                  : 1;

  /// 원정 전투력 배율 (부엉이 항상, 검은 고양이 밤)
  static double powerFactor(PetSpecies s,
      {required bool adult,
      int bond = 0,
      bool night = false,
      bool resonant = false}) {
    final m = bondMultiplier(bond, resonant: resonant);
    if (s == PetSpecies.owl) return 1 + (adult ? 0.12 : 0.08) * m;
    if (s == PetSpecies.blackCat && night) {
      return 1 + (adult ? 0.25 : 0.15) * m;
    }
    // 묶음 33 #185 희귀 펫
    if (s == PetSpecies.griffin) return 1 + (adult ? 0.15 : 0.10) * m;
    if (s == PetSpecies.direwolf) return 1 + (adult ? 0.25 : 0.18) * m;
    if (s == PetSpecies.drake) return 1 + (adult ? 0.15 : 0.10) * m;
    // 묶음 49 #235 영웅 펫
    if (s == PetSpecies.wolf) return 1 + (adult ? 0.22 : 0.15) * m;
    if (s == PetSpecies.panther) {
      return 1 + (night ? (adult ? 0.45 : 0.35) : (adult ? 0.18 : 0.12)) * m;
    }
    if (s == PetSpecies.phoenix) return 1 + (adult ? 0.30 : 0.22) * m;
    // 묶음 57 #244 전설 펫
    if (s == PetSpecies.pegasus) return 1 + (adult ? 0.30 : 0.22) * m;
    if (s == PetSpecies.nightmare) {
      return 1 + (night ? (adult ? 0.60 : 0.48) : (adult ? 0.28 : 0.20)) * m;
    }
    if (s == PetSpecies.dragon) return 1 + (adult ? 0.42 : 0.32) * m;
    if (s == PetSpecies.behemoth) return 1 + (adult ? 0.18 : 0.12) * m;
    return 1;
  }

  /// 원정 성공 때 더 가져오는 재료 수 (호문쿨루스: +2, 성체는 가끔 +3. 묶음 32 #190)
  static int extraMaterials(PetSpecies s, math.Random rng,
      {required bool adult, int bond = 0}) {
    // 묶음 49 #235: 모스 2 (성체 가끔 3) · 여명 1 (성체 가끔 2)
    if (s == PetSpecies.turtle) {
      return adult && rng.nextDouble() < 0.5 * bondMultiplier(bond) ? 3 : 2;
    }
    if (s == PetSpecies.stag) {
      return adult && rng.nextDouble() < 0.5 * bondMultiplier(bond) ? 2 : 1;
    }
    // 묶음 57 #244: 고르 3 (성체 가끔 4) · 루체 2 (성체 가끔 3)
    if (s == PetSpecies.behemoth) {
      return adult && rng.nextDouble() < 0.5 * bondMultiplier(bond) ? 4 : 3;
    }
    if (s == PetSpecies.unicorn) {
      return adult && rng.nextDouble() < 0.5 * bondMultiplier(bond) ? 3 : 2;
    }
    if (s == PetSpecies.direwolf) {
      // 묶음 33 #185: 다이어울프 이기면 재료 더 (성체는 가끔 하나 더)
      if (adult && rng.nextDouble() < 0.5 * bondMultiplier(bond)) return 2;
      return 1;
    }
    if (s != PetSpecies.homunculus) return 0;
    if (adult && rng.nextDouble() < 0.5 * bondMultiplier(bond)) return 3;
    return 2;
  }

  /// 미믹: 이긴 원정에서 가끔 금화·귀한 재료 (숨은 값)
  static double mimicChance({required bool adult, int bond = 0}) =>
      (adult ? 0.35 : 0.25) * bondMultiplier(bond);
  static const int mimicGoldMin = 30, mimicGoldMax = 80;

  /// 골렘: 원정에서 져도 기력을 돌려받음
  static bool keepsMpOnLoss(PetSpecies s) =>
      s == PetSpecies.golem || s == PetSpecies.turtle || s == PetSpecies.behemoth;

  /// 「잘 맞아요」(#188): 먼 목표 · 기력이 많이 드는 원정 기준 (숨은 값)
  static const double farM = 1000;
  static const int costlyMp = 20;

  /// 길에서 이만큼 넘게 떨어진 몬스터는 물가 몬스터로 친다 (두꺼비)
  static const double watersideM = 150;

  // ───────────────────────── 던전 스킬

  /// 스킬 피해 배율 (기본 정령의 일격 ×4 자리)
  static double skillMultiplier(PetSkill s,
          {required bool adult, bool resonant = false}) =>
      (resonant ? resonanceBoost : 1.0) *
      switch (s) {
        PetSkill.peck => adult ? 5.0 : 4.0,
        PetSkill.scratch => adult ? 4.5 : 3.5,
        PetSkill.tongue => adult ? 3.0 : 2.5,
        PetSkill.insight => 3.0,
        PetSkill.ember => adult ? 3.5 : 3.0,
        PetSkill.shield => 2.0,
        // 묶음 33 #185 희귀 펫 (일반보다 한 단계 세게)
        PetSkill.thunderClaw => adult ? 5.5 : 4.5,
        PetSkill.frostBite => adult ? 4.0 : 3.5,
        PetSkill.flameBreath => adult ? 4.5 : 4.0,
        PetSkill.tideWrap => adult ? 3.5 : 3.0,
        PetSkill.ambush => adult ? 3.5 : 3.0,
        PetSkill.stoneWall => 2.5,
        // 묶음 49 #235 영웅 펫 (희귀보다 한 단계 세게)
        PetSkill.galeFang => adult ? 6.5 : 5.5,
        PetSkill.mossShell => 3.0,
        PetSkill.shadowPounce => adult ? 5.0 : 4.5,
        PetSkill.tidalSong => adult ? 4.0 : 3.5,
        PetSkill.rebirthFlame => adult ? 6.0 : 5.0,
        PetSkill.dawnHalo => adult ? 3.5 : 3.0,
        // 묶음 57 #244 전설 펫 (영웅보다 한 단계 세게)
        PetSkill.starWing => adult ? 7.5 : 6.5,
        PetSkill.quake => adult ? 5.0 : 4.5,
        PetSkill.nightTerror => adult ? 6.0 : 5.5,
        PetSkill.abyssTide => adult ? 5.0 : 4.5,
        PetSkill.dragonFire => adult ? 7.0 : 6.0,
        PetSkill.holyHorn => adult ? 4.5 : 4.0,
      };

  /// 번개 발톱이 멈추게 할 확률 · 깜짝 물기가 아주 크게 물 확률·배율 (숨은 값)
  static const double thunderStun = 0.30;
  static double ambushChance({required bool adult}) => adult ? 0.40 : 0.30;
  static const double ambushMultiplier = 3.0;

  /// 화염 숨결 계속 타는 턴 · 물살 휘감기 회복 · 돌 방벽 막는 횟수
  static const int flameTurns = 4;
  static const double tideHeal = 0.08;
  static int stoneWallHits({required bool adult}) => adult ? 6 : 5;

  /// 스킬 충전 틱 (쪼기만 4, 나머지는 기본 5)
  static int? skillChargeTicks(PetSkill s) => switch (s) {
        PetSkill.peck => 4,
        PetSkill.galeFang => 3, // 묶음 49: 질풍 송곳니는 더 빨리
        PetSkill.starWing => 3, // 묶음 57: 별빛 날개도
        _ => null,
      };

  /// 영웅 펫 던전 스킬 (숨은 값): 그림자 덮치기 묶을 확률 · 고래 노래 회복 ·
  /// 되살림 불꽃 타는 턴 · 이끼 등딱지 막는 횟수 · 새벽 햇무리 회복
  static const double pounceBind = 0.30;
  static const double songHeal = 0.12;
  static const int rebirthTurns = 5;
  static int mossHits({required bool adult}) => adult ? 8 : 7;
  static const double haloHeal = 0.06;

  /// 전설 펫 던전 스킬 (숨은 값, 묶음 57 #244): 땅울림 멈출 확률 · 악몽 묶을 확률 ·
  /// 심해 물살 회복 · 용의 불꽃 타는 턴 · 성스러운 뿔 회복
  static const double quakeStun = 0.50;
  static const double terrorBind = 0.45;
  static const double abyssHeal = 0.16;
  static const int dragonFireTurns = 6;
  static const double hornHeal = 0.10;

  /// 약점 간파: 3턴 동안 각성자 피해 +20% (성체 +30%)
  static double insightBonus({required bool adult}) => adult ? 0.30 : 0.20;
  static const int insightTurns = 3;

  /// 작은 보호막: 다음 3번(성체 4번) 받는 피해 -50% (묶음 32 #190)
  static int shieldHits({required bool adult}) => adult ? 4 : 3;

  // ───────────────────────── 정보

  static PetSpeciesInfo info(PetSpecies s) => _info[s] ?? _heroInfo[s] ?? _legendInfo[s]!;

  static PetSpecies? byName(String name) {
    for (final s in PetSpecies.values) {
      if (s.name == name) return s;
    }
    return null;
  }

  static const Map<PetSpecies, PetSpeciesInfo> _info = {
    PetSpecies.crow: PetSpeciesInfo(
      id: PetSpecies.crow,
      element: Element.wind,
      name: '까마귀',
      grade: PetGrade.common,
      special: '원정을 빨리 다녀와요',
      specialAdult: '원정을 더 빨리 다녀와요',
      skill: PetSkill.peck,
      skillName: '쪼기',
      skillText: '금방 차고 세게 쪼아요',
      skillTextAdult: '금방 차고 세게 쪼아요',
      favorite: MaterialId.batWing,
    ),
    PetSpecies.blackCat: PetSpeciesInfo(
      id: PetSpecies.blackCat,
      element: Element.dark,
      name: '검은 고양이',
      grade: PetGrade.common,
      special: '밤 원정에 강해요',
      specialAdult: '밤 원정에 아주 강해요',
      skill: PetSkill.scratch,
      skillName: '할퀴기',
      skillText: '꼭 급소를 할퀴어요',
      skillTextAdult: '꼭 급소를 할퀴어요',
      favorite: MaterialId.rabbitMeat,
    ),
    PetSpecies.toad: PetSpeciesInfo(
      id: PetSpecies.toad,
      element: Element.poison,
      name: '두꺼비',
      grade: PetGrade.common,
      special: '물가 원정이 가볍고 빨라요',
      specialAdult: '물가 원정이 더 가볍고 빨라요',
      skill: PetSkill.tongue,
      skillName: '혀로 묶기',
      skillText: '몬스터를 한 번 묶어 둬요',
      skillTextAdult: '몬스터를 한 번 묶어 둬요',
      favorite: MaterialId.waterJelly,
    ),
    PetSpecies.owl: PetSpeciesInfo(
      id: PetSpecies.owl,
      element: Element.light,
      name: '부엉이',
      grade: PetGrade.common,
      special: '원정에서 잘 싸워요',
      specialAdult: '원정에서 더 잘 싸워요',
      skill: PetSkill.insight,
      skillName: '약점 간파',
      skillText: '약점을 찾아 내 공격이 잠시 세져요',
      skillTextAdult: '약점을 찾아 내 공격이 잠시 세져요',
      favorite: MaterialId.butterflyDust,
    ),
    PetSpecies.lizard: PetSpeciesInfo(
      id: PetSpecies.lizard,
      element: Element.fire,
      name: '꼬마 도마뱀',
      grade: PetGrade.common,
      special: '원정 기력을 덜 써요',
      specialAdult: '원정 기력을 더 덜 써요',
      skill: PetSkill.ember,
      skillName: '작은 불씨',
      skillText: '불씨가 남아 계속 타요',
      skillTextAdult: '불씨가 남아 계속 타요',
      favorite: MaterialId.fireJelly,
    ),
    PetSpecies.homunculus: PetSpeciesInfo(
      id: PetSpecies.homunculus,
      name: '호문쿨루스',
      grade: PetGrade.common,
      special: homunculusSpecial,
      specialAdult: homunculusSpecial,
      skill: PetSkill.shield,
      skillName: '작은 보호막',
      skillText: '받는 피해를 오래 막아 줘요',
      skillTextAdult: '받는 피해를 오래 막아 줘요',
      favorite: MaterialId.slimeCore,
    ),
    // ───────── 묶음 33 #185 희귀 펫
    PetSpecies.griffin: PetSpeciesInfo(
      id: PetSpecies.griffin,
      element: Element.thunder,
      name: '아기 그리핀',
      grade: PetGrade.rare,
      special: '원정을 빨리 다녀오고 잘 싸워요',
      specialAdult: '원정을 더 빨리 다녀오고 더 잘 싸워요',
      skill: PetSkill.thunderClaw,
      skillName: '번개 발톱',
      skillText: '세게 할퀴고 가끔 멈추게 해요',
      skillTextAdult: '세게 할퀴고 가끔 멈추게 해요',
      favorite: MaterialId.gemThunder,
    ),
    PetSpecies.direwolf: PetSpeciesInfo(
      id: PetSpecies.direwolf,
      element: Element.ice,
      name: '다이어울프',
      grade: PetGrade.rare,
      special: '원정에서 아주 잘 싸우고, 이기면 재료를 더 가져와요',
      specialAdult: '원정에서 아주 잘 싸우고, 이기면 재료를 더 많이 가져와요',
      skill: PetSkill.frostBite,
      skillName: '서리 물기',
      skillText: '물어서 얼려 잠시 움직이지 못하게 해요',
      skillTextAdult: '물어서 얼려 잠시 움직이지 못하게 해요',
      favorite: MaterialId.gemIce,
    ),
    PetSpecies.drake: PetSpeciesInfo(
      id: PetSpecies.drake,
      element: Element.fire,
      name: '드레이크',
      grade: PetGrade.rare,
      special: '원정 기력을 덜 쓰고 잘 싸워요',
      specialAdult: '원정 기력을 더 덜 쓰고 더 잘 싸워요',
      skill: PetSkill.flameBreath,
      skillName: '화염 숨결',
      skillText: '크게 태우고 불이 계속 타요',
      skillTextAdult: '크게 태우고 불이 계속 타요',
      favorite: MaterialId.gemFire,
    ),
    PetSpecies.kelpie: PetSpeciesInfo(
      id: PetSpecies.kelpie,
      element: Element.water,
      name: '켈피',
      grade: PetGrade.rare,
      special: '물가 원정이 아주 가볍고 빠르고, 다른 원정도 조금 빨라요',
      specialAdult: '물가 원정이 아주 가볍고 더 빠르고, 다른 원정도 빨라요',
      skill: PetSkill.tideWrap,
      skillName: '물살 휘감기',
      skillText: '몬스터를 묶고 내 HP를 조금 채워요',
      skillTextAdult: '몬스터를 묶고 내 HP를 조금 채워요',
      favorite: MaterialId.gemWater,
    ),
    PetSpecies.mimic: PetSpeciesInfo(
      id: PetSpecies.mimic,
      element: Element.metal,
      name: '미믹',
      grade: PetGrade.rare,
      special: '원정에서 가끔 금화나 귀한 재료를 가져와요',
      specialAdult: '원정에서 더 자주 금화나 귀한 재료를 가져와요',
      skill: PetSkill.ambush,
      skillName: '깜짝 물기',
      skillText: '가끔 아주 크게 물어요',
      skillTextAdult: '더 자주 아주 크게 물어요',
      favorite: MaterialId.gemMetal,
    ),
    PetSpecies.golem: PetSpeciesInfo(
      id: PetSpecies.golem,
      element: Element.earth,
      name: '골렘',
      grade: PetGrade.rare,
      special: '원정에서 져도 기력을 잃지 않아요',
      specialAdult: '원정에서 져도 기력을 잃지 않아요',
      skill: PetSkill.stoneWall,
      skillName: '돌 방벽',
      skillText: '아주 오래 막는 보호막을 쳐요',
      skillTextAdult: '아주 오래 막는 보호막을 쳐요',
      favorite: MaterialId.gemEarth,
    ),
  };

  static const Map<PetSpecies, PetSpeciesInfo> _heroInfo = {
    PetSpecies.wolf: PetSpeciesInfo(
      id: PetSpecies.wolf,
      element: Element.wind,
      name: '은빛 늑대',
      grade: PetGrade.hero,
      special: '원정을 아주 빨리 다녀오고 잘 싸워요',
      specialAdult: '원정을 더 빨리 다녀오고 더 잘 싸워요',
      walk: '함께 걸으면 원정 간 다른 펫이 조금 빨리 돌아와요',
      skill: PetSkill.galeFang,
      skillName: '질풍 송곳니',
      skillText: '바람처럼 빨리 차고 아주 세게 물어요',
      skillTextAdult: '바람처럼 빨리 차고 아주 세게 물어요',
      favorite: MaterialId.gemWind,
    ),
    PetSpecies.turtle: PetSpeciesInfo(
      id: PetSpecies.turtle,
      element: Element.earth,
      name: '이끼 거북',
      grade: PetGrade.hero,
      special: '원정에서 져도 기력을 잃지 않고, 이기면 재료를 많이 가져와요',
      specialAdult: '원정에서 져도 기력을 잃지 않고, 이기면 재료를 더 많이 가져와요',
      walk: '함께 걸으면 채집 자리가 조금 빨리 다시 차요',
      skill: PetSkill.mossShell,
      skillName: '이끼 등딱지',
      skillText: '아주 오래 버티는 보호막을 쳐요',
      skillTextAdult: '아주 오래 버티는 보호막을 쳐요',
      favorite: MaterialId.gemEarth,
    ),
    PetSpecies.panther: PetSpeciesInfo(
      id: PetSpecies.panther,
      element: Element.dark,
      name: '달그림자 표범',
      grade: PetGrade.hero,
      special: '원정에서 잘 싸우고, 밤 원정에 아주 강해요',
      specialAdult: '원정에서 더 잘 싸우고, 밤 원정에 더 강해요',
      walk: '밤에 함께 걸으면 나에게만 보이는 몬스터가 나타나요',
      skill: PetSkill.shadowPounce,
      skillName: '그림자 덮치기',
      skillText: '꼭 급소를 노리고 가끔 묶어 둬요',
      skillTextAdult: '꼭 급소를 노리고 가끔 묶어 둬요',
      favorite: MaterialId.gemDark,
    ),
    PetSpecies.whale: PetSpeciesInfo(
      id: PetSpecies.whale,
      element: Element.water,
      name: '안개 고래',
      grade: PetGrade.hero,
      special: '물가 원정이 아주 가볍고 빠르고, 다른 원정도 기력을 덜 써요',
      specialAdult: '물가 원정이 아주 가볍고 빠르고, 다른 원정도 기력을 더 덜 써요',
      walk: '함께 걸으면 가끔 지도에 하늘에서 떨어진 재료가 보여요',
      skill: PetSkill.tidalSong,
      skillName: '고래 노래',
      skillText: '몬스터를 묶고 내 HP를 넉넉히 채워요',
      skillTextAdult: '몬스터를 묶고 내 HP를 넉넉히 채워요',
      favorite: MaterialId.gemWater,
    ),
    PetSpecies.phoenix: PetSpeciesInfo(
      id: PetSpecies.phoenix,
      element: Element.fire,
      name: '잿불새',
      grade: PetGrade.hero,
      special: '원정에서 아주 잘 싸우고, 기력을 덜 써요',
      specialAdult: '원정에서 더 잘 싸우고, 기력을 더 덜 써요',
      walk: '함께 걸으면 잿빛 몬스터를 찾아내고, 던전에서 한 번 되살려 줘요',
      skill: PetSkill.rebirthFlame,
      skillName: '되살림 불꽃',
      skillText: '크게 태우고 불이 오래 타요',
      skillTextAdult: '크게 태우고 불이 오래 타요',
      favorite: MaterialId.gemFire,
    ),
    PetSpecies.stag: PetSpeciesInfo(
      id: PetSpecies.stag,
      element: Element.light,
      name: '새벽 사슴',
      grade: PetGrade.hero,
      special: '원정을 빨리 다녀오고, 이기면 재료를 더 가져와요',
      specialAdult: '원정을 더 빨리 다녀오고, 이기면 재료를 더 많이 가져와요',
      walk: '이른 아침에 함께 걸으면 HP와 기력이 조금씩 차요',
      skill: PetSkill.dawnHalo,
      skillName: '새벽 햇무리',
      skillText: '약점을 비춰 내 공격이 잠시 세지고 HP를 조금 채워요',
      skillTextAdult: '약점을 비춰 내 공격이 잠시 세지고 HP를 조금 채워요',
      favorite: MaterialId.gemLight,
    ),
  };

  /// 묶음 57 #244 전설 펫 6 (속성마다 하나)
  static const Map<PetSpecies, PetSpeciesInfo> _legendInfo = {
    PetSpecies.pegasus: PetSpeciesInfo(
      id: PetSpecies.pegasus,
      element: Element.wind,
      name: '페가수스',
      grade: PetGrade.legend,
      special: '원정을 눈 깜짝할 새 다녀오고 아주 잘 싸워요',
      specialAdult: '원정을 더 빨리 다녀오고 더 잘 싸워요',
      walk: '함께 걸으면 3막 여정 기력이 조금 더 차요',
      skill: PetSkill.starWing,
      skillName: '별빛 날개',
      skillText: '바람보다 빨리 차고 별빛으로 아주 세게 쳐요',
      skillTextAdult: '바람보다 빨리 차고 별빛으로 아주 세게 쳐요',
      favorite: MaterialId.gemWind,
    ),
    PetSpecies.behemoth: PetSpeciesInfo(
      id: PetSpecies.behemoth,
      element: Element.earth,
      name: '베히모스',
      grade: PetGrade.legend,
      special: '원정에서 져도 기력을 잃지 않고, 이기면 재료를 아주 많이 가져와요',
      specialAdult: '원정에서 져도 기력을 잃지 않고, 이기면 재료를 더 많이 가져와요',
      walk: '함께 걸으면 채집할 때 가끔 하나 더 나와요',
      skill: PetSkill.quake,
      skillName: '땅울림',
      skillText: '땅을 울려 크게 다치게 하고 자주 멈춰 세워요',
      skillTextAdult: '땅을 울려 크게 다치게 하고 자주 멈춰 세워요',
      favorite: MaterialId.gemEarth,
    ),
    PetSpecies.nightmare: PetSpeciesInfo(
      id: PetSpecies.nightmare,
      element: Element.dark,
      name: '나이트메어',
      grade: PetGrade.legend,
      special: '원정에서 아주 잘 싸우고, 밤 원정에 더없이 강해요',
      specialAdult: '원정에서 더 잘 싸우고, 밤 원정에 훨씬 강해요',
      walk: '함께 걸으면 던전 갈림길에서 함정을 미리 알려 줘요',
      skill: PetSkill.nightTerror,
      skillName: '악몽',
      skillText: '꼭 급소를 노리고 자주 묶어 둬요',
      skillTextAdult: '꼭 급소를 노리고 자주 묶어 둬요',
      favorite: MaterialId.gemDark,
    ),
    PetSpecies.leviathan: PetSpeciesInfo(
      id: PetSpecies.leviathan,
      element: Element.water,
      name: '리바이어던',
      grade: PetGrade.legend,
      special: '물가 원정은 거의 기력이 들지 않고, 다른 원정도 아주 가벼워요',
      specialAdult: '물가 원정은 거의 기력이 들지 않고, 다른 원정도 더 가벼워요',
      walk: '물가 근처를 함께 걸으면 가끔 귀한 재료를 찾아요',
      skill: PetSkill.abyssTide,
      skillName: '심해 물살',
      skillText: '몬스터를 묶고 내 HP를 크게 채워요',
      skillTextAdult: '몬스터를 묶고 내 HP를 크게 채워요',
      favorite: MaterialId.gemWater,
    ),
    PetSpecies.dragon: PetSpeciesInfo(
      id: PetSpecies.dragon,
      element: Element.fire,
      name: '드래곤',
      grade: PetGrade.legend,
      special: '원정에서 누구보다 잘 싸우고, 기력도 덜 써요',
      specialAdult: '원정에서 더 잘 싸우고, 기력을 더 덜 써요',
      walk: '함께 있으면 전투를 시작할 때 불을 한 번 뿜어요',
      skill: PetSkill.dragonFire,
      skillName: '용의 불꽃',
      skillText: '아주 크게 태우고 불이 오래 타요',
      skillTextAdult: '아주 크게 태우고 불이 오래 타요',
      favorite: MaterialId.gemFire,
    ),
    PetSpecies.unicorn: PetSpeciesInfo(
      id: PetSpecies.unicorn,
      element: Element.light,
      name: '유니콘',
      grade: PetGrade.legend,
      special: '원정을 빨리 다녀오고, 이기면 재료를 많이 가져와요',
      specialAdult: '원정을 더 빨리 다녀오고, 이기면 재료를 더 많이 가져와요',
      walk: '함께 있으면 3막에서 져도 한 번 그 자리에서 다시 일어나요',
      skill: PetSkill.holyHorn,
      skillName: '성스러운 뿔',
      skillText: '약점을 비춰 내 공격이 잠시 세지고 HP를 넉넉히 채워요',
      skillTextAdult: '약점을 비춰 내 공격이 잠시 세지고 HP를 넉넉히 채워요',
      favorite: MaterialId.gemLight,
    ),
  };

  // ───────────────────────── 정령 편지

  static const List<LetterInfo> letters = [
    LetterInfo(
      id: 'lv20',
      title: 'Lv.20 축하 편지',
      level: 20,
      manaStones: 10,
      snacks: 2,
      body: '벌써 Lv.20이라니! 멀리서도 네 발소리가 들려. '
          '네 곁의 친구에게 간식을 조금 보낼게. 둘이 사이좋게 나눠 먹어!',
    ),
    LetterInfo(
      id: 'lv30',
      title: 'Lv.30 축하 편지',
      level: 30,
      manaStones: 20,
      recipeNotes: 1,
      body: 'Lv.30! 이제는 내가 안내할 게 하나도 없겠다. '
          '여행하다 주운 쪽지를 넣어 둘게. 무슨 물약일지 궁금하지?',
    ),
    LetterInfo(
      id: 'day100',
      title: '각성 100일 편지',
      days: 100,
      gold: 300,
      compasses: 1,
      body: '우리가 처음 만난 지 100일이 됐어. 그날 네 손을 잡았던 게 엊그제 같아. '
          '먼 길 갈 때 쓰라고 나침반을 보낼게.',
    ),
    LetterInfo(
      id: 'day365',
      title: '각성 1년 편지',
      days: 365,
      gold: 1000,
      eggs: 1,
      body: '1년 동안 정말 많이 걸었구나. 나도 저 멀리서 같이 걸었어. '
          '작은 알 하나를 보내. 새 친구를 잘 부탁해!',
    ),
  ];
}

/// 떠난 정령이 보내는 편지
class LetterInfo {
  const LetterInfo({
    required this.id,
    required this.title,
    required this.body,
    this.level,
    this.days,
    this.manaStones = 0,
    this.gold = 0,
    this.snacks = 0,
    this.compasses = 0,
    this.recipeNotes = 0,
    this.eggs = 0,
  });

  final String id;
  final String title;
  final String body;

  /// 이 레벨이 되면 (또는 [days] 일째)
  final int? level;
  final int? days;

  final int manaStones;
  final int gold;
  final int snacks;
  final int compasses;
  final int recipeNotes;
  final int eggs;

  String get giftLabel => [
        if (manaStones > 0) '마석 $manaStones',
        if (gold > 0) '금화 $gold',
        if (snacks > 0) '펫 간식 $snacks',
        if (compasses > 0) '원정 나침반 $compasses',
        if (recipeNotes > 0) '레시피 쪽지 $recipeNotes',
        if (eggs > 0) '알 $eggs',
      ].join(' · ');
}
