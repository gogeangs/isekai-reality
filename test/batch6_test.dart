import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/location/location_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/map/korea_area.dart';
import 'package:isekai_reality/features/profile/profile_screen.dart';
import 'package:isekai_reality/theme/ornaments.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('하루 사냥 (11-11 #69)', () {
    test('1~5마리 그대로, 6~15 절반, 16부터 10%', () {
      expect(RuleConstants.fieldFactor(5), 1);
      expect(RuleConstants.fieldFactor(6), 0.5);
      expect(RuleConstants.fieldFactor(15), 0.5);
      expect(RuleConstants.fieldFactor(16), 0.1);
      expect(RuleConstants.fieldUnits(5), 5);
      expect(RuleConstants.fieldUnits(15), closeTo(10, 1e-9));
      expect(RuleConstants.fieldUnits(20), closeTo(10.5, 1e-9));
    });
  });

  group('이름 바꾸기 (11-11 #72)', () {
    test('마을 사람·정령 이름은 이미 쓰는 이름', () {
      final c = AppController(
        area: KoreaArea.area,
        store: InMemoryRecordStore(
          profile: const PlayerProfile(name: '하루', spiritName: '이슬'),
          history: [DailyRecord(date: DateTime(2026, 11, 10))],
        ),
        health: FakeHealthSource(),
        location: FakeLocationSource(),
        clock: () => DateTime(2026, 11, 11, 14),
        random: Random(1),
      );
      expect(c.nameTaken('하르트'), isTrue);
      expect(c.nameTaken('미나'), isTrue);
      expect(c.nameTaken('새벽'), isFalse);
    });

    Future<void> open(WidgetTester t, {int cost = 0}) async {
      await t.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showDialog<String>(
                  context: context,
                  builder: (_) => RenameDialog(
                    initial: '하루',
                    cost: cost,
                    taken: (n) => n == '미나',
                  ),
                ),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ));
      await t.tap(find.text('열기'));
      await t.pumpAndSettle();
    }

    TextButton save(WidgetTester t) =>
        t.widget<TextButton>(find.byKey(const Key('renameSave')));

    testWidgets('처음은 무료 뱃지, 바꾸지 않으면 저장 흐림', (t) async {
      await open(t);
      expect(find.text('이름 바꾸기'), findsOneWidget);
      expect(find.text('처음 한 번은 무료'), findsOneWidget);
      expect(find.text('2/10'), findsOneWidget);
      expect(save(t).onPressed, isNull);
    });

    testWidgets('중복이면 빨간 알림과 저장 흐림, 새 이름이면 저장', (t) async {
      await open(t, cost: 300);
      expect(find.text('금화 300'), findsOneWidget);
      await t.enterText(find.byKey(const Key('renameField')), '미나');
      await t.pump();
      expect(find.text('이미 쓰는 이름이에요'), findsOneWidget);
      expect(save(t).onPressed, isNull);
      await t.enterText(find.byKey(const Key('renameField')), '새벽빛');
      await t.pump();
      expect(find.text('이미 쓰는 이름이에요'), findsNothing);
      expect(find.text('3/10'), findsOneWidget);
      expect(save(t).onPressed, isNotNull);
      await t.tap(find.byKey(const Key('renameSave')));
      await t.pumpAndSettle();
      expect(find.byType(RenameDialog), findsNothing);
    });

    testWidgets('창이 닫히면 키보드(포커스)도 닫힌다 (#73)', (t) async {
      await open(t);
      await t.showKeyboard(find.byKey(const Key('renameField')));
      expect(
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<EditableText>(),
          isNotNull);
      await t.tap(find.text('그만두기'));
      await t.pumpAndSettle();
      expect(
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<EditableText>(),
          isNull);
    });
  });

  testWidgets('공용 팝업: 마지막 버튼은 금색 (#72)', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GameAlert(
          title: const Text('버릴까요?'),
          content: const Text('되돌릴 수 없어요.'),
          actions: [
            TextButton(onPressed: () {}, child: const Text('그만두기')),
            TextButton(onPressed: () {}, child: const Text('버리기')),
          ],
        ),
      ),
    ));
    expect(find.text('버릴까요?'), findsOneWidget);
    final gold = gameButtonStyle(gold: true).backgroundColor!.resolve({});
    final m = t.widget<Material>(find.descendant(
        of: find.widgetWithText(TextButton, '버리기'),
        matching: find.byType(Material)));
    expect(m.color, gold);
  });
}
