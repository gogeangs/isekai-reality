import 'dart:math' as math;
import 'dart:typed_data';

import 'geo.dart';

/// 전국 길 조각 (11-11 #42).
///
/// tool/build_route_tiles.py 가 OpenStreetMap 자료로 만든다.
/// 조각 하나는 위도 0.045° × 경도 0.05625° (약 5km × 5km), 10m 칸 500 × 500.
/// 칸마다 1바이트: [walk] 걸을 수 있는 길, [bigRoad] 큰 차도, [rail] 철로.
class RouteTiles {
  RouteTiles._();

  static const double originLat = 33.0;
  static const double originLng = 124.0;
  static const double tileLat = 0.045;
  static const double tileLng = 0.05625;
  static const int cells = 500;
  static const double cellLat = tileLat / cells;
  static const double cellLng = tileLng / cells;

  static const int walk = 1;
  static const int bigRoad = 2;
  static const int rail = 4;

  /// 전국 칸 좌표 (행, 열)
  static (int, int) cellOf(GeoPoint p) => (
        ((p.lat - originLat) / cellLat).floor(),
        ((p.lng - originLng) / cellLng).floor(),
      );

  /// 칸 가운데 점
  static GeoPoint pointOf(int row, int col) => GeoPoint(
      originLat + (row + 0.5) * cellLat, originLng + (col + 0.5) * cellLng);

  /// 조각 이름 "행_열"
  static String keyOf(int tileRow, int tileCol) => '${tileRow}_$tileCol';

  static (int, int) tileOfCell(int row, int col) =>
      (row ~/ cells, col ~/ cells);
}

/// 받아 둔 조각에서 칸 값을 읽는다. 없는 조각의 칸은 0 (길 없음).
class RouteGrid {
  RouteGrid(this.tiles);

  /// "행_열" → 500×500 바이트
  final Map<String, Uint8List> tiles;

  int at(int row, int col) {
    final t = tiles[RouteTiles.keyOf(
        row ~/ RouteTiles.cells, col ~/ RouteTiles.cells)];
    if (t == null) return 0;
    final i = (row % RouteTiles.cells) * RouteTiles.cells +
        col % RouteTiles.cells;
    return i < t.length ? t[i] : 0;
  }

  bool walkable(int row, int col) => at(row, col) & RouteTiles.walk != 0;

  /// 조각 이름들 (두 점을 둘러싼 네모 + 여유)
  static Set<String> tilesAround(GeoPoint a, GeoPoint b, {double marginM = 600}) {
    final dLat = marginM / 111320.0;
    final dLng = marginM / (111320.0 * math.cos(a.lat * math.pi / 180));
    final s = math.min(a.lat, b.lat) - dLat, n = math.max(a.lat, b.lat) + dLat;
    final w = math.min(a.lng, b.lng) - dLng, e = math.max(a.lng, b.lng) + dLng;
    final r0 = ((s - RouteTiles.originLat) / RouteTiles.tileLat).floor();
    final r1 = ((n - RouteTiles.originLat) / RouteTiles.tileLat).floor();
    final c0 = ((w - RouteTiles.originLng) / RouteTiles.tileLng).floor();
    final c1 = ((e - RouteTiles.originLng) / RouteTiles.tileLng).floor();
    return {
      for (var r = r0; r <= r1; r++)
        for (var c = c0; c <= c1; c++) RouteTiles.keyOf(r, c),
    };
  }

  /// [p] 에서 가장 가까운 길 칸 ([maxM] 미터 안). 없으면 null.
  (int, int)? nearestWalkable(GeoPoint p, {double maxM = 150}) {
    final (r0, c0) = RouteTiles.cellOf(p);
    if (walkable(r0, c0)) return (r0, c0);
    final maxRing = (maxM / 10).ceil();
    for (var k = 1; k <= maxRing; k++) {
      (int, int)? best;
      var bestD = double.infinity;
      for (var dr = -k; dr <= k; dr++) {
        for (var dc = -k; dc <= k; dc++) {
          if (dr.abs() != k && dc.abs() != k) continue;
          final r = r0 + dr, c = c0 + dc;
          if (!walkable(r, c)) continue;
          final d = (dr * dr + dc * dc).toDouble();
          if (d < bestD) {
            bestD = d;
            best = (r, c);
          }
        }
      }
      if (best != null) return best;
    }
    return null;
  }
}

