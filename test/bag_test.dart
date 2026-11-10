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

void main() {
  group('가방 규칙 (11-11 #48)', () {
    test('20칸에서 시작, 5칸씩, 100칸까지. 값은 200·400·700·1,000·2,000…', () {
      expect(BagRules.capacity(), 20);
      expect(BagRules.capacity(goldExpansions: 2), 30);
      expect(BagRules.capacity(goldExpansions: 30), 100);
      expect(BagRules.capacity(goldExpansions: 1, extraSlots: 3), 28);
      expect([for (var i = 0; i < 6; i++) BagRules.expansionCost(i)],
          [200, 400, 700, 1000, 2000, 3000]);
    });

    test('99개마다 한 칸, 입은 장비는 칸을 쓰지 않는다', () {
      const a = EquipItem(uid: 'a', base: EquipBase.dagger, grade: EquipGrade.white);
      const b = EquipItem(uid: 'b', base: EquipBase.armor, grade: EquipGrade.white);
      final armory = Armory(items: const [a, b], equipped: const {EquipSlot.weapon: 'a'});
      expect(
          BagRules.usedSlots(
            materials: {MaterialId.slimeJelly: 99, MaterialId.ratHide: 100},
            items: {ShopItem.healSmall: 3},
            armory: armory,
          ),
          1 + 2 + 1 + 1);
    });

    test('판매 값: 재료 5·25, 물약 절반, 장비 등급·강화', () {
      expect(BagRules.materialPrice(MaterialId.slimeJelly), 5);
      expect(BagRules.materialPrice(MaterialId.slimeCore), 25);
      expect(BagRules.itemPrice(ShopItem.healSmall),
          TownRules.info(ShopItem.healSmall).price ~/ 2);
      expect(
          BagRules.equipPrice(const EquipItem(
              uid: 'x', base: EquipBase.dagger, grade: EquipGrade.blue, enhance: 3)),
          156);
    });

    test('가득 차면 이미 있는 칸에만 쌓고 나머지는 금화로', () {
      final fit = BagRules.fit(
        incoming: {MaterialId.slimeJelly: 3, MaterialId.batWing: 2},
        have: {MaterialId.slimeJelly: 97},
        freeSlots: 0,
      );
      expect(fit.kept, {MaterialId.slimeJelly: 2});
      expect(fit.gold, 1 * 5 + 2 * 5);
    });
  });

  group('가방 (앱)', () {
    Future<AppController> start({Map<String, int> gains = const {}}) async {
      final now = DateTime(2026, 11, 10, 14);
      final c = AppController(
        area: KoreaArea.area,
        store: InMemoryRecordStore(
          profile: const PlayerProfile(name: '하루'),
          history: [
            DailyRecord(
              date: DateTime(2026, 11, 9),
              gains: {Wallet.gold: 1000, ...gains},
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

    test('늘리기는 금화를 쓰고, 칸보다 많아도 그대로 남긴다', () async {
      // 재료 25종 × 1개 = 25칸 (예전 저장본: 20칸보다 많다)
      final many = {for (final m in MaterialId.values.take(25)) m.name: 1};
      final c = await start(gains: many);
      expect(c.bagCapacity, 20);
      expect(c.bagUsed, 25);
      expect(c.bagFree, 0);
      expect(c.player.materials.length, 25);
      expect(c.canBuy(ShopItem.healSmall), PurchaseCheck.bagFull);

      expect(await c.expandBag(), isTrue);
      expect(c.bagCapacity, 25);
      expect(c.player.gold, 800);
      expect(await c.expandBag(), isTrue);
      expect(c.bagCapacity, 30);
      expect(c.player.gold, 400);
      expect(c.canBuy(ShopItem.healSmall), PurchaseCheck.ok);
    });

    test('잡화상에서 재료를 팔고, 버리면 사라진다', () async {
      final c = await start(gains: {'slimeJelly': 10, 'slimeCore': 2});
      expect(await c.sellMaterial(MaterialId.slimeJelly, 4), isTrue);
      expect(c.player.materialCount(MaterialId.slimeJelly), 6);
      expect(c.player.gold, 1020);
      expect(await c.sellMaterial(MaterialId.slimeCore, 1), isTrue);
      expect(c.player.gold, 1045);
      expect(await c.discardMaterial(MaterialId.slimeJelly, 6), isTrue);
      expect(c.player.materialCount(MaterialId.slimeJelly), 0);
      expect(await c.sellMaterial(MaterialId.slimeJelly, 1), isFalse);
    });

    test('물약도 팔고 버릴 수 있다', () async {
      final c = await start();
      await c.buy(ShopItem.healSmall);
      await c.buy(ShopItem.healSmall);
      expect(c.bagCount(ShopItem.healSmall), 2);
      final gold = c.player.gold;
      expect(await c.sellItem(ShopItem.healSmall, 1), isTrue);
      expect(c.player.gold, gold + BagRules.itemPrice(ShopItem.healSmall));
      expect(await c.discardItem(ShopItem.healSmall, 1), isTrue);
      expect(c.bagCount(ShopItem.healSmall), 0);
    });
  });
}
