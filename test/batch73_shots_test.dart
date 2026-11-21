// 묶음 73 (build/screenshots/b73_*)
// 작은 iPhone(SE) · 큰 iPhone · Android

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
import 'package:isekai_reality/data/storage/record_store.dart' show HeroLook;
import 'package:isekai_reality/features/act3/act3_screen.dart';
import 'package:isekai_reality/features/battle/battle_view.dart';
import 'package:isekai_reality/features/profile/profile_screen.dart';
import 'package:isekai_reality/features/smithy/first_weapon_picker.dart';
import 'package:isekai_reality/features/status/status_screen.dart';
import 'package:isekai_reality/theme/ornaments.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'batch52_test.dart' as b52;
import 'batch56_test.dart' as b56;

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
  File('build/screenshots/b73_$name.png')
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




void main() {
  setUpAll(_loadFonts);
  setUp(() => b56.now = b52.t0);

  for (final d in _devices) {
    final n = d.$1;

    testWidgets('b73 $n: 상태 화면 · 프로필 · 첫 무기', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async => c = (await b52.start(b52.account())).$1);
      for (final look in HeroLook.values) {
        await _page(
            tester,
            Scaffold(
                key: ObjectKey('s$n$look'),
                body: Builder(
                    builder: (ctx) => Stack(children: [
                          NightBackground(header: true, child: StatusScreen(player: c.player, look: look)),
                          Positioned(
                              top: MediaQuery.paddingOf(ctx).top + 6,
                              left: 12,
                              child: ProfileButton(look: look, level: c.player.level.level, onTap: () {})),
                        ]))));
        await _shot(tester, '${n}_0${look.index + 1}_상태화면_${look == HeroLook.male ? '남' : '여'}');
      }
      await _page(tester, ProfileScreen(key: ObjectKey('p$n'), controller: c));
      await _shot(tester, '${n}_03_프로필');
      await _page(
          tester,
          Scaffold(
              key: ObjectKey('w$n'),
              body: NightBackground(
                  child: SafeArea(
                      child: SingleChildScrollView(
                          padding: const EdgeInsets.all(14),
                          child: FirstWeaponPicker(controller: c, onCraft: (_) {}))))));
      await tester.tap(find.byKey(const Key('firstWeapon_ironSword')));
      await _settle(tester, 6);
      await _shot(tester, '${n}_04_첫무기');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('b73 $n: 싸움 (혼자 · 동료와 대열)', (tester) async {
      _device(tester, d);
      final b = Battle(
        playerMaxHp: 100000,
        playerAttack: 30,
        floors: [const Foe(monster: MonsterId.ashSlime, maxHp: 100000, attack: 1)],
        rng: math.Random(3),
      );
      await _page(
          tester,
          Scaffold(
              key: ObjectKey('b$n'),
              body: SafeArea(
                  child: Column(children: [
                Expanded(
                    child: BattleView(
                        battle: b, fit: true, onFinished: () {}, tickInterval: const Duration(milliseconds: 600))),
              ]))));
      await tester.pump(const Duration(milliseconds: 900));
      await _shot(tester, '${n}_05_혼자_서기');
      // 공격 중간쯤 (여섯 칸 중 가운데)
      for (var i = 0; i < 20 && find.byKey(const Key('heroFrame_3')).evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 40));
      }
      await _shot(tester, '${n}_06_혼자_공격');
      late AppController c;
      await tester.runAsync(() async {
        c = (await b52.start(b52.account())).$1;
        await c.openAct3();
      });
      await _page(
          tester,
          Act3BattleScreen(
              key: ObjectKey('f$n'),
              controller: c,
              placeId: 'baldrin_ashplain',
              tickInterval: const Duration(milliseconds: 400)));
      await _shot(tester, '${n}_07_동료와_대열');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 8));
    });
  }

  testWidgets('b73: 주인공 그림 줄 (서기 · 공격 여섯 칸 · 승리 · 지침)', (tester) async {
    _device(tester, _devices[2]);
    Widget cell(String label, Widget child) => Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 92, height: 124, child: child),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
        ]);
    await _page(
        tester,
        Scaffold(
            body: NightBackground(
                child: SafeArea(
                    child: Column(children: [
          for (final look in HeroLook.values)
            Wrap(spacing: 4, runSpacing: 6, children: [
              cell('서기', Image.asset(heroBaseAsset(look))),
              cell('지친 서기', Image.asset(heroBaseAsset(look, tired: true))),
              cell('전투 서기', HeroSprite(look: look, pose: HeroPose.idle)),
              for (var i = 0; i < 6; i++)
                cell('공격 ${i + 1}', HeroSprite(look: look, pose: HeroPose.attack, t: (i + 0.5) / 6)),
              cell('승리', HeroSprite(look: look, pose: HeroPose.victory)),
              cell('지침', HeroSprite(look: look, pose: HeroPose.tired)),
              cell('얼굴', Center(child: ProfileButton(look: look, level: 12))),
            ]),
        ])))));
    await _shot(tester, '그림줄');
  });
}
