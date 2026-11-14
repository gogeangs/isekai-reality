import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/profile/profile_screen.dart';
import 'package:isekai_reality/features/smithy/smithy_screen.dart';
import 'package:isekai_reality/features/town/inn_screen.dart';
import 'package:isekai_reality/features/village/board_parchment.dart';
import 'package:isekai_reality/features/village/board_screen.dart';
import 'package:isekai_reality/theme/ornaments.dart';

void main() {
  final t0 = DateTime(2026, 11, 14, 10);

  Future<AppController> start(InMemoryRecordStore store) async {
    final c = AppController(
      store: store,
      health: FakeHealthSource(stepsByDay: const {}),
      clock: () => t0,
    )..mailSources = const [];
    await c.init();
    return c;
  }

  void phone(WidgetTester tester, Size size, double dpr) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);
  }

  /// 화면에 보이는 모든 글 (KText 포함)
  String allText(WidgetTester tester) => [
        for (final w in tester.widgetList<Text>(find.byType(Text)))
          w.data ?? w.textSpan?.toPlainText() ?? '',
        for (final w in tester.widgetList<KText>(find.byType(KText))) w.data,
      ].join('\n').replaceAll('⁠', '');

  /// 칭호 하나(첫걸음)를 얻은 계정
  InMemoryRecordStore oneTitle({bool listed = true}) => InMemoryRecordStore(
        profile: const PlayerProfile(name: '하루'),
        history: [
          DailyRecord(date: DateTime(2026, 11, 10), steps: 3000),
        ],
        json: {
          'titles': {
            'seen': ['firstSteps'],
            if (listed) 'listed': ['firstSteps'] else 'listed': [],
          },
        },
      );

  group('#177·#178 프로필', () {
    testWidgets('칭호 1개: 1줄 + 「얻은 칭호 1개」, ??? 없음, 직업 줄 없음', (tester) async {
      phone(tester, const Size(1170, 2532), 3);
      late AppController c;
      await tester.runAsync(() async => c = await start(oneTitle()));
      expect(c.player.titles, {TitleId.firstSteps});
      await tester.pumpWidget(
          MaterialApp(home: ProfileScreen(controller: c)));
      await tester.pump();
      final text = allText(tester);
      expect(text, contains('얻은 칭호 1개'));
      expect(text, isNot(contains('???')));
      expect(text, isNot(contains('얻는 방법')));
      expect(text, isNot(contains('직업')));
      expect(text, isNot(contains('견습 각성자')));
      expect(text, isNot(contains(' / ')));
      expect(find.byKey(const Key('title_firstSteps')), findsOneWidget);
      expect(find.byKey(const Key('titleGlow')), findsNothing);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('새 칭호는 처음 볼 때 한 번 빛나고, 다시 보면 빛나지 않음', (tester) async {
      phone(tester, const Size(1170, 2532), 3);
      final store = oneTitle(listed: false);
      late AppController c;
      await tester.runAsync(() async => c = await start(store));
      await tester.pumpWidget(
          MaterialApp(home: ProfileScreen(controller: c)));
      await tester.pump();
      expect(find.byKey(const Key('titleGlow')), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      expect(c.titleIsNewInList(TitleId.firstSteps), isFalse);
      // 다시 켜도
      late AppController again;
      await tester.runAsync(() async => again = await start(store));
      expect(again.titleIsNewInList(TitleId.firstSteps), isFalse);
    });

    test('새로 얻은 칭호가 맨 위', () async {
      final c = await start(InMemoryRecordStore(
        profile: const PlayerProfile(name: '하루'),
        history: [
          for (var i = 0; i < 8; i++)
            DailyRecord(
                date: DateTime(2026, 11, 13 - i), steps: 20000, stepGoal: 6000),
        ],
        json: {
          'titles': {
            'seen': ['firstSteps'],
            'listed': ['firstSteps'],
          },
        },
      ));
      final list = c.titlesNewestFirst;
      expect(list.last, TitleId.firstSteps);
      expect(list.length, c.player.titles.length);
    });
  });

  testWidgets('#174 대장간: 확률·숙련도 숫자 없음, 색 점과 만든 장비 수만', (tester) async {
    phone(tester, const Size(1170, 2532), 3);
    late AppController c;
    await tester.runAsync(() async => c = await start(
        InMemoryRecordStore(profile: const PlayerProfile(name: '하루'))));
    await tester.pumpWidget(MaterialApp(home: SmithyScreen(controller: c)));
    await tester.pump();
    expect(find.byKey(const Key('gradeDots')), findsOneWidget);
    expect(find.byKey(const Key('craftCount')), findsOneWidget);
    final text = allText(tester);
    expect(text, isNot(contains('%p')));
    expect(text, isNot(contains('숙련도')));
    expect(text, isNot(contains('60%')));
    expect(text, isNot(contains('어울리는 직업')));
    await tester.pump(const Duration(seconds: 9));
  });

  group('#175 여관: 들어가자마자 버튼이 보인다', () {
    for (final (label, size, dpr) in const [
      ('작은 iPhone', Size(750, 1334), 2.0),
      ('큰 iPhone', Size(1290, 2796), 3.0),
      ('Android', Size(1080, 2400), 2.625),
    ]) {
      testWidgets(label, (tester) async {
        phone(tester, size, dpr);
        late AppController c;
        await tester.runAsync(() async => c = await start(
            InMemoryRecordStore(profile: const PlayerProfile(name: '하루'))));
        await tester.pumpWidget(MaterialApp(home: InnScreen(controller: c)));
        await tester.pump();
        final r = tester.getRect(find.byKey(const Key('innCheckIn')));
        expect(r.bottom, lessThanOrEqualTo(size.height / dpr));
        await tester.pump(const Duration(seconds: 13));
      });
    }
  });

  testWidgets('#180 게시판: 오늘의 의뢰·길드 의뢰, 수락하면 도장', (tester) async {
    phone(tester, const Size(750, 1334), 2);
    late AppController c;
    await tester.runAsync(() async => c = await start(InMemoryRecordStore(
        profile: const PlayerProfile(name: '하루'))));
    await tester.pumpWidget(MaterialApp(home: BoardScreen(controller: c)));
    await tester.pump();
    final text = allText(tester);
    expect(text, contains('오늘의 의뢰'));
    expect(text, contains('길드 의뢰'));
    expect(text, isNot(contains('일일 퀘스트')));
    expect(text, isNot(contains('수시 의뢰')));
    expect(find.byKey(const Key('woodBoard')), findsOneWidget);
    expect(find.byType(ParchmentNote), findsWidgets);
    // 쪽지가 화면 밖으로 나가지 않는다
    for (final e in find.byType(ParchmentNote).evaluate()) {
      final box = e.renderObject! as RenderBox;
      final left = box.localToGlobal(Offset.zero).dx;
      expect(left, greaterThanOrEqualTo(0));
      expect(left + box.size.width, lessThanOrEqualTo(375));
    }
    final slot = c.board.slots.indexWhere((s) => s.templateId != null);
    expect(slot, greaterThanOrEqualTo(0));
    expect(find.byKey(const Key('waxSeal')), findsNothing);
    final accept = find.byKey(Key('errandAccept_$slot'));
    await tester.ensureVisible(accept);
    await tester.pump();
    await tester.tap(accept);
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('waxSeal')), findsOneWidget);
    expect(find.byKey(Key('errandWait_$slot')), findsOneWidget);
    await tester.pump(const Duration(seconds: 9));
  });

  test('쪽지 기울기는 ±2° 안', () {
    for (var i = 0; i < 50; i++) {
      expect(ParchmentNote.tiltOf(i).abs(), lessThanOrEqualTo(2));
    }
  });
}
