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
  group('속성 상성 (11-11 #63)', () {
    test('요청서 상성표 그대로', () {
      expect(ElementRules.multiplier(Element.fire, Element.wind), ElementRules.strong);
      expect(ElementRules.multiplier(Element.fire, Element.water), ElementRules.weak);
      expect(ElementRules.multiplier(Element.light, Element.light), ElementRules.weak);
      expect(ElementRules.multiplier(Element.dark, Element.dark), ElementRules.weak);
      expect(ElementRules.multiplier(Element.thunder, Element.metal), ElementRules.strong);
      expect(ElementRules.multiplier(Element.poison, Element.water), ElementRules.strong);
      expect(ElementRules.multiplier(null, Element.fire), 1);
      expect(ElementRules.multiplier(Element.fire, null), 1);
      expect(ElementRules.multiplier(Element.ice, Element.thunder), 1);
      // 물을 이기는 속성
      expect(ElementRules.beats(Element.water).toSet(),
          {Element.ice, Element.wind, Element.thunder, Element.poison});
    });

    test('슬라임 11종, 모든 필드 몬스터에 속성표', () {
      expect(Monsters.slimes.length, 11);
      expect(Monsters.info(MonsterId.ashSlime).element, isNull);
      expect(Monsters.info(MonsterId.metalSlime).element, Element.metal);
      expect(Monsters.info(MonsterId.giantRat).element, Element.poison);
      final total = FieldMonsterRules.slimeWeights.fold(0.0, (a, e) => a + e.$2);
      expect(total, closeTo(1, 1e-9));
    });

    test('사냥 점수: 무기 속성이 있으면 그것, 없으면 이기는 속성이 나눠 받음', () {
      expect(ElementRules.huntScore(Element.water, Element.fire), {Element.fire: 2.0});
      final s = ElementRules.huntScore(Element.metal, null);
      expect(s.keys.toSet(), {Element.fire, Element.thunder});
      expect(s.values.fold(0.0, (a, b) => a + b), closeTo(1, 1e-9));
      expect(ElementRules.huntScore(null, null), isEmpty);
      expect(ElementRules.mainOf({Element.fire: 10}), isNull); // 30점부터
      expect(ElementRules.mainOf({Element.fire: 31, Element.ice: 40}), Element.ice);
    });

    test('상성 문구와 피해', () {
      Battle make(Element? atk) => Battle(
            playerMaxHp: 1000,
            playerAttack: 100,
            skillDamage: 100,
            floors: const [Foe(monster: MonsterId.waterSlime, maxHp: 100000, attack: 1)],
            rng: Random(1),
            attackElement: atk,
          );
      final strong = make(Element.thunder)..tick();
      final weak = make(Element.fire)..tick();
      final none = make(null)..tick();
      expect(strong.lastEvent, Battle.superEffective);
      expect(weak.lastEvent, Battle.notEffective);
      expect(strong.lastDealt, greaterThan(none.lastDealt));
      expect(weak.lastDealt, lessThan(none.lastDealt));
    });

    test('주 속성에 강한 몬스터가 더 자주', () {
      final rng = Random(4);
      var base = 0, fav = 0;
      for (var i = 0; i < 20000; i++) {
        final k = rng.nextDouble(), e = rng.nextDouble();
        if (Monsters.info(FieldMonsterRules.pickCommon(k, e)).element == Element.poison) base++;
        if (Monsters.info(FieldMonsterRules.pickCommon(k, e,
                    favored: {Element.poison}))
                .element ==
            Element.poison) {
          fav++;
        }
      }
      expect(fav, greaterThan(base * 1.3));
    });

    test('펫 기본 속성과 알 속성', () {
      expect(PetRules.info(PetSpecies.crow).element, Element.wind);
      expect(PetRules.info(PetSpecies.homunculus).element, isNull);
      final rng = Random(2);
      var lizard = 0;
      for (var i = 0; i < 6000; i++) {
        if (PetRules.rollSpecies(rng, element: Element.fire) == PetSpecies.lizard) lizard++;
      }
      // 3/8 근처 (보통은 1/6)
      expect(lizard / 6000, greaterThan(0.3));
    });
  });

  group('속성 (앱)', () {
    test('사냥 기록에 속성 점수가 쌓이고 칭호가 열린다', () async {
      final c = AppController(
        area: KoreaArea.area,
        store: InMemoryRecordStore(
          profile: const PlayerProfile(name: '하루'),
          history: [
            DailyRecord(date: DateTime(2026, 11, 10), counters: {'el:fire': 1005}),
          ],
        ),
        health: FakeHealthSource(stepsByDay: {'2026-11-11': 3000}),
        location: FakeLocationSource(),
        clock: () => DateTime(2026, 11, 11, 14),
        random: Random(1),
      );
      await c.init();
      expect(c.elementScores[Element.fire], closeTo(100.5, 1e-9));
      expect(c.mainElement, Element.fire);
      expect(c.player.titles, contains(TitleId.elFire));
      expect(TitleRules.visible(c.player.titles).map((t) => t.id),
          contains(TitleId.elFire));
      expect(TitleRules.all.map((t) => t.id), isNot(contains(TitleId.elFire)));
    });
  });

  group('원정 MP 물약 (11-11 #64)', () {
    test('한 병으로 채우는 가장 작은 물약 먼저, 아니면 병 수', () async {
      final c = AppController(
        area: KoreaArea.area,
        store: InMemoryRecordStore(
          profile: const PlayerProfile(name: '하루'),
          history: [
            DailyRecord(date: DateTime(2026, 11, 10), gains: {Wallet.gold: 1000}),
          ],
        ),
        health: FakeHealthSource(stepsByDay: {'2026-11-11': 3000}),
        location: FakeLocationSource(),
        clock: () => DateTime(2026, 11, 11, 14),
        random: Random(1),
      );
      await c.init();
      expect(c.manaOptions(10), isEmpty); // 물약이 없으면 버튼 없음
      for (var i = 0; i < 2; i++) {
        await c.buy(ShopItem.manaSmall);
      }
      await c.buy(ShopItem.mana);
      final small = (c.mpMax * 0.2).round();
      final big = (c.mpMax * 0.4).round();
      final a = c.manaOptions(small - 1);
      expect(a.first.item, ShopItem.manaSmall);
      expect(a.first.bottles, 1);
      final b = c.manaOptions(small + 1);
      expect(b.first.item, ShopItem.mana);
      final d = c.manaOptions(big + 1);
      expect(d.first.bottles, 2);
    });
  });
}
