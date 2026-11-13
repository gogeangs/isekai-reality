import 'element_rules.dart';
import 'dart:math' as math;

import 'monsters.dart';

/// 몬스터가 떨어뜨리거나 잡화상에서 사는 재료 (11-10 #20, 대장간 제작에 쓴다).
/// 이름은 저장된 기록의 키라 바꾸지 않는다.
enum MaterialId {
  slimeJelly,
  slimeCore,
  ratHide,
  glossyFur,
  batWing,
  batFang,
  butterflyDust,
  sleepPowder,
  wardenShard,
  labyrinthCore,
  ironShard,
  twig,
  poisonGland,
  // 11-11 #31·#40·#35
  rabbitMeat,
  smallHorn,
  goldenRabbitFur,
  boarMeat,
  toughHide,
  smallTusk,
  fireJelly,
  fireCore,
  waterJelly,
  waterCore,
  windJelly,
  windCore,
  mudJelly,
  earthCore,
  lightJelly,
  lightCore,
  darkJelly,
  shadowCore,
  herb,
  // 11-11 #59 던전 재료 · 가공 재료
  labyrinthStone,
  runeStone,
  ironIngot,
  hardWood,
  tannedLeather,
  herbExtract,
  essence,
  glowFireCore,
  glowWaterCore,
  glowWindCore,
  glowEarthCore,
  glowLightCore,
  glowShadowCore,
  // 11-11 #63 새 속성 슬라임
  iceJelly,
  iceCore,
  thunderJelly,
  thunderCore,
  metalJelly,
  metalCore,
  poisonJelly,
  poisonCore,
  glowIceCore,
  glowThunderCore,
  glowMetalCore,
  glowPoisonCore,
  // 11-11 #56 채집 귀한 재료
  dewHerb,
  manaOre,
  sturdyKnot,
  riverPearl,
  // 11-11 #74 속성 마석 (공방 전용: 속성 물약 재료)
  stoneFire,
  stoneWater,
  stoneWind,
  stoneEarth,
  stoneLight,
  stoneDark,
  stoneIce,
  stoneThunder,
  stoneMetal,
  stonePoison,
  // 11-11 #75 보스 전용 재료 · 보스 장비 조각
  bossWardenHeart,
  bossKingOrb,
  bossFrostFang,
  bossTreantHeart,
  bossQueenWing,
  bossThunderFeather,
  bossShard,
  // 11-11 #83 채집 2: 버섯 · 꽃 · 보석 · 유물
  shadeMushroom,
  poisonMushroom,
  moonMushroom,
  springPetal,
  summerPetal,
  autumnPetal,
  winterPetal,
  sunPollen,
  breezeBloom,
  roughGem,
  gemFire,
  gemWater,
  gemWind,
  gemEarth,
  gemLight,
  gemDark,
  gemIce,
  gemThunder,
  gemMetal,
  gemPoison,
  ancientShard,
  relicSeal,
}

class MaterialInfo {
  const MaterialInfo(this.id, this.name, this.description,
      {this.rare = false, this.price, this.processed = false});

  /// 판매 값을 따로 정한 재료 (가공 재료)
  final int? price;

  /// 가공해서 만든 재료 (대장간·공방)
  final bool processed;

  final MaterialId id;
  final String name;
  final String description;

  /// 귀한 재료: 제작할 때 하나 더 넣으면 좋은 등급이 잘 나온다
  final bool rare;

  /// assets/images/<asset>.png (그림이 없으면 아이콘으로 대신)
  String get asset => 'assets/images/mat_${id.name}.webp';
}

/// 지갑의 키: 마석·금화 (재료는 [MaterialId] 이름)
class Wallet {
  Wallet._();
  static const manaStone = 'manaStone';
  static const gold = 'gold';

  /// 수식어·속성 몬스터로 더 받은 경험치 (11-11)
  static const exp = 'exp';
}

class Materials {
  Materials._();

