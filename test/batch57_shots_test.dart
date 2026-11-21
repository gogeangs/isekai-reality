// 묶음 57: 동의 · 직업 · 스킬 · 지역 2~5 · 전설 펫 · 3막 끝 미리보기 (build/screenshots/b57_*)
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
import 'package:isekai_reality/core/models/pet_state.dart';
import 'package:isekai_reality/features/act3/act3_screen.dart';
import 'package:isekai_reality/features/act3/region_screens.dart';
import 'package:isekai_reality/features/jobs/guild_screen.dart';
import 'package:isekai_reality/features/jobs/skill_screen.dart';
import 'package:isekai_reality/features/legal/consent_screen.dart';
import 'package:isekai_reality/features/pets/farewell_screen.dart' show LegendReveal;
import 'package:isekai_reality/features/pets/pet_art.dart';
import 'package:isekai_reality/theme/app_colors.dart';
import 'package:isekai_reality/theme/ornaments.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'batch52_test.dart' as b52;
import 'batch56_test.dart' as b56;
import 'batch57_regions_test.dart' as r57;

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
  File('build/screenshots/b57_$name.png')
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
    final big = n == '큰iPhone';

    testWidgets('b57 $n: 동의 · 직업 · 스킬', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async {
        c = (await b56.start(login: false)).$1;
        await c.store.saveJson('jobs', {
          'awakened': true,
          'owned': ['blacksmith', 'archer', 'warrior'],
          'main': 'warrior',
          'subs': ['blacksmith'],
          'v57': true,
          'v31': true,
          'pageOpen': true,
        });
        c = (await b56.start(login: false, store: c.store as dynamic)).$1;
      });
      c.consentGate = true;
      await _page(tester, ConsentScreen(key: ObjectKey('c$n'), controller: c));
      await _shot(tester, '${n}_01_동의');
      if (!big) return;
      await _page(tester, GuildScreen(key: ObjectKey('g$n'), controller: c));
      await _shot(tester, '${n}_02_조합_직업');
      // 묶음 77 #356: 새 조합 화면 (격자에서 고르고 아래 판 버튼)
      final change = find.byKey(const Key('guildJob_archer'));
      await tester.ensureVisible(change);
      await _settle(tester, 2);
      await tester.tap(change, warnIfMissed: true);
      await _settle(tester);
      if (find.byKey(const Key('jobAsMain')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const Key('jobAsMain')));
        await _settle(tester);
      }
      await _shot(tester, '${n}_03_직업_바꾸기_미리보기');
      await _page(tester, JobAwakenScreen(key: ObjectKey('a$n'), controller: c));
      await _shot(tester, '${n}_04_직업_고르기');
      await _page(tester, SkillScreen(key: ObjectKey('s$n'), controller: c));
      await _shot(tester, '${n}_05_스킬');
    });

    testWidgets('b57 $n: 3막 지역 2~5 · 3막 끝 · 전설 펫', (tester) async {
      _device(tester, d);
      for (final (i, r) in RegionRules.all.indexed) {
        if (!big && i > 0) break;
        late AppController c;
        await tester.runAsync(() async {
          c = await r57.inRegion(r, more: {'${r.prefix}:arrive', '${r.prefix}:first'});
        });
        await _page(tester, Act3Screen(key: ObjectKey('m$n$i'), controller: c));
        await _shot(tester, '${n}_1${i}_${r.prefix}_지도');
        await _page(tester, RegionTownScreen(key: ObjectKey('t$n$i'), controller: c, region: r));
        await _shot(tester, '${n}_2${i}_${r.prefix}_마을');
      }
      if (!big) return;
      late AppController c;
      await tester.runAsync(() async {
        c = await r57.inRegion(RegionRules.aurel, more: {'aurel:arrive', 'aurel:lamp', 'aurel:choice:share'});
      });
      await _page(tester, Act3EndScreen(key: const ObjectKey('end'), controller: c));
      await _shot(tester, '${n}_30_3막끝_다섯등불');
      for (var i = 0; i < RegionRules.endScene.length; i++) {
        await tester.tapAt(const Offset(200, 400));
        await _settle(tester, 3);
      }
      await _shot(tester, '${n}_31_3막끝_테오와마르타');
      final pet = Pet(uid: 'p1', species: PetSpecies.dragon, name: '이그니스', bornAt: b52.t0);
      await _page(
          tester,
          Scaffold(
            backgroundColor: AppColors.night,
            body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                LegendReveal(child: PetArt.of(pet, size: 150)),
                const SizedBox(height: 8),
                Text('${pet.info.name} 이그니스가 태어났어요!',
                    style: AppText.title(19, color: AppColors.goldBright)),
                Text('전설 속 펫이 깨어났어요!', style: AppText.title(16, color: AppColors.goldBright)),
              ]),
            ),
          ));
      await _shot(tester, '${n}_40_전설펫');
    });
  }
}
