import '../format.dart';

/// 마을 사람 (묶음 35): 시설마다 한 사람, 모두 틈에 걸린 저쪽 세계 사람
/// 묶음 51: 리안(주점, 먼저 온 각성자) · 바르칸(거래소, 다리를 건너온 상인) — 결말 뒤
enum Npc { marta, mina, dorgun, eliel, hart, sera, lumi, garen, popo, lian, barkan }

class NpcInfo {
  const NpcInfo({
    required this.id,
    required this.name,
    required this.role,
    required this.first,
    required this.lines,
  });

  final Npc id;
  final String name;
  final String role;

  /// 처음 만날 때 한 줄 (시설마다 한 번)
  final String first;

  /// 막(1·2·3=결말 뒤)마다 평소 대사 두 줄 (번갈아). 1막 대사가 없으면 2막 것
  final Map<int, List<String>> lines;

  String get asset => 'assets/images/npc_${id.name}.webp';
}

/// 마을 규칙 (묶음 35)
class VillageRules {
  VillageRules._();

  // ───────────── 묶음 38 #213: 시설 안 정령 띠 대신 마을 사람이 안내
  static const innFull = '기운은 벌써 가득하네. 그래도 푹 쉬면 휴식 보너스를 챙겨 줄게.';
  static const innResting = '푹 쉬는 중이구나. 다른 일 보고 와도 돼. 다 쉬면 알려 줄게.';
  static const innRested = '오늘은 벌써 푹 쉬었지? 지치면 언제든 또 와.';
  static const innGuide = '오늘 하루 고생 많았어. 여기서 쉬면 HP랑 기력이 가득 찰 거야.';
  static const shopGuide = '몬스터를 잡으면 마석이 나와요. 저한테 팔면 금화로 바꿔 드려요!';
  static const smithyFree = '첫 무기는 값을 받지 않겠다. 마음에 드는 걸 골라라.';

  /// 대장간 탭 안내 (0 만들기 · 1 강화 · 2·3 수리·분해·가공 · 4 보스 장비)
  static String smithyGuide(int tab) => switch (tab) {
        0 => '몬스터 재료로 장비를 만든다. 귀한 재료를 넣으면 좋은 등급이 잘 나오지.',
        1 => '강화는 실패해도 부서지지 않는다. 마석과 금화만 든다.',
        // 묶음 40 #220: 탭 6개 (만들기 · 강화 · 수리 / 속성 · 재료 가공 · 보스 장비)
        2 => '닳은 건 고쳐 써라. 안 쓰는 건 분해하면 재료로 돌려주지.',
        3 => '속성을 입히면 날이 달라진다. 망치가 빗나가도 코어는 돌려주지.',
        4 => '광석은 녹여야 쓸 만해진다. 남는 재료를 가져와라.',
        _ => '보스 조각과 보스 재료로 세트 장비를 만든다. 모아 입을수록 힘이 깨어나지.',
      };

  /// 연금술 공방 탭 안내
  static String alchemyGuide(int tab) => switch (tab) {
        0 => '넣는 순서가 딱 맞거나 귀한 재료를 쓰면 품질이 좋아져요!',
        1 => '한 번 만든 물약은 여기 적혀요. 쪽지를 읽으면 재료도 알 수 있고요!',
        2 => '하위 재료 여러 개를 상위 재료로 바꿔 드릴게요.',
        _ => '남는 재료를 바꾸거나, 마석을 속성 마석으로 정제할 수 있어요.',
      };
  static const boardUrgent = '긴급 의뢰가 붙었네. 오늘 자정까지일세.';
  static const boardGuide = '오늘의 의뢰일세. 조합 의뢰는 수락해야 시작되네.';
  static const gardenGuide = '씨앗을 심으면 시간이 지나며 자라요! 앱을 꺼 둬도 자라요!';
  static const shelterGuide =
      '알은 둥지에서 내가 따뜻하게 봐 줄게. 원정에서 지친 애들은 여기서 쉬면 금방 나아!';

  /// 묶음 36 이름 바꿈 (예전 저장 키 → 새 키)
  static const renamed = {'toby': 'mina', 'bron': 'dorgun', 'ella': 'eliel'};

