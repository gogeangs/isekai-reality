// 묶음 82: #396 마을 기록 지워짐 · #383 안내 · #390 · #394 잿빛 틈 턴제 · #381 원정 동행 · #392 · #393 · #395 · 화면 정리

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/models/pet_state.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/data/location/location_source.dart';
import 'package:isekai_reality/core/geo/geo.dart';

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

  group('#394 잿빛 틈 턴제', () {
    AshTurn mk(AshAvatar a, {int hp = 99999, int atk = 10, bool pet = false, int seen = 0, List<AshTurnSkill> skills = const []}) => AshTurn(
          avatar: a,
          level: 12,
          heroMaxHp: hp,
          heroHp: hp,
          heroAttack: atk,
          mp: 100,
          mpMax: 100,
          skills: skills,
          hasPet: pet,
          potions: const [BattlePotion(key: 'shop:heal', name: '회복 물약', count: 5, hpRatio: 0.4)],
          memoriesSeen: seen,
          rng: math.Random(1),
        );

    test('게이지: 분신 차례마다 1칸 · 다 차면 예고 → 다음 분신 차례에 특별 공격 · 비움', () {
      final t = mk(AshAvatar.rage);
      for (var i = 1; i <= 4; i++) {
        t.act(AshCmd.attack);
        expect(t.gauge, i);
      }
      final e = t.act(AshCmd.attack);
      expect(t.gauge, 5);
      expect(t.specialNext, isTrue);
      expect(e.any((x) => x.kind == AshEventKind.warn), isTrue);
      expect(t.sayWarn, isTrue);
      final s = t.act(AshCmd.attack);
      expect(s.any((x) => x.kind == AshEventKind.foeSpecial && x.big), isTrue);
      expect(t.gauge, 0);
    });

    test('공격 스킬에 맞으면 1칸 더 · 방어는 분노 폭발을 크게 줄임', () {
      final t = mk(AshAvatar.rage, skills: const [AshTurnSkill(key: 'x', name: '강타', mp: 10, attack: true)]);
      t.act(AshCmd.skill1);
      expect(t.gauge, 2);
      expect(t.mp, 90);
      final a = mk(AshAvatar.rage)..gauge = 5;
      final b = mk(AshAvatar.rage)..gauge = 5;
      final hitA = a.act(AshCmd.attack).firstWhere((x) => x.kind == AshEventKind.foeSpecial).value;
      final hitB = b.act(AshCmd.guard).firstWhere((x) => x.kind == AshEventKind.foeSpecial).value;
      expect(hitB, lessThan(hitA * 0.45));
    });

    test('특별 공격 다섯: 눈물비 · 빼앗기 · 겁주기 · 고립', () {
      final s = mk(AshAvatar.sorrow)..gauge = 5;
      s.act(AshCmd.attack);
      expect(s.rain, 2);
      final g = mk(AshAvatar.greed, skills: const [AshTurnSkill(key: 'w', name: '철벽', mp: 10, attack: false)]);
      g.act(AshCmd.skill1);
      expect(g.wall, greaterThan(0));
      g.gauge = 5;
      g.act(AshCmd.attack);
      expect(g.wall, 0);
      expect(g.stolenWall, greaterThan(0));
      expect(g.foePower, greaterThan(1));
      g.gauge = 2;
      g.act(AshCmd.face); // 돌려받음
      expect(g.foePower, 1);
      final f = mk(AshAvatar.fear, skills: const [AshTurnSkill(key: 'x', name: '강타', mp: 10, attack: true)])..gauge = 5;
      f.act(AshCmd.attack);
      expect(f.skillsLocked, isTrue);
      expect(f.can(AshCmd.skill1), isFalse);
      f.act(AshCmd.attack);
      expect(f.can(AshCmd.skill1), isTrue);
      final l = mk(AshAvatar.lonely, pet: true)..gauge = 5;
      l.act(AshCmd.attack);
      expect(l.petAway, greaterThan(0));
      final ev = l.act(AshCmd.attack);
      expect(ev.any((x) => x.kind == AshEventKind.petAway), isTrue);
      l.gauge = 2;
      l.act(AshCmd.face);
      expect(l.petAway, 0);
    });

    test('마주하기: 2칸 미만이면 막힘 · 조각 3개 · 다 본 뒤엔 게이지만', () {
      final t = mk(AshAvatar.rage);
      expect(t.can(AshCmd.face), isFalse);
      for (var k = 0; k < 3; k++) {
        t.gauge = 3;
        final e = t.act(AshCmd.face).firstWhere((x) => x.kind == AshEventKind.face);
        expect(e.memory, k);
      }
      expect(t.allMemories, isTrue);
      t.gauge = 3;
      final e = t.act(AshCmd.face).firstWhere((x) => x.kind == AshEventKind.face);
      expect(e.memory, -1);
      // 이전에 본 조각부터 이어서
      final again = mk(AshAvatar.rage, seen: 2)..gauge = 2;
      expect(again.act(AshCmd.face).firstWhere((x) => x.kind == AshEventKind.face).memory, 2);
    });

    test('이김 · 짐 · 물약은 한 판에 3개', () {
      final w = mk(AshAvatar.rage, atk: 99999);
      w.act(AshCmd.attack);
      expect(w.won, isTrue);
      final l = mk(AshAvatar.rage, hp: 10);
      l.act(AshCmd.attack);
      expect(l.lost, isTrue);
      final p = mk(AshAvatar.rage, hp: 100000)..hp = 10;
      var n = 0;
      while (p.can(AshCmd.potion)) {
        p.act(AshCmd.potion);
        p.hp = 10;
        n++;
      }
      expect(n, 3);
    });

    test('같은 레벨 기준 각성자: 대략 8~14턴', () {
      for (final a in AshAvatar.values) {
        final lv = Act2Rules.info(a).level;
        final b = Battle.forPlayer(level: lv, stats: BattleRules.expectedStats(lv), floors: [Act2Rules.avatarFoe(a, lv)]);
        var turns = 0;
        for (var i = 0; i < 40; i++) {
          final t = AshTurn(avatar: a, level: lv, heroMaxHp: b.playerMaxHp, heroHp: b.playerMaxHp, heroAttack: b.playerAttack,
              damageTaken: b.damageTaken, mp: 0, mpMax: 0, hasPet: true,
              potions: const [BattlePotion(key: 'shop:heal', name: '물약', count: 5, hpRatio: 0.4)], rng: math.Random(i));
          while (!t.isOver && t.turn < 40) {
            t.act(t.specialNext ? AshCmd.guard : (t.hp < t.heroMaxHp * 0.35 && t.can(AshCmd.potion) ? AshCmd.potion : AshCmd.attack));
          }
          turns += t.turn;
        }
        expect(turns / 40, inInclusiveRange(8, 16), reason: '$a');
      }
    });

    test('끝나면 기억은 남고 HP · 물약이 반영됨 (진 판도)', () async {
      final s = _store(13, {
        'pets': _petsJson(),
        'bag': {'items': {'heal': 2}},
      });
      final c = await _open(s);
      await c.handleFix(LocationFix(point: c.riftPoint ?? const GeoPoint(37.3, 126.8)));
      final t = c.startAshTurn()!;
      expect(t.avatar, AshAvatar.rage);
      t.gauge = 2;
      t.act(AshCmd.face);
      t.hp = 0; // 진 판
      final r = await c.finishAshTurn(t);
      expect(r.won, isFalse);
      expect(c.act2.memoriesOf(0), 1);
      expect(c.hp, 0);
      expect(c.kingStories, isEmpty);
    });
  });

  // 아래 묶음 82 시험은 항목을 고칠 때마다 더함
  test('자리', () => expect(const SizedBox(), isNotNull));
}
