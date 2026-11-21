// 묶음 66 (build/screenshots/b66_*)
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
import 'package:isekai_reality/core/geo/geo.dart';
import 'package:isekai_reality/core/models/act5_state.dart';
import 'package:isekai_reality/core/models/armory.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/models/garden_state.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/act5/erbard_screens.dart';
import 'package:isekai_reality/features/act5/estate_manage_screen.dart';
import 'package:isekai_reality/features/battle/field_battle_screen.dart';
import 'package:isekai_reality/features/level_up/level_up_dialog.dart';
import 'package:isekai_reality/features/smithy/smithy_screen.dart';
import 'package:isekai_reality/features/status/status_screen.dart';
import 'package:isekai_reality/features/village/board_screen.dart';
import 'package:isekai_reality/theme/ornaments.dart';
import 'package:isekai_reality/features/village/garden_screen.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'batch52_test.dart' as b52;
import 'batch56_test.dart' as b56;
import 'batch60_test.dart' as b60;
import 'support/fake_arca.dart';
import 'support/npc_seed.dart';


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
  File('build/screenshots/b66_$name.png')
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


const _ch3 = Act5State(opened: true, chapter: 3, seen: {'e1a', 'e1b', 'e1c', 'e2a', 'e2b'}, ticketAt: -60000, pioneered: true, ch3Siege: 0);

Future<AppController> _gear() async {
  final c = AppController(
    store: InMemoryRecordStore(
      profile: const PlayerProfile(name: '하루', lastSeenLevel: 99),
      history: [
        DailyRecord(date: DateTime(2026, 11, 19), gains: {
          Wallet.gold: 50000, Wallet.manaStone: 300, Wallet.exp: LevelRules.totalExpToReach(30),
          'fireStone': 1, 'metalOre': 3, 'lightRelic': 2, 'glowFireCore': 3,
        }),
      ],
      json: {
        'armory': const Armory(
          items: [
            EquipItem(uid: 'w', base: EquipBase.dagger, grade: EquipGrade.blue, enhance: 7, element: Element.fire, elementLevel: 1),
            EquipItem(uid: 'b', base: EquipBase.armor, grade: EquipGrade.blue, enhance: 8),
          ],
          equipped: {EquipSlot.weapon: 'w', EquipSlot.body: 'b'},
          crafts: 5,
          nextId: 10,
        ).toJson(),
        'harvest': {'granted': true},
      },
    ),
    health: FakeHealthSource(stepsByDay: const {}),
    clock: () => DateTime(2026, 11, 20, 10),
  )..mailSources = const [];
  await c.init();
  return c;
}

