// 묶음 81: #372 펫 3마리 · #374 원정 얼굴 칸 · #375 잿빛 틈 원정 · #373 #371 여관 · #376 대사창 · #378 #377 가방 · #380 새 장소

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/geo/geo.dart';
import 'package:isekai_reality/core/models/armory.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/models/pet_state.dart';
import 'package:isekai_reality/core/models/vitals.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/storage/record_store.dart' show HeroLook;
import 'package:isekai_reality/features/awakening/awakening_screen.dart';
import 'package:isekai_reality/features/pets/pet_screen.dart';
import 'package:isekai_reality/features/town/bag_tab.dart';
import 'package:isekai_reality/features/town/inn_screen.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'support/village_seed.dart';

const _home = GeoPoint(37.3219, 126.8309);

void _phone(WidgetTester t) {
  t.view.physicalSize = const Size(1290, 2796);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
}

Widget _host(Widget child) => MaterialApp(builder: (context, c) => TopNoticeHost(child: c!), home: child);

Finder _txt(String t) => find.byWidgetPredicate(
    (w) => w is Text && (w.data ?? w.textSpan?.toPlainText() ?? '').replaceAll('⁠', '') == t);

Pet _pet(String uid, PetSpecies s, String name) =>
    Pet(uid: uid, species: s, name: name, bornAt: DateTime(2026, 11, 1));

Map<String, dynamic> _pets(List<Pet> pets, {List<PetEgg> eggs = const []}) => {
      'pets': PetState(
        pets: pets,
        companion: pets.first.uid,
        firstPet: pets.first.uid,
        firstSpiritName: '불씨',
        farewellAt: DateTime(2026, 11, 2),
        eggs: eggs,
      ).toJson(),
    };

final _three = [
  _pet('p1', PetSpecies.owl, '부엉'),
  _pet('p2', PetSpecies.blackCat, '나비'),
  _pet('p3', PetSpecies.toad, '개굴'),
];

