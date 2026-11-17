// 묶음 50 #146: 하이랜드 화면 미리보기 (build/screenshots/b50_*)
// 작은 iPhone(SE) · 큰 iPhone · Android

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/geo/geo.dart';
import 'package:isekai_reality/core/models/highland_state.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/features/highland/highland_screen.dart';
import 'package:isekai_reality/features/records/records_screen.dart';
import 'package:isekai_reality/features/smithy/boss_gear_tab.dart';
import 'package:isekai_reality/theme/app_colors.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'batch50_test.dart' as b50;

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
  File('build/screenshots/b50_$name.png')
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


Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)));
  await _settle(tester, 3);
}

void main() {
  setUpAll(_loadFonts);

  for (final d in _devices) {
    final n = d.$1;

    testWidgets('b50 $n: 첫 장면 · 섬 입구 · 갈림길 · 수호자 · 전투', (tester) async {
      _device(tester, d);
      b50.now = b50.am.add(const Duration(minutes: 5));
      late AppController c;
      await tester.runAsync(() async {
        c = await b50.start(b50.account(18, mats: {'skyFeather': 2}));
        await c.handleFix(const LocationFix(point: b50.home));
      });
      await _page(tester, HighlandSceneScreen(key: ObjectKey('s$n'), controller: c));
      await tester.pump(const Duration(seconds: 3));
      await _shot(tester, '${n}_01_첫장면_주인공');
      await tester.tapAt(const Offset(100, 200));
      await tester.pump(const Duration(seconds: 4));
      await _shot(tester, '${n}_02_첫장면_첫펫');
      await tester.runAsync(
          () async => c.handleFix(LocationFix(point: c.skyIsland!.point)));
      await _page(tester, HighlandScreen(key: ObjectKey('h$n'), controller: c));
      await _shot(tester, '${n}_03_섬_입구');
      await _tap(tester, 'skyClimb');
      await _shot(tester, '${n}_04_첫_갈림길');
      await _tap(tester, 'skyForkRuins');
      await _shot(tester, '${n}_05_폐허');
      await _tap(tester, 'skyNext');
      await _tap(tester, 'skyForkRuins');
      await _tap(tester, 'skyNext');
      await _shot(tester, '${n}_06_수호자_앞');
      await _tap(tester, 'skyGuardian');
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 950));
      }
      await _shot(tester, '${n}_07_수호자_전투');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('b50 $n: 석상 병사 · 비문 · 대장간 세트 · 기록 탭', (tester) async {
      _device(tester, d);
      b50.now = b50.am.add(const Duration(minutes: 5));
      final slot = HighlandRules.slotAt(b50.now)!.slot;
      late AppController c;
      await tester.runAsync(() async {
        c = await b50.start(b50.account(18,
            mats: {'skyStone': 9, 'stormCore': 2, 'cloudCrystal': 1},
            highland: HighlandState(
              sceneSeen: true,
              starter: true,
              climbedEver: true,
              firstLine: true,
              beaten: const [0, 1, 3],
              slot: slot,
              isle: Isle.ice.index,
              lat: b50.home.lat,
              lng: b50.home.lng,
              climbed: true,
            ).toJson()));
        await c.handleFix(const LocationFix(point: b50.home));
      });
      await _page(tester, HighlandScreen(key: ObjectKey('h$n'), controller: c));
      await _tap(tester, 'skyClimb');
      await _tap(tester, 'skyForkStone');
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 950));
      }
      await _shot(tester, '${n}_08_석상병사_얼음');
      await _page(
          tester,
          Builder(
              key: ObjectKey('i$n'),
              builder: (context) => Scaffold(
                    backgroundColor: AppColors.deepNight,
                    body: Center(
                      child: TextButton(
                          key: const Key('open'),
                          onPressed: () => showSkyInscription(context, 3),
                          child: const Text('열기')),
                    ),
                  )));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pump(const Duration(seconds: 2));
      await _shot(tester, '${n}_09_비문');
      await _page(
          tester,
          Scaffold(
              key: ObjectKey('g$n'),
              backgroundColor: AppColors.deepNight,
              body: SafeArea(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(14),
                    child: BossGearTab(controller: c)),
              )));
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -2400));
      await _settle(tester);
      await _shot(tester, '${n}_10_대장간_하이랜드세트');
      await _page(
          tester,
          Scaffold(
              key: ObjectKey('r$n'),
              backgroundColor: AppColors.deepNight,
              body: SafeArea(
                  child: RecordsScreen(
                      player: c.player, skyStones: c.skyInscriptions))));
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
      await _settle(tester);
      await _shot(tester, '${n}_11_기록_비문');
      await tester.pump(const Duration(seconds: 9));
    });
  }
}
