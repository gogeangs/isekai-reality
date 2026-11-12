import 'dart:math' as math;

import 'element_rules.dart';
import 'materials.dart';
import 'modifier_rules.dart';

/// 펫 등급. 이번에는 일반만 들어가고, 희귀·전설은 자리만 둔다 (11-11 #38).
enum PetGrade { common, rare, legend }

/// 펫 종류. 이름은 저장 키라 바꾸지 않는다.
/// 희귀(아기 그리핀·다이어울프·드레이크·켈피·미믹·골렘), 전설(아기 페가수스·유니콘·
/// 키메라·바실리스크·드래곤·피닉스)은 나중에 여기에 더한다.
enum PetSpecies { crow, blackCat, toad, owl, lizard, homunculus }

/// 펫의 던전 스킬 종류
enum PetSkill { peck, scratch, tongue, insight, ember, shield }

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
  });

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

  String asset({required bool adult}) =>
      'assets/images/pet_${id.name}_${adult ? 'adult' : 'baby'}.webp';
}

/// 펫 규칙 (11-11 제안서 3 확정 값)
class PetRules {
  PetRules._();

  static const int maxPets = 6;
  static const int maxLevel = 20;

  /// 아기 → 성체
  static const int adultLevel = 10;

  /// 정령과 이별하는 레벨
  static const int farewellLevel = 11;

  // ───────────────────────── 알

  /// Lv.11 전 필드 사냥에서 이길 때마다 (한 번만)
  static const double firstEggChance = 0.04;

  /// Lv.11 이후 필드 사냥 (수식어 등급별)
  static double fieldEggChance(ModGrade grade) => switch (grade) {
        ModGrade.none || ModGrade.common => 0.01,
        ModGrade.rare => 0.05,
        ModGrade.legend => 0.20,
      };

  /// 던전 보스를 쓰러뜨렸을 때
  static const double dungeonEggChance = 0.05;

  /// 주간 의뢰를 모두 끝낸 주: 2주에 한 번 알
  static const int boardEggEveryWeeks = 2;

  /// 품은 뒤 저절로 부화하기까지
  static const Duration hatchTime = Duration(hours: 12);

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

