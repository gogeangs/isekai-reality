import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';

void main() {
  test('포인트를 나누고, 되돌리면 처음은 무료 다음은 금화', () async {
    final store = InMemoryRecordStore(
      profile: const PlayerProfile(name: '하루'),
      history: [
        DailyRecord(
          date: DateTime(2026, 11, 10),
          dungeonRuns: List.filled(4, const DungeonRun(cleared: true)),
          gains: const {Wallet.gold: 500, Wallet.exp: 2000},
        ),
      ],
    );
    final c = AppController(
      store: store,
      health: FakeHealthSource(),
      clock: () => DateTime(2026, 11, 11, 10),
    );
    await c.init();
    final level = c.player.level.level;
    expect(level, greaterThan(3));
    expect(c.unspentPoints, StatRules.pointsFor(level));
    // 나누기 전에도 전투에서는 고르게 나눈 것처럼
    expect(c.combatStats.total, c.shownStats.total + c.unspentPoints);

    expect(await c.allocateStats(const Stats(strength: 5)), isTrue);
    expect(c.allocatedStats.strength, 5);
    expect(c.shownStats.strength, 15);
    expect(c.unspentPoints, StatRules.pointsFor(level) - 5);
    expect(await c.allocateStats(Stats(luck: c.unspentPoints + 1)), isFalse);

    expect(c.statResetCost, 0);
    expect(await c.resetStats(), isTrue);
    expect(c.allocatedStats, Stats.zero);
    expect(c.statResetCost, 100);
    await c.allocateStats(const Stats(vitality: 2));
    final gold = c.player.gold;
    expect(await c.resetStats(), isTrue);
    expect(c.player.gold, gold - 100);
  });

  test('처음 열 때는 지금 생활 보너스까지 이미 알려 준 것으로 친다', () async {
    final store = InMemoryRecordStore(
      profile: const PlayerProfile(name: '하루'),
      history: [
        for (var i = 0; i < 30; i++)
          DailyRecord(date: DateTime(2026, 10, 12).add(Duration(days: i)), steps: 11000),
      ],
    );
    final c = AppController(
        store: store, health: FakeHealthSource(), clock: () => DateTime(2026, 11, 11, 10));
    await c.init();
    expect(c.lifeBonusLine, isNull);
  });
}
