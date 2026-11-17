// 묶음 51: 결말 뒤 다른 각성자와 만남 · 주점 · 리안 (#242) + 거래소 완공 · 바르칸 (#229, 서버 전)

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/geo/geo.dart';
import 'package:isekai_reality/core/models/act2_state.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/models/pet_state.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/village/tavern_screen.dart';
import 'package:isekai_reality/features/village/village_screen.dart';
import 'package:isekai_reality/theme/top_notice.dart';

final t0 = DateTime(2026, 11, 16, 10);
const home = GeoPoint(37.3219, 126.8309);

/// 결말을 본 계정 (마을 소개 · 탑 불꽃은 본 것으로)
InMemoryRecordStore account({
  bool king = true,
  List<String> seen = const [],
  Map<String, int> mats = const {},
  Map<String, dynamic>? npc,
  List<DailyRecord> more = const [],
}) =>
    InMemoryRecordStore(
      profile: const PlayerProfile(
          name: '하루',
          spiritName: '불씨',
          spiritKind: SpiritKind.water,
          lastSeenLevel: 99),
      history: [
        DailyRecord(date: DateTime(2026, 11, 1), gains: {
          Wallet.exp: LevelRules.totalExpToReach(21),
          Wallet.gold: 2000,
          ...mats,
        }),
        ...more,
      ],
      json: {
        'tutorial': {'step': TutorialStep.done.index},
        'gates': {
          'legacy': false,
          'v28': true,
          'seen': [for (final f in Feature.values) f.name],
        },
        'village': {
          'seen': [
            'intro',
            'farewell',
            'lit',
            'shelterCard',
            'trainingCard',
            'gardenCard',
            for (final n in Npc.values) 'met:${n.name}',
            ...seen,
          ],
        },
        'act2': Act2State(
                beaten: king ? 5 : 3,
                kingPhase: king ? 5 : 0,
                kingDone: king,
                endingSeen: king,
                announced: 6)
            .toJson(),
        'pets': PetState(
          pets: [
            Pet(uid: 'p1', species: PetSpecies.owl, name: '부엉', bornAt: DateTime(2026, 10, 1)),
          ],
          companion: 'p1',
          firstPet: 'p1',
          firstSpiritName: '불씨',
          farewellAt: DateTime(2026, 10, 2),
        ).toJson(),
        if (npc != null) 'npc': npc,
      },
    );

Future<AppController> start(InMemoryRecordStore s,
    {Map<String, int> steps = const {}, DateTime Function()? clock}) async {
  final c = AppController(
    store: s,
    health: FakeHealthSource(stepsByDay: {...steps}),
    clock: clock ?? () => t0,
  )..mailSources = const [];
  await c.init();
  return c;
}

Map<String, dynamic> npcWith(String who, int done, {int points = 60, Map<String, dynamic>? active}) => {
      'v': 1,
      'points': {who: points},
      'shown': {who: NpcRules.stageOf(points).index},
      'done': {who: done},
      if (active != null) 'active': {who: active},
    };

