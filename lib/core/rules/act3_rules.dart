import 'dart:math' as math;

import 'element_rules.dart';
import 'equipment_rules.dart';
import 'monsters.dart';
import 'rule_constants.dart';
import 'battle_rules.dart';

/// 3막 다리 너머 탐험 (묶음 52 #243): 틀 — 열리는 때 · 걸음(다음 지역 길 · 여정 기력) · 지역 ·
/// 동료(이야기 동료 · 이름 없는 동료 · 모집권) · 지역 1 필드 사냥과 전리품.
/// 숫자는 개발이 정한 숨은 값(처음 값, 테스트로 조정). 화면엔 문장만 — 동료 능력치만 숫자로 보여 줌.

// ───────────── 지역 · 장소

enum Region { baldrin, selenia, elowin, morval, aurel }

enum SpotKind { town, field, dungeon, hidden }

class PlaceInfo {
  const PlaceInfo(this.id, this.name, this.kind, this.x, this.y,
      {this.monster, this.background});

  final String id;
  final String name;
  final SpotKind kind;

  /// 지역 지도 그림 위 자리 (가로 · 세로 비율)
  final double x, y;

  /// 필드에서 만나는 몬스터
  final MonsterId? monster;

  /// 싸울 때 배경 (그림이 오기 전엔 임시)
  final String? background;
}

class RegionInfo {
  const RegionInfo({
    required this.id,
    required this.name,
    required this.level,
    required this.element,
    required this.blurb,
    this.places = const [],
  });

  final Region id;
  final String name;

  /// 들어갈 수 있는 레벨
  final int level;
  final Element element;

  /// 세계 지도 한 줄
  final String blurb;
  final List<PlaceInfo> places;

  String get map => 'assets/images/map_region_${id.name}.webp';
}

// ───────────── 동료

enum AllyRace { elf, dwarf, fairy, dragonkin, catfolk, foxfolk, merfolk, starchild }

enum AllyJob { warrior, archer, mage, priest, rogue, knight }

/// 이야기 동료 (이번 묶음: 리안 · 가렌. 나머지는 그 지역 묶음에서)
enum StoryAlly { lian, garen }

/// 동료 스킬이 하는 일 (숨은 규칙, 화면엔 문장만)
enum AllySkillKind {
  hit, // 큰 피해
  hits, // 여러 번
  crit, // 꼭 치명타
  stun, // 피해 + 적 한 턴 멈춤
  partyAtk, // 몇 턴 아군 공격 세짐
  partyDef, // 몇 턴 아군 받는 피해 줄어듦
  partyNext, // 아군 모두 다음 공격 세짐
  lamp, // 몇 턴 빗나가지 않음 + 잿빛·어둠에 피해 더
  partyCount, // 함께한 수만큼 연달아
  rally, // 공격·방어 크게 + 강타 바로 참
  selfAtk, // 몇 턴 자기 공격 세짐
  lowHp, // 체력이 낮을수록 아주 큰 피해
  fullHp, // 적이 다치지 않았으면 아주 큰 피해
  element, // 속성 피해
  weak, // 약점이면 큰 피해
  barrier, // 다음 공격 한 번 막음
  healOne, // 아군 하나 회복
  healAll, // 아군 모두 회복
  regen, // 몇 턴 아군 모두 조금씩 회복
  cleanse, // 나쁜 효과 지움
  miracle, // 아군 모두 크게 회복 + 쓰러진 동료 일으킴
  steal, // 피해 조금 + 이기면 전리품 하나 더
  poison, // 몇 턴 독
  breakDef, // 피해 + 적 방어 약해짐
  taunt, // 몇 턴 대신 맞음
  guardSelf, // 몇 턴 자기 받는 피해 크게 줄어듦
  oath, // 아군 모두 보호막 + 몇 턴 반격
}

class AllySkillInfo {
  const AllySkillInfo(this.name, this.text, this.kind,
      {this.power = 1, this.hits = 1, this.turns = 3});

  final String name;

  /// 화면 문장 (숫자 없이)
  final String text;
  final AllySkillKind kind;

  /// 피해·회복 배율 (숨김)
  final double power;
  final int hits;
  final int turns;
}

