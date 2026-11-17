// 묶음 51 #242·#229: 주점·리안·거래소 화면 미리보기 (build/screenshots/b51_*)
// 작은 iPhone(SE) · 큰 iPhone · Android

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/features/village/tavern_screen.dart';
import 'package:isekai_reality/features/village/village_screen.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'batch51_test.dart' as b51;

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
  File('build/screenshots/b51_$name.png')
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

    testWidgets('b51 $n: 만남 장면 · 주점 · 거래소 · 마을', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async => c = await b51.start(b51.account()));
      await _page(tester, MeetScreen(key: ObjectKey('m$n'), controller: c));
      await tester.pump(const Duration(seconds: 3));
      await _shot(tester, '${n}_01_만남_불빛');
      await tester.tapAt(const Offset(100, 200));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      await _shot(tester, '${n}_02_만남_리안');
      for (var k = 0; k < 4; k++) {
        await tester.tapAt(const Offset(100, 200));
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
      }
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      await _shot(tester, '${n}_03_만남_마지막');
      await tester.runAsync(() async => c.markMeetSeen());
      await _page(
          tester,
          Scaffold(
              key: ObjectKey('v$n'),
              body: VillageScreen(controller: c)));
      await tester.pump(const Duration(milliseconds: 500));
      await _shot(tester, '${n}_04_마을_거래소완공');
      await tester.drag(find.byKey(const Key('villageScroll')), const Offset(600, 0));
      await tester.pump(const Duration(seconds: 2));
      await _shot(tester, '${n}_05_마을_주점');
      await _page(tester, TavernScreen(key: ObjectKey('t$n'), controller: c));
      await _shot(tester, '${n}_06_주점');
      await tester.tap(find.byKey(const Key('tavernHear')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await _settle(tester, 3);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
      await _settle(tester, 3);
      await _shot(tester, '${n}_07_주점_소문_식사');
      await _page(tester, MarketScreen(key: ObjectKey('k$n'), controller: c));
      await _shot(tester, '${n}_08_거래소_바르칸');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 9));
    });
  }
}
