// 묶음 57 #249: 직업 개편 — 전투 6 · 생산 6 · 히든 8, 주 1 + 보조 1, 보조 각인 · 짝 이름 · 숨은 특별 짝 10,
// 전직의 증표, 직업마다 따로 쌓이는 스킬 포인트. 수치는 모두 숨은 규칙 (화면엔 문장만).

import 'job_rules.dart';
import 'mastery_rules.dart';

/// 새 갈래
enum JobGroup { combat, craft, hidden, retired }

extension JobGroupLabel on JobGroup {
  String get label => switch (this) {
        JobGroup.combat => '전투',
        JobGroup.craft => '생산',
        JobGroup.hidden => '히든',
        JobGroup.retired => '',
      };
}

/// 보조 각인 (보조 직업마다 하나: 앞말 + 전투 주일 때 · 생산 주일 때)
class JobImprint {
  const JobImprint(this.job, this.prefix, this.combat, this.craft);
  final JobId job;
  final String prefix;
  final String combat;
  final String craft;
}

/// 숨은 특별 짝 (주 + 보조) — 처음 맞추면 「새 짝을 찾았어요」 + 칭호
class SpecialPair {
  const SpecialPair(this.id, this.name, this.main, this.sub, this.text,
      {this.legacy, this.skill, this.place = false});

  /// 묶음 77 #347: 장소(탐험가)가 있어야 되는 이명 — 장소 기능 전까지 숨김
  final bool place;
  final String id;
  final String name;
  final JobId main;
  final JobId sub;

  /// 더해지는 효과 한 줄
  final String text;

  /// 옛 직업의 고유 기술을 되살림 (그 직업 효과가 주 직업처럼 켜짐)
  final JobId? legacy;

  /// 이 짝일 때만 열리는 옛 공격 스킬 (전투 스킬 5개 제한 밖)
  final JobSkill? skill;

  String get title => 'title_pair_$id';
}

abstract final class JobPairRules {
  static const combat = [JobId.warrior, JobId.archer, JobId.mage, JobId.priest, JobId.rogue, JobId.knight];
  static const craft = [
    JobId.blacksmith,
    JobId.alchemist,
    JobId.herbalist,
    JobId.appraiser,
    JobId.merchant,
    JobId.tamer,
  ];
  static const hidden = [
    JobId.explorer,
    JobId.pilgrim,
    JobId.archaeologist,
    JobId.adventurer,
    JobId.nightWalker,
    JobId.gateHeir,
    JobId.ashHunter,
    JobId.allCrafter,
  ];

  /// 20가지 (고르는 순서)
  static const all = [...combat, ...craft, ...hidden];

  /// 히든 중 전투 주로 치는 직업 (짝 각인이 싸움에 붙음)
  static const _combatHidden = {JobId.nightWalker, JobId.gateHeir, JobId.ashHunter, JobId.adventurer};

  static JobGroup groupOf(JobId j) => combat.contains(j)
      ? JobGroup.combat
      : craft.contains(j)
          ? JobGroup.craft
          : hidden.contains(j)
              ? JobGroup.hidden
              : JobGroup.retired;

  /// 주 직업이 싸움 쪽인지 (각인이 싸움에 붙는지)
  static bool combatMain(JobId j) => combat.contains(j) || _combatHidden.contains(j);

