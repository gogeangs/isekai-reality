// 묶음 46 #233·#234: 채집 미니게임 손맛 · 화면 다시

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/core/models/harvest_state.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/features/harvest/harvest_games.dart';

Future<HarvestGameResult?> _open(WidgetTester tester, Widget screen) async {
  HarvestGameResult? out;
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            key: const Key('open'),
            onPressed: () async {
              out = await Navigator.of(context).push<HarvestGameResult>(
                  MaterialPageRoute(builder: (_) => screen));
            },
            child: const Text('열기'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.byKey(const Key('open')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return out;
}

void main() {
  test('규칙: 귀한 재료를 정할 수 있음 · 바람 세기 평균은 예전과 같음 · 기록 칸', () {
    final rng = math.Random(1);
    for (var i = 0; i < 30; i++) {
      final yes = HarvestRules.yieldOf(HarvestKind.water, HarvestGrade.good, rng,
          forceRare: true);
      expect(yes[MaterialId.riverPearl], 1);
      final no = HarvestRules.yieldOf(HarvestKind.water, HarvestGrade.perfect, rng,
          forceRare: false);
      expect(no.containsKey(MaterialId.riverPearl), isFalse);
    }
    final w = HarvestRules.flowerWindMs;
    expect(w.reduce((a, b) => a + b) / w.length, 1300);
    expect(HarvestRules.waterRareChance(3), greaterThan(HarvestRules.waterRareChance(0)));
    // 예전 기록은 그대로 읽고, 새 칸은 비어 있음
    final old = HarvestState.fromJson({'tools': {}, 'granted': true, 'total': 5});
    expect(old.kindStreak, isEmpty);
    expect(old.gamesSeen, isEmpty);
    final back = HarvestState.fromJson(old
        .copyWith(kindStreak: {'herb': 2}, gamesSeen: ['herb'])
        .toJson());
    expect(back.kindStreak['herb'], 2);
    expect(back.gamesSeen, ['herb']);
    expect(back.total, 5);
  });

  testWidgets('처음엔 큰 설명 → 시작 · 도구 → 받을 재료 줄 · 그만두기는 빠른 채집으로', (tester) async {
    var started = 0;
    HarvestGameResult? got;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            key: const Key('open'),
            onPressed: () async {
              got = await Navigator.of(context).push<HarvestGameResult>(
                  MaterialPageRoute(
                      builder: (_) => HarvestGameScreen(
                            kind: HarvestKind.herb,
                            toolAsset: 'tool_sickle_iron',
                            toolName: '철 약초 낫',
                            first: true,
                            vibrate: false,
                            sound: false,
                            onStart: () => started++,
                          )));
            },
            child: const Text('열기'),
          ),
        ),
      ),
    ));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('harvestFirstBubble')), findsOneWidget);
    expect(find.byKey(const Key('gameTap')), findsNothing);
    expect(find.byKey(const Key('harvestToolLine')), findsOneWidget);
    expect(find.text('귀한 재료?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('gameStart')));
    await tester.pump();
    expect(started, 1);
    expect(find.byKey(const Key('gameTap')), findsOneWidget);
    expect(find.byKey(const Key('harvestHint')), findsOneWidget);
    // 그만두기 → 확인 → 빠른 채집
    await tester.tap(find.byKey(const Key('harvestQuit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('그만두면 이번 채집은 빠른 채집으로 해요.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('harvestQuitYes')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(got?.quit, isTrue);
    expect(got?.grade, HarvestGrade.quick);
  });

  testWidgets('결과 연출: 받은 재료 줄 · 약 1초 뒤 닫힘 · 눌러서 넘김', (tester) async {
    await _open(
        tester,
        const HarvestGameScreen(
          kind: HarvestKind.ore,
          vibrate: false,
          sound: false,
          debugResult: HarvestPlay(HarvestGrade.perfect),
          debugMats: {MaterialId.ironShard: 3, MaterialId.manaOre: 1},
        ));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('harvestFx')), findsOneWidget);
    expect(find.text('완벽해요!'), findsOneWidget);
    expect(find.byKey(const Key('harvestFxMats')), findsOneWidget);
    await tester.tap(find.byKey(const Key('harvestFx')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('harvestFx')), findsNothing);
  });

  testWidgets('여덟 게임 모두 열리고 끝까지 감 (그림이 없어도 코드로 그림)', (tester) async {
    for (final k in HarvestKind.values) {
      await _open(
          tester,
          HarvestGameScreen(
              kind: k, vibrate: false, sound: false, debugRare: true, streak: 2));
      expect(find.byKey(const Key('harvestBg')), findsOneWidget, reason: k.name);
      expect(find.byKey(const Key('harvestFlames')), findsOneWidget, reason: k.name);
      if (k == HarvestKind.mushroom) {
        expect(find.byKey(const Key('goldMushroom')), findsOneWidget);
      }
      if (k == HarvestKind.water) {
        expect(find.byKey(const Key('fishBig')), findsOneWidget);
      }
      // 시간이 다 되거나 놓치면 끝난다 (타이밍 게임은 세 번 누름)
      for (var i = 0; i < 3; i++) {
        if (find.byKey(const Key('gameTap')).evaluate().isNotEmpty) {
          await tester.tap(find.byKey(const Key('gameTap')));
          await tester.pump(const Duration(milliseconds: 200));
        }
      }
      if (k == HarvestKind.wood) {
        for (var i = 0; i < 3; i++) {
          final g = await tester.startGesture(
              tester.getCenter(find.byKey(const Key('gameHold'))));
          await tester.pump(const Duration(milliseconds: 500));
          await g.up();
          await tester.pump(const Duration(milliseconds: 100));
        }
      }
      for (var i = 0; i < 100 && find.byKey(const Key('harvestFx')).evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.byKey(const Key('harvestFx')), findsOneWidget, reason: k.name);
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(HarvestGameScreen), findsNothing, reason: k.name);
    }
  });
}
