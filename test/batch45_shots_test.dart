// 묶음 45 #231·#232: 작은 부탁 · 게시판 마을 사람 쪽지 · 전용 아이템 퀘스트 미리보기 (build/screenshots/b45_*)
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

import 'package:isekai_reality/core/models/board_state.dart';
import 'package:isekai_reality/features/smithy/smithy_screen.dart';
import 'package:isekai_reality/features/town/bag_tab.dart';
import 'package:isekai_reality/features/village/board_screen.dart';
import 'package:isekai_reality/features/status/status_screen.dart';
import 'package:isekai_reality/features/town/inn_screen.dart';
import 'package:isekai_reality/features/village/npc_request.dart';
import 'package:isekai_reality/features/village/village_screen.dart';
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
  File('build/screenshots/b45_$name.png')
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
  Map<String, int> tally = const {},
  Map<String, dynamic> extra = const {},
}) =>
    {
      'v': 1,
      'points': points,
      'shown': {
        for (final e in points.entries) e.key: NpcRules.stageOf(e.value).index,
      },
      'done': const <String, int>{},
      'active': const <String, dynamic>{},
      'tally': tally,
      ...extra,
    };

Future<void> _wait(WidgetTester tester, [int ms = 120]) async {
  await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
  await _settle(tester);
}

void main() {
  setUpAll(_loadFonts);

  for (final d in _devices) {
    final n = d.$1;

    testWidgets('b45 $n: 게시판 마을 사람 쪽지 · 5번째 → 직접 작은 부탁', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async => c = await startNpc(
            level: 8,
            npc: _npc(extra: {
              'bDone': {'marta': 4},
            }),
            todaySteps: const {'2026-11-16': 5000},
            json: {
              'board': const BoardState(day: '2026-11-16', seq: 2, slots: [
                ErrandSlot(templateId: 'npc_marta_0', accepted: true, baseline: 0),
                ErrandSlot(templateId: 'npc_mina_1'),
              ]).toJson(),
            },
          ));
      await _page(tester, BoardScreen(controller: c));
      final sc = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(find.byKey(const Key('errandNote_1')), 200,
          scrollable: sc);
      await _settle(tester, 3);
      await _shot(tester, '${n}_01_게시판_마을사람쪽지');
      await tester.tap(find.byKey(const Key('errandNote_1')));
      await _settle(tester);
      await _shot(tester, '${n}_02_쪽지_상세');
      await tester.tapAt(const Offset(10, 10));
      await _settle(tester);
      await tester.runAsync(() => c.claimErrand(0));
      await _page(tester, InnScreen(key: ValueKey('inn$n'), controller: c));
      await _shot(tester, '${n}_03_여관_자주해결_작은부탁');
      await tester.tap(find.byKey(const Key('npcAsk_marta_small')));
      await _settle(tester);
      await _shot(tester, '${n}_04_작은부탁_창');
      await tester.pump(const Duration(seconds: 9));
    }, skip: true /* 묶음 69 #286: 건물 위쪽 부탁 줄을 게시판으로 옮김 — 예전 캡처는 그대로 둠 */);

    testWidgets('b45 $n: 마을 이름표 표시 · 다 했어요 → 한마디 → 특별한 부탁 · 상태 탭',
        (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async => c = await startNpc(
            level: 8,
            mats: const {'herb': 4, 'ironShard': 3},
            npc: _npc(points: {'hart': 6}, extra: {
              'sOffer': {'mina': 0},
              'rOffer': ['dorgun'],
              'small': {
                'marta': {'i': 1, 'day': '2026-11-16', 'base': {}, 'steps': 0},
              },
              'rMiss': {'marta': 20},
            }),
          ));
      await _page(tester, Scaffold(body: VillageScreen(controller: c)));
      await _shot(tester, '${n}_05_마을_부탁표시');

      await _page(tester, InnScreen(key: ValueKey('inn2$n'), controller: c));
      await _shot(tester, '${n}_06_여관_작은부탁_다했어요');
      await tester.tap(find.byKey(const Key('npcDone_marta_small')));
      await _wait(tester);
      await _shot(tester, '${n}_07_고맙다는_한마디');
      await tester.tap(find.byKey(const Key('npcThanksOk')));
      await _wait(tester);
      await _shot(tester, '${n}_08_특별한부탁_나옴');
      await tester.tap(find.byKey(const Key('npcAccept')));
      await _wait(tester, 80);

      await tester.runAsync(() => c.acceptRelic(Npc.dorgun));
      await tester.runAsync(() => c.acceptSmall(Npc.mina));
      await _page(
          tester,
          Scaffold(
              body: StatusScreen(
            player: c.player,
            hp: c.hp,
            mp: c.mp,
            maxHp: c.maxHp,
            mpMax: c.mpMax,
            armory: c.armory,
            requestPanel: NpcRequestPanel(controller: c),
          )));
      final sc = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(find.byKey(const Key('statusRequests')), 200,
          scrollable: sc);
      await tester.drag(sc, const Offset(0, -200));
      await _settle(tester, 3);
      await _shot(tester, '${n}_09_상태탭_부탁');
      await tester.pump(const Duration(seconds: 9));
    }, skip: true /* 묶음 69 #286: 건물 위쪽 부탁 줄을 게시판으로 옮김 — 예전 캡처는 그대로 둠 */);

    testWidgets('b45 $n: 특별한 부탁 단계 · 받는 장면 · 가방 소중한 물건', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async => c = await startNpc(
            level: 8,
            npc: _npc(tally: {'gather:ore': 3}, extra: {
              'relic': {
                'dorgun': {'i': 1, 'day': '2026-11-16', 'base': {'water': 0}, 'steps': 0},
              },
            }),
            todaySteps: const {'2026-11-16': 1200},
          ));
      await _page(tester, SmithyScreen(key: ValueKey('sm$n'), controller: c));
      await tester.tap(find.byKey(const Key('npcReq_dorgun_special')));
      await _settle(tester);
      await _shot(tester, '${n}_10_특별한부탁_단계');
      await tester.tap(find.byKey(const Key('npcClose')));
      await _settle(tester);

      late AppController c2;
      await tester.runAsync(() async => c2 = await startNpc(
            level: 8,
            mats: const {'ironIngot': 2},
            npc: _npc(extra: {
              'relic': {
                'dorgun': {'i': 2, 'day': '2026-11-16', 'base': {}, 'steps': 0},
              },
              'relics': ['marta', 'mina'],
            }),
          ));
      await _page(tester, SmithyScreen(key: ValueKey('sm2$n'), controller: c2));
      await tester.tap(find.byKey(const Key('npcDone_dorgun_special')));
      await _wait(tester);
      await _shot(tester, '${n}_11_전용아이템_받음');
      await tester.tap(find.byKey(const Key('npcRelicOk')));
      await _settle(tester);
      await _page(tester, Scaffold(body: BagTab(controller: c2)));
      await tester.scrollUntilVisible(find.byKey(const Key('preciousPanel')), 200,
          scrollable: find.byType(Scrollable).first);
      await _settle(tester, 3);
      await _shot(tester, '${n}_12_가방_소중한물건');
      await tester.pump(const Duration(seconds: 9));
    }, skip: true /* 묶음 69 #286: 건물 위쪽 부탁 줄을 게시판으로 옮김 — 예전 캡처는 그대로 둠 */);
  }
}
