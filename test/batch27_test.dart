import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/geo/geo.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';

void main() {
  final t0 = DateTime(2026, 11, 15, 10);

  Future<AppController> start(InMemoryRecordStore store,
      {DateTime Function()? clock}) async {
    final c = AppController(
      store: store,
      health: FakeHealthSource(stepsByDay: const {}),
      clock: clock ?? () => t0,
    )..mailSources = const [];
    await c.init();
    return c;
  }

  /// 숙련도 저장본이 이미 있는 계정 (예전 기록 시작 값은 건너뜀)
  InMemoryRecordStore withMastery(Map<String, dynamic> mastery,
          {List<DailyRecord> history = const []}) =>
      InMemoryRecordStore(
        profile: const PlayerProfile(name: '하루'),
        history: history,
        json: {'mastery': mastery},
      );

  group('규칙', () {
    test('단계: 큰 0·10·40·120·300, 세부 0·5·20·60·150', () {
      expect(MasteryRules.stageOf(9), MasteryStage.clumsy);
      expect(MasteryRules.stageOf(10), MasteryStage.familiar);
      expect(MasteryRules.stageOf(40), MasteryStage.skilled);
      expect(MasteryRules.stageOf(120), MasteryStage.expert);
      expect(MasteryRules.stageOf(300), MasteryStage.master);
      expect(MasteryRules.stageOf(99999), MasteryStage.master);
      expect(MasteryRules.stageOf(4, detail: true), MasteryStage.clumsy);
      expect(MasteryRules.stageOf(5, detail: true), MasteryStage.familiar);
      expect(MasteryRules.stageOf(150, detail: true), MasteryStage.master);
      expect(MasteryRules.fraction(0), 0);
      expect(MasteryRules.fraction(300), 1);
      expect(MasteryRules.fraction(99999), 1); // 효과 상한
    });

    test('세부 열쇠: 무기 종류 · 방어구 부위 · 채집 종류', () {
      expect(MasteryRules.weaponKind(EquipBase.ironSword), 'sword');
      expect(MasteryRules.weaponKind(EquipBase.frostWeapon), 'sword');
      expect(MasteryRules.weaponKind(EquipBase.woodAxe), 'axe');
      expect(MasteryRules.weaponKind(null), isNull);
      expect(MasteryRules.harvestKind(HarvestKind.flower), 'herb');
      expect(MasteryRules.harvestKind(HarvestKind.mushroom), 'herb');
      expect(MasteryRules.harvestKind(HarvestKind.gem), 'ore');
      expect(MasteryRules.harvestKind(HarvestKind.wood), 'wood');
      expect(MasteryRules.harvestKind(HarvestKind.water), isNull);
      expect(MasteryRules.harvestKind(HarvestKind.relic), isNull);
    });

    test('대사 32줄 · 성향 8줄 · 칭호 16개, 숫자 없음', () {
      final digit = RegExp(r'\d|%');
      var n = 0;
      for (final m in Mastery.values) {
        for (final s in MasteryStage.values.skip(1)) {
          final l = MasteryRules.stageLine(m, s)!;
          expect(digit.hasMatch(l), isFalse, reason: l);
          n++;
        }
        expect(digit.hasMatch(MasteryRules.leanLine(m)), isFalse);
        expect(MasteryRules.titleAt(m, MasteryStage.expert), isNotNull);
        expect(MasteryRules.titleAt(m, MasteryStage.master), isNotNull);
        expect(MasteryRules.titleAt(m, MasteryStage.skilled), isNull);
      }
      expect(n, 32);
      expect(TitleRules.masteryTitles.length, 16);
      expect(MasteryRules.masterLine('weapon:sword'), '이제 검이 손에 꼭 맞아!');
      expect(MasteryRules.masterLine('monster:${MonsterId.ashSlime.name}'),
          contains('눈 감고도 잡겠다'));
    });
  });

  group('쌓기 · 효과는 그 대상에만', () {
    test('세부 효과: 그 몬스터·그 장비 종류에만', () async {
      final c = await start(withMastery({
        'detail': {
          'monster:${MonsterId.ashSlime.name}': 150,
          'smith:sword': 150,
        },
      }));
      expect(c.combatPower(monster: MonsterId.ashSlime), closeTo(1.05, 1e-9));
      expect(c.combatPower(monster: MonsterId.giantRat), 1.0);
      expect(c.smithGradeBonus(EquipBase.ironSword), 10);
      expect(c.smithGradeBonus(EquipBase.woodAxe), 0);
    });

    test('큰 숙련도 효과: 정령술·장사', () async {
      final c = await start(withMastery({
        'big': {'spirit': 300, 'trade': 300},
      }));
      expect(c.spiritMpFactor, closeTo(0.9, 1e-9));
      expect(c.spiritTimeFactor, closeTo(0.9, 1e-9));
      expect(c.tradeGold(100), 105);
      expect(c.errandGold(100), 105);
      final plain = await start(withMastery({}));
      expect(plain.spiritMpFactor, 1);
      expect(plain.tradeGold(100), 100);
    });

    test('직접 사냥으로 이기면 전투 + 그 몬스터 세부, 줄지 않음', () async {
      final c = await start(InMemoryRecordStore(
          profile: const PlayerProfile(name: '하루')));
      await c.handleFix(const LocationFix(point: GeoPoint(37.3219, 126.8309)));
      final before = c.masteryOf(Mastery.combat);
      FieldSpawn? won;
      for (final s in c.todaySpawns.take(4)) {
        final b = c.startFieldBattle(s);
        if (b == null) continue;
        b.runToEnd(useSkills: true);
        await c.finishFieldBattle(s, b);
        if (c.player.today!.purifiedSpawnIds.contains(s.id)) {
          won = s;
          break;
        }
      }
      expect(won, isNotNull);
      expect(c.masteryOf(Mastery.combat), before + 1);
      expect(c.masteryDetail(MasteryRules.monsterKey(won!.monster)),
          greaterThanOrEqualTo(1));
      // 다시 켜도 그대로
      final again = await start(InMemoryRecordStore(
          profile: const PlayerProfile(name: '하루'),
          json: {'mastery': c.masteryState.toJson()}));
      expect(again.masteryOf(Mastery.combat), c.masteryOf(Mastery.combat));
    });

    test('걷기·탐험은 기록에서: 1,000보마다 1 (묶음 81: 장소는 세지 않음)', () {
      final v = MasteryRules.walkFrom([
        DailyRecord(
            date: DateTime(2026, 11, 13),
            steps: 12500,
            newPlacesVisited: 2,
            placesRevisited: 3),
      ]);
      expect(v, 12);
    });
  });

  group('알려 주기', () {
    test('단계 대사는 한 번만, 숙련된에서 칭호', () async {
      final c = await start(withMastery({
        'big': {'smith': 9},
        'announced': {'smith': 0},
      }));
      await c.gainMastery(Mastery.smith, 1);
      expect(c.masteryTalk,
          MasteryRules.stageLine(Mastery.smith, MasteryStage.familiar));
      await c.gainMastery(Mastery.smith, 1);
      expect(c.masteryState.pending, isEmpty);
      // 숙련된 → 칭호
      await c.gainMastery(Mastery.smith, 110);
      expect(c.player.titles, contains(TitleId.smithAdept));
      expect(c.titleIsQuiet(TitleId.smithAdept), isFalse);
      expect(c.masteryState.pending,
          contains(MasteryRules.stageLine(Mastery.smith, MasteryStage.expert)));
    });

    test('세부가 장인이 되면 한마디', () async {
      final c = await start(withMastery({
        'detail': {'weapon:sword': 149},
      }));
      await c.gainMastery(Mastery.combat, 1, details: ['weapon:sword']);
      expect(c.masteryState.pending, contains('이제 검이 손에 꼭 맞아!'));
      await c.gainMastery(Mastery.combat, 1, details: ['weapon:sword']);
      expect(
          c.masteryState.pending.where((l) => l == '이제 검이 손에 꼭 맞아!').length,
          1);
    });

    test('성향 대사: 일주일에 한 번쯤', () async {
      var now = t0;
      final c = await start(
          withMastery({
            'big': {'harvest': 50},
            'announced': {'harvest': 2},
            'top': 'harvest',
            'leanAt': t0.subtract(const Duration(days: 2)).toIso8601String(),
          }),
          clock: () => now);
      expect(c.masteryTalk, isNull);
      now = t0.add(const Duration(days: 6));
      expect(c.masteryTalk, MasteryRules.leanLine(Mastery.harvest));
      // 10분 동안은 같은 줄, 그 뒤 다음 주까지 없음
      now = now.add(const Duration(minutes: 11));
      expect(c.masteryTalk, isNull);
    });
  });

  group('예전 기록', () {
    test('지금까지 한 횟수로 시작 값, 대사는 몰아 띄우지 않고 칭호는 조용히', () async {
      final c = await start(InMemoryRecordStore(
        profile: const PlayerProfile(name: '하루'),
        history: [
          DailyRecord(
            date: DateTime(2026, 11, 10),
            dungeonRuns: List.filled(40, const DungeonRun(cleared: true)),
            huntCounts: {MonsterId.ashSlime.name: 20},
            counters: const {'expeditionWin': 6, 'expedition': 8, 'errandDone': 3},
          ),
        ],
      ));
      expect(c.masteryOf(Mastery.combat), 20 + 40 * 3);
      expect(c.masteryDetail(MasteryRules.monsterKey(MonsterId.ashSlime)), 20);
      expect(c.masteryOf(Mastery.spirit), 6 + 2 * 0.5);
      expect(c.masteryOf(Mastery.trade), 6);
      expect(c.masteryState.pending, isEmpty);
      expect(c.masteryStage(Mastery.combat), MasteryStage.expert);
      expect(c.player.titles, contains(TitleId.combatAdept));
      expect(c.titleIsQuiet(TitleId.combatAdept), isTrue);
      expect(c.masteryTalk, isNull);
    });

    test('강화 성공률은 숙련도와 상관없이 그대로', () {
      for (var to = 1; to <= EquipmentRules.maxEnhance; to++) {
        expect(EquipmentRules.enhanceChance(to), inInclusiveRange(0.0, 1.0));
      }
      // 등급 확률: 숙련도 보너스는 파랑에만
      final base = EquipmentRules.gradeChances(rare: false, bonus: 0);
      final best = EquipmentRules.gradeChances(rare: false, bonus: 10);
      expect(best[2] - base[2], 10);
      expect(best[0] - base[0], -10);
    });
  });
}
