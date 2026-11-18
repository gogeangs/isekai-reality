import 'act3_rules.dart';
import 'baldrin_rules.dart';
import 'element_rules.dart';
import 'equipment_rules.dart';
import 'materials.dart';
import 'monsters.dart';
import 'pet_rules.dart';
import 'title_rules.dart';
import 'town_rules.dart';

/// 3막 지역 2~5 (묶음 57 #243): 발드린(묶음 53)과 같은 틀 — 마을 · 주민 4 · 필드 3 · 던전 5층 · 숨은 장소 ·
/// 메인 흐름 · 큰 고르기 · 서브 4 + 동료 퀘스트 · 몬스터 7 · 장비 6 · 이름 있는 장비 3 · 지역 무기 · 칭호.
/// 숫자는 개발이 정한 숨은 값(처음 값, 테스트로 조정). 화면엔 문장만.

class RResident {
  const RResident(this.id, this.name, this.role, this.first, this.lines, {this.afterLamp, this.face});

  final String id;
  final String name;
  final String role;
  final String first;
  final List<String> lines;

  /// 등불 뒤 한마디 (번갈아)
  final String? afterLamp;

  /// 얼굴 그림 이름 (없으면 npc_<id>)
  final String? face;

  String get faceAsset => 'assets/images/${face ?? 'npc_$id'}.webp';
}

/// 서브 · 동료 퀘스트가 셈하는 것
enum RQKind {
  /// 그 장소 필드에서 이기기
  hunt,

  /// 던전 그 층까지 가기
  floor,

  /// 서로 다른 재료 [target]가지 (종류마다 2개) 건네기
  mats,

  /// 받은 뒤 걸음
  walk,

  /// 그 지역 중간 보스 쓰러뜨리기
  boss,
}

class RQuest {
  const RQuest({
    required this.id,
    required this.title,
    required this.ask,
    required this.task,
    required this.done,
    required this.kind,
    this.giver,
    this.ally,
    this.place,
    this.target = 1,
    this.line = '',
    this.embers = false,
  });

  /// 묶음 58: 테스 「다섯 불의 기록」 — 걸음에 더해 다섯 지역 불씨(그 지역에 들어갈 때 하나씩)도 모아야 끝남
  final bool embers;

  final String id;

  /// 맡기는 주민 (동료 퀘스트면 null)
  final String? giver;

  /// 동료 퀘스트 (끝내면 그 동료 스킬 ④)
  final StoryAlly? ally;
  final String title;
  final String ask;
  final String task;
  final String done;
  final RQKind kind;

  /// 사냥할 곳 · 「그 장소로 가기」
  final String? place;
  final int target;

  /// 한 칸 나아갈 때 결과 한 줄
  final String line;
}

class ROption {
  const ROption(this.key, this.title, this.text, this.result, {this.gold = 0, this.tickets = 0, this.unique});

  final String key;
  final String title;
  final String text;

  /// 고른 뒤 장면 (말하는 이 · 대사)
  final List<(String, String)> result;
  final int gold;
  final int tickets;

  /// 고르면 주는 이름 있는 장비
  final EquipBase? unique;
}

class RChoice {
  const RChoice(this.title, this.a, this.b, {this.afterLamp = false});

  final String title;
  final ROption a;
  final ROption b;

  /// 등불 보스(최종 보스)를 쓰러뜨린 뒤 고름 (아우렐)
  final bool afterLamp;
}

class RHidden {
  const RHidden({
    required this.place,
    required this.name,
    required this.locked,
    required this.unlockBy,
    required this.lines,
    required this.boss,
    required this.title,
    this.pet,
    this.petLine,
  });

  final String place;
  final String name;

  /// 열리기 전 한 줄
  final String locked;

  /// 이 서브 퀘스트를 끝내면 열림
  final String unlockBy;
  final List<String> lines;
  final MonsterId boss;
  final TitleId title;

  /// 이 영웅 펫을 가진 사람은 특별 대사
  final PetSpecies? pet;
  final String? petLine;
}

class RegionContent {
  const RegionContent({
    required this.region,
    required this.town,
    required this.townName,
    required this.dungeonName,
    required this.dungeonBg,
    required this.residents,
    required this.mains,
    required this.arrive,
    required this.talk,
    required this.eventPlace,
    required this.eventLabel,
    required this.eventFoes,
    required this.eventLines,
    required this.choice,
    required this.floors,
    required this.floorStories,
    required this.normals,
    required this.lampLines,
    required this.lampUnlocks,
    required this.lampTitle,
    required this.quests,
    required this.hidden,
    required this.gear,
    required this.uniques,
    required this.uniqueStories,
    required this.uniqueEffects,
    required this.weapon,
    required this.weaponMat,
    required this.weaponElement,
    required this.joins,
    this.shop = const [],
    this.shopMore = const [],
    this.shopDark = false,
  });

  final Region region;
  final String town;
  final String townName;
  final String dungeonName;
  final String dungeonBg;
  final List<RResident> residents;

  /// 메인 다섯 단계 (제목 · 할 일 · 장소)
  final List<({String title, String text, String? place})> mains;

  /// 지역에 처음 들어갈 때 장면 (동료 합류)
  final List<(String, String)> arrive;

  /// ② 마을 이야기 장면
  final List<(String, String)> talk;

  /// ③ 사건 (그 장소에서 싸운 뒤 큰 고르기)
  final String eventPlace;
  final String eventLabel;
  final List<MonsterId> eventFoes;
  final List<String> eventLines;
  final RChoice choice;

  final List<FloorInfo> floors;
  final List<String> floorStories;
  final List<MonsterId> normals;
  final List<String> lampLines;
  final List<String> lampUnlocks;
  final TitleId lampTitle;
  final List<RQuest> quests;
  final RHidden hidden;
  final List<EquipBase> gear;
  final List<EquipBase> uniques;
  final Map<EquipBase, String> uniqueStories;
  final Map<EquipBase, String> uniqueEffects;
  final EquipBase weapon;
  final MaterialId weaponMat;
  final Element weaponElement;

  /// 이야기 동료 합류 때: 'arrive' · 'choice:<옵션>' · 'floor:<층>'
  final Map<StoryAlly, String> joins;

  /// 마을 상점 (등불 뒤 더) · 등불 전엔 비싼 값(흑등 상회)
  final List<ShopItem> shop;
  final List<ShopItem> shopMore;
  final bool shopDark;

  String get prefix => region.name;

  /// 묶음 58: 현실 지도에 나오는 이 지역 재료
  MaterialId get mapMat => switch (region) {
        Region.selenia => MaterialId.stardust,
        Region.elowin => MaterialId.gemEarth,
        Region.morval => MaterialId.gemDark,
        _ => MaterialId.fireCore,
      };
  RResident resident(String id) => residents.firstWhere((r) => r.id == id);
  RQuest quest(String id) => quests.firstWhere((q) => q.id == id);
}

abstract final class RegionRules {
  // ───────────── 공통 숨은 값

  /// 서브 퀘스트 보상: 모집권 1 + 금화
  static const int sideTickets = 1;

  /// 묶음 58: 등불 켠 지역 재료가 현실 지도에 나올 확률(지역마다 하루) · 거리
  static const double mapMatChance = 0.6;
  static const double mapMatMinM = 200, mapMatMaxM = 600;

  /// 묶음 58: 다섯 불씨 (지역 수)
  static const int embersNeed = 5;
  static const int sideGold = 100;
  static const int matsEach = 2;

  /// 보스 세기 (발드린보다 지역마다 조금씩 더)
  static double hpScale(Region r) => 1 + 0.08 * r.index;

  /// 지역 무기 값 (금화 · 조각 · 마석)
  static const int weaponGold = 800;
  static const int weaponMats = 3;
  static const int weaponStones = 40;

  /// 등불 보스 조각: 처음 3 · 그 뒤 1
  static const int pieceFirst = 3, pieceAgain = 1;

  /// 이름 있는 장비 확률 (등불 · 중간 · 상자 · 숨은 보스 처음은 꼭)
  static const double uniqLamp = 0.05, uniqMid = 0.025, uniqChest = 0.012, uniqHidden = 0.06;

  /// 흑등 상회 빛 가게 값 (등불 전 셀레니아)
  static const double darkPrice = 2.0;

  /// 셀레니아 경매장 (NPC): 하루 한 물건
  static const int auctionGold = 220;

  /// 심층 (3막 뒤): 6층부터 끝없이, 5층마다 보스. 층이 깊을수록 세짐
  static const int deepStart = 6;
  static double deepScale(int floor) => 1 + 0.09 * (floor - deepStart + 1);

  /// 3막 끝 칭호 · 장면
  static const TitleId fiveLampsTitle = TitleId.fiveLamps;
  static const String fiveLampsScene = 'assets/images/scene_act3_fivelamps.webp';
  static const String teoMartaScene = 'assets/images/scene_teo_marta.webp';

