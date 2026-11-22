import 'materials.dart';
import 'monsters.dart';
import 'title_rules.dart';
import 'village_rules.dart';

/// 묶음 42 #226: 마을 사람 친해지기 단계 (화면에 보이지 않는다 — 대사로만)
enum FavorStage { stranger, known, close, best }

/// 부탁 할 일 종류
enum RequestStepKind {
  /// 받은 뒤 한 일 수 (사냥·채집·강화 등, [NpcRequestStep.key])
  tally,

  /// 가방에 있는 재료 (「다 했어요」 때 가져감)
  deliver,

  /// 받은 날부터 하루 걸음이 이만큼인 날이 있으면
  daySteps,

  /// 받은 날부터 이른 아침(새벽 5~9시) 걸음이 이만큼인 날이 있으면
  dawnSteps,

  /// 받은 뒤 걸은 걸음 (동행 펫과 함께)
  stepsSince,

  /// 받은 뒤 며칠 연속 여관에서 쉬기
  innStreak,

  /// 지금까지 쓰러뜨린 잿빛 분신 수
  allClones,

  /// 성체 펫이 있으면
  adultPet,

  /// 받은 뒤 새로 쓰러뜨린 분신 (모두 쓰러뜨린 뒤 받으면 이미 끝난 것으로)
  clone,

  /// 묶음 51: 받은 날부터 하루 [NpcRequestStep.min] 보 이상 걸은 날이 며칠 이어졌는지
  dayStreak,
}

/// 부탁 할 일 하나
class NpcRequestStep {
  const NpcRequestStep(this.kind, this.need, this.label,
      {this.key = '', this.mats = const {}, this.distinct = false, this.min = 0});

  /// [RequestStepKind.dayStreak] 의 하루 걸음 (이만큼 이상 걸은 날)
  final int min;

  final RequestStepKind kind;
  final int need;
  final String label;

  /// [RequestStepKind.tally] 의 셈 이름 ([NpcTally])
  final String key;

  /// [RequestStepKind.deliver] 의 재료 (비면 [NpcRules.monsterMats])
  final Set<MaterialId> mats;

  /// 서로 다른 종류로 셈 (몬스터 재료 3종)
  final bool distinct;
}

/// 부탁을 끝내야 받는 특별한 것 (4번째 부탁)
enum NpcSpecialKind { scarf, pouch, whetstone, dawnLight, keys, badge, nest, band, garden, knot, seal }

class NpcSpecial {
  const NpcSpecial(this.kind, this.title, this.name, this.text, this.asset);

  final NpcSpecialKind kind;
  final TitleId title;
  final String name;
  final String text;

  /// 그림 (assets/images/<asset>.webp)
  final String asset;
}

/// 마을 사람 부탁 하나
class NpcRequest {
  const NpcRequest({
    required this.npc,
    required this.index,
    required this.stage,
    required this.level,
    required this.say,
    required this.steps,
    required this.story,
    this.gifts = const {},
    this.special,
  });

  final Npc npc;

  /// 0~3 (차례대로)
  final int index;

  /// 열리는 친해지기 단계
  final FavorStage stage;

  /// 열리는 레벨
  final int level;

  /// 부탁 말
  final String say;
  final List<NpcRequestStep> steps;

  /// 끝내면 받는 것 (우편 선물과 같은 키: 'gold' · 'manaStone' · 'note' · 'item:<물건>' · 재료 이름)
  final Map<String, int> gifts;

  /// 사연 한 조각 (끝내면 기록 탭 「마을 사람 이야기」)
  final String story;

  /// 4번째 부탁의 특별 보상
  final NpcSpecial? special;
}

/// 단계가 오를 때 오는 작은 선물 우편
class FavorLetter {
  const FavorLetter(this.title, this.body, this.gifts);

  final String title;
  final String body;
  final Map<String, int> gifts;
}

/// 부탁이 세는 일 이름
class NpcTally {
  NpcTally._();
  static const rest3k = 'rest3k'; // 오늘 3,000보 걷고 여관에서 쉬기
  static const water = 'water'; // 물가 채집
  static const relic = 'relic'; // 고대 유물 채집
  static const stoneSold = 'stoneSold'; // 잡화상에 판 마석
  static const newPlace = 'newPlace'; // 새 장소
  static const enhance = 'enhance'; // 강화
  static const dungeon = 'dungeon'; // 던전 클리어 (보스까지)
  static const ashKill = 'ashKill'; // 슬라임 사냥 (묶음 47 #241: 속성 슬라임도)

  /// 묶음 47 #241: 「슬라임 ○마리」 부탁에 세는 몬스터 — 슬라임과 속성 슬라임 모두
  static bool slimeKill(MonsterId m) =>
      m == MonsterId.ashSlime || Monsters.info(m).slimeKind;
  static const brew = 'brew'; // 물약 끓이기
  static const newRecipe = 'newRecipe'; // 처음 보는 물약 레시피
  static const guildErrand = 'guildErrand'; // 조합 의뢰
  static const urgent = 'urgent'; // 긴급 의뢰
  static const petExpedition = 'petExp'; // 첫 펫 원정
  static const jobSkill = 'jobSkill'; // 직업 스킬
  static const clone = 'clone'; // 잿빛 분신
  static const fieldKill = 'fieldKill'; // 필드 몬스터
  static const snack = 'snack'; // 펫 간식
  static const hatch = 'hatch'; // 알 깨우기
  // 묶음 43 #228: 훈련장 (가렌)
  static const practiceBash = 'practiceBash'; // 연습에서 강타
  static const practiceStance = 'practiceStance'; // 연습에서 방어 태세
  static const practiceSkill = 'practiceSkill'; // 연습에서 스킬
  static const dailyTraining = 'dailyTraining'; // 하루 훈련 (하루 한 번)
  static const trial10 = 'trial10'; // 시련에서 10판 넘기기
  static const petTraining = 'petTraining'; // 펫 훈련
  // 묶음 45 #231: 작은 부탁
  static const gather = 'gather'; // 채집 (모두)
  static String gatherOf(String kind) => 'gather:$kind'; // 채집 종류별
  // 묶음 48 #230: 약초밭 (포포)
  static const gardenHarvest = 'gardenHarvest'; // 약초밭에서 거두기
  static const gardenGlow = 'gardenGlow'; // 빛나는 씨앗을 다 키워 거두기
  static const seedFound = 'seedFound'; // 채집하다 찾은 씨앗
  // 묶음 51 #242: 주점 (리안)
  static const meal = 'meal'; // 주점에서 한 끼
}

/// 마을 사람 부탁 · 사연 · 친해지기 규칙 (묶음 42 #226, 문서 「아르카 마을 사람 이야기」).
/// 점수·문턱·혜택 크기는 숨은 값(처음 값, 테스트로 조정)
class NpcRules {
  NpcRules._();

