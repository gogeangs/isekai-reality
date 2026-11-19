// 묶음 73 다시 보냄 10: 파티 플레이 캡처 (새 주인공 · 남녀, build/screenshots/b73p_*) — 큰 iPhone

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/geo/geo.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/cloud/cloud_auth.dart';
import 'package:isekai_reality/data/storage/record_store.dart' show HeroLook;
import 'package:isekai_reality/features/act3/act3_screen.dart';
import 'package:isekai_reality/features/act4/act4_screens.dart';
import 'package:isekai_reality/features/highland/highland_screen.dart';
import 'package:isekai_reality/features/party/party_boss_screen.dart';
import 'package:isekai_reality/features/village/tavern_screen.dart';
import 'package:isekai_reality/features/village/training_screen.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'batch50_test.dart' as b50;
import 'batch52_test.dart' as b52;
import 'batch56_test.dart' as b56;
import 'batch59_test.dart' as b59;
import 'support/fake_arca.dart';
import 'support/village_seed.dart';

final _root = GlobalKey();

Future<void> _loadFonts() async {
  // 묶음 71: 글꼴을 정하지 않은 글자(버튼 등)는 시험 기본 글꼴(FlutterTest)로 그려져 □로 나옴 —
  // 기기처럼 한글이 보이게 그 이름에도 한글 글꼴을 넣는다
  for (final family in ['Roboto', 'FlutterTest']) {
    final korean = FontLoader(family);
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
  }
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
  File('build/screenshots/b73p_$name.png')
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
        // 기기에선 글꼴을 정하지 않은 글자가 휴대폰 기본 글꼴(한글 있음)로 나옴 — 시험에서도 한글 글꼴로
        theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Roboto'),
        builder: (context, child) => TopNoticeHost(child: child!),
        home: home),
  ));
  await _settle(tester);
}





Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
  await _settle(tester, 3);
}

/// 각성자가 4칸(주먹이 닿는 순간)일 때까지
Future<void> _punch(WidgetTester tester) async {
  for (var i = 0; i < 200 && find.byKey(const Key('heroFrame_3')).evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  setUpAll(_loadFonts);
  final d = _devices[1];

  for (final look in HeroLook.values) {
    final n = look == HeroLook.male ? '남' : '여';

    testWidgets('b73p $n: 파티 · 보스 · 상점 · 꾸미기', (tester) async {
      _device(tester, d);
      b56.now = b52.t0;
      late AppController c;
      late FakeArca a;
      await tester.runAsync(() async {
        final r = await b56.start(steps: 9600, login: false);
        c = r.$1;
        a = r.$2;
        await c.store.saveJson('party', {'tickets': 85, 'together': 7, 'emblems': [5]});
        c = (await b56.start(steps: 9600, login: false, store: c.store as dynamic, arca: a)).$1;
        c.debugLook(look);
        await c.signInCloud(LoginProvider.google);
        await c.refreshParty();
      });
      await _page(tester, TavernScreen(key: ObjectKey('s$n'), controller: c, partyTab: true));
      await _shot(tester, '${n}_01_파티만들기');
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
      await _shot(tester, '${n}_02_파티화면');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -560));
      await _settle(tester, 3);
      await _shot(tester, '${n}_03_함께걷기');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -560));
      await _settle(tester, 3);
      await _shot(tester, '${n}_04_함께사냥');
      await tester.tap(find.byKey(const Key('partyShopOpen')));
      await _settle(tester, 4);
      await _shot(tester, '${n}_05_파티상점');
      await tester.tapAt(const Offset(10, 60));
      await _settle(tester, 4);
      await tester.tap(find.byKey(const Key('partyStyleOpen')));
      await _settle(tester, 4);
      await _shot(tester, '${n}_06_깃발꾸미기');
      Navigator.of(tester.element(find.byKey(const Key('partyStyleSheet')))).pop();
      await _settle(tester, 4);
      late Battle b;
      await tester.runAsync(() async => b = c.startPartyBoss()!);
      await _page(tester,
          PartyBossScreen(key: ObjectKey('b$n'), controller: c, battle: b, tickInterval: const Duration(milliseconds: 900)));
      await _shot(tester, '${n}_07_파티보스_대기');
      await _punch(tester);
      await _shot(tester, '${n}_08_파티보스_공격4칸');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('b73p $n: 길드 레이드 · 3막 지역 싸움 · 훈련장', (tester) async {
      _device(tester, d);
      b56.now = b52.t0;
      late AppController c;
      await tester.runAsync(() async {
        final a = FakeArca();
        (c, _) = await b59.act4(state: b59.ch2Done.copyWith(seals: 135), arca: a);
        await c.createGuild('등불지기', emblem: 2, color: 4);
        a.guildLevel = 6;
        a.guildStar = 3;
        a.raidLeft = 0.62;
        a.myRaidDamage = 4210;
        await c.refreshGuild();
        c.debugLook(look);
      });
      final rb = c.startRaid()!;
      await _page(tester,
          RaidBattleScreen(key: ObjectKey('r$n'), controller: c, battle: rb, tickInterval: const Duration(milliseconds: 900)));
      await _punch(tester);
      await _shot(tester, '${n}_09_길드레이드');
      late AppController c3;
      await tester.runAsync(() async {
        c3 = (await b52.start(b52.account())).$1;
        await c3.openAct3();
        c3.debugLook(look);
      });
      await _page(tester,
          Act3BattleScreen(key: ObjectKey('a$n'), controller: c3, placeId: 'baldrin_ashplain', tickInterval: const Duration(milliseconds: 900)));
      await _punch(tester);
      await _shot(tester, '${n}_10_3막지역싸움');
      late AppController ct;
      await tester.runAsync(() async {
        ct = await startVillage(13, farewell: true, village: {'seen': ['intro', 'farewell']});
        ct.debugLook(look);
      });
      await _page(tester, TrainingScreen(key: ObjectKey('t$n'), controller: ct));
      await _shot(tester, '${n}_11_훈련장');
      await _page(
          tester,
          TrainingBattleScreen(
              key: ValueKey('tb$n'),
              controller: ct,
              mode: TrainingMode.practice,
              dummy: DummyKind.normal,
              tickInterval: const Duration(milliseconds: 900)));
      await _punch(tester);
      await _shot(tester, '${n}_12_훈련장_싸움');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('b73p $n: 하이랜드 수호자', (tester) async {
      _device(tester, d);
      b50.now = b50.am.add(const Duration(minutes: 5));
      late AppController c;
      await tester.runAsync(() async {
        c = await b50.start(b50.account(18, mats: {'skyFeather': 2}));
        await c.handleFix(const LocationFix(point: b50.home));
        await c.handleFix(LocationFix(point: c.skyIsland!.point));
        c.debugLook(look);
      });
      await _page(tester, HighlandScreen(key: ObjectKey('h$n'), controller: c));
      await _tap(tester, 'skyClimb');
      await _tap(tester, 'skyForkRuins');
      await _tap(tester, 'skyNext');
      await _tap(tester, 'skyForkRuins');
      await _tap(tester, 'skyNext');
      await _tap(tester, 'skyGuardian');
      await _punch(tester);
      await _shot(tester, '${n}_13_하이랜드수호자');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 9));
    });
  }
}
