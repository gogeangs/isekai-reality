import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/geo/geo.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/location/location_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/map/gojan_area.dart';

const area = GojanArea.area;
const jungang = GeoPoint(37.31596, 126.83864);

LocationFix walk(GeoPoint p) => LocationFix(point: p, speedMps: 1.3);

void main() {
  group('좌표와 칸', () {
    test('중앙역 ~ 고잔역은 약 1.4km', () {
      final d = jungang.distanceTo(const GeoPoint(37.3168, 126.8230));
      expect(d, greaterThan(1300));
      expect(d, lessThan(1500));
    });

    test('지역은 100m 칸으로 나뉘고, 지역 밖은 칸이 없다', () {
      expect(area.totalCells, greaterThan(500));
      expect(area.cellIdOf(jungang), isNotNull);
      expect(area.cellIdOf(const GeoPoint(37.5666, 126.9780)), isNull); // 서울시청
    });

    test('칸의 네 꼭짓점은 지역 안에 있다', () {
      final corners = area.cellCorners(area.cellIdOf(jungang)!);
      expect(corners, hasLength(4));
      for (final c in corners) {
        expect(area.bounds.contains(c), isTrue);
      }
    });
  });

  group('탐험 규칙', () {
    test('차를 타고 빠르게 움직이면 탐험으로 치지 않는다', () {
      expect(ExplorationRules.countsAsExploring(walk(jungang)), isTrue);
      expect(
          ExplorationRules.countsAsExploring(
              const LocationFix(point: jungang, speedMps: 12)),
          isFalse);
    });

    test('중앙역 근처에 가면 중앙 미궁 입구를 방문한다', () {
      final places = ExplorationRules.placesInReach(
          area, const GeoPoint(37.3163, 126.8389));
      expect(places.map((p) => p.id), contains('gate_jungang'));
    });

    test('제외 구역 안에서는 어떤 장소도 방문으로 치지 않는다', () {
      final zone = area.exclusionZones.first;
      expect(area.isExcluded(zone.center), isTrue);
      expect(ExplorationRules.placesInReach(area, zone.center), isEmpty);
    });

    test('제외 구역 안에는 장소를 두지 않는다', () {
      for (final place in area.places) {
        expect(area.isExcluded(place.point), isFalse, reason: place.realName);
      }
    });
  });

  group('탐험 기록', () {
    final now = DateTime(2026, 11, 8, 14);

    Future<AppController> start(FakeLocationSource location,
        {RecordStore? store}) async {
      final controller = AppController(
        store: store ?? InMemoryRecordStore(profile: const PlayerProfile(name: '하루')),
        health: FakeHealthSource(granted: false),
        location: location,
        clock: () => now,
      );
      await controller.init();
      return controller;
    }

    test('걸으면 안개가 걷히고 저장된다', () async {
      final store = InMemoryRecordStore(profile: const PlayerProfile(name: '하루'));
      final controller = await start(FakeLocationSource(), store: store);
      await controller.handleFix(walk(jungang));
      await controller.handleFix(walk(const GeoPoint(37.3175, 126.8386)));

      expect(controller.revealedCells.length, 2);
      expect(controller.revealedRatio, greaterThan(0));
      expect(await store.loadRevealedCells(area.id), hasLength(2));
    });

    test('처음 간 장소는 새 장소, 같은 날 다시 가도 한 번만 센다', () async {
      final controller = await start(FakeLocationSource());
      await controller.handleFix(walk(jungang));
      await controller.handleFix(walk(jungang));

      final today = controller.history.last;
      expect(today.newPlacesVisited, 1);
      expect(today.placesRevisited, 0);
      expect(today.visitedPlaceIds, ['gate_jungang']);
      expect(controller.lastDiscovery?.id, 'gate_jungang');
    });

    test('차로 지나가면 안개도 장소도 기록하지 않는다', () async {
      final controller = await start(FakeLocationSource());
      await controller.handleFix(
          const LocationFix(point: jungang, speedMps: 15));
      expect(controller.revealedCells, isEmpty);
      expect(controller.history.last.visitedPlaceIds, isEmpty);
    });

    test('위치 스트림이 들어오면 자동으로 처리된다', () async {
      final location = FakeLocationSource();
      final controller = await start(location);
      location.emit(walk(jungang));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(controller.revealedCells, isNotEmpty);
      controller.dispose();
    });
  });
}
