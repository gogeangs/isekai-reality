// 묶음 58: 지역 의뢰 · 심층 순위 · 테스 일지 · 거래소 미리보기 (build/screenshots/b59_*)
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
import 'package:isekai_reality/features/act4/act4_screens.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'batch52_test.dart' as b52;
import 'batch56_test.dart' as b56;
import 'batch59_test.dart' as b59;
import 'support/fake_arca.dart';

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
  File('build/screenshots/b59_$name.png')
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



void main() {
  setUpAll(_loadFonts);
  setUp(() => b56.now = b52.t0);

  for (final d in _devices) {
    final n = d.$1;

    testWidgets('b59 $n: 4막 장면 · 길드 없을 때', (tester) async {
      _device(tester, d);
      late AppController c;
      late FakeArca a;
      await tester.runAsync(() async {
        a = FakeArca();
        a.publicGuilds.addAll([
          {'gid': 'g7', 'name': '새벽걸음', 'emblem': 1, 'color': 2, 'level': 5, 'members': 18, 'size': 24},
          {'gid': 'g8', 'name': '달빛산책단', 'emblem': 3, 'color': 5, 'level': 3, 'members': 9, 'size': 22},
          {'gid': 'g9', 'name': '등불지기', 'emblem': 0, 'color': 0, 'level': 8, 'members': 26, 'size': 26},
        ]);
        (c, _) = await b59.act4(state: b59.ch2Done, arca: a);
      });
      await _page(tester, Act4SceneScreen(key: ObjectKey('s1$n'), controller: c, scene: GuildRules.chapter(1).scenes.first));
      await _shot(tester, '${n}_01_4막_카스파르');
      await _page(tester, Act4SceneScreen(key: ObjectKey('s2$n'), controller: c, scene: GuildRules.chapter(2).scenes.last));
      await _shot(tester, '${n}_02_4막_빈터');
      await _page(tester, GuildHallScreen(key: ObjectKey('h$n'), controller: c));
      await _shot(tester, '${n}_03_길드만들기');
      await tester.dragUntilVisible(find.byKey(const Key('lianGuildPanel')), find.byType(ListView).first, const Offset(0, -250));
      await _settle(tester);
      await _shot(tester, '${n}_04_들어가기_리안');
      await tester.tap(find.byKey(const Key('guildBrowse')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await _settle(tester);
      await _shot(tester, '${n}_05_공개길드');
    });

    testWidgets('b59 $n: 길드 · 회관 · 레이드 · 상점', (tester) async {
      _device(tester, d);
      late AppController c;
      late FakeArca a;
      await tester.runAsync(() async {
        a = FakeArca();
        (c, _) = await b59.act4(state: b59.ch2Done.copyWith(seals: 135), arca: a);
        await c.createGuild('등불지기', emblem: 2, color: 4);
        a.guildLevel = 6;
        a.guildStar = 3;
        a.walkDone = [true, true, false];
        a.guildClaimed.add('walk0');
        a.raidLeft = 0.62;
        a.myRaidDamage = 4210;
        a.guildDecos.addAll(['lights', 'fountain', 'flowerbed']);
        a.guildSlots
          ..[0] = 'lights'
          ..[1] = 'fountain'
          ..[3] = 'flowerbed';
        final ms = {
          'u2': ('별하', 31, 48210, 'vice', '오늘도 만 보!'),
          'u3': ('모래', 27, 39550, 'member', '레이드 같이 가요'),
          'u4': ('해솔', 24, 22100, 'member', ''),
          'u5': ('달빛', 35, 61020, 'member', '거인 잡자'),
        };
        for (final e in ms.entries) {
          a.guildMembers[e.key] = {
            'name': e.value.$1, 'level': e.value.$2, 'weekSteps': e.value.$3, 'role': e.value.$4, 'line': e.value.$5,
          };
        }
        a.guildMembers[a.uid]!['line'] = '함께 지켜요';
        await c.refreshGuild();
      });
      await _page(tester, GuildHallScreen(key: ObjectKey('g$n'), controller: c));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await _settle(tester);
      await _shot(tester, '${n}_06_길드');
      await tester.tap(find.byKey(const Key('guildTab_1')));
      await _settle(tester);
      await _shot(tester, '${n}_07_회관');
      await tester.drag(find.byType(ListView).first, const Offset(0, -600));
      await _settle(tester);
      await _shot(tester, '${n}_08_회관_기부_게시판');
      await tester.tap(find.byKey(const Key('guildTab_2')));
      await _settle(tester);
      await _shot(tester, '${n}_09_레이드');
      await tester.tap(find.byKey(const Key('guildTab_3')));
      await _settle(tester);
      await _shot(tester, '${n}_10_길드상점');
      final b = c.startRaid()!;
      await _page(
          tester,
          RaidBattleScreen(
              key: ObjectKey('r$n'), controller: c, battle: b, tickInterval: const Duration(milliseconds: 200)));
      await _settle(tester, 14);
      await _shot(tester, '${n}_11_레이드_싸움');
    });
  }
}