  static const List<MaterialInfo> all = [
    MaterialInfo(MaterialId.slimeJelly, '슬라임 젤리', '말랑한 젤리. 장갑·장화를 만들 때 써요.'),
    MaterialInfo(MaterialId.slimeCore, '슬라임 코어', '슬라임 속의 단단한 구슬.', rare: true),
    MaterialInfo(MaterialId.ratHide, '쥐 가죽', '질긴 가죽. 가죽 장비의 기본 재료예요.'),
    MaterialInfo(MaterialId.glossyFur, '윤기 나는 쥐털', '반들반들 빛나는 털.', rare: true),
    MaterialInfo(MaterialId.batWing, '박쥐 날개', '얇고 가벼운 날개. 갑옷·목걸이에 써요.'),
    MaterialInfo(MaterialId.batFang, '박쥐 송곳니', '뾰족한 송곳니.', rare: true),
    MaterialInfo(MaterialId.butterflyDust, '나비 비늘가루', '반짝이는 가루. 지팡이에 써요.'),
    MaterialInfo(MaterialId.sleepPowder, '잠의 가루', '맡으면 졸음이 오는 가루.', rare: true),
    MaterialInfo(MaterialId.wardenShard, '문지기의 돌조각', '미궁 문지기의 몸에서 떨어진 돌.'),
    MaterialInfo(MaterialId.labyrinthCore, '미궁 핵', '미궁의 힘이 뭉친 결정.', rare: true),
    MaterialInfo(MaterialId.ironShard, '철 조각', '무기를 만들 때 써요. 잡화상에서 팔아요.'),
    MaterialInfo(MaterialId.twig, '나뭇가지', '지팡이를 만들 때 써요. 잡화상에서 팔아요.'),
    MaterialInfo(MaterialId.poisonGland, '독샘', '독을 품은 몬스터에게서 나와요.', rare: true),
    MaterialInfo(MaterialId.rabbitMeat, '토끼 고기', '혼래빗 고기. 나중에 요리에 써요.'),
    MaterialInfo(MaterialId.smallHorn, '작은 뿔', '혼래빗의 뿔. 뿔 단검을 만들어요.'),
    MaterialInfo(MaterialId.goldenRabbitFur, '황금빛 토끼털', '금빛으로 반짝이는 털.', rare: true),
    MaterialInfo(MaterialId.boarMeat, '멧돼지 고기', '아기 와일드 보어 고기. 나중에 요리에 써요.'),
    MaterialInfo(MaterialId.toughHide, '질긴 가죽', '멧돼지의 두꺼운 가죽. 갑옷에 좋아요.'),
    MaterialInfo(MaterialId.smallTusk, '작은 엄니', '멧돼지의 엄니.', rare: true),
    MaterialInfo(MaterialId.fireJelly, '불꽃 젤리', '따끈한 젤리. 모아 두는 재료예요.'),
    MaterialInfo(MaterialId.fireCore, '불꽃 코어', '불꽃 슬라임의 코어.', rare: true),
    MaterialInfo(MaterialId.waterJelly, '물 젤리', '촉촉한 젤리. 모아 두는 재료예요.'),
    MaterialInfo(MaterialId.waterCore, '물방울 코어', '물 슬라임의 코어.', rare: true),
    MaterialInfo(MaterialId.windJelly, '바람 젤리', '가벼운 젤리. 모아 두는 재료예요.'),
    MaterialInfo(MaterialId.windCore, '바람 코어', '바람 슬라임의 코어.', rare: true),
    MaterialInfo(MaterialId.mudJelly, '진흙 젤리', '묵직한 젤리. 모아 두는 재료예요.'),
    MaterialInfo(MaterialId.earthCore, '대지 코어', '대지 슬라임의 코어.', rare: true),
    MaterialInfo(MaterialId.lightJelly, '빛 젤리', '반짝이는 젤리. 모아 두는 재료예요.'),
    MaterialInfo(MaterialId.lightCore, '빛의 코어', '빛 슬라임의 코어.', rare: true),
    MaterialInfo(MaterialId.darkJelly, '어둠 젤리', '그림자 같은 젤리. 모아 두는 재료예요.'),
    MaterialInfo(MaterialId.shadowCore, '그림자 코어', '어둠 슬라임의 코어.', rare: true),
    MaterialInfo(MaterialId.herb, '약초', '물약의 기본 재료. 잡화상에서 팔아요.'),
    MaterialInfo(MaterialId.labyrinthStone, '미궁 석재',
        '던전에서만 나오는 단단한 돌. 가마솥과 상급 장비에 써요.'),
    MaterialInfo(MaterialId.runeStone, '빛바랜 룬석',
        '던전 깊은 곳의 룬이 새겨진 돌. 상급 장비·물약 재료예요.',
        rare: true),
    MaterialInfo(MaterialId.ironIngot, '철 주괴', '철 조각 3개를 녹여 만든 주괴. 다음 장비 재료예요.',
        price: 20, processed: true),
    MaterialInfo(MaterialId.hardWood, '단단한 목재', '나뭇가지 4개를 다듬은 목재. 다음 장비 재료예요.',
        price: 20, processed: true),
    MaterialInfo(MaterialId.tannedLeather, '무두질한 가죽',
        '가죽을 무두질해 부드럽게 만든 것. 다음 장비 재료예요.',
        price: 20, processed: true),
    MaterialInfo(MaterialId.herbExtract, '약초 진액', '약초 5개를 달인 진액. 상급 물약 재료예요.',
        price: 30, processed: true),
    MaterialInfo(MaterialId.essence, '정제 에센스', '젤리 5개에서 뽑은 맑은 에센스. 상급 물약 재료예요.',
        price: 30, processed: true),
    MaterialInfo(MaterialId.glowFireCore, '빛나는 불꽃 코어', '불꽃 코어 3개를 합친 것. 대장간에서 장비에 속성을 입힐 때 써요.',
        rare: true, price: 80, processed: true),
    MaterialInfo(MaterialId.glowWaterCore, '빛나는 물방울 코어', '물방울 코어 3개를 합친 것. 대장간에서 장비에 속성을 입힐 때 써요.',
        rare: true, price: 80, processed: true),
    MaterialInfo(MaterialId.glowWindCore, '빛나는 바람 코어', '바람 코어 3개를 합친 것. 대장간에서 장비에 속성을 입힐 때 써요.',
        rare: true, price: 80, processed: true),
    MaterialInfo(MaterialId.glowEarthCore, '빛나는 대지 코어', '대지 코어 3개를 합친 것. 대장간에서 장비에 속성을 입힐 때 써요.',
        rare: true, price: 80, processed: true),
    MaterialInfo(MaterialId.glowLightCore, '빛나는 빛의 코어', '빛의 코어 3개를 합친 것. 대장간에서 장비에 속성을 입힐 때 써요.',
        rare: true, price: 80, processed: true),
    MaterialInfo(MaterialId.glowShadowCore, '빛나는 그림자 코어', '그림자 코어 3개를 합친 것. 대장간에서 장비에 속성을 입힐 때 써요.',
        rare: true, price: 80, processed: true),
    MaterialInfo(MaterialId.iceJelly, '얼음 젤리', '차가운 젤리. 모아 두는 재료예요.'),
    MaterialInfo(MaterialId.iceCore, '얼음 코어', '얼음 슬라임의 코어.', rare: true),
    MaterialInfo(MaterialId.thunderJelly, '번개 젤리', '찌릿한 젤리. 모아 두는 재료예요.'),
    MaterialInfo(MaterialId.thunderCore, '번개 코어', '번개 슬라임의 코어.', rare: true),
    MaterialInfo(MaterialId.metalJelly, '금속 젤리', '묵직한 은빛 젤리. 모아 두는 재료예요.'),
    MaterialInfo(MaterialId.metalCore, '금속 코어', '금속 슬라임의 코어.', rare: true),
    MaterialInfo(MaterialId.poisonJelly, '독 젤리', '보랏빛이 도는 젤리. 모아 두는 재료예요.'),
    MaterialInfo(MaterialId.poisonCore, '독 코어', '독 슬라임의 코어.', rare: true),
    MaterialInfo(MaterialId.glowIceCore, '빛나는 얼음 코어', '얼음 코어 3개를 합친 것. 대장간에서 장비에 속성을 입힐 때 써요.',
        rare: true, price: 80, processed: true),
    MaterialInfo(MaterialId.glowThunderCore, '빛나는 번개 코어', '번개 코어 3개를 합친 것. 대장간에서 장비에 속성을 입힐 때 써요.',
        rare: true, price: 80, processed: true),
    MaterialInfo(MaterialId.glowMetalCore, '빛나는 금속 코어', '금속 코어 3개를 합친 것. 대장간에서 장비에 속성을 입힐 때 써요.',
        rare: true, price: 80, processed: true),
    MaterialInfo(MaterialId.glowPoisonCore, '빛나는 독 코어', '독 코어 3개를 합친 것. 대장간에서 장비에 속성을 입힐 때 써요.',
        rare: true, price: 80, processed: true),
    // 11-11 #56 채집 귀한 재료
    MaterialInfo(MaterialId.dewHerb, '이슬 맺힌 약초',
        '새벽 이슬을 머금은 약초. 공방에서 약초 진액 2개로 가공해요.', rare: true),
    MaterialInfo(MaterialId.manaOre, '마력 광석',
        '마력이 스민 광석. 대장간에서 철 주괴 2개로 가공해요.', rare: true),
    MaterialInfo(MaterialId.sturdyKnot, '튼튼한 옹이',
        '오래된 나무의 단단한 옹이. 대장간에서 단단한 목재 2개로 가공해요.', rare: true),
    MaterialInfo(MaterialId.riverPearl, '강의 진주',
        '물가에서 건진 작은 진주. 공방에서 정제 에센스 2개로 가공해요.', rare: true),
    // 11-11 #75 보스 전용 재료
    MaterialInfo(MaterialId.bossWardenHeart, '문지기의 심장', '미궁 문지기를 쓰러뜨리면 나와요. 돌처럼 단단하게 뛰는 심장.', rare: true, price: 100),
    MaterialInfo(MaterialId.bossKingOrb, '왕의 불꽃 구슬', '불꽃 슬라임 왕을 쓰러뜨리면 나와요. 꺼지지 않는 불꽃이 담겼어요.', rare: true, price: 100),
    MaterialInfo(MaterialId.bossFrostFang, '서리 송곳니', '서리 늑대왕을 쓰러뜨리면 나와요. 만지면 손끝이 시려요.', rare: true, price: 100),
    MaterialInfo(MaterialId.bossTreantHeart, '고목의 심재', '숲의 고목 정령을 달래면 나와요. 천 년의 나이테가 새겨졌어요.', rare: true, price: 100),
    MaterialInfo(MaterialId.bossQueenWing, '여왕의 밤날개', '그림자 박쥐 여왕을 쓰러뜨리면 나와요. 빛을 삼키는 날개.', rare: true, price: 100),
    MaterialInfo(MaterialId.bossThunderFeather, '천둥 깃털', '천둥 그리폰을 쓰러뜨리면 나와요. 찌릿찌릿 번개가 흘러요.', rare: true, price: 100),
    MaterialInfo(MaterialId.bossShard, '보스 장비 조각', '던전 보스가 가끔 떨어뜨려요. 대장간 「보스 장비」에서 써요.', rare: true, price: 100),
    // 11-11 #83 채집 2
    MaterialInfo(MaterialId.shadeMushroom, '그늘버섯', '숲 그늘에서 자라는 보랏빛 버섯. 어둠의 기운이 조금 있어요.'),
    MaterialInfo(MaterialId.poisonMushroom, '독버섯', '알록달록한 독버섯. 맨손으로 만지면 안 돼요.'),
    MaterialInfo(MaterialId.moonMushroom, '달빛 버섯', '밤에 은은하게 빛나는 귀한 버섯.', rare: true),
    MaterialInfo(MaterialId.springPetal, '벚꽃잎', '봄 꽃밭에서 모은 분홍 꽃잎. 물약에 향을 더해요.'),
    MaterialInfo(MaterialId.summerPetal, '해바라기 꽃잎', '여름 햇살을 머금은 노란 꽃잎.'),
    MaterialInfo(MaterialId.autumnPetal, '코스모스 꽃잎', '가을바람에 흔들리던 꽃잎.'),
    MaterialInfo(MaterialId.winterPetal, '동백 꽃잎', '추위 속에서 핀 붉은 꽃잎.'),
    MaterialInfo(MaterialId.sunPollen, '햇살 꽃가루', '빛의 기운이 담긴 금빛 꽃가루.', rare: true),
    MaterialInfo(MaterialId.breezeBloom, '바람꽃', '바람의 기운이 담긴 하얀 꽃.', rare: true),
    MaterialInfo(MaterialId.roughGem, '원석 조각', '보석 광맥에서 캔 다듬지 않은 원석.'),
    MaterialInfo(MaterialId.gemFire, '불꽃 보석', '불의 기운이 담긴 붉은 보석. 장비·장신구 재료.', rare: true),
    MaterialInfo(MaterialId.gemWater, '물결 보석', '물의 기운이 담긴 푸른 보석.', rare: true),
    MaterialInfo(MaterialId.gemWind, '바람 보석', '바람의 기운이 담긴 연두 보석.', rare: true),
    MaterialInfo(MaterialId.gemEarth, '대지 보석', '대지의 기운이 담긴 황토빛 보석.', rare: true),
    MaterialInfo(MaterialId.gemLight, '빛 보석', '빛의 기운이 담긴 금빛 보석.', rare: true),
    MaterialInfo(MaterialId.gemDark, '어둠 보석', '어둠의 기운이 담긴 보랏빛 보석.', rare: true),
    MaterialInfo(MaterialId.gemIce, '서리 보석', '얼음의 기운이 담긴 하늘빛 보석.', rare: true),
    MaterialInfo(MaterialId.gemThunder, '번개 보석', '번개의 기운이 담긴 노란 보석.', rare: true),
    MaterialInfo(MaterialId.gemMetal, '강철 보석', '금속의 기운이 담긴 은빛 보석.', rare: true),
    MaterialInfo(MaterialId.gemPoison, '독 보석', '독의 기운이 담긴 초록 보석.', rare: true),
    MaterialInfo(MaterialId.ancientShard, '옛 토기 조각', '고대 유물 자리에서 붓으로 털어 낸 토기 조각.'),
    MaterialInfo(MaterialId.relicSeal, '고대 인장', '오래전 이세계의 문양이 새겨진 인장.', rare: true, price: 120),
    // 11-11 #74 속성 마석: 공방에서 마석 3 + 그 속성 코어 1로 정제
    MaterialInfo(MaterialId.stoneFire, '불꽃의 마석', '공방에서 속성 물약을 만들 때 써요. (마석 정제로 만들어요)',
        rare: true, price: 60, processed: true),
    MaterialInfo(MaterialId.stoneWater, '물의 마석', '공방에서 속성 물약을 만들 때 써요. (마석 정제로 만들어요)',
        rare: true, price: 60, processed: true),
    MaterialInfo(MaterialId.stoneWind, '바람의 마석', '공방에서 속성 물약을 만들 때 써요. (마석 정제로 만들어요)',
        rare: true, price: 60, processed: true),
    MaterialInfo(MaterialId.stoneEarth, '대지의 마석', '공방에서 속성 물약을 만들 때 써요. (마석 정제로 만들어요)',
        rare: true, price: 60, processed: true),
    MaterialInfo(MaterialId.stoneLight, '빛의 마석', '공방에서 속성 물약을 만들 때 써요. (마석 정제로 만들어요)',
        rare: true, price: 60, processed: true),
    MaterialInfo(MaterialId.stoneDark, '어둠의 마석', '공방에서 속성 물약을 만들 때 써요. (마석 정제로 만들어요)',
        rare: true, price: 60, processed: true),
    MaterialInfo(MaterialId.stoneIce, '얼음의 마석', '공방에서 속성 물약을 만들 때 써요. (마석 정제로 만들어요)',
        rare: true, price: 60, processed: true),
    MaterialInfo(MaterialId.stoneThunder, '번개의 마석', '공방에서 속성 물약을 만들 때 써요. (마석 정제로 만들어요)',
        rare: true, price: 60, processed: true),
    MaterialInfo(MaterialId.stoneMetal, '금속의 마석', '공방에서 속성 물약을 만들 때 써요. (마석 정제로 만들어요)',
        rare: true, price: 60, processed: true),
    MaterialInfo(MaterialId.stonePoison, '독의 마석', '공방에서 속성 물약을 만들 때 써요. (마석 정제로 만들어요)',
        rare: true, price: 60, processed: true),
  ];

