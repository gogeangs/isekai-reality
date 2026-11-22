// 묶음 81 (build/screenshots/b81_*) — 큰 iPhone · SE

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/geo/geo.dart';
import 'package:isekai_reality/core/models/armory.dart';
import 'package:isekai_reality/core/models/pet_state.dart';
import 'package:isekai_reality/core/models/vitals.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/storage/record_store.dart' show HeroLook;
import 'package:isekai_reality/features/act2/ash_battle_screen.dart' show openRift;
import 'package:isekai_reality/features/awakening/awakening_screen.dart';
import 'package:isekai_reality/features/highland/highland_screen.dart' show HighlandSceneScreen;
import 'package:isekai_reality/features/jobs/skill_screen.dart';
import 'package:isekai_reality/features/map/expedition_sheet.dart';
import 'package:isekai_reality/features/map/trip_sheet.dart';
import 'package:isekai_reality/features/pets/pet_screen.dart';
import 'package:isekai_reality/features/status/buff_chips.dart';
import 'package:isekai_reality/features/status/status_screen.dart';
import 'package:isekai_reality/features/town/bag_tab.dart';
import 'package:isekai_reality/features/town/inn_screen.dart';
import 'package:isekai_reality/features/village/npc_header.dart';
import 'package:isekai_reality/features/village/tavern_screen.dart' show MeetScreen;
import 'package:isekai_reality/theme/top_notice.dart';

import 'batch52_test.dart' as b52;
import 'batch56_test.dart' as b56;
import 'support/village_seed.dart';

final _root = GlobalKey();
const _home = GeoPoint(37.3219, 126.8309);

Future<void> _loadFonts() async {
  for (final family in ['Roboto', 'FlutterTest']) {
    final korean = FontLoader(family);
    for (final f in ['NanumGothic-Regular', 'NanumGothic-Bold', 'NanumGothic-ExtraBold']) {
      korean.addFont(File('test/fonts/$f.ttf').readAsBytes().then((b) => ByteData.view(b.buffer)));
    }
    await korean.load();
  }
  final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
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
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
    await tester.pump();
  }
  final boundary = tester.renderObject(find.byKey(_root)) as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.5);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  File('build/screenshots/b81_$name.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!);
}

const _devices = [
  ('SE', Size(750, 1334), 2.0, 40.0, 0.0),
  ('큰iPhone', Size(1290, 2796), 3.0, 177.0, 102.0),
];

void _device(WidgetTester tester, (String, Size, double, double, double) d) {
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
        key: UniqueKey(),
        debugShowCheckedModeBanner: false,
        theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Roboto'),
        builder: (context, child) => TopNoticeHost(child: child!),
        home: home),
  ));
  await _settle(tester);
}

Widget _opener(void Function(BuildContext) open) => Scaffold(
    body: Builder(
        builder: (ctx) => Center(
            child: TextButton(key: const Key('open'), onPressed: () => open(ctx), child: const Text('열기')))));

Pet _pet(String uid, PetSpecies s, String name) =>
    Pet(uid: uid, species: s, name: name, bornAt: DateTime(2026, 11, 1));

final _three = [
  _pet('p1', PetSpecies.owl, '부엉'),
  _pet('p2', PetSpecies.blackCat, '나비'),
  _pet('p3', PetSpecies.toad, '개굴'),
];

Map<String, dynamic> _pets(List<Pet> pets, {List<PetEgg> eggs = const [], Map<String, DateTime> tired = const {}}) => {
      'pets': PetState(
        pets: pets,
        companion: pets.first.uid,
        firstPet: pets.first.uid,
        firstSpiritName: '불씨',
        farewellAt: DateTime(2026, 11, 2),
        eggs: eggs,
        tired: tired,
      ).toJson(),
    };

Map<String, dynamic> _jobs(String main) =>
    {'awakened': true, 'v57': true, 'v31': true, 'main': main, 'owned': [main]};

Future<void> _openTap(WidgetTester tester, Widget opener) async {
  await _page(tester, opener);
  await tester.tap(find.byKey(const Key('open')));
  await _settle(tester, 5);
}

