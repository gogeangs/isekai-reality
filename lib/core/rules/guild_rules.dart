import 'equipment_rules.dart';
import 'job_rules.dart';
import 'materials.dart';
import 'monsters.dart';
import 'title_rules.dart';

/// 4막 「길드 창설」 (#246 · 묶음 59). 숫자는 숨은 값(처음 값), 화면엔 문장만.
/// 서버(firebase/functions/src/guild.js)와 같은 값은 그쪽이 판정한다.

/// 장면 한 장 (그림 · 말하는 이 · 대사)
class Act4Scene {
  const Act4Scene(this.id, this.place, this.image, this.lines, {this.lianOnly = false, this.giveCharter = false});

  final String id;

  /// 장소 글 (「마을 광장」 등)
  final String place;
  final String image;
  final List<(String, String)> lines;

  /// 혼자인 사람에게만 (리안의 길드 안내)
  final bool lianOnly;

  /// 이 장면을 보면 「길드 창설 증서」
  final bool giveCharter;
}

class Act4Chapter {
  const Act4Chapter(this.n, this.title, this.goal, this.scenes, {this.steps = 0, this.guildLevel = 0, this.afterGiant = false});

  final int n;
  final String title;

  /// 일지에 보이는 할 일 (숫자 없이)
  final String goal;
  final List<Act4Scene> scenes;

  /// 앞 장 뒤(2장) · 길드에서(3 · 4장) · 거인 뒤(5장) 걸어야 하는 걸음 (숨은 값)
  final int steps;
  final int guildLevel;
  final bool afterGiant;
}

/// 레이드 보스 하나
class RaidBossInfo {
  const RaidBossInfo(this.id, this.monster, this.special, this.specialText, this.weak, this.mat, this.title);

  /// 서버 이름 ('raidGiant' …)
  final String id;
  final MonsterId monster;

  /// 특별 공격 이름 · 설명 (숫자 없이)
  final String special;
  final String specialText;

  /// 약점 직업 둘 (주 직업이면 피해 더 · 특별 공격 덜, 보조면 절반)
  final List<JobId> weak;
  final MaterialId mat;
  final TitleId title;
}

/// 길드 상점 물건
enum GuildShopItem {
  lanternWeapon,
  lanternHead,
  lanternBody,
  lanternHands,
  lanternFeet,
  lanternAcc,
  decoPlaque,
  decoLights,
  decoFlowerbed,
  decoFountain,
  decoStatue,
  decoCampfire,
  decoSpring,
  decoSummer,
  decoAutumn,
  decoWinter,
  gold,
  manaStone,
  matBundle,
  recruit,
}

class GuildShopInfo {
  const GuildShopInfo(this.item, this.name, this.seals,
      {this.equip, this.mats = const {}, this.deco, this.minLevel = 2, this.perWeek = 0, this.icon});

  final GuildShopItem item;
  final String name;
  final int seals;
  final EquipBase? equip;
  final Map<MaterialId, int> mats;

  /// 회관 꾸미기 (서버 이름)
  final String? deco;

  /// 길드 레벨 (Lv.2 상점 · Lv.8 물건 늘어남)
  final int minLevel;

  /// 주마다 살 수 있는 개수 (0이면 제한 없음)
  final int perWeek;
  final String? icon;
}

abstract final class GuildRules {
  // ───────────── 4막 열림 · 장 흐름

  static const String sceneSquare = 'assets/images/village_bg.webp';
  static const String sceneMarket = 'assets/images/village_market.webp';
  static const String sceneTavern = 'assets/images/village_tavern.webp';
  static const String sceneGuild = 'assets/images/guild_hall.webp';
  static const String sceneLot = 'assets/images/village_guildhall_1.webp';
  static const String sceneMap = 'assets/images/scene_act3_fivelamps.webp';
  static const String sceneAlley = 'assets/images/village_tavern_2.webp';
  static const String sceneAlchemy = 'assets/images/village_alchemy.webp';
  static const String sceneHall = 'assets/images/bg_guildhall.webp';
  static const String sceneGiant = 'assets/images/monster_raidGiant.webp';
  static const String sceneOath = 'assets/images/village_guildhall_4.webp';

