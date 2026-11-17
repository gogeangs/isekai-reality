/// 결말 뒤 다른 각성자와의 만남 · 주점 · 리안 (묶음 51 #242) + 거래소 · 바르칸 (#229, 서버 전).
/// 숫자는 개발이 정한 숨은 값, 화면에는 문장만.
enum Meal { stew, honeyBread, skewer }

class MealInfo {
  const MealInfo(this.id, this.name, this.text, this.price);

  final Meal id;
  final String name;

  /// 효과 (문장만, 숫자 없음)
  final String text;

  /// 금화
  final int price;

  String get asset => 'assets/images/food_${id.name}.webp';
}

class TavernRules {
  TavernRules._();

  // ───────────── 만남 장면 (기획 #242 6줄 그대로)

  static const String sceneLights = 'assets/images/scene_meet_lights.webp';
  static const String sceneLian = 'assets/images/scene_meet_lian.webp';

  /// (리안이 말하는지, 대사). 1줄은 낯선 불빛들 그림, 2줄부터 리안 그림
  static const List<(bool, String)> meet = [
    (false, '…저기 불빛들, 우리 마을 사람들 게 아니야.'),
    (true, '역시 당신이구나. 탑에 불이 붙는 걸 보고 바로 달려왔어요.'),
    (true, '문이 부서져 있는 동안 틈이 각성자마다 따로 갈라져 있었거든요. 저는 제 쪽에서 혼자 분신만 쓰러뜨리고 있었고요.'),
    (true, '당신이 본체를 쓰러뜨려서 다리가 놓이고, 틈이 하나로 이어졌어요. …고마워요, 진심으로.'),
    (true, '이제 혼자 걸을 필요 없어요. 같이 걸을 사람은 제가 찾아 줄게요.'),
    (false, '…우리, 혼자가 아니었구나.'),
  ];

  /// 리안 그림으로 바뀌는 줄 (이 줄부터)
  static const int lianFrom = 1;

  /// 「새로 열렸어요」 카드
  static const String openedLine = '주점이 열렸어! 리안이 같이 걸을 사람을 찾아 준대.';

  // ───────────── 주점 기능

  static const String partyName = '파티';
  static const String partySoon = '준비 중';
  static const String partyLine = '같이 걸을 사람을 찾는 창구예요. 각성자들이 더 모이면 바로 열게요.';

  /// 한 끼 식사 (하루 한 번, 그날 자정까지 걸을 때만)
  static const List<MealInfo> meals = [
    MealInfo(Meal.stew, '고기 스튜', '오늘 걸으면 기력이 조금 더 차요', 60),
    MealInfo(Meal.honeyBread, '꿀빵', '오늘 걸으면 채집 자리를 조금 더 만나요', 60),
    MealInfo(Meal.skewer, '매운 꼬치', '오늘 사냥 경험치가 조금 더', 80),
  ];

  static MealInfo meal(Meal m) => meals[m.index];

  /// 고기 스튜: 1,000보마다 기력 (숨김)
  static const int stewMp = 3;

  /// 꿀빵: 그날 처음 자리 둘레에 더 생기는 채집 자리 수 · 거리 (숨김)
  static const int breadSpots = 2;
  static const double breadMinM = 150;
  static const double breadMaxM = 400;

  /// 매운 꼬치: 필드 사냥 경험치 배율 (숨김)
  static const double skewerExp = 1.15;

  /// 리안과 단짝: 식사 효과가 다음 날 새벽 이때까지 (숨김)
  static const int bestUntilHour = 6;

  /// 리안의 낡은 나침반: 식사 값 배율 (숨김)
  static const double compassPrice = 0.75;

  /// 리안의 배낭 매듭(장신구): 걸을 때 1,000보마다 기력 (숨김)
  static const int knotMp = 2;

  /// 바르칸의 동전 주머니: 이 걸음마다 금화 (숨김)
  static const int purseSteps = 2000;
  static const int purseGold = 5;

  // ───────────── 소문판 (하루 한 번, 게임이 만든 짧은 소문 · 가끔 쓸모 있는 귀띔)

  static const List<String> rumors = [
    '요즘 저녁에 하늘 섬이 자주 보인대요. 깃털은 챙겨 두는 게 좋겠죠?',
    '밤에 걸으면 낯선 몬스터를 만난다던데요. 조심해서 다녀요.',
    '어떤 각성자는 하루에 만 보를 걷고 와서 꿀빵을 세 개나 먹었대요. 저도 못 믿었어요.',
    '물가에서 채집하면 가끔 좋은 게 나온대요. 낚싯대는 챙겼죠?',
    '대장간 도르군 씨가 요즘 콧노래를 부른대요. 탑 등불 틀 덕분인가 봐요.',
    '포포 씨 밭에 빛나는 싹이 올라왔대요. 걸음을 많이 먹고 자란다나요.',
    '던전 보스가 요일마다 바뀐다는 거, 다들 알고 있죠? 토요일엔 번개가 시끄럽대요.',
    '알을 오래 품으면 귀한 펫이 나온다는 소문이 있어요. 진짜인지는… 저도 몰라요.',
    '수식어 붙은 몬스터는 위험하지만 그만큼 많이 준대요. 무리는 하지 마요.',
    '이른 아침에 걸으면 공기가 다르대요. 아침 빛을 모으는 사람도 있다던데요.',
    '조합 의뢰는 아침에 새로 붙는대요. 하르트 씨가 그러더라고요.',
    '하늘 섬의 수호자들은 악당이 아니래요. 누군가를 기다리는 거래요.',
    '새로 생긴 거래소 할아버지, 셈이 엄청 빠르대요. 흥정은 조심해요.',
    '같이 걸을 사람을 찾는 각성자가 점점 늘고 있대요. 곧 파티를 꾸릴 수 있을 거예요.',
  ];

  /// 그날 소문 (날마다 하나)
  static String rumorOf(String dayKey) {
    var h = 0;
    for (final c in dayKey.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return rumors[h % rumors.length];
  }

  static const String rumorAgain = '오늘 소문은 여기까지예요. 내일 또 들려줄게요.';
}
