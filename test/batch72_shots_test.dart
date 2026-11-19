// 묶음 72 (build/screenshots/b72_*)
// 작은 iPhone(SE) · 큰 iPhone · Android

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/act2_state.dart';
import 'package:isekai_reality/core/models/pet_state.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/storage/record_store.dart' show SpiritKind;
import 'package:isekai_reality/features/alchemy/alchemy_screen.dart';
import 'package:isekai_reality/features/bulssi/bulssi_mood.dart';
import 'package:isekai_reality/features/chat/chat_screens.dart';
import 'package:isekai_reality/features/chat/chat_tour.dart';
import 'package:isekai_reality/features/jobs/guild_screen.dart';
import 'package:isekai_reality/features/map/map_screen.dart';
import 'package:isekai_reality/features/pets/farewell_talk.dart';
import 'package:isekai_reality/features/profile/profile_screen.dart';
import 'package:isekai_reality/features/smithy/smithy_screen.dart';
import 'package:isekai_reality/features/town/bag_hold_sheet.dart';
import 'package:isekai_reality/features/town/bag_tab.dart';
import 'package:isekai_reality/features/town/inn_screen.dart';
import 'package:isekai_reality/features/town/shop_screen.dart';
import 'package:isekai_reality/features/village/shelter_screen.dart';
import 'package:isekai_reality/features/village/tavern_screen.dart';
import 'package:isekai_reality/features/village/village_screen.dart';
import 'package:isekai_reality/theme/ornaments.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'batch52_test.dart' as b52;
import 'batch56_test.dart' as b56;
import 'batch70_test.dart' as b70;
import 'batch72_test.dart' as b72;
import 'support/npc_seed.dart';
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
  File('build/screenshots/b72_$name.png')
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




