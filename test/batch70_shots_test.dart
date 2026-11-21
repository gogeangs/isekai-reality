// 묶음 70 (build/screenshots/b70_*)
// 작은 iPhone(SE) · 큰 iPhone · Android

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/geo/geo.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/models/pet_state.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/location/location_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/alchemy/alchemy_screen.dart';
import 'package:isekai_reality/features/battle/dungeon_screen.dart';
import 'package:isekai_reality/features/chat/chat_screens.dart';
import 'package:isekai_reality/features/chat/chat_tour.dart';
import 'package:isekai_reality/features/codex/codex_screen.dart';
import 'package:isekai_reality/features/mail/mail_screen.dart';
import 'package:isekai_reality/features/map/expedition_sheet.dart';
import 'package:isekai_reality/features/map/korea_area.dart';
import 'package:isekai_reality/features/smithy/smithy_screen.dart';
import 'package:isekai_reality/features/town/shop_screen.dart';
import 'package:isekai_reality/features/tutorial/feature_tour.dart';
import 'package:isekai_reality/features/village/board_screen.dart';
import 'package:isekai_reality/theme/ornaments.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'batch52_test.dart' as b52;
import 'batch56_test.dart' as b56;
import 'batch70_test.dart' as b70;
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
  File('build/screenshots/b70_$name.png')
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


Future<void> _tapShot(WidgetTester tester, Key k, String name) async {
  await tester.tap(find.byKey(k).first);
  await _settle(tester, 3);
  await _shot(tester, name);
}

class _Location implements LocationSource {
  final _c = StreamController<LocationFix>.broadcast();
  void emit(LocationFix f) => _c.add(f);
  @override
  Future<bool> requestPermission() async => true;
  @override
  Stream<LocationFix> fixes() => _c.stream;
}

/// 안내가 알아보는 화면 이름 (앱처럼 내비게이터 관찰)
Future<void> _app(WidgetTester tester, Widget home, AppController c, {bool tour = false}) async {
  await tester.pumpWidget(RepaintBoundary(
    key: _root,
    child: MaterialApp(
        debugShowCheckedModeBanner: false,
        navigatorKey: tourBridge.navKey,
        navigatorObservers: [TourObserver()],
        builder: (context, child) => TopNoticeHost(
            child: Stack(children: [
          Positioned.fill(child: child!),
          if (tour) Positioned.fill(child: ChatTourLayer(controller: c)),
        ])),
        home: home),
  ));
  await _settle(tester);
}

