import 'element_rules.dart';
import 'equipment_rules.dart';
import 'materials.dart';
import 'monsters.dart';
import 'town_rules.dart';

/// 3막 지역 1 「발드린 관문」 내용 (묶음 53 #243): 야영지 · 주민 · 퀘스트 · 지하 요새 · 큰 고르기 ·
/// 바람의 굴 · 등불 · 이름 있는 장비. 숫자는 개발이 정한 숨은 값(처음 값, 테스트로 조정).

enum Resident { volk, hanna, pipi, orum }

class ResidentInfo {
  const ResidentInfo(this.id, this.name, this.role, this.first, this.lines);

  final Resident id;
  final String name;
  final String role;

  /// 처음 만날 때 한마디
  final String first;

  /// 평소 대사 (번갈아)
  final List<String> lines;

  String get face => 'assets/images/npc_${id.name}.webp';
}

/// 서브 · 동료 퀘스트
enum SideQuest { beacon, child, stall, dew, roster }

class SideQuestInfo {
  const SideQuestInfo({
    required this.id,
    required this.giver,
    required this.title,
    required this.ask,
    required this.task,
    required this.target,
    required this.done,
    this.place,
    this.garen = false,
  });

  final SideQuest id;

  /// 맡기는 사람 (가렌 동료 퀘스트는 null)
  final Resident? giver;
  final String title;

  /// 맡길 때 한마디
  final String ask;

  /// 일지에 보이는 할 일
  final String task;
  final int target;

  /// 끝내고 보고할 때 한마디
  final String done;

  /// 「그 장소로 가기」
  final String? place;
  final bool garen;
}

/// 지하 요새 층 (싸움 · 갈림길)
class FloorInfo {
  const FloorInfo(this.n, this.name, this.foes, {this.boss = false, this.lamp = false});

  final int n;
  final String name;
  final List<MonsterId> foes;

  /// 3층 중간 보스 · 5층 등불 보스
  final bool boss;
  final bool lamp;
}

/// 갈림길 (싸움 / 보물·함정 / 이야기)
enum Branch { fight, chest, story }

class BaldrinRules {
  BaldrinRules._();

  static const String town = 'assets/images/town_baldrin.webp';
  static const String dungeonBg = 'assets/images/bg_dungeon_baldrin.webp';
  static const String denBg = 'assets/images/bg_baldrin_windden.webp';

  // ───────────── 주민 4

  static const List<ResidentInfo> residents = [
    ResidentInfo(
      Resident.volk,
      '볼크',
      '초소장',
      '다리를 건너왔다고? …서른 해 동안 저 다리가 놓이길 기다렸다. 나는 볼크, 남은 문지기들의 초소장이다.',
      [
        '문지기는 줄었어도 초소는 아직 서 있다. 그거면 됐다.',
        '의뢰판에 붙은 일은 다 급한 일이다. 하나씩만 맡아 다오.',
        '요새 쪽 바람이 차다. 잿빛이 또 기어 나올 모양이야.',
      ],
    ),
    ResidentInfo(
      Resident.hanna,
      '한나',
      '천막 여관 주인',
      '어머, 아르카에서 왔어요? 그럼 마르타는… 마르타는 잘 지내요? 우리 둘이 같은 빵집에서 일했었거든요.',
      [
        '천막이라도 잠은 푹 잘 수 있어요. 담요는 넉넉하답니다.',
        '배고프면 말해요. 수프는 늘 끓고 있으니까.',
        '마르타 수프 맛을 아는 사람이 오다니, 꿈만 같아요.',
      ],
    ),
    ResidentInfo(
      Resident.pipi,
      '피피',
      '꼬마 노점상',
      '손님이다! 진짜 손님! 피피 노점에 어서 오세요! …아직 물건은 조금밖에 없지만요.',
      [
        '물약 필요해요? 피피가 제일 싸게 줄게요!',
        '언젠간 아르카 잡화상만큼 큰 가게를 차릴 거예요.',
        '오늘 장사 첫 손님은 언제나 형이에요. 아니, 누나인가?',
      ],
    ),
    ResidentInfo(
      Resident.orum,
      '오름',
      '눈먼 노병',
      '발소리가 낯설구먼. …빛 냄새가 나. 자네, 다리 저편에서 왔지?',
      [
        '눈은 잃었어도 귀는 남았지. 요새가 우는 소리가 들려.',
        '등불이 켜져 있던 시절엔 이 관문이 노래를 불렀다네.',
        '젊은 문지기 테오… 그 녀석은 겁이 없었어.',
      ],
    ),
  ];

