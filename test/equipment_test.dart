import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/armory.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/location/location_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/map/korea_area.dart';

EquipItem _item(EquipBase b,
        {EquipGrade g = EquipGrade.white, int enhance = 0, int dur = 100}) =>
    EquipItem(uid: b.name, base: b, grade: g, enhance: enhance, durability: dur);

void main() {
  group('장비 규칙', () {
    test('흰색 한 벌: 공격 +8%, 받는 피해 -13%, 최대 HP +5%', () {
      final set = [
        EquipBase.dagger,
        EquipBase.cap,
        EquipBase.armor,
        EquipBase.gloves,
        EquipBase.boots,
        EquipBase.fangNecklace,
      ].map(_item);
      final g = EquipmentRules.bonusOf(set);
      expect(g.attack, closeTo(0.08, 1e-9));
      expect(g.reduce, closeTo(0.13, 1e-9));
      expect(g.maxHp, closeTo(0.05, 1e-9));
    });

    test('등급 확률: 기본 60/28/10/1.8/0.2, 귀한 재료 30/40/22/6.5/1.5, 숙련도', () {
      expect(EquipmentRules.gradeChances(rare: false), [60, 28, 10, 1.8, 0.2]);
      expect(EquipmentRules.gradeChances(rare: true), [30, 40, 22, 6.5, 1.5]);
      final m = EquipmentRules.gradeChances(rare: false, crafts: 35);
      expect(m[0], 57);
      expect(m[2], 13);
      expect(EquipmentRules.gradeChances(rare: false, crafts: 500)[2], 20);
      for (final c in [m, EquipmentRules.gradeChances(rare: true)]) {
        expect(c.reduce((a, b) => a + b), closeTo(100, 1e-9));
      }
      final rng = Random(3);
      var white = 0;
      for (var i = 0; i < 5000; i++) {
        if (EquipmentRules.rollGrade(rng, rare: false) == EquipGrade.white) {
          white++;
        }
      }
      expect(white / 5000, closeTo(0.6, 0.03));
    });

    test('등급 배수와 추가 능력 개수', () {
      final rng = Random(1);
      expect(EquipmentRules.rollExtras(EquipGrade.white, rng), isEmpty);
      final purple = EquipmentRules.rollExtras(EquipGrade.purple, rng);
      expect(purple.values.fold<int>(0, (a, b) => a + b),
          inInclusiveRange(4, 6));
      final g = EquipmentRules.bonusOf(
          [_item(EquipBase.dagger, g: EquipGrade.orange)]);
      expect(g.attack, closeTo(0.08 * 1.8, 1e-9));
    });

    test('강화: +8%씩, 성공 확률과 비용', () {
      expect(EquipmentRules.enhanceChance(3), 1.0);
      expect(EquipmentRules.enhanceChance(4), 0.9);
      expect(EquipmentRules.enhanceChance(10), 0.3);
      expect(EquipmentRules.enhanceCost(7), (manaStones: 7, gold: 140));
      final g = EquipmentRules.bonusOf([_item(EquipBase.dagger, enhance: 10)]);
      expect(g.attack, closeTo(0.08 * 1.8, 1e-9));
    });

    test('내구도 0이면 능력 절반, 흰색을 0에서 고치면 금화 50', () {
      final g = EquipmentRules.bonusOf([_item(EquipBase.armor, dur: 0)]);
      expect(g.reduce, closeTo(0.03, 1e-9));
      expect(EquipmentRules.repairCost(_item(EquipBase.armor, dur: 0)), 50);
      expect(
          EquipmentRules.repairCost(
              _item(EquipBase.armor, dur: 0, g: EquipGrade.orange)),
          150);
      expect(EquipmentRules.repairCost(_item(EquipBase.armor)), 0);
    });

    test('분해: 재료 절반(내림) + 마석 1 + 강화 마석 절반', () {
      const item = EquipItem(
        uid: 'x',
        base: EquipBase.armor,
        grade: EquipGrade.white,
        materialsUsed: {'ratHide': 4, 'batWing': 1},
        enhanceManaSpent: 6,
      );
      final back = EquipmentRules.salvage(item);
      expect(back.manaStones, 4);
      expect(back.materials, {MaterialId.ratHide: 2});
    });

    test('장비를 입으면 공격이 세지고 받는 피해가 준다', () {
      final stats = BattleRules.expectedStats(5);
      final foes = [BattleRules.fieldFoe(level: 5, monster: MonsterId.ashSlime)];
      final plain = Battle.forPlayer(level: 5, stats: stats, floors: foes);
      final geared = Battle.forPlayer(
          level: 5,
          stats: stats,
          floors: foes,
          gear: EquipmentRules.bonusOf(
              [_item(EquipBase.dagger), _item(EquipBase.armor), _item(EquipBase.fangNecklace)]));
      expect(geared.playerAttack, (plain.playerAttack * 1.08).round());
      expect(geared.playerMaxHp, (plain.playerMaxHp * 1.05).round());
      expect(geared.damageTaken, closeTo(0.94, 1e-9));
      // 지팡이는 일격 충전 하나 빨리
      final staff = Battle.forPlayer(
          level: 5,
          stats: stats,
          floors: foes,
          gear: EquipmentRules.bonusOf([_item(EquipBase.staff)]));
      expect(staff.skillChargeTicks, RuleConstants.skillChargeTicks - 1);
    });

    test('저장했다 되살려도 같다', () {
      const a = Armory(
        items: [
          EquipItem(
              uid: 'eq1',
              base: EquipBase.staff,
              grade: EquipGrade.blue,
              enhance: 3,
              durability: 77,
              extras: {'wisdom': 2},
              materialsUsed: {'twig': 2})
        ],
        equipped: {EquipSlot.weapon: 'eq1'},
        crafts: 12,
        nextId: 2,
      );
      final b = Armory.fromJson(a.toJson());
      expect(b.items.single.grade, EquipGrade.blue);
      expect(b.items.single.enhance, 3);
      expect(b.items.single.durability, 77);
      expect(b.items.single.extras, {'wisdom': 2});
      expect(b.wornIn(EquipSlot.weapon)?.uid, 'eq1');
      expect(b.crafts, 12);
    });
  });

  group('대장간', () {
    Future<AppController> start() async {
      final now = DateTime(2026, 11, 10, 14);
      final c = AppController(
        area: KoreaArea.area,
        store: InMemoryRecordStore(
          profile: const PlayerProfile(name: '하루'),
          history: [
            DailyRecord(
              date: DateTime(2026, 11, 9),
              dungeonRuns: List.filled(6, const DungeonRun(cleared: true)),
              gains: const {
                Wallet.gold: 500,
                'ratHide': 10,
                'batWing': 4,
                'slimeCore': 1,
              },
            ),
          ],
        ),
        health: FakeHealthSource(stepsByDay: {'2026-11-10': 3000}),
        location: FakeLocationSource(),
        clock: () => now,
        random: Random(5),
      );
      await c.init();
      return c;
    }

    test('재료와 마석으로 만들고, 입으면 최대 HP가 는다', () async {
      final c = await start();
      expect(c.player.manaStones, 18);
      expect(c.canCraft(EquipBase.dagger), CraftCheck.materials); // 철 조각 없음

      final item = await c.craft(EquipBase.armor);
      expect(item, isNotNull);
      expect(c.player.materialCount(MaterialId.ratHide), 6);
      expect(c.player.materialCount(MaterialId.batWing), 3);
      expect(c.player.manaStones, 15);
      expect(c.armory.items, hasLength(1));
      expect(c.armory.crafts, 1);

      // 귀한 재료를 하나 더 넣는다
      final necklace =
          await c.craft(EquipBase.fangNecklace, rare: MaterialId.slimeCore);
      expect(c.player.materialCount(MaterialId.slimeCore), 0);
      expect(necklace!.materialsUsed['slimeCore'], 1);

      final before = c.maxHp;
      await c.equip(necklace.uid);
      expect(c.maxHp, greaterThan(before));
      expect(c.armory.wornIn(EquipSlot.accessory)?.uid, necklace.uid);
      await c.unequip(EquipSlot.accessory);
      expect(c.maxHp, before);
    });

    test('싸우면 내구도가 줄고, 고치고, 강화하고, 분해한다', () async {
      final c = await start();
      final item = (await c.craft(EquipBase.cap))!;
      await c.equip(item.uid);

      final spawn = c.todaySpawns.first;
      final b = c.startFieldBattle(spawn)!..runToEnd(useSkills: true);
      await c.finishFieldBattle(spawn, b);
      expect(c.armory.byUid(item.uid)!.durability, 99);

      final gold = c.player.gold;
      expect(await c.repair(item.uid), isTrue);
      expect(c.armory.byUid(item.uid)!.durability, 100);
      expect(c.player.gold, lessThan(gold));

      // +1은 늘 성공: 마석 1 + 금화 20
      final stones = c.player.manaStones;
      expect(await c.enhance(item.uid), isTrue);
      expect(c.armory.byUid(item.uid)!.enhance, 1);
      expect(c.player.manaStones, stones - 1);

      final hide = c.player.materialCount(MaterialId.ratHide);
      expect(await c.disassemble(item.uid), isTrue);
      expect(c.armory.items, isEmpty);
      expect(c.armory.wornIn(EquipSlot.head), isNull);
      expect(c.player.materialCount(MaterialId.ratHide), hide + 1);
    });
  });
}
