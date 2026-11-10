import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/geo/geo.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/location/location_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/map/korea_area.dart';

void main() {
  group('수식어 확률', () {
    test('Lv.1은 없음 60 · 일반 25 · 희귀 12 · 전설 3', () {
      final (none, common, rare, legend) = ModifierRules.chances(1);
      expect(none, closeTo(0.60, 1e-9));
      expect(common, 0.25);
      expect(rare, closeTo(0.12, 1e-9));
      expect(legend, closeTo(0.03, 1e-9));
    });

    test('레벨마다 희귀 +0.3%p, 전설 +0.1%p, 상한 49 · 25 · 20 · 6', () {
      final (n10, _, r10, l10) = ModifierRules.chances(11);
      expect(r10, closeTo(0.15, 1e-9));
      expect(l10, closeTo(0.04, 1e-9));
      expect(n10, closeTo(0.56, 1e-9));
      final (n, c, r, l) = ModifierRules.chances(60);
      expect([n, c, r, l].map((x) => (x * 100).round()), [49, 25, 20, 6]);
    });

    test('자리마다 같은 수식어, 실제 비율도 확률과 비슷하다', () {
      final counts = {for (final g in ModGrade.values) g: 0};
      for (var i = 0; i < 4000; i++) {
        final mods =
            ModifierRules.roll('2026-11-10#$i', MonsterId.ashSlime, 1);
        expect(ModifierRules.roll('2026-11-10#$i', MonsterId.ashSlime, 1),
            mods);
        counts[ModifierRules.gradeOf(mods)] =
            counts[ModifierRules.gradeOf(mods)]! + 1;
      }
      expect(counts[ModGrade.none]! / 4000, closeTo(0.60, 0.03));
      expect(counts[ModGrade.common]! / 4000, closeTo(0.25, 0.03));
      expect(counts[ModGrade.rare]! / 4000, closeTo(0.12, 0.02));
      expect(counts[ModGrade.legend]! / 4000, closeTo(0.03, 0.01));
    });

    test('던전 몬스터에는 붙지 않고, 전설은 둘까지 붙는다', () {
      var two = 0;
      for (var i = 0; i < 4000; i++) {
        expect(ModifierRules.roll('d#$i', MonsterId.labyrinthBat, 30), isEmpty);
        final mods = ModifierRules.roll('f#$i', MonsterId.giantRat, 30);
        expect(mods.length, lessThanOrEqualTo(2));
        if (mods.length == 2) {
          two++;
          expect(ModifierRules.info(mods.first).grade, ModGrade.legend);
          expect(ModifierRules.info(mods.last).grade,
              isNot(ModGrade.legend));
        }
        // 다른 몬스터 전용 수식어는 붙지 않는다
        for (final m in mods) {
          final only = ModifierRules.info(m).monster;
          expect(only == null || only == MonsterId.giantRat, isTrue);
        }
      }
      expect(two, greaterThan(0));
    });

    test('이름은 수식어를 앞에 붙이고, 색은 가장 높은 등급', () {
      const mods = [ModifierId.ancient, ModifierId.enraged];
      expect(ModifierRules.displayName(MonsterId.ashSlime, mods),
          '고대의 분노한 슬라임');
      expect(ModifierRules.gradeOf(mods), ModGrade.legend);
      expect(ModifierRules.recordInCodex(const [ModifierId.hungry]), isFalse);
      expect(ModifierRules.recordInCodex(mods), isTrue);
      final key = ModifierRules.codexKey(MonsterId.ashSlime, mods);
      expect(ModifierRules.parseCodexKey(key), (MonsterId.ashSlime, mods));
    });
  });

  group('수식어 전투', () {
    Battle fight(List<ModifierId> mods, {int seed = 1, int level = 5}) {
      final stats = BattleRules.expectedStats(level);
      return Battle.forPlayer(
        level: level,
        stats: stats,
        floors: BattleRules.fieldFoes(
            level: level,
            monster: MonsterId.giantRat,
            mods: mods,
            spawnId: 's$seed'),
        rng: Random(seed),
      );
    }

    test('수식어가 없으면 예전과 같은 한 마리', () {
      final b = fight(const []);
      expect(b.floors, hasLength(1));
      expect(b.foe.name, '큰쥐');
      expect(b.runToEnd().phase, BattlePhase.cleared);
    });

    test('굶주린은 먼저 치고, 능력치는 배수만큼', () {
      final plain = fight(const []);
      final b = fight(const [ModifierId.hungry]);
      expect(b.foe.attack, (plain.foe.attack * 1.25).round());
      final hp = b.playerHp;
      b.tick();
      expect(b.lastTaken, greaterThan(0));
      expect(b.playerHp, lessThan(hp));
    });

    test('무리 지은은 2~3마리, 찍찍거리는은 두 마리', () {
      for (var i = 0; i < 20; i++) {
        final n = fight(const [ModifierId.pack], seed: i).floors.length;
        expect(n, inInclusiveRange(2, 3));
      }
      expect(fight(const [ModifierId.squeaky]).floors, hasLength(2));
    });

    test('황금빛은 3턴 안에 못 잡으면 도망친다', () {
      final b = Battle(
        playerMaxHp: 1000,
        playerAttack: 1,
        floors: const [
          Foe(
              monster: MonsterId.ashSlime,
              maxHp: 100,
              attack: 1,
              mods: [ModifierId.golden],
              speed: 1.6),
        ],
        rng: Random(1),
      );
      b.runToEnd();
      expect(b.phase, BattlePhase.escaped);
      expect(b.ticks, 3);
      // 보통 각성자는 3턴 안에 잡을 수 있다
      var caught = 0;
      for (var i = 0; i < 20; i++) {
        if (fight(const [ModifierId.golden], seed: i).runToEnd().phase ==
            BattlePhase.cleared) {
          caught++;
        }
      }
      expect(caught, greaterThan(15));
    });

    test('독은 3턴 동안 최대 HP 2%씩', () {
      final b = Battle(
        playerMaxHp: 1000,
        playerAttack: 1,
        floors: const [
          Foe(
              monster: MonsterId.giantRat,
              maxHp: 1000,
              attack: 1,
              mods: [ModifierId.venomous]),
        ],
        rng: Random(2),
      );
      var poisoned = false;
      for (var i = 0; i < 30 && !poisoned; i++) {
        b.tick();
        poisoned = b.poisonTurns > 0;
      }
      expect(poisoned, isTrue);
      final hp = b.playerHp;
      b.tick();
      // 몬스터 공격(약 1) + 독 20
      expect(hp - b.playerHp, greaterThanOrEqualTo(20));
    });
  });

  group('수식어 사냥 기록', () {
    test('희귀 수식어 몬스터는 도감 수식어 칸에, 무리는 마리 수만큼 보상', () async {
      final now = DateTime(2026, 11, 8, 14);
      final c = AppController(
        area: KoreaArea.area,
        store: InMemoryRecordStore(profile: const PlayerProfile(name: '하루')),
        health: FakeHealthSource(stepsByDay: {'2026-11-08': 3000}),
        location: FakeLocationSource(),
        clock: () => now,
        random: Random(1),
      );
      await c.init();
      const spawn = FieldSpawn(
        id: '2026-11-8#pack',
        monster: MonsterId.giantRat,
        point: GeoPoint(37.3, 126.8),
        modifiers: [ModifierId.pack],
      );
      final b = c.startFieldBattle(spawn)!..runToEnd(useSkills: true);
      expect(b.phase, BattlePhase.cleared);
      final n = b.floors.length;
      final stones = c.player.manaStones;
      final exp = await c.finishFieldBattle(spawn, b);
      expect(exp, RuleConstants.fieldMonsterExp * n);
      expect(c.player.manaStones, stones + n);
      expect(c.history.last.fieldMonstersPurified, 1); // 하루 제한에는 1마리
      expect(c.huntTotals[MonsterId.giantRat], n);
      expect(c.modHuntTotals,
          {ModifierRules.codexKey(MonsterId.giantRat, spawn.modifiers): 1});
    });

    test('황금빛이 도망치면 오늘은 다시 나오지 않는다', () async {
      final now = DateTime(2026, 11, 8, 14);
      final c = AppController(
        area: KoreaArea.area,
        store: InMemoryRecordStore(profile: const PlayerProfile(name: '하루')),
        health: FakeHealthSource(stepsByDay: {'2026-11-08': 3000}),
        location: FakeLocationSource(),
        clock: () => now,
      );
      await c.init();
      final spawn = c.todaySpawns.first;
      final golden = FieldSpawn(
          id: spawn.id,
          monster: spawn.monster,
          point: spawn.point,
          modifiers: const [ModifierId.golden]);
      final b = c.startFieldBattle(golden)!;
      b.phase = BattlePhase.escaped;
      expect(await c.finishFieldBattle(golden, b), 0);
      expect(c.todaySpawns.map((s) => s.id), isNot(contains(spawn.id)));
      expect(c.history.last.fieldMonstersPurified, 0);
    });
  });
}