  /// 부화할 펫: 6종 각 1몫, 정령 짝은 2몫
  static PetSpecies rollSpecies(math.Random rng,
      {PetSpecies? favored, Element? element}) {
    final pool = [
      for (final s in PetSpecies.values) ...[
        s,
        if (s == favored) s,
        // 알을 얻을 때의 주 속성 (11-11 #63): 그 속성 펫이 3배
        if (element != null && info(s).element == element) ...[s, s],
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

  /// 친밀도 100(단짝)이면 원정 특기 ×1.2
  static double bondMultiplier(int bond) => bond >= maxBond ? 1.2 : 1.0;

  /// 돌려보내기: 마석 (5 + 레벨 × 2) + 좋아하던 재료 3개
  static int releaseMana(int level) => 5 + level * 2;
  static const int releaseMaterials = 3;

  // ───────────────────────── 원정 특기

  /// 원정 이동 시간 배율 (까마귀)
  static double travelTimeFactor(PetSpecies s, {required bool adult, int bond = 0}) {
    if (s != PetSpecies.crow) return 1;
    return 1 - (adult ? 0.30 : 0.20) * bondMultiplier(bond);
  }

  /// 원정 MP 배율 (꼬마 도마뱀, 물가의 두꺼비)
  static double mpFactor(PetSpecies s,
      {required bool adult, int bond = 0, bool waterside = false}) {
    final m = bondMultiplier(bond);
    if (s == PetSpecies.lizard) return 1 - (adult ? 0.35 : 0.25) * m;
    if (s == PetSpecies.toad && waterside) return 1 - (adult ? 0.60 : 0.50) * m;
    return 1;
  }

  /// 물가 두꺼비의 이동 시간 배율
  static double waterTimeFactor(PetSpecies s,
          {required bool adult, int bond = 0, bool waterside = false}) =>
      s == PetSpecies.toad && waterside ? 1 - 0.30 * bondMultiplier(bond) : 1;

  /// 원정 전투력 배율 (부엉이 항상, 검은 고양이 밤)
  static double powerFactor(PetSpecies s,
      {required bool adult, int bond = 0, bool night = false}) {
    final m = bondMultiplier(bond);
    if (s == PetSpecies.owl) return 1 + (adult ? 0.12 : 0.08) * m;
    if (s == PetSpecies.blackCat && night) {
      return 1 + (adult ? 0.25 : 0.15) * m;
    }
    return 1;
  }

  /// 원정 성공 때 더 가져오는 재료 수 (호문쿨루스)
  static int extraMaterials(PetSpecies s, math.Random rng,
      {required bool adult, int bond = 0}) {
    if (s != PetSpecies.homunculus) return 0;
    if (adult && rng.nextDouble() < 0.5 * bondMultiplier(bond)) return 2;
    return 1;
  }

  /// 길에서 이만큼 넘게 떨어진 몬스터는 물가 몬스터로 친다 (두꺼비)
  static const double watersideM = 150;

  // ───────────────────────── 던전 스킬

  /// 스킬 피해 배율 (기본 정령의 일격 ×4 자리)
  static double skillMultiplier(PetSkill s, {required bool adult}) =>
      switch (s) {
        PetSkill.peck => adult ? 5 : 4,
        PetSkill.scratch => adult ? 4.5 : 3.5,
        PetSkill.tongue => adult ? 3 : 2.5,
        PetSkill.insight => 3,
        PetSkill.ember => adult ? 3.5 : 3,
        PetSkill.shield => 2,
      };

  /// 스킬 충전 틱 (쪼기만 4, 나머지는 기본 5)
  static int? skillChargeTicks(PetSkill s) => s == PetSkill.peck ? 4 : null;

  /// 약점 간파: 3턴 동안 각성자 피해 +20% (성체 +30%)
  static double insightBonus({required bool adult}) => adult ? 0.30 : 0.20;
  static const int insightTurns = 3;

  /// 작은 보호막: 다음 2번(성체 3번) 받는 피해 -50%
  static int shieldHits({required bool adult}) => adult ? 3 : 2;

  // ───────────────────────── 정보

  static PetSpeciesInfo info(PetSpecies s) => _info[s]!;

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
      special: '원정 이동 시간 -20%',
      specialAdult: '원정 이동 시간 -30%',
      skill: PetSkill.peck,
      skillName: '쪼기',
      skillText: '피해 ×4, 빨리 차요 (4틱)',
      skillTextAdult: '피해 ×5, 빨리 차요 (4틱)',
      favorite: MaterialId.batWing,
    ),
    PetSpecies.blackCat: PetSpeciesInfo(
      id: PetSpecies.blackCat,
      element: Element.dark,
      name: '검은 고양이',
      grade: PetGrade.common,
      special: '밤(오후 7시~새벽 5시) 원정 전투력 +15%',
      specialAdult: '밤(오후 7시~새벽 5시) 원정 전투력 +25%',
      skill: PetSkill.scratch,
      skillName: '할퀴기',
      skillText: '피해 ×3.5, 반드시 치명타',
      skillTextAdult: '피해 ×4.5, 반드시 치명타',
      favorite: MaterialId.rabbitMeat,
    ),
    PetSpecies.toad: PetSpeciesInfo(
      id: PetSpecies.toad,
      element: Element.poison,
      name: '두꺼비',
      grade: PetGrade.common,
      special: '물가 몬스터 원정 MP -50%, 시간 -30%',
      specialAdult: '물가 몬스터 원정 MP -60%, 시간 -30%',
      skill: PetSkill.tongue,
      skillName: '혀로 묶기',
      skillText: '피해 ×2.5, 몬스터가 한 턴 멈춰요',
      skillTextAdult: '피해 ×3, 몬스터가 한 턴 멈춰요',
      favorite: MaterialId.waterJelly,
    ),
    PetSpecies.owl: PetSpeciesInfo(
      id: PetSpecies.owl,
      element: Element.light,
      name: '부엉이',
      grade: PetGrade.common,
      special: '원정 전투력 +8%',
      specialAdult: '원정 전투력 +12%',
      skill: PetSkill.insight,
      skillName: '약점 간파',
      skillText: '피해 ×3, 3턴 동안 내 피해 +20%',
      skillTextAdult: '피해 ×3, 3턴 동안 내 피해 +30%',
      favorite: MaterialId.butterflyDust,
    ),
    PetSpecies.lizard: PetSpeciesInfo(
      id: PetSpecies.lizard,
      element: Element.fire,
      name: '꼬마 도마뱀',
      grade: PetGrade.common,
      special: '원정 MP -25%',
      specialAdult: '원정 MP -35%',
      skill: PetSkill.ember,
      skillName: '작은 불씨',
      skillText: '피해 ×3, 화상 3턴',
      skillTextAdult: '피해 ×3.5, 화상 3턴',
      favorite: MaterialId.fireJelly,
    ),
    PetSpecies.homunculus: PetSpeciesInfo(
      id: PetSpecies.homunculus,
      name: '호문쿨루스',
      grade: PetGrade.common,
      special: '원정 성공 때 재료 +1',
      specialAdult: '원정 성공 때 재료 +1 (50%로 +2)',
      skill: PetSkill.shield,
      skillName: '작은 보호막',
      skillText: '피해 ×2, 다음 2번 받는 피해 -50%',
      skillTextAdult: '피해 ×2, 다음 3번 받는 피해 -50%',
      favorite: MaterialId.slimeCore,
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
        if (eggs > 0) '펫 알 $eggs',
      ].join(' · ');
}
