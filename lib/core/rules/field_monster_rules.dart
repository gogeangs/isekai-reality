import 'dart:math' as math;

import '../geo/geo.dart';
import 'exclusion_index.dart';
import 'exploration_rules.dart';
import 'modifier_rules.dart';
import 'monsters.dart';
import 'road_mask.dart';
import 'rule_constants.dart';

/// 지도에 나타난 필드 몬스터 하나
class FieldSpawn {
  const FieldSpawn({
    required this.id,
    required this.monster,
    required this.point,
    this.modifiers = const [],
  });

  /// 하루 안에서 겹치지 않는 id (예: '2026-11-08#3')
  final String id;
  final MonsterId monster;
  final GeoPoint point;

  /// 수식어 (11-10 #21). 자리마다 정해지고, 보는 사람의 레벨로 등급을 나눈다.
  final List<ModifierId> modifiers;

  MonsterInfo get info => Monsters.info(monster);

  /// 수식어를 붙인 이름
  String get name => ModifierRules.displayName(monster, modifiers);

  ModGrade get grade => ModifierRules.gradeOf(modifiers);
}

class FieldMonsterRules {
  FieldMonsterRules._();

  /// 그날의 필드 몬스터. 날짜로 정해지므로 같은 날에는 누구에게나 같은 자리.
  ///
  /// - 전국을 1km 블록으로 나눈 같은 격자를 쓴다 (11-10 전국 확대).
  ///   블록마다 70% 확률로 한 마리: 슬라임 또는 큰쥐.
  ///   블록마다 따로 난수를 쓰므로 어디서 보든 같은 블록에는 같은 몬스터.
  /// - [center] 가 있으면 그 둘레 [radiusM] 안 블록만, 없으면 지역 전체
  /// - 장소가 있는 지역이면 장소마다 한 마리 (장소에서 80~150m, 장소에 맞는 몬스터)
  /// - 밤(오후 7시 ~ 새벽 5시)에는 블록 몬스터 중 다섯에 하나꼴로 그림자 나비
  /// - 제외 구역([exclusions] 포함)과 지역 밖에는 두지 않는다.
  ///   [roads] 가 있으면 큰길·철로 둘레에도 두지 않는다.
  static List<FieldSpawn> spawnsFor(
    ExploreArea area,
    DateTime day, {
    GeoPoint? center,
    double radiusM = RuleConstants.fieldSpawnRadiusM,
    RoadMask? roads,
    ExclusionIndex? exclusions,
    int level = 1,
  }) {
    final key = '${day.year}-${day.month}-${day.day}';
    final spawns = <FieldSpawn>[];

    bool allowed(GeoPoint p) =>
        area.bounds.contains(p) &&
        !area.isExcluded(p) &&
        !(exclusions?.contains(p) ?? false) &&
        !(roads?.isRoad(p) ?? false);

    GeoPoint? pick(GeoPoint Function() candidate) {
      for (var attempt = 0; attempt < 8; attempt++) {
        final p = candidate();
        if (allowed(p)) return p;
      }
      return null;
    }

    for (final place in area.places) {
      if (center != null && place.point.distanceTo(center) > radiusM + 200) {
        continue;
      }
      final rng = math.Random(_stableHash('$key|${place.id}'));
      final p = pick(() => _offset(
            place.point,
            80 + rng.nextDouble() * 70,
            rng.nextDouble() * 2 * math.pi,
          ));
      if (p == null) continue;
      final id = '$key#${place.id}';
      final monster = _habitatMonster(place.kind);
      spawns.add(FieldSpawn(
        id: id,
        monster: monster,
        point: p,
        modifiers: ModifierRules.roll(id, monster, level),
      ));
    }

    // 11-10: 돌정령(정령계) 대신 큰쥐
    const commons = [MonsterId.ashSlime, MonsterId.giantRat];
    const blockLat = RuleConstants.fieldSpawnBlockM / 111320;
    final b = area.bounds;
    final double south, north;
    if (center == null) {
      south = b.south;
      north = b.north;
    } else {
      south = center.lat - radiusM / 111320;
      north = center.lat + radiusM / 111320;
    }
    final night = isNight(day);
    for (var r = (south / blockLat).floor();
        r <= (north / blockLat).floor();
        r++) {
      final rowLat = (r + 0.5) * blockLat;
      final blockLng = RuleConstants.fieldSpawnBlockM /
          (111320 * math.cos(rowLat * math.pi / 180));
      final double west, east;
      if (center == null) {
        west = b.west;
        east = b.east;
      } else {
        final dLng =
            radiusM / (111320 * math.cos(center.lat * math.pi / 180));
        west = center.lng - dLng;
        east = center.lng + dLng;
      }
      for (var c = (west / blockLng).floor();
          c <= (east / blockLng).floor();
          c++) {
        final s0 = r * blockLat, w0 = c * blockLng;
        if (center != null &&
            GeoPoint(s0 + blockLat / 2, w0 + blockLng / 2)
                    .distanceTo(center) >
                radiusM) {
          continue;
        }
        // 블록마다 같은 순서로 난수를 쓴다 (밤낮·보는 자리에 따라 바뀌지 않게)
        final rng = math.Random(_stableHash('$key|$r|$c'));
        final roll = rng.nextDouble();
        final kind = rng.nextInt(commons.length);
        final butterflyRoll = rng.nextDouble();
        if (roll >= RuleConstants.fieldSpawnChance) continue;
        final p = pick(() => GeoPoint(
              s0 + rng.nextDouble() * blockLat,
              w0 + rng.nextDouble() * blockLng,
            ));
        if (p == null) continue;
        final id = '$key#${r}_$c';
        final monster = night && butterflyRoll < nightButterflyShare
            ? MonsterId.shadowButterfly
            : commons[kind];
        spawns.add(FieldSpawn(
          id: id,
          monster: monster,
          point: p,
          modifiers: ModifierRules.roll(id, monster, level),
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
    ExclusionIndex? exclusions,
  }) {
    if (!ExplorationRules.countsAsExploring(fix)) return null;
    if (area.isExcluded(fix.point)) return null;
    if (exclusions?.contains(fix.point) ?? false) return null;
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
        // 물방울 정령(정령계)을 뺐다 (11-10)
        PlaceKind.spiritLake => MonsterId.ashSlime,
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