void main() {
  setUpAll(_loadFonts);
  setUp(() => b56.now = b52.t0);

  for (final d in _devices) {
    final n = d.$1;

    testWidgets('b72 $n: 가득 찬 가방 → 「가방이 가득 찼어요」 · 칸이 줄어 넘친 가방', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async {
        c = await b72.fullBag();
        final r = ProcessRules.all.firstWhere((x) => x.id == 'ingot');
        await c.process(r);
      });
      await _page(tester, Scaffold(body: Builder(builder: (ctx) => Center(child: TextButton(onPressed: () => showBagHoldSheet(ctx, c), child: const Text(''))))));
      await tester.tap(find.byType(TextButton));
      await _settle(tester, 4);
      await _shot(tester, '${n}_01_가방가득_창');
      await tester.tap(find.text('닫기').last);
      await _settle(tester, 3);
      await tester.runAsync(() async => c = await startVillage(12, gains: {
            for (final m in MaterialId.values.take(40)) m.name: 1,
          }, more: {
            'jobs': {
              'marks': {'bigPackDay': 20261115},
            },
          }));
      await _page(tester, Scaffold(body: NightBackground(child: BagTab(key: ObjectKey('bg$n'), controller: c))));
      await _shot(tester, '${n}_02_칸이줄어_넘친가방');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('b72 $n: Lv.8 로그인 권유 · 대장간 수리 재료 · 위쪽 버튼 · 대화방 설정', (tester) async {
      _device(tester, d);
      await _page(
          tester,
          BulssiScope(
            mood: BulssiMood.gold,
            spiritName: '불씨',
            kind: SpiritKind.water,
            child: Scaffold(
                body: NightBackground(
                    header: true,
                    child: Builder(
                        builder: (ctx) => Center(
                            child: TextButton(
                                onPressed: () => showDialog<void>(
                                    context: ctx,
                                    barrierColor: const Color(0xF2050614),
                                    builder: (dc) => SpiritLineAlert(
                                        spiritName: '불씨',
                                        line: '친구를 사귀려면 기록을 지켜 둬야 해!',
                                        actions: [
                                          (const Key('l'), '로그인', () => Navigator.pop(dc)),
                                          (const Key('n'), '나중에', () => Navigator.pop(dc)),
                                        ])),
                                child: const Text('')))))),
          ));
      await tester.tap(find.byType(TextButton).first);
      await _settle(tester, 4);
      await _shot(tester, '${n}_03_Lv8_로그인권유');
      await tester.tap(find.byKey(const Key('n')));
      await _settle(tester, 2);
      late AppController c;
      await tester.runAsync(() async => c = await startNpc(level: 12, gold: 3000, mats: const {
            'gortRoot': 2,
            'ironShard': 3,
            'twig': 1,
          }, json: {
            'harvest': {
              'granted': true,
              'tools': {'sickle': 4, 'pickaxe': 12, 'axe': 30, 'rod': 0, 'brush': 25},
            },
          }));
      await _page(tester, SmithyScreen(key: ObjectKey('sm$n'), controller: c));
      await tester.tap(find.byKey(const Key('smithyTab_2')));
      await _settle(tester, 3);
      await tester.scrollUntilVisible(find.byKey(const Key('toolRepairPanel')), 300,
          scrollable: find.descendant(of: find.byType(SmithyScreen), matching: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down)).first);
      await _settle(tester, 2);
      await _shot(tester, '${n}_04_대장간_수리재료_아무약초');
      // 위쪽 버튼 (Lv.8 친구 · Lv.11 대화 · 설정)
      final cs = <AppController>[];
      await tester.runAsync(() async {
        for (final lv in [9, 11]) {
          final r = await b70.chatAt(lv);
          await r.$1.refreshChat();
          cs.add(r.$1);
        }
      });
      await _page(
          tester,
          Scaffold(
              body: NightBackground(
                  header: true,
                  child: Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    for (final (i, label) in ['Lv.9 친구', 'Lv.11 대화'].indexed)
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          SizedBox(width: 110, child: Text(label, style: AppText.title(17))),
                          SizedBox(width: 60, height: 50, child: Center(child: ChatButton(controller: cs[i]))),
                        ]),
                      ),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      SizedBox(width: 110, child: Text('설정', style: AppText.title(17))),
                      const SizedBox(width: 60, height: 50, child: Center(child: SettingsButton())),
                    ]),
                  ])))));
      await _shot(tester, '${n}_05_위쪽버튼');
      await _page(tester, ChatHubScreen(key: ObjectKey('h$n'), controller: cs[1]));
      await _settle(tester, 3);
      await _shot(tester, '${n}_06_대화방_설정');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 20));
    });

    testWidgets('b72 $n: 연금술 작업대 (빈 · 넣는 순간 · 끓는 중 · 다 됨 · 증류기 · 변환 제단)', (tester) async {
      _device(tester, d);
      late AppController c;
      final t = vt0;
      await tester.runAsync(() async {
        c = await startVillage(14, more: {
          'alchemy': {
            'discovered': ['healSmall'],
            'cauldrons': 3,
            'brews': {
              '1': {'put': ['herb', 'herb', 'slimeJelly'], 'startedAt': t.subtract(const Duration(minutes: 4)).toIso8601String(), 'readyAt': t.add(const Duration(minutes: 3)).toIso8601String()},
              '2': {'put': ['fireJelly', 'herb'], 'startedAt': t.subtract(const Duration(minutes: 20)).toIso8601String(), 'readyAt': t.subtract(const Duration(minutes: 1)).toIso8601String()},
            },
          },
        }, gains: {MaterialId.herb.name: 6, MaterialId.slimeJelly.name: 4, MaterialId.fireJelly.name: 2, 'gold': 2000});
      });
      await _page(tester, AlchemyScreen(key: ObjectKey('al$n'), controller: c));
      await _settle(tester, 3);
      await _shot(tester, '${n}_07_작업대_다됨');
      await tester.tap(find.byKey(const Key('benchDot_0')));
      await _settle(tester, 4);
      await _shot(tester, '${n}_08_작업대_빈가마솥');
      await tester.tap(find.byKey(const Key('shelf_fireJelly')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await _shot(tester, '${n}_09_작업대_넣는순간');
      await _settle(tester, 4);
      await tester.tap(find.byKey(const Key('benchNext')));
      await _settle(tester, 4);
      await _shot(tester, '${n}_10_작업대_끓는중');
      await tester.tap(find.byKey(const Key('benchNext')));
      await _settle(tester, 3);
      await tester.tap(find.byKey(const Key('benchNext')));
      await _settle(tester, 4);
      await _shot(tester, '${n}_11_작업대_증류기');
      await tester.tap(find.byKey(const Key('benchNext')));
      await _settle(tester, 4);
      await _shot(tester, '${n}_12_작업대_변환제단');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('b72 $n: 알 부화장 · 정령 이별 마지막 줄 · 건물 안 6곳', (tester) async {
      _device(tester, d);
      late AppController c;
      final now = vt0;
      await tester.runAsync(() async => c = await startVillage(11, farewell: true, more: {
            'buildings': {
              'stars': {'shelter': 3},
            },
            'pets': PetState(
              pets: [Pet(uid: 'p1', species: PetSpecies.owl, name: '부엉', bornAt: DateTime(2026, 11, 1))],
              companion: 'p1',
              firstPet: 'p1',
              firstSpiritName: '불씨',
              farewellAt: DateTime(2026, 11, 2),
              eggs: [
                PetEgg(id: 'e1', source: 'field', incubatedAt: now.subtract(const Duration(hours: 7))),
                PetEgg(id: 'e2', source: 'field', incubatedAt: now.subtract(const Duration(hours: 13))),
              ],
              nextId: 3,
            ).toJson(),
          }));
      await _page(tester, ShelterScreen(key: ObjectKey('s$n'), controller: c));
      await _shot(tester, '${n}_13_부화장');
      for (final kind in SpiritKind.values) {
        await _page(
            tester,
            Scaffold(body: FarewellTalkScene(
              key: ObjectKey('f$n${kind.name}'),
              image: 'assets/images/farewell_04_light.webp',
              name: '불씨',
              kind: kind,
              line: '정말 고마웠어. 이제 너는 혼자서도 잘 걸을 수 있어.',
              index: 4,
              sound: false,
              vibrate: false,
              onNext: () {},
            )));
        await tester.pump(const Duration(seconds: 4));
        await _settle(tester, 3);
        await _shot(tester, '${n}_14_이별_마지막줄_${kind.name}');
        await tester.pumpWidget(const SizedBox());
      }
      await tester.runAsync(() async => c = await startNpc(level: 16, gold: 2000));
      var k = 15;
      for (final (name, w) in [
        ('대장간', SmithyScreen(key: ObjectKey('a$n'), controller: c)),
        ('여관', InnScreen(key: ObjectKey('b$n'), controller: c)),
        ('연금술', AlchemyScreen(key: ObjectKey('c$n'), controller: c)),
        ('잡화상', ShopScreen(key: ObjectKey('d$n'), controller: c)),
        ('주점', TavernScreen(key: ObjectKey('e$n'), controller: c)),
        ('길드', GuildScreen(key: ObjectKey('g$n'), controller: c)),
      ]) {
        await _page(tester, w);
        await _shot(tester, '${n}_${k++}_안_$name');
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('b72 $n: Lv.50 지도 · 약초 7종 가방 · 거래소 ★2 · ★3 마을', (tester) async {
      _device(tester, d);
      final manifest = await tester.runAsync(() => AssetManifest.loadFromAssetBundle(rootBundle));
      Monsters.knownAssets = manifest!.listAssets().toSet();
      addTearDown(() => Monsters.knownAssets = null);
      late AppController c;
      await tester.runAsync(() async => c = await startNpc(level: 50, clock: () => DateTime(2026, 11, 20, 12)));
      await _page(tester, Scaffold(body: MapScreen(key: ObjectKey('m$n'), controller: c)));
      await _settle(tester, 4);
      await _shot(tester, '${n}_21_지도_Lv50');
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async => c = await startVillage(12, gains: {
            for (final h in Materials.herbGroup) h.name: 3,
          }));
      await _page(tester, Scaffold(body: NightBackground(child: BagTab(key: ObjectKey('h$n'), controller: c))));
      await _shot(tester, '${n}_22_가방_약초7종');
      for (final star in [2, 3]) {
        await tester.runAsync(() async => c = await startNpc(level: 30, json: {
              'buildings': {
                'stars': {'market': star},
              },
              // 건물 단계는 2막 결말 뒤부터
              'act2': const Act2State(beaten: 5, kingPhase: 5, kingDone: true, endingSeen: true, announced: 6).toJson(),
              'village': {
                'seen': ['intro', 'farewell', 'lit', 'shelterCard', 'trainingCard', 'gardenCard', 'market', 'meet', for (final x in Npc.values) 'met:${x.name}'],
              },
            }));
        await _page(tester, Scaffold(body: VillageScreen(key: ObjectKey('v$n$star'), controller: c)));
        await _settle(tester, 4);
        final mk = find.byWidgetPredicate((w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName.contains('village_market'));
        if (mk.evaluate().isNotEmpty) {
          await tester.ensureVisible(mk.first);
          await _settle(tester, 3);
        }
        await _shot(tester, '${n}_${22 + star - 1}_마을_거래소★$star');
        await tester.pumpWidget(const SizedBox());
      }
      await tester.pump(const Duration(seconds: 5));
    });
  }
}
