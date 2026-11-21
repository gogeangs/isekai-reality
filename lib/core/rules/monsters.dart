import 'field_monster_rules.dart';
import 'element_rules.dart';

part 'monsters/table1.dart';
part 'monsters/table2.dart';

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
  // 묶음 18 #149: 첫 튜토리얼 전용 하늘색 슬라임 (도감·지도에는 나오지 않음)
  slime,
  // 묶음 34 2막: 잿빛 군주의 분신 다섯과 본체 (지도·도감에는 나오지 않음)
  ashRage,
  ashSorrow,
  ashGreed,
  ashFear,
  ashLonely,
  ashKing,
  // 묶음 43 #228: 훈련장 허수아비 셋과 훈련 골렘 (지도·도감에는 나오지 않음)
  dummy,
  dummyHard,
  dummyElement,
  trainingGolem,
  // 묶음 50 #146 하이랜드: 수호자 다섯 · 작은 석상 병사 (지도 밖, 도감 끝 칸)
  guardWind,
  guardThunder,
  guardLight,
  guardIce,
  guardWater,
  stoneSoldier,
  // 묶음 52 #243 3막 지역 1 「국경의 약탈자들」 + 보스 (저쪽 세계, 지도·도감 밖)
  goblinRaider,
  skeletonGuard,
  harpy,
  ogre,
  ashHounds,
  ashArmor,
  ashWolfAlpha,

  /// 묶음 56 #236: 파티 보스 (주마다 차례로)
  partyGolem,
  partyHydra,
  partyWyvern,
  partyKraken,
  // 묶음 57 #243 3막 지역 2~5 (저쪽 세계에서만, 지도·도감 밖)
  orcMerc,
  koboldMiner,
  gargoyle,
  livingArmor,
  orcCaptain,
  ashCart,
  metalColossus,
  treant,
  giantSpider,
  dryad,
  woodWolf,
  spiderQueen,
  ashElder,
  ashTortoise,
  vampireBat,
  wraith,
  ghoul,
  cultZealot,
  cultPriests,
  ashCaptain,
  ashBeasts,
  salamander,
  ifrit,
  koboldrake,
  cultFlamePriest,
  youngRedDragon,
  orben,
  orbenAsh,
  phoenixMother,
  // 묶음 59 #246 4막 길드 레이드 (도감 밖)
  raidGiant,
  raidDragon,
  raidLich,
  raidTortoise,
  // 묶음 60 #247 5막 에르바르드 야생 수비대 (바깥 보통 · 안쪽 강함) · 길드 수비대 (도감 밖)
  wildGriffin,
  wildKnightCaptain,
  wildTroll,
  wildRuneGolem,
  wildBoar,
  wildElfArcher,
  wildLizardman,
  wildBanshee,
  wildLavaGolem,
  wildDragonCaptain,
  garrisonClone,
  blackGuard,
  // 묶음 61: 흑등 연맹 지휘관 (5자리 · 왕성) · 길드원 분신 (주 직업 그림 6장)
  blackCaptain,
  cloneWarrior,
  cloneKnight,
  cloneArcher,
  cloneMage,
  clonePriest,
  cloneRogue,
  // 묶음 69 #281: Lv.50부터 지도 몬스터 (5단계)
  doppelganger,
  arachne,
  sphinx,
  clockworkKnight,
  centaur,
  owlbear,
  kelpie,
  naga,
  roc,
  dullahan,
  werewolf,
  deathKnight,
  basilisk,
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

  /// 묶음 69 #281 도플갱어: 첫 턴에 내 공격을 따라 함
  mirror,

  /// 바실리스크: 가끔 한 턴 돌로 굳게 함
  petrify,

  /// 웨어울프: 보름달 밤엔 더 셈
  moon,
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
    this.codexOnly = false,
    this.slimeKind = false,
    this.tint,
    this.element,
    this.highland = false,
    this.art,
    this.preLine,
  });

  /// 묶음 69 #281: 싸우기 전 한 마디 (스핑크스의 수수께끼)
  final String? preLine;

  /// 그림이 아직 없을 때 대신 쓰는 그림 이름 (같은 이름 그림이 오면 지움)
  final String? art;

  /// 묶음 50 하이랜드 몬스터: 도감 끝 칸 (도감 완성 칭호 개수에는 넣지 않음)
  final bool highland;

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

  /// 지도에는 나오지 않지만 도감에는 있는 몬스터 (묶음 23 #168: 튜토리얼 하늘 슬라임)
  final bool codexOnly;

  /// 속성 슬라임 (칭호 '도감의 현자' 조건에서 뺀다)
  final bool slimeKind;

  /// 그림이 없을 때 기본 슬라임 그림에 입히는 색 (0xAARRGGBB)
  final int? tint;

  /// 그림 파일. 없으면 화면에서 아이콘으로 대신 그린다.
  String get asset => 'assets/images/${art ?? 'monster_${id.name}'}.webp';

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

  /// 도감 칸 (묶음 23 #168): 하늘 슬라임이 맨 앞, 그 뒤 지금 나오는 몬스터.
  /// 도감 완성 칭호는 [all] 로 세어 하늘 슬라임은 넣지 않는다
  /// 묶음 50: 하이랜드 6칸은 도감 끝에 (하늘 슬라임처럼 칭호 개수에는 넣지 않음)
  static List<MonsterInfo> get codex => [
        for (final m in _all) if (m.codexOnly && !m.highland) m,
        ...all,
        for (final m in _all) if (m.highland) m,
      ];

  /// 도감에 보이는 몬스터인지
  static bool inCodex(MonsterId id) {
    final m = info(id);
    return !m.retired || m.codexOnly;
  }

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

  static const List<MonsterInfo> _all = [..._monsterTable1, ..._monsterTable2];

  static MonsterInfo info(MonsterId id) => _all.firstWhere((m) => m.id == id);

  /// 묶음 70 #293: 도감 갈래 (발견한 것만 칸을 그리고, 하나라도 발견해야 갈래 제목이 나옴). null = 도감에 없음
  static String? codexGroup(MonsterId id) {
    final m = info(id);
    // 레벨 단계 지도 몬스터 (3막 · 5막 몬스터를 지도에서 다시 씀)
    if (FieldMonsterRules.isTierMonster(id)) return '필드';
    if (m.highland) return '하이랜드';
    const ash = {MonsterId.ashRage, MonsterId.ashSorrow, MonsterId.ashGreed, MonsterId.ashFear, MonsterId.ashLonely, MonsterId.ashKing};
    if (ash.contains(id)) return '2막 분신';
    const train = {MonsterId.dummy, MonsterId.dummyHard, MonsterId.dummyElement, MonsterId.trainingGolem};
    if (train.contains(id)) return '훈련장';
    const party = {MonsterId.partyGolem, MonsterId.partyHydra, MonsterId.partyWyvern, MonsterId.partyKraken};
    if (party.contains(id)) return '파티 보스';
    const raid = {MonsterId.raidGiant, MonsterId.raidDragon, MonsterId.raidLich, MonsterId.raidTortoise};
    if (raid.contains(id)) return '길드 레이드';
    const clones = {MonsterId.cloneWarrior, MonsterId.cloneKnight, MonsterId.cloneArcher, MonsterId.cloneMage, MonsterId.clonePriest, MonsterId.cloneRogue, MonsterId.garrisonClone};
    if (clones.contains(id)) return null;
    if (id.index >= MonsterId.doppelganger.index) return '필드';
    if (id.index >= MonsterId.wildGriffin.index && id.index <= MonsterId.blackCaptain.index) return '공성전';
    if (!m.retired || m.codexOnly) return '필드';
    if (id.index >= MonsterId.goblinRaider.index && id.index <= MonsterId.phoenixMother.index) return '3막 지역';
    return null;
  }

  static const List<String> codexGroups = ['필드', '하이랜드', '2막 분신', '3막 지역', '파티 보스', '길드 레이드', '공성전', '훈련장'];

  /// 묶음 69 #281: 앱에 들어 있는 그림 (main 에서 채움 · 모르면 null = 있다고 봄)
  static Set<String>? knownAssets;
  static bool hasArt(MonsterId id) => knownAssets == null || knownAssets!.contains(info(id).asset);

  static MonsterId? byName(String name) {
    for (final id in MonsterId.values) {
      if (id.name == name) return id;
    }
    return null;
  }
}
