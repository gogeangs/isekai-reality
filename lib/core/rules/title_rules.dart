import 'erbard_rules.dart' show ErbardRules;
import 'element_rules.dart';
import '../models/daily_record.dart';
import 'monsters.dart';
import 'rule_constants.dart';
import 'town_rules.dart';

enum TitleId {
  firstSteps,
  persistentTraveler,
  morningSpiritFriend,
  bookwormSage, // 이름은 '도감의 현자' (저장된 칭호와 맞추려고 id는 그대로)
  forcedMarchKnight,
  nightWalker,
  awakened,
  lanternKeeper,
  // 탐험 칭호 (2026-11-09)
  gateKeeper,
  lakeFriend,
  townLight,
  // 속성 칭호 (11-11 #63): 그 속성 점수가 높으면. 얻기 전에는 보이지 않는다
  elFire,
  elWater,
  elWind,
  elEarth,
  elLight,
  elDark,
  elIce,
  elThunder,
  elMetal,
  elPoison,
  // 보스 칭호 (11-11 #75): 처음 잡으면. 얻기 전에는 보이지 않는다
  bossWarden,
  bossFireKing,
  bossFrostWolf,
  bossTreant,
  bossBatQueen,
  bossGriffin,
  // 11-11 #83: 고대 유물을 다섯 번 캐면 (얻기 전엔 숨김)
  relicHunter,
  // 숨은 숙련도 (묶음 27 #176): 큰 숙련도 숙련된 · 장인
  smithAdept,
  smithMaster,
  harvestAdept,
  harvestMaster,
  alchemyAdept,
  alchemyMaster,
  combatAdept,
  combatMaster,
  walkAdept,
  walkMaster,
  appraiseAdept,
  appraiseMaster,
  spiritAdept,
  spiritMaster,
  tradeAdept,
  tradeMaster,
  // 묶음 34 2막: 분신 다섯 · 본체를 처음 쓰러뜨리면 (얻기 전엔 숨김)
  ashRage,
  ashSorrow,
  ashGreed,
  ashFear,
  ashLonely,
  bridgeMaker,
  // 묶음 42 #226: 마을 사람 4번째 부탁을 끝내면 (얻기 전엔 숨김)
  npcMarta,
  npcMina,
  npcDorgun,
  npcEliel,
  npcHart,
  npcSera,
  npcLumi,
  // 묶음 43 #228: 가렌 마지막 부탁 · 시련 15판 (얻기 전엔 숨김)
  npcGaren,
  trialEndurer,
  // 묶음 48 #230: 포포 마지막 부탁 (그림 title_forestKeeper)
  forestKeeper,
  // 묶음 50 #146 하이랜드: 처음 섬에 오름 · 수호자 다섯 · 비문 다섯 (얻기 전엔 숨김)
  skyWalker,
  guardianTrust,
  kingdomWitness,
  // 묶음 51: 리안 · 바르칸 마지막 부탁 (얻기 전엔 숨김)
  walkTogether,
  merchantFriend,
  // 묶음 53 #243: 3막 지역 1 등불 · 숨은 보스 (얻기 전엔 숨김)
  baldrinLamp,
  windMemory,
  // 묶음 57 #243: 3막 지역 2~5 등불 · 숨은 장소 · 3막 끝 (얻기 전엔 숨김)
  seleniaLamp,
  stardustFinder,
  elowinLamp,
  mossFriend,
  morvalLamp,
  guardMemory,
  aurelLamp,
  phoenixHonor,
  fiveLamps,
  // 묶음 59 #246: 4막 길드 (얻기 전엔 숨김)
  raidGiant,
  raidDragon,
  raidLich,
  raidTortoise,
  lanternOath,
  guildLegend,
  // 묶음 60 #247: 5막 에르바르드
  erbardCrown,
  pioneer,
  // 묶음 69 #281: 바실리스크 첫 사냥
  basiliskSlayer,
  // 묶음 57 #249: 숨은 특별 짝 10 (그림 title_pair_<짝>)
  pairWeaponsmith,
  pairRunesmith,
  pairJeweler,
  pairPotionMerchant,
  pairPeddler,
  pairBeastKnight,
  pairPathfinder,
  pairPaladin,
  pairNightThief,
  pairRanger,
  // 묶음 65 #251: 공성전 선봉장 (그 공성전부터 다음 공성전 끝까지)
  vanguard,
}

class TitleInfo {
  const TitleInfo(this.id, this.name, this.hint);

  final TitleId id;
  final String name;

  /// 잠긴 칭호에 보여 줄 힌트
  final String hint;
}