  static MaterialInfo info(MaterialId id) => all.firstWhere((m) => m.id == id);

  /// 재료의 속성 (속성 젤리·코어, 11-11 #63). 없으면 null.
  static Element? elementOf(MaterialId m) => switch (m) {
        MaterialId.fireJelly || MaterialId.fireCore || MaterialId.glowFireCore || MaterialId.stoneFire => Element.fire,
        MaterialId.waterJelly || MaterialId.waterCore || MaterialId.glowWaterCore || MaterialId.stoneWater => Element.water,
        MaterialId.windJelly || MaterialId.windCore || MaterialId.glowWindCore || MaterialId.stoneWind => Element.wind,
        MaterialId.mudJelly || MaterialId.earthCore || MaterialId.glowEarthCore || MaterialId.stoneEarth => Element.earth,
        MaterialId.lightJelly || MaterialId.lightCore || MaterialId.glowLightCore || MaterialId.stoneLight => Element.light,
        MaterialId.darkJelly || MaterialId.shadowCore || MaterialId.glowShadowCore || MaterialId.stoneDark => Element.dark,
        MaterialId.iceJelly || MaterialId.iceCore || MaterialId.glowIceCore || MaterialId.stoneIce => Element.ice,
        MaterialId.thunderJelly || MaterialId.thunderCore || MaterialId.glowThunderCore || MaterialId.stoneThunder => Element.thunder,
        MaterialId.metalJelly || MaterialId.metalCore || MaterialId.glowMetalCore || MaterialId.stoneMetal => Element.metal,
        MaterialId.poisonJelly || MaterialId.poisonCore || MaterialId.glowPoisonCore || MaterialId.stonePoison => Element.poison,
        // 11-11 #83 채집 2
        MaterialId.gemFire => Element.fire,
        MaterialId.gemWater => Element.water,
        MaterialId.gemWind || MaterialId.breezeBloom => Element.wind,
        MaterialId.gemEarth => Element.earth,
        MaterialId.gemLight || MaterialId.sunPollen => Element.light,
        MaterialId.gemDark || MaterialId.shadeMushroom || MaterialId.moonMushroom => Element.dark,
        MaterialId.gemIce => Element.ice,
        MaterialId.gemThunder => Element.thunder,
        MaterialId.gemMetal => Element.metal,
        MaterialId.gemPoison || MaterialId.poisonMushroom => Element.poison,
        _ => null,
      };