  static const List<JobImprint> imprints = [
    JobImprint(JobId.warrior, '투지의', 'HP가 낮을수록 공격이 세져요', '만든 무기에 공격 특성이 잘 붙어요'),
    JobImprint(JobId.archer, '매눈', '첫 차례에 먼저 쏘고 치명타가 조금 더 나요', '채집·감정에서 「완벽」이 잘 나와요'),
    JobImprint(JobId.mage, '마력의', '공격에 내 속성이 실려요', '만든 장비·물약에 속성이 잘 붙어요'),
    JobImprint(JobId.priest, '축복의', '공격할 때 HP가 조금씩 차요', '회복 물약이 더 잘 채워 줘요'),
    JobImprint(JobId.rogue, '그림자', '가끔 두 번 치고 전리품이 하나 더 나와요', '재료를 가끔 아껴요'),
    JobImprint(JobId.knight, '수호의', '받는 피해가 줄고 막기가 쉬워요', '만든 장비가 더 튼튼해요'),
    JobImprint(JobId.blacksmith, '강철', '싸워도 장비가 덜 닳고 강화한 무기일수록 더 세요', '도구가 덜 닳고 수리비가 덜 들어요'),
    JobImprint(JobId.alchemist, '비약의', '공격 스킬에 독·화상이 묻고 물약이 더 잘 들어요', '가마솥이 더 빨리 끓어요'),
    JobImprint(JobId.herbalist, '숲의', '이기면 재료가 더 나오고 가끔 덩굴로 묶어요', '재료가 가끔 하나 더 나와요'),
    JobImprint(JobId.appraiser, '눈 밝은', '몬스터 약점을 알아채 약점 피해가 더 커요', '좋은 등급·귀한 재료가 잘 나와요'),
    JobImprint(JobId.merchant, '황금', '이기면 금화가 더 나와요', '파는 값이 오르고 사는 값이 내려가요'),
    JobImprint(JobId.tamer, '야수의', '펫이 내 공격에 맞춰 같이 쳐요', '동행 펫이 일을 도와 시간이 줄어요'),
    JobImprint(JobId.explorer, '방랑의', '처음 만난 몬스터에게 더 세요', '처음 가 본 곳 채집에서 더 얻어요'),
    JobImprint(JobId.pilgrim, '순례의', '자주 가는 곳에서 싸우면 더 세요', '자주 가는 곳에서 재료가 더 나와요'),
    JobImprint(JobId.archaeologist, '고대의', '가끔 고대 유물이 강한 공격을 막아요', '만든 것에 가끔 고대의 힘이 깃들어요'),
    JobImprint(JobId.adventurer, '모험의', '던전에서 더 세요', '의뢰 보상이 더 나와요'),
    JobImprint(JobId.nightWalker, '달밤의', '밤에 더 세요', '밤에 하는 일 결과가 더 좋아요'),
    JobImprint(JobId.gateHeir, '등불의', '잿빛 몬스터에게 더 세고 펫 기력이 덜 들어요', '펫이 도울 때 효과가 더 커요'),
    JobImprint(JobId.ashHunter, '잿빛을 쫓는', '잿빛 몬스터의 보호를 깨요', '잿빛 재료를 더 얻어요'),
    JobImprint(JobId.allCrafter, '만능', '주 직업 고유 기술이 조금 더 세요', '주 직업 고유 기술이 조금 더 세요'),
  ];

  static JobImprint imprintOf(JobId sub) =>
      imprints.firstWhere((i) => i.job == sub, orElse: () => imprints.last);

  static const List<SpecialPair> specials = [
    SpecialPair('weaponsmith', '무기 장인', JobId.blacksmith, JobId.warrior, '강화한 무기일수록 더 세게 싸워요',
        legacy: JobId.weaponsmith, skill: JobSkill.masterSlash),
    SpecialPair('runesmith', '룬 대장장이', JobId.blacksmith, JobId.alchemist, '장비를 만들 때 가끔 속성이 붙어요',
        legacy: JobId.runesmith),
    SpecialPair('jeweler', '보석 세공사', JobId.appraiser, JobId.blacksmith,
        '보석을 쓰는 장비가 좋은 등급으로 잘 나오고, 보석을 더 캐요',
        legacy: JobId.jeweler, skill: JobSkill.gemShard),
    SpecialPair('potionMerchant', '물약 상인', JobId.alchemist, JobId.merchant, '잡화상에서 물약을 싸게 사요',
        legacy: JobId.potionMerchant, skill: JobSkill.poisonFlask),
    SpecialPair('peddler', '행상인', JobId.merchant, JobId.explorer, '많이 걸은 날은 더 비싸게 팔아요',
        legacy: JobId.peddler, skill: JobSkill.bundleSwing, place: true),
    SpecialPair('beastKnight', '마수 기사', JobId.knight, JobId.tamer, '펫과 함께 싸우면 더 세져요',
        legacy: JobId.beastKnight, skill: JobSkill.jointAttack),
    SpecialPair('pathfinder', '길잡이', JobId.explorer, JobId.tamer, '먼 곳 원정에서 이기면 더 가져와요',
        legacy: JobId.pathfinder, place: true),
    SpecialPair('paladin', '성기사', JobId.knight, JobId.priest,
        '대신 맞을 때 HP가 조금 차고, 잿빛 몬스터에게 빛 피해를 줘요'),
    SpecialPair('nightThief', '밤의 도둑', JobId.rogue, JobId.nightWalker, '밤에는 훔치기가 꼭 되고 한 번 더 베어요'),
    SpecialPair('ranger', '레인저', JobId.archer, JobId.explorer, '처음 가는 곳에서는 꼭 먼저 쏘고 먼 몬스터가 더 보여요',
        place: true),
    // 묶음 77 #346: 공격형 숨은 이명 둘
    SpecialPair('spellblade', '마검사', JobId.warrior, JobId.mage,
        '강타에 내 속성이 실리고, 몬스터가 그 속성에 약하면 더 세요',
        skill: JobSkill.spellbladeSlash),
    SpecialPair('sage', '현자', JobId.mage, JobId.appraiser,
        '몬스터 약점 속성이 늘 보이고 약점 피해가 더 세요',
        skill: JobSkill.sageStrike),
  ];