const _el0 = '불꽃을 닮은 자';
const _el1 = '물결을 닮은 자';
const _el2 = '바람을 닮은 자';
const _el3 = '대지를 닮은 자';
const _el4 = '빛을 닮은 자';
const _el5 = '어둠을 닮은 자';
const _el6 = '서리를 닮은 자';
const _el7 = '번개를 닮은 자';
const _el8 = '강철을 닮은 자';
const _el9 = '독초를 닮은 자';

class TitleRules {
  TitleRules._();

  /// 얻은 이유 한 줄 (칭호 축하 연출, 11-11 #85)
  static String earnedLine(TitleId t) {
    final i = elementTitles.indexOf(t);
    if (i >= 0) {
      return '${Element.values[i].label} 속성과 오래 함께했어요';
    }
    return switch (t) {
      TitleId.firstSteps => '처음으로 걸었어요',
      TitleId.persistentTraveler => '일주일 내내 걸음 목표를 이뤘어요',
      TitleId.morningSpiritFriend => '일주일 내내 여관에서 쉬었어요',
      TitleId.bookwormSage => '도감의 몬스터를 모두 사냥했어요',
      TitleId.forcedMarchKnight => '하루에 아주 많이 걸었어요',
      TitleId.nightWalker => '저녁 8시가 넘어서도 걸었어요',
      TitleId.awakened => 'Lv.5에 올랐어요',
      TitleId.lanternKeeper => 'Lv.10에 올랐어요',
      TitleId.gateKeeper => '미궁 입구 다섯 곳을 가 봤어요',
      TitleId.lakeFriend => '정령의 물가에 다섯 번 놀러 갔어요',
      TitleId.townLight => '필드 몬스터 30마리를 사냥했어요',
      TitleId.bossWarden => '미궁 문지기를 처음 쓰러뜨렸어요',
      TitleId.bossFireKing => '불꽃 슬라임 왕을 처음 쓰러뜨렸어요',
      TitleId.bossFrostWolf => '서리 늑대왕을 처음 쓰러뜨렸어요',
      TitleId.bossTreant => '숲의 고목 정령을 처음 달랬어요',
      TitleId.bossBatQueen => '그림자 박쥐 여왕을 처음 쓰러뜨렸어요',
      TitleId.bossGriffin => '천둥 그리폰을 처음 쓰러뜨렸어요',
      TitleId.relicHunter => '고대 유물을 다섯 번 발굴했어요',
      TitleId.smithAdept || TitleId.smithMaster => '대장간 일에 익숙해졌어요',
      TitleId.harvestAdept || TitleId.harvestMaster => '채집에 익숙해졌어요',
      TitleId.alchemyAdept || TitleId.alchemyMaster => '물약 끓이기에 익숙해졌어요',
      TitleId.combatAdept || TitleId.combatMaster => '싸움에 익숙해졌어요',
      TitleId.walkAdept || TitleId.walkMaster => '정말 많이 걷고 찾아다녔어요',
      TitleId.appraiseAdept || TitleId.appraiseMaster => '감정에 익숙해졌어요',
      TitleId.spiritAdept || TitleId.spiritMaster => '원정 보내기에 익숙해졌어요',
      TitleId.tradeAdept || TitleId.tradeMaster => '장사와 의뢰에 익숙해졌어요',
      TitleId.ashRage => '잿불의 분노를 잠재웠어요',
      TitleId.ashSorrow => '잿비의 슬픔을 달랬어요',
      TitleId.ashGreed => '잿금의 탐욕을 끊어 냈어요',
      TitleId.ashFear => '잿그림자의 두려움을 이겨 냈어요',
      TitleId.ashLonely => '잿바람의 외로움을 안아 줬어요',
      TitleId.bridgeMaker => '잿빛 군주를 멈추고 문을 다리로 바꿨어요',
      TitleId.npcMarta => '마르타의 마지막 부탁을 들어줬어요',
      TitleId.npcMina => '미나의 마지막 부탁을 들어줬어요',
      TitleId.npcDorgun => '도르군의 마지막 부탁을 들어줬어요',
      TitleId.npcEliel => '엘리엘의 마지막 부탁을 들어줬어요',
      TitleId.npcHart => '하르트의 마지막 부탁을 들어줬어요',
      TitleId.npcSera => '세라의 마지막 부탁을 들어줬어요',
      TitleId.npcLumi => '루미의 마지막 부탁을 들어줬어요',
      TitleId.npcGaren => '가렌의 마지막 부탁을 들어줬어요',
      TitleId.forestKeeper => '포포의 마지막 부탁을 들어줬어요',
      TitleId.walkTogether => '리안의 마지막 부탁을 들어줬어요',
      TitleId.merchantFriend => '바르칸의 마지막 부탁을 들어줬어요',
      TitleId.skyWalker => '하늘에 뜬 섬에 처음 올랐어요',
      TitleId.guardianTrust => '하이랜드 수호자 다섯을 모두 쓰러뜨렸어요',
      TitleId.kingdomWitness => '하이랜드의 비문 다섯을 모두 모았어요',
      TitleId.baldrinLamp => '발드린 관문의 등불을 다시 켰어요',
      TitleId.windMemory => '바람의 굴에서 잿빛 늑대 우두머리를 쓰러뜨렸어요',
      TitleId.seleniaLamp => '셀레니아 대장터의 등불을 다시 켰어요',
      TitleId.stardustFinder => '별가루 광맥에서 고대 금속 거인을 쓰러뜨렸어요',
      TitleId.elowinLamp => '엘로윈 숲의 등불을 다시 켰어요',
      TitleId.mossFriend => '모스의 연못에서 잿빛 고대 거북을 쓰러뜨렸어요',
      TitleId.morvalLamp => '모르발 왕도의 등불을 다시 켰어요',
      TitleId.guardMemory => '근위대 마구간에서 잿빛 근위대 짐승을 쓰러뜨렸어요',
      TitleId.aurelLamp => '아우렐 성소의 마지막 등불을 켰어요',
      TitleId.phoenixHonor => '잿불새의 둥지에서 불사조 어미를 만났어요',
      TitleId.fiveLamps => '다섯 등불을 모두 다시 켰어요',
      TitleId.raidGiant => '길드와 함께 빛을 먹는 거인을 쓰러뜨렸어요',
      TitleId.raidDragon => '길드와 함께 고대 드래곤을 쓰러뜨렸어요',
      TitleId.raidLich => '길드와 함께 리치 왕을 쓰러뜨렸어요',
      TitleId.raidTortoise => '길드와 함께 대지의 거북을 쓰러뜨렸어요',
      TitleId.lanternOath => '4막 「등불의 맹세」를 끝냈어요',
      TitleId.guildLegend => '길드가 Lv.10 「전설의 길드」가 됐어요',
      TitleId.erbardCrown => '공성전에서 에르바르드 왕성을 지켰어요',
      TitleId.vanguard => '공성전에서 길드 가장 앞에 섰어요 (다음 공성전 끝까지)',
      TitleId.pioneer => '5막 「흑등 연맹의 귀환」을 끝냈어요',
      TitleId.basiliskSlayer => '아주 드물게 나타나는 바실리스크를 처음 쓰러뜨렸어요',
      TitleId.trialEndurer => '훈련장 시련에서 처음으로 15판을 넘겼어요',
      TitleId.pairWeaponsmith => '숨은 짝 「무기 장인」을 찾았어요',
      TitleId.pairRunesmith => '숨은 짝 「룬 대장장이」을 찾았어요',
      TitleId.pairJeweler => '숨은 짝 「보석 세공사」을 찾았어요',
      TitleId.pairPotionMerchant => '숨은 짝 「물약 상인」을 찾았어요',
      TitleId.pairPeddler => '숨은 짝 「행상인」을 찾았어요',
      TitleId.pairBeastKnight => '숨은 짝 「마수 기사」을 찾았어요',
      TitleId.pairPathfinder => '숨은 짝 「길잡이」을 찾았어요',
      TitleId.pairPaladin => '숨은 짝 「성기사」을 찾았어요',
      TitleId.pairNightThief => '숨은 짝 「밤의 도둑」을 찾았어요',
      TitleId.pairRanger => '숨은 짝 「레인저」을 찾았어요',

      _ => '새 칭호를 얻었어요',
    };
  }