  static const List<(String, String)> endScene = [
    ('pet', '다섯 등불이 모두 켜졌어… 저쪽 하늘이 처음으로 환해!'),
    ('lian', '빛을 빼앗지 않고 나눠서 켰어요. 왕도, 오르벤도 이걸 보고 있을 거예요.'),
    ('kaspar', '…아름답군. 이 빛, 병에 조금 담아 가도 되겠지? 장사꾼은 기회를 놓치지 않는 법이라.'),
    ('pet', '카스파르가 빛을 담은 병을 들고 다리 쪽으로 사라졌어. 저 사람, 뭘 하려는 걸까…'),
  ];

  static const List<(String, String)> teoScene = [
    ('teo', '어머니… 늦어서 미안해요. 문은 끝까지 지켰어요.'),
    ('marta', '…바보 같은 녀석. 수프 식기 전에 앉아. 이번엔 같이 끓이자.'),
    ('garen', '하하! 신병 다섯이 모두 돌아왔군. 이제야 내 호령이 끝났다.'),
  ];

  /// 3막 뒤 아르카 마을 새 대사
  static const String martaAfterEnd = '테오가 돌아왔어. 수프 냄새가 매일 두 배야. 너도 자주 와!';
  static const String hartAfterEnd = '다섯 지역 의뢰가 모두 게시판에 붙었네. 저쪽 일도 한 장씩 떼어 가게.';

  // ───────────── 장비 정보 (일반 6부위 · 이름 있는 장비 · 지역 무기)

  static EquipBaseInfo _g(EquipBase id, String name, EquipSlot slot, String asset,
          {double attack = 0, double reduce = 0, double maxHp = 0, double crit = 0, double evade = 0,
          double speed = 0, Map<MaterialId, int> recipe = const {}, int stones = 0}) =>
      EquipBaseInfo(
          id: id,
          name: name,
          slot: slot,
          recipe: recipe,
          manaStones: stones,
          attack: attack,
          reduce: reduce,
          maxHp: maxHp,
          crit: crit,
          evade: evade,
          speed: speed,
          asset: asset);

  static final List<EquipBaseInfo> gearInfos = [
    // 셀레니아 상단
    _g(EquipBase.seleniaWeapon, '셀레니아 호위 도끼', EquipSlot.weapon, 'equip_seleniaWeapon', attack: 0.15),
    _g(EquipBase.seleniaHead, '셀레니아 상단 두건', EquipSlot.head, 'equip_seleniaHead', reduce: 0.045),
    _g(EquipBase.seleniaBody, '셀레니아 가죽 조끼', EquipSlot.body, 'equip_seleniaBody', reduce: 0.09),
    _g(EquipBase.seleniaHands, '셀레니아 상단 장갑', EquipSlot.hands, 'equip_seleniaHands', reduce: 0.035),
    _g(EquipBase.seleniaFeet, '셀레니아 여행 장화', EquipSlot.feet, 'equip_seleniaFeet', reduce: 0.035),
    _g(EquipBase.seleniaAcc, '셀레니아 저울 펜던트', EquipSlot.accessory, 'equip_seleniaAcc', maxHp: 0.11),
    _g(EquipBase.uniqGrumHammer, '그럼의 화덕 망치', EquipSlot.weapon, 'uniq_grumHammer', attack: 0.19),
    _g(EquipBase.uniqBlackLantern, '흑등 상회의 빛 등불', EquipSlot.accessory, 'uniq_blackLantern', maxHp: 0.09, crit: 0.02),
    _g(EquipBase.uniqStardustBoots, '별가루 장화', EquipSlot.feet, 'uniq_stardustBoots', reduce: 0.04, speed: 0.05),
    _g(EquipBase.seleniaAxe, '장터의 저울 도끼', EquipSlot.weapon, 'equip_seleniaAxe',
        attack: 0.22, recipe: {MaterialId.cartWheel: weaponMats, MaterialId.stardust: 2}, stones: weaponStones),
    // 엘로윈 나무지기
    _g(EquipBase.elowinWeapon, '엘로윈 나무지기 창', EquipSlot.weapon, 'equip_elowinWeapon', attack: 0.16),
    _g(EquipBase.elowinHead, '엘로윈 잎 두건', EquipSlot.head, 'equip_elowinHead', reduce: 0.05),
    _g(EquipBase.elowinBody, '엘로윈 나무껍질 갑옷', EquipSlot.body, 'equip_elowinBody', reduce: 0.095),
    _g(EquipBase.elowinHands, '엘로윈 덩굴 장갑', EquipSlot.hands, 'equip_elowinHands', reduce: 0.04),
    _g(EquipBase.elowinFeet, '엘로윈 이끼 장화', EquipSlot.feet, 'equip_elowinFeet', reduce: 0.04),
    _g(EquipBase.elowinAcc, '엘로윈 씨앗 목걸이', EquipSlot.accessory, 'equip_elowinAcc', maxHp: 0.12),
    _g(EquipBase.uniqMomoWreath, '모모의 꽃 화관', EquipSlot.head, 'uniq_momoWreath', reduce: 0.05, maxHp: 0.05),
    _g(EquipBase.uniqArbelDagger, '아르벨의 잎새 단검', EquipSlot.weapon, 'uniq_arbelDagger', attack: 0.18, crit: 0.03),
    _g(EquipBase.uniqElderHeart, '고목의 심장', EquipSlot.accessory, 'uniq_elderHeart', maxHp: 0.13),
    _g(EquipBase.elowinStaff, '숲지기의 덩굴 지팡이', EquipSlot.weapon, 'equip_elowinStaff',
        attack: 0.23, recipe: {MaterialId.elderBark: weaponMats, MaterialId.gemEarth: 1}, stones: weaponStones),
    // 모르발 근위
    _g(EquipBase.morvalWeapon, '모르발 근위 장검', EquipSlot.weapon, 'equip_morvalWeapon', attack: 0.17),
    _g(EquipBase.morvalHead, '모르발 근위 투구', EquipSlot.head, 'equip_morvalHead', reduce: 0.055),
    _g(EquipBase.morvalBody, '모르발 근위 판금 갑옷', EquipSlot.body, 'equip_morvalBody', reduce: 0.10),
    _g(EquipBase.morvalHands, '모르발 근위 건틀릿', EquipSlot.hands, 'equip_morvalHands', reduce: 0.045),
    _g(EquipBase.morvalFeet, '모르발 근위 장화', EquipSlot.feet, 'equip_morvalFeet', reduce: 0.045),
    _g(EquipBase.morvalAcc, '모르발 근위 휘장', EquipSlot.accessory, 'equip_morvalAcc', maxHp: 0.13),
    _g(EquipBase.uniqLucyFlower, '루시의 빛꽃', EquipSlot.accessory, 'uniq_lucyFlower', maxHp: 0.10, evade: 0.02),
    _g(EquipBase.uniqKingCloak, '왕의 나눔 망토', EquipSlot.body, 'uniq_kingCloak', reduce: 0.10, maxHp: 0.04),
    _g(EquipBase.uniqMoonFang, '달그림자 송곳니', EquipSlot.weapon, 'uniq_moonFang', attack: 0.20, crit: 0.04),
    _g(EquipBase.morvalSword, '근위의 달그림자 검', EquipSlot.weapon, 'equip_morvalSword',
        attack: 0.24, recipe: {MaterialId.captainCrest: weaponMats, MaterialId.gemDark: 1}, stones: weaponStones),
    // 아우렐 순례
    _g(EquipBase.aurelWeapon, '아우렐 순례 창', EquipSlot.weapon, 'equip_aurelWeapon', attack: 0.18),
    _g(EquipBase.aurelHead, '아우렐 순례 두건', EquipSlot.head, 'equip_aurelHead', reduce: 0.06),
    _g(EquipBase.aurelBody, '아우렐 순례 겉옷', EquipSlot.body, 'equip_aurelBody', reduce: 0.105),
    _g(EquipBase.aurelHands, '아우렐 순례 장갑', EquipSlot.hands, 'equip_aurelHands', reduce: 0.05),
    _g(EquipBase.aurelFeet, '아우렐 순례 장화', EquipSlot.feet, 'equip_aurelFeet', reduce: 0.05),
    _g(EquipBase.aurelAcc, '아우렐 불씨 목걸이', EquipSlot.accessory, 'equip_aurelAcc', maxHp: 0.14),
    _g(EquipBase.uniqTeoCloak, '테오의 문지기 망토', EquipSlot.body, 'uniq_teoCloak', reduce: 0.11, maxHp: 0.05),
    _g(EquipBase.uniqNaomiStaff, '나오미의 순례 지팡이', EquipSlot.weapon, 'uniq_naomiStaff', attack: 0.19),
    _g(EquipBase.uniqPhoenixCharm, '불사조의 깃털 부적', EquipSlot.accessory, 'uniq_phoenixCharm', maxHp: 0.12),
    _g(EquipBase.aurelBow, '여명의 불꽃 활', EquipSlot.weapon, 'equip_aurelBow',
        attack: 0.25, crit: 0.05, recipe: {MaterialId.undyingEmber: weaponMats, MaterialId.fireCore: 1}, stones: weaponStones),
  ];

