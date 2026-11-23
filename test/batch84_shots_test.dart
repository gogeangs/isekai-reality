// 묶음 84 (build/screenshots/b84_*) — 큰 iPhone · SE

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/app.dart';
import 'package:isekai_reality/core/models/highland_state.dart';
import 'package:isekai_reality/core/models/pet_state.dart';
import 'package:isekai_reality/features/codex/codex_screen.dart';
import 'package:isekai_reality/features/highland/highland_screen.dart';
import 'package:isekai_reality/features/smithy/smithy_screen.dart';
import 'package:isekai_reality/features/town/bag_tab.dart';
import 'package:isekai_reality/features/village/board_screen.dart';
import 'package:isekai_reality/features/tutorial/feature_tour.dart' show tourBridge;
import 'package:isekai_reality/theme/top_notice.dart';

import 'batch50_test.dart' as b50;
import 'batch83_test.dart' as t83;
import 'batch84_test.dart' as t84;
import 'support/village_seed.dart';

final _root = GlobalKey();

Future<void> _loadFonts() async {
  for (final family in ['Roboto', 'FlutterTest']) {
    final korean = FontLoader(family);
    for (final f in ['NanumGothic-Regular', 'NanumGothic-Bold', 'NanumGothic-ExtraBold']) {
      korean.addFont(File('test/fonts/$f.ttf').readAsBytes().then((b) => ByteData.view(b.buffer)));
    }
    await korean.load();
  }
  final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
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
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
  }
  final boundary = tester.renderObject(find.byKey(_root)) as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.5);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  File('build/screenshots/b84_$name.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!);
}

const _devices = [
  ('SE', Size(750, 1334), 2.0, 40.0, 0.0),
  ('큰iPhone', Size(1290, 2796), 3.0, 177.0, 102.0),
];

void _device(WidgetTester tester, (String, Size, double, double, double) d) {
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
        key: UniqueKey(),
        debugShowCheckedModeBanner: false,
        theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Roboto'),
        builder: (context, child) => TopNoticeHost(child: child!),
        home: home),
  ));
  await _settle(tester);
}



Future<void> _done(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 3));
}

Future<AppController> _island(WidgetTester tester, Isle isle, {SkyClimb Function(String slot)? climb}) async {
  late AppController c;
  await tester.runAsync(() async {
    final slot = t83.slotNowAm();
    c = await t83.onIsland(isle: isle, climb: climb?.call(slot), guideSeen: true);
  });
  return c;
}

Future<void> _tapCell(WidgetTester tester, int i) async {
  final r = tester.getRect(find.byKey(Key('skyTile_$i')));
  await tester.tapAt(r.topCenter + Offset(0, r.height / 3));
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
}

List<int> _path(SkyBoard b, int to) {
  final prev = <int, int>{};
  final q = [b.entrance];
  final seen = {b.entrance};
  for (var k = 0; k < q.length; k++) {
    for (final j in b.neighbors4(q[k])) {
      if (seen.add(j)) {
        prev[j] = q[k];
        q.add(j);
      }
    }
  }
  final out = <int>[];
  var s = to;
  while (s != b.entrance) {
    out.add(s);
    s = prev[s]!;
  }
  return out.reversed.toList();
}

DateTime _urgentDay() {
  for (var i = 0; i < 400; i++) {
    final d = DateTime(2026, 11, 10).add(Duration(days: i));
    if (BoardRules.urgentFor(d) case final u?) return DateTime(d.year, d.month, d.day, u.appearsAt.hour + 1);
  }
  throw StateError('no urgent');
}

DateTime _calmDay() {
  for (var i = 0; i < 400; i++) {
    final d = DateTime(2026, 11, 10).add(Duration(days: i));
    if (BoardRules.urgentFor(d) == null) return DateTime(d.year, d.month, d.day, 15);
  }
  throw StateError('no calm');
}

