// 묶음 58: 묶음 57 확인 답 · 3막 마무리 4가지(지역 되풀이 의뢰 · 심층 주간 순위 · 지역 재료 · 이름 있는 장비 효과) · 거래소

import 'dart:io';

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/geo/geo.dart';
import 'package:isekai_reality/core/models/armory.dart';
import 'package:isekai_reality/core/models/board_state.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/act3/region_screens.dart';
import 'package:isekai_reality/features/village/market_screen.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'batch52_test.dart' as b52;
import 'batch53_test.dart' as b53;
import 'batch56_test.dart' as b56;
import 'batch57_regions_test.dart' as r57;

Widget host(Widget home) =>
    MaterialApp(builder: (context, child) => TopNoticeHost(child: child!), home: home);

/// 입은 장비 하나를 더한 계정으로 다시 연다
Future<AppController> wearing(AppController c, EquipBase b, EquipSlot slot) async {
  final a = c.armory;
  await c.store.saveJson('armory', {
    ...a.toJson(),
    'items': [
      for (final i in a.items) i.toJson(),
      EquipItem(uid: 'eqU', base: b, grade: EquipGrade.orange).toJson(),
    ],
    'equipped': {...a.toJson()['equipped'] as Map, slot.name: 'eqU'},
  });
  return (await b52.start(c.store as InMemoryRecordStore)).$1;
}