  /// 이름 있는 장비 숨은 효과 (숨김)
  static const double grumHammerPerLevel = 0.02; // 강화 단계가 높을수록 피해 더
  static const double blackLanternGold = 0.15; // 이기면 금화 조금 더
  static const double stardustBootsFind = 0.10; // 묶음 58: 1,000보마다 이 확률로 별가루 1 (하루 3번까지)
  static const int stardustBootsPerDay = 3;
  static const double momoWreathRegen = 0.12; // 묶음 58: 매 턴 이 확률로 HP 조금
  static const double momoWreathRatio = 0.04;
  static const double arbelBound = 0.20; // 묶인 적에게 피해 더
  static const double elderHeartGarden = 0.15; // 묶음 58: 약초밭이 이만큼 빨리 (자라는 시간 줄어듦)
  static const double lucyFlowerAllyRegen = 0.10; // 묶음 58: 매 턴 이 확률로 동료 HP 조금
  static const double kingCloakPotion = 0.08; // 묶음 58: 회복 물약을 쓰면 동료도 최대 HP의 이만큼
  static const double moonFangNight = 0.15; // 밤에 피해 더
  static const double teoCloakAsh = 0.10; // 잿빛에게 받는 피해 덜
  static const double naomiStaffEnergy = 0.25; // 묶음 58: 걸을 때 여정 기력이 이만큼 더
  static const int phoenixCharmRevive = 1; // 3막에서 한 번 버팀

  /// 지역 일반 세트 (숨김): 2개 받는 피해 ↓ · 4개 주는 피해 ↑ · 6개 둘 다 더
  static const double set2Taken = 0.05, set4Dealt = 0.08, set6Taken = 0.10, set6Dealt = 0.15;

  /// 묶음 58: 이번 주 심층 지역 (서버 deep.js 와 같은 규칙: 2026-11-16 주부터 셀레니아 → 엘로윈 → 모르발 → 아우렐)
  static Region deepRegionOf(DateTime now) {
    final k = now.toUtc().add(const Duration(hours: 9));
    final day = DateTime.utc(k.year, k.month, k.day);
    final monday = day.subtract(Duration(days: day.weekday - 1));
    final i = monday.difference(DateTime.utc(2026, 11, 16)).inDays ~/ 7;
    return all[i % all.length].region;
  }

  static RegionContent? of(Region r) => switch (r) {
        Region.baldrin => null,
        Region.selenia => selenia,
        Region.elowin => elowin,
        Region.morval => morval,
        Region.aurel => aurel,
      };

  static const List<RegionContent> all = [selenia, elowin, morval, aurel];

  static RegionContent? byPlace(String placeId) {
    for (final r in all) {
      if (placeId.startsWith('${r.prefix}_')) return r;
    }
    return null;
  }

  // ═════════════ 지역 2 「셀레니아 대장터」 (금속 · Lv.23)

