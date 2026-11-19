import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/act2_state.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/models/pet_state.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/village/shelter_screen.dart';
import 'package:isekai_reality/features/village/village_screen.dart';
import 'package:isekai_reality/features/town/inn_screen.dart';
import 'package:isekai_reality/theme/ornaments.dart' show KText;

void main() {
  final t0 = DateTime(2026, 11, 15, 10);

  /// Lv.[level] 계정. [farewell] 이면 첫 펫과 함께 (2막)
  InMemoryRecordStore account(int level,
          {bool farewell = false,
          Map<String, DateTime> tired = const {},
          List<PetEgg> eggs = const [],
          Map<String, dynamic>? act2,
          Map<String, dynamic>? village,
          bool newGates = false}) =>
      InMemoryRecordStore(
        profile: const PlayerProfile(
            name: '하루',
            spiritName: '불씨',
            spiritKind: SpiritKind.water,
            lastSeenLevel: 99),
        history: [
          DailyRecord(
            date: DateTime(2026, 11, 14),
            gains: {'exp': LevelRules.totalExpToReach(level)},
          ),
        ],
        json: {
          'tutorial': {'step': TutorialStep.done.index},
          // 새로 시작한 계정처럼 레벨로 기능이 열림 (안내는 이미 본 것으로)
          if (newGates)
            'gates': {
              'legacy': false,
              'v28': true,
              'seen': [for (final f in Feature.values) f.name],
            },
          if (farewell)
            'pets': PetState(
              pets: [
                Pet(
                    uid: 'p1',
                    species: PetSpecies.owl,
                    name: '부엉',
                    bornAt: DateTime(2026, 11, 1)),
              ],
              companion: 'p1',
              firstPet: 'p1',
              firstSpiritName: '불씨',
              farewellAt: DateTime(2026, 11, 2),
              tired: tired,
              eggs: eggs,
            ).toJson(),
          if (act2 != null) 'act2': act2,
          if (village != null) 'village': village,
        },
      );

  Future<AppController> start(InMemoryRecordStore store,
      {DateTime Function()? clock}) async {
    final c = AppController(
      store: store,
      health: FakeHealthSource(stepsByDay: const {}),
      clock: clock ?? () => t0,
    )..mailSources = const [];
    await c.init();
    return c;
  }

  group('묶음 34 확인 답', () {
    test('분신·본체는 처음 쓰러뜨릴 때 경험치 (분신 2배 · 본체 3배)', () {
      expect(Act2Rules.avatarExp, RuleConstants.dungeonClearExp * 2);
      expect(Act2Rules.kingExp, RuleConstants.dungeonClearExp * 3);
    });

    test('분신을 처음 쓰러뜨리면 경험치가 오른다', () async {
      final c = await start(account(12));
      final before = LevelRules.totalExpToReach(c.player.level.level) +
          c.player.level.expIntoLevel;
      final b = c.startAshBattle()!;
      b.floor = 0;
      b.foeHp = 1;
      b.phase = BattlePhase.cleared;
      final r = await c.finishAshBattle(b);
      expect(r.exp, Act2Rules.avatarExp);
      final after = LevelRules.totalExpToReach(c.player.level.level) +
          c.player.level.expIntoLevel;
      expect(after - before, Act2Rules.avatarExp);
    });
  });

  group('마을 사람', () {
    test('처음엔 첫 줄, 그 뒤엔 그 막의 두 줄을 번갈아 (1막 대사가 없으면 2막)', () {
      expect(VillageRules.lineFor(Npc.marta, act: 1, met: false, visits: 0),
          VillageRules.npc(Npc.marta).first);
      final a = VillageRules.lineFor(Npc.marta, act: 1, met: true, visits: 0);
      final b = VillageRules.lineFor(Npc.marta, act: 1, met: true, visits: 1);
      expect(a, isNot(b));
      expect(VillageRules.lineFor(Npc.marta, act: 1, met: true, visits: 2), a);
      expect(VillageRules.linesFor(Npc.sera, 1), VillageRules.linesFor(Npc.sera, 2));
      expect(VillageRules.linesFor(Npc.lumi, 3).first, contains('탑이 켜지니까'));
      for (final n in VillageRules.npcs) {
        expect(n.lines[3], hasLength(2), reason: n.name);
      }
    });

    test('만난 것·번갈아 셈은 저장된다 (예전 기록도 시설마다 한 번씩 첫 줄)', () async {
      final store = account(5);
      final c = await start(store);
      expect(c.takeNpcLine(Npc.dorgun), VillageRules.npc(Npc.dorgun).first);
      final x = c.takeNpcLine(Npc.dorgun);
      expect(x, isNot(VillageRules.npc(Npc.dorgun).first));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final again = await start(store);
      final y = again.takeNpcLine(Npc.dorgun);
      expect(y, isNot(x));
      expect(again.takeNpcLine(Npc.mina), VillageRules.npc(Npc.mina).first);
    });

    test('묶음 36 이름 바꿈: 토비·브론·엘라를 만난 기록은 미나·도르군·엘리엘로 이어 감', () async {
      final c = await start(account(8, village: {
        'seen': ['intro', 'met:toby', 'met:bron', 'met:ella'],
        'visits': {'bron': 1},
      }));
      expect(VillageRules.npc(Npc.mina).name, '미나');
      expect(VillageRules.npc(Npc.dorgun).name, '도르군');
      expect(VillageRules.npc(Npc.eliel).name, '엘리엘');
      expect(c.takeNpcLine(Npc.mina), isNot(VillageRules.npc(Npc.mina).first));
      expect(c.takeNpcLine(Npc.eliel), isNot(VillageRules.npc(Npc.eliel).first));
      // 도르군은 한 번 번갈았으므로 둘째 줄
      expect(c.takeNpcLine(Npc.dorgun), VillageRules.linesFor(Npc.dorgun, 1)[1]);
    });

    test('막: 이별 전 1 · 이별 뒤 2 · 결말 뒤 3', () async {
      expect((await start(account(5))).villageAct, 1);
      expect((await start(account(12, farewell: true))).villageAct, 2);
      expect(
          (await start(account(22,
                  farewell: true,
                  act2: const Act2State(beaten: 5, kingPhase: 5, kingDone: true)
                      .toJson())))
              .villageAct,
          3);
    });

    test('소개 3줄: 이별 뒤면 3번째 줄이 떠난 정령 이야기', () {
      expect(VillageRules.intro(), hasLength(3));
      expect(VillageRules.intro(departed: '불씨')[2],
          '저 탑에 다시 불을 켜는 게 불씨의 오래된 소원이었대.');
      expect(VillageRules.afterFarewell('불씨'), '불씨가 열어 둔 마을 길은 이제 네 안에 있대.');
      expect(VillageRules.afterFarewell('이슬빛'), startsWith('이슬빛이 열어'));
    });
  });

  group('펫 쉼터 · 지침', () {
    test('지침은 저장되고, 쉼터에 두면 그때부터 15분', () async {
      final store = account(12,
          farewell: true, tired: {'p1': t0.add(const Duration(minutes: 50))});
      final c = await start(store);
      expect(c.shelterOpen, isTrue);
      expect(c.petTiredLeft('p1'), const Duration(minutes: 50));
      expect(c.tiredPets.single.uid, 'p1');
      expect(await c.restInShelter('p1'), isTrue);
      expect(c.petTiredLeft('p1'), PetRules.shelterRest);
      expect(c.petInShelter('p1'), isTrue);
      final later = await start(store,
          clock: () => t0.add(const Duration(minutes: 16)));
      expect(later.petTiredLeft('p1'), isNull);
      expect(later.tiredPets, isEmpty);
    });

    test('예전에 진 펫은 지침 없이 시작 · 쉼터는 Lv.11 첫 펫과 함께', () async {
      final c = await start(account(12, farewell: true));
      expect(c.tiredPets, isEmpty);
      expect(c.shelterIntroPending, isTrue);
      await c.markShelterIntro();
      expect(c.shelterIntroPending, isFalse);
      expect((await start(account(8))).shelterOpen, isFalse);
    });
  });

  group('화면', () {
    void phone(WidgetTester tester,
        {Size size = const Size(1170, 2532), double dpr = 3}) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = dpr;
      addTearDown(tester.view.reset);
    }

    Future<void> village(WidgetTester tester, AppController c) async {
      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: VillageScreen(controller: c))));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('처음 들어오면 소개 3줄 + 탑 비춤, 건너뛰면 다시 안 나옴', (tester) async {
      phone(tester);
      late AppController c;
      await tester.runAsync(() async => c = await start(account(5)));
      await village(tester, c);
      expect(find.byKey(const Key('villageIntro')), findsOneWidget);
      expect(find.byKey(const Key('towerGlow')), findsOneWidget);
      await tester.tap(find.byKey(const Key('villageIntroNext')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('villageIntroSkip')));
      await tester.pump();
      expect(find.byKey(const Key('villageIntro')), findsNothing);
      expect(c.villageIntroPending, isFalse);
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('건물은 그림에, 열린 시설만 이름표 · 안 열린 건물은 어둡게', (tester) async {
      phone(tester);
      late AppController c;
      await tester.runAsync(() async =>
          c = await start(
              account(5, newGates: true, village: {'seen': ['intro']})));
      await village(tester, c);
      // 묶음 51: 주점은 결말 뒤 만남 장면 다음에만 (그 전엔 빈 공터)
      for (final f in Facility.values.where((f) => f != Facility.tavern && f != Facility.guildhall)) {
        expect(find.byKey(Key('building_${f.name}')), findsOneWidget, reason: f.name);
      }
      expect(find.byKey(const Key('facility_inn')), findsOneWidget);
      expect(find.byKey(const Key('facility_smithy')), findsOneWidget);
      expect(find.byKey(const Key('facility_alchemy')), findsNothing);
      expect(find.byKey(const Key('facility_shelter')), findsNothing);
      expect(find.byKey(const Key('facility_market')), findsNothing);
      expect(find.byKey(const Key('villageAllButton')), findsNothing);
      expect(find.byKey(const Key('villageFog')), findsNothing);
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('묶음 38: 작은 iPhone·큰 iPhone·Android — 처음 화면에 건물 8채가 다 보이고 이름표가 겹치지 않음',
        (tester) async {
      for (final (size, dpr) in const [
        (Size(750, 1334), 2.0),
        (Size(1290, 2796), 3.0),
        (Size(1080, 2400), 2.625),
      ]) {
        phone(tester, size: size, dpr: dpr);
        late AppController c;
        await tester.runAsync(() async => c = await start(account(16,
            farewell: true, village: {'seen': ['intro', 'farewell']})));
        await village(tester, c);
        final screen = tester.getRect(find.byKey(const Key('villageArt')));
        // 묶음 43: 훈련장은 오른쪽 공터 (처음 화면 밖, 끌어서 봄)
        for (final f in Facility.values
            .where((f) =>
                f != Facility.training && f != Facility.garden && f != Facility.tavern && f != Facility.guildhall)) {
          final r = tester.getRect(find.byKey(Key('building_${f.name}')));
          expect(r.left, greaterThanOrEqualTo(screen.left - 1), reason: '$size ${f.name}');
          expect(r.right, lessThanOrEqualTo(screen.right + 1), reason: '$size ${f.name}');
        }
        final tags = [
          for (final f in Facility.values)
            for (final k in ['tag_${f.name}', 'locked_${f.name}'])
              if (find.byKey(Key(k)).evaluate().isNotEmpty)
                tester.getRect(find.byKey(Key(k))),
        ];
        expect(tags.length, Facility.values.length - 2); // 주점은 결말 뒤 · 길드 회관은 4막
        for (var i = 0; i < tags.length; i++) {
          for (var j = i + 1; j < tags.length; j++) {
            expect(tags[i].overlaps(tags[j]), isFalse, reason: '$size $i $j');
          }
        }
        // 2막: 안개 (화면에 고정)
        expect(find.byKey(const Key('villageFog')), findsNothing, reason: '묶음 69 #283: 2막 안개 없음');
        // 아래 이름표 줄은 없음, 처음부터 끌기
        expect(find.byKey(const Key('villageTags')), findsNothing);
        expect(find.byKey(const Key('villageScroll')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 9));
      }
    });

    testWidgets('묶음 38·44: 안 열린 건물은 짓는 모습 + 완공 때, 누르면 안내 · 거래소 준비 중',
        (tester) async {
      phone(tester);
      late AppController c;
      await tester.runAsync(() async => c = await start(
          account(5, newGates: true, village: {'seen': ['intro']})));
      await village(tester, c);
      // 묶음 69 #290: 완성되지 않은 건물은 이름표 없이 공사 그림만, 누르면 위쪽 띠
      for (final n in ['alchemy', 'guild', 'shelter', 'market']) {
        expect(find.byKey(Key('tagSub_$n')), findsNothing, reason: n);
      }
      expect(find.byKey(const Key('locked_alchemy')), findsOneWidget);
      await tester.tap(find.byKey(const Key('locked_alchemy')));
      await tester.pump();
      expect(find.text('연금술 공방 · Lv.7에 완공돼요'), findsOneWidget);
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('결말 뒤: 밝은 바탕 + 탑 불꽃 + 첫 펫 한마디(한 번)', (tester) async {
      phone(tester);
      late AppController c;
      await tester.runAsync(() async => c = await start(account(22,
          farewell: true,
          village: {'seen': ['intro', 'farewell']},
          act2: const Act2State(beaten: 5, kingPhase: 5, kingDone: true, endingSeen: true)
              .toJson())));
      expect(c.villageMoment, VillageRules.towerLit);
      await village(tester, c);
      expect(find.byKey(const Key('towerLight')), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      expect(c.villageMoment, isNull);
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('여관: 마르타 얼굴 + 처음 만날 때 한 줄', (tester) async {
      phone(tester);
      late AppController c;
      await tester.runAsync(() async => c = await start(account(5)));
      await tester.pumpWidget(MaterialApp(home: InnScreen(controller: c)));
      await tester.pump();
      expect(find.byKey(const Key('npc_marta')), findsOneWidget);
      // 묶음 71: 처음 만남은 닫힌 채로(점) — 얼굴을 누르면 첫 줄
      expect(find.byKey(const Key('npcLine_marta')), findsNothing);
      await tester.tap(find.byKey(const Key('npcFace_marta')));
      await tester.pump();
      expect(
          tester.widget<KText>(find.byKey(const Key('npcLine_marta'))).data,
          VillageRules.npc(Npc.marta).first);
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('펫 쉼터: 둥지의 알 · 지친 펫 쉬게 하기', (tester) async {
      phone(tester);
      late AppController c;
      await tester.runAsync(() async => c = await start(account(12,
          farewell: true,
          tired: {'p1': t0.add(const Duration(minutes: 40))},
          eggs: [PetEgg(id: 'e1', incubatedAt: t0)])));
      await tester.pumpWidget(MaterialApp(home: ShelterScreen(controller: c)));
      await tester.pump();
      expect(find.byKey(const Key('npc_lumi')), findsOneWidget);
      expect(find.byKey(const Key('nest_e1')), findsOneWidget);
      expect(find.byKey(const Key('tired_p1')), findsOneWidget);
      await tester.tap(find.byKey(const Key('shelterRest_p1')));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
      expect(c.petTiredLeft('p1'), PetRules.shelterRest);
      expect(find.byKey(const Key('shelterRest_p1')), findsNothing);
      await tester.pump(const Duration(seconds: 9));
    });
  });
}
