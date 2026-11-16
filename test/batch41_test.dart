// 묶음 41: 잡화상 화면 다시 (#227)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/features/town/shop_screen.dart';
import 'package:isekai_reality/theme/ornaments.dart';

import 'support/shop_seed.dart';

void phone(WidgetTester tester,
    {Size size = const Size(1290, 2796), double dpr = 3, double text = 1}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = dpr;
  tester.platformDispatcher.textScaleFactorTestValue = text;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

String allText(WidgetTester tester) => [
      for (final w in tester.widgetList<Text>(find.byType(Text)))
        w.data ?? w.textSpan?.toPlainText() ?? '',
      for (final w in tester.widgetList<KText>(find.byType(KText))) w.data,
    ].join('\n').replaceAll('⁠', '');

Future<void> reveal(WidgetTester tester, String list, String key,
    [double delta = 150]) async {
  await tester.scrollUntilVisible(find.byKey(Key(key)), delta,
      scrollable: find.descendant(
          of: find.byKey(Key(list)), matching: find.byType(Scrollable))
          .first);
  Scrollable.ensureVisible(tester.element(find.byKey(Key(key))),
      alignment: 0.5);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  Future<AppController> open(WidgetTester tester,
      {int gold = 600, int stones = 12, bool shopped = true}) async {
    late AppController c;
    await tester.runAsync(() async =>
        c = await startShop(gold: gold, stones: stones, shopped: shopped));
    await tester.pumpWidget(MaterialApp(home: ShopScreen(controller: c)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return c;
  }

  Future<void> wait(WidgetTester tester, [int ms = 80]) async {
    await tester.runAsync(
        () => Future<void>.delayed(Duration(milliseconds: ms)));
    await tester.pumpAndSettle();
  }

  group('위쪽', () {
    testWidgets('그림·HP 줄 없음, 지갑 한 줄, 사기·팔기 탭, 내려도 붙어 있음', (tester) async {
      phone(tester, size: const Size(750, 1334), dpr: 2, text: 1.12);
      await open(tester);
      expect(find.image(const AssetImage('assets/images/map_store.webp')),
          findsNothing);
      expect(find.byKey(const Key('shopWallet')), findsOneWidget);
      expect(allText(tester), isNot(contains('HP 1')));
      expect(find.byKey(const Key('shopTab_0')), findsOneWidget);
      expect(find.byKey(const Key('shopTab_1')), findsOneWidget);
      final wallet = tester.getRect(find.byKey(const Key('shopWallet')));
      final tab = tester.getRect(find.byKey(const Key('shopTab_0')));
      expect(wallet.bottom, lessThanOrEqualTo(tab.top));
      // 첫 화면에 물약 카드
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(tester.getRect(find.byKey(const Key('shopItem_healSmall'))).top,
          lessThan(screen.height - 60));
      await tester.drag(find.byKey(const Key('shopList')), const Offset(0, -700));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.getRect(find.byKey(const Key('shopTab_0'))), tab);
      await tester.pump(const Duration(seconds: 9));
    });
  });

  group('사기 탭', () {
    testWidgets('묶음 칩 · 제목 · 막대 · 남은 수 · 흐린 카드 맨 아래', (tester) async {
      phone(tester);
      final c = await open(tester);
      expect(find.byKey(const Key('shopChip_all')), findsOneWidget);
      expect(find.byKey(const Key('shopGroup_potion')), findsOneWidget);
      expect(find.byKey(const Key('shopVitals')), findsOneWidget);
      expect(find.byKey(const Key('bar_jobMp')), findsNothing); // Lv.15 전
      // 작은 회복 물약: 가진 것 2 · 오늘 1개 남음
      expect(c.shopLeft(ShopItem.healSmall), 1);
      expect(allText(tester), contains('오늘 1개 남음'));
      expect(allText(tester), contains('가진 것 2'));
      // 다 산 정령 물약 · Lv 전 회복 물약은 흐리게 맨 아래
      expect(find.byKey(const Key('again_bulssiPotion')), findsOneWidget);
      expect(find.byKey(const Key('again_heal')), findsOneWidget);
      final y = tester.getTopLeft(find.byKey(const Key('shopItem_manaSmall'))).dy;
      expect(tester.getTopLeft(find.byKey(const Key('shopItem_bulssiPotion'))).dy,
          greaterThan(y));
      expect(allText(tester), contains('내일 다시'));
      expect(allText(tester), contains('Lv.3부터'));
      // 칩: 재료만
      await tester.tap(find.byKey(const Key('shopChip_material')));
      await tester.pump();
      expect(find.byKey(const Key('shopItem_ironShard')), findsOneWidget);
      expect(find.byKey(const Key('shopItem_healSmall')), findsNothing);
      expect(find.byKey(const Key('shopGroup_material')), findsNothing);
      // 「다시 살 수 있어요」 접기는 없앰
      expect(find.byKey(const Key('shopSoldOut')), findsNothing);
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('금화 부족은 흐리지 않고 값 버튼만 꺼짐', (tester) async {
      phone(tester);
      await open(tester, gold: 15, shopped: false);
      await reveal(tester, 'shopList', 'shopItem_expeditionCompass');
      expect(find.byKey(const Key('short_expeditionCompass')), findsOneWidget);
      expect(allText(tester), contains('금화 35 부족'));
      final btn = tester.widget<GoldButton>(
          find.byKey(const Key('price_expeditionCompass')));
      expect(btn.onPressed, isNull);
      expect(find.byKey(const Key('again_expeditionCompass')), findsNothing);
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('수량 창: 최대 · 합계 · 여러 개 사기', (tester) async {
      phone(tester);
      final c = await open(tester, shopped: false);
      final gold = c.player.gold;
      expect(c.shopMaxBuy(ShopItem.healSmall), 3);
      await tester.tap(find.byKey(const Key('shopItem_healSmall')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('buySheet')), findsOneWidget);
      expect(allText(tester), contains('오늘 3개 더 살 수 있어요'));
      await tester.tap(find.byKey(const Key('buyMax')));
      await tester.pump();
      expect(find.text('3'), findsWidgets);
      expect(allText(tester), contains('합계 금화 30'));
      expect(allText(tester), contains('남는 금화 ${gold - 30}'));
      await tester.tap(find.byKey(const Key('buyMinus')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('buyConfirm')));
      await wait(tester, 150);
      expect(c.bagCount(ShopItem.healSmall), 2);
      expect(c.player.gold, gold - 20);
      expect(allText(tester), contains('×2'));
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('최대가 1이면 − + 없이 바로 확인', (tester) async {
      phone(tester);
      final c = await open(tester, shopped: false);
      await reveal(tester, 'shopList', 'shopItem_spareKey');
      await tester.tap(find.byKey(const Key('shopItem_spareKey')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('buyPlus')), findsNothing);
      expect(allText(tester), contains('이번 주 1개 더 살 수 있어요'));
      final keys = c.player.gauge.keysAvailable;
      await tester.tap(find.byKey(const Key('buyConfirm')));
      await wait(tester);
      expect(c.player.gauge.keysAvailable, keys + 1);
      await tester.pump(const Duration(seconds: 9));
    });

    test('한 번에 사는 최대는 금화·남은 수·가방 칸 중 가장 적은 수', () async {
      final c = await startShop(gold: 25, shopped: false);
      expect(c.shopMaxBuy(ShopItem.healSmall), 2); // 금화 25 → 2개
      expect(c.shopMaxBuy(ShopItem.heal), 0); // Lv.3 전
      final (n, last) = await c.buyMany(ShopItem.healSmall, 5);
      expect(n, 2);
      expect(last, PurchaseCheck.notEnoughCrystals);
    });
  });

  group('팔기 탭', () {
    testWidgets('마석 3버튼 · 5개 남기고 모두', (tester) async {
      phone(tester);
      final c = await open(tester);
      await tester.tap(find.byKey(const Key('shopTab_1')));
      await tester.pumpAndSettle();
      expect(allText(tester), contains('대장간에서도 써요'));
      final gold = c.player.gold;
      await tester.tap(find.byKey(const Key('stoneSell_2')));
      await wait(tester);
      expect(c.player.manaStones, 5);
      expect(c.player.gold, gold + 7 * RuleConstants.goldPerManaStone);
      final all =
          tester.widget<GoldButton>(find.byKey(const Key('stoneSell_2')));
      expect(all.onPressed, isNull);
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('재료 여러 개 골라 한꺼번에 · 귀한 재료면 확인', (tester) async {
      phone(tester);
      final c = await open(tester);
      await tester.tap(find.byKey(const Key('shopTab_1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sellChip_material')), findsOneWidget);
      await tester.tap(find.byKey(const Key('sellRow_m:ratHide')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('sellRow_m:ironShard')));
      await tester.pump();
      expect(allText(tester), contains('2가지 10개 팔기'));
      // 길게 눌러 개수 정하기
      await tester.longPress(find.byKey(const Key('sellRow_m:ratHide')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sellCountSheet')), findsOneWidget);
      await tester.tap(find.byKey(const Key('sellMinus')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('sellCountOk')));
      await tester.pumpAndSettle();
      expect(allText(tester), contains('2가지 9개 팔기'));
      // 귀한 재료 없음 → 확인 없이 바로
      await tester.tap(find.byKey(const Key('sellPicked')));
      await wait(tester, 150);
      expect(find.byKey(const Key('sellConfirmYes')), findsNothing);
      expect(c.player.materialCount(MaterialId.ratHide), 1);
      expect(c.player.materialCount(MaterialId.ironShard), 0);
      // 귀한 재료는 확인
      await reveal(tester, 'sellList', 'sellRow_m:glossyFur');
      await tester.tap(find.byKey(const Key('sellRow_m:glossyFur')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('sellPicked')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sellConfirmYes')), findsOneWidget);
      await tester.tap(find.byKey(const Key('sellConfirmYes')));
      await wait(tester, 150);
      expect(c.player.materialCount(MaterialId.glossyFur), 0);
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('장비: 입는 중은 흐리게 못 팔고, 가방 장비는 확인 뒤 팔기', (tester) async {
      phone(tester);
      final c = await open(tester);
      await tester.tap(find.byKey(const Key('shopTab_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sellChip_equip')));
      await tester.pumpAndSettle();
      expect(allText(tester), contains('입는 중이라 못 팔아요'));
      await tester.tap(find.byKey(const Key('sellRow_e:w')));
      await tester.pump();
      expect(allText(tester), contains('팔 것을 골라 주세요'));
      await tester.tap(find.byKey(const Key('sellRow_e:f')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('sellPicked')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sellConfirmYes')));
      await wait(tester, 150);
      expect(c.armory.byUid('f'), isNull);
      expect(c.armory.byUid('w'), isNotNull);
      await tester.pump(const Duration(seconds: 9));
    });
  });
}
