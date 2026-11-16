// 묶음 43 #228: 훈련장 화면 미리보기 (build/screenshots/b43_*)
// 작은 iPhone(SE) · 큰 iPhone · Android

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/features/village/training_screen.dart';

import 'package:isekai_reality/features/village/village_screen.dart';
import 'package:isekai_reality/features/records/records_screen.dart';
import 'package:isekai_reality/theme/ornaments.dart';
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
  File('build/screenshots/b43_$name.png')
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

/// 마을 그림을 오른쪽 끝(훈련장 쪽)까지 끈다
Future<void> _toRight(WidgetTester tester) async {
  await tester.drag(find.byKey(const Key('villageScroll')), const Offset(-1200, 0));
  await _settle(tester, 3);
}

/// 전투가 끝나 결과가 나올 때까지 (빠른 틱)
Future<void> _runBattle(WidgetTester tester) async {
  for (var i = 0; i < 4000; i++) {
    if (find.byKey(const Key('trainingBack')).evaluate().isNotEmpty) break;
    await tester.pump(const Duration(milliseconds: 150));
    if (i % 40 == 0) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    }
  }
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
  await _settle(tester);
}

void main() {
  setUpAll(_loadFonts);

  for (final d in _devices) {
    final n = d.$1;

    testWidgets('b43 $n: 마을 공사 Lv.10·11·12 · 완공 연출 · 은은한 점', (tester) async {
      _device(tester, d);
      for (final lv in [10, 11, 12]) {
        late AppController c;
        await tester.runAsync(() async => c = await startVillage(lv,
            village: {'seen': ['intro', 'farewell', 'shelterCard']},
            farewell: lv >= 11));
        await _page(tester, Scaffold(body: VillageScreen(key: ObjectKey(c), controller: c)));
        await _toRight(tester);
        await _shot(tester, '${n}_01_Lv${lv}_공사');
      }
      late AppController c;
      await tester.runAsync(() async => c = await startVillage(13,
          farewell: true,
          village: {
            'seen': ['intro', 'farewell', 'shelterCard', 'v43', 'v44',
              'built:smithy', 'built:board', 'built:alchemy', 'built:shelter'],
          }));
      await tester.pumpWidget(RepaintBoundary(
        key: _root,
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            builder: (context, child) => TopNoticeHost(child: child!),
            home: Scaffold(body: VillageScreen(key: ObjectKey(c), controller: c))),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await _shot(tester, '${n}_02_Lv13_완공연출');
      await tester.pump(const Duration(seconds: 3));
      await _settle(tester);
      await _shot(tester, '${n}_03_Lv13_완공뒤_은은한점');
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('b43 $n: 가렌 첫 만남 · 탭 4개 · 연습 3종', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async => c = await startVillage(13,
          farewell: true, village: {'seen': ['intro', 'farewell']}));
      await _page(tester, TrainingScreen(key: ObjectKey(c), controller: c));
      await _shot(tester, '${n}_04_가렌_첫만남_연습탭');
      await tester.tap(find.byKey(const Key('dummyElement_water')));
      await _settle(tester, 2);
      final list = find.byType(Scrollable).last;
      await tester.drag(list, const Offset(0, -400));
      await _settle(tester, 3);
      await _shot(tester, '${n}_05_연습탭_속성고르기');
      for (final (i, name) in [(1, '하루훈련'), (2, '펫훈련'), (3, '시련')]) {
        await tester.tap(find.byKey(Key('trainingTab_$i')));
        await _settle(tester, 3);
        await _shot(tester, '${n}_0${5 + i}_${name}탭');
      }
      for (final (k, el) in [
        (DummyKind.normal, null),
        (DummyKind.hard, null),
        (DummyKind.element, Element.water),
      ]) {
        await _page(
            tester,
            TrainingBattleScreen(
                key: ValueKey('p${k.name}$n'),
                controller: c,
                mode: TrainingMode.practice,
                dummy: k,
                element: el,
                tickInterval: const Duration(milliseconds: 100)));
        for (var i = 0; i < 25; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await _shot(tester, '${n}_09_연습_${k.name}');
        if (k == DummyKind.element) {
          await tester.tap(find.byKey(const Key('practiceStop')));
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
          await _settle(tester);
          await _shot(tester, '${n}_10_연습_그만하기_결과');
        }
      }
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('b43 $n: 하루 훈련 3판 · 펫 훈련 · 시련 기록·보상·칭호', (tester) async {
      _device(tester, d);
      var now = vt0;
      late AppController c;
      await tester.runAsync(() async => c = await startVillage(16,
          farewell: true,
          village: {'seen': ['intro', 'farewell']},
          clock: () => now));
      final daily = (await tester.runAsync(c.startDailyTraining))!;
      await _page(
          tester,
          TrainingBattleScreen(
              controller: c,
              mode: TrainingMode.daily,
              battle: daily,
              tickInterval: const Duration(milliseconds: 60)));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      await _shot(tester, '${n}_11_하루훈련_전투');
      await _runBattle(tester);
      await _shot(tester, '${n}_12_하루훈련_결과');

      // 펫 훈련: 맡기기 → 훈련 중 → 끝
      await _page(tester, TrainingScreen(key: ValueKey('t2$n'), controller: c, tab: 2));
      await _shot(tester, '${n}_13_펫훈련_고르기');
      await tester.tap(find.byKey(const Key('trainPetGo_p1')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await _settle(tester);
      await _shot(tester, '${n}_14_펫훈련_맡김');
      now = vt0.add(const Duration(hours: 8, minutes: 1));
      await tester.runAsync(c.refreshVitals);
      final name = c.takePetTrainedNotice();
      await _page(tester, TrainingScreen(key: ValueKey('t3$n'), controller: c, tab: 2));
      showTopNotice(tester.element(find.byKey(const Key('trainingScreen'))),
          '$name이 훈련을 마쳤어요');
      await _settle(tester, 3);
      await _shot(tester, '${n}_15_펫훈련_끝_알림');
      await tester.pump(const Duration(seconds: 9));

      // 시련: 전투 → 결과 (실제 판 수)
      final trial = (await tester.runAsync(c.startTrial))!;
      await _page(
          tester,
          TrainingBattleScreen(
              key: ValueKey('tr$n'),
              controller: c,
              mode: TrainingMode.trial,
              battle: trial,
              tickInterval: const Duration(milliseconds: 60)));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      await _shot(tester, '${n}_16_시련_전투');
      await _runBattle(tester);
      await _shot(tester, '${n}_17_시련_결과');
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('b43 $n: 시련 15판 넘김 · 보상 · 칭호 · 기록 탭', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async => c = await startVillage(16,
          farewell: true, village: {'seen': ['intro', 'farewell']}));
      final b = (await tester.runAsync(c.startTrial))!;
      b.floor = 16;
      b.phase = BattlePhase.failed;
      await tester.runAsync(() => c.finishTrial(b));
      await _page(tester, TrainingScreen(key: ObjectKey(c), controller: c, tab: 3));
      await _shot(tester, '${n}_18_시련탭_15판_보상');
      await _page(
          tester,
          Scaffold(
              body: NightBackground(
                  header: true,
                  child: RecordsScreen(
                      player: c.player,
                      npcStories: c.npcStories,
                      trial: (week: c.trialBestThisWeek, ever: c.trialEver)))));
      final list = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
          find.byKey(const Key('trialRecords')), 200,
          scrollable: list);
      await _settle(tester, 3);
      await _shot(tester, '${n}_19_기록탭_시련');
      await tester.pump(const Duration(seconds: 9));
    });
  }
}
