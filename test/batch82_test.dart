// 묶음 82: #396 마을 기록 지워짐 · #383 안내 · #390 · #394 잿빛 틈 턴제 · #381 원정 동행 · #392 · #393 · #395 · 화면 정리

import 'dart:io';

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

  group('#383 안내', () {
    test('첫 카드를 보여 준 순간 봤음 · 이번 실행에서는 끝까지 · 다시 켜면 안 뜸', () async {
      final s = _store(12, {'pets': _petsJson(), 'village': {'seen': ['intro'], 'visits': {}}});
      final a = await _open(s);
      expect(a.shelterIntroPending, isTrue);
      await a.beginTour('shelter');
      expect(a.shelterIntroPending, isTrue); // 보여 주는 중
      expect(await _seen(s), contains('shelterCard'));
      final b = await _open(s); // 중간에 앱을 끔
      expect(b.shelterIntroPending, isFalse);
      await a.markShelterIntro();
      expect(a.shelterIntroPending, isFalse);
    });

    test('기능 안내도 같음 (f:smithy)', () async {
      final s = _store(4, {
        'gates': {'legacy': false, 'v28': true, 'seen': [for (final f in Feature.values) if (f != Feature.smithy) f.name]},
      });
      final a = await _open(s);
      expect(a.pendingFeatureIntro, Feature.smithy);
      await a.beginTour('f:smithy');
      expect(a.pendingFeatureIntro, Feature.smithy);
      final b = await _open(s);
      expect(b.pendingFeatureIntro, isNull);
      await a.markFeatureIntro(Feature.smithy);
      expect(a.pendingFeatureIntro, isNull);
    });

    test('앱이 열릴 때: 이미 써 본 기능의 안내는 봤음 (장비가 있으면 대장간)', () async {
      final s = _store(5, {
        'gates': {'legacy': false, 'v28': true, 'seen': [for (final f in Feature.values) if (f != Feature.smithy) f.name]},
        'armory': const {
          'items': [
            {'uid': 'eq1', 'base': 'dagger', 'grade': 'white'},
          ],
          'equipped': {},
          'nextId': 2,
        },
      });
      final c = await _open(s);
      expect(c.armory.items, isNotEmpty);
      expect(c.pendingFeatureIntro, isNull);
    });

    test('안내가 가리키는 Key는 모두 화면 어딘가에 있다 (Key를 바꾸면 안내도 같이)', () {
      final tour = [
        File('lib/features/tutorial/feature_tour.dart').readAsStringSync(),
        File('lib/features/chat/chat_tour.dart').readAsStringSync(),
      ].join('\n');
      final keys = {
        for (final m in RegExp(r"rectOfKey\(const Key\('([A-Za-z0-9_]+)'\)").allMatches(tour)) m.group(1)!,
        for (final m in RegExp(r"_homeTarget\([^,]+,\s*const Key\('([A-Za-z0-9_]+)'\)").allMatches(tour)) m.group(1)!,
      };
      expect(keys, isNotEmpty);
      final others = [
        for (final f in Directory('lib').listSync(recursive: true))
          if (f is File &&
              f.path.endsWith('.dart') &&
              !f.path.endsWith('feature_tour.dart') &&
              !f.path.endsWith('chat_tour.dart'))
            f.readAsStringSync(),
      ].join('\n');
      final missing = [
        for (final k in keys)
          // 이름 그대로, 또는 「앞부분_${…}」처럼 만들어 다는 Key
          if (!others.contains("'$k'") &&
              !others.contains("Key('${k.split('_').first}_\${") &&
              !others.contains("Key('${k.replaceAll(RegExp(r'[0-9]+$'), '')}\$")) k,
      ];
      expect(missing, isEmpty, reason: '안내가 찾는데 화면에 없는 Key: $missing');
    });
  });

  group('#390 잿빛 틈 열림', () {
    test('첫 틈(분노)은 긴 설명 · 두 번째부터는 소식 띠 한 줄', () async {
      final first = await _open(_store(12, {'pets': _petsJson()}));
      expect(first.takeRiftNews(), isNull);
      expect(first.masteryTalk, Act2Rules.riftFirstLine);
      final second = await _open(_store(14, {
        'pets': _petsJson(),
        'act2': {'beaten': 1, 'announced': 1},
      }));
      expect(second.masteryTalk, isNot(Act2Rules.riftFirstLine));
      final n = second.takeRiftNews();
      expect(n, AshAvatar.sorrow);
      expect(Act2Ops.riftNewsLine(n!), '새 잿빛 틈 · ${Act2Rules.info(AshAvatar.sorrow).name}의 기운이 느껴져요');
      expect(second.takeRiftNews(), isNull); // 한 번만
    });
  });

  // 아래 묶음 82 시험은 항목을 고칠 때마다 더함
  test('자리', () => expect(const SizedBox(), isNotNull));
}