/// 원정 길: 걸어가는 길 + (물 위 몬스터면) 날아가는 끝 구간
class ExpeditionRoute {
  const ExpeditionRoute(this.points, {this.followsRoads = true});

  /// 직선 (길 조각이 없거나 길이 이어지지 않을 때)
  factory ExpeditionRoute.straight(GeoPoint a, GeoPoint b) =>
      ExpeditionRoute([a, b], followsRoads: false);

  final List<GeoPoint> points;
  final bool followsRoads;

  double get lengthM {
    var d = 0.0;
    for (var i = 1; i < points.length; i++) {
      d += points[i - 1].distanceTo(points[i]);
    }
    return d;
  }
}

/// 길찾기 (A*, 8방향). 휴대폰에서 돈다.
class RouteFinder {
  RouteFinder._();

  /// 길 거리가 직선의 이 배수를 넘으면 직선으로
  static const double maxDetour = 3.0;

  /// 출발점이 길에서 이만큼 떨어져 있으면 직선으로
  static const double snapStartM = 150;

  /// 몬스터가 길에서 이만큼 안이면 길 끝에서 걸어간다 (그보다 멀면 물가에서 날아간다)
  static const double flyFromShoreM = 1500;

  static ExpeditionRoute find(RouteGrid grid, GeoPoint from, GeoPoint to) {
    final straight = from.distanceTo(to);
    final fallback = ExpeditionRoute.straight(from, to);
    if (straight < 30) return fallback;
    final start = grid.nearestWalkable(from, maxM: snapStartM);
    final goal = grid.nearestWalkable(to, maxM: flyFromShoreM);
    if (start == null || goal == null) return fallback;

    final cells = _astar(grid, start, goal, maxLenM: straight * maxDetour);
    if (cells == null) return fallback;
    final path = _simplify([
      from,
      for (final (r, c) in cells) RouteTiles.pointOf(r, c),
      to,
    ]);
    final route = ExpeditionRoute(path);
    if (route.lengthM > straight * maxDetour) return fallback;
    return route;
  }

  static List<(int, int)>? _astar(
      RouteGrid grid, (int, int) start, (int, int) goal,
      {required double maxLenM}) {
    if (start == goal) return [start];
    // 경도 칸이 위도 칸보다 약간 넓다 → 미터 단위 가중치
    final midLat = RouteTiles.pointOf(start.$1, start.$2).lat;
    const wLat = RouteTiles.cellLat * 111320.0;
    final wLng = RouteTiles.cellLng * 111320.0 * math.cos(midLat * math.pi / 180);
    final wDiag = math.sqrt(wLat * wLat + wLng * wLng);

    double h(int r, int c) {
      final dy = (r - goal.$1).abs() * wLat;
      final dx = (c - goal.$2).abs() * wLng;
      return math.sqrt(dx * dx + dy * dy);
    }

    // 찾는 범위: 두 점 둘레 네모 + 여유 (너무 넓게 돌지 않게)
    final pad = (maxLenM / 2 / 10).ceil() + 20;
    final rMin = math.min(start.$1, goal.$1) - pad;
    final rMax = math.max(start.$1, goal.$1) + pad;
    final cMin = math.min(start.$2, goal.$2) - pad;
    final cMax = math.max(start.$2, goal.$2) + pad;
    final width = cMax - cMin + 1;
    final height = rMax - rMin + 1;
    if (width * height > 2500000) return null;
    int idx(int r, int c) => (r - rMin) * width + (c - cMin);

    final g = Float64List(width * height)..fillRange(0, width * height, double.infinity);
    final came = Int32List(width * height)..fillRange(0, width * height, -1);
    final closed = Uint8List(width * height);
    final heap = _Heap();
    final s = idx(start.$1, start.$2);
    g[s] = 0;
    heap.push(h(start.$1, start.$2), s);
    final goalIdx = idx(goal.$1, goal.$2);
    var expanded = 0;

    while (heap.isNotEmpty) {
      final cur = heap.pop();
      if (closed[cur] == 1) continue;
      closed[cur] = 1;
      if (cur == goalIdx) break;
      if (++expanded > 400000) return null;
      final r = cur ~/ width + rMin, c = cur % width + cMin;
      for (var dr = -1; dr <= 1; dr++) {
        for (var dc = -1; dc <= 1; dc++) {
          if (dr == 0 && dc == 0) continue;
          final nr = r + dr, nc = c + dc;
          if (nr < rMin || nr > rMax || nc < cMin || nc > cMax) continue;
          if (!grid.walkable(nr, nc)) continue;
          final n = idx(nr, nc);
          if (closed[n] == 1) continue;
          final step = dr == 0 ? wLng : (dc == 0 ? wLat : wDiag);
          final ng = g[cur] + step;
          if (ng > maxLenM) continue;
          if (ng < g[n]) {
            g[n] = ng;
            came[n] = cur;
            heap.push(ng + h(nr, nc), n);
          }
        }
      }
    }
    if (closed[goalIdx] != 1) return null;
    final out = <(int, int)>[];
    for (var i = goalIdx; i != -1; i = came[i]) {
      out.add((i ~/ width + rMin, i % width + cMin));
    }
    return out.reversed.toList();
  }

