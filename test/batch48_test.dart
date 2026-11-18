// 묶음 48 #230: 마을 새 건물 「약초밭」 · 포포

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/garden_state.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/features/village/garden_screen.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'support/npc_seed.dart';

Map<String, dynamic> _npc({
  Map<String, int> points = const {},
  Map<String, int> done = const {},
  Map<String, dynamic> active = const {},
  Map<String, int> tally = const {},
}) =>
    {
      'v': 1,
      'points': points,
      'shown': {
        for (final e in points.entries) e.key: NpcRules.stageOf(e.value).index,
      },
      'done': done,
      'active': active,
      'tally': tally,
    };

/// 11-15에 심은 밭 (그날 걸음 0 → 그 뒤 걸음이 모두 셈)
/// 심은 칸 ([ago] 칸 → 몇 분 전에 심었는지, 없으면 오래전 = 다 자람)
Map<String, dynamic> _garden(Map<int, String> seeds, {Map<int, int> ago = const {}}) => GardenState(plots: {
      for (final e in seeds.entries)
        e.key: GardenPlot(
            seed: e.value,
            day: '2026-11-15',
            steps: 0,
            at: ago[e.key] == null ? 0 : DateTime(2026, 11, 16, 10).subtract(Duration(minutes: ago[e.key]!)).millisecondsSinceEpoch),
    }).toJson();