  static const selenia = RegionContent(
    region: Region.selenia,
    town: 'assets/images/town_selenia.webp',
    townName: '불 꺼진 대장터',
    dungeonName: '흑등 상회 지하 금고',
    dungeonBg: 'assets/images/bg_dungeon_selenia.webp',
    residents: [
      RResident('eni', '에니', '상단 서기', '바르칸 상단의 장부는 제가 지켜요. 장터가 다시 열리는 날까지 한 장도 잃어버리지 않을 거예요.',
          ['장부는 거짓말을 안 해요. 흑등 상회가 뭘 빼앗았는지 다 적혀 있죠.', '의뢰판의 일은 다 장부에 남아요. 하나씩 지워 가요.', '바르칸 어르신이 돌아오셨으니, 이제 장터도 돌아올 거예요.'],
          afterLamp: '장터에 불이 켜졌어요! 오늘 장부엔 「손님 많음」이라고 적을래요.'),
      RResident('grum', '그럼', '드워프 대장장이', '…화덕이 식었다. 도르군 녀석은 잘 있나? 내 사제다. 망치질이 나보다 조금 모자라지.',
          ['화덕돌만 있으면 다시 불을 붙일 텐데.', '좋은 도끼는 저울처럼 무게가 고르다. 기억해 둬라.', '도르군에게 전해라. 손목에 힘 빼라고.'],
          afterLamp: '화덕에 다시 불이 붙었다. 장터의 저울 도끼, 만들 재료를 가져오면 손봐 주마.'),
      RResident('oscar', '오스카', '빛 가게 점원', '어서 오세요, 흑등 상회 빛 가게입니다. 병에 담은 빛, 오늘은 아주 비싸요. …늘 그렇지만요.',
          ['상회 일이요? 저는 그냥 병을 닦을 뿐이에요.', '카스파르 님은 손님을 고르지 않아요. 돈만 고르죠.', '…가끔은 이 빛이 원래 누구 것이었는지 생각해요.'],
          afterLamp: '이제 빛을 사지 않아도 되네요. 가게는 닫았어요. …시원섭섭하네요.'),
      RResident('mir', '미르', '별가루 광부 할머니', '이 골짜기 별가루는 원래 밤마다 노래를 불렀단다. 내가 어릴 땐 말이지.',
          ['광맥 깊은 곳엔 금속 거인이 산다는 옛이야기가 있지.', '별가루는 욕심 없는 손에만 반짝인단다.', '자장가를 불러 주면 별가루가 깨어난다더구나.'],
          afterLamp: '골짜기가 다시 반짝이는구나. 아이고, 살다 보니 이런 날이 다 오네.'),
    ],
    mains: [
      (title: '대상의 길', text: '대상의 길에서 습격당한 수레를 구하고 장터에 도착해요.', place: 'selenia_caravan'),
      (title: '불 꺼진 대장터', text: '장터에서 바르칸 상단의 서기 에니에게 이야기를 들어요.', place: 'selenia_town'),
      (title: '지갑 도둑', text: '버려진 광산 쪽에서 지갑을 훔친 아이를 붙잡아요.', place: 'selenia_mine'),
      (title: '흑등 상회 지하 금고', text: '금고 5층까지 내려가 빼앗긴 빛이 어디로 갔는지 알아내요.', place: 'selenia_vault'),
      (title: '장터의 등불', text: '잿빛 수레 괴물을 쓰러뜨리고 장터의 등불을 켜요.', place: 'selenia_vault'),
    ],
    arrive: [
      ('barkan', '허허! 기다렸네, 각성자 양반. 여기가 내 상단의 장터… 였던 곳이지.'),
      ('barkan', '흑등 상회 놈들이 빛을 병에 담아 팔면서 장터 불이 다 꺼졌네. 내 도끼, 다시 들어 볼까.'),
      ('lian', '바르칸 씨가 함께하면 든든해요. 주점에서 데려갈 동료로 고를 수 있어요.'),
    ],
    talk: [
      ('eni', '바르칸 어르신! 살아 계셨군요. 장부는… 장부는 제가 다 지켰어요.'),
      ('eni', '흑등 상회가 등불의 빛을 병에 담아 가져갔어요. 그 뒤로 장터 불이 하나둘 꺼졌죠.'),
      ('kaspar', '…손님이 많군. 빛이 필요하면 언제든 흑등 상회로. 값은 넉넉히 준비해 두시고.'),
      ('barkan', '카스파르…! 저 여우 같은 놈. 내 상단 수레도 저놈 짓이었어.'),
      ('eni', '금고 열쇠 조각이 광산 쪽에 흩어져 있다는 소문이 있어요. 조심하세요, 요즘 도둑이 많아요.'),
    ],
    eventPlace: 'selenia_mine',
    eventLabel: '지갑을 훔친 아이 쫓기',
    eventFoes: [MonsterId.koboldMiner, MonsterId.koboldMiner],
    eventLines: [
      '코볼트를 쫓아내자, 지갑을 든 고양이 귀 소녀가 꼼짝없이 붙잡혔어요.',
      '니아: 「…놔! 상회에 갚을 빚이 있단 말이야. 너희가 뭘 알아!」',
    ],
    choice: RChoice(
      '지갑 도둑 니아',
      ROption('hand', '상회에 넘기기', '흑등 상회에 넘겨 빚을 갚게 해요. 장터 규칙은 규칙이에요.', [
        ('nia', '…그래, 넘겨. 어차피 다들 그랬으니까.'),
        ('oscar', '상회가 아이를 데려갔어요. 금고 안쪽으로요. …저는 아무것도 못 봤어요.'),
        ('barkan', '흠… 저 아이, 금고에서 다시 보게 될 것 같군.'),
      ], gold: 150),
      ROption('free', '보내 주기', '지갑만 돌려받고 보내 줘요. 저 아이도 사정이 있을 거예요.', [
        ('nia', '…정말 보내 주는 거야? 바보 아냐? …고마워.'),
        ('nia', '이거, 금고 암호야. 빚 대신 훔쳐 둔 거. 나도 같이 갈래. 상회에 진 빚, 이제 내가 갚을 차례야.'),
      ], tickets: 1),
    ),
    floors: [
      FloorInfo(1, '금고 입구', [MonsterId.livingArmor]),
      FloorInfo(2, '장부 창고', [MonsterId.orcMerc, MonsterId.koboldMiner]),
      FloorInfo(3, '용병 막사', [MonsterId.orcCaptain], boss: true),
      FloorInfo(4, '빛 병 보관실', [MonsterId.livingArmor, MonsterId.gargoyle]),
      FloorInfo(5, '수레 무덤', [MonsterId.ashCart], boss: true, lamp: true),
    ],
    floorStories: [
      '금고 문에 수십 개의 자물쇠. 그중 하나는 바르칸 상단 문양이에요.',
      '장부가 산더미예요. 「빛 한 병 — 금화 300」. 값이 매일 올랐어요.',
      '용병 막사 벽에 감긴 눈 표식이 그려져 있어요. 흑등 상회와 다른 누군가가 거래했어요.',
      '빈 병이 줄지어 있어요. 병마다 작은 빛 찌꺼기가 남아 반짝여요.',
      '수레바퀴가 잿빛에 엉겨 있어요. 미나 할머니의 수레 바퀴 자국도 보여요.',
    ],
    normals: [MonsterId.orcMerc, MonsterId.koboldMiner, MonsterId.gargoyle, MonsterId.livingArmor],
    lampLines: [
      '잿빛 수레 괴물이 무너지자 빼앗긴 수레들이 하나둘 제 모습으로 돌아와요.',
      '금고 안쪽에서 장부 한 권이 떨어져요. 「잿빛 맹세단과의 거래」. 카스파르는 이미 떠났어요.',
      '등불에 빛을 바치자, 꺼져 있던 장터의 가게들이 차례로 불을 켜요.',
    ],
    lampUnlocks: [
      '칭호 「장터의 등불지기」',
      '모집권 5장',
      '장터의 가게가 다시 열려요 · 경매장',
      '이 지역 몬스터가 현실 지도에도 가끔 나와요',
      '대장간 「보스 장비」 탭에 「장터의 저울 도끼」',
      '다음 지역 「엘로윈 숲」으로 가는 길',
    ],
    lampTitle: TitleId.seleniaLamp,
    quests: [
      RQuest(id: 'sel_ledger', giver: 'eni', title: '흩어진 장부', kind: RQKind.hunt, place: 'selenia_caravan', target: 3,
          ask: '습격당한 수레 세 대에 장부 조각이 남아 있을 거예요. 오크 용병들이 지키고 있어요.',
          task: '대상의 길에서 오크 용병을 물리치고 장부 조각 찾기', line: '수레 밑에서 장부 조각을 찾았어요',
          done: '세 조각이 다 모였어요! 이제 흑등 상회가 뭘 빼앗았는지 다 적을 수 있어요.'),
      RQuest(id: 'sel_forge', giver: 'grum', title: '꺼진 화덕', kind: RQKind.hunt, place: 'selenia_mine', target: 2,
          ask: '코볼트 녀석들이 내 화덕돌을 광산으로 가져갔다. 둘만 혼내 주면 내놓을 거다.',
          task: '버려진 광산에서 코볼트 광부를 물리치고 화덕돌 되찾기', line: '코볼트가 화덕돌 하나를 놓고 갔어요',
          done: '…따뜻하군. 화덕이 다시 숨을 쉰다. 고맙다.'),
      RQuest(id: 'sel_secret', giver: 'oscar', title: '상회의 비밀 장부', kind: RQKind.floor, place: 'selenia_vault', target: 2,
          ask: '…저 대신 금고 2층 장부 창고에서 빨간 끈 장부 하나만 가져다주실래요? 아무도 모르게요.',
          task: '지하 금고 2층 장부 창고까지 가기', line: '빨간 끈이 묶인 장부를 찾았어요',
          done: '이 장부… 「다음은 숲」. 맹세단이 숲으로 간다는 뜻일까요? 조심하세요.'),
      RQuest(id: 'sel_lullaby', giver: 'mir', title: '별가루 자장가', kind: RQKind.hunt, place: 'selenia_stardust', target: 3,
          ask: '골짜기 가고일들이 별가루를 깔고 앉아 있단다. 셋만 쫓아내고 별가루를 모아 다오.',
          task: '별가루 골짜기에서 가고일을 물리치며 별가루 모으기', line: '가고일 밑에서 별가루를 주웠어요',
          done: '그래, 이 소리야. 별가루가 노래하는 소리. …광맥은 골짜기 끝 바위틈에 있단다.'),
      RQuest(id: 'sel_nia', ally: StoryAlly.nia, title: '카스파르의 빚 문서', kind: RQKind.floor, place: 'selenia_vault', target: 4,
          ask: '니아: 금고 4층에 내 빚 문서가 있어. 그걸 태워야 진짜 자유야.',
          task: '지하 금고 4층 빛 병 보관실까지 가기', line: '니아가 빚 문서를 찾아 불태웠어요',
          done: '니아: …다 탔다. 이제 아무한테도 안 빌렸어. 고마워. 내 그림자 급소, 이제 너희를 위해 쓸게.'),
      RQuest(id: 'sel_barkan', ally: StoryAlly.barkan, title: '상단의 깃발', kind: RQKind.walk, place: 'selenia_town', target: 5000,
          ask: '바르칸: 장터 한가운데에 미나 할매 깃발을 다시 꽂고 싶네. 장터를 한 바퀴 같이 걸어 주겠나?',
          task: '깃발을 들고 5,000보 걷기', line: '',
          done: '바르칸: 허허! 깃발이 바람을 탔군. 미나 할매가 봤으면 좋아했을 거야. 내 분노, 이제 제대로 쓰겠네.'),
    ],
    hidden: RHidden(
      place: 'selenia_vein',
      name: '별가루 광맥',
      locked: '미르 할머니의 자장가 이야기를 들으면 길을 찾을지도 몰라요.',
      unlockBy: 'sel_lullaby',
      lines: [
        '바위틈 안쪽, 별가루가 강물처럼 흐르는 광맥이 나와요.',
        '그때, 광맥을 지키던 고대 금속 거인이 천천히 일어나요.',
      ],
      boss: MonsterId.metalColossus,
      title: TitleId.stardustFinder,
    ),
    gear: [EquipBase.seleniaWeapon, EquipBase.seleniaHead, EquipBase.seleniaBody, EquipBase.seleniaHands, EquipBase.seleniaFeet, EquipBase.seleniaAcc],
    uniques: [EquipBase.uniqGrumHammer, EquipBase.uniqBlackLantern, EquipBase.uniqStardustBoots],
    uniqueStories: {
      EquipBase.uniqGrumHammer: '드워프 그럼이 화덕 앞에서 쓰던 망치. 두드릴수록 단단해진다.',
      EquipBase.uniqBlackLantern: '흑등 상회 빛 가게의 등불. 이제는 누구에게나 공짜로 비춘다.',
      EquipBase.uniqStardustBoots: '별가루가 묻은 장화. 걸을 때마다 작게 반짝인다.',
    },
    uniqueEffects: {
      EquipBase.uniqGrumHammer: '강화 단계가 높을수록 피해가 더 들어가요',
      EquipBase.uniqBlackLantern: '이기면 금화가 조금 더 나와요',
      EquipBase.uniqStardustBoots: '걸으면 가끔 별가루를 주워요',
    },
    weapon: EquipBase.seleniaAxe,
    weaponMat: MaterialId.cartWheel,
    weaponElement: Element.metal,
    joins: {StoryAlly.barkan: 'arrive', StoryAlly.nia: 'choice:free|floor:3'},
    shop: [ShopItem.healSmall, ShopItem.manaSmall, ShopItem.ironShard],
    shopMore: [ShopItem.heal, ShopItem.mana, ShopItem.jobMana, ShopItem.hardWood],
    shopDark: true,
  );

  // ═════════════ 지역 3 「엘로윈 숲」 (대지 · Lv.25)

