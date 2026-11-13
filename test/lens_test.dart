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
  group('마법 돋보기 규칙 (11-11 #60)', () {
    test('종족 8가지, 별의 아이는 드물다', () {
      expect(LensRules.all.length, 8);
      expect({for (final i in LensRules.all) i.id}, Race.values.toSet());
      final rng = Random(3);
      final n = <Race, int>{};
      for (var i = 0; i < 15000; i++) {
        final r = LensRules.roll(rng);
        n[r] = (n[r] ?? 0) + 1;
      }
      expect(n[Race.starChild]!, lessThan(n[Race.elf]! * 0.7));
      expect(n.length, 8);
    });

    test('한 사진의 여러 얼굴은 되도록 서로 다른 종족', () {
      final rng = Random(5);
      var same = 0;
      for (var i = 0; i < 200; i++) {
        final r = LensRules.rollFaces(rng, 3);
        expect(r.length, 3);
        if (r.toSet().length < 3) same++;
      }
      expect(same, lessThan(30));
    });

    test('잡화상: 금화 40, 하루 3개, 가방에 들어간다', () {
      final i = TownRules.info(ShopItem.raceLens);
      expect(i.price, 40);
      expect(i.perLimit, 3);
      expect(TownRules.bagItems, contains(ShopItem.raceLens));
      expect(TownRules.items.map((e) => e.item), contains(ShopItem.raceLens));
      // 예전 안개 돋보기는 계속 팔지 않고, 예전 값도 그대로
      expect(TownRules.items.map((e) => e.item), isNot(contains(ShopItem.magicLens)));
      expect(TownRules.info(ShopItem.magicLens).price, 60);
    });
  });

  group('감정 (앱)', () {
    late DateTime now;
    late InMemoryRecordStore store;
    AppController make() => AppController(
          area: KoreaArea.area,
          store: store,
          health: FakeHealthSource(stepsByDay: {'2026-11-11': 3000}),
          location: FakeLocationSource(),
          clock: () => now,
          random: Random(2),
        );

    setUp(() {
      now = DateTime(2026, 11, 11, 14);
      store = InMemoryRecordStore(
        profile: const PlayerProfile(name: '하루'),
        history: [
          DailyRecord(date: DateTime(2026, 11, 10), gains: {Wallet.gold: 1000}),
        ],
      );
    });

    test('돋보기를 쓰고, 처음 본 종족은 도감과 경험치', () async {
      final c = make();
      await c.init();
      // 묶음 19 #154: 매일 첫 감정은 무료 (돋보기를 쓰지 않는다)
      expect(c.lensFreeToday, isTrue);
      final exp0 = c.player.totalExp;
      final r = (await c.appraise([Race.elf, Race.elf, Race.dwarf]))!;
      expect(r.firsts, [Race.elf, Race.dwarf]);
      expect(r.exp, 2 * LensRules.firstExp);
      expect(c.player.totalExp - exp0, 2 * LensRules.firstExp);
      expect(c.lensFreeToday, isFalse);
      expect(await c.appraise([Race.elf]), isNull); // 무료는 썼고 돋보기가 없다
      expect(await c.buy(ShopItem.raceLens), PurchaseCheck.ok);
      expect(c.bagCount(ShopItem.raceLens), 1);
      expect(await c.appraise([Race.elf]), isNotNull);
      expect(c.bagCount(ShopItem.raceLens), 0);
      expect(c.racesSeen, {Race.elf, Race.dwarf});
      expect(c.lens.counts['elf'], 3);
      expect(c.lensRewardsLeft, LensRules.rewardedPerDay - 2);

      // 다시 열어도 남아 있다
      final again = make();
      await again.init();
      expect(again.racesSeen, {Race.elf, Race.dwarf});
      expect(again.lensRewardsLeft, LensRules.rewardedPerDay - 2);
      expect(again.lensFreeToday, isFalse);
    });

    test('하루 3개까지 사고, 보상은 하루 3번, 다음 날 다시', () async {
      final c = make();
      await c.init();
      for (var i = 0; i < 3; i++) {
        expect(await c.buy(ShopItem.raceLens), PurchaseCheck.ok);
      }
      expect(await c.buy(ShopItem.raceLens), PurchaseCheck.limitReached);
      // 무료 1번 + 돋보기 3개
      for (var i = 0; i < 4; i++) {
        expect(await c.appraise([Race.mermaid]), isNotNull);
      }
      expect(c.lensRewardsLeft, 0);
      expect(c.bagCount(ShopItem.raceLens), 0);
      final more = await c.appraise([Race.mermaid]);
      expect(more, isNull);
      now = DateTime(2026, 11, 12, 9);
      expect(c.lensRewardsLeft, LensRules.rewardedPerDay);
      expect(c.lensFreeToday, isTrue); // 자정에 다시
    });
  });
}
