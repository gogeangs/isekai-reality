// 묶음 71 (build/screenshots/b71_*)
// 작은 iPhone(SE) · 큰 iPhone · Android

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/data/storage/record_store.dart' show SpiritKind;
import 'package:isekai_reality/features/alchemy/alchemy_screen.dart';
import 'package:isekai_reality/features/bulssi/bulssi_mood.dart';
import 'package:isekai_reality/features/chat/chat_tour.dart';
import 'package:isekai_reality/features/map/expedition_sheet.dart';
import 'package:isekai_reality/features/smithy/smithy_screen.dart';
import 'package:isekai_reality/features/town/shop_screen.dart';
import 'package:isekai_reality/features/village/board_screen.dart';
import 'package:isekai_reality/theme/ornaments.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'batch52_test.dart' as b52;
import 'batch56_test.dart' as b56;
import 'support/npc_seed.dart';
import 'support/route_seed.dart';

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
  File('build/screenshots/b71_$name.png')
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

    testWidgets('b71 $n: 들어간 직후 (게시판 · 연금술 · 잡화상) — 말풍선 닫힌 채로', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async => c = await startNpc(level: 16));
      await _page(tester, BoardScreen(key: ObjectKey('b$n'), controller: c));
      await _shot(tester, '${n}_01_게시판_들어간직후');
      await _page(tester, AlchemyScreen(key: ObjectKey('a$n'), controller: c));
      await _shot(tester, '${n}_02_연금술_들어간직후');
      await _page(tester, ShopScreen(key: ObjectKey('s$n'), controller: c));
      await _shot(tester, '${n}_03_잡화상_들어간직후');
      // 얼굴을 누르면 제자리에 열리고 탭은 아래로
      await tester.tap(find.byKey(const Key('npcFace_mina')));
      await _settle(tester, 2);
      await _shot(tester, '${n}_04_잡화상_얼굴누르면');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('b71 $n: Lv.8 친구 장면 · 로그인 권유 (정령 얼굴 + 말풍선)', (tester) async {
      _device(tester, d);
      for (final (k, line, acts) in [
        ('05_Lv8_친구장면', '요즘 걷는 길이 좀 심심하지 않아? 함께 걸을 친구가 있으면 더 멀리 갈 수 있을 거야!', ['응!']),
        ('06_Lv8_로그인권유', '친구를 사귀려면 기록을 지켜 둬야 해!', ['로그인', '나중에']),
      ]) {
        await _page(
            tester,
            BulssiScope(
              mood: BulssiMood.gold,
              spiritName: '불씨',
              kind: SpiritKind.water,
              child: Scaffold(
                  body: NightBackground(
                      header: true,
                      child: Builder(
                          builder: (ctx) => Center(
                              child: TextButton(
                                  onPressed: () => showDialog<void>(
                                      context: ctx,
                                      barrierColor: const Color(0xD9000000),
                                      builder: (_) => SpiritLineAlert(
                                          spiritName: '불씨',
                                          line: line,
                                          actions: [for (final a in acts) (Key(a), a, () {})])),
                                  child: const Text('열기')))))),
            ));
        await tester.tap(find.text('열기'));
        await _settle(tester, 4);
        await _shot(tester, '${n}_$k');
      }
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('b71 $n: 대장간 수리 (채집 도구 다섯 · 모두 수리)', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async => c = await startNpc(level: 12, gold: 3000, mats: const {
            'herb': 3,
            'ironShard': 3,
            'twig': 1,
          }, json: {
            'harvest': {
              'granted': true,
              'tools': {'sickle': 4, 'pickaxe': 12, 'axe': 30, 'rod': 0, 'brush': 25},
            },
          }));
      await _page(tester, SmithyScreen(key: ObjectKey('sm$n'), controller: c));
      await tester.tap(find.byKey(const Key('smithyTab_2')));
      await _settle(tester, 3);
      await _shot(tester, '${n}_07_대장간_수리');
      await tester.scrollUntilVisible(find.byKey(const Key('toolRepairPanel')), 300,
          scrollable: find.descendant(of: find.byType(SmithyScreen), matching: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down)).first);
      await _settle(tester, 2);
      await _shot(tester, '${n}_08_대장간_수리_도구');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('b71 $n: 원정 (길 자료 있음) — 부엉이 직선 · 다이어울프 길', (tester) async {
      _device(tester, d);
      late AppController c;
      late dynamic s;
      await tester.runAsync(() async {
        final r = await routedExpedition();
        c = r.$1;
        s = r.$2;
      });
      await _page(tester, Scaffold(body: NightBackground(child: Align(alignment: Alignment.bottomCenter, child: SpawnSheet(key: ObjectKey('o$n'), controller: c, spawn: s)))));
      await _settle(tester, 3);
      await _shot(tester, '${n}_09_원정_부엉이_직선');
      await tester.tap(find.text('서리').first);
      await _settle(tester, 3);
      await _shot(tester, '${n}_10_원정_다이어울프_길');
      await tester.pumpWidget(const SizedBox());
    });
  }
}