class AllyTraitInfo {
  const AllyTraitInfo(this.id, this.name,
      {this.attack = 0, this.hp = 0, this.crit = 0, this.charge = 0, this.heal = 0,
      this.ash = 0, this.element});

  final String id;
  final String name;

  /// 숨은 효과 (배율 더하기)
  final double attack, hp, crit, heal, ash;

  /// 스킬이 이만큼 빨리 참 (틱)
  final int charge;

  /// 그 속성 피해 더 (「불을 잘 다룸」)
  final Element? element;
}

class Act3Rules {
  Act3Rules._();

  // ───────────── 열리는 때

  /// Lv.21 + 본체를 쓰러뜨린 뒤 (결말 뒤 만남을 지난 계정)
  static const int openLevel = 21;

  /// 처음 다리를 건널 때 장면 (첫 펫 · 리안 · 가렌). (말하는 이: 'lian' · 'garen' · 'pet', 대사)
  static const String bridgeImage = 'assets/images/ending_04_bridge.webp';
  static const List<(String, String)> bridgeScene = [
    ('lian', '준비됐어요? 저는 저쪽에서 건너온 사람이라, 이쪽에서 건너가는 건 처음이에요.'),
    ('garen', '테오 녀석이 저 너머 어딘가에 있다! 지팡이를 짚어도 앞장은 내가 선다!'),
    ('pet', '다리 끝에 커다란 등불이 꺼져 있어… 저게 저쪽 세계의 등불일까?'),
    ('lian', '가요. 이번엔 셋이서요.'),
  ];

  // ───────────── 걸음: 다음 지역 길 · 여정 기력

  /// 다음 지역으로 가는 길 (3막이 열린 뒤 걸은 걸음)
  static const int roadSteps = 50000;

  /// 여정 기력 (원정 기력과 따로)
  static const int energyMax = 100;
  static const int energyPerStep = 10; // 1,000보마다
  static const int energyStepUnit = 1000;
  static const int energyField = 5; // 필드 사냥 1번
  static const int energyFloor = 10; // 던전 한 층

  /// 모집권: 5,000보마다 1장 (하루 2장까지) · 광고 하루 1장 · 던전 끝 1 · 서브 1 · 등불 5
  static const int ticketSteps = 5000;
  static const int ticketStepsPerDay = 2;
  static const int ticketLamp = 5;

  /// 처음 3막이 열릴 때 리안이 건네는 모집권 (첫 모험가를 바로 만나 보게)
  static const int ticketStarter = 1;

  // ───────────── 지역 5곳 (지역 1만 이번 묶음에서 장소가 있음)

  static const List<RegionInfo> regions = [
    RegionInfo(
      id: Region.baldrin,
      name: '발드린 관문',
      level: 21,
      element: Element.light,
      blurb: '다리 끝 무너진 문지기 초소',
      places: [
        PlaceInfo('baldrin_town', '피난민 야영지', SpotKind.town, 0.48, 0.60),
        PlaceInfo('baldrin_ashplain', '잿빛 들판', SpotKind.field, 0.17, 0.50,
            monster: MonsterId.goblinRaider,
            background: 'assets/images/bg_field_mountain.webp'),
        PlaceInfo('baldrin_wallroad', '무너진 성벽길', SpotKind.field, 0.80, 0.48,
            monster: MonsterId.skeletonGuard,
            background: 'assets/images/bg_gate.webp'),
        PlaceInfo('baldrin_wolfhill', '은빛 늑대의 언덕', SpotKind.field, 0.14, 0.16,
            monster: MonsterId.harpy,
            background: 'assets/images/bg_field_forest.webp'),
        PlaceInfo('baldrin_fort', '문지기 지하 요새', SpotKind.dungeon, 0.56, 0.17),
        PlaceInfo('baldrin_windden', '???', SpotKind.hidden, 0.89, 0.16),
      ],
    ),
    RegionInfo(
        id: Region.selenia, name: '셀레니아 대장터', level: 23, element: Element.metal,
        blurb: '불 꺼진 큰 장터'),
    RegionInfo(
        id: Region.elowin, name: '엘로윈 숲', level: 25, element: Element.earth,
        blurb: '잠든 고목의 숲'),
    RegionInfo(
        id: Region.morval, name: '모르발 왕도', level: 27, element: Element.dark,
        blurb: '다시 일어서는 왕도'),
    RegionInfo(
        id: Region.aurel, name: '아우렐 성소', level: 29, element: Element.fire,
        blurb: '모든 등불의 불이 시작된 곳'),
  ];