void main() {
  group('#372 펫 3마리 · 기력 펫 보너스 없음', () {
    test('값', () {
      expect(PetRules.maxPets, 3);
      expect(PetRules.mpMaxBonus(3), 0);
      expect(PetRules.mpRegenBonus(6), 0);
    });

    test('4마리 넘는 계정: 그대로 · 새로 깨우지 못함', () async {
      final c = await startVillage(18, farewell: true, more: _pets([
        ..._three,
        _pet('p4', PetSpecies.crow, '까망'),
      ]));
      expect(c.pets.pets.length, 4);
      expect(c.petsFull, isTrue);
      expect(c.mpMax, VitalRules.levelMp(c.player.level.level));
    });

    testWidgets('펫 화면 「펫 N / 3」 · 가득일 때 알 창 한 줄', (tester) async {
      _phone(tester);
      late AppController c;
      const egg = PetEgg(id: 'e1', source: 'field');
      await tester.runAsync(() async => c = await startVillage(18, farewell: true, more: _pets(_three, eggs: [egg])));
      await tester.pumpWidget(_host(PetScreen(controller: c)));
      await tester.pump();
      expect(find.textContaining('펫 3 / 3'), findsOneWidget);
      await tester.pumpWidget(_host(Scaffold(body: EggSheet(controller: c, egg: egg))));
      await tester.pump();
      expect(find.byKey(const Key('eggSheetPetsFull')), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('#375 잿빛 틈 원정', () {
    test('보내기 → 닿음(알림) → 기다리는 동안 싸움 → 돌아옴', () async {
      var now = DateTime(2026, 11, 16, 10);
      final c = await startVillage(13, farewell: true, more: _pets(_three), clock: () => now);
      await c.handleFix(const LocationFix(point: _home));
      expect(c.riftPoint, isNotNull);
      expect(c.atRift, isFalse);
      expect(c.canOfferTrip('rift'), isTrue);
      final plan = c.planTrip('rift', petUid: 'p2');
      expect(plan.ok, isTrue);
      final mp0 = c.mp;
      expect(await c.sendTrip('rift', 'p2'), ExpeditionCheck.ok);
      expect(c.mp, mp0 - plan.mpCost);
      expect(c.isAway('p2'), isTrue);
      expect(c.canOfferTrip('rift'), isFalse); // 한 번에 한 마리
      expect(c.tripWaiting('rift'), isFalse);
      now = now.add(plan.oneWay + const Duration(seconds: 1));
      await c.refreshVitals();
      expect(c.tripWaiting('rift'), isTrue);
      expect(c.tripArrivedUnseen, isNotNull);
      // 들어가 싸움 (지면 하루 3번에 셈)
      final b = c.startAshBattle()!;
      b.playerHp = 0;
      while (!b.isOver) {
        b.tick();
      }
      await c.finishAshBattle(b);
      expect(c.tripWaiting('rift'), isFalse);
      expect(c.isAway('p2'), isTrue); // 돌아오는 길
      now = now.add(plan.oneWay + const Duration(seconds: 2));
      await c.refreshVitals();
      expect(c.tripTo('rift'), isNull);
      expect(c.isAway('p2'), isFalse);
    });

    test('기다림이 끝나면 싸우지 않고 돌아옴 (기력은 안 돌려줌)', () async {
      var now = DateTime(2026, 11, 16, 10);
      final c = await startVillage(13, farewell: true, more: _pets(_three), clock: () => now);
      await c.handleFix(const LocationFix(point: _home));
      final plan = c.planTrip('rift', petUid: 'p1');
      await c.sendTrip('rift', 'p1');
      final mp1 = c.mp;
      now = now.add(plan.oneWay + SpotTripOps.riftWait + plan.oneWay + const Duration(minutes: 1));
      await c.refreshVitals();
      expect(c.tripTo('rift'), isNull);
      expect(c.mp, greaterThanOrEqualTo(mp1));
    });
  });

  group('#373 여관', () {
    test('시간당 20% · ★2 · 단짝 속도', () {
      expect(InnRules.gain(100, 1, 0).$1, 20);
      expect(InnRules.speed(star2: true), InnRules.star2Speed);
      expect(InnRules.speed(star2: true, martaBest: true), closeTo(1.25 * 1.1, 1e-9));
      expect(InnRules.untilFull([(0, 100)]), const Duration(hours: 5));
    });

    test('원정 나간 동안은 여관 회복이 멈춤 (구간 겹침)', () {
      final t = DateTime(2026, 11, 16, 10);
      final p = InnRules.pausedWithin(t, t.add(const Duration(hours: 3)), [
        (t.subtract(const Duration(hours: 1)), t.add(const Duration(hours: 1))),
        (t.add(const Duration(minutes: 30)), t.add(const Duration(hours: 2))),
      ]);
      expect(p, const Duration(hours: 2));
    });

    test('원정 중이면 멈춤 · 광고 바로 회복은 두 번까지', () async {
      var now = DateTime(2026, 11, 16, 10);
      final c = await startVillage(13, farewell: true, more: _pets(_three), clock: () => now,
          vitals: const Vitals(hp: 1, mp: 999));
      c.watchAd = (_) async => true;
      await c.handleFix(const LocationFix(point: _home));
      expect(await c.restAtInn(), isTrue);
      expect(await c.sendTrip('rift', 'p3'), ExpeditionCheck.ok);
      expect(c.innPaused, isTrue);
      expect(c.canInnAd, isFalse);
      final hp = c.hp;
      now = now.add(const Duration(minutes: 20));
      await c.refreshVitals();
      expect(c.hp, hp); // 멈춤
    });

    test('광고 바로 회복: 한 번에 20% · 두 번까지', () async {
      final now = DateTime(2026, 11, 16, 10);
      final c = await startVillage(13, farewell: true, clock: () => now, vitals: const Vitals(hp: 1, mp: 0));
      c.watchAd = (_) async => true;
      await c.restAtInn();
      final hp = c.hp;
      expect(await c.innAd(), isTrue);
      expect(c.hp - hp, closeTo(c.maxHp * 0.2, 1));
      expect(await c.innAd(), isTrue);
      expect(c.canInnAd, isFalse);
    });

    testWidgets('판: 가득이면 「언제든 일어나도 돼요」 · MP 아이콘은 보라', (tester) async {
      _phone(tester);
      late AppController c;
      await tester.runAsync(() async => c = await startVillage(18, farewell: true, more: {
            'jobs': {'awakened': true, 'v57': true, 'v31': true, 'main': 'mage', 'owned': ['mage']},
          }));
      await tester.runAsync(() => c.restAtInn());
      await tester.pumpWidget(_host(InnScreen(controller: c)));
      await tester.pump();
      expect(find.text('쉬는 중'), findsOneWidget); // 묶음 82 #391: 띠는 「쉬는 중」만
      expect(
          find.descendant(
              of: find.byKey(const Key('innFill_jobMp')),
              matching: find.image(const AssetImage('assets/images/icon_job_mp.webp'))),
          findsOneWidget);
      expect(_txt('여관에 있는 동안 HP · MP · 기력이 조금씩 차요'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('#376 대사창', () {
    testWidgets('주인공은 오른쪽 얼굴 · 펫은 왼쪽 · 나레이션은 얼굴 없음 · 꼬리 없음', (tester) async {
      _phone(tester);
      final pet = _three.first;
      Widget scene(String? sp, SceneWho? who) => MaterialApp(
            home: IllustratedScene(
                key: UniqueKey(), image: 'assets/images/bg_battle.webp', line: '안녕', lineKey: 'x', onNext: () {}, speaker: sp, who: who),
          );
      await tester.pumpWidget(scene('하루', const SceneWho.hero(HeroLook.male)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('dialogHead_right')), findsOneWidget);
      expect(find.byKey(const Key('dialogFace_hero')), findsOneWidget);
      await tester.pumpWidget(scene('부엉', SceneWho.pet(pet)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('dialogHead_left')), findsOneWidget);
      expect(find.byKey(Key('dialogFace_pet:${pet.uid}')), findsOneWidget);
      await tester.pumpWidget(scene('정령', const SceneWho.name()));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('dialogSpeaker')), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('dialogFace_')),
          findsNothing);
      await tester.pumpWidget(scene(null, null));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('dialogSpeaker')), findsNothing);
      expect(find.byKey(const Key('dialogTailUp')), findsNothing);
      expect(find.byKey(const Key('dialogTailDown')), findsNothing);
      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('#377 장비 비교', () {
    const worn = EquipItem(uid: 'a', base: EquipBase.cap, grade: EquipGrade.green);
    test('좋아짐 ▲ · 나빠짐 ▼ · 섞임 ⇄ · 같음 없음', () {
      const better = EquipItem(uid: 'b', base: EquipBase.cap, grade: EquipGrade.purple);
      const worse = EquipItem(uid: 'c', base: EquipBase.cap, grade: EquipGrade.white);
      const mixed = EquipItem(uid: 'd', base: EquipBase.cap, grade: EquipGrade.white, extras: {'str': 3});
      const same = EquipItem(uid: 'e', base: EquipBase.cap, grade: EquipGrade.green);
      expect(EquipmentRules.markOf(EquipmentRules.compareItems(better, worn)), CompareMark.up);
      expect(EquipmentRules.markOf(EquipmentRules.compareItems(worse, worn)), CompareMark.down);
      expect(EquipmentRules.markOf(EquipmentRules.compareItems(mixed, worn)), CompareMark.mix);
      expect(EquipmentRules.markOf(EquipmentRules.compareItems(same, worn)), isNull);
      // 대장간 비교(흰색 +0)와 같은 계산
      expect(EquipmentRules.compareWith(EquipBase.cap, worn), EquipmentRules.compareItems(worse, worn));
    });
  });

  group('#378 가방', () {
    test('새로 얻은 것 · 최근 차례 · 정렬 기억', () async {
      final c = await startVillage(10);
      c.noteBagContents({'m:herb': 3});
      expect(c.bagIsNew('m:herb'), isFalse); // 처음엔 기억만
      c.noteBagContents({'m:herb': 5, 'm:slimeJelly': 1});
      expect(c.bagIsNew('m:herb'), isTrue);
      expect(c.bagIsNew('m:slimeJelly'), isTrue);
      expect(c.bagOrderOf('m:slimeJelly'), greaterThan(0));
      await c.markBagSeen('m:herb');
      expect(c.bagIsNew('m:herb'), isFalse);
      expect(c.bagSort, BagSort.recent);
      await c.setBagSort(BagSort.grade);
      expect(c.bagSort, BagSort.grade);
    });

    testWidgets('첫 화면: 칩 · 5칸 격자 · 「가방 N / M칸」 · 물약 판 없음 · 골라서 버리기', (tester) async {
      _phone(tester);
      late AppController c;
      await tester.runAsync(() async => c = await startVillage(14, farewell: true, gains: {'herb': 12, 'slimeJelly': 30, 'gold': 500}));
      await tester.pumpWidget(_host(Scaffold(body: BagTab(controller: c))));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('bagGoldChip')), findsOneWidget);
      expect(find.byKey(const Key('bagManaChip')), findsOneWidget);
      expect(find.byKey(const Key('activePotions')), findsNothing);
      expect(find.byKey(const Key('bagCap')), findsOneWidget);
      expect(find.byKey(const Key('bagSort')), findsOneWidget);
      expect(find.byKey(const Key('bagLegend')), findsOneWidget);
      final grid = tester.widget<GridView>(find.byKey(const Key('bagGrid')));
      expect((grid.childrenDelegate as SliverChildListDelegate).children.length, greaterThan(5));
      expect(find.textContaining('칸을 쓰지 않아요'), findsNothing);
      // 골라서 버리기
      await tester.tap(find.byKey(const Key('bagPickToggle')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('bagCell_0')));
      await tester.pump();
      expect(find.text('1칸 골랐어요'), findsOneWidget);
      await tester.tap(find.byKey(const Key('bagPickGo')));
      await tester.pump();
      expect(find.byKey(const Key('bagPickConfirm')), findsOneWidget);
      await tester.tap(find.byKey(const Key('bagPickYes')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
      expect(find.text('1칸을 비웠어요'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('#380 새 장소 정리', () {
    test('걷기·탐험 숙련은 1,000보마다만 · 경험치 없음', () {
      final d = DailyRecord(date: DateTime(2026, 11, 16), steps: 5500, newPlacesVisited: 3, placesRevisited: 2);
      expect(MasteryRules.walkFrom([d]), 5);
      expect(ExpRules.forDay(d).total, 0);
      expect(MasteryRules.howUp(Mastery.walk), '걷기');
    });

    test('마을 사람 부탁에 「새 장소」 · 「안 가 본 곳」 없음', () {
      final labels = [
        for (final r in NpcRules.requests)
          for (final s in r.steps) s.label,
        for (final r in NpcSmallRules.relics)
          for (final st in r.stages)
            for (final s in st.steps) s.label,
      ];
      expect(labels.where((l) => l.contains('새 장소') || l.contains('안 가 본 곳')), isEmpty);
    });
  });
}