  static const List<Act4Chapter> chapters = [
    Act4Chapter(1, '상회의 모집', '카스파르의 흑등 길드 이야기를 들어요', [
      Act4Scene('c1a', '마을 광장', sceneSquare, [
        ('kaspar', '다섯 등불을 켜신 분이군요. 축하드립니다. 이제 그 빛, 값을 매길 차례지요.'),
        ('kaspar', '흑등 길드에 들어오시면 매주 금화를 드립니다. 걷기만 하시면 됩니다. 쉬운 셈이지요?'),
      ]),
      Act4Scene('c1b', '거래소', sceneMarket, [
        ('barkan', '허허… 카스파르 녀석이 금화를 뿌리고 다니는구먼.'),
        ('barkan', '그 녀석 셈엔 늘 빠진 줄이 하나 있네. 남의 몫 말일세. 금화에 발 묶이지 말게.'),
      ]),
    ]),
    Act4Chapter(2, '등불을 지키는 사람들', '걸으며 마을 사람들의 이야기를 기다려요', [
      Act4Scene('c2a', '주점', sceneTavern, [
        ('lian', '혼자 걷던 때가 길었어요. 그런데 다섯 등불은 결국 여럿이 켰잖아요.'),
        ('lian', '우리도 길드를 만들어요. 금화가 아니라, 등불을 같이 지키는 사람들로요.'),
      ], giveCharter: true),
      Act4Scene('c2b', '조합', sceneGuild, [
        ('sera', '길드를 세운다고? 좋다. 맹세는 가볍게 하는 게 아니다. 서로의 등을 지키겠다는 약속이니까.'),
      ]),
      Act4Scene('c2c', '마을 빈 터', sceneLot, [
        ('lian', '여기에 회관을 지어요. 처음엔 작아도 괜찮아요. 걸음이 모이면 커질 거예요.'),
        ('lian', '아직 함께할 사람이 없어도 괜찮아요. 제 길드에 먼저 들어와요. 자리는 늘 비워 둘게요.'),
      ]),
    ], steps: 30000),
    Act4Chapter(3, '흐려 가는 빛', '길드를 키우며 함께 걸어요', [
      Act4Scene('c3a', '지도', sceneMap, [
        ('pet', '저 등불… 어제보다 흐려. 누가 빛을 덜어 가고 있어.'),
      ]),
      Act4Scene('c3b', '주점 뒤 골목', sceneAlley, [
        ('nia', '흥, 내가 알려 주는 건 이번 한 번뿐이거든?'),
        ('nia', '흑등 길드 사람들이 밤마다 등불에서 빛을 떠 가. 병에 담아서 저쪽 장터에 비싸게 팔아.'),
      ]),
      Act4Scene('c3c', '연금술 공방', sceneAlchemy, [
        ('eliel', '빛을 병에 담는 법… 그건 제가 처음 만든 거예요. 진짜예요.'),
        ('eliel', '나누려고 만든 걸 팔고 있다니. 멈춰야 해요. 이번엔 제 손으로요.'),
      ]),
    ], steps: 50000, guildLevel: 2),
    Act4Chapter(4, '길드의 힘', '길드와 함께 빛을 먹는 거인을 쓰러뜨려요', [
      Act4Scene('c4a', '길드 회관', sceneHall, [
        ('lian', '병에 갇혔던 빛이 뭉쳐서 괴물이 됐대요. 빛을 먹는 거인이요.'),
        ('lian', '혼자서는 못 잡아요. 그래서 길드가 있는 거잖아요.'),
      ]),
    ], steps: 100000, guildLevel: 4),
    Act4Chapter(5, '등불의 맹세', '거인 뒤에도 함께 걸어요', [
      Act4Scene('c5a', '거래소 앞', sceneMarket, [
        ('kaspar', '제 셈이 틀렸군요. 금화로 묶은 사람은 금화가 떨어지면 떠나는데… 여러분은 걸음으로 묶여 있었어요.'),
      ]),
      Act4Scene('c5b', '거래소 앞', sceneMarket, [
        ('barkan', '놓아 주게. 장사꾼은 장부로 갚는 걸세.'),
        ('kaspar', '이번 빚은 기억해 두지요. 다음엔 땅 위에서 셈을 다시 맞춥시다. 길드와 길드로요.'),
      ]),
      Act4Scene('c5c', '길드 회관', sceneOath, [
        ('lian', '우리 길드의 첫 맹세예요. 빛은 팔지 않는다. 함께 지킨다.'),
      ]),
    ], steps: 150000, afterGiant: true),
  ];

