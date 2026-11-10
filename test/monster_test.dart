import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/core/models/armory.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/rules/rules.dart';

void main() {
  group('필드 몬스터 6종 (11-11)', () {
    test('슬라임 30 · 큰쥐 25 · 혼래빗 20 · 보어 15 · 박쥐 10', () {
      final rng = Random(1);
      final n = <MonsterId, int>{};
      const total = 20000;
      for (var i = 0; i < total; i++) {
        var m = FieldMonsterRules.pickCommon(rng.nextDouble(), rng.nextDouble());
        if (Monsters.info(m).slimeKind) m = MonsterId.ashSlime;
        n[m] = (n[m] ?? 0) + 1;
      }
      expect(n[MonsterId.ashSlime]! / total, closeTo(0.30, 0.02));
      expect(n[MonsterId.giantRat]! / total, closeTo(0.25, 0.02));
      expect(n[MonsterId.hornRabbit]! / total, closeTo(0.20, 0.02));
      expect(n[MonsterId.babyBoar]! / total, closeTo(0.15, 0.02));
      expect(n[MonsterId.labyrinthBat]! / total, closeTo(0.10, 0.02));
    });

    test('슬라임 속성: 빛은 낮에, 어둠은 밤에 더 자주', () {
      int count(MonsterId id, bool night) {
        final rng = Random(2);
        var c = 0;
        for (var i = 0; i < 20000; i++) {
          if (FieldMonsterRules.pickCommon(0.0, rng.nextDouble(), night: night) == id) c++;
        }
        return c;
      }

      expect(count(MonsterId.lightSlime, false) / 20000, closeTo(0.06, 0.01));
      expect(count(MonsterId.lightSlime, true) / 20000, closeTo(0.02, 0.01));
      expect(count(MonsterId.darkSlime, true) / 20000, closeTo(0.06, 0.01));
      expect(count(MonsterId.ashSlime, false) / 20000, closeTo(0.40, 0.02));
    });

    test('혼래빗은 토끼 고기나 작은 뿔, 빛 슬라임은 귀한 재료 15%', () {
      final rng = Random(3);
      final got = <MaterialId>{};
      for (var i = 0; i < 200; i++) {
        got.addAll(LootRules.field(MonsterId.hornRabbit, rng).keys);
      }
      expect(got, containsAll([MaterialId.rabbitMeat, MaterialId.smallHorn]));
      expect(LootRules.dropsOf(MonsterId.lightSlime).chance, 0.15);
      expect(LootRules.dropsOf(MonsterId.waterSlime).rare, MaterialId.waterCore);
    });

    test('도감은 13칸, 칭호 도감의 현자는 속성 슬라임을 뺀 7종', () {
      expect(Monsters.all, hasLength(13));
      final base = [for (final m in Monsters.all) if (!m.slimeKind) m.id.name];
      expect(base, hasLength(7));
      expect(TitleRules.earned([DailyRecord(date: DateTime(2026, 11, 11), purifiedMonsterIds: base)], 1),
          contains(TitleId.bookwormSage));
    });
  });

  group('몬스터 전투 특징', () {
    Battle fight(MonsterId m, {int seed = 1}) => Battle(
          playerMaxHp: 10000,
          playerAttack: 100,
          floors: [
            Foe(
                monster: m,
                maxHp: 1000,
                attack: 10,
                defense: Monsters.info(m).defense,
                speed: Monsters.info(m).speed),
          ],
          rng: Random(seed),
        );

    test('물 슬라임은 매 턴 5% 회복, 어둠 슬라임은 때린 만큼 흡수', () {
      final w = fight(MonsterId.waterSlime)..tick();
      expect(w.lastDealt, greaterThan(50));
      expect(w.foeHp, 1000 - w.lastDealt + 50);
      final d = fight(MonsterId.darkSlime)..tick();
      expect(d.foeHp, greaterThan(1000 - d.lastDealt));
    });

    test('불꽃 슬라임은 화상, 빛 슬라임은 빗나감, 바람 슬라임은 먼저 침', () {
      var burned = false, missed = false;
      for (var s = 0; s < 30; s++) {
        final f = fight(MonsterId.fireSlime, seed: s);
        for (var i = 0; i < 5; i++) {
          f.tick();
        }
        burned |= f.poisonTurns > 0;
        final l = fight(MonsterId.lightSlime, seed: s)..tick();
        missed |= l.lastEvent == '눈부셔요!';
      }
      expect(burned, isTrue);
      expect(missed, isTrue);
      final wind = fight(MonsterId.windSlime);
      expect(wind.foe.speed, greaterThan(wind.playerSpeed));
    });

    test('보어는 단단하고 혼래빗은 빠르다', () {
      final boar = BattleRules.fieldFoe(level: 5, monster: MonsterId.babyBoar);
      final rat = BattleRules.fieldFoe(level: 5, monster: MonsterId.giantRat);
      expect(boar.maxHp, greaterThan(rat.maxHp));
      expect(BattleRules.fieldFoe(level: 5, monster: MonsterId.hornRabbit).speed, 1.2);
    });

    test('전용 수식어: 혼래빗·보어', () {
      expect(ModifierRules.info(ModifierId.thickHorn).monster, MonsterId.hornRabbit);
      expect(ModifierRules.info(ModifierId.chieftain).grade, ModGrade.rare);
      final b = ModifierRules.bonus(
          MonsterId.hornRabbit, const [ModifierId.thickHorn], Random(1));
      expect(b.materials[MaterialId.smallHorn], 1);
    });
  });

  group('보상', () {
    test('수식어·속성 보너스 경험치는 기록에 남아 레벨에 더해진다', () {
      final r = DailyRecord(
          date: DateTime(2026, 11, 11),
          fieldMonstersPurified: 1,
          gains: const {Wallet.exp: 8});
      expect(ExpRules.forDay(r).fieldMonster, RuleConstants.fieldMonsterExp + 8);
    });

    test('약초는 금화 15, 하루 5개', () {
      final i = TownRules.info(ShopItem.herb);
      expect(i.price, 15);
      expect(i.perLimit, 5);
      expect(i.material, MaterialId.herb);
    });

    test('새 장비 4종', () {
      expect(EquipmentRules.info(EquipBase.hornDagger).recipe[MaterialId.smallHorn], 3);
      expect(EquipmentRules.info(EquipBase.boarArmor).reduce, 0.07);
      final g = EquipmentRules.bonusOf([
        const EquipItem(uid: 'a', base: EquipBase.hornDagger, grade: EquipGrade.white),
      ]);
      expect(g.crit, closeTo(0.03, 1e-9));
    });
  });
}
