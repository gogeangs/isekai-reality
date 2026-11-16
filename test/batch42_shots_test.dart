// 묶음 42 #226: 마을 사람 부탁 · 사연 · 친해지기 화면 미리보기 (build/screenshots/b42_*)
// 작은 iPhone(SE) · 큰 iPhone · Android

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/rules/rules.dart';

import 'package:isekai_reality/features/records/records_screen.dart';
import 'package:isekai_reality/features/status/status_screen.dart';
import 'package:isekai_reality/features/town/inn_screen.dart';
import 'package:isekai_reality/features/town/shop_screen.dart';
import 'package:isekai_reality/features/village/npc_request.dart';
import 'package:isekai_reality/features/village/village_screen.dart';
import 'package:isekai_reality/theme/ornaments.dart';
import 'package:isekai_reality/theme/top_notice.dart';

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
  File('build/screenshots/b42_$name.png')
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

Map<String, dynamic> _npc({
  Map<String, int> points = const {},
  Map<String, int> done = const {},
  Map<String, dynamic> active = const {},
  Map<String, int> tally = const {},
}) =>
    {
      'v': 1,
      'points': points,
      'shown': {
        for (final e in points.entries) e.key: NpcRules.stageOf(e.value).index,
      },
      'done': done,
      'active': active,
      'tally': tally,
    };

void main() {
  setUpAll(_loadFonts);

  for (final d in _devices) {
    final n = d.$1;

    testWidgets('b42 $n: 이름표 ! · 부탁 듣기 · 부탁 창 · 상태 의뢰 칸 · 다 했어요 · 사연', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async => c = await startNpc(
          level: 8,
          npc: _npc(points: {'mina': 10, 'marta': 25, 'dorgun': 8}, done: {'marta': 1})));
      await _page(tester, Scaffold(body: VillageScreen(controller: c)));
      await _shot(tester, '${n}_01_마을_이름표_느낌표');

      await _page(tester, ShopScreen(key: ObjectKey(c), controller: c));
      await _shot(tester, '${n}_02_잡화상_부탁듣기');
      await tester.tap(find.byKey(const Key('npcAsk_mina')));
      await _settle(tester);
      await _shot(tester, '${n}_03_부탁창');
      await tester.tap(find.byKey(const Key('npcAccept')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await _settle(tester);
      await tester.runAsync(() => c.sellManaStones(4));
      await _settle(tester);
      await _shot(tester, '${n}_04_잡화상_부탁진행');

      // 마르타 부탁도 받아 두고 상태 탭 의뢰 칸
      await tester.runAsync(() => c.acceptRequest(Npc.marta));
      await _page(
          tester,
          Scaffold(body: StatusScreen(
            player: c.player,
            hp: c.hp,
            mp: c.mp,
            maxHp: c.maxHp,
            mpMax: c.mpMax,
            armory: c.armory,
            requestPanel: NpcRequestPanel(controller: c),
          )));
      final sc = find.byType(Scrollable).first;
      await tester.drag(sc, const Offset(0, -900));
      await _settle(tester, 3);
      await _shot(tester, '${n}_05_상태탭_의뢰칸');

      await tester.runAsync(() => c.sellManaStones(6));
      await _page(tester, ShopScreen(key: ValueKey('s2$n'), controller: c));
      await _shot(tester, '${n}_06_잡화상_다했어요');
      await tester.tap(find.byKey(const Key('npcDone_mina')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
      await _settle(tester);
      await _shot(tester, '${n}_07_사연_대사창');
      await tester.tap(find.byKey(const Key('npcStoryOk')));
      await _settle(tester);
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('b42 $n: 특별 보상 · 기록 탭 마을 사람 이야기', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async => c = await startNpc(
            level: 13,
            npc: _npc(
              points: {'marta': 50, 'mina': 22, 'hart': 9, 'dorgun': 6, 'eliel': 6},
              done: {'marta': 3, 'mina': 1, 'hart': 2},
              active: {
                'marta': {'i': 3, 'day': '2026-11-16', 'base': {'relic': 0}, 'steps': 0},
              },
              tally: {'relic': 1},
            ),
          ));
      await _page(tester, InnScreen(controller: c));
      await _shot(tester, '${n}_08_여관_다했어요');
      await tester.tap(find.byKey(const Key('npcDone_marta')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
      await _settle(tester);
      await _shot(tester, '${n}_09_마지막_사연');
      await tester.tap(find.byKey(const Key('npcStoryOk')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await _settle(tester);
      await _shot(tester, '${n}_10_특별보상');
      await tester.tap(find.byKey(const Key('npcSpecialOk')));
      await _settle(tester);

      await _page(
          tester,
          Scaffold(
              body: NightBackground(
                  header: true,
                  child: RecordsScreen(
                      player: c.player, npcStories: c.npcStories))));
      final list = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
          find.byKey(const Key('npcStoryRecords')), 200,
          scrollable: list);
      Scrollable.ensureVisible(
          tester.element(find.byKey(const Key('npcStoryRecords'))));
      await _settle(tester, 3);
      await _shot(tester, '${n}_11_기록탭_마을사람이야기');
      await tester.drag(list, const Offset(0, -500));
      await _settle(tester, 3);
      await _shot(tester, '${n}_12_기록탭_아래');
      await tester.pump(const Duration(seconds: 9));
    });
  }
}
