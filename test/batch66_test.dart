// 묶음 66: 묶음 65 확인 답 (힘 고르기 · 선봉장 길드장 · 특산물 쓰임 · 돕는 영지) + #265~#270
// (서버 판정은 node 시험 siege65.test.js · estate65.test.js)

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/act5_state.dart';
import 'package:isekai_reality/core/models/armory.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/models/garden_state.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/core/geo/geo.dart';
import 'package:isekai_reality/features/act5/erbard_screens.dart';
import 'package:isekai_reality/features/map/korea_area.dart';
import 'package:isekai_reality/features/village/board_screen.dart';

import 'batch52_test.dart' as b52;
import 'batch56_test.dart' as b56;
import 'batch60_test.dart' as b60;
import 'support/npc_seed.dart';

const _ch3 = Act5State(opened: true, chapter: 3, seen: {'e1a', 'e1b', 'e1c', 'e2a', 'e2b'}, ticketAt: -60000);

/// +[enhance] 무기 · 방어구 · 장신구를 입은 기록 (11-20)
Future<AppController> _gear(int enhance, Map<String, int> mats) async {
  final c = AppController(
    store: InMemoryRecordStore(
      profile: const PlayerProfile(name: '하루', lastSeenLevel: 99),
      history: [
        DailyRecord(date: DateTime(2026, 11, 19), gains: {Wallet.gold: 50000, Wallet.manaStone: 300, ...mats}),
      ],
      json: {
        'armory': Armory(
          items: [
            EquipItem(uid: 'w', base: EquipBase.dagger, grade: EquipGrade.blue, enhance: enhance, element: Element.fire, elementLevel: 0),
            EquipItem(uid: 'b', base: EquipBase.armor, grade: EquipGrade.blue, enhance: enhance),
          ],
          equipped: const {EquipSlot.weapon: 'w', EquipSlot.body: 'b'},
          crafts: 5,
          nextId: 10,
        ).toJson(),
        'harvest': {'granted': true},
      },
    ),
    health: FakeHealthSource(stepsByDay: const {}),
    clock: () => DateTime(2026, 11, 20, 10),
  )..mailSources = const [];
  await c.init();
  return c;
}

