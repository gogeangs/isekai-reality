// 묶음 53 #243: 3막 지역 1 발드린 관문 미리보기 (build/screenshots/b53_*)
// 작은 iPhone(SE) · 큰 iPhone · Android

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/features/act3/act3_screen.dart';
import 'package:isekai_reality/features/act3/ally_screens.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/act3/act3_town.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'batch52_test.dart' as b52;
import 'batch53_test.dart' as b53;

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
  File('build/screenshots/b53_$name.png')
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

    testWidgets('b53 $n: 야영지 · 요새 · 큰 고르기 · 등불 · 모음', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async {
        final a = await b53.opened();
        await a.store.saveJson('act3', a.act3.copyWith(firstFight: true, energy: 80).toJson());
        c = (await b52.start(a.store as InMemoryRecordStore)).$1;
        await c.recruit();
      });
      await _page(tester, Act3Screen(key: ObjectKey('m$n'), controller: c));
      await _shot(tester, '${n}_01_지도_느낌표');
      await _page(tester, TownScreen(key: ObjectKey('t$n'), controller: c));
      await _shot(tester, '${n}_02_야영지');
      await tester.tap(find.byKey(const Key('resident_volk')));
      await _settle(tester, 3);
      await _shot(tester, '${n}_03_볼크_이야기');
      for (var i = 0; i < BaldrinRules.volkTalk.length; i++) {
        await tester.tap(find.byKey(const Key('talkNext')));
        await _settle(tester, 2);
      }
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await _settle(tester, 2);
      await tester.tap(find.byKey(const Key('resident_hanna')));
      await _settle(tester, 3);
      await _shot(tester, '${n}_04_한나_부탁');
      await tester.tap(find.byKey(const Key('questTake')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await _settle(tester, 3);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
      await _settle(tester, 3);
      await _shot(tester, '${n}_05_여관_노점_의뢰판');
      await tester.runAsync(() async {
        await c.store.saveJson('act3', c.act3.copyWith(flags: {...c.act3.flags, 'wallFought'}).toJson());
        c = (await b52.start(c.store as InMemoryRecordStore)).$1;
      });
      await _page(tester, LetterChoiceScreen(key: ObjectKey('l$n'), controller: c));
      await _shot(tester, '${n}_06_테오의_편지');
      await tester.runAsync(() async => c.chooseLetter(marta: false));
      await _page(tester, FortScreen(key: ObjectKey('f$n'), controller: c));
      await _shot(tester, '${n}_07_지하요새');
      await tester.runAsync(() async {
        final fights = c.enterFloor()!;
        for (final e in fights) {
          await b53.fight(c, e);
        }
      });
      await _page(tester, Act3BattleScreen(
          key: ObjectKey('b$n'),
          controller: c,
          encounter: const A3Enc(kind: A3Kind.mid, foes: [MonsterId.ashHounds],
              place: 'baldrin_fort', background: BaldrinRules.dungeonBg),
          tickInterval: const Duration(milliseconds: 400)));
      await _settle(tester, 8);
      await _shot(tester, '${n}_08_중간보스');
      await _page(tester, LampScreen(key: ObjectKey('p$n'), controller: c));
      for (var i = 0; i < 14; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }
      await _shot(tester, '${n}_09_등불');
      await _page(tester, UniqueBookScreen(key: ObjectKey('u$n'), controller: c));
      await _shot(tester, '${n}_10_이름있는장비');
      await _page(tester, AllyDetailScreen(key: ObjectKey('a$n'), controller: c, allyId: c.nameless.first.id));
      await _shot(tester, '${n}_11_동료_직업그림');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 9));
    });
  }
}
