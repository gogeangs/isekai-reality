// 묶음 76 (build/screenshots/b76_*) — 큰 iPhone · SE

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
import 'package:isekai_reality/features/battle/hero_rig.dart' show WeaponKind;
import 'package:isekai_reality/features/bulssi/bulssi_mood.dart';
import 'package:isekai_reality/features/map/expedition_result.dart';
import 'package:isekai_reality/features/pets/pet_screen.dart';
import 'package:isekai_reality/features/status/status_screen.dart';
import 'package:isekai_reality/features/village/hatchery.dart';
import 'package:isekai_reality/features/jobs/guild_screen.dart';
import 'package:isekai_reality/features/profile/profile_screen.dart';
import 'package:isekai_reality/features/status/stat_screen.dart';
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
  File('build/screenshots/b76_$name.png')
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

Map<String, dynamic> _pets(List<PetEgg> eggs) => PetState(
      pets: [Pet(uid: 'p1', species: PetSpecies.owl, name: '부엉', exp: 1200, bornAt: DateTime(2026, 11, 1))],
      companion: 'p1',
      firstPet: 'p1',
      firstSpiritName: '불씨',
      farewellAt: DateTime(2026, 11, 2),
      eggs: eggs,
      nextId: 9,
    ).toJson();

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

    testWidgets('b76 $n: 1 상태 화면 직업 그림', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async => c = await startVillage(20));
      for (final (i, job, label) in [
        (1, null, '직업없음'),
        (2, 'warrior', '전사'),
        (3, 'archer', '궁수'),
        (4, 'mage', '마법사'),
        (5, 'priest', '사제'),
        (6, 'rogue', '도적'),
        (7, 'knight', '기사'),
        (8, 'mage', '연금술사_마법사그림'),
      ]) {
        final look = i.isEven ? HeroLook.female : HeroLook.male;
        await _page(tester, Scaffold(key: ObjectKey('st$n$i'), body: NightBackground(header: true, child: StatusScreen(player: c.player, look: look, heroJob: job))));
        await _shot(tester, '${n}_0${i}_상태_${label}_${look.name}');
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('b76 $n: 2 전투 직업 그림 대기 · 공격 4칸', (tester) async {
      _device(tester, d);
      for (final (i, job, look, weapon) in [
        (0, 'warrior', HeroLook.male, null),
        (1, 'mage', HeroLook.female, null),
        (2, 'archer', HeroLook.male, WeaponKind.bow),
      ]) {
        await _page(tester, _battle(_b(), job: job, look: look, weapon: weapon, tick: const Duration(seconds: 30)));
        await _shot(tester, '${n}_1${i}a_전투_${job}_대기');
        await _page(tester, _battle(_b(), job: job, look: look, weapon: weapon));
        await _until(tester, find.byKey(const Key('heroFrame_3')));
        await _shot(tester, '${n}_1${i}b_전투_${job}_공격4칸${find.byKey(const Key('fxArrow')).evaluate().isEmpty ? '_코드화살없음' : '_코드화살있음'}');
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('b76 $n: 3 원정 광고 두 배 뒤 · 부화장 · 먹이 주기 · 프로필', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async => c = await startVillage(11, farewell: true, more: {'pets': _pets(const [])}, gains: {
            'slimeJelly': 3,
            'bulssiPotion': 2,
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
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('adDouble')));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 800));
      await _shot(tester, '${n}_20_원정_두배받았어요');
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1500)));
      await _settle(tester, 3);
      for (final (k, eggs) in [
        ('빈둥지', <PetEgg>[]),
        ('알여러개', [
          PetEgg(id: 'e1', source: 'field', incubatedAt: vt0.subtract(const Duration(hours: 2))),
          PetEgg(id: 'e2', source: 'field', incubatedAt: vt0.subtract(const Duration(hours: 30))),
          const PetEgg(id: 'e3', source: 'field'),
        ]),
      ]) {
        late AppController h;
        await tester.runAsync(() async => h = await startVillage(11, farewell: true, more: {'pets': _pets(eggs)}));
        await _page(tester, Scaffold(key: ObjectKey('h$n$k'), body: NightBackground(child: SafeArea(child: Padding(padding: const EdgeInsets.all(12), child: HatcheryPanel(controller: h))))));
        await _shot(tester, '${n}_21_부화장_$k');
      }
      await _page(tester, PetScreen(key: ObjectKey('ps$n'), controller: c));
      await tester.tap(find.text('먹이 주기').first);
      await _settle(tester, 4);
      await _shot(tester, '${n}_22_먹이주기_간식그림');
      Navigator.of(tester.element(find.byKey(const Key('feedSnack')))).pop();
      await _settle(tester, 3);
      await _page(tester, ProfileScreen(key: ObjectKey('pf$n'), controller: c));
      await _shot(tester, '${n}_23_프로필_정보');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('b76 $n: 4 방어 태세 · 막기 버튼 · 막음 · 막기로 쓰러뜨림', (tester) async {
      _device(tester, d);
      // 방어 태세 (허수아비)
      final s = _b(m: MonsterId.dummy, skills: true)..stanceTurns = 3;
      await _page(tester, _battle(s, job: 'knight', tick: const Duration(seconds: 30)));
      await _shot(tester, '${n}_30_방어태세_방패');
      // 보스 경고 → 「막기!」
      final b = _b(m: MonsterId.fireSlimeKing, boss: true, skills: true);
      b.tick();
      b.tick();
      b.bashCharge = Battle.bashTicks;
      await _page(tester, _battle(b, job: 'warrior', tick: const Duration(milliseconds: 1600)));
      await _shot(tester, '${n}_31_경고_막기버튼_강타쉼_HP한줄');
      await tester.tapAt(tester.getCenter(find.byKey(const Key('guardButton'))));
      await tester.pump(const Duration(milliseconds: 100));
      await _shot(tester, '${n}_32_막기준비');
      if (await _until(tester, find.byKey(const Key('fxGuardHit')))) {
        await tester.pump(const Duration(milliseconds: 120));
        await _shot(tester, '${n}_33_막음');
      }
      // 막지 못함 (깨짐)
      final k = _b(m: MonsterId.fireSlimeKing, boss: true, skills: true)
        ..tick()
        ..tick();
      await _page(tester, _battle(k, job: 'mage', look: HeroLook.female, tick: const Duration(milliseconds: 1600)));
      if (await _until(tester, find.byKey(const Key('fxGuardBreak')), max: 200)) {
        await tester.pump(const Duration(milliseconds: 80));
        await _shot(tester, '${n}_34_깨짐');
      }
      // 막기로 보스를 쓰러뜨린 순간
      final w = Battle(
        playerMaxHp: 100000,
        playerAttack: 3000,
        floors: const [Foe(monster: MonsterId.fireSlimeKing, maxHp: 8800, attack: 20)],
        rng: math.Random(3),
        telegraphs: true,
        heroSkills: true,
      )
        ..tick()
        ..tick();
      await _page(tester, _battle(w, job: 'warrior', tick: const Duration(milliseconds: 1600)));
      if (find.byKey(const Key('guardButton')).evaluate().isNotEmpty) {
        await tester.tapAt(tester.getCenter(find.byKey(const Key('guardButton'))));
      }
      if (await _until(tester, find.byKey(const Key('guardText')), max: 200)) {
        await tester.pump(const Duration(milliseconds: 60));
        await _shot(tester, '${n}_35_막기로쓰러뜨림_완벽한막기');
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        await _shot(tester, '${n}_36_막기로쓰러뜨림_사냥');
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('b76 $n: 5 직업 고르기', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async => c = await startVillage(15, farewell: true, more: {
            'mastery': {
              'big': {'trade': 50.0, 'combat': 5.0},
            },
          }));
      await _page(tester, JobAwakenScreen(key: ObjectKey('ja$n'), controller: c));
      await tester.tap(find.byKey(const Key('jobAwakenGo')));
      await _settle(tester, 4);
      await _shot(tester, '${n}_40_직업고르기_처음_추천상인');
      await tester.tap(find.byKey(const Key('jobTabCombat')));
      await _settle(tester, 2);
      await tester.tap(find.byKey(const Key('jobPick_archer')));
      await _settle(tester, 3);
      await _shot(tester, '${n}_41_전투탭_궁수_추천은띠');
      final first = JobRules.firstOf(JobId.archer);
      await tester.ensureVisible(find.byKey(Key('jobSkill_${first.name}')));
      await tester.tap(find.byKey(Key('jobSkill_${first.name}')));
      await _settle(tester, 3);
      await _shot(tester, '${n}_42_스킬_전투');
      await tester.tap(find.byKey(const Key('jobTabCraft')));
      await _settle(tester, 2);
      await tester.ensureVisible(find.byKey(const Key('jobPick_blacksmith')));
      await tester.tap(find.byKey(const Key('jobPick_blacksmith')));
      await _settle(tester, 2);
      final life = JobRules.info(JobId.blacksmith).skills.firstWhere((x) => !JobRules.skill(x).isBattle);
      await tester.ensureVisible(find.byKey(Key('jobSkill_${life.name}')));
      await tester.tap(find.byKey(Key('jobSkill_${life.name}')));
      await _settle(tester, 3);
      await _shot(tester, '${n}_43_대장장이_7칸_생활스킬');
      await tester.tap(find.byKey(const Key('jobPickMain')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await _settle(tester, 6);
      await _shot(tester, '${n}_44_길이열렸어요');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('b76 $n: 6 주 스탯', (tester) async {
      _device(tester, d);
      for (final (i, job, subs) in [
        (0, 'mage', ['merchant']),
        (1, 'knight', <String>[]),
      ]) {
        late AppController c;
        await tester.runAsync(() async => c = await startVillage(20, more: {'jobs': _jobs(job, subs: subs)}));
        await _page(tester, StatScreen(key: ObjectKey('ss$n$i'), controller: c));
        await _shot(tester, '${n}_5${i}_스탯분배_$job');
        if (i == 0) {
          await _page(tester, GuildScreen(key: ObjectKey('gs$n'), controller: c));
          await _shot(tester, '${n}_52_조합_직업요약');
        }
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  }
}