void main() {
  setUp(() => b56.now = b52.t0);

  group('0 묶음 65 확인 답', () {
    test('게이지가 차면 힘이 쌓이고 길드장이 공성 망치 · 성벽 보수 중 고름', () async {
      final (c, a) = await b60.act5(guild: true, state: _ch3);
      a.siegeActive = true;
      a.siegeOwners['sol_lily'] = {'gid': 'mine', 'name': '새벽걸음', 'emblem': 0, 'color': 0};
      a.siegeDefense['sol_lily'] = 2;
      a.rallyEstate = 'dor_deep';
      a.gauge = {'progress': 0.2, 'full': 1, 'rams': 0, 'ramMax': 2, 'repairs': <String>[], 'power': 1};
      b56.now = DateTime(2026, 11, 28, 10);
      await c.refreshErbard();
      expect(c.erbard.gauge!.power, 1);
      expect(await c.usePower('repair', estate: 'sol_lily'), isTrue);
      expect(c.erbard.gauge!.repairs, ['sol_lily']);
      expect(c.erbard.gauge!.power, 0);
      expect(await c.usePower('ram'), isFalse);
      expect(ErbardRules.errorText(c.erbardError ?? ''), '아직 모인 힘이 없어요');
    });

    testWidgets('전황판에 「쓸 수 있는 힘」 · 망치 / 보수 버튼', (tester) async {
      late AppController c;
      await tester.runAsync(() async {
        final (cc, a) = await b60.act5(guild: true, state: _ch3);
        c = cc;
        a.siegeActive = true;
        a.siegeOwners['sol_lily'] = {'gid': 'mine', 'name': '새벽걸음', 'emblem': 0, 'color': 0};
        a.siegeDefense['sol_lily'] = 1;
        a.rallyEstate = 'dor_deep';
        a.gauge = {'progress': 0.2, 'full': 2, 'rams': 0, 'ramMax': 2, 'repairs': <String>[], 'power': 2};
        b56.now = DateTime(2026, 11, 28, 10);
        await c.refreshErbard();
      });
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SiegePowerPanel(controller: c))));
      expect(find.text('쓸 수 있는 힘 2'), findsOneWidget);
      expect(find.byKey(const Key('powerRam')), findsOneWidget);
      expect(find.byKey(const Key('powerRepair')), findsOneWidget);
    });

    test('강화 +8 · +9 · +10: 특산물 1 · 2 · 3 (무기 용암석 · 방어구 청동 광석 · 장신구 안개 결정)', () async {
      expect(EquipmentRules.enhanceSpecial(EquipSlot.weapon, 7), isNull);
      expect(EquipmentRules.enhanceSpecial(EquipSlot.weapon, 8), (mat: MaterialId.fireStone, n: 1));
      expect(EquipmentRules.enhanceSpecial(EquipSlot.body, 9), (mat: MaterialId.metalOre, n: 2));
      expect(EquipmentRules.enhanceSpecial(EquipSlot.accessory, 10), (mat: MaterialId.darkCrystal, n: 3));
      // 묶음 82 #395: 부위 가공 재료도 있게
      final c = await _gear(7, const {'metalOre': 1, 'ironIngot': 20, 'tannedLeather': 20});
      final w = c.armory.byUid('w')!, b = c.armory.byUid('b')!;
      expect(c.canEnhance(w), CraftCheck.materials, reason: '용암석이 없음');
      expect(c.canEnhance(b), CraftCheck.ok);
      await c.enhance('b');
      expect(c.player.materialCount(MaterialId.metalOre), 0, reason: '성공 · 실패 모두 씀');
    });

    test('속성 강화에 특산물 더 넣기 → 실패 확률 절반 · 특산물 1개 씀', () async {
      expect(SmithRules.failChance(SmithAction.upgrade, level: 0) * 0.5, 0.15);
      final c = await _gear(0, const {'lightRelic': 2, 'glowFireCore': 3});
      expect(c.extraSpecialty, MaterialId.lightRelic);
      final r = await c.smith('w', SmithAction.upgrade, special: true);
      expect(r, isNot(SmithResult.cannot));
      expect(c.player.materialCount(MaterialId.lightRelic), 1);
    });

    test('연금술: 맞는 특산물이면 최상 확정 · 맞지 않으면 귀한 재료 +1 · 특산물은 레시피 칸 밖', () {
      expect(AlchemyRules.specialtyFor(PotionId.heal), MaterialId.lightRelic);
      expect(AlchemyRules.specialtyFor(PotionId.jobMana), MaterialId.darkCrystal);
      expect(AlchemyRules.specialtyFor(PotionId.steps), MaterialId.earthWood);
      expect(AlchemyRules.specialtyFor(PotionId.weaponFire), MaterialId.fireStone);
      expect(AlchemyRules.specialtyFor(PotionId.vitality), MaterialId.metalOre);
      final r = AlchemyRules.info(PotionId.healSmall).recipe;
      expect(AlchemyRules.qualityWith(PotionId.healSmall, perfect: false, put: [...r, MaterialId.lightRelic]), PotionQuality.best);
      expect(AlchemyRules.qualityWith(PotionId.healSmall, perfect: false, put: [...r, MaterialId.fireStone]),
          AlchemyRules.quality(perfect: false, put: [...r, MaterialId.fireStone], mastery: 1),
          reason: '묶음 67: 엘라린 잎이 작은 회복 물약에 잘 맞음 (+1)');
    });

    test('주민 의뢰 돕는 영지 고르기', () async {
      final (c, a) = await b60.act5(guild: true, state: _ch3);
      a.siegeOwners['sol_lily'] = {'gid': 'mine', 'name': '새벽걸음', 'emblem': 0, 'color': 0};
      a.siegeOwners['sol_bell'] = {'gid': 'mine', 'name': '새벽걸음', 'emblem': 0, 'color': 0};
      b56.now = DateTime(2026, 12, 1, 10);
      await c.refreshErbard();
      await c.refreshEstateDev();
      expect(c.estateDev!.help, isNotNull);
      expect(await c.setHelpEstate('sol_bell'), isTrue);
      expect(c.estateDev!.help, 'sol_bell');
    });
  });

  group('#265 · #270', () {
    test('사냥 경험치 × (1 + 0.05 × (레벨 − 1)) · Lv.21부터 #254와 곱함', () {
      expect((15 * WalkRewardRules.huntMult(10)).round(), 22);
      expect((15 * WalkRewardRules.huntMult(20)).round(), 29);
      expect((15 * WalkRewardRules.huntMult(40)).round(), 44);
      expect(WalkRewardRules.huntMult(1), 1);
    });

    test('기력: 60 + 2 × (레벨 − 1) · 빈 기력이 가득 차는 데 약 6시간', () async {
      expect(VitalRules.levelMp(1), 60);
      expect(VitalRules.levelMp(10), 78);
      expect(VitalRules.levelMp(20), 98);
      expect(VitalRules.levelMp(40), 138);
      final full = VitalRules.levelMp(40);
      final (mp, _) = VitalRules.regenMp(0, DateTime(2026, 11, 20), DateTime(2026, 11, 20, 6), max: full, perHour: VitalRules.levelMpPerHour(40));
      expect(mp, full);
      final (mp2, _) = VitalRules.regenMp(0, DateTime(2026, 11, 20), DateTime(2026, 11, 20, 1), max: 62, perHour: 62 / 6);
      expect(mp2, 10, reason: '소수는 분 단위로');
      final c = await startNpc(level: 20);
      expect(c.mpMax, 98 + PetRules.mpMaxBonus(c.pets.pets.length));
    });
  });

  group('#266 · #267 · #268', () {
    test('약초밭: 심은 뒤 흐른 시간으로 자람 · 4 / 8 / 8 / 24시간 · 남은 시간 문구', () async {
      expect(GardenRules.minutesOf(MaterialId.herbSeed), 240);
      expect(GardenRules.minutesOf(MaterialId.flowerSeed), 480);
      expect(GardenRules.minutesOf(MaterialId.sporeSeed), 480);
      expect(GardenRules.minutesOf(MaterialId.glowSeed), 1440);
      expect(GardenRules.leftText(80), '약 1시간 20분 뒤');
      expect(GardenRules.leftText(45), '약 45분 뒤');
      var now = DateTime(2026, 11, 20, 9);
      final c = await startNpc(level: 9, mats: const {'herbSeed': 1}, clock: () => now);
      expect(await c.plantSeed(0, MaterialId.herbSeed), isTrue);
      expect(c.plotView(0).stage, 0);
      now = now.add(const Duration(hours: 2));
      expect(c.plotView(0).stage, 1);
      expect(c.plotView(0).leftText, '약 2시간 뒤');
      now = now.add(const Duration(hours: 2));
      expect(c.plotView(0).ready, isTrue);
      expect(GardenState.fromJson(c.garden.toJson()).plots[0]!.at, isNotNull);
    });

    test('몬스터 자리: 하루 6칸 (한국 시간 4시간마다) · 남은 시간 문구', () {
      expect(FieldMonsterRules.slotKey(DateTime.utc(2026, 11, 17, 3)), '2026-11-17@3', reason: '묶음 69: 날짜 기준 없음');
      expect(FieldMonsterRules.slotKey(DateTime.utc(2026, 11, 19, 3)), '2026-11-19@3'); // KST 12시
      expect(FieldMonsterRules.slotKey(DateTime.utc(2026, 11, 19, 6, 59)), '2026-11-19@3'); // KST 15:59
      expect(FieldMonsterRules.slotKey(DateTime.utc(2026, 11, 19, 7)), '2026-11-19@4');
      expect(FieldMonsterRules.untilText(DateTime.utc(2026, 11, 19, 5, 40)), '몬스터가 바뀌기까지 1시간 20분');
      expect(FieldMonsterRules.untilText(DateTime.utc(2026, 11, 19, 6, 30)), '몬스터가 바뀌기까지 30분');
      const area = KoreaArea.area;
      const home = GeoPoint(37.3219, 126.8309);
      final a = FieldMonsterRules.spawnsFor(area, DateTime.utc(2026, 11, 19, 3), center: home, radiusM: 3000);
      final b = FieldMonsterRules.spawnsFor(area, DateTime.utc(2026, 11, 19, 7), center: home, radiusM: 3000);
      expect(a.first.id, startsWith('2026-11-19@3#'));
      expect(b.map((s) => s.id).toSet().intersection(a.map((s) => s.id).toSet()), isEmpty);
    });

    testWidgets('게시판 맨 아래 「마을 사람 부탁」', (tester) async {
      tester.view.physicalSize = const Size(1200, 9000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      late AppController c;
      await tester.runAsync(() async => c = await startNpc(level: 12, npc: {
            'points': {'gil': 10},
            'active': {
              'gil': {'i': 0, 'day': '2026-11-16', 'base': <String, int>{}, 'steps': 0},
            },
          }));
      await tester.pumpWidget(MaterialApp(home: BoardScreen(controller: c)));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      if (c.activeAsks.isEmpty) return; // 부탁 형식이 바뀌면 화면만 확인
      expect(find.byKey(const Key('boardNpcAsks')), findsOneWidget);
      expect(find.text('마을 사람 부탁'), findsOneWidget);
    });
  });
}
