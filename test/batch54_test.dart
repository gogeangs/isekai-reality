// 묶음 54: 건물 레벨업 ★2·★3 (10채) + 백업 위치 덜어 내기

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/building_state.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/cloud/backup_scrub.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/town/inn_screen.dart';
import 'package:isekai_reality/features/village/village_screen.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'batch52_test.dart' as b52;

/// 지금 시각 (시험마다 옮긴다)
DateTime now = b52.t0;

/// 결말을 본 계정 + 금화 · 고칠 재료 넉넉히 · 건물 단계 [stars]
InMemoryRecordStore rich({Map<String, int> stars = const {}, bool king = true, bool mats = true}) {
  final s = b52.account(king: king);
  s.upsert(DailyRecord(date: DateTime(2026, 11, 2), gains: {
    Wallet.gold: 30000,
    if (mats)
      for (final m in MaterialId.values)
        if (BuildingRules.all.any((i) =>
            i.to2.mats.containsKey(m) || i.to3.mats.containsKey(m)))
          m.name: 30,
  }));
  if (stars.isNotEmpty) s.saveJson('buildings', BuildingState(stars: stars).toJson());
  return s;
}

Future<AppController> start(InMemoryRecordStore s) async {
  final h = FakeHealthSource(stepsByDay: {b52.todayKey: 1000});
  final c = AppController(
    store: s,
    health: h,
    clock: () => now,
    random: math.Random(3),
  )..mailSources = const [];
  await c.init();
  return c;
}

Map<String, int> all(int star) => {for (final b in Building.values) b.name: star};

