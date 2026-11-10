import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/models/pet_state.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/location/location_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/map/korea_area.dart';

void main() {
  group('펫 규칙 (11-11 #38)', () {
    test('펫 레벨: 50 × 레벨씩, Lv.10에 성체', () {
      expect(PetRules.levelFor(0), 1);
      expect(PetRules.levelFor(49), 1);
      expect(PetRules.levelFor(50), 2);
      // Lv.10까지 50×(1+…+9) = 2,250
      expect(PetRules.levelFor(2250), 10);
      expect(PetRules.levelFor(2249), 9);
      expect(PetRules.levelFor(999999), PetRules.maxLevel);
      expect(Pet(uid: 'a', species: PetSpecies.crow, name: 'a', exp: 2250,
              bornAt: DateTime(2026)).adult,
          isTrue);
    });

    test('정령 짝 펫은 두 몫', () {
      final rng = Random(1);
      var owl = 0;
      for (var i = 0; i < 7000; i++) {
        if (PetRules.rollSpecies(rng, favored: PetSpecies.owl) ==
            PetSpecies.owl) {
          owl++;
        }
      }
      expect(owl / 7000, closeTo(2 / 7, 0.03));
    });

    test('바로 부화: 남은 1시간마다 마석 2 · 금화 20', () {
      final start = DateTime(2026, 11, 11, 9);
      expect(PetRules.hatchManaCost(start, start), 24);
      expect(PetRules.hatchGoldCost(start, start), 240);
      expect(PetRules.hatchManaCost(start, start.add(const Duration(hours: 11, minutes: 30))), 2);
      expect(PetRules.hatchGoldCost(start, start.add(const Duration(hours: 12))), 0);
    });

    test('공용 MP: 두 번째 펫부터 +10', () {
      expect(PetRules.mpMaxBonus(1), 0);
      expect(PetRules.mpMaxBonus(6), 50);
      expect(PetRules.mpRegenBonus(6), 10);
    });
  });

  group('정령 이별 (앱)', () {
    Future<(AppController, InMemoryRecordStore)> start(
        {int exp = 0, PetState? pets, DateTime? now}) async {
      final at = now ?? DateTime(2026, 11, 11, 14);
      final store = InMemoryRecordStore(
        profile: const PlayerProfile(
            name: '하루', spiritName: '불씨', spiritKind: SpiritKind.plant),
        history: [
          DailyRecord(
            date: DateTime(2026, 11, 10),
            gains: {'exp': exp, Wallet.gold: 1000, Wallet.manaStone: 100},
          ),
        ],
      );
      if (pets != null) await store.saveJson('pets', pets.toJson());
      final c = AppController(
        area: KoreaArea.area,
        store: store,
        health: FakeHealthSource(stepsByDay: {'2026-11-11': 3000}),
        location: FakeLocationSource(),
        clock: () => at,
        random: Random(3),
      );
      await c.init();
      return (c, store);
    }

    test('Lv.11 전에는 이별도 품기도 없다', () async {
      final (c, _) = await start(
          pets: const PetState(eggs: [PetEgg(id: 'e1')], firstEggFound: true));
      expect(c.player.level.level, lessThan(11));
      expect(c.farewellPending, isFalse);
      expect(c.farewellDone, isFalse);
      expect(c.bagUsed, 1); // 알은 가방 한 칸
      expect(await c.incubateEgg('e1'), isFalse);
      expect(c.itemName(ShopItem.bulssiPotion), '정령 물약');
    });

    test('Lv.11: 가방의 알이 깨어나고 정령은 처음 함께한 정령으로 남는다', () async {
      final need = LevelRules.totalExpToReach(11);
      final (c, _) = await start(
          exp: need,
          pets: const PetState(eggs: [PetEgg(id: 'e1')], firstEggFound: true));
      expect(c.player.level.level, 11);
      expect(c.farewellPending, isTrue);
      expect(c.hasEggForFarewell, isTrue);

      final pet = await c.completeFarewell(PetSpecies.owl, '호호');
      expect(pet.name, '호호');
      expect(c.farewellDone, isTrue);
      expect(c.farewellPending, isFalse);
      expect(c.pets.eggs, isEmpty);
      expect(c.companionName, '호호');
      expect(c.firstSpiritName, '불씨');
      expect(c.itemName(ShopItem.bulssiPotion), '펫 간식');
    });

    test('알이 없으면 선물 알에서 태어난다. 지나간 편지는 오지 않는다', () async {
      final (c, _) = await start(exp: LevelRules.totalExpToReach(31));
      expect(c.hasEggForFarewell, isFalse);
      await c.completeFarewell(PetSpecies.crow, '');
      expect(c.companionName, '까마귀'); // 이름을 비우면 종류 이름
      expect(c.pets.skippedLetters, containsAll(['lv20', 'lv30']));
      await c.refreshVitals();
      expect(c.receivedLetters, isEmpty);
    });

    test('정령이 떠난 뒤: 품기 12시간, 마석·금화로 바로 부화', () async {
      final (c, _) = await start(
          exp: LevelRules.totalExpToReach(12),
          pets: PetState(
            farewellAt: DateTime(2026, 11, 1),
            pets: [
              Pet(
                  uid: 'pet1',
                  species: PetSpecies.toad,
                  name: '개굴',
                  bornAt: DateTime(2026, 11, 1))
            ],
            companion: 'pet1',
            eggs: const [PetEgg(id: 'e2'), PetEgg(id: 'e3')],
            nextId: 4,
          ));
      expect(await c.incubateEgg('e2'), isTrue);
      expect(await c.incubateEgg('e3'), isFalse); // 한 번에 하나
      final egg = c.pets.eggs.first;
      expect(c.eggReady(egg), isFalse);
      expect(c.hatchManaCost(egg), 24);
      final mana = c.player.manaStones;
      expect(await c.hatchNow('e2', useMana: true), isTrue);
      expect(c.player.manaStones, mana - 24);
      expect(c.readyEgg?.id, 'e2');
      final pet = await c.hatch('e2', '꼬물');
      expect(pet, isNotNull);
      expect(c.pets.pets, hasLength(2));
      expect(c.pets.eggs.map((e) => e.id), ['e3']);
    });
  });
}
