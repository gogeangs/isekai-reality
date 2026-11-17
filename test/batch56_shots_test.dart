// 묶음 56: 파티 · 문의 미리보기 (build/screenshots/b56_*)
// 작은 iPhone(SE) · 큰 iPhone · Android

import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/cloud/cloud_auth.dart';
import 'package:isekai_reality/features/party/party_boss_screen.dart';
import 'package:isekai_reality/features/settings/inquiry_screen.dart';
import 'package:isekai_reality/features/village/tavern_screen.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'batch52_test.dart' as b52;
import 'batch56_test.dart' as b56;
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
  File('build/screenshots/b56_$name.png')
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

    testWidgets('b56 $n: 파티 탭 · 보스 · 상점 · 꾸미기 · 문의', (tester) async {
      _device(tester, d);
      late AppController c;
      late FakeArca a;
      await tester.runAsync(() async {
        final r = await b56.start(steps: 9600, login: false);
        c = r.$1;
        a = r.$2;
        await c.store.saveJson('party', {'tickets': 85, 'together': 7, 'emblems': [5]});
        c = (await b56.start(steps: 9600, login: false, store: c.store as dynamic, arca: a)).$1;
      });
      await _page(tester, TavernScreen(key: ObjectKey('l$n'), controller: c, partyTab: true));
      await _shot(tester, '${n}_01_로그인안내');
      await tester.runAsync(() async {
        await c.signInCloud(LoginProvider.google);
        await c.refreshParty();
      });
      await _page(tester, TavernScreen(key: ObjectKey('s$n'), controller: c, partyTab: true));
      await _shot(tester, '${n}_02_만들기_들어가기');
      await tester.runAsync(() async {
        await c.createParty('새벽 원정대');
        a.addMember('ABC234', 'u_star', '별', stepsWeek: 48200);
        a.addMember('ABC234', 'u_moon', '달', stepsWeek: 21500);
        a.cheeredBy = '별';
        a.near = true;
        await c.refreshParty();
        await c.styleParty(emblem: 5, color: 4);
        c.takePartyNotice();
      });
      await _page(tester, TavernScreen(key: ObjectKey('p$n'), controller: c, partyTab: true));
      await _shot(tester, '${n}_03_파티');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -560));
      await _settle(tester, 3);
      await _shot(tester, '${n}_04_함께걷기_보스');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -560));
      await _settle(tester, 3);
      await _shot(tester, '${n}_05_함께사냥_상점버튼');
      await tester.tap(find.byKey(const Key('partyShopOpen')));
      await _settle(tester, 4);
      await _shot(tester, '${n}_06_파티상점');
      await tester.tapAt(const Offset(10, 60));
      await _settle(tester, 4);
      await tester.tap(find.byKey(const Key('partyStyleOpen')));
      await _settle(tester, 4);
      await _shot(tester, '${n}_07_꾸미기');
      late Battle b;
      await tester.runAsync(() async {
        b = c.startPartyBoss()!;
      });
      await _page(tester, PartyBossScreen(
          key: ObjectKey('b$n'), controller: c, battle: b, tickInterval: const Duration(milliseconds: 400)));
      await _settle(tester, 8);
      await _shot(tester, '${n}_08_보스_싸움');
      await _page(tester, InquiryScreen(
          key: ObjectKey('i$n'),
          controller: c,
          model: 'iPhone15,2 · iOS 26.1',
          picker: () async => Uint8List(0)));
      await tester.tap(find.byKey(const Key('inquiryKind_bug')));
      await tester.enterText(find.byKey(const Key('inquiryText')), '원정 보낸 펫이 돌아오지 않아요. 지도를 다시 열어도 그대로예요.');
      await _settle(tester, 2);
      await _shot(tester, '${n}_09_문의');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await _settle(tester, 2);
      await _shot(tester, '${n}_10_문의_함께보내는것');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 9));
    });
  }
}
