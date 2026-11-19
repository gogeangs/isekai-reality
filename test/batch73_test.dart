// 묶음 73: #261 새 주인공 (맨손, 통 그림) · #260 전투 대열 (각성자 앞, 동료 뒷줄)

import 'dart:io';

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/data/storage/record_store.dart' show HeroLook;
import 'package:isekai_reality/features/act3/act3_screen.dart';
import 'package:isekai_reality/features/battle/battle_view.dart';
import 'package:isekai_reality/features/profile/profile_screen.dart';
import 'package:isekai_reality/features/smithy/first_weapon_picker.dart';
import 'package:isekai_reality/features/status/status_screen.dart';

import 'batch52_test.dart' as b52;
import 'batch56_test.dart' as b56;

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  setUp(() => b56.now = b52.t0);

  group('#261 새 주인공 그림', () {
    test('공격은 여섯 칸을 차례로 넘긴다', () {
      expect(HeroSprite.frameAt(0), 0);
      expect(HeroSprite.frameAt(0.17), 1);
      expect(HeroSprite.frameAt(0.5), 3);
      expect(HeroSprite.frameAt(0.99), 5);
      expect(HeroSprite.frameAt(1), 5);
      expect(HeroSprite.frameAt(-1), 0);
    });

    test('쓰는 그림이 모두 있고, 옛 그림(부위 그림·옛 서기)은 없다', () {
      for (final look in HeroLook.values) {
        for (final f in [
          heroBaseAsset(look),
          heroBaseAsset(look, tired: true),
          portraitAsset(look),
          for (final p in HeroPose.values) 'assets/images/hero_${p.name}_${look.name}.webp',
        ]) {
          expect(File(f).existsSync(), isTrue, reason: f);
        }
      }
      expect(heroBaseAsset(HeroLook.female, tired: true), 'assets/images/hero_stand_tired_female.webp');
      expect(heroBaseAsset(HeroLook.male), 'assets/images/hero_base_male.webp');
      expect(Directory('assets/images/rig').existsSync(), isFalse);
      for (final f in ['hero_chibi_male', 'hero_stand_male', 'hero_stand_female']) {
        expect(File('assets/images/$f.webp').existsSync(), isFalse, reason: f);
      }
      expect(File('pubspec.yaml').readAsStringSync(), isNot(contains('images/rig/')));
    });

    testWidgets('공격 그림: 가운데쯤이면 넷째 칸, 바닥에 맞춰 그린다', (tester) async {
      await tester.pumpWidget(_app(const Center(
          child: SizedBox(
              width: 300,
              height: 400,
              child: HeroSprite(look: HeroLook.female, pose: HeroPose.attack, t: 0.5)))));
      expect(find.byKey(const Key('heroFrame_3')), findsOneWidget);
      final frame = tester.getRect(find.byKey(const Key('heroFrame_3')));
      expect(frame.width, closeTo(300 * 640 / 768, 0.5));
      expect(frame.height, closeTo(400 * 800 / 1024, 0.5));
      final box = tester.getRect(find.byType(HeroSprite));
      expect(frame.bottom, closeTo(box.bottom, 0.5));
      final img = tester.widget<Image>(find.byType(Image));
      expect((img.image as AssetImage).assetName, 'assets/images/hero_attack_female.webp');
    });

    testWidgets('얼굴 동그라미: 크게 키워 얼굴을 가운데로, 그림 밖은 보이지 않게', (tester) async {
      for (final look in HeroLook.values) {
        await tester.pumpWidget(_app(Center(child: ProfileButton(look: look, level: 3))));
        final circle = tester.getRect(find.byType(PortraitFace));
        final pic = tester.getRect(find.byKey(const Key('portraitFace')));
        expect(pic.width, closeTo(circle.width * PortraitFace.zoom, 0.5));
        expect(pic.left, lessThanOrEqualTo(circle.left + 0.01));
        expect(pic.top, lessThanOrEqualTo(circle.top + 0.01));
        expect(pic.right, greaterThanOrEqualTo(circle.right - 0.01));
        expect(pic.bottom, greaterThanOrEqualTo(circle.bottom - 0.01));
        // 얼굴 가운데가 동그라미 가운데 가까이
        final f = PortraitFace.faceOf(look);
        final face = Offset(pic.left + f.dx * pic.width, pic.top + f.dy * pic.height);
        expect((face.dx - circle.center.dx).abs(), lessThan(circle.width * 0.12));
        expect(face.dy, lessThan(circle.center.dy));
      }
    });

    testWidgets('첫 무기 고르기: 맨손 주인공 옆에 고른 무기', (tester) async {
      late AppController c;
      await tester.runAsync(() async => c = (await b52.start(b52.account())).$1);
      await tester.pumpWidget(_app(SingleChildScrollView(child: FirstWeaponPicker(controller: c, onCraft: (_) {}))));
      await tester.tap(find.byKey(const Key('firstWeapon_ironSword')));
      await tester.pump(const Duration(milliseconds: 300));
      final preview = find.byKey(const Key('firstWeaponPreview'));
      expect(preview, findsOneWidget);
      final img = tester.widget<Image>(find.descendant(of: preview, matching: find.byType(Image)).first);
      expect((img.image as AssetImage).assetName, heroBaseAsset(c.profile.look));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 8));
    });
  });

  group('#260 전투 대열', () {
    testWidgets('동료가 있으면 각성자가 앞(몬스터 쪽), 동료는 뒷줄, 각성자 머리가 더 위', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      late AppController c;
      await tester.runAsync(() async {
        c = (await b52.start(b52.account())).$1;
        await c.openAct3();
      });
      await tester.pumpWidget(MaterialApp(
          home: Act3BattleScreen(
              controller: c, placeId: 'baldrin_ashplain', tickInterval: const Duration(milliseconds: 400))));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      // 그림(768×1024)이 칸 안에 바닥 맞춰 들어갈 때 머리 꼭대기
      double headTop(Rect box, double figureTop) {
        final ih = box.height < box.width / 0.75 ? box.height : box.width / 0.75;
        return box.bottom - ih * (1 - figureTop / 1024);
      }
      final hero = tester.getRect(find.byKey(const Key('sceneHero')));
      final allies = find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('sceneAlly_'));
      expect(allies, findsWidgets);
      for (final e in allies.evaluate()) {
        final r = tester.getRect(find.byWidget(e.widget));
        expect(hero.left, greaterThan(r.left));
        // 각성자 서기 그림은 위 182/1024 가 비어 있음. 동료는 640×640 칸(위 약 110/640 이 비어 있음, 묶음 73b)
        final allyTop = r.bottom - r.height * (1 - 110 / 640);
        expect(headTop(hero, 182), lessThan(allyTop));
        // 동료 얼굴·몸통을 가리지 않게: 각성자 몸(칸 왼쪽 17%부터)이 동료 칸 가운데보다 오른쪽
        expect(hero.left + hero.width * 0.17, greaterThan(r.center.dx));
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
