// 묶음 69: 68 확인 답 · #279 공성전 스위치 · #280 #281 레벨 단계 몬스터 · #282 #285 부화장 · #283 #286 #290 마을 · #287~#289 말풍선 · #284 정령 이별
// (서버 판정은 node 시험 siege69.test.js · review_seed.test.js)

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/act5_state.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/features/act5/erbard_screens.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'batch52_test.dart' as b52;
import 'batch56_test.dart' as b56;
import 'batch60_test.dart' as b60;

const _ch2 = Act5State(opened: true, chapter: 2, seen: {'e1a', 'e1b', 'e1c'}, ticketAt: -60000);

void main() {
  setUp(() => b56.now = b52.t0);
  tearDown(() => ErbardRules.schedule = ErbardRules.legacySchedule);

  group('0 묶음 68 확인 답', () {
    test('공성전 빠른 말 「○○에 집결!」 · 밤은 19~6시 하나로', () {
      expect(ChatRules.siegeQuick('깊은 갱도 성').first, '깊은 갱도 성에 집결!');
      for (final h in [19, 23, 0, 5]) {
        final t = DateTime(2026, 11, 20, h);
        expect([HarvestRules.isNight(t), FieldMonsterRules.isNight(t), JobRules.isNight(t)], [true, true, true], reason: '$h시');
      }
      for (final h in [6, 12, 18]) {
        final t = DateTime(2026, 11, 20, h);
        expect([HarvestRules.isNight(t), FieldMonsterRules.isNight(t), JobRules.isNight(t)], [false, false, false], reason: '$h시');
      }
    });

    test('11-19 날짜 기준 없음: 예전 날 기록에도 많이 걸은 날 · 몬스터 6칸', () {
      expect(WalkRewardRules.steps2500(20000, DateTime(2026, 11, 1)), 4);
      expect(WalkRewardRules.chestsOn(20000, DateTime(2026, 11, 1)), isNotEmpty);
      expect(FieldMonsterRules.slotKey(DateTime.utc(2026, 11, 1, 3)), '2026-11-1@3');
    });
  });

  group('#279 공성전 스위치', () {
    test('일정: 닫힘 · 열기(그다음 토요일부터 2주마다) · 닫기(지금 것까지만)', () {
      expect(ErbardRules.closedSchedule.open, isFalse);
      final s = SiegeSchedule(anchor: DateTime.utc(2026, 11, 20, 15), firstNo: 3, doneBefore: 2);
      expect(s.open, isTrue);
      expect(s.no(DateTime.utc(2026, 11, 19)), 3);
      expect(s.start(4), DateTime.utc(2026, 12, 4, 15));
      final stop = SiegeSchedule(anchor: DateTime.utc(2026, 11, 20, 15), firstNo: 3, stopAfter: 3, doneBefore: 2);
      expect(stop.open, isFalse);
      expect(stop.start(4), SiegeSchedule.never);
      expect(SiegeSchedule.fromJson(s.toJson()).toJson(), s.toJson());
    });

    test('닫혀 있으면(서버) 공성권 · 싸움 없음 · 일지는 「곧 열려요」', () async {
      final (c, a) = await b60.act5(guild: true, state: _ch2);
      a.siegeOpen = false;
      await c.refreshErbard();
      expect(c.siegeOpen, isFalse);
      expect(c.erbardFightKind(ErbardRules.estate('sol_lily')!), isNull);
      expect(c.act5Goal, ErbardRules.closedGoal);
      expect(siegeLine(c.erbard, c.now), ErbardRules.closedLine);
      a.siegeOpen = true;
      await c.refreshErbard();
      expect(c.erbardFightKind(ErbardRules.estate('sol_lily')!), 'wild');
    });

    test('로그인하지 않아도 서버가 알려 준 일정을 따름 (없으면 닫힘)', () async {
      ErbardRules.schedule = ErbardRules.closedSchedule;
      final (c, _) = await b60.act5(state: _ch2, login: false);
      expect(c.siegeOpen, isFalse);
      expect(c.erbardFightKind(ErbardRules.estate('sol_lily')!), isNull);
      ErbardRules.schedule = ErbardRules.legacySchedule;
      expect(c.siegeOpen, isTrue);
    });

    testWidgets('영지 창: 닫혀 있으면 「깃발 공성전은 곧 열려요」 · 수비대 · 싸우기 없음', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      late AppController c;
      await tester.runAsync(() async {
        final (cc, a) = await b60.act5(guild: true, state: _ch2);
        c = cc;
        a.siegeOpen = false;
        await c.refreshErbard();
      });
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => TopNoticeHost(child: child!),
          home: Scaffold(
              body: Builder(
                  builder: (ctx) => Center(
                      child: TextButton(
                          onPressed: () => showEstateSheet(ctx, c, ErbardRules.estate('sol_lily')!), child: const Text('열기')))))));
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('estateClosed')), findsOneWidget);
      expect(find.byKey(const Key('estateFight')), findsNothing);
    });
  });
}
