// 묶음 80: #370 정리 · #365 알 팔기 · #366 조합 그림 띠 · #367 여관 · #368 잿빛 군주 안내

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/models/pet_state.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/features/jobs/guild_screen.dart';
import 'package:isekai_reality/features/town/bag_tab.dart';
import 'package:isekai_reality/features/town/inn_screen.dart';
import 'package:isekai_reality/features/town/sell_sheet.dart';
import 'package:isekai_reality/features/town/shop_screen.dart';
import 'package:isekai_reality/features/village/village_screen.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'support/village_seed.dart';

void _phone(WidgetTester t) {
  t.view.physicalSize = const Size(1290, 2796);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
}

/// KText 는 글자 사이에 줄바꿈 막는 표시를 넣으므로 빼고 비교
Finder _txt(String t) => find.byWidgetPredicate(
    (w) => w is Text && (w.data ?? w.textSpan?.toPlainText() ?? '').replaceAll('\u2060', '') == t);

Widget _host(Widget child) => MaterialApp(builder: (context, c) => TopNoticeHost(child: c!), home: child);

Map<String, dynamic> _pets({bool farewell = true, List<PetEgg> eggs = const []}) => {
      'pets': PetState(
        pets: [Pet(uid: 'p1', species: PetSpecies.owl, name: '부엉', bornAt: DateTime(2026, 11, 1))],
        companion: 'p1',
        firstPet: 'p1',
        firstSpiritName: '불씨',
        farewellAt: farewell ? DateTime(2026, 11, 2) : null,
        eggs: eggs,
      ).toJson(),
    };

Map<String, dynamic> _jobs(String main, {int? mp}) => {
      'jobs': {'awakened': true, 'v57': true, 'v31': true, 'main': main, 'owned': [main], if (mp != null) 'mp': mp},
    };