  static const elowin = RegionContent(
    region: Region.elowin,
    town: 'assets/images/town_elowin.webp',
    townName: '잎사귀 마을',
    dungeonName: '고목의 뿌리 미궁',
    dungeonBg: 'assets/images/bg_dungeon_elowin.webp',
    residents: [
      RResident('arbel', '아르벨', '나무지기', '포포가 돌아왔구나. 그리고 너는… 빛 냄새가 나는 손님이군. 잎사귀 마을에 어서 오게.',
          ['숲은 천 년을 기다릴 줄 안다. 하지만 이번엔 너무 오래 잠들었어.', '잎이 회색인 건 빛이 없어서가 아니다. 누군가 뿌리에 독을 넣었지.', '의뢰판의 일은 다 숲의 일이다.'],
          afterLamp: '잎이 다시 초록이야. 숲이 깨어났어. 고맙네, 손님.'),
      RResident('momo', '모모', '요정', '포포?! 포포다! …흥, 늦었잖아! 얼마나 기다렸는데!',
          ['포포랑 나는 같은 꽃에서 태어났어.', '포포한테 편지를 썼는데, 부칠 곳이 없었어.', '숲이 깨어나면 제일 먼저 꽃 화관을 만들 거야.'],
          afterLamp: '봐, 봐! 꽃이 피었어! 포포랑 화관 만들러 갈 거야!'),
      RResident('doto', '도토', '다람쥐 수인 약초 상인', '도토리 하나에 약초 하나! …라고 하고 싶은데, 요즘은 약초가 귀해서요.',
          ['겨울 도토리를 거미들한테 다 빼앗겼어요.', '약초는 버섯 언덕 쪽이 좋아요. 거미만 없으면요.', '포포 님 약초밭 이야기는 저도 들었어요!'],
          afterLamp: '약초가 쑥쑥 자라요! 가게에 물건이 넘쳐 나요!'),
      RResident('ella', '엘라', '드라이어드', '(엘라는 말없이 고개를 숙여요. 손끝에서 작은 잎이 돋아요.)',
          ['(엘라가 숲 깊은 곳을 가리켜요.)', '(엘라가 감긴 눈 모양을 땅에 그려요.)', '(엘라가 조용히 웃어요.)'],
          afterLamp: '(엘라가 처음으로 소리 내어 말해요.) 「…고마워.」', face: 'npc_ellaDryad'),
    ],
    mains: [
      (title: '숲으로', text: '포포와 함께 잿빛 덩굴 숲길로 들어가요.', place: 'elowin_vinepath'),
      (title: '잎사귀 마을', text: '나무지기 아르벨에게 숲이 잠든 까닭을 들어요.', place: 'elowin_town'),
      (title: '잿빛 항아리', text: '숲길 깊은 곳에서 잿빛 항아리를 지키는 것들을 물리쳐요.', place: 'elowin_vinepath'),
      (title: '고목의 뿌리 미궁', text: '뿌리 미궁 5층까지 내려가 독의 근원을 찾아요.', place: 'elowin_roots'),
      (title: '숲의 등불', text: '잿빛 고목을 쓰러뜨리고 숲의 등불을 켜요.', place: 'elowin_roots'),
    ],
    arrive: [
      ('popo', '여기예요, 여기! 제가 태어난 숲이에요! …잎이 다 회색이네요.'),
      ('popo', '저도 같이 싸울게요! 치유는 자신 있어요! 주점에서 저를 데려갈 수 있어요!'),
    ],
    talk: [
      ('arbel', '숲이 잠든 건 빛이 모자라서가 아니다. 누군가 뿌리에 독을 넣었어.'),
      ('ella', '(엘라가 땅에 감긴 눈 모양을 그려요.)'),
      ('arbel', '이 표식… 숲길 깊은 곳에 잿빛 항아리가 묻혀 있다. 그걸 지키는 것들이 있지.'),
      ('popo', '감긴 눈… 발드린 요새에서 본 그 표식이에요!'),
    ],
    eventPlace: 'elowin_vinepath',
    eventLabel: '잿빛 항아리 부수기',
    eventFoes: [MonsterId.treant, MonsterId.woodWolf],
    eventLines: [
      '깨진 항아리 안에서 잿빛 물이 흘러나와요. 항아리 바닥에 새겨진 글씨.',
      '「잿빛 맹세단 — 빛은 빼앗는 자의 것」. 처음 듣는 이름이에요.',
      '아르벨: 「마지막 빛나는 씨앗이 남아 있다. 어디에 심을지는 네가 정해 다오.」',
    ],
    choice: RChoice(
      '마지막 씨앗',
      ROption('roots', '뿌리 아래 대지에', '숲 전체의 뿌리가 닿는 대지에 심어요. 숲이 천천히, 깊게 깨어나요.', [
        ('arbel', '뿌리 아래라… 숲 전체가 그 씨앗을 나눠 마시겠군. 좋은 선택이다.'),
        ('popo', '땅이 따뜻해졌어요! 숲 전체가 숨 쉬는 게 느껴져요!'),
      ], tickets: 2),
      ROption('village', '마을 한가운데에', '잎사귀 마을 한가운데에 심어요. 마을부터 빠르게 살아나요.', [
        ('momo', '마을에 꽃이 피었어! 포포, 봐! 우리 꽃이야!'),
        ('doto', '약초가 벌써 돋았어요! 가게에 물건이 늘겠어요!'),
      ], gold: 200),
    ),
    floors: [
      FloorInfo(1, '뿌리 입구', [MonsterId.woodWolf]),
      FloorInfo(2, '이끼 회랑', [MonsterId.treant, MonsterId.dryad]),
      FloorInfo(3, '거미줄 방', [MonsterId.spiderQueen], boss: true),
      FloorInfo(4, '독 웅덩이', [MonsterId.giantSpider, MonsterId.treant]),
      FloorInfo(5, '고목의 심장', [MonsterId.ashElder], boss: true, lamp: true),
    ],
    floorStories: [
      '뿌리마다 잿빛 실이 감겨 있어요. 누군가 일부러 감아 둔 것 같아요.',
      '이끼 사이에 작은 꽃자리 하나. 포포가 「여기서 태어났어요」라고 속삭여요.',
      '거미줄에 맹세단 망토 조각이 걸려 있어요.',
      '독 웅덩이 둘레에 빈 항아리가 줄지어 있어요.',
      '고목의 심장이 느리게 뛰어요. 잿빛 맥박이에요.',
    ],
    normals: [MonsterId.treant, MonsterId.giantSpider, MonsterId.dryad, MonsterId.woodWolf],
    lampLines: [
      '잿빛 고목이 쓰러지자 뿌리를 감던 잿빛 실이 풀려요.',
      '포포가 약초밭에서 키운 씨앗을 고목 자리에 심어요. 순식간에 새싹이 돋아요.',
      '등불에 빛을 바치자, 회색 잎이 차례로 초록으로 물들어요. 숲이 깨어나요.',
    ],
    lampUnlocks: [
      '칭호 「숲의 등불지기」',
      '모집권 5장',
      '이 지역 몬스터가 현실 지도에도 가끔 나와요',
      '대장간 「보스 장비」 탭에 「숲지기의 덩굴 지팡이」',
      '다음 지역 「모르발 왕도」로 가는 길',
    ],
    lampTitle: TitleId.elowinLamp,
    quests: [
      RQuest(id: 'elo_trees', giver: 'arbel', title: '시든 나무 세 그루', kind: RQKind.hunt, place: 'elowin_vinepath', target: 3,
          ask: '숲길에 잿빛 항아리가 셋 더 묻혀 있다. 트렌트들이 미쳐서 지키고 있지.',
          task: '잿빛 덩굴 숲길에서 항아리 부수기', line: '잿빛 항아리 하나를 부쉈어요',
          done: '세 그루가 다시 숨을 쉰다. 고맙네.'),
      RQuest(id: 'elo_letter', giver: 'momo', title: '기다린 편지', kind: RQKind.hunt, place: 'elowin_spring', target: 1,
          ask: '포포한테 쓴 편지를 연못에 떨어뜨렸어. 드라이어드가 가져가 버렸어!',
          task: '멈춘 샘물 연못에서 드라이어드에게 편지 되찾기', line: '젖은 편지를 되찾았어요',
          done: '…이걸 포포한테 줘. 아니, 내가 줄래! 흥!'),
      RQuest(id: 'elo_acorn', giver: 'doto', title: '겨울 도토리', kind: RQKind.hunt, place: 'elowin_mushroom', target: 3,
          ask: '버섯 언덕 거미들이 겨울 도토리 저장고를 차지했어요. 셋만 쫓아내 주세요!',
          task: '버섯 안개 언덕에서 거대 거미 물리치기', line: '도토리 저장고 하나를 되찾았어요',
          done: '도토리다! 이번 겨울은 걱정 없어요! 가게도 다시 열 수 있겠어요!'),
      RQuest(id: 'elo_witness', giver: 'ella', title: '말 없는 증언', kind: RQKind.boss, place: 'elowin_roots', target: 1,
          ask: '(엘라가 뿌리 미궁을 가리키고, 거미 모양을 그려요.)',
          task: '뿌리 미궁 3층 거미 여왕 쓰러뜨리기', line: '거미 여왕을 쓰러뜨리자 엘라가 그림을 그려요',
          done: '(엘라가 맹세단 복장을 자세히 그려 줘요. 감긴 눈 망토, 그리고 왕관을 쓴 그림자 하나.)'),
      RQuest(id: 'elo_popo', ally: StoryAlly.popo, title: '다시 핀 첫 꽃', kind: RQKind.walk, place: 'elowin_town', target: 5000,
          ask: '포포: 제가 태어난 꽃자리에 꽃을 피우고 싶어요! 꽃은 걸음을 먹고 자라요!',
          task: '꽃자리를 돌보며 5,000보 걷기', line: '',
          done: '포포: 피었다! 피었어요! …고마워요. 이제 숲의 깨어남, 진짜로 쓸 수 있어요!'),
    ],
    hidden: RHidden(
      place: 'elowin_mosspond',
      name: '모스의 연못',
      locked: '모모가 연못 이야기를 알고 있을지도 몰라요.',
      unlockBy: 'elo_letter',
      lines: [
        '이끼에 덮인 오래된 연못. 영웅 펫 모스가 지키던 곳이에요.',
        '수면이 갈라지며 잿빛에 물든 고대 거북이 떠올라요.',
      ],
      boss: MonsterId.ashTortoise,
      title: TitleId.mossFriend,
      pet: PetSpecies.turtle,
      petLine: '모스가 연못에 발을 담그더니 오래오래 물을 바라봐요. …여기가 모스의 집이었어.',
    ),
    gear: [EquipBase.elowinWeapon, EquipBase.elowinHead, EquipBase.elowinBody, EquipBase.elowinHands, EquipBase.elowinFeet, EquipBase.elowinAcc],
    uniques: [EquipBase.uniqMomoWreath, EquipBase.uniqArbelDagger, EquipBase.uniqElderHeart],
    uniqueStories: {
      EquipBase.uniqMomoWreath: '모모가 포포를 기다리며 엮은 화관. 시들지 않는다.',
      EquipBase.uniqArbelDagger: '나무지기 아르벨의 잎새 단검. 덩굴이 잡은 것을 놓치지 않는다.',
      EquipBase.uniqElderHeart: '깨어난 고목의 심장 조각. 따뜻하게 뛴다.',
    },
    uniqueEffects: {
      EquipBase.uniqMomoWreath: '싸움 중 가끔 HP가 조금 차요',
      EquipBase.uniqArbelDagger: '묶인 적에게 피해가 더 들어가요',
      EquipBase.uniqElderHeart: '걸으면 약초밭이 조금 빨리 자라요',
    },
    weapon: EquipBase.elowinStaff,
    weaponMat: MaterialId.elderBark,
    weaponElement: Element.earth,
    joins: {StoryAlly.popo: 'arrive'},
    shop: [ShopItem.healSmall, ShopItem.herb, ShopItem.herbSeed],
    shopMore: [ShopItem.heal, ShopItem.manaSmall, ShopItem.mana, ShopItem.purifyIncense],
  );

