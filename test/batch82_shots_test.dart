// 묶음 82 (build/screenshots/b82_*) — 큰 iPhone · SE

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
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/models/pet_state.dart';
import 'package:isekai_reality/core/models/vitals.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/act2/ash_battle_screen.dart';
import 'package:isekai_reality/features/act2/ash_turn_view.dart';
import 'package:isekai_reality/features/battle/auto_use_window.dart';
import 'package:isekai_reality/features/map/expedition_result.dart';
import 'package:isekai_reality/features/map/expedition_sheet.dart';
import 'package:isekai_reality/features/smithy/boss_gear_tab.dart' show showBossMade;
import 'package:isekai_reality/features/smithy/smithy_screen.dart';
import 'package:isekai_reality/features/town/bag_tab.dart';
import 'package:isekai_reality/features/town/inn_screen.dart';
import 'package:isekai_reality/features/town/shop_screen.dart';
import 'package:isekai_reality/features/tutorial/feature_tour.dart';
import 'package:isekai_reality/features/village/village_screen.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'batch52_test.dart' as b52;
import 'batch56_test.dart' as b56;
import 'support/village_seed.dart';

final _root = GlobalKey();
const _home = GeoPoint(37.3219, 126.8309);
final _t0 = DateTime(2026, 11, 16, 10);

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
  File('build/screenshots/b82_$name.png')
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

Future<void> _page(WidgetTester tester, Widget home, {AppController? tour}) async {
  await tester.pumpWidget(RepaintBoundary(
    key: _root,
    child: MaterialApp(
        key: UniqueKey(),
        debugShowCheckedModeBanner: false,
        theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Roboto'),
        builder: (context, child) => TopNoticeHost(
            child: Stack(children: [
          Positioned.fill(child: child!),
          if (tour != null) Positioned.fill(child: FeatureTourLayer(controller: tour)),
        ])),
        home: home),
  ));
  await _settle(tester);
}

Widget _opener(void Function(BuildContext) open) => Scaffold(
    body: Builder(
        builder: (ctx) => Center(
            child: TextButton(key: const Key('open'), onPressed: () => open(ctx), child: const Text('열기')))));

Future<void> _openTap(WidgetTester tester, Widget opener) async {
  await _page(tester, opener);
  await tester.tap(find.byKey(const Key('open')));
  await _settle(tester, 5);
}

Pet _pet(String uid, PetSpecies s, String name) => Pet(uid: uid, species: s, name: name, bornAt: DateTime(2026, 11, 1));

final _four = [
  _pet('p1', PetSpecies.owl, '부엉'),
  _pet('p2', PetSpecies.blackCat, '나비'),
  _pet('p3', PetSpecies.toad, '개굴'),
  _pet('p4', PetSpecies.crow, '까망'),
];

Map<String, dynamic> _pets(List<Pet> pets, {List<PetEgg> eggs = const []}) => {
      'pets': PetState(
        pets: pets,
        companion: pets.first.uid,
        firstPet: pets.first.uid,
        firstSpiritName: '불씨',
        farewellAt: DateTime(2026, 11, 2),
        eggs: eggs,
      ).toJson(),
    };

Map<String, dynamic> _jobs(String main) => {'awakened': true, 'v57': true, 'v31': true, 'main': main, 'owned': [main]};

/// 첫 무기를 분해한 계정 (예전엔 켤 때마다 마을 기록이 지워짐)
InMemoryRecordStore _wipedStore(int level, {required Map<String, dynamic> village, Map<String, dynamic> more = const {}}) =>
    InMemoryRecordStore(
      profile: const PlayerProfile(name: '하루', spiritName: '불씨', spiritKind: SpiritKind.water, lastSeenLevel: 99),
      history: [
        DailyRecord(date: DateTime(2026, 11, 15), gains: {'exp': LevelRules.totalExpToReach(level)}),
      ],
      json: {
        'tutorial': {'step': TutorialStep.done.index},
        'gates': {'legacy': false, 'v28': true, 'seen': [for (final f in Feature.values) f.name]},
        'gifts': {'got': [Gift.firstWeapon]},
        'armory': const {'items': [], 'equipped': {}, 'nextId': 3},
        'village': village,
        ..._pets([_four.first]),
        ...more,
      },
    );