  static ResidentInfo resident(Resident r) => residents[r.index];

  // ───────────── 메인 흐름 (① 첫 싸움은 3막 틀)

  static const List<({String title, String text, String? place})> mains = [
    (title: '잿빛 들판에서 첫 싸움', text: '다리를 건너 잿빛 들판에서 저쪽 세계의 몬스터와 처음 싸워요.', place: 'baldrin_ashplain'),
    (title: '초소장의 이야기', text: '피난민 야영지의 초소장 볼크에게 이야기를 들어요.', place: 'baldrin_town'),
    (title: '성벽길의 흔적', text: '무너진 성벽길에서 테오가 남긴 흔적을 찾아요.', place: 'baldrin_wallroad'),
    (title: '문지기 지하 요새', text: '요새 5층까지 내려가 잿빛이 어디서 오는지 알아내요.', place: 'baldrin_fort'),
    (title: '관문의 등불', text: '잿빛 빈 갑주를 쓰러뜨리고 꺼진 등불을 다시 켜요.', place: 'baldrin_fort'),
  ];

  /// ② 볼크 이야기 (메인 ① 뒤 야영지에서)
  static const List<(String, String)> volkTalk = [
    ('volk', '등불이 꺼진 뒤로 요새에서 잿빛이 기어 나온다. 처음엔 안개였지, 이젠 짐승 꼴을 하고 나와.'),
    ('volk', '문지기들은 거의 다 쓰러졌어. 남은 건 나와 늙은이들, 그리고 피난민들뿐이다.'),
    ('garen', '테오라는 녀석을 아시오? 갈색 곱슬머리, 창을 든 문지기 말이오.'),
    ('volk', '…테오. 성벽길로 마지막 순찰을 나갔다가 돌아오지 않았다. 그쪽을 찾아보게.'),
  ];

  /// ③ 성벽길: 해골 문지기 둘을 물리치면 편지
  static const List<MonsterId> wallFoes = [MonsterId.skeletonGuard, MonsterId.skeletonGuard];
  static const String letterLine = '무너진 초소 돌 틈에 봉투 하나가 끼어 있어요. 봉투에는 「어머니께」라고 적혀 있어요.';

  // ───────────── 큰 고르기 「테오의 편지」

  static const String choiceTitle = '테오의 편지';
  static const String choiceNote = '한 번 고르면 바꿀 수 없어요';
  static const ({String title, String text}) choiceMarta = (
    title: '마르타에게 바로',
    text: '편지를 부치러 잠깐 아르카로 돌아가요. 이 편지는 어머니가 먼저 읽어야 해요.',
  );
  static const ({String title, String text}) choiceGaren = (
    title: '가렌에게 먼저',
    text: '가렌에게 먼저 보여 줘요. 문지기끼리만 아는 표시가 있을지도 몰라요.',
  );

  /// 마르타 쪽: 아르카 여관에서 (마르타 · 첫 펫)
  static const List<(String, String)> martaScene = [
    ('marta', '…이건, 테오 글씨야. 「어머니께」라니, 그 애가 이런 말을 다 쓰네.'),
    ('marta', '살아 있다는 거지? 저 다리 너머 어딘가에서. …됐어, 그거면 됐어.'),
    ('marta', '빈손으로 보낼 순 없지. 도시락 싸 줄게. 길에서 배곯지 말고, 그 애도 꼭 찾아 줘.'),
  ];

  /// 가렌 쪽: 편지 속 암호 → 숨은 무기고
  static const List<(String, String)> garenScene = [
    ('garen', '잠깐, 편지 귀퉁이의 이 점들… 문지기 신호다! 내가 가르친 거야.'),
    ('garen', '「셋째 탑 아래, 돌 넷」. 녀석, 비상 무기고를 숨겨 뒀군.'),
    ('garen', '이 창… 테오가 「혹시 몰라서」 하나 더 벼려 둔 거다. 네가 들고 가라. 녀석도 그걸 바랄 거다.'),
  ];

  /// 마르타의 도시락: 쓰면 여정 기력 +[lunchEnergy] (3개)
  static const int lunchCount = 3;
  static const int lunchEnergy = 40;
  static const String lunchImage = 'assets/images/item_martaLunch.webp';

  // ───────────── 지하 요새 5층