  // ───────────── 친해지기 점수

  /// 그 시설에 들르기 (하루 한 번)
  static const int visitPoints = 1;

  /// 시설 쓰기 (하루 [usesPerDay] 번까지)
  static const int usePoints = 1;
  static const int usesPerDay = 3;

  /// 부탁 끝내기
  static const int requestPoints = 5;

  /// 단계 문턱: 아는 사이 · 친함 · 단짝
  static const int knownAt = 5;
  static const int closeAt = 20;
  static const int bestAt = 45;

  /// 예전 기록으로 어림한 시작 점수의 최대 (단짝은 부탁을 끝내며 닿게)
  static const int seedMax = 30;

  static FavorStage stageOf(int points) => points >= bestAt
      ? FavorStage.best
      : points >= closeAt
          ? FavorStage.close
          : points >= knownAt
              ? FavorStage.known
              : FavorStage.stranger;

  // ───────────── 단짝 혜택 (숨은 값)

  // 마르타: 여관에서 조금 더 빨리 회복 (묶음 81 #371, InnRules.martaSpeed)

  /// 미나: 산 값 일부를 돌려받음
  static const double minaRefund = 0.08;

  /// 도르군: 수리비
  static const double dorgunRepair = 0.85;

  /// 엘리엘: 가끔 재료 하나 덜
  static const double elielSave = 0.15;

  /// 하르트: 의뢰 금화
  static const double hartGold = 1.1;

  /// 세라: 숙련도
  static const double seraMastery = 1.1;

  /// 루미: 펫 친밀도
  static const double lumiBond = 1.25;

  /// 가렌: 하루 훈련 보상 (금화) — [TrainingRules.garenGold]

  // ───────────── 특별 보상 크기 (숨은 값)

  /// 미나의 짐 주머니: 가방 칸
  static const int pouchSlots = 2;

  /// 루미의 둥지 장식: 알 품는 시간 (이만큼 덜)
  static const double nestFaster = 0.15;

  /// 부탁 알림 한 줄 (마을 사람 말풍선)
  static const String askLine = '부탁이 하나 있는데…';

  /// 묶음 69 #286: 부탁은 의뢰 게시판 「마을 사람 부탁」에서
  static const String boardAskLine = '게시판에 부탁 하나 붙여 뒀어!';

  // ───────────── 재료 묶음

  static const Set<MaterialId> flowerMushroom = {
    MaterialId.shadeMushroom,
    MaterialId.poisonMushroom,
    MaterialId.moonMushroom,
    MaterialId.springPetal,
    MaterialId.summerPetal,
    MaterialId.autumnPetal,
    MaterialId.winterPetal,
    MaterialId.sunPollen,
    MaterialId.breezeBloom,
  };

  static const Set<MaterialId> ores = {MaterialId.ironShard, MaterialId.manaOre};

  static const Set<MaterialId> gems = {
    MaterialId.gemFire,
    MaterialId.gemWater,
    MaterialId.gemWind,
    MaterialId.gemEarth,
    MaterialId.gemLight,
    MaterialId.gemDark,
    MaterialId.gemIce,
    MaterialId.gemThunder,
    MaterialId.gemMetal,
    MaterialId.gemPoison,
  };

  /// 몬스터가 떨어뜨리는 재료
  static final Set<MaterialId> monsterMats = {
    for (final m in MonsterId.values) ...[
      ...LootRules.dropsOf(m).common,
      LootRules.dropsOf(m).rare,
    ],
  };

  static Set<MaterialId> matsOf(NpcRequestStep s) => s.mats.isEmpty
      ? monsterMats
      : identical(s.mats, anyMatsMarker)
          ? anyMats
          // 묶음 67 #273: 약초는 아무 약초나
          : s.mats.contains(MaterialId.herb)
              ? {...s.mats, ...Materials.herbGroup}
              : s.mats;

  /// 묶음 51 바르칸 「서로 다른 재료 5종」: 가방의 재료 무엇이든 (가공 재료·하늘 깃털 빼고)
  static final Set<MaterialId> anyMats = {
    for (final m in Materials.all)
      if (!m.processed && m.id != MaterialId.skyFeather) m.id,
  };

  // ───────────── 부탁 28 (사람마다 4개, 차례대로)