  /// 도감에 보이는 칭호. 장소 칭호(미궁의 문지기·호수의 친구)는
  /// 전국 확대로 장소를 빼면서 숨겼다 (11-10, 장소를 다시 넣을 때 되살림).
  static List<TitleInfo> get all => [
        for (final t in _all)
          if (!hidden.contains(t.id)) t,
      ];

  static const Set<TitleId> hidden = {
    TitleId.gateKeeper,
    TitleId.lakeFriend,
    ...elementTitles,
    ...bossTitles,
    TitleId.relicHunter,
    ...masteryTitles,
    ...ashTitles,
    ...npcTitles,
    TitleId.trialEndurer,
    ...skyTitles,
    ...pairTitles,
  };

  /// 묶음 57: 특별 짝 칭호 (counters 'stitle:<이름>' 으로 얻음, 얻기 전엔 숨김)
  static const List<TitleId> pairTitles = [
    TitleId.pairWeaponsmith,
    TitleId.pairRunesmith,
    TitleId.pairJeweler,
    TitleId.pairPotionMerchant,
    TitleId.pairPeddler,
    TitleId.pairBeastKnight,
    TitleId.pairPathfinder,
    TitleId.pairPaladin,
    TitleId.pairNightThief,
    TitleId.pairRanger,
  ];

