// 묶음 71: 길 자료가 있는 원정 시험 (ㄱ자 길 — 걷는 펫은 길 거리, 나는 펫은 직선)

import 'dart:async';
import 'dart:typed_data';

import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/geo/geo.dart';
import 'package:isekai_reality/core/geo/route_grid.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/models/pet_state.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/location/location_source.dart';
import 'package:isekai_reality/data/route/route_tile_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/map/korea_area.dart';

class SeedLocation implements LocationSource {
  final _c = StreamController<LocationFix>.broadcast();
  void emit(LocationFix f) => _c.add(f);
  @override
  Future<bool> requestPermission() async => true;
  @override
  Stream<LocationFix> fixes() => _c.stream;
}

/// ㄱ자 길 (조각 행 96 · 열 50): 출발 a → 모퉁이 → 몬스터 b
({Map<String, Uint8List> tiles, GeoPoint a, GeoPoint b}) lRoad() {
  const tr = 96, tc = 50;
  final cells = Uint8List(RouteTiles.cells * RouteTiles.cells);
  for (var c = 100; c <= 300; c++) {
    cells[100 * RouteTiles.cells + c] = RouteTiles.walk;
  }
  for (var r = 100; r <= 300; r++) {
    cells[r * RouteTiles.cells + 300] = RouteTiles.walk;
  }
  const r0 = tr * RouteTiles.cells, c0 = tc * RouteTiles.cells;
  return (
    tiles: {RouteTiles.keyOf(tr, tc): cells},
    a: RouteTiles.pointOf(r0 + 100, c0 + 100),
    b: RouteTiles.pointOf(r0 + 300, c0 + 300),
  );
}

/// 부엉이(나는 펫) · 다이어울프(걷는 펫)를 가진 Lv.16 계정, 길 자료 · 위치 · 몬스터 하나
Future<(AppController, FieldSpawn)> routedExpedition() async {
  final road = lRoad();
  final loc = SeedLocation();
  final born = DateTime(2026, 11, 1);
  final c = AppController(
    area: KoreaArea.area,
    store: InMemoryRecordStore(
      profile: const PlayerProfile(name: '하루'),
      history: [
        DailyRecord(date: DateTime(2026, 11, 10), gains: {'exp': LevelRules.totalExpToReach(16)}),
      ],
      json: {
        'tutorial': {'step': TutorialStep.done.index},
        'pets': PetState(
          farewellAt: born,
          pets: [
            Pet(uid: 'p1', species: PetSpecies.owl, name: '부엉', bornAt: born),
            Pet(uid: 'p2', species: PetSpecies.direwolf, name: '서리', bornAt: born),
          ],
          companion: 'p1',
          firstPet: 'p1',
          nextId: 3,
        ).toJson(),
      },
    ),
    health: FakeHealthSource(stepsByDay: const {}),
    location: loc,
    clock: () => DateTime(2026, 11, 11, 14),
    fallbackCenter: road.a,
  )
    ..mailSources = const []
    ..routeTiles = MemoryRouteTiles(road.tiles);
  await c.init();
  loc.emit(LocationFix(point: road.a, speedMps: 1));
  await Future<void>.delayed(Duration.zero);
  final spawn = FieldSpawn(id: 'road-test', monster: MonsterId.giantRat, point: road.b);
  await c.prepareRoute(spawn);
  return (c, spawn);
}
