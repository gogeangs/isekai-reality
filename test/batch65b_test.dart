// 묶음 65 (2/2): #252 많이 걸은 날 · #254 높은 레벨 경험치 · #255 영지 관리

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/models/player_state.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/features/status/step_chest_row.dart';

import 'support/npc_seed.dart';

final _d20 = DateTime(2026, 11, 20);

Future<AppController> walker(Map<String, int> steps, {int level = 12, List<DailyRecord> more = const [], DateTime? at}) =>
    startNpc(level: level, todaySteps: steps, more: more, clock: () => at ?? DateTime(2026, 11, 20, 20));

void main() {
  group('#252 많이 걸은 날', () {
    test('발자국 · 조각: 1만 보를 넘긴 2,500보마다, 2만 보까지 · 예전 기록엔 없음', () {
      expect(WalkRewardRules.steps2500(9999, _d20), 0);
      expect(WalkRewardRules.steps2500(12499, _d20), 0);
      expect(WalkRewardRules.steps2500(12500, _d20), 1);
      expect(WalkRewardRules.steps2500(15000, _d20), 2);
      expect(WalkRewardRules.steps2500(30000, _d20), 4);
      expect(WalkRewardRules.steps2500(30000, DateTime(2026, 11, 18)), 0, reason: '예전 기록 그대로');
      final r = DailyRecord(date: _d20, steps: 15000);
      expect(ExpRules.forDay(r).footprint, 2 * WalkRewardRules.footprintExp);
      expect(WalkRewardRules.chestsOn(15000, _d20), [0, 1]);
      expect(WalkRewardRules.chestsOn(11999, _d20), isEmpty);
    });

    test('열쇠 조각: 두 개 = 열쇠, 넘어가는 열쇠가 차 있으면 조각으로 보관', () {
      // 1만5천 보 → 열쇠 4 + 조각 2. 열쇠가 4개 있으니 조각은 보관
      var g = DungeonGaugeRules.today(steps: 15000, shardsToday: 2);
      expect(g.keysAvailable, 4);
      expect(g.shards, 2);
      expect(g.shardKeysToday, 0);
      // 열쇠를 두 개 쓰면 (남은 2 < 3) 조각이 맞물려 열쇠 하나
      g = DungeonGaugeRules.today(steps: 15000, shardsToday: 2, keysUsedToday: 2);
      expect(g.keysAvailable, 3);
      expect(g.shards, 0);
      expect(g.shardKeysToday, 1);
      // 날이 지나도 조각은 남는다
      DailyRecord day(int d, int steps, int runs) => DailyRecord(
          date: DateTime(2026, 11, d), steps: steps, dungeonRuns: [for (var i = 0; i < runs; i++) const DungeonRun(cleared: true)]);
      final h = [day(19, 12500, 4), day(22, 3000, 0)];
      final p = PlayerState.fromHistory(name: 'x', history: h);
      expect(p.gauge.shards, 1, reason: '19일 조각 1개는 사흘 뒤에도 그대로');
    });

    test('#254 Lv.21부터 배율 (그날 시작할 때 레벨) · 예전 날은 그대로', () {
      expect(WalkRewardRules.levelMult(20), 1);
      expect(WalkRewardRules.levelMult(21), 1);
      expect(WalkRewardRules.levelMult(40), closeTo(1.57, 1e-9));
      final base = LevelRules.totalExpToReach(40);
      DailyRecord d(DateTime t) => DailyRecord(date: t, fieldMonstersPurified: 5, questsCompleted: 3);
      final before = PlayerState.fromHistory(name: 'x', history: [
        DailyRecord(date: DateTime(2026, 11, 10), gains: {Wallet.exp: base}),
        d(DateTime(2026, 11, 18)),
      ]);
      final after = PlayerState.fromHistory(name: 'x', history: [
        DailyRecord(date: DateTime(2026, 11, 10), gains: {Wallet.exp: base}),
        d(DateTime(2026, 11, 20)),
      ]);
      final plain = before.dailyExp.last.total;
      expect(after.dailyExp.last.total, closeTo(plain * 1.57, 6));
      // 7천 보 하루(약 400) 기준 레벨 하나에 약 2일
      final days = LevelRules.expRequiredFor(40) / (400 * WalkRewardRules.levelMult(40));
      expect(days, inInclusiveRange(1.6, 2.4));
    });

    testWidgets('걸음 상자: 홈에 도착 · 열면 사라짐 · 다음 날도 남음', (tester) async {
      late AppController c;
      await tester.runAsync(() async => c = await walker({'2026-11-20': 15200}));
      expect(c.stepChests.map((x) => x.$2), [0, 1]);
      expect(c.player.gauge.shardInto, 200);
      expect(c.player.dailyExp.last.footprint, greaterThan(0));
      expect(c.walkTalk, isNotNull);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: StepChestRow(controller: c))));
      expect(find.text('걸음 상자가 도착했어요 · 2개'), findsOneWidget);
      late ({List<String> got, int best})? r;
      await tester.runAsync(() async => r = await c.openStepChests());
      expect(r!.best, 1);
      expect(r!.got.first, '금화', reason: '숫자는 숨김');
      expect(c.stepChests, isEmpty);
      await tester.pump();
      expect(find.byKey(const Key('stepChestRow')), findsNothing);
    });

    test('안 연 상자는 다음 날도 남고, 그다음 날엔 사라짐', () async {
      final y = [DailyRecord(date: DateTime(2026, 11, 20), steps: 12100)];
      final c = await walker({'2026-11-20': 12100, '2026-11-21': 300}, more: y, at: DateTime(2026, 11, 21, 9));
      expect(c.stepChests.map((x) => (x.$1.day, x.$2)), [(20, 0)]);
      final c2 = await walker({'2026-11-20': 12100, '2026-11-22': 300}, more: y, at: DateTime(2026, 11, 22, 9));
      expect(c2.stepChests, isEmpty);
    });
  });
}
