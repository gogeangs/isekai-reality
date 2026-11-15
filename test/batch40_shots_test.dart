// 묶음 40: 작은 iPhone(SE) · 큰 iPhone · Android 화면 미리보기 (build/screenshots/b40_*)
// 글자 크기 기본·한 단계 크게(×1.12) 두 가지로 대장간 탭 6개와 Lv.3 첫 무기 안내를 찍는다.

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/smithy/smithy_screen.dart';
import 'package:isekai_reality/features/tutorial/targets.dart';

import 'support/smithy_seed.dart';

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
  File('build/screenshots/b40_$name.png')
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

Future<void> _smithy(WidgetTester tester, AppController c) async {
  await tester.pumpWidget(RepaintBoundary(
    key: _root,
    child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: SmithyScreen(controller: c)),
  ));
  await _settle(tester);
}

Future<void> _tab(WidgetTester tester, int i) async {
  await tester.tap(find.byKey(Key('smithyTab_$i')));
  await _settle(tester, 3);
}

Future<void> _down(WidgetTester tester, double dy) async {
  await tester.drag(find.byKey(const Key('smithyList')), Offset(0, -dy));
  await _settle(tester, 4);
}

void main() {
  setUpAll(_loadFonts);

  for (final d in _devices) {
    for (final (tn, ts) in const [('기본', 1.0), ('크게', 1.12)]) {
      final n = '${d.$1}_글자$tn';

      testWidgets('b40 $n: 대장간 탭 6개', (tester) async {
        _device(tester, d, text: ts);
        late AppController c;
        await tester.runAsync(() async => c = await startSmithy());
        await _smithy(tester, c);
        await _shot(tester, '${n}_01_만들기_첫화면');
        await _down(tester, 500);
        await _shot(tester, '${n}_02_만들기_내린뒤');
        await tester.drag(
            find.byKey(const Key('smithyList')), const Offset(0, 3000));
        await _settle(tester, 4);
        await tester.tap(find.byKey(const Key('slotChip_body')));
        await _settle(tester, 3);
        await _shot(tester, '${n}_03_만들기_몸_모자람');
        await tester.tap(find.byKey(const Key('slotChip_all')));
        await _settle(tester, 3);
        await tester.drag(
            find.byKey(const Key('smithyList')), const Offset(0, 3000));
        await _settle(tester, 4);
        await tester.tap(find.byKey(const Key('craft_cap')));
        await _settle(tester);
        await tester.tap(find.byKey(const Key('rare_glossyFur')));
        await _settle(tester, 3);
        await _shot(tester, '${n}_04_만들기_확인창_귀한재료');
        await tester.tap(find.byKey(const Key('craftCancel')));
        await _settle(tester);

        await _tab(tester, 1);
        await _shot(tester, '${n}_05_강화');
        await _down(tester, 700);
        await _shot(tester, '${n}_06_강화_가방');

        await _tab(tester, 2);
        await tester.drag(
            find.byKey(const Key('smithyList')), const Offset(0, 3000));
        await _settle(tester, 4);
        await _shot(tester, '${n}_07_수리');
        await tester.tap(find.byKey(const Key('more_w')));
        await _settle(tester);
        await _shot(tester, '${n}_08_수리_분해메뉴_입는중');
        await tester.tapAt(const Offset(4, 300));
        await _settle(tester);
        await _down(tester, 3000);
        await _shot(tester, '${n}_09_수리_아래_채집도구');

        await _tab(tester, 3);
        await tester.drag(
            find.byKey(const Key('smithyList')), const Offset(0, 3000));
        await _settle(tester, 4);
        await _shot(tester, '${n}_10_속성');
        await tester.tap(find.byKey(const Key('smith_change_w')));
        await _settle(tester, 3);
        await tester.scrollUntilVisible(find.byKey(const Key('pick_apply_g_fire')), 150,
          scrollable: find.descendant(
              of: find.byKey(const Key('smithyList')),
              matching: find.byType(Scrollable)));
        await tester.tap(find.byKey(const Key('pick_apply_g_fire')));
        await _settle(tester, 3);
        await _shot(tester, '${n}_11_속성_바꾸기_모자란코어');

        await _tab(tester, 4);
        await _shot(tester, '${n}_12_재료가공');
        await _tab(tester, 5);
        await _shot(tester, '${n}_13_보스장비');
        expect(tester.takeException(), isNull);

        // 귀한 재료가 없을 때 짧은 확인 창
        await tester.runAsync(() async =>
            c = await startSmithy(mats: const {'ratHide': 4}));
        await _smithy(tester, c);
        await tester.tap(find.byKey(const Key('craft_cap')));
        await _settle(tester);
        await _shot(tester, '${n}_14_만들기_확인창_짧게');
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 9));
      });

      testWidgets('b40 $n: Lv.3 첫 무기 안내', (tester) async {
        _device(tester, d, text: ts);
        final t0 = DateTime(2026, 11, 13, 10);
        late AppController c;
        await tester.runAsync(() async {
          c = AppController(
            store: InMemoryRecordStore(
              profile: const PlayerProfile(name: '하루', lastSeenLevel: 99),
              history: [
                for (var i = 2; i >= 1; i--)
                  DailyRecord(
                    date: DateTime(2026, 11, 13 - i),
                    dungeonRuns:
                        List.filled(4, const DungeonRun(cleared: true)),
                  ),
              ],
              json: {
                'tutorial': {'step': TutorialStep.done.index},
                'gates': {'legacy': false, 'seen': <String>[]},
              },
            ),
            health: FakeHealthSource(stepsByDay: const {}),
            clock: () => t0,
          )..mailSources = const [];
          await c.init();
        });
        expect(c.pendingFeatureIntro, Feature.smithy);
        await tester.pumpWidget(
            RepaintBoundary(key: _root, child: IsekaiRealityApp(controller: c)));
        await _settle(tester, 8);
        await tester.tap(find.byKey(const Key('tourButton')));
        await _settle(tester, 8);
        await tester.tapAt(rectOf(tutorialNavKeys[3])!.center);
        await _settle(tester, 8);
        Scrollable.ensureVisible(
            tester.element(find.byKey(const Key('facility_smithy'))),
            alignment: 0.5);
        await _settle(tester, 8);
        await tester.tap(find.byKey(const Key('facility_smithy')));
        await _settle(tester, 16);
        await _shot(tester, '${n}_15_첫무기안내_고르기');
        Scrollable.ensureVisible(
            tester.element(find.byKey(const Key('firstWeapon_ironSpear'))),
            alignment: 0.5);
        await _settle(tester, 16);
        await tester.tap(find.byKey(const Key('firstWeapon_ironSpear')));
        await _settle(tester, 16);
        await _shot(tester, '${n}_16_첫무기안내_만들기');
        // 「만들기 (무료)」가 붙어 있는 위쪽 아래, 화면 안에 다 보인다
        final craft = tester.getRect(find.byKey(const Key('firstWeaponCraft')));
        final tabs = tester.getRect(find.byKey(const Key('smithyTab_5')));
        final screen = d.$2 / d.$3;
        expect(craft.top, greaterThanOrEqualTo(tabs.bottom));
        expect(craft.bottom, lessThanOrEqualTo(screen.height - d.$5 / d.$3));
        await tester.tap(find.byKey(const Key('firstWeaponCraft')),
            warnIfMissed: false);
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)));
        await _settle(tester, 8);
        expect(find.byKey(const Key('equipNow')), findsOneWidget);
        await tester.pump(const Duration(seconds: 9));
      });
    }
  }
}
