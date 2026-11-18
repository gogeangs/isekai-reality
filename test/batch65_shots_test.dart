// 묶음 65 (1/2): 화면 고침 5건 · 공성전 다듬기 (build/screenshots/b65_*)
// 작은 iPhone(SE) · 큰 iPhone · Android

import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/act5_state.dart';
import 'package:isekai_reality/core/models/garden_state.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/features/act2/ash_battle_screen.dart';
import 'package:isekai_reality/features/act5/erbard_screens.dart';
import 'package:isekai_reality/features/battle/battle_view.dart';
import 'package:isekai_reality/features/harvest/harvest_sheet.dart';
import 'package:isekai_reality/features/village/board_screen.dart';
import 'package:isekai_reality/features/village/garden_screen.dart';
import 'package:isekai_reality/features/village/village_screen.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'batch52_test.dart' as b52;
import 'batch56_test.dart' as b56;
import 'batch60_test.dart' as b60;
import 'support/fake_arca.dart';
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
  File('build/screenshots/b65_$name.png')
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

Map<String, dynamic> _plots(Map<int, (String, String)> m) => GardenState(plots: {
      for (final e in m.entries) e.key: GardenPlot(seed: e.value.$1, day: e.value.$2, steps: 0),
    }).toJson();

Future<(AppController, FakeArca)> _siege() async {
  final (c, a) = await b60.act5(
      guild: true,
      state: const Act5State(opened: true, chapter: 3, seen: {'e1a', 'e1b', 'e1c', 'e2a', 'e2b'}, ticketAt: -14000, pioneered: true, ch3Siege: 0));
  await c.awakenJob(JobId.rogue);
  a.siegeActive = true;
  a.siegeOwners['sol_lily'] = {'gid': 'mine', 'name': '새벽걸음', 'emblem': 2, 'color': 3};
  a.siegeOwners['sol_bell'] = {'gid': 'mine', 'name': '새벽걸음', 'emblem': 2, 'color': 3};
  a.siegeOwners['dor_deep'] = {'gid': 'other', 'name': '노을', 'emblem': 1, 'color': 1};
  a.siegeRun['dor_deep'] = [0];
  a.siegeRun['sol_silver'] = [0, 1, 2];
  a.siegeWeak['dor_deep'] = [1];
  a.siegeDefense['sol_lily'] = 2;
  a.siegeDefense['sol_bell'] = 0;
  a.gauge = {'progress': 0.62, 'full': 1, 'rams': 1, 'ramMax': 2, 'repairs': ['sol_lily']};
  a.rallyEstate = 'dor_deep';
  final t = DateTime.utc(2026, 11, 28, 3).millisecondsSinceEpoch;
  a.siegeNews.addAll([
    {'at': t, 'text': '별하님이 은방패 요새 셋째 자리를 깼어요'},
    {'at': t, 'text': '우리 영지 백합 들판 성가 공격받고 있어요'},
    {'at': t, 'text': '성벽 보수로 백합 들판 성 둘째 자리를 되살렸어요'},
    {'at': t, 'text': '공성 망치로 깊은 갱도 성 둘째 자리를 흔들었어요'},
    {'at': t, 'text': '하루님이 깊은 갱도 성에 집결 깃발을 꽂았어요. 깊은 갱도 성에 집결해요'},
  ]);
  b56.now = DateTime(2026, 11, 28, 10);
  await c.refreshErbard();
  return (c, a);
}