  static const List<NpcRequest> requests = [
    // 마르타 (여관, Lv.1)
    NpcRequest(
      npc: Npc.marta,
      index: 0,
      stage: FavorStage.known,
      level: 1,
      say: '오늘 많이 걷고 와서 여기서 푹 쉬어 줄래? 땀 흘리고 와서 쉬어야 쉬는 맛이 나거든.',
      steps: [
        NpcRequestStep(RequestStepKind.tally, 1, '오늘 3,000보 걷고 여관에서 쉬기',
            key: NpcTally.rest3k),
      ],
      gifts: {'item:heal': 2},
      story: '이 여관은 원래 문지기들이 쉬어 가던 곳이었어. 밤마다 갑옷 소리로 시끌시끌했지.',
    ),
    NpcRequest(
      npc: Npc.marta,
      index: 1,
      stage: FavorStage.close,
      level: 5,
      say: '수프를 끓이려는데 꽃이랑 버섯이 모자라. 세 개만 구해다 줄래?',
      steps: [
        NpcRequestStep(RequestStepKind.deliver, 3, '꽃·버섯 3개 가져오기',
            mats: flowerMushroom),
      ],
      gifts: {'gold': 100},
      story: '내 아들 테오도 문지기였어. 이건 그 애가 제일 좋아하던 수프야.',
    ),
    NpcRequest(
      npc: Npc.marta,
      index: 2,
      stage: FavorStage.close,
      level: 9,
      say: '물가에 한 번 다녀와 줄래? 그리고 사흘은 꼭 여기서 쉬어. 요즘 네가 걱정돼서 그래.',
      steps: [
        NpcRequestStep(RequestStepKind.tally, 1, '물가 채집 1번', key: NpcTally.water),
        NpcRequestStep(RequestStepKind.innStreak, 3, '사흘 연속 여관에서 쉬기'),
      ],
      gifts: {'item:mana': 2},
      story: '문이 깨지던 날, 테오는 문 저편에 있었어. 그 뒤로 소식이 없어.',
    ),
    NpcRequest(
      npc: Npc.marta,
      index: 3,
      stage: FavorStage.best,
      level: 13,
      say: '고대 유물 자리에 옛 글씨가 남아 있대. 하나만 찾아다 줄래? 꼭 읽어 보고 싶은 게 있어.',
      steps: [
        NpcRequestStep(RequestStepKind.tally, 1, '고대 유물 채집 1번', key: NpcTally.relic),
      ],
      story: '언젠가 문이 다시 열리면… 테오에게 이 편지를 전해 줄래?',
      special: NpcSpecial(NpcSpecialKind.scarf, TitleId.npcMarta, '마르타의 손뜨개 목도리',
          '장신구 · 마르타가 한 코 한 코 뜬 따뜻한 목도리', 'equip_martaScarf'),
    ),
    // 미나 (잡화상, Lv.1)
    NpcRequest(
      npc: Npc.mina,
      index: 0,
      stage: FavorStage.known,
      level: 1,
      say: '마석 좀 팔아 주실래요? 대장간에 넘길 물량이 모자라서요!',
      steps: [
        NpcRequestStep(RequestStepKind.tally, 10, '잡화상에 마석 10개 팔기',
            key: NpcTally.stoneSold),
      ],
      gifts: {'gold': 80},
      story: '우리 집안은 대대로 두 세계를 오가는 행상이었어요!',
    ),
    NpcRequest(
      npc: Npc.mina,
      index: 1,
      stage: FavorStage.close,
      level: 6,
      say: '서로 다른 몬스터 재료 세 가지만 구해 주실래요? 견본으로 진열해 두려고요!',
      steps: [
        NpcRequestStep(RequestStepKind.deliver, 3, '서로 다른 몬스터 재료 3종 가져오기',
            distinct: true),
      ],
      gifts: {'item:manaSmall': 3},
      story: '할머니 수레는 문을 지나 저쪽 큰 장터까지 갔대요. 거기엔 별가루도 팔았다나요?',
    ),
    NpcRequest(
      npc: Npc.mina,
      index: 2,
      stage: FavorStage.close,
      level: 10,
      say: '새 교역로를 그리고 있어요. 안 가 본 곳 세 군데만 다녀와 주세요!',
      steps: [
        NpcRequestStep(RequestStepKind.tally, 3, '새 장소 3곳 다녀오기',
            key: NpcTally.newPlace),
      ],
      gifts: {'gold': 200},
      story: '문이 깨지고 길이 끊겼어요. 수레는 저쪽에 두고 왔죠. 지금 가게는… 남은 짐으로 차린 거예요.',
    ),
    NpcRequest(
      npc: Npc.mina,
      index: 3,
      stage: FavorStage.best,
      level: 17,
      say: '하루에 만 보를 걸으면 새 길이 보인대요. 한번 확인해 주실래요?',
      steps: [NpcRequestStep(RequestStepKind.daySteps, 10000, '하루 10,000보 걷기')],
      story: '다리가 생기면 제일 먼저 장사 깃발을 꽂을 거예요. 그날 같이 가요!',
      special: NpcSpecial(NpcSpecialKind.pouch, TitleId.npcMina, '미나의 짐 주머니',
          '가방 칸이 2칸 늘어요 (한 번 받으면 계속)', 'item_minaPouch'),
    ),
    // 도르군 (대장간, Lv.3)
    NpcRequest(
      npc: Npc.dorgun,
      index: 0,
      stage: FavorStage.known,
      level: 3,
      say: '…장비 하나 강화해 봐라. 네 손을 보고 싶다.',
      steps: [
        NpcRequestStep(RequestStepKind.tally, 1, '장비 하나 강화하기', key: NpcTally.enhance),
      ],
      gifts: {'ironShard': 3},
      story: '…이 망치는 탑을 지을 때 쓰던 거다.',
    ),
    NpcRequest(
      npc: Npc.dorgun,
      index: 1,
      stage: FavorStage.close,
      level: 8,
      say: '광석 다섯, 철 주괴 둘. 가져와라. 쓸 데가 있다.',
      steps: [
        NpcRequestStep(RequestStepKind.deliver, 5, '광석 5개 가져오기', mats: ores),
        NpcRequestStep(RequestStepKind.deliver, 2, '철 주괴 2개 가져오기',
            mats: {MaterialId.ironIngot}),
      ],
      gifts: {'manaStone': 5},
      story: '탑 꼭대기 등불 틀은 내가 두드렸다. 서른 날 밤낮으로.',
    ),
    NpcRequest(
      npc: Npc.dorgun,
      index: 2,
      stage: FavorStage.close,
      level: 10,
      say: '단단한 재료가 필요하다. 던전 보스를 세 번 쓰러뜨려라.',
      steps: [
        NpcRequestStep(RequestStepKind.tally, 3, '던전 보스 3번 쓰러뜨리기',
            key: NpcTally.dungeon),
      ],
      gifts: {'bossShard': 1},
      story: '문이 깨질 때 등불이 꺼졌지. 틀에 금이 갔다. 내 망치질이 모자랐던 거다.',
    ),
    NpcRequest(
      npc: Npc.dorgun,
      index: 3,
      stage: FavorStage.best,
      level: 19,
      say: '보석 셋, 그리고 잿빛 놈들의 흔적. 새 틀에 넣을 거다. 마지막 부탁이다.',
      steps: [
        NpcRequestStep(RequestStepKind.deliver, 3, '보석 3개 가져오기', mats: gems),
        NpcRequestStep(RequestStepKind.tally, 2, '슬라임 2마리 잡기',
            key: NpcTally.ashKill),
      ],
      story: '새 틀을 만들어 두겠다. 탑에 불이 다시 켜지는 날, 그 불은 이 틀에 담길 거다.',
      special: NpcSpecial(NpcSpecialKind.whetstone, TitleId.npcDorgun, '도르군의 숫돌',
          '강화를 한 번 꼭 성공시켜요 (1개, 대장간 강화에서 써요)', 'item_dorgunWhetstone'),
    ),
    // 엘리엘 (연금술 공방, Lv.7)
    NpcRequest(
      npc: Npc.eliel,
      index: 0,
      stage: FavorStage.known,
      level: 7,
      say: '물약을 세 번만 끓여 봐 주실래요? 가마솥 상태를 보고 싶어요!',
      steps: [NpcRequestStep(RequestStepKind.tally, 3, '물약 3번 끓이기', key: NpcTally.brew)],
      gifts: {'herb': 3},
      story: '저는 빛을 병에 담는 연구를 했어요. 진짜예요!',
    ),
    NpcRequest(
      npc: Npc.eliel,
      index: 1,
      stage: FavorStage.close,
      level: 9,
      say: '물가의 맑은 기운이랑 정제 에센스 하나가 필요해요. 부탁해요!',
      steps: [
        NpcRequestStep(RequestStepKind.tally, 1, '물가 채집 1번', key: NpcTally.water),
        NpcRequestStep(RequestStepKind.deliver, 1, '정제 에센스 1개 가져오기',
            mats: {MaterialId.essence}),
      ],
      gifts: {'note': 1},
      story: '저쪽 세계는 빛이 모자랐어요. 병에 담아 두면 아껴 쓸 수 있을 줄 알았죠.',
    ),
    NpcRequest(
      npc: Npc.eliel,
      index: 2,
      stage: FavorStage.close,
      level: 13,
      say: '아침 빛을 모으고 싶어요. 새벽 다섯 시부터 아홉 시 사이에 3,000보만 걸어 주실래요?',
      steps: [
        NpcRequestStep(RequestStepKind.dawnSteps, 3000, '이른 아침(새벽 5~9시) 3,000보 걷기'),
      ],
      gifts: {'gemLight': 1},
      story: '왕께서도 제 연구를 보러 오셨어요. 그분은 \'모자라면 빼앗으면 된다\'고 하셨죠…',
    ),
    NpcRequest(
      npc: Npc.eliel,
      index: 3,
      stage: FavorStage.best,
      level: 17,
      say: '처음 보는 물약 하나만 알아내 주세요. 마지막 연구에 꼭 필요해요!',
      steps: [
        NpcRequestStep(RequestStepKind.tally, 1, '처음 보는 물약 레시피 하나 알아내기',
            key: NpcTally.newRecipe),
      ],
      story: '빼앗지 않고 나누는 빛. 그게 제 답이에요. 다리가 생기면 이 병들을 들고 갈 거예요.',
      special: NpcSpecial(NpcSpecialKind.dawnLight, TitleId.npcEliel, '여명의 빛 물약 레시피',
          'HP와 기력이 모두 가득 차는 물약 (한 병 함께)', 'potion_dawnLight'),
    ),
    // 하르트 (의뢰 게시판, Lv.4)
    NpcRequest(
      npc: Npc.hart,
      index: 0,
      stage: FavorStage.known,
      level: 4,
      say: '조합 의뢰가 밀려 있네. 세 건만 맡아 주겠나?',
      steps: [
        NpcRequestStep(RequestStepKind.tally, 3, '조합 의뢰 3건 끝내기',
            key: NpcTally.guildErrand),
      ],
      gifts: {'gold': 100},
      story: '이 게시판 나무는 옛 문지기 초소 문짝이었네.',
    ),
    NpcRequest(
      npc: Npc.hart,
      index: 1,
      stage: FavorStage.close,
      level: 8,
      say: '던전 안쪽이 수상하네. 두 번만 다녀와 주게.',
      steps: [NpcRequestStep(RequestStepKind.tally, 2, '던전 2번 클리어', key: NpcTally.dungeon)],
      gifts: {'item:spareKey': 1},
      story: '나도 문지기 기사단이었지. 작은 빛 하나가 늘 내 어깨에 있었네.',
    ),
    NpcRequest(
      npc: Npc.hart,
      index: 2,
      stage: FavorStage.close,
      level: 11,
      say: '자네 펫과 원정을 세 번 다녀와 보게. 그 아이 솜씨를 보고 싶네.',
      steps: [
        NpcRequestStep(RequestStepKind.tally, 3, '첫 펫과 원정 3번',
            key: NpcTally.petExpedition),
      ],
      gifts: {'item:bulssiPotion': 2},
      story: '자네 정령… 문 안으로 들어갔다지. 그 빛, 내가 알던 아이일지도 모르겠군.',
    ),
    NpcRequest(
      npc: Npc.hart,
      index: 3,
      stage: FavorStage.best,
      level: 15,
      say: '긴급 의뢰 두 건. 자네라면 해낼 걸세.',
      steps: [
        NpcRequestStep(RequestStepKind.tally, 2, '긴급 의뢰 2건 끝내기', key: NpcTally.urgent),
      ],
      story: '문이 깨지던 날 나는 이쪽에 있었네. 지키지 못했어. 자네는 끝까지 가게.',
      special: NpcSpecial(NpcSpecialKind.keys, TitleId.npcHart, '여분의 열쇠 3개',
          '던전 열쇠를 하나씩 더 얻어요', 'icon_key'),
    ),
    // 세라 (길드, Lv.15)
    NpcRequest(
      npc: Npc.sera,
      index: 0,
      stage: FavorStage.known,
      level: 15,
      say: '직업 스킬을 다섯 번 써 보아라. 손에 익혀야 한다.',
      steps: [
        NpcRequestStep(RequestStepKind.tally, 5, '직업 스킬 5번 쓰기', key: NpcTally.jobSkill),
      ],
      gifts: {'item:jobMana': 2},
      story: '나는 한때 왕의 근위 기사였다.',
    ),
    NpcRequest(
      npc: Npc.sera,
      index: 1,
      stage: FavorStage.close,
      level: 16,
      say: '잿빛 분신 하나를 쓰러뜨려라. 그들의 얼굴을 알아야 한다.',
      steps: [NpcRequestStep(RequestStepKind.clone, 1, '잿빛 분신 하나 쓰러뜨리기')],
      gifts: {'relicSeal': 1},
      story: '왕은 백성을 사랑했다. 그래서 빛이 꺼질 때 누구보다 아파했지.',
    ),
    NpcRequest(
      npc: Npc.sera,
      index: 2,
      stage: FavorStage.close,
      level: 18,
      say: '필드 몬스터 스무 마리. 몸이 기억하게 해라.',
      steps: [
        NpcRequestStep(RequestStepKind.tally, 20, '필드 몬스터 20마리 잡기',
            key: NpcTally.fieldKill),
      ],
      gifts: {'manaStone': 8},
      story: '왕이 문 너머 빛을 빼앗자고 했을 때, 나는 검을 내려놓고 떠났다.',
    ),
    NpcRequest(
      npc: Npc.sera,
      index: 3,
      stage: FavorStage.best,
      level: 20,
      say: '분신 다섯을 모두 쓰러뜨려라. 그래야 왕 앞에 설 수 있다.',
      steps: [NpcRequestStep(RequestStepKind.allClones, 5, '분신 다섯 모두 쓰러뜨리기')],
      story: '왕을 멈춰 다오. 내가 못 한 일이다. …그리고 할 수 있다면, 그분을 용서해 다오.',
      special: NpcSpecial(NpcSpecialKind.badge, TitleId.npcSera, '세라의 휘장',
          '장신구 · 근위 기사단의 낡은 휘장', 'equip_seraBadge'),
    ),
    // 루미 (펫 쉼터, 첫 펫 Lv.11)
    NpcRequest(
      npc: Npc.lumi,
      index: 0,
      stage: FavorStage.known,
      level: 11,
      say: '펫한테 간식 세 번만 줘 볼래? 애들이 좋아하는 얼굴 보고 싶어!',
      steps: [NpcRequestStep(RequestStepKind.tally, 3, '펫에게 간식 3번 주기', key: NpcTally.snack)],
      gifts: {'item:bulssiPotion': 2},
      story: '나는 숲속 수인 마을에서 왔어. 짐승들이랑 같이 자랐지!',
    ),
    NpcRequest(
      npc: Npc.lumi,
      index: 1,
      stage: FavorStage.close,
      level: 13,
      say: '펫이랑 같이 5,000보 걸어 줄래? 산책이 최고야!',
      steps: [NpcRequestStep(RequestStepKind.stepsSince, 5000, '펫과 함께 5,000보 걷기')],
      gifts: {'gold': 150},
      story: '내 단짝은 은빛 늑대 \'바람\'이었어. 문이 깨질 때 저쪽에 남았어.',
    ),
    NpcRequest(
      npc: Npc.lumi,
      index: 2,
      stage: FavorStage.close,
      level: 17,
      say: '알 하나 깨워 줄래? 새 친구가 보고 싶어!',
      steps: [NpcRequestStep(RequestStepKind.tally, 1, '알 하나 깨우기', key: NpcTally.hatch)],
      gifts: {'item:bulssiPotion': 3},
      story: '바람은 지금도 문 앞에서 기다리고 있을 거야. 늘 그랬거든.',
    ),
    NpcRequest(
      npc: Npc.lumi,
      index: 3,
      stage: FavorStage.best,
      level: 19,
      say: '펫 하나를 다 키워 줄래? 다 큰 모습을 꼭 보고 싶어!',
      steps: [NpcRequestStep(RequestStepKind.adultPet, 1, '펫 하나 성체로 키우기')],
      story: '다리가 생기면 바람을 데리러 갈 거야. 그때 너도 같이 가 줘!',
      special: NpcSpecial(NpcSpecialKind.nest, TitleId.npcLumi, '루미의 둥지 장식',
          '알이 조금 더 빨리 깨어나요', 'item_lumiNest'),
    ),
    // 가렌 (훈련장, Lv.13 · 묶음 43 #228). 부탁 말은 개발 초안
    NpcRequest(
      npc: Npc.garen,
      index: 0,
      stage: FavorStage.known,
      level: 13,
      say: '허수아비부터다! 연습에서 강타, 방어 태세, 스킬을 한 번씩 써 봐라!',
      steps: [
        NpcRequestStep(RequestStepKind.tally, 1, '연습에서 강타 쓰기', key: NpcTally.practiceBash),
        NpcRequestStep(RequestStepKind.tally, 1, '연습에서 방어 태세 쓰기',
            key: NpcTally.practiceStance),
        NpcRequestStep(RequestStepKind.tally, 1, '연습에서 스킬 쓰기', key: NpcTally.practiceSkill),
      ],
      gifts: {'gold': 100},
      story: '이 훈련장은 문지기 기사단 신병들이 땀 흘리던 곳이다. 하르트 녀석도 여기서 굴렀지!',
    ),
    NpcRequest(
      npc: Npc.garen,
      index: 1,
      stage: FavorStage.close,
      level: 14,
      say: '몸은 하루아침에 안 만들어진다! 하루 훈련을 사흘 해 와라!',
      steps: [
        NpcRequestStep(RequestStepKind.tally, 3, '하루 훈련 3일 하기', key: NpcTally.dailyTraining),
      ],
      gifts: {'item:heal': 2},
      story: '문이 깨지던 날, 난 신병 다섯을 데리고 문 앞에 있었다. 이 다리는 그날 얻은 거다.',
    ),
    NpcRequest(
      npc: Npc.garen,
      index: 2,
      stage: FavorStage.close,
      level: 16,
      say: '시련에 나가 봐라! 열 판은 넘겨야 내 제자라 할 수 있다!',
      steps: [
        NpcRequestStep(RequestStepKind.tally, 1, '시련에서 10판 넘기기', key: NpcTally.trial10),
      ],
      gifts: {'labyrinthCore': 1},
      story: '넷은 데리고 나왔다. 한 녀석… 테오만 문 저편에 남았지. 마르타 얼굴을 볼 면목이 없다.',
    ),
    NpcRequest(
      npc: Npc.garen,
      index: 3,
      stage: FavorStage.best,
      level: 18,
      say: '펫도 함께 단련해라! 그리고 잿빛 분신 하나를 쓰러뜨리고 와라!',
      steps: [
        NpcRequestStep(RequestStepKind.tally, 3, '펫 훈련 3번 하기', key: NpcTally.petTraining),
        NpcRequestStep(RequestStepKind.clone, 1, '잿빛 분신 하나 쓰러뜨리기'),
      ],
      story: '다리가 놓이면 내가 제일 먼저 건너가 그 녀석을 데려오겠다. …그때까지 네가 내 대신 강해져라!',
      special: NpcSpecial(NpcSpecialKind.band, TitleId.npcGaren, '가렌의 훈련 완장',
          '장신구 · 문지기 기사단 교관의 완장', 'equip_garenBand'),
    ),
    // 포포 (약초밭, Lv.9 · 묶음 48 #230). 부탁 말은 개발 초안
    NpcRequest(
      npc: Npc.popo,
      index: 0,
      stage: FavorStage.known,
      level: 9,
      say: '씨앗 하나만 심어서 끝까지 키워 줄래요?! 걸으면 걸을수록 쑥쑥 커요!',
      steps: [
        NpcRequestStep(RequestStepKind.tally, 1, '씨앗 하나 심어서 다 키우기',
            key: NpcTally.gardenHarvest),
      ],
      gifts: {'herbSeed': 3},
      story: '저쪽 세계 숲은 아주아주 컸어요! 나무가 하늘까지 닿았다니까요!',
    ),
    NpcRequest(
      npc: Npc.popo,
      index: 1,
      stage: FavorStage.close,
      level: 10,
      say: '채집하다 보면 씨앗이 가끔 떨어져 있어요! 두 개만 찾아 줄래요? 밭을 한 칸 넓힐게요!',
      steps: [
        NpcRequestStep(RequestStepKind.tally, 2, '채집하다 씨앗 2개 찾기', key: NpcTally.seedFound),
      ],
      story: '빛이 꺼지기 시작하자 숲이 하나씩 잠들었어요. 저는 씨앗 주머니만 꼭 안고 도망쳤죠.',
    ),
    NpcRequest(
      npc: Npc.popo,
      index: 2,
      stage: FavorStage.close,
      level: 13,
      say: '밭에 물을 주려면 발걸음이 많이 필요해요! 하루에 6,000보, 할 수 있죠?!',
      steps: [NpcRequestStep(RequestStepKind.daySteps, 6000, '하루 6,000보 걷기 (밭에 물 주기)')],
      story: '이 씨앗들이 마지막이에요. 여기서 키워서, 언젠가 꼭 돌려보내고 싶어요.',
    ),
    NpcRequest(
      npc: Npc.popo,
      index: 3,
      stage: FavorStage.best,
      level: 17,
      say: '빛나는 씨앗을 하나 끝까지 키워 줄래요? 저쪽 숲에서 가장 소중한 씨앗이에요!',
      steps: [
        NpcRequestStep(RequestStepKind.tally, 1, '빛나는 씨앗 하나 다 키우기', key: NpcTally.gardenGlow),
      ],
      story: '다리가 생기면… 이 밭의 씨앗을 저쪽 숲에 심으러 갈 거예요. 그때 같이 가 줄래요?!',
      special: NpcSpecial(NpcSpecialKind.garden, TitleId.forestKeeper, '약초밭 6칸째 · 빛나는 씨앗 2',
          '포포가 아끼던 마지막 밭 한 칸과 빛나는 씨앗', 'seed_glow'),
    ),
    // 리안 (주점, 결말 뒤 · 묶음 51 #242). 레벨 문턱 없음 (결말 뒤라서)
    NpcRequest(
      npc: Npc.lian,
      index: 0,
      stage: FavorStage.known,
      level: 1,
      say: '주점 첫 손님이 되어 주세요! 오늘 5,000보만 걷고 와서 한잔해요. 물이요, 물.',
      steps: [NpcRequestStep(RequestStepKind.daySteps, 5000, '하루 5,000보 걷기')],
      gifts: {'gold': 100},
      story: '제 틈엔 마을이 없었어요. 배낭 하나 메고, 정령이랑 둘이서만 걸었죠.',
    ),
    NpcRequest(
      npc: Npc.lian,
      index: 1,
      stage: FavorStage.close,
      level: 1,
      say: '제 틈의 길도 이어졌을까요? 안 가 본 곳 세 군데만 같이 확인해 줘요.',
      steps: [
        NpcRequestStep(RequestStepKind.tally, 3, '안 가 본 곳 3곳 다녀오기', key: NpcTally.newPlace),
      ],
      gifts: {'item:heal': 2},
      story: '분노 분신까지는 어떻게든 쓰러뜨렸어요. 그런데 슬픔 분신 앞에서 몇 달을 멈춰 있었어요.',
    ),
    NpcRequest(
      npc: Npc.lian,
      index: 2,
      stage: FavorStage.close,
      level: 1,
      say: '같이 걷는 연습이요. 펫이랑 함께 8,000보, 천천히 걸어 봐요.',
      steps: [NpcRequestStep(RequestStepKind.stepsSince, 8000, '펫과 함께 8,000보 걷기')],
      gifts: {'manaStone': 8},
      story: '그때 알았어요. 저 혼자서는 문 앞까지 못 간다는 걸. 그래서 매일 걸으면서 누군가 해내기를 기다렸어요.',
    ),
    NpcRequest(
      npc: Npc.lian,
      index: 3,
      stage: FavorStage.best,
      level: 1,
      say: '일주일 동안 하루도 빠짐없이요. 매일 3,000보, 우리 같이 해 봐요.',
      steps: [
        NpcRequestStep(RequestStepKind.dayStreak, 7, '7일 이어서 매일 3,000보 걷기', min: 3000),
      ],
      story: '틈이 이어지던 날, 처음으로 다른 사람 발소리를 들었어요. …그래서 이 주점을 열었어요. 아무도 혼자 걷지 않게.',
      special: NpcSpecial(NpcSpecialKind.knot, TitleId.walkTogether, '리안의 배낭 매듭',
          '장신구 · 걸을 때 기력이 조금 더 빨리 차요', 'equip_lianKnot'),
    ),
    // 바르칸 (거래소, 결말 뒤 · 묶음 51 #229). 서버 없이 되는 할 일만
    NpcRequest(
      npc: Npc.barkan,
      index: 0,
      stage: FavorStage.known,
      level: 1,
      say: '장터 둘레 길부터 익히게. 하루 6,000보면 길이 눈에 들어올 걸세.',
      steps: [NpcRequestStep(RequestStepKind.daySteps, 6000, '하루 6,000보 걷기')],
      gifts: {'gold': 120},
      story: '우리 상단은 저쪽 세계 큰 장터를 누볐네. 별가루며 빛 보석이며, 없는 게 없었지.',
    ),
    NpcRequest(
      npc: Npc.barkan,
      index: 1,
      stage: FavorStage.close,
      level: 1,
      say: '상단 견본이 필요하네. 서로 다른 재료 다섯 가지만 가져오게.',
      steps: [
        NpcRequestStep(RequestStepKind.deliver, 5, '서로 다른 재료 5종 가져오기',
            mats: anyMatsMarker, distinct: true),
      ],
      gifts: {'manaStone': 8},
      story: '미나 할머니는 내 가장 오랜 거래 상대였지. 셈은 나보다 빨랐어, 허허.',
    ),
    NpcRequest(
      npc: Npc.barkan,
      index: 2,
      stage: FavorStage.close,
      level: 1,
      say: '수레 바퀴를 손봐야겠어. 나무 두 번 캐 오고, 철 주괴 하나만 구해 주게.',
      steps: [
        NpcRequestStep(RequestStepKind.tally, 2, '나무 2번 캐기', key: 'gather:wood'),
        NpcRequestStep(RequestStepKind.deliver, 1, '철 주괴 1개 가져오기',
            mats: {MaterialId.ironIngot}),
      ],
      gifts: {'item:heal': 2},
      story: '문이 깨지던 날, 그 집안은 이쪽 틈에 걸리고 수레만 내 장터에 남았네. 언젠가 돌려주려고 날마다 닦아 두었지.',
    ),
    NpcRequest(
      npc: Npc.barkan,
      index: 3,
      stage: FavorStage.best,
      level: 1,
      say: '새 교역로를 그리세. 안 가 본 곳 다섯 군데, 그리고 하루 10,000보일세.',
      steps: [
        NpcRequestStep(RequestStepKind.tally, 5, '안 가 본 곳 5곳 다녀오기', key: NpcTally.newPlace),
        NpcRequestStep(RequestStepKind.daySteps, 10000, '하루 10,000보 걷기'),
      ],
      story: '빛을 빼앗던 시절엔 장사도 숨이 막혔지. 이제는 나눠서 사고팔면 되네. 그게 장사꾼이 바라던 다리일세.',
      special: NpcSpecial(NpcSpecialKind.seal, TitleId.merchantFriend, '바르칸의 상단 인장',
          '소중한 물건 · 거래소에 물건을 올릴 때 드는 금화가 줄어요', 'item_barkanSeal'),
    ),
  ];

