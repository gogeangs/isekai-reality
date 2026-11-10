import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/core/geo/geo.dart';
import 'package:isekai_reality/core/geo/route_grid.dart';
import 'package:isekai_reality/core/models/vitals.dart';

/// 조각 하나(행 96, 열 50 근처 = 위도 37.32, 경도 126.81)에 ㄱ자 길을 그린다
({RouteGrid grid, GeoPoint a, GeoPoint b, GeoPoint corner}) _lGrid() {
  const tr = 96, tc = 50;
  final cells = Uint8List(RouteTiles.cells * RouteTiles.cells);
  // 가로 길: 100행, 100~300열 / 세로 길: 300열, 100~300행
  for (var c = 100; c <= 300; c++) {
    cells[100 * RouteTiles.cells + c] = RouteTiles.walk;
  }
  for (var r = 100; r <= 300; r++) {
    cells[r * RouteTiles.cells + 300] = RouteTiles.walk;
  }
  final grid = RouteGrid({RouteTiles.keyOf(tr, tc): cells});
  final r0 = tr * RouteTiles.cells, c0 = tc * RouteTiles.cells;
  return (
    grid: grid,
    a: RouteTiles.pointOf(r0 + 100, c0 + 100),
    b: RouteTiles.pointOf(r0 + 300, c0 + 300),
    corner: RouteTiles.pointOf(r0 + 100, c0 + 300),
  );
}

void main() {
  group('원정 길찾기 (11-11 #42)', () {
    test('길을 따라 ㄱ자로 간다 (직선보다 길다)', () {
      final g = _lGrid();
      final route = RouteFinder.find(g.grid, g.a, g.b);
      expect(route.followsRoads, isTrue);
      final straight = g.a.distanceTo(g.b);
      expect(route.lengthM, greaterThan(straight * 1.3));
      expect(route.lengthM, lessThan(straight * 1.5));
      // 모퉁이를 지난다
      expect(route.points.any((p) => p.distanceTo(g.corner) < 15), isTrue);
    });

    test('바다 위 몬스터: 길 끝까지 가서 남은 거리는 날아간다', () {
      final g = _lGrid();
      // 세로 길 끝에서 300m 더 동쪽(길 없음)
      final sea = GeoPoint(g.b.lat, g.b.lng + 300 / (111320.0 * 0.795));
      final route = RouteFinder.find(g.grid, g.a, sea);
      expect(route.followsRoads, isTrue);
      expect(route.points.last.lat, sea.lat);
    });

    test('조각이 없거나 길이 이어지지 않으면 직선', () {
      final g = _lGrid();
      final none = RouteFinder.find(RouteGrid({}), g.a, g.b);
      expect(none.followsRoads, isFalse);
      expect(none.points, hasLength(2));

      // 출발점이 길에서 멀다 (1km 북쪽)
      final far = GeoPoint(g.a.lat + 1000 / 111320.0, g.a.lng);
      expect(RouteFinder.find(g.grid, far, g.b).followsRoads, isFalse);
    });

    test('길 거리가 직선의 3배를 넘으면 직선', () {
      const tr = 96, tc = 50;
      final cells = Uint8List(RouteTiles.cells * RouteTiles.cells);
      // ㄷ자로 크게 돌아가는 길: (100,100)→(100,400)→(110,400)... 아니라
      // 두 점은 2칸 거리(행 100, 110)이지만 길은 400칸을 돌아간다
      for (var c = 100; c <= 300; c++) {
        cells[100 * RouteTiles.cells + c] = RouteTiles.walk;
        cells[110 * RouteTiles.cells + c] = RouteTiles.walk;
      }
      for (var r = 100; r <= 110; r++) {
        cells[r * RouteTiles.cells + 300] = RouteTiles.walk;
      }
      final grid = RouteGrid({RouteTiles.keyOf(tr, tc): cells});
      final r0 = tr * RouteTiles.cells, c0 = tc * RouteTiles.cells;
      final a = RouteTiles.pointOf(r0 + 100, c0 + 100);
      final b = RouteTiles.pointOf(r0 + 110, c0 + 100);
      expect(RouteFinder.find(grid, a, b).followsRoads, isFalse);
    });

    test('정령은 길을 따라 움직인다', () {
      const pts = [(0.0, 0.0), (0.0, 1.0), (1.0, 1.0)];
      final mid = Expedition.pointAlong(pts, 0.5);
      // 경도 보정(0.8) 때문에 첫 구간이 조금 짧다
      expect(mid.$2, 1.0);
      expect(mid.$1, closeTo(0.1, 0.01));
      expect(Expedition.pointAlong(pts, 0), (0.0, 0.0));
      expect(Expedition.pointAlong(pts, 1), (1.0, 1.0));
    });
  });
}
