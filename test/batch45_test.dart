// 묶음 45 #231·#232: 마을 사람 작은 부탁 · 게시판 마을 사람 쪽지 · 전용 아이템 퀘스트

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/board_state.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/features/town/bag_tab.dart';
import 'package:isekai_reality/features/village/npc_request.dart';

import 'support/npc_seed.dart';

int _exp(AppController c) =>
    c.player.history.fold<int>(0, (t, r) => t + (r.gains['exp'] ?? 0));

Map<String, dynamic> _npc({
  Map<String, int> points = const {},
  Map<String, int> tally = const {},
  Map<String, dynamic> extra = const {},
}) =>
    {
      'v': 1,
      'points': points,
      'shown': {
        for (final e in points.entries) e.key: NpcRules.stageOf(e.value).index,
      },
      'done': const <String, int>{},
      'active': const <String, dynamic>{},
      'tally': tally,
      ...extra,
    };

void main() {
  group('규칙', () {
    test('게시판 마을 사람 쪽지: 사람마다 2장 · 경험치만 · 가끔 붙음 · 같은 사람은 한 장', () {
      for (final n in Npc.values) {
        expect(NpcSmallRules.notesOf(n.name), hasLength(2), reason: n.name);
        expect(NpcSmallRules.smallsOf(n), isNotEmpty, reason: n.name);
        expect(NpcSmallRules.boardAsk[n], isNotNull, reason: n.name);
        final r = NpcSmallRules.relicOf(n);
        expect(r.stages.length, inInclusiveRange(2, 3), reason: n.name);
      }
      for (final t in NpcSmallRules.boardNotes) {
        expect(t.exp, greaterThan(0));
        expect(t.gold, 0);
        expect(BoardRules.template(t.id), same(t));
      }
      expect(NpcSmallRules.relics, hasLength(11)); // 묶음 48 포포 · 묶음 51 리안·바르칸
      // 여러 날을 돌려 보면 가끔 마을 사람 쪽지가 붙는다
      final npcs = [for (final n in Npc.values) n.name];
      var npcNotes = 0, total = 0;
      for (var d = 0; d < 60; d++) {
        final b = BoardRules.refresh(
            const BoardState(), DateTime(2026, 12, 1).add(Duration(days: d)),
            npcs: npcs);
        final who = [
          for (final s in b.slots)
            if (BoardRules.template(s.templateId)?.npc case final n?) n,
        ];
        expect(who.toSet().length, who.length);
        npcNotes += who.length;
        total += b.slots.length;
      }
      expect(npcNotes, greaterThan(0));
      expect(npcNotes, lessThan(total));
      // 건물이 열린 사람이 없으면 마을 사람 쪽지는 안 붙음
      final none = BoardRules.refresh(const BoardState(), DateTime(2026, 12, 1));
      expect(
          none.slots.every((s) => BoardRules.template(s.templateId)?.npc == null),
          isTrue);
    });
  });

  group('게시판 「마을 사람 의뢰」', () {
    test('끝내면 그 사람 친밀도 +1 · 경험치 조금 · 금화 없음 · 5번째면 그 사람이 직접 작은 부탁',
        () async {
      final c = await startNpc(
        level: 5,
        npc: _npc(extra: {
          'bDone': {'marta': 4},
        }),
        todaySteps: const {'2026-11-16': 5000},
        json: {
          'board': const BoardState(day: '2026-11-16', seq: 2, slots: [
            ErrandSlot(templateId: 'npc_marta_0', accepted: true, baseline: 0),
            ErrandSlot(templateId: 'rat3'),
          ]).toJson(),
        },
      );
      expect(c.errandProgress(0), 2000);
      final gold = c.player.gold, exp = _exp(c), fav = c.favorPoints(Npc.marta);
      expect(await c.claimErrand(0), isTrue);
      expect(c.player.gold, gold);
      expect(_exp(c), exp + NpcSmallRules.boardExp);
      expect(c.favorPoints(Npc.marta), fav + 1);
      expect(c.npcState.boardDone['marta'], 5);
      // 5번째 → 마르타가 직접 작은 부탁 (「자주 해결」 말풍선)
      expect(c.smallOffer(Npc.marta), isNotNull);
      expect(c.npcAskKind(Npc.marta), AskKind.small);
      expect(c.smallSay(Npc.marta), startsWith(NpcSmallRules.boardAsk[Npc.marta]!));
      expect(c.takeNpcLine(Npc.marta), NpcSmallRules.boardAsk[Npc.marta]);
    });
  });

  group('작은 부탁', () {
    test('트리거마다 한 사람에 하나 · 낯섦부터 · 건물이 열린 뒤', () async {
      final c = await startNpc(level: 1, npc: _npc());
      // 미나: 오늘 잡화상에서 여러 번 거래
      for (var i = 0; i < NpcRules.usesPerDay; i++) {
        await c.sellManaStones(1);
      }
      expect(c.favorStage(Npc.mina), FavorStage.stranger);
      expect(c.smallOffer(Npc.mina), isNotNull);
      final first = c.npcState.smallOffer['mina'];
      expect(c.takeSmallNotice(), Npc.mina);
      // 한 사람에 하나: 또 거래해도 바뀌지 않음
      for (var i = 0; i < 5; i++) {
        await c.sellManaStones(1);
      }
      expect(c.npcState.smallOffer['mina'], first);
      // 건물이 안 열린 사람(길드 세라)은 안 나옴
      final c2 = await startNpc(level: 1, npc: _npc(extra: {'sOffer': {'sera': 0}}));
      expect(c2.smallOffer(Npc.sera), isNull);
      expect(c2.npcAskKind(Npc.sera), isNull);
    });

    test('받고 다 하면: 재료를 건네고 친밀도 +2 · 경험치 · 고맙다는 한마디 (사연 없음)', () async {
      final c = await startNpc(
        level: 5,
        mats: const {'herb': 3},
        npc: _npc(extra: {
          'sOffer': {'marta': 1},
          'rMiss': {'marta': 0},
        }),
      );
      expect(c.smallOffer(Npc.marta)!.steps.single.kind, RequestStepKind.deliver);
      expect(await c.acceptSmall(Npc.marta), isTrue);
      expect(c.smallOffer(Npc.marta), isNull);
      expect(c.smallReady(Npc.marta), isTrue);
      expect(c.activeAsks.where((a) => a.kind == AskKind.small), hasLength(1));
      final fav = c.favorPoints(Npc.marta), exp = _exp(c);
      final done = (await c.completeSmall(Npc.marta))!;
      expect(done.thanks, NpcSmallRules.small(Npc.marta, 1)!.thanks);
      expect(c.player.materialCount(MaterialId.herb), 1);
      expect(c.favorPoints(Npc.marta), fav + NpcSmallRules.smallFavor);
      expect(_exp(c), exp + NpcSmallRules.smallExp);
      expect(c.npcStories.firstWhere((e) => e.$1 == Npc.marta).$2.every((x) => x == null),
          isTrue);
      expect(c.npcState.smallDone['marta'], 1);
    });

    test('전용 퀘스트: 안 나오면 확률이 오르고, 나오면 사람마다 한 번', () async {
      expect(NpcSmallRules.relicChanceAfter(0), NpcSmallRules.relicChance);
      expect(NpcSmallRules.relicChanceAfter(3), greaterThan(NpcSmallRules.relicChance));
      final c = await startNpc(
        level: 5,
        mats: const {'herb': 5},
        npc: _npc(extra: {
          'small': {
            'marta': {'i': 1, 'day': '2026-11-16', 'base': {}, 'steps': 0},
          },
          'rMiss': {'marta': 20},
        }),
      );
      final done = (await c.completeSmall(Npc.marta))!;
      expect(done.relicOffered, isTrue);
      expect(c.relicOffer(Npc.marta), isNotNull);
      expect(c.npcAskKind(Npc.marta), AskKind.special);
      expect(await c.acceptRelic(Npc.marta), isTrue);
      expect(c.relicActive(Npc.marta), isNotNull);
      expect(c.relicStage(Npc.marta), 0);
    });
  });

  group('전용 아이템 퀘스트', () {
    test('단계를 다 하면 다음 단계 + 한마디 · 마지막은 「다 했어요」 → 소중한 물건 + 친밀도 +5',
        () async {
      final c = await startNpc(
        level: 5,
        mats: const {'ironShard': 3},
        npc: _npc(extra: {
          'relic': {
            'mina': {'i': 0, 'day': '2026-11-16', 'base': <String, int>{}, 'steps': 0},
          },
        }),
        todaySteps: const {'2026-11-16': 5000},
      );
      await c.refreshVitals();
      expect(c.relicStage(Npc.mina), 1);
      final n = c.takeRelicStageNotice()!;
      expect(n.$1, Npc.mina);
      expect(n.$2, NpcSmallRules.relicOf(Npc.mina).stages[1].line);
      expect(c.relicReady(Npc.mina), isFalse);
    });

    test('마지막 단계: 받으면 가방 「소중한 물건」 · 효과 (미나의 주판: 팔 때 금화 더)', () async {
      final c = await startNpc(
        level: 5,
        mats: const {'ironShard': 3, 'ratHide': 30},
        npc: _npc(extra: {
          'relic': {
            'mina': {'i': 2, 'day': '2026-11-16', 'base': {}, 'steps': 0},
          },
        }),
      );
      expect(c.relicReady(Npc.mina), isTrue);
      final gold0 = c.player.gold;
      await c.sellMaterial(MaterialId.ratHide, 10);
      final plain = c.player.gold - gold0;
      final fav = c.favorPoints(Npc.mina);
      final r = (await c.completeRelic(Npc.mina))!;
      expect(r.asset, 'item_minaAbacus');
      expect(c.player.materialCount(MaterialId.ironShard), 1);
      expect(c.favorPoints(Npc.mina), fav + NpcSmallRules.relicFavor);
      expect(c.hasRelic(Npc.mina), isTrue);
      expect(c.ownedRelics.map((x) => x.npc), [Npc.mina]);
      expect(c.relicActive(Npc.mina), isNull);
      final gold1 = c.player.gold;
      await c.sellMaterial(MaterialId.ratHide, 10);
      expect(c.player.gold - gold1, greaterThan(plain));
      // 한 번 받으면 다시 안 나옴
      expect(c.relicOffer(Npc.mina), isNull);
    });

    test('걸으면 듣는 것: 도르군의 작은 모루 (입은 장비 내구도) · 가렌의 무게 추 (전투 숙련도)', () async {
      final c = await startNpc(
        level: 13,
        npc: _npc(extra: {
          'relics': ['dorgun', 'garen'],
          'walkDay': '2026-11-16',
          'walk': 0,
        }),
        todaySteps: const {'2026-11-16': 5000},
      );
      await c.refreshVitals();
      final w = c.armory.byUid('w')!;
      expect(w.durability, 40 + 5000 ~/ NpcSmallRules.anvilSteps);
      expect(c.masteryOf(Mastery.combat), greaterThanOrEqualTo(NpcSmallRules.weightMastery * 5 - 0.001));
      // 같은 걸음을 두 번 세지 않음
      await c.refreshVitals();
      expect(c.armory.byUid('w')!.durability, w.durability);
    });

    test('하르트의 낡은 지도통: 길드 의뢰가 조금 더 빨리 새로 붙음', () async {
      final c = await startNpc(
        level: 5,
        npc: _npc(extra: {'relics': ['hart']}),
        todaySteps: const {'2026-11-16': 5000},
        json: {
          'board': const BoardState(day: '2026-11-16', seq: 2, slots: [
            ErrandSlot(templateId: 'steps3000', accepted: true, baseline: 0),
            ErrandSlot(templateId: 'rat3'),
          ]).toJson(),
        },
      );
      expect(await c.claimErrand(0), isTrue);
      expect(c.board.slots[0].readyAt,
          c.now.add(NpcSmallRules.mapcaseCooldown));
    });

    test('세라의 방패 문장: 막기 판정이 넉넉해짐 (완벽한 막기는 끝 0.3초)', () {
      const late = Duration(milliseconds: 1200);
      expect(Battle.judgeGuard(late), isNull);
      expect(Battle.judgeGuard(late, ease: NpcSmallRules.crestGuard),
          GuardResult.perfect);
      expect(Battle.judgeGuard(const Duration(milliseconds: 800),
              ease: NpcSmallRules.crestGuard),
          GuardResult.block);
    });
  });

  group('화면', () {
    testWidgets('부탁 창: 작은 부탁 표시 · 특별한 부탁은 단계', (tester) async {
      late AppController c;
      await tester.runAsync(() async => c = await startNpc(
            level: 5,
            npc: _npc(extra: {
              'sOffer': {'marta': 0},
              'rOffer': ['mina'],
            }),
          ));
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Builder(
                  builder: (context) => Column(children: [
                        NpcRequestBar(controller: c, npc: Npc.marta),
                        NpcRequestBar(controller: c, npc: Npc.mina),
                      ])))));
      await tester.pump();
      expect(find.byKey(const Key('npcAsk_marta_small')), findsOneWidget);
      expect(find.byKey(const Key('npcAsk_mina_special')), findsOneWidget);
      await tester.tap(find.byKey(const Key('npcAsk_mina_special')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('askTag_special')), findsOneWidget);
      expect(find.byKey(const Key('npcStage_0')), findsOneWidget);
      expect(find.byKey(const Key('npcStage_2')), findsOneWidget);
      await tester.tap(find.byKey(const Key('npcAccept')));
      await tester.pumpAndSettle();
      expect(c.relicActive(Npc.mina), isNotNull);
    });

    testWidgets('가방 「소중한 물건」 칸', (tester) async {
      late AppController c;
      await tester.runAsync(() async => c = await startNpc(
            level: 5,
            npc: _npc(extra: {
              'relics': ['marta', 'lumi'],
            }),
          ));
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: PreciousPanel(controller: c))));
      await tester.pump();
      expect(find.byKey(const Key('precious_marta')), findsOneWidget);
      expect(find.byKey(const Key('precious_lumi')), findsOneWidget);
      expect(find.text('마르타의 보온병'), findsOneWidget);
    });
  });
}