  static const List<FloorInfo> floors = [
    FloorInfo(1, '무너진 입구', [MonsterId.ogre]),
    FloorInfo(2, '문지기 막사', [MonsterId.skeletonGuard, MonsterId.goblinRaider]),
    FloorInfo(3, '사냥개 우리', [MonsterId.ashHounds], boss: true),
    FloorInfo(4, '무기고 회랑', [MonsterId.ogre, MonsterId.skeletonGuard]),
    FloorInfo(5, '등불의 방', [MonsterId.ashArmor], boss: true, lamp: true),
  ];

  /// 층마다 싸움 1~2번: 두 번째 싸움이 붙을 확률 (보스 층은 한 번)
  static const double secondFight = 0.4;

  /// 갈림길 「보물·함정」: 보물 상자일 확률 (아니면 함정 HP -[trapHp])
  static const double chestChance = 0.7;
  static const double trapHp = 0.12;
  static const int chestGoldMin = 30;
  static const int chestGoldMax = 70;
  static const double chestGear = 0.5;

  /// 갈림길 「이야기」: 경험치 조금
  static const int storyExp = 20;

  /// 층 이야기 (갈림길 「이야기」를 고르면)
  static const List<String> floorStories = [
    '벽에 문지기들의 이름이 새겨져 있어요. 맨 아래, 아직 마르지 않은 글씨로 「테오」.',
    '부서진 침상마다 작은 등잔이 놓여 있어요. 문지기들은 밤새 불을 지켰던 모양이에요.',
    '사냥개 우리 뒤편, 물방울이 떨어지는 소리가 들려요. 어딘가 샘이 있는 것 같아요.',
    '녹슨 창들 사이에 새 창 자루 하나. 누군가 최근에 여기를 다녀갔어요.',
    '등불의 방 문에 낯선 표식이 그려져 있어요. 잿빛으로 그린, 감긴 눈 모양.',
  ];

  /// 보스 세기 (같은 레벨 필드 몬스터 대비): 중간 보스 · 등불 보스 · 숨은 보스
  static const double midHp = 3.5, midAtk = 1.5;
  static const double lampHp = 6.0, lampAtk = 1.7;
  static const double denHp = 5.0, denAtk = 1.8;

  /// 보스 보상 (경험치는 필드 몬스터 한 마리 기준 배수)
  static const int midExp = 6, lampExp = 12, denExp = 10;
  static const int bossGoldMin = 80, bossGoldMax = 150;

  /// 등불을 켤 때 · 던전 처음 끝낼 때 모집권
  static const int lampTickets = 5;
  static const int dungeonTicket = 1;

  /// 빈 갑주 조각 (지역 무기 재료): 처음 등불 보스 3 · 그 뒤 1
  static const int plateFirst = 3;
  static const int plateAgain = 1;

  static const List<String> lampLines = [
    '빈 갑주가 무너지자, 갑옷 안에서 잿빛으로 그린 표식이 떨어져요. 감긴 눈 하나.',
    '볼크: 「…맹세단. 잿빛을 부리는 놈들이 따로 있었단 말인가.」',
    '등불에 빛을 바치자, 관문 전체가 천천히 밝아져요.',
  ];

  /// 등불을 켜면 열리는 것 (화면에 차례로)
  static const List<String> lampUnlocks = [
    '칭호 「관문의 등불지기」',
    '모집권 5장',
    '이 지역 몬스터가 현실 지도에도 가끔 나와요',
    '대장간 「보스 장비」 탭에 「관문의 빛 창」',
    '다음 지역 「셀레니아 대장터」로 가는 길',
  ];

  // ───────────── 숨은 장소 「바람의 굴」

  /// 은빛 늑대의 언덕에서 이길 때 은빛 털이 나올 확률 (못 받았을 때만)
  static const double furChance = 0.35;
  static const String furLine = '하피 둥지 옆에서 반짝이는 은빛 털 한 줌을 주웠어요.';
  static const String lumiFur = '이 털… 바람이야! 우리 바람이 저 너머에서 기다리던 곳이 있었구나. 언덕 위 바람 부는 굴, 거기일 거야. 꼭 가 봐!';
  static const List<String> denLines = [
    '굴 깊은 곳에 마른풀로 엮은 둥지가 있어요. 누군가 아주 오래 기다린 자리예요.',
    '그때, 잿빛에 물든 늑대들이 둥지를 에워싸요.',
  ];
  static const String denWolfLine = '바람이 둥지 냄새를 맡더니 고개를 들어 길게 울어요. …여기가 바람의 자리였어.';

  // ───────────── 서브 퀘스트 4 + 가렌 동료 퀘스트