  // ═════════════ 지역 4 「모르발 왕도」 (어둠 · Lv.27)

  static const morval = RegionContent(
    region: Region.morval,
    town: 'assets/images/town_morval.webp',
    townName: '왕도 아랫마을',
    dungeonName: '잿빛 왕좌의 탑',
    dungeonBg: 'assets/images/bg_dungeon_morval.webp',
    residents: [
      RResident('king', '잿빛 왕', '빛을 나누는 왕', '…각성자. 다리 저편에서 너를 만났지. 그때 너는 나를 멈췄다. 이번엔 내가 빛을 나누는 걸 지켜봐 다오.',
          ['빛은 쥐면 꺼지고, 나누면 번진다. 늦게 알았지.', '백성 한 집 한 집에 빛을 나르고 있다. 걸음이 많이 드는 일이야.', '세라… 그 아이 얼굴을 볼 면목이 없구나.'],
          afterLamp: '왕도의 등불이 켜졌다. 이번엔 빼앗은 빛이 아니다.', face: 'npc_ashKingRestored'),
      RResident('howden', '하우든', '늙은 시종장', '전하를 끝까지 섬긴 것이 제 자랑입니다. 의뢰가 있으시면 제게 말씀하십시오.',
          ['전하께서 빛을 나누신 뒤로, 아랫마을에 불이 하나씩 켜집니다.', '폐허에 옛 왕국 그림이 흩어져 있을 겁니다.', '오르벤… 그 이름은 입에 담고 싶지 않군요.'],
          afterLamp: '왕도에 등불이… 살아서 이 날을 봅니다.'),
      RResident('lucy', '루시', '꽃 파는 소녀', '전하가 저한테 제일 먼저 빛을 나눠 주셨어요! 이 꽃, 그 빛으로 핀 거예요!',
          ['꽃 사세요! 빛꽃은 밤에도 반짝여요!', '호수 쪽 꽃들은 다 시들었어요. 안개 때문에요.', '세라 언니는 무섭게 생겼는데 착해요!'],
          afterLamp: '꽃이 다 살아났어요! 오늘은 다 공짜예요!'),
      RResident('marco', '마르코', '맹세단을 나온 사제', '…저는 맹세단이었습니다. 감긴 눈 망토를 벗은 지 얼마 안 됐죠.',
          ['오르벤은 빛을 모아 무언가를 하려 합니다. 무엇인지는 끝내 몰랐지만.', '지하 묘지에 맹세단 장부가 숨겨져 있습니다.', '용서받을 수 있을까요. 저 같은 사람도.'],
          afterLamp: '오르벤이 성소로 갔습니다. 마지막 불을 노리고 있어요.'),
    ],
    mains: [
      (title: '빛을 나누는 왕', text: '무너진 성벽 밖 폐허를 지나 왕도에 들어가요.', place: 'morval_ruins'),
      (title: '왕과 세라', text: '아랫마을에서 빛을 나누는 왕과 다시 만나요.', place: 'morval_town'),
      (title: '맹세단의 그림자', text: '지하 묘지에서 맹세단 광신도들을 쫓아내요.', place: 'morval_crypt'),
      (title: '잿빛 왕좌의 탑', text: '왕좌의 탑 5층까지 올라가 오르벤의 흔적을 쫓아요.', place: 'morval_tower'),
      (title: '왕도의 등불', text: '잿빛 근위대장을 쓰러뜨리고 왕도의 등불을 켜요.', place: 'morval_tower'),
    ],
    arrive: [
      ('sera', '…여기가 내가 버리고 떠난 왕도다. 돌아올 줄은 몰랐다.'),
      ('sera', '방패는 내가 든다. 주점에서 나를 데려가라. 이번엔 끝까지 지키겠다.'),
    ],
    talk: [
      ('king', '세라. …돌아왔구나.'),
      ('sera', '전하. 저는 검을 내려놓고 떠났습니다. 그 일을 사과하지는 않겠습니다.'),
      ('king', '사과할 사람은 나다. 엘라라는 드라이어드가 그린 그림을 보았다. 이 망토, 이 감긴 눈.'),
      ('king', '오르벤… 내게 빼앗으라고 속삭인 자. 내 곁의 사제였다. 그자가 맹세단의 우두머리다.'),
      ('marco', '오르벤은 지하 묘지에 장부를 숨겼습니다. 광신도들이 지키고 있어요.'),
    ],
    eventPlace: 'morval_crypt',
    eventLabel: '묘지의 광신도 쫓기',
    eventFoes: [MonsterId.cultZealot, MonsterId.cultZealot],
    eventLines: [
      '광신도들이 흩어지자, 세라가 왕의 묘비 앞에 멈춰 서요.',
      '세라: 「…전하를 용서해야 할까. 아직 모르겠다.」',
    ],
    choice: RChoice(
      '세라와 왕',
      ROption('help', '용서하도록 돕기', '세라 곁에서 왕의 이야기를 함께 들어요. 용서는 혼자 하기 어려우니까요.', [
        ('sera', '…함께 들어 주겠나. 그렇다면, 한 번 더 전하의 이야기를 듣겠다.'),
        ('king', '세라. 고맙다. 이 망토를 너의 벗에게 주마. 나눔의 망토다.'),
      ], unique: EquipBase.uniqKingCloak),
      ROption('wait', '스스로 정하게 두기', '세라가 스스로 정할 때까지 기다려요. 그 마음은 세라의 것이에요.', [
        ('sera', '…기다려 주겠다고? 그래, 내 마음은 내가 정한다. 탑을 오르며 생각하겠다.'),
        ('king', '…그래. 세라는 늘 스스로 길을 찾았지.'),
      ], tickets: 2),
    ),
    floors: [
      FloorInfo(1, '탑 아래 문', [MonsterId.vampireBat]),
      FloorInfo(2, '망령의 계단', [MonsterId.wraith, MonsterId.ghoul]),
      FloorInfo(3, '맹세단 제단', [MonsterId.cultPriests], boss: true),
      FloorInfo(4, '근위대 회랑', [MonsterId.cultZealot, MonsterId.wraith]),
      FloorInfo(5, '왕좌의 방', [MonsterId.ashCaptain], boss: true, lamp: true),
    ],
    floorStories: [
      '탑 문에 왕실 문장과 감긴 눈 표식이 겹쳐 그려져 있어요.',
      '계단마다 근위대원의 이름이 새겨져 있어요. 세라가 손끝으로 하나씩 짚어요.',
      '제단 위에 빈 병이 가득해요. 빼앗은 빛을 모으던 곳이에요.',
      '회랑 벽에 세라의 옛 방패 자국이 남아 있어요.',
      '왕좌는 비어 있어요. 오르벤은 이미 떠났어요.',
    ],
    normals: [MonsterId.vampireBat, MonsterId.wraith, MonsterId.ghoul, MonsterId.cultZealot],
    lampLines: [
      '근위대장의 눈빛이 잠깐 돌아와요. 「세라… 미안하다.」 그리고 잿빛이 흩어져요.',
      '엘리엘이 병에 모아 둔 빛을 꺼내요. 「빼앗지 않고 나누는 빛. 이게 제 답이에요.」',
      '등불에 빛을 붓자, 왕도 아랫마을 집집마다 불이 켜져요.',
    ],
    lampUnlocks: [
      '칭호 「왕도의 등불지기」',
      '모집권 5장',
      '이 지역 몬스터가 현실 지도에도 가끔 나와요',
      '대장간 「보스 장비」 탭에 「근위의 달그림자 검」',
      '다음 지역 「아우렐 성소」로 가는 길',
    ],
    lampTitle: TitleId.morvalLamp,
    quests: [
      RQuest(id: 'mor_album', giver: 'howden', title: '왕의 사진첩', kind: RQKind.hunt, place: 'morval_ruins', target: 3,
          ask: '폐허에 빛을 잃기 전 왕국 그림 세 장이 흩어져 있을 겁니다. 박쥐들이 둥지를 틀었지요.',
          task: '무너진 성벽 밖 폐허에서 왕국 그림 찾기', line: '박쥐 둥지 아래에서 그림 한 장을 찾았어요',
          done: '…이 그림. 전하께서 웃고 계시던 때입니다. 고맙습니다.'),
      RQuest(id: 'mor_flower', giver: 'lucy', title: '빛을 받은 꽃', kind: RQKind.hunt, place: 'morval_lake', target: 2,
          ask: '호수 꽃들이 다 시들었어요. 맑은 물만 있으면 살릴 수 있어요! 구울들이 물가를 막고 있어요.',
          task: '잿빛 안개 호수에서 구울을 쫓고 맑은 물 뜨기', line: '맑은 물을 한 병 떴어요',
          done: '꽃이 고개를 들었어요! 이 빛꽃, 언니한테 줄게요!'),
      RQuest(id: 'mor_ledger', giver: 'marco', title: '떠난 자의 장부', kind: RQKind.hunt, place: 'morval_crypt', target: 2,
          ask: '지하 묘지 깊은 곳에 오르벤의 장부가 있습니다. 광신도들이 지키고 있어요.',
          task: '왕실 지하 묘지에서 광신도를 물리치고 장부 찾기', line: '맹세단 장부 한 쪽을 찾았어요',
          done: '…「마지막 불을 꺼서 모든 빛을 하나로」. 오르벤은 성소의 마지막 불을 노립니다.'),
      RQuest(id: 'mor_homes', giver: 'king', title: '나눠진 빛 다섯 집', kind: RQKind.walk, place: 'morval_town', target: 6000,
          ask: '아랫마을 다섯 집에 빛을 나르고 싶다. 걸음이 많이 드는 일이니, 함께 걸어 다오.',
          task: '빛을 나르며 6,000보 걷기', line: '',
          done: '다섯 집에 불이 켜졌다. 나누니 번지는구나. 고맙다.'),
      RQuest(id: 'mor_sera', ally: StoryAlly.sera, title: '내려놓은 검', kind: RQKind.floor, place: 'morval_tower', target: 4,
          ask: '세라: 떠날 때 버린 검이 근위대 회랑에 있을 거다. 되찾아 다오.',
          task: '왕좌의 탑 4층 근위대 회랑까지 가기', line: '세라의 옛 검을 찾았어요',
          done: '세라: …녹슬었지만 내 검이다. 이 검으로 이번엔 지키는 쪽에 서겠다. 용서의 빛, 이제 쓸 수 있다.'),
    ],
    hidden: RHidden(
      place: 'morval_stable',
      name: '근위대 마구간',
      locked: '하우든이 옛 근위대 이야기를 알고 있을지도 몰라요.',
      unlockBy: 'mor_album',
      lines: [
        '무너진 마구간. 근위대 짐승들이 묶여 있던 자리가 그대로예요.',
        '어둠 속에서 잿빛에 물든 근위대 짐승들이 일어나요.',
      ],
      boss: MonsterId.ashBeasts,
      title: TitleId.guardMemory,
      pet: PetSpecies.panther,
      petLine: '녹턴이 마구간 한가운데 앉아 낮게 울어요. 세라가 「녹턴, 너였구나」 하고 쓰다듬어요.',
    ),
    gear: [EquipBase.morvalWeapon, EquipBase.morvalHead, EquipBase.morvalBody, EquipBase.morvalHands, EquipBase.morvalFeet, EquipBase.morvalAcc],
    uniques: [EquipBase.uniqLucyFlower, EquipBase.uniqKingCloak, EquipBase.uniqMoonFang],
    uniqueStories: {
      EquipBase.uniqLucyFlower: '루시가 왕에게 받은 빛으로 피운 꽃. 밤에도 시들지 않는다.',
      EquipBase.uniqKingCloak: '빛을 나누기 시작한 왕의 망토. 곁에 선 이를 감싼다.',
      EquipBase.uniqMoonFang: '근위대 마구간의 짐승이 남긴 송곳니. 달밤에 빛난다.',
    },
    uniqueEffects: {
      EquipBase.uniqLucyFlower: '함께 다니는 동료가 싸움 중 가끔 HP가 조금 차요',
      EquipBase.uniqKingCloak: '회복 물약을 쓰면 동료도 함께 조금 회복해요',
      EquipBase.uniqMoonFang: '밤에 피해가 더 들어가요',
    },
    weapon: EquipBase.morvalSword,
    weaponMat: MaterialId.captainCrest,
    weaponElement: Element.dark,
    joins: {StoryAlly.sera: 'arrive'},
    shop: [ShopItem.healSmall, ShopItem.heal, ShopItem.manaSmall],
    shopMore: [ShopItem.mana, ShopItem.jobManaSmall, ShopItem.jobMana, ShopItem.tannedLeather],
  );

