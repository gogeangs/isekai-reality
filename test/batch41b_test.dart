// 묶음 41 확인 답: 위쪽 알림 띠 (앱 전체)
// 띠가 떠 있어도 아래 화면은 바로 눌리고, 띠를 누르거나 위로 밀면 닫히고,
// 새 알림은 앞 알림을 바꿔 띄운다. 소식 알림(showTopNoticeQueued)은 차례를 지킨다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/features/town/shop_screen.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'support/shop_seed.dart';

void main() {
  Widget host(Widget home) => MaterialApp(
        builder: (context, child) => TopNoticeHost(child: child!),
        home: home,
      );

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('새 알림은 바꿔 띄우고, 소식 알림은 차례를 지킨다', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(host(Builder(builder: (c) {
      ctx = c;
      return const Scaffold(body: SizedBox.expand());
    })));
    showTopNoticeQueued(ctx, '새 칭호 「첫걸음」');
    await settle(tester);
    expect(find.text('새 칭호 「첫걸음」'), findsOneWidget);
    showTopNotice(ctx, '가방에 넣었어요!');
    await settle(tester);
    expect(find.text('가방에 넣었어요!'), findsOneWidget);
    expect(find.text('새 칭호 「첫걸음」'), findsNothing);
    showTopNotice(ctx, '가방에 넣었어요! ×2');
    await settle(tester);
    expect(find.text('가방에 넣었어요!'), findsNothing);
    expect(find.text('가방에 넣었어요! ×2'), findsOneWidget);
    // 위로 밀면 닫히고, 미뤄 둔 소식이 다시 나온다
    await tester.fling(
        find.byKey(const Key('topNotice')), const Offset(0, -80), 600);
    await settle(tester);
    await settle(tester);
    expect(find.text('가방에 넣었어요! ×2'), findsNothing);
    expect(find.text('새 칭호 「첫걸음」'), findsOneWidget);
    await tester.pump(const Duration(seconds: 8));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('잡화상: 알림이 떠 있어도 바로 또 사고, 팔고 바로 다른 줄 고르기', (tester) async {
    tester.view.physicalSize = const Size(750, 1334);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    late AppController c;
    await tester.runAsync(() async => c = await startShop(shopped: false));
    await tester.pumpWidget(host(ShopScreen(controller: c)));
    await settle(tester);

    Future<void> buyOne() async {
      await tester.tap(find.byKey(const Key('shopItem_healSmall')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('buyConfirm')));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 80)));
      await settle(tester);
    }

    await buyOne();
    expect(find.byKey(const Key('topNotice')), findsOneWidget);
    await buyOne(); // 알림이 떠 있는 채로 바로
    expect(c.bagCount(ShopItem.healSmall), 2);
    expect(find.byKey(const Key('topNotice')), findsOneWidget);

    await tester.tap(find.byKey(const Key('shopTab_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sellRow_m:ironShard')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('sellPicked')));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)));
    await settle(tester);
    expect(c.player.materialCount(MaterialId.ironShard), 0);
    expect(find.byKey(const Key('topNotice')), findsOneWidget);
    // 알림이 떠 있는 채로 바로 다른 줄 고르기
    await tester.tap(find.byKey(const Key('sellRow_m:twig')));
    await tester.pump();
    expect(find.textContaining('1가지 2개 팔기'), findsOneWidget);
    // 띠를 누르면 닫힘
    await tester.tap(find.byKey(const Key('topNotice')));
    await settle(tester);
    expect(find.byKey(const Key('topNotice')), findsNothing);
    await tester.pump(const Duration(seconds: 8));
  });
}
