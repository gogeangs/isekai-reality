import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/geo/geo.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/models/pet_state.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';

void main() {
  final t0 = DateTime(2026, 11, 15, 10);

  Future<AppController> start(InMemoryRecordStore store,
      {Map<String, int> windows = const {}}) async {
    final c = AppController(
      store: store,
      health: FakeHealthSource(windowSteps: windows),
      clock: () => t0,
    )..mailSources = const [];
    await c.init();
    return c;
  }

  InMemoryRecordStore account(int level,
          {PetState? pets,
          Map<String, double> big = const {},
          List<DailyRecord> extra = const [],
          Map<String, dynamic> json = const {}}) =>
      InMemoryRecordStore(
        profile: const PlayerProfile(name: '하루', lastSeenLevel: 99),
        history: [
          ...extra,
          DailyRecord(
            date: DateTime(2026, 11, 14),
            gains: {'exp': LevelRules.totalExpToReach(level)},
          ),
        ],
        json: {
          'tutorial': {'step': TutorialStep.done.index},
          if (pets != null) 'pets': pets.toJson(),
          'mastery': {'big': big},
          ...json,
        },
      );

  group('#184 펫 설명: 숫자·틱 없음', () {
    test('특기·스킬 문구', () {
      for (final s in PetSpecies.values) {
        final i = PetRules.info(s);
        for (final t in [i.special, i.specialAdult, i.skillText, i.skillTextAdult]) {
          expect(RegExp(r'[0-9%×]|틱').hasMatch(t), isFalse, reason: t);
        }
      }
      expect(PetRules.info(PetSpecies.crow).special, '원정을 빨리 다녀와요');
      expect(PetRules.info(PetSpecies.lizard).specialAdult, '원정 기력을 더 덜 써요');
      expect(PetRules.info(PetSpecies.homunculus).skillText, '받는 피해를 오래 막아 줘요');
      expect(PetRules.info(PetSpecies.homunculus).special,
          contains('어느 몬스터에게도 약하지 않아요'));
    });
  });

  group('#186 #187 알', () {
    test('확률: 보통 2% · 던전 보스 10% · 희귀 5% · 전설 20%', () {
      expect(PetRules.fieldEggChance(ModGrade.none), 0.02);
      expect(PetRules.fieldEggChance(ModGrade.common), 0.02);
      expect(PetRules.fieldEggChance(ModGrade.rare), 0.05);
      expect(PetRules.fieldEggChance(ModGrade.legend), 0.20);
      expect(PetRules.dungeonEggChance, 0.10);
    });

    test('광고 보고 남은 시간 절반, 알 하나에 한 번', () async {
      final born = DateTime(2026, 11, 1);
      final c = await start(account(12,
          pets: PetState(
            farewellAt: born,
            pets: [Pet(uid: 'pet1', species: PetSpecies.owl, name: '부엉', bornAt: born)],
            companion: 'pet1',
            firstPet: 'pet1',
            eggs: [PetEgg(id: 'e1', incubatedAt: t0.subtract(const Duration(hours: 2)))],
            nextId: 2,
          )));
      c.watchAd = (_) async => true;
      final egg = c.pets.eggs.single;
      expect(c.canAdHalveEgg(egg), isTrue);
      expect(await c.adHalveEgg('e1'), isTrue);
      final after = c.pets.eggs.single;
      // 남은 10시간 → 5시간
      expect(after.incubatedAt!.add(PetRules.hatchTime).difference(t0),
          const Duration(hours: 5));
      expect(after.adHalved, isTrue);
      expect(c.canAdHalveEgg(after), isFalse);
      expect(await c.adHalveEgg('e1'), isFalse);
      expect(PetEgg.fromJson(after.toJson()).adHalved, isTrue);
    });
  });

  group('#190 호문쿨루스', () {
    test('원정 재료 +2(성체 가끔 +3), 보호막 3번(성체 4번)', () {
      final r = math.Random(1);
      expect(PetRules.extraMaterials(PetSpecies.homunculus, r, adult: false), 2);
      final adult = {
        for (var i = 0; i < 50; i++)
          PetRules.extraMaterials(PetSpecies.homunculus, r, adult: true),
      };
      expect(adult, {2, 3});
      expect(PetRules.shieldHits(adult: false), 3);
      expect(PetRules.shieldHits(adult: true), 4);
    });

    test('상성 약점 없음 · 속성 몬스터 피해 덜', () {
      Battle make({bool homun = false}) => Battle.forPlayer(
            level: 10,
            stats: Stats.all(10),
            floors: const [
              Foe(monster: MonsterId.fireSlime, maxHp: 100000, attack: 50),
            ],
            rng: math.Random(3),
          )
            ..noWeakness = homun
            ..elementGuard = homun ? 0.10 : 0;
      final a = make(), b = make(homun: true);
      for (var i = 0; i < 6; i++) {
        a.tick();
        b.tick();
      }
      expect(b.playerHp, greaterThan(a.playerHp));
    });
  });

  group('#189 속성 점수', () {
    test('밤·이른 아침 걸음 (예전 기록은 저녁 8시 뒤·오전 5~8시)', () {
      final s = ElementRules.scoresFrom([
        DailyRecord(date: DateTime(2026, 11, 1), stepsNight: 4500, stepsDawn: 2000),
        DailyRecord(
            date: DateTime(2026, 11, 2), stepsAfter8pm: 3000, stepsMorning: 1000),
      ]);
      expect(s[Element.dark], (4 + 3) * 0.5);
      expect(s[Element.light], (2 + 1) * 0.5);
    });

    test('건강 앱 시간 창에서 밤·아침 걸음을 읽는다', () async {
      final c = await start(account(5), windows: {
        '2026-11-15@0': 2000,
        '2026-11-15@5': 3000,
      });
      expect(c.player.today!.stepsNight, 2000);
      expect(c.player.today!.stepsDawn, 3000);
    });

    test('채집·속성 부여로 쌓이고, 주 속성이 생기면 한마디 + 프로필 기운', () async {
      final c = await start(account(9, json: {
        'harvest': {
          'granted': true,
          'tools': {for (final t in HarvestTool.values) t.name: 99},
        },
        'gates': {'legacy': true},
      }));
      await c.handleFix(const LocationFix(point: GeoPoint(37.3219, 126.8309)));
      expect(c.mainElement, isNull);
      for (var i = 0; i < 31; i++) {
        final spot = HarvestSpot(
            id: 'w$i',
            kind: HarvestKind.water,
            point: const GeoPoint(37.3219, 126.8309));
        await c.harvestAt(spot, HarvestGrade.quick);
      }
      expect(c.elementScores[Element.water], greaterThanOrEqualTo(30));
      expect(c.mainElement, Element.water);
      expect(c.masteryState.pending, contains('요즘 너한테서 시원한 물 냄새가 나.'));
    });

    test('예전 기록: 남은 기록으로 한 번 세고, 대사 없이', () async {
      final c = await start(account(12, big: {'harvest': 100}, json: {
        'mastery': {
          'big': {'harvest': 100},
          'detail': {'harvest:ore': 70},
        },
      }));
      expect(c.elementScores[Element.metal], 35);
      expect(c.mainElement, Element.metal);
      expect(c.masteryState.pending.any((l) => l.contains('쇠 냄새')), isFalse);
    });

    test('첫 펫: 연금술 1등 → 호문쿨루스, 아니면 5속성 1등, 모두 0이면 호문쿨루스', () {
      expect(PetRules.firstPetFrom({Element.fire: 50}, alchemyTop: true),
          PetSpecies.homunculus);
      expect(PetRules.firstPetFrom({Element.fire: 5, Element.dark: 8, Element.water: 90}),
          PetSpecies.blackCat);
      expect(PetRules.firstPetFrom({Element.water: 90}), PetSpecies.homunculus);
      expect(PetRules.firstPetFrom({}), PetSpecies.homunculus);
    });

    test('연금술 1등 계정 Lv.11 → 첫 펫 호문쿨루스', () async {
      final c = await start(account(11, big: {'alchemy': 20, 'combat': 5}));
      expect(c.alchemyIsTop, isTrue);
      expect(c.firstPetSpecies, PetSpecies.homunculus);
    });

    test('알: 연금술 1등이면 호문쿨루스 3배', () {
      var normal = 0, top = 0;
      final r1 = math.Random(7), r2 = math.Random(7);
      for (var i = 0; i < 4000; i++) {
        if (PetRules.rollSpecies(r1) == PetSpecies.homunculus) normal++;
        if (PetRules.rollSpecies(r2, alchemyTop: true) == PetSpecies.homunculus) {
          top++;
        }
      }
      expect(top, greaterThan(normal * 2));
    });
  });

  group('#191 기운 공명', () {
    test('같은 속성 펫: 특기·스킬 효과 +10%', () {
      expect(PetRules.resonant(PetSpecies.lizard, Element.fire), isTrue);
      expect(PetRules.resonant(PetSpecies.homunculus, null), isFalse);
      expect(
          PetRules.mpFactor(PetSpecies.lizard, adult: false, resonant: true),
          closeTo(1 - 0.25 * 1.1, 1e-9));
      expect(PetRules.skillMultiplier(PetSkill.peck, adult: false, resonant: true),
          closeTo(4.4, 1e-9));
    });
  });
}