  /// 바르칸 「서로 다른 재료 5종」 표시 (실제 재료는 [anyMats])
  static const Set<MaterialId> anyMatsMarker = {MaterialId.skyFeather};

  static List<NpcRequest> of(Npc n) => [
        for (final r in requests)
          if (r.npc == n) r,
      ];

  /// [n] 의 [index] 번째 부탁 (없으면 null)
  static NpcRequest? at(Npc n, int index) {
    final l = of(n);
    return index >= 0 && index < l.length ? l[index] : null;
  }

  // ───────────── 단계가 오르면 섞이는 새 대사 2줄 (개발 초안)

  static const Map<Npc, Map<FavorStage, List<String>>> stageLines = {
    Npc.marta: {
      FavorStage.known: ['또 왔구나! 네 발소리는 이제 알아.', '다친 데는 없지? 없어도 수프는 먹고 가.'],
      FavorStage.close: ['요즘은 네가 안 오면 문 쪽만 보게 돼.', '너 오는 날엔 수프를 조금 더 끓여 둬.'],
      FavorStage.best: ['너는 이제 우리 집 식구야. 방 하나는 늘 비워 둘게.', '힘들면 아무 말 안 해도 돼. 그냥 와서 쉬어.'],
    },
    Npc.mina: {
      FavorStage.known: ['아, 단골 후보님 오셨네요!', '오늘은 뭘 찾으세요? 없는 건… 거의 없어요!'],
      FavorStage.close: ['손님한텐 특별히 좋은 물건부터 보여 드릴게요.', '장부에 이름 적어 뒀어요. 단골 칸에요!'],
      FavorStage.best: ['우리 사이에 흥정은 필요 없죠. 제가 알아서 챙겨 드릴게요!', '언젠가 같이 장삿길에 나가요. 진짜로요!'],
    },
    Npc.dorgun: {
      FavorStage.known: ['…왔나. 연장은 잘 쓰고 있겠지.', '손을 보면 안다. 너는 일을 하는 손이다.'],
      FavorStage.close: ['네 장비는 내가 따로 본다. 허투루 두드리지 않는다.', '망치 소리가 들리면 언제든 들어와라.'],
      FavorStage.best: ['…너라면 내 망치를 맡겨도 되겠군.', '수리비는 신경 쓰지 마라. 내 기분이다.'],
    },
    Npc.eliel: {
      FavorStage.known: ['아, 또 오셨네요! 마침 재미있는 걸 발견했어요!', '이 병은 만지지 마세요. 아마 괜찮겠지만요!'],
      FavorStage.close: ['실험 노트에 이름을 적어 뒀어요. 조수로요!', '같이 끓이면 물약도 더 잘 나오는 것 같아요.'],
      FavorStage.best: ['함께 있으면 실패해도 즐거워요. 진짜예요!', '재료는 걱정 마세요. 제 몫에서 조금 덜어 쓸게요.'],
    },
    Npc.hart: {
      FavorStage.known: ['오, 자네 왔나. 게시판 앞이 든든하군.', '의뢰는 많고 손은 모자라네. 자네가 있어 다행이야.'],
      FavorStage.close: ['자네 이름을 게시판 맨 위에 적어 둘까 싶네.', '젊을 때 내 모습을 보는 것 같군.'],
      FavorStage.best: ['자네라면 어떤 의뢰든 믿고 맡기겠네.', '보상은 조금 더 얹어 두었네. 이 늙은이 마음이야.'],
    },
    Npc.sera: {
      FavorStage.known: ['왔군. 오늘도 네 길을 걷고 있나.', '검을 쥔 손에 망설임이 줄었군.'],
      FavorStage.close: ['너를 보면 기사단 시절이 떠오른다.', '힘들 땐 멈춰도 된다. 다만 돌아서지는 마라.'],
      FavorStage.best: ['네 등은 내가 지킨다. 그것이 내 새로운 맹세다.', '너는 이미 누구보다 빨리 자라고 있다.'],
    },
    Npc.lumi: {
      FavorStage.known: ['또 왔네! 애들이 네 냄새를 기억해!', '쓰다듬는 법이 늘었어. 애들이 좋아해!'],
      FavorStage.close: ['너랑 있으면 애들이 꼬리를 더 세게 흔들어!', '내 비밀 간식 숨긴 곳, 너한테만 알려 줄게.'],
      FavorStage.best: ['너는 이제 우리 무리야! 바람도 너를 좋아했을 거야.', '애들이 너만 보면 달려가. 나보다 더 좋아하는 것 같아!'],
    },
    Npc.garen: {
      FavorStage.known: ['오, 또 왔구나! 발걸음이 가벼워졌다!', '팔에 힘이 붙었다! 허수아비가 겁먹겠다!'],
      FavorStage.close: ['너를 보면 신병 시절 하르트가 떠오른다! 그 녀석보다는 낫다!', '힘들면 쉬어도 된다! 다만 포기는 하지 마라!'],
      FavorStage.best: ['너라면 기사단 깃발을 맡겨도 되겠다!', '오늘 훈련 보상은 내가 조금 더 챙겨 두마! 비밀이다!'],
    },
    Npc.popo: {
      FavorStage.known: ['또 왔어요?! 새싹들이 손님 발소리를 알아들어요!', '오늘은 몇 걸음 걸었어요? 밭이 벌써 궁금해해요!'],
      FavorStage.close: ['손님 덕분에 밭이 반짝반짝해요! 진짜예요!', '씨앗 주머니에 손님 이름도 적어 뒀어요. 소중한 사람 칸에요!'],
      FavorStage.best: ['손님은 이제 우리 숲 식구예요! 나무들도 그렇게 말할 거예요!', '거둘 때 하나씩 더 몰래 넣어 둘게요! 쉿, 비밀이에요!'],
    },
    Npc.lian: {
      FavorStage.known: ['또 왔네요. 자리 비워 뒀어요, 창가 쪽으로.', '오늘 걸음은 어땠어요? 저는 오늘 길을 두 번 잃었어요.'],
      FavorStage.close: ['당신 발소리는 이제 문 열기 전에 알아요.', '같이 걸을 사람 명단 맨 위에 당신 이름 적어 뒀어요.'],
      FavorStage.best: ['당신이 있어서 이 주점을 연 보람이 있어요. 진짜로요.', '한 끼는 조금 넉넉히 담았어요. 오래 든든할 거예요.'],
    },
    Npc.barkan: {
      FavorStage.known: ['오, 또 왔구먼. 발소리가 장사꾼 귀엔 금화 소리지.', '미나 녀석이 자네 칭찬을 늘어놓더군.'],
      FavorStage.close: ['자네 이름은 상단 장부 맨 앞에 적어 두었네.', '흥정하는 눈이 제법이야. 우리 상단에 들어오겠나? 허허, 농담일세.'],
      FavorStage.best: ['자네라면 내 수레 열쇠를 맡겨도 되겠어.', '자네한테 수수료를 다 받으면 내가 장사꾼이 아니지.'],
    },
  };

