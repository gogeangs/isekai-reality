// 묶음 77 (build/screenshots/b77_*) — 큰 iPhone · SE

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/storage/record_store.dart' show HeroLook, SpiritKind;
import 'package:isekai_reality/features/battle/battle_view.dart';
import 'package:isekai_reality/features/battle/hero_rig.dart' show WeaponKind;
import 'package:isekai_reality/features/bulssi/bulssi_mood.dart';
import 'package:isekai_reality/features/status/status_screen.dart';
import 'package:isekai_reality/features/jobs/guild_screen.dart';
import 'package:isekai_reality/theme/ornaments.dart';
import 'package:isekai_reality/theme/top_notice.dart';
import 'package:isekai_reality/core/models/armory.dart';
import 'package:isekai_reality/features/codex/codex_screen.dart';
import 'package:isekai_reality/features/map/map_screen.dart';
import 'package:isekai_reality/features/profile/title_celebration.dart';
import 'package:isekai_reality/features/smithy/equipment_view.dart';
import 'package:isekai_reality/features/status/status_cards.dart';
import 'package:isekai_reality/features/tutorial/feature_tour.dart';
import 'package:isekai_reality/features/village/board_screen.dart';
import 'package:isekai_reality/features/village/village_screen.dart';
import 'support/npc_seed.dart';
import 'package:isekai_reality/theme/app_colors.dart';

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
  File('build/screenshots/b77_$name.png')
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


Widget _skillBattle(Battle b, JobSkill s, {String? job, HeroLook look = HeroLook.male}) => BulssiScope(
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
                jobSkills: [(s, 25, 1.0)],
                jobMp: () => 100,
                onJobSkill: (_) async => true,
                onFinished: () {},
                tickInterval: const Duration(milliseconds: 600))),
      ]))),
    );

