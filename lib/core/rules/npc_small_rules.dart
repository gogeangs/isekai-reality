import 'board_rules.dart';
import 'materials.dart';
import 'npc_rules.dart';
import 'village_rules.dart';

/// 묶음 45 #231: 마을 사람 작은 부탁 하나 (상황에 따라, 사연 없음)
class NpcSmall {
  const NpcSmall(this.say, this.steps, this.thanks);

  final String say;
  final List<NpcRequestStep> steps;

  /// 끝냈을 때 고맙다는 한마디
  final String thanks;
}

/// 묶음 45 #232: 전용 아이템 퀘스트 한 단계 (단계마다 마을 사람 한마디)
class NpcRelicStage {
  const NpcRelicStage(this.line, this.steps);

  final String line;
  final List<NpcRequestStep> steps;
}

/// 묶음 45 #232: 마을 사람 전용 아이템 (가방 「소중한 물건」, 가지고만 있으면 효과)
class NpcRelic {
  const NpcRelic({
    required this.npc,
    required this.asset,
    required this.name,
    required this.text,
    required this.say,
    required this.stages,
    required this.done,
  });

  final Npc npc;

  /// 그림 (assets/images/<asset>.webp)
  final String asset;
  final String name;

  /// 효과 (문장만, 숫자 없음)
  final String text;

  /// 처음 부탁 말
  final String say;
  final List<NpcRelicStage> stages;

  /// 받을 때 한마디
  final String done;
}

/// 부탁 종류: 큰 부탁(사연) · 작은 부탁 · 특별한 부탁(전용 아이템)
enum AskKind { big, small, special }

/// 마을 사람 작은 부탁 · 게시판 쪽지 · 전용 아이템 퀘스트 (묶음 45 #231·#232).
/// 확률·크기는 숨은 값(처음 값, 테스트로 조정)
class NpcSmallRules {
  NpcSmallRules._();

  // ───────────── 게시판 「마을 사람 의뢰」

  /// 길드 의뢰가 새로 붙을 때 마을 사람 쪽지가 붙는 확률
  static const double boardChance = 0.3;

  /// 쪽지를 끝내면: 친밀도 · 경험치
  static const int boardFavor = 1;
  static const int boardExp = 12;

  /// 같은 사람 쪽지를 이만큼 끝낼 때마다 그 사람이 직접 작은 부탁
  static const int boardAskEvery = 5;

  // ───────────── 작은 부탁

  /// 끝내면: 친밀도 · 경험치 (게시판 쪽지보다 조금 적게)
  static const int smallFavor = 2;
  static const int smallExp = 8;

  /// 하루 8,000보를 넘긴 날 (마르타)
  static const int martaSteps = 8000;

  // ───────────── 전용 아이템 퀘스트

  /// 작은 부탁을 끝낼 때 나올 확률 · 안 나올 때마다 오르는 정도
  static const double relicChance = 0.2;
  static const double relicStep = 0.1;

  static double relicChanceAfter(int misses) =>
      (relicChance + relicStep * misses).clamp(0.0, 1.0);

  /// 받으면 친밀도
  static const int relicFavor = 5;

  // ───────────── 전용 아이템 효과 크기 (숨은 값)

  /// 마르타의 보온병: 1,000보마다 최대 HP의 이만큼 더 참
  static const double flaskHp = 0.03;

  /// 미나의 주판: 잡화상에 팔 때 금화
  static const double abacusGold = 1.05;

  /// 도르군의 작은 모루: 이 걸음마다 입은 장비 내구도 +1
  static const int anvilSteps = 2000;

  /// 엘리엘의 별빛 플라스크: 물약을 마셔도 병이 남을 확률
  static const double starFlask = 0.1;

  /// 하르트의 낡은 지도통: 길드 의뢰가 새로 붙는 시간
  static const Duration mapcaseCooldown = Duration(minutes: 90);

  /// 세라의 방패 문장: 보스 큰 공격 막기 판정 넉넉히 (배)
  static const double crestGuard = 1.35;

  /// 루미의 호루라기: 원정에서 진 펫이 쉬는 시간
  static const Duration whistleTired = Duration(minutes: 40);

  /// 가렌의 무게 추: 1,000보마다 전투 숙련도
  static const double weightMastery = 0.2;

  // ───────────── 게시판 쪽지 (사람마다 2개)