  /// 묶음 77 #347: 장소 기능이 생길 때까지 숨기는 것 (탐험가 · 순례자 · 탐험가가 있어야 하는 숨은 이명)
  static const Set<JobId> placeJobs = {JobId.explorer, JobId.pilgrim};

  /// 게임에 보이는 숨은 이명 (장소 관련은 빼고)
  static List<SpecialPair> get visibleSpecials => [for (final p in specials) if (!p.place) p];

  /// 게임에 보이는 히든 직업
  static List<JobId> get visibleHidden => [for (final j in hidden) if (!placeJobs.contains(j)) j];

  static SpecialPair? specialOf(JobId? main, JobId? sub) {
    if (main == null || sub == null) return null;
    for (final p in specials) {
      if (p.main == main && p.sub == sub) return p;
    }
    return null;
  }

  static SpecialPair? specialById(String id) {
    for (final p in specials) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// 짝 이름: 보조 앞말 + 주 직업 (특별 짝이면 그 이름)
  static String pairName(JobId main, JobId? sub) {
    final m = JobRules.info(main).name;
    if (sub == null) return m;
    final sp = specialOf(main, sub);
    if (sp != null) return sp.name;
    return '${imprintOf(sub).prefix} $m';
  }

  /// 짝 각인 한 줄 (주가 싸움 쪽이면 싸움 효과)
  static String imprintLine(JobId main, JobId sub) {
    final i = imprintOf(sub);
    return combatMain(main) ? i.combat : i.craft;
  }

  // ───────────── 숨은 수치

  /// 보조 각인 세기 (Lv.20 보조 각인 2단계에 더 셈)
  /// 묶음 77 #357: 각인 2단계(1.5배)는 Lv.30부터 · 보조 직업은 Lv.20부터
  static double imprintPower(int level) => level >= imprintDeepLevel ? 1.5 : 1.0;
  static const int imprintDeepLevel = 30;
  static const int subJobLevel = 20;

  /// 전직의 증표: 일주일에 5만 보마다 1장 · 조합 상점에서 주에 1장 (금화)
  static const int tokenSteps = 50000;
  static const int tokenShopGold = 300;
  static const int changeGold = 100;

  /// 히든 조건 (게임엔 보여 주지 않음)
  /// 묶음 77 #345 · #347: 히든 직업은 극소수만 (숨은 값)
  static const int explorerPlaces = 500;
  static const int pilgrimWeeks = 12;
  static const int pilgrimVisits = 4; // 한 주 5일 이상 (4 넘게)
  static const int archaeologistRelics = 300;
  static const int adventurerDungeons = 200;
  static const int adventurerQuests = 500;
  static const int ashHunterKills = 500;
  static const int allCrafterMasters = 6;

  /// 옛 숨은 직업 · 탐험형 직업 (예전 기록에서 열려 있었으면 열린 채로)
  static const legacyHiddenFrom = {
    JobId.explorer: JobId.explorer,
    JobId.pathfinder: JobId.explorer,
    JobId.pilgrim: JobId.pilgrim,
    JobId.archaeologist: JobId.archaeologist,
    JobId.adventurer: JobId.adventurer,
    JobId.nightWalker: JobId.nightWalker,
    JobId.gateHeir: JobId.gateHeir,
    JobId.ashHunter: JobId.ashHunter,
    JobId.allCrafter: JobId.allCrafter,
  };

  /// 전투 스킬 최대 (직업마다)
  static const int maxCombatSkills = 5;

  /// 잘 맞는 무기 (숨은 보너스)
  static const double preferredWeapon = 0.08;

  /// 고유 기술 (새 전투 직업, 숨은 값)
  static const double warriorBash = 0.25; // 강타 더 세게
  static const int warriorBashTicks = 1; // 강타가 한 턴 빨리
  static const double mageMp = 0.30; // 최대 MP 더
  static const double mageMpFill = 0.5; // 걸을 때 더 빨리
  static const double rogueDodge = 0.10;
  static const double knightGuard = 0.10; // 받는 피해 덜
  static const double knightBlock = 0.15; // 막기 쉬움

  /// Lv.15 조합 추천: 가장 높은 큰 숙련도 → 직업 (전투면 무기, 걷기·탐험이면 다음 숙련도)
  static JobId recommend(List<Mastery> byValue, String? weaponKind) {
    for (final m in byValue) {
      switch (m) {
        case Mastery.smith:
          return JobId.blacksmith;
        case Mastery.harvest:
          return JobId.herbalist;
        case Mastery.alchemy:
          return JobId.alchemist;
        case Mastery.appraise:
          return JobId.appraiser;
        case Mastery.trade:
          return JobId.merchant;
        case Mastery.spirit:
          return JobId.tamer;
        case Mastery.combat:
          return switch (weaponKind) {
            'bow' => JobId.archer,
            'staff' => JobId.mage,
            'dagger' => JobId.rogue,
            'spear' => JobId.knight,
            _ => JobId.warrior,
          };
        case Mastery.walk:
          continue;
      }
    }
    return JobId.warrior;
  }

  /// 직업마다 잘 맞는 무기 종류 (hero_rig weaponKind 이름)
  static Set<String> preferredWeapons(JobId j) => switch (j) {
        JobId.warrior => const {'sword', 'axe'},
        JobId.archer => const {'bow'},
        JobId.mage || JobId.priest => const {'staff'},
        JobId.rogue => const {'dagger'},
        JobId.knight => const {'sword', 'spear'},
        _ => const {},
      };

  /// 세라의 특별 짝 힌트 (조합 ★2, 하루 한 줄) — 아직 못 찾은 짝 하나를 은근히
  static String hintOf(SpecialPair p) {
    final m = JobRules.info(p.main).name, s = JobRules.info(p.sub).name;
    return switch (p.id) {
      'weaponsmith' => '망치를 든 사람이 칼도 잘 쓰면, 무기가 먼저 알아본대요.',
      'runesmith' => '쇠와 약물을 함께 다루는 손에서 빛나는 장비가 나온다는 이야기가 있어요.',
      'jeweler' => '보는 눈이 밝은 사람이 망치까지 들면 보석이 말을 건대요.',
      'potionMerchant' => '물약을 끓이는 사람이 셈까지 빠르면 잡화상이 반긴대요.',
      'peddler' => '장사꾼이 멀리 걷기까지 하면 짐이 금이 된대요.',
      'beastKnight' => '방패를 든 사람 곁에 짐승이 서면 둘 다 강해진대요.',
      'pathfinder' => '길을 아는 사람과 펫이 함께면 먼 곳도 가깝대요.',
      'paladin' => '방패와 기도가 만나면 빛이 대신 맞아 준대요.',
      'nightThief' => '밤길을 아는 손은 무엇이든 가져온대요.',
      'ranger' => '활 쏘는 사람이 처음 가는 길을 좋아하면 늘 먼저 쏜대요.',
      'spellblade' => '칼끝에 마법을 실을 줄 아는 전사가 있대요.',
      'sage' => '약점을 꿰뚫어 보는 마법사는 한 번에 끝낸대요.',
      _ => '$m에게 $s의 힘이 더해지면 무슨 일이 생길까요?',
    };
  }
}
