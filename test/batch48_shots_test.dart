// 묶음 48 #230: 약초밭 화면 미리보기 (build/screenshots/b48_*)
// 작은 iPhone(SE) · 큰 iPhone · Android

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/garden_state.dart';
import 'package:isekai_reality/features/village/garden_screen.dart';

import 'package:isekai_reality/features/village/village_screen.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'support/npc_seed.dart';
import 'support/village_seed.dart';

final _root = GlobalKey();

Future<void> _loadFonts() async {
  final korean = FontLoader('Roboto');
  for (final f in [
    'NanumGothic-Regular',
    'NanumGothic-Bold',
    'NanumGothic-ExtraBold',
  ]) {
    korean.addFont(File('test/fonts/$f.ttf')
        .readAsBytes()
        .then((b) => ByteData.view(b.buffer)));
  }
  await korean.load();
  final manifest =
      jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final family in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(family['family'] as String);
    for (final font in (family['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      final image = element.widget as Image;
      await precacheImage(image.image, element, onError: (_, __) {});
    }
  });
  await tester.pump();
  for (var i = 0; i < 2; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 400)));
    await tester.pump();
  }
  final boundary =
      tester.renderObject(find.byKey(_root)) as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.5);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  File('build/screenshots/b48_$name.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!);
}

/// (이름, 화면 픽셀, 배율, 위·아래 여백(픽셀))
const _devices = [
  ('SE', Size(750, 1334), 2.0, 40.0, 0.0),
  ('큰iPhone', Size(1290, 2796), 3.0, 177.0, 102.0),
  ('Android', Size(1080, 2400), 2.625, 63.0, 63.0),
];

void _device(WidgetTester tester, (String, Size, double, double, double) d,
    {double text = 1}) {
  tester.platformDispatcher.textScaleFactorTestValue = text;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  tester.view.physicalSize = d.$2;
  tester.view.devicePixelRatio = d.$3;
  tester.view.padding = FakeViewPadding(top: d.$4, bottom: d.$5);
  tester.view.viewPadding = FakeViewPadding(top: d.$4, bottom: d.$5);
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester, [int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}


Future<void> _page(WidgetTester tester, Widget home) async {
  await tester.pumpWidget(RepaintBoundary(
    key: _root,
    child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => TopNoticeHost(child: child!),
        home: home),
  ));
  await _settle(tester);
}

/// 마을 그림을 왼쪽 끝(약초밭 쪽)까지 끈다
Future<void> _toLeft(WidgetTester tester) async {
  await tester.drag(find.byKey(const Key('villageScroll')), const Offset(1200, 0));
  await _settle(tester, 3);
}

Map<String, dynamic> _plots(Map<int, (String, String)> m) => GardenState(plots: {
      for (final e in m.entries)
        e.key: GardenPlot(seed: e.value.$1, day: e.value.$2, steps: 0),
    }).toJson();

void main() {
  setUpAll(_loadFonts);

  for (final d in _devices) {
    final n = d.$1;

    testWidgets('b48 $n: 마을 약초밭 공사 Lv.6·7·8 · Lv.9 완공 연출', (tester) async {
      _device(tester, d);
      for (final lv in const [6, 7, 8]) {
        late AppController c;
        await tester.runAsync(() async => c = await startVillage(lv,
            village: {'seen': ['intro', 'v43', 'v44', 'v48']}));
        await _page(tester, Scaffold(body: VillageScreen(key: ObjectKey(c), controller: c)));
        await _toLeft(tester);
        await _shot(tester, '${n}_01_Lv${lv}_공사');
      }
      late AppController c;
      await tester.runAsync(() async => c = await startVillage(9, village: {
            'seen': ['intro', 'v43', 'v44', 'v48', 'built:smithy', 'built:board', 'built:alchemy'],
          }));
      await tester.pumpWidget(RepaintBoundary(
        key: _root,
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            builder: (context, child) => TopNoticeHost(child: child!),
            home: Scaffold(body: VillageScreen(key: ObjectKey(c), controller: c))),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await _shot(tester, '${n}_02_Lv9_완공연출');
      await tester.pump(const Duration(seconds: 3));
      await _settle(tester);
      await _shot(tester, '${n}_03_Lv9_완공뒤');
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('b48 $n: 약초밭 화면 · 씨앗 고르기', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async => c = await startNpc(
            level: 10,
            mats: const {'herbSeed': 3, 'flowerSeed': 1, 'sporeSeed': 2, 'glowSeed': 1},
            todaySteps: const {'2026-11-16': 2600},
            json: {
              'garden': _plots({
                0: ('herbSeed', '2026-11-15'),
                1: ('flowerSeed', '2026-11-15'),
                2: ('glowSeed', '2026-11-15'),
              }),
            },
          ));
      await _page(tester, GardenScreen(key: ObjectKey(c), controller: c));
      await _shot(tester, '${n}_04_약초밭');
      await tester.tap(find.byKey(const Key('gardenHarvest_0')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await _settle(tester);
      await _shot(tester, '${n}_05_거둔뒤');
      await tester.tap(find.byKey(const Key('gardenPlant_0')));
      await _settle(tester);
      await _shot(tester, '${n}_06_씨앗고르기');
      await tester.tap(find.byKey(const Key('plantSeed_sporeSeed')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await _settle(tester);
      await _shot(tester, '${n}_07_심은뒤');
      await tester.pump(const Duration(seconds: 9));
    });
  }
}
