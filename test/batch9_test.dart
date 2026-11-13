import 'dart:math';

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/geo/geo.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/location/location_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/battle/battle_view.dart';
import 'package:isekai_reality/features/map/korea_area.dart';

/// 늘 같은 값을 내는 난수
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

Foe _foe(MonsterId m, {int hp = 100000, int attack = 10}) =>
    Foe(monster: m, maxHp: hp, attack: attack);

Battle _battle(MonsterId m,
        {bool telegraphs = true,
        bool heroSkills = false,
        int hp = 100000,
        int attack = 10}) =>
    Battle(
      playerMaxHp: 100000,
      playerAttack: 10,
      floors: [_foe(m, hp: hp, attack: attack)],
      rng: _Fixed(0.5),
      telegraphs: telegraphs,
      heroSkills: heroSkills,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('#75 막기 타이밍', () {
    test('예고 뒤 1.0초 안 = 막기, 끝 0.3초 = 완벽한 막기, 지나면 판정 없음', () {
      expect(Battle.judgeGuard(const Duration(milliseconds: 100)),
          GuardResult.block);
      expect(Battle.judgeGuard(const Duration(milliseconds: 699)),
          GuardResult.block);
      expect(Battle.judgeGuard(const Duration(milliseconds: 700)),
          GuardResult.perfect);
      expect(Battle.judgeGuard(const Duration(milliseconds: 1000)),
          GuardResult.perfect);
      expect(Battle.judgeGuard(const Duration(milliseconds: 1001)), isNull);
    });

    test('모든 몬스터가 4턴마다 힘을 모은다 (예고), 막기는 받는 피해 -60%', () {
      final a = _battle(MonsterId.ashSlime);
      final b = _battle(MonsterId.ashSlime);
      for (var i = 0; i < 3; i++) {
        expect(a.strongNext, isFalse);
        a.tick();
        b.tick();
      }
      expect(a.strongNext, isTrue);
      expect(a.strongLabel, '힘을 모은다!');
      // 예고가 없을 때는 막기가 되지 않는다 (일찍 눌러도 벌 없음)
      expect(_battle(MonsterId.ashSlime).guard(perfect: false), isFalse);
      expect(b.guard(perfect: false), isTrue);
      expect(b.guard(perfect: true), isFalse, reason: '예고 하나에 한 번');
      a.tick();
      b.tick();
      expect(b.lastGuard, GuardResult.block);
      expect(b.lastEvent, '막았다!');
      // 힘을 모은 공격 15 → 막으면 6
      expect(a.lastTaken, 15);
      expect(b.lastTaken, 6);
    });

    test('완벽한 막기: 피해 없음 + 내 보통 공격만큼 반격', () {
      final b = _battle(MonsterId.ashSlime);
      for (var i = 0; i < 3; i++) {
        b.tick();
      }
      final hp = b.foeHp;
      expect(b.guard(perfect: true), isTrue);
      b.tick();
      expect(b.lastGuard, GuardResult.perfect);
      expect(b.lastTaken, 0);
      // 내 공격 10 + 반격 10
      expect(hp - b.foeHp, 20);
    });

    test('원정 자동 전투(예고 없음)는 막기가 없다', () {
      final b = _battle(MonsterId.ashSlime, telegraphs: false);
      for (var i = 0; i < 6; i++) {
        expect(b.strongNext, isFalse);
        b.tick();
      }
    });
  });

  group('#75 내 스킬', () {
    test('강타: 6턴마다 보통 공격 ×2.5', () {
      final b = _battle(MonsterId.ashSlime, heroSkills: true, attack: 1);
      for (var i = 0; i < 5; i++) {
        b.tick();
        expect(b.bashReady, isFalse);
      }
      b.tick();
      expect(b.bashReady, isTrue);
      final hp = b.foeHp;
      expect(b.useBash(), isTrue);
      expect(hp - b.foeHp, 25);
      expect(b.bashReady, isFalse);
    });

    test('방어 태세: 8턴마다, 3턴 동안 받는 피해 -40%', () {
      final b = _battle(MonsterId.ashSlime, heroSkills: true, telegraphs: false);
      for (var i = 0; i < 8; i++) {
        b.tick();
      }
      expect(b.stanceReady, isTrue);
      expect(b.useStance(), isTrue);
      b.tick();
      expect(b.lastTaken, 6);
      b.tick();
      b.tick();
      b.tick();
      expect(b.stanceTurns, 0);
      expect(b.lastTaken, 10);
    });
  });

  group('#75 던전 보스', () {
    test('요일 보스: 월 문지기 … 토 그리폰, 미궁 입구는 늘 문지기', () {
      // 2026-11-09 월요일
      final mon = DateTime(2026, 11, 9);
      final want = [
        MonsterId.labyrinthWarden,
        MonsterId.fireSlimeKing,
        MonsterId.frostWolfKing,
        MonsterId.ancientTreant,
        MonsterId.shadowBatQueen,
        MonsterId.thunderGriffin,
      ];
      for (var i = 0; i < 6; i++) {
        expect(
            BattleRules.bossOf(mon.add(Duration(days: i)), atGate: false), want[i]);
        expect(BattleRules.bossOf(mon.add(Duration(days: i)), atGate: true),
            MonsterId.labyrinthWarden);
      }
      final sun = BattleRules.bossOf(DateTime(2026, 11, 15),
          atGate: false, rng: Random(3));
      expect(BattleRules.weekBosses, contains(sun));
      // 강도는 모두 같다
      final floors = BattleRules.dungeonFloors(
          level: 5, atGate: false, rng: Random(1), day: DateTime(2026, 11, 10));
      final warden = BattleRules.dungeonFloors(
          level: 5, atGate: false, rng: Random(1), day: mon);
      expect(floors.last.monster, MonsterId.fireSlimeKing);
      expect(floors.last.maxHp, warden.last.maxHp);
      expect(floors.last.attack, warden.last.attack);
    });

    test('보스: 3턴마다 큰 공격 예고(×2), 체력 절반 아래 분노', () {
      final b = Battle(
        playerMaxHp: 100000,
        playerAttack: 30,
        floors: [_foe(MonsterId.fireSlimeKing, hp: 100, attack: 10)],
        rng: _Fixed(0.5),
        telegraphs: true,
      );
      b.tick();
      b.tick();
      expect(b.strongNext, isTrue);
      expect(b.strongLabel, '큰 공격이 온다!');
      expect(b.enraged, isTrue, reason: '30+30 = 60 → 절반 아래');
      b.tick();
      // 10 × 2 × 1.3 = 26
      expect(b.lastTaken, 26);
    });

    test('보스 보상: 전용 재료 1개 확정', () {
      final loot = LootRules.dungeon(
          cleared: true, rng: Random(1), boss: MonsterId.frostWolfKing);
      expect(loot[MaterialId.bossFrostFang], 1);
    });
  });

  group('#75 패배의 벌 · A4 첫 중독 안내', () {
    var now = DateTime(2026, 11, 11, 14);
    Future<AppController> start() async {
      now = DateTime(2026, 11, 11, 14);
      final c = AppController(
        area: KoreaArea.area,
        store: InMemoryRecordStore(
          profile: const PlayerProfile(name: '하루'),
          history: [DailyRecord(date: DateTime(2026, 11, 10))],
        ),
        health: FakeHealthSource(stepsByDay: {'2026-11-11': 1000}),
        location: FakeLocationSource(),
        clock: () => now,
        random: Random(2),
        fallbackCenter: const GeoPoint(37.32, 126.83),
      );
      await c.init();
      return c;
    }

    test('지면 지친 상태 1시간 (경험치 -20%), 여관에 들르면 바로 풀린다', () async {
      final c = await start();
      final spawn = c.todaySpawns.firstWhere((s) => s.modifiers.isEmpty);
      final lost = c.startFieldBattle(spawn)!..phase = BattlePhase.failed;
      await c.finishFieldBattle(spawn, lost);
      expect(c.tired, isTrue);
      now = now.add(const Duration(minutes: 59));
      expect(c.tired, isTrue);

      // 지친 채로 잡으면 경험치가 줄고, 기록으로 다시 계산해도 같다
      final other = c.todaySpawns
          .firstWhere((s) => s.modifiers.isEmpty && s.id != spawn.id);
      final b = c.startFieldBattle(other)!..runToEnd();
      final before = c.player.totalExp;
      // 묶음 25 #171: Lv.5까지는 두 배
      final x2 = c.player.level.level <= 5 ? 2 : 1;
      final exp = await c.finishFieldBattle(other, b);
      expect(exp, lessThan(RuleConstants.fieldMonsterExp * x2));
      expect(c.player.totalExp - before, greaterThanOrEqualTo(exp));

      now = now.add(const Duration(minutes: 2));
      expect(c.tired, isFalse, reason: '1시간 뒤 풀림');
      // 다시 지면 시간만 다시 1시간
      await c.finishFieldBattle(spawn, lost);
      expect(c.tired, isTrue);
      await c.restAtInn();
      expect(c.tired, isFalse);
    });

    testWidgets('처음 중독되면 해독제 안내 (있으면 바로 쓰기)', (tester) async {
      final b = Battle(
        playerMaxHp: 1000,
        playerAttack: 1,
        floors: [_foe(MonsterId.poisonSlime)],
        rng: _Fixed(0.01),
        potions: const [
          BattlePotion(
              key: 'alc:antidote',
              name: '해독제',
              count: 1,
              cure: CureKind.poison),
        ],
      );
      var shown = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BattleView(
              battle: b,
              onFinished: () {},
              poisonTip: true,
              onPoisonTipShown: () => shown++,
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 950));
      await tester.pump();
      expect(find.byKey(const Key('poisonTip')), findsOneWidget);
      expect(shown, 1);
      await tester.tap(find.byKey(const Key('poisonTipUse')));
      await tester.pump();
      expect(b.poisonTurns, 0);
      expect(find.byKey(const Key('poisonTip')), findsNothing);
      // 화면을 닫아 타이머를 정리한다
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
