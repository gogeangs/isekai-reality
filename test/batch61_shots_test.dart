// 묶음 61: 길드 금고 · 흑등 수비대 · 가짜 위치 띠 · 거래 지갑 (build/screenshots/b61_*)
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
import 'package:isekai_reality/core/models/act5_state.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/act4/act4_screens.dart';
import 'package:isekai_reality/features/act5/erbard_screens.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/features/village/market_screen.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'batch52_test.dart' as b52;
import 'batch56_test.dart' as b56;
import 'batch60_test.dart' as b60;
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
  File('build/screenshots/b61_$name.png')
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
Future<(AppController, FakeArca)> _guild() async {
  final (c, a) = await b60.act5(
      guild: true,
      state: const Act5State(opened: true, chapter: 3, seen: {'e1a', 'e1b', 'e1c', 'e2a', 'e2b'}, ticketAt: -14000, pioneered: true, ch3Siege: 0));
  a.siegeOwners['sol_lily'] = {'gid': 'mine', 'name': '새벽걸음', 'emblem': 2, 'color': 3};
  a.siegeOwners['dor_wind'] = {'gid': 'other', 'name': '노을', 'emblem': 1, 'color': 1};
  a.garrisons['sol_lily'] = [
    {'name': '별하', 'level': 31, 'job': 'mage', 'allies': ['도윤'], 'me': false},
    {'name': '하루', 'level': 30, 'job': 'warrior', 'allies': ['리안', '가렌'], 'me': true},
    {'name': '모래', 'level': 27, 'job': 'herbalist', 'allies': <String>[], 'me': false},
    {'name': '해솔', 'level': 24, 'job': 'nightWalker', 'allies': <String>[], 'me': false},
    null,
  ];
  a.guildStar = 2;
  a.guildLevel = 4;
  a.guildDecos.addAll(['lights', 'fountain']);
  a.guildSlots
    ..[0] = 'lights'
    ..[1] = 'fountain';
  for (final e in {
    'u2': ('별하', 31, 48210, 'vice', '오늘도 만 보!'),
    'u3': ('모래', 27, 39550, 'member', '레이드 같이 가요'),
  }.entries) {
    a.guildMembers[e.key] = {'name': e.value.$1, 'level': e.value.$2, 'weekSteps': e.value.$3, 'role': e.value.$4, 'line': e.value.$5};
  }
  a.treasury = 42800;
  a.canShare = true;
  await c.refreshErbard();
  await c.refreshGuild();
  // 금고 쓰기 기록 몇 줄
  await c.boostGarrison('sol_lily', 2);
  await c.treasuryShop('goldLights');
  await c.treasuryShop('goldFlag');
  await c.treasuryHall(1000);
  await c.placeDeco(3, 'goldLights');
  return (c, a);
}