void main() {
  group('규칙', () {
    test('만남 장면 6줄 · 리안 · 바르칸 · 주점 · 거래소 이름 (기획 문구 그대로)', () {
      expect(TavernRules.meet, hasLength(6));
      expect(TavernRules.meet.first, (false, '…저기 불빛들, 우리 마을 사람들 게 아니야.'));
      expect(TavernRules.meet.last, (false, '…우리, 혼자가 아니었구나.'));
      expect([for (final l in TavernRules.meet) l.$1], [false, true, true, true, true, false]);
      expect(TavernRules.openedLine, '주점이 열렸어! 리안이 같이 걸을 사람을 찾아 준대.');
      expect(VillageRules.npc(Npc.lian).name, '리안');
      expect(VillageRules.npc(Npc.lian).role, '먼저 온 각성자');
      expect(VillageRules.npc(Npc.barkan).first,
          '허허, 다리가 놓였다길래 제일 먼저 건너왔지! 바르칸일세. 저쪽 큰 장터에서 상단을 꾸린다네.');
      expect(VillageRules.linesFor(Npc.barkan, 3), [
        '물건은 돌고 돌아야 값이 나지. 쌓아 두면 먼지만 앉아.',
        '셈은 정확히, 인심은 넉넉히. 그게 우리 상단 규칙일세.',
      ]);
      expect(VillageRules.marketGuide, '장부를 정리하는 중일세. 각성자들이 더 모이면 장을 열겠네.');
      expect(VillageRules.minaBarkan, '바르칸 할아버지가… 할머니 수레를 끌고 왔어요!');
      expect(VillageRules.facilityName('tavern'), '주점');
    });

    test('한 끼 셋 · 소문 10~15개 · 문장에 숫자·확률 없음', () {
      expect([for (final m in TavernRules.meals) m.text], [
        '오늘 걸으면 기력이 조금 더 차요',
        '오늘 걸으면 채집 자리를 조금 더 만나요',
        '오늘 사냥 경험치가 조금 더',
      ]);
      expect(TavernRules.meal(Meal.stew).asset, 'assets/images/food_stew.webp');
      expect(TavernRules.rumors.length, inInclusiveRange(10, 15));
      for (final r in TavernRules.rumors) {
        expect(RegExp(r'[0-9%]').hasMatch(r), isFalse, reason: r);
      }
      expect(TavernRules.rumors, contains(startsWith('요즘 저녁에 하늘 섬이 자주 보인대요')));
      expect(TavernRules.rumors, contains(startsWith('밤에 걸으면 낯선 몬스터를 만난다던데요')));
      expect(TavernRules.rumorOf('2026-11-16'), TavernRules.rumorOf('2026-11-16'));
    });

    test('부탁 4개씩 · 사연 · 단계 대사 · 선물 우편 · 칭호 · 특별 보상', () {
      final l = NpcRules.of(Npc.lian), b = NpcRules.of(Npc.barkan);
      expect(l, hasLength(4));
      expect(b, hasLength(4));
      expect([for (final r in [...l, ...b]) r.level], everyElement(1)); // 레벨 문턱 없음
      expect(l[0].gifts, {'gold': 100});
      expect(l[3].steps.single.kind, RequestStepKind.dayStreak);
      expect(l[3].steps.single.min, 3000);
      expect(l[3].special?.title, TitleId.walkTogether);
      expect(b[0].gifts, {'gold': 120});
      expect(b[3].special?.title, TitleId.merchantFriend);
      expect(l[3].story, '틈이 이어지던 날, 처음으로 다른 사람 발소리를 들었어요. …그래서 이 주점을 열었어요. 아무도 혼자 걷지 않게.');
      expect(b[1].story, '미나 할머니는 내 가장 오랜 거래 상대였지. 셈은 나보다 빨랐어, 허허.');
      expect(NpcRules.letters[Npc.barkan]?[FavorStage.best]?.gifts, {'gold': 200});
      expect(NpcRules.linesAt(Npc.barkan, FavorStage.best).first, '자네라면 내 수레 열쇠를 맡겨도 되겠어.');
      expect(TitleRules.info(TitleId.walkTogether).name, '함께 걷는 자');
      expect(TitleRules.info(TitleId.merchantFriend).name, '상단의 벗');
      expect(EquipmentRules.info(EquipBase.lianKnot).asset, 'equip_lianKnot');
      expect(NpcSmallRules.relicOf(Npc.lian).stages, hasLength(3));
      expect(NpcSmallRules.barkanSeal.asset, 'item_barkanSeal');
    });
  });

  group('흐름', () {
    test('결말 뒤 첫 방문: 만남 장면 → 주점 바로 열림 · 그다음 방문: 거래소 완공 · 미나 한마디 한 번', () async {
      final c = await start(account());
      expect(c.meetPending, isTrue);
      expect(c.tavernOpen, isFalse);
      expect(c.facilityOpen('tavern'), isFalse);
      await c.villageVisit(); // 만남 전 방문엔 거래소 그대로
      expect(c.marketOpen, isFalse);

      await c.markMeetSeen();
      expect(c.meetPending, isFalse);
      expect(c.tavernOpen, isTrue);
      expect(c.npcHomeOpen(Npc.lian), isTrue);
      expect(c.tavernIntroPending, isTrue);
      expect(c.marketOpen, isFalse); // 같은 방문엔 몰리지 않게

      await c.villageVisit();
      expect(c.marketOpen, isTrue);
      expect(c.builtPending, contains('market'));
      expect(c.npcHomeOpen(Npc.barkan), isTrue);
      expect(c.takeNpcLine(Npc.mina), VillageRules.minaBarkan);
      expect(c.takeNpcLine(Npc.mina), isNot(VillageRules.minaBarkan));
    });

    test('결말 전엔 만남도 주점도 없음 · #124 예전 결말 계정은 다음 방문에 만남부터', () async {
      final pre = await start(account(king: false));
      expect(pre.meetPending, isFalse);
      expect(pre.tavernOpen, isFalse);
      final old = await start(account());
      expect(old.meetPending, isTrue);
      expect(old.marketOpen, isFalse);
    });

    test('리안·바르칸 이름은 펫 이름으로 못 씀', () async {
      final c = await start(account());
      expect(c.nameTaken('리안'), isTrue);
      expect(c.nameTaken('바르칸'), isTrue);
      expect(await c.renamePet('p1', '리안'), isFalse);
      expect(c.pets.pets.first.name, '부엉');
      expect(await c.renamePet('p1', '구름'), isTrue);
    });
  });

  group('주점', () {
    test('한 끼: 하루 한 번 금화 · 그날만 · 꿀빵이면 채집 자리가 더 · 소문은 하루 한 번', () async {
      final c = await start(account(seen: ['meet']));
      await c.handleFix(const LocationFix(point: home));
      final before = c.harvestSpots.where((s) => s.id.startsWith('meal-')).length;
      expect(before, 0);
      final gold = c.player.gold;
      expect(await c.eatMeal(Meal.honeyBread), isTrue);
      expect(c.player.gold, gold - TavernRules.meal(Meal.honeyBread).price);
      expect(c.ateToday, isTrue);
      expect(c.mealOn(Meal.honeyBread), isTrue);
      expect(c.mealOn(Meal.skewer), isFalse);
      expect(await c.eatMeal(Meal.skewer), isFalse);
      expect(c.harvestSpots.where((s) => s.id.startsWith('meal-')),
          hasLength(TavernRules.breadSpots));
      expect(c.rumorHeardToday, isFalse);
      final r = await c.hearRumor();
      expect(TavernRules.rumors, contains(r));
      expect(c.rumorHeardToday, isTrue);
      expect(c.npcState.tally[NpcTally.meal], 1);
    });

    test('다음 날엔 효과 없음 · 리안과 단짝이면 새벽까지', () async {
      var now = t0;
      final s = account(seen: ['meet']);
      final c = await start(s, clock: () => now);
      expect(await c.eatMeal(Meal.skewer), isTrue);
      now = DateTime(2026, 11, 17, 4);
      expect(c.activeMeal, isNull);
      final best = await start(
          account(seen: ['meet'], npc: npcWith('lian', 0, points: 60)),
          clock: () => now);
      now = t0;
      expect(await best.eatMeal(Meal.stew), isTrue);
      now = DateTime(2026, 11, 17, 4);
      expect(best.activeMeal, Meal.stew);
      now = DateTime(2026, 11, 17, 7);
      expect(best.activeMeal, isNull);
    });

    test('리안 4번: 7일 이어서 매일 3,000보 → 칭호 「함께 걷는 자」 + 배낭 매듭', () async {
      final days = [for (var d = 10; d <= 16; d++) DateTime(2026, 11, d)];
      final c = await start(
        account(
          seen: ['meet'],
          npc: npcWith('lian', 3,
              active: {'i': 3, 'day': '2026-11-10', 'base': {}, 'steps': 0}),
          more: [for (final d in days.take(6)) DailyRecord(date: d, steps: 3500)],
        ),
        steps: {for (final d in days) DailyRecord.dayKeyOf(d): 3500},
      );
      final p = c.requestProgress(Npc.lian);
      expect(p.single.have, 7);
      expect(c.requestReady(Npc.lian), isTrue);
      final done = (await c.completeRequest(Npc.lian))!;
      expect(done.special?.kind, NpcSpecialKind.knot);
      expect(c.player.titles, contains(TitleId.walkTogether));
      expect(c.armory.items.any((i) => i.base == EquipBase.lianKnot), isTrue);
    });

    test('리안 4번: 하루라도 빠지면 다시', () async {
      final c = await start(
        account(
          seen: ['meet'],
          npc: npcWith('lian', 3,
              active: {'i': 3, 'day': '2026-11-10', 'base': {}, 'steps': 0}),
          more: [
            for (var d = 10; d <= 15; d++)
              DailyRecord(date: DateTime(2026, 11, d), steps: d == 13 ? 1200 : 3500),
          ],
        ),
        steps: {
          for (var d = 10; d <= 16; d++)
            '2026-11-${d.toString().padLeft(2, '0')}': d == 13 ? 1200 : 3500,
        },
      );
      expect(c.requestProgress(Npc.lian).single.have, 3);
      expect(c.requestReady(Npc.lian), isFalse);
    });
  });

  group('거래소 · 바르칸', () {
    test('2번: 서로 다른 재료 5종 (가져감) → 마석 8', () async {
      final c = await start(account(
        seen: ['meet', 'market', 'built:market'],
        mats: {'herb': 3, 'ratHide': 1, 'slimeJelly': 2, 'ironShard': 4, 'batWing': 1},
        npc: npcWith('barkan', 1,
            active: {'i': 1, 'day': '2026-11-16', 'base': {}, 'steps': 0}),
      ));
      expect(c.requestProgress(Npc.barkan).single.have, 5);
      final stones = c.player.manaStones;
      final done = (await c.completeRequest(Npc.barkan))!;
      expect(done.got.join(' '), contains('마석'));
      expect(c.player.manaStones, stones + 8);
      expect(c.player.materialCount(MaterialId.herb), 2);
    });

    test('4번 특별 보상: 칭호 「상단의 벗」 + 가방 「소중한 물건」 상단 인장', () async {
      final c = await start(
        account(
          seen: ['meet', 'market', 'built:market'],
          npc: {
            ...npcWith('barkan', 3,
                active: {'i': 3, 'day': '2026-11-16', 'base': {'newPlace': 0}, 'steps': 0}),
            'tally': {'newPlace': 5},
          },
        ),
        steps: {'2026-11-16': 10500},
      );
      expect(c.requestReady(Npc.barkan), isTrue);
      final done = (await c.completeRequest(Npc.barkan))!;
      expect(done.special?.kind, NpcSpecialKind.seal);
      expect(c.hasBarkanSeal, isTrue);
      expect(c.ownedRelics, contains(NpcSmallRules.barkanSeal));
      expect(c.player.titles, contains(TitleId.merchantFriend));
    });
  });

  group('화면', () {
    testWidgets('만남 장면 6줄 → 마지막 줄을 넘기면 본 것으로 (대사창은 리안 그림에서 위)', (tester) async {
      tester.view.physicalSize = const Size(750, 1334);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      late AppController c;
      await tester.runAsync(() async => c = await start(account()));
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Builder(
                  builder: (context) => Center(
                        child: TextButton(
                            key: const Key('go'),
                            onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                    builder: (_) => MeetScreen(controller: c))),
                            child: const Text('go')),
                      )))));
      await tester.pump();
      await tester.tap(find.byKey(const Key('go')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byKey(const Key('meetScreen')), findsOneWidget);
      for (var i = 0; i < TavernRules.meet.length; i++) {
        await tester.tapAt(const Offset(180, 330));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pump(const Duration(milliseconds: 700));
      }
      expect(c.tavernOpen, isTrue);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }
      expect(find.byKey(const Key('meetScreen')), findsNothing);
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('주점: 파티 준비 중 · 소문 듣기 · 한 끼 · 거래소: 장부 정리 중', (tester) async {
      tester.view.physicalSize = const Size(750, 1334);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      late AppController c;
      await tester.runAsync(() async => c = await start(account(seen: ['meet', 'market'])));
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => TopNoticeHost(child: child!),
          home: TavernScreen(controller: c)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('npc_lian')), findsOneWidget);
      expect(find.byKey(const Key('tavernPartySoon')), findsOneWidget);
      await tester.tap(find.byKey(const Key('tavernHear')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('tavernRumorText')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('eat_stew')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('eat_stew')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(c.todayMeal, Meal.stew);
      expect(find.byKey(const Key('eat_stew')), findsNothing);

      await tester.pumpWidget(MaterialApp(home: MarketScreen(controller: c)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('npc_barkan')), findsOneWidget);
      expect(find.byKey(const Key('marketClosed')), findsOneWidget);
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('마을: 만남 뒤 주점 건물 · 다음 방문에 거래소 완공 그림', (tester) async {
      tester.view.physicalSize = const Size(750, 1334);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      late AppController c;
      await tester.runAsync(() async => c = await start(account(seen: ['meet'])));
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: VillageScreen(controller: c))));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('building_tavern')), findsOneWidget);
      expect(c.marketOpen, isTrue);
      expect(find.byKey(const Key('builtReveal_market')), findsOneWidget);
      await tester.pump(const Duration(seconds: 9));
    });
  });
}
