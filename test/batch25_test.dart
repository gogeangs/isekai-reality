import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/geo/geo.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/models/vitals.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/awakening/awakening_screen.dart';
import 'package:isekai_reality/features/bulssi/bulssi_bubble.dart';
import 'package:isekai_reality/features/bulssi/bulssi_lines.dart';

void main() {
  final t0 = DateTime(2026, 11, 14, 10);
  const home = GeoPoint(37.3219, 126.8309);

  /// 새로 설치 → 튜토리얼 끝 (Lv.2)
  Future<AppController> afterTutorial(DateTime Function() clock,
      void Function(DateTime) set) async {
    final c = AppController(
      store: InMemoryRecordStore(),
      health: FakeHealthSource(stepsByDay: const {}),
      clock: clock,
    )..mailSources = const [];
    await c.init();
    await c.awaken(name: '하루', look: HeroLook.male);
    await c.finishIntro();
    final first = c.tutorialSpawn!;
    final battle = c.startFieldBattle(first)!;
    battle.runToEnd(useSkills: true);
    await c.finishFieldBattle(first, battle);
    await c.tutorialBagSeen();
    expect(await c.sendSpirit(c.tutorialSpawn!), ExpeditionCheck.ok);
    set(clock().add(const Duration(minutes: 5)));
    await c.refreshVitals();
    for (final ex in [...c.finishedExpeditions]) {
      expect(ex.back, isTrue);
      await c.acknowledgeExpedition();
    }
    expect(c.inTutorial, isFalse);
    return c;
  }

  List<FieldSpawn> near(AppController c) =>
      [for (final s in c.todaySpawns) if (s.id.startsWith('near-')) s];

  group('#171 첫날 안에 Lv.3', () {
    test('Lv.2: 내 둘레 몬스터 3마리(400m 안), 잡으면 사라지고 다음 날 새로', () async {
      var now = t0;
      final c = await afterTutorial(() => now, (t) => now = t);
      expect(c.player.level.level, 2);
      await c.handleFix(const LocationFix(point: home));
      final first = near(c);
      expect(first.length, 3);
      for (final s in first) {
        final d = home.distanceTo(s.point);
        expect(d, inInclusiveRange(140, 410), reason: s.id);
      }
      // 걸어 다녀도 오늘 기준 자리는 그대로
      await c.handleFix(
          const LocationFix(point: GeoPoint(37.3260, 126.8350), speedMps: 1));
      expect(near(c).map((s) => s.id), first.map((s) => s.id));
      expect(near(c).first.point.lat, first.first.point.lat);

      // 잡으면 사라진다
      final target = first.first;
      for (var i = 0; i < 4 && near(c).any((s) => s.id == target.id); i++) {
        final b = c.startFieldBattle(target);
        if (b == null) break;
        b.runToEnd(useSkills: true);
        await c.finishFieldBattle(target, b);
      }
      expect(near(c).any((s) => s.id == target.id), isFalse);

      // 다음 날 새로
      now = DateTime(2026, 11, 15, 9);
      await c.handleFix(const LocationFix(point: home));
      final next = near(c);
      expect(next.length, 3);
      expect(next.first.id, isNot(first.first.id));
    });

    test('새로 설치 → Lv.2 → 몬스터 5마리로 Lv.3', () async {
      var now = t0;
      final c = await afterTutorial(() => now, (t) => now = t);
      await c.handleFix(const LocationFix(point: home));
      var wins = 0;
      for (var tries = 0; tries < 12 && wins < 5; tries++) {
        final spawns = [
          ...near(c),
          ...c.todaySpawns.where((s) => !s.id.startsWith('near-')),
        ];
        if (spawns.isEmpty) break;
        final s = spawns.first;
        final b = c.startFieldBattle(s);
        if (b == null) break;
        b.runToEnd(useSkills: true);
        await c.finishFieldBattle(s, b);
        if (c.player.today!.purifiedSpawnIds.contains(s.id)) wins++;
      }
      expect(wins, lessThanOrEqualTo(5));
      expect(c.player.level.level, greaterThanOrEqualTo(3));
    });

    test('Lv.6 이상 기존 기록: 내 둘레 몬스터 없음', () async {
      final c = AppController(
        store: InMemoryRecordStore(
          profile: const PlayerProfile(name: '하루'),
          history: [
            DailyRecord(
              date: DateTime(2026, 11, 13),
              gains: const {Wallet.exp: 2500},
            ),
          ],
        ),
        health: FakeHealthSource(stepsByDay: const {}),
        clock: () => t0,
      )..mailSources = const [];
      await c.init();
      expect(c.player.level.level, greaterThanOrEqualTo(6));
      await c.handleFix(const LocationFix(point: home));
      expect(near(c), isEmpty);
    });
  });

  group('#166 원정 대사', () {
    Expedition ex({bool? cleared, bool? back, String? pet, int startedAgo = 5}) =>
        Expedition(
          spawnId: 's',
          monster: MonsterId.ashSlime.name,
          lat: 37.32,
          lng: 126.83,
          distanceM: 300,
          mpCost: 3,
          startedAt: t0.subtract(Duration(minutes: startedAgo)),
          arriveAt: t0.add(const Duration(minutes: 5)),
          returnAt: t0.add(const Duration(minutes: 10)),
          cleared: cleared,
          back: back,
          petUid: pet == null ? null : 'p1',
          petName: pet,
        );
    String? line(Expedition e) =>
        BulssiLines.expedition(e, playerName: '하루', now: t0);

    test('단계별 · 이름 · 펫', () {
      expect(line(ex(startedAgo: 0)), '하루 대신 내가 원정을 다녀올게. 돌아오면 알려 줄게!');
      expect(line(ex()), endsWith('에게 가는 중이야. 조금만 기다려 줘!'));
      expect(line(ex(cleared: true, back: false)), '정화했어! 지금 돌아가는 중이야.');
      expect(line(ex(cleared: false, back: false)), '이번엔 놓쳤어… 돌아가서 다시 준비하자.');
      expect(line(ex(cleared: true, back: true)), '다녀왔어! 결과를 확인해 볼래?');
      expect(line(ex(pet: '콩')), '콩이 원정 중이야');
      expect(line(ex(pet: '보리')), '보리가 원정 중이야');
      expect(line(ex(pet: '보리', cleared: true, back: true)), isNull);
      expect(BulssiLines.expedition(null, playerName: '하루', now: t0), isNull);
    });

    testWidgets('배지를 누르면 대사 끝에 「서두를까?」', (tester) async {
      var rushed = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SpiritTalkBadge(
            line: '하루 대신 내가 원정을 다녀올게.',
            maxBubbleWidth: 260,
            actionLabel: '서두를까?',
            onAction: () => rushed++,
          ),
        ),
      ));
      await tester.pump();
      expect(find.byKey(const Key('spiritAction')), findsNothing);
      await tester.tap(find.byKey(const Key('spiritBadge')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('spiritAction')), findsOneWidget);
      await tester.tap(find.byKey(const Key('spiritAction')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(rushed, 1);
      await tester.pump(const Duration(seconds: 9));
    });
  });

  group('#165 능력치 안내', () {
    test('새로 설치: 튜토리얼 뒤 Lv.2 → 능력치 안내, 다 나누면 끝', () async {
      var now = t0;
      final c = await afterTutorial(() => now, (t) => now = t);
      while (c.pendingLevelUp != null) {
        await c.acknowledgeLevelUp();
      }
      expect(c.unspentPoints, greaterThan(0));
      expect(c.pendingFeatureIntro, Feature.stats);
      await c.markFeatureIntro(Feature.stats);
      expect(c.pendingFeatureIntro, isNot(Feature.stats));
    });

    test('예전 기록: 남은 포인트가 있어도 안내 없음', () async {
      final c = AppController(
        store: InMemoryRecordStore(
          profile: const PlayerProfile(name: '하루'),
          history: [
            DailyRecord(
                date: DateTime(2026, 11, 13), gains: const {Wallet.exp: 200}),
          ],
        ),
        health: FakeHealthSource(stepsByDay: const {}),
        clock: () => t0,
      )..mailSources = const [];
      await c.init();
      expect(c.pendingFeatureIntro, isNull);
    });
  });

  group('#163 각성 장면 자리', () {
    for (final size in const [
      Size(320, 568), // 작은 iPhone
      Size(375, 667),
      Size(390, 844),
      Size(430, 932), // 큰 iPhone
      Size(412, 915), // Android
    ]) {
      test('$size: 발은 마법진 가운데, 정령은 오른쪽 어깨 높이', () {
        final g = FinaleLayout.of(size);
        expect(g.circle.dx, closeTo(size.width / 2, size.width * 0.02));
        expect(g.hero.bottomCenter.dx, closeTo(g.circle.dx, 0.5));
        expect(g.hero.bottom, closeTo(g.circle.dy, 0.5));
        expect(g.spirit.center.dx, greaterThan(g.hero.center.dx));
        expect(g.spirit.center.dy, lessThan(g.hero.center.dy));
        expect(g.spirit.center.dy, greaterThan(g.hero.top));
        expect(g.spirit.right, lessThanOrEqualTo(size.width));
        expect(g.hero.top, greaterThan(0));
      });
    }
  });
}
