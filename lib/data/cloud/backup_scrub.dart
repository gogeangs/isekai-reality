import 'dart:convert';

/// 백업으로 올리는 기록에서 위치를 덜어 낸다 (묶음 54, 기획 11-17 결정).
/// 이 휴대폰의 기록은 그대로 두고, 서버로 보내는 스냅숏만 바꾼다.
///
/// - 빼기: 그날 첫 자리(json.nearAnchor) · 안내 핀(json.guidePins) · 하이랜드 섬 자리(json.highland 의 lat·lng,
///   돌아오면 섬 자리는 다시 정함)
/// - 칸 가운데로: 원정(vitals.v1 의 expeditions: 목적지 · 출발점 · 길 점) · 불러낸 몬스터(json.alchemy 의 called)
///   — 약 100m 칸의 가운데 점으로 바꿔 정확한 자리가 남지 않게
class BackupScrub {
  BackupScrub._();

  /// 칸 크기 (위도 0.0009° ≈ 100m, 경도 0.001125° ≈ 한국 위도에서 약 100m)
  static const double cellLat = 0.0009;
  static const double cellLng = 0.001125;

  static double _center(double v, double size) => ((v / size).floor() + 0.5) * size;

  /// (위도, 경도) → 그 칸 가운데
  static (double, double) cell(double lat, double lng) =>
      (_center(lat, cellLat), _center(lng, cellLng));

  static Map<String, Object> scrub(Map<String, Object> snap) {
    final out = <String, Object>{...snap};
    out.remove('json.nearAnchor');
    out.remove('json.guidePins');
    _edit(out, 'json.highland', (j) {
      if (j is Map) {
        j.remove('lat');
        j.remove('lng');
      }
      return j;
    });
    _edit(out, 'vitals.v1', (j) {
      if (j is Map) {
        for (final key in const ['expeditions', 'expedition']) {
          final v = j[key];
          if (v is List) {
            for (final e in v) {
              _expedition(e);
            }
          } else if (v is Map) {
            _expedition(v);
          }
        }
      }
      return j;
    });
    _edit(out, 'json.alchemy', (j) {
      if (j is Map && j['called'] is List) {
        for (final c in j['called'] as List) {
          if (c is Map) _point(c, 'lat', 'lng');
        }
      }
      return j;
    });
    return out;
  }

  static void _expedition(Object? e) {
    if (e is! Map) return;
    _point(e, 'lat', 'lng');
    _point(e, 'fromLat', 'fromLng');
    final r = e['route'];
    if (r is List) {
      final pts = <List<double>>[];
      for (final p in r) {
        if (p is List && p.length >= 2 && p[0] is num && p[1] is num) {
          final (a, b) = cell((p[0] as num).toDouble(), (p[1] as num).toDouble());
          // 같은 칸이 이어지면 하나로
          if (pts.isEmpty || pts.last[0] != a || pts.last[1] != b) pts.add([a, b]);
        }
      }
      e['route'] = pts;
    }
  }

  static void _point(Map m, String latKey, String lngKey) {
    final la = m[latKey], ln = m[lngKey];
    if (la is num && ln is num) {
      final (a, b) = cell(la.toDouble(), ln.toDouble());
      m[latKey] = a;
      m[lngKey] = b;
    }
  }

  static void _edit(Map<String, Object> out, String key, Object? Function(Object?) f) {
    final v = out[key];
    if (v is! String) return;
    try {
      out[key] = jsonEncode(f(jsonDecode(v)));
    } catch (_) {
      // 읽을 수 없는 값은 그대로
    }
  }
}