  static const List<SideQuestInfo> sides = [
    SideQuestInfo(
      id: SideQuest.beacon,
      giver: Resident.volk,
      title: '침묵한 봉화대',
      ask: '들판 봉화대 세 곳이 꺼졌다. 고블린 놈들이 기름을 훔쳐 간 탓이지. 다시 불을 붙여 다오.',
      task: '잿빛 들판에서 고블린 무리를 물리치고 봉화대에 불 붙이기',
      target: 3,
      done: '봉화가 셋 다 올랐군. 서른 해 만에 들판이 안심하고 잠들겠다.',
      place: 'baldrin_ashplain',
    ),
    SideQuestInfo(
      id: SideQuest.child,
      giver: Resident.hanna,
      title: '돌아오지 않는 아이',
      ask: '천막 아이 하나가 어젯밤 언덕에 올라갔다가 돌아오지 않았어요. 하피 둥지 쪽이에요. 제발…',
      task: '은빛 늑대의 언덕 하피 둥지에서 아이 구하기',
      target: 1,
      done: '아이고, 이 녀석! …고마워요, 정말 고마워요. 오늘 수프는 제가 대접할게요.',
      place: 'baldrin_wolfhill',
    ),
    SideQuestInfo(
      id: SideQuest.stall,
      giver: Resident.pipi,
      title: '꼬마 상인의 첫 장사',
      ask: '피피도 진짜 가게를 차리고 싶어요! 서로 다른 재료 세 가지만 구해 주면 진열대를 만들 수 있어요.',
      task: '서로 다른 재료 3가지를 피피에게 건네기',
      target: 3,
      done: '진열대 완성! 이제 피피 노점에 물건이 더 많아져요. 첫 단골은 당연히 형이에요!',
      place: 'baldrin_town',
    ),
    SideQuestInfo(
      id: SideQuest.dew,
      giver: Resident.orum,
      title: '빛 이슬',
      ask: '요새 3층 뒤에 숨은 샘이 있었지. 등불 빛이 고여 이슬이 맺히던 곳이야. 한 방울만 가져다주겠나.',
      task: '지하 요새 3층 뒤 숨은 샘에서 빛 이슬 떠 오기',
      target: 1,
      done: '…따뜻하군. 눈은 못 떠도 빛이 느껴져. 옛날 문지기들은 이 빛으로 밤을 지켰다네.',
      place: 'baldrin_fort',
    ),
    SideQuestInfo(
      id: SideQuest.roster,
      giver: null,
      title: '신병 다섯의 명부',
      ask: '가렌: 내 마지막 신병 다섯… 테오 말고 넷이 성벽길에서 쓰러졌다. 이름표라도 찾아 주고 싶다.',
      task: '무너진 성벽길에서 신병 넷의 이름표 찾기',
      target: 4,
      done: '가렌: …넷 다 찾았군. 이제 다섯 이름을 함께 부를 수 있다. 고맙다. 내 마지막 호령, 이제 너희와 함께 쓰겠다.',
      place: 'baldrin_wallroad',
      garen: true,
    ),
  ];

  static SideQuestInfo side(SideQuest q) => sides[q.index];

  /// 서브 퀘스트 보상: 모집권 1 + 금화
  static const int sideTickets = 1;
  static const int sideGold = 80;

  /// 피피에게 건넬 재료 (종류마다 개수)
  static const int stallEach = 2;

  /// 하피 둥지 싸움 (하피 둘)
  static const List<MonsterId> nestFoes = [MonsterId.harpy, MonsterId.harpy];

  // ───────────── 천막 여관 · 피피의 노점

  /// 하루 한 번 여정 기력 조금
  static const int innEnergy = 30;

  static const List<ShopItem> stall = [ShopItem.healSmall, ShopItem.manaSmall, ShopItem.herb];
  static const List<ShopItem> stallMore = [ShopItem.heal, ShopItem.mana, ShopItem.purifyIncense];

  // ───────────── 이름 있는 장비 (고유) · 지역 무기 · 세트

  static const List<EquipBase> uniques = [
    EquipBase.uniqVolkHelm,
    EquipBase.uniqTeoSpear,
    EquipBase.uniqWindPendant,
  ];

  static const Map<EquipBase, String> stories = {
    EquipBase.uniqVolkHelm: '서른 해 동안 관문을 지킨 투구. 금이 간 자리마다 이야기가 있다.',
    EquipBase.uniqTeoSpear: '"혹시 몰라서" 숨겨 둔 창. 테오다운 준비성이다.',
    EquipBase.uniqWindPendant: '은빛 털을 엮은 목걸이. 바람이 기다리던 언덕의 냄새가 난다.',
  };