  static RegionInfo region(Region r) => regions[r.index];

  static PlaceInfo? place(String id) {
    for (final r in regions) {
      for (final p in r.places) {
        if (p.id == id) return p;
      }
    }
    return null;
  }

  /// 임시 배경 (그림이 오면 같은 이름으로 바꿔 끼움)
  static const String fallbackBackground = 'assets/images/bg_boss_warden.webp';

  /// 메인 퀘스트 (지역 1, 이번 묶음은 ①만 — 나머지는 지역 1 묶음에서)
  static const String mainFirstFight = '잿빛 들판에서 첫 싸움';
  static const String mainFirstFightText = '다리를 건너 잿빛 들판에서 저쪽 세계의 몬스터와 처음 싸워요.';

  // ───────────── 필드 몬스터 (지역 1, 정통 판타지)

  /// 그 레벨 필드 몬스터 대비 (동료 둘이 함께 싸우니 조금 세게)
  static const double fieldHp = 1.8;
  static const double fieldAttack = 1.3;

  static Foe fieldFoe(MonsterId m, int level) {
    final b = BattleRules.fieldFoe(level: math.max(level, openLevel), monster: m);
    return Foe(
      monster: m,
      maxHp: math.max(1, (b.maxHp * fieldHp).round()),
      attack: math.max(1, (b.attack * fieldAttack).round()),
      defense: b.defense,
      speed: b.speed,
    );
  }

  /// 필드 사냥 보상 (경험치 · 금화 · 장비): 경험치는 필드 몬스터 한 마리의 2배
  static const int fieldExp = RuleConstants.fieldMonsterExp * 2;
  static const int fieldGoldMin = 12;
  static const int fieldGoldMax = 28;

  /// 「발드린 문지기」 장비가 떨어질 확률
  static const double gearDrop = 0.25;

  /// 동료가 받는 경험치 (한 판)
  static const int allyExpField = 12;

  static int allyExpToNext(int level) => 40 + level * 4;

  // ───────────── 동료 능력치 (숫자로 보여 줌)

  /// 이야기 동료 기준 능력치 (힘 · 체력 · 민첩 · 지능)
  static const int baseStat = 12;

  /// 이름 없는 동료 폭: 대부분 70~100%, 아주 가끔 100~110%
  static const double rollMin = 0.70;
  static const double rollHigh = 1.10;
  static const double highChance = 0.03;

  /// 특성 2개가 붙을 확률 (나머지는 1개)
  static const double twoTraits = 0.30;

  /// 동료 공격·체력 (그 레벨 기준 각성자 대비, 능력치 12일 때)
  static const double allyAttack = 0.45;
  static const double allyHp = 0.70;

  /// 동료 스킬이 차는 틱
  static const int allyCharge = 7;

  /// 동료를 노리는 확률 (나머지는 각성자)
  static const double foeTargetsAlly = 0.35;

  /// 보유 한도 (이름 없는 동료): 처음 4 · 리안과 친해질 때마다 +1 (최대 +3)
  static const int rosterBase = 4;

  /// 내보낼 때 금화
  static const int releaseGold = 30;

  /// 스킬 포인트: 합류 뒤 동료 레벨 2마다 1 · ②·③ 1씩 · ④ 2
  static const int levelsPerPoint = 2;

  static int skillCost(int slot) => slot == 3 ? 2 : slot == 0 ? 0 : 1;

  // ───────────── 이야기 동료

