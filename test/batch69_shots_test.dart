// 묶음 69 (build/screenshots/b69_*)
// 작은 iPhone(SE) · 큰 iPhone · Android

import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/act5_state.dart';
import 'package:isekai_reality/core/models/pet_state.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/features/act5/erbard_screens.dart';
import 'package:isekai_reality/features/bulssi/bulssi_bubble.dart';
import 'package:isekai_reality/features/bulssi/bulssi_mood.dart';
import 'package:isekai_reality/features/codex/codex_screen.dart';
import 'package:isekai_reality/features/map/map_screen.dart';
import 'package:isekai_reality/features/pets/farewell_screen.dart';
import 'package:isekai_reality/features/town/bag_tab.dart';
import 'package:isekai_reality/features/town/inn_screen.dart';
import 'package:isekai_reality/features/town/shop_screen.dart';
import 'package:isekai_reality/features/smithy/smithy_screen.dart';
import 'package:isekai_reality/features/village/board_screen.dart';
import 'package:isekai_reality/features/village/shelter_screen.dart';
import 'package:isekai_reality/features/village/village_screen.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/theme/ornaments.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'batch52_test.dart' as b52;
import 'batch56_test.dart' as b56;
import 'batch60_test.dart' as b60;
import 'support/npc_seed.dart';
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
  File('build/screenshots/b69_$name.png')
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


const _ch2 = Act5State(opened: true, chapter: 2, seen: {'e1a', 'e1b', 'e1c'}, ticketAt: -60000);

Future<void> _tapShot(WidgetTester tester, Key k, String name) async {
  await tester.tap(find.byKey(k).first);
  await _settle(tester, 3);
  await _shot(tester, name);
}

