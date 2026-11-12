import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/models/vitals.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/level_up/level_up_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 건강 데이터가 끝내 답하지 않는 기기
class _HangHealth implements HealthSource {
  @override
  Future<bool> requestPermission() => Completer<bool>().future;
  @override
  Future<int> stepsBetween(DateTime start, DateTime end) =>
      Completer<int>().future;
}

/// 처음 한 번은 프로필을 못 읽는 저장소
class _FlakyStore extends InMemoryRecordStore {
  _FlakyStore() : super(profile: const PlayerProfile(name: '하루'));
  var fails = 1;
  @override
  Future<PlayerProfile?> loadProfile() async {
    if (fails > 0) {
      fails--;
      throw StateError('읽기 실패');
    }
    return super.loadProfile();
  }
}

void main() {
  final now = DateTime(2026, 11, 13, 10);

  AppController make(RecordStore store, {HealthSource? health}) =>
      AppController(
        store: store,
        health: health ?? FakeHealthSource(stepsByDay: const {}),
        clock: () => now,
      )..mailSources = const [];

  group('#124 예전 기록으로 시작해도 켜진다', () {
    test('쉬기 시작 값이 지금 최대보다 커도 (예전 버전 기록)', () {
      expect(TownRules.restFill(9999, 300, 0.5), 300);
      expect(TownRules.restFill(-5, 300, 0), 0);
      expect(TownRules.restFill(100, 0, 0.5), 0);
      expect(TownRules.restFill(100, 300, double.nan), 100);
    });

    test('묶음 12~14 시절 쉬는 중 기록 → 켜지고 HP는 최대 안', () async {
      final store =
          InMemoryRecordStore(profile: const PlayerProfile(name: '하루'));
      await store.saveVitals(Vitals.fromJson({
        'hp': 9999,
        'mp': 9999,
        'restStartedAt':
            now.subtract(const Duration(hours: 2)).toIso8601String(),
        'restHp0': 9999,
        'restMp0': 9999,
        // 예전 저장본은 원정 하나
        'expedition': null,
      }));
      final c = make(store);
      await c.init();
      expect(c.ready, isTrue);
      expect(c.startError, isNull);
      expect(c.hp, lessThanOrEqualTo(c.maxHp));
    });

    test('기록 하나가 틀리면 그 부분만 기본값, 원본은 따로, 나머지는 그대로',
        () async {
      final store = InMemoryRecordStore(
        profile: const PlayerProfile(name: '하루'),
        json: {
          'bag': {'singleSlots': '셋'}, // 틀린 기록
          'tutorial': {'step': 0},
        },
      );
      final c = make(store);
      await c.init();
      expect(c.ready, isTrue);
      expect(c.loadIssues, contains('bag'));
      expect(await store.loadJson('bag.broken'), {'singleSlots': '셋'});
      expect(c.profile.name, '하루');
    });

    test('건강 데이터가 답하지 않아도 화면은 먼저 열린다', () async {
      final store =
          InMemoryRecordStore(profile: const PlayerProfile(name: '하루'));
      final c = make(store, health: _HangHealth());
      await c.init();
      expect(c.ready, isTrue);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('그래도 멈추면 「다시 시도」 + 오류 기록, 다시 시도하면 켜진다', () async {
      final store = _FlakyStore();
      final c = make(store);
      await c.init();
      expect(c.ready, isFalse);
      expect(c.startError, isNotNull);
      final log = await store.loadJson('startErrors');
      expect((log?['list'] as List).length, 1);
      await c.init();
      expect(c.ready, isTrue);
      expect(c.startError, isNull);
    });
  });

  group('#124 기기 저장소에서 틀린 기록', () {
    test('하루치 하나가 틀려도 나머지 날은 지키고, 틀린 것은 따로 남긴다',
        () async {
      final good = DailyRecord(date: DateTime(2026, 11, 10), stepGoal: 8000);
      SharedPreferences.setMockInitialValues({
        'history.v1': jsonEncode([
          good.toJson(),
          {'date': '이상한 날'},
        ]),
        'vitals.v1': '{깨진',
        'json.bag': '{"singleSlots": 3',
      });
      final store = SharedPrefsRecordStore();
      final history = await store.loadHistory();
      expect(history.map((r) => r.dayKey), [good.dayKey]);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('history.v1.broken'), contains('이상한 날'));
      // 원래 기록은 지우지 않았다
      expect(prefs.getString('history.v1'), contains('이상한 날'));

      expect((await store.loadVitals()).hp, isNull);
      expect(prefs.getString('vitals.v1.broken'), '{깨진');

      await expectLater(store.loadJson('bag'), throwsA(anything));
      expect(prefs.getString('json.bag.broken'), '{"singleSlots": 3');
    });
  });

  testWidgets('#127 레벨업 창은 작은 휴대폰(칭호와 함께)에서도 한 화면, 버튼은 화면 안',
      (tester) async {
    tester.view.physicalSize = const Size(320 * 2, 568 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const LevelUpDialog(
                  from: 1,
                  to: 2,
                  title: '첫걸음을 뗀 각성자',
                  healedFrom: (hp: 3, maxHp: 120, mp: 1, mpMax: 30),
                ),
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final ok = tester.getRect(find.byKey(const Key('levelUpOk')));
    expect(ok.bottom, lessThanOrEqualTo(568));
    expect(find.byKey(const Key('levelUpArrow')), findsOneWidget);
    expect(find.text('Lv.2'), findsNothing); // 중복 Lv 명판 없음
  });

  group('#141~#144 레벨에 따라 여는 기능', () {
    test('새로 시작: Lv.1 에는 대장간·게시판·채집·돋보기 잠김, 튜토리얼은 연출부터', () async {
      final store = InMemoryRecordStore();
      final c = make(store);
      await c.init();
      await c.awaken(name: '하루', look: HeroLook.female);
      expect(c.tutorialStep, TutorialStep.intro);
      for (final f in Feature.values) {
        expect(c.featureOpen(f), isFalse, reason: f.name);
      }
      expect(c.harvestSpots, isEmpty);
      expect(c.shopItems.any((i) => i.item == ShopItem.raceLens), isFalse);
      await c.finishIntro();
      expect(c.tutorialStep, TutorialStep.hunt);
    });

    test('기존 사용자: 아무것도 잠그지 않고 안내도 띄우지 않는다', () async {
      final store =
          InMemoryRecordStore(profile: const PlayerProfile(name: '하루'));
      final c = make(store);
      await c.init();
      for (final f in Feature.values) {
        expect(c.featureOpen(f), isTrue, reason: f.name);
      }
      expect(c.pendingFeatureIntro, isNull);
      expect(c.firstWeaponFree, isFalse);
      expect(c.takeHpTip(), isFalse);
    });

    test('튜토리얼 동안 걸음 경험치는 모아 두고 Lv.1 에 머문다', () async {
      final store = InMemoryRecordStore();
      final c = make(store,
          health: FakeHealthSource(stepsByDay: {'2026-11-13': 30000}));
      await c.init();
      await c.awaken(name: '하루', look: HeroLook.male);
      expect(c.inTutorial, isTrue);
      expect(c.player.level.level, 1);
      final held = c.player.totalExp;
      await c.skipTutorial();
      expect(c.player.totalExp, greaterThanOrEqualTo(held));
    });
  });
}