void main() {
  setUpAll(_loadFonts);
  setUp(() => b56.now = b52.t0);

  for (final d in _devices) {
    final n = d.$1;

    testWidgets('b66 $n: 힘 고르기 · 선봉장 소식 · 돕는 영지', (tester) async {
      _device(tester, d);
      late AppController c;
      late FakeArca a;
      await tester.runAsync(() async {
        (c, a) = await b60.act5(guild: true, state: _ch3);
        a.siegeActive = true;
        a.siegeOwners['sol_lily'] = {'gid': 'mine', 'name': '새벽걸음', 'emblem': 2, 'color': 3};
        a.siegeOwners['sol_bell'] = {'gid': 'mine', 'name': '새벽걸음', 'emblem': 2, 'color': 3};
        a.siegeOwners['dor_deep'] = {'gid': 'other', 'name': '노을', 'emblem': 1, 'color': 1};
        a.siegeDefense['sol_lily'] = 2;
        a.rallyEstate = 'dor_deep';
        a.gauge = {'progress': 0.35, 'full': 2, 'rams': 0, 'ramMax': 2, 'repairs': <String>[], 'power': 2};
        final t = DateTime.utc(2026, 11, 28, 3).millisecondsSinceEpoch;
        a.siegeNews.addAll([
          {'at': t, 'text': '길드 걸음 게이지가 가득 찼어요. 공성 망치나 성벽 보수에 쓸 수 있어요'},
          {'at': t, 'text': '제0회 공성전에서 자리를 가장 많이 깬 사람 · 별하님'},
          {'at': t, 'text': '하루님이 제0회 공성전 선봉장이 됐어요'},
        ]);
        b56.now = DateTime(2026, 11, 28, 10);
        await c.refreshErbard();
      });
      await _page(tester, ErbardScreen(key: ObjectKey('m$n'), controller: c));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('erbardWarBoard')));
      await _settle(tester);
      await _shot(tester, '${n}_01_전황판_힘');
      await tester.tap(find.byKey(const Key('powerRam')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await _settle(tester);
      await _shot(tester, '${n}_02_망치씀');
      Navigator.of(tester.element(find.byKey(const Key('warBoard')))).pop();
      await _settle(tester);
      await tester.runAsync(() async {
        a.siegeActive = false;
        b56.now = DateTime(2026, 12, 1, 10);
        await c.refreshErbard();
        await c.refreshEstateDev();
      });
      await _page(tester, EstateManageScreen(key: ObjectKey('e$n'), controller: c, estate: ErbardRules.estate('sol_bell')!));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await _settle(tester);
      await tester.scrollUntilVisible(find.byKey(const Key('estateRequest')), 300, scrollable: find.byType(Scrollable).first);
      Scrollable.ensureVisible(tester.element(find.byKey(const Key('estateRequest'))), alignment: 0.1);
      await _settle(tester);
      await _shot(tester, '${n}_03_돕는영지');
    });

    testWidgets('b66 $n: 강화 +8 재료 줄 · 속성 강화 특산물 더 넣기', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async => c = await _gear());
      await _page(tester, SmithyScreen(key: ObjectKey('s$n'), controller: c));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await _settle(tester);
      final tab = find.text('강화');
      if (tab.evaluate().isNotEmpty) await tester.tap(tab.first);
      await _settle(tester);
      if (find.byKey(const Key('enhanceSpecial_w')).evaluate().isNotEmpty) {
        Scrollable.ensureVisible(tester.element(find.byKey(const Key('enhanceSpecial_w'))), alignment: 0.3);
      }
      await _settle(tester);
      await _shot(tester, '${n}_04_강화_특산물');
      final el = find.text('속성');
      if (el.evaluate().isNotEmpty) await tester.tap(el.first);
      await _settle(tester);
      if (find.byKey(const Key('smith_extra_w')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const Key('smith_extra_w')));
        await _settle(tester);
        Scrollable.ensureVisible(tester.element(find.byKey(const Key('smith_extra_w'))), alignment: 0.4);
        await _settle(tester);
      }
      await _shot(tester, '${n}_05_속성강화_특산물');
    });

    for (final lv in [1, 10, 21, 40]) {
      testWidgets('b66 $n: 사냥 결과 경험치 Lv.$lv', (tester) async {
        _device(tester, d);
        late AppController c;
        await tester.runAsync(() async => c = await startNpc(level: lv, clock: () => DateTime(2026, 11, 20, 14)));
        const spawn = FieldSpawn(id: '2026-11-20@3#t', monster: MonsterId.ashSlime, point: GeoPoint(37.3219, 126.8309));
        await _page(tester, FieldBattleScreen(key: ObjectKey('f$n$lv'), controller: c, spawn: spawn, tickInterval: const Duration(milliseconds: 100)));
        for (var i = 0; i < 80 && find.text('사냥 성공!').evaluate().isEmpty && find.text('이번엔 물러났어요').evaluate().isEmpty; i++) {
          await tester.pump(const Duration(milliseconds: 300));
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        }
        await _settle(tester, 10);
        await _shot(tester, '${n}_06_사냥결과_Lv$lv');
      });
    }

    testWidgets('b66 $n: 약초밭 4종 (심은 직후 · 절반 · 다 자람)', (tester) async {
      _device(tester, d);
      late AppController c;
      final now = DateTime(2026, 11, 20, 14);
      int ago(int min) => now.subtract(Duration(minutes: min)).millisecondsSinceEpoch;
      await tester.runAsync(() async => c = await startNpc(
            level: 17,
            clock: () => now,
            json: {
              'garden': GardenState(plots: {
                0: GardenPlot(seed: 'herbSeed', day: '2026-11-20', steps: 0, at: ago(1)),
                1: GardenPlot(seed: 'flowerSeed', day: '2026-11-20', steps: 0, at: ago(250)),
                2: GardenPlot(seed: 'sporeSeed', day: '2026-11-20', steps: 0, at: ago(500)),
                3: GardenPlot(seed: 'glowSeed', day: '2026-11-20', steps: 0, at: ago(760)),
              }).toJson(),
              'npc': {'done': {'popo': 3}, 'points': {'popo': 40}},
            },
          ));
      await _page(tester, GardenScreen(key: ObjectKey('g$n'), controller: c));
      await _shot(tester, '${n}_07_약초밭');
    });

    testWidgets('b66 $n: 게시판 마을 사람 부탁 · 상태 화면 위 줄 · 레벨업 최대 기력', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async => c = await startNpc(level: 12, npc: {
            'points': {'gil': 10, 'popo': 10},
            'active': {
              'gil': {'i': 0, 'day': '2026-11-16', 'base': <String, int>{}, 'steps': 0},
              'popo': {'i': 0, 'day': '2026-11-16', 'base': <String, int>{}, 'steps': 0},
            },
          }));
      await _page(tester, BoardScreen(key: ObjectKey('b$n'), controller: c));
      if (find.byKey(const Key('boardNpcAsks')).evaluate().isNotEmpty) {
        await tester.scrollUntilVisible(find.byKey(const Key('boardNpcAsks')), 300, scrollable: find.byType(Scrollable).first);
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
      }
      await _settle(tester);
      await _shot(tester, '${n}_08_게시판_부탁');
      Widget status() => Scaffold(
            body: Stack(children: [
              NightBackground(
                child: StatusScreen(
                  player: c.player,
                  hp: c.hp,
                  mp: c.mp,
                  maxHp: c.maxHp,
                  mpMax: c.mpMax,
                  armory: c.armory,
                  look: c.profile.look,
                  now: c.now,
                  requestPanel: const SizedBox(height: 600),
                ),
              ),
              Positioned(
                top: MediaQuery.paddingOf(tester.element(find.byType(Scaffold).first)).top + 6,
                right: 12,
                child: const CircleAvatar(radius: 22, child: Icon(Icons.settings)),
              ),
            ]),
          );
      await _page(tester, status());
      await _shot(tester, '${n}_09_상태_내리기전');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await _settle(tester);
      await _shot(tester, '${n}_10_상태_내린뒤');
      await _page(tester, const Scaffold(body: Center(child: LevelUpDialog(from: 19, to: 20))));
      await _shot(tester, '${n}_11_레벨업_기력');
    });
  }
}
