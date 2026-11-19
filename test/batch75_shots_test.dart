// 묶음 75 (build/screenshots/b75_*) — 큰 iPhone · SE

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/armory.dart';
import 'package:isekai_reality/core/models/mail_state.dart';
import 'package:isekai_reality/core/models/pet_state.dart';
import 'package:isekai_reality/core/models/vitals.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/alchemy/alchemy_screen.dart';
import 'package:isekai_reality/features/chat/chat_screens.dart';
import 'package:isekai_reality/features/jobs/skill_screen.dart';
import 'package:isekai_reality/features/mail/mail_screen.dart';
import 'package:isekai_reality/features/pets/companion_pet_panel.dart';
import 'package:isekai_reality/features/pets/egg_news.dart';
import 'package:isekai_reality/features/profile/profile_screen.dart';
import 'package:isekai_reality/features/profile/title_celebration.dart';
import 'package:isekai_reality/features/smithy/boss_gear_tab.dart';
import 'package:isekai_reality/features/status/status_screen.dart';
import 'package:isekai_reality/features/town/bag_tab.dart';
import 'package:isekai_reality/features/town/shop_screen.dart';
import 'package:isekai_reality/features/village/training_screen.dart';
import 'package:isekai_reality/features/village/village_screen.dart';
import 'package:isekai_reality/theme/ornaments.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/location/location_source.dart';
import 'package:isekai_reality/features/map/korea_area.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'batch70_test.dart' as b70;

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
  File('build/screenshots/b75_$name.png')
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





/// 연금술 계정 (가마솥 3 · 하나는 끓는 중)
Future<AppController> alchemyAccount({bool boiling = true}) => startVillage(14, more: {
      'alchemy': {
        'discovered': ['healSmall', 'heal', 'manaSmall', 'antidote', 'strength', 'resistFire', 'weaponFire'],
        'noted': ['clearEye'],
        'bestMade': ['healSmall'],
        'cauldrons': 3,
        'brews': {
          if (boiling)
            '1': {
              'put': ['herb', 'herb', 'slimeJelly'],
              'startedAt': vt0.subtract(const Duration(minutes: 4)).toIso8601String(),
              'readyAt': vt0.add(const Duration(minutes: 3)).toIso8601String()
            },
        },
      },
    }, gains: {
      MaterialId.herb.name: 6,
      MaterialId.gortRoot.name: 2,
      MaterialId.slimeJelly.name: 4,
      MaterialId.fireJelly.name: 2,
      MaterialId.batWing.name: 3,
      MaterialId.lightRelic.name: 1,
      MaterialId.ironShard.name: 5,
      MaterialId.ratHide.name: 2,
      MaterialId.springPetal.name: 2,
      'gold': 2000,
    });

/// 선반 재료를 눌러 넣고 (작은 화면은 내려서) 가마솥이 보이게 다시 올림
Future<void> _put(WidgetTester tester, String m) async {
  final f = find.byKey(Key('shelf_$m'));
  await tester.ensureVisible(f);
  await _settle(tester, 2);
  await tester.tap(f);
  await _settle(tester, 5);
  final pot = find.byKey(const Key('cauldronPot'));
  if (pot.evaluate().isNotEmpty) {
    await tester.drag(pot.first, const Offset(0, 900));
    await _settle(tester, 3);
  }
}

Pet _pet(String uid, PetSpecies s, String name, {int exp = 900}) =>
    Pet(uid: uid, species: s, name: name, exp: exp, bornAt: DateTime(2026, 11, 1));

/// 펫 [n]마리 (첫 펫 부엉), 알 [eggs]
Map<String, dynamic> _pets(int n, {List<PetEgg> eggs = const []}) {
  const kinds = [
    (PetSpecies.owl, '부엉'),
    (PetSpecies.blackCat, '까망'),
    (PetSpecies.wolf, '늑이'),
    (PetSpecies.golem, '돌콩'),
    (PetSpecies.dragon, '용용'),
    (PetSpecies.toad, '두꺼비'),
    (PetSpecies.lizard, '도마'),
  ];
  return PetState(
    pets: [for (var i = 0; i < n; i++) _pet('p${i + 1}', kinds[i % kinds.length].$1, kinds[i % kinds.length].$2)],
    companion: 'p1',
    firstPet: 'p1',
    firstSpiritName: '불씨',
    farewellAt: DateTime(2026, 11, 2),
    eggs: eggs,
    nextId: 20,
  ).toJson();
}

