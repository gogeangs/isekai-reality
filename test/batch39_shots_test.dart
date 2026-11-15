// 묶음 38·39: 작은 iPhone(SE) · 큰 iPhone · Android 화면 미리보기 (build/screenshots/b39_*)
// 글자 크기 기본·한 단계 크게(×1.12) 두 가지로 마을 · 시설 · 의뢰 게시판 쪽지를 찍는다.

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/features/village/board_parchment.dart';
import 'package:isekai_reality/features/village/board_screen.dart';
import 'package:isekai_reality/features/smithy/smithy_screen.dart';
import 'package:isekai_reality/features/town/inn_screen.dart';

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
  File('build/screenshots/b39_$name.png')
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

/// 긴 이름·여러 줄 쪽지를 일부러 모은 게시판 (오늘의 3 + 보너스 / 주간 3 / 길드 2)
Widget _sampleBoard() => ListView(
      padding: const EdgeInsets.fromLTRB(14, 60, 14, 28),
      children: [
        WoodBoard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const BoardPlaque('오늘의 의뢰', note: '완료 0/3'),
              const SizedBox(height: 4),
              NoteGrid(children: [
                for (final (i, t) in [
                  '필드 몬스터 15마리 잡기',
                  '5,000보 걷기',
                  '채집 3번',
                ].indexed)
                  SmallNote(
                      title: t, seed: i, ratio: 0.3, progress: '3 / 15마리'),
              ]),
              const SizedBox(height: 14),
              const BoardPlaque('주간 의뢰', note: '완료 0/3 · 4일 남음'),
              const SizedBox(height: 4),
              NoteGrid(children: [
                for (final (i, t) in [
                  '이번 주 2만 보 걷기',
                  '던전 5번 클리어',
                  '필드 몬스터 15마리 사냥',
                ].indexed)
                  SmallNote(
                      title: t,
                      seed: i + 3,
                      ratio: 0.5,
                      progress: '10,000 / 20,000보'),
              ]),
              const SizedBox(height: 14),
              const BoardPlaque('길드 의뢰', note: '오늘 0 / 3'),
              const SizedBox(height: 4),
              const NoteGrid(children: [
                SmallNote(title: '슬라임 젤리 5개 모으기', seed: 7, progress: '수락 전'),
                SmallNote(
                    title: '잿빛 슬라임 3마리',
                    seed: 8,
                    ratio: 0.33,
                    progress: '1 / 3마리',
                    sealed: true),
                SmallNote(
                    title: '수식어 붙은 몬스터 2마리 사냥',
                    seed: 9,
                    ratio: 0.5,
                    progress: '1 / 2마리'),
                ParchmentNote(
                  seed: 10,
                  small: true,
                  faded: true,
                  child: Text('새 의뢰가 1시간 12분 뒤에 붙어요',
                      style: TextStyle(color: kInkSoft, fontSize: 12, height: 1.3)),
                ),
              ]),
            ],
          ),
        ),
      ],
    );

void main() {
  setUpAll(_loadFonts);

  for (final d in _devices) {
    testWidgets('b39 ${d.$1}: 마을 · 시설 · 게시판', (tester) async {
      _device(tester, d);
      final c = AppController.demo(clock: () => DateTime(2026, 11, 16, 14));
      await tester.pumpWidget(
          RepaintBoundary(key: _root, child: IsekaiRealityApp(controller: c)));
      await c.init();
      await tester.pumpAndSettle();

      await tester.tap(find.text('마을'));
      await tester.pumpAndSettle();
      await _shot(tester, '${d.$1}_마을');
      // 왼쪽 끝까지 끌어 보기
      await tester.drag(
          find.byKey(const Key('villageScroll')), const Offset(600, 0));
      await tester.pumpAndSettle();
      await _shot(tester, '${d.$1}_마을_왼쪽');
      await tester.drag(
          find.byKey(const Key('villageScroll')), const Offset(-300, 0));
      await tester.pumpAndSettle();

      // 시설: 여관 · 대장간 · 게시판 (마을 사람 말풍선, 정령 띠 없음)
      await tester.ensureVisible(find.byKey(const Key('facility_inn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('facility_inn')));
      await tester.pumpAndSettle();
      await _shot(tester, '${d.$1}_여관');
      Navigator.of(tester.element(find.byType(InnScreen))).pop();
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('facility_smithy')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('facility_smithy')));
      await tester.pumpAndSettle();
      await _shot(tester, '${d.$1}_대장간');
      Navigator.of(tester.element(find.byType(SmithyScreen))).pop();
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('facility_board')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('facility_board')));
      await tester.pumpAndSettle();
      await _shot(tester, '${d.$1}_게시판_위');
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -500));
      await tester.pumpAndSettle();
      await _shot(tester, '${d.$1}_게시판_아래');
      Navigator.of(tester.element(find.byType(BoardScreen))).pop();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 9));
    });

    for (final (tn, ts) in const [('기본', 1.0), ('크게', 1.12)])
    testWidgets('b39 ${d.$1} 글자$tn: 긴 이름 쪽지 모음 · 게시판', (tester) async {
      _device(tester, d, text: ts);
      await tester.pumpWidget(RepaintBoundary(
        key: _root,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
              backgroundColor: const Color(0xFF14163A), body: _sampleBoard()),
        ),
      ));
      await tester.pumpAndSettle();
      await _shot(tester, '${d.$1}_글자${tn}_쪽지_위');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await tester.pumpAndSettle();
      await _shot(tester, '${d.$1}_글자${tn}_쪽지_아래');
      expect(tester.takeException(), isNull);

      // 실제 게시판 (예시 계정)
      final c = AppController.demo(clock: () => DateTime(2026, 11, 16, 14));
      await tester.runAsync(c.init);
      await tester.pumpWidget(RepaintBoundary(
        key: _root,
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: BoardScreen(controller: c)),
      ));
      await tester.pumpAndSettle();
      await _shot(tester, '${d.$1}_글자${tn}_게시판_위');
      await tester.drag(find.byKey(const Key('boardScroll')), const Offset(0, -600));
      await tester.pumpAndSettle();
      await _shot(tester, '${d.$1}_글자${tn}_게시판_아래');
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 9));
    });
  }
}