void main() {
  setUpAll(_loadFonts);
  setUp(() => b56.now = b52.t0);

  for (final d in [_devices[1], _devices[0]]) {
    final n = d.$1;
    final big = n != 'SE';
    final look = big ? HeroLook.male : HeroLook.female;

    testWidgets('b77 $n: 1 조합', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async => c = await startVillage(17, farewell: true, more: {'jobs': _jobs('warrior')}));
      await _page(tester, GuildScreen(key: ObjectKey('g1$n'), controller: c));
      await _shot(tester, '${n}_01_조합_Lv17');
      await tester.tap(find.byKey(const Key('guildJob_mage')));
      await _settle(tester, 3);
      await _shot(tester, '${n}_02_조합_Lv17_마법사고름_이직업으로바꾸기');
      await tester.runAsync(() async => c = await startVillage(20, farewell: true, more: {'jobs': _jobs('warrior')}));
      await _page(tester, GuildScreen(key: ObjectKey('g2$n'), controller: c, glowSub: true));
      await _shot(tester, '${n}_03_조합_Lv20_빈보조칸빛남_세라힌트');
      await tester.runAsync(() async => c = await startVillage(22, farewell: true, more: {'jobs': _jobs('knight', subs: ['priest'])}));
      await _page(tester, GuildScreen(key: ObjectKey('g3$n'), controller: c));
      await _shot(tester, '${n}_04_조합_보조단뒤_숨은이명_성기사');
      await tester.runAsync(() async => c = await startVillage(31, farewell: true, more: {'jobs': _jobs('warrior', subs: ['mage'])}));
      await _page(tester, GuildScreen(key: ObjectKey('g4$n'), controller: c));
      await _shot(tester, '${n}_05_조합_마검사_각인2단계');
      if (find.byKey(const Key('guildTab_hidden')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const Key('guildTab_hidden')));
        await _settle(tester, 3);
        await _shot(tester, '${n}_06_조합_히든탭');
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('b77 $n: 2 직업 고르기 Lv.15', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async => c = await startVillage(15, farewell: true));
      await _page(tester, JobAwakenScreen(key: ObjectKey('ja$n'), controller: c));
      await tester.tap(find.byKey(const Key('jobAwakenGo')));
      await _settle(tester, 4);
      await _shot(tester, '${n}_10_직업고르기_보조줄없음');
      await tester.tap(find.byKey(const Key('jobTabCraft')));
      await _settle(tester, 2);
      for (final (i, j) in [(1, 'blacksmith'), (2, 'tamer')]) {
        await tester.ensureVisible(find.byKey(Key('jobPick_$j')));
        await tester.tap(find.byKey(Key('jobPick_$j')));
        await _settle(tester, 3);
        final id = JobId.values.byName(j);
        final life = JobRules.info(id).skills.firstWhere((x) => !JobRules.skill(x).isBattle);
        await tester.ensureVisible(find.byKey(Key('jobSkill_${life.name}')));
        await tester.tap(find.byKey(Key('jobSkill_${life.name}')));
        await _settle(tester, 3);
        await _shot(tester, '${n}_1${i}_직업고르기_${j}_자기그림_생활스킬아이콘');
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('b77 $n: 3 상태 · 카드 · 새로 열렸어요', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async => c = await startVillage(14, farewell: true));
      Widget status(AppController c, {(int, int)? mp}) => Scaffold(
          body: NightBackground(
              header: true,
              child: StatusScreen(
                  player: c.player,
                  look: look,
                  heroJob: c.heroJobArt,
                  jobMp: mp,
                  cards: StatusCards(controller: c))));
      await _page(tester, KeyedSubtree(key: ObjectKey('s1$n'), child: status(c)));
      await _shot(tester, '${n}_20_상태_각성전_HP한줄_기력');
      await tester.runAsync(() async => c = await startVillage(20, farewell: true, more: {'jobs': _jobs('mage')}));
      await _page(tester, KeyedSubtree(key: ObjectKey('s2$n'), child: status(c, mp: (c.jobMp, c.jobMpMax))));
      await tester.pump(const Duration(seconds: 2));
      await _settle(tester, 2);
      await _shot(tester, '${n}_21_상태_각성뒤_HP_MP_기력_카드_포인트있음');
      // Lv.20 「새로 열렸어요 · 보조 직업」 카드
      await tester.runAsync(() async {
        await c.markSkillIntro();
        await c.markShelterIntro();
      });
      tourBridge.tab = FeatureTourLayer.tStatus;
      await tester.pumpWidget(RepaintBoundary(
        key: _root,
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Roboto'),
            navigatorKey: tourBridge.navKey,
            navigatorObservers: [TourObserver()],
            builder: (context, child) => TopNoticeHost(
                child: Stack(children: [
              Positioned.fill(child: child!),
              Positioned.fill(child: FeatureTourLayer(controller: c)),
            ])),
            home: KeyedSubtree(key: ObjectKey('s3$n'), child: status(c, mp: (c.jobMp, c.jobMpMax)))),
      ));
      await _settle(tester, 10);
      await _shot(tester, '${n}_22_새로열렸어요_보조직업${find.byKey(const Key('subJobSeraLine')).evaluate().isEmpty ? '_카드안뜸' : ''}');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('b77 $n: 4 지도 기력 칩', (tester) async {
      _device(tester, d);
      for (final (i, lv, job, label) in [(0, 14, null, '각성전'), (1, 20, 'mage', '각성뒤')]) {
        late AppController c;
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
        await tester.runAsync(() async => c = await startVillage(lv, farewell: true, more: {if (job != null) 'jobs': _jobs(job)}));
        await _page(tester, Scaffold(body: MapScreen(key: ObjectKey('m$n$i'), controller: c)));
        await _settle(tester, 4);
        await _shot(tester, '${n}_3${i}a_지도_기력칩_$label');
        final chip = find.byKey(const Key('mapJobMp'));
        if (chip.evaluate().isNotEmpty) {
          await tester.tap(chip.first, warnIfMissed: false);
          await _settle(tester, 4);
          await _shot(tester, '${n}_3${i}b_지도_기력창_$label');
        }
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('b77 $n: 5 마을 · 게시판', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async => c = await startNpc(level: 14));
      await _page(tester, Scaffold(key: ObjectKey('v$n'), body: VillageScreen(controller: c)));
      await _shot(tester, '${n}_40_마을_게시판에만느낌표');
      await _page(tester, BoardScreen(key: ObjectKey('bd$n'), controller: c));
      if (find.byKey(const Key('boardTab_npc')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const Key('boardTab_npc')));
        await _settle(tester, 4);
        await _shot(tester, '${n}_41_게시판_마을사람탭');
      } else {
        await _shot(tester, '${n}_41_게시판_마을사람탭없음');
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('b77 $n: 6 칭호 연출 3등급', (tester) async {
      _device(tester, d);
      late AppController c;
      await tester.runAsync(() async => c = await startVillage(20, farewell: true));
      for (final (i, t) in [(0, TitleId.values.first), (1, TitleId.basiliskSlayer), (2, TitleId.guildLegend)]) {
        final g = TitleRules.gradeLabel(TitleRules.gradeOf(t));
        await _page(tester, Scaffold(backgroundColor: const Color(0xFF05060F), body: TitleCelebration(key: ObjectKey('t$n${i}a'), controller: c, title: t, start: 0.6)));
        await _shot(tester, '${n}_5${i}a_칭호_${g}_빛줄기순간');
        await _page(tester, Scaffold(backgroundColor: const Color(0xFF05060F), body: TitleCelebration(key: ObjectKey('t$n${i}b'), controller: c, title: t, start: 1.0)));
        await _shot(tester, '${n}_5${i}b_칭호_${g}_끝화면');
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('b77 $n: 7 전투 생산 직업 · 마검사 · 현자 · 합동 돌격', (tester) async {
      _device(tester, d);
      for (final (i, job) in [(0, 'blacksmith'), (1, 'alchemist'), (2, 'tamer'), (3, 'merchant')]) {
        await _page(tester, _battle(_b(), job: job, look: look, tick: const Duration(seconds: 30)));
        await _shot(tester, '${n}_6${i}a_전투_${job}_대기');
        await _page(tester, _battle(_b(), job: job, look: look));
        await _until(tester, find.byKey(const Key('heroFrame_3')));
        await _shot(tester, '${n}_6${i}b_전투_${job}_공격');
      }
      for (final (i, s, job) in [
        (4, JobSkill.spellbladeSlash, 'warrior'),
        (5, JobSkill.sageStrike, 'mage'),
        (6, JobSkill.jointAttack, 'tamer'),
      ]) {
        final b = _b(skills: true);
        if (s == JobSkill.spellbladeSlash) b.spellblade = true;
        if (s == JobSkill.sageStrike) b.sage = true;
        await _page(tester, _skillBattle(b, s, job: job, look: look));
        await _settle(tester, 3);
        final btn = find.byKey(Key('battleJob_${s.name}'));
        if (btn.evaluate().isNotEmpty) {
          await tester.tap(btn.first, warnIfMissed: false);
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pump(const Duration(milliseconds: 300));
        }
        await _shot(tester, '${n}_6${i}_전투_${s.name}${btn.evaluate().isEmpty ? '_버튼없음' : ''}');
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('b77 $n: 8 몬스터 장비 · 도감 · 엿보기 상성', (tester) async {
      _device(tester, d);
      final manifest = await tester.runAsync(() => AssetManifest.loadFromAssetBundle(rootBundle));
      Monsters.knownAssets = manifest!.listAssets().toSet();
      addTearDown(() => Monsters.knownAssets = null);
      for (final (i, base, grade) in [
        (0, EquipBase.monGoblinDagger, EquipGrade.white),
        (1, EquipBase.monDeathSword, EquipGrade.blue),
      ]) {
        final item = EquipItem(uid: 'eq$i', base: base, grade: grade);
        final m = MonGearRules.monsterOf(base)!;
        await _page(
            tester,
            Scaffold(
                key: ObjectKey('mg$n$i'),
                body: NightBackground(
                    child: ListView(padding: const EdgeInsets.fromLTRB(14, 60, 14, 20), children: [
                  Text('사냥 성공!', textAlign: TextAlign.center, style: AppText.title(30)),
                  const SizedBox(height: 12),
                  Center(child: MonsterPicture(monster: m, size: 130)),
                  OrnatePanel(
                      ornament: true,
                      child: Column(children: [
                        Text(Monsters.info(m).name, style: AppText.title(19)),
                        const SizedBox(height: 6),
                        const Text('경험치 +240', style: TextStyle(color: AppColors.text, fontSize: 14)),
                        const SizedBox(height: 6),
                        MonGearGotBanner(item: item),
                      ])),
                ]))));
        await tester.pump(const Duration(seconds: 2));
        await _shot(tester, '${n}_7${i}_결과창_${base.name}');
      }
      for (final (i, found) in [(0, false), (1, true)]) {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
        await _page(
            tester,
            Scaffold(
                key: ObjectKey('cx$n$i'),
                body: NightBackground(
                    child: CodexScreen(
                        purifiedMonsters: const {MonsterId.ogre, MonsterId.goblinRaider},
                        huntCounts: const {MonsterId.ogre: 12},
                        monGearFound: found ? const {EquipBase.monOgreBracers} : const {}))));
        await tester.ensureVisible(find.byKey(const Key('codexTile_ogre')));
        await tester.tap(find.byKey(const Key('codexTile_ogre')));
        await _settle(tester, 5);
        await _shot(tester, '${n}_7${2 + i}_도감_떨어뜨리는것_${found ? '얻음' : '물음표'}');
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      await _page(
          tester,
          Scaffold(
              key: ObjectKey('pk$n'),
              body: NightBackground(
                  child: ListView(padding: const EdgeInsets.fromLTRB(14, 60, 14, 20), children: [
                Text('엿보기 상성 글', style: AppText.title(19)),
                for (final e in ErbardRules.cloneWeakTo.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      MonsterPicture(monster: MonsterId.values.byName(e.key), size: 44),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text('이 자리는 ${e.value.map((j) => JobRules.info(j).name).join(' · ')}에게 약해 보여요',
                              style: const TextStyle(color: AppColors.goldBright, fontSize: 13))),
                    ]),
                  ),
              ]))));
      await _shot(tester, '${n}_74_공성전엿보기_상성글');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  }
}