Future<AppController> _bossAccount({required bool smith}) async {
  final c = AppController(
    area: KoreaArea.area,
    store: InMemoryRecordStore(
      profile: const PlayerProfile(name: '하루', lastSeenLevel: 99),
      json: {
        'tutorial': {'step': TutorialStep.done.index},
        if (smith) 'jobs': {'main': 'blacksmith'},
      },
      history: [
        DailyRecord(
          date: DateTime(2026, 11, 10),
          purifiedMonsterIds: const ['labyrinthWarden'],
          gains: {
            'exp': LevelRules.totalExpToReach(20),
            Wallet.gold: 5000,
            MaterialId.bossShard.name: 20,
            MaterialId.bossWardenHeart.name: 5,
          },
        ),
      ],
    ),
    health: FakeHealthSource(stepsByDay: const {}),
    location: FakeLocationSource(),
    clock: () => DateTime(2026, 11, 11, 14),
  )..mailSources = const [];
  await c.init();
  return c;
}

MailItem _mail(int i, {Map<String, int> gifts = const {}, bool claimed = false, Map<String, int> taken = const {}}) => MailItem(
      id: 'm$i',
      kind: MailKind.reward,
      from: i.isEven ? '하르트' : '여명의 탑 운영실',
      title: i.isEven ? '의뢰 보상이 도착했어요' : '점검 보상 $i',
      body: '수고 많았어요. 선물을 받아 가세요.',
      gifts: gifts,
      sentAt: vt0.subtract(Duration(hours: i * 3)),
      expiresAt: vt0.add(const Duration(days: 20)),
      claimed: claimed,
      read: i > 2,
      taken: taken,
    );

Widget _scaffold(Widget child) => Scaffold(body: NightBackground(header: true, child: child));

