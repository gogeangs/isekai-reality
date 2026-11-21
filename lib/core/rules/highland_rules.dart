import 'dart:math' as math;

import '../geo/geo.dart';
import 'battle_rules.dart';
import 'element_rules.dart';
import 'equipment_rules.dart';
import 'exclusion_index.dart';
import 'exploration_rules.dart';
import 'materials.dart';
import 'monsters.dart';
import 'place_grid.dart';
import 'road_mask.dart';
import 'rule_constants.dart';
import 'title_rules.dart';

/// 하이랜드 (묶음 50 #146): 하늘에 떠오르는 섬 다섯. 순서는 바람·번개·빛·얼음·물 (비문 자리 순서)
enum Isle { wind, thunder, light, ice, water }

/// 수호자의 특별한 공격 (숨은 규칙, 화면에는 문장만). 2막 분신 공격과 겹치지 않는다
enum SkyMove {
  /// 회오리: 몇 턴 동안 두 번씩 움직인다
  whirl,

  /// 낙뢰: 큰 번개를 예고하고 몇 턴 뒤 떨어뜨린다 (방어 태세로 막는다)
  bolt,

  /// 햇살 치유: 체력이 절반 아래로 내려가면 한 번 크게 회복
  sunHeal,

  /// 서리 갑옷: 몇 턴마다 받는 피해를 크게 줄인다 (강타로 깬다)
  frostArmor,

  /// 물살: 나에게 걸린 좋은 효과를 모두 씻어 낸다
  wash,
}

class IsleInfo {
  const IsleInfo({
    required this.id,
    required this.place,
    required this.element,
    required this.guardian,
    required this.move,
    required this.moveName,
    required this.moveLine,
    required this.crystal,
    required this.inscription,
    required this.color,
  });

  final Isle id;

  /// 섬 이름 ('구름 초원')
  final String place;
  final Element element;
  final MonsterId guardian;
  final SkyMove move;

  /// '회오리'
  final String moveName;

  /// 특별한 공격을 쓸 때 화면 문장 (숫자 없이)
  final String moveLine;

  /// 수호자가 나눠 주는 귀한 결정
  final MaterialId crystal;

  /// 처음 쓰러뜨리면 얻는 비문
  final String inscription;

  /// 속성 색 (ARGB, 석상 병사·지도 표시)
  final int color;

  String get background => 'assets/images/bg_highland_${id.name}.webp';
  String get marker => 'assets/images/map_highland_${id.name}.webp';
}

/// 하이랜드 규칙 (묶음 50 #146). 숫자는 개발이 정한 숨은 값, 화면에는 보이지 않는다.
class HighlandRules {
  HighlandRules._();

  /// 2막 Lv.17에 열림
  static const int openLevel = 17;

  static const List<IsleInfo> isles = [
    IsleInfo(
      id: Isle.wind,
      place: '구름 초원',
      element: Element.wind,
      guardian: MonsterId.guardWind,
      move: SkyMove.whirl,
      moveName: '회오리',
      moveLine: '회오리가 일어나요! 석상 기사가 두 번씩 움직여요.',
      crystal: MaterialId.cloudCrystal,
      inscription: '구름 위에 왕국이 있었다. 바람이 길을 내고, 사람들은 그 길로 하늘을 건넜다.',
      color: 0xFF6FE3B0,
    ),
    IsleInfo(
      id: Isle.thunder,
      place: '뇌운 봉우리',
      element: Element.thunder,
      guardian: MonsterId.guardThunder,
      move: SkyMove.bolt,
      moveName: '낙뢰',
      moveLine: '먹구름이 모여요! 큰 번개가 떨어지기 전에 방어 태세!',
      crystal: MaterialId.stormCore,
      inscription: '폭풍은 성벽이었다. 번개가 칠 때마다 왕국은 더 단단해졌다.',
      color: 0xFFFFD84A,
    ),
    IsleInfo(
      id: Isle.light,
      place: '햇살 정원',
      element: Element.light,
      guardian: MonsterId.guardLight,
      move: SkyMove.sunHeal,
      moveName: '햇살 치유',
      moveLine: '햇살이 쏟아져요! 석상 거인이 크게 회복했어요.',
      crystal: MaterialId.sunDew,
      inscription: '해가 지지 않는 정원에서 왕은 백성과 함께 꽃을 길렀다.',
      color: 0xFFFFF0A0,
    ),
    IsleInfo(
      id: Isle.ice,
      place: '서리 성채',
      element: Element.ice,
      guardian: MonsterId.guardIce,
      move: SkyMove.frostArmor,
      moveName: '서리 갑옷',
      moveLine: '서리 갑옷을 둘렀어요! 강타로 깨뜨려요.',
      crystal: MaterialId.frostCrystal,
      inscription: '어느 날 왕은 "곧 돌아오마" 하고 구름 아래로 내려갔다. 수호자들은 문을 닫지 않았다.',
      color: 0xFFA8E6FF,
    ),
    IsleInfo(
      id: Isle.water,
      place: '폭포 계곡',
      element: Element.water,
      guardian: MonsterId.guardWater,
      move: SkyMove.wash,
      moveName: '물살',
      moveLine: '거센 물살에 좋은 효과가 씻겨 나갔어요!',
      crystal: MaterialId.fallsPearl,
      inscription: '섬들은 하나둘 흩어졌다. 그래도 수호자들은 기다린다. 왕이 돌아올 그날을.',
      color: 0xFF4FA8FF,
    ),
  ];