void main() {
  setUp(() => now = b52.t0);

  group('규칙', () {
    test('10채 · ★3 엔 귀한 재료 하나 · 고치는 시간 1시간 · 4시간 · 그림', () {
      expect(BuildingRules.all, hasLength(11));
      expect({for (final i in BuildingRules.all) i.id}, Building.values.toSet());
      for (final i in BuildingRules.all) {
        final rare = [
          for (final m in i.to3.mats.keys)
            if (Materials.info(m).rare) m,
        ];
        expect(rare, hasLength(1), reason: i.name);
        expect(i.to3.mats[rare.single], 1, reason: i.name);
        expect(i.to2.mats.keys.where((m) => Materials.info(m).rare), isEmpty, reason: i.name);
        expect(i.to3.gold, greaterThan(i.to2.gold));
        expect(BuildingRules.ofNpc(i.npc), i.id);
        // 묶음 67 #271: 거래소는 칸 수 · 시간을 숫자로 (기획 결정) · 그림은 오기 전엔 ★1 그림
        if (i.id == Building.market) continue;
        expect(i.text2.contains(RegExp(r'\d')), isFalse);
        expect(i.text3.contains(RegExp(r'\d')), isFalse);
        for (final s in [2, 3]) {
          expect(File(i.assetFor(s)).existsSync(), isTrue, reason: i.assetFor(s));
        }
      }
      expect(BuildingRules.fixTime(2), const Duration(hours: 1));
      expect(BuildingRules.fixTime(3), const Duration(hours: 4));
      expect(BuildingRules.ofNpc(Npc.barkan), Building.market);
      expect(File('assets/images/food_mushroomSoup.webp').existsSync(), isTrue);
      expect(TavernRules.meal(Meal.mushroomSoup).name, '버섯 수프');
    });
  });

  group('고치기', () {
    test('결말 전엔 닫혀 있음', () async {
      final c = await start(rich(king: false));
      expect(c.buildingsOpen, isFalse);
      expect(c.buildingUpgradeOpen(Building.inn), isFalse);
      expect(c.canUpgradeBuilding(Building.inn), isFalse);
    });

    test('가져다 주기 → 고치는 중(시설 그대로) → 1시간 뒤 ★2 · 연출 한 번 → ★3 은 4시간', () async {
      final c = await start(rich());
      expect(c.buildingsOpen, isTrue);
      expect(c.buildingStar(Building.inn), 1);
      final need = c.buildingNeed(Building.inn)!;
      final gold0 = c.player.gold;
      final wood0 = c.player.materialCount(MaterialId.hardWood);
      expect(c.buildingProgress(Building.inn), (need.mats.length + 1, need.mats.length + 1));
      expect(await c.deliverBuilding(Building.inn), isTrue);
      expect(c.player.gold, gold0 - need.gold);
      expect(c.player.materialCount(MaterialId.hardWood),
          wood0 - need.mats[MaterialId.hardWood]!);
      expect(c.buildingFixing(Building.inn), isTrue);
      expect(c.buildingStar(Building.inn), 1);
      expect(c.buildingNeed(Building.inn), isNotNull);
      expect(c.canUpgradeBuilding(Building.inn), isFalse);
      // 고치는 동안에도 여관은 그대로
      expect(await c.restAtInn(), isTrue);
      expect(c.starPending, isEmpty);

      now = now.add(const Duration(minutes: 61));
      expect(c.buildingStar(Building.inn), 2);
      expect(c.starPending, {'inn'});
      await c.refreshVitals();
      // 다시 켜도 ★2
      final again = await start(c.store as InMemoryRecordStore);
      expect(again.buildingStar(Building.inn), 2);
      expect(again.starPending, {'inn'});
      await again.markStarSeen({'inn'});
      expect(again.starPending, isEmpty);

      final n3 = again.buildingNeed(Building.inn)!;
      expect(n3.mats.containsKey(MaterialId.sturdyKnot), isTrue);
      expect(await again.deliverBuilding(Building.inn), isTrue);
      now = now.add(const Duration(hours: 3));
      expect(again.buildingStar(Building.inn), 2);
      now = now.add(const Duration(hours: 1, minutes: 1));
      expect(again.buildingStar(Building.inn), 3);
      expect(again.buildingNeed(Building.inn), isNull);
      expect(again.buildingUpgradeOpen(Building.inn), isFalse);
    });

    test('재료가 모자라면 못 고침 (모은 정도만)', () async {
      final c = await start(rich(mats: false));
      final (have, total) = c.buildingProgress(Building.smithy);
      expect(have, 1); // 금화만
      expect(total, 3);
      expect(c.canUpgradeBuilding(Building.smithy), isFalse);
      expect(await c.deliverBuilding(Building.smithy), isFalse);
    });

    test('예전 기록(건물 기록 없음)은 모두 ★1, 효과 없음', () async {
      final c = await start(b52.account());
      for (final b in Building.values) {
        expect(c.buildingStar(b), 1);
      }
      expect(c.cauldronCount, c.alchemy.cauldrons);
      expect(c.eggSlots, 1);
      expect(c.trialMarks, TrainingRules.trialMarks);
      expect(c.mealMenu.map((m) => m.id), isNot(contains(Meal.mushroomSoup)));
    });
  });

  group('효과', () {
    test('★2: 여관 휴식 짧게 · 게시판 칸 · 잡화상 물건 · 펫 쉼터 · 약초밭 칸 · 하루 훈련 두 번 · 주점', () async {
      final base = await start(rich());
      final c = await start(rich(stars: all(2)));
      // 여관
      await c.restAtInn();
      expect(c.innSpeed, InnRules.star2Speed); // 묶음 81 #373: 회복 속도
      // 게시판
      expect(c.board.slots.length, base.board.slots.length + 1);
      expect(c.errandsPerDay, BoardRules.errandsPerDay + 1);
      // 잡화상
      final items = [for (final i in c.shopItems) i.item];
      expect(items, containsAll([ShopItem.hardWood, ShopItem.tannedLeather]));
      expect([for (final i in base.shopItems) i.item], isNot(contains(ShopItem.hardWood)));
      expect(await c.buy(ShopItem.hardWood), PurchaseCheck.ok);
      // 대장간 · 연금술 · 조합
      expect(c.smithGradeBonus(EquipBase.values.first),
          base.smithGradeBonus(EquipBase.values.first) + BuildingRules.smithGrade);
      expect(c.guildDetailHint, isTrue);
      expect(base.guildDetailHint, isFalse);
      // 약초밭
      expect(c.gardenPlotCount, base.gardenPlotCount + 1);
      // 훈련장: 하루 두 번
      expect(await c.startDailyTraining(), isNotNull);
      expect(c.dailyTrainingDone, isFalse);
      expect(c.dailyTrainingExtra, isTrue);
      expect(await c.startDailyTraining(), isNotNull);
      expect(c.dailyTrainingDone, isTrue);
      expect(await c.startDailyTraining(), isNull);
      expect(await base.startDailyTraining(), isNotNull);
      expect(base.dailyTrainingDone, isTrue);
      // 주점: 모험가 +2 · 버섯 수프
      expect(c.rosterLimit, base.rosterLimit + 2);
      expect(c.mealMenu.map((m) => m.id), contains(Meal.mushroomSoup));
      expect(await c.eatMeal(Meal.mushroomSoup), isTrue);
      expect(c.mealOn(Meal.mushroomSoup), isTrue);
      expect(await base.eatMeal(Meal.mushroomSoup), isFalse);
    });

    test('★3: 강화 쉬움 · 수리비 · 가마솥 · 알 둘 · 시련 20판 · 모험가 +4 · 한 끼 다음 날 낮까지', () async {
      final base = await start(rich());
      final c = await start(rich(stars: all(3)));
      expect(c.enhanceChanceShown(10),
          closeTo(base.enhanceChanceShown(10) + BuildingRules.smithEnhance, 1e-9));
      expect(c.cauldronCount, base.cauldronCount + 1);
      expect(c.eggSlots, 2);
      expect(c.trialMarks, [...TrainingRules.trialMarks, 20]);
      expect(TrainingRules.trialReward(20), isNotEmpty);
      expect(c.rosterLimit, base.rosterLimit + 4);
      // 잡화상 ★3: 하루 개수 +1
      expect(c.shopLeft(ShopItem.healSmall), base.shopLeft(ShopItem.healSmall) + 1);
      // 한 끼: 다음 날 11시엔 아직 · 12시엔 끝
      expect(await c.eatMeal(Meal.skewer), isTrue);
      now = DateTime(2026, 11, 18, 11);
      expect(c.activeMeal, Meal.skewer);
      now = DateTime(2026, 11, 18, 12);
      expect(c.activeMeal, isNull);
    });

    test('잡화상 ★3 특별한 물건: 며칠 중 몇 날, 그날 하나', () {
      final days = [
        for (var d = 1; d <= 30; d++)
          TownRules.specialOf(DailyRecord.dayKeyOf(DateTime(2026, 12, d))),
      ];
      expect(days.whereType<ShopItem>(), isNotEmpty);
      expect(days.where((x) => x == null), isNotEmpty);
    });

    test('여관 ★3 (묶음 81 #373): 가득 찬 뒤 일어나면 잠시 HP · 기력 최대가 조금 늘어요', () async {
      final c = await start(rich(stars: all(3)));
      expect(c.innBoostOn, isFalse);
      final hp0 = c.maxHp;
      await c.restAtInn();
      now = now.add(const Duration(hours: 6));
      await c.refreshVitals();
      await c.stopResting();
      expect(c.innBoostOn, isTrue);
      expect(c.maxHp, greaterThan(hp0));
      now = now.add(InnRules.star3For + const Duration(minutes: 1));
      expect(c.innBoostOn, isFalse);
    });

    test('조합 ★2 힌트: 숙련도마다 얼마나 왔는지 문장으로 (숫자 없음)', () {
      final line = JobRules.detailLine(JobRules.jobs.first.id, (_) => 0);
      expect(line, contains('아직 갈 길이 멀어요'));
      expect(line.contains(RegExp(r'\d')), isFalse);
    });
  });

  group('백업 위치', () {
    test('첫 자리 · 안내 핀 · 섬 자리는 빼고, 원정 · 불러낸 몬스터는 칸 가운데로', () {
      final snap = <String, Object>{
        'json.nearAnchor': jsonEncode({'lat': 37.1234567, 'lng': 127.1234567}),
        'json.guidePins': jsonEncode({'pins': []}),
        'json.highland': jsonEncode({'slot': 'x', 'isle': 1, 'lat': 37.5, 'lng': 127.0}),
        'json.alchemy': jsonEncode({
          'called': [
            {'id': 'a', 'monster': 'slime', 'lat': 37.123456, 'lng': 127.654321, 'mods': []},
          ],
        }),
        'vitals.v1': jsonEncode({
          'expeditions': [
            {
              'lat': 37.1234567,
              'lng': 127.1234567,
              'fromLat': 37.1239,
              'fromLng': 127.1201,
              'route': [
                [37.12341, 127.12341],
                [37.12342, 127.12342],
                [37.13, 127.13],
              ],
            },
          ],
        }),
        'json.tavern': jsonEncode({'meals': 2}),
      };
      final out = BackupScrub.scrub(snap);
      expect(out.containsKey('json.nearAnchor'), isFalse);
      expect(out.containsKey('json.guidePins'), isFalse);
      final hl = jsonDecode(out['json.highland']! as String) as Map;
      expect(hl.containsKey('lat'), isFalse);
      expect(hl['isle'], 1);
      final ex = ((jsonDecode(out['vitals.v1']! as String) as Map)['expeditions'] as List).first as Map;
      final (la, ln) = BackupScrub.cell(37.1234567, 127.1234567);
      expect(ex['lat'], la);
      expect(ex['lng'], ln);
      expect(((ex['lat'] as double) - 37.1234567).abs(), lessThan(BackupScrub.cellLat));
      expect(ex['lat'], isNot(37.1234567));
      expect((ex['route'] as List), hasLength(2)); // 같은 칸 두 점은 하나로
      final called = ((jsonDecode(out['json.alchemy']! as String) as Map)['called'] as List).first as Map;
      expect(called['lat'], BackupScrub.cell(37.123456, 127.654321).$1);
      expect(out['json.tavern'], snap['json.tavern']);
      // 원래 스냅숏은 그대로
      expect(snap.containsKey('json.nearAnchor'), isTrue);
    });
  });

  group('화면', () {
    testWidgets('여관: 「★2로 고치기」 → 고치기 창 → 가져다 주기 → 고치는 중', (tester) async {
      tester.view.physicalSize = const Size(750, 1334);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      late AppController c;
      await tester.runAsync(() async => c = await start(rich()));
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => TopNoticeHost(child: child!),
          home: InnScreen(controller: c)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('upgradeOpen_inn')), findsOneWidget);
      await tester.tap(find.byKey(const Key('upgradeOpen_inn')));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('buildingSay')), findsOneWidget);
      expect(find.byKey(const Key('buildingNeed')), findsOneWidget);
      expect(find.byKey(const Key('buildingMat_hardWood')), findsOneWidget);
      await tester.tap(find.byKey(const Key('buildingDeliver')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(c.buildingFixing(Building.inn), isTrue);
      expect(find.byKey(const Key('upgradeFixing_inn')), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('마을: ★ 이름표 · 고치는 중 · 다 고치면 레벨업 연출', (tester) async {
      tester.view.physicalSize = const Size(750, 1334);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      late AppController c;
      await tester.runAsync(() async {
        final s = rich(stars: {'shop': 3});
        c = await start(s);
        await c.deliverBuilding(Building.inn);
        await c.deliverBuilding(Building.smithy);
      });
      now = now.add(const Duration(minutes: 61));
      await tester.runAsync(() => c.refreshVitals());
      // 대장간은 다시 고치는 중으로 (★3)
      await tester.runAsync(() async {
        await c.markStarSeen({'smithy'});
        await c.deliverBuilding(Building.smithy);
      });
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: VillageScreen(controller: c))));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('tagStar_shop')), findsOneWidget);
      expect(find.byKey(const Key('tagStar_inn')), findsOneWidget);
      expect(find.byKey(const Key('starReveal_inn')), findsOneWidget);
      expect(find.byKey(const Key('tagFixing_smithy')), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      expect(c.starPending, isEmpty);
    });
  });
}