void main() {
  group('#368 잠긴 건물 안내', () {
    test('본체 전 주점 · 거래소는 「잿빛 군주를 쓰러뜨리면 열려요」', () {
      for (final f in [Facility.tavern, Facility.market]) {
        expect(VillageScreen.lockNotice(f, label: '', kingBeaten: false), '잿빛 군주를 쓰러뜨리면 열려요');
      }
    });

    test('본체 뒤: 거래소는 지금 문구 · 주점은 「조금 더 지나면 열려요」', () {
      expect(VillageScreen.lockNotice(Facility.market, label: '', kingBeaten: true),
          '아직 짓는 중이에요 · 완공은 조금 더 기다려 주세요');
      expect(VillageScreen.lockNotice(Facility.tavern, label: '', kingBeaten: true), '조금 더 지나면 열려요');
    });

    test('빈 「에 열려요」는 어떤 건물에도 없다', () {
      for (final f in Facility.values) {
        for (final king in [false, true]) {
          for (final building in [false, true]) {
            for (final label in ['', 'Lv.7']) {
              final s = VillageScreen.lockNotice(f, label: label, kingBeaten: king, building: building);
              expect(s, isNot(startsWith('에 ')), reason: '$f $king $building');
              expect(s.trim(), isNotEmpty);
            }
          }
        }
      }
      expect(VillageScreen.lockNotice(Facility.smithy, label: 'Lv.7', kingBeaten: false), 'Lv.7에 열려요');
      expect(VillageScreen.lockNotice(Facility.smithy, label: 'Lv.7', kingBeaten: false, building: true), 'Lv.7에 완공돼요');
    });
  });

  group('#365 알 팔기', () {
    test('값 절반쯤 · 거래소 기준값 그대로', () {
      expect([for (final g in EggGrade.values) g.price], [80, 250, 700, 2000]);
      expect(MarketRules.eggBase, 150);
    });

    testWidgets('잡화상 팔기 「알」 묶음: 있을 때만 · 개수 · 물건 묶음엔 없음', (tester) async {
      _phone(tester);
      late AppController c;
      await tester.runAsync(() async => c = await startVillage(14, farewell: true, more: _pets(eggs: [
            const PetEgg(id: 'e1', source: 'field', grade: EggGrade.hero),
            const PetEgg(id: 'e2', source: 'field'),
            PetEgg(id: 'e3', source: 'field', incubatedAt: DateTime(2026, 11, 16, 9)),
          ])));
      await tester.pumpWidget(_host(ShopScreen(controller: c, sellGroup: SellGroup.egg)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('알 2'), findsOneWidget);
      expect(find.byKey(const Key('sellRow_g:e1')), findsOneWidget);
      expect(find.byKey(const Key('sellRow_g:e2')), findsOneWidget);
      expect(find.byKey(const Key('sellRow_g:e3')), findsNothing);
      expect(find.text('금화 700'), findsOneWidget);
      await tester.tap(find.byKey(const Key('sellChip_item')));
      await tester.pump();
      expect(find.byKey(const Key('sellRow_g:e1')), findsNothing);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('알이 없으면 「알」 묶음 칩이 없다', (tester) async {
      _phone(tester);
      late AppController c;
      await tester.runAsync(() async => c = await startVillage(14, farewell: true));
      await tester.pumpWidget(_host(ShopScreen(controller: c, sellGroup: SellGroup.egg)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('sellChip_egg')), findsNothing);
      expect(find.byKey(const Key('sellChip_material')), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('가방 알 창 3가지: 팔 수 있음 · 품는 중 · 신비한 알', (tester) async {
      _phone(tester);
      late AppController a;
      late AppController b;
      const free = PetEgg(id: 'e1', source: 'field', grade: EggGrade.rare);
      final warm = PetEgg(id: 'e2', source: 'field', incubatedAt: DateTime(2026, 11, 16, 9));
      await tester.runAsync(() async {
        a = await startVillage(14, farewell: true, more: _pets(eggs: [free, warm]));
        b = await startVillage(8, more: _pets(farewell: false, eggs: [free]));
      });
      await tester.pumpWidget(_host(Scaffold(body: EggSheet(key: const ValueKey(1), controller: a, egg: free))));
      await tester.pump();
      expect(_txt('잡화상에서 금화 250'), findsOneWidget);
      expect(find.byKey(const Key('eggSellGo')), findsOneWidget);
      await tester.pumpWidget(_host(Scaffold(body: EggSheet(key: const ValueKey(2), controller: a, egg: warm))));
      await tester.pump();
      expect(_txt('품는 중이라 팔 수 없어요'), findsOneWidget);
      expect(find.byKey(const Key('eggSellGo')), findsNothing);
      await tester.pumpWidget(_host(Scaffold(body: EggSheet(key: const ValueKey(3), controller: b, egg: free))));
      await tester.pump();
      expect(_txt('아직 팔 수 없어요'), findsOneWidget);
      expect(find.byKey(const Key('eggSellGo')), findsNothing);
    });
  });

  group('#366 조합', () {
    testWidgets('그림 띠 없음 · 세라 머리줄', (tester) async {
      _phone(tester);
      late AppController c;
      await tester.runAsync(() async => c = await startVillage(17, farewell: true, more: _jobs('warrior')));
      await tester.pumpWidget(_host(GuildScreen(controller: c)));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const Key('guildHall')), findsNothing);
      expect(find.byKey(const Key('guildSeraLine')), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('#367 여관', () {
    test('휴식은 경험치를 주지 않는다', () {
      final rested = DailyRecord(date: DateTime(2026, 11, 16), restsCompleted: 2);
      expect(ExpRules.forDay(rested).total, 0);
    });

    test('직업 MP도 서서히 · 일어나면 찬 만큼 · (묶음 81) 시간당 20%', () async {
      var now = DateTime(2026, 11, 16, 10);
      final c = await startVillage(18, farewell: true, more: _jobs('mage', mp: 0), clock: () => now);
      expect(c.jobMp, 0);
      expect(await c.restAtInn(), isTrue);
      now = now.add(const Duration(hours: 2));
      await c.refreshVitals();
      expect(c.jobMp, closeTo(c.jobMpMax * 0.4, 2));
      final half = c.jobMp;
      await c.stopResting();
      now = now.add(const Duration(minutes: 30));
      await c.refreshVitals();
      expect(c.jobMp, greaterThanOrEqualTo(half)); // 일어나도 찬 만큼 그대로
      expect(await c.restAtInn(), isTrue);
      now = now.add(const Duration(hours: 5, minutes: 1));
      await c.refreshVitals();
      expect(c.jobMp, c.jobMpMax);
    });


    testWidgets('「쉬는 동안 차는 것」 판: 각성 뒤 MP 줄 · 각성 전엔 없음 · 옛 판 없음', (tester) async {
      _phone(tester);
      late AppController a;
      late AppController b;
      await tester.runAsync(() async {
        a = await startVillage(18, farewell: true, more: _jobs('warrior'));
        b = await startVillage(8);
      });
      await tester.pumpWidget(_host(InnScreen(key: const ValueKey(1), controller: a)));
      await tester.pump();
      expect(find.byKey(const Key('innFillPanel')), findsOneWidget);
      expect(find.byKey(const Key('innFill_jobMp')), findsOneWidget);
      expect(_txt('여관에 있는 동안 HP · MP · 기력이 조금씩 차요'), findsOneWidget);
      expect(find.text('오늘 하루'), findsNothing);
      expect(find.textContaining('연속 휴식'), findsNothing);
      expect(find.textContaining('보너스'), findsNothing);
      await tester.pumpWidget(_host(InnScreen(key: const ValueKey(2), controller: b)));
      await tester.pump();
      expect(find.byKey(const Key('innFill_jobMp')), findsNothing);
      expect(_txt('여관에 있는 동안 HP · 기력이 조금씩 차요'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });
  });
}