void main() {
  group('규칙', () {
    test('밭 칸 · 씨앗 걸음 · 자람 단계 · 거두는 재료', () {
      expect(GardenRules.plotsFor(0), 3);
      expect(GardenRules.plotsFor(1), 3);
      expect(GardenRules.plotsFor(2), 4);
      expect(GardenRules.plotsFor(3), 5);
      expect(GardenRules.plotsFor(4), 6);
      expect(GardenRules.need(MaterialId.herbSeed), 2000);
      expect(GardenRules.need(MaterialId.flowerSeed), 4000);
      expect(GardenRules.need(MaterialId.sporeSeed), 4000);
      expect(GardenRules.need(MaterialId.glowSeed), 8000);
      expect(GardenRules.need(MaterialId.herbSeed, dew: true), lessThan(2000));
      expect(GardenRules.stageOf(0, 2000), 0);
      expect(GardenRules.stageOf(1000, 2000), 1);
      expect(GardenRules.stageOf(2000, 2000), 2);
      expect(GardenRules.yieldOf(MaterialId.herbSeed, 11), MaterialId.herb);
      expect(GardenRules.yieldOf(MaterialId.flowerSeed, 11), MaterialId.autumnPetal);
      expect(GardenRules.yieldOf(MaterialId.sporeSeed, 11), MaterialId.shadeMushroom);
      expect(GardenRules.yieldOf(MaterialId.glowSeed, 11), MaterialId.sunPollen);
      expect(GardenRules.gatherSeed(HarvestKind.herb), MaterialId.herbSeed);
      expect(GardenRules.gatherSeed(HarvestKind.ore), isNull);
      // 씨앗 그림은 seed_○○
      expect(Materials.info(MaterialId.glowSeed).asset, 'assets/images/seed_glow.webp');
      expect(Materials.info(MaterialId.herb).asset, 'assets/images/mat_herb.webp');
    });

    test('포포: 부탁 4 · 단계 대사 · 선물 우편 · 작은 부탁 · 쪽지 · 이슬병 · 칭호', () {
      expect(VillageRules.npc(Npc.popo).name, '포포');
      expect(VillageRules.facilityName('garden'), '약초밭');
      expect(VillageRules.buildLevels['garden'], 9);
      final rs = NpcRules.of(Npc.popo);
      expect(rs, hasLength(4));
      expect([for (final r in rs) r.level], [9, 10, 13, 17]);
      expect(rs.last.special?.title, TitleId.forestKeeper);
      expect(TitleRules.info(TitleId.forestKeeper).name, '숲을 기르는 자');
      expect(NpcSmallRules.notesOf('popo'), hasLength(2));
      expect(NpcSmallRules.relicOf(Npc.popo).asset, 'item_popoDew');
      expect(TownRules.info(ShopItem.herbSeed).minLevel, 9);
      for (final l in VillageRules.npc(Npc.popo).lines.values) {
        expect(l, hasLength(2));
      }
    });
  });

  group('열림 · 공사 중', () {
    test('Lv.6 터 닦기 · 7 뼈대 · 8 거의 완성 · 9 완공', () async {
      for (final (lv, st) in const [(6, 1), (7, 2), (8, 3)]) {
        final c = await startNpc(level: lv);
        expect(c.gardenOpen, isFalse, reason: '$lv');
        expect(c.buildStage('garden'), st, reason: '$lv');
        expect(c.npcHomeOpen(Npc.popo), isFalse);
      }
      final c = await startNpc(level: 9);
      expect(c.gardenOpen, isTrue);
      expect(c.buildStage('garden'), isNull);
      expect(c.npcHomeOpen(Npc.popo), isTrue);
    });

    test('예전 기록 Lv.9 이상: 완공 연출 없이 열림 (#124)', () async {
      final c = await startNpc(level: 12);
      expect(c.builtPending, isNot(contains('garden')));
    });

    test('「새로 열렸어요」 카드를 넘기면 포포가 약초 씨앗 2개 (한 번만)', () async {
      final c = await startNpc(level: 9, mats: const {});
      await c.markGardenIntro();
      expect(c.player.materialCount(MaterialId.herbSeed), 2);
      expect(c.garden.starter, isTrue);
      await c.markGardenIntro();
      expect(c.player.materialCount(MaterialId.herbSeed), 2);
    });
  });

  group('심기 · 자라기 · 거두기', () {
    test('씨앗을 심으면 가방에서 하나 · 빈 칸에만 · 처음 3칸', () async {
      final c = await startNpc(level: 9, mats: const {'herbSeed': 2});
      expect(c.gardenPlotCount, 3);
      expect(await c.plantSeed(0, MaterialId.herbSeed), isTrue);
      expect(c.player.materialCount(MaterialId.herbSeed), 1);
      expect(await c.plantSeed(0, MaterialId.herbSeed), isFalse);
      expect(await c.plantSeed(3, MaterialId.herbSeed), isFalse);
      expect(await c.plantSeed(1, MaterialId.glowSeed), isFalse); // 없음
      final v = c.plotView(0);
      expect(v.seed, MaterialId.herbSeed);
      expect(v.walked, 0);
      expect(v.ready, isFalse);
      expect(v.left, 240, reason: '묶음 66: 약초 씨앗 4시간');
    });

    test('심은 시각부터 자람 · 다 자라면 빨간 점 · 거두면 재료 2개 이상', () async {
      final c = await startNpc(
        level: 9,
        todaySteps: const {'2026-11-16': 2500},
        json: {'garden': _garden({0: 'herbSeed', 1: 'glowSeed'}, ago: {1: 450})},
      );
      final a = c.plotView(0), b = c.plotView(1);
      expect(a.walked, greaterThanOrEqualTo(a.need));
      expect(a.ready, isTrue);
      expect(a.stage, 2);
      expect(b.ready, isFalse);
      expect(b.left, 1440 - 450);
      expect(c.gardenReady, 1);
      final herb0 = c.player.materialCount(MaterialId.herb);
      expect(await c.harvestPlot(1), isNull);
      final r = (await c.harvestPlot(0))!;
      expect(Materials.isHerb(r.material), isTrue, reason: '묶음 67: 이세계 약초 중 하나');
      expect(r.count, greaterThanOrEqualTo(2));
      expect(c.player.materialCount(MaterialId.herb), herb0 + r.count);
      expect(c.garden.plots.containsKey(0), isFalse);
      expect(c.garden.harvested, 1);
      expect(c.npcState.tally[NpcTally.gardenHarvest], 1);
      expect(c.gardenReady, 0);
    });

    test('포포 부탁을 끝낼수록 밭이 넓어짐 · 4번 특별 보상: 칭호 + 6칸 + 빛나는 씨앗 2', () async {
      final c = await startNpc(
        level: 17,
        npc: _npc(
          points: {'popo': 60},
          done: {'popo': 3},
          active: {
            'popo': {'i': 3, 'day': '2026-11-16', 'base': {NpcTally.gardenGlow: 0}, 'steps': 0},
          },
          tally: {NpcTally.gardenGlow: 1},
        ),
      );
      expect(c.gardenPlotCount, 5);
      expect(c.requestReady(Npc.popo), isTrue);
      final done = (await c.completeRequest(Npc.popo))!;
      expect(done.special?.kind, NpcSpecialKind.garden);
      expect(done.got.join(' '), contains('6칸'));
      expect(c.gardenPlotCount, 6);
      expect(c.player.materialCount(MaterialId.glowSeed), 2);
      expect(c.player.titles, contains(TitleId.forestKeeper));
    });
  });

  testWidgets('약초밭 화면: 포포 · 밭 3칸 + 잠긴 칸 · 「약 ○시간 뒤」 · 거두기', (tester) async {
    tester.view.physicalSize = const Size(750, 1334);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    late AppController c;
    await tester.runAsync(() async => c = await startNpc(
          level: 9,
          mats: const {'herbSeed': 1, 'flowerSeed': 1},
          todaySteps: const {'2026-11-16': 2500},
          json: {'garden': _garden({0: 'herbSeed', 1: 'flowerSeed'}, ago: {1: GardenRules.growMinutes(MaterialId.flowerSeed) - 180})},
        ));
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => TopNoticeHost(child: child!),
        home: GardenScreen(controller: c)));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byKey(const Key('npc_popo')), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      expect(find.byKey(Key('gardenPlot_$i')), findsOneWidget);
    }
    for (var i = 3; i < 6; i++) {
      expect(find.byKey(Key('gardenLocked_$i')), findsOneWidget);
    }
    expect(find.byKey(const Key('gardenHarvest_0')), findsOneWidget);
    expect(find.byKey(const Key('gardenPlant_2')), findsOneWidget);
    expect(find.text('약 3시간 뒤'), findsOneWidget);
    await tester.tap(find.byKey(const Key('gardenHarvest_0')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(c.garden.plots.containsKey(0), isFalse);
    await tester.pump(const Duration(seconds: 9));
  });
}
