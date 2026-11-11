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

/// 늘 같은 값을 내는 난수
class _Fixed implements Random {
  _Fixed(this.v);
  double v;
  @override
  double nextDouble() => v;
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
}

EquipItem _item(EquipBase b, {Element? element}) =>
    EquipItem(uid: b.name, base: b, grade: EquipGrade.white, element: element);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('#82 보스 장비 규칙', () {
    test('6세트 × 6부위 = 36종, 부위·이름이 모두 있다', () {
      expect(BossGearRules.infos, hasLength(36));
      for (final s in BossGearRules.sets) {
        expect(s.parts.map((p) => EquipmentRules.info(p.$1).slot).toList(),
            EquipSlot.values);
        for (final p in s.parts) {
          expect(BossGearRules.setOf(p.$1), s.id);
          expect(EquipmentRules.isBossGear(p.$1), isTrue);
        }
      }
      expect(EquipmentRules.isBossGear(EquipBase.dagger), isFalse);
      // 대장간 「만들기」 탭의 일반 장비에는 섞이지 않는다
      expect(EquipmentRules.all.any((e) => EquipmentRules.isBossGear(e.id)),
          isFalse);
    });

    test('같은 부위 가장 좋은 일반 장비보다 조금 위', () {
      for (final slot in EquipSlot.values) {
        final normal = EquipmentRules.all.where((e) => e.slot == slot);
        double best(EquipBaseInfo e) => e.attack + e.reduce + e.maxHp;
        final top = normal.map(best).reduce(max);
        final boss = BossGearRules.infos.firstWhere((e) => e.slot == slot);
        expect(best(boss), greaterThan(top));
        expect(best(boss), lessThan(top * 1.4));
      }
    });

    test('무기가 가장 많이 든다', () {
      final w = BossGearRules.cost(EquipSlot.weapon);
      for (final s in EquipSlot.values) {
        final c = BossGearRules.cost(s);
        expect(c.shards, lessThanOrEqualTo(w.shards));
        expect(c.gold, lessThanOrEqualTo(w.gold));
      }
      expect(BossGearRules.failChance(blacksmith: true),
          lessThan(BossGearRules.failChance()));
      expect(BossGearRules.cost(EquipSlot.weapon, blacksmith: true).gold,
          lessThan(w.gold));
    });

    test('세트 효과 2·4·6개, 장비 속성을 바꿔도 세트 속성은 그대로', () {
      final frost = BossGearRules.info(BossSet.frost).parts.map((p) => p.$1).toList();
      final two = SetBonus.of([
        _item(frost[0], element: Element.fire), // 무기 속성을 불로 바꿨다
        _item(frost[1]),
      ]);
      expect(two.resist, {Element.ice: BossGearRules.setResist});
      expect(two.attack, isEmpty);
      final four = SetBonus.of([for (final b in frost.take(4)) _item(b)]);
      expect(four.attack, {Element.ice: BossGearRules.setAttack});
      expect(four.abilities, isEmpty);
      final six = SetBonus.of([for (final b in frost) _item(b)]);
      expect(six.abilities, {BossSetAbility.freeze});
      expect(six.look, BossSet.frost);
      // 장비 힘에도 실린다
      expect(EquipmentRules.bonusOf([for (final b in frost) _item(b)]).sets.look,
          BossSet.frost);
    });

    test('6개 고유 능력: 불꽃 세트는 가끔 불태우고, 고목 세트는 HP가 찬다', () {
      final fire = Battle(
        playerMaxHp: 1000,
        playerAttack: 10,
        floors: const [Foe(monster: MonsterId.ashSlime, maxHp: 100000, attack: 1)],
        rng: _Fixed(0.01),
        setAbilities: const {BossSetAbility.burn},
      );
      fire.tick();
      expect(fire.foeBurnTurns, greaterThan(0));
      expect(fire.setProcs, 1);

      final grove = Battle(
        playerMaxHp: 1000,
        startHp: 500,
        playerAttack: 10,
        floors: const [Foe(monster: MonsterId.ashSlime, maxHp: 100000, attack: 1)],
        rng: _Fixed(0.5),
        setAbilities: const {BossSetAbility.regrow},
      );
      grove.tick();
      expect(grove.playerHp, greaterThan(500));
    });

    test('4개 효과: 그 속성으로 공격하면 더 세다', () {
      Battle b(Map<Element, double> set) => Battle(
            playerMaxHp: 1000,
            playerAttack: 100,
            floors: const [Foe(monster: MonsterId.labyrinthBat, maxHp: 100000, attack: 1)],
            rng: _Fixed(0.5),
            attackElement: Element.ice,
            setAttack: set,
          );
      final plain = b(const {})..tick();
      final boosted = b(const {Element.ice: BossGearRules.setAttack})..tick();
      expect(boosted.lastDealt, greaterThan(plain.lastDealt));
    });
  });

  group('#82 보스 장비 만들기 (앱)', () {
    Future<AppController> start(double roll, {bool metWarden = true}) async {
      final c = AppController(
        area: KoreaArea.area,
        store: InMemoryRecordStore(
          profile: const PlayerProfile(name: '하루'),
          history: [
            DailyRecord(
              date: DateTime(2026, 11, 10),
              purifiedMonsterIds: [if (metWarden) 'labyrinthWarden'],
              gains: {
                Wallet.gold: 5000,
                MaterialId.bossShard.name: 20,
                MaterialId.bossWardenHeart.name: 5,
              },
            ),
          ],
        ),
        health: FakeHealthSource(stepsByDay: {'2026-11-11': 3000}),
        location: FakeLocationSource(),
        clock: () => DateTime(2026, 11, 11, 14),
        random: _Fixed(roll),
      )..mailSources = const [];
      await c.init();
      return c;
    }

    test('못 잡은 보스의 세트는 잠겨 있다', () async {
      final c = await start(0.9, metWarden: false);
      expect(c.bossSetOpen(BossSet.warden), isFalse);
      expect(c.canCraftBoss(EquipBase.wardenWeapon), isNot(CraftCheck.ok));
    });

    test('성공: 조각·전용 재료·금화를 쓰고, 보스 속성이 입혀진 장비가 나온다', () async {
      final c = await start(0.9);
      final gold = c.player.gold;
      final r = await c.craftBoss(EquipBase.wardenWeapon);
      expect(r!.ok, isTrue);
      expect(r.item!.element, Element.metal);
      expect(c.hasBossPart(EquipBase.wardenWeapon), isTrue);
      final cost = BossGearRules.cost(EquipSlot.weapon);
      expect(c.player.materialCount(MaterialId.bossShard), 20 - cost.shards);
      expect(c.player.materialCount(MaterialId.bossWardenHeart), 5 - cost.mats);
      expect(c.player.gold, gold - cost.gold);
    });

    test('실패: 금화 절반·조각 일부만 잃고 전용 재료는 그대로', () async {
      final c = await start(0.01);
      final gold = c.player.gold;
      final r = await c.craftBoss(EquipBase.wardenWeapon);
      expect(r!.ok, isFalse);
      expect(r.line, isNotEmpty);
      final loss = BossGearRules.failLoss(EquipSlot.weapon);
      expect(c.player.materialCount(MaterialId.bossShard), 20 - loss.shards);
      expect(c.player.materialCount(MaterialId.bossWardenHeart), 5);
      expect(c.player.gold, gold - loss.gold);
      expect(c.hasBossPart(EquipBase.wardenWeapon), isFalse);
    });
  });
}
