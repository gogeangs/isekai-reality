import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/board_state.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/models/player_state.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';

DailyRecord _day(int d, {int steps = 0, int clears = 0, int field = 0}) =>
    DailyRecord(
      date: DateTime(2026, 11, d),
      steps: steps,
      stepGoal: 99999, // 일일 퀘스트와 섞이지 않게
      dungeonRuns: List.filled(clears, const DungeonRun(cleared: true)),
      fieldMonstersPurified: field,
    );

void main() {
  group('주간 의뢰', () {
    test('월요일부터 쌓아서, 마친 날에 경험치 60 · 금화 80', () {
      // 11-09 월 ~ 11-15 일
      final h = [
        _day(9, steps: 12000, clears: 2, field: 5),
        _day(10, steps: 9000, clears: 3, field: 5),
        _day(11, field: 5),
      ];
      expect(BoardRules.weeklyCompletedOn(h, 0), 0);
      expect(BoardRules.weeklyCompletedOn(h, 1), 2); // 2만 보, 던전 5번
      expect(BoardRules.weeklyCompletedOn(h, 2), 1); // 필드 15마리
      final p = PlayerState.fromHistory(name: '하루', history: h);
      expect(p.dailyExp[1].weekly, 120);
      expect(p.dailyExp[2].weekly, 60);
      expect(p.gold, 80 * 3);
    });

    test('다음 월요일에 새로 시작하고, 11-09 이전 주에는 없다', () {
      final h = [
        _day(2, steps: 30000, clears: 5, field: 15),
        _day(9, steps: 1000),
        _day(16, steps: 25000),
      ];
      expect(BoardRules.weeklyCompletedOn(h, 0), 0);
      expect(BoardRules.weeklyCompletedOn(h, 1), 0);
      expect(BoardRules.weeklyCompletedOn(h, 2), 1);
      expect(BoardRules.thisWeek(h).first.current, 25000);
    });
  });

  group('수시 의뢰', () {
    test('처음엔 두 칸에 서로 다른 의뢰, 수락한 뒤로 센다', () {
      final now = DateTime(2026, 11, 10, 9);
      final b = BoardRules.refresh(const BoardState(), now);
      expect(b.slots, hasLength(2));
      expect(b.slots[0].templateId, isNot(b.slots[1].templateId));
      expect(b.slots.every((s) => !s.accepted), isTrue);

      final rat = BoardRules.template('rat3')!;
      final today = DailyRecord(
          date: DateTime(2026, 11, 10), huntCounts: const {'giantRat': 4});
      expect(BoardRules.progress(rat, today, 2), 2);
      expect(BoardRules.progress(rat, today, 0), 3); // 목표에서 멈춤
    });

    test('하루 4개까지만 올라온다', () {
      final now = DateTime(2026, 11, 10, 9);
      final b = BoardRules.refresh(
          BoardState(
              day: '2026-11-10',
              doneToday: 3,
              seq: 5,
              slots: const [ErrandSlot(templateId: 'rat3'), ErrandSlot()]),
          now);
      expect(b.slots[1].empty, isTrue);
    });

    test('끝내면 금화와 재료, 2시간 뒤 새 의뢰', () async {
      var now = DateTime(2026, 11, 10, 9);
      final store = InMemoryRecordStore(
          profile: const PlayerProfile(name: '하루'));
      await store.saveJson('board', BoardState(day: '2026-11-10', seq: 2, slots: const [
        ErrandSlot(templateId: 'steps3000', accepted: true, baseline: 1000),
        ErrandSlot(templateId: 'rat3'),
      ]).toJson());
      final c = AppController(
        store: store,
        health: FakeHealthSource(stepsByDay: {'2026-11-10': 4500}),
        clock: () => now,
      );
      await c.init();
      expect(c.errandProgress(0), 3000);
      final gold = c.player.gold;
      expect(await c.claimErrand(0), isTrue);
      expect(c.player.gold, gold + 60);
      expect(c.board.slots[0].empty, isTrue);
      expect(c.board.doneToday, 1);
      expect(await c.claimErrand(0), isFalse);

      now = DateTime(2026, 11, 10, 11, 1);
      expect(c.board.slots[0].empty, isFalse);

      // 수락하면 지금부터 센다
      await c.acceptErrand(1);
      expect(c.board.slots[1].accepted, isTrue);
      expect(c.errandProgress(1), 0);

      // 포기하면 보상 없이 2시간 뒤
      await c.abandonErrand(1);
      expect(c.board.slots[1].empty, isTrue);
      expect(c.board.doneToday, 1);

      // 다음 날에는 처음부터
      now = DateTime(2026, 11, 11, 8);
      expect(c.board.doneToday, 0);
      expect(c.board.slots.every((s) => !s.empty), isTrue);
    });
  });

  group('긴급 의뢰', () {
    test('넷 중 하나꼴로, 오전 9시~오후 6시에 뜬다', () {
      var days = 0;
      for (var i = 0; i < 400; i++) {
        final d = DateTime(2026, 1, 1).add(Duration(days: i));
        final u = BoardRules.urgentFor(d);
        if (u == null) continue;
        days++;
        expect(u.appearsAt.hour, inInclusiveRange(9, 17));
      }
      expect(days / 400, closeTo(0.25, 0.06));
    });

    test('수락하고 끝내면 보상 (열쇠 또는 귀한 재료) + 금화 100', () async {
      // 던전 2번 클리어 긴급 의뢰가 뜨는 날을 찾는다
      DateTime? day;
      for (var i = 0; i < 400 && day == null; i++) {
        final d = DateTime(2026, 11, 10).add(Duration(days: i));
        if (BoardRules.urgentFor(d)?.quest.id == 'dungeon2') day = d;
      }
      final u = BoardRules.urgentFor(day!)!;
      final now = DateTime(day.year, day.month, day.day, 23);
      final store = InMemoryRecordStore(
          profile: const PlayerProfile(name: '하루'));
      final c = AppController(
          store: store, health: FakeHealthSource(), clock: () => now);
      await c.init();
      expect(c.urgent?.quest.id, 'dungeon2');
      await c.acceptUrgent();
      await store.upsert(c.history.last.copyWith(dungeonRuns: const [
        DungeonRun(cleared: true),
        DungeonRun(cleared: true),
      ]));
      await c.sync();
      expect(c.urgentProgress, 2);
      final gold = c.player.gold;
      final keys = c.player.gauge.keysAvailable;
      expect(await c.claimUrgent(), isTrue);
      expect(c.player.gold, gold + 100);
      if (u.prize == UrgentPrize.key) {
        expect(c.player.gauge.keysAvailable, keys + 1);
      } else {
        expect(c.player.materialCount(u.rare), 1);
      }
      expect(await c.claimUrgent(), isFalse);
    });
  });
}
