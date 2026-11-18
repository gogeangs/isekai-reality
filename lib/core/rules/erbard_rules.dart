import 'dart:math' as math;

import 'guild_rules.dart' show Act4Scene, GuildRules;
import 'job_rules.dart' show JobId;
import 'materials.dart';
import 'monsters.dart';

/// 5막 첫 편 「흑등 연맹의 귀환」 (#247 · 묶음 60): 새 대륙 에르바르드 · 영지 30 + 왕성 · 야생 수비대 · 깃발 공성전.
/// 숫자는 숨은 값(처음 값), 화면엔 문장만. 서버(firebase/functions/src/siege.js)가 같은 영지 표(siege_estates.json)로 판정한다.

/// 속성 지방 다섯
enum Province { light, metal, earth, dark, fire }

class ProvinceInfo {
  const ProvinceInfo(this.province, this.name, this.element, this.outer, this.inner, this.flavor);
  final Province province;
  final String name;

  /// 속성 글 (빛 · 금속 · 대지 · 어둠 · 불)
  final String element;

  /// 바깥(보통) · 안쪽(강함) 야생 수비대
  final MonsterId outer, inner;
  final String flavor;
}

/// 영지 하나 (지도 그림 3072×3072 위 자리)
class EstateInfo {
  const EstateInfo(this.id, this.name, this.province, this.inner, this.x, this.y, {this.npcStart = false});
  final String id;
  final String name;

  /// null 이면 가운데 왕성
  final Province? province;

  /// 안쪽(강함) 영지
  final bool inner;
  final double x, y;

  /// 흑등 연맹이 쥐고 시작
  final bool npcStart;

  bool get royal => province == null;
}

/// 지금 영지 주인 (서버 · 혼자면 처음 판)
class EstateOwner {
  const EstateOwner({this.gid, this.name = '', this.emblem = 0, this.color = 0, this.crown = false});
  final String? gid;
  final String name;
  final int emblem, color;
  final bool crown;

  bool get npc => gid == ErbardRules.npc;
  bool get empty => gid == null;
}

abstract final class ErbardRules {
  static const String mapImage = 'assets/images/map_erbard.webp';
  static const double mapW = 3072, mapH = 3072;
  static const String arriveImage = 'assets/images/scene_erbard_arrive.webp';
  static const String siegeBg = 'assets/images/bg_siege.webp';
  static const String ticketImage = 'assets/images/item_siegeTicket.webp';
  static const String royalChest = 'assets/images/chest_royal.webp';
  static const String crownMark = 'assets/images/flag_mark_crown.webp';
  static const String npcEmblem = 'assets/images/flag_emb_blackLantern.webp';

  /// 흑등 연맹 (NPC) 길드 번호 · 이름
  static const String npc = 'npc';
  static const String npcName = '흑등 연맹';

  static String estateIcon(EstateInfo e) => 'assets/images/icon_estate_${e.province?.name ?? 'royal'}.webp';

  static const List<ProvinceInfo> provinces = [
    ProvinceInfo(Province.light, '솔레안 평원', '빛', MonsterId.wildGriffin, MonsterId.wildKnightCaptain, '옛 기사 왕국의 성채'),
    ProvinceInfo(Province.metal, '도르마크 산맥', '금속', MonsterId.wildTroll, MonsterId.wildRuneGolem, '드워프 광산 요새'),
    ProvinceInfo(Province.earth, '실바렌 숲', '대지', MonsterId.wildBoar, MonsterId.wildElfArcher, '엘프 나무 성'),
    ProvinceInfo(Province.dark, '모르테인 늪', '어둠', MonsterId.wildLizardman, MonsterId.wildBanshee, '무너진 망자의 성'),
    ProvinceInfo(Province.fire, '이그나르 화산', '불', MonsterId.wildLavaGolem, MonsterId.wildDragonCaptain, '용족 화산 요새'),
  ];
  static ProvinceInfo province(Province p) => provinces[p.index];

