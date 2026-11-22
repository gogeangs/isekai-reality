// 묶음 82: #396 마을 기록 지워짐 · #383 안내 · #390 · #394 잿빛 틈 턴제 · #381 원정 동행 · #392 · #393 · #395 · 화면 정리

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/models/pet_state.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';

final _t0 = DateTime(2026, 11, 16, 10);

Map<String, dynamic> _petsJson() => PetState(
      pets: [Pet(uid: 'p1', species: PetSpecies.owl, name: '부엉', bornAt: DateTime(2026, 11, 1))],
      companion: 'p1',
      firstPet: 'p1',
      firstSpiritName: '불씨',
      farewellAt: DateTime(2026, 11, 2),
    ).toJson();

InMemoryRecordStore _store(int level, Map<String, dynamic> json) => InMemoryRecordStore(
      profile: const PlayerProfile(
          name: '하루', spiritName: '불씨', spiritKind: SpiritKind.water, lastSeenLevel: 99),
      history: [
        DailyRecord(date: DateTime(2026, 11, 15), gains: {'exp': LevelRules.totalExpToReach(level)}),
      ],
      json: {
        'tutorial': {'step': TutorialStep.done.index},
        'gates': {
          'legacy': false,
          'v28': true,
          'seen': [for (final f in Feature.values) f.name],
        },
        ...json,
      },
    );

Future<AppController> _open(InMemoryRecordStore s) async {
  final c = AppController(
    store: s,
    health: FakeHealthSource(stepsByDay: const {}),
    clock: () => _t0,
  )..mailSources = const [];
  await c.init();
  return c;
}

Future<Set<String>> _seen(InMemoryRecordStore s) async =>
    {for (final x in ((await s.loadJson('village'))?['seen'] as List? ?? const [])) '$x'};

void main() {
  group('#396 마을 기록', () {
    test('첫 무기를 분해한 기록: 두 번 켜도 마을 기록 그대로', () async {
      final s = _store(14, {
        'gifts': {'got': [Gift.firstWeapon]},
        'armory': const {'items': [], 'equipped': {}, 'nextId': 3},
        'pets': _petsJson(),
        'village': {
          'seen': ['intro', 'farewell', 'shelterCard', 'trainingCard', 'chatTour', 'met:marta'],
          'visits': {'marta': 3},
        },
      });
      final a = await _open(s);
      expect(a.shelterIntroPending, isFalse);
      expect(a.villageIntroPending, isFalse);
      final b = await _open(s);
      expect(b.shelterIntroPending, isFalse);
      expect(b.trainingIntroPending, isFalse);
      final seen = await _seen(s);
      expect(seen, containsAll(['intro', 'shelterCard', 'trainingCard', 'chatTour', 'met:marta', 'giftMarked']));
      expect((await s.loadJson('village'))!['visits'], {'marta': 3});
    });

    test('켜는 중 막이: 읽기 전 마을 표시는 모았다가 합침 · 읽기 전 저장은 하지 않음', () async {
      final s = _store(14, {
        'gifts': {'got': [Gift.firstWeapon]},
        'pets': _petsJson(),
        'village': {'seen': ['intro', 'shelterCard'], 'visits': {}},
      });
      final c = await _open(s);
      expect(c.blockedSaves.where((k) => k == 'village'), isEmpty);
      expect(await _seen(s), containsAll(['intro', 'shelterCard', 'giftMarked', 'v82']));
    });

    test('되살리기: 지워진 Lv.20 기록 → 카드 하나도 안 뜸 · 한 번만', () async {
      final s = _store(20, {
        'gifts': {'got': [Gift.firstWeapon]},
        'pets': _petsJson(),
        'jobs': {'awakened': true, 'v57': true, 'v31': true, 'main': 'warrior', 'owned': ['warrior']},
        'npc': {'v': 1, 'points': {'marta': 12, 'mina': 3}},
        'training': {'daily': '2026-11-14'},
        'garden': {'harvested': 2},
        'tavern': {'meals': 1},
        'village': {'seen': ['giftMarked'], 'visits': {}},
      });
      final c = await _open(s);
      expect(c.revivedVillage, isNotEmpty, reason: '${c.revivedVillage}');
      expect(c.shelterIntroPending, isFalse);
      expect(c.trainingIntroPending, isFalse);
      expect(c.subJobIntroPending, isFalse);
      expect(c.gardenIntroPending, isFalse);
      expect(c.tavernIntroPending, isFalse);
      expect(c.chatTourPending, isFalse);
      expect(c.villageIntroPending, isFalse);
      expect(c.friendSceneSeen, isTrue);
      final seen = await _seen(s);
      expect(seen, containsAll(['met:marta', 'met:mina', 'meet', 'market', 'v82']));
      // 두 번째 켤 때는 되살리기 없음
      final d = await _open(s);
      expect(d.revivedVillage, isEmpty);
    });

    test('지워진 적 없는 기록은 되살리지 않음(새 계정 카드는 그대로)', () async {
      final s = _store(14, {'pets': _petsJson(), 'village': {'seen': ['intro'], 'visits': {}}});
      final c = await _open(s);
      expect(c.revivedVillage, isEmpty);
      expect(c.shelterIntroPending, isTrue);
    });
  });

  // 아래 묶음 82 시험은 항목을 고칠 때마다 더함
  test('자리', () => expect(const SizedBox(), isNotNull));
}