  static const List<ErrandTemplate> boardNotes = [
    ErrandTemplate(
        id: 'npc_marta_0', npc: 'marta', title: '2,000보 더 걷기',
        counter: 'steps', target: 2000, unit: '보', exp: boardExp),
    ErrandTemplate(
        id: 'npc_marta_1', npc: 'marta', title: '채집 2번',
        counter: 'harvest', target: 2, unit: '번', exp: boardExp),
    ErrandTemplate(
        id: 'npc_mina_0', npc: 'mina', title: '잡화상 거래 2번',
        counter: 'shopTrade', target: 2, unit: '번', exp: boardExp),
    ErrandTemplate(
        id: 'npc_mina_1', npc: 'mina', title: '몬스터 3마리 사냥',
        counter: 'huntAll', target: 3, unit: '마리', exp: boardExp),
    ErrandTemplate(
        id: 'npc_dorgun_0', npc: 'dorgun', title: '큰쥐 2마리 사냥',
        counter: 'hunt:giantRat', target: 2, unit: '마리', exp: boardExp),
    ErrandTemplate(
        id: 'npc_dorgun_1', npc: 'dorgun', title: '채집 3번',
        counter: 'harvest', target: 3, unit: '번', exp: boardExp),
    ErrandTemplate(
        id: 'npc_eliel_0', npc: 'eliel', title: '물약 1번 끓이기',
        counter: 'brew', target: 1, unit: '번', exp: boardExp),
    ErrandTemplate(
        id: 'npc_eliel_1', npc: 'eliel', title: '채집 2번',
        counter: 'harvest', target: 2, unit: '번', exp: boardExp),
    ErrandTemplate(
        id: 'npc_hart_0', npc: 'hart', title: '원정 1번',
        counter: 'expedition', target: 1, unit: '번', exp: boardExp),
    ErrandTemplate(
        id: 'npc_hart_1', npc: 'hart', title: '2,000보 더 걷기',
        counter: 'steps', target: 2000, unit: '보', exp: boardExp),
    ErrandTemplate(
        id: 'npc_sera_0', npc: 'sera', title: '던전 1번 클리어',
        counter: 'dungeonClear', target: 1, unit: '번', exp: boardExp),
    ErrandTemplate(
        id: 'npc_sera_1', npc: 'sera', title: '몬스터 4마리 사냥',
        counter: 'huntAll', target: 4, unit: '마리', exp: boardExp),
    ErrandTemplate(
        id: 'npc_lumi_0', npc: 'lumi', title: '원정 1번',
        counter: 'expedition', target: 1, unit: '번', exp: boardExp),
    ErrandTemplate(
        id: 'npc_lumi_1', npc: 'lumi', title: '2,500보 더 걷기',
        counter: 'steps', target: 2500, unit: '보', exp: boardExp),
    ErrandTemplate(
        id: 'npc_garen_0', npc: 'garen', title: '몬스터 3마리 사냥',
        counter: 'huntAll', target: 3, unit: '마리', exp: boardExp),
    ErrandTemplate(
        id: 'npc_garen_1', npc: 'garen', title: '3,000보 더 걷기',
        counter: 'steps', target: 3000, unit: '보', exp: boardExp),
    // 묶음 48 #230
    ErrandTemplate(
        id: 'npc_popo_0', npc: 'popo', title: '채집 2번',
        counter: 'harvest', target: 2, unit: '번', exp: boardExp),
    ErrandTemplate(
        id: 'npc_popo_1', npc: 'popo', title: '2,000보 더 걷기',
        counter: 'steps', target: 2000, unit: '보', exp: boardExp),
    // 묶음 51 #242·#229
    ErrandTemplate(
        id: 'npc_lian_0', npc: 'lian', title: '3,000보 더 걷기',
        counter: 'steps', target: 3000, unit: '보', exp: boardExp),
    ErrandTemplate(
        id: 'npc_lian_1', npc: 'lian', title: '몬스터 3마리 사냥',
        counter: 'huntAll', target: 3, unit: '마리', exp: boardExp),
    ErrandTemplate(
        id: 'npc_barkan_0', npc: 'barkan', title: '채집 3번',
        counter: 'harvest', target: 3, unit: '번', exp: boardExp),
    ErrandTemplate(
        id: 'npc_barkan_1', npc: 'barkan', title: '2,500보 더 걷기',
        counter: 'steps', target: 2500, unit: '보', exp: boardExp),
  ];