  static ({String name, String image, String face, AllyJob role, String roleName, Element? element,
          List<int> stats, List<AllySkillInfo> skills}) story(StoryAlly a) =>
      switch (a) {
        StoryAlly.lian => (
            name: '리안',
            image: 'assets/images/ally_lian.webp',
            face: 'assets/images/npc_lian.webp',
            role: AllyJob.warrior,
            roleName: '검 · 균형',
            element: null,
            stats: const [12, 12, 12, 12],
            skills: const [
              AllySkillInfo('각성자의 일격', '큰 피해를 줘요', AllySkillKind.hit, power: 3.0),
              AllySkillInfo('함께 걷는 발걸음', '아군 모두 다음 공격이 세져요', AllySkillKind.partyNext,
                  power: 1.6),
              AllySkillInfo('등불 들기', '잠시 빗나가지 않고, 잿빛·어둠 몬스터에게 피해가 더 들어가요',
                  AllySkillKind.lamp, power: 1.3),
              AllySkillInfo('혼자가 아닌 검', '함께한 동료 수만큼 연달아 베어요',
                  AllySkillKind.partyCount, power: 1.4),
            ],
          ),
        StoryAlly.garen => (
            name: '가렌',
            image: 'assets/images/ally_garen.webp',
            face: 'assets/images/npc_garen.webp',
            role: AllyJob.knight,
            roleName: '지휘',
            element: null,
            stats: const [11, 14, 9, 12],
            skills: const [
              AllySkillInfo('교관의 호령', '잠시 아군 공격이 세져요', AllySkillKind.partyAtk,
                  power: 1.3),
              AllySkillInfo('자세 교정', '잠시 아군이 받는 피해가 줄어요', AllySkillKind.partyDef,
                  power: 0.7),
              AllySkillInfo('지팡이 후려치기', '피해를 주고 적을 한 턴 멈춰요', AllySkillKind.stun,
                  power: 1.6),
              AllySkillInfo('신병 다섯의 함성', '아군 모두 공격·방어가 크게 오르고 강타가 바로 차요',
                  AllySkillKind.rally, power: 1.5),
            ],
          ),
      };

  /// 가렌 스킬 ④는 동료 퀘스트 「신병 다섯의 명부」로 열림 (지역 1 묶음)
  static bool lockedByQuest(StoryAlly a, int slot) => a == StoryAlly.garen && slot == 3;

  /// 직업에 잘 맞는 무기 (묶음 53 확정: 전사 검·도끼 / 궁수 활 / 마법사·사제 지팡이 / 도적 단검 / 기사 검·창).
  /// 활은 아직 활 장비가 없어 지역 5 「여명의 불꽃 활」 때 더함
  static const Map<AllyJob, Set<String>> jobWeapons = {
    AllyJob.warrior: {'sword', 'axe'},
    AllyJob.archer: {'bow'},
    AllyJob.mage: {'staff'},
    AllyJob.priest: {'staff'},
    AllyJob.rogue: {'dagger'},
    AllyJob.knight: {'sword', 'spear'},
  };

  /// 잘 맞는 무기를 들면 공격 + (숨김)
  static const double fitBonus = 0.10;

  // ───────────── 이름 없는 동료 (모험가 · 용병)

  static const Map<AllyRace, String> raceNames = {
    AllyRace.elf: '엘프',
    AllyRace.dwarf: '드워프',
    AllyRace.fairy: '요정',
    AllyRace.dragonkin: '용인',
    AllyRace.catfolk: '고양이 수인',
    AllyRace.foxfolk: '여우 수인',
    AllyRace.merfolk: '인어',
    AllyRace.starchild: '별의 아이',
  };

  static const Map<AllyJob, String> jobNames = {
    AllyJob.warrior: '전사',
    AllyJob.archer: '궁수',
    AllyJob.mage: '마법사',
    AllyJob.priest: '사제',
    AllyJob.rogue: '도적',
    AllyJob.knight: '기사',
  };

  /// 마법사 속성은 종족에 따라
  static const Map<AllyRace, Element> mageElement = {
    AllyRace.elf: Element.wind,
    AllyRace.dwarf: Element.earth,
    AllyRace.fairy: Element.light,
    AllyRace.dragonkin: Element.fire,
    AllyRace.catfolk: Element.dark,
    AllyRace.foxfolk: Element.thunder,
    AllyRace.merfolk: Element.water,
    AllyRace.starchild: Element.ice,
  };

  /// 종족이 조금 더 잘하는 능력치 (힘 · 체력 · 민첩 · 지능 중 하나에 +10%)
  static const Map<AllyRace, int> raceStat = {
    AllyRace.elf: 2,
    AllyRace.dwarf: 1,
    AllyRace.fairy: 3,
    AllyRace.dragonkin: 0,
    AllyRace.catfolk: 2,
    AllyRace.foxfolk: 3,
    AllyRace.merfolk: 1,
    AllyRace.starchild: 3,
  };