  /// 거인을 쓰러뜨렸을 때 (4장 ②)
  static const Act4Scene giantDown = Act4Scene('c4b', '길드 회관', sceneHall, [
    ('dorgun', '…흩어진 빛은 내가 틀에 다시 담겠다. 다들 걸음이 무거웠겠군. 잘했다.'),
  ]);

  static const String act5Teaser = '저 너머 새 대륙에서 깃발 소리가 들려요';
  static const int oathSeals = 30;

  static Act4Chapter chapter(int n) => chapters[(n - 1).clamp(0, chapters.length - 1)];

  // ───────────── 길드 만들기 · 크기 (서버와 같음)

  static const int createGold = 1000;
  static const int lianName = 0;
  static const String lianGuildName = '리안의 길드';

  /// 길드 레벨마다 열리는 것 (화면에 문장으로)
  static const Map<int, String> levelUnlocks = {
    1: '길드 걸음 목표 · 20명',
    2: '길드 상점',
    3: '회관 ★2 · 22명',
    4: '길드 레이드',
    5: '함께 걸으면 여정 기력이 조금 더 · 24명',
    6: '회관 ★3 · 길드 칭호',
    7: '레이드 보상이 조금 더 · 26명',
    8: '상점 물건이 늘어나요',
    9: '깃발 꾸미기가 늘어나요 · 28명',
    10: '회관 ★4 · 30명 · 「전설의 길드」',
  };

  /// 회관 ★ (그림 village_guildhall_★)
  static const Map<int, String> stars = {
    1: '길드 게시판 — 길드원 걸음 순위 · 한마디',
    2: '길드 창고 — 길드원끼리 재료 나눠 주기',
    3: '길드 훈련소 — 길드원 모두 경험치가 조금 더',
    4: '길드 깃대 — 레이드 도전권이 하루 하나 더',
  };

  static String hallImage(int star) => 'assets/images/village_guildhall_${star.clamp(1, 4)}.webp';

  /// 기부: 금화 10당 · 재료 하나당 회관이 커지고, 모이면 등불 인장 (숨은 값, 서버와 같음)
  static const int donateGoldStep = 100;
  static const int shareDayLimit = 10;

  /// 길드 Lv.5: 여정 기력 조금 더 · ★3 훈련소: 경험치 조금 더 (숨은 값)
  static const double lv5Energy = 0.10;
  static const double trainingExp = 0.05;

  // ───────────── 레이드

  static const int fightTicks = 40;
  static const RaidBossInfo giant = RaidBossInfo('raidGiant', MonsterId.raidGiant, '빛 삼키기',
      '몇 턴마다 내 좋은 효과를 먹고 체력을 채워요', [JobId.priest, JobId.mage], MaterialId.giantLight, TitleId.raidGiant);
  static const List<RaidBossInfo> raids = [
    RaidBossInfo('raidDragon', MonsterId.raidDragon, '불바다', '몇 턴마다 큰 불 피해와 화상을 줘요',
        [JobId.knight, JobId.archer], MaterialId.ancientScale, TitleId.raidDragon),
    RaidBossInfo('raidLich', MonsterId.raidLich, '망자의 방패', '해골 병사를 불러 몇 턴 동안 보호막을 쳐요',
        [JobId.priest, JobId.rogue], MaterialId.lichRelic, TitleId.raidLich),
    RaidBossInfo('raidTortoise', MonsterId.raidTortoise, '등껍질 숨기', '몇 턴 숨어 피해를 크게 줄이고, 나오면 크게 들이받아요',
        [JobId.warrior, JobId.mage], MaterialId.tortoiseShell, TitleId.raidTortoise),
  ];

