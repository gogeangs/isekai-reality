// 묶음 62: 처리방침 3판 다시 동의 · 분신 그림 (build/screenshots/b62_*)
// 작은 iPhone(SE) · 큰 iPhone · Android

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/act5_state.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/act5/erbard_screens.dart';
import 'package:isekai_reality/features/legal/consent_screen.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'batch52_test.dart' as b52;
import 'batch56_test.dart' as b56;
import 'batch60_test.dart' as b60;
import 'support/fake_arca.dart';

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
  File('build/screenshots/b62_$name.png')
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
  setUp(() => b56.now = b52.t0);

  for (final d in _devices) {
    final n = d.$1;

    testWidgets('b62 $n: 처리방침 3판 다시 동의', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async {
        b56.now = DateTime(2026, 11, 18, 18);
        final r = await b56.start(login: false);
        await r.$1.store.saveJson('consent', {
          'docs': {for (final k in LegalKind.values) k.name: {'v': 2, 'at': '2026-11-18T10:00:00.000'}},
          'age14': '2026-11-17T10:00:00.000',
        });
        c = (await b56.start(login: false, store: r.$1.store as InMemoryRecordStore)).$1;
      });
      c.consentGate = true;
      await _page(tester, ConsentScreen(key: ObjectKey('c$n'), controller: c));
      await _shot(tester, '${n}_01_처리방침3판_다시동의');
    });

    testWidgets('b62 $n: 수비대 분신 (생산 · 히든 주 직업)', (tester) async {
      _device(tester, d);
      late AppController c;
      late FakeArca a;
      await tester.runAsync(() async {
        (c, a) = await b60.act5(
            guild: true,
            state: const Act5State(opened: true, chapter: 3, seen: {'e1a', 'e1b', 'e1c', 'e2a', 'e2b'}, ticketAt: -14000, pioneered: true, ch3Siege: 0));
        a.siegeOwners['sol_lily'] = {'gid': 'mine', 'name': '새벽걸음', 'emblem': 2, 'color': 3};
        a.garrisons['sol_lily'] = [
          {'name': '별하', 'level': 31, 'job': 'herbalist', 'allies': ['도윤'], 'me': false},
          {'name': '하루', 'level': 30, 'job': 'gateHeir', 'allies': <String>[], 'me': true},
          {'name': '모래', 'level': 27, 'job': 'appraiser', 'allies': <String>[], 'me': false},
          {'name': '해솔', 'level': 24, 'job': 'merchant', 'allies': <String>[], 'me': false},
          {'name': '달빛', 'level': 35, 'job': 'blacksmith', 'allies': <String>[], 'me': false},
        ];
        await c.refreshErbard();
      });
      await _page(tester, GarrisonScreen(key: ObjectKey('g$n'), controller: c, estate: ErbardRules.estate('sol_lily')!));
      await _shot(tester, '${n}_02_분신_수비대');
    });
  }
}