  /// 영지 30 + 왕성 (지도 빈 터 31곳 그대로, 안쪽 3곳은 왕성에 가까운 쪽)
  static const List<EstateInfo> estates = [
    EstateInfo('royal', '에르바르드 왕성', null, true, 1538, 1568, npcStart: true),
    // 솔레안 평원 (빛)
    EstateInfo('sol_lily', '백합 들판 성', Province.light, false, 2063, 331),
    EstateInfo('sol_bell', '종루 마을', Province.light, false, 1507, 299),
    EstateInfo('sol_pilgrim', '순례자 다리', Province.light, false, 992, 314),
    EstateInfo('sol_dawn', '새벽 성채', Province.light, true, 1254, 527),
    EstateInfo('sol_silver', '은방패 요새', Province.light, true, 1818, 527, npcStart: true),
    EstateInfo('sol_sun', '햇살 망루', Province.light, true, 1534, 730),
    // 도르마크 산맥 (금속)
    EstateInfo('dor_wind', '쇠바람 고개', Province.metal, false, 2474, 857),
    EstateInfo('dor_forge', '용광로 마을', Province.metal, false, 2727, 936),
    EstateInfo('dor_crystal', '수정 동굴', Province.metal, false, 2734, 1252),
    EstateInfo('dor_hammer', '망치봉 요새', Province.metal, true, 2298, 747),
    EstateInfo('dor_deep', '깊은 갱도 성', Province.metal, true, 2134, 973),
    EstateInfo('dor_bronze', '청동문 관문', Province.metal, true, 2234, 1271, npcStart: true),
    // 실바렌 숲 (대지)
    EstateInfo('sil_deer', '사슴 샘', Province.earth, false, 740, 735),
    EstateInfo('sil_mushroom', '버섯 골짜기', Province.earth, false, 360, 936),
    EstateInfo('sil_leaf', '잎사귀 망루', Province.earth, false, 343, 1244),
    EstateInfo('sil_moss', '이끼 성벽', Province.earth, true, 980, 970),
    EstateInfo('sil_vine', '덩굴 다리', Province.earth, true, 870, 1127, npcStart: true),
    EstateInfo('sil_throne', '고목 왕좌', Province.earth, true, 857, 1257),
    // 모르테인 늪 (어둠)
    EstateInfo('mor_ferry', '망자의 나루', Province.dark, false, 326, 1796),
    EstateInfo('mor_mill', '검은 물레방아', Province.dark, false, 372, 2080),
    EstateInfo('mor_grave', '안개 묘지', Province.dark, false, 551, 2374),
    EstateInfo('mor_sunken', '가라앉은 성', Province.dark, true, 872, 1801),
    EstateInfo('mor_raven', '까마귀 탑', Province.dark, true, 1058, 2050, npcStart: true),
    EstateInfo('mor_abbey', '등불 꺼진 수도원', Province.dark, true, 968, 2313),
    // 이그나르 화산 (불)
    EstateInfo('ign_beacon', '붉은 봉화대', Province.fire, false, 2727, 1793),
    EstateInfo('ign_bridge', '용암 다리', Province.fire, false, 2680, 2082),
    EstateInfo('ign_forge', '잿불 대장간', Province.fire, false, 2538, 2376),
    EstateInfo('ign_temple', '불꽃 신전', Province.fire, true, 2139, 1823),
    EstateInfo('ign_gate', '흑요석 성문', Province.fire, true, 1999, 2058, npcStart: true),
    EstateInfo('ign_nest', '용의 둥지 요새', Province.fire, true, 2136, 2313),
  ];

  static EstateInfo? estate(String id) => estates.where((e) => e.id == id).firstOrNull;

  /// 혼자일 때(서버 없이) 보는 처음 판: 흑등 연맹이 왕성 + 지방마다 1곳
  static Map<String, EstateOwner> get startOwners => {
        for (final e in estates)
          if (e.npcStart) e.id: const EstateOwner(gid: npc, name: npcName),
      };

  // ───────────── 숫자 (숨은 값, 서버와 같음)

  static const int maxEstates = 3;
  static const int royalNeeds = 2;
  static const int slots = 5;
  static const int garrisonAllies = 2;