  static RaidBossInfo? boss(String id) => [giant, ...raids].where((b) => b.id == id).firstOrNull;

  /// 약점 직업 (숨은 값): 주 직업이면 피해 +25% · 특별 공격 피해 −30%, 보조면 절반
  static const double weakDeal = 0.25;
  static const double weakTaken = 0.30;

  /// 특별 공격 간격(턴)
  static const int specialEvery = 4;

  /// 리안의 길드 레이드: 가상 길드원이 내 한 판마다 함께 넣는 피해(내 피해 × 배수) · 보스 체력(한 판 몫 × 배수)
  static const double lianHelpers = 2.0;
  static const int lianGiantFights = 8;
  static const int lianRaidFights = 10;

  /// 리안의 길드 레이드 도전권: 3,000보마다 1장 · 하루 3장 (서버와 같음)
  static const int raidTicketSteps = 3000;
  static const int raidTicketsPerDay = 3;

  /// 레이드 보상 (서버와 같음, 리안의 길드는 앱이)
  static const int raidWinSeals = 40;
  static const int raidWinMats = 2;

  /// 주간 걸음 목표 등불 인장 (리안의 길드: 한 사람 몫만)
  static const List<int> weekSteps = [20000, 50000, 80000];
  static const List<int> weekSeals = [10, 20, 30];

  // ───────────── 회관 꾸미기 (서버 이름 ↔ 그림)

