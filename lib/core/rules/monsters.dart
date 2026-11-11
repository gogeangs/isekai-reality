import 'element_rules.dart';

/// 몬스터 (11-10 '정화' → '사냥'으로 바꿈).
///
/// 몬스터는 사냥하면 쓰러지고 사라진다. 정화된 모습·이름은 쓰지 않는다.
/// 정령은 각성자의 동료 전용이라 정령계 몬스터(물방울 정령·돌정령)는 뺐다.
/// 예전 기록을 읽으려고 id 는 남겨 두고 [MonsterInfo.retired] 로 숨긴다.
///
/// 11-11 #31·#40: 혼래빗·아기 와일드 보어, 슬라임 속성 6종(각각 다른 몬스터로 기록).
enum MonsterId {
  ashSlime,
  labyrinthBat,
  roughWaterSpirit,
  shadowButterfly,
  lostStoneSpirit,
  labyrinthWarden,
  giantRat,
  hornRabbit,
  babyBoar,
  fireSlime,
  waterSlime,
  windSlime,
  earthSlime,
  lightSlime,
  darkSlime,
  // 11-11 #63 새 속성 슬라임
  iceSlime,
  thunderSlime,
  metalSlime,
  poisonSlime,
  // 11-11 #75 던전 보스 (요일마다)
  fireSlimeKing,
  frostWolfKing,
  ancientTreant,
  shadowBatQueen,
  thunderGriffin,
}

/// 전투 성향 (도감 설명)
enum Tendency { sturdy, nimble, arcane, charm }

/// 몬스터만의 전투 특징 (11-11)
enum MonsterTrait {
  none,

  /// 맞히면 30% 확률로 화상 3턴 (매 턴 최대 HP 2%)
  burn,

  /// 매 턴 끝에 자기 최대 체력의 5% 회복
  regen,

  /// 각성자 공격을 15% 피함
  evade,

  /// 눈부심: 각성자 공격이 25% 빗나감
  dazzle,

  /// 때린 피해의 30%만큼 체력 회복
  drain,

  /// 맞히면 30% 확률로 중독 3턴 (11-11 #63 독 슬라임)
  poison,

  /// 맞히면 20% 확률로 얼어 다음 차례를 쉼 (11-11 #74 얼음 슬라임)
  freeze,

  /// 맞히면 낮은 확률로 약한 중독 (11-11 A4 큰쥐: 2턴 동안 매 턴 최대 HP 1%)
  weakPoison,
}

class MonsterInfo {
  const MonsterInfo({
    required this.id,
    required this.name,
    required this.habitat,
    required this.huntLine,
    this.description = '',
    this.tendency = Tendency.sturdy,
    this.trait = MonsterTrait.none,
    this.traitText = '',
    this.hp = 1,
    this.attack = 1,
    this.defense = 1,
    this.speed = 1,
    this.expBonus = 0,
    this.isBoss = false,
    this.retired = false,
    this.slimeKind = false,
    this.tint,
    this.element,
  });

  /// 속성 (무속성은 null, 11-11 #63)
  final Element? element;

  final MonsterId id;
  final String name;

  /// 나오는 곳 (설명용)
  final String habitat;

  /// 사냥했을 때 정령 대사
  final String huntLine;

  /// 도감 설명
  final String description;
  final Tendency tendency;
  final MonsterTrait trait;

  /// 전투 특징 (도감)
  final String traitText;

  /// 능력치 배수 (같은 레벨 기본 몬스터 대비)
  final double hp, attack, defense, speed;

  /// 경험치 보너스 (0.1 = +10%)
  final double expBonus;
  final bool isBoss;

  /// 더 나오지 않는 몬스터 (예전 기록에만 남음, 도감에서 숨김)
  final bool retired;

  /// 속성 슬라임 (칭호 '도감의 현자' 조건에서 뺀다)
  final bool slimeKind;

  /// 그림이 없을 때 기본 슬라임 그림에 입히는 색 (0xAARRGGBB)
  final int? tint;

  /// 그림 파일. 없으면 화면에서 아이콘으로 대신 그린다.
  String get asset => 'assets/images/monster_${id.name}.png';

  String get tendencyName => switch (tendency) {
        Tendency.sturdy => '단단함',
        Tendency.nimble => '날렵함',
        Tendency.arcane => '마력',
        Tendency.charm => '홀림',
      };
}

class Monsters {
  Monsters._();

