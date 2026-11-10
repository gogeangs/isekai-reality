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

/// 늘 같은 값을 내는 난수 (실패·성공을 정해 두고 시험한다)
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var now = DateTime(2026, 11, 11, 14);
  Future<AppController> start(Map<String, int> gains,
      {Random? random, Map<String, Map<String, dynamic>>? json}) async {
    now = DateTime(2026, 11, 11, 14);
    final c = AppController(
      area: KoreaArea.area,
      store: InMemoryRecordStore(
        profile: const PlayerProfile(name: '하루'),
        history: [
          DailyRecord(
              date: DateTime(2026, 11, 10), gains: {Wallet.gold: 5000, ...gains}),
        ],
        json: json,
      ),
      health: FakeHealthSource(stepsByDay: {'2026-11-11': 3000}),
      location: FakeLocationSource(),
      clock: () => now,
      random: random ?? Random(1),
    )..mailSources = const [];
    await c.init();
    return c;
  }

  group('물약 품질 (11-11 #74)', () {
    test('순서 +2, 귀한·가공 재료 +1 → 보통 · 좋음 · 최상', () {
      const h = MaterialId.herb, j = MaterialId.slimeJelly;
      expect(AlchemyRules.quality(perfect: false, put: [j, h, h]), PotionQuality.normal);
      expect(AlchemyRules.quality(perfect: true, put: [h, h, j]), PotionQuality.good);
      expect(
          AlchemyRules.quality(
              perfect: true,
              put: [MaterialId.herbExtract, MaterialId.waterCore, MaterialId.essence]),
          PotionQuality.best);
      // 귀한 재료만 있고 순서가 틀리면 보통
      expect(
          AlchemyRules.quality(
              perfect: false,
              put: [MaterialId.essence, MaterialId.waterCore, MaterialId.herbExtract]),
          PotionQuality.normal);
    });

    test('가방 키: 예전 완벽한 조제(*)는 좋음, **는 최상', () {
      expect(AlchemyRules.parseKey('healBig'),
          (id: PotionId.healBig, quality: PotionQuality.normal));
      expect(AlchemyRules.parseKey('healBig*')!.quality, PotionQuality.good);
      expect(AlchemyRules.parseKey('healBig**')!.quality, PotionQuality.best);
      expect(AlchemyRules.parseKey('?:herb'), isNull);
    });

    test('새 물약 레시피: 공격 속성 10종 · 걸음 · 녹이는 물약', () {
      for (final e in Element.values) {
        final put = [
          Materials.elementStone(e),
          Materials.elementJelly(e),
          Materials.elementJelly(e),
          MaterialId.essence,
        ];
        final m = AlchemyRules.match(put);
        expect(m, (id: AlchemyRules.weaponOf(e), perfect: true));
        expect(AlchemyRules.info(m!.id).slot, PotionSlot.element);
      }
      expect(AlchemyRules.match(
              [MaterialId.fireJelly, MaterialId.fireJelly, MaterialId.herb])!
          .id, PotionId.thaw);
      expect(AlchemyRules.info(PotionId.steps).slot, PotionSlot.explore);
      expect(AlchemyRules.info(PotionId.callMonsters).name, '유인 물약');
      expect(AlchemyRules.info(PotionId.strength).slot, PotionSlot.battle);
    });
  });

  group('동시 사용과 지속 (11-11 #74)', () {
    test('같은 종류를 또 마시면 새 물약으로 바뀐다, 전투가 끝날 때마다 하나씩 준다', () async {
      // 가방에 물약을 넣어 둔다
      final c = await start({}, json: {
        'alchemy': {
          'potions': {'strength': 1, 'agility*': 1, 'resistFire': 1, 'weaponIce': 1},
        },
      });
      expect(await c.drinkPotion('strength'), isNull);
      expect(c.activeBuffs.map((b) => b.key), ['strength']);
      expect(await c.drinkPotion('agility*'), isNull);
      // 전투 물약은 하나만 (힘 → 민첩으로 바뀜). 좋음은 전투 수가 더 길다
      expect(c.activeBuffs.map((b) => b.key), ['agility']);
      expect(c.activeBuffs.single.battles, 6);
      expect(await c.drinkPotion('resistFire'), isNull);
      expect(await c.drinkPotion('weaponIce'), isNull);
      // 저항과 공격 속성은 같은 「속성」 칸이라 공격 물약만 남는다
      expect(c.activeBuffs.map((b) => b.key).toSet(), {'agility', 'weaponIce'});
      expect(c.weaponPotionElement, Element.ice);
      expect(c.activeResists, isEmpty);
      expect(c.buffLeftLabel(c.activeBuffs.last), '전투 5번 남음');
    });
  });

  group('전투 상태 이상 (11-11 #74)', () {
    Foe foe(MonsterId m) => BattleRules.fieldFoes(
            level: 5, monster: m, mods: const [], spawnId: 'x')
        .first;

    test('얼음 슬라임에게 얼면 다음 차례를 쉬고, 녹이는 물약이 풀어 준다', () {
      final b = Battle(
        playerMaxHp: 1000,
        playerAttack: 1,
        floors: [foe(MonsterId.iceSlime)],
        rng: _Fixed(0.01),
        potions: const [
          BattlePotion(key: 'alc:thaw', name: '녹이는 물약', count: 1, cure: CureKind.freeze),
        ],
      );
      b.tick();
      expect(b.frozen, isTrue);
      expect(b.drink('alc:thaw'), isTrue);
      expect(b.frozen, isFalse);
      expect(b.freezeImmune, 3);
    });

    test('공격 속성 물약은 무기 속성보다 먼저 쓰이고, 얼음은 몬스터를 얼린다', () {
      final b = Battle(
        playerMaxHp: 1000,
        playerAttack: 5,
        floors: [foe(MonsterId.ashSlime)],
        rng: _Fixed(0.01),
        attackElement: Element.wind,
        weaponPotion: Element.ice,
      );
      b.tick();
      expect(b.foeFreezes, 1);
    });
  });

  group('공방 변환 (11-11 #74)', () {
    test('상위 변환: 쥐 가죽 3 → 윤기 나는 쥐털, 금화 10, 10분', () async {
      final c = await start({'ratHide': 4});
      final p = ConvertRules.upgrade(MaterialId.ratHide)!;
      expect(p.get, {MaterialId.glossyFur: 1});
      final gold = c.player.gold;
      expect(await c.startConvert(p), isTrue);
      expect(c.player.materialCount(MaterialId.ratHide), 1);
      expect(c.player.gold, gold - 10);
      // 변환대는 한 칸
      expect(c.canConvert(ConvertRules.refine(Element.fire)), isFalse);
      expect(await c.collectConvert(), isNull);
      now = now.add(const Duration(minutes: 10));
      expect(await c.collectConvert(), isNotNull);
      expect(c.player.materialCount(MaterialId.glossyFur), 1);
      expect(c.alchemy.mastery, AlchemistRules.convertPoints);
    });

    test('마석 정제: 마석 3 + 불꽃 코어 1 → 불꽃의 마석', () async {
      final c = await start({'fireCore': 1, Wallet.manaStone: 3});
      final stones = c.player.manaStones;
      expect(await c.startConvert(ConvertRules.refine(Element.fire)), isTrue);
      expect(c.player.manaStones, stones - 3);
      now = now.add(const Duration(minutes: 20));
      await c.collectConvert();
      expect(c.player.materialCount(MaterialId.stoneFire), 1);
    });

    test('분해는 바로: 귀한 재료 1 → 마석 2, 좋음 물약 → 약초 + 마석', () async {
      final c = await start({'glossyFur': 1});
      final stones = c.player.manaStones;
      expect(await c.startConvert(ConvertRules.decomposeMaterial(MaterialId.glossyFur)),
          isTrue);
      expect(c.player.manaStones, stones + 2);
      final p = ConvertRules.decomposePotion('healBig*');
      expect(p.get, {MaterialId.herb: 1});
      expect(p.getManaStones, 1);
      expect(c.convertJob, isNull);
    });
  });

  group('대장간 장비 속성 (11-11 #74)', () {
    Map<String, Map<String, dynamic>> withDagger({int level = 0, bool fire = false}) => {
          'armory': Armory(items: [
            EquipItem(
                uid: 'w',
                base: EquipBase.dagger,
                grade: EquipGrade.white,
                element: fire ? Element.fire : null,
                elementLevel: level),
          ]).toJson(),
        };

    test('실패하면 금화만 잃고 코어는 그대로, 장비도 그대로', () async {
      final c = await start({'glowFireCore': 1},
          random: _Fixed(0.10), json: withDagger()); // 0.10 < 25% → 실패
      final gold = c.player.gold;
      expect(await c.smith('w', SmithAction.apply, to: Element.fire),
          SmithResult.failed);
      expect(c.player.gold, gold - 100);
      expect(c.player.materialCount(MaterialId.glowFireCore), 1);
      expect(c.armory.byUid('w')!.element, isNull);
    });

    test('입히기 → 강화 → 추출 (코어를 돌려받고 강화 단계는 사라짐)', () async {
      final c = await start({'glowFireCore': 3},
          random: _Fixed(0.99), json: withDagger());
      expect(await c.smith('w', SmithAction.apply, to: Element.fire), SmithResult.ok);
      expect(await c.smith('w', SmithAction.upgrade), SmithResult.ok);
      expect(c.armory.byUid('w')!.elementLevel, 1);
      expect(c.player.materialCount(MaterialId.glowFireCore), 0);
      expect(c.gear.attackLevel, 0); // 입지 않았다
      expect(await c.smith('w', SmithAction.extract), SmithResult.ok);
      expect(c.armory.byUid('w')!.element, isNull);
      expect(c.armory.byUid('w')!.elementLevel, 0);
      expect(c.player.materialCount(MaterialId.glowFireCore), 1);
    });

    test('강화 실패 확률은 단계마다 커지고, 대장장이는 절반 (숨은 규칙)', () {
      expect(SmithRules.failChance(SmithAction.upgrade, level: 0), 0.30);
      expect(SmithRules.failChance(SmithAction.upgrade, level: 2), 0.60);
      expect(SmithRules.failChance(SmithAction.apply, blacksmith: true), 0.125);
      expect(SmithRules.gold(SmithAction.change, blacksmith: true), 75);
      expect(SmithRules.strongAt(3), closeTo(1.6, 1e-9));
      expect(SmithRules.guardAt(3), closeTo(0.65, 1e-9));
    });
  });

  group('걸음 물약 · 연금술사 (11-11 #74)', () {
    test('게이지 보너스 걸음은 열쇠에만 더해지고 목표 보너스에는 세지 않는다', () {
      final g = DungeonGaugeRules.today(steps: 2000, bonusSteps: 600);
      expect(g.keysEarnedToday, 1);
      expect(g.stepsIntoNextKey, 100);
      final goal = DungeonGaugeRules.today(steps: 2000, stepGoal: 2500, bonusSteps: 600);
      expect(goal.goalBonusKey, isFalse);
    });

    test('숙련도 단계와 열리는 능력', () {
      expect(AlchemistRules.rankOf(0), AlchemistRank.apprentice);
      expect(AlchemistRules.rankOf(400), AlchemistRank.artisan);
      expect(AlchemistRules.rankOf(1000), AlchemistRank.master);
      expect(AlchemistRules.abilities.first.level, 15);
      expect(AlchemistRules.homunculusElement(null, Element.fire, 1), Element.fire);
      expect(AlchemistRules.homunculusElement(Element.fire, Element.ice, 2), Element.fire);
      expect(AlchemistRules.homunculusElement(Element.fire, Element.ice, 3), Element.ice);
    });
  });
}