  /// 그 사람 쪽지들
  static List<ErrandTemplate> notesOf(String npc) => [
        for (final t in boardNotes)
          if (t.npc == npc) t,
      ];

  /// 게시판 쪽지를 [boardAskEvery] 번 끝냈을 때 그 사람 말풍선 (개발 초안)
  static const Map<Npc, String> boardAsk = {
    Npc.marta: '게시판 쪽지 네가 다 해 줬다며? 하나만 더 부탁해도 될까?',
    Npc.mina: '게시판에 붙인 제 쪽지, 다 해 주셨더라고요! 하나 더 부탁드려도 될까요?',
    Npc.dorgun: '…게시판 쪽지, 네가 다 했다지. 하나 더 맡기겠다.',
    Npc.eliel: '제 쪽지 다 해 주신 거 맞죠? 그럼 이번엔 직접 부탁할게요!',
    Npc.hart: '내 쪽지를 자네가 다 떼어 갔더군. 이번엔 직접 부탁하겠네.',
    Npc.sera: '게시판 쪽지는 네가 다 했다고 들었다. 하나 더 맡긴다.',
    Npc.lumi: '게시판 쪽지 네가 다 했지? 헤헤, 하나만 더 부탁할게!',
    Npc.garen: '게시판 쪽지를 네가 다 해치웠다며! 하나 더 맡겨 주마!',
    Npc.popo: '게시판 쪽지 다 해 준 거 손님이죠?! 하나만 더 부탁해도 돼요?',
    Npc.lian: '게시판 쪽지, 당신이 다 해 줬죠? 역시요. 하나만 더 부탁해도 돼요?',
    Npc.barkan: '게시판 쪽지를 자네가 다 처리했다지? 허허, 하나 더 맡기겠네.',
  };

  // ───────────── 작은 부탁 (사람마다 3개 중 하나, 개발 초안)