  /// 공성권: 5막 1장부터 어디서든 2,000보마다 1장 (최대 20장)
  static const int ticketSteps = 2000;
  static const int ticketMax = 20;

  /// 공성전: 2주에 한 번, 격주 토 · 일 48시간 (한국 시각). 첫 공성전 2026-11-28(토) 0시
  static final DateTime siegeAnchor = DateTime.utc(2026, 11, 27, 15);
  static const Duration siegePeriod = Duration(days: 14);
  static const Duration siegeLength = Duration(days: 2);

  /// 지금(또는 다음) 공성전 번호: 0 = 첫 공성전
  static int siegeNo(DateTime now) {
    final d = now.toUtc().difference(siegeAnchor);
    if (d.isNegative) return 0;
    final n = d.inMilliseconds ~/ siegePeriod.inMilliseconds;
    return d.inMilliseconds - n * siegePeriod.inMilliseconds < siegeLength.inMilliseconds ? n : n + 1;
  }

  static DateTime siegeStart(int n) => siegeAnchor.add(siegePeriod * n);
  static DateTime siegeEnd(int n) => siegeStart(n).add(siegeLength);
  static bool siegeActive(DateTime now) {
    final n = siegeNo(now);
    final u = now.toUtc();
    return !u.isBefore(siegeStart(n)) && u.isBefore(siegeEnd(n));
  }

  /// 연맹은 공성전 4번(8주)마다 다시 고름
  static const int allianceLock = 4;
  static const int allianceMax = 3;

  /// 야생 수비대 · 흑등 수비대 세기: 서버 길드 평균 레벨 기준, 안쪽 · 왕성은 더, 자리마다 조금씩 더
  static const double innerMult = 1.35;
  static const double royalMult = 1.7;
  static const double slotStep = 0.08;
  static const double wildHp = 4.0, wildAtk = 1.3;

  /// 길드원 걸음으로 수비대가 튼튼해짐 (두 주 동안, 한 사람 몫 10만 보마다 +10%, 최대 +50%)
  static const int garrisonStepsPer = 100000;
  static const double garrisonStepBonus = 0.10;
  static const double garrisonStepMax = 0.50;

  /// 보상 (등불 인장)
  static const int wildWinGold = 80;
  static const int wildClearSeals = 15;
  static const int pioneerSeals = 20, pioneerGold = 500;
  static const int siegeSealsPerEstate = 10;
  static const int siegeTicketSeals = 10;
  static const int siegeJoinSeals = 5;
  static const int royalWeight = 3;

  // ───────────── 묶음 61: 길드 금고 (금화) · 서버 확인

  /// 수비대 강화 3단계: 금고 금화 (길드장 · 부길드장에게 보임) · 세기 (숨김). 그 영지 · 다음 공성전 끝까지
  static const List<int> boostCost = [3000, 7000, 12000];
  static const List<double> boostMult = [0.10, 0.20, 0.30];

  /// 길드원에게 나눠 주기: 공성전이 끝난 뒤 다음 공성전 전까지 한 번, 금고의 절반까지, 한 사람 2,000 금화까지
  static const double shareMaxRate = 0.5;
  static const int sharePerHeadMax = 2000;

  /// 회관 공사: 금고 금화 10당 회관 점수 1 (하루 400점까지)
  static const int hallTreasuryDayPoints = 400;

  /// 금고 상점 (금고 금화로만): 금빛 꾸미기 2 · 금빛 깃발 문양 1
  static const Map<String, int> treasuryShop = {'goldLights': 4000, 'goldFountain': 6000, 'goldFlag': 5000};

  /// 공성 · 야생 한 판은 이보다 빨리 끝나면 이김으로 세지 않음 (서버)
  static const int minFightMs = 4000;

  // ───────────── 묶음 65 #251: 공성전 다듬기 (숨은 값)

  /// 집결 깃발: 6시간마다 바꿈 · 그 영지를 치면 조금 강해짐
  static const int rallyHours = 6;
  static const double rallyBonus = 0.10;

  /// 공성 망치 · 성벽 보수 게이지: 공성전 동안 길드원 걸음, 한 칸 = 한 사람 몫 × max(5, 인원)
  static const int gaugePerHead = 15000;
  static const int ramMax = 2;

