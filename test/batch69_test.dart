// 묶음 69: 68 확인 답 · #279 공성전 스위치 · #280 #281 레벨 단계 몬스터 · #282 #285 부화장 · #283 #286 #290 마을 · #287~#289 말풍선 · #284 정령 이별
// (서버 판정은 node 시험 siege69.test.js · review_seed.test.js)

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/geo/geo.dart';
import 'package:isekai_reality/core/models/act5_state.dart';
import 'package:isekai_reality/core/models/pet_state.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/features/act5/erbard_screens.dart';
import 'package:isekai_reality/features/map/korea_area.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'batch52_test.dart' as b52;
import 'batch56_test.dart' as b56;
import 'batch60_test.dart' as b60;
import 'support/village_seed.dart';

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

  group('#280 #281 레벨 단계 지도 몬스터', () {
    const area = KoreaArea.area;
    const home = GeoPoint(37.3219, 126.8309);
    final day = DateTime(2026, 11, 20, 12); // 낮 12시
    // 수식어 등급은 보는 사람 레벨로 나누므로(예전 그대로) 같은 [level] 로, 몬스터 단계만 [tier] 로
    List<FieldSpawn> at(int tier, {DateTime? t, LandKind? land}) => FieldMonsterRules.spawnsFor(area, t ?? day,
        center: home, radiusM: 6000, level: 5, tierLevel: tier, land: land == null ? null : (_) => land);

    test('단계: Lv.1~10 · 11~20 · 21~30 · 31~49 · 50~', () {
      expect([1, 10, 11, 20, 21, 30, 31, 49, 50, 80].map(FieldMonsterRules.tierOf), [1, 1, 2, 2, 3, 3, 4, 4, 5, 5]);
    });

    test('자리 · 수식어는 누구에게나 같고 몬스터 종류만 보는 사람 단계 · 섞는 비율 60 · 30 · 10', () {
      final a = at(5), b = at(35);
      expect(b.map((s) => s.id), a.map((s) => s.id));
      expect(b.map((s) => s.point.lat), a.map((s) => s.point.lat));
      expect([for (final s in b) s.modifiers], [for (final s in a) s.modifiers]);
      final t4 = {...FieldMonsterRules.tierLand(4, null)};
      final t3 = {...FieldMonsterRules.tierLand(3, null)};
      final n4 = b.where((s) => t4.contains(s.monster)).length / b.length;
      final n3 = b.where((s) => t3.contains(s.monster)).length / b.length;
      final n1 = b.where((s) => !FieldMonsterRules.isTierMonster(s.monster)).length / b.length;
      expect(n4, closeTo(0.6, 0.08));
      expect(n3, closeTo(0.3, 0.08));
      expect(n1, closeTo(0.1, 0.06));
      expect(a.every((s) => !FieldMonsterRules.isTierMonster(s.monster)), isTrue, reason: 'Lv.5 는 지금 그대로');
    });

    test('장소별 몬스터 · 밤 몬스터 (그림자 나비 자리)', () {
      final forest = at(25, land: LandKind.forest);
      final t3 = forest.where((s) => FieldMonsterRules.tierOf(25) == 3 && FieldMonsterRules.tierLand(3, LandKind.forest).contains(s.monster));
      expect(t3, isNotEmpty);
      expect(forest.any((s) => s.monster == MonsterId.orcMerc), isFalse, reason: '숲엔 오크 용병(마을 · 도시 · 산)이 안 나옴');
      final night = at(15, t: DateTime(2026, 11, 20, 22)); // 밤 10시
      expect(night.any((s) => s.monster == MonsterId.vampireBat), isTrue);
    });

    test('Lv.50: 새 13종 · 바실리스크 약 3% · 그림이 없으면 4단계 몬스터로', () {
      final s = at(55);
      final t5 = {...FieldMonsterRules.tierLand(5, null)};
      expect(s.where((x) => t5.contains(x.monster)).length / s.length, closeTo(0.57, 0.08));
      final bas = s.where((x) => x.monster == MonsterId.basilisk).length / s.length;
      expect(bas, inInclusiveRange(0.01, 0.06));
      expect(FieldMonsterRules.tierMonsters.where((m) => m.index >= MonsterId.doppelganger.index), hasLength(13));
      Monsters.knownAssets = {'assets/images/monster_ogre.webp'};
      addTearDown(() => Monsters.knownAssets = null);
      final noArt = at(55);
      expect(noArt.any((x) => x.monster.index >= MonsterId.doppelganger.index), isFalse);
      expect(noArt.where((x) => x.monster == MonsterId.ogre).length / noArt.length, greaterThan(0.5));
    });

    test('특정 몬스터 부탁: 높은 단계면 그 단계의 비슷한 몬스터로 · 「필드 몬스터 ○마리」는 그대로', () {
      expect(FieldMonsterRules.askFor(MonsterId.ashSlime, 5), MonsterId.ashSlime);
      expect(FieldMonsterRules.askFor(MonsterId.ashSlime, 15), MonsterId.goblinRaider);
      final slime = BoardRules.errands.firstWhere((t) => t.id == 'slime3');
      final hi = BoardRules.forLevel(slime, 15);
      expect(hi.title, '고블린 약탈자 3마리 사냥');
      expect(hi.counter, 'hunt:goblinRaider');
      expect(BoardRules.forLevel(slime, 8).title, '슬라임 3마리 사냥');
    });

    test('특성: 도플갱어 첫 공격 따라 하기 · 바실리스크 돌 굳히기 · 웨어울프 보름달', () {
      expect(Monsters.info(MonsterId.doppelganger).trait, MonsterTrait.mirror);
      expect(Monsters.info(MonsterId.basilisk).trait, MonsterTrait.petrify);
      expect(Monsters.info(MonsterId.werewolf).trait, MonsterTrait.moon);
      expect(Monsters.info(MonsterId.sphinx).preLine, isNotNull);
      expect(FieldMonsterRules.isFullMoon(DateTime.utc(2026, 11, 24, 15)), isTrue); // 2026-11-24 보름
      expect(FieldMonsterRules.isFullMoon(DateTime.utc(2026, 11, 9)), isFalse);
      for (final m in FieldMonsterRules.tierMonsters) {
        expect(LootRules.dropsOf(m).common, isNot(contains(MaterialId.slimeJelly)), reason: '$m');
      }
    });
  });

  group('#282 #283 #286 #290', () {
    test('품는 중인 알은 가방 칸에서 빠짐 (안 품은 알은 그대로)', () async {
      final c = await startVillage(11, farewell: true, more: {
        'pets': PetState(
          pets: [Pet(uid: 'p1', species: PetSpecies.owl, name: '부엉', bornAt: DateTime(2026, 11, 1))],
          companion: 'p1',
          firstPet: 'p1',
          firstSpiritName: '불씨',
          farewellAt: DateTime(2026, 11, 2),
          eggs: [PetEgg(id: 'e1', source: 'field', incubatedAt: vt0), const PetEgg(id: 'e2', source: 'field')],
          nextId: 3,
        ).toJson(),
      });
      expect(c.bagUsed, 1);
    });

    test('2막 마을 대사 · 부탁은 게시판에서 (새 부탁 · 「게시판에 부탁 하나 붙여 뒀어!」)', () {
      expect(HarvestRules.prophecy[1].$2, '잿빛… 그 잿빛 틈이랑 같은 색이야. 설마…');
      expect(NpcRules.boardAskLine, '게시판에 부탁 하나 붙여 뒀어!');
    });
  });
}