  /// 칭호 그림 이름 (특별 짝은 title_pair_<짝>)
  static String asset(TitleId t) {
    if (pairTitles.contains(t)) {
      final n = t.name.substring(4);
      return 'title_pair_${n[0].toLowerCase()}${n.substring(1)}';
    }
    return 'title_${t.name}';
  }

  /// 하이랜드 칭호 (묶음 50 #146). 기록 counters 'stitle:<이름>' 으로 얻는다
  static const List<TitleId> skyTitles = [
    TitleId.skyWalker,
    TitleId.guardianTrust,
    TitleId.kingdomWitness,
    TitleId.baldrinLamp,
    TitleId.windMemory,
    TitleId.seleniaLamp,
    TitleId.stardustFinder,
    TitleId.elowinLamp,
    TitleId.mossFriend,
    TitleId.morvalLamp,
    TitleId.guardMemory,
    TitleId.aurelLamp,
    TitleId.phoenixHonor,
    TitleId.fiveLamps,
    TitleId.raidGiant,
    TitleId.raidDragon,
    TitleId.raidLich,
    TitleId.raidTortoise,
    TitleId.lanternOath,
    TitleId.guildLegend,
    TitleId.erbardCrown,
    TitleId.pioneer,
    TitleId.basiliskSlayer,
  ];

  static String skyCounter(TitleId t) => 'stitle:${t.name}';

  /// 선봉장 기록 ('vanguard@<공성전 번호>')
  static const String vanguardPrefix = 'vanguard@';

  /// 마을 사람 칭호 (묶음 42 #226). 기록 counters 'ntitle:<이름>' 으로 얻는다
  static const List<TitleId> npcTitles = [
    TitleId.npcMarta,
    TitleId.npcMina,
    TitleId.npcDorgun,
    TitleId.npcEliel,
    TitleId.npcHart,
    TitleId.npcSera,
    TitleId.npcLumi,
    TitleId.npcGaren,
    TitleId.forestKeeper,
    TitleId.walkTogether,
    TitleId.merchantFriend,
  ];

  static String npcCounter(TitleId t) => 'ntitle:${t.name}';

  /// 묶음 43: 시련 15판 칭호 기록 칸
  static const String trialCounter = 'trial15';

  /// 2막 칭호 (묶음 34)와 그 몬스터: 처음 쓰러뜨리면
  static const Map<TitleId, MonsterId> ashTitleMonsters = {
    TitleId.ashRage: MonsterId.ashRage,
    TitleId.ashSorrow: MonsterId.ashSorrow,
    TitleId.ashGreed: MonsterId.ashGreed,
    TitleId.ashFear: MonsterId.ashFear,
    TitleId.ashLonely: MonsterId.ashLonely,
    TitleId.bridgeMaker: MonsterId.ashKing,
  };
  static const List<TitleId> ashTitles = [
    TitleId.ashRage,
    TitleId.ashSorrow,
    TitleId.ashGreed,
    TitleId.ashFear,
    TitleId.ashLonely,
    TitleId.bridgeMaker,
  ];

  /// 숨은 숙련도 칭호 (묶음 27 #176). 기록 counters 'mtitle:<이름>' 으로 얻는다
  static const List<TitleId> masteryTitles = [
    TitleId.smithAdept,
    TitleId.smithMaster,
    TitleId.harvestAdept,
    TitleId.harvestMaster,
    TitleId.alchemyAdept,
    TitleId.alchemyMaster,
    TitleId.combatAdept,
    TitleId.combatMaster,
    TitleId.walkAdept,
    TitleId.walkMaster,
    TitleId.appraiseAdept,
    TitleId.appraiseMaster,
    TitleId.spiritAdept,
    TitleId.spiritMaster,
    TitleId.tradeAdept,
    TitleId.tradeMaster,
  ];

  /// 숙련도 칭호를 얻었다는 기록 칸
  static String masteryCounter(TitleId t) => 'mtitle:${t.name}';