  /// 공성 망치로 흔들린 자리: 상대가 이만큼 약해짐
  static const double ramWeak = 0.6;

  /// 흑등 연맹은 늘 영지 몇 곳을 쥠
  static const int npcMin = 3;

  /// 왕관의 무게: 왕성을 연속으로 가질수록 왕성 수비대 걸음 강화가 약해짐 (한 번마다)
  static const double crownDecay = 0.15;

  /// 엿보기 · 상성: 수비대 직업에 강한 직업 (내 주 직업이면 +25% · 받는 피해 −30%, 보조면 절반 — 레이드 약점과 같음)
  static const Map<String, List<JobId>> cloneWeakTo = {
    'cloneWarrior': [JobId.mage, JobId.archer],
    'cloneKnight': [JobId.mage, JobId.rogue],
    'cloneArcher': [JobId.knight, JobId.rogue],
    'cloneMage': [JobId.rogue, JobId.archer],
    'clonePriest': [JobId.warrior, JobId.rogue],
    'cloneRogue': [JobId.knight, JobId.warrior],
    'blackGuard': [JobId.mage, JobId.priest],
    'blackCaptain': [JobId.priest, JobId.knight],
  };

  /// 그림 (오기 전엔 아이콘)
  static const String rallyIcon = 'assets/images/icon_rallyFlag.webp';
  static const String ramIcon = 'assets/images/icon_siegeRam.webp';
  static const String repairIcon = 'assets/images/icon_wallRepair.webp';
  static const String finalSky = 'assets/images/bg_siegeFinal.webp';
  static const String resultScene = 'assets/images/scene_siegeResult.webp';

  /// 마지막 6시간 (일요일 18~24시)
  static const Duration finalHours = Duration(hours: 6);
  static bool siegeFinal(DateTime now) =>
      siegeActive(now) && !now.toUtc().isBefore(siegeEnd(siegeNo(now)).subtract(finalHours));

  /// 에르바르드 사냥 (여정 기력) · 내 길드 영지에서는 경험치 · 재료 조금 더
  static const int huntEnergy = 5;
  static const double ownedHuntBonus = 0.15;

  /// 수비대 한 자리 세기 배수 (숨김)
  static double guardMult(EstateInfo e, int slot) =>
      (e.royal ? royalMult : e.inner ? innerMult : 1.0) * (1 + slotStep * slot);

  /// 길드원 분신 그림 — 주 직업 그림 6장 (묶음 62: 지금 직업 20가지 기준, 예전 직업 이름은 예전 기록 대비)
  static MonsterId cloneOf(String? job) => switch (job) {
        'archer' || 'herbalist' || 'explorer' || 'ashHunter' => MonsterId.cloneArcher,
        'mage' || 'alchemist' || 'appraiser' || 'archaeologist' => MonsterId.cloneMage,
        'priest' || 'pilgrim' => MonsterId.clonePriest,
        'rogue' || 'merchant' || 'nightWalker' => MonsterId.cloneRogue,
        'knight' || 'tamer' || 'gateHeir' => MonsterId.cloneKnight,
        // 예전 직업 (#249 전 기록)
        'hunter' || 'pathfinder' => MonsterId.cloneArcher,
        'runesmith' || 'jeweler' || 'potionMerchant' => MonsterId.cloneMage,
        'healer' => MonsterId.clonePriest,
        'peddler' => MonsterId.cloneRogue,
        'beastKnight' => MonsterId.cloneKnight,
        _ => MonsterId.cloneWarrior, // 전사 · 대장장이 · 모험가 · 만물 장인 · 직업 없음 (예전 무기 장인)
      };

  /// 흑등 연맹 수비대: 1~4자리 용병, 5자리 · 왕성은 지휘관
  static MonsterId blackOf(EstateInfo e, int slot) =>
      e.royal || slot == slots - 1 ? MonsterId.blackCaptain : MonsterId.blackGuard;

