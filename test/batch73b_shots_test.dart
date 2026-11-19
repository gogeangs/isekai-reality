// 묶음 73 다시 보냄 (build/screenshots/b73b_*)
// 작은 iPhone(SE) · 큰 iPhone · Android

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/pet_state.dart';
import 'package:isekai_reality/core/models/vitals.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/storage/record_store.dart' show HeroLook, SpiritKind;
import 'package:isekai_reality/features/battle/battle_view.dart';
import 'package:isekai_reality/features/bulssi/bulssi_mood.dart';
import 'package:isekai_reality/features/map/expedition_result.dart';
import 'package:isekai_reality/features/pets/companion_pet_panel.dart';
import 'package:isekai_reality/features/pets/pet_screen.dart';
import 'package:isekai_reality/features/status/status_screen.dart';
import 'package:isekai_reality/features/village/hatchery.dart';
import 'package:isekai_reality/features/village/village_screen.dart';
import 'package:isekai_reality/theme/ornaments.dart';
import 'package:isekai_reality/theme/top_notice.dart';

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
  File('build/screenshots/b73b_$name.png')
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





BattleAlly _ally(String id) => BattleAlly(id: id, name: id, maxHp: 100000, attack: 20);

Widget _battle(Battle b, {List<String> allies = const [], PetSpecies? pet, bool adult = true, SpiritKind kind = SpiritKind.fire, HeroLook look = HeroLook.male}) =>
    BulssiScope(
      key: UniqueKey(),
      mood: BulssiMood.gold,
      spiritName: '불씨',
      kind: kind,
      petSpecies: pet,
      petAdult: adult,
      child: Scaffold(
          body: SafeArea(
              child: Column(children: [
        Expanded(
            child: BattleView(
                battle: b,
                fit: true,
                look: look,
                onFinished: () {},
                tickInterval: const Duration(milliseconds: 900),
                allyArts: [
                  for (final a in allies) (art: 'assets/images/ally_$a.webp', face: null, color: 0xFFE8C77A),
                ])),
      ]))),
    );

Battle _b({List<String> allies = const []}) => Battle(
      playerMaxHp: 100000,
      playerAttack: 30,
      floors: [Foe(monster: MonsterId.ashSlime, maxHp: 1000000, attack: 1)],
      rng: math.Random(3),
      allies: [for (final a in allies) _ally(a)],
    );

Future<bool> _until(WidgetTester tester, Finder f, {int max = 120}) async {
  for (var i = 0; i < max; i++) {
    if (f.evaluate().isNotEmpty) return true;
    await tester.pump(const Duration(milliseconds: 20));
  }
  return false;
}