  /// 보스 칭호와 그 보스
  static const Map<TitleId, MonsterId> bossTitleMonsters = {
    TitleId.bossWarden: MonsterId.labyrinthWarden,
    TitleId.bossFireKing: MonsterId.fireSlimeKing,
    TitleId.bossFrostWolf: MonsterId.frostWolfKing,
    TitleId.bossTreant: MonsterId.ancientTreant,
    TitleId.bossBatQueen: MonsterId.shadowBatQueen,
    TitleId.bossGriffin: MonsterId.thunderGriffin,
  };
  static const List<TitleId> bossTitles = [
    TitleId.bossWarden,
    TitleId.bossFireKing,
    TitleId.bossFrostWolf,
    TitleId.bossTreant,
    TitleId.bossBatQueen,
    TitleId.bossGriffin,
  ];

  /// 속성 칭호 (Element 순서와 같다)
  static const List<TitleId> elementTitles = [
    TitleId.elFire,
    TitleId.elWater,
    TitleId.elWind,
    TitleId.elEarth,
    TitleId.elLight,
    TitleId.elDark,
    TitleId.elIce,
    TitleId.elThunder,
    TitleId.elMetal,
    TitleId.elPoison,
  ];

  /// 프로필에 보이는 칭호: 보통 칭호 + 얻은 속성 칭호
  static List<TitleInfo> visible(Set<TitleId> earned) => [
        ...all,
        for (final t in elementTitles)
          if (earned.contains(t)) info(t),
        for (final t in bossTitles)
          if (earned.contains(t)) info(t),
        if (earned.contains(TitleId.relicHunter)) info(TitleId.relicHunter),
        for (final t in masteryTitles)
          if (earned.contains(t)) info(t),
        for (final t in ashTitles)
          if (earned.contains(t)) info(t),
      ];