  /// 직업 스킬 4칸 (직업마다 같고 특성이 차이를 만듦)
  static List<AllySkillInfo> jobSkills(AllyJob j) => switch (j) {
        AllyJob.warrior => const [
            AllySkillInfo('내려베기', '큰 피해를 줘요', AllySkillKind.hit, power: 2.8),
            AllySkillInfo('함성', '잠시 자기 공격이 세져요', AllySkillKind.selfAtk, power: 1.5),
            AllySkillInfo('휩쓸기', '크게 휩쓸어 베어요', AllySkillKind.hit, power: 2.4),
            AllySkillInfo('결사의 일격', '체력이 낮을수록 아주 큰 피해를 줘요', AllySkillKind.lowHp,
                power: 2.5),
          ],
        AllyJob.archer => const [
            AllySkillInfo('조준 사격', '꼭 치명타로 맞혀요', AllySkillKind.crit, power: 1.6),
            AllySkillInfo('속사', '빠르게 두 번 쏴요', AllySkillKind.hits, power: 1.3, hits: 2),
            AllySkillInfo('덫 화살', '적을 한 턴 멈춰요', AllySkillKind.stun, power: 1.0),
            AllySkillInfo('별똥별 화살', '다치지 않은 적에게 아주 큰 피해를 줘요', AllySkillKind.fullHp,
                power: 4.0),
          ],
        AllyJob.mage => const [
            AllySkillInfo('속성 화살', '속성 피해를 줘요', AllySkillKind.element, power: 2.2),
            AllySkillInfo('마력 보호막', '다음 공격 한 번을 막아요', AllySkillKind.barrier),
            AllySkillInfo('약점 꿰뚫기', '그 속성에 약한 적에게 큰 피해를 줘요', AllySkillKind.weak,
                power: 3.5),
            AllySkillInfo('대마법', '큰 속성 피해를 줘요', AllySkillKind.element, power: 3.6),
          ],
        AllyJob.priest => const [
            AllySkillInfo('치유', '아군 하나를 회복해요', AllySkillKind.healOne, power: 0.30),
            AllySkillInfo('축복', '잠시 아군 모두 받는 피해가 줄어요', AllySkillKind.partyDef,
                power: 0.7),
            AllySkillInfo('정화', '나쁜 효과를 지워요', AllySkillKind.cleanse),
            AllySkillInfo('기적', '아군 모두 크게 회복하고 쓰러진 동료를 한 번 일으켜요',
                AllySkillKind.miracle, power: 0.40),
          ],
        AllyJob.rogue => const [
            AllySkillInfo('기습', '연달아 두 번 찔러요', AllySkillKind.hits, power: 1.3, hits: 2),
            AllySkillInfo('훔치기', '이기면 전리품이 하나 더 나와요', AllySkillKind.steal, power: 1.0),
            AllySkillInfo('독 바르기', '잠시 독이 퍼져요', AllySkillKind.poison, power: 0.04),
            AllySkillInfo('그림자 연격', '빠르게 다섯 번 베어요', AllySkillKind.hits, power: 0.8, hits: 5),
          ],
        AllyJob.knight => const [
            AllySkillInfo('방패 치기', '피해를 주고 적을 잠시 약하게 해요', AllySkillKind.breakDef,
                power: 1.5),
            AllySkillInfo('수호', '잠시 대신 맞아요', AllySkillKind.taunt),
            AllySkillInfo('굳건한 자세', '잠시 받는 피해가 크게 줄어요', AllySkillKind.guardSelf,
                power: 0.4),
            AllySkillInfo('성기사의 맹세', '아군 모두 보호막을 두르고 잠시 되받아쳐요', AllySkillKind.oath),
          ],
      };

  /// 직업 임시 그림 자리 (그림이 오기 전 아이콘 색, ARGB)
  static const Map<AllyJob, int> jobColor = {
    AllyJob.warrior: 0xFFE06B4F,
    AllyJob.archer: 0xFF6FBF5A,
    AllyJob.mage: 0xFF7E7BF2,
    AllyJob.priest: 0xFFF2D27E,
    AllyJob.rogue: 0xFF8A8FA8,
    AllyJob.knight: 0xFF5FA8E8,
  };

