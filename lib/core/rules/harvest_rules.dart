import 'dart:math' as math;

import '../geo/geo.dart';
import 'exclusion_index.dart';
import 'element_rules.dart';
import 'exploration_rules.dart';
import 'materials.dart';
import 'place_grid.dart';
import 'road_mask.dart';

/// 채집 자리 종류 (11-11 #56). 이름은 저장 기록의 키라 바꾸지 않는다.
enum HarvestKind { herb, ore, wood, water, mushroom, flower, gem, relic }

/// 채집 도구. 버섯·꽃은 약초 낫, 보석은 곡괭이, 유물은 붓 (11-11 #83)
enum HarvestTool { sickle, pickaxe, axe, rod, brush }

/// 도구 등급 (11-11 #83): 돌 → 철 → 은 → 미스릴. 높을수록 내구도↑·미니게임 쉬움·귀한 재료↑ (숨김)
enum ToolTier { stone, iron, silver, mithril }

extension ToolTierLabel on ToolTier {
  String get label => switch (this) {
        ToolTier.stone => '돌',
        ToolTier.iron => '철',
        ToolTier.silver => '은',
        ToolTier.mithril => '미스릴',
      };
}

/// 미니게임 결과
enum HarvestGrade { quick, fail, good, perfect }

class HarvestKindInfo {
  const HarvestKindInfo(this.kind, this.name, this.base, this.rare, this.tool,
      this.toolName, this.game, this.gameHint);

  final HarvestKind kind;
  final String name;

  /// 항상 나오는 기본 재료
  final MaterialId base;

  /// 귀한 재료
  final MaterialId rare;
  final HarvestTool tool;
  final String toolName;

  /// 미니게임 이름과 설명
  final String game;
  final String gameHint;

  /// 지도 그림 (있는 그림만 쓸 수 있다). 11-11 #83 새 자리 4종은 임시 아이콘 그림.
  String get mapAsset => switch (kind) {
        HarvestKind.mushroom ||
        HarvestKind.flower ||
        HarvestKind.gem ||
        HarvestKind.relic =>
          'assets/images/map_harvest_${kind.name}.webp',
        _ => 'assets/images/mat_${base.name}.webp',
      };
}

/// 지도 위 채집 자리 하나
class HarvestSpot {
  const HarvestSpot({required this.id, required this.kind, required this.point});

  final String id;
  final HarvestKind kind;
  final GeoPoint point;

  HarvestKindInfo get info => HarvestRules.info(kind);
}

/// 자리마다 남은 채집 횟수 (시간이 지나면 다시 찬다)
class SpotCharge {
  const SpotCharge({required this.charges, required this.at});

  /// [at] 때의 남은 횟수
  final int charges;
  final DateTime at;

  /// 지금 남은 횟수. [recharge] 하나가 다시 차는 시간 (묶음 49 모스: 조금 빨리)
  int current(DateTime now, {Duration? recharge}) {
    final r = recharge ?? HarvestRules.recharge;
    if (charges >= HarvestRules.maxCharges) return HarvestRules.maxCharges;
    final gained = now.difference(at).inSeconds ~/ r.inSeconds;
    return math.min(HarvestRules.maxCharges, charges + math.max(0, gained));
  }

  /// 다음 하나가 차기까지 (가득이면 null)
  Duration? untilNext(DateTime now, {Duration? recharge}) {
    final r = recharge ?? HarvestRules.recharge;
    if (current(now, recharge: r) >= HarvestRules.maxCharges) return null;
    final passed = now.difference(at).inSeconds % r.inSeconds;
    return Duration(seconds: r.inSeconds - passed);
  }

  /// 하나 쓴 뒤
  SpotCharge use(DateTime now, {Duration? recharge}) {
    final r = recharge ?? HarvestRules.recharge;
    final c = current(now, recharge: r);
    if (c >= HarvestRules.maxCharges) return SpotCharge(charges: c - 1, at: now);
    // 차오르는 시계는 이어서 간다
    final gained = now.difference(at).inSeconds ~/ r.inSeconds;
    final from = at.add(r * gained);
    return SpotCharge(charges: c - 1, at: from);
  }

