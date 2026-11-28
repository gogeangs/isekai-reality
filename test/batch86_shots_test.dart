// 묶음 86 (build/screenshots/b86_*) — 큰 iPhone · SE

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/pet_state.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/cloud/cloud_auth.dart' show LoginProvider;
import 'package:isekai_reality/features/pets/companion_pet_panel.dart';
import 'package:isekai_reality/features/act4/act4_screens.dart';
import 'package:isekai_reality/features/alchemy/alchemy_screen.dart';
import 'package:isekai_reality/features/jobs/guild_screen.dart';
import 'package:isekai_reality/features/jobs/skill_screen.dart';
import 'package:isekai_reality/features/level_up/level_up_dialog.dart';
import 'package:isekai_reality/features/pets/pet_screen.dart';
import 'package:isekai_reality/features/town/bag_tab.dart';
import 'package:isekai_reality/features/village/tavern_screen.dart';
import 'package:isekai_reality/features/village/village_screen.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'batch52_test.dart' as b52;
import 'batch56_test.dart' as b56;
import 'batch59_test.dart' as b59;
import 'batch86_test.dart' as t86;
import 'support/fake_arca.dart';
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
  File('build/screenshots/b86_$name.png')
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


Future<void> _mid(WidgetTester tester, Finder f) async {
  await tester.runAsync(() => Scrollable.ensureVisible(tester.element(f), alignment: 0.45));
  await _settle(tester, 2);
}

