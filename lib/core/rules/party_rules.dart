import 'materials.dart';
import 'name_rules.dart';
import 'monsters.dart';

/// 파티 (묶음 56 #236): 주점 「파티」 탭, 창구 리안. 최대 4명, 초대 코드로만.
/// 함께 걷기 · 응원 · 파티 보스 · 함께 사냥 · 파티 상점 · 꾸미기. 숫자는 숨은 값(테스트로 조정).
/// 판정(걸음 합계 · 보스 체력 · 함께 있어요)은 서버가 한다 (firebase/functions/src/rules.js 와 같은 값).
class PartyRules {
  PartyRules._();

  static const int maxMembers = 4;

  /// 함께 걷기 1인당 목표 (× 인원)
  static const List<int> walkPerHead = [30000, 70000, 100000];

  /// 파티 보스 (주마다 차례로)
  static const List<MonsterId> bosses = [
    MonsterId.partyGolem,
    MonsterId.partyHydra,
    MonsterId.partyWyvern,
    MonsterId.partyKraken,
  ];

  static MonsterId? bossOf(String id) {
    for (final b in bosses) {
      if (b.name == id) return b;
    }
    return null;
  }

  /// 보스마다 재료
  static MaterialId bossMat(MonsterId b) => switch (b) {
        MonsterId.partyHydra => MaterialId.hydraScale,
        MonsterId.partyWyvern => MaterialId.wyvernClaw,
        MonsterId.partyKraken => MaterialId.krakenPearl,
        _ => MaterialId.golemCore,
      };

  /// 한 판에 그 레벨이 보통 주는 피해 · 한 판 보스 체력(= 서버 한도)
  static int perFight(int level) => 900 + 140 * (level < 1 ? 1 : level);
  static int fightHp(int level) => perFight(level) * 3;

  /// 한 판은 정해진 턴 (넘으면 거기까지 준 피해만)
  static const int fightTicks = 40;

  /// 도전권: 3,000보마다 1장, 하루 3장
  static const int ticketSteps = 3000;

  /// 함께 있어요: 서버에 칸을 알리는 간격 · 효과가 이어지는 시간
  static const Duration nearPing = Duration(minutes: 3);
  static const Duration nearFor = Duration(minutes: 10);

  /// 함께 사냥: 경험치 조금 더 · 재료 가끔 하나 더
  static const double togetherExp = 1.1;
  static const double togetherMat = 0.3;

  /// 100m 칸 (서버 · 백업과 같은 크기)
  static const double cellLat = 0.0009;
  static const double cellLng = 0.001125;
  static (int, int) cellOf(double lat, double lng) =>
      ((lat / cellLat).floor(), (lng / cellLng).floor());

  // ───────────── 꾸미기: 깃발 문양 8 · 색 8 (처음엔 3개씩, 상점 · 상자로 더)

  static const List<String> emblems = [
    'sword',
    'paw',
    'lantern',
    'tower',
    'leaf',
    'star',
    'moon',
    'wing',
  ];
  static const List<String> emblemNames = ['검', '발자국', '등불', '탑', '잎', '별', '달', '날개'];
  static const List<int> colors = [
    0xFFC0392B,
    0xFF2E86DE,
    0xFF27AE60,
    0xFFE1B12C,
    0xFF8E44AD,
    0xFF16A085,
    0xFFE17055,
    0xFF34495E,
  ];
  static const int freeEmblems = 3;
  static const int freeColors = 3;
  static String emblemAsset(int i) => 'assets/images/flag_emb_${emblems[i]}.webp';
  static const String flagAsset = 'assets/images/flag_party.webp';

  // ───────────── 보상

  /// 재료 꾸러미 (흔한 재료 셋 × 2)
  static const List<MaterialId> bundleMats = [
    MaterialId.hardWood,
    MaterialId.ironShard,
    MaterialId.herb,
    MaterialId.tannedLeather,
    MaterialId.slimeJelly,
    MaterialId.twig,
  ];

  // ───────────── 파티 상점 (발자국 표)

  static const int emblemPrice = 30;
  static const int colorPrice = 20;
  static const List<PartyShopItem> shop = [
    PartyShopItem('gold', '금화 300', 20, {'gold': 300}),
    PartyShopItem('mana', '마석 5', 20, {'manaStone': 5}),
    PartyShopItem('bundle', '재료 꾸러미', 25, {'matBundle': 1}),
    PartyShopItem('recruit', '모집권', 40, {'recruit': 1}, weekLimit: 2),
  ];

  // ───────────── 「동행」 세트 (파티 보스 재료로 대장간에서)

  static Map<MaterialId, int> partCost(int slotIndex) => switch (slotIndex) {
        0 => const {
            MaterialId.golemCore: 2,
            MaterialId.hydraScale: 2,
            MaterialId.wyvernClaw: 2,
            MaterialId.krakenPearl: 2,
          },
        1 => const {MaterialId.golemCore: 3, MaterialId.wyvernClaw: 2},
        2 => const {MaterialId.golemCore: 3, MaterialId.krakenPearl: 3},
        3 => const {MaterialId.hydraScale: 3, MaterialId.wyvernClaw: 2},
        4 => const {MaterialId.wyvernClaw: 3, MaterialId.hydraScale: 2},
        _ => const {MaterialId.krakenPearl: 3, MaterialId.hydraScale: 2},
      };
  static int partGold(int slotIndex) => const [800, 400, 600, 300, 300, 400][slotIndex];

