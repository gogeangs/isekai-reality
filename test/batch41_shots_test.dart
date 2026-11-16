// 묶음 41: 작은 iPhone(SE) · 큰 iPhone · Android 화면 미리보기 (build/screenshots/b41_*)
// 글자 크기 기본·한 단계 크게(×1.12) 두 가지로 잡화상 사기·팔기를 찍는다.
// 묶음 41 확인 답: 알림 띠가 떠 있는 채로 연달아 사기 · 팔고 바로 다른 줄 고르기 (b41n_*)

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/rules/rules.dart';

import 'package:isekai_reality/features/town/shop_screen.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'support/shop_seed.dart';

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
  File('build/screenshots/b41_$name.png')
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

Future<void> _shop(WidgetTester tester, AppController c) async {
  await tester.pumpWidget(RepaintBoundary(
    key: _root,
    child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ShopScreen(key: ObjectKey(c), controller: c)),
  ));
  await _settle(tester);
}

Future<void> _scrollTo(WidgetTester tester, String list, String key,
    {double delta = 150}) async {
  await tester.scrollUntilVisible(find.byKey(Key(key)), delta,
      scrollable: find.descendant(
          of: find.byKey(Key(list)), matching: find.byType(Scrollable))
          .first);
  Scrollable.ensureVisible(tester.element(find.byKey(Key(key))),
      alignment: 0.5);
  await _settle(tester, 3);
}

void main() {
  setUpAll(_loadFonts);

  for (final d in _devices) {
    for (final (tn, ts) in const [('기본', 1.0), ('크게', 1.12)]) {
      final n = '${d.$1}_글자$tn';

      testWidgets('b41 $n: 잡화상 사기·팔기', (tester) async {
        _device(tester, d, text: ts);
        late AppController c;
        await tester.runAsync(() async => c = await startShop());
        await _shop(tester, c);
        await _shot(tester, '${n}_01_사기_첫화면');
        await tester.drag(
            find.byKey(const Key('shopList')), const Offset(0, -500));
        await _settle(tester, 4);
        await _shot(tester, '${n}_02_사기_내린뒤');
        await _scrollTo(tester, 'shopList', 'shopItem_bulssiPotion');
        await _shot(tester, '${n}_03_사기_흐린카드_다산것_Lv전');
        await tester.drag(
            find.byKey(const Key('shopList')), const Offset(0, 3000));
        await _settle(tester, 4);
        await tester.tap(find.byKey(const Key('shopChip_travel')));
        await _settle(tester, 3);
        await _shot(tester, '${n}_04_사기_여행도구');
        await tester.tap(find.byKey(const Key('shopChip_material')));
        await _settle(tester, 3);
        await _shot(tester, '${n}_05_사기_재료');
        await tester.tap(find.byKey(const Key('shopChip_potion')));
        await _settle(tester, 3);
        await tester.tap(find.byKey(const Key('shopItem_manaSmall')));
        await _settle(tester);
        await tester.tap(find.byKey(const Key('buyPlus')));
        await _settle(tester, 2);
        await _shot(tester, '${n}_06_수량창');
        await tester.tap(find.byKey(const Key('buyCancel')));
        await _settle(tester);
        await tester.tap(find.byKey(const Key('shopChip_travel')));
        await _settle(tester, 3);
        await tester.tap(find.byKey(const Key('shopItem_spareKey')));
        await _settle(tester);
        await _shot(tester, '${n}_07_수량창_최대1');
        await tester.tap(find.byKey(const Key('buyCancel')));
        await _settle(tester);

        await tester.tap(find.byKey(const Key('shopTab_1')));
        await _settle(tester, 3);
        await tester.tap(find.byKey(const Key('sellRow_m:ratHide')));
        await _scrollTo(tester, 'sellList', 'sellRow_m:glossyFur');
        await tester.tap(find.byKey(const Key('sellRow_m:glossyFur')));
        await _settle(tester, 2);
        await _shot(tester, '${n}_08_팔기_재료_골라팔기');
        await tester.tap(find.byKey(const Key('sellChip_equip')));
        await _settle(tester, 3);
        await _shot(tester, '${n}_09_팔기_장비_입는중');
        expect(tester.takeException(), isNull);

        // 금화가 모자란 계정
        await tester.runAsync(() async =>
            c = await startShop(gold: 15, stones: 4, shopped: false));
        await _shop(tester, c);
        await tester.tap(find.byKey(const Key('shopChip_travel')));
        await _settle(tester, 3);
        await _shot(tester, '${n}_10_사기_금화부족');
        await tester.tap(find.byKey(const Key('shopTab_1')));
        await _settle(tester, 3);
        await _shot(tester, '${n}_11_팔기_마석4개');
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 9));
      });

      testWidgets('b41n $n: 알림 띠가 떠 있어도 바로 누르기', (tester) async {
        _device(tester, d, text: ts);
        late AppController c;
        await tester.runAsync(() async => c = await startShop(shopped: false));
        await tester.pumpWidget(RepaintBoundary(
          key: _root,
          child: MaterialApp(
              debugShowCheckedModeBanner: false,
              builder: (context, child) => TopNoticeHost(child: child!),
              home: ShopScreen(key: ObjectKey(c), controller: c)),
        ));
        await _settle(tester);
        for (var k = 0; k < 2; k++) {
          await tester.tap(find.byKey(const Key('shopItem_healSmall')));
          await _settle(tester);
          await tester.tap(find.byKey(const Key('buyConfirm')));
          await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 80)));
          await _settle(tester, 2);
        }
        await _shot(tester, '${n}_n1_연달아_2번_사기');
        await tester.tap(find.byKey(const Key('shopTab_1')));
        await _settle(tester, 3);
        await tester.tap(find.byKey(const Key('sellRow_m:ironShard')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('sellPicked')));
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 80)));
        await _settle(tester, 2);
        await tester.tap(find.byKey(const Key('sellRow_m:twig')));
        await _settle(tester, 1);
        await _shot(tester, '${n}_n2_팔고_바로_다른줄');
        expect(c.bagCount(ShopItem.healSmall), 2);
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 9));
      });
    }
  }
}
