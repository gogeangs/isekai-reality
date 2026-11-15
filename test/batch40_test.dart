// 묶음 40: 대장간 화면 다시 (#220~#223)

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/armory.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/features/smithy/smithy_screen.dart';
import 'package:isekai_reality/theme/ornaments.dart';

import 'support/smithy_seed.dart';

void phone(WidgetTester tester,
    {Size size = const Size(750, 1334), double dpr = 2, double text = 1}) {
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
    ].join('\n').replaceAll('\u2060', '');

void main() {
  Future<AppController> open(WidgetTester tester,
      {int gold = 5000,
      int stones = 1,
      Map<String, int>? mats}) async {
    late AppController c;
    await tester.runAsync(() async => c = mats == null
        ? await startSmithy(gold: gold, stones: stones)
        : await startSmithy(gold: gold, stones: stones, mats: mats));
    await tester.pumpWidget(MaterialApp(home: SmithyScreen(controller: c)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return c;
  }

  Future<void> tab(WidgetTester tester, int i) async {
    await tester.tap(find.byKey(Key('smithyTab_$i')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('#220 위쪽 · 탭 두 줄 · 붙어 있음', () {
    testWidgets('대장간 그림·마석 칸 없음, 탭 3개씩 두 줄, 지갑 한 줄', (tester) async {
      phone(tester, text: 1.12);
      await open(tester);
      expect(find.image(const AssetImage('assets/images/icon_smithy.webp')),
          findsNothing);
      expect(find.byKey(const Key('smithyWallet')), findsOneWidget);
      final y = [
        for (var i = 0; i < 6; i++)
          tester.getRect(find.byKey(Key('smithyTab_$i'))).top
      ];
      expect(y[0], y[1]);
      expect(y[1], y[2]);
      expect(y[3], y[4]);
      expect(y[4], y[5]);
      expect(y[3], greaterThan(y[0]));
      // 지갑은 탭 바로 위 오른쪽
      final w = tester.getRect(find.byKey(const Key('smithyWallet')));
      expect(w.bottom, lessThanOrEqualTo(y[0]));
      expect(find.text('재료 가공'), findsOneWidget);
      expect(find.text('수리 · 분해'), findsNothing);
      // 탭 글씨가 줄지 않는다 (작은 iPhone, 글자 크게)
      for (var i = 0; i < 6; i++) {
        final fit = find.descendant(
            of: find.byKey(Key('smithyTab_$i')), matching: find.byType(Text));
        // FittedBox 안 글자의 원래 폭이 칸 안에 들어가면 줄어들지 않은 것
        final box = tester.getSize(fit);
        final full = tester.getSize(find.byKey(Key('smithyTab_$i')));
        expect(box.width, lessThanOrEqualTo(full.width - 8));
      }
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('내려도 위쪽이 그대로 · 첫 장비 카드가 첫 화면에', (tester) async {
      phone(tester, text: 1.12);
      await open(tester);
      final tabTop = tester.getRect(find.byKey(const Key('smithyTab_5'))).bottom;
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      // 부위 칩 아래 첫 장비 카드 윗부분이 보인다
      final first = find.byWidgetPredicate(
          (w) => w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith('recipe_'));
      expect(tester.getRect(first.first).top, lessThan(screen.height - 40));
      await tester.drag(
          find.byKey(const Key('smithyList')), const Offset(0, -600));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.getRect(find.byKey(const Key('smithyTab_5'))).bottom,
          tabTop);
      expect(find.byKey(const Key('smithyHeaderShadow')), findsOneWidget);
      await tester.pump(const Duration(seconds: 9));
    });

    test('도르군 탭 안내', () {
      expect(VillageRules.smithyGuide(2),
          '닳은 건 고쳐 써라. 안 쓰는 건 분해하면 재료로 돌려주지.');
      expect(VillageRules.smithyGuide(3),
          '속성을 입히면 날이 달라진다. 망치가 빗나가도 코어는 돌려주지.');
      expect(VillageRules.smithyGuide(4), '광석은 녹여야 쓸 만해진다. 남는 재료를 가져와라.');
      expect(VillageRules.smithyGuide(5), contains('보스 조각'));
      expect(VillageRules.smithyGuide(1), contains('부서지지'));
    });

    testWidgets('재료 가공 탭엔 가공만, 채집 도구 수리는 수리 탭 아래', (tester) async {
      phone(tester);
      await open(tester);
      await tab(tester, 4);
      expect(allText(tester), isNot(contains('채집 도구')));
      await tab(tester, 2);
      await tester.drag(
          find.byKey(const Key('smithyList')), const Offset(0, -3000));
      await tester.pump(const Duration(milliseconds: 500));
      expect(allText(tester), contains('채집 도구'));
      await tester.pump(const Duration(seconds: 9));
    });
  });

  group('#221 만들기', () {
    test('비교 한 줄: 좋아지면 ▲, 나빠지면 ▼, 숫자는 실제 값', () {
      final worn = EquipItem(uid: 'x', base: EquipBase.dagger, grade: EquipGrade.white);
      // 같은 장비 흰색 +0 → 차이 없음
      expect(EquipmentRules.compareWith(EquipBase.dagger, worn), isEmpty);
      final strong = EquipItem(
          uid: 'y', base: EquipBase.dagger, grade: EquipGrade.green, enhance: 2);
      final lines = EquipmentRules.compareWith(EquipBase.dagger, strong);
      expect(lines.first.$1, isFalse);
      expect(lines.first.$2, startsWith('공격 -'));
      final weak = EquipItem(
          uid: 'z', base: EquipBase.staff, grade: EquipGrade.white);
      final up = EquipmentRules.compareWith(EquipBase.ironSword, weak);
      expect(up, isNotEmpty);
    });

    testWidgets('부위 칩 · 만들 수 있어요 맨 위 · 모자란 카드 · 새 부위', (tester) async {
      phone(tester, size: const Size(1290, 2796), dpr: 3);
      final c = await open(tester);
      expect(find.byKey(const Key('slotChip_all')), findsOneWidget);
      expect(find.byKey(const Key('canMake_cap')), findsOneWidget);
      // 갑옷: 박쥐 날개가 모자라다
      await tester.tap(find.byKey(const Key('slotChip_body')));
      await tester.pump();
      expect(find.byKey(const Key('recipe_armor')), findsOneWidget);
      expect(find.byKey(const Key('recipe_cap')), findsNothing);
      final miss = tester.widget<KText>(find.byKey(const Key('missing_armor')));
      expect(miss.data.replaceAll('\u2060', ''), contains('박쥐 날개 1개'));
      expect(miss.data.replaceAll('\u2060', ''), endsWith('모자라요'));
      // 장갑은 입은 게 없다 → 새 부위
      await tester.tap(find.byKey(const Key('slotChip_hands')));
      await tester.pump();
      expect(find.text('새 부위'), findsWidgets);
      // 전체: 만들 수 있는 장비가 먼저
      await tester.tap(find.byKey(const Key('slotChip_all')));
      await tester.pump();
      final ready = [
        for (final i in EquipmentRules.all)
          if (c.canCraft(i.id) == CraftCheck.ok) i.id.name
      ];
      final notReady = [
        for (final i in EquipmentRules.all)
          if (c.canCraft(i.id) == CraftCheck.materials ||
              c.canCraft(i.id) == CraftCheck.manaStones)
            i.id.name
      ];
      expect(ready, isNotEmpty);
      expect(notReady, isNotEmpty);
      final list = tester.widget<ListView>(find.byKey(const Key('smithyList')));
      expect(list, isNotNull);
      final yReady = tester.getTopLeft(find.byKey(Key('recipe_${ready.last}'),
          skipOffstage: false));
      final yRest = tester.getTopLeft(find.byKey(
          Key('recipe_${notReady.first}'),
          skipOffstage: false));
      expect(yReady.dy, lessThan(yRest.dy));
      // 귀한 재료 넣기 칸 · 만든 장비 줄은 없앰
      expect(find.text('귀한 재료 넣기'), findsNothing);
      expect(find.byKey(const Key('craftCount')), findsNothing);
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('확인 창: 귀한 재료를 고르면 색 점과 한 줄', (tester) async {
      phone(tester, size: const Size(1290, 2796), dpr: 3);
      final c = await open(tester);
      final crafts = c.armory.crafts;
      await tester.tap(find.byKey(const Key('craft_cap')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('craftSheet')), findsOneWidget);
      expect(find.byKey(const Key('rare_none')), findsOneWidget);
      expect(find.byKey(const Key('gradeDots')), findsOneWidget);
      expect(find.byKey(const Key('rareHint')), findsNothing);
      await tester.tap(find.byKey(const Key('rare_glossyFur')));
      await tester.pump();
      expect(find.byKey(const Key('rareHint')), findsOneWidget);
      expect(allText(tester), isNot(contains('%')));
      await tester.tap(find.byKey(const Key('craftCancel')));
      await tester.pumpAndSettle();
      expect(c.armory.crafts, crafts);
      await tester.tap(find.byKey(const Key('craft_cap')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('craftConfirm')));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
      expect(c.armory.crafts, crafts + 1);
      expect(find.byKey(const Key('equipNow')), findsOneWidget);
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('귀한 재료가 없으면 넣기 칸 없이 짧은 확인 창', (tester) async {
      phone(tester, size: const Size(1290, 2796), dpr: 3);
      await open(tester, mats: const {'ratHide': 4});
      await tester.tap(find.byKey(const Key('craft_cap')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('craftSheet')), findsOneWidget);
      expect(find.byKey(const Key('rare_none')), findsNothing);
      expect(find.byKey(const Key('craftConfirm')), findsOneWidget);
      await tester.pump(const Duration(seconds: 9));
    });
  });

  group('#222 강화 · 수리', () {
    testWidgets('입는 중이 위 · 모자란 것 한 줄', (tester) async {
      phone(tester, size: const Size(1290, 2796), dpr: 3);
      await open(tester, stones: 0);
      await tab(tester, 1);
      expect(find.byKey(const Key('group_worn')), findsOneWidget);
      expect(find.byKey(const Key('group_bag')), findsOneWidget);
      expect(tester.getTopLeft(find.byKey(const Key('enhanceCard_w'))).dy,
          lessThan(tester.getTopLeft(find.byKey(const Key('group_bag'))).dy));
      expect(find.byKey(const Key('short_w')), findsOneWidget);
      expect(allText(tester), contains('개 모자라요'));
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('모두 수리 · ⋯ 분해 메뉴 (입는 중은 흐리게)', (tester) async {
      phone(tester, size: const Size(1290, 2796), dpr: 3);
      final c = await open(tester);
      await tab(tester, 2);
      final total =
          c.masteryRepairCost(c.armory.byUid('w')!) +
              c.masteryRepairCost(c.armory.byUid('b')!);
      expect(find.text('모두 수리 · 금화 $total'), findsOneWidget);
      expect(allText(tester), contains('입은 장비 2개가 닳았어요'));
      expect(allText(tester), isNot(contains('필드 전투 한 번에')));
      // 수리 카드엔 분해·속성 글자 버튼이 없다
      expect(find.byKey(const Key('imbue_w')), findsNothing);
      await tester.tap(find.byKey(const Key('more_w')));
      await tester.pumpAndSettle();
      expect(find.text('입는 중이에요'), findsOneWidget);
      final item = tester.widget<PopupMenuItem<int>>(
          find.byKey(const Key('salvage_w')));
      expect(item.enabled, isFalse);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('more_f')));
      await tester.tap(find.byKey(const Key('more_f')));
      await tester.pumpAndSettle();
      expect(find.text('마석과 재료 일부를 돌려받아요'), findsOneWidget);
      await tester.tap(find.byKey(const Key('salvage_f')));
      await tester.pumpAndSettle();
      expect(find.textContaining('분해할까요?'), findsOneWidget);
      await tester.tap(find.text('그만두기'));
      await tester.pumpAndSettle();
      // 모두 수리
      await tester.tap(find.byKey(const Key('repairAll')));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 80)));
      await tester.pumpAndSettle();
      expect(c.armory.byUid('w')!.durability, EquipmentRules.maxDurability);
      expect(c.armory.byUid('b')!.durability, EquipmentRules.maxDurability);
      expect(c.armory.byUid('f')!.durability, 20); // 가방 장비는 그대로
      expect(find.text('모두 멀쩡해요'), findsOneWidget);
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('금화가 모자라면 모두 수리가 꺼지고 모자란 금화', (tester) async {
      phone(tester, size: const Size(1290, 2796), dpr: 3);
      final c = await open(tester, gold: 3);
      await tab(tester, 2);
      final total =
          c.masteryRepairCost(c.armory.byUid('w')!) +
              c.masteryRepairCost(c.armory.byUid('b')!);
      expect(allText(tester), contains('금화 ${total - 3} 모자라요'));
      await tester.pump(const Duration(seconds: 9));
    });
  });

  group('#223 속성', () {
    testWidgets('있는 장비 3칸 · 없는 장비 고르기 · 모자란 코어', (tester) async {
      phone(tester, size: const Size(1290, 2796), dpr: 3);
      final c = await open(tester);
      await tab(tester, 3);
      expect(find.byKey(const Key('elementIntro')), findsOneWidget);
      expect(find.byKey(const Key('elementOf_w')), findsOneWidget);
      expect(find.byKey(const Key('smith_upgrade_w')), findsOneWidget);
      expect(find.byKey(const Key('smith_change_w')), findsOneWidget);
      expect(find.byKey(const Key('smith_extract_w')), findsOneWidget);
      // 불 코어가 없어 속성 강화가 꺼지고 모자란 코어 한 줄
      expect(allText(tester), contains('2개 모자라요'));
      // 실패 확률 숫자 없음
      expect(allText(tester), isNot(contains('%')));
      // 속성이 없는 모자: 고르기 5칸 + 더 보기, 물 코어만 밝게
      expect(find.byKey(const Key('pick_apply_h_water')), findsOneWidget);
      expect(find.byKey(const Key('pickMore_h')), findsOneWidget);
      await tester.tap(find.byKey(const Key('pick_apply_h_water')));
      await tester.pump();
      final gold = c.player.gold;
      await tester.ensureVisible(find.byKey(const Key('smith_apply_h')));
      await tester.tap(find.byKey(const Key('smith_apply_h')));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 80)));
      await tester.pump();
      expect(c.player.gold, gold - SmithRules.gold(SmithAction.apply));
      // 코어가 없는 속성을 고르면 모자란 코어 한 줄
      await tester.ensureVisible(find.byKey(const Key('pick_apply_g_fire')));
      await tester.tap(find.byKey(const Key('pick_apply_g_fire')));
      await tester.pump();
      expect(allText(tester), contains('1개 모자라요'));
      // 바꾸기를 누르면 고르기가 펼쳐짐
      await tester.ensureVisible(find.byKey(const Key('smith_change_w')));
      await tester.tap(find.byKey(const Key('smith_change_w')));
      await tester.pump();
      expect(find.byKey(const Key('pick_change_w_water')), findsOneWidget);
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('가장 진하게 빛나면 속성 강화가 꺼짐', (tester) async {
      phone(tester, size: const Size(1290, 2796), dpr: 3);
      late AppController c;
      await tester.runAsync(() async {
        c = await startSmithy();
      });
      final it = c.armory.byUid('w')!;
      expect(it.elementLevel, lessThan(SmithRules.maxLevel));
      await tester.pumpWidget(MaterialApp(home: SmithyScreen(controller: c)));
      await tester.pump();
      await tab(tester, 3);
      expect(find.text('속성 강화'), findsOneWidget);
      await tester.pump(const Duration(seconds: 9));
    });
  });

  test('예전 기록(#124): 입은 장비·속성·강화·내구도 그대로', () async {
    final c = await startSmithy();
    final w = c.armory.byUid('w')!;
    expect(c.armory.isWorn(w), isTrue);
    expect(w.element, Element.fire);
    expect(w.elementLevel, 1);
    expect(w.enhance, 2);
    expect(w.durability, 40);
    expect(c.armory.byUid('f')!.durability, 20);
  });
}