  /// 속성 마석 (11-11 #74)
  /// 속성 보석 (11-11 #83)
  static MaterialId elementGem(Element e) => switch (e) {
        Element.fire => MaterialId.gemFire,
        Element.water => MaterialId.gemWater,
        Element.wind => MaterialId.gemWind,
        Element.earth => MaterialId.gemEarth,
        Element.light => MaterialId.gemLight,
        Element.dark => MaterialId.gemDark,
        Element.ice => MaterialId.gemIce,
        Element.thunder => MaterialId.gemThunder,
        Element.metal => MaterialId.gemMetal,
        Element.poison => MaterialId.gemPoison,
      };

  static MaterialId elementStone(Element e) => switch (e) {
        Element.fire => MaterialId.stoneFire,
        Element.water => MaterialId.stoneWater,
        Element.wind => MaterialId.stoneWind,
        Element.earth => MaterialId.stoneEarth,
        Element.light => MaterialId.stoneLight,
        Element.dark => MaterialId.stoneDark,
        Element.ice => MaterialId.stoneIce,
        Element.thunder => MaterialId.stoneThunder,
        Element.metal => MaterialId.stoneMetal,
        Element.poison => MaterialId.stonePoison,
      };

  /// 속성 젤리
  static MaterialId elementJelly(Element e) => switch (e) {
        Element.fire => MaterialId.fireJelly,
        Element.water => MaterialId.waterJelly,
        Element.wind => MaterialId.windJelly,
        Element.earth => MaterialId.mudJelly,
        Element.light => MaterialId.lightJelly,
        Element.dark => MaterialId.darkJelly,
        Element.ice => MaterialId.iceJelly,
        Element.thunder => MaterialId.thunderJelly,
        Element.metal => MaterialId.metalJelly,
        Element.poison => MaterialId.poisonJelly,
      };