  Map<String, dynamic> toJson() => {'c': charges, 'at': at.toIso8601String()};

  static SpotCharge? fromJson(Object? j) {
    if (j is! Map) return null;
    final at = DateTime.tryParse(j['at'] as String? ?? '');
    if (at == null) return null;
    return SpotCharge(charges: (j['c'] as num?)?.toInt() ?? 0, at: at);
  }
}

/// 채집 규칙 (11-11 제안서 4 확정)
class HarvestRules {
  HarvestRules._();

  /// 250m 칸마다 한 자리 (11-11 #83: 500m → 250m. 전국 같은 규칙, 날마다 바뀌지 않는다)
  static const double blockM = 250;

  /// 이만큼 가까이 가야 채집 (11-11 #83: 40m → 80m)
  static const double reachM = 80;

  /// 둘레에서 찾는 거리 (지도에는 1km 안만 그린다)
  static const double radiusM = 2000;
  static const double mapRadiusM = 1000;

  /// 자리마다 3번, 2시간마다 하나씩 다시 찬다
  static const int maxCharges = 3;
  static const Duration recharge = Duration(hours: 2);

  /// 도구 내구도 (미니게임 한 번에 1). 돌 도구 기준.
  static const int toolMax = 30;

  /// 등급별 최대 내구도
  static int toolMaxFor(ToolTier t) => switch (t) {
        ToolTier.stone => 30,
        ToolTier.iron => 45,
        ToolTier.silver => 60,
        ToolTier.mithril => 80,
      };

  /// 다음 등급으로 만드는 재료와 금화 (대장간: 곡괭이·도끼, 공방: 낫·낚싯대·붓)
  static ({Map<MaterialId, int> mats, int gold})? upgradeCost(ToolTier now) =>
      switch (now) {
        ToolTier.stone => (mats: {MaterialId.ironIngot: 2}, gold: 200),
        ToolTier.iron => (
            mats: {MaterialId.ironIngot: 2, MaterialId.manaOre: 2},
            gold: 500
          ),
        ToolTier.silver => (
            mats: {
              MaterialId.roughGem: 3,
              MaterialId.manaOre: 3,
              MaterialId.labyrinthCore: 1,
            },
            gold: 1200
          ),
        ToolTier.mithril => null,
      };

  /// 등급이 높을수록 귀한 재료 확률 + (숨김)
  static const double rarePerTier = 0.03;

  /// 완벽을 이어 갈수록 귀한 재료 확률 + (숨김, 5번까지, 끊기면 처음부터)
  static const double rarePerStreak = 0.02;
  static const int maxStreak = 5;

  /// 한 종류에서 완벽을 이만큼 쌓으면 빠른 채집도 「좋음」 (숨김)
  static const int masteryPerfects = 10;

  /// 도구 속성과 같은 속성의 귀한 재료는 더 잘 나온다 (숨김)
  static const double elementBoost = 1.5;

  /// 고대 유물 이야기 (묶음 13 C8: 보류. 실제 유산 연동·가상 이야기 모두 정해지면 채운다)
  static const List<String> relicLore = [];

  /// 묶음 28 #181: 새로 시작한 사람에게 채집 자리가 열리는 레벨
  static int openLevel(HarvestKind k) => switch (k) {
        HarvestKind.flower || HarvestKind.mushroom => 5,
        HarvestKind.herb => 7,
        HarvestKind.ore || HarvestKind.gem => 8,
        HarvestKind.wood || HarvestKind.water => 9,
        HarvestKind.relic => 10,
      };

  /// 고대 유물 예언 조각 (글귀, 정령 한마디). 처음 세 번 캘 때 차례로 (2막 설정)
  static const List<(String, String)> prophecy = [
    ('저편의 빛이 다하는 날, 그 나라의 왕이 일어서리라.',
        '이 글씨… 저쪽 세계 글자야. 뭔가 더 있을 것 같아.'),
    ('왕은 잿빛을 두르고, 빛이 남은 세계의 문을 두드리리라.',
        '잿빛… 그 잿빛 틈이랑 같은 색이야. 설마…'),
    ('문이 깨지고 두 세계가 겹칠 때, 사람들은 그를 잿빛 군주라 부르리라.',
        '잿빛 군주… 문을 깬 게 저쪽 세계의 왕이었다니…'),
  ];

