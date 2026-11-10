import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/features/profile/profile_screen.dart';
import 'package:isekai_reality/core/rules/title_rules.dart';
import 'package:isekai_reality/app.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/data/weather/weather_source.dart';
import 'package:isekai_reality/features/bulssi/bulssi_mood.dart';

void main() {
  group('날씨와 불씨 색', () {
    test('WMO 날씨 코드를 네 가지로 묶는다', () {
      expect(WeatherNow.kindFromWmo(0), WeatherKind.clear);
      expect(WeatherNow.kindFromWmo(3), WeatherKind.cloudy);
      expect(WeatherNow.kindFromWmo(45), WeatherKind.cloudy);
      expect(WeatherNow.kindFromWmo(61), WeatherKind.rain);
      expect(WeatherNow.kindFromWmo(81), WeatherKind.rain);
      expect(WeatherNow.kindFromWmo(95), WeatherKind.rain);
      expect(WeatherNow.kindFromWmo(73), WeatherKind.snow);
      expect(WeatherNow.kindFromWmo(86), WeatherKind.snow);
    });

    test('Open-Meteo 응답을 읽는다', () {
      final w = OpenMeteoWeatherSource.parse({
        'current': {'weather_code': 63, 'is_day': 1, 'temperature_2m': 8.4},
      })!;
      expect(w.kind, WeatherKind.rain);
      expect(w.isDay, isTrue);
      expect(w.temperatureC, 8.4);
      expect(OpenMeteoWeatherSource.parse({'oops': 1}), isNull);
    });

    test('맑음 황금, 비 하늘색, 눈 흰색, 밤에는 보라', () {
      final noon = DateTime(2026, 11, 8, 13);
      expect(BulssiMoods.of(now: noon), BulssiMood.gold);
      expect(
          BulssiMoods.of(
              weather: const WeatherNow(kind: WeatherKind.rain), now: noon),
          BulssiMood.sky);
      expect(
          BulssiMoods.of(
              weather: const WeatherNow(kind: WeatherKind.snow), now: noon),
          BulssiMood.snow);
      expect(
          BulssiMoods.of(
              weather: const WeatherNow(kind: WeatherKind.rain),
              now: DateTime(2026, 11, 8, 21)),
          BulssiMood.night);
      expect(
          BulssiMoods.of(
              weather: const WeatherNow(kind: WeatherKind.clear, isDay: false),
              now: noon),
          BulssiMood.night);
    });

    test('날씨는 30분에 한 번만 읽고, 상태창에 이름과 기온을 보여 준다', () async {
      var now = DateTime(2026, 11, 8, 13);
      final weather = FakeWeatherSource(
          const WeatherNow(kind: WeatherKind.rain, temperatureC: 7.6));
      final c = AppController(
        store: InMemoryRecordStore(profile: const PlayerProfile(name: '하루')),
        health: FakeHealthSource(),
        weatherSource: weather,
        clock: () => now,
      );
      await c.init();
      await c.refreshWeather();
      expect(weather.calls, 1);
      expect(c.weatherLabel, '비 8°');
      expect(c.bulssiMood, BulssiMood.sky);

      now = now.add(const Duration(minutes: 31));
      await c.refreshWeather();
      expect(weather.calls, 2);
    });

    test('날씨 조회를 끄면 조회하지 않고 받은 날씨도 버린다', () async {
      final weather = FakeWeatherSource(
          const WeatherNow(kind: WeatherKind.rain, temperatureC: 7.6));
      final c = AppController(
        store: InMemoryRecordStore(profile: const PlayerProfile(name: '하루')),
        health: FakeHealthSource(),
        weatherSource: weather,
        clock: () => DateTime(2026, 11, 8, 13),
      );
      await c.init();
      await c.refreshWeather();
      final calls = weather.calls;

      await c.setWeatherEnabled(false);
      expect(c.weatherLabel, '날씨 꺼짐');
      expect(c.weather, isNull);
      await c.refreshWeather(force: true);
      expect(weather.calls, calls);
      expect(c.profile.weatherEnabled, isFalse);
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

    test('이름과 정령 이름을 바꾼다 (빈 이름은 무시)', () async {
      final c = make(InMemoryRecordStore(
          profile: const PlayerProfile(name: '하루')));
      await c.init();
      await c.renameHero('  새벽 ');
      await c.renameSpirit('반딧불');
      await c.renameSpirit('   ');
      expect(c.profile.name, '새벽');
      expect(c.profile.spiritName, '반딧불');
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
      expect(find.text('대표 칭호'), findsOneWidget);
      await tester.tap(find.text('기록'));
      await tester.pump();
      expect(findK('최근 7일', contains: true), findsOneWidget);
      await tester.scrollUntilVisible(find.textContaining('오늘 ·'), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.textContaining('오늘 ·'), findsOneWidget);
    });

    testWidgets('도감 탭: 칭호, 몬스터', (tester) async {
      await openDemo(tester);
      await tester.tap(find.text('도감'));
      await tester.pump();
      expect(find.textContaining('/${TitleRules.all.length}'), findsWidgets);
      expect(findK('몬스터 도감 0 / 5'), findsNothing);
      // 탭을 누르면 몬스터 그룹만 보인다
      await tester.tap(find.text('몬스터 0/5'));
      await tester.pump();
      expect(findK('몬스터 도감 0 / 5'), findsOneWidget);
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