void main() {
  setUpAll(_loadFonts);
  setUp(() => b56.now = b52.t0);

  for (final d in _devices) {
    final n = d.$1;

    testWidgets('b69 $n: 공성전 닫힘 「곧 열려요」', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async {
        final (cc, a) = await b60.act5(guild: true, state: _ch2);
        c = cc;
        a.siegeOpen = false;
        await c.refreshErbard();
      });
      await _page(tester, ErbardScreen(key: ObjectKey('e$n'), controller: c));
      await _shot(tester, '${n}_01_에르바르드_곧열려요');
      await _page(tester, Scaffold(body: Builder(builder: (ctx) => Center(child: TextButton(onPressed: () => showEstateSheet(ctx, c, ErbardRules.estate('sol_lily')!), child: const Text('열기'))))));
      await tester.tap(find.text('열기'));
      await _settle(tester, 6);
      await _shot(tester, '${n}_02_영지_곧열려요');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('b69 $n: 레벨 단계 지도 몬스터 Lv.5 · 15 · 25 · 35 · 50 (낮 · 밤)', (tester) async {
      _device(tester, d);
      // 앱처럼: 그림이 없는 Lv.50 몬스터는 4단계로 (그림이 오면 그대로)
      final manifest = await tester.runAsync(() => AssetManifest.loadFromAssetBundle(rootBundle));
      Monsters.knownAssets = manifest!.listAssets().toSet();
      addTearDown(() => Monsters.knownAssets = null);
      var k = 3;
      for (final (lv, h) in [(5, 12), (15, 12), (25, 12), (35, 12), (50, 12), (35, 22)]) {
        late AppController c;
        await tester.runAsync(() async => c = await startNpc(level: lv, clock: () => DateTime(2026, 11, 20, h)));
        await _page(tester, Scaffold(body: MapScreen(key: ObjectKey('m$n$lv$h'), controller: c)));
        await _settle(tester, 4);
        await _shot(tester, '${n}_${(k++).toString().padLeft(2, '0')}_지도_Lv$lv${h >= 19 ? '_밤' : ''}');
        await tester.pumpWidget(const SizedBox());
      }
      late AppController c;
      await tester.runAsync(() async => c = await startNpc(level: 50));
      await _page(tester, Scaffold(body: NightBackground(child: CodexScreen(purifiedMonsters: {MonsterId.goblinRaider, MonsterId.orcMerc, MonsterId.ogre, ...c.purifiedEver}, huntCounts: const {}))));
      await tester.scrollUntilVisible(find.byKey(const Key('codexGroup_필드')), 300, scrollable: find.byType(Scrollable).first);
      await _settle(tester, 2);
      await _shot(tester, '${n}_09_도감_필드');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('b69 $n: 가방 · 부화장 (품는 중 · 다 됨 · 빈 둥지)', (tester) async {
      _device(tester, d);
      late AppController c;
      final now = vt0;
      await tester.runAsync(() async => c = await startVillage(11, farewell: true, more: {
            'buildings': {'shelter': 3},
            'pets': PetState(
              pets: [Pet(uid: 'p1', species: PetSpecies.owl, name: '부엉', bornAt: DateTime(2026, 11, 1))],
              companion: 'p1',
              firstPet: 'p1',
              firstSpiritName: '불씨',
              farewellAt: DateTime(2026, 11, 2),
              eggs: [
                PetEgg(id: 'e1', source: 'field', incubatedAt: now.subtract(const Duration(hours: 7))),
                PetEgg(id: 'e2', source: 'field', incubatedAt: now.subtract(const Duration(hours: 13))),
                const PetEgg(id: 'e3', source: 'field'),
              ],
              nextId: 4,
            ).toJson(),
          }));
      await _page(tester, Scaffold(body: NightBackground(child: BagTab(key: ObjectKey('b$n'), controller: c))));
      await _shot(tester, '${n}_10_가방_품는알');
      await _page(tester, ShelterScreen(key: ObjectKey('s$n'), controller: c));
      await _shot(tester, '${n}_11_부화장');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('b69 $n: Lv.11 마을 (안개 없음 · 공사 중 이름표 없음) · 정령 얼굴 누르면', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async => c = await startVillage(11, village: {'seen': ['intro']}));
      await _page(tester, Scaffold(body: VillageScreen(key: ObjectKey('v$n'), controller: c)));
      await _settle(tester, 4);
      await _shot(tester, '${n}_12_마을_Lv11');
      await _tapShot(tester, const Key('spiritBadge'), '${n}_13_마을_정령누르면');
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async => c = await startVillage(5, village: {'seen': ['intro']}));
      await _page(tester, Scaffold(body: VillageScreen(key: ObjectKey('v5$n'), controller: c)));
      await _settle(tester, 4);
      await _shot(tester, '${n}_14_마을_Lv5_공사중');
      await tester.tap(find.byKey(const Key('locked_alchemy')).first, warnIfMissed: false);
      await _settle(tester, 2);
      await _shot(tester, '${n}_15_공사중_누르면');
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('b69 $n: 정령 이별 장면 줄마다', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async => c = await startVillage(11));
      await _page(tester, FarewellScreen(key: ObjectKey('f$n'), controller: c));
      for (var i = 0; i < 6; i++) {
        // 「내 빛을 조금 남겨 둘게」는 빛 맥박 · 알갱이가 흐르는 중에
        await tester.pump(Duration(milliseconds: i == 4 ? 900 : 4000));
        await _settle(tester, i == 4 ? 1 : 2);
        await _shot(tester, '${n}_${(16 + i).toString()}_이별_${i + 1}');
        if (i < 5) {
          await tester.tapAt(const Offset(200, 200));
          await _settle(tester, 2);
        }
      }
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('b69 $n: 건물 위쪽 (대사 닫힘 / 열림, 부탁 줄 없음) · 게시판 마을 사람 부탁', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async => c = await startNpc(level: 14, npc: {
            'v': 1,
            'points': {'mina': 30, 'marta': 30, 'dorgun': 30},
            'shown': {'mina': NpcRules.stageOf(30).index, 'marta': NpcRules.stageOf(30).index, 'dorgun': NpcRules.stageOf(30).index},
            'active': {
              'marta': {'i': 0, 'day': '2026-11-16', 'base': <String, int>{}, 'steps': 0},
            },
          }));
      for (final (k, w) in [
        ('inn', InnScreen(key: ObjectKey('i$n'), controller: c)),
        ('shop', ShopScreen(key: ObjectKey('sh$n'), controller: c)),
        ('smithy', SmithyScreen(key: ObjectKey('sm$n'), controller: c)),
      ]) {
        await _page(tester, w);
        await _settle(tester, 3);
        await _shot(tester, '${n}_22_${k}_위쪽');
        final face = find.byWidgetPredicate((x) => x.key is ValueKey<String> && '${(x.key as ValueKey<String>).value}'.startsWith('npcFace_'));
        if (face.evaluate().isNotEmpty) {
          // 열려 있으면 닫았다가 다시 (다음 대사)
          if (find.byWidgetPredicate((x) => x.key is ValueKey<String> && '${(x.key as ValueKey<String>).value}'.startsWith('npcBubble_')).evaluate().isNotEmpty) {
            await tester.tap(face.first);
            await _settle(tester, 2);
            await _shot(tester, '${n}_22_${k}_닫힘');
          }
          await tester.tap(face.first);
          await _settle(tester, 2);
          await _shot(tester, '${n}_22_${k}_누르면');
        }
        await tester.pumpWidget(const SizedBox());
      }
      await _page(tester, BoardScreen(key: ObjectKey('bd$n'), controller: c));
      await tester.scrollUntilVisible(find.byKey(const Key('boardNpcAsks')), 300, scrollable: find.byType(Scrollable).first);
      await _settle(tester, 3);
      await _shot(tester, '${n}_23_게시판_마을사람부탁');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('b69 $n: 안내 말풍선 (꼬리가 캐릭터 얼굴) · 가방 · 지도 · 상태', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async => c = await startVillage(11, farewell: true));
      await _page(tester, Scaffold(body: NightBackground(child: BagTab(key: ObjectKey('bg$n'), controller: c))));
      await _tapShot(tester, const Key('spiritBadge'), '${n}_24_가방_정령누르면');
      await _page(tester, Scaffold(body: MapScreen(key: ObjectKey('mp$n'), controller: c)));
      await _settle(tester, 3);
      await _tapShot(tester, const Key('spiritBadge'), '${n}_25_지도_정령누르면');
      // 큰 안내 말풍선 (기능 둘러보기와 같은 것)
      await _page(
          tester,
          Scaffold(
              body: NightBackground(
                  child: BulssiScope(
                      mood: BulssiMood.gold,
                      kind: SpiritKind.fire,
                      spiritName: '부엉',
                      petSpecies: PetSpecies.owl,
                      child: const Padding(
                        padding: EdgeInsets.fromLTRB(14, 200, 14, 0),
                        child: Column(children: [
                          BulssiBubble(line: '펫 쉼터가 열렸어! 알은 둥지에서, 지친 펫은 여기서 쉬어.', size: 52),
                          SizedBox(height: 30),
                          BulssiBubble(line: '여기는 짧아.', size: 52),
                        ]),
                      )))));
      await _shot(tester, '${n}_26_큰안내_말풍선');
      await tester.pumpWidget(const SizedBox());
    });
  }
}
