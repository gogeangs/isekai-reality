// 개발용: 지도 화면 · 탭 옮기기에서 컨트롤러 알림 · 프레임 수를 잰다 (flutter test test/tool/perf_probe.dart).
// CI 대상 아님. 옛 커밋(묶음 81 · 82 · 83)에서도 돌도록 공개 API만 씀.
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/geo/geo.dart';

import '../batch50_test.dart' as b50;
import '../support/village_seed.dart';

void main() {
  testWidgets('perf probe', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    late AppController c;
    await tester.runAsync(() async {
      b50.now = b50.am.add(const Duration(minutes: 5));
      c = await startVillage(24, farewell: true, clock: () => b50.now, more: {
        'jobs': {'awakened': true, 'v57': true, 'v31': true, 'main': 'warrior', 'owned': ['warrior']},
      });
    });
    var notes = 0;
    c.addListener(() => notes++);
    var frames = 0;
    SchedulerBinding.instance.addPersistentFrameCallback((_) => frames++);
    await tester.pumpWidget(IsekaiRealityApp(controller: c));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.runAsync(() async {
      await c.handleFix(const LocationFix(point: b50.home));
    });
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // ignore: avoid_print
    print('PROBE texts ${find.byType(Text).evaluate().take(30).map((e) => (e.widget as Text).data).toList()}');
    // 지도에 가만히 10초
    notes = 0;
    frames = 0;
    final sw = Stopwatch()..start();
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // ignore: avoid_print
    print('PROBE idle10s notes=$notes frames=$frames cpu=${sw.elapsedMilliseconds}ms');
    // 탭 옮기기 (아래 탭 글자를 차례로)
    notes = 0;
    frames = 0;
    sw.reset();
    for (final t in ['상태', '마을', '지도', '상태', '지도']) {
      final f = find.text(t);
      if (f.evaluate().isEmpty) continue;
      await tester.tap(f.last, warnIfMissed: false);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
    // ignore: avoid_print
    print('PROBE tabs notes=$notes frames=$frames cpu=${sw.elapsedMilliseconds}ms');
    // 지도에서 1초마다 위치가 바뀌며 30초 걷기
    final mapTab = find.text('지도');
    if (mapTab.evaluate().isNotEmpty) await tester.tap(mapTab.last, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 500));
    notes = 0;
    frames = 0;
    var pumpMs = 0;
    var fixMs = 0;
    for (var k = 0; k < 30; k++) {
      final f = Stopwatch()..start();
      await tester.runAsync(() async {
        b50.now = b50.now.add(const Duration(seconds: 1));
        await c.handleFix(LocationFix(point: GeoPoint(b50.home.lat + k * 0.0000125, b50.home.lng)));
      });
      fixMs += f.elapsedMilliseconds;
      for (var i = 0; i < 10; i++) {
        final p = Stopwatch()..start();
        await tester.pump(const Duration(milliseconds: 100));
        pumpMs += p.elapsedMilliseconds;
      }
    }
    // ignore: avoid_print
    print('PROBE walk30s notes=$notes frames=$frames pump=${pumpMs}ms fix=${fixMs}ms');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
