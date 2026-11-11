import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/geo/geo.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/location/location_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/battle/dungeon_screen.dart';
import 'package:isekai_reality/features/map/ansan_area.dart';
import 'package:isekai_reality/features/map/korea_area.dart';

const area = AnsanArea.area;
const jungang = GeoPoint(37.31596, 126.83864);

Battle dungeonFor(int level, Stats stats, {int seed = 1, bool atGate = false}) {
  final rng = Random(seed);
  return Battle.forPlayer(
    level: level,
    stats: stats,
    floors: BattleRules.dungeonFloors(level: level, atGate: atGate, rng: rng),
    rng: rng,
  );
}

final weak = Stats.all(10);

void main() {
  group('던전 구성', () {
    test('일반 3층 + 마지막 보스 미궁 문지기', () {
      final floors =
          BattleRules.dungeonFloors(level: 5, atGate: false, rng: Random(3));
      expect(floors, hasLength(4));
      expect(floors.last.monster, MonsterId.labyrinthWarden);
      expect(floors.take(3).every((f) => !f.isBoss), isTrue);
    });

    test('미궁 입구에서 열면 일반 층은 모두 미궁 박쥐', () {
      final floors =
          BattleRules.dungeonFloors(level: 5, atGate: true, rng: Random(3));
      expect(floors.take(3).map((f) => f.monster).toSet(),
          {MonsterId.labyrinthBat});
    });
  });

  group('밸런스', () {
    test('보통으로 생활한 사람은 스킬 없이도 대부분 클리어한다', () {
      for (final level in [1, 5, 10, 15, 20]) {
        var wins = 0;
        for (var seed = 0; seed < 20; seed++) {
          final b = dungeonFor(level, BattleRules.expectedStats(level),
                  seed: seed)
              .runToEnd();
          if (b.phase == BattlePhase.cleared) wins++;
        }
        expect(wins, greaterThanOrEqualTo(18), reason: 'Lv.$level');
      }
    });

    test('층마다 10~15번 공격, 보스까지 1분 안팎', () {
      final b =
          dungeonFor(10, BattleRules.expectedStats(10)).runToEnd();
      expect(b.ticks, inInclusiveRange(40, 75));
    });

    test('스킬을 쓰면 더 빨리 끝나고 체력이 더 남는다', () {
      final stats = BattleRules.expectedStats(10);
      final plain = dungeonFor(10, stats, seed: 7).runToEnd();
      final skilled = dungeonFor(10, stats, seed: 7).runToEnd(useSkills: true);
      expect(skilled.phase, BattlePhase.cleared);
      expect(skilled.ticks, lessThan(plain.ticks));
      expect(skilled.playerHp, greaterThan(plain.playerHp));
    });

    test('같은 레벨보다 약하면 스킬이 승패를 가른다', () {
      var plainWins = 0;
      var skillWins = 0;
      // 포인트를 거의 쓰지 않은 Lv.18 (모든 스탯 10)
      final low = weak;
      for (var seed = 0; seed < 20; seed++) {
        if (dungeonFor(18, low, seed: seed).runToEnd().phase ==
            BattlePhase.cleared) {
          plainWins++;
        }
        if (dungeonFor(18, low, seed: seed).runToEnd(useSkills: true).phase ==
            BattlePhase.cleared) {
          skillWins++;
        }
      }
      expect(plainWins, lessThan(20));
      expect(skillWins, greaterThanOrEqualTo(plainWins));
    });

    test('필드 몬스터는 짧고 거의 지지 않는다', () {
      final b = Battle.forPlayer(
        level: 3,
        stats: weak,
        floors: [BattleRules.fieldFoe(level: 3, monster: MonsterId.ashSlime)],
        rng: Random(1),
      ).runToEnd();
      expect(b.phase, BattlePhase.cleared);
      expect(b.ticks, lessThanOrEqualTo(9));
      expect(b.purified, [MonsterId.ashSlime]);
    });
  });

  group('전투 진행', () {
    test('스킬은 충전되어야만 쓸 수 있다', () {
      final b = dungeonFor(5, BattleRules.expectedStats(5));
      expect(b.useSkill(), isFalse);
      for (var i = 0; i < RuleConstants.skillChargeTicks; i++) {
        b.tick();
      }
      expect(b.skillReady, isTrue);
      expect(b.useSkill(), isTrue);
      expect(b.skillReady, isFalse);
    });

    test('층을 정화하면 다음 틱에 다음 층으로 가고, 체력은 이어진다', () {
      final b = dungeonFor(5, BattleRules.expectedStats(5));
      while (b.phase != BattlePhase.floorCleared) {
        b.tick();
      }
      final hp = b.playerHp;
      expect(b.purified, hasLength(1));
      b.tick();
      expect(b.floor, 1);
      expect(b.phase, BattlePhase.fighting);
      expect(b.playerHp, hp);
    });
  });

  group('필드 몬스터 자리', () {
    final day = DateTime(2026, 11, 8);

    test('시내 500m 블록마다 한 마리꼴, 같은 날에는 같은 자리 (11-11 #80)', () {
      final a = FieldMonsterRules.spawnsFor(area, day);
      final b = FieldMonsterRules.spawnsFor(area, day);
      // 장소마다 1 + 블록(약 0.25km²)의 70%: 1km 블록 때의 약 4배
      expect(a.length, greaterThan(area.places.length + 200));
      expect(a.length, lessThan(area.places.length + 1000));
      expect(a.map((s) => s.id), b.map((s) => s.id));
      expect(a.first.point.lat, b.first.point.lat);
      final other = FieldMonsterRules.spawnsFor(area, DateTime(2026, 11, 9));
      expect(other.first.point.lat, isNot(a.first.point.lat));
    });

    test('지역 안, 제외 구역 밖에만 나온다 (30일 확인)', () {
      for (var i = 0; i < 30; i++) {
        for (final s in FieldMonsterRules.spawnsFor(
            area, day.add(Duration(days: i)))) {
          expect(area.bounds.contains(s.point), isTrue);
          expect(area.isExcluded(s.point), isFalse);
        }
      }
    });

    test('길 격자가 있으면 큰길·철로 둘레에는 나오지 않는다', () {
      // 서쪽 절반을 모두 길로 칠한 격자
      const rows = 110, cols = 185;
      final bits = List<int>.filled((rows * cols + 7) ~/ 8, 0);
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols ~/ 2; c++) {
          final i = r * cols + c;
          bits[i >> 3] |= 1 << (i & 7);
        }
      }
      final mask = RoadMask(
          south: area.bounds.south,
          west: area.bounds.west,
          latStep: 0.001,
          lngStep: 0.001,
          rows: rows,
          cols: cols,
          bits: bits);
      expect(mask.isRoad(const GeoPoint(37.30, 126.75)), isTrue);
      expect(mask.isRoad(const GeoPoint(37.30, 126.90)), isFalse);
      expect(mask.isRoad(const GeoPoint(36.0, 126.75)), isFalse); // 격자 밖

      final all = FieldMonsterRules.spawnsFor(area, day);
      final safe = FieldMonsterRules.spawnsFor(area, day, roads: mask);
      expect(safe, isNotEmpty);
      expect(safe.length, lessThan(all.length));
      for (final sp in safe) {
        expect(mask.isRoad(sp.point), isFalse);
      }
    });

    test('전국: 내 둘레 3km 블록에만, 어디서 봐도 같은 블록엔 같은 몬스터', () {
      const busan = GeoPoint(35.1580, 129.1600);
      final a = FieldMonsterRules.spawnsFor(KoreaArea.area, day, center: busan);
      // 3km 둘레 500m 블록 약 113칸 × 70% (11-11 #80)
      expect(a.length, greaterThan(50));
      expect(a.length, lessThan(120));
      for (final s in a) {
        expect(s.point.distanceTo(busan), lessThan(3000 + 1500));
      }
      // 1km 옆에서 봐도 겹치는 블록의 몬스터는 같다
      const near = GeoPoint(35.1580, 129.1710);
      final b = FieldMonsterRules.spawnsFor(KoreaArea.area, day, center: near);
      final shared = a.map((s) => s.id).toSet().intersection(
          b.map((s) => s.id).toSet());
      expect(shared, isNotEmpty);
      for (final id in shared) {
        expect(a.firstWhere((s) => s.id == id).point.lat,
            b.firstWhere((s) => s.id == id).point.lat);
      }
    });

    test('전국 제외 구역(학교·병원 둘레)에는 두지 않고 만나지 않는다', () {
      const center = GeoPoint(35.1580, 129.1600);
      final all = FieldMonsterRules.spawnsFor(KoreaArea.area, day, center: center);
      final target = all.first.point;
      final idx = ExclusionIndex([(target.lat, target.lng, 150)]);
      expect(idx.contains(target), isTrue);
      expect(idx.contains(GeoPoint(target.lat + 0.01, target.lng)), isFalse);
      final safe = FieldMonsterRules.spawnsFor(KoreaArea.area, day,
          center: center, exclusions: idx);
      for (final s in safe) {
        expect(idx.contains(s.point), isFalse);
      }
      expect(
          FieldMonsterRules.encounter(
              area: KoreaArea.area,
              spawns: all,
              fix: LocationFix(point: target, speedMps: 1),
              exclusions: idx),
          isNull);
    });

    test('장소 근처에는 그 장소의 몬스터가 나온다', () {
      final spawns = FieldMonsterRules.spawnsFor(area, day);
      final kinds = spawns.map((s) => s.monster).toSet();
      expect(kinds, contains(MonsterId.labyrinthBat));
      expect(kinds, contains(MonsterId.ashSlime));
      expect(kinds, isNot(contains(MonsterId.roughWaterSpirit)));
      expect(kinds, isNot(contains(MonsterId.lostStoneSpirit)));
    });

    test('밤에는 블록 몬스터 일부가 그림자 나비가 된다', () {
      int butterflies(DateTime t) => FieldMonsterRules.spawnsFor(area, t)
          .where((s) => s.monster == MonsterId.shadowButterfly)
          .length;
      expect(butterflies(DateTime(2026, 11, 8, 14)), 0);
      expect(butterflies(DateTime(2026, 11, 8, 21)), greaterThan(5));
      expect(butterflies(DateTime(2026, 11, 9, 3)), greaterThan(5));
      // 자리는 낮과 같다
      expect(
          FieldMonsterRules.spawnsFor(area, DateTime(2026, 11, 8, 21))
              .map((s) => s.id),
          FieldMonsterRules.spawnsFor(area, DateTime(2026, 11, 8, 14))
              .map((s) => s.id));
    });

    test('40m 안에서 걸어가면 만나고, 차로 지나가면 만나지 않는다', () {
      final spawn = FieldMonsterRules.spawnsFor(area, day).first;
      expect(
          FieldMonsterRules.encounter(
              area: area,
              spawns: [spawn],
              fix: LocationFix(point: spawn.point, speedMps: 1.2))?.id,
          spawn.id);
      expect(
          FieldMonsterRules.encounter(
              area: area,
              spawns: [spawn],
              fix: LocationFix(point: spawn.point, speedMps: 12)),
          isNull);
      expect(
          FieldMonsterRules.encounter(
              area: area,
              spawns: [spawn],
              fix: const LocationFix(point: GeoPoint(37.30, 126.84))),
          isNull);
    });
  });

  group('기록', () {
    final now = DateTime(2026, 11, 8, 14);

    Future<AppController> start(
        {int steps = 6000, InMemoryRecordStore? store, ExploreArea? area}) async {
      final c = AppController(
        area: area ?? KoreaArea.area,
        // 목표 8,000보: 보너스 열쇠 없이 걸음 열쇠만 센다
        store: store ??
            InMemoryRecordStore(
                profile: const PlayerProfile(name: '하루', stepGoal: 8000)),
        health: FakeHealthSource(stepsByDay: {'2026-11-08': steps}),
        location: FakeLocationSource(),
        stepGoal: 8000,
        clock: () => now,
        random: Random(1),
      );
      await c.init();
      return c;
    }

    test('던전을 마치면 열쇠를 쓰고 경험치와 도감이 기록된다', () async {
      final c = await start();
      expect(c.player.gauge.keysAvailable, 2);
      final expBefore = c.player.totalExp;

      final battle = c.startDungeon()!..runToEnd(useSkills: true);
      final exp = await c.finishDungeon(battle, atGate: false);

      expect(exp, RuleConstants.dungeonClearExp);
      expect(c.player.gauge.keysAvailable, 1);
      // 일일 퀘스트 '던전 1번 열기'도 끝난다 (11-10)
      expect(c.player.totalExp - expBefore,
          RuleConstants.dungeonClearExp + RuleConstants.questExp);
      // 11-11 #75: 요일 보스 (11-08 일요일은 6종 중 무작위)
      final boss = battle.floors.last.monster;
      expect(BattleRules.weekBosses, contains(boss));
      expect(c.purifiedEver, contains(boss));
      expect(c.player.materialCount(LootRules.bossMaterial(boss)), 1);
      // 마석 3개, 박쥐 날개 2 + 문지기의 돌조각 1 (11-10)
      expect(c.lastReward.manaStones, 3);
      expect(c.player.materialCount(MaterialId.batWing), 2);
      expect(c.player.materialCount(MaterialId.wardenShard), 1);
    });

    test('미궁 입구에서는 보너스, 열쇠가 없으면 열 수 없다', () async {
      // 장소는 11-10 전국 확대 때 뺐지만, 장소가 있는 지역에서는 그대로 동작한다
      final c = await start(steps: 2600, area: AnsanArea.area);
      await c.handleFix(const LocationFix(point: jungang, speedMps: 0.5));
      expect(c.atGate, isTrue);
      final b = c.startDungeon()!..runToEnd(useSkills: true);
      expect(await c.finishDungeon(b, atGate: c.atGate), 75);
      expect(c.startDungeon(), isNull);
    });

    test('차량 속도로 움직이는 중에는 전투를 시작하지 않는다', () async {
      final c = await start();
      await c.handleFix(const LocationFix(point: jungang, speedMps: 14));
      expect(c.canFightNow, isFalse);
      expect(c.startDungeon(), isNull);
    });

    test('필드 몬스터를 정화하면 경험치, 다시 나오지 않음', () async {
      final c = await start();
      // 수식어 몬스터는 재료를 더 준다 → 보통 몬스터로
      final spawn = c.todaySpawns.firstWhere((s) => s.modifiers.isEmpty);
      await c.handleFix(LocationFix(point: spawn.point, speedMps: 1));
      expect(c.nearbySpawn?.id, spawn.id);

      final b = c.startFieldBattle(spawn)!..runToEnd();
      final stones = c.player.manaStones;
      expect(await c.finishFieldBattle(spawn, b), RuleConstants.fieldMonsterExp);
      expect(c.history.last.fieldMonstersPurified, 1);
      // 마석 1개와 그 몬스터 재료 1개 (11-10)
      expect(c.player.manaStones, stones + 1);
      final common = LootRules.dropsOf(spawn.monster).common;
      expect(common.map(c.player.materialCount).fold<int>(0, (a, b) => a + b), 1);
      expect(common.any((m) => c.lastReward.materials[m] == 1), isTrue);
      expect(c.todaySpawns.map((s) => s.id), isNot(contains(spawn.id)));
      // 같은 자리를 두 번 기록하지 않는다
      expect(await c.finishFieldBattle(spawn, b), 0);
    });

    test('하루 5마리를 정화해도 몬스터는 계속 나온다 (11-11 #69)', () async {
      final store = InMemoryRecordStore(
        profile: const PlayerProfile(name: '하루'),
        history: [
          DailyRecord(date: DateTime(2026, 11, 8), fieldMonstersPurified: 5),
        ],
      );
      final c = await start(store: store);
      expect(c.todaySpawns, isNotEmpty);
    });
  });

  testWidgets('던전 화면: 입장 → 전투 → 결과', (tester) async {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final c = AppController(
      store: InMemoryRecordStore(
          profile: const PlayerProfile(name: '하루', stepGoal: 8000)),
      health: FakeHealthSource(stepsByDay: {'2026-11-08': 6000}),
      stepGoal: 8000,
      clock: () => DateTime(2026, 11, 8, 14),
      random: Random(2),
    );
    await c.init();

    await tester.pumpWidget(MaterialApp(
      home: DungeonScreen(
          controller: c, tickInterval: const Duration(milliseconds: 100)),
    ));
    expect(find.text('열쇠 2개'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('던전 열기 · 열쇠 1개'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('던전 열기 · 열쇠 1개'));
    await tester.pump();
    expect(find.text('1층 / 3층'), findsOneWidget);

    for (var i = 0;
        i < 200 && find.text('던전 돌파!').evaluate().isEmpty;
        i++) {
      if (find.text('불씨의 일격!').evaluate().isNotEmpty) {
        await tester.tap(find.text('불씨의 일격!'));
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();

    expect(find.text('던전 돌파!'), findsOneWidget);
    expect(find.text('경험치 +50'), findsOneWidget);
    expect(c.history.last.dungeonRuns, hasLength(1));
  });
}
