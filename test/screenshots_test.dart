// 화면 미리보기 이미지를 build/screenshots/ 에 만든다.
// GitHub 자동 테스트가 이 그림들을 ci-results 브랜치에 올린다.
//
// 한글은 테스트용 나눔고딕(test/fonts, OFL 라이선스)으로 그린다.
// 앱에는 들어가지 않는다.

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/battle/field_battle_screen.dart';
import 'package:isekai_reality/features/level_up/level_up_dialog.dart';
import 'package:isekai_reality/features/town/inn_screen.dart';

final _root = GlobalKey();

Future<void> _loadFonts() async {
  // 테스트의 기본 글꼴(Roboto) 자리에 한글 글꼴을 넣는다
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

  // 머티리얼 아이콘
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
  // 그림 파일을 먼저 읽어 둔다 (없는 그림은 아이콘으로 대신 그려진다)
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      final image = element.widget as Image;
      await precacheImage(image.image, element, onError: (_, __) {});
    }
  });
  await tester.pump();
  // 배경으로 쓰는 그림(테두리·버튼)은 따로 읽히므로 잠깐 기다렸다가 다시 그린다
  for (var i = 0; i < 2; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 400)));
    await tester.pump();
  }

  final boundary =
      tester.renderObject(find.byKey(_root)) as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  File('build/screenshots/$name.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!);
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532); // 아이폰 13·14 크기
  tester.view.devicePixelRatio = 3;
  // 상태 표시줄(위 47pt)과 홈 표시줄(아래 34pt)까지 실제 아이폰처럼
  tester.view.padding = const FakeViewPadding(top: 141, bottom: 102);
  tester.view.viewPadding = const FakeViewPadding(top: 141, bottom: 102);
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('화면 미리보기: 예시 데이터로 탭과 던전', (tester) async {
    _phone(tester);
    final c = AppController.demo(clock: () => DateTime(2026, 11, 8, 14));
    await tester.pumpWidget(
        RepaintBoundary(key: _root, child: IsekaiRealityApp(controller: c)));
    await c.init();
    await tester.pump();
    await tester.pump();

    await _shot(tester, '01_상태창');

    await tester.tap(find.text('지도'));
    await tester.pumpAndSettle();
    await _shot(tester, '02_지도_키없음');

    // 던전
    await tester.tap(find.text('상태'));
    await tester.pumpAndSettle();
    final open = find.textContaining('던전 열기 (열쇠');
    await tester.scrollUntilVisible(open, 300,
        scrollable: find.byType(Scrollable).first);
    await _shot(tester, '03_상태창_아래');
    await tester.tap(open);
    await tester.pumpAndSettle();
    await _shot(tester, '04_던전_입장');

    await tester.scrollUntilVisible(find.text('던전 열기 · 열쇠 1개'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await _shot(tester, '04b_던전_입장_아래');
    await tester.tap(find.text('던전 열기 · 열쇠 1개'));
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 900));
    }
    await _shot(tester, '05_던전_전투');

    // 연출 중간 모습: 타격 순간, 불씨의 일격
    await tester.pump(const Duration(milliseconds: 250));
    await _shot(tester, '05b_던전_타격');
    if (find.text('불씨의 일격!').evaluate().isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 550));
      await _shot(tester, '05a_던전_대기');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('불씨의 일격!').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 240));
      await _shot(tester, '05c_던전_일격');
    }

    var bossShot = false;
    for (var i = 0;
        i < 200 &&
            find.text('던전 정화 완료!').evaluate().isEmpty &&
            find.text('이번엔 물러났어요').evaluate().isEmpty;
        i++) {
      if (!bossShot && find.text('BOSS').evaluate().isNotEmpty) {
        bossShot = true;
        await tester.pump(const Duration(milliseconds: 900));
        await _shot(tester, '06_던전_보스');
      }
      if (find.text('불씨의 일격!').evaluate().isNotEmpty) {
        await tester.tap(find.text('불씨의 일격!'));
      }
      await tester.pump(const Duration(milliseconds: 900));
    }
    await tester.pumpAndSettle();
    await _shot(tester, '07_던전_결과');
    await tester.scrollUntilVisible(find.text('돌아가기'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('돌아가기'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('기록'));
    await tester.pumpAndSettle();
    await _shot(tester, '08_기록');

    await tester.tap(find.text('도감'));
    await tester.pumpAndSettle();
    await _shot(tester, '09_도감');
    await tester.scrollUntilVisible(find.textContaining('몬스터 도감'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pump();
    await _shot(tester, '10_도감_몬스터');

    await tester.tap(find.text('설정'));
    await tester.pumpAndSettle();
    await _shot(tester, '11_설정');

    // 레벨업 연출
    showDialog<void>(
      context: tester.element(find.byType(OrnateNavBar)),
      builder: (_) => const LevelUpDialog(from: 9, to: 10),
    );
    await tester.pumpAndSettle();
    await _shot(tester, '12_레벨업');
    await tester.tap(find.text('계속'));
    await tester.pumpAndSettle();

    // 필드 몬스터 정화
    final spawn = c.todaySpawns.firstWhere(
        (s) => s.info.name == '거칠어진 물방울 정령',
        orElse: () => c.todaySpawns.first);
    Navigator.of(tester.element(find.byType(OrnateNavBar))).push(
      MaterialPageRoute<void>(
          builder: (_) => FieldBattleScreen(controller: c, spawn: spawn)),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 700));
    }
    await _shot(tester, '13_필드_전투');
    for (var i = 0;
        i < 60 &&
            find.text('정화 완료!').evaluate().isEmpty &&
            find.text('이번엔 물러났어요').evaluate().isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 700));
    }
    await tester.pumpAndSettle();
    await _shot(tester, '14_필드_정화');
    await tester.scrollUntilVisible(find.text('돌아가기'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('돌아가기'));
    await tester.pumpAndSettle();
  });

  testWidgets('화면 미리보기: 여성 각성자', (tester) async {
    _phone(tester);
    final c = AppController.demo(clock: () => DateTime(2026, 11, 8, 14));
    await tester.pumpWidget(
        RepaintBoundary(key: _root, child: IsekaiRealityApp(controller: c)));
    await c.init();
    await c.updateProfile(c.profile.copyWith(look: HeroLook.female));
    await tester.pumpAndSettle();
    await _shot(tester, '17_여성_상태창');

    await tester.tap(find.text('도감'));
    await tester.pumpAndSettle();
    await _shot(tester, '18_여성_도감');

    final spawn = c.todaySpawns.first;
    Navigator.of(tester.element(find.byType(OrnateNavBar))).push(
      MaterialPageRoute<void>(
          builder: (_) => FieldBattleScreen(controller: c, spawn: spawn)),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      await tester.pump(const Duration(milliseconds: 700));
    }
    await _shot(tester, '19_여성_전투');
    for (var i = 0;
        i < 60 &&
            find.text('정화 완료!').evaluate().isEmpty &&
            find.text('이번엔 물러났어요').evaluate().isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 700));
    }
    await tester.pumpAndSettle();
  });

  testWidgets('화면 미리보기: 여관과 잡화상', (tester) async {
    _phone(tester);
    final c = AppController.demo(clock: () => DateTime(2026, 11, 8, 20));
    await tester.pumpWidget(
        RepaintBoundary(key: _root, child: IsekaiRealityApp(controller: c)));
    await c.init();
    await tester.pumpAndSettle();

    final inn = find.text('여관');
    await tester.scrollUntilVisible(inn, 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await _shot(tester, '20_상태창_마을');

    await tester.tap(inn);
    await tester.pumpAndSettle();
    await _shot(tester, '21_여관');
    Navigator.of(tester.element(find.byType(InnScreen))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('잡화상'));
    await tester.pumpAndSettle();
    await c.buy(ShopItem.bulssiPotion);
    await tester.pumpAndSettle();
    await _shot(tester, '22_잡화상');
  });

  testWidgets('화면 미리보기: 첫 실행 각성', (tester) async {
    _phone(tester);
    final c = AppController(
      store: InMemoryRecordStore(),
      health: FakeHealthSource(granted: false),
      clock: () => DateTime(2026, 11, 8, 14),
    );
    await tester.pumpWidget(
        RepaintBoundary(key: _root, child: IsekaiRealityApp(controller: c)));
    await c.init();
    await tester.pump();
    await _shot(tester, '15_각성_소개');

    for (var i = 0; i < 4; i++) {
      final next = find.text('다음').evaluate().isNotEmpty
          ? find.text('다음')
          : find.text('좋아!');
      await tester.tap(next);
      await tester.pumpAndSettle();
    }
    await _shot(tester, '15b_각성_동의');
    final checks = find.byType(Checkbox);
    for (final i in [0, 1, 3]) {
      await tester.tap(checks.at(i));
    }
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('동의하고 다음'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('동의하고 다음'));
    await tester.pumpAndSettle();
    await _shot(tester, '16_각성_이름');
  });
}
