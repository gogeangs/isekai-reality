import 'dart:math' as math;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/geo/geo.dart';
import 'package:isekai_reality/core/models/highland_state.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/features/highland/highland_screen.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'batch50_test.dart' as b50;

/// 묶음 83 #389: 하이랜드 쿼터뷰 구름 걷기 · 수호자 턴제
Future<AppController> onIsland({Map<String, int> mats = const {'skyFeather': 2}, int level = 18, SkyClimb? climb, Isle isle = Isle.wind, bool guideSeen = false}) async {
  b50.now = b50.am.add(const Duration(minutes: 5));
  final slot = HighlandRules.slotAt(b50.now)!.slot;
  final c = await b50.start(b50.account(level,
      mats: mats,
      highland: HighlandState(
        sceneSeen: true,
        starter: true,
        climbedEver: true,
        firstLine: true,
        slot: slot,
        isle: isle.index,
        lat: b50.home.lat,
        lng: b50.home.lng,
        climb: climb,
        guideSeen: guideSeen,
      ).toJson()));
  await c.handleFix(const LocationFix(point: b50.home));
  return c;
}

String get slotNow => HighlandRules.slotAt(b50.now)!.slot;

/// 밝힌 칸에서 [target] 까지 걸음 (병사가 나오면 이겨서 지나감). 바람이 모자라면 false
Future<bool> walkTo(AppController c, int target) async {
  while (true) {
    final cl = c.skyClimb!;
    final b = c.skyBoard!;
    final opened = cl.opened.toSet();
    if (opened.contains(target)) return true;
    // 밝힌 칸에서 target 까지 가장 짧은 길의 첫 칸
    final prev = <int, int>{};
    final q = [...opened];
    final seen = {...opened};
    var found = false;
    for (var k = 0; k < q.length && !found; k++) {
      for (final j in b.neighbors4(q[k])) {
        if (seen.add(j)) {
          prev[j] = q[k];
          q.add(j);
          if (j == target) found = true;
        }
      }
    }
    var step = target;
    while (!opened.contains(prev[step]!)) {
      step = prev[step]!;
    }
    final s = await c.revealSkyCell(step);
    if (s == null) return false;
    if (s.kind == SkyCell.soldier) {
      final bt = c.startSoldierBattle()!;
      b50.win(bt);
      await c.finishSoldierBattle(bt);
    }
  }
}

SkyTurn turn(Isle isle, {bool hints = false, int potions = 3, bool pet = true, math.Random? rng}) => SkyTurn(
      isle: isle,
      level: 20,
      heroMaxHp: 1000000,
      heroHp: 1000000,
      heroAttack: 1,
      mp: 100,
      mpMax: 100,
      skills: const [
        AshTurnSkill(key: 'a', name: '내려베기', mp: 20, attack: true),
        AshTurnSkill(key: 'w', name: '철벽', mp: 20, attack: false),
      ],
      hasPet: pet,
      potions: [BattlePotion(key: 'p', name: '물약', count: potions, hpRatio: 0.3)],
      hints: hints,
      rng: rng ?? math.Random(3),
    );

