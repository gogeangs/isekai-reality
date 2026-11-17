// 묶음 50 #146: 하이랜드 (하늘에 떠오르는 섬)

import 'dart:math' as math;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/geo/geo.dart';
import 'package:isekai_reality/core/models/armory.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/models/highland_state.dart';
import 'package:isekai_reality/core/models/pet_state.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/notify/notifier.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/highland/highland_screen.dart';
import 'package:isekai_reality/features/records/records_screen.dart';
import 'package:isekai_reality/theme/top_notice.dart';

const home = GeoPoint(37.3219, 126.8309);
final day = DateTime(2026, 11, 16);
final am = HighlandRules.riseAt(day, evening: false);
final pm = HighlandRules.riseAt(day, evening: true);

class Acc {
  Acc(this.store, this.notifier);
  final InMemoryRecordStore store;
  final FakeNotifier notifier;
}

Acc account(int level,
    {Map<String, int> mats = const {},
    Map<String, dynamic>? highland,
    bool farewell = true}) =>
    Acc(
      InMemoryRecordStore(
        profile: const PlayerProfile(
            name: '하루',
            spiritName: '불씨',
            spiritKind: SpiritKind.water,
            lastSeenLevel: 99),
        history: [
          DailyRecord(date: DateTime(2026, 11, 15), gains: {
            Wallet.exp: LevelRules.totalExpToReach(level),
            Wallet.gold: 5000,
            ...mats,
          }),
        ],
        json: {
          'tutorial': {'step': TutorialStep.done.index},
          'gates': {
            'legacy': false,
            'v28': true,
            'seen': [for (final f in Feature.values) f.name],
          },
          if (farewell)
            'pets': PetState(
              pets: [
                Pet(
                    uid: 'p1',
                    species: PetSpecies.owl,
                    name: '부엉',
                    bornAt: DateTime(2026, 11, 1)),
              ],
              companion: 'p1',
              firstPet: 'p1',
              firstSpiritName: '불씨',
              farewellAt: DateTime(2026, 11, 2),
            ).toJson(),
          if (highland != null) 'highland': highland,
        },
      ),
      FakeNotifier(),
    );

DateTime now = am.add(const Duration(minutes: 5));

Future<AppController> start(Acc a, {int steps = 0}) async {
  final c = AppController(
    store: a.store,
    health: FakeHealthSource(stepsByDay: {'2026-11-16': steps}),
    notifier: a.notifier,
    clock: () => now,
  )..mailSources = const [];
  await c.init();
  return c;
}

void win(Battle b) {
  b.foeHp = 0;
  b.phase = BattlePhase.cleared;
}

void lose(Battle b) {
  b.playerHp = 0;
  b.phase = BattlePhase.failed;
}

Battle duel(Foe f) => Battle(
      playerMaxHp: 1000000,
      playerAttack: 1,
      floors: [f],
      rng: math.Random(5),
      telegraphs: true,
      heroSkills: true,
    );