void main() {
  setUpAll(_loadFonts);
  setUp(() => b56.now = b52.t0);

  for (final d in _devices) {
    final n = d.$1;

    testWidgets('b61 $n: 길드 금고 · 수비대 강화 · 나눠 주기 · 금고 상점', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async => (c, _) = await _guild());
      await _page(tester, GuildHallScreen(key: ObjectKey('g$n'), controller: c));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await _settle(tester);
      await _shot(tester, '${n}_01_길드_금빛깃발');
      await tester.tap(find.byKey(const Key('guildTab_1')));
      await _settle(tester);
      await _shot(tester, '${n}_02_회관_금빛꾸미기');
      await tester.scrollUntilVisible(find.byKey(const Key('guildTreasury')), 300, scrollable: find.byType(Scrollable).first);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
      await _settle(tester);
      await _shot(tester, '${n}_03_길드금고');
      await tester.scrollUntilVisible(find.byKey(const Key('guildBoard')), 300, scrollable: find.byType(Scrollable).first);
      await _settle(tester);
      await _shot(tester, '${n}_04_게시판_금고기록');
      await Scrollable.ensureVisible(tester.element(find.byKey(const Key('treasuryShare'))), alignment: 0.5);
      await _settle(tester, 2);
      await tester.tap(find.byKey(const Key('treasuryShare')));
      await _settle(tester);
      await _shot(tester, '${n}_05_나눠주기');
      await _page(tester, GarrisonScreen(key: ObjectKey('gs$n'), controller: c, estate: ErbardRules.estate('sol_lily')!));
      await _shot(tester, '${n}_06_수비대_분신그림');
      await tester.scrollUntilVisible(find.byKey(const Key('garrisonBoost')), 300, scrollable: find.byType(Scrollable).first);
      await _settle(tester);
      await _shot(tester, '${n}_07_수비대강화');
    });

    testWidgets('b61 $n: 흑등 수비대 · 지휘관 · 다른 길드 분신 · 가짜 위치 띠', (tester) async {
      _device(tester, d);
      late AppController c;
      late FakeArca a;
      await tester.runAsync(() async {
        (c, a) = await _guild();
        a.siegeActive = true;
        b56.now = DateTime(2026, 11, 28, 10);
        await c.refreshErbard();
      });
      Battle? b;
      await tester.runAsync(() async => b = await c.startErbardFight(ErbardRules.estate('sol_silver')!));
      await _page(tester, ErbardBattleScreen(key: ObjectKey('b1$n'), controller: c, battle: b!, estate: ErbardRules.estate('sol_silver')!, tickInterval: const Duration(milliseconds: 200)));
      await _settle(tester, 10);
      await _shot(tester, '${n}_08_흑등용병');
      await tester.runAsync(() async {
        await c.finishErbardFight(b!);
        a.siegeRun['sol_silver'] = [0, 1, 2, 3];
        b = await c.startErbardFight(ErbardRules.estate('sol_silver')!);
      });
      await _page(tester, ErbardBattleScreen(key: ObjectKey('b2$n'), controller: c, battle: b!, estate: ErbardRules.estate('sol_silver')!, tickInterval: const Duration(milliseconds: 200)));
      await _settle(tester, 10);
      await _shot(tester, '${n}_09_흑등지휘관');
      await tester.runAsync(() async {
        await c.finishErbardFight(b!);
        b = await c.startErbardFight(ErbardRules.estate('dor_wind')!);
      });
      await _page(tester, ErbardBattleScreen(key: ObjectKey('b3$n'), controller: c, battle: b!, estate: ErbardRules.estate('dor_wind')!, tickInterval: const Duration(milliseconds: 200)));
      await _settle(tester, 10);
      await _shot(tester, '${n}_10_다른길드분신');
      await _page(tester, GuildHallScreen(key: ObjectKey('m$n'), controller: c));
      showTopNotice(tester.element(find.byKey(const Key('guildTab_0'))), FairOps.mockLine, icon: Icons.location_off_rounded);
      await _settle(tester, 3);
      await _shot(tester, '${n}_11_가짜위치띠');
    });

    testWidgets('b61 $n: 거래 지갑 · 맡기기 · 꺼내기', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async {
        final r = await b56.start();
        final t = r.$1.history.last;
        await r.$1.store.upsert(t.copyWith(gains: DailyRecord.addCounts(t.gains, {Wallet.gold: 5200})));
        c = (await b56.start(store: r.$1.store as InMemoryRecordStore, arca: r.$2)).$1;
        r.$2.wallet = 1350;
        r.$2.listings.add({'id': 'o1', 'kind': 'mat', 'key': 'herb', 'name': '약초', 'qty': 5, 'mode': 'fixed', 'price': 60, 'status': 'open', 'sellerName': '별'});
        await c.markMarketIntro();
      });
      await _page(tester, MarketScreen(key: ObjectKey('mk$n'), controller: c));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await _settle(tester);
      await _shot(tester, '${n}_12_지갑_바르칸');
      await tester.tap(find.text('알겠어요'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await _settle(tester);
      await _shot(tester, '${n}_13_거래소_지갑');
      await tester.tap(find.byKey(const Key('walletDeposit')));
      await _settle(tester);
      await tester.enterText(find.byKey(const Key('walletAmount')), '1000');
      await _settle(tester, 2);
      await _shot(tester, '${n}_14_맡기기');
      Navigator.of(tester.element(find.byKey(const Key('walletAmount')))).pop();
      await _settle(tester);
      await tester.tap(find.byKey(const Key('walletWithdraw')));
      await _settle(tester);
      await tester.enterText(find.byKey(const Key('walletAmount')), '500');
      await _settle(tester, 2);
      await _shot(tester, '${n}_15_꺼내기');
    });
  }
}