  static const Map<EquipBase, String> uniqueEffects = {
    EquipBase.uniqVolkHelm: '막을 때 가끔 빛을 내뿜어 적이 멈춰요',
    EquipBase.uniqTeoSpear: '잿빛 몬스터에게 피해가 더 들어가요',
    EquipBase.uniqWindPendant: '펫 게이지가 조금 빨리 차요',
  };

  /// 이름 있는 장비가 나올 확률: 등불 보스 · 중간 보스 · 보물 상자 · 숨은 보스(처음은 꼭)
  static const double uniqLamp = 0.04;
  static const double uniqMid = 0.02;
  static const double uniqChest = 0.01;
  static const double uniqDen = 0.05;

  /// 숨은 효과 (숨김)
  static const double volkFlash = 0.25;
  static const double teoAsh = 0.15;
  static const int windFaster = 1;

  /// 「발드린 문지기」 세트 (숨김): 2개 잿빛에게 받는 피해 ↓ · 4개 주는 피해 ↑ · 6개 둘 다 더
  static const double set2Taken = 0.05, set4Dealt = 0.08, set6Taken = 0.10, set6Dealt = 0.15;

  static const List<EquipBaseInfo> gearInfos = [
    EquipBaseInfo(
        id: EquipBase.uniqVolkHelm, name: '볼크의 금 간 투구', slot: EquipSlot.head,
        recipe: {}, reduce: 0.06, maxHp: 0.04, asset: 'uniq_volkHelm'),
    EquipBaseInfo(
        id: EquipBase.uniqTeoSpear, name: '테오의 예비 창', slot: EquipSlot.weapon,
        recipe: {}, attack: 0.17, crit: 0.03, asset: 'uniq_teoSpear'),
    EquipBaseInfo(
        id: EquipBase.uniqWindPendant, name: '바람의 은빛 목걸이', slot: EquipSlot.accessory,
        recipe: {}, maxHp: 0.08, evade: 0.03, asset: 'uniq_windPendant'),
    // 지역 무기: 대장간 「보스 장비」 탭 (등불을 켠 뒤)
    EquipBaseInfo(
        id: EquipBase.baldrinSpear, name: '관문의 빛 창', slot: EquipSlot.weapon,
        recipe: {MaterialId.hollowPlate: 3, MaterialId.ironIngot: 2},
        manaStones: 30, attack: 0.20, asset: 'equip_baldrinSpear'),
  ];

  /// 지역 무기 값 (금화)
  static const int spearGold = 600;
  static const Element spearElement = Element.light;

  /// 이 지역 일반 몬스터 (등불을 켜면 현실 지도에도 가끔)
  static const List<MonsterId> normals = [
    MonsterId.goblinRaider,
    MonsterId.skeletonGuard,
    MonsterId.harpy,
    MonsterId.ogre,
  ];

  /// 현실 지도 블록 몬스터 중 이 지역 몬스터가 될 비율 (등불 뒤)
  static const double realMapShare = 0.08;

  // ───────────── 아르카 마을 사람 새 대사 (등불 · 큰 고르기 뒤)

  static const List<String> martaAfterMarta = [
    '그 애 편지, 하루에 열 번은 읽어. 글씨가 닳겠어.',
    '도시락은 다 먹었니? 모자라면 또 싸 줄게.',
  ];
  static const List<String> martaAfterGaren = [
    '가렌한테 먼저 보였다며? …그래, 문지기끼리 아는 게 있겠지. 그래도 그 편지, 나한테도 꼭 보여 줘.',
  ];
  static const List<String> garenAfterGaren = [
    '테오 녀석 창은 잘 쓰고 있나? 그 녀석, 날 끝을 늘 반 치 길게 벼렸지.',
  ];
  static const List<String> garenAfterMarta = [
    '마르타에게 먼저 간 건 잘한 일이다. 어미가 먼저지. …나도 언젠가 그 편지를 보고 싶군.',
  ];
  static const List<String> afterLamp = [
    '관문 쪽 하늘이 밝아졌어. 다리 너머 첫 등불이 켜졌대!',
  ];
  static const String hartAfterLamp = '관문 몬스터들이 우리 쪽에도 보인다던데. 의뢰판에 그쪽 의뢰도 붙여 두지.';
  static const String lumiAfterDen = '바람 둥지를 찾았다며? …고마워. 언젠가 나도 그 언덕에 꼭 가 볼게.';
}