  /// 지금 나오는 몬스터 (도감 순서)
  static List<MonsterInfo> get all =>
      [for (final m in _all) if (!m.retired) m];

  /// 속성 슬라임 (무속성 슬라임 포함, 나오는 비율 순)
  static const slimes = [
    MonsterId.ashSlime,
    MonsterId.fireSlime,
    MonsterId.waterSlime,
    MonsterId.windSlime,
    MonsterId.earthSlime,
    MonsterId.lightSlime,
    MonsterId.darkSlime,
    MonsterId.iceSlime,
    MonsterId.thunderSlime,
    MonsterId.metalSlime,
    MonsterId.poisonSlime,
  ];

  static const List<MonsterInfo> _all = [
    MonsterInfo(
      id: MonsterId.ashSlime,
      name: '슬라임',
      habitat: '어디서나',
      huntLine: '슬라임을 잡았어! 말랑한 젤리가 남았네.',
      description: '어디서나 보이는 말랑한 몬스터. 느리지만 잘 버텨요.',
      traitText: '기본형',
    ),
    MonsterInfo(
      id: MonsterId.fireSlime,
      element: Element.fire,
      name: '불꽃 슬라임',
      habitat: '어디서나',
      huntLine: '불꽃 슬라임을 잡았어! 아직 따끈한 젤리야.',
      description: '몸이 이글이글 타오르는 슬라임.',
      tendency: Tendency.arcane,
      trait: MonsterTrait.burn,
      traitText: '맞으면 30% 확률로 화상 (3턴 동안 매 턴 최대 HP 2%)',
      expBonus: 0.10,
      slimeKind: true,
      tint: 0xFFFF7A45,
    ),
    MonsterInfo(
      id: MonsterId.waterSlime,
      element: Element.water,
      name: '물 슬라임',
      habitat: '어디서나',
      huntLine: '물 슬라임을 잡았어! 촉촉한 젤리가 남았어.',
      description: '맑은 물로 된 슬라임. 조금씩 상처가 아물어요.',
      trait: MonsterTrait.regen,
      traitText: '매 턴 끝에 체력을 5%씩 회복',
      expBonus: 0.10,
      slimeKind: true,
      tint: 0xFF4FA8FF,
    ),
    MonsterInfo(
      id: MonsterId.windSlime,
      element: Element.wind,
      name: '바람 슬라임',
      habitat: '어디서나',
      huntLine: '바람 슬라임을 잡았어! 휘익, 빨랐다!',
      description: '바람을 타고 다니는 가벼운 슬라임.',
      tendency: Tendency.nimble,
      trait: MonsterTrait.evade,
      traitText: '먼저 공격하고, 공격을 15% 피함',
      speed: 1.3,
      expBonus: 0.10,
      slimeKind: true,
      tint: 0xFF6FE3B0,
    ),
    MonsterInfo(
      id: MonsterId.earthSlime,
      element: Element.earth,
      name: '대지 슬라임',
      habitat: '어디서나',
      huntLine: '대지 슬라임을 잡았어! 진흙이 잔뜩 묻었네.',
      description: '흙과 돌을 품은 단단한 슬라임.',
      traitText: '방어가 높고 느림',
      hp: 1.1,
      defense: 1.4,
      speed: 0.8,
      expBonus: 0.10,
      slimeKind: true,
      tint: 0xFFB08850,
    ),
    MonsterInfo(
      id: MonsterId.lightSlime,
      element: Element.light,
      name: '빛 슬라임',
      habitat: '어디서나 (낮에 조금 더 자주)',
      huntLine: '빛 슬라임을 잡았어! 눈이 부셨어.',
      description: '반짝반짝 빛나는 드문 슬라임.',
      tendency: Tendency.charm,
      trait: MonsterTrait.dazzle,
      traitText: '눈부심: 각성자 공격이 25% 빗나감',
      expBonus: 0.30,
      slimeKind: true,
      tint: 0xFFFFE680,
    ),
    MonsterInfo(
      id: MonsterId.darkSlime,
      element: Element.dark,
      name: '어둠 슬라임',
      habitat: '어디서나 (밤에 조금 더 자주)',
      huntLine: '어둠 슬라임을 잡았어! 그림자가 스르륵 흩어졌어.',
      description: '그림자처럼 어두운 드문 슬라임.',
      tendency: Tendency.arcane,
      trait: MonsterTrait.drain,
      traitText: '때린 피해의 30%만큼 체력을 빨아들임',
      expBonus: 0.30,
      slimeKind: true,
      tint: 0xFF8A5CD6,
    ),
    MonsterInfo(
      id: MonsterId.iceSlime,
      element: Element.ice,
      name: '얼음 슬라임',
      habitat: '어디서나',
      huntLine: '얼음 슬라임을 잡았어! 손이 꽁꽁 얼었어.',
      description: '몸이 차갑게 얼어붙은 슬라임. 단단해서 잘 버텨요.',
      trait: MonsterTrait.freeze,
      traitText: '방어가 높고, 맞으면 20% 확률로 얼어 한 차례 쉼',
      hp: 1.1,
      defense: 1.3,
      expBonus: 0.10,
      slimeKind: true,
      tint: 0xFFA8E6FF,
    ),
    MonsterInfo(
      id: MonsterId.thunderSlime,
      element: Element.thunder,
      name: '번개 슬라임',
      habitat: '어디서나',
      huntLine: '번개 슬라임을 잡았어! 머리카락이 쭈뼛 섰어.',
      description: '찌릿찌릿 번개를 품은 슬라임. 아주 빨라요.',
      tendency: Tendency.nimble,
      traitText: '빨라서 먼저 공격하고 세게 때림',
      attack: 1.15,
      speed: 1.35,
      expBonus: 0.10,
      slimeKind: true,
      tint: 0xFFFFD84A,
    ),
    MonsterInfo(
      id: MonsterId.metalSlime,
      element: Element.metal,
      name: '금속 슬라임',
      habitat: '어디서나',
      huntLine: '금속 슬라임을 잡았어! 깡, 하고 울렸어.',
      description: '은빛으로 번쩍이는 묵직한 슬라임. 아주 단단해요.',
      traitText: '방어가 아주 높고 느림',
      hp: 0.9,
      defense: 1.6,
      speed: 0.75,
      expBonus: 0.10,
      slimeKind: true,
      tint: 0xFFB8C0CC,
    ),
    MonsterInfo(
      id: MonsterId.poisonSlime,
      element: Element.poison,
      name: '독 슬라임',
      habitat: '어디서나',
      huntLine: '독 슬라임을 잡았어! 해독제를 챙겨 두자.',
      description: '보랏빛 독이 흐르는 슬라임. 맞으면 중독될 수 있어요.',
      tendency: Tendency.arcane,
      trait: MonsterTrait.poison,
      traitText: '맞으면 30% 확률로 중독 (3턴 동안 매 턴 최대 HP 2%)',
      expBonus: 0.10,
      slimeKind: true,
      tint: 0xFF9BD45A,
    ),
    MonsterInfo(
      id: MonsterId.giantRat,
      element: Element.poison,
      name: '큰쥐',
      habitat: '어디서나',
      huntLine: '큰쥐를 잡았어! 가죽은 장비 만들 때 쓸 수 있어.',
      description: '골목을 누비는 커다란 쥐. 재빠르게 덤벼요.',
      tendency: Tendency.nimble,
      trait: MonsterTrait.weakPoison,
      traitText: '가끔 물려서 약하게 중독',
    ),
    MonsterInfo(
      id: MonsterId.hornRabbit,
      element: Element.wind,
      name: '혼래빗',
      habitat: '어디서나',
      huntLine: '혼래빗을 잡았어! 작은 뿔이 떨어졌어.',
      description: '이마에 작은 뿔이 난 토끼. 재빨라서 먼저 들이받아요.',
      tendency: Tendency.nimble,
      traitText: '빨라서 먼저 공격',
      hp: 0.9,
      speed: 1.2,
    ),
    MonsterInfo(
      id: MonsterId.babyBoar,
      element: Element.earth,
      name: '아기 와일드 보어',
      habitat: '어디서나',
      huntLine: '아기 와일드 보어를 잡았어! 작아도 힘이 셌어.',
      description: '작지만 힘센 멧돼지. 몸이 단단하고 묵직해요.',
      traitText: '체력과 힘이 세고 느림',
      hp: 1.3,
      attack: 1.1,
      speed: 0.85,
    ),
    MonsterInfo(
      id: MonsterId.labyrinthBat,
      element: Element.dark,
      name: '미궁 박쥐',
      habitat: '던전, 필드',
      huntLine: '박쥐를 쫓아냈어! 날개를 하나 주웠어.',
      description: '미궁에서 흘러나온 박쥐. 던전에 가장 많아요.',
      tendency: Tendency.nimble,
      traitText: '기본형',
    ),
    MonsterInfo(
      id: MonsterId.shadowButterfly,
      element: Element.dark,
      name: '그림자 나비',
      habitat: '밤 (오후 7시 ~ 새벽 5시) 어디서나',
      huntLine: '그림자 나비를 잡았어! 반짝이는 가루가 떨어졌어.',
      description: '밤에만 날아다니는 나비. 날개 가루에 홀리기 쉬워요.',
      tendency: Tendency.charm,
      traitText: '기본형',
    ),
    MonsterInfo(
      id: MonsterId.labyrinthWarden,
      element: Element.metal,
      name: '미궁 문지기',
      habitat: '던전 마지막 층',
      huntLine: '문지기를 쓰러뜨렸어! 던전을 끝까지 돌파했어!',
      description: '던전 마지막 층을 지키는 돌 거인.',
      traitText: '보스: 큰 공격을 예고하고, 체력이 절반 아래면 분노해요',
      isBoss: true,
    ),
    MonsterInfo(
      id: MonsterId.fireSlimeKing,
      element: Element.fire,
      name: '불꽃 슬라임 왕',
      habitat: '던전 마지막 층',
      huntLine: '불꽃 슬라임 왕을 쓰러뜨렸어! 왕관이 식었어.',
      description: '불타는 왕관을 쓴 거대한 슬라임. 화요일 던전의 주인.',
      traitText: '보스: 큰 공격을 예고하고, 체력이 절반 아래면 분노해요',
      isBoss: true,
    ),
    MonsterInfo(
      id: MonsterId.frostWolfKing,
      element: Element.ice,
      name: '서리 늑대왕',
      habitat: '던전 마지막 층',
      huntLine: '서리 늑대왕을 쓰러뜨렸어! 숨결이 얼음 같았어.',
      description: '서리 갈기를 두른 늑대들의 왕. 수요일 던전의 주인.',
      traitText: '보스: 큰 공격을 예고하고, 체력이 절반 아래면 분노해요',
      isBoss: true,
    ),
    MonsterInfo(
      id: MonsterId.ancientTreant,
      element: Element.earth,
      name: '숲의 고목 정령',
      habitat: '던전 마지막 층',
      huntLine: '숲의 고목 정령을 달랬어! 나뭇잎이 조용해졌어.',
      description: '천 년 묵은 고목에 깃든 숲의 수호자. 목요일 던전의 주인.',
      traitText: '보스: 큰 공격을 예고하고, 체력이 절반 아래면 분노해요',
      isBoss: true,
    ),
    MonsterInfo(
      id: MonsterId.shadowBatQueen,
      element: Element.dark,
      name: '그림자 박쥐 여왕',
      habitat: '던전 마지막 층',
      huntLine: '그림자 박쥐 여왕을 쓰러뜨렸어! 밤이 밝아졌어.',
      description: '미궁 박쥐들을 거느리는 밤의 여왕. 금요일 던전의 주인.',
      traitText: '보스: 큰 공격을 예고하고, 체력이 절반 아래면 분노해요',
      isBoss: true,
    ),
    MonsterInfo(
      id: MonsterId.thunderGriffin,
      element: Element.thunder,
      name: '천둥 그리폰',
      habitat: '던전 마지막 층',
      huntLine: '천둥 그리폰을 쓰러뜨렸어! 하늘이 맑아졌어.',
      description: '번개를 몰고 다니는 하늘의 사냥꾼. 토요일 던전의 주인.',
      traitText: '보스: 큰 공격을 예고하고, 체력이 절반 아래면 분노해요',
      isBoss: true,
    ),
    MonsterInfo(
      id: MonsterId.roughWaterSpirit,
      name: '물방울 정령',
      habitat: '(더 나오지 않음)',
      huntLine: '',
      retired: true,
    ),
    MonsterInfo(
      id: MonsterId.lostStoneSpirit,
      name: '돌정령',
      habitat: '(더 나오지 않음)',
      huntLine: '',
      retired: true,
    ),
  ];

  static MonsterInfo info(MonsterId id) => _all.firstWhere((m) => m.id == id);

  static MonsterId? byName(String name) {
    for (final id in MonsterId.values) {
      if (id.name == name) return id;
    }
    return null;
  }
}
