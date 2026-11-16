// 묶음 42 #226: 마을 사람 부탁 · 사연 · 친해지기

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/features/records/records_screen.dart';
import 'package:isekai_reality/features/village/npc_header.dart';
import 'package:isekai_reality/features/village/npc_request.dart';

import 'support/npc_seed.dart';

Map<String, dynamic> _npc({
  Map<String, int> points = const {},
  Map<String, int> done = const {},
  Map<String, dynamic> active = const {},
  Map<String, int> tally = const {},
}) =>
    {
      'v': 1,
      'points': points,
      'shown': {
        for (final e in points.entries)
          e.key: NpcRules.stageOf(e.value).index,
      },
      'done': done,
      'active': active,
      'tally': tally,
    };

String _text(WidgetTester tester) => [
      for (final e in find.byType(Text).evaluate())
        (e.widget as Text).data ?? (e.widget as Text).textSpan?.toPlainText() ?? '',
      for (final e in find.byType(RichText).evaluate())
        (e.widget as RichText).text.toPlainText(),
    ].join('\n').replaceAll('⁠', '');

void main() {
  group('친해지기 (숨은 점수)', () {
    test('들르기는 하루 한 번, 시설 쓰기는 하루 3번까지', () async {
      final c = await startNpc(npc: _npc());
      c.takeNpcLine(Npc.mina);
      c.takeNpcLine(Npc.mina);
      await Future<void>.delayed(Duration.zero);
      expect(c.favorPoints(Npc.mina), 1);
      for (var i = 0; i < 5; i++) {
        await c.sellManaStones(1);
      }
      expect(c.favorPoints(Npc.mina), 1 + NpcRules.usesPerDay);
    });

    test('단계가 오르면 작은 선물 우편 한 통 · 새 대사 2줄이 섞임', () async {
      final c = await startNpc(npc: _npc(points: {'marta': 4}, done: {'marta': 1}));
      expect(c.favorStage(Npc.marta), FavorStage.stranger);
      expect(c.npcStageLines(Npc.marta), isEmpty);
      c.takeNpcLine(Npc.marta);
      await Future<void>.delayed(Duration.zero);
      expect(c.favorStage(Npc.marta), FavorStage.known);
      expect(c.mail.mails.where((m) => m.id == 'favor_marta_known'), hasLength(1));
      expect(c.npcStageLines(Npc.marta), hasLength(2));
      // 번갈아 나오는 대사에 새 대사가 섞인다
      final seen = <String>{
        for (var i = 0; i < 6; i++) c.takeNpcLine(Npc.marta),
      };
      expect(seen.intersection(c.npcStageLines(Npc.marta).toSet()), isNotEmpty);
    });

    test('예전 기록: 지금까지 기록으로 시작 점수 · 선물 우편은 몰아 보내지 않음', () async {
      final c = await startNpc(more: [
        for (var d = 1; d <= 6; d++)
          DailyRecord(date: DateTime(2026, 11, d), restsCompleted: 1),
      ]);
      expect(c.favorPoints(Npc.marta), 12);
      expect(c.favorStage(Npc.marta), FavorStage.known);
      expect(c.mail.mails.where((m) => m.id.startsWith('favor_')), isEmpty);
      // 시설이 안 열린 사람은 0 (세라 · 루미)
      expect(c.favorPoints(Npc.sera), 0);
      expect(c.favorPoints(Npc.lumi), 0);
    });
  });

  group('부탁', () {
    test('1번: 아는 사이가 되어야 열림 → 받기 → 받은 뒤부터 셈 → 다 했어요', () async {
      final c = await startNpc(npc: _npc(points: {'mina': 4}));
      expect(c.requestOffer(Npc.mina), isNull);
      await c.sellManaStones(3); // 받기 전 판 것은 세지 않음
      c.takeNpcLine(Npc.mina);
      await Future<void>.delayed(Duration.zero);
      expect(c.requestOffer(Npc.mina)?.index, 0);
      expect(c.npcAttention(Npc.mina), isTrue);
      expect(await c.acceptRequest(Npc.mina), isTrue);
      expect(c.requestOffer(Npc.mina), isNull);
      expect(c.requestProgress(Npc.mina).single.have, 0);
      await c.sellManaStones(6);
      expect(c.requestProgress(Npc.mina).single.have, 6);
      expect(c.requestReady(Npc.mina), isFalse);
      await c.sellManaStones(4);
      expect(c.requestReady(Npc.mina), isTrue);
      expect(c.npcAttention(Npc.mina), isTrue);
      final before = c.player.gold;
      final pts = c.favorPoints(Npc.mina);
      final done = await c.completeRequest(Npc.mina);
      expect(done!.request.story, contains('행상'));
      expect(c.player.gold, before + 80);
      expect(c.favorPoints(Npc.mina), pts + NpcRules.requestPoints);
      expect(c.requestActive(Npc.mina), isNull);
      // 다음 부탁은 친함 + Lv.6
      expect(c.requestOffer(Npc.mina), isNull);
      expect(c.npcStories.firstWhere((s) => s.$1 == Npc.mina).$2,
          [isNotNull, null, null, null]);
    });

    test('가져오기: 서로 다른 몬스터 재료 3종은 종류마다 하나씩 건넴', () async {
      final c = await startNpc(
          level: 6, npc: _npc(points: {'mina': 25}, done: {'mina': 1}));
      expect(c.requestOffer(Npc.mina)?.index, 1);
      await c.acceptRequest(Npc.mina);
      expect(c.requestProgress(Npc.mina).single.have, 3);
      expect(c.requestReady(Npc.mina), isTrue);
      final hide = c.player.materialCount(MaterialId.ratHide);
      final fur = c.player.materialCount(MaterialId.glossyFur);
      final jelly = c.player.materialCount(MaterialId.slimeJelly);
      await c.completeRequest(Npc.mina);
      final taken = (hide - c.player.materialCount(MaterialId.ratHide)) +
          (fur - c.player.materialCount(MaterialId.glossyFur)) +
          (jelly - c.player.materialCount(MaterialId.slimeJelly));
      expect(taken, 3);
      expect(c.player.materialCount(MaterialId.ratHide), hide - 1);
    });

    test('레벨 문턱: 친함이어도 레벨이 모자라면 안 열림', () async {
      final c = await startNpc(
          level: 4, npc: _npc(points: {'marta': 30}, done: {'marta': 1}));
      expect(c.requestOffer(Npc.marta), isNull); // Lv.5 부터
      final c2 = await startNpc(
          level: 5, npc: _npc(points: {'marta': 30}, done: {'marta': 1}));
      expect(c2.requestOffer(Npc.marta)?.index, 1);
    });

    test('한 사람에 부탁은 하나, 여러 사람은 동시에', () async {
      final c = await startNpc(
          level: 7, npc: _npc(points: {'mina': 6, 'dorgun': 6, 'eliel': 6}));
      expect(await c.acceptRequest(Npc.mina), isTrue);
      expect(await c.acceptRequest(Npc.dorgun), isTrue);
      expect(await c.acceptRequest(Npc.eliel), isTrue);
      expect(c.activeRequests, hasLength(3));
      expect(await c.acceptRequest(Npc.mina), isFalse);
    });

    test('4번째 부탁: 칭호 + 특별 보상 (마르타 목도리 · 도르군 숫돌 꼭 성공 · 미나 주머니)', () async {
      final c = await startNpc(
        level: 19,
        npc: _npc(
          points: {'marta': 50, 'dorgun': 50, 'mina': 50},
          done: {'marta': 3, 'dorgun': 3, 'mina': 3},
          active: {
            'marta': {'i': 3, 'day': '2026-11-16', 'base': {'relic': 0}, 'steps': 0},
          },
          tally: {'relic': 1},
        ),
      );
      expect(c.requestReady(Npc.marta), isTrue);
      final d = await c.completeRequest(Npc.marta);
      expect(d!.special?.title, TitleId.npcMarta);
      expect(c.player.titles, contains(TitleId.npcMarta));
      expect(c.armory.items.any((i) => i.base == EquipBase.martaScarf), isTrue);
      expect(c.npcStories.firstWhere((s) => s.$1 == Npc.marta).$2.every((p) => p != null),
          isTrue);
      // 미나: 하루 10,000보 → 짐 주머니 (가방 칸 +2)
      final cap = c.bagCapacity;
      await c.acceptRequest(Npc.mina);
      expect(c.requestReady(Npc.mina), isFalse);
      // 도르군: 숫돌 → 강화 한 번 꼭 성공
      expect(c.whetstones, 0);
      await c.acceptRequest(Npc.dorgun);
      expect(c.requestProgress(Npc.dorgun).map((p) => p.step.label),
          contains(contains('잿빛 슬라임')));
      expect(cap, greaterThan(0));
    });

    test('특별 보상 받기 (숫돌 · 주머니 · 레시피)', () async {
      final c = await startNpc(
        level: 19,
        npc: _npc(
          points: {'dorgun': 50, 'mina': 50, 'eliel': 50},
          done: {'dorgun': 3, 'mina': 3, 'eliel': 3},
          active: {
            'dorgun': {'i': 3, 'day': '2026-11-16', 'base': {'ashKill': 0}, 'steps': 0},
            'eliel': {'i': 3, 'day': '2026-11-16', 'base': {'newRecipe': 0}, 'steps': 0},
          },
          tally: {'ashKill': 2, 'newRecipe': 1},
        ),
        mats: const {'gemFire': 2, 'gemLight': 1},
      );
      expect(c.requestReady(Npc.dorgun), isTrue);
      await c.completeRequest(Npc.dorgun);
      expect(c.whetstones, 1);
      expect(c.player.materialCount(MaterialId.gemFire), 0);
      final w = c.armory.items.firstWhere((i) => i.uid == 'w');
      expect(await c.enhance('w', whetstone: true), isTrue);
      expect(c.armory.items.firstWhere((i) => i.uid == 'w').enhance, w.enhance + 1);
      expect(c.whetstones, 0);
      // 엘리엘: 여명의 빛 물약 레시피 + 한 병
      await c.completeRequest(Npc.eliel);
      expect(c.recipeDiscovered(PotionId.dawnLight), isTrue);
      expect(c.player.titles, contains(TitleId.npcEliel));
    });

    test('짐 주머니: 가방 칸 +2', () async {
      final c = await startNpc(
        level: 17,
        npc: _npc(
          points: {'mina': 50},
          done: {'mina': 3},
          active: {'mina': {'i': 3, 'day': '2026-11-16', 'base': {}, 'steps': 0}},
        ),
        todaySteps: const {'2026-11-16': 12000},
      );
      final cap = c.bagCapacity;
      expect(c.requestReady(Npc.mina), isTrue);
      await c.completeRequest(Npc.mina);
      expect(c.bagCapacity, cap + NpcRules.pouchSlots);
    });

    test('연속 휴식: 사흘 연속 여관에서 쉬기', () async {
      var now = DateTime(2026, 11, 16, 10);
      final c = await startNpc(
        level: 9,
        npc: _npc(points: {'marta': 30}, done: {'marta': 2}),
        clock: () => now,
      );
      await c.acceptRequest(Npc.marta);
      for (var d = 0; d < 3; d++) {
        now = DateTime(2026, 11, 16 + d, 10);
        await c.restAtInn();
        now = now.add(const Duration(hours: 5));
        await c.refreshVitals();
      }
      final p = c.requestProgress(Npc.marta);
      expect(p[1].have, 3);
      expect(p[0].have, 0); // 물가 채집은 아직
    });

    test('튜토리얼·기능 안내 중엔 부탁을 숨김 · 순서 규칙(첫 줄 → 부탁 알림)', () async {
      final c = await startNpc(npc: _npc(points: {'mina': 10}));
      // 이미 만난 사람: 부탁 알림이 먼저
      expect(c.takeNpcLine(Npc.mina), NpcRules.askLine);
      // 상황 안내가 있으면 그것이 먼저
      expect(c.takeNpcLine(Npc.mina, situation: '상황'), '상황');
    });
  });

  group('화면', () {
    testWidgets('시설 마을 사람: 부탁 듣기 → 받기 → 진행 → 다 했어요 → 사연', (tester) async {
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      late AppController c;
      await tester.runAsync(() async => c = await startNpc(npc: _npc(points: {'mina': 10})));
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Padding(
                  padding: const EdgeInsets.all(12),
                  child: NpcHeader(controller: c, npc: Npc.mina)))));
      await tester.pump();
      expect(_text(tester), contains(NpcRules.askLine));
      await tester.tap(find.byKey(const Key('npcAsk_mina')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('npcRequestSheet')), findsOneWidget);
      expect(_text(tester), contains('잡화상에 마석 10개 팔기'));
      expect(_text(tester), contains('금화 80'));
      await tester.tap(find.byKey(const Key('npcAccept')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('npcReq_mina')), findsOneWidget);
      await tester.runAsync(() => c.sellManaStones(10));
      await tester.pump();
      expect(find.byKey(const Key('npcDone_mina')), findsOneWidget);
      await tester.tap(find.byKey(const Key('npcDone_mina')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('npcStoryDialog')), findsOneWidget);
      expect(_text(tester), contains('두 세계를 오가는 행상'));
      await tester.tap(find.byKey(const Key('npcStoryOk')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('npcStoryDialog')), findsNothing);
    });

    testWidgets('기록 탭 「마을 사람 이야기」: ??? 칸 · 4조각이면 금테', (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: NpcStoryRecords(stories: [
        (Npc.marta, [for (final r in NpcRules.of(Npc.marta)) r.story]),
        (Npc.mina, [NpcRules.of(Npc.mina).first.story, null, null, null]),
      ])))));
      await tester.pump();
      expect(find.byKey(const Key('npcStoryFull')), findsOneWidget);
      expect(_text(tester), contains('???'));
      expect(find.byType(RecordsScreen), findsNothing);
    });
  });

  test('부탁 28개 · 사람마다 4개 · 단계 대사·선물 우편 모두', () {
    expect(NpcRules.requests, hasLength(28));
    for (final n in Npc.values) {
      final l = NpcRules.of(n);
      expect(l, hasLength(4));
      expect(l.last.special, isNotNull);
      for (final s in [FavorStage.known, FavorStage.close, FavorStage.best]) {
        expect(NpcRules.linesAt(n, s), hasLength(2));
        expect(NpcRules.letters[n]?[s], isNotNull);
      }
    }
    // 화면 문구에 개발 말·숫자 확률 없음
    for (final r in NpcRules.requests) {
      expect(r.say.contains('%'), isFalse);
    }
  });
}