  static const Map<Npc, List<NpcSmall>> smalls = {
    Npc.marta: [
      NpcSmall('바람 좀 쐬고 와. 3,000보면 딱 좋아!', [
        NpcRequestStep(RequestStepKind.stepsSince, 3000, '3,000보 걷기'),
      ], '볼이 발그레하네! 고마워, 이제 푹 쉬어.'),
      NpcSmall('수프에 넣을 약초가 두 개 모자라. 구해 줄래?', [
        NpcRequestStep(RequestStepKind.deliver, 2, '약초 2개 가져오기',
            mats: {...Materials.herbGroup}),
      ], '좋아, 오늘 수프는 네 몫까지 끓일게!'),
      NpcSmall('창밖에 슬라임이 자꾸 기웃거려. 세 마리만 쫓아 줄래?', [
        NpcRequestStep(RequestStepKind.tally, 3, '슬라임 3마리 잡기',
            key: NpcTally.ashKill),
      ], '휴, 이제 창문을 열어 둘 수 있겠다. 고마워!'),
    ],
    Npc.mina: [
      NpcSmall('새 길에 뭐가 있는지 궁금해요! 2,000보만 걸어 봐 주실래요?', [
        NpcRequestStep(RequestStepKind.stepsSince, 2000, '2,000보 걷기'),
      ], '덕분에 장부에 새 길을 적었어요!'),
      NpcSmall('진열장이 비었어요. 채집 두 번만 해 주실래요?', [
        NpcRequestStep(RequestStepKind.tally, 2, '채집 2번', key: NpcTally.gather),
      ], '와, 진열장이 반짝반짝해요!'),
      NpcSmall('몬스터 재료 견본이 필요해요. 세 마리만 잡아 주세요!', [
        NpcRequestStep(RequestStepKind.tally, 3, '필드 몬스터 3마리 잡기',
            key: NpcTally.fieldKill),
      ], '견본 완성! 손님들이 좋아하겠어요!'),
    ],
    Npc.dorgun: [
      NpcSmall('…철 조각 셋. 가져와라.', [
        NpcRequestStep(RequestStepKind.deliver, 3, '철 조각 3개 가져오기',
            mats: {MaterialId.ironShard}),
      ], '…좋다. 쓸 만하군.'),
      NpcSmall('광석을 캐 와라. 두 번.', [
        NpcRequestStep(RequestStepKind.tally, 2, '광석 2번 캐기',
            key: 'gather:ore'),
      ], '…손이 빨라졌군.'),
      NpcSmall('몸을 풀어라. 몬스터 넷.', [
        NpcRequestStep(RequestStepKind.tally, 4, '필드 몬스터 4마리 잡기',
            key: NpcTally.fieldKill),
      ], '…됐다. 망치 소리가 가벼워졌다.'),
    ],
    Npc.eliel: [
      NpcSmall('물약 하나만 끓여 주실래요? 가마솥이 심심해해요!', [
        NpcRequestStep(RequestStepKind.tally, 1, '물약 1번 끓이기', key: NpcTally.brew),
      ], '보글보글! 가마솥이 신났어요!'),
      NpcSmall('약초 세 개만 나눠 주실래요? 실험에 써 볼게요!', [
        NpcRequestStep(RequestStepKind.deliver, 3, '약초 3개 가져오기',
            mats: {...Materials.herbGroup}),
      ], '좋은 냄새! 고마워요!'),
      NpcSmall('맑은 기운이 필요해요. 2,500보 걸으며 모아 주세요!', [
        NpcRequestStep(RequestStepKind.stepsSince, 2500, '2,500보 걷기'),
      ], '병 안이 반짝여요! 고마워요!'),
    ],
    Npc.hart: [
      NpcSmall('던전 한 번 둘러봐 주겠나? 조용하니 오히려 수상하네.', [
        NpcRequestStep(RequestStepKind.tally, 1, '던전 1번 클리어', key: NpcTally.dungeon),
      ], '역시 자네일세. 고맙네.'),
      NpcSmall('마을 둘레를 한 바퀴 돌아 주게. 3,000보면 될 걸세.', [
        NpcRequestStep(RequestStepKind.stepsSince, 3000, '3,000보 걷기'),
      ], '든든하군. 오늘 밤은 편히 자겠네.'),
      NpcSmall('몬스터 다섯만 정리해 주겠나?', [
        NpcRequestStep(RequestStepKind.tally, 5, '필드 몬스터 5마리 잡기',
            key: NpcTally.fieldKill),
      ], '깔끔하군. 자네 솜씨가 늘었네.'),
    ],
    Npc.sera: [
      NpcSmall('검을 쥔 채 걸어라. 3,000보.', [
        NpcRequestStep(RequestStepKind.stepsSince, 3000, '3,000보 걷기'),
      ], '좋다. 발이 단단해졌군.'),
      NpcSmall('필드 몬스터 다섯. 망설이지 마라.', [
        NpcRequestStep(RequestStepKind.tally, 5, '필드 몬스터 5마리 잡기',
            key: NpcTally.fieldKill),
      ], '망설임이 없었다. 잘했다.'),
      NpcSmall('던전 한 번. 끝까지 가라.', [
        NpcRequestStep(RequestStepKind.tally, 1, '던전 1번 클리어', key: NpcTally.dungeon),
      ], '끝까지 갔군. 그거면 됐다.'),
    ],
    Npc.lumi: [
      NpcSmall('펫이랑 2,000보 산책 다녀와! 애들이 좋아해!', [
        NpcRequestStep(RequestStepKind.stepsSince, 2000, '펫과 함께 2,000보 걷기'),
      ], '애들 꼬리 흔드는 거 봐! 고마워!'),
      NpcSmall('간식 한 번만 줘 볼래? 애들이 기다려!', [
        NpcRequestStep(RequestStepKind.tally, 1, '펫에게 간식 1번 주기', key: NpcTally.snack),
      ], '냠냠! 애들이 너 최고래!'),
      NpcSmall('물가에 가 볼래? 애들이 물놀이를 좋아하거든!', [
        NpcRequestStep(RequestStepKind.tally, 1, '물가 채집 1번', key: NpcTally.water),
      ], '시원했지? 애들도 신났어!'),
    ],
    Npc.garen: [
      NpcSmall('허수아비 앞에 서라! 연습에서 강타 한 번이다!', [
        NpcRequestStep(RequestStepKind.tally, 1, '연습에서 강타 쓰기',
            key: NpcTally.practiceBash),
      ], '좋다! 팔이 제법 매서워졌다!'),
      NpcSmall('내 다리 대신 네가 걸어라! 3,000보다!', [
        NpcRequestStep(RequestStepKind.stepsSince, 3000, '3,000보 걷기'),
      ], '훌륭하다! 다리가 튼튼해야 검도 산다!'),
      NpcSmall('실전이 최고의 훈련이다! 몬스터 네 마리!', [
        NpcRequestStep(RequestStepKind.tally, 4, '필드 몬스터 4마리 잡기',
            key: NpcTally.fieldKill),
      ], '그래, 그게 실전이다! 잘했다!'),
    ],
    Npc.popo: [
      NpcSmall('밭에 물 줄 시간이에요! 2,500보만 걸어 줄래요?', [
        NpcRequestStep(RequestStepKind.stepsSince, 2500, '2,500보 걷기'),
      ], '촉촉해졌어요! 새싹들이 고맙대요!'),
      NpcSmall('밭에서 하나만 거둬 줄래요? 다음 씨앗을 심을 자리가 필요해요!', [
        NpcRequestStep(RequestStepKind.tally, 1, '약초밭에서 1번 거두기',
            key: NpcTally.gardenHarvest),
      ], '와아, 잘 자랐다! 손님 손이 최고예요!'),
      NpcSmall('꽃이나 버섯 두 개만 보여 줄래요? 씨앗을 받아 볼래요!', [
        NpcRequestStep(RequestStepKind.deliver, 2, '꽃·버섯 2개 가져오기',
            mats: NpcRules.flowerMushroom),
      ], '씨앗이 잔뜩 들었어요! 고마워요!'),
    ],
    // 묶음 51 #242 리안 (한 끼 먹을 때 · 소문 들을 때)
    Npc.lian: [
      NpcSmall('같이 걸을 사람을 찾는 중이에요. 2,000보만 먼저 걸어 볼래요?', [
        NpcRequestStep(RequestStepKind.stepsSince, 2000, '2,000보 걷기'),
      ], '발소리가 좋네요. 기억해 둘게요.'),
      NpcSmall('주점 탁자에 올릴 꽃이 필요해요. 꽃이나 버섯 두 개만요?', [
        NpcRequestStep(RequestStepKind.deliver, 2, '꽃·버섯 2개 가져오기',
            mats: NpcRules.flowerMushroom),
      ], '탁자가 환해졌어요. 고마워요!'),
      NpcSmall('소문 확인 좀 도와줄래요? 필드 몬스터 세 마리요.', [
        NpcRequestStep(RequestStepKind.tally, 3, '필드 몬스터 3마리 잡기',
            key: NpcTally.fieldKill),
      ], '소문이 맞았네요. 역시 당신이에요.'),
    ],
    // 묶음 51 #229 바르칸 (나무·광석을 캘 때)
    Npc.barkan: [
      NpcSmall('수레에 실을 짐이 모자라구먼. 채집 두 번만 해 오게.', [
        NpcRequestStep(RequestStepKind.tally, 2, '채집 2번', key: NpcTally.gather),
      ], '허허, 수레가 묵직해졌네. 고맙네.'),
      NpcSmall('장터 둘레가 궁금하네. 2,500보만 걸어 보고 오게.', [
        NpcRequestStep(RequestStepKind.stepsSince, 2500, '2,500보 걷기'),
      ], '길 이야기는 장사꾼한테 금화나 마찬가지일세.'),
      NpcSmall('철 조각 두 개만 구해 주겠나? 저울추를 새로 달아야겠어.', [
        NpcRequestStep(RequestStepKind.deliver, 2, '철 조각 2개 가져오기',
            mats: {MaterialId.ironShard}),
      ], '셈은 정확히! 이제 저울이 바로 서는구먼.'),
    ],
  };

