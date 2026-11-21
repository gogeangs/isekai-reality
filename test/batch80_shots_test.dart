// 묶음 80 (build/screenshots/b80_*) — 큰 iPhone · SE

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/pet_state.dart';
import 'package:isekai_reality/core/models/vitals.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/features/jobs/guild_screen.dart';
import 'package:isekai_reality/features/lens/demo_filter_engine.dart';
import 'package:isekai_reality/features/lens/lens_output.dart';
import 'package:isekai_reality/features/lens/lens_screen.dart';
import 'package:isekai_reality/features/lens/race_stickers.dart';
import 'package:isekai_reality/features/town/bag_tab.dart';
import 'package:isekai_reality/features/town/inn_screen.dart';
import 'package:isekai_reality/features/town/sell_sheet.dart';
import 'package:isekai_reality/features/town/shop_screen.dart';
import 'package:isekai_reality/features/village/village_screen.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'batch51_test.dart' as b51;
import 'batch52_test.dart' as b52;
import 'batch56_test.dart' as b56;
import 'support/village_seed.dart';

final _root = GlobalKey();

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

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      final image = element.widget as Image;
      await precacheImage(image.image, element, onError: (_, __) {});
    }
  });
  await tester.pump();
  for (var i = 0; i < 2; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
    await tester.pump();
  }
  final boundary = tester.renderObject(find.byKey(_root)) as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.5);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  File('build/screenshots/b80_$name.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!);
}

const _devices = [
  ('SE', Size(750, 1334), 2.0, 40.0, 0.0),
  ('큰iPhone', Size(1290, 2796), 3.0, 177.0, 102.0),
];

void _device(WidgetTester tester, (String, Size, double, double, double) d) {
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
        theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Roboto'),
        builder: (context, child) => TopNoticeHost(child: child!),
        home: home),
  ));
  await _settle(tester);
}

Map<String, dynamic> _pets({bool farewell = true, List<PetEgg> eggs = const []}) => {
      'pets': PetState(
        pets: [Pet(uid: 'p1', species: PetSpecies.owl, name: '부엉', bornAt: DateTime(2026, 11, 1))],
        companion: 'p1',
        firstPet: 'p1',
        firstSpiritName: '불씨',
        farewellAt: farewell ? DateTime(2026, 11, 2) : null,
        eggs: eggs,
      ).toJson(),
    };

Map<String, dynamic> _jobs(String main, {List<String> subs = const []}) =>
    {'awakened': true, 'v57': true, 'v31': true, 'main': main, 'owned': [main, ...subs], 'subs': subs};

/// 버튼 하나 있는 빈 화면 (눌러서 창을 연다)
Widget _opener(void Function(BuildContext) open) => Scaffold(
    body: Builder(
        builder: (ctx) => Center(
            child: TextButton(key: const Key('open'), onPressed: () => open(ctx), child: const Text('열기')))));