  /// 세트 효과 (숨은 값): 2개 파티 보스 피해 · 4개 함께 있을 때 경험치 · 6개 파티 보스 피해 더
  static const double set2Boss = 0.08;
  static const double set4Together = 0.05;
  static const double set6Boss = 0.18;

  // ───────────── 글 (리안)

  static const String loginLine = '파티는 로그인한 각성자끼리 맺어요. 설정에서 로그인하면 바로 함께할 수 있어요!';
  static const String noPartyLine = '같이 걸을 사람이 있나요? 파티를 만들거나, 받은 초대 코드로 들어가 보세요.';
  static const String restrictedLine = '지금은 함께하는 기능을 쓸 수 없어요. 자세한 건 설정 → 문의로 물어봐 주세요.';
  static const String offlineLine = '파티 소식을 불러오지 못했어요. 인터넷을 확인하고 다시 눌러 주세요.';
  static const String nearOn = '파티원이 가까이 있어요! 함께 잡은 몬스터는 조금 더 보상을 줘요.';
  static const String sameDevice = '같은 휴대폰으로 로그인한 계정끼리는 한 파티에 들어갈 수 없어요.';
  static const String stepsElsewhere = '오늘 이 휴대폰 걸음은 다른 계정에 먼저 쌓였어요.';
  static String cheerFrom(String name) => '$name님이 응원했어요! 다음 1,000보가 더 크게 쌓여요.';
  static String inviteText(String name, String code) =>
      '아르카 파티 「$name」에 초대할게요! ${inviteLink(code)} 를 누르거나, 주점 → 파티 → 「초대 코드로 들어가기」에 $code 를 넣어 주세요.';

  /// 묶음 57: 초대 링크 (앱이 있으면 앱이 열리고, 없으면 스토어 안내 페이지)
  static const linkHost = 'api-ujbfnvvalq-du.a.run.app';
  static String inviteLink(String code) => 'https://$linkHost/join/$code';

  /// 묶음 60: 길드 초대 링크 (https://…/join/g/ABC234 · arca://join/g/ABC234)
  static String guildInviteLink(String code) => 'https://$linkHost/join/g/$code';
  static String guildInviteText(String name, String code) =>
      '아르카 길드 「$name」에 함께해요! ${guildInviteLink(code)} 를 누르거나, 마을 → 길드 회관 → 「초대 코드」에 $code 를 넣어 주세요.';

  static String? guildCodeFromLink(Uri u) {
    final segs = u.pathSegments.where((s) => s.isNotEmpty).toList();
    String? c;
    if (u.scheme == 'arca' && u.host == 'join' && segs.length == 2 && segs.first == 'g') c = segs[1];
    if (segs.length == 3 && segs[0] == 'join' && segs[1] == 'g' && (u.host == linkHost || u.scheme == 'arca')) c = segs[2];
    c = c?.toUpperCase();
    return c != null && RegExp(r'^[A-Z0-9]{6}$').hasMatch(c) ? c : null;
  }

  /// 초대 링크에서 코드 (https://…/join/ABC234 · arca://join/ABC234). 아니면 null
  static String? codeFromLink(Uri u) {
    final segs = u.pathSegments.where((s) => s.isNotEmpty).toList();
    String? c;
    if (u.scheme == 'arca' && u.host == 'join' && segs.isNotEmpty) c = segs.first;
    if (segs.length == 2 && segs.first == 'join' && (u.host == linkHost || u.scheme == 'arca')) c = segs[1];
    c = c?.toUpperCase();
    return c != null && RegExp(r'^[A-Z2-9]{6}$').hasMatch(c) ? c : null;
  }

  /// 서버 오류 → 화면 글
  static String errorText(String code) => switch (code) {
        'already_in_party' => '이미 파티에 있어요. 한 번에 한 파티만 함께할 수 있어요.',
        'no_party' => '그 초대 코드의 파티를 찾지 못했어요.',
        'full' => '파티가 가득 찼어요. 4명까지 함께할 수 있어요.',
        'same_device' => sameDevice,
        'not_owner' => '파티장만 할 수 있어요.',
        'bad_name' => '쓸 수 없는 이름이에요. 12자 안에서 다른 이름을 써 주세요.',
        'banned_word' => NameRules.bannedMessage,
        'cheered_today' => '오늘은 이미 응원했어요. 내일 또 응원해 주세요.',
        'no_ticket' => '도전권이 없어요. 3,000보마다 한 장 생겨요.',
        'defeated' => '이번 주 보스는 이미 쓰러졌어요!',
        'claimed' => '이미 받았어요.',
        'not_yet' => '아직 받을 수 없어요.',
        'no_damage' => '이번 주 보스에게 피해를 준 사람만 받을 수 있어요.',
        'restricted' => restrictedLine,
        'login_required' => loginLine,
        _ => offlineLine,
      };
}

class PartyShopItem {
  const PartyShopItem(this.id, this.name, this.price, this.gifts, {this.weekLimit = 0});

  final String id;
  final String name;
  final int price;
  final Map<String, int> gifts;

  /// 일주일에 살 수 있는 개수 (0 = 제한 없음)
  final int weekLimit;
}