Future<AppController> _open(InMemoryRecordStore s) async {
  final c = AppController(store: s, health: FakeHealthSource(stepsByDay: const {}), clock: () => _t0)..mailSources = const [];
  await c.init();
  return c;
}

/// 턴제 화면만 (상태를 맞춘 한 판)
Widget _turnPage(AppController c, AshTurn t) => Scaffold(
      body: Padding(
        padding: const EdgeInsets.fromLTRB(14, 50, 14, 20),
        child: AshTurnView(controller: c, turn: t, background: 'assets/images/bg_boss_flame.webp', onFinished: () {}),
      ),
    );

AshTurn _turn(AppController c, AshAvatar a, {int seen = 0}) => AshTurn(
      avatar: a,
      level: Act2Rules.info(a).level,
      heroMaxHp: c.maxHp,
      heroHp: c.maxHp,
      heroAttack: 150,
      mp: c.jobMp,
      mpMax: c.jobMpMax,
      skills: [
        for (final (s, cost, power) in c.battleJobSlots.take(2))
          AshTurnSkill(key: s.name, name: JobRules.skill(s).name, mp: cost, attack: JobRules.skill(s).attack, power: power),
      ],
      hasPet: true,
      potions: const [BattlePotion(key: 'shop:heal', name: '회복 물약', count: 3, hpRatio: 0.4)],
      memoriesSeen: seen,
    );

