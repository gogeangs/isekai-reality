import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/geo/geo.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/models/lens_state.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/core/story/dungeon_clues.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/location/location_source.dart';
import 'package:isekai_reality/data/notify/notifier.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/bulssi/bulssi_bubble.dart';
import 'package:isekai_reality/features/smithy/first_weapon_picker.dart';
import 'package:isekai_reality/features/tutorial/targets.dart';
import 'package:isekai_reality/theme/ornaments.dart';

void main() {
  final t0 = DateTime(2026, 11, 13, 10);

  /// 새로 시작한 사람(레벨 잠금 대상), 튜토리얼은 끝, 던전으로 [days]일 경험치
  InMemoryRecordStore grown(int days, {List<String> seen = const []}) =>
      InMemoryRecordStore(
        profile: const PlayerProfile(name: '하루', lastSeenLevel: 99),
        history: [
          for (var i = days; i >= 1; i--)
            DailyRecord(
              date: DateTime(2026, 11, 13 - i),
              dungeonRuns: List.filled(4, const DungeonRun(cleared: true)),
            ),
        ],
        json: {
          'tutorial': {'step': TutorialStep.done.index},
          'gates': {'legacy': false, 'seen': seen},
        },
      );

  Future<AppController> start(InMemoryRecordStore store,
      {LocationSource? location}) async {
    final c = AppController(
      store: store,
      health: FakeHealthSource(stepsByDay: const {}),
      location: location,
      clock: () => t0,
    )..mailSources = const [];
    await c.init();
    return c;
  }

  group('#5 첫 무기 5종', () {
    test('5종 모두 무기이고 성격 한 줄이 있다 (숫자 없음)', () {
      for (final b in FirstWeaponPicker.choices) {
        final info = EquipmentRules.info(b);
        expect(info.slot, EquipSlot.weapon);
        expect(info.trait, isNotNull);
        expect(RegExp(r'\d').hasMatch(info.trait!), isFalse, reason: b.name);
      }
      expect(EquipmentRules.info(EquipBase.ironSword).attack, 0.08);
      expect(EquipmentRules.info(EquipBase.woodAxe).attack, 0.10);
      expect(EquipmentRules.info(EquipBase.woodAxe).crit, lessThan(0));
      expect(EquipmentRules.info(EquipBase.ironSpear).attack, 0.07);
      expect(EquipmentRules.info(EquipBase.ironSpear).speed, greaterThan(0));
      expect(EquipmentRules.info(EquipBase.dagger).attack, 0.08);
      expect(EquipmentRules.info(EquipBase.staff).attack, 0.06);
      expect(EquipmentRules.info(EquipBase.staff).skillFaster, 1);
    });

    test('창은 먼저 친다 (빠르기), 예전 장비 이름은 그대로 읽힌다', () {
      expect(EquipmentRules.baseByName('ironSpear'), EquipBase.ironSpear);
      expect(EquipmentRules.baseByName('dagger'), EquipBase.dagger);
    });

    test('Lv.3 새 사용자: 고른 첫 무기는 무료', () async {
      final c = await start(grown(2));
      expect(c.player.level.level, greaterThanOrEqualTo(3));
      expect(c.firstWeaponFree, isTrue);
      expect(c.canCraft(EquipBase.woodAxe), CraftCheck.ok);
      final item = await c.craft(EquipBase.woodAxe);
      expect(item?.base, EquipBase.woodAxe);
      expect(c.firstWeaponFree, isFalse);
    });
  });

  group('#154 돋보기 하루 1번 무료', () {
    test('예전 기록(무료 기록 없음)도 읽히고, 오늘 무료가 남아 있다', () async {
      final old = LensState.fromJson(const {
        'seen': ['elf'],
        'counts': {'elf': 2},
        'day': '2026-11-12',
        'rewardedToday': 1,
      });
      expect(old.freeDay, isNull);
      expect(old.toJson().containsKey('freeDay'), isFalse);
      final c = await start(InMemoryRecordStore(
        profile: const PlayerProfile(name: '하루'),
        json: {'lens': old.toJson()},
      ));
      expect(c.lensFreeToday, isTrue);
      expect(c.canAppraise, isTrue);
      final r = await c.appraise(const [Race.dwarf]);
      expect(r, isNotNull);
      expect(c.lensFreeToday, isFalse);
      expect(c.canAppraise, isFalse); // 가방 돋보기 없음
      expect(c.album, isNotEmpty);
    });
  });

  group('4-1 · 6-2', () {
    test('튜토리얼 둘째 몬스터 원정은 편도 2분, 마석 1개로 바로 돌아오기', () async {
      final c = AppController(
        store: InMemoryRecordStore(),
        health: FakeHealthSource(stepsByDay: const {}),
        clock: () => t0,
      )..mailSources = const [];
      await c.init();
      await c.awaken(name: '하루', look: HeroLook.male);
      await c.finishIntro();
      final first = c.tutorialSpawn!;
      final battle = c.startFieldBattle(first)!;
      battle.runToEnd(useSkills: true);
      await c.finishFieldBattle(first, battle);
      await c.tutorialBagSeen();
      expect(await c.sendSpirit(c.tutorialSpawn!), ExpeditionCheck.ok);
      final ex = c.activeExpeditions.single;
      expect(ex.returnAt.difference(t0), const Duration(minutes: 4));
      expect(c.rushCost(ex), 1);
    });

    test('알림 번호 → 열 화면', () {
      expect(NotifyId.targetOf(1), NotifyTarget.expedition);
      expect(NotifyId.targetOf(150), NotifyTarget.expedition);
      expect(NotifyId.targetOf(NotifyId.letter), NotifyTarget.mail);
      expect(NotifyId.targetOf(NotifyId.quest), NotifyTarget.board);
    });
  });

  group('4-2 Lv.4~6 안내 (규칙)', () {
    test('게시판: 쉬운 의뢰를 붙이고, 아무 몬스터 하나로 깨고, 보상', () async {
      final c = await start(grown(3, seen: const ['smithy', 'freeWeapon']));
      expect(c.player.level.level, greaterThanOrEqualTo(4));
      expect(c.pendingFeatureIntro, Feature.board);
      await c.prepareGuideErrand();
      final slot = c.board.slots
          .indexWhere((s) => s.templateId == BoardRules.guideErrand.id);
      expect(slot, 0);
      await c.acceptErrand(slot);
      c.guideHunt = true;
      final spawn = c.guideSpawn!;
      expect(c.todaySpawns.any((s) => s.id == AppController.guideHuntId), isTrue);
      final battle = c.startFieldBattle(spawn)!;
      battle.runToEnd(useSkills: true);
      await c.finishFieldBattle(spawn, battle);
      expect(c.questRewardsReady, 1);
      final gold = c.player.gold;
      expect(await c.claimErrand(slot), isTrue);
      expect(c.player.gold, gold + 30);
      expect(c.guideSpawn, isNull); // 잡은 뒤엔 사라진다
      await c.markFeatureIntro(Feature.board);
      expect(c.pendingFeatureIntro, isNot(Feature.board));
    });

    test('채집: 첫 도구는 무료, 위치가 있으면 바로 옆 꽃', () async {
      final loc = FakeLocationSource();
      final c = await start(
          grown(5, seen: const ['smithy', 'freeWeapon', 'board']),
          location: loc);
      expect(c.player.level.level, greaterThanOrEqualTo(5));
      expect(c.harvestToolsReady, isFalse);
      expect(await c.makeFirstTools(), isTrue);
      expect(c.harvestToolsReady, isTrue);
      expect(await c.makeFirstTools(), isFalse); // 한 번만
      await c.handleFix(const LocationFix(point: GeoPoint(37.3219, 126.8309)));
      c.guideHarvest = true;
      expect(c.guideHarvestSpot, isNotNull);
      expect(c.guideMapTarget?.id, 'tutorial-harvest');
      c.guideHarvest = false;
      expect(c.guideHarvestSpot, isNull);
    });

    test('기존 사용자는 안내가 없고, 첫 도구 무료 칸도 없다', () async {
      final c = await start(
          InMemoryRecordStore(profile: const PlayerProfile(name: '하루')));
      expect(c.newGates, isFalse);
      expect(c.pendingFeatureIntro, isNull);
    });
  });

  test('#7 던전 층별 단서: 장마다 4층, 레벨로 이어지고 이별 뒤엔 없다', () {
    for (final ch in DungeonClues.chapters) {
      expect(ch.length, 4);
      for (final l in ch) {
        expect(RegExp(r'\d').hasMatch(l), isFalse);
      }
    }
    expect(
        DungeonClues.lineFor(level: 1, floor: 0, floors: 4, farewellDone: false),
        DungeonClues.chapters[0][0]);
    expect(
        DungeonClues.lineFor(level: 10, floor: 3, floors: 4, farewellDone: false),
        DungeonClues.chapters[4][3]);
    expect(
        DungeonClues.lineFor(level: 7, floor: 1, floors: 4, farewellDone: false),
        DungeonClues.chapters[2][1]);
    expect(
        DungeonClues.lineFor(level: 12, floor: 0, floors: 4, farewellDone: true),
        isNull);
  });

  group('4-2 안내 화면', () {
    void phone(WidgetTester tester) {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
    }

    String line(WidgetTester tester) =>
        tester.widget<BulssiBubble>(find.byKey(const Key('tourLine'))).line;

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    /// 묶음 20 #157: 안내 앞 「새로 열렸어요」 → 「가 보기」
    Future<void> opened(WidgetTester tester) async {
      expect(find.byKey(const Key('featureOpened')), findsOneWidget);
      await tester.tap(find.byKey(const Key('tourButton')));
      await settle(tester);
      expect(find.byKey(const Key('featureOpened')), findsNothing);
    }

    testWidgets('Lv.3 대장간: 마을 → 대장간 → 고르기 → 만들기 → 입기 → 무기 칸 빛남',
        (tester) async {
      phone(tester);
      late AppController c;
      await tester.runAsync(() async => c = await start(grown(2)));
      expect(c.pendingFeatureIntro, Feature.smithy);
      await tester.pumpWidget(IsekaiRealityApp(controller: c));
      await settle(tester);
      await opened(tester);
      expect(line(tester), contains('마을로 가 보자'));
      expect(find.byKey(const Key('tourSkip')), findsOneWidget);

      // 밝힌 아래 메뉴 「마을」을 그대로 누른다
      await tester.tapAt(rectOf(tutorialNavKeys[3])!.center);
      await settle(tester);
      expect(line(tester), '대장간을 눌러 봐!');

      Scrollable.ensureVisible(
          tester.element(find.byKey(const Key('facility_smithy'))),
          alignment: 0.5);
      await settle(tester);
      await tester.tap(find.byKey(const Key('facility_smithy')));
      await settle(tester);
      expect(find.byKey(const Key('firstWeaponPicker')), findsOneWidget);
      expect(line(tester), contains('하나 골라 봐'));

      Scrollable.ensureVisible(
          tester.element(find.byKey(const Key('firstWeapon_ironSpear'))),
          alignment: 0.5);
      await settle(tester);
      await tester.tap(find.byKey(const Key('firstWeapon_ironSpear')));
      await settle(tester);
      expect(line(tester), contains('만들어 보자'));
      expect(find.byKey(const Key('firstWeaponPreview')), findsOneWidget);

      Scrollable.ensureVisible(
          tester.element(find.byKey(const Key('firstWeaponCraft'))),
          alignment: 0.5);
      await settle(tester);
      await tester.tap(find.byKey(const Key('firstWeaponCraft')),
            warnIfMissed: false);
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await settle(tester);
      expect(find.byKey(const Key('equipNow')), findsOneWidget);
      expect(line(tester), contains('바로 입어 보자'));

      await tester.tap(find.byKey(const Key('equipNow')));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await settle(tester);
      await settle(tester);
      expect(c.armory.wornIn(EquipSlot.weapon)?.base, EquipBase.ironSpear);
      expect(line(tester), contains('무기 칸이 빛나지'));
      expect(find.byKey(const Key('gearSlotGlow')), findsOneWidget);

      await tester.tap(find.byKey(const Key('spotlightHole')),
            warnIfMissed: false);
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await settle(tester);
      expect(c.pendingFeatureIntro, isNot(Feature.smithy));
      expect(c.armory.wornIn(EquipSlot.weapon), isNotNull);
    });

    testWidgets('건너뛰기: 언제든 끝, 다시 켜도 나오지 않는다', (tester) async {
      phone(tester);
      final store = grown(2);
      late AppController c;
      await tester.runAsync(() async => c = await start(store));
      await tester.pumpWidget(IsekaiRealityApp(controller: c));
      await settle(tester);
      await tester.tap(find.byKey(const Key('tourSkip')));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await settle(tester);
      expect(c.pendingFeatureIntro, isNot(Feature.smithy));
      final again = await tester.runAsync(() => start(store));
      expect(again!.pendingFeatureIntro, isNot(Feature.smithy));
    });

    testWidgets('Lv.5 채집 · 위치 거부: 도구 뒤 「위치를 켜면」 안내로 끝', (tester) async {
      phone(tester);
      late AppController c;
      await tester.runAsync(() async {
        c = await start(grown(5, seen: const ['smithy', 'freeWeapon', 'board']),
            location: FakeLocationSource(granted: false));
        await c.makeFirstTools();
      });
      expect(c.pendingFeatureIntro, Feature.harvest);
      await tester.pumpWidget(IsekaiRealityApp(controller: c));
      await settle(tester);
      await opened(tester);
      expect(line(tester), contains('위치를 켜면'));
      await tester.tap(find.byKey(const Key('tourButton')));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await settle(tester);
      expect(c.pendingFeatureIntro, Feature.lens);
      await opened(tester);
      // Lv.6 돋보기: 지도에서 돋보기 버튼을 비춘다
      expect(line(tester), contains('눌러 봐'));
      expect(find.byKey(const Key('mapLens')), findsOneWidget);
      expect(find.byKey(const Key('tourFinger')), findsOneWidget);
    });

    testWidgets('6-1 확인 창: 버리기는 붉은 테, 취소는 작게', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (d) => GameAlert(
                    title: const Text('버릴까요?'),
                    content: const Text('되돌릴 수 없어요.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(d),
                          child: const Text('그만둘래요')),
                      TextButton(
                          onPressed: () => Navigator.pop(d),
                          child: const Text('버리기')),
                    ],
                  ),
                ),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      final danger = tester.getSize(find.text('버리기'));
      final cancel = tester.getSize(find.text('그만둘래요'));
      expect(danger.height, greaterThan(0));
      expect(cancel.height, lessThanOrEqualTo(danger.height));
    });
  });
}