  /// 도구 수리: 금화 30 + 재료 1
  static const int repairGold = 30;

  /// 귀한 재료 확률: 빠른 채집 · 좋음 · 완벽
  static const double rareQuick = 0.05;
  static const double rareGood = 0.15;
  static const double rarePerfect = 0.35;

  /// 미니게임은 멈춰 있을 때만 (최근 10초 동안 시속 2km 아래)
  static const double stillSpeedMps = 2 / 3.6;
  static const Duration stillFor = Duration(seconds: 10);

  static const double lakeNearM = 500;

  static const List<HarvestKindInfo> all = [
    // 11-11 #83 채집 2: 새 자리 4종
    HarvestKindInfo(HarvestKind.mushroom, '버섯 군락', MaterialId.shadeMushroom,
        MaterialId.moonMushroom, HarvestTool.sickle, '약초 낫', '독버섯 피해 고르기',
        '먹을 수 있는 버섯만 세 개 골라요. 점박이 독버섯은 피해요!'),
    HarvestKindInfo(HarvestKind.flower, '꽃밭', MaterialId.springPetal,
        MaterialId.sunPollen, HarvestTool.sickle, '약초 낫', '잎 안 다치게 따기',
        '흔들리는 꽃이 가운데에 왔을 때 눌러요. 세 번!'),
    HarvestKindInfo(HarvestKind.gem, '보석 광맥', MaterialId.roughGem,
        MaterialId.gemLight, HarvestTool.pickaxe, '곡괭이', '금 따라 깎기',
        '빛나는 금을 차례대로 눌러 원석을 떼어 내요.'),
    HarvestKindInfo(HarvestKind.relic, '고대 유물', MaterialId.ancientShard,
        MaterialId.relicSeal, HarvestTool.brush, '붓', '붓으로 흙 털기',
        '화면을 문질러 흙을 털어요. 시간 안에 많이!'),
    HarvestKindInfo(HarvestKind.herb, '약초 덤불', MaterialId.herb,
        MaterialId.dewHerb, HarvestTool.sickle, '약초 낫', '타이밍 뽑기',
        '오가는 바늘이 초록 칸에 오면 눌러요. 세 번!'),
    HarvestKindInfo(HarvestKind.ore, '광석 바위', MaterialId.ironShard,
        MaterialId.manaOre, HarvestTool.pickaxe, '곡괭이', '약한 곳 두드리기',
        '5초 동안 빛나는 금을 눌러 바위를 깨요.'),
    HarvestKindInfo(HarvestKind.wood, '쓰러진 나무', MaterialId.twig,
        MaterialId.sturdyKnot, HarvestTool.axe, '도끼', '톱질 맞추기',
        '누른 채 기다리다 표시에 닿으면 손을 떼요. 세 번!'),
    HarvestKindInfo(HarvestKind.water, '물가', MaterialId.waterJelly,
        MaterialId.riverPearl, HarvestTool.rod, '낚싯대', '찌 당기기',
        '찌가 가라앉으면 바로 누르고, 줄이 끊기지 않게 눌러 잡아요.'),
  ];

  static HarvestKindInfo info(HarvestKind k) => all.firstWhere((i) => i.kind == k);

  // ───────────── 묶음 46 #233: 미니게임 손맛 (숨은 값)

  /// 버섯 고르기에 금빛 버섯이 나올 확률 (고르면 귀한 재료 꼭)
  static const double goldMushroom = 0.12;

  /// 꽃 따기 바람 세기 (판마다 흔들림 한 번 걸리는 시간, 평균은 예전 1.3초와 같게)
  static const List<int> flowerWindMs = [1000, 1300, 1600];

  /// 물가: 시작할 때 귀한 재료(큰 물고기 그림자)가 걸릴 확률 (좋음 판정과 같은 몫 + 도구 등급)
  static double waterRareChance(int tier) => rareGood + tier * rarePerTier;

