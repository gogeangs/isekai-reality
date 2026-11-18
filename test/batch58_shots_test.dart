// 묶음 58: 지역 의뢰 · 심층 순위 · 테스 일지 · 거래소 미리보기 (build/screenshots/b58_*)
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
import 'package:isekai_reality/core/models/armory.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/act3/act3_screen.dart';
import 'package:isekai_reality/features/act3/region_screens.dart';
import 'package:isekai_reality/features/village/board_screen.dart';
import 'package:isekai_reality/features/village/market_screen.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'batch52_test.dart' as b52;
import 'batch56_test.dart' as b56;
import 'batch57_regions_test.dart' as r57;
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
  File('build/screenshots/b58_$name.png')
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

    testWidgets('b58 $n: 지역 의뢰 · 테스 일지 · 심층 순위', (tester) async {
      _device(tester, d);
      late AppController c;
      late FakeArca a;
      await tester.runAsync(() async {
        final base = await r57.inRegion(RegionRules.aurel, more: {
          'aurel:arrive', 'aurel:first', 'aurel:talk', 'aurel:event', 'aurel:choice:share', 'act3End', 'ember:aurel', 'ember:selenia',
          for (final x in RegionRules.all) ...{'reach:${x.prefix}', '${x.prefix}:lamp'},
        });
        final r = await b56.start();
        a = r.$2;
        a.deepRows['other'] = 0;
        a.deepRows[a.uid] = 14;
        await r.$1.store.saveJson('act3', base.act3.copyWith(
          quests: {'aur_record': 1, 'aur_stones': 1},
          prog: {'aur_record': 3200, 'aur_stones': 1, 'aurel:floorBest': 5, 'aurel:deepBest': 14},
        ).toJson());
        await r.$1.store.saveJson('board', {
          'day': DailyRecord.dayKeyOf(b52.t0),
          'slots': [
            {'templateId': 'seleniaHunt3', 'accepted': true, 'baseline': 0},
            {'templateId': 'aurelGather2', 'accepted': false, 'baseline': 0},
            {'templateId': 'morvalFloor2', 'accepted': false, 'baseline': 0},
          ],
          'doneToday': 0,
          'seq': 3,
        });
        c = (await b56.start(store: r.$1.store as InMemoryRecordStore, arca: a)).$1;
      });
      await _page(tester, BoardScreen(key: ObjectKey('b$n'), controller: c));
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await _settle(tester);
      await _shot(tester, '${n}_01_하르트_지역의뢰');
      await _page(tester, Act3Screen(key: ObjectKey('j$n'), controller: c, tab: 1));
      await _shot(tester, '${n}_02_테스_일지');
      await _page(tester, DeepRankScreen(key: ObjectKey('r$n'), controller: c));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await _settle(tester);
      await _shot(tester, '${n}_03_심층순위');
    });

    testWidgets('b58 $n: 거래소 사기 · 올리기 · 경매 · 내 장부', (tester) async {
      _device(tester, d);
      late AppController c;
      late FakeArca a;
      await tester.runAsync(() async {
        final r = await b56.start();
        a = r.$2;
        final today = r.$1.history.last;
        await r.$1.store.upsert(today.copyWith(
            gains: DailyRecord.addCounts(today.gains, {'herb': 12, 'stardust': 3, 'gold': 3000}),
            goldPurchases: [...today.goldPurchases, 'healSmall', 'healSmall']));
        await r.$1.store.saveJson('village', {
          ...?(await r.$1.store.loadJson('village')),
        });
        c = (await b56.start(store: r.$1.store as InMemoryRecordStore, arca: a)).$1;
        await c.markMarketIntro();
        await c.markWalletIntro();
        Map<String, dynamic> row(String id, String kind, String key, String name, int qty, int price,
                {String mode = 'fixed', String seller = '별', EquipItem? e, int? bid, int bids = 0, int? buyNow}) =>
            {
              'id': id, 'kind': kind, 'key': key, 'name': name, 'qty': qty, 'mode': mode,
              if (mode == 'fixed') 'price': price else 'start': price,
              'bid': bid, 'bids': bids, 'buyNow': buyNow, 'next': bid == null ? price : bid + (bid * 0.05).ceil(),
              'sellerName': seller, 'status': 'open',
              'endsAt': b52.t0.add(Duration(hours: mode == 'fixed' ? 40 : 5)).millisecondsSinceEpoch,
              if (e != null) 'equip': e.toJson(),
            };
        a.listings.addAll([
          row('l1', 'mat', 'herb', '약초', 5, 30),
          row('l2', 'item', 'healSmall', '작은 회복 물약', 3, 45, seller: '달빛'),
          row('l3', 'equip', 'dagger', '단검', 1, 260, seller: '하늘',
              e: EquipItem(uid: 'x', base: EquipBase.dagger, grade: EquipGrade.blue, enhance: 2)),
          row('l4', 'mat', 'stardust', '별가루', 2, 120, seller: '모래'),
          row('l5', 'egg', 'egg', '알', 1, 200, mode: 'auction', bid: 260, bids: 3, buyNow: 600),
          row('l6', 'equip', 'seleniaHead', '셀레니아 상단 두건', 1, 300, mode: 'auction', seller: '해',
              e: EquipItem(uid: 'y', base: EquipBase.seleniaHead, grade: EquipGrade.purple)),
        ]);
      });
      await _page(tester, MarketScreen(key: ObjectKey('m$n'), controller: c));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await _settle(tester);
      await _shot(tester, '${n}_10_거래소_사기');
      await tester.scrollUntilVisible(find.byKey(const Key('listingAct_l3')), 200,
          scrollable: find.byType(Scrollable).first);
      await _settle(tester, 2);
      await tester.tap(find.byKey(const Key('listingAct_l3')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await _settle(tester);
      await _shot(tester, '${n}_11_사기_확인');
      await tester.tap(find.text('그만두기'));
      await _settle(tester);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
      await _settle(tester, 2);
      await tester.tap(find.byKey(const Key('marketTab_1')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await _settle(tester);
      await _shot(tester, '${n}_12_올리기');
      await tester.ensureVisible(find.byKey(const Key('sell_herb')));
      await _settle(tester, 2);
      await tester.tap(find.byKey(const Key('sell_herb')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('sellQtyUp')));
      await tester.tap(find.byKey(const Key('sellQtyUp')));
      await _settle(tester);
      await _shot(tester, '${n}_13_올리기_창');
      await tester.tap(find.byKey(const Key('sellAuction')));
      await _settle(tester);
      await tester.enterText(find.byKey(const Key('sellBuyNow')), '80');
      await _settle(tester);
      await _shot(tester, '${n}_14_올리기_경매');
      await tester.tap(find.byKey(const Key('sellOk')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await _settle(tester);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
      await _settle(tester, 2);
      await tester.tap(find.byKey(const Key('marketTab_2')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await _settle(tester);
      await _shot(tester, '${n}_15_경매');
      await tester.ensureVisible(find.byKey(const Key('listingAct_l5')));
      await _settle(tester, 2);
      await tester.tap(find.byKey(const Key('listingAct_l5')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await _settle(tester);
      await _shot(tester, '${n}_16_입찰');
      await tester.tap(find.text('그만두기'));
      await _settle(tester);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
      await _settle(tester, 2);
      await tester.tap(find.byKey(const Key('marketTab_3')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await _settle(tester);
      await _shot(tester, '${n}_17_내장부');
    });
  }
}