void main() {
  setUpAll(_loadFonts);
  setUp(() => b56.now = b52.t0);

  for (final d in _devices) {
    final n = d.$1;

    testWidgets('b65 $n: 양피지 두 장 · 약초밭 · 게시판', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async => c = await startNpc(
            level: 12,
            mats: const {'herbSeed': 3},
            todaySteps: const {'2026-11-16': 2600},
            json: {
              'garden': _plots({0: ('herbSeed', '2026-11-15'), 1: ('flowerSeed', '2026-11-16')}),
            },
          ));
      await _page(tester, Scaffold(body: Builder(builder: (ctx) => Center(child: TextButton(onPressed: () => showProphecy(ctx, 0), child: const Text('열기'))))));
      await tester.tap(find.text('열기'));
      await _settle(tester, 6);
      await _shot(tester, '${n}_01_예언조각');
      await tester.pumpWidget(const SizedBox());
      await _page(tester, Scaffold(key: const ValueKey('k'), body: Builder(builder: (ctx) => Center(child: TextButton(onPressed: () => showKingStory(ctx, 1), child: const Text('열기'))))));
      await tester.tap(find.text('열기'));
      await _settle(tester, 6);
      await _shot(tester, '${n}_02_왕의사연');
      await tester.pumpWidget(const SizedBox());
      await _page(tester, GardenScreen(key: ObjectKey(c), controller: c));
      await _shot(tester, '${n}_03_약초밭칸');
      await _page(tester, BoardScreen(key: ObjectKey('b$n'), controller: c));
      await _shot(tester, '${n}_04_게시판위');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
      await _settle(tester);
      await _shot(tester, '${n}_05_게시판아래');
    });

    testWidgets('b65 $n: 마을 약초밭 · 훈련장 자리', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async => c = await startVillage(20, village: {
            'seen': ['intro', 'v43', 'v44', 'v48', 'built:smithy', 'built:board', 'built:alchemy', 'built:garden', 'built:training'],
          }));
      await _page(tester, Scaffold(body: VillageScreen(key: ObjectKey(c), controller: c)));
      await tester.drag(find.byKey(const Key('villageScroll')), const Offset(1200, 0));
      await _settle(tester, 4);
      await _shot(tester, '${n}_06_마을_약초밭');
      await tester.drag(find.byKey(const Key('villageScroll')), const Offset(-2600, 0));
      await _settle(tester, 4);
      await _shot(tester, '${n}_07_마을_훈련장');
    });

    testWidgets('b65 $n: 막기 방어막 · BOSS 경고', (tester) async {
      _device(tester, d);
      final b = Battle(
        playerMaxHp: 100000,
        playerAttack: 30,
        floors: [
          Foe(monster: MonsterId.ashSlime, maxHp: 1, attack: 1),
          Foe(monster: MonsterId.fireSlimeKing, maxHp: 100000, attack: 10),
        ],
        rng: math.Random(3),
        telegraphs: true,
      );
      await _page(tester, Scaffold(body: SafeArea(child: Column(children: [
        Expanded(child: BattleView(battle: b, fit: true, onFinished: () {}, tickInterval: const Duration(milliseconds: 600))),
      ]))));
      Future<void> nextWarning() async {
        for (var i = 0; i < 40 && b.strongNext; i++) {
          await tester.pump(const Duration(milliseconds: 600));
        }
        for (var i = 0; i < 40 && !b.strongNext; i++) {
          await tester.pump(const Duration(milliseconds: 600));
        }
      }
      await nextWarning();
      await tester.pump(const Duration(milliseconds: 200));
      await _shot(tester, '${n}_08_보스경고');
      await nextWarning();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(const Offset(200, 300));
      await tester.pump(const Duration(milliseconds: 100));
      await _shot(tester, '${n}_09_막기준비');
      for (var i = 0; i < 10 && b.lastGuard == null; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      await tester.pump(const Duration(milliseconds: 250));
      await _shot(tester, '${n}_10_막았다');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('b65 $n: 공성전 지도 · 엿보기 · 전황판 · 수비대 성벽 보수 · 마지막 6시간 · 결과 장면', (tester) async {
      _device(tester, d);
      late AppController c;
      late FakeArca a;
      await tester.runAsync(() async => (c, a) = await _siege());
      await _page(tester, ErbardScreen(key: ObjectKey('m$n'), controller: c));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await _settle(tester);
      await _shot(tester, '${n}_11_지도_집결깃발');
      await tester.tap(find.byKey(const Key('estate_dor_deep')), warnIfMissed: false);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await _settle(tester);
      await _shot(tester, '${n}_12_엿보기');
      Navigator.of(tester.element(find.byKey(const Key('estateSheet_dor_deep')))).pop();
      await _settle(tester);
      await tester.tap(find.byKey(const Key('erbardWarBoard')));
      await _settle(tester);
      await _shot(tester, '${n}_13_전황판');
      Navigator.of(tester.element(find.byKey(const Key('warBoard')))).pop();
      await _settle(tester);
      await _page(tester, GarrisonScreen(key: ObjectKey('g$n'), controller: c, estate: ErbardRules.estate('sol_lily')!));
      await tester.scrollUntilVisible(find.byKey(const Key('garrisonRepair')), 300, scrollable: find.byType(Scrollable).first);
      await _settle(tester);
      await _shot(tester, '${n}_14_성벽보수');
      // 마지막 6시간
      b56.now = DateTime.utc(2026, 11, 29, 10);
      await _page(tester, ErbardScreen(key: ObjectKey('f$n'), controller: c));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await _settle(tester);
      await _shot(tester, '${n}_15_마지막6시간');
      // 결과 장면
      await tester.runAsync(() async {
        a.siegeActive = false;
        a.siegeLast = {
          'no': 0,
          'royal': {'gid': 'npc', 'name': '흑등 연맹'},
          'changes': [
            {'estate': 'dor_deep', 'fromName': '노을', 'toName': '새벽걸음'},
          ],
        };
        a.siegeOwners['dor_deep'] = {'gid': 'mine', 'name': '새벽걸음', 'emblem': 2, 'color': 3};
        b56.now = DateTime(2026, 11, 30, 10);
        await c.refreshErbard();
      });
      await _page(tester, SiegeResultScene(key: ObjectKey('s$n'), controller: c));
      await tester.pump(const Duration(milliseconds: 4000));
      await _shot(tester, '${n}_16_결과장면');
    });
  }
}