void main() {
  setUpAll(_loadFonts);
  setUp(() => b56.now = b52.t0);

  for (final d in [_devices[1], _devices[0]]) {
    final n = d.$1;

    testWidgets('b81 $n: 1 펫', (tester) async {
      _device(tester, d);
      late AppController c;
      late AppController four;
      const egg = PetEgg(id: 'e1', source: 'field', grade: EggGrade.rare);
      await tester.runAsync(() async {
        c = await startVillage(18, farewell: true, more: _pets(_three, eggs: [egg]));
        four = await startVillage(18, farewell: true, more: _pets([..._three, _pet('p4', PetSpecies.crow, '까망')]));
      });
      await _page(tester, PetScreen(controller: c));
      await _shot(tester, '${n}_01_펫화면_3of3');
      await _openTap(tester, _opener((ctx) => showBagEntry(ctx, c, const EggEntry(egg))));
      await _shot(tester, '${n}_02_펫가득_알창');
      await _page(tester, PetScreen(controller: four));
      await _shot(tester, '${n}_03_4마리계정_4of3');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('b81 $n: 2 원정 창 얼굴 칸', (tester) async {
      _device(tester, d);
      final now = DateTime(2026, 11, 16, 10);
      late AppController c;
      late AppController all;
      // 가까운 몬스터부터 (기력이 모자라지 않게)
      List<FieldSpawn> near(AppController x) =>
          [...x.todaySpawns]..sort((a, b) => _home.distanceTo(a.point).compareTo(_home.distanceTo(b.point)));
      await tester.runAsync(() async {
        c = await startVillage(16, farewell: true, clock: () => now, vitals: Vitals(mp: 999, mpAt: now),
            more: _pets(_three, tired: {'p3': now.add(const Duration(minutes: 40))}));
        await c.handleFix(const LocationFix(point: _home));
        await c.sendSpirit(near(c)[1], petUid: 'p2');
        all = await startVillage(16, farewell: true, clock: () => now, vitals: Vitals(mp: 999, mpAt: now),
            more: _pets(_three.take(2).toList()));
        await all.handleFix(const LocationFix(point: _home));
        await all.sendSpirit(near(all)[1], petUid: 'p1');
        await all.sendSpirit(near(all)[2], petUid: 'p2');
      });
      await _openTap(tester, _opener((ctx) => showSpawnSheet(ctx, c, near(c).first)));
      await _shot(tester, '${n}_10_원정창_얼굴칸_원정중_쉬는중');
      await _openTap(tester, _opener((ctx) => showSpawnSheet(ctx, all, near(all).first)));
      await _shot(tester, '${n}_11_원정창_모두원정중');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('b81 $n: 3 잿빛 틈 · 섬 원정', (tester) async {
      _device(tester, d);
      var now = DateTime(2026, 11, 16, 10);
      late AppController c;
      await tester.runAsync(() async {
        c = await startVillage(13, farewell: true, clock: () => now, more: _pets(_three));
        await c.handleFix(const LocationFix(point: _home));
      });
      await _openTap(tester, _opener((ctx) => openRift(ctx, c)));
      await _shot(tester, '${n}_20_잿빛틈_걸어서_원정');
      await tester.tap(find.byKey(const Key('tripSend')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await _settle(tester, 4);
      final trip = c.tripTo('rift')!;
      now = trip.arriveAt.add(const Duration(seconds: 1));
      await tester.runAsync(c.refreshVitals);
      await _page(tester, Builder(builder: (ctx) {
        return _opener((x) => showTopNotice(x, '${SpotTripOps.tripArrivedLine(trip)} 싸우러 가자', icon: Icons.pets_rounded));
      }));
      await tester.tap(find.byKey(const Key('open')));
      await _settle(tester, 2);
      await _shot(tester, '${n}_21_펫닿음_알림띠');
      await _openTap(tester, _opener((ctx) => openRift(ctx, c)));
      await _shot(tester, '${n}_22_잿빛틈_펫기다림_싸우러가기');
      // 섬: 지기 전에 못 닿음 (멀리 · 끝나기 직전)
      late AppController sky;
      var skyNow = DateTime(2026, 11, 16, 7, 50);
      await tester.runAsync(() async {
        sky = await startVillage(21, farewell: true, clock: () => skyNow, more: _pets(_three));
        await sky.handleFix(const LocationFix(point: _home));
      });
      if (sky.skyIsland != null) {
        skyNow = sky.skyIsland!.until.subtract(const Duration(minutes: 2));
        await _openTap(tester, _opener((ctx) => showTripSheet(ctx, sky,
            kind: 'sky', title: sky.skyIsland!.info.place, about: '하늘에 섬이 떠 있어요.',
            distanceM: sky.skyDistance, onEnter: () async {})));
        await _shot(tester, '${n}_23_섬_지기전에못닿음');
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('b81 $n: 4 여관', (tester) async {
      _device(tester, d);
      var now = DateTime(2026, 11, 16, 10);
      late AppController c;
      late AppController young;
      await tester.runAsync(() async {
        c = await startVillage(18, farewell: true, clock: () => now, more: {
          ..._pets(_three),
          'jobs': {..._jobs('mage'), 'mp': 4},
        }, vitals: Vitals(hp: 30, mp: 5, mpAt: now));
        c.watchAd = (_) async => true;
        await c.handleFix(const LocationFix(point: _home));
        young = await startVillage(8, clock: () => now, vitals: Vitals(hp: 20, mp: 3, mpAt: now));
        await c.restAtInn();
        await young.restAtInn();
      });
      now = now.add(const Duration(hours: 1, minutes: 30));
      await tester.runAsync(c.refreshVitals);
      await _page(tester, InnScreen(controller: c));
      await _shot(tester, '${n}_30_여관_쉬는중_차는중');
      await tester.runAsync(() => c.innAd());
      await _page(tester, InnScreen(controller: c));
      await _shot(tester, '${n}_31_여관_광고바로회복뒤');
      await tester.runAsync(() => c.sendTrip('rift', 'p2'));
      await _page(tester, InnScreen(controller: c));
      await _shot(tester, '${n}_32_여관_원정중멈춤');
      await tester.runAsync(c.refreshVitals);
      await tester.runAsync(() async {
        now = now.add(const Duration(hours: 10));
        await c.refreshVitals();
      });
      await _page(tester, InnScreen(controller: c));
      await _shot(tester, '${n}_33_여관_가득');
      await tester.runAsync(young.refreshVitals);
      await _page(tester, InnScreen(controller: young));
      await _shot(tester, '${n}_34_여관_각성전');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('b81 $n: 5 대사창', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async => c = await startVillage(21, farewell: true, more: _pets(_three)));
      await _page(tester, HighlandSceneScreen(controller: c));
      await _shot(tester, '${n}_40_하이랜드_첫장면_주인공');
      await tester.tapAt(const Offset(200, 300));
      await _settle(tester, 8);
      await _shot(tester, '${n}_41_하이랜드_첫장면_펫');
      await _page(tester, MeetScreen(controller: c));
      for (var i = 0; i < 2; i++) {
        await tester.tapAt(const Offset(200, 300));
        await _settle(tester, 6);
      }
      await _shot(tester, '${n}_42_주점_만남_리안');
      Widget scene(String? sp, SceneWho? who, String line, String img) => Scaffold(
          body: IllustratedScene(image: img, line: line, lineKey: line, onNext: () {}, speaker: sp, who: who));
      await _page(tester, scene('불씨', const SceneWho.name(), '여기야. 내가 처음 떨어졌던 곳.', 'assets/images/farewell_01_gate.webp'));
      await _settle(tester, 12);
      await _shot(tester, '${n}_43_정령이별_정령_이름만');
      await _page(tester, scene(null, null, '문 너머, 잿빛 속에서 누군가 이쪽을 보고 있었다.', 'assets/images/farewell_05_eyes.webp'));
      await _settle(tester, 12);
      await _shot(tester, '${n}_44_나레이션');
      await _page(tester, scene('하루', const SceneWho.hero(HeroLook.male), '…같이 가면 안 돼?', 'assets/images/farewell_02_lookup.webp'));
      await _settle(tester, 12);
      await _shot(tester, '${n}_45_주인공_오른쪽');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('b81 $n: 6 가방', (tester) async {
      _device(tester, d);
      late AppController c;
      late AppController full;
      const wornCap = EquipItem(uid: 'w1', base: EquipBase.cap, grade: EquipGrade.green);
      const wornArmor = EquipItem(uid: 'w2', base: EquipBase.armor, grade: EquipGrade.blue);
      final armory = const Armory(items: [
        wornCap,
        wornArmor,
        EquipItem(uid: 'b1', base: EquipBase.cap, grade: EquipGrade.purple),
        EquipItem(uid: 'b2', base: EquipBase.cap, grade: EquipGrade.white),
        EquipItem(uid: 'b3', base: EquipBase.armor, grade: EquipGrade.white, extras: {'str': 4}),
        EquipItem(uid: 'b4', base: EquipBase.fangNecklace, grade: EquipGrade.green),
        EquipItem(uid: 'b5', base: EquipBase.armor, grade: EquipGrade.blue),
      ], equipped: {EquipSlot.head: 'w1', EquipSlot.body: 'w2'}, nextId: 10).toJson();
      await tester.runAsync(() async {
        c = await startVillage(19, farewell: true, gains: {
          'herb': 12, 'slimeJelly': 30, 'batWing': 4, 'gold': 1200, 'manaStone': 3,
        }, more: {
          'armory': armory,
          ..._pets(_three, eggs: [const PetEgg(id: 'e1', source: 'field')]),
          'npc': {'v': 1, 'relics': ['mina', 'dorgun']},
          'harvest': {'granted': true},
        });
      });
      await _page(tester, Scaffold(body: BagTab(controller: c)));
      // 새로 얻은 것 표시가 보이게: 기억한 개수를 조금 적게 두고 다시 그림
      c.noteBagContents({...bagCounts(bagEntries(c)), 'm:herb': 10, 'e:b1': 0});
      await tester.runAsync(() => c.setBagSort(BagSort.recent));
      await _settle(tester, 3);
      await _shot(tester, '${n}_50_가방_첫화면');
      if (find.byKey(const Key('bagStrip_tool')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const Key('bagStrip_tool')));
        await _settle(tester, 2);
        await _shot(tester, '${n}_51_가방_도구펼침');
        await tester.tap(find.byKey(const Key('bagStrip_tool')));
        await _settle(tester, 2);
      }
      if (find.byKey(const Key('bagStrip_treasure')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const Key('bagStrip_treasure')));
        await _settle(tester, 2);
        await _shot(tester, '${n}_52_가방_보물펼침');
        await tester.tap(find.byKey(const Key('bagStrip_treasure')));
        await _settle(tester, 2);
      }
      await tester.tap(find.byKey(const Key('bagTab_equip')));
      await _settle(tester, 2);
      await _shot(tester, '${n}_53_가방_장비탭_비교표시');
      await tester.tap(find.byKey(const Key('bagCell_0')));
      await _settle(tester, 4);
      await _shot(tester, '${n}_54_장비누른창_비교');
      await tester.tapAt(const Offset(20, 120));
      await _settle(tester, 4);
      final neck = find.byWidgetPredicate((w) => w is BagSlot && w.entry is EquipEntry && (w.entry as EquipEntry).item.uid == 'b4');
      if (neck.evaluate().isNotEmpty) {
        await tester.tap(neck.first);
        await _settle(tester, 4);
        await _shot(tester, '${n}_55_장비누른창_빈부위');
        await tester.tapAt(const Offset(20, 120));
        await _settle(tester, 4);
      }
      await tester.tap(find.byKey(const Key('bagTab_all')));
      await tester.tap(find.byKey(const Key('bagSort')));
      await _settle(tester, 2);
      await _shot(tester, '${n}_56_가방_정렬_등급순');
      await tester.tap(find.byKey(const Key('bagPickToggle')));
      await _settle(tester, 1);
      for (final i in [1, 2]) {
        final f = find.byKey(Key('bagCell_$i'));
        if (f.evaluate().isNotEmpty) await tester.tap(f, warnIfMissed: false);
      }
      await _settle(tester, 2);
      await _shot(tester, '${n}_57_가방_골라서버리기');
      await tester.runAsync(() async => full = await startVillage(19, farewell: true, gains: {
            for (final m in Materials.displayOrder.take(40)) m.name: 2,
          }));
      await _page(tester, Scaffold(body: BagTab(controller: full)));
      await _shot(tester, '${n}_58_가방_가득_빨간막대');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('b81 $n: 7 상태 물약 칩 · 걷기 숙련 · 부탁', (tester) async {
      _device(tester, d);
      final now = DateTime(2026, 11, 16, 10);
      late AppController c;
      late AppController plain;
      await tester.runAsync(() async {
        c = await startVillage(16, farewell: true, clock: () => now, more: {
          'alchemy': {
            'buffs': [
              {'key': 'resistIce', 'until': now.add(const Duration(hours: 3)).toIso8601String(), 'battles': 4},
              {'key': 'strength', 'until': now.add(const Duration(minutes: 30)).toIso8601String()},
            ],
          },
          'jobs': _jobs('warrior'),
        });
        plain = await startVillage(16, farewell: true, clock: () => now);
      });
      Widget status(AppController x) => Scaffold(
          body: SingleChildScrollView(
              child: StatusScreen(
                  player: x.player, hp: x.hp, mp: x.mp, maxHp: x.maxHp, mpMax: x.mpMax, buffRow: buffChips(x))));
      await _page(tester, status(c));
      await _shot(tester, '${n}_60_상태_물약칩');
      await _page(tester, status(plain));
      await _shot(tester, '${n}_61_상태_물약없음');
      await _page(tester, SkillScreen(controller: c, tab: 2));
      final walk = find.byKey(const Key('masteryRow_walk'));
      if (walk.evaluate().isNotEmpty) {
        await tester.ensureVisible(walk);
        await tester.tap(walk);
        await _settle(tester, 3);
      }
      await _shot(tester, '${n}_62_걷기탐험_숙련_펼침');
      await _page(tester, Scaffold(
          body: ListView(padding: const EdgeInsets.all(16), children: [
        for (final r in NpcRules.requests)
          for (final s in r.steps)
            if (s.kind == RequestStepKind.stepsSince && s.label.startsWith('부탁 받은 뒤'))
              Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    NpcFace(npc: r.npc, size: 36),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${r.say}\n· ${s.label}', style: const TextStyle(color: Colors.white))),
                  ])),
        for (final r in NpcSmallRules.relics)
          for (final st in r.stages)
            for (final s in st.steps)
              if (s.label.startsWith('부탁 받은 뒤'))
                Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('${r.name} · ${st.line}\n· ${s.label}', style: const TextStyle(color: Colors.white))),
      ])));
      await _shot(tester, '${n}_63_바뀐_마을사람_부탁');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 9));
    });
  }
}