  /// 속성 코어 (슬라임의 귀한 재료)
  static MaterialId elementCore(Element e) => switch (e) {
        Element.fire => MaterialId.fireCore,
        Element.water => MaterialId.waterCore,
        Element.wind => MaterialId.windCore,
        Element.earth => MaterialId.earthCore,
        Element.light => MaterialId.lightCore,
        Element.dark => MaterialId.shadowCore,
        Element.ice => MaterialId.iceCore,
        Element.thunder => MaterialId.thunderCore,
        Element.metal => MaterialId.metalCore,
        Element.poison => MaterialId.poisonCore,
      };

  static MaterialId? byName(String name) {
    for (final m in MaterialId.values) {
      if (m.name == name) return m;
    }
    return null;
  }

  /// 귀한 재료 (제작에 더 넣을 수 있는 것)
  static List<MaterialId> get rares => [
        for (final m in all)
          if (m.rare) m.id,
      ];
}

/// 사냥 보상 (결과 화면에 보여 준다)
class HuntReward {
  const HuntReward({
    this.exp = 0,
    this.manaStones = 0,
    this.gold = 0,
    this.materials = const {},
  });

  final int exp;
  final int manaStones;
  final int gold;
  final Map<MaterialId, int> materials;

  bool get isEmpty =>
      exp == 0 && manaStones == 0 && gold == 0 && materials.isEmpty;