void main() {
  setUpAll(_loadFonts);
  setUp(() => b56.now = b52.t0);

  for (final d in [_devices[1], _devices[0]]) {
    final n = d.$1;

    testWidgets('b82 $n: 1 시작 · 마을 기록', (tester) async {
      _device(tester, d);
      late AppController a;
      late AppController revived;
      await tester.runAsync(() async {
        final s = _wipedStore(14, village: {
          'seen': ['intro', 'farewell', 'shelterCard', 'trainingCard', 'gardenCard', 'chatTour', 'met:marta', 'v44', 'v43', 'v48'],
          'visits': {'marta': 3},
        });
        await _open(s);
        a = await _open(s); // 두 번째로 켬
        revived = await _open(_wipedStore(20,
            village: const {'seen': ['giftMarked'], 'visits': {}},
            more: {
              'jobs': _jobs('warrior'),
              'npc': {'v': 1, 'points': {'marta': 12, 'mina': 3}},
              'training': {'daily': '2026-11-14'},
              'garden': {'harvested': 2},
              'tavern': {'meals': 1},
            }));
      });
      tourBridge.tab = FeatureTourLayer.tVillage;
      await _page(tester, Scaffold(body: VillageScreen(controller: a)), tour: a);
      await _settle(tester, 6);
      await _shot(tester, '${n}_01_첫무기분해_두번켠뒤_마을_카드없음');
      await _page(tester, Scaffold(body: VillageScreen(controller: revived)), tour: revived);
      await _settle(tester, 6);
      await _shot(tester, '${n}_02_Lv20_되살리기_마을_카드없음');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('b82 $n: 2 잿빛 틈 두 번째 소식', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async => c = await startVillage(14, farewell: true, more: {
            'act2': {'beaten': 1, 'announced': 1},
          }));
      final rift = c.takeRiftNews()!;
      await _openTap(
          tester, _opener((ctx) => showTopNotice(ctx, Act2Ops.riftNewsLine(rift), image: 'assets/images/map_rift.webp')));
      await _settle(tester, 3);
      await _shot(tester, '${n}_10_두번째_잿빛틈_소식띠');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('b82 $n: 3 잿빛 틈 턴제', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async => c = await startVillage(16, farewell: true, more: {'jobs': _jobs('warrior')}));
      // 첫 화면
      var t = _turn(c, AshAvatar.rage);
      await _page(tester, _turnPage(c, t));
      await _shot(tester, '${n}_20_턴제_첫화면');
      // 게이지 4칸 · 마주하기 열림
      t = _turn(c, AshAvatar.rage)
        ..gauge = 4
        ..foeHp = (AshTurnRules.foeMaxHp(12) * 0.6).round()
        ..hp = (c.maxHp * 0.7).round()
        ..say = AshTurnRules.info(AshAvatar.rage).lines[2];
      await _page(tester, _turnPage(c, t));
      await _shot(tester, '${n}_21_게이지4칸_마주하기열림');
      // 다 찬 예고 (붉은 말풍선 · 정령 힌트)
      t = _turn(c, AshAvatar.rage)
        ..gauge = 4
        ..foeHp = (AshTurnRules.foeMaxHp(12) * 0.5).round();
      await _page(tester, _turnPage(c, t));
      await tester.tap(find.byKey(const Key('ashCmd_guard')));
      await _settle(tester, 12);
      await _shot(tester, '${n}_22_다찬예고_붉은말풍선_정령힌트');
      // 분노 폭발 (방어로 받음)
      await tester.tap(find.byKey(const Key('ashCmd_guard')));
      await tester.pump(const Duration(milliseconds: 1100));
      await _shot(tester, '${n}_23_분노폭발');
      await _settle(tester, 10);
      // 마주하기 닫힘
      t = _turn(c, AshAvatar.rage)..gauge = 1;
      await _page(tester, _turnPage(c, t));
      await _shot(tester, '${n}_24_마주하기_닫힘');
      // 왕의 기억 글판
      t = _turn(c, AshAvatar.rage)..gauge = 3;
      await _page(tester, _turnPage(c, t));
      await tester.tap(find.byKey(const Key('ashCmd_face')));
      await _settle(tester, 4);
      await _shot(tester, '${n}_25_왕의기억_글판');
      await tester.tap(find.byKey(const Key('ashMemoryNext')));
      await _settle(tester, 12);
      // 다른 분신 넷
      for (final (a, name) in [
        (AshAvatar.sorrow, '슬픔_눈물비'),
        (AshAvatar.greed, '탐욕_빼앗기'),
        (AshAvatar.fear, '두려움_스킬잠김'),
        (AshAvatar.lonely, '외로움_펫멈춤'),
      ]) {
        t = _turn(c, a);
        if (a == AshAvatar.greed) t.wall = 2;
        t.gauge = 5;
        t.act(AshCmd.attack);
        await _page(tester, _turnPage(c, t));
        await _shot(tester, '${n}_26_$name');
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('b82 $n: 4 잿빛 틈 결과', (tester) async {
      _device(tester, d);
      for (final (kind, label) in [(0, '다본승리'), (1, '덜본승리'), (2, '패배')]) {
        late AppController c;
        await tester.runAsync(() async {
          c = await startVillage(12, farewell: true, more: {
            'act2': {'mem': kind == 0 ? [2, 0, 0, 0, 0] : [0, 0, 0, 0, 0]},
          });
          await c.handleFix(const LocationFix(point: _home));
          final r = c.riftPoint!;
          await c.handleFix(LocationFix(point: r));
        });
        await _page(tester, AshBattleScreen(controller: c));
        await tester.tap(find.byKey(const Key('ashEnter')));
        await _settle(tester, 4);
        final t = (tester.widget(find.byType(AshTurnView)) as AshTurnView).turn;
        void redraw() => (tester.state(find.byType(AshTurnView)) as dynamic).setState(() {});
        if (kind == 2) {
          t.hp = 1;
          redraw();
        } else {
          t.foeHp = 1;
          redraw();
          if (kind == 0) {
            t.gauge = 2;
            redraw();
            await tester.pump();
            await tester.tap(find.byKey(const Key('ashCmd_face')));
            await _settle(tester, 3);
            await tester.tap(find.byKey(const Key('ashMemoryNext')));
            await _settle(tester, 14);
          }
        }
        if (find.byKey(const Key('ashCmd_attack')).evaluate().isNotEmpty) {
          await tester.tap(find.byKey(const Key('ashCmd_attack')));
        }
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 250));
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
        }
        await _settle(tester, 6);
        await _shot(tester, '${n}_30_$label');
        if (kind == 0) {
          // 바로 입기 (유품) 누른 뒤
          if (find.byKey(const Key('equipNow')).evaluate().isNotEmpty) {
            await tester.ensureVisible(find.byKey(const Key('equipNow')));
            await tester.tap(find.byKey(const Key('equipNow')));
            await _settle(tester, 4);
            await _shot(tester, '${n}_31_유품_입었어요');
          }
        }
        if (kind == 1) {
          await _openTap(tester, _opener((ctx) => showKingStory(ctx, 0, seen: 1)));
          await _settle(tester, 12);
          await _shot(tester, '${n}_32_왕의사연_빈칸');
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 9));
      }
    });

    testWidgets('b82 $n: 5 원정 창 · 결과', (tester) async {
      _device(tester, d);
      final cs = <String, AppController>{};
      await tester.runAsync(() async {
        for (final (k, hp) in [('full', 1.0), ('low', 0.04), ('zero', 0.0)]) {
          final c = await startVillage(18, farewell: true, more: {..._pets(_four), 'jobs': _jobs('warrior')});
          await c.handleFix(const LocationFix(point: _home));
          cs[k] = await startVillage(18,
              farewell: true,
              clock: () => _t0,
              vitals: Vitals(hp: (c.maxHp * hp).round(), mp: 999, mpAt: _t0),
              more: {..._pets(_four), 'jobs': _jobs('warrior')});
          await cs[k]!.handleFix(const LocationFix(point: _home));
        }
      });
      List<FieldSpawn> near(AppController x) =>
          [...x.todaySpawns]..sort((a, b) => _home.distanceTo(a.point).compareTo(_home.distanceTo(b.point)));
      final easy = cs['full']!;
      final weak = near(easy).firstWhere((s) => s.modifiers.isEmpty, orElse: () => near(easy).first);
      await _openTap(tester, _opener((ctx) => showSpawnSheet(ctx, easy, weak)));
      await _shot(tester, '${n}_40_원정창_주인공함께_쉬워요_얼굴칸4');
      final hard = [...easy.todaySpawns]..sort((a, b) => b.modifiers.length.compareTo(a.modifiers.length));
      await _openTap(tester, _opener((ctx) => showSpawnSheet(ctx, cs['low']!, hard.first)));
      await _shot(tester, '${n}_41_원정창_HP낮음_어려움');
      await _openTap(tester, _opener((ctx) => showSpawnSheet(ctx, cs['zero']!, weak)));
      await _shot(tester, '${n}_42_원정창_HP0_막힘');
      final ex = Expedition(
        spawnId: weak.id,
        monster: weak.monster.name,
        lat: weak.point.lat,
        lng: weak.point.lng,
        distanceM: 400,
        mpCost: 8,
        startedAt: _t0,
        arriveAt: _t0,
        returnAt: _t0,
        petUid: 'p1',
        petName: '부엉',
      ).withResult(true, reward: const {'exp': 30, 'manaStone': 1}, hpLost: 214, mpLost: 12);
      await _openTap(tester, _opener((ctx) => showExpeditionResult(ctx, ex, '부엉', controller: easy)));
      await _shot(tester, '${n}_43_원정결과_HP_MP_줄어듦');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('b82 $n: 6 자동 마시기 · 바로 입기', (tester) async {
      _device(tester, d);
      await _openTap(tester, _opener((ctx) => showAutoUseWindow(ctx, hp: 50, cure: true, onChanged: (_, __) {})));
      await _shot(tester, '${n}_50_자동마시기_각성전');
      await _openTap(tester,
          _opener((ctx) => showAutoUseWindow(ctx, hp: 50, cure: true, mp: 30, onMpChanged: (_) {}, onChanged: (_, __) {})));
      await _shot(tester, '${n}_51_자동마시기_각성뒤_MP');
      await _page(
          tester,
          Scaffold(
              body: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final (hp, cure, mp) in [(50, true, 30), (30, false, 0), (0, false, 0), (50, true, 50)])
              Padding(
                padding: const EdgeInsets.all(6),
                child: Text('전투 물약 줄 · ${autoUseLabel(hp, cure, mp: mp, short: true)}',
                    style: const TextStyle(color: Colors.white, fontSize: 16)),
              ),
          ]))));
      await _shot(tester, '${n}_52_전투물약줄_표시');
      late AppController c;
      await tester.runAsync(() async => c = await startVillage(16, farewell: true, more: {
            'armory': const Armory(items: [
              EquipItem(uid: 'w1', base: EquipBase.ironSword, grade: EquipGrade.blue),
              EquipItem(uid: 'b1', base: EquipBase.flameWeapon, grade: EquipGrade.purple),
            ], nextId: 5)
                .toJson(),
          }));
      await _openTap(tester, _opener((ctx) => showEquipMade(ctx, c, c.armory.byUid('w1')!)));
      await _shot(tester, '${n}_53_대장간만들기_바로입기');
      await tester.tap(find.byKey(const Key('equipNow')));
      await _settle(tester, 3);
      await _shot(tester, '${n}_54_대장간만들기_입었어요');
      await _openTap(tester,
          _opener((ctx) => showBossMade(ctx, c, EquipBase.flameWeapon, BossCraftResult(item: c.armory.byUid('b1')))));
      await _shot(tester, '${n}_55_왕의장비_바로입기');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('b82 $n: 7 강화 탭', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async => c = await startVillage(16, farewell: true, gains: {
            'manaStone': 200,
            'gold': 5000,
            'ironIngot': 10,
            'tannedLeather': 3,
            'runeStone': 1,
          }, more: {
            'armory': const Armory(items: [
              EquipItem(uid: 'w1', base: EquipBase.ironSword, grade: EquipGrade.white),
              EquipItem(uid: 'a1', base: EquipBase.armor, grade: EquipGrade.blue, enhance: 2),
              EquipItem(uid: 'c1', base: EquipBase.fangNecklace, grade: EquipGrade.purple, element: Element.fire),
              EquipItem(uid: 'w2', base: EquipBase.dagger, grade: EquipGrade.orange, enhance: 2),
            ], nextId: 9)
                .toJson(),
          }));
      await _page(tester, SmithyScreen(controller: c));
      await tester.tap(find.byKey(const Key('smithyTab_1')));
      await _settle(tester, 4);
      await _shot(tester, '${n}_60_강화탭_흰무기_파랑방어구');
      await tester.drag(find.byKey(const Key('smithyList')), const Offset(0, -500));
      await _settle(tester, 4);
      await _shot(tester, '${n}_61_강화탭_보라장신구_주황무기_모자람');
      final make = find.byKey(const Key('enhanceMake_c1'));
      if (make.evaluate().isNotEmpty) {
        await tester.ensureVisible(make);
        await tester.tap(make);
        await _settle(tester, 4);
        await _shot(tester, '${n}_62_재료가공_바로가기');
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('b82 $n: 8 여관 · 잡화상 · 가방', (tester) async {
      _device(tester, d);
      late AppController resting;
      late AppController paused;
      late AppController full;
      late AppController shop;
      late AppController bag;
      late AppController hidden;
      var now = _t0;
      await tester.runAsync(() async {
        resting = await startVillage(16, farewell: true, clock: () => now, vitals: Vitals(hp: 300, mp: 10, mpAt: now));
        await resting.restAtInn();
        paused = await startVillage(16, farewell: true, more: _pets(_four), clock: () => _t0, vitals: Vitals(hp: 300, mp: 999, mpAt: _t0));
        await paused.handleFix(const LocationFix(point: _home));
        final ps = [...paused.todaySpawns]..sort((a, b) => _home.distanceTo(a.point).compareTo(_home.distanceTo(b.point)));
        expect(await paused.sendSpirit(ps.first, petUid: 'p2'), ExpeditionCheck.ok);
        await paused.restAtInn();
        full = await startVillage(16, farewell: true, clock: () => now);
        await full.restAtInn();
        shop = await startVillage(16, farewell: true, more: {'jobs': _jobs('mage')});
        bag = await startVillage(19, farewell: true, gains: {'herb': 5, 'gold': 12345, 'manaStone': 678});
        hidden = await startVillage(9, gains: {'slimeJelly': 3}, more: {
          'pets': const PetState(eggs: [PetEgg(id: 'e1', source: 'field')]).toJson(),
        });
      });
      now = now.add(const Duration(hours: 1));
      await tester.runAsync(() async {
        await resting.refreshVitals();
      });
      await _page(tester, InnScreen(controller: resting));
      await _shot(tester, '${n}_70_여관_쉬는중');
      await _page(tester, InnScreen(controller: paused));
      await _shot(tester, '${n}_71_여관_원정중');
      await _page(tester, InnScreen(controller: full));
      await _shot(tester, '${n}_72_여관_가득');
      await _page(tester, ShopScreen(controller: shop));
      await _shot(tester, '${n}_73_잡화상_사기탭_막대없음');
      await _page(tester, Scaffold(body: BagTab(controller: bag)));
      await _shot(tester, '${n}_74_가방_머리줄_탭줄');
      await _page(tester, Scaffold(body: BagTab(controller: hidden)));
      await _shot(tester, '${n}_75_가방_숨은알_칸수제외');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 9));
    });
  }
}