  static const List<TitleInfo> _all = [
    TitleInfo(TitleId.firstSteps, '첫 걸음', '처음으로 걸어 보기'),
    TitleInfo(TitleId.persistentTraveler, '끈기의 여행자', '일주일 내내 목표 달성'),
    TitleInfo(TitleId.morningSpiritFriend, '아침 정령의 친구', '여관에서 일주일 내내 쉬기'),
    TitleInfo(TitleId.bookwormSage, '도감의 현자', '몬스터 7종을 모두 사냥하기 (속성 슬라임은 빼고)'),
    TitleInfo(TitleId.forcedMarchKnight, '강행군의 기사', '하루에 아주 많이 걷기'),
    TitleInfo(TitleId.nightWalker, '밤길의 산책자', '저녁 8시 이후에 걷기'),
    TitleInfo(TitleId.awakened, '각성자', 'Lv.5 달성'),
    TitleInfo(TitleId.lanternKeeper, '등불지기', 'Lv.10 달성'),
    TitleInfo(TitleId.gateKeeper, '미궁의 문지기', '미궁 입구 다섯 곳 가 보기'),
    TitleInfo(TitleId.lakeFriend, '호수의 친구', '정령의 물가에 다섯 번 놀러 가기'),
    TitleInfo(TitleId.townLight, '동네의 빛', '필드 몬스터 30마리 사냥하기'),
    TitleInfo(TitleId.elFire, _el0, '숨은 칭호'),
    TitleInfo(TitleId.elWater, _el1, '숨은 칭호'),
    TitleInfo(TitleId.elWind, _el2, '숨은 칭호'),
    TitleInfo(TitleId.elEarth, _el3, '숨은 칭호'),
    TitleInfo(TitleId.elLight, _el4, '숨은 칭호'),
    TitleInfo(TitleId.elDark, _el5, '숨은 칭호'),
    TitleInfo(TitleId.elIce, _el6, '숨은 칭호'),
    TitleInfo(TitleId.elThunder, _el7, '숨은 칭호'),
    TitleInfo(TitleId.elMetal, _el8, '숨은 칭호'),
    TitleInfo(TitleId.elPoison, _el9, '숨은 칭호'),
    TitleInfo(TitleId.bossWarden, '문지기를 넘은 자', '숨은 칭호'),
    TitleInfo(TitleId.bossFireKing, '불꽃왕 사냥꾼', '숨은 칭호'),
    TitleInfo(TitleId.bossFrostWolf, '서리를 깨뜨린 자', '숨은 칭호'),
    TitleInfo(TitleId.bossTreant, '숲을 달래는 자', '숨은 칭호'),
    TitleInfo(TitleId.bossBatQueen, '밤을 밝힌 자', '숨은 칭호'),
    TitleInfo(TitleId.bossGriffin, '하늘을 가른 자', '숨은 칭호'),
    TitleInfo(TitleId.relicHunter, '옛 이야기를 캔 자', '숨은 칭호'),
    TitleInfo(TitleId.smithAdept, '견습 대장장이', '대장간 일을 꾸준히'),
    TitleInfo(TitleId.smithMaster, '장인 대장장이', '대장간 일의 장인'),
    TitleInfo(TitleId.harvestAdept, '약초꾼', '채집을 꾸준히'),
    TitleInfo(TitleId.harvestMaster, '대지의 손', '채집의 장인'),
    TitleInfo(TitleId.alchemyAdept, '견습 연금술사', '물약을 꾸준히'),
    TitleInfo(TitleId.alchemyMaster, '물약 장인', '연금술의 장인'),
    TitleInfo(TitleId.combatAdept, '노련한 사냥꾼', '싸움을 꾸준히'),
    TitleInfo(TitleId.combatMaster, '전장의 장인', '싸움의 장인'),
    TitleInfo(TitleId.walkAdept, '길잡이', '걷고 찾아다니기를 꾸준히'),
    TitleInfo(TitleId.walkMaster, '대륙을 걷는 자', '걷기와 탐험의 장인'),
    TitleInfo(TitleId.appraiseAdept, '견습 감정사', '감정을 꾸준히'),
    TitleInfo(TitleId.appraiseMaster, '진실의 눈', '감정의 장인'),
    TitleInfo(TitleId.spiritAdept, '정령의 벗', '원정을 꾸준히'),
    TitleInfo(TitleId.spiritMaster, '정령과 하나 된 자', '정령술의 장인'),
    TitleInfo(TitleId.tradeAdept, '떠돌이 상인', '장사와 의뢰를 꾸준히'),
    TitleInfo(TitleId.tradeMaster, '조합의 해결사', '장사와 의뢰의 장인'),
    TitleInfo(TitleId.ashRage, '분노를 잠재운 자', '숨은 칭호'),
    TitleInfo(TitleId.ashSorrow, '슬픔을 달랜 자', '숨은 칭호'),
    TitleInfo(TitleId.ashGreed, '탐욕을 끊은 자', '숨은 칭호'),
    TitleInfo(TitleId.ashFear, '두려움을 이긴 자', '숨은 칭호'),
    TitleInfo(TitleId.ashLonely, '외로움을 안아 준 자', '숨은 칭호'),
    TitleInfo(TitleId.bridgeMaker, '다리를 놓은 자', '숨은 칭호'),
    TitleInfo(TitleId.npcMarta, '여관의 단골', '숨은 칭호'),
    TitleInfo(TitleId.npcMina, '행상의 길동무', '숨은 칭호'),
    TitleInfo(TitleId.npcDorgun, '도르군의 제자', '숨은 칭호'),
    TitleInfo(TitleId.npcEliel, '빛을 담는 이', '숨은 칭호'),
    TitleInfo(TitleId.npcHart, '문지기의 후배', '숨은 칭호'),
    TitleInfo(TitleId.npcSera, '근위 기사의 맹세', '숨은 칭호'),
    TitleInfo(TitleId.npcLumi, '짐승들의 친구', '숨은 칭호'),
    TitleInfo(TitleId.npcGaren, '문지기 기사단의 후예', '숨은 칭호'),
    TitleInfo(TitleId.trialEndurer, '시련을 견딘 자', '숨은 칭호'),
    TitleInfo(TitleId.forestKeeper, '숲을 기르는 자', '숨은 칭호'),
    TitleInfo(TitleId.walkTogether, '함께 걷는 자', '숨은 칭호'),
    TitleInfo(TitleId.merchantFriend, '상단의 벗', '숨은 칭호'),
    TitleInfo(TitleId.skyWalker, '하늘을 걸은 자', '숨은 칭호'),
    TitleInfo(TitleId.guardianTrust, '수호자들이 인정한 자', '숨은 칭호'),
    TitleInfo(TitleId.kingdomWitness, '잊힌 왕국의 증인', '숨은 칭호'),
    TitleInfo(TitleId.baldrinLamp, '관문의 등불지기', '숨은 칭호'),
    TitleInfo(TitleId.windMemory, '바람을 기억하는 자', '숨은 칭호'),
    TitleInfo(TitleId.seleniaLamp, '장터의 등불지기', '숨은 칭호'),
    TitleInfo(TitleId.stardustFinder, '별가루를 찾은 자', '숨은 칭호'),
    TitleInfo(TitleId.elowinLamp, '숲의 등불지기', '숨은 칭호'),
    TitleInfo(TitleId.mossFriend, '모스의 친구', '숨은 칭호'),
    TitleInfo(TitleId.morvalLamp, '왕도의 등불지기', '숨은 칭호'),
    TitleInfo(TitleId.guardMemory, '근위대의 기억', '숨은 칭호'),
    TitleInfo(TitleId.aurelLamp, '성소의 등불지기', '숨은 칭호'),
    TitleInfo(TitleId.phoenixHonor, '불사조의 예우', '숨은 칭호'),
    TitleInfo(TitleId.fiveLamps, '다섯 등불의 수호자', '숨은 칭호'),
    TitleInfo(TitleId.raidGiant, '빛을 되찾은 길드원', '숨은 칭호'),
    TitleInfo(TitleId.raidDragon, '용을 잠재운 길드원', '숨은 칭호'),
    TitleInfo(TitleId.raidLich, '왕관을 부순 길드원', '숨은 칭호'),
    TitleInfo(TitleId.raidTortoise, '대지를 흔든 길드원', '숨은 칭호'),
    TitleInfo(TitleId.lanternOath, '등불의 맹세', '숨은 칭호'),
    TitleInfo(TitleId.guildLegend, '전설의 길드', '숨은 칭호'),
    TitleInfo(TitleId.erbardCrown, '에르바르드의 왕관', '숨은 칭호'),
    TitleInfo(TitleId.vanguard, '선봉장', '숨은 칭호'),
    TitleInfo(TitleId.pioneer, '에르바르드의 개척자', '숨은 칭호'),
    TitleInfo(TitleId.basiliskSlayer, '뱀의 왕을 쓰러뜨린 자', '숨은 칭호'),
    TitleInfo(TitleId.pairWeaponsmith, '무기 장인', '숨은 짝'),
    TitleInfo(TitleId.pairRunesmith, '룬 대장장이', '숨은 짝'),
    TitleInfo(TitleId.pairJeweler, '보석 세공사', '숨은 짝'),
    TitleInfo(TitleId.pairPotionMerchant, '물약 상인', '숨은 짝'),
    TitleInfo(TitleId.pairPeddler, '행상인', '숨은 짝'),
    TitleInfo(TitleId.pairBeastKnight, '마수 기사', '숨은 짝'),
    TitleInfo(TitleId.pairPathfinder, '길잡이', '숨은 짝'),
    TitleInfo(TitleId.pairPaladin, '성기사', '숨은 짝'),
    TitleInfo(TitleId.pairNightThief, '밤의 도둑', '숨은 짝'),
    TitleInfo(TitleId.pairRanger, '레인저', '숨은 짝'),

  ];