  /// 지금 단계의 새 대사 (낯섦이면 없음)
  static List<String> linesAt(Npc n, FavorStage s) =>
      stageLines[n]?[s] ?? const [];

  // ───────────── 단계가 오르면 오는 작은 선물 우편 (개발 초안)

  static const Map<Npc, Map<FavorStage, FavorLetter>> letters = {
    Npc.marta: {
      FavorStage.known: FavorLetter('또 와 줘서 고마워',
          '손님이 다시 오는 게 여관 주인한텐 제일 큰 기쁨이야. 작은 회복 물약 하나 넣었어.',
          {'item:healSmall': 1}),
      FavorStage.close: FavorLetter('수프 한 그릇',
          '요즘 네 얼굴이 밝아 보여서 좋아. 수프는 못 보내니 물약 두 병 보내. 꼭 챙겨 먹어.',
          {'item:healSmall': 2}),
      FavorStage.best: FavorLetter('우리 집 식구에게',
          '이제 네 방은 늘 비워 둘게. 앞으로 여관에서 조금 더 빨리 회복할 거야. 작은 선물이야.', {'item:heal': 2}),
    },
    Npc.mina: {
      FavorStage.known: FavorLetter('단골 후보님께',
          '또 와 주셔서 감사해요! 덤으로 금화 조금 넣었어요. 비밀이에요!', {'gold': 30}),
      FavorStage.close: FavorLetter('단골 장부에 올렸어요',
          '이름을 단골 장부에 올렸어요! 기념으로 작은 기력 물약이에요.', {'item:manaSmall': 2}),
      FavorStage.best: FavorLetter('최고의 단골에게',
          '이제 우리 가게 최고의 단골이에요. 앞으로 값은 제가 알아서 챙길게요!', {'gold': 100}),
    },
    Npc.dorgun: {
      FavorStage.known: FavorLetter('연장 손질',
          '…연장을 아껴 쓰는 게 보였다. 철 조각 몇 개 보낸다.', {'ironShard': 3}),
      FavorStage.close: FavorLetter('쓸 만한 손',
          '네 손은 쓸 만하다. 주괴 하나 보낸다. 허투루 쓰지 마라.', {'ironIngot': 1}),
      FavorStage.best: FavorLetter('내 망치를 믿는 자에게',
          '앞으로 수리는 내가 덜 받겠다. 대신 연장을 아껴라.', {'manaStone': 5}),
    },
    Npc.eliel: {
      FavorStage.known: FavorLetter('실험 결과 보고',
          '또 와 주셔서 기뻐요! 실험하다 남은 약초예요. 아마 멀쩡해요!', {'herb': 3}),
      FavorStage.close: FavorLetter('조수님께',
          '덕분에 실험이 잘 돼요! 정제 에센스 하나 보내요.', {'essence': 1}),
      FavorStage.best: FavorLetter('가장 소중한 연구 동료',
          '재료가 모자라면 제 몫에서 덜어 쓸게요. 우리 같이 빛을 담아요!', {'note': 1}),
    },
    Npc.hart: {
      FavorStage.known: FavorLetter('든든한 얼굴',
          '게시판 앞에 자네가 보이면 마음이 놓이네. 작은 감사일세.', {'gold': 50}),
      FavorStage.close: FavorLetter('이름을 적어 두었네',
          '자네 이름을 믿을 사람 명단에 적어 두었네. 열쇠 하나 넣네.', {'item:spareKey': 1}),
      FavorStage.best: FavorLetter('믿을 수 있는 각성자',
          '앞으로 자네 의뢰엔 내가 조금씩 얹어 주겠네. 늙은이 마음이니 받아 두게.', {'gold': 150}),
    },
    Npc.sera: {
      FavorStage.known: FavorLetter('조합에서',
          '네가 조합에 자주 오는 걸 봤다. 작은 마나 물약을 보낸다.', {'item:jobManaSmall': 2}),
      FavorStage.close: FavorLetter('기사의 조언',
          '급히 가지 마라. 그러나 멈추지도 마라. 마석 몇 개 보낸다.', {'manaStone': 5}),
      FavorStage.best: FavorLetter('새로운 맹세',
          '네 곁을 지키겠다. 이것이 내 새로운 맹세다.', {'manaStone': 10}),
    },
    Npc.lumi: {
      FavorStage.known: FavorLetter('애들이 보고 싶대',
          '애들이 네 얘기만 해! 간식 하나 보낼게.', {'item:bulssiPotion': 1}),
      FavorStage.close: FavorLetter('내 비밀 간식',
          '비밀 간식 나눠 줄게. 애들한테 줘!', {'item:bulssiPotion': 2}),
      FavorStage.best: FavorLetter('우리 무리에게',
          '너는 이제 우리 무리야! 애들이랑 더 빨리 친해질 거야.', {'item:bulssiPotion': 3}),
    },
    Npc.garen: {
      FavorStage.known: FavorLetter('자세가 좋아졌다',
          '처음보다 자세가 훨씬 낫다! 땀 흘린 뒤에 마셔라!', {'item:healSmall': 2}),
      FavorStage.close: FavorLetter('신병 명부에 올렸다',
          '네 이름을 기사단 신병 명부에 적어 뒀다! 마석 몇 개 보낸다!', {'manaStone': 5}),
      FavorStage.best: FavorLetter('내 대신 강해져라',
          '이제 너는 내 제자다! 앞으로 하루 훈련 보상은 조금 더 챙겨 주마!', {'gold': 150}),
    },
    Npc.popo: {
      FavorStage.known: FavorLetter('새싹이 인사해요',
          '밭에 자주 와 줘서 고마워요! 새로 받은 씨앗 하나 넣었어요!', {'herbSeed': 2}),
      FavorStage.close: FavorLetter('꽃이 피었어요',
          '손님이 걸어 준 덕분에 꽃이 피었어요! 꽃 씨앗 나눠 드려요!', {'flowerSeed': 2}),
      FavorStage.best: FavorLetter('숲의 식구에게',
          '이제 손님은 우리 숲 식구예요! 아끼던 버섯 포자도 드릴게요!', {'sporeSeed': 3}),
    },
    Npc.lian: {
      FavorStage.known: FavorLetter('주점 단골 1호',
          '또 와 줘서 고마워요. 주점 첫 단골이에요! 오늘 밥값 조금 넣어 뒀어요.', {'gold': 40}),
      FavorStage.close: FavorLetter('같이 걷는 사람에게',
          '요즘 당신이랑 걸은 날이 제일 즐거워요. 지칠 때 마셔요.', {'item:heal': 1}),
      FavorStage.best: FavorLetter('혼자가 아니었던 사람에게',
          '틈 저편에서 혼자 걷던 때가 거짓말 같아요. 고마워요. 진짜로요.', {'manaStone': 8}),
    },
    Npc.barkan: {
      FavorStage.known: FavorLetter('첫 인사일세',
          '허허, 다리 건너 첫 손님에게 인사를 안 할 수 있나. 받아 두게.', {'gold': 50}),
      FavorStage.close: FavorLetter('상단 장부에 올렸네',
          '자네 이름을 상단 장부에 올렸네. 기념일세.', {'manaStone': 5}),
      FavorStage.best: FavorLetter('상단의 벗에게',
          '셈은 정확히, 인심은 넉넉히. 이번엔 인심 쪽일세, 허허.', {'gold': 200}),
    },
  };
}
