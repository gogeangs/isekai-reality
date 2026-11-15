import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/core/rules/rules.dart';

void main() {
  group('#185 희귀 펫', () {
    test('부화할 때 10%쯤 희귀 6종', () {
      final rng = math.Random(5);
      var rare = 0;
      final seen = <PetSpecies>{};
      for (var i = 0; i < 6000; i++) {
        final s = PetRules.rollSpecies(rng);
        if (PetRules.isRare(s)) {
          rare++;
          seen.add(s);
        }
      }
      expect(rare / 6000, closeTo(0.10, 0.02));
      expect(seen, PetRules.rareSpecies.toSet());
    });

    test('설명은 숫자 없이, 그림은 아기·성체·지도', () {
      for (final s in PetRules.rareSpecies) {
        final i = PetRules.info(s);
        expect(i.grade, PetGrade.rare);
        for (final t in [i.special, i.specialAdult, i.skillText, i.skillTextAdult]) {
          expect(RegExp(r'[0-9%×]').hasMatch(t), isFalse, reason: t);
        }
        expect(i.asset(adult: false), 'assets/images/pet_${s.name}_baby.webp');
      }
      expect(PetRules.info(PetSpecies.griffin).skillName, '번개 발톱');
      expect(PetRules.info(PetSpecies.golem).skillName, '돌 방벽');
    });

    test('원정 특기: 일반 펫보다 한 단계 세게', () {
      expect(
          PetRules.travelTimeFactor(PetSpecies.griffin, adult: false),
          lessThan(PetRules.travelTimeFactor(PetSpecies.crow, adult: false)));
      expect(PetRules.mpFactor(PetSpecies.drake, adult: false),
          lessThan(PetRules.mpFactor(PetSpecies.lizard, adult: false)));
      expect(PetRules.powerFactor(PetSpecies.drake, adult: false), greaterThan(1));
      expect(PetRules.powerFactor(PetSpecies.direwolf, adult: false),
          greaterThan(PetRules.powerFactor(PetSpecies.owl, adult: false)));
      expect(
          PetRules.mpFactor(PetSpecies.kelpie, adult: false, waterside: true),
          lessThan(PetRules.mpFactor(PetSpecies.toad, adult: false, waterside: true)));
      expect(PetRules.travelTimeFactor(PetSpecies.kelpie, adult: false), lessThan(1));
      expect(PetRules.extraMaterials(PetSpecies.direwolf, math.Random(1), adult: false), 1);
      expect(PetRules.keepsMpOnLoss(PetSpecies.golem), isTrue);
      expect(PetRules.keepsMpOnLoss(PetSpecies.owl), isFalse);
      expect(PetRules.mimicChance(adult: true),
          greaterThan(PetRules.mimicChance(adult: false)));
    });

    test('던전 스킬: 서리 물기 얼림 · 물살 휘감기 회복 · 돌 방벽 보호막', () {
      Battle make(PetSkill s) => Battle.forPlayer(
            level: 12,
            stats: Stats.all(10),
            floors: const [
              Foe(monster: MonsterId.slime, maxHp: 100000, attack: 10),
            ],
            petSkill: s,
            startHp: 50,
          );
      final frost = make(PetSkill.frostBite);
      frost.skillCharge = frost.skillChargeTicks;
      expect(frost.useSkill(), isTrue);
      expect(frost.foeFrozen, isTrue);
      final tide = make(PetSkill.tideWrap);
      tide.skillCharge = tide.skillChargeTicks;
      expect(tide.useSkill(), isTrue);
      expect(tide.playerHp, greaterThan(50));
      expect(tide.foeBound, isTrue);
      final wall = make(PetSkill.stoneWall);
      wall.skillCharge = wall.skillChargeTicks;
      expect(wall.useSkill(), isTrue);
      expect(wall.shieldHits, PetRules.stoneWallHits(adult: false));
    });
  });

  group('지난 확인 답', () {
    test('시간이 있는 스킬 설명은 「○분 동안」', () {
      for (final s in JobRules.skills) {
        if (s.mode != SkillMode.timed) continue;
        expect(s.text, matches(RegExp(r'^\d+(분|시간) 동안')), reason: s.name);
      }
    });
  });
}
