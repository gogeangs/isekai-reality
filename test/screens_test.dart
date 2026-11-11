import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/features/profile/profile_screen.dart';
import 'package:isekai_reality/core/rules/title_rules.dart';
import 'package:isekai_reality/app.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/bulssi/bulssi_mood.dart';

void main() {
  group('불씨 색 (날씨 기능은 묶음 13에서 뺐다)', () {
    test('낮에는 황금, 밤에는 보라 (기기 시간만)', () {
      expect(BulssiMoods.of(now: DateTime(2026, 11, 8, 13)), BulssiMood.gold);
      expect(BulssiMoods.of(now: DateTime(2026, 11, 8, 21)), BulssiMood.night);
      expect(BulssiMoods.of(now: DateTime(2026, 11, 8, 4)), BulssiMood.night);
    });
  });

  group('설정', () {
    final now = DateTime(2026, 11, 8, 14);

    AppController make(InMemoryRecordStore store) => AppController(
          store: store,
          health: FakeHealthSource(stepsByDay: {'2026-11-08': 4000}),
          clock: () => now,
        );

    test('걸음 목표는 모두 같다 (3,000보, 예전에 바꾼 목표는 무시)', () async {
      final c = make(InMemoryRecordStore(
          profile: const PlayerProfile(name: '하루', stepGoal: 8000)));
      await c.init();
      expect(c.history.last.stepGoal, 3000);
      expect(c.history.last.stepGoalAchieved, isTrue); // 4,000보
    });

    test('이름은 처음 1번 무료, 그다음 금화 300 (빈 이름은 무시)', () async {
      final c = make(InMemoryRecordStore(
          profile: const PlayerProfile(name: '하루')));
      await c.init();
      expect(c.renameCost, 0);
      expect(await c.renameHero('   '), isFalse);
      expect(await c.renameHero('  새벽 '), isTrue);
      expect(c.profile.name, '새벽');
      expect(c.renameCost, AppController.renameGold);
      // 금화가 없으면 못 바꾼다
      expect(await c.renameHero('노을'), isFalse);
      expect(c.profile.name, '새벽');
    });

    test('기록 내보내기: 하루별 한 줄, 좌표·이름 없음', () async {
      final c = AppController.demo(clock: () => DateTime(2026, 11, 8, 14));
      await c.init();
      final csv = c.exportRecordsCsv();
      final lines = csv.trim().split('\n');
      expect(lines.first, startsWith('날짜,걸음,목표'));
      expect(lines.length, 1 + 14 + 1);
      expect(lines[14], startsWith('2026-11-08,6400,8000,0,0,0,0,'));
      expect(lines[14], endsWith(',${c.player.level.level}'));
      expect(csv, isNot(contains('하루')));
      expect(csv, isNot(contains('37.')));
    });

    test('모든 기록을 지우면 처음(각성)으로 돌아간다', () async {
      final store = InMemoryRecordStore(
          profile: const PlayerProfile(name: '하루'));
      final c = make(store);
      await c.init();
      await store.saveRevealedCells('ansan', {'1_1'});

      await c.resetAll();
      expect(c.needsAwakening, isTrue);
      expect(await store.loadProfile(), isNull);
      expect(await store.loadHistory(), isEmpty);
      expect(await store.loadRevealedCells('ansan'), isEmpty);
    });
  });

  group('화면', () {
    Future<AppController> openDemo(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final c = AppController.demo(clock: () => DateTime(2026, 11, 8, 14));
      await tester.pumpWidget(IsekaiRealityApp(controller: c));
      await c.init();
      await tester.pump();
      return c;
    }

    testWidgets('프로필 기록: 최근 7일과 오늘 카드', (tester) async {
      await openDemo(tester);
      // 11-10: 기록은 왼쪽 위 프로필 안으로 옮겼다
      await tester.tap(find.byType(ProfileButton));
      await tester.pumpAndSettle();
      expect(find.text('칭호'), findsWidgets);
      await tester.tap(find.text('기록'));
      await tester.pump();
      expect(findK('최근 7일', contains: true), findsOneWidget);
      await tester.scrollUntilVisible(find.textContaining('오늘 ·'), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.textContaining('오늘 ·'), findsOneWidget);
    });

    testWidgets('도감은 몬스터 한 화면, 칭호는 프로필에서', (tester) async {
      await openDemo(tester);
      await tester.tap(find.text('도감'));
      await tester.pump();
      expect(findK('몬스터 도감 0 / 22'), findsOneWidget);
      await tester.scrollUntilVisible(find.textContaining('희귀·전설'), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.textContaining('희귀·전설'), findsWidgets);
      await tester.tap(find.byType(ProfileButton));
      await tester.pumpAndSettle();
      expect(find.textContaining('/ ${TitleRules.all.length}'), findsWidgets);
    });

    testWidgets('설정(오른쪽 위 톱니바퀴): 기록 지우기', (tester) async {
      final c = await openDemo(tester);
      await tester.tap(find.byTooltip('설정'));
      await tester.pumpAndSettle();


      final reset = find.text('모든 기록 지우고 처음부터');
      await tester.scrollUntilVisible(reset, 300,
          scrollable: find.byType(Scrollable).first);
      // 하단 메뉴에 가리지 않게 조금 더 올린다
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -250));
      await tester.pumpAndSettle();
      await tester.tap(reset);
      await tester.pumpAndSettle();
      await tester.tap(find.text('모두 지우기'));
      await tester.pumpAndSettle();

      expect(c.needsAwakening, isTrue);
      expect(find.text('오늘도 별일 없는 하루였어.'), findsOneWidget);
    });
  });
}

/// 줄바꿈 금지 문자(keepAll)를 빼고 글자를 찾는다
Finder findK(String text, {bool contains = false}) => find.byWidgetPredicate((w) {
      if (w is! Text) return false;
      final d = (w.data ?? w.textSpan?.toPlainText() ?? '').replaceAll('\u2060', '');
      return contains ? d.contains(text) : d == text;
    });