void main() {
  setUpAll(_loadFonts);

  for (final d in _devices) {
    final n = d.$1;

    testWidgets('b84 $n: 1 가방 숨은 알 · 이별 뒤', (tester) async {
      _device(tester, d);
      late AppController before;
      await tester.runAsync(() async {
        before = await startVillage(9, gains: {'slimeJelly': 3, 'herb': 2}, more: {
          'pets': const PetState(eggs: [PetEgg(id: 'e1', source: 'field', grade: EggGrade.rare)], firstEggFound: true).toJson(),
        });
      });
      await _page(tester, Scaffold(body: BagTab(key: ObjectKey('b$n'), controller: before)));
      await _shot(tester, '${n}_01_가방_이별전_숨은알_안보임');
      await tester.runAsync(() async {
        await before.completeFarewell('부엉');
      });
      await _page(tester, Scaffold(body: BagTab(key: ObjectKey('a$n'), controller: before)));
      await _shot(tester, '${n}_02_가방_이별뒤_알보임');
      await _done(tester);
    });

    testWidgets('b84 $n: 2 대장간 하이랜드 세트 · 하늘 계단', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async {
        c = await b50.start(b50.account(18, smith: true, mats: {'skyStone': 20, 'stormCore': 2}, highland: const HighlandState(beaten: [0, 1]).toJson()));
      });
      await _page(tester, SmithyScreen(controller: c));
      await tester.tap(find.byKey(const Key('smithyTab_5')));
      await _settle(tester, 4);
      final sky = find.byKey(const Key('bossSet_sky'));
      await tester.dragUntilVisible(sky, find.byKey(const Key('smithyList')), const Offset(0, -300));
      await _settle(tester, 3);
      await _shot(tester, '${n}_03_대장간_하이랜드세트_비용');
      await _done(tester);
      // 하늘 계단: 구름 속 빛기둥 · 걷은 뒤 계단 그림
      final c1 = await _island(tester, Isle.wind, climb: (s) => SkyClimb(slot: s, seed: 21, wind: 10, opened: [SkyBoard.generate(21, 1).entrance], hero: SkyBoard.generate(21, 1).entrance));
      await _page(tester, HighlandScreen(key: ObjectKey('s1$n'), controller: c1));
      await _shot(tester, '${n}_04_하늘계단_구름속_빛기둥');
      await _done(tester);
      final b = SkyBoard.generate(21, 1);
      final path = _path(b, b.goal);
      final c2 = await _island(tester, Isle.wind, climb: (s) => SkyClimb(slot: s, seed: 21, wind: 6, opened: [b.entrance, ...path.sublist(0, path.length - 1)], hero: path[path.length - 2]));
      await _page(tester, HighlandScreen(key: ObjectKey('s2$n'), controller: c2));
      await _tapCell(tester, b.goal);
      await _settle(tester, 6);
      await _shot(tester, '${n}_05_하늘계단_걷은뒤_그림');
      await _done(tester);
    });

    testWidgets('b84 $n: 3 도감 · 상태', (tester) async {
      _device(tester, d);
      await _page(tester, const Scaffold(
          body: CodexScreen(purifiedMonsters: {MonsterId.ashSlime, MonsterId.giantRat}, huntCounts: {MonsterId.ashSlime: 12})));
      final scroll = find.byType(Scrollable).first;
      await tester.drag(scroll, const Offset(0, -2000));
      await _settle(tester, 3);
      await _shot(tester, '${n}_06_도감_몬스터탭_맨아래');
      await _done(tester);
      late AppController c;
      var now = DateTime(2026, 11, 23, 10);
      await tester.runAsync(() async {
        c = await t84.longAccount(5, () => now, more: {
          'village': {
            'seen': ['shelterCard', 'trainingCard', 'gardenCard', 'tavernCard', 'subJobCard', 'chatTour', 'marketIntro', 'v44', 'codexNotice'],
          },
        });
        await c.markCodexSeen();
      });
      await tester.pumpWidget(RepaintBoundary(key: _root, child: IsekaiRealityApp(controller: c)));
      await _settle(tester, 8);
      // 새로 열렸어요 카드 · 안내는 넘김
      for (var k = 0; k < 8; k++) {
        final ok = find.text('알겠어').evaluate().isNotEmpty
            ? find.text('알겠어')
            : find.text('알겠어요').evaluate().isNotEmpty
                ? find.text('알겠어요')
                : find.text('가 보기');
        if (ok.evaluate().isEmpty) break;
        await tester.tap(ok.first, warnIfMissed: false);
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
        await _settle(tester, 4);
        if (tester.widgetList(find.byType(Navigator)).length > 1 || find.byType(BackButton).evaluate().isNotEmpty) {
          await tester.pageBack();
          await _settle(tester, 3);
        }
      }
      tourBridge.openTab?.call(0);
      await _settle(tester, 6);
      for (var k = 0; k < 4; k++) {
        final later = find.text('나중에');
        if (later.evaluate().isEmpty) break;
        await tester.tap(later.first, warnIfMissed: false);
        await _settle(tester, 4);
      }
      await tester.dragFrom(const Offset(200, 500), const Offset(0, -700));
      await _settle(tester, 4);
      await _shot(tester, '${n}_07_상태_펫칸아래_훈련장줄없음');
      await _done(tester);
    });

    testWidgets('b84 $n: 4 게시판 긴급 쪽지', (tester) async {
      _device(tester, d);
      final t = _urgentDay();
      late AppController c;
      late AppController calm;
      await tester.runAsync(() async {
        c = await startVillage(10, clock: () => t);
        calm = await startVillage(10, clock: () => _calmDay());
      });
      await _page(tester, BoardScreen(key: ObjectKey('u$n'), controller: c));
      await _shot(tester, '${n}_08_게시판_긴급있는날_맨앞쪽지_빨간점');
      await tester.tap(find.byKey(const Key('urgentNote')));
      await _settle(tester, 4);
      await _shot(tester, '${n}_09_긴급양피지_테두리없음');
      await tester.tap(find.text('수락하기'));
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tapAt(const Offset(20, 60));
      await _settle(tester, 6);
      await _shot(tester, '${n}_10_게시판_긴급받은뒤_진행');
      await _done(tester);
      await _page(tester, BoardScreen(key: ObjectKey('c$n'), controller: calm));
      await _shot(tester, '${n}_11_게시판_긴급없는날');
      await _done(tester);
    });
  }
}