void main() {
  setUpAll(_loadFonts);
  setUp(() => b56.now = b52.t0);

  for (final d in [_devices[1], _devices[0]]) {
    final n = d.$1;

    testWidgets('b80 $n: 1 돋보기', (tester) async {
      _device(tester, d);
      LensScreen.engineFactory = DemoFilterEngine.new;
      LensOutput.saver = (_) async => null;
      late AppController c;
      await tester.runAsync(() async {
        c = await startVillage(8, gains: {'gold': 3000});
        await c.buy(ShopItem.raceLens);
        await StickerArt.load();
      });
      await _page(tester, LensScreen(key: ObjectKey('lens$n'), controller: c));
      await _settle(tester, 4);
      await tester.tap(find.byKey(const Key('pickRace')));
      await _settle(tester, 4);
      await _shot(tester, '${n}_01_돋보기_종족칸_엘프도준비중');
      await tester.tap(find.byKey(const Key('race_elf')));
      await _settle(tester, 3);
      await _shot(tester, '${n}_02_돋보기_엘프누름_곧만나요');
      await tester.tapAt(const Offset(10, 10));
      await _settle(tester, 4);
      await tester.tap(find.byKey(const Key('appraise')));
      await tester.pump(const Duration(milliseconds: 1100));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      await tester.tap(find.byKey(const Key('lensToFilter')));
      await _settle(tester, 4);
      await _shot(tester, '${n}_03_돋보기_스티커장식');
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('lensShutter')));
        await Future<void>.delayed(const Duration(seconds: 2));
      });
      await _settle(tester, 2);
      await _shot(tester, '${n}_04_돋보기_사진');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('b80 $n: 2 알 팔기', (tester) async {
      _device(tester, d);
      final warm = PetEgg(id: 'e3', source: 'field', grade: EggGrade.rare, incubatedAt: DateTime(2026, 11, 16, 9));
      const free = PetEgg(id: 'e1', source: 'field', grade: EggGrade.hero);
      late AppController c;
      late AppController young;
      await tester.runAsync(() async {
        c = await startVillage(14, farewell: true, more: _pets(eggs: [
          free,
          const PetEgg(id: 'e2', source: 'field'),
          const PetEgg(id: 'e4', source: 'field', grade: EggGrade.legend),
          warm,
        ]));
        young = await startVillage(8, more: _pets(farewell: false, eggs: [const PetEgg(id: 'e9', source: 'field')]));
      });
      await _page(tester, ShopScreen(key: ObjectKey('shop$n'), controller: c, sellGroup: SellGroup.egg));
      await _shot(tester, '${n}_10_잡화상_팔기_알묶음');
      await tester.tap(find.byKey(const Key('sellRow_g:e1')));
      await _settle(tester, 2);
      await _shot(tester, '${n}_11_잡화상_알_하나고름');
      for (final (k, ctrl, egg, name) in [
        (1, c, free, '12_가방알창_팔수있음'),
        (2, c, warm, '13_가방알창_품는중'),
        (3, young, const PetEgg(id: 'e9', source: 'field'), '14_가방알창_신비한알'),
      ]) {
        await _page(tester, KeyedSubtree(key: ValueKey('o$k$n'), child: _opener((ctx) => showBagEntry(ctx, ctrl, EggEntry(egg)))));
        await tester.tap(find.byKey(const Key('open')));
        await _settle(tester, 4);
        await _shot(tester, '${n}_$name');
      }
      await tester.tap(find.byKey(const Key('open')), warnIfMissed: false);
      await _page(tester, KeyedSubtree(key: ValueKey('o4$n'), child: _opener((ctx) => showBagEntry(ctx, c, const EggEntry(free)))));
      await tester.tap(find.byKey(const Key('open')));
      await _settle(tester, 4);
      await tester.tap(find.byKey(const Key('eggSellGo')));
      await _settle(tester, 6);
      await _shot(tester, '${n}_15_가방알창_잡화상에서팔기_누름');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('b80 $n: 3 조합', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async => c = await startVillage(17, farewell: true, more: {'jobs': _jobs('warrior')}));
      await _page(tester, GuildScreen(key: ObjectKey('g1$n'), controller: c));
      await _shot(tester, '${n}_20_조합_Lv17_띠없음');
      await tester.runAsync(() async => c = await startVillage(22, farewell: true, more: {'jobs': _jobs('knight', subs: ['priest'])}));
      await _page(tester, GuildScreen(key: ObjectKey('g2$n'), controller: c));
      await _shot(tester, '${n}_21_조합_Lv20뒤_띠없음');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('b80 $n: 4 여관', (tester) async {
      _device(tester, d);
      var now = DateTime(2026, 11, 16, 10);
      late AppController c;
      late AppController young;
      await tester.runAsync(() async {
        c = await startVillage(18, farewell: true, clock: () => now, more: {
          'jobs': {..._jobs('mage'), 'mp': 4},
        }, vitals: Vitals(hp: 30, mp: 5, mpAt: now));
        young = await startVillage(8, clock: () => now, vitals: Vitals(hp: 20, mp: 3, mpAt: now));
      });
      await _page(tester, InnScreen(key: ObjectKey('inn1$n'), controller: c));
      await _shot(tester, '${n}_30_여관_체크인전');
      await tester.tap(find.byKey(const Key('innCheckIn')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await _settle(tester, 4);
      now = now.add(const Duration(hours: 1, minutes: 40));
      await tester.runAsync(c.refreshVitals);
      await _settle(tester, 5);
      await _shot(tester, '${n}_31_여관_쉬는중_막대차는중');
      await _page(tester, InnScreen(key: ObjectKey('inn2$n'), controller: young));
      await _shot(tester, '${n}_32_여관_각성전_MP줄없음');
      now = now.add(const Duration(hours: 3));
      await tester.runAsync(c.refreshVitals);
      await _page(tester, InnScreen(key: ObjectKey('inn3$n'), controller: c));
      // 다 쉰 알림 (첫 화면이 띄우는 글과 같음)
      showTopNotice(tester.element(find.byType(InnScreen)),
          c.jobsOpen ? '푹 쉬었어요 · HP · MP · 기력이 가득 찼어요' : '푹 쉬었어요 · HP · 기력이 가득 찼어요');
      await _settle(tester, 3);
      await _shot(tester, '${n}_33_여관_다쉼_알림');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('b80 $n: 5 마을 잠긴 주점 · 거래소', (tester) async {
      _device(tester, d);
      for (final (k, king) in [(1, false), (2, true)]) {
        late AppController c;
        await tester.runAsync(() async => c = await b51.start(b51.account(king: king)));
        await tester.pumpWidget(RepaintBoundary(
          key: _root,
          child: MaterialApp(
              key: ValueKey('v$k$n'),
              debugShowCheckedModeBanner: false,
              theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Roboto'),
              builder: (context, child) => TopNoticeHost(child: child!),
              home: Scaffold(body: VillageScreen(controller: c))),
        ));
        await tester.pump(const Duration(milliseconds: 300));
        final tag = king ? '본체뒤_만남전' : '본체전';
        for (final (i, key) in [(0, 'locked_tavern'), (1, 'tag_market')]) {
          final f = find.byKey(Key(key));
          if (f.evaluate().isEmpty) continue;
          await tester.tap(f, warnIfMissed: false);
          await tester.pump(const Duration(milliseconds: 300));
          await _shot(tester, '${n}_4$k${i}_마을_${key == 'tag_market' ? '거래소' : '주점'}_$tag');
          await tester.pump(const Duration(seconds: 4));
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 9));
      }
    });
  }
}
