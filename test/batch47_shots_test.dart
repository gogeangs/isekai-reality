// 묶음 47 #239·#240: 게시판 포기 버튼 · 가방 가득 창 미리보기 (build/screenshots/b47_*)
// 작은 iPhone(SE) · 큰 iPhone · Android

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/rules/rules.dart';

import 'package:isekai_reality/core/models/board_state.dart';
import 'package:isekai_reality/core/models/bag_state.dart';
import 'package:isekai_reality/core/models/mail_state.dart';
import 'package:isekai_reality/features/mail/mail_screen.dart';
import 'package:isekai_reality/features/town/bag_hold_sheet.dart';
import 'package:isekai_reality/features/town/bag_tab.dart';
import 'package:isekai_reality/features/village/board_screen.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'support/npc_seed.dart';
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
  File('build/screenshots/b47_$name.png')
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

Map<String, int> get _full99 => {for (final m in MaterialId.values) m.name: 99};

void main() {
  setUpAll(_loadFonts);

  for (final d in _devices) {
    final n = d.$1;

    testWidgets('b47 $n: 가방이 가득 찼어요 창 · 가방 탭 띠', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async => c = await startNpc(level: 8, mats: _full99, json: {
            'bag': const BagState(hold: {
              'herb': 3,
              'item:healSmall': 2,
              'ironShard': 12,
              'springPetal': 1,
            }).toJson(),
          }));
      await _page(tester, Scaffold(body: BagTab(key: ValueKey('bag$n'), controller: c)));
      await _shot(tester, '${n}_01_가방_받지못한것_띠');
      await tester.tap(find.byKey(const Key('bagHoldView')));
      await _settle(tester);
      await _shot(tester, '${n}_02_가방이_가득_찼어요_창');
      await tester.tap(find.byKey(const Key('bagHoldSell_herb')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await _settle(tester);
      await _shot(tester, '${n}_03_하나_판매한_뒤');
      await tester.tap(find.byKey(const Key('bagHoldDropAll')));
      await _settle(tester);
      await _shot(tester, '${n}_04_모두_버리기_확인');
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('b47 $n: 홈에서 뜨는 창 (가방 열기)', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async {
        c = await startNpc(level: 8, mats: _full99);
        await c.admitBagForTest(const {'herb': 2, 'item:spareKey': 1, 'slimeJelly': 5});
      });
      await _page(tester, Builder(
          builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    key: const Key('open'),
                    onPressed: () => showBagHoldSheet(context, c, onOpenBag: () {}),
                    child: const Text('열기'),
                  ),
                ),
              )));
      await tester.tap(find.byKey(const Key('open')));
      await _settle(tester);
      await _shot(tester, '${n}_05_새로_얻은_것_창');
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('b47 $n: 게시판 상세 — 인장은 이름 옆 · 포기 버튼 · 확인 창', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async => c = await startNpc(
            level: 15,
            json: {
              'board': const BoardState(day: '2026-11-16', seq: 2, slots: [
                ErrandSlot(templateId: 'npc_hart_0', accepted: true, baseline: 0),
                ErrandSlot(templateId: 'npc_mina_1'),
              ]).toJson(),
            },
          ));
      await _page(tester, BoardScreen(key: ValueKey('board$n'), controller: c));
      // 묶음 70 #300: 조합 탭
      await tester.tap(find.byKey(const Key('boardTab_errand')));
      await _settle(tester, 3);
      await _settle(tester, 3);
      await _shot(tester, '${n}_06_게시판_조합의뢰');
      await tester.tap(find.byKey(const Key('errandNote_0')));
      await _settle(tester, 10);
      await _shot(tester, '${n}_07_상세_포기버튼');
      await tester.tap(find.byKey(const Key('errandAbandon_0')));
      await _settle(tester);
      await _shot(tester, '${n}_08_포기_확인창');
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('b47 $n: 우편 — 가방이 가득해 남겨 둔 것', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async {
        c = await startNpc(level: 12, mats: _full99, json: {
          'mail': MailState(mails: [
            MailItem(
              id: 'm1',
              kind: MailKind.letter,
              from: '세라',
              title: '길드에서',
              body: '네가 길드에 자주 오는 걸 봤다.',
              gifts: const {'gold': 50, 'item:jobManaSmall': 2},
              sentAt: t0,
            ),
          ], sent: const ['m1']).toJson(),
        });
        await c.admitBagForTest(const {'herb': 2, 'egg': 1}, toMail: true);
        await c.claimMail('m1');
      });
      await _page(tester, MailScreen(key: ValueKey('mail$n'), controller: c));
      await _shot(tester, '${n}_09_우편함');
      await tester.tap(find.byKey(const Key('mailRow_m1')));
      await _settle(tester);
      await _shot(tester, '${n}_10_남겨둔_우편');
      await tester.pump(const Duration(seconds: 9));
    });
  }
}