  /// 마을 탭 처음 소개 3줄 (이별 뒤면 첫 펫이 말하고 3번째 줄만 바뀜)
  static List<String> intro({String? departed}) => [
        '여기는 여명의 탑 아래 마을이야.',
        '문이 깨질 때 마을이 통째로 틈에 걸렸어. 그래서 어디서든 올 수 있어.',
        departed == null
            ? '저 탑에 다시 불을 켜는 게 내 오래된 소원이야.'
            : '저 탑에 다시 불을 켜는 게 $departed의 오래된 소원이었대.',
      ];

  /// 이별 뒤 처음 마을에 들어갈 때 첫 펫 한마디
  static String afterFarewell(String departed) =>
      '${josa(departed, '이/가')} 열어 둔 마을 길은 이제 네 안에 있대.';

  /// 결말 뒤 처음 마을에 들어갈 때 (탑 불꽃이 켜지는 연출과 함께)
  static const String towerLit = '탑에 불이 켜졌어! 저 멀리 다리도 보여.';

  /// 마을이 처음 넓어질 때
  static const String wideLine = '마을이 많이 커졌어! 옆으로 끌어서 둘러봐.';

  /// 이 수부터 마을 그림을 좌우로 끌어서 둘러본다
  static const int wideFrom = 12;

  // ───────────── 묶음 44 #225: 안 열린 건물은 「짓고 있는 모습」

  /// 공사 중 그림이 있는 건물 (시설 이름)과 완공 레벨 (펫 쉼터는 첫 펫 Lv.11 기준)
  static const Map<String, int> buildLevels = {
    'smithy': 3,
    'board': 4,
    'alchemy': 7,
    'shelter': 11,
    'guild': 15,
    // 묶음 43 #228: Lv.10 터 닦기 · 11 뼈대 · 12 거의 완성 · 13 완공
    'training': 13,
    // 묶음 48 #230: Lv.6 터 닦기 · 7 뼈대 · 8 거의 완성 · 9 완공
    'garden': 9,
  };

  /// 공사 단계: 1 터 닦기(완공 3레벨 이상 전) · 2 뼈대(2레벨 전) · 3 거의 완성(바로 전 레벨)
  static int buildStage(int level, int openAt) {
    final gap = openAt - level;
    if (gap <= 1) return 3;
    if (gap == 2) return 2;
    return 1;
  }

  /// 시설 이름 → 화면 이름
  static String facilityName(String f) => switch (f) {
        'inn' => '여관',
        'shop' => '잡화상',
        'smithy' => '대장간',
        'board' => '의뢰 게시판',
        'alchemy' => '연금술 공방',
        'guild' => '조합',
        'shelter' => '펫 쉼터',
        'training' => '훈련장',
        'garden' => '약초밭',
        'tavern' => '주점',
        'market' => '거래소',
        _ => f,
      };

  /// 완공 연출 때 마을 배지 한마디
  static String builtLine(String name) => '${josa(name, '이/가')} 다 지어졌어!';