  static IsleInfo info(Isle i) => isles[i.index];

  static IsleInfo? ofGuardian(MonsterId m) {
    for (final i in isles) {
      if (i.guardian == m) return i;
    }
    return null;
  }

  static IsleInfo? ofMove(SkyMove m) {
    for (final i in isles) {
      if (i.move == m) return i;
    }
    return null;
  }

  /// 하늘 재료 (결정 다섯 + 하늘 돌 조각)
  static const List<MaterialId> crystals = [
    MaterialId.cloudCrystal,
    MaterialId.stormCore,
    MaterialId.sunDew,
    MaterialId.frostCrystal,
    MaterialId.fallsPearl,
  ];

  // ───────────── 대사 (기획 #146 그대로)

  /// 처음 하늘에 섬이 뜰 때 짧은 장면 (주인공 · 첫 펫)
  static const String scene = 'assets/images/scene_highland_first.webp';
  static const String sceneHero = '…하늘에 섬이 떠 있어?';
  static const List<String> scenePet = [
    '저건 저쪽 세계 하늘에 떠 있던 섬이야! 세계가 겹친 틈으로 여기까지 비쳐 보이나 봐.',
    '오래 머물진 못할 거야. 하늘 깃털이 있으면 올라가 볼 수 있어!',
  ];

  /// 처음 섬에 올랐을 때 한 번 (첫 펫)
  static const String firstClimbLine =
      '여기가 하이랜드야. 옛날 사람들은 그냥 그렇게 불렀대. 진짜 이름은 아무도 몰라.';

  // ───────────── 섬 나오는 때 (하루 2번, 한 번 뜨면 1시간)

  /// 아침 섬이 떠오르는 때: 7시 ~ 9시 사이 하루마다 다른 분
  static const int morningFrom = 7;

  /// 저녁 섬이 떠오르는 때: 18시 ~ 20시 사이
  static const int eveningFrom = 18;

  /// 떠오르는 분이 흩어지는 폭 (분)
  static const int riseSpread = 120;

  /// 떠 있는 시간
  static const Duration stay = Duration(hours: 1);

  /// 세트 6개: 조금 더 오래 떠 있음
  static const Duration staySet6 = Duration(minutes: 15);

  /// 그날 [evening] 섬이 떠오르는 때
  static DateTime riseAt(DateTime day, {required bool evening}) {
    final d = DateTime(day.year, day.month, day.day);
    final key = '${d.year}-${d.month}-${d.day}|${evening ? 'pm' : 'am'}';
    final m = _hash('$key|rise') % riseSpread;
    return d.add(Duration(hours: evening ? eveningFrom : morningFrom, minutes: m));
  }

  /// 지금 떠 있는 섬의 칸 ('yyyy-mm-dd-am' 등)과 떠오른 때 · 지는 때 (없으면 null)
  static ({String slot, DateTime from, DateTime until, bool evening})? slotAt(
      DateTime now, {bool longer = false}) {
    for (final evening in const [false, true]) {
      final from = riseAt(now, evening: evening);
      final until = from.add(stay + (longer ? staySet6 : Duration.zero));
      if (!now.isBefore(from) && now.isBefore(until)) {
        return (
          slot: '${_day(now)}-${evening ? 'pm' : 'am'}',
          from: from,
          until: until,
          evening: evening,
        );
      }
    }
    return null;
  }

  /// 다음에 섬이 떠오르는 때 (알림)
  static DateTime nextRise(DateTime now) {
    for (var d = 0; d < 3; d++) {
      final day = DateTime(now.year, now.month, now.day + d);
      for (final evening in const [false, true]) {
        final r = riseAt(day, evening: evening);
        if (r.isAfter(now)) return r;
      }
    }
    return riseAt(DateTime(now.year, now.month, now.day + 1), evening: false);
  }

  // ───────────── 어느 섬이 뜰지

