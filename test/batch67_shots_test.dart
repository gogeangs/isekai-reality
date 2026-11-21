// 묶음 67 (build/screenshots/b67_*)
// 작은 iPhone(SE) · 큰 iPhone · Android

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/features/alchemy/alchemy_screen.dart';
import 'package:isekai_reality/features/map/map_screen.dart';
import 'package:isekai_reality/features/town/bag_tab.dart';
import 'package:isekai_reality/features/village/building_upgrade.dart';
import 'package:isekai_reality/features/village/npc_request.dart';
import 'package:isekai_reality/theme/ornaments.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'batch52_test.dart' as b52;
import 'batch56_test.dart' as b56;
import 'batch54_test.dart' as b54;
import 'support/npc_seed.dart';


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
  File('build/screenshots/b67_$name.png')
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


const _herbs = {'herb': 4, 'gortRoot': 3, 'silvaFern': 2, 'mireaGrass': 2, 'zephiraLeaf': 1, 'noctiGrass': 2, 'mandragora': 1, 'slimeJelly': 3};

void main() {
  setUpAll(_loadFonts);
  setUp(() => b56.now = b52.t0);

  for (final d in _devices) {
    final n = d.$1;

    testWidgets('b67 $n: 지도 「새 몬스터가 나타났어요!」', (tester) async {
      _device(tester, d);
      var now = DateTime.utc(2026, 11, 20, 6, 59, 40); // KST 15:59:40
      late AppController c;
      await tester.runAsync(() async => c = await startNpc(level: 12, clock: () => now));
      await _page(tester, Scaffold(body: MapScreen(key: ObjectKey('m$n'), controller: c)));
      await _shot(tester, '${n}_01_지도_바뀌기전');
      now = DateTime.utc(2026, 11, 20, 7, 0, 5);
      await tester.pump(const Duration(seconds: 30));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('새 몬스터가 나타났어요!'), findsOneWidget);
      await _shot(tester, '${n}_02_새몬스터_띠');
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('b67 $n: 거래소 고치기 창 ★2 · ★3', (tester) async {
      _device(tester, d);
      for (final (star, k) in [(1, '03_거래소_2성고치기'), (2, '04_거래소_3성고치기')]) {
        late AppController c;
        await tester.runAsync(() async {
          b54.now = DateTime(2026, 11, 20, 10);
          c = await b54.start(b54.rich(stars: {'market': star}));
        });
        await _page(tester, Scaffold(
            body: Builder(builder: (ctx) => Center(child: TextButton(onPressed: () => showBuildingSheet(ctx, c, Building.market), child: const Text('열기'))))));
        await tester.tap(find.text('열기'));
        await _settle(tester, 6);
        await _shot(tester, '${n}_$k');
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('b67 $n: 약초 7종 — 가방 · 레시피 책 · 부탁에 섞어 내기', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async => c = await startNpc(level: 12, mats: _herbs, npc: {
            'points': {'marta': 10},
            'small': {
              'marta': {'i': 1, 'day': '2026-11-16', 'base': <String, int>{}, 'steps': 0},
            },
          }));
      await _page(tester, Scaffold(body: NightBackground(child: BagTab(key: ObjectKey('bag$n'), controller: c))));
      await _shot(tester, '${n}_05_가방_약초묶음');
      await _page(tester, AlchemyScreen(key: ObjectKey('a$n'), controller: c));
      await tester.tap(find.text('레시피').first);
      await _settle(tester);
      await _shot(tester, '${n}_06_레시피_잘맞는약초');
      await _page(tester, Scaffold(body: Builder(builder: (ctx) => Center(child: TextButton(onPressed: () => showNpcRequestSheet(ctx, c, Npc.marta, kind: AskKind.small), child: const Text('열기'))))));
      await tester.tap(find.text('열기'));
      await _settle(tester, 6);
      await _shot(tester, '${n}_07_부탁_아무약초');
      await tester.pumpWidget(const SizedBox());
    });
  }
}
