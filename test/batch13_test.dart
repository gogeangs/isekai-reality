import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/core/geo/geo.dart';
import 'package:isekai_reality/core/rules/rules.dart';

void main() {
  group('C7 장소 종류 격자', () {
    final g = PlaceGrid.tryParse(
        File('test/fixtures/place_grid_small.bin').readAsBytesSync())!;
    GeoPoint at(int r, int c) =>
        GeoPoint(37.4 - (r + 0.5) * 0.001, 126.8 + (c + 0.5) * 0.001);

    test('칸마다 종류를 읽는다 (타일 경계 넘어도)', () {
      expect(g.kindAt(at(0, 0)), LandKind.village);
      expect(g.kindAt(at(15, 15)), LandKind.park);
      expect(g.kindAt(at(80, 120)), LandKind.sea);
      expect(g.kindAt(at(50, 120)), LandKind.city);
      expect(g.kindAt(at(99, 149)), LandKind.mountain);
      expect(g.kindAt(at(65, 70)), LandKind.village);
    });

    test('격자 밖은 null, 틀린 자료는 null', () {
      expect(g.kindAt(const GeoPoint(30, 120)), isNull);
      expect(PlaceGrid.tryParse(File('pubspec.yaml').readAsBytesSync()), isNull);
    });
  });

  group('C7 장소 종류별 채집 자리', () {
    test('공원·숲은 약초·나무·버섯·꽃, 도심은 광석·보석이 대부분', () {
      final rng = Random(1);
      int count(LandKind p, Set<HarvestKind> want) {
        var n = 0;
        for (var i = 0; i < 2000; i++) {
          if (want.contains(HarvestRules.kindAt(
              p, rng.nextDouble(), rng.nextDouble()))) {
            n++;
          }
        }
        return n;
      }

      expect(
          count(LandKind.park, {
            HarvestKind.herb,
            HarvestKind.wood,
            HarvestKind.mushroom,
            HarvestKind.flower
          }),
          greaterThan(1600));
      expect(count(LandKind.city, {HarvestKind.ore, HarvestKind.gem}),
          greaterThan(1600));
      expect(count(LandKind.sea, {HarvestKind.water}), greaterThan(1600));
    });
  });
}
