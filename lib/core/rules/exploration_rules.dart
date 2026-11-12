import 'dart:math' as math;

import '../geo/geo.dart';

enum PlaceKind {
  /// 미궁 입구 (지하철역) — 던전 보상 1.5배
  labyrinthGate,

  /// 정령의 호수 (호수공원)
  spiritLake,
}

/// 지도 위 이세계 장소
class GamePlace {
  const GamePlace({
    required this.id,
    required this.name,
    required this.realName,
    required this.kind,
    required this.point,
    this.visitRadiusM = 60,
  });

  final String id;

  /// 이세계 이름 (예: 중앙 미궁 입구)
  final String name;

  /// 실제 장소 이름 (예: 안산 중앙역)
  final String realName;
  final PlaceKind kind;
  final GeoPoint point;

  /// 이 거리 안에 들어오면 방문으로 친다
  final double visitRadiusM;
}

/// 몬스터·전투·이벤트·장소를 두지 않는 곳 (제외 구역 원칙)
class ExclusionZone {
  const ExclusionZone({
    required this.name,
    required this.center,
    required this.radiusM,
  });

  final String name;
  final GeoPoint center;
  final double radiusM;

  bool contains(GeoPoint p) => center.distanceTo(p) <= radiusM;
}

/// 탐험 지역 (예: 안산시). 안개는 [cellSizeM] 칸 단위로 걷힌다.
class ExploreArea {
  const ExploreArea({
    required this.id,
    required this.name,
    required this.bounds,
    required this.places,
    required this.exclusionZones,
    this.cellSizeM = 100,
  });

  final String id;
  final String name;
  final GeoBounds bounds;
  final List<GamePlace> places;
  final List<ExclusionZone> exclusionZones;
  final double cellSizeM;

  // 위도 1도 ≈ 111,320m, 경도 1도 ≈ 111,320m × cos(위도)
  double get _cellLat => cellSizeM / 111320;
  double get _cellLng =>
      cellSizeM / (111320 * math.cos(bounds.center.lat * math.pi / 180));

  int get rows => ((bounds.north - bounds.south) / _cellLat).ceil();
  int get cols => ((bounds.east - bounds.west) / _cellLng).ceil();
  int get totalCells => rows * cols;

  /// 이 점이 속한 칸의 id ('행_열'). 지역 밖이면 null.
  String? cellIdOf(GeoPoint p) {
    if (!bounds.contains(p)) return null;
    final r = ((p.lat - bounds.south) / _cellLat).floor().clamp(0, rows - 1);
    final c = ((p.lng - bounds.west) / _cellLng).floor().clamp(0, cols - 1);
    return '${r}_$c';
  }

  /// 칸의 네 꼭짓점 (남서 → 남동 → 북동 → 북서)
  List<GeoPoint> cellCorners(String cellId) {
    final parts = cellId.split('_').map(int.parse).toList();
    final s = bounds.south + parts[0] * _cellLat;
    final w = bounds.west + parts[1] * _cellLng;
    final n = math.min(s + _cellLat, bounds.north);
    final e = math.min(w + _cellLng, bounds.east);
    return [GeoPoint(s, w), GeoPoint(s, e), GeoPoint(n, e), GeoPoint(n, w)];
  }

  bool isExcluded(GeoPoint p) => exclusionZones.any((z) => z.contains(p));
}

class ExplorationRules {
  ExplorationRules._();

  /// 이보다 빠르면(차량 등) 탐험으로 치지 않는다. 뛰는 속도까지는 인정.
  static const double maxExploreSpeedMps = 4.5;

  static bool countsAsExploring(LocationFix fix) =>
      fix.speedMps <= maxExploreSpeedMps;

  /// 이 위치에서 방문으로 칠 장소들 (제외 구역 안이면 없음)
  static List<GamePlace> placesInReach(ExploreArea area, GeoPoint p) {
    if (area.isExcluded(p)) return const [];
    return area.places
        .where((place) => place.point.distanceTo(p) <= place.visitRadiusM)
        .toList();
  }

}