void main() {
  group('판 만들기', () {
    test('층마다 칸 수 · 놓인 것 · 계단(제단) 거리 · 입구 둘레 3칸 · 같은 씨앗은 같은 판', () {
      for (var seed = 0; seed < 120; seed++) {
        for (final f in SkyWalkRules.floors) {
          final b = SkyBoard.generate(seed, f.floor);
          expect(b.count, const {1: 65, 2: 37, 3: 21}[f.floor]);
          int n(SkyCell k) => b.cells.where((c) => c == k).length;
          expect(n(SkyCell.crystal), f.crystals);
          expect(n(SkyCell.stone), f.stones);
          expect(n(SkyCell.spring), f.springs);
          expect(n(SkyCell.soldier), f.soldiers);
          expect(n(SkyCell.shard), 1);
          expect(n(f.top ? SkyCell.altar : SkyCell.stair), 1);
          expect(b.dist[b.goal], inInclusiveRange(f.goalMin, f.goalMax));
          // 입구는 맨 앞(x + y 가장 큼)
          final front = [for (var i = 0; i < b.cells.length; i++) if (b.inside(i)) b.xOf(i) + b.yOf(i)].reduce(math.max);
          expect(b.xOf(b.entrance) + b.yOf(b.entrance), front);
          expect(b.at(b.entrance), SkyCell.empty);
          for (var i = 0; i < b.cells.length; i++) {
            final k = b.at(i);
            if (k == null || k == SkyCell.empty) continue;
            final loot = k == SkyCell.crystal || k == SkyCell.stone;
            expect(b.dist[i], greaterThanOrEqualTo(loot ? SkyWalkRules.lootFallback : SkyWalkRules.clearance),
                reason: 'seed $seed floor ${f.floor} $k');
            if (f.floor < 3) expect(b.dist[i], greaterThanOrEqualTo(SkyWalkRules.clearance));
          }
          expect(b.columns.length, f.floor == 2 ? inInclusiveRange(5, 7) : 0);
          for (final i in b.columns) {
            expect(b.at(i), SkyCell.empty);
          }
          final again = SkyBoard.generate(seed, f.floor);
          expect(again.cells, b.cells);
          expect(again.columns, b.columns);
        }
      }
      expect(SkyBoard.generate(1, 1).cells, isNot(SkyBoard.generate(2, 1).cells));
    });

    test('상하좌우만 걷을 수 있음 · 숫자는 아직 숨은 유물 조각만 센다', () {
      final b = SkyBoard.generate(11, 1);
      final opened = {b.entrance};
      final x = b.xOf(b.entrance), y = b.yOf(b.entrance);
      expect(b.canReveal((y - 1) * b.n + x, opened), isTrue);
      expect(b.canReveal((y - 1) * b.n + x - 1, opened), isFalse); // 대각선
      expect(b.canReveal(b.entrance, opened), isFalse);
      final near = b.neighbors8(b.shard).first;
      expect(b.hint(near, {near}), 1);
      expect(b.hint(near, {near, b.shard}), 0);
    });
  });

  group('구름 걷기', () {
    test('오르면 깃털 하나 · 새 판 · 바람 · 걷기는 바람 1 · 결정은 바로 가방에 · 바람 샘 +3', () async {
      final c = await onIsland();
      expect(await c.climbIsland(), isTrue);
      expect(c.skyFeathers, 1);
      final cl = c.skyClimb!;
      final b = c.skyBoard!;
      expect(cl.floor, 1);
      expect(cl.wind, 18);
      expect(cl.opened, [b.entrance]);
      // 맞닿지 않은 칸은 안 됨
      final far = b.goal;
      expect(await c.revealSkyCell(far), isNull);
      // 결정 칸까지
      final crystal = [for (var i = 0; i < b.cells.length; i++) if (b.at(i) == SkyCell.crystal) i]
        ..sort((p, q) => b.dist[p] - b.dist[q]);
      c.highland; // 판 그대로
      final wind0 = c.skyClimb!.wind;
      expect(await walkTo(c, crystal.first), isTrue);
      final used = c.skyClimb!.opened.length - 1;
      final springs = [for (final i in c.skyClimb!.opened) if (b.at(i) == SkyCell.spring) i].length;
      expect(c.skyClimb!.wind, wind0 - used + springs * SkyWalkRules.springWind);
      expect(c.player.materialCount(MaterialId.cloudCrystal), greaterThanOrEqualTo(1));
      expect(c.skyClimb!.crystals, greaterThanOrEqualTo(1));
    });

    test('바람 샘을 밝히면 +3 (그 자리는 걷은 칸)', () async {
      final c = await onIsland();
      await c.climbIsland();
      final b = c.skyBoard!;
      final spring = [for (var i = 0; i < b.cells.length; i++) if (b.at(i) == SkyCell.spring) i]
        ..sort((p, q) => b.dist[p] - b.dist[q]);
      // 샘 바로 옆까지 걷고, 샘을 밝힐 때 바람을 본다
      final s = spring.first;
      final before = b.neighbors4(s).reduce((p, q) => b.dist[p] < b.dist[q] ? p : q);
      expect(await walkTo(c, before), isTrue);
      final w = c.skyClimb!.wind;
      final step = await c.revealSkyCell(s);
      expect(step!.kind, SkyCell.spring);
      expect(c.skyClimb!.wind, w - 1 + SkyWalkRules.springWind);
    });

    test('바람이 다하면 끝 · 계단을 찾았으면 위층으로 · 남은 바람은 이어짐 · 층 점', () async {
      final seed = 5;
      final b1 = SkyBoard.generate(seed, 1);
      final c = await onIsland(
          climb: SkyClimb(slot: slotNowAm(), seed: seed, wind: 0, opened: [b1.entrance], hero: b1.entrance));
      expect(c.skyClimb, isNotNull);
      expect(c.skyStuck, isTrue);
      expect(c.canClimbUp, isFalse);

      final c2 = await onIsland(
          climb: SkyClimb(slot: slotNowAm(), seed: seed, wind: 0, opened: [b1.entrance, b1.goal], hero: b1.goal));
      expect(c2.skyStuck, isFalse);
      expect(c2.canClimbUp, isTrue);
      expect(await c2.climbUp(), isTrue);
      final cl = c2.skyClimb!;
      expect(cl.floor, 2);
      expect(cl.wind, 0 + SkyWalkRules.floor(2).wind);
      expect(cl.opened, [c2.skyBoard!.entrance]);
      expect(c2.skyBoard!.floor, 2);
    });

    test('꼭대기: 조각 셋 + 제단이면 수호자 · 아니면 안 됨', () async {
      final b3 = SkyBoard.generate(9, 3);
      final two = await onIsland(
          climb: SkyClimb(slot: slotNowAm(), seed: 9, floor: 3, wind: 2, opened: [b3.entrance, b3.goal], hero: b3.goal, shards: 2));
      expect(two.canWakeGuardian, isFalse);
      expect(await two.startGuardianTurn(), isNull);
      final three = await onIsland(
          climb: SkyClimb(slot: slotNowAm(), seed: 9, floor: 3, wind: 0, opened: [b3.entrance, b3.goal], hero: b3.goal, shards: 3));
      expect(three.canWakeGuardian, isTrue);
      expect(three.skyStuck, isFalse);
    });

    test('석상 병사: 지금 HP로 싸움 · 이기면 하늘 돌 · 지면 이번 오르기 끝 (얻은 것은 그대로)', () async {
      final c = await onIsland();
      await c.climbIsland();
      final b = c.skyBoard!;
      final soldiers = [for (var i = 0; i < b.cells.length; i++) if (b.at(i) == SkyCell.soldier) i]
        ..sort((p, q) => b.dist[p] - b.dist[q]);
      final s = soldiers.first;
      final before = b.neighbors4(s).reduce((p, q) => b.dist[p] < b.dist[q] ? p : q);
      expect(await walkTo(c, before), isTrue);
      await c.revealSkyCell(s);
      expect(c.skyClimb!.soldier, s);
      // 병사와 싸우는 동안 다른 칸은 못 걷음
      final other = b.neighbors4(before).firstWhere((i) => !c.skyClimb!.opened.contains(i), orElse: () => -1);
      if (other >= 0) expect(await c.revealSkyCell(other), isNull);
      final bt = c.startSoldierBattle()!;
      expect(bt.playerHp, c.hp);
      expect(bt.foe.monster, MonsterId.stoneSoldier);
      b50.lose(bt);
      final stones0 = c.player.materialCount(MaterialId.skyStone);
      final r = await c.finishSoldierBattle(bt);
      expect(r.won, isFalse);
      expect(r.climb, isNotNull);
      expect(c.skyClimb, isNull);
      expect(c.player.materialCount(MaterialId.skyStone), stones0);
    });

    test('앱을 다시 켜도 판 · 바람 · 조각이 이어진다', () async {
      final a = b50.account(18, mats: {'skyFeather': 1});
      b50.now = b50.am.add(const Duration(minutes: 5));
      final c = await b50.start(a);
      await c.markHighlandScene();
      await c.handleFix(const LocationFix(point: b50.home));
      await c.handleFix(LocationFix(point: c.skyIsland!.point));
      expect(await c.climbIsland(), isTrue);
      final b = c.skyBoard!;
      final step = b.neighbors4(b.entrance).first;
      await c.revealSkyCell(step);
      final before = c.skyClimb!;
      final again = await b50.start(a);
      await again.handleFix(LocationFix(point: again.skyIsland!.point));
      final after = again.skyClimb!;
      expect(after.seed, before.seed);
      expect(after.wind, before.wind);
      expect(after.opened, before.opened);
      expect(after.shards, before.shards);
      expect(again.skyBoard!.cells, b.cells);
    });

    test('섬이 떠나면 오르기가 끝남 (결과 숫자는 남음)', () async {
      final b1 = SkyBoard.generate(3, 1);
      final c = await onIsland(
          climb: SkyClimb(slot: slotNowAm(), seed: 3, wind: 9, opened: [b1.entrance], hero: b1.entrance, crystals: 2, stones: 1));
      expect(c.skyClimb, isNotNull);
      b50.now = b50.am.add(const Duration(minutes: 90));
      expect(c.skyIsland, isNull);
      expect(c.skyClimb, isNull);
      final s = await c.endSkyClimb();
      expect(s.floor, 1);
      expect(s.crystals, 2);
      expect(s.stones, 1);
    });

    test('#375 펫이 섬 아래에서 기다리면 그대로 오름', () async {
      final c = await onIsland();
      final plan = c.planTrip('sky', petUid: 'p1');
      expect(plan.ok, isTrue);
      expect(await c.sendTrip('sky', 'p1'), ExpeditionCheck.ok);
      b50.now = b50.now.add(plan.oneWay + const Duration(seconds: 2));
      await c.refreshVitals();
      expect(c.skyReachable, isTrue);
      expect(await c.climbIsland(), isTrue);
      expect(c.skyClimb, isNotNull);
    });
  });

  group('수호자 턴제', () {
    test('회오리: 예고(붉게) → 다음 턴 두 번 공격', () {
      final t = turn(Isle.wind);
      t.act(SkyCmd.strike);
      t.act(SkyCmd.strike);
      expect(t.turn, 3);
      expect(t.intent, SkyIntent.whirl);
      expect(t.bigNext, isTrue);
      final e = t.act(SkyCmd.strike);
      expect(e.where((x) => x.kind == SkyEventKind.foeHit).length, HighlandRules.whirlLength);
    });

    test('낙뢰: 먹구름(1턴) → 다음 턴 큰 피해 · 방어하면 거의 막음', () {
      int bolt({required bool guard}) {
        final t = turn(Isle.thunder, rng: math.Random(1));
        t.act(SkyCmd.strike);
        t.act(SkyCmd.strike);
        expect(t.intent, SkyIntent.charge);
        expect(t.bigNext, isFalse);
        final e = t.act(SkyCmd.strike);
        expect(e.any((x) => x.kind == SkyEventKind.foeCharge), isTrue);
        expect(t.intent, SkyIntent.bolt);
        expect(t.bigNext, isTrue);
        expect(SkyTurnRules.intentLine(t.intent, t.isle), '다음 턴: 낙뢰');
        final hp = t.hp;
        t.act(guard ? SkyCmd.guard : SkyCmd.strike);
        expect(t.intent, isNot(SkyIntent.bolt));
        return hp - t.hp;
      }

      final open = bolt(guard: false), held = bolt(guard: true);
      expect(held, lessThan(open * 0.35));
    });

    test('햇살 치유: 절반 아래로 처음 내려가면 예고 → 크게 회복 · 한 번만', () {
      final t = turn(Isle.light);
      t.foeHp = t.foeMax ~/ 3;
      t.act(SkyCmd.strike);
      expect(t.intent, SkyIntent.heal);
      final before = t.foeHp;
      final e = t.act(SkyCmd.strike);
      expect(e.any((x) => x.kind == SkyEventKind.foeHeal), isTrue);
      expect(t.foeHp, greaterThan(before));
      expect(t.healed, isTrue);
      t.foeHp = t.foeMax ~/ 4;
      for (var k = 0; k < 6; k++) {
        t.act(SkyCmd.guard);
        expect(t.intent, isNot(SkyIntent.heal));
      }
    });

    test('서리 갑옷: 예고 → 받는 피해 크게 줄어듦 · 강타 한 번에 깨짐', () {
      final t = turn(Isle.ice);
      t.act(SkyCmd.guard);
      t.act(SkyCmd.guard);
      expect(t.intent, SkyIntent.armor);
      t.act(SkyCmd.guard);
      expect(t.frost, greaterThan(0));
      expect(t.hinted, isEmpty); // 힌트는 처음 싸울 때만
      final e = t.act(SkyCmd.strike);
      expect(e.first.kind, SkyEventKind.armorBreak);
      expect(t.frost, 0);
    });

    test('물살: 예고 → 막는 스킬(철벽)을 씻어 냄', () {
      final t = turn(Isle.water);
      t.act(SkyCmd.strike);
      t.act(SkyCmd.strike);
      expect(t.intent, SkyIntent.wash);
      t.act(SkyCmd.skill2);
      expect(t.wall, 0);
      final t2 = turn(Isle.water);
      t2.act(SkyCmd.skill2);
      expect(t2.wall, SkyTurnRules.wallTurns - 1);
    });

    test('처음 싸울 때만 초록 힌트 · 예고 세 번까지', () {
      final t = turn(Isle.thunder, hints: true);
      var shown = 0;
      for (var k = 0; k < 30 && !t.isOver; k++) {
        final h = t.hinted;
        if (h.isNotEmpty) {
          shown++;
          if (t.intent == SkyIntent.bolt) expect(h, {SkyCmd.guard});
        }
        t.act(h.isNotEmpty ? h.first : SkyCmd.strike);
      }
      expect(shown, SkyTurnRules.hintCount);
      expect(turn(Isle.thunder).hintsLeft, 0);
    });

    test('물약은 한 판에 셋 · 펫 스킬은 세 턴마다', () {
      final t = turn(Isle.wind, potions: 9);
      t.hp = 500000;
      for (var k = 0; k < 3; k++) {
        expect(t.can(SkyCmd.potion), isTrue);
        t.act(SkyCmd.potion);
        t.hp = 500000;
      }
      expect(t.can(SkyCmd.potion), isFalse);
      expect(t.can(SkyCmd.petSkill), isTrue);
      t.act(SkyCmd.petSkill);
      expect(t.can(SkyCmd.petSkill), isFalse);
      t.act(SkyCmd.strike);
      t.act(SkyCmd.strike);
      expect(t.can(SkyCmd.petSkill), isTrue);
      expect(turn(Isle.wind, pet: false).can(SkyCmd.petSkill), isFalse);
    });

    test('이기면 지금 보상 + 오르기 합계 · 지면 오르기 얻은 것 그대로 · 깨운 채 나가면 진 것', () async {
      final b3 = SkyBoard.generate(4, 3);
      SkyClimb top() => SkyClimb(slot: slotNowAm(), seed: 4, floor: 3, wind: 1, opened: [b3.entrance, b3.goal], hero: b3.goal, shards: 3, crystals: 3, stones: 2);
      final c = await onIsland(climb: top());
      final t = (await c.startGuardianTurn())!;
      expect(t.hints, isTrue);
      expect(t.hp, c.hp);
      t.foeHp = 0;
      final r = await c.finishGuardianTurn(t);
      expect(r.won, isTrue);
      expect(r.firstKill, isTrue);
      expect(r.climb!.crystals, 3);
      expect(r.climb!.floor, 3);
      expect(c.player.materialCount(MaterialId.cloudCrystal), HighlandRules.firstCrystals);
      expect(c.skyIsland!.cleared, isTrue);
      expect(c.skyClimb, isNull);
      expect(c.highland.fought, [Isle.wind.index]);

      final lost = await onIsland(climb: top());
      final t2 = (await lost.startGuardianTurn())!;
      t2.hp = 0;
      final r2 = await lost.finishGuardianTurn(t2);
      expect(r2.won, isFalse);
      expect(r2.climb!.stones, 2);
      expect(lost.skyIsland!.cleared, isFalse);
      expect(lost.skyClimb, isNull);

      final gone = await onIsland(climb: top());
      await gone.startGuardianTurn();
      expect(gone.skyGuardianAbandoned, isTrue);
      final r3 = await gone.finishGuardianTurn(null);
      expect(r3.won, isFalse);
      expect(gone.skyClimb, isNull);
    });
  });

  testWidgets('섬 화면: 오르기 → 구름 걷기 → 걷기 · 안내 카드 · 작은 지도', (tester) async {
    tester.view.physicalSize = const Size(750, 1334);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    late AppController c;
    await tester.runAsync(() async {
      c = await onIsland();
    });
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => TopNoticeHost(child: child!),
        home: HighlandScreen(controller: c)));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const Key('skyClimb')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const Key('skyMiniMap')), findsOneWidget);
    expect(find.byKey(const Key('skyGuide')), findsOneWidget);
    expect(c.highland.guideSeen, isTrue);
    expect(find.byKey(const Key('skyFloorDot_1_now')), findsOneWidget);
    expect(find.byKey(const Key('skyPillar')), findsNothing);
    final can = find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.endsWith('_can'));
    expect(can, findsWidgets);
    final wind = c.skyClimb!.wind;
    // 걷을 수 있는 구름을 누름
    final b = c.skyBoard!;
    final i = b.neighbors4(b.entrance).first;
    final r = tester.getRect(find.byKey(Key('skyTile_$i')));
    await tester.tapAt(r.topCenter + Offset(0, r.height / 3));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 600));
    expect(c.skyClimb!.wind, lessThan(wind + SkyWalkRules.springWind));
    expect(c.skyClimb!.opened.length, 2);
    for (var k = 0; k < 10; k++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}

String slotNowAm() {
  b50.now = b50.am.add(const Duration(minutes: 5));
  return slotNow;
}