  /// 특성 (1~2개)
  static const List<AllyTraitInfo> traits = [
    AllyTraitInfo('fire', '불을 잘 다룸', attack: 0.15, element: Element.fire),
    AllyTraitInfo('water', '물을 잘 다룸', attack: 0.15, element: Element.water),
    AllyTraitInfo('light', '빛을 잘 다룸', attack: 0.15, element: Element.light),
    AllyTraitInfo('sturdy', '튼튼함', hp: 0.12),
    AllyTraitInfo('strong', '힘이 셈', attack: 0.08),
    AllyTraitInfo('lucky', '운이 좋음', crit: 0.08),
    AllyTraitInfo('quick', '손이 빠름', charge: 1),
    AllyTraitInfo('healer', '치유의 손', heal: 0.25),
    AllyTraitInfo('ashHunter', '잿빛 사냥꾼', ash: 0.15),
    AllyTraitInfo('brave', '겁이 없음', attack: 0.05, hp: 0.05),
  ];

  static AllyTraitInfo? trait(String id) {
    for (final t in traits) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// 무작위 이름 (바꿀 수 있음)
  static const List<String> names = [
    '라엘', '도린', '미르샤', '케인', '실바', '토르', '엘리나', '바스', '루카', '세린',
    '오웬', '나린', '피오', '하젤', '로웬', '카야', '테스', '유리엘', '보른', '시아',
    '레온', '아델', '밀로', '이브', '단테', '노아', '페른', '루나', '그렌', '에코',
  ];

  // ───────────── 「발드린 문지기」 장비 (지역 1 일반 장비 6부위)

  static const List<EquipBase> baldrinGear = [
    EquipBase.baldrinWeapon,
    EquipBase.baldrinHead,
    EquipBase.baldrinBody,
    EquipBase.baldrinHands,
    EquipBase.baldrinFeet,
    EquipBase.baldrinAcc,
  ];

  static const List<EquipBaseInfo> gearInfos = [
    EquipBaseInfo(
        id: EquipBase.baldrinWeapon, name: '발드린 문지기 장검', slot: EquipSlot.weapon,
        recipe: {}, attack: 0.13, asset: 'equip_baldrinWeapon'),
    EquipBaseInfo(
        id: EquipBase.baldrinHead, name: '발드린 문지기 투구', slot: EquipSlot.head,
        recipe: {}, reduce: 0.04, asset: 'equip_baldrinHead'),
    EquipBaseInfo(
        id: EquipBase.baldrinBody, name: '발드린 문지기 사슬 갑옷', slot: EquipSlot.body,
        recipe: {}, reduce: 0.085, asset: 'equip_baldrinBody'),
    EquipBaseInfo(
        id: EquipBase.baldrinHands, name: '발드린 문지기 건틀릿', slot: EquipSlot.hands,
        recipe: {}, reduce: 0.03, asset: 'equip_baldrinHands'),
    EquipBaseInfo(
        id: EquipBase.baldrinFeet, name: '발드린 문지기 장화', slot: EquipSlot.feet,
        recipe: {}, reduce: 0.03, asset: 'equip_baldrinFeet'),
    EquipBaseInfo(
        id: EquipBase.baldrinAcc, name: '발드린 문지기 휘장', slot: EquipSlot.accessory,
        recipe: {}, maxHp: 0.10, asset: 'equip_baldrinAcc'),
  ];

  static const String ticketImage = 'assets/images/item_recruitTicket.webp';
  static const String energyImage = 'assets/images/icon_journeyEnergy.webp';

  /// 주점 「동료」 탭 확률 공개 문장
  static List<String> odds() => [
        '종족 8가지는 모두 같은 확률이에요 (각 12.5%).',
        '직업 6가지도 모두 같은 확률이에요 (각 약 16.7%).',
        '능력치는 이야기 동료의 70~100% 사이에서 정해져요. 3% 확률로 100~110%까지 나와요.',
        '특성은 1개(70%) 또는 2개(30%)가 붙어요. 특성 10가지는 모두 같은 확률이에요.',
        '이름은 무작위로 붙고, 언제든 바꿀 수 있어요.',
      ];
}