  /// '마석 +1 · 슬라임 젤리 +1' 처럼 (경험치 빼고)
  String get itemsLabel => [
        if (manaStones > 0) '마석 +$manaStones',
        if (gold > 0) '금화 +$gold',
        for (final e in materials.entries)
          '${Materials.info(e.key).name} +${e.value}',
      ].join(' · ');

  /// 기록에 더할 지갑 변화 (마석은 규칙으로 계산하는 몫을 뺀 '추가'만)
  static Map<String, int> ledger(
      {int extraManaStones = 0, int gold = 0, Map<MaterialId, int>? materials}) {
    return {
      if (extraManaStones > 0) Wallet.manaStone: extraManaStones,
      if (gold > 0) Wallet.gold: gold,
      for (final e in (materials ?? const {}).entries)
        if (e.value > 0) e.key.name: e.value,
    };
  }
}

/// 몬스터가 떨어뜨리는 재료 (제안서 1장, 11-10 확정)
class LootRules {
  LootRules._();

  /// 귀한 재료가 나올 확률
  static const double rareChance = 0.10;

  /// 몬스터마다 재료(둘이면 반반 중 하나), 귀한 재료, 귀한 재료 확률
  static ({List<MaterialId> common, MaterialId rare, double chance}) dropsOf(
          MonsterId m) =>
      switch (m) {
        MonsterId.ashSlime || MonsterId.slime =>
          (common: [MaterialId.slimeJelly], rare: MaterialId.slimeCore, chance: rareChance),
        MonsterId.fireSlime =>
          (common: [MaterialId.fireJelly], rare: MaterialId.fireCore, chance: rareChance),
        MonsterId.waterSlime =>
          (common: [MaterialId.waterJelly], rare: MaterialId.waterCore, chance: rareChance),
        MonsterId.windSlime =>
          (common: [MaterialId.windJelly], rare: MaterialId.windCore, chance: rareChance),
        MonsterId.earthSlime =>
          (common: [MaterialId.mudJelly], rare: MaterialId.earthCore, chance: rareChance),
        MonsterId.lightSlime =>
          (common: [MaterialId.lightJelly], rare: MaterialId.lightCore, chance: 0.15),
        MonsterId.darkSlime =>
          (common: [MaterialId.darkJelly], rare: MaterialId.shadowCore, chance: 0.15),
        MonsterId.iceSlime =>
          (common: [MaterialId.iceJelly], rare: MaterialId.iceCore, chance: rareChance),
        MonsterId.thunderSlime =>
          (common: [MaterialId.thunderJelly], rare: MaterialId.thunderCore, chance: rareChance),
        MonsterId.metalSlime =>
          (common: [MaterialId.metalJelly], rare: MaterialId.metalCore, chance: rareChance),
        MonsterId.poisonSlime =>
          (common: [MaterialId.poisonJelly], rare: MaterialId.poisonCore, chance: rareChance),
        MonsterId.giantRat =>
          (common: [MaterialId.ratHide], rare: MaterialId.glossyFur, chance: rareChance),
        MonsterId.hornRabbit => (
            common: [MaterialId.rabbitMeat, MaterialId.smallHorn],
            rare: MaterialId.goldenRabbitFur,
            chance: rareChance
          ),
        MonsterId.babyBoar => (
            common: [MaterialId.boarMeat, MaterialId.toughHide],
            rare: MaterialId.smallTusk,
            chance: rareChance
          ),
        MonsterId.labyrinthBat =>
          (common: [MaterialId.batWing], rare: MaterialId.batFang, chance: rareChance),
        MonsterId.shadowButterfly => (
            common: [MaterialId.butterflyDust],
            rare: MaterialId.sleepPowder,
            chance: rareChance
          ),
        MonsterId.labyrinthWarden => (
            common: [MaterialId.wardenShard],
            rare: MaterialId.labyrinthCore,
            chance: rareChance
          ),
        // 11-11 #75 새 보스: 전용 재료는 던전 보상에서 따로 준다
        MonsterId.fireSlimeKing ||
        MonsterId.frostWolfKing ||
        MonsterId.ancientTreant ||
        MonsterId.shadowBatQueen ||
        MonsterId.thunderGriffin =>
          (common: [MaterialId.wardenShard], rare: MaterialId.labyrinthCore, chance: rareChance),
        // 예전 정령 몬스터 (지금은 나오지 않음)
        MonsterId.roughWaterSpirit || MonsterId.lostStoneSpirit =>
          (common: [MaterialId.slimeJelly], rare: MaterialId.slimeCore, chance: rareChance),
      };

