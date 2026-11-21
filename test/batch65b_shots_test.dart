// 묶음 65 (2/2): 많이 걸은 날 · 높은 레벨 경험치 · 영지 관리 (build/screenshots/b65b_*)
// 작은 iPhone(SE) · 큰 iPhone · Android

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/act5_state.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/features/status/status_screen.dart';
import 'package:isekai_reality/features/status/step_chest_row.dart';
import 'package:isekai_reality/theme/ornaments.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/features/act5/erbard_screens.dart';
import 'package:isekai_reality/features/act5/estate_manage_screen.dart';
import 'package:isekai_reality/features/map/map_screen.dart';
import 'package:isekai_reality/features/profile/profile_screen.dart';
import 'package:isekai_reality/features/town/inn_screen.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'batch52_test.dart' as b52;
import 'batch56_test.dart' as b56;
import 'batch60_test.dart' as b60;
import 'support/fake_arca.dart';
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
  File('build/screenshots/b65b_$name.png')
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


const _ch3 = Act5State(opened: true, chapter: 3, seen: {'e1a', 'e1b', 'e1c', 'e2a', 'e2b'}, ticketAt: -60000, pioneered: true, ch3Siege: 0);

Future<(AppController, FakeArca)> _estate() async {
  final (c, a) = await b60.act5(guild: true, state: _ch3);
  a.siegeOwners['sol_lily'] = {'gid': 'mine', 'name': '새벽걸음', 'emblem': 2, 'color': 3};
  a.siegeOwners['sol_bell'] = {'gid': 'mine', 'name': '새벽걸음', 'emblem': 2, 'color': 3};
  a.siegeOwners['dor_deep'] = {'gid': 'other', 'name': '노을', 'emblem': 1, 'color': 1};
  a.treasury = 18400;
  a.matPool = 64;
  a.stages['sol_lily'] = 1;
  a.stages['dor_deep'] = 2;
  a.estateDev['sol_lily'] = {'fac': {'wall': 2, 'light': 1}};
  a.guildStore.addAll({'lightRelic': 9, 'metalOre': 2});
  b56.now = DateTime(2026, 12, 1, 10);
  await c.refreshErbard();
  await c.refreshEstateDev();
  return (c, a);
}

void main() {
  setUpAll(_loadFonts);
  setUp(() => b56.now = b52.t0);

  for (final d in _devices) {
    final n = d.$1;

    testWidgets('b65b $n: 1만5천 보 날 — 홈 걸음 상자 · 정령 한 줄 · 열쇠 조각 · 여관 내역', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async => c = await startNpc(
            level: 24,
            todaySteps: const {'2026-11-20': 15200},
            more: [DailyRecord(date: DateTime(2026, 11, 19), steps: 8000)],
            clock: () => DateTime(2026, 11, 20, 18),
          ));
      await _page(tester, Scaffold(
        body: NightBackground(
          child: ListenableBuilder(
            listenable: c,
            builder: (context, _) => StatusScreen(
              player: c.player,
              hp: c.hp,
              mp: c.mp,
              maxHp: c.maxHp,
              mpMax: c.mpMax,
              armory: c.armory,
              lifeLine: c.walkTalk ?? c.statusLifeLine,
              look: c.profile.look,
              now: c.now,
              requestPanel: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [StepChestRow(controller: c)]),
            ),
          ),
        ),
      ));
      await _settle(tester, 8);
      await _shot(tester, '${n}_01_홈_걸음상자');
      await tester.scrollUntilVisible(find.byKey(const Key('stepChestRow')), 200, scrollable: find.byType(Scrollable).first);
      await _settle(tester);
      await _shot(tester, '${n}_02_홈_걸음상자_아래');
      await tester.tap(find.byKey(const Key('stepChestRow')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await _settle(tester);
      await _shot(tester, '${n}_03_걸음상자_열기');
      await tester.pumpWidget(const SizedBox());
      await _page(tester, Scaffold(
          backgroundColor: const Color(0xFF0B0D26),
          body: SafeArea(
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              Padding(
                padding: const EdgeInsets.all(10),
                child: SizedBox(height: 56, child: DungeonStrip(gauge: c.player.gauge, onOpen: () {})),
              ),
            ]),
          )));
      await _shot(tester, '${n}_04_열쇠조각_게이지');
      await _page(tester, InnScreen(key: ObjectKey('inn$n'), controller: c));
      await tester.scrollUntilVisible(find.byKey(const Key('innFootprint')), 200, scrollable: find.byType(Scrollable).first);
      await _settle(tester);
      await _shot(tester, '${n}_05_여관_발자국');
    });

    testWidgets('b65b $n: 영지 관리 — 번영도 · 시설 · 정책 · 주민 의뢰 · 창고 · 기부 · 지도 아이콘', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async => (c, _) = await _estate());
      await _page(tester, ErbardScreen(key: ObjectKey('m$n'), controller: c));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await _settle(tester);
      await _shot(tester, '${n}_06_지도_번영');
      await _page(tester, EstateManageScreen(key: ObjectKey('e$n'), controller: c, estate: ErbardRules.estate('sol_lily')!));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await _settle(tester);
      await _shot(tester, '${n}_07_영지관리_위');
      await tester.tap(find.byKey(const Key('facBuild_tower')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await _settle(tester);
      await _shot(tester, '${n}_08_시설짓기');
      await tester.scrollUntilVisible(find.byKey(const Key('estatePolicy')), 300, scrollable: find.byType(Scrollable).first);
      Scrollable.ensureVisible(tester.element(find.byKey(const Key('estatePolicy'))), alignment: 0.02);
      await _settle(tester);
      await _shot(tester, '${n}_09_정책_주민의뢰');
      await tester.scrollUntilVisible(find.byKey(const Key('estateDonate')), 300, scrollable: find.byType(Scrollable).first);
      await _settle(tester);
      await _shot(tester, '${n}_10_창고_기부');
    });

    testWidgets('b65b $n: 선봉장 칭호', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async {
        final (cc, a) = await b60.act5(guild: true, state: _ch3);
        c = cc;
        b56.now = DateTime(2026, 11, 30, 10);
        a.inbox.add({'id': 'v0', 'from': '세라', 'title': '제1회 깃발 공성전 선봉장', 'reward': <String, int>{}, 'equips': [], 'op': {'vanguard': 0}});
        await c.checkInquiryInbox();
        final m = c.mail.mails.firstWhere((x) => x.title.contains('선봉장'));
        await c.claimMail(m.id);
        await c.sync();
      });
      await _page(tester, ProfileScreen(key: ObjectKey('t$n'), controller: c));
      await tester.scrollUntilVisible(find.text('선봉장').first, 300, scrollable: find.byType(Scrollable).first);
      await _settle(tester);
      await _shot(tester, '${n}_11_선봉장');
    });
  }
}
