import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';

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

  /// 새로 시작한 사람 (레벨 잠금 대상), 던전으로 [days]일 경험치
  InMemoryRecordStore grown(int days,
          {List<String> seen = const [], Map<String, dynamic>? gifts}) =>
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
          'gates': {'legacy': false, 'seen': seen},
          if (gifts != null) 'gifts': gifts,
        },
      );

  group('1 한 번만 주는 선물은 따로 저장', () {
    test('예전 기록: 첫 무기를 받은 사람은 다시 못 받고, 안 받은 사람은 받는다', () async {
      final got = await start(grown(2, seen: const ['smithy', 'freeWeapon']));
      expect(got.gotGift(Gift.firstWeapon), isTrue);
      expect(got.firstWeaponFree, isFalse);
      final notYet = await start(grown(2, seen: const ['smithy']));
      expect(notYet.gotGift(Gift.firstWeapon), isFalse);
      expect(notYet.firstWeaponFree, isTrue);
    });

    test('안내 기록을 지워도 첫 무기는 다시 주지 않는다', () async {
      final c = await start(
          grown(2, seen: const [], gifts: {'got': [Gift.firstWeapon]}));
      expect(c.pendingFeatureIntro, Feature.smithy); // 안내는 다시 나와도
      expect(c.firstWeaponFree, isFalse); // 무료 무기는 없음
    });

    test('새로 설치: Lv.3 첫 무기 무료 한 번만, 다시 켜도 그대로', () async {
      final store = grown(2);
      final c = await start(store);
      expect(c.firstWeaponFree, isTrue);
      final item = await c.craft(EquipBase.ironSword);
      expect(item, isNotNull);
      expect(c.firstWeaponFree, isFalse);
      expect(c.canCraft(EquipBase.woodAxe), isNot(CraftCheck.ok));
      final again = await start(store);
      expect(again.gotGift(Gift.firstWeapon), isTrue);
      expect(again.firstWeaponFree, isFalse);
    });

    test('새로 설치: Lv.5 도구 한 벌 무료 한 번만', () async {
      final store = grown(5, seen: const ['smithy', 'board']);
      final c = await start(store);
      expect(c.harvestToolsReady, isFalse);
      expect(c.toolDurability(HarvestTool.sickle), 0); // 3: 없으면 0
      expect(await c.makeFirstTools(), isTrue);
      expect(c.gotGift(Gift.firstTools), isTrue);
      expect(c.toolDurability(HarvestTool.sickle), greaterThan(0));
      expect(await c.makeFirstTools(), isFalse);
      final again = await start(store);
      expect(await again.makeFirstTools(), isFalse);
      expect(again.allMails.any((m) => m.id == 'toolsGift'), isFalse);
    });

    test('예전 기록: 도구를 가진 기존 사용자는 받은 것으로, 우편 없음', () async {
      final c = await start(InMemoryRecordStore(
        profile: const PlayerProfile(name: '하루'),
        json: {
          'harvest': {'granted': true, 'tools': {'sickle': 7}},
        },
      ));
      expect(c.gotGift(Gift.firstTools), isTrue);
      expect(c.allMails.any((m) => m.id == 'toolsGift'), isFalse);
      expect(c.toolDurability(HarvestTool.sickle), 7);
      expect(await c.makeFirstTools(), isFalse);
    });

    test('예전 기록: 도구가 없는 기존 사용자는 우편으로 한 번만', () async {
      final store =
          InMemoryRecordStore(profile: const PlayerProfile(name: '하루'));
      final c = await start(store);
      expect(c.gotGift(Gift.firstTools), isFalse);
      final m = c.giftMails.singleWhere((x) => x.id == 'toolsGift');
      expect(await c.claimMail(m.id), contains('채집 도구 한 벌'));
      expect(c.gotGift(Gift.firstTools), isTrue);
      expect(c.harvestNeedsTool, isFalse);
      // 대장간 무료 칸으로 또 받을 수 없다
      expect(await c.makeFirstTools(), isFalse);
      final again = await start(store);
      expect(again.gotGift(Gift.firstTools), isTrue);
      expect(again.allMails.where((x) => x.id == 'toolsGift').length, 1);
    });
  });
}