  /// 결과 연출 길이 (눌러서 넘길 수 있음)
  static const Duration resultFx = Duration(milliseconds: 1000);

  /// 도구의 대표 자리 (도구 이름·아이콘에 쓴다)
  static HarvestKindInfo ofTool(HarvestTool t) => switch (t) {
        HarvestTool.sickle => info(HarvestKind.herb),
        HarvestTool.pickaxe => info(HarvestKind.ore),
        HarvestTool.axe => info(HarvestKind.wood),
        HarvestTool.rod => info(HarvestKind.water),
        HarvestTool.brush => info(HarvestKind.relic),
      };

  static String toolName(HarvestTool t) => ofTool(t).toolName;

  /// 고칠 때 드는 재료
  static MaterialId repairMaterial(HarvestTool t) => switch (t) {
        HarvestTool.sickle => MaterialId.herb,
        HarvestTool.pickaxe => MaterialId.ironShard,
        HarvestTool.axe => MaterialId.ironShard,
        HarvestTool.rod => MaterialId.twig,
        HarvestTool.brush => MaterialId.twig,
      };

  /// 계절 꽃잎 (3~5월 봄, 6~8월 여름, 9~11월 가을, 겨울)
  static MaterialId seasonPetal(int month) => switch (month) {
        3 || 4 || 5 => MaterialId.springPetal,
        6 || 7 || 8 => MaterialId.summerPetal,
        9 || 10 || 11 => MaterialId.autumnPetal,
        _ => MaterialId.winterPetal,
      };

  /// 받는 재료. 기본 재료(1~2)는 늘 나오고, 결과에 따라 더 받는다.
  /// [tier] 도구 등급, [streak] 완벽 연속, [element] 도구 속성 (모두 숨김)
  static Map<MaterialId, int> yieldOf(
      HarvestKind kind, HarvestGrade grade, math.Random rng,
      {double factor = 1,
      ToolTier tier = ToolTier.stone,
      int streak = 0,
      Element? element,
      int month = 1,
      bool? forceRare,
      LandKind? land,
      bool night = false}) {
    final i = info(kind);
    var base = 1 + rng.nextInt(2);
    base += switch (grade) {
      HarvestGrade.good => 1,
      HarvestGrade.perfect => 2,
      _ => 0,
    };
    var rareChance = switch (grade) {
          HarvestGrade.quick || HarvestGrade.fail => rareQuick,
          HarvestGrade.good => rareGood,
          HarvestGrade.perfect => rarePerfect,
        } +
        tier.index * rarePerTier +
        math.min(streak, maxStreak) * rarePerStreak;
    final baseMat = switch (kind) {
      HarvestKind.mushroom =>
        rng.nextBool() ? MaterialId.shadeMushroom : MaterialId.poisonMushroom,
      HarvestKind.flower => seasonPetal(month),
      // 묶음 67 #273: 약초 덤불은 장소 · 시간에 따라 이세계 약초
      HarvestKind.herb => herbAt(land, night, rng),
      _ => i.base,
    };
    final rare = switch (kind) {
      HarvestKind.flower => element == Element.light
          ? MaterialId.sunPollen
          : element == Element.wind
              ? MaterialId.breezeBloom
              : (rng.nextBool() ? MaterialId.sunPollen : MaterialId.breezeBloom),
      HarvestKind.gem => Materials.elementGem(
          element != null && rng.nextDouble() < 0.6
              ? element
              : Element.values[rng.nextInt(Element.values.length)]),
      _ => i.rare,
    };
    if (element != null && Materials.elementOf(rare) == element) {
      rareChance *= elementBoost;
    }
    final out = <MaterialId, int>{baseMat: math.max(1, (base * factor).floor())};
    // 묶음 46 #233: 미니게임이 정한 귀한 재료 (금빛 버섯 · 큰 물고기 그림자) — true 꼭 · false 없음
    final hit = rng.nextDouble() < rareChance * factor;
    if (forceRare ?? hit) out[rare] = 1;
    // 묶음 67: 만드라고라 뿌리는 어느 약초 덤불이든 가끔 (이슬 맺힌 약초와 따로)
    if (kind == HarvestKind.herb && rng.nextDouble() < mandragoraChance * factor) {
      out[MaterialId.mandragora] = (out[MaterialId.mandragora] ?? 0) + 1;
    }
    return out;
  }