  static const List<NpcInfo> npcs = [
    NpcInfo(
      id: Npc.marta,
      name: '마르타',
      role: '여관 주인',
      first: '어머, 새 손님이네! 틈에 걸린 뒤로 손님은 너뿐이야. 푸욱 쉬어.',
      lines: {
        1: ['밥은 먹고 다니는 거지? 쉬는 것도 모험이야.', '오늘도 많이 걸었구나. 침대는 늘 데워 놨어.'],
        2: ['안개가 창문까지 왔어… 넌 꼭 무사히 돌아와야 해.', '요즘 밤이 길어. 그래도 네가 오면 불을 하나 더 켜.'],
        3: ['탑에 불이 켜진 걸 봤니? 오늘은 내가 한턱낼게!', '다리 너머 손님이 올지도 몰라. 방을 더 치워 둬야겠어.'],
      },
    ),
    NpcInfo(
      id: Npc.mina,
      name: '미나',
      role: '잡화상 주인',
      first: '어서 와요, 어서 와! 틈에 걸려도 장사는 해야죠. 뭐든 있어요… 거의!',
      lines: {
        1: ['셈은 제가 할게요, 빠르거든요!', '슬라임 젤리 팔 거 있어요? 요즘 찾는 사람이 많아요.'],
        2: ['안개 때문에 물건 들어오는 길이 막혔어요. 그래도 문은 안 닫아요!', '잿빛 몬스터 재료요? 으, 냄새는 나도 값은 쳐 드릴게요.'],
        3: ['다리가 생겼으니 저쪽 물건도 들어오겠죠? 벌써 신나요!', '단골손님께 감사의 뜻으로… 웃음은 공짜예요!'],
      },
    ),
    NpcInfo(
      id: Npc.dorgun,
      name: '도르군',
      role: '대장장이',
      first: '…각성자인가. 연장은 아껴 쓰도록.',
      lines: {
        1: ['망치는 거짓말을 안 한다.', '날이 무디면 마음도 무뎌진다. 손질해 둬라.'],
        2: ['잿빛 놈들 껍질이 단단하다. 날을 세워 두지.', '화덕 불이 약해졌다. 안개 탓이야.'],
        3: ['…탑의 불이 돌아왔군. 내 화덕도 다시 뜨겁다.', '네가 해냈다. 망치로 증명할 필요도 없지.'],
      },
    ),
    NpcInfo(
      id: Npc.eliel,
      name: '엘리엘',
      role: '연금술사',
      first: '어, 손님이다! 잠깐만요, 이거 터지기 전에… 아, 안녕하세요!',
      lines: {
        1: ['이 세계 약초는 향이 달라요! 하나만 더 연구해 볼게요.', '레시피요? 적어 뒀는데… 어디 뒀더라?'],
        2: ['잿빛 안개를 병에 담아 봤는데요, 병이 시무룩해졌어요.', '안개를 걷는 물약… 아직은 실패예요. 그래도 포기 안 해요!'],
        3: ['탑의 불빛을 담으면 어떤 물약이 될까요? 궁금해요!', '다리 너머 약초도 보고 싶어요. 갈 때 꼭 불러 주세요!'],
      },
    ),
    NpcInfo(
      id: Npc.hart,
      name: '하르트',
      role: '게시판 주인',
      first: '자네가 새 각성자로군. 할 일은 저 게시판에 다 붙어 있네.',
      lines: {
        1: ['작은 의뢰부터 차근차근. 나도 그렇게 시작했지.', '우편은 받았나? 이 늙은이가 보낸 걸세.'],
        2: ['요즘 의뢰가 무거워졌어. 무리하지 말게.', '옛날 같았으면 나도 칼을 들었을 텐데… 자네를 믿네.'],
        3: ['게시판 쪽지가 다 웃는 얼굴이야. 자네 덕일세.', '다리 너머 의뢰도 곧 붙겠지. 은퇴는 미뤄야겠군.'],
      },
    ),
    NpcInfo(
      id: Npc.sera,
      name: '세라',
      role: '조합장',
      first: '조합에 온 걸 환영한다. 네 길은 네가 고르는 거다.',
      lines: {
        2: ['직업은 칭호가 아니라 약속이다. 잊지 마라.', '분신과 싸울 땐 서두르지 마라. 펫도 네 동료다.'],
        3: ['잘 싸웠다, 각성자. 조합의 이름으로 경의를 표한다.', '이제 조합도 다리 너머를 준비해야겠군.'],
      },
    ),
    NpcInfo(
      id: Npc.lumi,
      name: '루미',
      role: '쉼터 지기',
      first: '와아, 펫이다! 쓰다듬어도 돼? 난 루미야, 여기 쉼터 지기!',
      lines: {
        2: ['알은 내가 따뜻하게 봐 줄게. 걱정 마!', '원정에서 지고 온 애들은 여기서 푹 쉬면 금방 괜찮아져.'],
        3: ['탑이 켜지니까 애들이 다 신났어! 꼬리 흔드는 거 봐!', '다리 너머에도 펫 친구들이 있을까? 꼭 만나 보고 싶어!'],
      },
    ),
    // 묶음 43 #228: 훈련장 (Lv.13). 2막·결말 평소 대사는 개발 초안
    NpcInfo(
      id: Npc.garen,
      name: '가렌',
      role: '훈련 교관',
      first: '하르트 녀석이 말한 각성자가 너로군! 자세부터 보자!',
      lines: {
        2: ['자세가 무너지면 마음도 무너진다! 허리부터 펴라!', '이 다리로도 너 하나쯤은 가르칠 수 있다! 걱정 마라!'],
        3: ['탑에 불이 켜졌다! 오늘은 나도 지팡이를 내려놓고 싶구나!', '다리 너머로 갈 날이 머지않았다! 그날을 위해 단련해 둬라!'],
      },
    ),
    // 묶음 48 #230: 약초밭 (Lv.9). 평소 대사는 개발 초안
    NpcInfo(
      id: Npc.popo,
      name: '포포',
      role: '약초밭 정원사',
      first: '와아, 손님이에요! 저는 포포, 이 밭의 정원사예요! 씨앗 심어 볼래요?!',
      lines: {
        1: ['걸을 때마다 새싹이 쑥쑥! 발걸음은 최고의 물뿌리개예요!', '이 흙, 냄새 맡아 봤어요? 저쪽 숲 냄새랑 조금 닮았어요!'],
        2: ['안개가 밭까지 오면 어쩌죠? 그래도 새싹들은 씩씩해요!', '빛이 모자라면 씨앗이 잠들어요. 그러니까 많이 걸어 주세요!'],
        3: ['탑에 불이 켜졌어요! 새싹들이 다 그쪽으로 고개를 돌렸어요!', '다리 너머 숲에 심을 씨앗, 벌써 주머니에 챙겨 뒀어요!'],
      },
    ),
    // 묶음 51 #242: 주점 (결말 뒤 만남 장면 다음). 첫 만남은 만남 장면이라 첫 줄은 짧게
    NpcInfo(
      id: Npc.lian,
      name: '리안',
      role: '먼저 온 각성자',
      first: '어서 와요! 주점은 처음이죠? 편하게 앉아요. 오늘은 제가 살게요… 아니, 다음에요.',
      lines: {
        3: ['오늘도 걸었어요? 발이 피곤하면 여기서 쉬어 가요.', '혼자 걷는 길도 좋지만, 같이 걸으면 더 멀리 가요.'],
      },
    ),
    // 묶음 51 #229: 거래소 (리안 만남 다음 마을 방문에 완공)
    NpcInfo(
      id: Npc.barkan,
      name: '바르칸',
      role: '상단 우두머리',
      first: '허허, 다리가 놓였다길래 제일 먼저 건너왔지! 바르칸일세. 저쪽 큰 장터에서 상단을 꾸린다네.',
      lines: {
        3: ['물건은 돌고 돌아야 값이 나지. 쌓아 두면 먼지만 앉아.', '셈은 정확히, 인심은 넉넉히. 그게 우리 상단 규칙일세.'],
      },
    ),
  ];

  // ───────────── 묶음 51 #242·#229: 주점 · 거래소 (결말 뒤)

  static const tavernGuide = '피곤하면 앉아 가요. 소문도 듣고, 한 끼 먹고 가면 오늘 걸음이 가벼워져요.';
  static const marketGuide = '장부를 정리하는 중일세. 각성자들이 더 모이면 장을 열겠네.';

  /// 거래소가 완공된 날 미나 말풍선 (한 번)
  static const minaBarkan = '바르칸 할아버지가… 할머니 수레를 끌고 왔어요!';

  static NpcInfo npc(Npc n) => npcs[n.index];

  /// 그 막의 평소 대사 (없으면 가까운 다음 막)
  static List<String> linesFor(Npc n, int act) {
    final l = npc(n).lines;
    return l[act] ?? l[act + 1] ?? l[2] ?? l.values.first;
  }

  /// 들어갈 때 보여 줄 한마디: 처음이면 첫 줄, 그 뒤엔 번갈아
  static String lineFor(Npc n, {required int act, required bool met, required int visits}) {
    if (!met) return npc(n).first;
    final l = linesFor(n, act);
    return l[visits % l.length];
  }
}
