import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/location/location_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/map/korea_area.dart';

void main() {
  group('연금술 규칙 (11-11 #57·#58)', () {
    test('종류·개수가 맞으면 물약, 순서까지 맞으면 완벽한 조제', () {
      const h = MaterialId.herb, j = MaterialId.slimeJelly;
      expect(AlchemyRules.match([h, h, j]), (id: PotionId.healSmall, perfect: true));
      expect(AlchemyRules.match([j, h, h]), (id: PotionId.healSmall, perfect: false));
      expect(AlchemyRules.match([h, j]), isNull); // 개수가 다르면 수상한 물약
    });

    test('레시피는 서로 겹치지 않는다', () {
      final keys = <String>{};
      for (final p in AlchemyRules.all) {
        expect(keys.add(AlchemyRules.comboKey(p.recipe)), isTrue,
            reason: p.name);
        expect(p.recipe.length, lessThanOrEqualTo(AlchemyRules.maxIngredients));
      }
    });

    test('수상한 물약: 가장 많이 넣은 성질의 약한 효과, 같은 조합은 같은 효과', () {
      final e = AlchemyRules.suspiciousEffect(
          [MaterialId.fireJelly, MaterialId.fireJelly, MaterialId.batWing]);
      expect(e.stat, StatKind.strength);
      expect(e.amount, 2);
      final hp = AlchemyRules.suspiciousEffect([MaterialId.herb]);
      expect(hp.stat, isNull);
      expect(hp.amount, 5);
      expect(AlchemyRules.comboKey([MaterialId.herb, MaterialId.batWing]),
          AlchemyRules.comboKey([MaterialId.batWing, MaterialId.herb]));
    });

    test('가공: 젤리 아무거나 5개는 많은 것부터', () {
      final r = ProcessRules.all.firstWhere((x) => x.id == 'essence');
      final use = ProcessRules.use(r, {
        MaterialId.slimeJelly: 3,
        MaterialId.fireJelly: 4,
      })!;
      expect(use[MaterialId.fireJelly], 4);
      expect(use[MaterialId.slimeJelly], 1);
      expect(ProcessRules.use(r, {MaterialId.slimeJelly: 4}), isNull);
    });
  });

  group('전투 물약', () {
    Foe foe() => const Foe(monster: MonsterId.ashSlime, maxHp: 100000, attack: 100);

    test('HP 30% 아래면 자동으로 회복 물약, 전투 한 번에 3개까지', () {
      final b = Battle(
        playerMaxHp: 1000,
        playerAttack: 1,
        floors: [foe()],
        rng: Random(1),
        startHp: 290,
        autoHp: 30,
        potions: const [
          BattlePotion(key: 'shop:healSmall', name: '작은 회복 물약', count: 10, hpRatio: 0.2),
        ],
      );
      for (var i = 0; i < 30 && !b.isOver; i++) {
        b.tick();
      }
      expect(b.potionsUsed['shop:healSmall'], AlchemyRules.perBattle);
    });

    test('해독제는 중독만, 연고는 화상만 푼다', () {
      final b = Battle(
        playerMaxHp: 1000,
        playerAttack: 1,
        floors: [foe()],
        potions: const [
          BattlePotion(key: 'alc:antidote', name: '해독제', count: 1, cure: CureKind.poison),
          BattlePotion(key: 'alc:burnSalve', name: '화상 연고', count: 1, cure: CureKind.burn),
        ],
      );
      b.poisonTurns = 3;
      b.burning = true;
      expect(b.drink('alc:antidote'), isFalse);
      expect(b.drink('alc:burnSalve'), isTrue);
      expect(b.poisonTurns, 0);
      expect(b.immuneTurns, 3);
    });

    test('저항 물약: 그 속성 몬스터에게 받는 피해 -30%', () {
      Battle make(Map<Element, double> r) => Battle(
            playerMaxHp: 100000,
            playerAttack: 1,
            floors: const [Foe(monster: MonsterId.fireSlime, maxHp: 100000, attack: 1000)],
            rng: Random(4),
            resist: r,
          );
      final plain = make(const {})..tick();
      final res = make(const {Element.fire: 0.3})..tick();
      expect(res.lastTaken, lessThan(plain.lastTaken));
    });
  });

  group('공방 (앱)', () {
    Future<AppController> start(Map<String, int> gains, {DateTime? at}) async {
      var now = at ?? DateTime(2026, 11, 11, 14);
      final c = AppController(
        area: KoreaArea.area,
        store: InMemoryRecordStore(
          profile: const PlayerProfile(name: '하루'),
          history: [
            DailyRecord(
                date: DateTime(2026, 11, 10),
                gains: {Wallet.gold: 5000, ...gains}),
          ],
        ),
        health: FakeHealthSource(stepsByDay: {'2026-11-11': 3000}),
        location: FakeLocationSource(),
        clock: () => now,
        random: Random(1),
      );
      await c.init();
      return c;
    }

    test('작은 회복 물약을 순서대로 끓이면 완벽한 조제, 처음엔 레시피 2개만', () async {
      var now = DateTime(2026, 11, 11, 14);
      final c = AppController(
        area: KoreaArea.area,
        store: InMemoryRecordStore(
          profile: const PlayerProfile(name: '하루'),
          history: [
            DailyRecord(date: DateTime(2026, 11, 10), gains: {
              Wallet.gold: 5000,
              'herb': 10,
              'slimeJelly': 5,
              'poisonGland': 2,
            }),
          ],
        ),
        health: FakeHealthSource(stepsByDay: {'2026-11-11': 3000}),
        location: FakeLocationSource(),
        clock: () => now,
        random: Random(1),
      );
      await c.init();
      expect(c.knownRecipes, [PotionId.healSmall, PotionId.manaSmall]);

      expect(
          await c.startBrew(0, [MaterialId.herb, MaterialId.herb, MaterialId.slimeJelly]),
          isTrue);
      expect(c.player.materialCount(MaterialId.herb), 8);
      expect(c.brewReady(0), isFalse);
      now = now.add(const Duration(minutes: 11));
      final r = await c.collectBrew(0);
      expect(r!.potion, PotionId.healSmall);
      expect(r.perfect, isTrue);
      expect(c.alchemy.count('healSmall*'), 3);

      // 해독제를 찾아낸다 (순서는 달라도 됨)
      await c.startBrew(0, [MaterialId.herb, MaterialId.poisonGland, MaterialId.herb]);
      now = now.add(const Duration(minutes: 21));
      final r2 = await c.collectBrew(0);
      expect(r2!.potion, PotionId.antidote);
      expect(r2.perfect, isFalse);
      expect(r2.discovered, isTrue);
      expect(c.knownRecipes, contains(PotionId.antidote));
      expect(c.battlePotions.any((p) => p.key == 'alc:antidote'), isTrue);
    });

    test('맞지 않는 조합은 수상한 물약, 마시면 효과를 알게 된다', () async {
      var now = DateTime(2026, 11, 11, 14);
      final c = AppController(
        area: KoreaArea.area,
        store: InMemoryRecordStore(
          profile: const PlayerProfile(name: '하루'),
          history: [
            DailyRecord(date: DateTime(2026, 11, 10), gains: {'fireJelly': 3}),
          ],
        ),
        health: FakeHealthSource(stepsByDay: {'2026-11-11': 3000}),
        location: FakeLocationSource(),
        clock: () => now,
        random: Random(1),
      );
      await c.init();
      await c.startBrew(0, [MaterialId.fireJelly, MaterialId.fireJelly]);
      now = now.add(const Duration(minutes: 10));
      final r = await c.collectBrew(0);
      expect(r!.suspicious, isNotNull);
      final key = r.suspicious!;
      expect(c.potionDescription(key), contains('마시기 전'));
      final before = c.combatStats.strength;
      expect(await c.drinkPotion(key), isNull);
      expect(c.combatStats.strength, before + 2);
      expect(c.alchemy.knownSuspicious, contains(key));
    });

    test('가공과 가마솥 늘리기', () async {
      final c = await start({'ironShard': 7, 'labyrinthStone': 5});
      final ingot = ProcessRules.all.firstWhere((r) => r.id == 'ingot');
      expect(await c.process(ingot), isTrue);
      expect(c.player.materialCount(MaterialId.ironIngot), 1);
      expect(c.player.materialCount(MaterialId.ironShard), 4);
      expect(c.cauldronGold, 500);
      expect(await c.buyCauldron(), isTrue);
      expect(c.alchemy.cauldrons, 2);
      expect(await c.buyCauldron(), isTrue); // 1,500 + 미궁 석재 5
      expect(c.cauldronGold, isNull);
      expect(c.player.materialCount(MaterialId.labyrinthStone), 0);
    });
  });
}