  /// 야생 수비대 몬스터 (자리 5는 안쪽 몬스터)
  static MonsterId wildMonster(EstateInfo e, int slot) {
    if (e.royal) return blackOf(e, slot);
    final p = province(e.province!);
    return e.inner || slot == slots - 1 ? p.inner : p.outer;
  }

  static int garrisonBonusPct(int steps2w, int members) =>
      (math.min(garrisonStepMax, garrisonStepBonus * steps2w / math.max(1, members * garrisonStepsPer)) * 100).round();

  // ───────────── 이야기 (#247 세부 2, 대사 그대로)

  static const Act4Scene e1a = Act4Scene('e1a', '길드 회관', GuildRules.sceneHall, [
    ('lian', '저 너머에서 깃발 소리가 들렸죠? 가 봐요, 같이.'),
  ]);
  static const Act4Scene e1b = Act4Scene('e1b', '에르바르드', arriveImage, [
    ('barkan', '허허, 잊힌 왕국들의 땅일세. 주인 없는 성이 서른 곳이 넘지.'),
  ]);
  static const Act4Scene e1c = Act4Scene('e1c', '에르바르드 왕성', mapImage, [
    ('kaspar', '또 뵙는군요. 이번엔 땅으로 셈하지요. 왕성은 제가 먼저 샀습니다.'),
  ]);
  static const Act4Scene e2a = Act4Scene('e2a', '조합', GuildRules.sceneGuild, [
    ('sera', '성은 돌로 지키는 게 아니다. 사람으로 지킨다.'),
  ]);
  static const Act4Scene e2bSolo = Act4Scene('e2b', '에르바르드', mapImage, [
    ('lian', '이 땅은 비워 둬요. 대신 길을 열었으니, 다음 사람이 덜 헤맬 거예요.'),
  ], lianOnly: true);
  static const Act4Scene e3aWin = Act4Scene('e3a', '에르바르드 왕성', mapImage, [
    ('kaspar', '…셈은 길게 하는 법이지요. 다음 공성전에 다시 뵙겠습니다.'),
  ]);
  static const Act4Scene e3aLose = Act4Scene('e3a', '에르바르드 왕성', mapImage, [
    ('kaspar', '왕관은 아직 제 것이군요. 걸음이 더 필요하시겠습니다.'),
  ]);
  static const Act4Scene e3b = Act4Scene('e3b', '길드 회관', GuildRules.sceneHall, [
    ('lian', '다섯 등불도 함께 켰잖아요. 이 땅도 그렇게 될 거예요.'),
  ]);

  static const List<(int, String)> chapters = [
    (1, '다리 너머의 깃발'),
    (2, '빈 땅의 주인'),
    (3, '첫 공성전'),
  ];
  static String chapterTitle(int n) => chapters[(n - 1).clamp(0, 2)].$2;

  /// 2장: 1장 뒤 2만 보 + 빈 영지 야생 수비대 5자리
  static const int ch2Steps = 20000;

  /// 3장(혼자): 공성전 기간에 야생 수비대 3번
  static const int soloSiegeFights = 3;

  static const String erbardTeaser = '에르바르드의 이야기는 업데이트 때 한 편씩 이어져요';

