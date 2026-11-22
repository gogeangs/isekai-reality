import 'dart:math' as math;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/features/act2/ash_turn_view.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/geo/geo.dart';
import 'package:isekai_reality/core/models/act2_state.dart';
import 'package:isekai_reality/core/models/armory.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/act2/ash_battle_screen.dart';
import 'package:isekai_reality/features/map/ansan_area.dart';

void main() {
  final t0 = DateTime(2026, 11, 15, 10);
  const home = GeoPoint(37.3219, 126.8309);

  InMemoryRecordStore account(int level, {Map<String, dynamic>? act2}) =>
      InMemoryRecordStore(
        profile: const PlayerProfile(
            name: '하루',
            spiritName: '불씨',
            spiritKind: SpiritKind.water,
            lastSeenLevel: 99),
        history: [
          DailyRecord(
            date: DateTime(2026, 11, 14),
            gains: {'exp': LevelRules.totalExpToReach(level)},
          ),
        ],
        json: {
          'tutorial': {'step': TutorialStep.done.index},
          if (act2 != null) 'act2': act2,
        },
      );

  Future<AppController> start(InMemoryRecordStore store) async {
    final c = AppController(
      store: store,
      health: FakeHealthSource(stepsByDay: const {}),
      clock: () => t0,
    )..mailSources = const [];
    await c.init();
    return c;
  }

  Battle win(AppController c, Battle b) {
    // 테스트: 몬스터 체력을 1로 두고 끝까지
    b.foeHp = 1;
    for (var i = 0; i < 200 && !b.isOver; i++) {
      b.foeHp = math.min(b.foeHp, 1);
      b.tick();
    }
    return b;
  }

  group('2막 흐름', () {
    test('Lv.12부터 2레벨마다, 순서대로만', () {
      expect(Act2Rules.nextAvatar(beaten: 0, level: 11), isNull);
      expect(Act2Rules.nextAvatar(beaten: 0, level: 12), AshAvatar.rage);
      expect(Act2Rules.nextAvatar(beaten: 0, level: 30), AshAvatar.rage);
      expect(Act2Rules.nextAvatar(beaten: 1, level: 13), isNull);
      expect(Act2Rules.nextAvatar(beaten: 1, level: 14), AshAvatar.sorrow);
      expect(Act2Rules.nextAvatar(beaten: 4, level: 20), AshAvatar.lonely);
      expect(Act2Rules.nextAvatar(beaten: 5, level: 30), isNull);
      expect([for (final a in Act2Rules.avatars) a.level], [12, 14, 16, 18, 20]);
      expect([for (final a in Act2Rules.avatars) a.element], [
        Element.fire,
        Element.water,
        Element.metal,
        Element.dark,
        Element.wind,
      ]);
    });

    test('특별한 공격 문장·사연·칭호는 숫자 없이', () {
      for (final a in Act2Rules.avatars) {
        for (final t in [a.moveLine, a.kingLine, a.story, a.name]) {
          expect(RegExp(r'[0-9%×]').hasMatch(t), isFalse, reason: t);
        }
        expect(TitleRules.info(a.title).name, isNotEmpty);
      }
      expect(TitleRules.info(TitleId.ashRage).name, '분노를 잠재운 자');
      expect(TitleRules.info(TitleId.ashLonely).name, '외로움을 안아 준 자');
      expect(TitleRules.info(TitleId.bridgeMaker).name, '다리를 놓은 자');
    });

    test('분신은 그 레벨 던전 보스보다 조금 세다', () {
      final boss = BattleRules.dungeonFloors(
              level: 12, atGate: false, rng: math.Random(1))
          .last;
      final rage = Act2Rules.avatarFoe(AshAvatar.rage, 12);
      expect(rage.maxHp, greaterThan(boss.maxHp));
      expect(rage.attack, greaterThan(boss.attack));
      expect(rage.isBoss, isTrue);
      expect(rage.element, Element.fire);
      final king = Act2Rules.kingFoes(20);
      expect(king.length, 5);
      expect([for (final f in king) f.element],
          [for (final a in Act2Rules.avatars) a.element]);
      expect(Act2Rules.kingFoes(20, from: 3).length, 2);
    });

    test('잿빛 틈 자리: 300~800m, 하루 고정', () {
      const area = AnsanArea.area;
      final a = Act2Rules.riftSpot(area, dayKey: '2026-11-15', anchor: home, avatar: 0);
      final b = Act2Rules.riftSpot(area, dayKey: '2026-11-15', anchor: home, avatar: 0);
      final next = Act2Rules.riftSpot(area, dayKey: '2026-11-16', anchor: home, avatar: 0);
      expect(a.lat, b.lat);
      expect(a.distanceTo(home), inInclusiveRange(290, 810));
      expect(next.lat == a.lat && next.lng == a.lng, isFalse);
    });
  });

  group('특별한 공격', () {
    Battle make(Foe f) => Battle.forPlayer(
          level: 16,
          stats: Stats.all(25),
          floors: [f],
          rng: math.Random(3),
          heroSkills: true,
          telegraphs: true,
        );

    test('겁주기: 한 턴 동안 스킬 버튼이 잠긴다', () {
      final b = make(const Foe(
          monster: MonsterId.ashFear,
          maxHp: 1000000,
          attack: 1,
          move: AshMove.fear));
      var locked = false;
      for (var i = 0; i < 6; i++) {
        b.tick();
        if (b.skillsLocked) {
          locked = true;
          expect(b.lastMove, Act2Rules.info(AshAvatar.fear).moveLine);
          expect(b.useJobSkill(JobSkill.rush), isFalse);
          b.tick();
          expect(b.skillsLocked, isFalse);
          break;
        }
      }
      expect(locked, isTrue);
    });

    test('고립: 그동안 펫 게이지가 멈춘다', () {
      final b = make(const Foe(
          monster: MonsterId.ashLonely,
          maxHp: 1000000,
          attack: 1,
          move: AshMove.isolate));
      for (var i = 0; i < 3; i++) {
        b.tick();
      }
      expect(b.isolated, isTrue);
      final before = b.skillCharge;
      b.tick();
      expect(b.skillCharge, before);
    });

    test('빼앗기: 좋은 효과를 빼앗고 세진다', () {
      final b = make(const Foe(
          monster: MonsterId.ashGreed,
          maxHp: 1000000,
          attack: 1,
          move: AshMove.steal));
      for (var i = 0; i < 3; i++) {
        b.tick();
      }
      b.rallyTurns = 3;
      b.tick(); // 4번째 턴
      expect(b.rallyTurns, 0);
      expect(b.stolenTurns, greaterThan(0));
    });

    test('눈물비: 그사이 스스로 회복', () {
      final b = make(const Foe(
          monster: MonsterId.ashSorrow,
          maxHp: 1000000,
          attack: 1,
          move: AshMove.tears));
      for (var i = 0; i < 3; i++) {
        b.tick();
      }
      expect(b.tearTurns, greaterThan(0));
    });

    test('분노 폭발: 체력이 줄면 문장이 나온다', () {
      final b = make(const Foe(
          monster: MonsterId.ashRage,
          maxHp: 1000000,
          attack: 1,
          move: AshMove.rage));
      b.foeHp = 300000;
      b.tick();
      expect(b.lastMove, Act2Rules.info(AshAvatar.rage).moveLine);
    });
  });

  group('유품 세트', () {
    test('2·4·6개: 잿빛 몬스터에게 받는 피해↓ 주는 피해↑', () {
      EquipItem item(EquipBase b) =>
          EquipItem(uid: b.name, base: b, grade: EquipGrade.white);
      final parts = [for (final p in BossGearRules.relicSet.parts) item(p.$1)];
      expect(SetBonus.of(parts.take(2)).ashTaken, greaterThan(0));
      expect(SetBonus.of(parts.take(2)).ashDealt, 0);
      expect(SetBonus.of(parts.take(4)).ashDealt, greaterThan(0));
      final six = SetBonus.of(parts);
      expect(six.ashDealt, greaterThan(SetBonus.of(parts.take(4)).ashDealt));
      expect(six.ashTaken, greaterThan(SetBonus.of(parts.take(4)).ashTaken));
      expect(six.look, BossSet.ash);
      expect(BossGearRules.setOf(EquipBase.ashCrown), BossSet.ash);
      expect(EquipmentRules.info(EquipBase.ashCrown).slot, EquipSlot.head);
      expect(EquipmentRules.info(EquipBase.ashWeapon).asset, 'equip_ashWeapon');
      // 대장간에서 만드는 세트 목록에는 없다
      expect(BossGearRules.sets.any((s) => s.id == BossSet.ash), isFalse);
    });
  });

  group('#124 예전 기록', () {
    test('Lv.12 이상 예전 계정: 분노부터 하나씩, 진행은 저장', () async {
      final store = account(17);
      final c = await start(store);
      expect(c.nextAvatar, AshAvatar.rage);
      await c.handleFix(const LocationFix(point: home));
      final rift = c.riftPoint;
      expect(rift, isNotNull);
      expect(rift!.distanceTo(home), inInclusiveRange(290, 810));

      final b = c.startAshBattle()!;
      expect(b.floors.single.monster, MonsterId.ashRage);
      win(c, b);
      expect(b.phase, BattlePhase.cleared);
      final r = await c.finishAshBattle(b);
      expect(r.won, isTrue);
      expect(r.firstKill, isTrue);
      expect(r.item?.base, EquipBase.ashWeapon);
      expect(r.egg, isTrue);
      expect(c.player.titles, contains(TitleId.ashRage));
      expect(c.kingStories.length, 1);
      // 숨은 직업 「잿빛 사냥꾼」 조건
      expect(c.player.today?.counters['ashClone'], 1);
      expect(c.nextAvatar, AshAvatar.sorrow);

      // 껐다 켜도 이어진다 (다른 분신이 한꺼번에 열리지 않음)
      final again = await start(store);
      expect(again.act2.beaten, 1);
      expect(again.nextAvatar, AshAvatar.sorrow);
      expect(again.armory.items.any((i) => i.base == EquipBase.ashWeapon), isTrue);
    });

    test('하루 세 번 지면 내일 다시', () async {
      final store = account(12);
      final c = await start(store);
      for (var i = 0; i < 3; i++) {
        await c.levelUpHeal();
        final b = c.startAshBattle()!;
        b.playerHp = 0;
        b.phase = BattlePhase.failed;
        await c.finishAshBattle(b);
      }
      expect(c.riftClosedToday, isTrue);
      expect(c.startAshBattle(), isNull);
      expect(c.act2.beaten, 0);
    });

    test('본체: 지면 걷어낸 단계부터, 이기면 결말·왕관·칭호', () async {
      final store = account(15, act2: const Act2State(beaten: 5).toJson());
      final c = await start(store);
      expect(c.kingOpen, isTrue);
      final b = c.startKingBattle()!;
      expect(b.floors.length, 5);
      // 두 단계를 걷어내고 진다
      b.floor = 2;
      b.foeHp = b.foe.maxHp;
      b.playerHp = 0;
      b.phase = BattlePhase.failed;
      final lost = await c.finishKingBattle(b);
      expect(lost.won, isFalse);
      expect(c.act2.kingPhase, 2);

      await c.levelUpHeal();
      final again = c.startKingBattle()!;
      expect(again.floors.length, 3);
      again.floor = 2;
      again.foeHp = 1;
      again.phase = BattlePhase.cleared;
      final r = await c.finishKingBattle(again);
      expect(r.won, isTrue);
      expect(c.endingPending, isTrue);
      expect(c.player.titles, contains(TitleId.bridgeMaker));
      expect(c.armory.items.any((i) => i.base == EquipBase.ashCrown), isTrue);
      // Lv.21 전이면 다리 안내는 아직
      await c.markEndingSeen();
      expect(c.bridgePending, isFalse);
      final reopened = await start(store);
      expect(reopened.endingPending, isFalse);
      expect(reopened.kingOpen, isFalse);
    });
  });

  test('결말 대사: 이름·조사 맞춤', () {
    final lines = Act2Rules.ending(
        hero: '하루', spirit: '불씨', pet: '부엉', female: true);
    expect(lines[1].image, contains('_female'));
    expect(lines[2].speaker, '하루');
    expect(lines[4].top, isTrue);
    expect(lines[5].line, '저 빛… 불씨야. 문이 다리가 됐어도, 불씨는 여기 있었구나.');
    final m = Act2Rules.ending(hero: '하루', spirit: '이슬빛', pet: '부엉', female: false);
    expect(m[5].line, contains('이슬빛이야'));
    expect(m[5].line, contains('이슬빛은'));
    expect(m[1].image, isNot(contains('_female')));
  });

  group('화면', () {
    void phone(WidgetTester tester) {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
    }

    testWidgets('잿빛 틈: 입장 → 턴제 전투(묶음 82) → 이기면 결과 · 사연은 다시 보기에서', (tester) async {
      phone(tester);
      late AppController c;
      await tester.runAsync(() async => c = await start(account(12)));
      await tester.pumpWidget(MaterialApp(
          home: AshBattleScreen(
              controller: c, tickInterval: const Duration(milliseconds: 20))));
      await tester.pump();
      expect(find.byKey(const Key('ashEntryArt')), findsOneWidget);
      expect(find.text('오늘 남은 도전 3번'), findsOneWidget);
      await tester.tap(find.byKey(const Key('ashEnter')));
      await tester.pump();
      expect(find.byType(AshTurnView), findsOneWidget);
      final t = tester.widget<AshTurnView>(find.byType(AshTurnView)).turn;
      t.foeHp = 1;
      await tester.tap(find.byKey(const Key('ashCmd_attack')));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 250));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      }
      expect(t.won, isTrue);
      expect(find.byKey(const Key('ashBack')), findsOneWidget);
      expect(find.byKey(const Key('ashStoryAgain')), findsOneWidget);
      expect(c.act2.beaten, 1);
    });

    testWidgets('결말: 건너뛰기 없이 7줄 → 보상', (tester) async {
      phone(tester);
      late AppController c;
      await tester.runAsync(() async => c = await start(account(22,
          act2: const Act2State(beaten: 5, kingPhase: 5, kingDone: true)
              .toJson())));
      expect(c.endingPending, isTrue);
      await tester.pumpWidget(MaterialApp(home: EndingScreen(controller: c)));
      await tester.pump();
      for (var i = 0; i < 7; i++) {
        expect(find.byKey(const Key('endingReward')), findsNothing);
        await tester.tapAt(const Offset(200, 300));
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(find.byKey(const Key('endingReward')), findsOneWidget);
      expect(find.byKey(const Key('bridgeLine')), findsOneWidget);
      expect(c.endingPending, isFalse);
      expect(c.bridgePending, isFalse);
      await tester.pump(const Duration(seconds: 3));
    });
  });
}
