import 'dart:math' as math;

import '../geo/geo.dart';
import 'exploration_rules.dart';
import 'monsters.dart';
import 'road_mask.dart';
import 'rule_constants.dart';

/// 지도에 나타난 필드 몬스터 하나
class FieldSpawn {
  const FieldSpawn({required this.id, required this.monster, required this.point});

  /// 하루 안에서 겹치지 않는 id (예: '2026-11-08#3')
  final String id;
  final MonsterId monster;
  final GeoPoint point;

  MonsterInfo get info => Monsters.info(monster);
}

class FieldMonsterRules {
  FieldMonsterRules._();

  /// 그날의 필드 몬스터. 날짜로 정해지므로 같은 날에는 누구에게나 같은 자리.
  ///
  /// - 장소마다 한 마리: 장소에서 80~150m 떨어진 곳, 장소에 맞는 몬스터
  /// - 지역을 1km 블록으로 나눠 블록마다 70% 확률로 한 마리:
  ///   잿빛 슬라임 또는 길 잃은 돌정령
  /// - 밤(오후 7시 ~ 새벽 5시)에는 블록 몬스터 중 다섯에 하나꼴로 그림자 나비가 된다
  /// - 제외 구역과 지역 밖, 큰길·철로 둘레에는 두지 않는다
  /// [roads] 가 있으면 큰길·철로 둘레에는 두지 않는다 (11-10).
  static List<FieldSpawn> spawnsFor(ExploreArea area, DateTime day,
      {RoadMask? roads}) {
    final key = '${day.year}-${day.month}-${day.day}';
    final rng = math.Random(_stableHash('${area.id}|$key'));
    final spawns = <FieldSpawn>[];

    GeoPoint? pick(GeoPoint Function() candidate) {
      for (var attempt = 0; attempt < 8; attempt++) {
        final p = candidate();
        if (area.bounds.contains(p) &&
            !area.isExcluded(p) &&
            !(roads?.isRoad(p) ?? false)) {
          return p;
        }
      }
      return null;
    }

    for (final place in area.places) {
      final p = pick(() => _offset(
            place.point,
            80 + rng.nextDouble() * 70,
            rng.nextDouble() * 2 * math.pi,
          ));
      if (p == null) continue;
      spawns.add(FieldSpawn(
        id: '$key#${spawns.length}',
        monster: _habitatMonster(place.kind),
        point: p,
      ));
    }

    const commons = [MonsterId.ashSlime, MonsterId.lostStoneSpirit];
    final b = area.bounds;
    final midLat = (b.south + b.north) / 2;
    const blockLat = RuleConstants.fieldSpawnBlockM / 111320;
    final blockLng = RuleConstants.fieldSpawnBlockM /
        (111320 * math.cos(midLat * math.pi / 180));
    final night = isNight(day);
    for (var lat = b.south; lat < b.north; lat += blockLat) {
      for (var lng = b.west; lng < b.east; lng += blockLng) {
        // 블록마다 같은 순서로 난수를 쓴다 (밤낮에 따라 자리가 바뀌지 않게)
        final roll = rng.nextDouble();
        final kind = rng.nextInt(commons.length);
        final butterflyRoll = rng.nextDouble();
        final s0 = lat, w0 = lng;
        final p = pick(() => GeoPoint(
              s0 + rng.nextDouble() * blockLat,
              w0 + rng.nextDouble() * blockLng,
            ));
        if (roll >= RuleConstants.fieldSpawnChance || p == null) continue;
        spawns.add(FieldSpawn(
          id: '$key#${spawns.length}',
          monster: night && butterflyRoll < nightButterflyShare
              ? MonsterId.shadowButterfly
              : commons[kind],
          point: p,
        ));
      }
    }
    return spawns;
  }

  /// 밤에 그림자 나비가 되는 블록 몬스터 비율
  static const double nightButterflyShare = 0.2;

  /// 그림자 나비가 나오는 시간 (오후 7시 ~ 새벽 5시)
  static bool isNight(DateTime t) => t.hour >= 19 || t.hour < 5;

  /// 지금 위치에서 만날 수 있는 가장 가까운 몬스터.
  /// 차량 속도로 움직이는 중이거나 제외 구역 안이면 없음.
  static FieldSpawn? encounter({
    required ExploreArea area,
    required List<FieldSpawn> spawns,
    required LocationFix fix,
  }) {
    if (!ExplorationRules.countsAsExploring(fix)) return null;
    if (area.isExcluded(fix.point)) return null;
    FieldSpawn? best;
    double? bestDistance;
    for (final s in spawns) {
      final d = s.point.distanceTo(fix.point);
      if (d > RuleConstants.fieldEncounterRadiusM) continue;
      if (bestDistance == null || d < bestDistance) {
        best = s;
        bestDistance = d;
      }
    }
    return best;
  }

  static MonsterId _habitatMonster(PlaceKind kind) => switch (kind) {
        PlaceKind.labyrinthGate => MonsterId.labyrinthBat,
        PlaceKind.spiritLake => MonsterId.roughWaterSpirit,
      };

  /// [from] 에서 [meters] 만큼 [bearing] 방향으로 옮긴 점 (짧은 거리용 근사)
  static GeoPoint _offset(GeoPoint from, double meters, double bearing) {
    final dLat = meters * math.cos(bearing) / 111320;
    final dLng = meters *
        math.sin(bearing) /
        (111320 * math.cos(from.lat * math.pi / 180));
    return GeoPoint(from.lat + dLat, from.lng + dLng);
  }

  /// 실행할 때마다 같은 값을 내는 문자열 해시 (FNV-1a 32비트)
  static int _stableHash(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }
}
