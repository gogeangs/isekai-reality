// 묶음 67: 새 몬스터 띠 · #271 거래소 ★2 · ★3 · #272 건물 안 바탕 · #273 이세계 약초 7종
// (서버 판정은 node 시험 market.test.js)

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/building_state.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/models/garden_state.dart';
import 'package:isekai_reality/core/models/player_state.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/theme/ornaments.dart';

import 'batch54_test.dart' as b54;
import 'support/npc_seed.dart';

void main() {
  group('#271 거래소 ★2 · ★3', () {
    test('바르칸 · 고치는 값 · 칸 5 → 7 → 9 · ★3 값을 정해 올린 물건 72시간', () async {
      final i = BuildingRules.info(Building.market);
      expect(i.npc, Npc.barkan);
      expect(i.to2.gold, 450);
      expect(i.to2.mats, {MaterialId.hardWood: 5, MaterialId.ironShard: 6});
      expect(i.to3.gold, 950);
      expect(i.to3.mats, {MaterialId.ironIngot: 3, MaterialId.hardWood: 4, MaterialId.runeStone: 1});
      expect(i.doneFor(2), '가판을 하나 더 냈어! 이제 물건을 더 많이 올려도 돼.');
      expect(i.doneFor(3), contains('사흘까지'));
      expect([1, 2, 3].map(BuildingRules.marketSlots), [5, 7, 9]);
      expect([1, 2, 3].map(BuildingRules.marketFixedHours), [48, 48, 72]);
      final cat = jsonDecode(File('firebase/functions/src/market_catalog.json').readAsStringSync()) as Map;
      expect(cat['slotsByStar'], [5, 7, 9]);
      expect(cat['fixedHoursByStar'], [48, 48, 72]);
      b54.now = DateTime(2026, 11, 20, 10);
      final c = await b54.start(b54.rich(stars: const {'market': 3}));
      expect(c.marketSlots, c.buildingsOpen ? 9 : 5);
    });
  });

  group('#272 건물 안 바탕', () {
    test('여섯 곳이 그림 이름으로 바탕을 깔고, 그림이 없으면 지금처럼', () {
      for (final (f, k) in [
        ('lib/features/smithy/smithy_screen.dart', 'smithy'),
        ('lib/features/town/inn_screen.dart', 'inn'),
        ('lib/features/alchemy/alchemy_screen.dart', 'alchemy'),
        ('lib/features/town/shop_screen.dart', 'shop'),
        ('lib/features/village/tavern_screen.dart', 'tavern'),
        ('lib/features/jobs/guild_screen.dart', 'guild'),
      ]) {
        expect(File(f).readAsStringSync(), contains("interior: '$k'"), reason: f);
      }
      expect(InteriorArt.asset('inn'), 'assets/images/bg_in_inn.webp');
    });

    testWidgets('그림이 없어도 화면이 그려짐', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: NightBackground(interior: 'nothing', child: Text('목록')))));
      await tester.pump();
      expect(find.text('목록'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('#273 이세계 약초 7종', () {
    test('이름 · 설명 · 묶음 · 파는 값 · 저장 키는 그대로', () {
      expect(Materials.info(MaterialId.herb).name, '엘라린 잎');
      expect(MaterialId.herb.name, 'herb');
      expect(Materials.herbGroup, hasLength(7));
      expect(Materials.info(MaterialId.mandragora).rare, isTrue);
      expect(BagRules.materialPrice(MaterialId.gortRoot), BagRules.materialPrice(MaterialId.herb));
      expect(BagRules.materialPrice(MaterialId.mandragora), greaterThan(BagRules.materialPrice(MaterialId.herb)));
      expect(Materials.needName(MaterialId.herb), '아무 약초');
      final i = Materials.displayOrder.indexOf(MaterialId.herb);
      expect(Materials.displayOrder.sublist(i, i + 7), Materials.herbGroup);
      for (final m in Materials.herbGroup) {
        expect(File(Materials.info(m).asset).existsSync(), isTrue, reason: m.name);
        expect(MarketRules.matTradable(m), isTrue, reason: m.name);
      }
      expect(File('firebase/functions/src/market_catalog.json').readAsStringSync(), contains('"mandragora"'));
      expect(TownRules.info(ShopItem.values.firstWhere((s) => TownRules.info(s).material == MaterialId.herb)).material, MaterialId.herb);
    });

    test('장소 · 시간에 따라 다른 약초 · 만드라고라 가끔', () {
      final r = math.Random(1);
      expect(HarvestRules.herbAt(LandKind.forest, false, r), MaterialId.silvaFern);
      expect(HarvestRules.herbAt(LandKind.water, false, r), MaterialId.mireaGrass);
      expect(HarvestRules.herbAt(LandKind.mountain, false, r), MaterialId.zephiraLeaf);
      expect(HarvestRules.herbAt(null, false, r), MaterialId.herb);
      final park = [for (var i = 0; i < 400; i++) HarvestRules.herbAt(LandKind.park, false, r)];
      final gort = park.where((m) => m == MaterialId.gortRoot).length / park.length;
      expect(gort, closeTo(0.4, 0.08));
      expect(park.toSet(), {MaterialId.herb, MaterialId.gortRoot});
      final night = [for (var i = 0; i < 400; i++) HarvestRules.herbAt(LandKind.forest, true, r)];
      expect(night.where((m) => m == MaterialId.noctiGrass).length / night.length, closeTo(0.5, 0.08));
      var mandra = 0;
      for (var i = 0; i < 2000; i++) {
        final y = HarvestRules.yieldOf(HarvestKind.herb, HarvestGrade.good, r, land: LandKind.forest);
        expect(y.keys.first, MaterialId.silvaFern);
        if (y.containsKey(MaterialId.mandragora)) mandra++;
      }
      expect(mandra / 2000, closeTo(0.05, 0.015));
    });

    test('「약초」가 필요한 곳은 아무 약초 · 흔한 것부터 빠짐 (예전 기록 그대로)', () {
      final p = PlayerState.fromHistory(name: 'x', history: [
        DailyRecord(date: DateTime(2026, 11, 19), gains: {'herb': 1, 'gortRoot': 2, 'silvaFern': 3, 'mandragora': 1}),
        DailyRecord(date: DateTime(2026, 11, 20), spends: {'herb': 4}),
      ]);
      expect(p.materialExact(MaterialId.herb), 0);
      expect(p.materialExact(MaterialId.gortRoot), 0);
      expect(p.materialExact(MaterialId.silvaFern), 2);
      expect(p.materialExact(MaterialId.mandragora), 1);
      expect(p.materialCount(MaterialId.herb), 3, reason: '아무 약초');
      final old = PlayerState.fromHistory(name: 'x', history: [
        DailyRecord(date: DateTime(2026, 11, 10), gains: {'herb': 5}, spends: {'herb': 2}),
      ]);
      expect(old.materialExact(MaterialId.herb), 3);
    });

    test('연금술: 약초 7종 모두 「약초」 칸에 맞음 · 잘 맞는 약초면 품질 +1 · 레시피 책 한 줄', () async {
      expect(AlchemyRules.bestHerb(PotionId.antidote), MaterialId.gortRoot);
      expect(AlchemyRules.bestHerb(PotionId.mana), MaterialId.mireaGrass);
      expect(AlchemyRules.bestHerb(PotionId.healBig), MaterialId.mandragora);
      final r = AlchemyRules.info(PotionId.antidote).recipe;
      final withGort = [for (final m in r) m == MaterialId.herb ? MaterialId.gortRoot : m];
      expect(AlchemyRules.match(AlchemyRules.asRecipe(withGort))?.id, PotionId.antidote);
      expect(AlchemyRules.qualityWith(PotionId.antidote, perfect: false, put: withGort).index,
          greaterThan(AlchemyRules.qualityWith(PotionId.antidote, perfect: false, put: [for (final m in r) m == MaterialId.herb ? MaterialId.silvaFern : m]).index));
    });

    test('마을 사람 부탁 「약초 2개」에 섞어 내기 · 건물 고치기도 아무 약초', () async {
      final c = await startNpc(level: 12, mats: const {'gortRoot': 1, 'silvaFern': 1});
      expect(c.player.materialCount(MaterialId.herb), 2);
      final step = NpcSmallRules.smalls[Npc.marta]!
          .expand((s) => s.steps)
          .firstWhere((s) => s.kind == RequestStepKind.deliver);
      expect(NpcRules.matsOf(step), containsAll(Materials.herbGroup));
    });

    test('약초밭 약초 씨앗 → 다섯 가지 중 하나', () async {
      final now = DateTime(2026, 11, 20, 14);
      final seen = <MaterialId>{};
      for (var k = 0; k < 6; k++) {
        final c = await startNpc(
          level: 12,
          clock: () => now,
          json: {
            'garden': GardenState(plots: {
              0: GardenPlot(seed: 'herbSeed', day: '2026-11-20', steps: 0, at: now.subtract(const Duration(hours: 5)).millisecondsSinceEpoch),
            }).toJson(),
          },
        );
        final h = (await c.harvestPlot(0))!;
        expect(Materials.herbGroup.take(5), contains(h.material));
        seen.add(h.material);
      }
      expect(seen, isNotEmpty);
      expect(BuildingState.fromJson(const {}).stars, isEmpty);
    });
  });
}
