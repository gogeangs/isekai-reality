// 묶음 75 (build/screenshots/b75_*) — 큰 iPhone · SE

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
import 'package:isekai_reality/theme/top_notice.dart';

import 'batch52_test.dart' as b52;
import 'batch56_test.dart' as b56;
import 'support/village_seed.dart';

final _root = GlobalKey();

Future<void> _loadFonts() async {
  // 묶음 71: 글꼴을 정하지 않은 글자(버튼 등)는 시험 기본 글꼴(FlutterTest)로 그려져 □로 나옴 —
  // 기기처럼 한글이 보이게 그 이름에도 한글 글꼴을 넣는다
  for (final family in ['Roboto', 'FlutterTest']) {
    final korean = FontLoader(family);
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
  }
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
  File('build/screenshots/b75_$name.png')
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
        // 기기에선 글꼴을 정하지 않은 글자가 휴대폰 기본 글꼴(한글 있음)로 나옴 — 시험에서도 한글 글꼴로
        theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Roboto'),
        builder: (context, child) => TopNoticeHost(child: child!),
        home: home),
  ));
  await _settle(tester);
}





/// 연금술 계정 (가마솥 3 · 하나는 끓는 중)
Future<AppController> alchemyAccount({bool boiling = true}) => startVillage(14, more: {
      'alchemy': {
        'discovered': ['healSmall', 'heal', 'manaSmall', 'antidote', 'strength', 'resistFire', 'weaponFire'],
        'noted': ['clearEye'],
        'bestMade': ['healSmall'],
        'cauldrons': 3,
        'brews': {
          if (boiling)
            '1': {
              'put': ['herb', 'herb', 'slimeJelly'],
              'startedAt': vt0.subtract(const Duration(minutes: 4)).toIso8601String(),
              'readyAt': vt0.add(const Duration(minutes: 3)).toIso8601String()
            },
        },
      },
    }, gains: {
      MaterialId.herb.name: 6,
      MaterialId.gortRoot.name: 2,
      MaterialId.slimeJelly.name: 4,
      MaterialId.fireJelly.name: 2,
      MaterialId.batWing.name: 3,
      MaterialId.lightRelic.name: 1,
      MaterialId.ironShard.name: 5,
      MaterialId.ratHide.name: 2,
      MaterialId.springPetal.name: 2,
      'gold': 2000,
    });

/// 선반 재료를 눌러 넣고 (작은 화면은 내려서) 가마솥이 보이게 다시 올림
Future<void> _put(WidgetTester tester, String m) async {
  final f = find.byKey(Key('shelf_$m'));
  await tester.ensureVisible(f);
  await _settle(tester, 2);
  await tester.tap(f);
  await _settle(tester, 5);
  final pot = find.byKey(const Key('cauldronPot'));
  if (pot.evaluate().isNotEmpty) {
    await tester.drag(pot.first, const Offset(0, 900));
    await _settle(tester, 3);
  }
}

void main() {
  setUpAll(_loadFonts);
  setUp(() => b56.now = b52.t0);

  for (final d in [_devices[1], _devices[0]]) {
    final n = d.$1;

    testWidgets('b75 $n: 1 작업대', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async => c = await alchemyAccount());
      await _page(tester, AlchemyScreen(key: ObjectKey('al$n'), controller: c));
      await _shot(tester, '${n}_01_작업대_빈가마솥');
      await _put(tester, 'herb');
      await _put(tester, 'herb');
      await _shot(tester, '${n}_02_작업대_재료2개_레시피중간');
      await _put(tester, 'slimeJelly');
      await _shot(tester, '${n}_03_작업대_맞는레시피');
      await _put(tester, 'lightRelic');
      await _shot(tester, '${n}_04_작업대_특산물');
      await tester.tap(find.byKey(const Key('benchNext')).first);
      await _settle(tester, 6);
      await _shot(tester, '${n}_05_작업대_끓는중');
      await tester.tap(find.byKey(const Key('recipeOpen')));
      await _settle(tester, 4);
      await _shot(tester, '${n}_06_레시피창');
      await tester.tap(find.byKey(const Key('recipeTile_antidote')));
      await _settle(tester, 4);
      await _shot(tester, '${n}_07_레시피_상세');
      Navigator.of(tester.element(find.byKey(const Key('recipeFill')))).pop();
      await _settle(tester, 3);
      await tester.tap(find.byKey(const Key('recipeTile_healSmall')));
      await _settle(tester, 4);
      await tester.tap(find.byKey(const Key('recipeFill')));
      await _settle(tester, 10);
      await _shot(tester, '${n}_08_채우기_뒤');
      await tester.pumpWidget(const SizedBox());
    });
  }
}