  /// 아직 수호자를 못 쓰러뜨린 섬이 이만큼 더 잘 나온다 (숨은 값)
  static const int unbeatenWeight = 3;

  /// 첫 섬은 바람 고정. 그 뒤엔 무작위 (못 쓰러뜨린 섬이 더 잘), 같은 날 아침·저녁은 서로 다른 섬
  static Isle pickIsle({
    required String slot,
    required bool first,
    required Set<Isle> beaten,
    Isle? avoid,
  }) {
    if (first) return Isle.wind;
    final rng = math.Random(_hash('$slot|isle'));
    final pool = [
      for (final i in Isle.values)
        if (i != avoid)
          for (var k = 0; k < (beaten.contains(i) ? 1 : unbeatenWeight); k++) i,
    ];
    return pool[rng.nextInt(pool.length)];
  }

  // ───────────── 섬 자리 (떠오를 때 내 둘레 300~800m)

  static const double spotMinM = 300;
  static const double spotMaxM = 800;

  /// 걸어서 섬 아래에 닿았다고 보는 거리
  static const double enterM = 50;

  static GeoPoint spot(
    ExploreArea area, {
    required String slot,
    required GeoPoint anchor,
    RoadMask? roads,
    ExclusionIndex? exclusions,
    LandKind? Function(GeoPoint)? land,
  }) {
    bool allowed(GeoPoint p, {bool road = true}) {
      final l = land?.call(p);
      return area.bounds.contains(p) &&
          !area.isExcluded(p) &&
          !(exclusions?.contains(p) ?? false) &&
          !(road && (roads?.isRoad(p) ?? false)) &&
          l != LandKind.water &&
          l != LandKind.sea;
    }

    final rng = math.Random(_hash('$slot|spot'));
    final tries = [
      for (var i = 0; i < 24; i++)
        _offset(anchor, spotMinM + rng.nextDouble() * (spotMaxM - spotMinM),
            rng.nextDouble() * 2 * math.pi),
    ];
    for (final p in tries) {
      if (allowed(p)) return p;
    }
    for (final p in tries) {
      if (allowed(p, road: false)) return p;
    }
    return tries.first;
  }

  // ───────────── 하늘 깃털 (숨은 값)

  /// 걸음: 이만큼 걸을 때마다 하나 (세트 2개면 더 짧게)
  static const int featherSteps = 3000;
  static const int featherStepsSet2 = 2400;

  /// 걸어서 얻는 깃털은 하루 이만큼까지
  static const int featherDayCap = 3;

  /// 날개 달린 몬스터(미궁 박쥐·그림자 나비)가 떨어뜨릴 확률
  static const double wingDrop = 0.05;
  static const Set<MonsterId> winged = {
    MonsterId.labyrinthBat,
    MonsterId.shadowButterfly,
  };

  /// 하이랜드가 처음 열릴 때 첫 펫이 주운 깃털 (첫 섬을 바로 올라 볼 수 있게)
  static const int starterFeathers = 1;

  /// 오늘 걸음으로 받을 깃털 수 (하루 한도까지)
  static int feathersFor(int steps, {bool set2 = false}) =>
      math.min(featherDayCap, steps ~/ (set2 ? featherStepsSet2 : featherSteps));

  // ───────────── 섬 안 길 (입구 → 갈림길 둘 → 수호자 앞)

  /// 폐허의 길: 상자 · 빈손 · 하늘 깃털 (운)
  static const double ruinsChest = 0.50;
  static const double ruinsFeather = 0.15;

  /// 폐허 상자: 금화 · 하늘 돌 조각 1
  static const int chestGoldMin = 30;
  static const int chestGoldMax = 80;

  /// 석상 병사: 그 레벨 필드 몬스터 대비 체력·공격 · 이기면 하늘 돌 조각 1~2
  static const double soldierHp = 1.3;
  static const double soldierAttack = 1.1;
  static const int soldierStoneMin = 1;
  static const int soldierStoneMax = 2;

  static Foe soldierFoe(Isle isle, int level) {
    final b = BattleRules.fieldFoe(level: level, monster: MonsterId.stoneSoldier);
    final i = info(isle);
    return Foe(
      monster: MonsterId.stoneSoldier,
      maxHp: math.max(1, (b.maxHp * soldierHp).round()),
      attack: math.max(1, (b.attack * soldierAttack).round()),
      defense: b.defense,
      speed: b.speed,
      forceElement: i.element,
      tint: i.color,
    );
  }

  // ───────────── 수호자 (그 레벨 던전 보스 대비, 내 레벨에 맞춤)

  static const double guardianHp = 1.6;
  static const double guardianAttack = 1.15;