  /// 오류 → 한 줄
  static String errorText(String code) => switch (code) {
        'login_required' => '공성전 · 영지는 로그인한 길드끼리예요. 혼자서도 빈 영지를 개척할 수 있어요',
        'no_guild' => '길드에 들어가야 영지를 가질 수 있어요',
        'no_ticket' => '공성권이 없어요. 2,000보마다 한 장 생겨요',
        'not_empty' => '이미 주인이 있는 영지예요. 공성전 때 빼앗을 수 있어요',
        'empty' => '빈 영지예요. 야생 수비대를 깨면 차지할 수 있어요',
        'not_siege' => '지금은 공성전 기간이 아니에요',
        'own' => '우리 길드 영지예요',
        'ally' => '연맹 길드의 영지예요',
        'full' => '길드는 영지를 세 곳까지 가질 수 있어요',
        'royal_locked' => '왕성은 영지를 두 곳 이상 가진 길드만 공성할 수 있어요',
        'broken' => '이미 깬 자리예요',
        'restricted' => '지금은 함께하는 기능을 쓸 수 없어요',
        'not_staff' || 'not_owner' => '길드장만 할 수 있어요',
        'siege_lock' => '공성전 중에는 수비대를 바꿀 수 없어요',
        'not_yours' => '우리 길드 영지에만 수비대를 세울 수 있어요',
        'alliance_full' => '연맹은 길드 세 곳까지예요',
        'alliance_locked' => '연맹은 공성전 네 번마다 다시 고를 수 있어요',
        'no_alliance' => '그 연맹을 찾지 못했어요',
        'no_fight' => '싸움을 처음부터 다시 시작해 주세요',
        'rally_wait' => '집결 깃발은 6시간마다 바꿀 수 있어요',
        'no_treasury' => '길드 금고 금화가 모자라요',
        'owned' => '이미 그 단계예요',
        'shared' => '이번 공성전 몫은 이미 나눠 줬어요',
        'no_users' => '이번 공성전에 공성권을 쓴 길드원이 없어요',
        'not_yet' => '공성전이 끝난 뒤에 나눠 줄 수 있어요',
        'bad_amount' => '그 금화로는 할 수 없어요',
        'app_check' => '앱을 최신으로 바꾼 뒤 다시 해 주세요',
        'offline' => '인터넷이 연결되지 않았어요',
        _ => '잠시 뒤 다시 해 주세요',
      };

  /// 서버 표 (영지 · 지방 · 숫자) — 서버 시험이 이 값과 같은지 봄
  static String estatesJson() {
    final b = StringBuffer('{\n "estates": [\n');
    for (final (i, e) in estates.indexed) {
      b.write('  {"id": "${e.id}", "name": "${e.name}", "province": ${e.province == null ? 'null' : '"${e.province!.name}"'}, '
          '"inner": ${e.inner}, "npcStart": ${e.npcStart}}${i == estates.length - 1 ? '' : ','}\n');
    }
    b.write(' ],\n');
    b.write(' "maxEstates": $maxEstates, "royalNeeds": $royalNeeds, "slots": $slots, "garrisonAllies": $garrisonAllies,\n');
    b.write(' "anchor": ${siegeAnchor.millisecondsSinceEpoch}, "period": ${siegePeriod.inMilliseconds}, "length": ${siegeLength.inMilliseconds},\n');
    b.write(' "allianceLock": $allianceLock, "allianceMax": $allianceMax,\n');
    b.write(' "garrisonStepsPer": $garrisonStepsPer, "garrisonStepBonus": $garrisonStepBonus, "garrisonStepMax": $garrisonStepMax,\n');
    b.write(' "wildClearSeals": $wildClearSeals, "siegeSealsPerEstate": $siegeSealsPerEstate, "siegeTicketSeals": $siegeTicketSeals, '
        '"siegeJoinSeals": $siegeJoinSeals, "royalWeight": $royalWeight,\n');
    b.write(' "ticketSteps": $ticketSteps, "ticketMax": $ticketMax, "minFightMs": $minFightMs,\n');
    b.write(' "boostCost": [${boostCost.join(', ')}], "boostMult": [${boostMult.join(', ')}],\n');
    b.write(' "shareMaxRate": $shareMaxRate, "sharePerHeadMax": $sharePerHeadMax, "hallTreasuryDayPoints": $hallTreasuryDayPoints,\n');
    b.write(' "treasuryShop": {${treasuryShop.entries.map((e) => '"${e.key}": ${e.value}').join(', ')}},\n');
    b.write(' "rallyHours": $rallyHours, "gaugePerHead": $gaugePerHead, "ramMax": $ramMax, "npcMin": $npcMin, "crownDecay": $crownDecay\n}\n');
    return b.toString();
  }

  /// 혹시 지방 재료 (에르바르드 사냥 보너스)
  static MaterialId provinceMat(Province p) => switch (p) {
        Province.light => MaterialId.stardust,
        Province.metal => MaterialId.metalCore,
        Province.earth => MaterialId.gemEarth,
        Province.dark => MaterialId.gemDark,
        Province.fire => MaterialId.fireCore,
      };
}
