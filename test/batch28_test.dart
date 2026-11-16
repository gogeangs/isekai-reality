import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/geo/geo.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';

void main() {
  final t0 = DateTime(2026, 11, 15, 10);
  const home = GeoPoint(37.3219, 126.8309);

  Future<AppController> start(InMemoryRecordStore store) async {
    final c = AppController(
      store: store,
      health: FakeHealthSource(stepsByDay: const {}),
      clock: () => t0,
    )..mailSources = const [];
    await c.init();
    return c;
  }

  /// 새로 시작한 사람, [days]일 던전 → 레벨. [v28] 이면 이 묶음 저장 방식(옮기기 없음)
  InMemoryRecordStore grown(int days,
          {List<String> seen = const [],
          bool v28 = true,
          Map<String, dynamic> extra = const {}}) =>
      InMemoryRecordStore(
        profile: const PlayerProfile(name: '하루', lastSeenLevel: 99),
        history: [
          for (var i = days; i >= 1; i--)
            DailyRecord(
              date: DateTime(2026, 11, 14 - i),
              dungeonRuns: List.filled(4, const DungeonRun(cleared: true)),
            ),
        ],
        json: {
          'tutorial': {'step': TutorialStep.done.index},
          'gates': {'legacy': false, 'seen': seen, if (v28) 'v28': true},
          'harvest': {
            'granted': true,
            'tools': {for (final t in HarvestTool.values) t.name: 20},
          },
          ...extra,
        },
      );

  const before = [
    'stats', 'smithy', 'freeWeapon', 'board', 'harvest', 'lens',
    'opened:smithy', 'opened:board', 'opened:harvest', 'opened:lens',
  ];

  group('#176 확인 답', () {
    test('31번 대사', () {
      expect(MasteryRules.stageLine(Mastery.trade, MasteryStage.expert),
          '조합에서도 네 이름을 알더라. 일 맡기기 든든하대!');
    });

    test('기존 계정: 대장간 좋은 등급은 예전 값(10개마다 +1%p)보다 줄지 않음', () async {
      final c = await start(InMemoryRecordStore(
        profile: const PlayerProfile(name: '하루'),
        json: {
          'armory': {'crafts': 57, 'items': [], 'nextId': 60},
        },
      ));
      expect(c.masteryState.smithFloor, 5);
      expect(c.smithGradeBonus(EquipBase.ironSword), 5);
      expect(c.smithGradeBonus(EquipBase.woodAxe), 5);
      // iPhone 129 숙련도 저장본(바닥값 없음)도 한 번 채운다
      final again = await start(InMemoryRecordStore(
        profile: const PlayerProfile(name: '하루'),
        json: {
          'armory': {'crafts': 31, 'items': [], 'nextId': 40},
          'mastery': {
            'detail': {'smith:sword': 150},
          },
        },
      ));
      expect(again.masteryState.smithFloor, 3);
      expect(again.smithGradeBonus(EquipBase.ironSword), 10); // 숙련도가 더 크면 그쪽
      expect(again.smithGradeBonus(EquipBase.woodAxe), 3);
    });
  });

  group('#181 채집 자리 나눠 열기', () {
    test('여는 레벨: 꽃·버섯 5 · 약초 7 · 광석·보석 8 · 나무·물가 9 · 유물 10', () {
      expect(HarvestRules.openLevel(HarvestKind.flower), 5);
      expect(HarvestRules.openLevel(HarvestKind.mushroom), 5);
      expect(HarvestRules.openLevel(HarvestKind.herb), 7);
      expect(HarvestRules.openLevel(HarvestKind.ore), 8);
      expect(HarvestRules.openLevel(HarvestKind.gem), 8);
      expect(HarvestRules.openLevel(HarvestKind.wood), 9);
      expect(HarvestRules.openLevel(HarvestKind.water), 9);
      expect(HarvestRules.openLevel(HarvestKind.relic), 10);
      expect(AppController.featureLevel[Feature.alchemy], 7);
      expect(AppController.featureLevel[Feature.relic], 10);
    });

    test('새로 시작: 지도에는 지금 레벨에 맞는 채집 자리만', () async {
      for (final days in [5, 7, 9]) {
        final c = await start(grown(days, seen: [
          ...before,
          'alchemy', 'ore', 'wood', 'relic',
        ]));
        await c.handleFix(const LocationFix(point: home));
        final lv = c.player.level.level;
        final kinds = {for (final s in c.harvestSpots) s.kind};
        for (final k in kinds) {
          expect(HarvestRules.openLevel(k), lessThanOrEqualTo(lv),
              reason: 'Lv.$lv ${k.name}');
        }
      }
    });

    test('연금술 공방은 Lv.7 전엔 잠김, 업데이트 때 이미 쓰던 사람은 그대로', () async {
      final low = await start(grown(3, seen: before));
      expect(low.player.level.level, lessThan(7));
      expect(low.featureOpen(Feature.alchemy), isFalse);
      final used = await start(grown(3, seen: before, v28: false, extra: {
        'alchemy': {
          'discovered': ['healSmall'],
        },
      }));
      expect(used.featureOpen(Feature.alchemy), isTrue);
    });

    test('업데이트 때 이미 Lv.7 이상: 채집 자리·연금술 그대로, 안내 없음', () async {
      final store = grown(9, seen: before, v28: false);
      final c = await start(store);
      expect(c.player.level.level, greaterThanOrEqualTo(7));
      expect(c.pendingFeatureIntro, isNot(Feature.alchemy));
      if (c.player.level.level < 8) {
        expect(c.pendingFeatureIntro, isNot(Feature.ore));
      }
      await c.handleFix(const LocationFix(point: home));
      // 예전처럼 모든 채집 자리 (레벨보다 높은 것도)
      final again = await start(store);
      await again.handleFix(const LocationFix(point: home));
      expect(again.pendingFeatureIntro, isNot(Feature.alchemy));
    });

    test('Lv.7 새로 오른 사람: 연금술 안내 + 가까이(50~150m) 약초 덤불 하나, 그날 고정',
        () async {
      // Lv.7 이 되는 날 수를 찾는다
      var days = 6;
      late AppController c;
      while (true) {
        c = await start(grown(days, seen: before));
        if (c.player.level.level >= 7) break;
        days++;
      }
      expect(c.pendingFeatureIntro, Feature.alchemy);
      await c.handleFix(const LocationFix(point: home));
      final g = c.harvestSpots.where((s) => s.id == 'guide-herb').toList();
      expect(g, hasLength(1));
      expect(g.single.kind, HarvestKind.herb);
      expect(g.single.point.distanceTo(home), inInclusiveRange(45, 155));
      await c.handleFix(
          const LocationFix(point: GeoPoint(37.3230, 126.8320), speedMps: 1));
      final g2 = c.harvestSpots.singleWhere((s) => s.id == 'guide-herb');
      expect(g2.point.lat, g.single.point.lat);
    });

    test('첫 물약: 재료가 모자라면 false, 있으면 바로 완성', () async {
      var days = 6;
      late AppController c;
      while (true) {
        c = await start(grown(days, seen: [...before, 'opened:alchemy']));
        if (c.player.level.level >= 7) break;
        days++;
      }
      expect(c.firstPotionGuide, isTrue);
      expect(c.firstPotionMissing, isNotEmpty);
      expect(await c.brewFirstPotion(), isFalse);
    });
  });

  group('#181 고대 유물 예언 조각', () {
    test('처음 세 번 차례로 1·2·3, 그 뒤엔 없음, 기록 탭에 모은 조각만', () async {
      final c = await start(InMemoryRecordStore(
        profile: const PlayerProfile(name: '하루'),
        json: {
          'harvest': {
            'granted': true,
            'tools': {for (final t in HarvestTool.values) t.name: 20},
          },
        },
      ));
      await c.handleFix(const LocationFix(point: home));
      expect(c.prophecyPieces, isEmpty);
      final got = <int?>[];
      for (var i = 0; i < 4; i++) {
        final spot =
            HarvestSpot(id: 'relic-$i', kind: HarvestKind.relic, point: home);
        expect(await c.harvestAt(spot, HarvestGrade.quick), isNotNull);
        got.add(c.takeProphecy());
      }
      expect(got, [0, 1, 2, null]);
      expect(c.prophecyPieces, [
        for (final p in HarvestRules.prophecy) p.$1,
      ]);
      expect(HarvestRules.prophecy[2].$1, contains('잿빛 군주'));
    });
  });
}