void main() {
  setUpAll(_loadFonts);
  setUp(() => b56.now = b52.t0);

  for (final d in _devices) {
    final n = d.$1;

    testWidgets('b86 $n: 1 스킬 한 화면', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async {
        c = await t86.job(26, owned: ['warrior', 'mage'], subs: ['mage'], gold: 5000);
        for (final s in JobRules.info(JobId.warrior).skills.take(3)) {
          await c.raiseSkill(s);
        }
        await c.raiseSkill(JobRules.info(JobId.mage).skills[1]);
        await c.buyBook(JobSkill.bookFirstAid);
        await c.buyBook(JobSkill.bookQuickStep);
      });
      await _page(tester, SkillScreen(key: ObjectKey('s$n'), controller: c));
      await _shot(tester, '${n}_01_스킬_맨위_포인트_전투칸_칩');
      for (final (k, name) in [
        ('skillChip_main', '02_주직업칸'),
        ('skillChip_sub', '03_보조직업칸'),
        ('skillChip_common', '04_공용칸'),
        ('skillChip_mastery', '05_숙련칸'),
      ]) {
        await tester.tap(find.byKey(Key(k)));
        await _settle(tester, 3);
        await _shot(tester, '${n}_$name');
      }
      // 「칸에」 → 위 칸
      await tester.tap(find.byKey(const Key('skillChip_common')));
      await _settle(tester, 3);
      await _mid(tester, find.byKey(const Key('skillToSlot_bookFirstAid')));
      await tester.tap(find.byKey(const Key('skillToSlot_bookFirstAid')));
      await _settle(tester, 2);
      await _shot(tester, '${n}_06_칸에_누른뒤_칸고르기');
      await tester.tap(find.byKey(const Key('skillSlot_1')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await _settle(tester, 2);
      await _shot(tester, '${n}_07_칸에_끼움');
      // 다시 나누기
      await _page(tester, SkillScreen(key: ObjectKey('r$n'), controller: c));
      await tester.tap(find.byKey(const Key('skillReset')));
      await _settle(tester, 2);
      await tester.tap(find.byKey(const Key('skillResetOk')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await _settle(tester, 4);
      await _shot(tester, '${n}_08_다시나누기_뒤');
      await _done(tester);
    });

    testWidgets('b86 $n: 2 레벨업 +3 · 직업 숙련 열림', (tester) async {
      _device(tester, d);
      await _page(tester, const Scaffold(body: Center(child: LevelUpDialog(from: 19, to: 20))));
      await _shot(tester, '${n}_09_레벨업_스킬포인트3');
      late AppController c;
      await tester.runAsync(() async {
        c = await t86.job(24);
        for (final s in JobRules.info(JobId.warrior).skills) {
          while (c.skillLevel(s) < 3 && c.canRaiseSkill(s)) {
            await c.raiseSkill(s);
          }
        }
        await c.raiseDrill(JobId.warrior);
      });
      await _page(tester, SkillScreen(key: ObjectKey('d$n'), controller: c));
      await _mid(tester, find.byKey(const Key('jobDrill_warrior')));
      await _shot(tester, '${n}_10_직업숙련_열림_Lv24');
      await _done(tester);
    });

    testWidgets('b86 $n: 3 조합 스킬북 · 직업 바꾸기', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async {
        c = await t86.job(20, owned: ['warrior', 'mage', 'archer'], subs: ['mage'], gold: 1500);
        await c.buyBook(JobSkill.bookFirstAid);
      });
      await _page(tester, GuildScreen(key: ObjectKey('g$n'), controller: c));
      await tester.tap(find.byKey(const Key('guildTab_books')));
      await _settle(tester, 3);
      await _shot(tester, '${n}_11_조합_스킬북');
      await tester.drag(find.byKey(const Key('guildScroll')), const Offset(0, -500));
      await _settle(tester, 3);
      await _shot(tester, '${n}_12_조합_스킬북_아래');
      await _done(tester);
      late AppController r;
      await tester.runAsync(() async {
        r = await t86.job(20, owned: ['warrior', 'mage', 'archer'], subs: ['mage'], gold: 30000);
        await r.raiseSkill(JobRules.info(JobId.warrior).skills[1]);
        await r.raiseSkill(JobRules.info(JobId.mage).skills[1]);
      });
      await _page(tester, GuildScreen(key: ObjectKey('m$n'), controller: r));
      await tester.tap(find.byKey(const Key('guildJob_archer')));
      await _settle(tester, 2);
      await _shot(tester, '${n}_13_직업_아래판_금화');
      await tester.tap(find.byKey(const Key('jobAsMain')));
      await _settle(tester, 3);
      await _shot(tester, '${n}_14_주직업_바꾸기_확인창');
      await tester.tap(find.byKey(const Key('jobChangeOk')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await _settle(tester, 4);
      await _shot(tester, '${n}_15_바꾼뒤_보조칸_비워짐');
      await tester.runAsync(() async => r.changeJobs(JobId.archer, JobId.mage));
      await _page(tester, GuildScreen(key: ObjectKey('m2$n'), controller: r));
      await tester.tap(find.byKey(const Key('guildJob_warrior')));
      await _settle(tester, 2);
      await tester.tap(find.byKey(const Key('jobAsSub')));
      await _settle(tester, 3);
      await _shot(tester, '${n}_16_보조직업_바꾸기_확인창');
      await _done(tester);
      // 금화 모자람
      late AppController poor;
      await tester.runAsync(() async => poor = await t86.job(20, owned: ['warrior', 'archer']));
      await _page(tester, GuildScreen(key: ObjectKey('p$n'), controller: poor));
      await tester.tap(find.byKey(const Key('guildJob_archer')));
      await _settle(tester, 2);
      await _shot(tester, '${n}_17_금화모자람');
      await _done(tester);
    });

    testWidgets('b86 $n: 4 가방 칸 열기 · 펫 · 상태 내 펫', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async {
        c = await startVillage(15, gains: {'gold': 9000, 'herb': 2}, more: {
          'bag': {'singleSlots': 22},
        });
      });
      await _page(tester, Scaffold(body: BagTab(key: ObjectKey('b$n'), controller: c)));
      final slot = find.byKey(const Key('bagExpandSlot'));
      if (slot.evaluate().isNotEmpty) {
        await _mid(tester, slot);
        await tester.tap(slot);
        await _settle(tester, 3);
      }
      await _shot(tester, '${n}_18_가방_한칸열기_값');
      await _done(tester);
      late AppController p;
      await tester.runAsync(() async {
        p = await startVillage(15, more: {
          'pets': PetState(
            pets: [
              Pet(uid: 'p1', species: PetSpecies.owl, name: '부엉', bornAt: DateTime(2026, 11, 1)),
              Pet(uid: 'p2', species: PetSpecies.blackCat, name: '나비', bornAt: DateTime(2026, 11, 3)),
              Pet(uid: 'p3', species: PetSpecies.crow, name: '까망', bornAt: DateTime(2026, 11, 4)),
            ],
            companion: 'p3',
            firstPet: 'p1',
            firstSpiritName: '불씨',
            farewellAt: DateTime(2026, 11, 2),
          ).toJson(),
        });
      });
      await _page(tester, PetScreen(key: ObjectKey('pp$n'), controller: p));
      await _shot(tester, '${n}_19_펫_데리고다니는펫_맨위');
      await _page(tester, Scaffold(body: SingleChildScrollView(child: CompanionPetPanel(controller: p))));
      await _shot(tester, '${n}_20_상태_내펫칸');
      await _done(tester);
    });

    testWidgets('b86 $n: 5 모집권 그림 · 연금술 공방 점 · 다 끓은 물약', (tester) async {
      _device(tester, d);
      late AppController c;
      late FakeArca a;
      await tester.runAsync(() async {
        final r = await b56.start(steps: 9600, login: false);
        c = r.$1;
        a = r.$2;
        await c.store.saveJson('party', {'tickets': 85, 'together': 7, 'emblems': [5]});
        c = (await b56.start(steps: 9600, login: false, store: c.store as dynamic, arca: a)).$1;
        await c.signInCloud(LoginProvider.google);
        await c.createParty('새벽 원정대');
        await c.refreshParty();
        c.takePartyNotice();
      });
      await _page(tester, TavernScreen(key: ObjectKey('t$n'), controller: c, partyTab: true));
      final open = find.byKey(const Key('partyShopOpen'));
      for (var k = 0; k < 4 && open.evaluate().isEmpty; k++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -560));
        await _settle(tester, 2);
      }
      if (open.evaluate().isNotEmpty) {
        await tester.tap(open);
        await _settle(tester, 4);
      }
      await _shot(tester, '${n}_21_파티상점_모집권');
      await _done(tester);
      late AppController g;
      await tester.runAsync(() async {
        final fa = FakeArca();
        (g, _) = await b59.act4(state: b59.ch2Done.copyWith(seals: 135), arca: fa);
        await g.createGuild('등불지기', emblem: 2, color: 4);
        fa.guildLevel = 6;
        await g.refreshGuild();
      });
      await _page(tester, GuildHallScreen(key: ObjectKey('gh$n'), controller: g));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.tap(find.byKey(const Key('guildTab_3')));
      await _settle(tester, 3);
      final rec = find.byKey(const Key('guildShopRow_recruit'));
      if (rec.evaluate().isNotEmpty) await _mid(tester, rec);
      await _shot(tester, '${n}_22_길드회관상점_모집권');
      await _done(tester);
      // 연금술 공방 점 · 다 끓은 가마솥 물약 그림
      final t = vt0;
      late AppController v;
      await tester.runAsync(() async {
        v = await startVillage(14, more: {
          'alchemy': {
            'discovered': ['healSmall'],
            'brews': {
              '0': {'put': ['herb', 'slimeJelly'], 'startedAt': t.subtract(const Duration(minutes: 20)).toIso8601String(), 'readyAt': t.subtract(const Duration(minutes: 1)).toIso8601String()},
            },
          },
        });
      });
      await _page(tester, Scaffold(body: VillageScreen(key: ObjectKey('v$n'), controller: v, visits: ValueNotifier(1))));
      await _settle(tester, 6);
      await _shot(tester, '${n}_23_마을_연금술공방_빨간점');
      await _page(tester, AlchemyScreen(key: ObjectKey('al$n'), controller: v));
      await _settle(tester, 4);
      await _shot(tester, '${n}_24_다끓은가마솥_물약그림');
      await _done(tester);
    });
  }
}