  static List<NpcSmall> smallsOf(Npc n) => smalls[n] ?? const [];

  static NpcSmall? small(Npc n, int i) {
    final l = smallsOf(n);
    return i >= 0 && i < l.length ? l[i] : null;
  }

  // ───────────── 전용 아이템 퀘스트 (사람마다 1개, 개발 초안)

  static const List<NpcRelic> relics = [
    NpcRelic(
      npc: Npc.marta,
      asset: 'item_martaFlask',
      name: '마르타의 보온병',
      text: '걸으면 HP가 조금씩 차요',
      say: '테오가 들고 다니던 보온병이 있는데… 낡아서 손을 봐야 해. 같이 해 줄래?',
      stages: [
        NpcRelicStage('먼저 맑은 물이 필요해. 멀리 걸어 다녀와 줘.', [
          NpcRequestStep(RequestStepKind.stepsSince, 3000, '3,000보 걷기'),
        ]),
        NpcRelicStage('물가에서 시원한 물을 한 번 떠 와 줄래?', [
          NpcRequestStep(RequestStepKind.tally, 1, '물가 채집 1번', key: NpcTally.water),
        ]),
        NpcRelicStage('마지막으로 약초 두 개. 따뜻한 차를 담아 줄게.', [
          NpcRequestStep(RequestStepKind.deliver, 2, '약초 2개 가져오기',
              mats: {...Materials.herbGroup}),
        ]),
      ],
      done: '자, 이건 이제 네 거야. 걸을 때마다 몸이 따뜻해질 거야.',
    ),
    NpcRelic(
      npc: Npc.mina,
      asset: 'item_minaAbacus',
      name: '미나의 주판',
      text: '잡화상에 팔 때 금화가 조금 더 나와요',
      say: '할머니 주판을 고치고 싶어요! 같이 해 주실래요?',
      stages: [
        NpcRelicStage('주판알 재료를 파는 곳을 찾아야 해요. 좀 걸어 봐요!', [
          NpcRequestStep(RequestStepKind.stepsSince, 5000, '부탁 받은 뒤 5,000보 걷기'),
        ]),
        NpcRelicStage('알을 꿰려면 발품이 들어요. 4,000보만요!', [
          NpcRequestStep(RequestStepKind.stepsSince, 4000, '4,000보 걷기'),
        ]),
        NpcRelicStage('마지막으로 철 조각 두 개면 끝이에요!', [
          NpcRequestStep(RequestStepKind.deliver, 2, '철 조각 2개 가져오기',
              mats: {MaterialId.ironShard}),
        ]),
      ],
      done: '딸깍딸깍! 이 주판이면 손해 볼 일은 없을 거예요!',
    ),
    NpcRelic(
      npc: Npc.dorgun,
      asset: 'item_dorgunAnvil',
      name: '도르군의 작은 모루',
      text: '걸으면 입은 장비 내구도가 조금씩 돌아와요',
      say: '…들고 다닐 작은 모루를 하나 만들겠다. 손을 빌려라.',
      stages: [
        NpcRelicStage('…광석부터 캐 와라. 세 번.', [
          NpcRequestStep(RequestStepKind.tally, 3, '광석 3번 캐기', key: 'gather:ore'),
        ]),
        NpcRelicStage('달군 쇠를 식혀야 한다. 멀리 물가까지 가라.', [
          NpcRequestStep(RequestStepKind.stepsSince, 2000, '2,000보 걷기'),
          NpcRequestStep(RequestStepKind.tally, 1, '물가 채집 1번 (쇠 식히기)',
              key: NpcTally.water),
        ]),
        NpcRelicStage('…마지막이다. 대장간으로 주괴 하나.', [
          NpcRequestStep(RequestStepKind.deliver, 1, '철 주괴 1개 가져오기',
              mats: {MaterialId.ironIngot}),
        ]),
      ],
      done: '…가져가라. 걸을 때마다 네 장비를 다듬어 줄 거다.',
    ),
    NpcRelic(
      npc: Npc.eliel,
      asset: 'item_elielFlask',
      name: '엘리엘의 별빛 플라스크',
      text: '물약을 마셔도 가끔 병이 남아요',
      say: '별빛을 담는 병을 만들고 있어요! 도와주실래요?',
      stages: [
        NpcRelicStage('먼저 3,000보 걸으며 빛을 모아 주세요!', [
          NpcRequestStep(RequestStepKind.stepsSince, 3000, '3,000보 걷기'),
        ]),
        NpcRelicStage('이제 가마솥으로 빛을 녹여요. 두 번!', [
          NpcRequestStep(RequestStepKind.tally, 2, '물약 2번 끓이기', key: NpcTally.brew),
        ]),
        NpcRelicStage('마지막으로 정제 에센스 하나만요!', [
          NpcRequestStep(RequestStepKind.deliver, 1, '정제 에센스 1개 가져오기',
              mats: {MaterialId.essence}),
        ]),
      ],
      done: '완성! 별빛이 남아 있어서 가끔 병이 다시 차오를 거예요!',
    ),
    NpcRelic(
      npc: Npc.hart,
      asset: 'item_hartMapcase',
      name: '하르트의 낡은 지도통',
      text: '조합 의뢰가 조금 더 빨리 새로 붙어요',
      say: '내 옛 지도에 빈칸이 많네. 함께 채워 주겠나?',
      stages: [
        NpcRelicStage('먼저 길을 좀 걸어 주게.', [
          NpcRequestStep(RequestStepKind.stepsSince, 5000, '부탁 받은 뒤 5,000보 걷기'),
        ]),
        NpcRelicStage('길은 몸으로 익혀야 그려지네. 5,000보일세.', [
          NpcRequestStep(RequestStepKind.stepsSince, 5000, '5,000보 걷기'),
        ]),
      ],
      done: '이 지도통을 자네에게 주겠네. 의뢰가 자네를 더 빨리 찾아갈 걸세.',
    ),
    NpcRelic(
      npc: Npc.sera,
      asset: 'item_seraCrest',
      name: '세라의 방패 문장',
      text: '보스의 큰 공격을 막기가 조금 쉬워져요',
      say: '근위 기사단의 방패 문장을 다시 새기려 한다. 도와라.',
      stages: [
        NpcRelicStage('먼저 던전 둘. 끝까지 가라.', [
          NpcRequestStep(RequestStepKind.tally, 2, '던전 2번 클리어', key: NpcTally.dungeon),
        ]),
        NpcRelicStage('걸으며 마음을 가라앉혀라. 4,000보.', [
          NpcRequestStep(RequestStepKind.stepsSince, 4000, '4,000보 걷기'),
        ]),
        NpcRelicStage('문장을 새길 쇠 하나. 가져와라.', [
          NpcRequestStep(RequestStepKind.deliver, 1, '철 주괴 1개 가져오기',
              mats: {MaterialId.ironIngot}),
        ]),
      ],
      done: '이 문장을 지녀라. 큰 공격 앞에서도 흔들리지 않을 거다.',
    ),
    NpcRelic(
      npc: Npc.lumi,
      asset: 'item_lumiWhistle',
      name: '루미의 호루라기',
      text: '원정에서 진 펫이 더 빨리 회복해요',
      say: '바람이 좋아하던 호루라기를 하나 더 만들 거야! 같이 하자!',
      stages: [
        NpcRelicStage('먼저 펫이랑 산책! 3,000보!', [
          NpcRequestStep(RequestStepKind.stepsSince, 3000, '펫과 함께 3,000보 걷기'),
        ]),
        NpcRelicStage('호루라기 깎을 나무가 필요해. 두 번!', [
          NpcRequestStep(RequestStepKind.tally, 2, '나무 2번 캐기', key: 'gather:wood'),
        ]),
        NpcRelicStage('마지막으로 애한테 간식 하나 주고 와. 소리 시험해 볼래!', [
          NpcRequestStep(RequestStepKind.tally, 1, '펫에게 간식 1번 주기', key: NpcTally.snack),
        ]),
      ],
      done: '삐익! 이 소리 들으면 지친 애들도 금방 힘이 날 거야!',
    ),
    NpcRelic(
      npc: Npc.garen,
      asset: 'item_garenWeight',
      name: '가렌의 무게 추',
      text: '걸으면 전투 숙련도가 조금씩 올라요',
      say: '내가 신병 때 차던 무게 추를 물려주마! 대신 땀 좀 흘려라!',
      stages: [
        NpcRelicStage('먼저 하루 훈련이다!', [
          NpcRequestStep(RequestStepKind.tally, 1, '하루 훈련 1번', key: NpcTally.dailyTraining),
        ]),
        NpcRelicStage('추를 차고 걷는 거다! 5,000보!', [
          NpcRequestStep(RequestStepKind.stepsSince, 5000, '5,000보 걷기'),
        ]),
        NpcRelicStage('마지막은 실전이다! 다섯!', [
          NpcRequestStep(RequestStepKind.tally, 5, '필드 몬스터 5마리 잡기',
              key: NpcTally.fieldKill),
        ]),
      ],
      done: '가져가라! 걸을 때마다 몸이 싸움을 기억할 거다!',
    ),
    // 묶음 48 #230
    NpcRelic(
      npc: Npc.popo,
      asset: 'item_popoDew',
      name: '포포의 이슬병',
      text: '약초밭이 조금 빨리 자라요',
      say: '저쪽 숲의 새벽 이슬을 담는 병이 있어요! 같이 채워 볼래요?!',
      stages: [
        NpcRelicStage('이슬은 새벽 공기를 좋아해요! 먼저 3,000보 걸어 주세요!', [
          NpcRequestStep(RequestStepKind.stepsSince, 3000, '3,000보 걷기'),
        ]),
        NpcRelicStage('이제 맑은 물이 필요해요! 물가에서 한 번만요!', [
          NpcRequestStep(RequestStepKind.tally, 1, '물가 채집 1번', key: NpcTally.water),
        ]),
        NpcRelicStage('마지막! 밭에서 하나 거두면 이슬이 내려앉아요!', [
          NpcRequestStep(RequestStepKind.tally, 1, '약초밭에서 1번 거두기',
              key: NpcTally.gardenHarvest),
        ]),
      ],
      done: '이슬병 완성! 이걸 가지고 있으면 밭이 덜 목말라해요!',
    ),
    // 묶음 51 #242
    NpcRelic(
      npc: Npc.lian,
      asset: 'item_lianCompass',
      name: '리안의 낡은 나침반',
      text: '주점 한 끼가 조금 싸져요',
      say: '혼자 걸을 때 쓰던 나침반이 있어요. 바늘이 좀 이상한데… 같이 고쳐 볼래요?',
      stages: [
        NpcRelicStage('바늘이 길을 잊었나 봐요. 같이 좀 걸어 봐요.', [
          NpcRequestStep(RequestStepKind.stepsSince, 5000, '부탁 받은 뒤 5,000보 걷기'),
        ]),
        NpcRelicStage('바늘이 떨려요. 4,000보 걸으면서 맞춰 봐요.', [
          NpcRequestStep(RequestStepKind.stepsSince, 4000, '4,000보 걷기'),
        ]),
        NpcRelicStage('마지막으로 주점에서 한 끼 먹고 와요. 배가 든든해야 길을 잃지 않죠.', [
          NpcRequestStep(RequestStepKind.tally, 1, '주점에서 한 끼 먹기', key: NpcTally.meal),
        ]),
      ],
      done: '자, 이제 당신 거예요. 어디서든 주점으로 돌아오는 길을 알려 줄 거예요.',
    ),
    // 묶음 51 #229
    NpcRelic(
      npc: Npc.barkan,
      asset: 'item_barkanPurse',
      name: '바르칸의 동전 주머니',
      text: '걸으면 가끔 금화를 주워요',
      say: '허허, 낡은 동전 주머니가 하나 있는데 말일세. 같이 손볼 텐가?',
      stages: [
        NpcRelicStage('장터 둘레를 한 바퀴 돌게. 3,000보일세.', [
          NpcRequestStep(RequestStepKind.stepsSince, 3000, '3,000보 걷기'),
        ]),
        NpcRelicStage('주머니 끈이 낡았구먼. 나무 한 번 캐 오게.', [
          NpcRequestStep(RequestStepKind.tally, 1, '나무 1번 캐기', key: 'gather:wood'),
        ]),
        NpcRelicStage('마지막일세. 철 조각 두 개만 가져오게.', [
          NpcRequestStep(RequestStepKind.deliver, 2, '철 조각 2개 가져오기',
              mats: {MaterialId.ironShard}),
        ]),
      ],
      done: '이 주머니는 돌고 도는 금화를 잘 붙잡지. 가져가게, 허허.',
    ),
  ];

  /// 묶음 51 바르칸 4번째 부탁 특별 보상 (가방 「소중한 물건」, 효과는 거래소가 열릴 때)
  static const NpcRelic barkanSeal = NpcRelic(
    npc: Npc.barkan,
    asset: 'item_barkanSeal',
    name: '바르칸의 상단 인장',
    text: '거래소에 물건을 올릴 때 드는 금화가 줄어요',
    say: '',
    stages: [],
    done: '',
  );

  static NpcRelic relicOf(Npc n) => relics.firstWhere((r) => r.npc == n);
}
