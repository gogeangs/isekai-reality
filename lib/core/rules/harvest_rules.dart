import 'dart:math' as math;

import '../geo/geo.dart';
import 'exclusion_index.dart';
import 'exploration_rules.dart';
import 'materials.dart';
import 'road_mask.dart';

/// 채집 자리 종류 (11-11 #56). 이름은 저장 기록의 키라 바꾸지 않는다.
enum HarvestKind { herb, ore, wood, water }

/// 채집 도구 (자리 종류마다 하나)
enum HarvestTool { sickle, pickaxe, axe, rod }

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

  /// 지도 그림 (있는 그림만 쓸 수 있다)
  String get mapAsset => 'assets/images/mat_${base.name}.png';
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

  /// 지금 남은 횟수
  int current(DateTime now) {
    if (charges >= HarvestRules.maxCharges) return HarvestRules.maxCharges;
    final gained = now.difference(at).inSeconds ~/ HarvestRules.recharge.inSeconds;
    return math.min(HarvestRules.maxCharges, charges + math.max(0, gained));
  }

  /// 다음 하나가 차기까지 (가득이면 null)
  Duration? untilNext(DateTime now) {
    if (current(now) >= HarvestRules.maxCharges) return null;
    final passed = now.difference(at).inSeconds % HarvestRules.recharge.inSeconds;
    return Duration(seconds: HarvestRules.recharge.inSeconds - passed);
  }

  /// 하나 쓴 뒤
  SpotCharge use(DateTime now) {
    final c = current(now);
    if (c >= HarvestRules.maxCharges) return SpotCharge(charges: c - 1, at: now);
    // 차오르는 시계는 이어서 간다
    final gained = now.difference(at).inSeconds ~/ HarvestRules.recharge.inSeconds;
    final from = at.add(HarvestRules.recharge * gained);
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

  /// 500m 칸마다 한 자리 (전국 같은 규칙, 날마다 바뀌지 않는다)
  static const double blockM = 500;

  /// 이만큼 가까이 가야 채집
  static const double reachM = 40;

  /// 지도에 보이는 거리
  static const double radiusM = 3000;

  /// 자리마다 3번, 2시간마다 하나씩 다시 찬다
  static const int maxCharges = 3;
  static const Duration recharge = Duration(hours: 2);

  /// 도구 내구도 (미니게임 한 번에 1)
  static const int toolMax = 30;

  /// 도구 수리: 금화 30 + 재료 1
  static const int repairGold = 30;

  /// 귀한 재료 확률: 빠른 채집 · 좋음 · 완벽
  static const double rareQuick = 0.05;
  static const double rareGood = 0.15;
  static const double rarePerfect = 0.35;

  /// 미니게임은 멈춰 있을 때만 (최근 10초 동안 시속 2km 아래)
  static const double stillSpeedMps = 2 / 3.6;
  static const Duration stillFor = Duration(seconds: 10);

  /// 물가: 호수 근처가 아니면 칸의 10%가 작은 샘
  static const double springShare = 0.10;
  static const double lakeNearM = 500;

  static const List<HarvestKindInfo> all = [
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

  static HarvestKindInfo ofTool(HarvestTool t) => all.firstWhere((i) => i.tool == t);

  static String toolName(HarvestTool t) => ofTool(t).toolName;

  /// 대장간에서 고치는 도구 (나머지는 연금술 공방)
  static bool smithyTool(HarvestTool t) =>
      t == HarvestTool.pickaxe || t == HarvestTool.axe;

  /// 고칠 때 드는 재료
  static MaterialId repairMaterial(HarvestTool t) => switch (t) {
        HarvestTool.sickle => MaterialId.herb,
        HarvestTool.pickaxe => MaterialId.ironShard,
        HarvestTool.axe => MaterialId.ironShard,
        HarvestTool.rod => MaterialId.twig,
      };

  static HarvestKind? parseKind(String? s) {
    for (final k in HarvestKind.values) {
      if (k.name == s) return k;
    }
    return null;
  }

  static HarvestTool? parseTool(String? s) {
    for (final t in HarvestTool.values) {
      if (t.name == s) return t;
    }
    return null;
  }

  /// 받는 재료. 기본 재료(1~2)는 늘 나오고, 결과에 따라 더 받는다.
  static Map<MaterialId, int> yieldOf(
      HarvestKind kind, HarvestGrade grade, math.Random rng,
      {double factor = 1}) {
    final i = info(kind);
    var base = 1 + rng.nextInt(2);
    base += switch (grade) {
      HarvestGrade.good => 1,
      HarvestGrade.perfect => 2,
      _ => 0,
    };
    final rareChance = switch (grade) {
      HarvestGrade.quick || HarvestGrade.fail => rareQuick,
      HarvestGrade.good => rareGood,
      HarvestGrade.perfect => rarePerfect,
    };
    final out = <MaterialId, int>{i.base: math.max(1, (base * factor).floor())};
    if (rng.nextDouble() < rareChance * factor) out[i.rare] = 1;
    return out;
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
        final kind = nearLake || roll < springShare
            ? HarvestKind.water
            : roll < springShare + 0.36
                ? HarvestKind.herb
                : roll < springShare + 0.36 + 0.27
                    ? HarvestKind.wood
                    : HarvestKind.ore;
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

  static int _hash(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }
}