void main() {
  setUpAll(_loadFonts);
  setUp(() => b56.now = b52.t0);

  for (final d in _devices) {
    final n = d.$1;

    testWidgets('b70 $n: Lv.8 친구 장면 (로그인 안 함 · 함) · 친구 화면 · 초대 보상 우편 · 버튼', (tester) async {
      _device(tester, d);
      final dummy = await tester.runAsync(() => startVillage(8));
      await _page(
          tester,
          Scaffold(
              body: NightBackground(
                  child: Center(
                      child: SpiritLineAlert(
                          spiritName: '불씨',
                          line: '요즘 걷는 길이 좀 심심하지 않아? 함께 걸을 친구가 있으면 더 멀리 갈 수 있을 거야!',
                          actions: [(const Key('a'), '응!', () {})])))));
      await _shot(tester, '${n}_01_Lv8_친구장면');
      await _page(
          tester,
          Scaffold(
              body: NightBackground(
                  child: Center(
                      child: SpiritLineAlert(
                          spiritName: '불씨',
                          line: '친구를 사귀려면 기록을 지켜 둬야 해!',
                          actions: [(const Key('a'), '로그인', () {}), (const Key('b'), '나중에', () {})])))));
      await _shot(tester, '${n}_02_Lv8_로그인안함');
      // 로그인했으면 친구 화면 안내
      late AppController c;
      await tester.runAsync(() async {
        final r = await b70.chatAt(9);
        c = r.$1;
        r.$2
          ..chatInvited = 3
          ..chatInvitePaid = 2
          ..chatFriends.add('u_sol')
          ..chatRequests.add('u_bam')
          ..inbox.add({
            'id': 'inv1',
            'from': '하르트',
            'title': '친구 초대 보상',
            'body': '초대한 솔님이 Lv.5가 됐다네. 길동무를 데려와 줘서 고맙네!',
            'reward': {'gold': 300, 'manaStone': 5, 'item:bulssiPotion': 1},
            'equips': [],
          });
        await c.refreshChat();
      });
      friendTourOn.value = true;
      await _page(tester, ChatHubScreen(key: ObjectKey('h$n'), controller: c, tab: 1));
      await _settle(tester, 3);
      await _shot(tester, '${n}_03_Lv8_친구화면_안내');
      friendTourOn.value = false;
      await _settle(tester, 2);
      await _shot(tester, '${n}_04_친구화면_초대한친구');
      await tester.runAsync(() async => c.checkInquiryInbox());
      await _page(tester, MailScreen(key: ObjectKey('ml$n'), controller: c));
      await _shot(tester, '${n}_05_초대보상_우편');
      // 버튼: Lv.7 없음 · Lv.9 친구 · Lv.11 말풍선
      final cs = <AppController>[];
      await tester.runAsync(() async {
        for (final lv in [7, 9, 11]) {
          final r = await b70.chatAt(lv);
          await r.$1.refreshChat();
          cs.add(r.$1);
        }
      });
      await _page(
          tester,
          Scaffold(
              body: NightBackground(
                  child: Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final (i, lv) in [7, 9, 11].indexed)
              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  SizedBox(width: 90, child: Text('Lv.$lv', style: AppText.title(18))),
                  SizedBox(width: 60, height: 50, child: Center(child: ChatButton(controller: cs[i]))),
                ]),
              ),
          ])))));
      await _shot(tester, '${n}_06_버튼_Lv7_9_11');
      expect(dummy, isNotNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 20));
    });

    testWidgets('b70 $n: Lv.11 「세계」 안내 ①~⑤', (tester) async {
      _device(tester, d);
      late AppController c;
      late dynamic a;
      await tester.runAsync(() async {
        final r = await b70.chatAt(11);
        c = r.$1;
        a = r.$2;
        a.chatRulesSeen = true;
        a.chatSay('server', 'u_sol', '다들 오늘 많이 걸었어요?');
        await c.refreshChat();
      });
      expect(c.chatTourPending, isTrue);
      tourBridge.tab = FeatureTourLayer.tStatus;
      await _app(
          tester,
          Scaffold(
              body: NightBackground(
                  header: true,
                  child: Stack(children: [
                    Positioned(top: MediaQuery.paddingOf(tester.element(find.byType(Container).first)).top + 6, right: 120, child: ChatButton(controller: c)),
                  ]))),
          c,
          tour: true);
      await _settle(tester, 4);
      await _shot(tester, '${n}_07_세계안내_1_말풍선');
      await tester.tap(find.byKey(const Key('chatButton')));
      await _settle(tester, 6);
      await _shot(tester, '${n}_08_세계안내_2_세계방');
      await tester.tap(find.byKey(const Key('chatRoom_server_server')));
      await _settle(tester, 6);
      await _shot(tester, '${n}_09_세계안내_3_안녕하세요');
      await tester.tap(find.byKey(const Key('chatQuick_0')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await _settle(tester, 6);
      await _shot(tester, '${n}_10_세계안내_4_잘했어');
      await tester.tap(find.byKey(const Key('chatTourButton')));
      await _settle(tester, 6);
      await _shot(tester, '${n}_11_세계안내_4_친구탭');
      await tester.tap(find.byKey(const Key('chatTourButton')));
      await _settle(tester, 4);
      await tester.runAsync(() async {
        a.inbox.add({
          'id': 'hello',
          'from': '하르트',
          'title': '첫 인사',
          'body': '세계에 처음 인사를 건넸구먼! 같이 걷는 각성자들이 반가워할 걸세.',
          'reward': {'gold': 100},
          'equips': [],
        });
        await c.checkInquiryInbox();
      });
      await _page(tester, MailScreen(key: ObjectKey('mh$n'), controller: c));
      await _shot(tester, '${n}_12_세계안내_5_첫인사_우편');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 20));
    });

    testWidgets('b70 $n: 도감 (조금 발견 · 새로 오른 칸 · 처음 발견 띠) · 펫 도감', (tester) async {
      _device(tester, d);
      await _page(
          tester,
          Scaffold(
              body: NightBackground(
                  header: true,
                  child: CodexScreen(
                    purifiedMonsters: {...MonsterId.values.where((m) => Monsters.codexGroup(m) == '필드').take(5), MonsterId.guardWind, MonsterId.goblinRaider},
                    fresh: const {'m:goblinRaider'},
                    highlandOpen: true,
                    petsSeen: const {PetSpecies.owl, PetSpecies.griffin, PetSpecies.wolf},
                    petsOpen: true,
                  ))));
      showTopNotice(tester.element(find.byType(CodexScreen)), '도감에 새로 올랐어요 · ${Monsters.info(MonsterId.goblinRaider).name}',
          icon: Icons.menu_book_rounded);
      await _settle(tester, 3);
      await _shot(tester, '${n}_13_도감_몬스터');
      await tester.tap(find.text('펫'));
      await _settle(tester, 3);
      await _shot(tester, '${n}_14_도감_펫');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('b70 $n: 원정 보내기 — 부엉이(날아서) · 다이어울프', (tester) async {
      _device(tester, d);
      final loc = _Location();
      late AppController c;
      late FieldSpawn s;
      await tester.runAsync(() async {
        final born = DateTime(2026, 11, 1);
        c = AppController(
          area: KoreaArea.area,
          store: InMemoryRecordStore(
            profile: const PlayerProfile(name: '하루'),
            history: [
              DailyRecord(date: DateTime(2026, 11, 10), gains: {'exp': LevelRules.totalExpToReach(16)}),
            ],
            json: {
              'tutorial': {'step': TutorialStep.done.index},
              'pets': PetState(
                farewellAt: born,
                pets: [
                  Pet(uid: 'p1', species: PetSpecies.owl, name: '부엉', bornAt: born),
                  Pet(uid: 'p2', species: PetSpecies.direwolf, name: '서리', bornAt: born),
                ],
                companion: 'p1',
                firstPet: 'p1',
                nextId: 3,
              ).toJson(),
            },
          ),
          health: FakeHealthSource(stepsByDay: const {}),
          location: loc,
          clock: () => DateTime(2026, 11, 11, 14),
          fallbackCenter: const GeoPoint(37.32, 126.83),
        )..mailSources = const [];
        await c.init();
        const here = GeoPoint(37.32, 126.83);
        loc.emit(const LocationFix(point: here, speedMps: 1));
        await Future<void>.delayed(Duration.zero);
        final far = [for (final x in c.todaySpawns) if (x.point.distanceTo(here) > 900) x]
          ..sort((a, b) => a.point.distanceTo(here).compareTo(b.point.distanceTo(here)));
        s = far.first;
      });
      await _page(tester, Scaffold(body: NightBackground(child: Align(alignment: Alignment.bottomCenter, child: SpawnSheet(key: ObjectKey('o$n'), controller: c, spawn: s)))));
      await _settle(tester, 3);
      await _shot(tester, '${n}_15_원정_부엉이');
      await tester.tap(find.text('서리').first);
      await _settle(tester, 3);
      await _shot(tester, '${n}_16_원정_다이어울프');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('b70 $n: 연금술 작업대 (넣기 · 끓는 중 · 다 끓음 · 증류기 · 제단 · 하나 더) · 레시피 격자 · 상세', (tester) async {
      _device(tester, d);
      late AppController c;
      final t = vt0;
      await tester.runAsync(() async {
        c = await startVillage(14, more: {
          'alchemy': {
            'discovered': ['healSmall', 'heal', 'manaSmall', 'antidote', 'strength', 'resistFire', 'weaponFire'],
            'noted': ['clearEye'],
            'bestMade': ['healSmall'],
            'cauldrons': 3,
            'brews': {
              '1': {'put': ['herb', 'herb', 'slimeJelly'], 'startedAt': t.subtract(const Duration(minutes: 4)).toIso8601String(), 'readyAt': t.add(const Duration(minutes: 3)).toIso8601String()},
              '2': {'put': ['herb', 'slimeJelly'], 'startedAt': t.subtract(const Duration(minutes: 20)).toIso8601String(), 'readyAt': t.subtract(const Duration(minutes: 1)).toIso8601String()},
            },
          },
        }, gains: {
          MaterialId.herb.name: 6,
          MaterialId.gortRoot.name: 2,
          MaterialId.slimeJelly.name: 4,
          MaterialId.fireJelly.name: 2,
          MaterialId.batWing.name: 3,
          'gold': 2000,
        });
      });
      await _page(tester, AlchemyScreen(key: ObjectKey('al$n'), controller: c));
      await _settle(tester, 3);
      await _shot(tester, '${n}_17_작업대_다끓음_먼저');
      await tester.tap(find.byKey(const Key('benchDot_0')));
      await _settle(tester, 4);
      await _shot(tester, '${n}_18_작업대_빈가마솥');
      await tester.tap(find.byKey(const Key('shelf_herb')));
      await tester.pump(const Duration(milliseconds: 250));
      await _shot(tester, '${n}_19_작업대_넣는중');
      await _settle(tester, 4);
      await tester.tap(find.byKey(const Key('shelf_herb')));
      await _settle(tester, 4);
      await tester.tap(find.byKey(const Key('shelf_slimeJelly')));
      await _settle(tester, 6);
      await _shot(tester, '${n}_20_작업대_레시피순서_반짝');
      await tester.tap(find.byKey(const Key('benchNext')).first, warnIfMissed: false);
      await _settle(tester, 4);
      await _shot(tester, '${n}_21_작업대_끓는중');
      await tester.tap(find.byKey(const Key('benchNext')).first, warnIfMissed: false);
      await _settle(tester, 4);
      await tester.tap(find.byKey(const Key('benchNext')).first, warnIfMissed: false);
      await _settle(tester, 4);
      await _shot(tester, '${n}_22_작업대_증류기');
      await tester.tap(find.byKey(const Key('benchNext')).first, warnIfMissed: false);
      await _settle(tester, 4);
      await _shot(tester, '${n}_23_작업대_변환제단');
      await tester.tap(find.byKey(const Key('recipeOpen')));
      await _settle(tester, 3);
      await _shot(tester, '${n}_24_레시피_격자');
      await tester.tap(find.byKey(const Key('recipeTile_healSmall')));
      await _settle(tester, 4);
      await _shot(tester, '${n}_25_레시피_상세');
      await tester.tap(find.byKey(const Key('recipeFill')));
      await _settle(tester, 6);
      await _shot(tester, '${n}_26_가마솥에_넣기');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('b70 $n: 게시판 탭 · 긴급 띠 · 잡화상 · 던전 열쇠 · 대장간 수리', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async => c = await startVillage(16, gains: {'gold': 3000}));
      await _page(tester, BoardScreen(key: ObjectKey('bd$n'), controller: c));
      await _shot(tester, '${n}_27_게시판_탭');
      await _tapShot(tester, const Key('boardTab_errand'), '${n}_28_게시판_조합');
      await _page(tester, ShopScreen(key: ObjectKey('sh$n'), controller: c));
      await tester.tap(find.byKey(const Key('shopChip_travel')));
      await _settle(tester, 2);
      await _shot(tester, '${n}_29_잡화상_여행도구');
      await _page(tester, DungeonScreen(key: ObjectKey('dg$n'), controller: c));
      await _shot(tester, '${n}_30_던전_열쇠');
      await _page(tester, SmithyScreen(key: ObjectKey('sm$n'), controller: c));
      await _tapShot(tester, const Key('smithyTab_2'), '${n}_31_대장간_수리_도구');
      await tester.pumpWidget(const SizedBox());
    });
  }
}
