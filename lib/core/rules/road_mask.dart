import 'dart:convert';

import '../geo/geo.dart';

/// 큰길(왕복 차도)과 철로 둘레를 표시한 격자.
/// 필드 몬스터가 차도·철로 위에 나오지 않게 할 때 쓴다.
///
/// tool/build_road_mask.py 가 OpenStreetMap 자료로 만들어
/// assets/data/road_mask.json 에 둔다 (20m 칸, 1비트).
class RoadMask {
  RoadMask({
    required this.south,
    required this.west,
    required this.latStep,
    required this.lngStep,
    required this.rows,
    required this.cols,
    required List<int> bits,
  }) : _bits = bits;

  final double south;
  final double west;
  final double latStep;
  final double lngStep;
  final int rows;
  final int cols;
  final List<int> _bits;

  factory RoadMask.fromJson(Map<String, dynamic> j) => RoadMask(
        south: (j['south'] as num).toDouble(),
        west: (j['west'] as num).toDouble(),
        latStep: (j['latStep'] as num).toDouble(),
        lngStep: (j['lngStep'] as num).toDouble(),
        rows: j['rows'] as int,
        cols: j['cols'] as int,
        bits: base64Decode(j['bits'] as String),
      );

  static RoadMask? tryParse(String raw) {
    try {
      return RoadMask.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// [p] 가 큰길·철로 둘레인지 (격자 밖이면 false)
  bool isRoad(GeoPoint p) {
    final r = ((p.lat - south) / latStep).floor();
    final c = ((p.lng - west) / lngStep).floor();
    if (r < 0 || c < 0 || r >= rows || c >= cols) return false;
    final i = r * cols + c;
    final byte = i >> 3;
    if (byte >= _bits.length) return false;
    return (_bits[byte] >> (i & 7)) & 1 == 1;
  }
}