  /// 거의 곧은 점들을 줄인다 (Douglas–Peucker, 6m)
  static List<GeoPoint> _simplify(List<GeoPoint> pts, {double tolM = 6}) {
    if (pts.length <= 2) return pts;
    final keep = List<bool>.filled(pts.length, false);
    keep[0] = keep[pts.length - 1] = true;
    final stack = <(int, int)>[(0, pts.length - 1)];
    final lat0 = pts.first.lat * math.pi / 180;
    double x(GeoPoint p) => p.lng * 111320.0 * math.cos(lat0);
    double y(GeoPoint p) => p.lat * 111320.0;
    while (stack.isNotEmpty) {
      final (a, b) = stack.removeLast();
      final ax = x(pts[a]), ay = y(pts[a]), bx = x(pts[b]), by = y(pts[b]);
      final dx = bx - ax, dy = by - ay;
      final len2 = dx * dx + dy * dy;
      var worst = -1.0;
      var wi = -1;
      for (var i = a + 1; i < b; i++) {
        final px = x(pts[i]) - ax, py = y(pts[i]) - ay;
        double d;
        if (len2 == 0) {
          d = math.sqrt(px * px + py * py);
        } else {
          final t = ((px * dx + py * dy) / len2).clamp(0.0, 1.0);
          final ex = px - t * dx, ey = py - t * dy;
          d = math.sqrt(ex * ex + ey * ey);
        }
        if (d > worst) {
          worst = d;
          wi = i;
        }
      }
      if (worst > tolM && wi > 0) {
        keep[wi] = true;
        stack
          ..add((a, wi))
          ..add((wi, b));
      }
    }
    return [for (var i = 0; i < pts.length; i++) if (keep[i]) pts[i]];
  }
}

/// 작은 최소 힙 (우선순위, 값)
class _Heap {
  final _k = <double>[];
  final _v = <int>[];

  bool get isNotEmpty => _k.isNotEmpty;

  void push(double k, int v) {
    _k.add(k);
    _v.add(v);
    var i = _k.length - 1;
    while (i > 0) {
      final p = (i - 1) >> 1;
      if (_k[p] <= _k[i]) break;
      _swap(i, p);
      i = p;
    }
  }

  int pop() {
    final top = _v[0];
    final lastK = _k.removeLast(), lastV = _v.removeLast();
    if (_k.isNotEmpty) {
      _k[0] = lastK;
      _v[0] = lastV;
      var i = 0;
      final n = _k.length;
      while (true) {
        final l = 2 * i + 1, r = l + 1;
        var m = i;
        if (l < n && _k[l] < _k[m]) m = l;
        if (r < n && _k[r] < _k[m]) m = r;
        if (m == i) break;
        _swap(i, m);
        i = m;
      }
    }
    return top;
  }

  void _swap(int a, int b) {
    final k = _k[a];
    _k[a] = _k[b];
    _k[b] = k;
    final v = _v[a];
    _v[a] = _v[b];
    _v[b] = v;
  }
}