  // ───────────── 묶음 67 #273: 이세계 약초

  static const double mandragoraChance = 0.05;

  /// 밤엔 어디서나 덤불의 절반쯤이 녹티 풀
  static const double noctiShare = 0.5;

  /// 마을 · 공원: 엘라린 잎 6 : 고르트 뿌리 4
  static const double gortShare = 0.4;

  /// 장소 · 시간에 맞는 약초 (장소를 모르면 엘라린 잎)
  static MaterialId herbAt(LandKind? land, bool night, math.Random rng) {
    if (night && rng.nextDouble() < noctiShare) return MaterialId.noctiGrass;
    return switch (land) {
      LandKind.forest => MaterialId.silvaFern,
      LandKind.water || LandKind.sea => MaterialId.mireaGrass,
      LandKind.mountain => MaterialId.zephiraLeaf,
      LandKind.village || LandKind.park || LandKind.city => rng.nextDouble() < gortShare ? MaterialId.gortRoot : MaterialId.herb,
      null => MaterialId.herb,
    };
  }

  /// [center] 둘레의 채집 자리. 칸마다 같은 자리라 누구에게나 같다.
  static List<HarvestSpot> spotsAround(
    GeoPoint center, {
    double radiusM = radiusM,
    RoadMask? roads,
    ExclusionIndex? exclusions,
    List<GamePlace> places = const [],
    bool Function(GeoPoint)? excluded,
    double density = 1,
    bool night = false,
    LandKind? Function(GeoPoint)? land,
  }) {
    final out = <HarvestSpot>[];
    const blockLat = blockM / 111320;
    final south = center.lat - radiusM / 111320, north = center.lat + radiusM / 111320;
    final lakes = [
      for (final p in places)
        if (p.kind == PlaceKind.spiritLake) p.point,
    ];
    for (var r = (south / blockLat).floor(); r <= (north / blockLat).floor(); r++) {
      final rowLat = (r + 0.5) * blockLat;
      final blockLng = blockM / (111320 * math.cos(rowLat * math.pi / 180));
      final dLng = radiusM / (111320 * math.cos(center.lat * math.pi / 180));
      for (var c = ((center.lng - dLng) / blockLng).floor();
          c <= ((center.lng + dLng) / blockLng).floor();
          c++) {
        final s0 = r * blockLat, w0 = c * blockLng;
        final mid = GeoPoint(s0 + blockLat / 2, w0 + blockLng / 2);
        if (mid.distanceTo(center) > radiusM) continue;
        final rng = math.Random(_hash('harvest|$r|$c'));
        GeoPoint? p;
        for (var t = 0; t < 6; t++) {
          final q = GeoPoint(
              s0 + rng.nextDouble() * blockLat, w0 + rng.nextDouble() * blockLng);
          if ((roads?.isRoad(q) ?? false) ||
              (exclusions?.contains(q) ?? false) ||
              (excluded?.call(q) ?? false)) {
            continue;
          }
          p = q;
          break;
        }
        if (p == null) continue;
        final roll = rng.nextDouble();
        final nearLake = lakes.any((l) => l.distanceTo(p!) <= lakeNearM);
        // 묶음 13 C7: 실제 장소 종류(OSM 격자)에 맞춰. 격자가 없으면 예전처럼 고르게
        final here = land?.call(p);
        final kind = nearLake
            ? HarvestKind.water
            : here == null
                ? kindOf(roll, night: night)
                : kindAt(here, roll, rng.nextDouble(), night: night);
        out.add(HarvestSpot(id: 'h${r}_$c', kind: kind, point: p));
        // 유인 물약 (11-11 #74): 칸마다 [density]-1 확률로 한 자리 더
        if (density > 1) {
          final lr = math.Random(_hash('lure|$r|$c'));
          if (lr.nextDouble() < density - 1) {
            for (var t = 0; t < 6; t++) {
              final q = GeoPoint(s0 + lr.nextDouble() * blockLat,
                  w0 + lr.nextDouble() * blockLng);
              if ((roads?.isRoad(q) ?? false) ||
                  (exclusions?.contains(q) ?? false) ||
                  (excluded?.call(q) ?? false)) {
                continue;
              }
              final k2 = lr.nextDouble() < 0.5 ? HarvestKind.herb : HarvestKind.wood;
              out.add(HarvestSpot(id: 'h${r}_${c}L', kind: k2, point: q));
              break;
            }
          }
        }
      }
    }
    return out;
  }

