import 'materials.dart';
import 'village_rules.dart';

/// 건물 레벨업 (묶음 54): 결말(본체) 뒤 마을 건물 10채를 ★1 → ★2 → ★3 으로 고친다.
/// 금화 + 재료를 그 시설 마을 사람에게 가져다 주면 「고치는 중」(★2 1시간 · ★3 4시간,
/// 그동안에도 시설은 그대로 씀) 뒤 레벨업 연출. 효과는 화면에 문장으로만 (수치는 숨김).
/// 이름은 마을 시설([Facility]) 이름과 같다 (그림 village_<name>_<★>.webp).
enum Building { inn, shop, board, guild, smithy, alchemy, shelter, training, garden, tavern, market }

/// 한 단계를 고치는 데 드는 것
class BuildingNeed {
  const BuildingNeed(this.gold, this.mats);

  final int gold;
  final Map<MaterialId, int> mats;
}

class BuildingInfo {
  const BuildingInfo(this.id, this.name, this.npc,
      {required this.to2, required this.to3, required this.text2, required this.text3, this.done2, this.done3});

  /// 묶음 67: 다 고쳤을 때 마을 사람 한마디 (없으면 「○○ ★n 완성!」만)
  final String? done2;
  final String? done3;
  String? doneFor(int star) => star >= 3 ? done3 : done2;

  final Building id;
  final String name;

  /// 그 시설 마을 사람 (고칠 것을 가져다 주는 사람)
  final Npc npc;

  /// ★2 · ★3 으로 고치는 데 드는 것 (★3 엔 귀한 재료 하나)
  final BuildingNeed to2;
  final BuildingNeed to3;

  /// 좋아지는 것 (숫자 없이 문장)
  final String text2;
  final String text3;

  BuildingNeed needFor(int toStar) => toStar >= 3 ? to3 : to2;
  String textFor(int star) => star >= 3 ? text3 : text2;

  /// 그 단계 그림 (★1 은 지금 그림)
  String assetFor(int star) => star >= 2
      ? 'assets/images/village_${id.name}_$star.webp'
      : 'assets/images/village_${id.name}.webp';
}

class BuildingRules {
  BuildingRules._();

  static const int maxStar = 3;

  /// 고치는 시간: ★2 1시간 · ★3 4시간
  static Duration fixTime(int toStar) =>
      toStar >= 3 ? const Duration(hours: 4) : const Duration(hours: 1);

  static const List<BuildingInfo> all = [
    BuildingInfo(Building.inn, '여관', Npc.marta,
        to2: BuildingNeed(400, {MaterialId.hardWood: 4, MaterialId.tannedLeather: 2}),
        to3: BuildingNeed(900, {
          MaterialId.hardWood: 6,
          MaterialId.tannedLeather: 4,
          MaterialId.sturdyKnot: 1,
        }),
        text2: '여관에서 더 빨리 회복해요',
        text3: '가득 찬 뒤 일어나면 잠시 HP · 기력 최대가 조금 늘어요'),
    BuildingInfo(Building.shop, '잡화상', Npc.mina,
        to2: BuildingNeed(450, {MaterialId.ironShard: 6, MaterialId.twig: 6}),
        to3: BuildingNeed(950, {
          MaterialId.ironIngot: 3,
          MaterialId.hardWood: 4,
          MaterialId.riverPearl: 1,
        }),
        text2: '파는 물건이 늘어나요',
        text3: '하루에 살 수 있는 개수가 늘고, 가끔 특별한 물건이 들어와요'),
    BuildingInfo(Building.board, '의뢰 게시판', Npc.hart,
        to2: BuildingNeed(400, {MaterialId.twig: 8, MaterialId.ratHide: 4}),
        to3: BuildingNeed(900, {
          MaterialId.hardWood: 4,
          MaterialId.tannedLeather: 3,
          MaterialId.runeStone: 1,
        }),
        text2: '조합 의뢰 칸이 하나 늘어나요',
        text3: '의뢰 보상이 조금 좋아져요'),
    BuildingInfo(Building.guild, '조합', Npc.sera,
        to2: BuildingNeed(450, {MaterialId.hardWood: 4, MaterialId.ironShard: 6}),
        to3: BuildingNeed(1000, {
          MaterialId.ironIngot: 4,
          MaterialId.ancientShard: 3,
          MaterialId.runeStone: 1,
        }),
        text2: '세라가 하루 한 번 숨은 이명 힌트를 들려줘요',
        text3: '숙련도가 조금 더 빨리 올라요'),
    BuildingInfo(Building.smithy, '대장간', Npc.dorgun,
        to2: BuildingNeed(500, {MaterialId.ironShard: 10, MaterialId.roughGem: 2}),
        to3: BuildingNeed(1000, {
          MaterialId.ironIngot: 5,
          MaterialId.roughGem: 4,
          MaterialId.manaOre: 1,
        }),
        text2: '좋은 등급이 조금 더 잘 나와요',
        text3: '수리비가 줄고 강화가 조금 쉬워져요'),
    BuildingInfo(Building.alchemy, '연금술 공방', Npc.eliel,
        to2: BuildingNeed(450, {MaterialId.herb: 10, MaterialId.slimeJelly: 6}),
        to3: BuildingNeed(950, {
          MaterialId.herbExtract: 3,
          MaterialId.essence: 2,
          MaterialId.dewHerb: 1,
        }),
        text2: '물약이 끓는 시간이 짧아져요',
        text3: '가마솥이 하나 더 생겨요'),
    BuildingInfo(Building.shelter, '펫 쉼터', Npc.lumi,
        to2: BuildingNeed(400, {MaterialId.twig: 10, MaterialId.hardWood: 2}),
        to3: BuildingNeed(900, {
          MaterialId.hardWood: 5,
          MaterialId.tannedLeather: 3,
          MaterialId.sturdyKnot: 1,
        }),
        text2: '지친 펫이 더 빨리 회복해요',
        text3: '알 두 개를 함께 품을 수 있어요'),
    BuildingInfo(Building.training, '훈련장', Npc.garen,
        to2: BuildingNeed(450, {MaterialId.hardWood: 5, MaterialId.ironShard: 8}),
        to3: BuildingNeed(1000, {
          MaterialId.ironIngot: 4,
          MaterialId.hardWood: 6,
          MaterialId.manaOre: 1,
        }),
        text2: '하루 훈련을 한 번 더 할 수 있어요',
        text3: '펫 훈련 효과가 조금 커지고, 시련 보상이 한 단계 더 생겨요'),
    BuildingInfo(Building.garden, '약초밭', Npc.popo,
        to2: BuildingNeed(400, {MaterialId.herb: 8, MaterialId.herbSeed: 3}),
        to3: BuildingNeed(900, {
          MaterialId.flowerSeed: 3,
          MaterialId.sporeSeed: 3,
          MaterialId.sunPollen: 1,
        }),
        text2: '밭이 한 칸 늘어나요',
        text3: '조금 더 빨리 자라고, 가끔 두 배로 거둬요'),
    BuildingInfo(Building.tavern, '주점', Npc.lian,
        to2: BuildingNeed(450, {MaterialId.hardWood: 5, MaterialId.flowerSeed: 3}),
        to3: BuildingNeed(950, {
          MaterialId.hardWood: 6,
          MaterialId.shadeMushroom: 4,
          MaterialId.breezeBloom: 1,
        }),
        text2: '모험가를 두 명 더 둘 수 있고, 새 메뉴 「버섯 수프」가 생겨요',
        text3: '모험가를 두 명 더 둘 수 있고, 한 끼 효과가 조금 더 오래가요'),
    // 묶음 67 #271: 거래소 (바르칸)
    BuildingInfo(Building.market, '거래소', Npc.barkan,
        to2: BuildingNeed(450, {MaterialId.hardWood: 5, MaterialId.ironShard: 6}),
        to3: BuildingNeed(950, {
          MaterialId.ironIngot: 3,
          MaterialId.hardWood: 4,
          MaterialId.runeStone: 1,
        }),
        text2: '한 번에 올리는 칸이 5칸에서 7칸으로 늘어나요',
        text3: '칸이 9칸이 되고, 값을 정해 올린 물건을 48시간에서 72시간까지 맡아 줘요',
        done2: '가판을 하나 더 냈어! 이제 물건을 더 많이 올려도 돼.',
        done3: '창고도 넓혔지. 정해 둔 값으로 내놓은 물건은 사흘까지 맡아 줄게!'),
  ];

