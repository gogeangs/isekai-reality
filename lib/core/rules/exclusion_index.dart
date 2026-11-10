import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import '../geo/geo.dart';

/// 전국 제외 구역 (학교·유치원·병원·묘지 둘레) 색인 (11-10).
///
/// tool/build_exclusions.py 가 OpenStreetMap 자료로 만들어
/// assets/data/exclusions.json 에 둔다. 한 곳은 (위도, 경도, 반경 m) 원 하나.
/// 몬스터·전투를 두지 않고, 그 안에서는 몬스터를 만나지 않는다.
class ExclusionIndex {
  ExclusionIndex(List<(double, double, double)> zones) {
    for (final z in zones) {
      final key = _key(z.$1, z.$2);
      (_buckets[key] ??= []).add(z);
    }
    count = zones.length;
  }

  /// 칸 크기 (도). 반경이 칸보다 작아서 둘레 9칸만 보면 된다.
  static const double _bucket = 0.01;

  final Map<int, List<(double, double, double)>> _buckets = {};
  late final int count;

  static int _key(double lat, double lng) =>
      (lat / _bucket).floor() * 100000 + (lng / _bucket).floor();

  /// json: {"data": base64( [int32 위도×1e5, int32 경도×1e5, uint16 반경m] × n, little-endian )}
  factory ExclusionIndex.fromJson(Map<String, dynamic> j) {
    final bytes = base64Decode(j['data'] as String);
    final view = ByteData.sublistView(Uint8List.fromList(bytes));
    final zones = <(double, double, double)>[];
    for (var o = 0; o + 10 <= bytes.length; o += 10) {
      zones.add((
        view.getInt32(o, Endian.little) / 1e5,
        view.getInt32(o + 4, Endian.little) / 1e5,
        view.getUint16(o + 8, Endian.little).toDouble(),
      ));
    }
    return ExclusionIndex(zones);
  }

  static ExclusionIndex? tryParse(String raw) {
    try {
      return ExclusionIndex.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  bool contains(GeoPoint p) {
    final r0 = (p.lat / _bucket).floor();
    final c0 = (p.lng / _bucket).floor();
    final cosLat = math.cos(p.lat * math.pi / 180);
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        final list = _buckets[(r0 + dr) * 100000 + (c0 + dc)];
        if (list == null) continue;
        for (final z in list) {
          final dy = (p.lat - z.$1) * 111320;
          final dx = (p.lng - z.$2) * 111320 * cosLat;
          if (dx * dx + dy * dy <= z.$3 * z.$3) return true;
        }
      }
    }
    return false;
  }
}
