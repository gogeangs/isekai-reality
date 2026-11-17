// 묶음 49 #235: 영웅 펫 화면 미리보기 (build/screenshots/b49_*)
// 작은 iPhone(SE) · 큰 iPhone · Android

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/pet_state.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/features/pets/pet_screen.dart';
import 'package:isekai_reality/features/village/shelter_screen.dart';

import 'package:isekai_reality/theme/top_notice.dart';

import 'support/village_seed.dart';

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
  File('build/screenshots/b49_$name.png')
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

Pet _p(String uid, PetSpecies s, {bool adult = false, int bond = 0}) => Pet(
    uid: uid,
    species: s,
    name: PetRules.heroName(s),
    exp: adult ? 2300 : 0,
    bond: bond,
    bornAt: DateTime(2026, 11, 10));

PetState get _heroes => PetState(
      pets: [
        _p('p1', PetSpecies.wolf, adult: true, bond: 100),
        _p('p2', PetSpecies.turtle),
        _p('p3', PetSpecies.panther, adult: true),
        _p('p4', PetSpecies.whale, adult: true, bond: 60),
        _p('p5', PetSpecies.phoenix, adult: true, bond: 100),
        _p('p6', PetSpecies.stag, adult: true, bond: 100),
      ],
      companion: 'p1',
      firstPet: 'p1',
      firstSpiritName: '불씨',
      farewellAt: DateTime(2026, 11, 2),
      nextId: 7,
    );

void main() {
  setUpAll(_loadFonts);

  for (final d in _devices) {
    final n = d.$1;

    testWidgets('b49 $n: 펫 탭 영웅 6종 · 각성 모습 · 루미 한마디', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async => c = await startVillage(16,
          farewell: true,
          village: {'seen': ['intro', 'farewell', 'shelterCard', 'met:lumi']},
          more: {'pets': _heroes.toJson()}));
      await _page(tester, PetScreen(key: ObjectKey(c), controller: c));
      await _shot(tester, '${n}_01_펫탭');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
      await _settle(tester);
      await _shot(tester, '${n}_02_펫탭_아래');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -1400));
      await _settle(tester);
      await _shot(tester, '${n}_03_펫탭_맨아래');
      await _page(tester, ShelterScreen(key: ObjectKey('s$n'), controller: c));
      await _shot(tester, '${n}_04_루미_한마디');
      await tester.pump(const Duration(seconds: 9));
    });
  }
}