  // ═════════════ 지역 5 「아우렐 성소」 (불 · Lv.29)

  static const aurel = RegionContent(
    region: Region.aurel,
    town: 'assets/images/town_aurel.webp',
    townName: '순례자 천막촌',
    dungeonName: '여명의 근원',
    dungeonBg: 'assets/images/bg_dungeon_aurel.webp',
    residents: [
      RResident('naomi', '나오미', '순례자 우두머리', '맹세단에게 포위된 지 한 달이에요. 그래도 불은 꺼지지 않았어요. 테오 덕분이죠.',
          ['순례자는 불을 지키는 사람이에요. 칼은 서툴러요.', '순례길 표식돌이 다 쓰러졌어요.', '테오는 혼자서 마지막 불을 지켜 왔어요.'],
          afterLamp: '다섯 불이 이어졌어요. 순례길이 다시 열려요.'),
      RResident('tess', '테스', '불을 기록하는 필사공', '불은 기록되어야 해요. 언제 켜지고, 언제 꺼졌는지.',
          ['다섯 지역의 불씨를 모으면 기록이 완성돼요.', '첫 등불은 발드린에서 켜졌다고 적었어요.', '제 기록에 당신 이름도 있어요.'],
          afterLamp: '「다섯 등불이 다시 이어진 날」. 제 기록의 마지막 줄이에요.'),
      RResident('cord', '코르드', '용인 대장장이', '도르군? 하하, 그 꼬마가 아직 망치를 드는가. 내 제자였지.',
          ['등불 틀은 불을 담는 그릇이다. 틀이 깨지면 불도 흩어지지.', '내 망치는 용암 협곡에 떨어뜨렸다.', '도르군이 새 틀을 만들었다고? …그 녀석, 컸군.'],
          afterLamp: '도르군의 틀이 불을 담았다. 스승으로서 이보다 기쁜 날은 없다.'),
      RResident('pin', '핀', '순례자 아이', '테오 형 친구예요? 테오 형은요, 하나도 안 무서워해요!',
          ['테오 형이 저한테 부탁이 있대요.', '테오 형 엄마는 수프를 잘 끓인대요!', '저도 크면 문지기 할래요!'],
          afterLamp: '테오 형이 집에 간대요! 저도 언젠가 아르카에 놀러 갈래요!'),
    ],
    mains: [
      (title: '포위된 성소', text: '재가 내리는 순례길을 지나 순례자 천막촌에 도착해요.', place: 'aurel_pilgrim'),
      (title: '마지막 불의 문지기', text: '천막촌에서 혼자 불을 지키던 테오를 만나요.', place: 'aurel_town'),
      (title: '꺼져 가는 제단', text: '불꽃 제단을 노리는 맹세단 잿불 사제를 물리쳐요.', place: 'aurel_altar'),
      (title: '여명의 근원', text: '근원 5층까지 내려가 오르벤과 마주해요.', place: 'aurel_source'),
      (title: '마지막 불', text: '오르벤을 쓰러뜨리고 마지막 등불을 켜요.', place: 'aurel_source'),
    ],
    arrive: [
      ('teo', '…누구야? 맹세단이면 한 발짝도 못 들어와. —잠깐, 가렌 교관님?!'),
      ('garen', '테오! 이 녀석… 살아 있었구나! 하하! 신병 다섯 중 마지막이 여기 있었어!'),
      ('teo', '교관님, 다리가… 지팡이까지 짚고 여기까지 오셨어요? …같이 싸울게요. 주점에서 저를 불러 주세요.'),
    ],
    talk: [
      ('naomi', '테오는 한 달 동안 혼자 마지막 불을 지켰어요. 맹세단이 제단을 노리고 있어요.'),
      ('teo', '오르벤은 근원 깊은 곳에 있어. 모든 빛을 하나로 모아 자기 것으로 만들려고.'),
      ('cord', '등불 틀이 깨졌다. 불을 켜도 담을 그릇이 없어.'),
      ('pet', '도르군이 새 틀을 만들어 둔다고 했었어! 아르카에서 가져오자!'),
    ],
    eventPlace: 'aurel_altar',
    eventLabel: '제단을 노리는 잿불 사제 물리치기',
    eventFoes: [MonsterId.cultFlamePriest, MonsterId.koboldrake],
    eventLines: [
      '잿불 사제를 물리치자 제단의 불이 다시 일어서요.',
      '테오: 「이제 근원으로 가자. 오르벤을 끝내야 해.」',
    ],
    choice: RChoice(
      '쓰러진 오르벤',
      ROption('king', '왕에게 넘기기', '오르벤을 왕도로 데려가 왕이 판단하게 해요. 왕을 속인 죄는 왕이 물어야 해요.', [
        ('orben', '…왕에게라. 그래, 그분 앞에서 끝나는 것도 나쁘지 않군.'),
        ('king', '(편지) 오르벤은 내가 맡겠다. 벌이 아니라, 함께 빛을 나르게 하겠다.'),
      ], gold: 300),
      ROption('share', '빛을 나눠 주고 보내기', '오르벤에게도 빛 한 줌을 나눠 주고 보내요. 빛은 빼앗는 게 아니라 나누는 거니까요.', [
        ('orben', '…내게도 빛을? 빼앗지 않고 받는 빛은… 이렇게 따뜻한 것이었나.'),
        ('orben', '오르벤은 빛 한 줌을 쥐고 순례길 너머로 천천히 걸어가요.'),
      ], tickets: 3),
      afterLamp: true,
    ),
    floors: [
      FloorInfo(1, '불꽃 회랑', [MonsterId.salamander]),
      FloorInfo(2, '용암 다리', [MonsterId.ifrit, MonsterId.koboldrake]),
      FloorInfo(3, '용의 둥지', [MonsterId.youngRedDragon], boss: true),
      FloorInfo(4, '잿불 제단', [MonsterId.cultFlamePriest, MonsterId.ifrit]),
      FloorInfo(5, '근원의 심장', [MonsterId.orben, MonsterId.orbenAsh], boss: true, lamp: true),
    ],
    floorStories: [
      '벽마다 다섯 등불 그림이 새겨져 있어요. 다섯 번째가 이 근원이에요.',
      '용암 다리 아래로 빛 조각이 떠다녀요.',
      '어린 용의 목에 맹세단 목줄 자국이 남아 있어요.',
      '제단 위에 빛을 담은 병들이 줄지어 있어요. 오르벤이 모은 빛이에요.',
      '근원의 심장이 느리게 뛰어요. 그 앞에 오르벤이 서 있어요.',
    ],
    normals: [MonsterId.salamander, MonsterId.ifrit, MonsterId.koboldrake, MonsterId.cultFlamePriest],
    lampLines: [
      '오르벤이 무릎을 꿇어요. 잿빛이 걷히자 그는 그저 지친 노인이에요.',
      '도르군이 만든 새 등불 틀에 마지막 불을 담아요. 틀이 금빛으로 울려요.',
      '마지막 등불이 켜지자, 다섯 등불이 빛의 줄로 이어져요. 저쪽 세계 하늘이 밝아져요.',
    ],
    lampUnlocks: [
      '칭호 「성소의 등불지기」',
      '모집권 5장',
      '이 지역 몬스터가 현실 지도에도 가끔 나와요',
      '대장간 「보스 장비」 탭에 「여명의 불꽃 활」',
      '다섯 지역을 자유롭게 오가요 · 「심층」',
    ],
    lampTitle: TitleId.aurelLamp,
    quests: [
      RQuest(id: 'aur_stones', giver: 'naomi', title: '순례길의 표식돌', kind: RQKind.hunt, place: 'aurel_pilgrim', target: 3,
          ask: '순례길 표식돌이 다 쓰러졌어요. 샐러맨더들이 둘레에 몰려 있어요.',
          task: '재가 내리는 순례길에서 표식돌 세우기', line: '표식돌 하나를 다시 세웠어요',
          done: '순례자들이 다시 길을 찾을 수 있겠어요. 고마워요.'),
      RQuest(id: 'aur_record', giver: 'tess', title: '다섯 불의 기록', kind: RQKind.walk, place: 'aurel_town', target: 8000,
          embers: true,
          ask: '다섯 지역의 작은 불씨를 모아 주세요. 지역에 들어서면 그곳 불씨가 저절로 모이고, 오가며 걸으면 기록이 채워져요.',
          task: '다섯 지역에 들어가 불씨 모으기 · 오가며 8,000보 걷기', line: '',
          done: '다섯 불씨가 모였어요. 기록이 완성됐어요. 당신 이름을 맨 위에 적을게요.'),
      RQuest(id: 'aur_hammer', giver: 'cord', title: '스승의 망치', kind: RQKind.hunt, place: 'aurel_lava', target: 2,
          ask: '용암 협곡에 내 망치를 떨어뜨렸다. 이프리트들이 망치를 장난감 삼고 있지.',
          task: '용암 협곡에서 이프리트를 물리치고 망치 찾기', line: '망치 손잡이가 보여요',
          done: '내 망치다! …도르군에게 전해 다오. 이 망치를 물려주겠다고.'),
      RQuest(id: 'aur_pin', giver: 'pin', title: '테오 형의 부탁', kind: RQKind.boss, place: 'aurel_source', target: 1,
          ask: '테오 형이 그러는데요, 근원 3층 용을 풀어 주고 싶대요. 나쁜 용이 아니래요!',
          task: '여명의 근원 3층 새끼 레드 드래곤 쓰러뜨리기', line: '새끼 용의 목줄이 끊어졌어요',
          done: '용이 날아갔대요! 테오 형이 웃었대요! 형 웃는 거 처음 봤대요!'),
      RQuest(id: 'aur_teo', ally: StoryAlly.teo, title: '어머니의 수프', kind: RQKind.walk, place: 'aurel_town', target: 3000,
          ask: '테오: 어머니께 돌아가서 수프를 같이 끓이고 싶어. 아르카까지 함께 걸어 줄래?',
          task: '테오와 아르카로 3,000보 걷기', line: '',
          done: '테오: 어머니 수프, 여전히 최고야. …고마워. 문을 지킨 창, 이제 너희를 위해 들게.'),
    ],
    hidden: RHidden(
      place: 'aurel_nest',
      name: '잿불새의 둥지',
      locked: '코르드가 협곡 위 둥지 이야기를 알고 있을지도 몰라요.',
      unlockBy: 'aur_hammer',
      lines: [
        '협곡 꼭대기, 재 속에서 따뜻한 둥지가 빛나요. 잿불새 엠버가 태어난 곳이에요.',
        '하늘이 붉게 물들며 불사조 어미가 내려앉아요.',
      ],
      boss: MonsterId.phoenixMother,
      title: TitleId.phoenixHonor,
      pet: PetSpecies.phoenix,
      petLine: '엠버가 어미 불사조에게 날아가 날개를 비벼요. 어미가 각성자에게 고개를 숙여요.',
    ),
    gear: [EquipBase.aurelWeapon, EquipBase.aurelHead, EquipBase.aurelBody, EquipBase.aurelHands, EquipBase.aurelFeet, EquipBase.aurelAcc],
    uniques: [EquipBase.uniqTeoCloak, EquipBase.uniqNaomiStaff, EquipBase.uniqPhoenixCharm],
    uniqueStories: {
      EquipBase.uniqTeoCloak: '테오가 마지막 불 앞에서 두르던 문지기 망토. 재 냄새가 난다.',
      EquipBase.uniqNaomiStaff: '나오미가 순례길을 걸을 때 짚던 지팡이. 지칠 때 힘을 준다.',
      EquipBase.uniqPhoenixCharm: '불사조 어미가 남긴 깃털 부적. 쓰러져도 다시 일어나게 한다.',
    },
    uniqueEffects: {
      EquipBase.uniqTeoCloak: '잿빛 몬스터에게 받는 피해가 줄어요',
      EquipBase.uniqNaomiStaff: '걸을 때 여정 기력이 조금 더 차요',
      EquipBase.uniqPhoenixCharm: '3막 싸움에서 쓰러져도 한 번 일어나요',
    },
    weapon: EquipBase.aurelBow,
    weaponMat: MaterialId.undyingEmber,
    weaponElement: Element.fire,
    joins: {StoryAlly.teo: 'arrive'},
    shop: [ShopItem.healSmall, ShopItem.heal, ShopItem.manaSmall, ShopItem.mana],
    shopMore: [ShopItem.jobManaSmall, ShopItem.jobMana, ShopItem.purifyIncense],
  );
}