void main() {
  setUpAll(_loadFonts);
  setUp(() => b56.now = b52.t0);

  for (final d in [_devices[1], _devices[0]]) {
    final n = d.$1;

    testWidgets('b75 $n: 1 작업대', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async => c = await alchemyAccount());
      await _page(tester, AlchemyScreen(key: ObjectKey('al$n'), controller: c));
      await _shot(tester, '${n}_01_작업대_빈가마솥');
      await _put(tester, 'herb');
      await _put(tester, 'herb');
      await _shot(tester, '${n}_02_작업대_재료2개_레시피중간');
      await _put(tester, 'slimeJelly');
      await _shot(tester, '${n}_03_작업대_맞는레시피');
      await _put(tester, 'lightRelic');
      await _shot(tester, '${n}_04_작업대_특산물');
      await tester.tap(find.byKey(const Key('benchNext')).first);
      await _settle(tester, 6);
      await _shot(tester, '${n}_05_작업대_끓는중');
      await tester.tap(find.byKey(const Key('recipeOpen')));
      await _settle(tester, 4);
      await _shot(tester, '${n}_06_레시피창');
      await tester.tap(find.byKey(const Key('recipeTile_antidote')));
      await _settle(tester, 4);
      await _shot(tester, '${n}_07_레시피_상세');
      Navigator.of(tester.element(find.byKey(const Key('recipeFill')))).pop();
      await _settle(tester, 3);
      await tester.tap(find.byKey(const Key('recipeTile_healSmall')));
      await _settle(tester, 4);
      await tester.tap(find.byKey(const Key('recipeFill')));
      await _settle(tester, 10);
      await _shot(tester, '${n}_08_채우기_뒤');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('b75 $n: 2 알 · 가방 · 팔기 격자', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async => c = await startVillage(14, farewell: true, more: {
            'pets': _pets(1, eggs: const [
              PetEgg(id: 'e1', source: 'field', grade: EggGrade.rare),
              PetEgg(id: 'e2', source: 'dungeon', grade: EggGrade.hero),
              PetEgg(id: 'e3', source: 'board', grade: EggGrade.legend),
              PetEgg(id: 'e4', source: 'field'),
            ]),
          }, gains: {
            MaterialId.herb.name: 6,
            MaterialId.slimeJelly.name: 4,
            MaterialId.batWing.name: 3,
            MaterialId.ironShard.name: 5,
            MaterialId.ratHide.name: 2,
            'gold': 800,
          }));
      await _page(
          tester,
          _scaffold(Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('전투 보상 맨 앞', style: AppText.title(16)),
            const SizedBox(height: 12),
            const EggGotBanner(grade: EggGrade.hero, farewell: true),
          ]))));
      await _shot(tester, '${n}_10_알_얻음띠_영웅');
      await _page(
          tester,
          _scaffold(Builder(
              builder: (ctx) => Center(
                  child: TextButton(
                      onPressed: () => showEggGotDialog(ctx, c, EggGrade.legend), child: const Text('열기'))))));
      await tester.tap(find.text('열기'));
      await _settle(tester, 6);
      await _shot(tester, '${n}_11_알_얻음창_전설');
      await _page(tester, _scaffold(BagTab(key: ObjectKey('bag$n'), controller: c)));
      await _shot(tester, '${n}_12_가방_등급알');
      await _page(tester, ShopScreen(key: ObjectKey('shop$n'), controller: c));
      await tester.tap(find.byKey(const Key('shopTab_1')));
      await _settle(tester, 4);
      for (final k in ['sellRow_herb', 'sellRow_slimeJelly']) {
        final f = find.byKey(Key(k));
        if (f.evaluate().isNotEmpty) {
          await tester.tap(f.first, warnIfMissed: false);
          await _settle(tester, 3);
        }
      }
      await _shot(tester, '${n}_13_잡화상_팔기격자_일부고름');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('b75 $n: 3 상태 내 펫 · 주인공 얼굴 · 프로필', (tester) async {
      _device(tester, d);
      for (final k in [1, 4, 7]) {
        late AppController c;
        await tester.runAsync(() async {
          c = await startVillage(14, farewell: true, more: {
            'pets': _pets(k),
            if (k == 4) 'training': {'pet': 'p3', 'petEnd': vt0.add(const Duration(hours: 2)).toIso8601String(), 'petDay': '2026-11-16'},
          });
          if (k >= 4) {
            await c.store.saveVitals(Vitals(expeditions: [
              Expedition(
                spawnId: 's1',
                monster: MonsterId.slime.name,
                lat: 37.5,
                lng: 127,
                distanceM: 300,
                mpCost: 5,
                startedAt: vt0.subtract(const Duration(minutes: 3)),
                arriveAt: vt0.add(const Duration(minutes: 5)),
                returnAt: vt0.add(const Duration(minutes: 12)),
                petUid: 'p2',
                petName: '까망',
              ),
            ]));
            await c.init();
          }
        });
        await _page(
            tester,
            _scaffold(StatusScreen(
                key: ObjectKey('st$n$k'),
                player: c.player,
                look: c.profile.look,
                requestPanel: CompanionPetPanel(controller: c))));
        final grid = find.byKey(const Key('statusPetGrid'));
        if (grid.evaluate().isNotEmpty) {
          await tester.ensureVisible(grid);
          await _settle(tester, 3);
        }
        await _shot(tester, '${n}_2${k == 1 ? 0 : k == 4 ? 1 : 2}_상태_내펫_$k마리');
      }
      late AppController c;
      await tester.runAsync(() async => c = await startVillage(14, farewell: true, more: {'pets': _pets(2)}));
      await _page(
          tester,
          Scaffold(
              body: NightBackground(
                  header: true,
                  child: Stack(children: [
            Positioned.fill(child: StatusScreen(key: ObjectKey('sh$n'), player: c.player, look: c.profile.look)),
            Positioned(
                top: MediaQuery.paddingOf(tester.element(find.byType(Scaffold).first)).top + 6,
                left: 12,
                child: ProfileButton(look: c.profile.look, level: 14, face: c.avatarFace)),
          ]))));
      await _shot(tester, '${n}_23_상태_주인공얼굴');
      await _page(tester, ProfileScreen(key: ObjectKey('pf$n'), controller: c));
      await _shot(tester, '${n}_24_프로필_정보');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('b75 $n: 4 말풍선 · 건설 중', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async => c = await startVillage(14, farewell: true, more: {'pets': _pets(1)}));
      await _page(tester, Scaffold(key: ObjectKey('v$n'), body: VillageScreen(controller: c)));
      await _shot(tester, '${n}_30_마을_정령말풍선');
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await _settle(tester, 2);
      await _shot(tester, '${n}_31_마을_5초뒤');
      await _page(tester, ShopScreen(key: ObjectKey('mina$n'), controller: c));
      await _shot(tester, '${n}_32_잡화상_미나말풍선');
      late AppController low;
      await tester.runAsync(() async => low = await startVillage(1, village: {'seen': ['intro']}));
      await _page(tester, Scaffold(key: ObjectKey('low$n'), body: VillageScreen(controller: low)));
      await _shot(tester, '${n}_33_건설중_건물');
      await tester.tap(find.byKey(const Key('locked_smithy')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await _shot(tester, '${n}_34_건설중_누른띠');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('b75 $n: 5 보스 장비 대장장이 · 아님', (tester) async {
      _device(tester, d);
      for (final smith in [true, false]) {
        late AppController c;
        await tester.runAsync(() async => c = await _bossAccount(smith: smith));
        await _page(tester, _scaffold(SafeArea(child: ListView(padding: const EdgeInsets.all(12), children: [BossGearTab(key: ObjectKey('bg$n$smith'), controller: c)]))));
        await _shot(tester, '${n}_4${smith ? 0 : 1}_보스장비_${smith ? '대장장이' : '아님'}');
        if (!smith) {
          final f = find.byKey(const Key('bossCraftLocked_wardenWeapon'));
          if (f.evaluate().isNotEmpty) {
            await tester.tap(f.first, warnIfMissed: false);
            await _settle(tester, 3);
            await _shot(tester, '${n}_42_보스장비_대장장이만_안내');
          }
        }
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('b75 $n: 6 속성 허수아비 연습', (tester) async {
      _device(tester, d);
      const target = Element.wind;
      final weak = ElementRules.beats(target).first;
      late AppController c;
      await tester.runAsync(() async => c = await startVillage(16, more: {
            'armory': Armory(items: [
              EquipItem(uid: 'w1', base: EquipBase.dagger, grade: EquipGrade.blue, element: weak, elementLevel: 3),
            ], equipped: const {EquipSlot.weapon: 'w1'}, nextId: 2).toJson(),
            'training': {'practiceBest': {TrainingRules.practiceKey(DummyKind.element, target): 3}},
          }));
      await _page(
          tester,
          TrainingBattleScreen(
              key: ObjectKey('tb$n'),
              controller: c,
              mode: TrainingMode.practice,
              dummy: DummyKind.element,
              element: target,
              tickInterval: const Duration(milliseconds: 500)));
      await _shot(tester, '${n}_50_허수아비_대기');
      var hint = false;
      for (var i = 0; i < 40 && !hint; i++) {
        await tester.pump(const Duration(milliseconds: 250));
        hint = find.byKey(const Key('hintGood')).evaluate().isNotEmpty;
      }
      await _shot(tester, '${n}_51_허수아비_맞음${hint ? '_효과좋음' : ''}');
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      await tester.tap(find.byKey(const Key('practiceStop')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await _settle(tester, 6);
      await _shot(tester, '${n}_52_연습결과');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('b75 $n: 7 스킬 숙련 · 정령 한마디 · 짝 칭호', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async {
        c = await startVillage(16, farewell: true, more: {'pets': _pets(1)});
        await c.gainSkillUses({'bash': 300, 'stance': 12});
      });
      await _page(tester, SkillScreen(key: ObjectKey('sk$n'), controller: c));
      await _shot(tester, '${n}_60_스킬_익숙한_장인');
      late AppController v;
      await tester.runAsync(() async {
        v = await startVillage(14);
        await v.gainSkillUses({'bash': 10});
      });
      await _page(tester, Scaffold(key: ObjectKey('vv$n'), body: VillageScreen(controller: v)));
      await _shot(tester, '${n}_61_정령_강타가손에익었어');
      await _page(
          tester,
          _scaffold(Builder(
              builder: (ctx) => Center(
                  child: TextButton(
                      onPressed: () => showTitleCelebration(ctx, c, TitleId.pairRunesmith), child: const Text('열기'))))));
      await tester.tap(find.text('열기'));
      await _settle(tester, 6);
      await _shot(tester, '${n}_62_칭호_룬대장장이를');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('b75 $n: 8 우편 선물 그림 · 쪽', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async => c = await startVillage(14, more: {
            'mail': MailState(mails: [
              _mail(0, gifts: const {'gold': 300, 'manaStone': 5, 'exp': 120, 'note': 1, 'egg:hero': 1, 'herb': 4, 'tools': 1}),
              _mail(1, gifts: const {'slimeJelly': 3, 'item:healSmall': 2}, taken: const {'gold': 100, 'egg:rare': 1}),
              _mail(2, gifts: const {'gold': 50}),
              for (var i = 3; i < 40; i++) _mail(i, gifts: i % 7 == 0 ? const {'gold': 30} : const {}, claimed: i % 7 != 0),
            ]).toJson(),
          }));
      await _page(tester, MailScreen(key: ObjectKey('ml$n'), controller: c));
      await _shot(tester, '${n}_70_우편_1쪽');
      await tester.tap(find.byKey(const Key('mailPage_3')));
      await _settle(tester, 3);
      await _shot(tester, '${n}_71_우편_마지막쪽');
      await tester.tap(find.byKey(const Key('mailPage_1')));
      await _settle(tester, 3);
      await tester.tap(find.byKey(const Key('mailRow_m0')));
      await _settle(tester, 6);
      await _shot(tester, '${n}_72_우편_선물그림');
      Navigator.of(tester.element(find.byKey(const Key('mailGifts')))).pop();
      await _settle(tester, 4);
      await tester.tap(find.byKey(const Key('mailRow_m1')));
      await _settle(tester, 6);
      await _shot(tester, '${n}_73_우편_일부받음');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('b75 $n: 9 프로필 사진 · 세계 대화', (tester) async {
      _device(tester, d);
      late AppController c;
      late dynamic a;
      await tester.runAsync(() async {
        final r = await b70.chatAt(14);
        c = r.$1;
        a = r.$2;
        a.chatRulesSeen = true;
      });
      await _page(tester, ProfileScreen(key: ObjectKey('pp$n'), controller: c));
      await tester.tap(find.byKey(const Key('profileFace')));
      await _settle(tester, 6);
      await _shot(tester, '${n}_80_프로필사진창');
      await tester.tap(find.byKey(const Key('avatarTab_title')));
      await _settle(tester, 3);
      await _shot(tester, '${n}_81_프로필사진_배지탭');
      await tester.runAsync(() async {
        a.chatPeople['u_sol'] = {...(a.chatPeople['u_sol'] as Map? ?? {'name': '솔'}), 'face': 'pet_owl_adult'};
        a.chatPeople['u_ria'] = {'name': '리아', 'level': 18, 'face': 'npc_marta'};
        a.chatSay('server', 'u_sol', '펫 얼굴로 바꿨어요!');
        a.chatSay('server', 'u_ria', '마르타 아주머니 얼굴이네요 ㅎㅎ');
        await c.refreshChat();
      });
      await _page(tester, ChatRoomScreen(key: ObjectKey('cr$n'), controller: c, room: 'server', name: '세계', kind: 'server'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await _settle(tester, 6);
      await _shot(tester, '${n}_82_세계대화_얼굴');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 20));
    });
  }
}
