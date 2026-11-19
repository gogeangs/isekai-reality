// 묶음 71: 70 확인 답 · 고칠 것 — 조합 탭 Lv.4 · 마을 사람 말풍선(닫힌 채로 · 꼭 알릴 말만 잠깐) ·
// Lv.8 정령 얼굴 + 말풍선 · 대장간 수리 · 길 자료가 있는 원정 (걷는 펫은 길, 나는 펫은 직선)

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/features/chat/chat_tour.dart';
import 'package:isekai_reality/features/village/board_screen.dart';
import 'package:isekai_reality/features/village/npc_header.dart';

import 'batch52_test.dart' as b52;
import 'batch56_test.dart' as b56;
import 'support/route_seed.dart';
import 'support/village_seed.dart';

void phone(WidgetTester t) {
  t.view.physicalSize = const Size(750, 1334);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
}

void main() {
  setUp(() => b56.now = b52.t0);

  test('원정: 길 자료가 있으면 걷는 펫은 길 거리(ㄱ자) · 나는 펫은 직선 — 기력 · 시간도 따라 다름', () async {
    final (c, s) = await routedExpedition();
    final owl = c.planExpedition(s, petUid: 'p1');
    final wolf = c.planExpedition(s, petUid: 'p2');
    expect(wolf.followsRoads, isTrue);
    expect(owl.followsRoads, isFalse);
    final straight = c.lastFix!.point.distanceTo(s.point);
    expect(owl.distanceM, closeTo(straight, 1));
    expect(wolf.distanceM, greaterThan(straight * 1.3));
    expect(wolf.mpCost, greaterThan(owl.mpCost));
  });

  testWidgets('게시판: 「조합」 탭은 게시판이 열릴 때(Lv.4)부터', (tester) async {
    phone(tester);
    expect(BoardRules.errandTabLevel, 4);
    late AppController c;
    await tester.runAsync(() async => c = await startVillage(5));
    await tester.pumpWidget(MaterialApp(home: BoardScreen(controller: c)));
    await tester.pump();
    expect(find.byKey(const Key('boardTab_errand')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('마을 사람: 처음 만남도 닫힌 채로(점) · 상황 안내는 저절로 열렸다 몇 초 뒤 닫힘 · 탭을 덮지 않음', (tester) async {
    phone(tester);
    late AppController c;
    await tester.runAsync(() async => c = await startVillage(12));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Column(children: [
      NpcHeader(controller: c, npc: Npc.hart, guide: '안내'),
      const Text('탭', key: Key('under')),
    ]))));
    await tester.pump();
    expect(find.byKey(const Key('npcBubble_hart')), findsNothing, reason: '처음 만남은 닫힌 채로');
    expect(find.byKey(const Key('npcDot_hart')), findsOneWidget);
    await tester.tap(find.byKey(const Key('npcFace_hart')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('npcBubble_hart')), findsOneWidget);
    // 말풍선이 열려도 아래 글을 덮지 않음 (아래로 밀림)
    final bubble = tester.getRect(find.byKey(const Key('npcBubble_hart')));
    final under = tester.getRect(find.byKey(const Key('under')));
    expect(bubble.bottom, lessThanOrEqualTo(under.top + 0.5));
    await tester.pumpWidget(const SizedBox());

    // 상황 안내: 저절로 열림 → 몇 초 뒤 닫힘
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: NpcHeader(key: UniqueKey(), controller: c, npc: Npc.hart, guide: '안내', situation: '긴급 의뢰가 붙었네!'))));
    await tester.pump();
    expect(find.byKey(const Key('npcBubble_hart')), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('npcBubble_hart')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Lv.8 친구 장면 · 기록 지키기: 정령 얼굴 + 말풍선 · 「나중에」는 작은 글자', (tester) async {
    phone(tester);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SpiritLineAlert(
      spiritName: '불씨',
      line: '친구를 사귀려면 기록을 지켜 둬야 해!',
      actions: [(const Key('a'), '로그인', () {}), (const Key('b'), '나중에', () {})],
    ))));
    await tester.pump();
    expect(find.byKey(const Key('spiritLine')), findsOneWidget);
    expect(find.text('나중에'), findsOneWidget);
    expect(find.byKey(const Key('b')), findsOneWidget);
  });
}