void main() {
  setUpAll(_loadFonts);
  setUp(() => b56.now = b52.t0);

  for (final d in _devices) {
    final n = d.$1;

    testWidgets('b73b $n: 싸움 대열', (tester) async {
      _device(tester, d);
      await _page(tester, _battle(_b(), kind: SpiritKind.water));
      await _shot(tester, '${n}_01_혼자_대기');
      await _until(tester, find.byKey(const Key('heroFrame_3')));
      await _shot(tester, '${n}_02_혼자_주먹4칸');
      for (final (k, pair) in [
        (0, ['lian', 'garen']),
        (0, ['popo', 'sera']),
        (1, ['popo', 'sera']),
      ]) {
        await _page(tester, _battle(_b(allies: pair), allies: pair));
        if (k == 0 && pair.first == 'lian') await _shot(tester, '${n}_03_동료둘_대기');
        await _until(tester, find.byKey(Key('allyFrame_${k}_3')));
        await _shot(tester, '${n}_04_${pair[k]}_공격4칸');
      }
      await _page(tester, _battle(_b(allies: ['lian', 'garen']), allies: ['lian', 'garen'], pet: PetSpecies.golem));
      await _shot(tester, '${n}_05_펫과_대열_골렘');
      await _page(tester, _battle(_b(), pet: PetSpecies.dragon, look: HeroLook.female));
      await _shot(tester, '${n}_06_뒤집힌펫_드래곤');
      await _page(tester, _battle(_b(), kind: SpiritKind.plant, look: HeroLook.female));
      await _shot(tester, '${n}_07_정령전투그림_풀');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('b73b $n: 부화장 · 광고 두 배 · 빛의 다리 · 함께하는 펫 · 먹이 주기', (tester) async {
      _device(tester, d);
      Map<String, dynamic> pets(List<PetEgg> eggs) => PetState(
            pets: [Pet(uid: 'p1', species: PetSpecies.owl, name: '부엉', exp: 1200, bornAt: DateTime(2026, 11, 1))],
            companion: 'p1',
            firstPet: 'p1',
            firstSpiritName: '불씨',
            farewellAt: DateTime(2026, 11, 2),
            eggs: eggs,
            nextId: 9,
          ).toJson();
      for (final (k, eggs) in [
        ('빈둥지', <PetEgg>[]),
        ('알1개', [PetEgg(id: 'e1', source: 'field', incubatedAt: vt0.subtract(const Duration(hours: 2)))]),
        ('알2개', [
          PetEgg(id: 'e1', source: 'field', incubatedAt: vt0.subtract(const Duration(hours: 2))),
          PetEgg(id: 'e2', source: 'field', incubatedAt: vt0.subtract(const Duration(hours: 30))),
        ]),
      ]) {
        late AppController c;
        await tester.runAsync(() async => c = await startVillage(11, farewell: true, more: {'pets': pets(eggs)}));
        await _page(tester, Scaffold(key: ObjectKey('h$n$k'), body: NightBackground(child: SafeArea(child: Padding(padding: const EdgeInsets.all(12), child: HatcheryPanel(controller: c))))));
        await _shot(tester, '${n}_08_부화장_$k');
      }
      late AppController c;
      await tester.runAsync(() async => c = await startVillage(11, farewell: true, more: {'pets': pets(const [])}, gains: {
            'slimeJelly': 3,
            'wolfFang': 1,
          }));
      c.watchAd = (_) async => true;
      final ex = Expedition(
        spawnId: 's1',
        monster: MonsterId.slime.name,
        lat: 37.5,
        lng: 127,
        distanceM: 300,
        mpCost: 5,
        startedAt: vt0,
        arriveAt: vt0,
        returnAt: vt0,
        cleared: true,
        reward: const {'gold': 30, 'exp': 10, 'slimeJelly': 2},
        baseReward: const {'gold': 30, 'exp': 10, 'slimeJelly': 2},
      );
      await _page(tester, Scaffold(key: ObjectKey('x$n'), body: Builder(builder: (ctx) => Center(child: TextButton(onPressed: () => showExpeditionResult(ctx, ex, '불씨', controller: c), child: const Text('열기'))))));
      await tester.tap(find.text('열기'));
      await _settle(tester, 4);
      await _shot(tester, '${n}_09_원정성공_광고전');
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('adDouble')));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 800));
      await _shot(tester, '${n}_10_원정성공_두배도장');
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1500)));
      await _settle(tester, 3);
      // 상태 화면 「함께하는 펫」
      await _page(tester, Scaffold(key: ObjectKey('st$n'), body: NightBackground(header: true, child: StatusScreen(player: c.player, look: c.profile.look, requestPanel: CompanionPetPanel(controller: c)))));
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await _settle(tester, 3);
      await _shot(tester, '${n}_11_상태_함께하는펫');
      await _page(tester, PetScreen(key: ObjectKey('ps$n'), controller: c));
      await tester.tap(find.text('먹이 주기').first);
      await _settle(tester, 4);
      await _shot(tester, '${n}_12_먹이주기');
      Navigator.of(tester.element(find.byKey(const Key('feedSnack')))).pop();
      await _settle(tester, 3);
      // 마을 빛의 다리 (판을 넘겨도 정령 줄 밑으로 안 들어감)
      late AppController v;
      await tester.runAsync(() async => v = (await b52.start(b52.account())).$1);
      await _page(tester, Scaffold(key: ObjectKey('v$n'), body: VillageScreen(controller: v)));
      await _shot(tester, '${n}_13_마을_빛의다리');
      await tester.drag(find.byKey(const Key('villageScroll')), const Offset(260, 0));
      await _settle(tester, 4);
      await _shot(tester, '${n}_14_마을_넘긴판');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  }
}