  /// 초반에 아직 쓸 곳이 없는 재료 → 초반 제작에 쓰는 재료 (#129)
  static const earlyCommon = {
    MaterialId.fireJelly: MaterialId.slimeJelly,
    MaterialId.waterJelly: MaterialId.slimeJelly,
    MaterialId.windJelly: MaterialId.slimeJelly,
    MaterialId.mudJelly: MaterialId.slimeJelly,
    MaterialId.lightJelly: MaterialId.slimeJelly,
    MaterialId.darkJelly: MaterialId.slimeJelly,
    MaterialId.iceJelly: MaterialId.slimeJelly,
    MaterialId.thunderJelly: MaterialId.slimeJelly,
    MaterialId.metalJelly: MaterialId.slimeJelly,
    MaterialId.poisonJelly: MaterialId.slimeJelly,
    MaterialId.rabbitMeat: MaterialId.smallHorn,
    MaterialId.boarMeat: MaterialId.toughHide,
  };

  /// 필드 몬스터 한 마리: 그 몬스터 재료 1 (+귀한 재료). [rareBonus] 는 행운 보너스.
  static Map<MaterialId, int> field(MonsterId m, math.Random rng,
      {double rareBonus = 0, bool early = false}) {
    final d = dropsOf(m);
    var common = d.common[rng.nextInt(d.common.length)];
    // 묶음 16 #129: 처음(Lv.5까지)엔 바로 쓰는 재료만. 속성 젤리 → 슬라임 젤리
    if (early) common = earlyCommon[common] ?? common;
    return {
      common: 1,
      if (rng.nextDouble() < d.chance + rareBonus) d.rare: 1,
    };
  }

