// 묶음 85 (build/screenshots/b85_*) — 큰 iPhone · SE

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/core/models/highland_state.dart';
import 'package:isekai_reality/core/models/pet_state.dart';
import 'dart:math' as math;

import 'package:isekai_reality/data/storage/record_store.dart' show HeroLook, SpiritKind;
import 'package:isekai_reality/core/models/garden_state.dart';
import 'package:isekai_reality/features/battle/battle_view.dart';
import 'package:isekai_reality/features/bulssi/bulssi_mood.dart';
import 'package:isekai_reality/features/highland/highland_screen.dart';
import 'package:isekai_reality/features/jobs/job_picker.dart';
import 'package:isekai_reality/features/jobs/skill_screen.dart';
import 'package:isekai_reality/features/map/map_screen.dart';
import 'package:isekai_reality/features/pets/pet_screen.dart';
import 'package:isekai_reality/features/profile/profile_screen.dart';
import 'package:isekai_reality/features/town/bag_tab.dart';
import 'package:isekai_reality/features/village/garden_screen.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'package:isekai_reality/app.dart' show OrnateNavBar;

import 'batch83_test.dart' as t83;
import 'batch84_test.dart' as t84;
import 'batch85_test.dart' as t85;
import 'support/village_seed.dart';

final _root = GlobalKey();

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
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
  }
  final boundary = tester.renderObject(find.byKey(_root)) as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.5);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  File('build/screenshots/b85_$name.png')
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



Future<void> _done(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 3));
}

List<int> _path(SkyBoard b, int to) {
  final prev = <int, int>{};
  final q = [b.entrance];
  final seen = {b.entrance};
  for (var k = 0; k < q.length; k++) {
    for (final j in b.neighbors4(q[k])) {
      if (seen.add(j)) {
        prev[j] = q[k];
        q.add(j);
      }
    }
  }
  final out = <int>[];
  var s = to;
  while (s != b.entrance) {
    out.add(s);
    s = prev[s]!;
  }
  return out.reversed.toList();
}



Widget _battle(Battle b, {List<String>? bar, Duration tick = const Duration(seconds: 30)}) => BulssiScope(
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
                look: HeroLook.male,
                heroJob: 'warrior',
                bar: bar,
                emptySlots: true,
                onFinished: () {},
                tickInterval: tick)),
      ]))),
    );

const _potion = BattlePotion(key: 'hp', name: '회복 물약', count: 3, hpRatio: 0.3);

Battle _b(List<Foe> foes) => Battle(
      playerMaxHp: 1200,
      playerAttack: 40,
      floors: foes,
      rng: math.Random(3),
      heroSkills: true,
      potions: const [_potion],
      autoHp: 30,
    );