  /// 자리 종류 (11-11 #83). 실제 장소 판정(#81 배경 자료)이 들어오면 장소에 맞는
  /// 종류가 주로 나오게 바꾼다. 지금은 어디서나 섞여 나온다.
  /// 밤에는 약초 덤불 일부가 버섯 군락이 된다.
  static HarvestKind kindOf(double roll, {bool night = false}) {
    const water = 0.08, herb = 0.24, wood = 0.18, ore = 0.16;
    const mushroom = 0.14, flower = 0.12, gem = 0.05;
    var x = roll;
    if (x < water) return HarvestKind.water;
    x -= water;
    if (x < herb) {
      // 밤: 약초 덤불의 절반이 버섯으로
      return night && x < herb / 2 ? HarvestKind.mushroom : HarvestKind.herb;
    }
    x -= herb;
    if (x < wood) return HarvestKind.wood;
    x -= wood;
    if (x < ore) return HarvestKind.ore;
    x -= ore;
    if (x < mushroom) return HarvestKind.mushroom;
    x -= mushroom;
    if (x < flower) return HarvestKind.flower;
    x -= flower;
    if (x < gem) return HarvestKind.gem;
    return HarvestKind.relic; // 나머지 3%: 문화재 자료가 들어오면 그 근처로
  }

  /// 장소 종류에 맞는 채집 자리 (묶음 13 C7). 어느 장소든 가끔(약 15%)은 다른 종류,
  /// 고대 유물은 어디서나 드물게 (예전과 같은 3%).
  static const double otherChance = 0.15;

  static HarvestKind kindAt(LandKind land, double roll, double roll2,
      {bool night = false}) {
    if (roll < 0.03) return HarvestKind.relic;
    if (roll < 0.03 + otherChance) {
      final k = kindOf(roll2, night: night);
      return k == HarvestKind.relic ? HarvestKind.herb : k;
    }
    // 이 장소의 몫: roll2 로 고른다 (가중치는 숨김)
    final table = switch (land) {
      LandKind.park || LandKind.forest => const [
          (HarvestKind.herb, 3),
          (HarvestKind.wood, 3),
          (HarvestKind.mushroom, 2),
          (HarvestKind.flower, 2),
        ],
      LandKind.water => const [(HarvestKind.water, 3), (HarvestKind.flower, 1)],
      LandKind.sea => const [(HarvestKind.water, 1)],
      LandKind.city => const [(HarvestKind.ore, 9), (HarvestKind.gem, 1)],
      LandKind.mountain => const [
          (HarvestKind.ore, 3),
          (HarvestKind.wood, 3),
          (HarvestKind.herb, 3),
          (HarvestKind.gem, 1),
        ],
      LandKind.village => const [
          (HarvestKind.herb, 1),
          (HarvestKind.flower, 1),
          (HarvestKind.wood, 1),
        ],
    };
    final total = table.fold<int>(0, (a, e) => a + e.$2);
    var x = roll2 * total;
    for (final (k, w) in table) {
      if (x < w) {
        // 밤: 약초 덤불의 절반이 버섯으로 (예전 규칙)
        if (k == HarvestKind.herb && night && x < w / 2) return HarvestKind.mushroom;
        return k;
      }
      x -= w;
    }
    return table.last.$1;
  }

  static bool isNight(DateTime t) => t.hour >= 19 || t.hour < 6;

  static int _hash(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }
}