void main() {
  setUp(() => b56.now = b52.t0);

  group('0 묶음 57 확인 답', () {
    test('다섯 번째 몬스터 한마디는 요청 문장 그대로 (숫자 없음)', () {
      expect(TutorialOps.fifthLine, '오늘은 몸이 좀 무거워. 많이 걸으면 던전에서 더 크게 자랄 수 있어.');
    });

    test('테스 「다섯 불의 기록」: 불씨 5/5 + 걸음 8,000 둘 다 · 지역에 들어갈 때 하나씩', () async {
      final r = RegionRules.aurel;
      var c = await r57.inRegion(r, more: {
        'aurel:arrive', 'aurel:first', 'aurel:talk', 'act3End',
        for (final x in RegionRules.all) 'reach:${x.prefix}',
      });
      final q = r.quest('aur_record');
      expect(q.embers, isTrue);
      await c.acceptQuest(q);
      expect(c.embersFound, 1, reason: '받을 때 있는 아우렐 불씨');
      c = await r57.reload(c, (s) => s.copyWith(prog: {...s.prog, q.id: q.target}));
      expect(c.questReady(q), isFalse, reason: '걸음만 채우면 안 끝남');
      expect(questProgText(c, q), '불씨 1/5 · 걸음 8,000/8,000');
      for (final g in [Region.baldrin, Region.selenia, Region.elowin, Region.morval]) {
        await c.travelTo(g);
      }
      await c.travelTo(Region.selenia); // 다시 들어가도 같은 불씨는 하나
      expect(c.embersFound, 5);
      expect(c.questReady(q), isTrue);
    });
  });

  group('1 3막 마무리', () {
    test('하르트 게시판: 등불 켠 지역마다 그 지역 의뢰(사냥 · 채집 · 던전)', () {
      expect(BoardRules.template('seleniaHunt3')!.counter, 'a3fight:selenia');
      expect(BoardRules.template('aurelGather2')!.counter, 'a3gather:aurel');
      expect(BoardRules.template('morvalFloor2')!.tickets, 1);
      var sel = 0, other = 0;
      for (var d = 1; d <= 30; d++) {
        final b = BoardRules.refresh(const BoardState(), DateTime(2026, 12, d % 28 + 1, 10, d),
            regions: const ['baldrin', 'selenia']);
        for (final s in b.slots) {
          final t = BoardRules.template(s.templateId);
          if (t?.region == 'selenia') sel++;
          if (t?.region == 'elowin' || t?.region == 'aurel') other++;
        }
      }
      expect(sel, greaterThan(0));
      expect(other, 0, reason: '등불을 안 켠 지역 의뢰는 안 붙음');
    });

    test('지역 싸움 · 던전 층이 그 지역 의뢰 수로 셈 · 현실 지도에 그 지역 재료 (줍기 → 재료 · 의뢰 수)', () async {
      final r = RegionRules.selenia;
      var c = await r57.inRegion(r, more: {'selenia:arrive', 'selenia:first', 'selenia:lamp'});
      await b53.field(c, 'selenia_caravan');
      expect(c.history.last.counters['a3fight:selenia'], 1);
      // 지역 재료: 그날 지역마다 가끔 (등불 켠 셀레니아만)
      var spots = <HarvestSpot>[];
      for (var d = 0; d < 6 && spots.isEmpty; d++) {
        b56.now = b52.t0.add(Duration(days: d));
        c = (await b52.start(c.store as InMemoryRecordStore)).$1;
        await c.handleFix(const LocationFix(point: GeoPoint(37.5665, 126.978)));
        spots = [for (final s in c.harvestSpots) if (c.regionOfSpot(s) != null) s];
      }
      expect(spots, isNotEmpty);
      expect(c.regionOfSpot(spots.first), same(r));
      expect(c.isTreasure(spots.first), isTrue);
      await c.handleFix(LocationFix(point: spots.first.point));
      final before = c.player.materialCount(MaterialId.stardust);
      final got = await c.openTreasure(spots.first);
      expect(got!.keys, [MaterialId.stardust]);
      expect(c.player.materialCount(MaterialId.stardust), greaterThan(before));
      expect(c.history.last.counters['a3gather:selenia'], 1);
      expect(await c.openTreasure(spots.first), isNull, reason: '그날 한 번');
      expect([for (final s in c.harvestSpots) if (c.regionOfSpot(s) != null) s], isEmpty);
    });

    test('이름 있는 장비 효과: 화관 · 단검 · 빛꽃 · 망토는 싸움에 · 지팡이는 여정 기력 · 고목의 심장은 약초밭', () async {
      var c = await b53.opened(level: 30);
      c = await wearing(c, EquipBase.uniqMomoWreath, EquipSlot.head);
      var b = c.startAct3Fight('baldrin_ashplain')!;
      expect(b.regenChance, RegionRules.momoWreathRegen);
      c = await wearing(c, EquipBase.uniqArbelDagger, EquipSlot.weapon);
      b = c.startAct3Fight('baldrin_ashplain')!;
      expect(b.boundBoost, RegionRules.arbelBound);
      c = await wearing(c, EquipBase.uniqLucyFlower, EquipSlot.accessory);
      b = c.startAct3Fight('baldrin_ashplain')!;
      expect(b.allyRegenChance, RegionRules.lucyFlowerAllyRegen);
      c = await wearing(c, EquipBase.uniqKingCloak, EquipSlot.body);
      b = c.startAct3Fight('baldrin_ashplain')!;
      expect(b.potionShare, RegionRules.kingCloakPotion);
      // 망토: 회복 물약을 쓰면 동료도
      b.allies.first.hp = 1;
      b.playerHp = 1;
      final p = b.potions.values.where((x) => x.hpRatio > 0).firstOrNull;
      if (p != null) {
        b.drink(p.key);
        expect(b.allies.first.hp, greaterThan(1));
      }
      // 화관: 매 턴 가끔 회복 (확률을 1로)
      b.regenChance = 1;
      b.playerHp = 1;
      b.tick();
      expect(b.playerHp, greaterThan(1));
    });

    test('나오미의 지팡이: 걸으면 여정 기력 더', () async {
      var c = await b53.opened(level: 30);
      Future<int> walk() async {
        await c.store.saveJson('act3',
            c.act3.copyWith(energy: 0, walkDay: '2026-11-18', walkSteps: 0, energyRem: 0).toJson());
        return (await b52.start(c.store as InMemoryRecordStore, steps: 5000)).$1.journeyEnergy;
      }
      final plain = await walk();
      c = await wearing(c, EquipBase.uniqNaomiStaff, EquipSlot.weapon);
      final staff = await walk();
      expect(staff, greaterThan(plain));
    });

    test('심층 주간 순위: 이번 주 지역(서버와 같은 규칙) · 그 지역 심층이면 서버에 올림 · 순위 화면', () async {
      expect(RegionRules.deepRegionOf(DateTime.utc(2026, 11, 18, 3)), Region.selenia);
      expect(RegionRules.deepRegionOf(DateTime.utc(2026, 11, 23, 3)), Region.elowin);
      expect(RegionRules.deepRegionOf(DateTime.utc(2026, 12, 14, 3)), Region.selenia);
      final r = RegionRules.selenia;
      final (c0, a) = await b56.start();
      await c0.store.saveJson('act3', (await r57.inRegion(r, more: {
        'selenia:arrive', 'selenia:first', 'selenia:talk', 'selenia:event', 'selenia:choice:free',
        'selenia:lamp', 'act3End',
      })).act3.copyWith(prog: {'selenia:floorBest': 5, 'selenia:floorNow': 6}).toJson());
      final c = (await b56.start(store: c0.store as InMemoryRecordStore, arca: a)).$1;
      expect(c.deepRegion, Region.selenia);
      for (final e in c.regionEnterFloor(r)!) {
        await b53.fight(c, e);
      }
      await c.regionClearFloor(r);
      await Future<void>.delayed(Duration.zero);
      expect(a.deepRows[a.uid], 6);
      final board = await c.deepBoard();
      expect(board!.myRank, 2);
      expect(board.top.first.name, '별');
    });
  });

  group('2 거래소', () {
    test('규칙: 사고팔 수 있는 장비 · 값 한도 · 수수료 · 서버 표와 같음', () {
      expect(MarketRules.equipBases, contains(EquipBase.dagger));
      expect(MarketRules.equipBases, contains(EquipBase.seleniaHead));
      for (final no in [
        EquipBase.wardenHead, EquipBase.ashCrown, EquipBase.martaScarf,
        EquipBase.seleniaAxe, EquipBase.uniqTeoCloak, EquipBase.partyWeapon, EquipBase.skyHead, EquipBase.lianKnot,
      ]) {
        expect(MarketRules.equipBases.contains(no), isFalse, reason: no.name);
      }
      // 묶음 59: 첫 무기 종류도 대장간에서 만든 건 팔 수 있음 (받은 것만 막음)
      expect(MarketRules.equipBases, contains(EquipBase.ironSword));
      expect(MarketRules.itemTradable(ShopItem.healSmall), isTrue);
      expect(MarketRules.listFee(100), 10);
      expect(MarketRules.listFee(2000), 40);
      expect(MarketRules.listFee(2000, seal: true), 20);
      expect(MarketRules.saleFee(1000), 100);
      expect(MarketRules.saleFee(1000, best: true), 70);
      expect(MarketRules.minPrice(10, 3), 15);
      expect(MarketRules.maxPrice(10, 3), 180);
      expect(File('firebase/functions/src/market_catalog.json').readAsStringSync(), MarketRules.catalogJson(),
          reason: '규칙을 바꾸면 서버 표도 다시 만들어야 해요');
    });

    test('올리기: 서버가 되면 재료 · 올리는 금화를 뺌 / 안 되면 그대로 · 사기: 금화를 빼고 우편(바르칸)으로', () async {
      final (c, a) = await b56.start();
      final today = c.history.last;
      await c.store.upsert(today.copyWith(gains: DailyRecord.addCounts(today.gains, {'herb': 10})));
      final c2 = (await b56.start(store: c.store as InMemoryRecordStore, arca: a)).$1;
      final own = c2.marketOwn(MarketKind.mat).firstWhere((o) => o.key == 'herb');
      expect(own.have, 10);
      final g0 = c2.player.gold;
      a.marketFail = 'not_owned';
      expect(await c2.listOnMarket(own, qty: 3, auction: false, price: 30), isFalse);
      expect(c2.marketError, 'not_owned');
      expect(c2.player.materialCount(MaterialId.herb), 10);
      a.marketFail = null;
      expect(await c2.listOnMarket(own, qty: 3, auction: false, price: 30), isTrue);
      expect(c2.player.materialCount(MaterialId.herb), 7);
      expect(c2.player.gold, g0 - MarketRules.listFee(30));
      expect(a.marketBodies.last['me'], {'name': c2.profile.name});
      // 다른 사람 물건 사기 (장비) → 우편 · 이 휴대폰 장비 번호를 새로 붙임
      a.listings.add({
        'id': 'other1', 'kind': 'equip', 'key': 'dagger', 'name': '단검', 'qty': 1, 'mode': 'fixed', 'price': 120,
        'status': 'open', 'sellerName': '별',
        'equip': EquipItem(uid: 'eq1', base: EquipBase.dagger, grade: EquipGrade.blue, enhance: 3).toJson(),
      });
      final rows = await c2.browseMarket();
      expect(rows!.single.sellerName, '별');
      final g1 = c2.player.gold;
      final next = c2.armory.nextId;
      expect(await c2.buyOnMarket(rows.single), isTrue);
      expect(c2.player.gold, g1 - 120);
      final mail = c2.mail.mails.firstWhere((m) => m.from == '바르칸');
      expect(mail.equips.single.enhance, 3);
      expect(mail.equips.single.uid, 'eq$next', reason: '이 휴대폰 장비 번호를 새로');
      expect(c2.armory.nextId, next + 1);
      expect(MarketOps.marketErrorText('same_device'), contains('같은 휴대폰'));
    });

    testWidgets('거래소 화면: 로그인 안 했으면 안내 · 하면 사기 · 올리기 · 경매 · 내 장부', (tester) async {
      late AppController c;
      await tester.runAsync(() async => c = (await b56.start(login: false)).$1);
      await tester.pumpWidget(host(MarketScreen(controller: c)));
      await tester.pump();
      expect(find.byKey(const Key('marketClosed')), findsOneWidget);
      await tester.runAsync(() async => c = (await b56.start()).$1);
      await tester.pumpWidget(host(MarketScreen(key: const ValueKey('in'), controller: c)));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('marketIntro')), findsOneWidget);
      await tester.tap(find.text('좋아요'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 300));
      for (var i = 0; i < 4; i++) {
        expect(find.byKey(Key('marketTab_$i')), findsOneWidget);
      }
      await tester.tap(find.byKey(const Key('marketTab_1')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('marketCat_mat')), findsOneWidget);
    });
  });
}
