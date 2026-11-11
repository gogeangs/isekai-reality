import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/geo/geo.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/location/location_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/map/expedition_sheet.dart';
import 'package:isekai_reality/features/map/korea_area.dart';

class _Location implements LocationSource {
  final _c = StreamController<LocationFix>.broadcast();
  void emit(LocationFix f) => _c.add(f);
  @override
  Future<bool> requestPermission() async => true;
  @override
  Stream<LocationFix> fixes() => _c.stream;
}

void main() {
  test('지도 몬스터: 500m 블록으로 내 둘레가 촘촘해진다 (11-11 #80)', () {
    const here = GeoPoint(37.32, 126.83);
    final s = FieldMonsterRules.spawnsFor(KoreaArea.area, DateTime(2026, 11, 11),
        center: here);
    final near = s.where((x) => x.point.distanceTo(here) <= 1000).length;
    // 1km 블록 때는 1km 안에 2~3마리였다
    expect(near, greaterThanOrEqualTo(6));
  });

  testWidgets('원정 띠: 한 줄 → 누르면 펼침 → 다시 누르면 접힘 (11-11 #78)',
      (tester) async {
    final loc = _Location();
    final c = AppController(
      area: KoreaArea.area,
      store: InMemoryRecordStore(
        profile: const PlayerProfile(name: '하루'),
        history: [DailyRecord(date: DateTime(2026, 11, 10))],
      ),
      health: FakeHealthSource(stepsByDay: {'2026-11-11': 1000}),
      location: loc,
      clock: () => DateTime(2026, 11, 11, 14),
      random: Random(2),
      fallbackCenter: const GeoPoint(37.32, 126.83),
    );
    await tester.runAsync(() async {
      await c.init();
      loc.emit(const LocationFix(point: GeoPoint(37.32, 126.83), speedMps: 1));
      await Future<void>.delayed(Duration.zero);
    });
    final target = c.todaySpawns.first;
    late ExpeditionCheck sent;
    await tester.runAsync(() async => sent = await c.sendSpirit(target));
    expect(sent, ExpeditionCheck.ok);

    var open = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, set) => ExpeditionStrip(
            controller: c,
            open: open,
            onToggle: () => set(() => open = !open),
          ),
        ),
      ),
    ));
    expect(find.byKey(const Key('expeditionStrip')), findsOneWidget);
    expect(find.textContaining('가는 중'), findsOneWidget);
    await tester.tap(find.byKey(const Key('expeditionStrip')));
    await tester.pump();
    expect(find.byKey(const Key('expeditionOpen')), findsOneWidget);
    await tester.tap(find.byKey(const Key('expeditionOpen')));
    await tester.pump();
    expect(find.byKey(const Key('expeditionStrip')), findsOneWidget);
  });
}