  static const List<String> decos = [
    'plaque', 'lights', 'flowerbed', 'fountain', 'statue', 'campfire', 'spring', 'summer', 'autumn', 'winter',
  ];
  static const Map<String, String> decoNames = {
    'flag': '길드 깃발',
    'plaque': '길드 현판',
    'lights': '등불 줄',
    'flowerbed': '화단',
    'fountain': '작은 분수',
    'statue': '펫 조각상',
    'campfire': '모닥불 자리',
    'spring': '봄 벚꽃',
    'summer': '여름 풍경',
    'autumn': '가을 낙엽',
    'winter': '겨울 눈사람',
    'goldLights': '금빛 등불 줄',
    'goldFountain': '금빛 분수',
  };
  /// 그림 이름 (서버 이름과 다른 셋은 들어온 그림 이름으로)
  static String decoImage(String id) => 'assets/images/deco_${const {
        'plaque': 'nameplate',
        'lights': 'lanternString',
        'statue': 'petStatue',
        'goldLights': 'lanternString',
        'goldFountain': 'fountain',
      }[id] ?? id}.webp';

  /// 묶음 61: 금고 상점 꾸미기 (있는 그림을 금빛으로)
  static bool goldDeco(String id) => id.startsWith('gold');

  /// 금고 상점 (금고 금화로만, 길드장 · 부길드장)
  static const Map<String, String> treasuryShopNames = {
    'goldLights': '금빛 등불 줄',
    'goldFountain': '금빛 분수',
    'goldFlag': '금빛 깃발 문양',
  };
  static const Map<String, String> treasuryShopLines = {
    'goldLights': '회관 앞에 금빛으로 빛나는 등불 줄',
    'goldFountain': '금빛 물이 흐르는 회관 분수',
    'goldFlag': '길드 깃발 문양이 금빛으로 (길드 화면 · 회관)',
  };

  /// 회관 그림 위 꾸미기 자리 4곳 (그림 비율: 가로 · 세로)
  static const List<(double, double)> decoSpots = [(0.16, 0.78), (0.38, 0.86), (0.62, 0.86), (0.84, 0.78)];

  // ───────────── 길드 상점 (등불 인장)

  static const List<GuildShopInfo> shop = [
    GuildShopInfo(GuildShopItem.lanternWeapon, '등불 수호단 장검', 120,
        equip: EquipBase.lanternWeapon, mats: {MaterialId.ancientScale: 2, MaterialId.giantLight: 1}),
    GuildShopInfo(GuildShopItem.lanternHead, '등불 수호단 투구', 90,
        equip: EquipBase.lanternHead, mats: {MaterialId.lichRelic: 2}),
    GuildShopInfo(GuildShopItem.lanternBody, '등불 수호단 갑옷', 120,
        equip: EquipBase.lanternBody, mats: {MaterialId.tortoiseShell: 2, MaterialId.giantLight: 1}),
    GuildShopInfo(GuildShopItem.lanternHands, '등불 수호단 장갑', 80,
        equip: EquipBase.lanternHands, mats: {MaterialId.ancientScale: 1, MaterialId.lichRelic: 1}),
    GuildShopInfo(GuildShopItem.lanternFeet, '등불 수호단 장화', 80,
        equip: EquipBase.lanternFeet, mats: {MaterialId.tortoiseShell: 1, MaterialId.lichRelic: 1}),
    GuildShopInfo(GuildShopItem.lanternAcc, '등불 수호단 등불', 100,
        equip: EquipBase.lanternAcc, mats: {MaterialId.giantLight: 2}),
    GuildShopInfo(GuildShopItem.decoPlaque, '길드 현판', 30, deco: 'plaque'),
    GuildShopInfo(GuildShopItem.decoLights, '등불 줄', 30, deco: 'lights'),
    GuildShopInfo(GuildShopItem.decoFlowerbed, '화단', 30, deco: 'flowerbed'),
    GuildShopInfo(GuildShopItem.decoFountain, '작은 분수', 50, deco: 'fountain'),
    GuildShopInfo(GuildShopItem.decoStatue, '펫 조각상', 50, deco: 'statue'),
    GuildShopInfo(GuildShopItem.decoCampfire, '모닥불 자리', 40, deco: 'campfire'),
    GuildShopInfo(GuildShopItem.decoSpring, '봄 벚꽃', 40, deco: 'spring', minLevel: 8),
    GuildShopInfo(GuildShopItem.decoSummer, '여름 풍경', 40, deco: 'summer', minLevel: 8),
    GuildShopInfo(GuildShopItem.decoAutumn, '가을 낙엽', 40, deco: 'autumn', minLevel: 8),
    GuildShopInfo(GuildShopItem.decoWinter, '겨울 눈사람', 40, deco: 'winter', minLevel: 8),
    GuildShopInfo(GuildShopItem.gold, '금화 500', 15, icon: 'assets/images/icon_gold.webp'),
    GuildShopInfo(GuildShopItem.manaStone, '마석 10', 15, icon: 'assets/images/icon_crystal.webp'),
    GuildShopInfo(GuildShopItem.matBundle, '재료 꾸러미', 20, minLevel: 8),
    GuildShopInfo(GuildShopItem.recruit, '모집권', 40, perWeek: 2),
  ];

  static GuildShopInfo shopInfo(GuildShopItem i) => shop.firstWhere((x) => x.item == i);

  // ───────────── 「등불 수호단」 세트 (숨은 값)

  static const double set2Steps = 0.10; // 길드 걸음 목표에 내 걸음이 조금 더
  static const double set4Raid = 0.15; // 레이드 피해 더
  static const double set6Burst = 0.12; // 공격하면 가끔 등불 빛이 터짐
  static const double set6BurstMult = 2.0; // 잿빛 몬스터에게 큰 피해

  static EquipBaseInfo _g(EquipBase id, String name, EquipSlot slot,
          {double attack = 0, double reduce = 0, double maxHp = 0, double crit = 0}) =>
      EquipBaseInfo(
          id: id,
          name: name,
          slot: slot,
          recipe: const {},
          attack: attack,
          reduce: reduce,
          maxHp: maxHp,
          crit: crit,
          asset: 'equip_${id.name}');

  static final List<EquipBaseInfo> gearInfos = [
    _g(EquipBase.lanternWeapon, '등불 수호단 장검', EquipSlot.weapon, attack: 0.24),
    _g(EquipBase.lanternHead, '등불 수호단 투구', EquipSlot.head, reduce: 0.06),
    _g(EquipBase.lanternBody, '등불 수호단 갑옷', EquipSlot.body, reduce: 0.11),
    _g(EquipBase.lanternHands, '등불 수호단 장갑', EquipSlot.hands, reduce: 0.05, crit: 0.02),
    _g(EquipBase.lanternFeet, '등불 수호단 장화', EquipSlot.feet, reduce: 0.05),
    _g(EquipBase.lanternAcc, '등불 수호단 등불', EquipSlot.accessory, maxHp: 0.14),
  ];

  static const Set<EquipBase> lanternSet = {
    EquipBase.lanternWeapon,
    EquipBase.lanternHead,
    EquipBase.lanternBody,
    EquipBase.lanternHands,
    EquipBase.lanternFeet,
    EquipBase.lanternAcc,
  };

  static const String sealImage = 'assets/images/item_lanternSeal.webp';
  static const String charterImage = 'assets/images/item_guildCharter.webp';

  /// 오류 → 한 줄
  static String errorText(String code) => switch (code) {
        'login_required' => '길드는 로그인한 각성자끼리예요. 리안의 길드는 로그인 없이도 함께해요',
        'already_in_guild' => '이미 길드에 들어 있어요',
        'no_guild' => '그 길드를 찾지 못했어요',
        'full' => '길드 자리가 가득 찼어요',
        'same_device' => '같은 휴대폰으로 로그인한 계정끼리는 같은 길드에 들 수 없어요',
        'restricted' => '지금은 함께하는 기능을 쓸 수 없어요',
        'banned_word' => '쓸 수 없는 말이 들어 있어요',
        'bad_name' => '길드 이름은 2~12자로 지어 주세요',
        'not_staff' || 'not_owner' => '길드장 · 부길드장만 할 수 있어요',
        'vices_full' => '부길드장은 두 명까지예요',
        'donate_limit' => '오늘은 더 기부할 수 없어요. 내일 다시 해 주세요',
        'share_limit' => '오늘은 더 나눠 줄 수 없어요',
        'need_star' => '회관이 더 커지면 열려요',
        'need_level' => '길드 레벨이 더 오르면 열려요',
        'no_ticket' => '도전권이 없어요. 걸으면 생겨요',
        'defeated' => '이미 쓰러뜨린 보스예요',
        'claimed' => '이미 받았어요',
        'not_yet' => '아직 받을 수 없어요',
        'no_damage' => '이번 레이드에 피해를 준 사람만 받아요',
        'offline' => '인터넷이 연결되지 않았어요',
        'no_gold' => '금화가 모자라요',
        'no_charter' => '길드 창설 증서가 있어야 해요. 리안에게 받아요',
        'no_wallet_gold' => '거래 지갑 금화가 모자라요. 거래소에서 바르칸에게 맡겨 주세요',
        'no_treasury' => '길드 금고 금화가 모자라요',
        'not_yours' => '우리 길드 영지가 아니에요',
        'siege_lock' => '공성전 중에는 바꿀 수 없어요',
        'owned' => '이미 있어요',
        'shared' => '이번 공성전 몫은 이미 나눠 줬어요',
        'no_users' => '이번 공성전에 공성권을 쓴 길드원이 없어요',
        'bad_amount' => '그 금화로는 할 수 없어요',
        'app_check' => '앱을 최신으로 바꾼 뒤 다시 해 주세요',
        _ => '잠시 뒤 다시 해 주세요',
      };
}