  /// 이기면: 하늘 돌 조각 2~3 · 그 섬 결정 (처음은 2개, 그 뒤엔 반쯤 1개)
  static const int guardianStoneMin = 2;
  static const int guardianStoneMax = 3;
  static const int firstCrystals = 2;
  static const double crystalChance = 0.5;

  /// 처음 쓰러뜨릴 때 경험치 (던전 보스 클리어의 2배, 2막 분신과 같음)
  static const int guardianExp = RuleConstants.dungeonClearExp * 2;

  static Foe guardianFoe(Isle isle, int level) {
    final i = info(isle);
    final atk = BattleRules.expectedAttack(level);
    final hp = BattleRules.expectedMaxHp(level);
    final floorAttack =
        math.max(1, (hp / RuleConstants.dungeonHpBudgetTicks).round());
    return Foe(
      monster: i.guardian,
      maxHp: math.max(1, (atk * RuleConstants.bossHitsToClear * guardianHp).round()),
      attack: math.max(1,
          (floorAttack * RuleConstants.bossAttackMultiplier * guardianAttack).round()),
      sky: i.move,
    );
  }

  // ───────────── 특별한 공격 세기 (숨김)

  /// 회오리: 몇 턴마다 · 몇 턴 동안 두 번씩
  static const int whirlEvery = 6;
  static const int whirlLength = 2;

  /// 낙뢰: 몇 턴마다 예고 · 예고 뒤 몇 턴에 떨어짐 · 공격 배율 · 방어 태세로 막으면 남는 피해
  static const int boltEvery = 8;
  static const int boltDelay = 2;
  static const double boltPower = 3.0;
  static const double boltBlocked = 0.2;

  /// 햇살 치유: 체력이 이 아래로 내려가면 한 번 · 회복(최대 체력 비율)
  static const double sunHealBelow = 0.5;
  static const double sunHeal = 0.30;

  /// 서리 갑옷: 몇 턴마다 · 몇 턴 동안 · 그동안 받는 피해 배율
  static const int frostEvery = 7;
  static const int frostLength = 3;
  static const double frostTaken = 0.35;

  /// 물살: 몇 턴마다
  static const int washEvery = 5;

  // ───────────── 「하이랜드 수호 기사」 세트 (숨김)

  /// 4개: 바람·번개·빛·얼음·물 속성 공격에 받는 피해 감소
  static const double setTaken4 = 0.12;
  static const Set<Element> skyElements = {
    Element.wind,
    Element.thunder,
    Element.light,
    Element.ice,
    Element.water,
  };

  /// 세트 부위 → 그 부위 결정 (장신구는 결정 다섯 하나씩) · 하늘 돌 조각 · 금화
  static ({Map<MaterialId, int> mats, int gold}) partCost(EquipSlot s) =>
      switch (s) {
        EquipSlot.weapon => (
            mats: {MaterialId.skyStone: 8, MaterialId.stormCore: 2},
            gold: 800
          ),
        EquipSlot.head => (
            mats: {MaterialId.skyStone: 4, MaterialId.sunDew: 1},
            gold: 400
          ),
        EquipSlot.body => (
            mats: {MaterialId.skyStone: 6, MaterialId.frostCrystal: 2},
            gold: 600
          ),
        EquipSlot.hands => (
            mats: {MaterialId.skyStone: 3, MaterialId.fallsPearl: 1},
            gold: 300
          ),
        EquipSlot.feet => (
            mats: {MaterialId.skyStone: 3, MaterialId.cloudCrystal: 1},
            gold: 300
          ),
        EquipSlot.accessory => (
            mats: {
              MaterialId.skyStone: 4,
              for (final c in crystals) c: 1,
            },
            gold: 400
          ),
      };

  /// 세트 부위의 속성 (그 부위 결정의 섬 속성, 장신구는 없음)
  static Element? partElement(EquipSlot s) => switch (s) {
        EquipSlot.weapon => Element.thunder,
        EquipSlot.head => Element.light,
        EquipSlot.body => Element.ice,
        EquipSlot.hands => Element.water,
        EquipSlot.feet => Element.wind,
        EquipSlot.accessory => null,
      };

  // ───────────── 칭호

  static const TitleId climbTitle = TitleId.skyWalker;
  static const TitleId guardiansTitle = TitleId.guardianTrust;
  static const TitleId witnessTitle = TitleId.kingdomWitness;

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static GeoPoint _offset(GeoPoint from, double meters, double bearing) {
    final dLat = meters * math.cos(bearing) / 111320;
    final dLng = meters *
        math.sin(bearing) /
        (111320 * math.cos(from.lat * math.pi / 180));
    return GeoPoint(from.lat + dLat, from.lng + dLng);
  }

  static int _hash(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h;
  }
}
