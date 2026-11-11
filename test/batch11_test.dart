import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/theme/top_notice.dart';

void main() {
  group('#86 이용 연령', () {
    final now = DateTime(2026, 11, 12);
    test('만 14세 이상만, 올해 14살이면 생일이 지났는지 묻는다', () {
      expect(AgeRules.allowed(2000, now), isTrue);
      expect(AgeRules.allowed(2011, now), isTrue); // 15살 해
      expect(AgeRules.allowed(2013, now), isFalse); // 13살 해
      expect(AgeRules.needsBirthdayQuestion(2012, now), isTrue);
      expect(AgeRules.allowed(2012, now, birthdayPassed: true), isTrue);
      expect(AgeRules.allowed(2012, now, birthdayPassed: false), isFalse);
      expect(AgeRules.validYear(1899, now), isFalse);
      expect(AgeRules.validYear(2027, now), isFalse);
    });

    testWidgets('14세 미만이면 이용 불가 화면, 다시 켜도 그대로', (tester) async {
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final store = InMemoryRecordStore();
      final c = AppController(
        store: store,
        health: FakeHealthSource(granted: false),
        clock: () => DateTime(2026, 11, 12, 14),
      );
      await tester.pumpWidget(IsekaiRealityApp(controller: c));
      await c.init();
      await tester.pumpAndSettle();
      await c.blockForAge();
      await tester.pumpAndSettle();
      expect(find.text(AgeRules.blockedLine), findsOneWidget);
      final again = AppController(
        store: store,
        health: FakeHealthSource(granted: false),
        clock: () => DateTime(2026, 11, 12, 14),
      );
      await again.init();
      expect(again.ageBlocked, isTrue);
    });
  });

  testWidgets('#85 위쪽 금테 띠: 차례로 보이고, 누르면 동작', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => TopNoticeHost(child: child!),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () {
                showTopNotice(context, '첫째 알림', onTap: () => tapped++);
                showTopNotice(context, '둘째 알림');
              },
              child: const Text('보내기'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('보내기'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('첫째 알림'), findsOneWidget);
    expect(find.text('둘째 알림'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    await tester.tap(find.byKey(const Key('topNotice')));
    expect(tapped, 1);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('둘째 알림'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 1));
  });
}
