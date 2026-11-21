// 묶음 78 (build/screenshots/b78_*) — 큰 iPhone · SE

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/storage/record_store.dart' show HeroLook, SpiritKind;
import 'package:isekai_reality/features/battle/battle_view.dart';
import 'package:isekai_reality/features/battle/hero_rig.dart' show WeaponKind;
import 'package:isekai_reality/features/bulssi/bulssi_mood.dart';
import 'package:isekai_reality/features/status/status_screen.dart';
import 'package:isekai_reality/features/jobs/guild_screen.dart';
import 'package:isekai_reality/features/jobs/skill_screen.dart';
import 'package:isekai_reality/theme/ornaments.dart';
import 'package:isekai_reality/theme/top_notice.dart';
import 'package:isekai_reality/core/models/armory.dart';
import 'package:isekai_reality/features/codex/codex_screen.dart';
import 'package:isekai_reality/features/map/map_screen.dart';
import 'package:isekai_reality/features/profile/title_celebration.dart';
import 'package:isekai_reality/features/smithy/equipment_view.dart';
import 'package:isekai_reality/features/status/status_cards.dart';
import 'package:isekai_reality/features/tutorial/feature_tour.dart';
import 'package:isekai_reality/features/village/board_screen.dart';
import 'package:isekai_reality/features/village/village_screen.dart';
import 'support/npc_seed.dart';
import 'package:isekai_reality/theme/app_colors.dart';

import 'batch52_test.dart' as b52;
import 'batch56_test.dart' as b56;
import 'support/village_seed.dart';

final _root = GlobalKey();

Future<void> _loadFonts() async {
  // 묶음 71: 글꼴을 정하지 않은 글자(버튼 등)는 시험 기본 글꼴(FlutterTest)로 그려져 □로 나옴 —
  // 기기처럼 한글이 보이게 그 이름에도 한글 글꼴을 넣는다
  for (final family in ['Roboto', 'FlutterTest']) {
    final korean = FontLoader(family);
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
  }
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
  File('build/screenshots/b78_$name.png')
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
        // 기기에선 글꼴을 정하지 않은 글자가 휴대폰 기본 글꼴(한글 있음)로 나옴 — 시험에서도 한글 글꼴로
        theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Roboto'),
        builder: (context, child) => TopNoticeHost(child: child!),
        home: home),
  ));
  await _settle(tester);
}

Future<bool> _until(WidgetTester tester, Finder f, {int max = 150}) async {
  for (var i = 0; i < max; i++) {
    if (f.evaluate().isNotEmpty) return true;
    await tester.pump(const Duration(milliseconds: 20));
  }
  return false;
}

Map<String, dynamic> _jobs(String main, {List<String> subs = const []}) =>
    {'awakened': true, 'v57': true, 'main': main, 'owned': [main, ...subs], 'subs': subs};

Widget _battle(Battle b, {String? job, HeroLook look = HeroLook.male, WeaponKind? weapon, Duration tick = const Duration(milliseconds: 900)}) =>
    BulssiScope(
      key: UniqueKey(),
      mood: BulssiMood.gold,
      spiritName: '불씨',
      kind: SpiritKind.fire,
      child: Scaffold(
          body: SafeArea(
              child: Column(children: [
        Expanded(
            child: BattleView(
                battle: b,
                fit: true,
                look: look,
                heroJob: job,
                weapon: weapon,
                onFinished: () {},
                tickInterval: tick)),
      ]))),
    );

Battle _b({MonsterId m = MonsterId.ashSlime, int hp = 1000000, bool boss = false, bool skills = false}) => Battle(
      playerMaxHp: 100000,
      playerAttack: 30,
      floors: [Foe(monster: m, maxHp: hp, attack: boss ? 20 : 1)],
      rng: math.Random(3),
      telegraphs: boss,
      heroSkills: skills,
    );



void main() {
  setUpAll(_loadFonts);
  setUp(() => b56.now = b52.t0);

  for (final d in [_devices[1], _devices[0]]) {
    final n = d.$1;

    testWidgets('b78 $n: 1 스킬 전투 칸', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async => c = await startVillage(18, farewell: true, more: {
            'jobs': {..._jobs('warrior'), 'learned': {'cleave': 1, 'ironWall': 2}},
            'mastery': {'big': {'combat': 150.0, 'walk': 50.0}},
          }));
      await _page(tester, SkillScreen(key: ObjectKey('s1$n'), controller: c));
      await _shot(tester, '${n}_01_전투칸_처음');
      await tester.tap(find.byKey(const Key('skillSlot_1')));
      await _settle(tester, 2);
      await _shot(tester, '${n}_02_전투칸_칸2고름');
      final pick = find.byKey(const Key('battlePick_mastery:combat'));
      if (pick.evaluate().isNotEmpty) {
        await tester.tap(pick);
        await _settle(tester, 2);
        await tester.ensureVisible(find.byKey(const Key('battlePut')));
        await tester.tap(find.byKey(const Key('battlePut')));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
        await _settle(tester, 3);
        await _shot(tester, '${n}_03_전투칸_넣음한줄');
      }
      await tester.tap(find.byKey(const Key('battleFixed_strike')));
      await _settle(tester, 2);
      await _shot(tester, '${n}_05_전투칸_강타누름_늘있음');
      final lockedKey = find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('battlePick_job:') );
      for (final e in lockedKey.evaluate()) {
        final k = ((e.widget.key) as ValueKey<String>).value;
        final s = JobRules.parseSkill(k.substring('battlePick_job:'.length));
        if (s != null && c.skillLevel(s) == 0) {
          await tester.tap(find.byKey(Key(k)));
          await _settle(tester, 2);
          await _shot(tester, '${n}_06_전투칸_안배운스킬_포인트로열기');
          break;
        }
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('b78 $n: 2 스킬 고유 · 숙련', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async => c = await startVillage(18, farewell: true, more: {
            'jobs': {..._jobs('warrior'), 'learned': {'cleave': 3, 'ironWall': 1}},
            'mastery': {'big': {'combat': 150.0, 'walk': 50.0, 'smith': 320.0, 'harvest': 12.0}},
          }));
      await _page(tester, SkillScreen(key: ObjectKey('s2$n'), controller: c, tab: 1));
      await _shot(tester, '${n}_10_고유_포인트있음');
      final raise = find.byKey(const Key('skillRaise_ironWall'));
      if (raise.evaluate().isNotEmpty) {
        await tester.ensureVisible(raise);
        await tester.tap(raise);
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
        await _settle(tester, 3);
        await _shot(tester, '${n}_11_고유_강화뒤한줄');
      }
      await tester.ensureVisible(find.byKey(const Key('jobSkillTile_cleave')));
      await tester.tap(find.byKey(const Key('jobSkillTile_cleave')));
      await _settle(tester, 3);
      await _shot(tester, '${n}_12_고유_펼침_MAX');
      await _page(tester, SkillScreen(key: ObjectKey('s3$n'), controller: c, tab: 2));
      await _shot(tester, '${n}_20_숙련_여럿오름');
      await tester.ensureVisible(find.byKey(const Key('masteryRow_combat')));
      await _settle(tester, 1);
      await tester.tap(find.byKey(const Key('masteryRow_combat')));
      await _settle(tester, 2);
      await tester.ensureVisible(find.byKey(const Key('masteryDetail_combat')));
      await _settle(tester, 2);
      await _shot(tester, '${n}_21_숙련_숙련된펼침');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  }
}
