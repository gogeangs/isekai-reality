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
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/lens/demo_filter_engine.dart';
import 'package:isekai_reality/features/lens/lens_output.dart';
import 'package:isekai_reality/features/lens/lens_screen.dart';
import 'package:isekai_reality/features/lens/race_stickers.dart';
import 'package:isekai_reality/features/battle/field_battle_screen.dart';
import 'package:isekai_reality/features/level_up/level_up_dialog.dart';
import 'package:isekai_reality/features/town/inn_screen.dart';
import 'package:isekai_reality/features/village/board_screen.dart';
import 'package:isekai_reality/features/map/expedition_result.dart';
import 'package:isekai_reality/features/pets/farewell_screen.dart';
import 'package:isekai_reality/features/pets/pet_screen.dart';
import 'package:isekai_reality/core/models/pet_state.dart';
import 'package:isekai_reality/features/town/bag_tab.dart';
import 'package:isekai_reality/core/models/vitals.dart';
import 'package:isekai_reality/features/town/shop_screen.dart';
import 'package:isekai_reality/features/settings/settings_screen.dart';
import 'package:isekai_reality/features/smithy/smithy_screen.dart';
import 'package:isekai_reality/features/alchemy/alchemy_screen.dart';
import 'package:isekai_reality/features/town/material_view.dart';
import 'package:isekai_reality/features/profile/profile_screen.dart';
import 'package:isekai_reality/core/geo/geo.dart';
import 'package:isekai_reality/features/harvest/harvest_sheet.dart';

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
    // 묶음 16 #126: 켜면 지도. 상태창은 눌러서
    await tester.tap(find.text('상태'));
    await tester.pumpAndSettle();

    await _shot(tester, '01_상태창');

    await tester.tap(find.text('지도'));
    await tester.pumpAndSettle();
    await _shot(tester, '02_지도_키없음');
    final monsterTile = find.byType(ListTile).first;
    await tester.scrollUntilVisible(monsterTile, 200,
        scrollable: find.byType(Scrollable).first);
    // 위쪽 버튼(프로필·우편·설정)에 가리지 않게 조금 내린다
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 160));
    await tester.pumpAndSettle();
    await _shot(tester, '02a_지도_원정목록');
    await tester.tap(monsterTile);
    await tester.pumpAndSettle();
    await _shot(tester, '02b_정령_원정');
    await tester.tapAt(const Offset(200, 80));
    await tester.pumpAndSettle();

    // 던전
    // 11-11 #68: 던전 열기는 지도 아래 띠
    await tester.tap(find.text('지도'));
    await tester.pumpAndSettle();
    await _shot(tester, '03_지도_던전_띠');
    // 원정 한 줄 띠와 펼친 모습 (11-11 #78)
    final sent = await c.sendSpirit(c.todaySpawns.first);
    await tester.pumpAndSettle();
    if (sent == ExpeditionCheck.ok) {
      await _shot(tester, '03b_지도_원정_띠');
      await tester.tap(find.byKey(const Key('expeditionStrip')));
      await tester.pumpAndSettle();
      await _shot(tester, '03c_지도_원정_펼침');
      await tester.tap(find.byKey(const Key('expeditionOpen')));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const Key('openDungeon')));
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
    if (find.text('약점 간파!').evaluate().isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 550));
      await _shot(tester, '05a_던전_대기');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const Key('skillButton')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 240));
      await _shot(tester, '05c_던전_일격');
    }

    var bossShot = false;
    for (var i = 0;
        i < 200 &&
            find.text('던전 돌파!').evaluate().isEmpty &&
            find.text('이번엔 물러났어요').evaluate().isEmpty;
        i++) {
      if (!bossShot && find.text('BOSS').evaluate().isNotEmpty) {
        bossShot = true;
        await tester.pump(const Duration(milliseconds: 900));
        await _shot(tester, '06_던전_보스');
      }
      if (find.text('약점 간파!').evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const Key('skillButton')),
            warnIfMissed: false);
      }
      await tester.pump(const Duration(milliseconds: 900));
    }
    await tester.pumpAndSettle();
    await _shot(tester, '07_던전_결과');
    // 알을 주웠다는 알림이 버튼을 가리지 않게
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).last))
        .clearSnackBars();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('돌아가기'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('돌아가기'));
    await tester.pumpAndSettle();

    // 프로필 (왼쪽 위) · 기록
    await tester.tap(find.byType(ProfileButton));
    await tester.pumpAndSettle();
    await _shot(tester, '08_프로필');
    await tester.tap(find.text('기록'));
    await tester.pumpAndSettle();
    await _shot(tester, '08b_프로필_기록');
    Navigator.of(tester.element(find.byType(ProfileScreen))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('도감'));
    await tester.pumpAndSettle();
    await _shot(tester, '09_도감');
    final tile = find.textContaining('마리');
    if (tile.evaluate().isNotEmpty) {
      await tester.ensureVisible(tile.first);
      await tester.pumpAndSettle();
      await tester.tap(tile.first, warnIfMissed: false);
      await tester.pumpAndSettle();
      if (find.byType(BottomSheet).evaluate().isNotEmpty) {
        await _shot(tester, '10_도감_몬스터_설명');
        Navigator.of(tester.element(find.byType(BottomSheet))).pop();
        await tester.pumpAndSettle();
      }
    }

    await tester.tap(find.byTooltip('설정'));
    await tester.pumpAndSettle();
    await _shot(tester, '11_설정');
    Navigator.of(tester.element(find.byType(SettingsScreen))).pop();
    await tester.pumpAndSettle();

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
            find.text('사냥 성공!').evaluate().isEmpty &&
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
            find.text('사냥 성공!').evaluate().isEmpty &&
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

    // 11-10: 여관·잡화상은 마을 탭에서
    await tester.tap(find.text('마을'));
    await tester.pumpAndSettle();
    await _shot(tester, '20_마을');

    await tester.tap(find.text('여관').last);
    await tester.pumpAndSettle();
    await _shot(tester, '21_여관');
    Navigator.of(tester.element(find.byType(InnScreen))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('잡화상').last);
    await tester.pumpAndSettle();
    await c.buy(ShopItem.bulssiPotion);
    await c.buy(ShopItem.healSmall);
    await tester.pumpAndSettle();
    await _shot(tester, '22_잡화상');
    expect(find.text('가방 열기'), findsNothing); // 11-11 #99
    await tester.ensureVisible(find.text('재료·물건·장비 팔기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('재료·물건·장비 팔기'));
    await tester.pumpAndSettle();
    await _shot(tester, '22c_잡화상_팔기');
    Navigator.of(tester.element(find.byType(BottomSheet))).pop();
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(ShopScreen))).pop();
    await tester.pumpAndSettle();

    // 의뢰 게시판 · 가방 탭
    await tester.tap(find.text('의뢰 게시판').last);
    await tester.pumpAndSettle();
    await _shot(tester, '27_의뢰_게시판');
    Navigator.of(tester.element(find.byType(BoardScreen))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('가방'));
    await tester.pumpAndSettle();
    await _shot(tester, '26_가방_탭');
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
    await tester.pumpAndSettle();
    await _shot(tester, '15_각성_도입1');
    // 장면 2(위쪽 대사창), 3(탑), 6(정령들)까지 눌러서 넘긴다
    await tester.tapAt(const Offset(200, 600));
    await tester.pumpAndSettle();
    await _shot(tester, '15a_각성_도입2');
    for (var i = 0; i < 2; i++) {
      await tester.tapAt(const Offset(200, 600));
      await tester.pumpAndSettle();
    }
    await _shot(tester, '15c_각성_도입3_탑');
    for (var i = 0; i < 4; i++) {
      await tester.tapAt(const Offset(200, 600));
      await tester.pumpAndSettle();
    }
    await _shot(tester, '15d_각성_도입6_정령들');
    await tester.tap(find.text('건너뛰기 ›'));
    await tester.pumpAndSettle();
    await _shot(tester, '15e_정령_고르기');
    await tester.tap(find.text('식물의 정령'));
    await tester.pumpAndSettle();
    await _shot(tester, '15f_정령_고르기_식물');
    await tester.scrollUntilVisible(find.text('이 정령과 함께하기'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('이 정령과 함께하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('확정'));
    await tester.pumpAndSettle();
    await _shot(tester, '15g_정령_이름');
    await tester.scrollUntilVisible(find.text('이 이름으로'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('이 이름으로'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('확정'));
    await tester.pumpAndSettle();
    await _shot(tester, '15b_각성_동의');
    final checks = find.byType(Checkbox);
    for (final i in [0, 1]) {
      await tester.tap(checks.at(i));
    }
    await tester.enterText(find.byKey(const Key('birthYear')), '1995');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('동의하고 다음'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('동의하고 다음'));
    await tester.pumpAndSettle();
    await _shot(tester, '16_각성_이름');
    await tester.enterText(find.byType(TextField), '하루');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('다음'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    await _shot(tester, '16b_각성_장면');
    await tester.tap(find.text('깨어나기'));
    await tester.pumpAndSettle();
    await _shot(tester, '16c_식물_정령_상태창');
  });

  testWidgets('화면 미리보기: 지친 각성자와 정령 표정', (tester) async {
    _phone(tester);
    final c = AppController.demo(clock: () => DateTime(2026, 11, 8, 14));
    await tester.pumpWidget(
        RepaintBoundary(key: _root, child: IsekaiRealityApp(controller: c)));
    await c.init();
    await tester.pumpAndSettle();

    // 필드 전투에서 HP 0
    final spawn = c.todaySpawns.first;
    final battle = c.startFieldBattle(spawn)!;
    battle.playerHp = 0;
    await c.finishFieldBattle(spawn, battle);
    await tester.pumpAndSettle();
    await _shot(tester, '23_지친_상태창');

    final nav = Navigator.of(tester.element(find.byType(Scaffold).first));
    nav.push(MaterialPageRoute<void>(
        builder: (_) =>
            FieldBattleScreen(controller: c, spawn: c.todaySpawns.first)));
    await tester.pumpAndSettle();
    await _shot(tester, '24_지친_필드');
    nav.pop();
    await tester.pumpAndSettle();

    // 여관에서 쉬는 중: 졸린 정령
    await c.restAtInn();
    await tester.pumpAndSettle();
    await _shot(tester, '25_쉬는_중');
  });

  testWidgets('화면 미리보기: 수식어·대장간·장비', (tester) async {
    _phone(tester);
    final c = AppController.demo(clock: () => DateTime(2026, 11, 8, 20));
    await tester.pumpWidget(
        RepaintBoundary(key: _root, child: IsekaiRealityApp(controller: c)));
    await c.init();
    await tester.pumpAndSettle();

    // 수식어 몬스터와 싸운다 (고대의 분노한 큰쥐)
    final base = c.todaySpawns.first;
    final spawn = FieldSpawn(
      id: base.id,
      monster: MonsterId.giantRat,
      point: base.point,
      modifiers: const [ModifierId.ancient, ModifierId.enraged],
    );
    final nav = Navigator.of(tester.element(find.byType(Scaffold).first));
    nav.push(MaterialPageRoute<void>(
        builder: (_) => FieldBattleScreen(
            controller: c,
            spawn: spawn,
            tickInterval: const Duration(milliseconds: 100))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await _shot(tester, '29_수식어_전투');
    for (var i = 0;
        i < 300 &&
            find.text('사냥 성공!').evaluate().isEmpty &&
            find.text('이번엔 물러났어요').evaluate().isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    await _shot(tester, '29b_수식어_결과');
    nav.pop();
    await tester.pumpAndSettle();

    // 도감 아래 희귀·전설 사냥 기록
    await tester.tap(find.text('도감'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('희귀·전설 사냥 기록'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await _shot(tester, '29c_도감_수식어');

    // 장비를 만들고 입는다
    final armor = await c.craft(EquipBase.armor);
    final cap = await c.craft(EquipBase.cap);
    await c.equip(armor!.uid);
    await c.equip(cap!.uid);
    await c.enhance(armor.uid);
    await tester.pumpAndSettle();

    await tester.tap(find.text('마을'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('대장간').last);
    await tester.pumpAndSettle();
    await _shot(tester, '28_대장간');
    await tester.tap(find.text('강화'));
    await tester.pumpAndSettle();
    await _shot(tester, '28b_대장간_강화');
    await tester.tap(find.text('수리 · 분해'));
    await tester.pumpAndSettle();
    await _shot(tester, '28c_대장간_수리');
    // 장비 속성 (11-11 #74): 입히기 · 바꾸기 · 추출 · 강화
    await tester.ensureVisible(find.byKey(Key('imbue_${armor.uid}')));
    await tester.tap(find.byKey(Key('imbue_${armor.uid}')));
    await tester.pumpAndSettle();
    await _shot(tester, '28d_대장간_속성');
    Navigator.of(tester.element(find.text('속성 입히기'))).pop();
    await tester.pumpAndSettle();
    // 보스 장비 (11-11 #82)
    await tester.tap(find.text('보스 장비'));
    await tester.pumpAndSettle();
    await _shot(tester, '28g_대장간_보스장비');
    Navigator.of(tester.element(find.byType(SmithyScreen))).pop();
    await tester.pumpAndSettle();

    // 연금술 공방 변환 (11-11 #74)
    Navigator.of(tester.element(find.byType(Scaffold).first)).push(
        MaterialPageRoute<void>(builder: (_) => AlchemyScreen(controller: c)));
    await tester.pumpAndSettle();
    await _shot(tester, '28e_공방_가마솥');
    await tester.tap(find.text('변환'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('마석 정제'));
    await tester.pumpAndSettle();
    await _shot(tester, '28f_공방_변환');
    Navigator.of(tester.element(find.byType(AlchemyScreen))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('가방'));
    await tester.pumpAndSettle();
    await _shot(tester, '26b_가방_장비');
    await tester.tap(find.byType(BagSlot).first);
    await tester.pumpAndSettle();
    await _shot(tester, '26c_가방_칸_누름');
  });

  testWidgets('화면 미리보기: 원정 결과 카드', (tester) async {
    _phone(tester);
    final base = Expedition(
      spawnId: 's1',
      monster: 'hornRabbit',
      lat: 37.3,
      lng: 126.8,
      distanceM: 800,
      mpCost: 16,
      startedAt: DateTime(2026, 11, 8, 14),
      arriveAt: DateTime(2026, 11, 8, 14, 8),
      returnAt: DateTime(2026, 11, 8, 14, 16),
    );
    final cases = {
      '33a_원정_성공': base.withResult(true,
          newSpecies: true,
          reward: const {'exp': 18, 'manaStone': 1, 'smallHorn': 1, 'goldenRabbitFur': 1}),
      '33b_원정_실패': base.withResult(false),
      '33c_원정_놓침': base.withResult(false, escaped: true),
    };
    for (final e in cases.entries) {
      await tester.pumpWidget(RepaintBoundary(
        key: _root,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          home: Scaffold(
            backgroundColor: const Color(0xFF0F1233),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: ExpeditionResultCard(ex: e.value, spiritName: '불씨'),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await _shot(tester, e.key);
    }
  });

  testWidgets('화면 미리보기: 정령 이별과 펫', (tester) async {
    _phone(tester);
    final c = AppController(
      store: InMemoryRecordStore(
        profile: const PlayerProfile(name: '하루'),
        history: [
          DailyRecord(
              date: DateTime(2026, 11, 8),
              gains: {'exp': LevelRules.totalExpToReach(11)}),
        ],
        json: {
          'pets': const PetState(
                  eggs: [PetEgg(id: 'egg1', source: 'field')],
                  firstEggFound: true,
                  nextId: 2)
              .toJson(),
        },
      ),
      health: FakeHealthSource(granted: false),
      clock: () => DateTime(2026, 11, 8, 14),
    );
    await tester.pumpWidget(
        RepaintBoundary(key: _root, child: IsekaiRealityApp(controller: c)));
    await c.init();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    // 레벨업 연출이 먼저 뜨면 닫는다
    if (find.text('계속').evaluate().isNotEmpty) {
      await tester.tap(find.text('계속').first);
      await tester.pump(const Duration(milliseconds: 500));
    }
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.byType(FarewellScreen), findsOneWidget);
    await _shot(tester, '40_정령_이별1');
    await tester.tap(find.text('다음'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('다음'));
    await tester.pump(const Duration(milliseconds: 400));
    await _shot(tester, '40b_정령_이별_알');
    await tester.tap(find.text('알을 깨운다'));
    await tester.pump(const Duration(seconds: 1));
    await _shot(tester, '41_첫_펫_부화');
    await tester.enterText(find.byKey(const Key('petName')), '호호');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.text('이름 짓기'));
    await tester.tap(find.text('이름 짓기'));
    await tester.pump(const Duration(milliseconds: 500));
    await _shot(tester, '42_정령_작별');
    await tester.tap(find.textContaining('함께 가기'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    await _shot(tester, '43_펫과_상태창');
    Navigator.of(tester.element(find.byType(OrnateNavBar))).push(
        MaterialPageRoute<void>(builder: (_) => PetScreen(controller: c)));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    await _shot(tester, '44_내_펫');
  });

  testWidgets('화면 미리보기: 펫 도감·알·원정', (tester) async {
    _phone(tester);
    final c = AppController.demo(clock: () => DateTime(2026, 11, 8, 14));
    await tester.pumpWidget(
        RepaintBoundary(key: _root, child: IsekaiRealityApp(controller: c)));
    await c.init();
    await tester.pumpAndSettle();
    await tester.tap(find.text('도감'));
    await tester.pumpAndSettle();
    // 묶음 15 #116: 펫 탭은 정령과 이별한 뒤에만
    if (c.farewellDone) {
      await tester.tap(find.text('펫'));
      await tester.pumpAndSettle();
    } else {
      expect(find.byKey(const Key('codexTab_1')), findsNothing);
    }
    await _shot(tester, '45_도감_펫');
    await tester.tap(find.text('가방'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BagSlot).first);
    await tester.pumpAndSettle();
    await _shot(tester, '46_가방_펫_알');
  });

  testWidgets('화면 미리보기: 마법 돋보기 감정', (tester) async {
    _phone(tester);
    LensScreen.engineFactory = DemoFilterEngine.new;
    var saved = 0;
    LensOutput.saver = (_) async {
      saved++;
      return null;
    };
    final c = AppController.demo(clock: () => DateTime(2026, 11, 8, 14));
    await tester.pumpWidget(
        RepaintBoundary(key: _root, child: IsekaiRealityApp(controller: c)));
    await c.init();
    await tester.pumpAndSettle();
    expect(await c.buy(ShopItem.raceLens), PurchaseCheck.ok);
    await tester.pumpAndSettle();
    // 종족 장식 그림은 실제 시간에 읽어 둔다 (그림이 생기면 테스트 시계로는 끝나지 않는다)
    await tester.runAsync(StickerArt.load);
    Navigator.of(tester.element(find.byType(OrnateNavBar))).push(
        MaterialPageRoute<void>(builder: (_) => LensScreen(controller: c)));
    await tester.pumpAndSettle();
    await _shot(tester, '47_돋보기_조준');
    await tester.tap(find.byKey(const Key('appraise')));
    await tester.pump(const Duration(milliseconds: 1100));
    await _shot(tester, '48_돋보기_감정중');
    await tester.pumpAndSettle();
    expect(find.textContaining('감정 결과'), findsOneWidget);
    await _shot(tester, '49_돋보기_감정결과');
    expect(c.bagCount(ShopItem.raceLens), 0);
    expect(c.racesSeen, isNotEmpty);
    await tester.tap(find.byKey(const Key('lensToFilter')));
    await tester.pumpAndSettle();
    await _shot(tester, '50_돋보기_종족필터');
    // 사진 만들기(그림 그리기·PNG)는 실제 시간이 필요하다
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('lensShutter')));
      await Future<void>.delayed(const Duration(seconds: 2));
    });
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('lensPhoto')), findsOneWidget);
    await _shot(tester, '51_돋보기_사진틀');
    await tester.tap(find.byKey(const Key('lensSave')));
    await tester.pumpAndSettle();
    // 묶음 13 B5: 저장 직전 다른 사람 동의 안내
    expect(find.byKey(const Key('consentAlert')), findsOneWidget);
    await _shot(tester, '51b_돋보기_동의_안내');
    await tester.tap(find.byKey(const Key('consentOk')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(saved, 1);
    // 11-11 #97: 도감 「종족」 대신 돋보기 안 감정 앨범
    expect(c.album, isNotEmpty);
    await tester.tap(find.byKey(const Key('lensAlbum')));
    await tester.pumpAndSettle();
    expect(find.text('사진 ${c.album.length}장'), findsOneWidget);
    expect(find.text('처음 만난 종족!'), findsWidgets);
    expect(find.textContaining('/ 8'), findsNothing);
    await _shot(tester, '52_감정_앨범');
  });

  testWidgets('화면 미리보기: 채집·승객·우편 (11-11)', (tester) async {
    _phone(tester);
    var now = DateTime(2026, 11, 8, 14);
    final c = AppController.demo(clock: () => now);
    await tester.pumpWidget(
        RepaintBoundary(key: _root, child: IsekaiRealityApp(controller: c)));
    await c.init();
    await tester.pumpAndSettle();
    // 채집 자리 앞에 선다
    final spot = c.harvestSpots.firstWhere((h) => h.kind == HarvestKind.herb);
    await c.handleFix(LocationFix(point: spot.point));
    await tester.pumpAndSettle();
    final ctx = tester.element(find.byType(OrnateNavBar));
    showHarvestSheet(ctx, c, spot);
    await tester.pumpAndSettle();
    await _shot(tester, '53_채집_자리');
    await tester.tap(find.byKey(const Key('harvestGame')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 400));
    await _shot(tester, '54_채집_미니게임');
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const Key('gameTap')));
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(c.harvest.total, 1);
    Navigator.of(tester.element(find.byType(OrnateNavBar))).popUntil((r) => r.isFirst);
    await tester.pumpAndSettle();
    ScaffoldMessenger.of(tester.element(find.byType(OrnateNavBar))).clearSnackBars();
    await tester.pumpAndSettle();
    // 차량 속도
    await c.handleFix(LocationFix(point: spot.point, speedMps: 9));
    now = now.add(const Duration(seconds: 11));
    await c.handleFix(LocationFix(point: spot.point, speedMps: 9));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('driveTitle')), findsOneWidget);
    await _shot(tester, '55_승객_확인');
    await tester.tap(find.byKey(const Key('drivePassenger')));
    await tester.pumpAndSettle();
    await _shot(tester, '56_승객_모드');
    // 우편함 (위쪽 알림 띠가 지나간 뒤에)
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mailButton')));
    await tester.pumpAndSettle();
    await _shot(tester, '57_우편함');
    // 11-11 #100: 선물·편지 탭 없이 한 목록, 필터만
    expect(find.textContaining('편지 '), findsNothing);
    await tester.tap(find.byKey(const Key('mailFilter_1')));
    await tester.pumpAndSettle();
    await _shot(tester, '58_우편함_공지');
  });

  // 그림 확인 (11-11): 앱이 쓰는 그림 자리마다 실제 화면 위젯으로 그려 본다.
  // 그림이 있으면 그림, 없으면 대신 그리는 아이콘이 보인다.
  testWidgets('화면 미리보기: 그림 확인 (물약·재료·몬스터)', (tester) async {
    _phone(tester);
    Widget grid(String title, List<(String, Widget)> items) => MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: const Color(0xFF141B3A),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(children: [
                  Text(title,
                      style: const TextStyle(color: Color(0xFFF5DC94), fontSize: 18)),
                  const SizedBox(height: 6),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 6,
                      childAspectRatio: 0.72,
                      children: [
                        for (final (name, w) in items)
                          Column(children: [
                            SizedBox(width: 52, height: 52, child: w),
                            Text(name,
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Color(0xFFF2EEE4), fontSize: 9)),
                          ]),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ),
        );
    Future<void> show(String shot, String title, List<(String, Widget)> items) async {
      await tester.pumpWidget(RepaintBoundary(key: _root, child: grid(title, items)));
      await tester.pump();
      await _shot(tester, shot);
    }

    await show('90_그림확인_물약', '물약 (PotionIcon)', [
      for (final p in AlchemyRules.all)
        (p.name, PotionIcon(potion: p.id, size: 52)),
      ('수상한 물약', const PotionIcon(suspicious: true, size: 52)),
    ]);
    const mats = Materials.all;
    final half = (mats.length / 2).ceil();
    await show('91_그림확인_재료1', '재료 1 (MaterialIcon)', [
      for (final m in mats.take(half)) (m.name, MaterialIcon(m.id, size: 52)),
    ]);
    await show('92_그림확인_재료2', '재료 2 (MaterialIcon)', [
      for (final m in mats.skip(half)) (m.name, MaterialIcon(m.id, size: 52)),
    ]);
    await show('93_그림확인_몬스터·아이콘', '몬스터 · 아이콘', [
      for (final m in MonsterId.values)
        (
          Monsters.info(m).name,
          Image.asset(Monsters.info(m).asset,
              errorBuilder: (_, __, ___) => const Icon(Icons.help_outline,
                  color: Colors.redAccent, size: 40))
        ),
      for (final n in ['icon_post', 'icon_mail', 'icon_alchemy', 'cauldron',
          'item_recipe_book', 'item_recipe_note', 'item_pouch', 'icon_convert_table'])
        (
          n,
          Image.asset('assets/images/$n.webp',
              errorBuilder: (_, __, ___) => const Icon(Icons.help_outline,
                  color: Colors.redAccent, size: 40))
        ),
    ]);
  });

  testWidgets('화면 미리보기: 첫 튜토리얼 (묶음 18)', (tester) async {
    _phone(tester);
    final t0 = DateTime(2026, 11, 13, 10);
    final c = AppController(
      store: InMemoryRecordStore(),
      health: FakeHealthSource(stepsByDay: const {}),
      clock: () => t0,
    )..mailSources = const [];
    await tester.runAsync(() async {
      await c.init();
      await c.awaken(name: '하루', look: HeroLook.female);
    });
    await tester.pumpWidget(
        RepaintBoundary(key: _root, child: IsekaiRealityApp(controller: c)));
    await tester.pump(const Duration(milliseconds: 1500));
    await _shot(tester, 'T1_각성_연출');
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 500));
    await _shot(tester, 'T1b_각성_연출_대사');
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await _shot(tester, 'T2_첫전투_안내');
    await tester.tap(find.byKey(const Key('spotlightHole')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    for (var i = 0;
        i < 80 && find.text('사냥 성공!').evaluate().isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 700));
    }
    await tester.pumpAndSettle();
    await _shot(tester, 'T3_사냥_결과');
    Navigator.of(tester.element(find.byType(FieldBattleScreen))).pop();
    await tester.pumpAndSettle();
    await _shot(tester, 'T4_가방_안내');
    await tester.tap(find.byKey(const Key('spotlightHole')));
    await tester.pumpAndSettle();
    await _shot(tester, 'T5_가방_반짝');
    await tester.tap(find.byKey(const Key('spotlightHole')));
    await tester.pumpAndSettle();
    await _shot(tester, 'T6_원정_안내');
    await tester.tap(find.byKey(const Key('spotlightHole')));
    await tester.pumpAndSettle();
    await _shot(tester, 'T7_원정_보내기');
    await tester.tap(find.byKey(const Key('spotlightHole')));
    await tester.pumpAndSettle();
    await _shot(tester, 'T8_원정_중_서두르기');
    await tester.tap(find.byKey(const Key('spotlightHole')));
    await tester.pumpAndSettle();
    await _shot(tester, 'T9_바로_돌아오기');
  });
}
