import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
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
  });

  group('설정', () {
    final now = DateTime(2026, 11, 8, 14);

    AppController make(InMemoryRecordStore store) => AppController(
          store: store,
          health: FakeHealthSource(stepsByDay: {'2026-11-08': 4000}),
          clock: () => now,
        );

    test('걸음 목표를 바꾸면 오늘 기록에도 바로 적용된다', () async {
      final c = make(InMemoryRecordStore(
          profile: const PlayerProfile(name: '하루', stepGoal: 5000)));
      await c.init();
      expect(c.history.last.stepGoalAchieved, isFalse);

      await c.setStepGoal(3000);
      expect(c.profile.stepGoal, 3000);
      expect(c.history.last.stepGoal, 3000);
      expect(c.history.last.stepGoalAchieved, isTrue);

      await c.setStepGoal(99999); // 최대 10,000보
      expect(c.profile.stepGoal, 10000);
    });

    test('첫 3일 평균에 맞춘 목표를 권한다 (500보 단위)', () async {
      // 어제 기록은 건강 앱 값으로 다시 마감하므로 건강 앱에도 같은 걸음을 둔다
      final c = AppController(
        store: InMemoryRecordStore(
        profile: const PlayerProfile(name: '하루', stepGoal: 5000),
        history: [
          DailyRecord(date: DateTime(2026, 11, 5), steps: 3900),
          DailyRecord(date: DateTime(2026, 11, 6), steps: 4300),
          DailyRecord(date: DateTime(2026, 11, 7), steps: 4100),
        ],
        ),
        health: FakeHealthSource(
            stepsByDay: {'2026-11-07': 4100, '2026-11-08': 1000}),
        clock: () => now,
      );
      await c.init();
      expect(c.stepGoalSuggestion, 4000);
    });

    test('3일 연속 목표를 넘으면 1,000보 올리기를 권한다', () async {
      final c = AppController(
        store: InMemoryRecordStore(
          profile: const PlayerProfile(name: '하루', stepGoal: 5000),
          history: [
            for (var d = 1; d <= 7; d++)
              DailyRecord(
                  date: DateTime(2026, 11, d), steps: 6000, stepGoal: 5000),
          ],
        ),
        health: FakeHealthSource(
            stepsByDay: {'2026-11-07': 6000, '2026-11-08': 1000}),
        clock: () => now,
      );
      await c.init();
      expect(c.stepGoalSuggestion, 6000);
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

    test('모든 기록을 지우면 처음(각성)으로 돌아간다', () async {
      final store = InMemoryRecordStore(
          profile: const PlayerProfile(name: '하루'));
      final c = make(store);
      await c.init();
      await store.saveRevealedCells('ansan_gojan', {'1_1'});

      await c.resetAll();
      expect(c.needsAwakening, isTrue);
      expect(await store.loadProfile(), isNull);
      expect(await store.loadHistory(), isEmpty);
      expect(await store.loadRevealedCells('ansan_gojan'), isEmpty);
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

    testWidgets('기록 탭: 최근 7일과 오늘 카드', (tester) async {
      await openDemo(tester);
      await tester.tap(find.text('기록'));
      await tester.pump();
      expect(find.text('최근 7일'), findsOneWidget);
      expect(find.textContaining('오늘 ·'), findsOneWidget);
    });

    testWidgets('도감 탭: 직업, 칭호, 몬스터', (tester) async {
      await openDemo(tester);
      await tester.tap(find.text('도감'));
      await tester.pump();
      expect(find.text('직업'), findsOneWidget);
      expect(find.textContaining('칭호 '), findsOneWidget);
      await tester.scrollUntilVisible(find.text('몬스터 도감 0 / 6'), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('몬스터 도감 0 / 6'), findsOneWidget);
    });

    testWidgets('설정 탭: 걸음 목표 바꾸기, 기록 지우기', (tester) async {
      final c = await openDemo(tester);
      await tester.tap(find.text('설정'));
      await tester.pump();

      await tester.tap(find.text('3,000보'));
      await tester.pumpAndSettle();
      expect(c.profile.stepGoal, 3000);

      final reset = find.text('모든 기록 지우고 처음부터');
      await tester.scrollUntilVisible(reset, 300,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(reset);
      await tester.pumpAndSettle();
      await tester.tap(find.text('모두 지우기'));
      await tester.pumpAndSettle();

      expect(c.needsAwakening, isTrue);
      expect(find.text('드디어 찾았다! 너구나, 탑이 고른 각성자.'), findsOneWidget);
    });
  });
}
