import 'dart:math' as math;

/// 위도·경도 한 점. 지도 플러그인과 분리해 규칙에서 쓴다.
class GeoPoint {
  const GeoPoint(this.lat, this.lng);

  final double lat;
  final double lng;

  /// 두 점 사이 거리(미터), 하버사인 공식
  double distanceTo(GeoPoint other) {
    const earthRadius = 6371000.0;
    final dLat = _rad(other.lat - lat);
    final dLng = _rad(other.lng - lng);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat)) *
            math.cos(_rad(other.lat)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _rad(double deg) => deg * math.pi / 180;

  @override
  String toString() => 'GeoPoint($lat, $lng)';
}

/// 위치 측정 한 번의 결과
class LocationFix {
  const LocationFix({required this.point, this.speedMps = 0});

  final GeoPoint point;

  /// 이동 속도(m/s). 알 수 없으면 0.
  final double speedMps;
}

/// 사각형 영역 (남·서·북·동 경계)
class GeoBounds {
  const GeoBounds({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  final double south;
  final double west;
  final double north;
  final double east;

  bool contains(GeoPoint p) =>
      p.lat >= south && p.lat <= north && p.lng >= west && p.lng <= east;

  GeoPoint get center => GeoPoint((south + north) / 2, (west + east) / 2);
}
