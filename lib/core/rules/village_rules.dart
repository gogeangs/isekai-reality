import '../format.dart';

/// 마을 사람 (묶음 35): 시설마다 한 사람, 모두 틈에 걸린 저쪽 세계 사람
enum Npc { marta, toby, bron, ella, hart, sera, lumi }

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
      id: Npc.toby,
      name: '토비',
      role: '잡화상 주인',
      first: '어서 와요, 어서 와! 틈에 걸려도 장사는 해야죠. 뭐든 있어요… 거의!',
      lines: {
        1: ['셈은 제가 할게요, 빠르거든요!', '슬라임 젤리 팔 거 있어요? 요즘 찾는 사람이 많아요.'],
        2: ['안개 때문에 물건 들어오는 길이 막혔어요. 그래도 문은 안 닫아요!', '잿빛 몬스터 재료요? 으, 냄새는 나도 값은 쳐 드릴게요.'],
        3: ['다리가 생겼으니 저쪽 물건도 들어오겠죠? 벌써 신나요!', '단골손님께 감사의 뜻으로… 웃음은 공짜예요!'],
      },
    ),
    NpcInfo(
      id: Npc.bron,
      name: '브론',
      role: '대장장이',
      first: '…각성자인가. 연장은 아껴 쓰도록.',
      lines: {
        1: ['망치는 거짓말을 안 한다.', '날이 무디면 마음도 무뎌진다. 손질해 둬라.'],
        2: ['잿빛 놈들 껍질이 단단하다. 날을 세워 두지.', '화덕 불이 약해졌다. 안개 탓이야.'],
        3: ['…탑의 불이 돌아왔군. 내 화덕도 다시 뜨겁다.', '네가 해냈다. 망치로 증명할 필요도 없지.'],
      },
    ),
    NpcInfo(
      id: Npc.ella,
      name: '엘라',
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
      role: '길드장',
      first: '길드에 온 걸 환영한다. 네 길은 네가 고르는 거다.',
      lines: {
        2: ['직업은 칭호가 아니라 약속이다. 잊지 마라.', '분신과 싸울 땐 서두르지 마라. 펫도 네 동료다.'],
        3: ['잘 싸웠다, 각성자. 길드의 이름으로 경의를 표한다.', '이제 길드도 다리 너머를 준비해야겠군.'],
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
  ];

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
