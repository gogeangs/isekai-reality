// 묶음 80 #370 그림 줄이기 전 · 후 비교 (build/screenshots/b80img_<IMG_TAG>_*.png) — 큰 iPhone, 기기 해상도(3배) 그대로

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/storage/record_store.dart' show HeroLook, SpiritKind;
import 'package:isekai_reality/features/battle/battle_view.dart';
import 'package:isekai_reality/features/bulssi/bulssi_mood.dart';
import 'package:isekai_reality/features/village/village_screen.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'batch52_test.dart' as b52;
import 'batch56_test.dart' as b56;
import 'support/village_seed.dart';

final _root = GlobalKey();
final _tag = Platform.environment['IMG_TAG'] ?? 'now';

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

Future<void> _precache(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      final image = element.widget as Image;
      await precacheImage(image.image, element, onError: (_, __) {});
    }
  });
  await tester.pump();
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
  await tester.pump();
}

Future<void> _shot(WidgetTester tester, String name, {bool cache = true}) async {
  if (cache) await _precache(tester);
  final boundary = tester.renderObject(find.byKey(_root)) as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  File('build/screenshots/b80img_${_tag}_$name.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!);
}

void _device(WidgetTester tester) {
  tester.view.physicalSize = const Size(1290, 2796);
  tester.view.devicePixelRatio = 3;
  tester.view.padding = const FakeViewPadding(top: 177, bottom: 102);
  tester.view.viewPadding = const FakeViewPadding(top: 177, bottom: 102);
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester, [int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _page(WidgetTester tester, Widget home, {int settle = 6}) async {
  await tester.pumpWidget(RepaintBoundary(
    key: _root,
    child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Roboto'),
        builder: (context, child) => TopNoticeHost(child: child!),
        home: home),
  ));
  await _settle(tester, settle);
}

Widget _battle(Battle b, {String? background, String? job}) => BulssiScope(
      key: UniqueKey(),
      mood: BulssiMood.gold,
      spiritName: '불씨',
      kind: SpiritKind.fire,
      child: Scaffold(
          body: SafeArea(
              child: Column(children: [
        Expanded(
            child: BattleView(
                battle: b,
                fit: true,
                look: HeroLook.male,
                heroJob: job,
                background: background,
                onFinished: () {},
                tickInterval: const Duration(milliseconds: 900))),
      ]))),
    );

Battle _b(MonsterId m) => Battle(
      playerMaxHp: 100000,
      playerAttack: 30,
      floors: [Foe(monster: m, maxHp: 1000000, attack: 1)],
      rng: math.Random(3),
    );

void main() {
  setUpAll(_loadFonts);
  setUp(() => b56.now = b52.t0);

  // 배경 3 · 주인공 대기 · 몬스터 2 (같은 전투 화면, 시작 순간)
  for (final (name, bg, m, job) in [
    ('01_배경_던전_슬라임_대기', null, MonsterId.ashSlime, null),
    ('02_배경_숲_몬스터2_전사대기', 'assets/images/bg_field_forest.webp', MonsterId.ashElder, 'warrior'),
    ('03_배경_불꽃보스', 'assets/images/bg_boss_flame.webp', MonsterId.ashSlime, 'mage'),
  ]) {
    testWidgets('b80img $name', (tester) async {
      _device(tester);
      // 첫 공격 전 (대기 모습 · 몬스터 맞기 전)
      await _page(tester, _battle(_b(m), background: bg, job: job), settle: 1);
      await _shot(tester, name);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    });
  }

  testWidgets('b80img 04 주인공 공격', (tester) async {
    _device(tester);
    await _page(tester, _battle(_b(MonsterId.ashSlime), job: 'warrior'));
    await _precache(tester);
    final attack = find.byWidgetPredicate(
        (w) => w is HeroSprite && w.pose == HeroPose.attack && HeroSprite.frameAt(w.t) >= 2);
    for (var i = 0; i < 200 && attack.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    await _shot(tester, '04_주인공_공격', cache: false);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('b80img 05 마을', (tester) async {
    _device(tester);
    late AppController c;
    await tester.runAsync(() async => c = await startVillage(12, farewell: true, village: {'seen': ['intro', 'farewell', 'v44']}));
    await _page(tester, Scaffold(body: VillageScreen(controller: c)));
    await _shot(tester, '05_마을');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  });
}