void main() {
  setUp(() => now = am.add(const Duration(minutes: 5)));

  group('규칙', () {
    test('섬 다섯 · 수호자 · 결정 · 비문 (기획 문구 그대로) · 화면 문장에 숫자 없음', () {
      expect([for (final i in HighlandRules.isles) i.element], [
        Element.wind,
        Element.thunder,
        Element.light,
        Element.ice,
        Element.water,
      ]);
      expect(HighlandRules.info(Isle.wind).place, '구름 초원');
      expect([for (final i in HighlandRules.isles) Monsters.info(i.guardian).name], [
        '구름 날개 석상 기사',
        '뇌운 석상 사자',
        '정원지기 석상 거인',
        '서리 갑주 석상 기사',
        '폭포 석상 뱀',
      ]);
      expect([for (final i in HighlandRules.isles) Materials.info(i.crystal).name],
          ['구름 결정', '뇌운 핵', '햇살 이슬', '서리 결정', '폭포 진주']);
      expect(HighlandRules.isles[0].inscription,
          '구름 위에 왕국이 있었다. 바람이 길을 내고, 사람들은 그 길로 하늘을 건넜다.');
      expect(HighlandRules.isles[3].inscription,
          '어느 날 왕은 "곧 돌아오마" 하고 구름 아래로 내려갔다. 수호자들은 문을 닫지 않았다.');
      for (final i in HighlandRules.isles) {
        for (final t in [i.moveLine, Monsters.info(i.guardian).traitText]) {
          expect(RegExp(r'[0-9%×]').hasMatch(t), isFalse, reason: t);
        }
        expect(Monsters.info(i.guardian).habitat, '하이랜드 · ${i.place}');
        expect(Monsters.info(i.guardian).asset,
            'assets/images/monster_${i.guardian.name}.webp');
      }
      expect(Materials.info(MaterialId.skyFeather).asset,
          'assets/images/item_skyFeather.webp');
      expect(Materials.info(MaterialId.skyStone).asset,
          'assets/images/mat_skyStone.webp');
      expect(TitleRules.info(TitleId.skyWalker).name, '하늘을 걸은 자');
      expect(TitleRules.info(TitleId.guardianTrust).name, '수호자들이 인정한 자');
      expect(TitleRules.info(TitleId.kingdomWitness).name, '잊힌 왕국의 증인');
    });

    test('도감: 수호자 5 + 석상 병사 1이 끝 칸 · 도감 완성 칭호 개수에는 없음', () {
      final codex = Monsters.codex;
      expect([for (final m in codex.reversed.take(6)) m.id].reversed, [
        MonsterId.guardWind,
        MonsterId.guardThunder,
        MonsterId.guardLight,
        MonsterId.guardIce,
        MonsterId.guardWater,
        MonsterId.stoneSoldier,
      ]);
      for (final m in codex.reversed.take(6)) {
        expect(Monsters.inCodex(m.id), isTrue);
        expect(Monsters.all.any((x) => x.id == m.id), isFalse);
      }
    });

    test('하루 두 번 (아침·저녁) · 한 번 뜨면 1시간 · 세트 6개면 조금 더', () {
      expect(am.hour, inInclusiveRange(7, 8));
      expect(pm.hour, inInclusiveRange(18, 19));
      expect(HighlandRules.slotAt(am.subtract(const Duration(minutes: 1))), isNull);
      expect(HighlandRules.slotAt(am)?.slot, '2026-11-16-am');
      expect(HighlandRules.slotAt(am.add(const Duration(minutes: 59)))?.evening, isFalse);
      final after = am.add(const Duration(minutes: 61));
      expect(HighlandRules.slotAt(after), isNull);
      expect(HighlandRules.slotAt(after, longer: true), isNotNull);
      expect(HighlandRules.slotAt(pm.add(const Duration(minutes: 30)))?.slot,
          '2026-11-16-pm');
      expect(HighlandRules.nextRise(DateTime(2026, 11, 16, 6)), am);
      expect(HighlandRules.nextRise(am.add(const Duration(minutes: 1))), pm);
    });

    test('첫 섬은 바람 · 그 뒤 무작위 (못 쓰러뜨린 섬이 더 잘) · 아침과 저녁은 서로 다름', () {
      expect(HighlandRules.pickIsle(slot: 'x', first: true, beaten: const {}),
          Isle.wind);
      final counts = <Isle, int>{};
      for (var i = 0; i < 600; i++) {
        final s = HighlandRules.pickIsle(
            slot: 's$i', first: false, beaten: const {Isle.wind, Isle.thunder});
        counts[s] = (counts[s] ?? 0) + 1;
      }
      expect(counts[Isle.light]!, greaterThan(counts[Isle.wind]! * 2));
      for (var i = 0; i < 60; i++) {
        expect(
            HighlandRules.pickIsle(
                slot: 'p$i', first: false, beaten: const {}, avoid: Isle.ice),
            isNot(Isle.ice));
      }
    });

    test('하늘 깃털: 걸음마다 하나 · 하루 한도 · 세트 2개면 더 잘', () {
      expect(HighlandRules.feathersFor(2999), 0);
      expect(HighlandRules.feathersFor(3000), 1);
      expect(HighlandRules.feathersFor(7000), 2);
      expect(HighlandRules.feathersFor(30000), HighlandRules.featherDayCap);
      expect(HighlandRules.feathersFor(2400, set2: true), 1);
    });

    test('「하이랜드 수호 기사」: 6부위 · 부위마다 하늘 돌 + 그 부위 결정 · 2·4·6 효과', () {
      const s = BossGearRules.skySet;
      expect(s.name, '하이랜드 수호 기사');
      expect(BossGearRules.setOf(EquipBase.skyAcc), BossSet.sky);
      expect(EquipmentRules.info(EquipBase.skyWeapon).asset, 'equip_skyWeapon');
      MapEntry<MaterialId, int> crystal(EquipBase b) => BossGearRules.partCost(b)
          .mats
          .entries
          .firstWhere((e) => e.key != MaterialId.skyStone);
      expect(crystal(EquipBase.skyWeapon).key, MaterialId.stormCore);
      expect(crystal(EquipBase.skyHead).key, MaterialId.sunDew);
      expect(crystal(EquipBase.skyBody).key, MaterialId.frostCrystal);
      expect(crystal(EquipBase.skyHands).key, MaterialId.fallsPearl);
      expect(crystal(EquipBase.skyFeet).key, MaterialId.cloudCrystal);
      final acc = BossGearRules.partCost(EquipBase.skyAcc).mats;
      for (final c in HighlandRules.crystals) {
        expect(acc[c], 1);
      }
      expect(acc[MaterialId.skyStone], greaterThan(0));
      EquipItem it(EquipBase b) =>
          EquipItem(uid: b.name, base: b, grade: EquipGrade.white);
      final two = SetBonus.of([it(EquipBase.skyWeapon), it(EquipBase.skyHead)]);
      expect(two.skyFeather, isTrue);
      expect(two.skyTaken, 0);
      final six = SetBonus.of([for (final p in s.parts) it(p.$1)]);
      expect(six.skyTaken, greaterThan(0));
      expect(six.look, BossSet.sky);
      expect(six.abilities, contains(BossSetAbility.skyKnight));
    });
  });

  group('수호자 특별한 공격', () {
    Foe g(Isle i) => HighlandRules.guardianFoe(i, 20);

    test('회오리: 몇 턴 동안 두 번씩 움직인다', () {
      final b = duel(g(Isle.wind));
      b.tick();
      expect(b.whirlTurns, 0);
      b.tick();
      expect(b.lastMove, HighlandRules.info(Isle.wind).moveLine);
      expect(b.whirlTurns, HighlandRules.whirlLength - 1);
    });

    test('낙뢰: 예고 뒤 떨어진다 · 방어 태세면 거의 막는다', () {
      int strike({required bool stance}) {
        final b = duel(g(Isle.thunder));
        for (var t = 1; t <= 4; t++) {
          b.tick();
        }
        expect(b.boltComing, isTrue);
        expect(b.lastMove, HighlandRules.info(Isle.thunder).moveLine);
        b.tick();
        if (stance) b.stanceTurns = 3;
        final hp = b.playerHp;
        b.tick();
        expect(b.boltComing, isFalse);
        expect(b.lastMove,
            stance ? '방어 태세로 낙뢰를 막아 냈어요!' : '낙뢰가 떨어졌어요!');
        return hp - b.playerHp;
      }

      expect(strike(stance: true), lessThan(strike(stance: false)));
    });

    test('햇살 치유: 체력이 절반 아래면 한 번 크게 회복', () {
      final b = duel(g(Isle.light));
      b.foeHp = b.foe.maxHp ~/ 3;
      b.tick();
      expect(b.sunHealed, isTrue);
      expect(b.foeHp, greaterThan(b.foe.maxHp ~/ 3));
      expect(b.lastMove, HighlandRules.info(Isle.light).moveLine);
      final hp = b.foeHp;
      b.tick();
      expect(b.foeHp, lessThanOrEqualTo(hp));
    });

    test('서리 갑옷: 받는 피해가 줄고 · 강타로 깬다', () {
      final b = duel(g(Isle.ice));
      b.tick();
      expect(b.frosted, isTrue);
      b.bashCharge = Battle.bashTicks;
      expect(b.useBash(), isTrue);
      expect(b.frosted, isFalse);
      expect(b.lastEvent, contains('서리 갑옷이 깨졌어요'));
    });

    test('물살: 나에게 걸린 좋은 효과를 모두 씻어 낸다', () {
      final b = duel(g(Isle.water));
      b.tick();
      b.tick();
      b.rallyTurns = 3;
      b.wallTurns = 3;
      b.dodgeNext = true;
      b.tick();
      expect(b.rallyTurns, 0);
      expect(b.wallTurns, 0);
      expect(b.dodgeNext, isFalse);
      expect(b.lastMove, HighlandRules.info(Isle.water).moveLine);
    });

    test('세트 4개: 하늘 속성 공격에 받는 피해가 줄어든다', () {
      Battle fight(double t) => Battle(
          playerMaxHp: 100000,
          playerAttack: 1,
          floors: [HighlandRules.soldierFoe(Isle.ice, 20)],
          rng: math.Random(1),
          skyTaken: t)
        ..tick();
      expect(fight(0.12).lastTaken, lessThan(fight(0).lastTaken));
    });
  });

  group('계정', () {
    test('Lv.16은 아직 · Lv.17이면 아침에 첫 섬(바람)이 300~800m에 · 알림 예약', () async {
      final low = await start(account(16));
      expect(low.highlandOpen, isFalse);
      expect(low.skyIsland, isNull);

      final a = account(17);
      final c = await start(a);
      await c.refreshVitals();
      expect(c.highlandOpen, isTrue);
      await c.handleFix(const LocationFix(point: home));
      final s = c.skyIsland!;
      expect(s.isle, Isle.wind);
      expect(s.point.distanceTo(home), inInclusiveRange(290, 810));
      expect(c.skyMinutesLeft, inInclusiveRange(50, 55));
      expect(a.notifier.scheduled[NotifyId.highland]?.$1, pm);
      // 섬이 지면 사라진다
      now = am.add(const Duration(minutes: 70));
      expect(c.skyIsland, isNull);
    });

    test('첫 만남 장면은 한 번 · 넘기면 첫 펫이 주운 깃털 하나 (#124 예전 Lv.17 이상도)', () async {
      final c = await start(account(19));
      await c.handleFix(const LocationFix(point: home));
      expect(c.highlandScenePending, isTrue);
      expect(c.skyFeathers, 0);
      await c.markHighlandScene();
      expect(c.highlandScenePending, isFalse);
      expect(c.skyFeathers, 1);
      await c.markHighlandScene();
      expect(c.skyFeathers, 1);
    });

    test('걸음으로 하늘 깃털 (하루 한도까지)', () async {
      final c = await start(account(17), steps: 7200);
      await c.refreshVitals();
      expect(c.skyFeathers, 2);
      await c.refreshVitals();
      expect(c.skyFeathers, 2);
      expect(c.highland.featherGot, 2);
    });

    test('섬 아래까지 걸어가야 오름 · 깃털 하나 · 다시 도전은 무료 · 첫 한마디 · 칭호', () async {
      final c = await start(account(17, mats: {'skyFeather': 1}));
      await c.handleFix(const LocationFix(point: home));
      final s = c.skyIsland!;
      expect(c.atSkyIsland, isFalse);
      expect(await c.climbIsland(), isFalse);
      await c.handleFix(LocationFix(point: s.point));
      expect(c.atSkyIsland, isTrue);
      expect(c.canClimb, isTrue);
      expect(await c.climbIsland(), isTrue);
      expect(c.skyFeathers, 0);
      expect(c.skyIsland!.climbed, isTrue);
      expect(c.player.titles, contains(TitleId.skyWalker));
      expect(c.takeFirstClimbLine(), HighlandRules.firstClimbLine);
      expect(c.takeFirstClimbLine(), isNull);

      // 석상의 길: 이기면 하늘 돌 조각
      final sb = c.startSoldierBattle()!;
      expect(sb.foe.monster, MonsterId.stoneSoldier);
      expect(sb.foe.element, Element.wind);
      expect(sb.foe.tint, HighlandRules.info(Isle.wind).color);
      win(sb);
      final sr = await c.finishSoldierBattle(sb);
      expect(sr.won, isTrue);
      expect(c.player.materialCount(MaterialId.skyStone), inInclusiveRange(1, 2));
      expect(c.purifiedEver, contains(MonsterId.stoneSoldier));

      // 폐허의 길: 상자 · 빈손 · 깃털
      final r = (await c.searchRuins())!;
      expect(RuinsFind.values, contains(r.find));

      // 수호자에게 지면 입구로 · 다시 오르기는 깃털 없이
      await c.levelUpHeal();
      final lostB = c.startGuardianBattle()!;
      lose(lostB);
      expect((await c.finishGuardianBattle(lostB)).won, isFalse);
      expect(c.skyIsland!.cleared, isFalse);
      expect(await c.climbIsland(), isTrue);

      // 이기면 결정 둘 · 비문 1번 · 경험치 · 섬은 문을 닫는다
      await c.levelUpHeal();
      final gb = c.startGuardianBattle()!;
      expect(gb.foe.monster, MonsterId.guardWind);
      expect(gb.foe.sky, SkyMove.whirl);
      win(gb);
      final gr = await c.finishGuardianBattle(gb);
      expect(gr.won, isTrue);
      expect(gr.firstKill, isTrue);
      expect(gr.inscription, 0);
      expect(gr.exp, HighlandRules.guardianExp);
      expect(c.player.materialCount(MaterialId.cloudCrystal), 2);
      expect(c.skyIsland!.cleared, isTrue);
      expect(c.canClimb, isFalse);
      expect(c.skyInscriptions.first, HighlandRules.isles[0].inscription);
      expect(c.skyInscriptions.skip(1), everyElement(isNull));
      expect(c.bossSetOpen(BossSet.sky), isTrue);
    });

    test('저녁 섬은 아침과 다른 섬', () async {
      final c = await start(account(17));
      await c.handleFix(const LocationFix(point: home));
      expect(c.skyIsland!.isle, Isle.wind);
      now = pm.add(const Duration(minutes: 3));
      await c.handleFix(const LocationFix(point: home));
      expect(c.skyIsland!.isle, isNot(Isle.wind));
      expect(c.highland.slot, '2026-11-16-pm');
    });

    test('다섯째 수호자: 「수호자들이 인정한 자」 · 「잊힌 왕국의 증인」', () async {
      final slot = HighlandRules.slotAt(now)!.slot;
      final c = await start(account(18,
          highland: HighlandState(
            sceneSeen: true,
            starter: true,
            climbedEver: true,
            firstLine: true,
            beaten: const [0, 1, 2, 3],
            slot: slot,
            isle: Isle.water.index,
            lat: home.lat,
            lng: home.lng,
            climbed: true,
          ).toJson()));
      await c.handleFix(const LocationFix(point: home));
      expect(c.skyIsland!.isle, Isle.water);
      final b = c.startGuardianBattle()!;
      win(b);
      final r = await c.finishGuardianBattle(b);
      expect(r.titles, [TitleId.guardianTrust, TitleId.kingdomWitness]);
      expect(c.player.titles,
          containsAll([TitleId.guardianTrust, TitleId.kingdomWitness]));
      expect(c.skyInscriptions, everyElement(isNotNull));
    });

    test('대장간: 결정과 하늘 돌이 있으면 만들 수 있고 부위 속성은 그 결정의 섬', () async {
      final c = await start(account(18,
          mats: {'skyStone': 20, 'stormCore': 2},
          highland: const HighlandState(beaten: [1]).toJson()));
      expect(c.canCraftBoss(EquipBase.skyWeapon), CraftCheck.ok);
      expect(c.canCraftBoss(EquipBase.skyHead), isNot(CraftCheck.ok));
      expect(HighlandRules.partElement(EquipSlot.weapon), Element.thunder);
    });

    test('예전 기록(#124): 하이랜드 칸이 없어도 · 모르는 칸이 있어도 그대로', () {
      final h = HighlandState.fromJson(const {});
      expect(h.beaten, isEmpty);
      expect(h.firstIsle, isTrue);
      final back = HighlandState.fromJson({
        ...const HighlandState(
                beaten: [0, 2], slot: '2026-11-16-am', isle: 0, featherGot: 2)
            .toJson(),
        'future': 1,
      });
      expect(back.beaten, [0, 2]);
      expect(back.slot, '2026-11-16-am');
      expect(back.featherGot, 2);
    });
  });

  testWidgets('섬 화면: 오르기 → 갈림길 둘 → 폐허 → 다음 · 기록 탭 비문', (tester) async {
    tester.view.physicalSize = const Size(750, 1334);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    late AppController c;
    await tester.runAsync(() async {
      c = await start(account(17, mats: {'skyFeather': 2}));
      await c.handleFix(const LocationFix(point: home));
      await c.handleFix(LocationFix(point: c.skyIsland!.point));
    });
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => TopNoticeHost(child: child!),
        home: HighlandScreen(controller: c)));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('하늘 깃털 1개로 오르기'), findsOneWidget);
    expect(find.byKey(const Key('skyEntryArt')), findsOneWidget);
    await tester.tap(find.byKey(const Key('skyClimb')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 200));
    expect(c.highland.firstLine, isTrue);
    expect(find.byKey(const Key('skyStep_1')), findsOneWidget);
    expect(find.byKey(const Key('skyForkStone')), findsOneWidget);
    expect(find.byKey(const Key('skyForkRuins')), findsOneWidget);
    await tester.tap(find.byKey(const Key('skyForkRuins')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const Key('skyForkResult')), findsOneWidget);
    await tester.tap(find.byKey(const Key('skyNext')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const Key('skyForkRuins')), findsOneWidget);
    expect(c.skyFeathers, inInclusiveRange(1, 2));

    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: RecordsScreen(
                player: c.player,
                skyStones: [HighlandRules.isles[0].inscription, null, null, null, null]))));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.scrollUntilVisible(find.byKey(const Key('skyStone_4')), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const Key('skyStoneRecords')), findsOneWidget);
    expect(find.byKey(const Key('skyStone_4')), findsOneWidget);
    await tester.pump(const Duration(seconds: 9));
  });
}