  /// 탐험 칭호가 보는 장소 id 머리말 (lib/features/map/ansan_area.dart)
  static const String gatePrefix = 'gate_';
  static const String lakePrefix = 'lake_';

  /// 대표 칭호: 플레이어가 고른 칭호가 있고 얻은 칭호면 그것,
  /// 아니면 '끈기의 여행자' → 가장 나중 칭호 순으로 자동.
  static TitleId? equipped(Set<TitleId> earned, {TitleId? chosen}) {
    if (chosen != null && earned.contains(chosen)) return chosen;
    if (earned.contains(TitleId.persistentTraveler)) {
      return TitleId.persistentTraveler;
    }
    for (final t in all.reversed) {
      if (earned.contains(t.id)) return t.id;
    }
    return null;
  }

  static TitleId? parse(String? name) {
    for (final t in TitleId.values) {
      if (t.name == name) return t;
    }
    return null;
  }

  static TitleInfo info(TitleId id) => _all.firstWhere((t) => t.id == id);

  /// 날짜순으로 정렬된 [history] 와 현재 [level] 로 얻은 칭호를 계산한다
  static Set<TitleId> earned(List<DailyRecord> history, int level) {
    final result = <TitleId>{};

    final totalSteps = history.fold<int>(0, (s, d) => s + d.steps);
    final species = <String>{for (final d in history) ...d.purifiedMonsterIds};

    if (totalSteps >= RuleConstants.firstStepsThreshold) {
      result.add(TitleId.firstSteps);
    }
    if (_longestStreak(history, (d) => d.stepGoalAchieved) >=
        RuleConstants.persistentTravelerDays) {
      result.add(TitleId.persistentTraveler);
    }
    final restStreaks = TownRules.restStreaks(history);
    if (restStreaks.isNotEmpty &&
        restStreaks.reduce((a, b) => a > b ? a : b) >=
            RuleConstants.morningSpiritDays) {
      result.add(TitleId.morningSpiritFriend);
    }
    // 11-10: 지금 도감의 몬스터를 모두 사냥했거나, 예전 6종을 모두 정화했으면
    // 11-11: 속성 슬라임은 빼고 7종 (무속성 슬라임 포함)
    final active = {
      for (final m in Monsters.all)
        // 11-11 #75 요일 보스는 빼고 (미궁 문지기는 그대로)
        if (!m.slimeKind && (!m.isBoss || m.id == MonsterId.labyrinthWarden))
          m.id.name,
    };
    const oldSix = {
      'ashSlime', 'labyrinthBat', 'roughWaterSpirit',
      'shadowButterfly', 'lostStoneSpirit', 'labyrinthWarden',
    };
    if (species.containsAll(active) || species.containsAll(oldSix)) {
      result.add(TitleId.bookwormSage);
    }
    if (history.any((d) => d.steps >= RuleConstants.forcedMarchSteps)) {
      result.add(TitleId.forcedMarchKnight);
    }
    final nightDays = history
        .where((d) => d.stepsAfter8pm >= RuleConstants.nightWalkSteps)
        .length;
    if (nightDays >= RuleConstants.nightWalkDays) {
      result.add(TitleId.nightWalker);
    }
    if (level >= RuleConstants.awakenedLevel) result.add(TitleId.awakened);
    if (level >= RuleConstants.lanternKeeperLevel) {
      result.add(TitleId.lanternKeeper);
    }

    final visited = <String>{for (final d in history) ...d.visitedPlaceIds};
    final gates = visited.where((id) => id.startsWith(gatePrefix)).length;
    if (gates >= RuleConstants.gateKeeperGates) result.add(TitleId.gateKeeper);
    final lakeDays = history
        .where((d) => d.visitedPlaceIds.any((id) => id.startsWith(lakePrefix)))
        .length;
    if (lakeDays >= RuleConstants.lakeFriendVisits) {
      result.add(TitleId.lakeFriend);
    }
    // 속성 칭호 (11-11 #63)
    ElementRules.scoresFrom(history).forEach((e, v) {
      if (v >= ElementRules.titleScore) {
        result.add(elementTitles[Element.values.indexOf(e)]);
      }
    });
    // 보스 칭호 (11-11 #75): 그 보스를 처음 잡으면
    bossTitleMonsters.forEach((t, m) {
      if (species.contains(m.name)) result.add(t);
    });
    // 묶음 34 2막: 분신·본체를 처음 쓰러뜨리면
    ashTitleMonsters.forEach((t, m) {
      if (species.contains(m.name)) result.add(t);
    });
    final relics = history.fold<int>(0, (s, d) => s + (d.counters['relicDug'] ?? 0));
    if (relics >= 5) result.add(TitleId.relicHunter);
    // 숨은 숙련도 칭호 (묶음 27 #176)
    for (final t in masteryTitles) {
      final k = masteryCounter(t);
      if (history.any((d) => (d.counters[k] ?? 0) > 0)) result.add(t);
    }
    for (final t in npcTitles) {
      final k = npcCounter(t);
      if (history.any((d) => (d.counters[k] ?? 0) > 0)) result.add(t);
    }
    // 묶음 50 #146: 하이랜드
    for (final t in [...skyTitles, ...pairTitles]) {
      final k = skyCounter(t);
      if (history.any((d) => (d.counters[k] ?? 0) > 0)) result.add(t);
    }
    // 묶음 65 #251: 선봉장 — 그 공성전부터 다음 공성전 끝까지만
    final last = history.isEmpty ? null : history.last.date;
    if (last != null) {
      for (final d in history) {
        for (final k in d.counters.keys) {
          if (!k.startsWith(vanguardPrefix)) continue;
          final n = int.tryParse(k.substring(vanguardPrefix.length));
          if (n != null && last.isBefore(ErbardRules.siegeEnd(n + 1).toLocal())) result.add(TitleId.vanguard);
        }
      }
    }
    // 묶음 43 #228: 시련에서 처음 15판을 넘기면
    if (history.any((d) => (d.counters[trialCounter] ?? 0) > 0)) {
      result.add(TitleId.trialEndurer);
    }
    final monsters =
        history.fold<int>(0, (s, d) => s + d.fieldMonstersPurified);
    if (monsters >= RuleConstants.townLightMonsters) {
      result.add(TitleId.townLight);
    }
    return result;
  }

  static int _longestStreak(
    List<DailyRecord> history,
    bool Function(DailyRecord) test,
  ) {
    var best = 0;
    var current = 0;
    for (final day in history) {
      current = test(day) ? current + 1 : 0;
      if (current > best) best = current;
    }
    return best;
  }
}
