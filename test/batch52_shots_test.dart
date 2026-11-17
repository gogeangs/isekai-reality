// 묶음 52 #243: 3막 다리 너머 탐험 틀 미리보기 (build/screenshots/b52_*)
// 작은 iPhone(SE) · 큰 iPhone · Android

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/features/act3/act3_screen.dart';
import 'package:isekai_reality/features/act3/ally_screens.dart';
import 'package:isekai_reality/features/village/tavern_screen.dart';
import 'package:isekai_reality/features/village/village_screen.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'batch52_test.dart' as b52;

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
  File('build/screenshots/b52_$name.png')
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



void main() {
  setUpAll(_loadFonts);

  for (final d in _devices) {
    final n = d.$1;

    testWidgets('b52 $n: 다리 · 3막 지도 · 싸움 · 동료', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async => c = (await b52.start(b52.account())).$1);
      await _page(tester, Scaffold(key: ObjectKey('v$n'), body: VillageScreen(controller: c)));
      await tester.pump(const Duration(milliseconds: 500));
      await _shot(tester, '${n}_01_마을_빛의다리');
      await _page(tester, BridgeSceneScreen(key: ObjectKey('b$n'), controller: c));
      await tester.pump(const Duration(seconds: 3));
      await _shot(tester, '${n}_02_다리장면');
      await tester.runAsync(() async => c.openAct3());
      await _page(tester, Act3Screen(key: ObjectKey('a$n'), controller: c));
      await _shot(tester, '${n}_03_지역지도');
      await tester.tap(find.byKey(const Key('place_baldrin_ashplain')));
      await _settle(tester, 4);
      await _shot(tester, '${n}_04_잿빛들판');
      Navigator.of(tester.element(find.byKey(const Key('placeSheet_baldrin_ashplain')))).pop();
      await _settle(tester, 4);
      await _page(tester, Act3Screen(key: ObjectKey('j$n'), controller: c, tab: 1));
      await _shot(tester, '${n}_05_일지');
      await _page(tester, Act3Screen(key: ObjectKey('w$n'), controller: c, tab: 2));
      await _shot(tester, '${n}_06_세계');
      await _page(
          tester,
          Act3BattleScreen(
              key: ObjectKey('f$n'),
              controller: c,
              placeId: 'baldrin_ashplain',
              tickInterval: const Duration(milliseconds: 400)));
      await _settle(tester, 8);
      await _shot(tester, '${n}_07_싸움_동료');
      await tester.runAsync(() async => c.recruit());
      await _page(tester, TavernScreen(key: ObjectKey('t$n'), controller: c, allyTab: true));
      await _shot(tester, '${n}_08_주점_동료');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
      await _settle(tester, 3);
      await _shot(tester, '${n}_09_주점_모집');
      await _page(tester,
          AllyDetailScreen(key: ObjectKey('d$n'), controller: c, allyId: c.nameless.first.id));
      await _shot(tester, '${n}_10_동료_자세히');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
      await _settle(tester, 3);
      await _shot(tester, '${n}_11_동료_스킬');
      await _page(tester, AllyDetailScreen(key: ObjectKey('g$n'), controller: c, allyId: 'garen'));
      await _shot(tester, '${n}_12_가렌');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 9));
    });
  }
}