  static BuildingInfo info(Building b) => all.firstWhere((i) => i.id == b);

  static Building? parse(String name) {
    for (final b in Building.values) {
      if (b.name == name) return b;
    }
    return null;
  }

  /// 그 마을 사람이 맡은 건물 (묶음 67: 거래소 바르칸도)
  static Building? ofNpc(Npc n) {
    for (final i in all) {
      if (i.npc == n) return i.id;
    }
    return null;
  }

  // ───────────── 마을 사람 말 (고치기 판)

  static const String needLine = '고치려면 이게 필요해';
  static const String fixingLine = '지금 고치는 중이야. 그동안에도 그대로 써도 돼!';
  static const String maxLine = '더 고칠 데가 없어. 마을에서 제일 멋진 건물이야!';

  // ───────────── 효과 (숨은 값, 테스트로 조정)

  // 여관 ★2 · ★3 값은 InnRules (묶음 81 #373: 회복 속도 ×1.25 · 가득 찬 뒤 일어나면 잠시 최대 조금 더)

  /// 잡화상 ★3: 하루 살 수 있는 개수 +1 · 특별한 물건이 들어오는 날 (6일 중 3일 꼴)
  static const int shopExtraLimit = 1;

  /// 게시판 ★3: 의뢰 금화 조금 더
  static const double boardGold = 1.15;

  /// 대장간 ★2: 좋은 등급 +%p · ★3: 수리비 · 강화 성공률 +
  static const double smithGrade = 3;
  static const double smithRepair = 0.8;
  static const double smithEnhance = 0.05;

  /// 연금술 ★2: 끓는 시간
  static const double brewTime = 0.8;

  /// 조합 ★3: 숙련도
  static const double guildMastery = 1.1;

  /// 펫 쉼터 ★2: 지친 시간
  static const double shelterTired = 0.7;

  /// 약초밭 ★3: 자라는 데 드는 걸음 · 두 배 수확 확률
  static const double gardenNeed = 0.85;
  static const double gardenDouble = 0.15;

  /// 훈련장 ★3: 펫 훈련 경험치 · 더 생기는 시련 보상 판
  static const double petTraining = 1.3;
  static const int trialExtraMark = 20;

  /// 주점: 단계마다 모험가 보유 +2 · ★3 한 끼 효과가 다음 날 이 시각까지
  static const int rosterPerStar = 2;
  static const int mealUntilHour = 12;

  /// 묶음 67 #271 거래소: 한 번에 올리는 칸 (★1 5 · ★2 7 · ★3 9) · 값을 정해 올린 물건 시간 (★3 72시간)
  static int marketSlots(int star) => switch (star) { >= 3 => 9, 2 => 7, _ => 5 };
  static int marketFixedHours(int star) => star >= 3 ? 72 : 48;

  /// 버섯 수프: 그날 채집할 때 가끔 하나 더
  static const double soupExtra = 0.25;
}
