import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/geo/geo.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/models/gather_state.dart';
import 'package:isekai_reality/core/models/harvest_state.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/location/location_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/map/korea_area.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var now = DateTime(2026, 11, 12, 14);
  AppController make({Map<String, Map<String, dynamic>>? json}) => AppController(
        area: KoreaArea.area,
        store: InMemoryRecordStore(
          profile: const PlayerProfile(name: '하루'),
          history: [
            DailyRecord(date: DateTime(2026, 11, 10), gains: {
              Wallet.gold: 5000,
              MaterialId.ironIngot.name: 4,
              MaterialId.manaOre.name: 2,
              MaterialId.glowFireCore.name: 1,
            }),
          ],
          json: json,
        ),
        health: FakeHealthSource(stepsByDay: {'2026-11-12': 3000}),
        location: FakeLocationSource(),
        clock: () => now,
        random: Random(4),
        fallbackCenter: const GeoPoint(37.3219, 126.8309),
      )..mailSources = const [];

  group('#83 채집 2', () {
    test('250m 칸·80m, 새 자리 4종이 섞이고, 밤에는 버섯이 늘어난다', () {
      expect(HarvestRules.blockM, 250);
      expect(HarvestRules.reachM, 80);
      const center = GeoPoint(37.3219, 126.8309);
      final day = HarvestRules.spotsAround(center);
      final night = HarvestRules.spotsAround(center, night: true);
      expect(day.length, greaterThan(150));
      expect({for (final s in day) s.kind}, containsAll(HarvestKind.values));
      int mush(List<HarvestSpot> l) =>
          l.where((s) => s.kind == HarvestKind.mushroom).length;
      expect(mush(night), greaterThan(mush(day)));
      // 새 도구 붓과 자리마다 도구
      expect(HarvestRules.info(HarvestKind.relic).tool, HarvestTool.brush);
      expect(HarvestRules.info(HarvestKind.gem).tool, HarvestTool.pickaxe);
    });

    test('꽃은 계절 꽃잎, 보석은 속성 보석, 도구 등급·완벽 연속이 귀한 재료를 올린다', () {
      expect(HarvestRules.seasonPetal(4), MaterialId.springPetal);
      expect(HarvestRules.seasonPetal(11), MaterialId.autumnPetal);
      final f = HarvestRules.yieldOf(HarvestKind.flower, HarvestGrade.good, Random(1),
          month: 7);
      expect(f.keys.first, MaterialId.summerPetal);
      int rares(ToolTier t, int streak, {Element? el}) {
        final rng = Random(9);
        var n = 0;
        for (var i = 0; i < 2000; i++) {
          final y = HarvestRules.yieldOf(HarvestKind.gem, HarvestGrade.good, rng,
              tier: t, streak: streak, element: el);
          if (y.length > 1) n++;
        }
        return n;
      }

      final base = rares(ToolTier.stone, 0);
      expect(rares(ToolTier.mithril, 0), greaterThan(base));
      expect(rares(ToolTier.stone, 5), greaterThan(base));
      // 불 속성 곡괭이면 불꽃 보석이 잘 나온다
      final rng = Random(2);
      var fire = 0;
      for (var i = 0; i < 400; i++) {
        final y = HarvestRules.yieldOf(HarvestKind.gem, HarvestGrade.perfect, rng,
            element: Element.fire);
        if (y.containsKey(MaterialId.gemFire)) fire++;
      }
      expect(fire, greaterThan(40));
    });

    test('도구 등급 올리기: 재료·금화를 쓰고 내구도가 늘어난다, 속성 입히기', () async {
      final c = make();
      await c.init();
      expect(c.toolTier(HarvestTool.pickaxe), ToolTier.stone);
      expect(c.canUpgradeTool(HarvestTool.pickaxe), CraftCheck.ok);
      expect(await c.upgradeTool(HarvestTool.pickaxe), isTrue);
      expect(c.toolTier(HarvestTool.pickaxe), ToolTier.iron);
      expect(c.toolMaxOf(HarvestTool.pickaxe), 45);
      expect(c.player.materialCount(MaterialId.ironIngot), 2);
      expect(await c.imbueTool(HarvestTool.pickaxe, Element.fire), isTrue);
      expect(c.toolElement(HarvestTool.pickaxe), Element.fire);
      expect(c.harvestEase(HarvestKind.gem), 1);
    });

    test('완벽을 많이 쌓은 종류는 빠른 채집도 「좋음」 (숨김)', () {
      const h = HarvestState(perfects: {'herb': 10});
      expect(h.mastered(HarvestKind.herb), isTrue);
      expect(h.mastered(HarvestKind.ore), isFalse);
      // 예전 저장본은 붓이 없어도 새 붓으로 친다
      expect(const HarvestState(granted: true, tools: {'sickle': 3})
          .durability(HarvestTool.brush), HarvestRules.toolMax);
    });
  });

  group('#84 떠돌이 상인', () {
    test('지도 자리·남은 시간, 한 번 사면 「팔렸어요」', () async {
      final c = make(json: {
        'gather': GatherState(
          merchantUntil: now.add(const Duration(minutes: 20)),
          merchantLat: 37.322,
          merchantLng: 126.831,
          offers: {MaterialId.dewHerb.name: 80},
          noteOffer: true,
        ).toJson(),
      });
      await c.init();
      expect(c.merchantHere, isTrue);
      expect(c.merchantPoint!.lat, 37.322);
      expect(c.merchantPoint!.lng, 126.831);
      expect(c.merchantMinutesLeft, 20);
      expect(await c.buyFromMerchant(MaterialId.dewHerb), isTrue);
      expect(c.merchantSold(MaterialId.dewHerb), isTrue);
      expect(await c.buyFromMerchant(MaterialId.dewHerb), isFalse);
      expect(c.gather.offers, contains(MaterialId.dewHerb.name));
      now = now.add(const Duration(minutes: 21));
      expect(c.merchantHere, isFalse);
      expect(c.merchantPoint, isNull);
    });
  });
}