void main() {
  setUpAll(_loadFonts);

  for (final d in _devices) {
    final n = d.$1;

    testWidgets('b85 $n: 1 전투 머리 위 HP', (tester) async {
      _device(tester, d);
      // 필드 (수식어 몬스터)
      final field = _b([Foe(monster: MonsterId.hornRabbit, maxHp: 840, attack: 1, mods: const [ModifierId.sturdy])]);
      await _page(tester, _battle(field, bar: const ['base:bash', 'base:stance', '', '']));
      await _shot(tester, '${n}_01_전투_필드_머리위HP');
      // 한 대 맞은 뒤 (흰 자국)
      await _page(tester, _battle(_b([Foe(monster: MonsterId.hornRabbit, maxHp: 840, attack: 1)]), tick: const Duration(milliseconds: 700)));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await _shot(tester, '${n}_02_전투_맞은뒤_흰자국');
      await _done(tester);
      // 던전 보스
      await _page(tester, _battle(_b([Foe(monster: MonsterId.labyrinthWarden, maxHp: 52000, attack: 1)])));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await _shot(tester, '${n}_03_전투_던전보스_큰막대');
      await _done(tester);
      // 무리 (여러 마리 중 지금 한 마리)
      await _page(tester, _battle(_b([
        Foe(monster: MonsterId.babyBoar, maxHp: 600, attack: 1, mods: const [ModifierId.hungry]),
        Foe(monster: MonsterId.babyBoar, maxHp: 600, attack: 1),
        Foe(monster: MonsterId.babyBoar, maxHp: 600, attack: 1),
      ])));
      await _shot(tester, '${n}_04_전투_무리_지금한마리');
      await _done(tester);
    });

    testWidgets('b85 $n: 2 스킬 페이지', (tester) async {
      _device(tester, d);
      late AppController pre, c, lv25;
      await tester.runAsync(() async {
        pre = await startVillage(12, farewell: true, gains: {'mtitle:x': 0}, more: {
          'jobs': {'pageOpen': true, 'pageIntro': true},
        });
        c = await startVillage(20, farewell: true, more: t85.awakened());
        await c.raiseSkill(JobRules.info(JobId.warrior).skills[1]);
        await c.setLoadout(1, null);
        lv25 = await startVillage(50, farewell: true, more: t85.awakened());
        for (final k in JobRules.info(JobId.warrior).skills) {
          while (lv25.canRaiseSkill(k)) {
            await lv25.raiseSkill(k);
          }
        }
        await lv25.raiseDrill(JobId.warrior);
        await lv25.raiseDrill(JobId.warrior);
      });
      await _page(tester, SkillScreen(key: ObjectKey('p$n'), controller: pre));
      await _shot(tester, '${n}_05_스킬_각성전_칸2개');
      await _page(tester, SkillScreen(key: ObjectKey('c$n'), controller: c));
      await _shot(tester, '${n}_06_스킬_각성뒤_칸4개');
      // 칸 3(강타)을 고르고 다른 스킬로 바꿈 → 알림
      await tester.tap(find.byKey(const Key('skillSlot_2')));
      await _settle(tester, 2);
      final pick = find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('battlePick_job:${JobRules.info(JobId.warrior).skills[1].name}'));
      if (pick.evaluate().isNotEmpty) {
        await tester.tap(pick.first);
        await _settle(tester, 2);
        await tester.ensureVisible(find.byKey(const Key('battlePut')));
        await tester.tap(find.byKey(const Key('battlePut')));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
        await _settle(tester, 3);
      }
      await _shot(tester, '${n}_07_스킬_강타뺌_알림');
      await _done(tester);
      // 직업 탭: Lv.20 (4단계 잠김) · Lv.50 끝까지 · 직업 숙련
      late AppController l20;
      await tester.runAsync(() async {
        l20 = await startVillage(24, farewell: true, more: t85.awakened());
        final s = JobRules.info(JobId.warrior).skills.first;
        await l20.raiseSkill(s);
        await l20.raiseSkill(s);
      });
      await _page(tester, SkillScreen(key: ObjectKey('j$n'), controller: l20, tab: 1));
      await tester.tap(find.byKey(Key('jobSkillTile_${JobRules.info(JobId.warrior).skills.first.name}')));
      await _settle(tester, 3);
      await _shot(tester, '${n}_08_스킬_4단계_Lv25에열려요');
      await _page(tester, SkillScreen(key: ObjectKey('m$n'), controller: lv25, tab: 1));
      await _shot(tester, '${n}_09_스킬_5단계_직업숙련');
      await _done(tester);
    });

    testWidgets('b85 $n: 3 첫 펫 보내기', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async {
        c = await startVillage(15, more: {
          'pets': PetState(
            pets: [
              Pet(uid: 'p1', species: PetSpecies.owl, name: '부엉', bornAt: DateTime(2026, 11, 1)),
              Pet(uid: 'p2', species: PetSpecies.blackCat, name: '나비', bornAt: DateTime(2026, 11, 3)),
            ],
            companion: 'p1',
            firstPet: 'p1',
            firstSpiritName: '불씨',
            farewellAt: DateTime(2026, 11, 2),
          ).toJson(),
        });
      });
      await _page(tester, PetScreen(key: ObjectKey('pp$n'), controller: c));
      final rel = find.byKey(const Key('petRelease_p1'));
      await tester.ensureVisible(rel);
      await tester.tap(rel);
      await _settle(tester, 3);
      await tester.tap(find.text('돌려보내기'));
      await _settle(tester, 3);
      await _shot(tester, '${n}_10_첫펫_보내기_확인');
      await tester.tap(find.text('보내기'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await _settle(tester, 4);
      await _shot(tester, '${n}_11_첫펫_보낸뒤');
      final last = find.byKey(const Key('petRelease_p2'));
      await tester.ensureVisible(last);
      await tester.tap(last);
      await _settle(tester, 2);
      await _shot(tester, '${n}_12_마지막한마리_알림');
      await _done(tester);
      // 원정 중
      late AppController away;
      await tester.runAsync(() async {
        away = await startVillage(15, more: {
          'pets': PetState(
            pets: [
              Pet(uid: 'p1', species: PetSpecies.owl, name: '부엉', bornAt: DateTime(2026, 11, 1)),
              Pet(uid: 'p2', species: PetSpecies.blackCat, name: '나비', bornAt: DateTime(2026, 11, 3)),
            ],
            companion: 'p1',
            firstPet: 'p1',
            firstSpiritName: '불씨',
            farewellAt: DateTime(2026, 11, 2),
          ).toJson(),
          'training': {'v': 1, 'pet': 'p2', 'petEnd': vt0.add(const Duration(hours: 2)).toIso8601String()},
        });
      });
      await _page(tester, PetScreen(key: ObjectKey('pa$n'), controller: away));
      final t = find.byKey(const Key('petRelease_p2'));
      await tester.ensureVisible(t);
      await tester.tap(t);
      await _settle(tester, 2);
      await _shot(tester, '${n}_13_훈련중_알림');
      await _done(tester);
    });

    testWidgets('b85 $n: 4 아래 탭 4개 · 프로필 도감 · 도감', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async {
        c = await t84.longAccount(5, () => DateTime(2026, 11, 23, 10));
      });
      await _page(tester, ProfileScreen(key: ObjectKey('pr$n'), controller: c));
      await _shot(tester, '${n}_14_프로필_도감버튼');
      await tester.tap(find.byKey(const Key('profileCodex')));
      await _settle(tester, 4);
      await _shot(tester, '${n}_15_도감_뒤로가기');
      await _done(tester);
      await _page(tester, Scaffold(
          body: Stack(children: [
            Positioned(top: d.$4 / d.$3 + 6, left: 12, child: ProfileButton(look: HeroLook.male, level: 12, dot: true, onTap: () {})),
          ]),
          bottomNavigationBar: OrnateNavBar(index: 2, onTap: (_) {})));
      await _shot(tester, '${n}_16_얼굴_빨간점');
      await _done(tester);
    });

    testWidgets('b85 $n: 5 가방 · 약초밭', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async {
        c = await startVillage(9, gains: {'slimeJelly': 3, 'herb': 2});
      });
      await _page(tester, Scaffold(body: BagTab(key: ObjectKey('b$n'), controller: c)));
      await _shot(tester, '${n}_17_가방_막대없음_정령줄없음');
      await _done(tester);
      final t0 = vt0;
      late AppController g;
      await tester.runAsync(() async {
        GardenPlot at(String seed, Duration ago) =>
            GardenPlot(seed: seed, day: '2026-11-14', steps: 0, at: t0.subtract(ago).millisecondsSinceEpoch);
        g = await startVillage(12, clock: () => t0, village: {
          'seen': ['gardenCard'],
        }, more: {
          'garden': GardenState(plots: {
            0: at('herbSeed', const Duration(days: 2)),
            1: at('flowerSeed', const Duration(days: 2)),
            2: at('sporeSeed', const Duration(days: 2)),
          }, starter: true).toJson(),
        });
      });
      await _page(tester, GardenScreen(key: ObjectKey('g$n'), controller: g));
      await _shot(tester, '${n}_18_약초밭_씨앗마다그림');
      await _done(tester);
      late AppController g2;
      await tester.runAsync(() async {
        GardenPlot at(String seed, Duration ago) =>
            GardenPlot(seed: seed, day: '2026-11-14', steps: 0, at: t0.subtract(ago).millisecondsSinceEpoch);
        g2 = await startVillage(12, clock: () => t0, village: {
          'seen': ['gardenCard'],
        }, more: {
          'garden': GardenState(plots: {
            0: at('glowSeed', const Duration(days: 3)),
            1: at('sporeSeed', const Duration(hours: 5)),
            2: at('herbSeed', const Duration(minutes: 10)),
          }, starter: true).toJson(),
        });
      });
      await _page(tester, GardenScreen(key: ObjectKey('g2$n'), controller: g2));
      await _shot(tester, '${n}_19_약초밭_빛씨앗_버섯자람');
      await _done(tester);
    });

    testWidgets('b85 $n: 6 하이랜드 1층 기둥 없음 · 계단 찾음', (tester) async {
      _device(tester, d);
      late AppController c1;
      await tester.runAsync(() async {
        final slot = t83.slotNowAm();
        c1 = await t83.onIsland(isle: Isle.wind, guideSeen: false);
        expect(slot, isNotNull);
      });
      await _page(tester, HighlandScreen(key: ObjectKey('h1$n'), controller: c1));
      await tester.tap(find.byKey(const Key('skyClimb')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await _settle(tester, 4);
      final b1 = c1.skyBoard!;
      final near = b1.neighbors4(b1.entrance).toList();
      for (var k = 0; k < 2 && k < near.length; k++) {
        final r = tester.getRect(find.byKey(Key('skyTile_${near[k]}')));
        await tester.tapAt(r.topCenter + Offset(0, r.height / 3));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
        await _settle(tester, 2);
        if (find.text('어딘가에 위층으로 가는 하늘 계단이 숨어 있어요').evaluate().isNotEmpty) break;
      }
      await _shot(tester, '${n}_20_하이랜드_1층_기둥없음_안내');
      await _done(tester);
      final b = SkyBoard.generate(21, 1);
      final path = _path(b, b.goal);
      late AppController c2;
      await tester.runAsync(() async {
        final slot = t83.slotNowAm();
        c2 = await t83.onIsland(
            isle: Isle.wind,
            climb: SkyClimb(slot: slot, seed: 21, wind: 6, opened: [b.entrance, ...path.sublist(0, path.length - 1)], hero: path[path.length - 2]),
            guideSeen: true);
      });
      await _page(tester, HighlandScreen(key: ObjectKey('h2$n'), controller: c2));
      await _shot(tester, '${n}_21_하이랜드_계단직전_기둥없음');
      final r = tester.getRect(find.byKey(Key('skyTile_${b.goal}')));
      await tester.tapAt(r.topCenter + Offset(0, r.height / 3));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await _settle(tester, 6);
      await _shot(tester, '${n}_22_하이랜드_계단찾음');
      await _done(tester);
    });

    testWidgets('b85 $n: 7 지도 돋보기 없음 · 직업 고르기 감정사 없음', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async {
        c = await startVillage(15, farewell: true);
      });
      await _page(tester, Scaffold(body: MapScreen(key: ObjectKey('mp$n'), controller: c)));
      await _shot(tester, '${n}_23_지도_돋보기버튼없음');
      await _done(tester);
      await _page(tester, Scaffold(body: SafeArea(child: JobPicker(key: ObjectKey('jp$n'), controller: c, onPick: (_) {}))));
      final craft = find.textContaining('생산');
      if (craft.evaluate().isNotEmpty) {
        await tester.tap(craft.first);
        await _settle(tester, 3);
      }
      await _shot(tester, '${n}_24_직업고르기_생산_감정사없음');
      await _done(tester);
    });
  }
}
