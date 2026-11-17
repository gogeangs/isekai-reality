// 묶음 49 #235: 영웅 펫 6종

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/pet_state.dart';
import 'package:isekai_reality/core/rules/rules.dart';

import 'support/village_seed.dart';

PetState _pets({required PetSpecies hero, int bond = 0, List<PetEgg> eggs = const []}) =>
    PetState(
      pets: [
        Pet(uid: 'p1', species: PetSpecies.owl, name: '부엉', bornAt: DateTime(2026, 11, 1)),
        Pet(
            uid: 'p2',
            species: hero,
            name: PetRules.heroName(hero),
            bond: bond,
            bornAt: DateTime(2026, 11, 10)),
      ],
      eggs: eggs,
      companion: 'p2',
      firstPet: 'p1',
      firstSpiritName: '불씨',
      farewellAt: DateTime(2026, 11, 2),
      nextId: 3,
    );

void main() {
  group('규칙', () {
    test('영웅 펫 6종 · 등급 · 정해진 이름 · 문장에 숫자 없음', () {
      expect(PetRules.heroSpecies, hasLength(6));
      expect([for (final s in PetRules.heroSpecies) PetRules.heroName(s)],
          ['바람', '모스', '녹턴', '무', '엠버', '여명']);
      for (final s in PetRules.heroSpecies) {
        final i = PetRules.info(s);
        expect(i.grade, PetGrade.hero);
        expect(PetRules.isHero(s), isTrue);
        expect(i.walk, isNotNull);
        for (final t in [i.special, i.specialAdult, i.skillText, i.skillTextAdult, i.walk!]) {
          expect(RegExp(r'[0-9%×]|틱').hasMatch(t), isFalse, reason: t);
        }
        expect(i.asset(adult: true, awake: true), 'assets/images/pet_${s.name}_awake.webp');
      }
      expect(PetRules.info(PetSpecies.wolf).element, Element.wind);
      expect(PetRules.info(PetSpecies.turtle).element, Element.earth);
      expect(PetRules.info(PetSpecies.panther).element, Element.dark);
      expect(PetRules.info(PetSpecies.whale).element, Element.water);
      expect(PetRules.info(PetSpecies.phoenix).element, Element.fire);
      expect(PetRules.info(PetSpecies.stag).element, Element.light);
      expect(PetRules.isHero(PetSpecies.griffin), isFalse);
    });

    test('나오는 확률: 처음 1% · 안 나올 때마다 조금씩 · 최대가 있음', () {
      expect(PetRules.heroChance(0), 0.01);
      expect(PetRules.heroChance(4), greaterThan(PetRules.heroChance(0)));
      expect(PetRules.heroChance(1000), PetRules.heroMax);
      final rng = math.Random(7);
      for (var i = 0; i < 50; i++) {
        expect(PetRules.isHero(PetRules.rollSpecies(rng)), isFalse);
        expect(PetRules.isHero(PetRules.rollSpecies(rng, heroChance: 1)), isTrue);
      }
    });

    test('희귀보다 한 단계 센 원정 특기·던전 스킬', () {
      expect(PetRules.travelTimeFactor(PetSpecies.wolf, adult: true),
          lessThan(PetRules.travelTimeFactor(PetSpecies.griffin, adult: true)));
      expect(PetRules.powerFactor(PetSpecies.wolf, adult: true), greaterThan(1));
      expect(PetRules.powerFactor(PetSpecies.panther, adult: true, night: true),
          greaterThan(PetRules.powerFactor(PetSpecies.blackCat, adult: true, night: true)));
      expect(PetRules.mpFactor(PetSpecies.whale, adult: true, waterside: true),
          lessThan(PetRules.mpFactor(PetSpecies.kelpie, adult: true, waterside: true)));
      expect(PetRules.keepsMpOnLoss(PetSpecies.turtle), isTrue);
      expect(PetRules.extraMaterials(PetSpecies.turtle, math.Random(1), adult: false), 2);
      expect(PetRules.skillMultiplier(PetSkill.galeFang, adult: true),
          greaterThan(PetRules.skillMultiplier(PetSkill.thunderClaw, adult: true)));
      expect(PetRules.skillChargeTicks(PetSkill.galeFang), 3);
      expect(PetRules.mossHits(adult: false),
          greaterThan(PetRules.stoneWallHits(adult: true)));
    });

    test('엠버: 던전에서 쓰러지면 한 번 되살아남', () {
      final b = Battle(
        playerMaxHp: 10,
        playerAttack: 1,
        floors: [BattleRules.fieldFoe(level: 30, monster: MonsterId.giantRat)],
        rng: math.Random(3),
      )..revives = 1;
      for (var i = 0; i < 2000 && !b.isOver; i++) {
        b.tick();
      }
      expect(b.revived, 1);
      expect(b.phase, BattlePhase.failed);
    });
  });

  group('계정', () {
    test('예전 기록(#124): 영웅 칸이 없어도 그대로 읽힘', () {
      final old = _pets(hero: PetSpecies.wolf).toJson()
        ..remove('heroMiss')
        ..remove('heroMet');
      final p = PetState.fromJson(old);
      expect(p.heroMiss, 0);
      expect(p.heroMet, isEmpty);
      expect(p.pets.last.species, PetSpecies.wolf);
      final back = PetState.fromJson(p.copyWith(heroMiss: 3, heroMet: ['lumi']).toJson());
      expect(back.heroMiss, 3);
      expect(back.heroMet, ['lumi']);
    });

    test('단짝(친밀도 100)이면 각성 모습', () {
      final a = Pet(uid: 'a', species: PetSpecies.stag, name: '여명', bornAt: DateTime(2026));
      expect(a.hero, isTrue);
      expect(a.awake, isFalse);
      expect(a.copyWith(bond: 100).awake, isTrue);
      final g = Pet(uid: 'g', species: PetSpecies.golem, name: '바위', bond: 100, bornAt: DateTime(2026));
      expect(g.awake, isFalse);
    });

    test('동행 영웅 펫 · 루미·포포·세라 한마디는 한 번', () async {
      final c = await startVillage(15,
          farewell: true, more: {'pets': _pets(hero: PetSpecies.wolf).toJson()});
      expect(c.heroCompanion?.species, PetSpecies.wolf);
      expect(c.takeHeroReaction(Npc.lumi), contains('바람'));
      expect(c.takeHeroReaction(Npc.lumi), isNull);
      expect(c.takeHeroReaction(Npc.sera), isNotNull);
      expect(c.takeHeroReaction(Npc.marta), isNull);
    });

    test('영웅 펫이 깨어나면 정해진 이름', () async {
      final c = await startVillage(15,
          farewell: true,
          more: {
            'pets': _pets(hero: PetSpecies.wolf, eggs: [
              PetEgg(id: 'e1', source: 'field', incubatedAt: DateTime(2026, 11, 10)),
            ]).toJson(),
          });
      final pet = (await c.hatch('e1', '아무 이름', species: PetSpecies.whale))!;
      expect(pet.name, '무');
      expect(pet.hero, isTrue);
    });
  });
}
