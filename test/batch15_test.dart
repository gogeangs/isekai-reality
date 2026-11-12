import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/bag_state.dart';
import 'package:isekai_reality/core/models/vitals.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/status/status_screen.dart';

void main() {
  group('#108 장비 칸은 무대 안에', () {
    test('넉넉하면 그대로, 모자라면 간격 → 칸 크기 순으로 줄인다', () {
      expect(gearSlotFit(400), (size: 50.0, gap: 8.0));
      final a = gearSlotFit(156);
      expect(a.size, 50);
      expect(a.size * 3 + a.gap * 2, lessThanOrEqualTo(156));
      final b = gearSlotFit(130);
      expect(b.size * 3 + b.gap * 2, lessThanOrEqualTo(130.001));
      expect(b.size, lessThan(50));
      expect(gearSlotFit(10).size, 36); // 아주 작으면 최소 크기
    });
  });

  test('#114 화면 글에 개발 메모(#번호·날짜)가 없다', () {
    final pat = RegExp(r'(\(\s*1[01]-1\d|#\d{1,3}\b|묶음\s*\d)');
    final str = RegExp(r"'(?:[^'\\\n]|\\.)*'");
    final bad = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      for (final line in f.readAsLinesSync()) {
        final code = line.split('//').first;
        for (final m in str.allMatches(code)) {
          final t = m.group(0)!;
          if (pat.hasMatch(t) && !t.contains('Key') && !t.contains('#\$')) {
            bad.add('${f.path}: $t');
          }
        }
      }
    }
    expect(bad, isEmpty);
  });

  group('#107 쉬는 동안 차오름', () {
    test('시간에 맞춰 고르게, 끝나면 가득', () {
      final t0 = DateTime(2026, 11, 12, 10);
      expect(TownRules.restProgress(t0, t0), 0);
      expect(TownRules.restProgress(t0, t0.add(const Duration(hours: 2))),
          closeTo(0.5, 1e-9));
      expect(TownRules.restFill(100, 300, 0.5), 200);
      expect(TownRules.restFill(100, 300, 1), 300);
    });

    test('일어나면 찬 만큼은 그대로, 광고로 줄이면 바로 더 참', () async {
      var now = DateTime(2026, 11, 12, 10);
      final store =
          InMemoryRecordStore(profile: const PlayerProfile(name: '하루'));
      await store.saveVitals(const Vitals(hp: 1, mp: 0));
      final c = AppController(
        store: store,
        health: FakeHealthSource(stepsByDay: const {}),
        clock: () => now,
      )..mailSources = const [];
      await c.init();
      final max = c.maxHp;
      expect(await c.restAtInn(), isTrue);
      now = now.add(const Duration(hours: 1));
      await c.refreshVitals();
      final mid = c.hp;
      expect(mid, greaterThan(1));
      expect(mid, lessThan(max));
      // 광고로 1시간 줄이기 → 바로 더 찬다
      c.watchAd = (_) async => true;
      expect(await c.adShortenRest(), isTrue);
      expect(c.hp, greaterThan(mid));
      final before = c.hp;
      await c.stopResting();
      expect(c.resting, isFalse);
      expect(c.hp, greaterThanOrEqualTo(before));
    });
  });

  group('#106 가방 한 칸씩', () {
    test('예전 묶음은 그대로, 첫째·둘째 칸은 광고로도', () async {
      final store =
          InMemoryRecordStore(profile: const PlayerProfile(name: '하루'));
      await store.saveJson('bag', const BagState(goldExpansions: 1).toJson());
      final c = AppController(
        store: store,
        health: FakeHealthSource(stepsByDay: const {}),
        clock: () => DateTime(2026, 11, 12, 10),
      )..mailSources = const [];
      await c.init();
      expect(c.bagCapacity, 25);
      expect(c.bagExpandCost, 80);
      expect(c.bagSlotByAd, isTrue);
      c.watchAd = (_) async => true;
      expect(await c.expandBag(byAd: true), isTrue);
      expect(await c.expandBag(byAd: true), isTrue);
      expect(c.bagCapacity, 27);
      expect(c.bagSlotByAd, isFalse); // 셋째 칸부터 금화만
      expect(await c.expandBag(byAd: true), isFalse);
      expect(c.bagExpandCost, 130);
    });
  });

  group('#104 튜토리얼', () {
    test('새로 시작하면 바로 옆 몬스터, 건너뛰면 끝. 기존 사용자는 없음', () async {
      final now = DateTime(2026, 11, 12, 10);
      final c = AppController(
        store: InMemoryRecordStore(),
        health: FakeHealthSource(stepsByDay: const {}),
        clock: () => now,
      )..mailSources = const [];
      await c.init();
      await c.awaken(name: '하루', look: HeroLook.male);
      expect(c.tutorialStep, TutorialStep.hunt);
      expect(c.tutorialSpawn?.id, AppController.tutorialHuntId);
      await c.skipTutorial();
      expect(c.inTutorial, isFalse);
      expect(c.tutorialSpawn, isNull);

      final old = AppController(
        store: InMemoryRecordStore(profile: const PlayerProfile(name: '하루')),
        health: FakeHealthSource(stepsByDay: const {}),
        clock: () => now,
      )..mailSources = const [];
      await old.init();
      expect(old.inTutorial, isFalse);
    });

    test('둘째 몬스터(정령 원정)를 잡으면 Lv.2', () async {
      var now = DateTime(2026, 11, 12, 10);
      final c = AppController(
        store: InMemoryRecordStore(),
        health: FakeHealthSource(stepsByDay: const {}),
        clock: () => now,
      )..mailSources = const [];
      await c.init();
      await c.awaken(name: '하루', look: HeroLook.male);
      final first = c.tutorialSpawn!;
      final battle = c.startFieldBattle(first)!;
      battle.runToEnd(useSkills: true);
      await c.finishFieldBattle(first, battle);
      expect(c.player.level.level, 1); // 첫 전투만으로는 오르지 않는다
      expect(c.tutorialStep, TutorialStep.bag);
      await c.tutorialBagSeen();
      expect(c.tutorialStep, TutorialStep.expedition);
      final second = c.tutorialSpawn!;
      expect(await c.sendSpirit(second), ExpeditionCheck.ok);
      now = now.add(const Duration(minutes: 1));
      await c.refreshVitals();
      expect(c.player.level.level, 2);
      expect(c.inTutorial, isFalse);
    });
  });

  test('#116 도감 펫 탭은 정령과 이별한 뒤에만', () async {
    final c = AppController(
      store: InMemoryRecordStore(profile: const PlayerProfile(name: '하루')),
      health: FakeHealthSource(stepsByDay: const {}),
      clock: () => DateTime(2026, 11, 12, 10),
    )..mailSources = const [];
    await c.init();
    expect(c.petCodexOpen, c.farewellDone);
  });
}