  /// 던전 한 번: 클리어 박쥐 날개 2 + 문지기의 돌조각 1 (+미궁 핵 10%, 박쥐 송곳니 10%),
  /// 실패 박쥐 날개 1
  static Map<MaterialId, int> dungeon(
      {required bool cleared,
      required math.Random rng,
      MonsterId boss = MonsterId.labyrinthWarden}) {
    if (!cleared) return {MaterialId.batWing: 1};
    return {
      MaterialId.batWing: 2,
      MaterialId.wardenShard: 1,
      if (rng.nextDouble() < rareChance) MaterialId.labyrinthCore: 1,
      if (rng.nextDouble() < rareChance) MaterialId.batFang: 1,
      // 11-11 #75: 보스 전용 재료 1개(확정) + 보스 장비 조각 30%
      bossMaterial(boss): 1,
      if (rng.nextDouble() < bossShardChance) MaterialId.bossShard: 1,
    };
  }

  static const double bossShardChance = 0.30;

  /// 보스마다 전용 재료
  static MaterialId bossMaterial(MonsterId boss) => switch (boss) {
        MonsterId.fireSlimeKing => MaterialId.bossKingOrb,
        MonsterId.frostWolfKing => MaterialId.bossFrostFang,
        MonsterId.ancientTreant => MaterialId.bossTreantHeart,
        MonsterId.shadowBatQueen => MaterialId.bossQueenWing,
        MonsterId.thunderGriffin => MaterialId.bossThunderFeather,
        _ => MaterialId.bossWardenHeart,
      };
}
