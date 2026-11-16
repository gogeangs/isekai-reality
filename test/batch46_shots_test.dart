// 묶음 46 #233·#234: 채집 미니게임 화면 미리보기 (build/screenshots/b46_*)
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
import 'package:isekai_reality/features/harvest/harvest_games.dart';
import 'package:isekai_reality/features/settings/settings_screen.dart';
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
  File('build/screenshots/b46_$name.png')
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

HarvestGameScreen _game(HarvestKind k,
        {bool first = false,
        bool? rare,
        HarvestPlay? result,
        Map<MaterialId, int>? mats,
        int streak = 0}) =>
    HarvestGameScreen(
      key: UniqueKey(),
      kind: k,
      ease: 1,
      toolAsset: 'tool_${HarvestRules.info(k).tool.name}_iron',
      toolName: '철 ${HarvestRules.info(k).toolName}',
      base: HarvestRules.info(k).base,
      first: first,
      streak: streak,
      vibrate: false,
      sound: false,
      debugRare: rare,
      debugResult: result,
      debugMats: mats,
    );

const _names = {
  HarvestKind.herb: '약초',
  HarvestKind.flower: '꽃',
  HarvestKind.mushroom: '버섯',
  HarvestKind.ore: '광석',
  HarvestKind.gem: '보석',
  HarvestKind.wood: '나무',
  HarvestKind.water: '물가',
  HarvestKind.relic: '유물',
};

void main() {
  setUpAll(_loadFonts);

  for (final d in _devices) {
    final n = d.$1;

    testWidgets('b46 $n: 여덟 게임 처음(큰 설명) · 두 번째(한 줄)', (tester) async {
      _device(tester, d);
      var i = 0;
      for (final k in HarvestKind.values) {
        i++;
        final no = i.toString().padLeft(2, '0');
        await _page(tester, _game(k, first: true));
        await _shot(tester, '${n}_${no}a_${_names[k]}_처음');
        await _page(tester, _game(k, streak: k == HarvestKind.herb ? 3 : 0, rare: false));
        // 한두 번 해 본 모습
        if (find.byKey(const Key('gameTap')).evaluate().isNotEmpty) {
          await tester.tap(find.byKey(const Key('gameTap')));
          await _settle(tester, 2);
        }
        if (k == HarvestKind.ore) {
          await tester.tap(find.byKey(const Key('rock_4')));
        }
        if (k == HarvestKind.gem) {
          await tester.tap(find.byKey(const Key('crack_0')));
          await _settle(tester, 1);
          await tester.tap(find.byKey(const Key('crack_1')));
        }
        if (k == HarvestKind.relic) {
          final area = find.byKey(const Key('brushArea'));
          final c0 = tester.getCenter(area);
          await tester.dragFrom(c0 - const Offset(80, 30), const Offset(160, 40));
          await tester.dragFrom(c0 - const Offset(60, -30), const Offset(140, 10));
        }
        if (k == HarvestKind.mushroom) {
          await tester.tap(find.byKey(const Key('mushroom_0')));
        }
        await _settle(tester, 3);
        await _shot(tester, '${n}_${no}b_${_names[k]}_두번째');
        await _page(tester, const SizedBox());
      }
    });

    testWidgets('b46 $n: 완벽·좋음·실패 연출 · 금빛 버섯 · 큰 물고기 그림자 · 그만두기', (tester) async {
      _device(tester, d);
      await _page(
          tester,
          _game(HarvestKind.mushroom,
              result: const HarvestPlay(HarvestGrade.perfect, rare: true),
              mats: {MaterialId.shadeMushroom: 3, MaterialId.moonMushroom: 1}));
      await tester.pump(const Duration(milliseconds: 380));
      await _shot(tester, '${n}_20_완벽_연출');
      await _page(tester, const SizedBox());
      await _page(
          tester,
          _game(HarvestKind.ore,
              result: const HarvestPlay(HarvestGrade.good),
              mats: {MaterialId.ironShard: 3}));
      await tester.pump(const Duration(milliseconds: 380));
      await _shot(tester, '${n}_21_좋음_연출');
      await _page(tester, const SizedBox());
      await _page(
          tester,
          _game(HarvestKind.herb,
              result: const HarvestPlay(HarvestGrade.fail),
              mats: {MaterialId.herb: 1}));
      await tester.pump(const Duration(milliseconds: 380));
      await _shot(tester, '${n}_22_실패_연출');
      await _page(tester, const SizedBox());

      await _page(tester, _game(HarvestKind.mushroom, rare: true));
      await _shot(tester, '${n}_23_금빛버섯');
      await _page(tester, const SizedBox());
      await _page(tester, _game(HarvestKind.water, rare: true));
      await _shot(tester, '${n}_24_큰물고기_그림자');
      await tester.tap(find.byKey(const Key('harvestQuit')));
      await _settle(tester, 3);
      await _shot(tester, '${n}_25_그만두기');
      await _page(tester, const SizedBox());
    });

    testWidgets('b46 $n: 설정 「소리」', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async => c = await startNpc(level: 6));
      await _page(tester, Scaffold(body: SettingsScreen(controller: c)));
      final sc = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(find.byKey(const Key('feelSound')), 200,
          scrollable: sc);
      await _settle(tester, 3);
      await _shot(tester, '${n}_26_설정_소리');
      await tester.pump(const Duration(seconds: 9));
    });
  }
}
