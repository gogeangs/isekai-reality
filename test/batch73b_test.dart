// 묶음 73 다시 보냄: #260 대열 다듬기 · #306 동료 공격 칸 · 묶음 72 더하기(펫·정령 전투 그림, 뒤집기)
// · #308 부화장 · #310 광고 두 배 뒤 닫기 · #313 함께하는 펫 · #314 주기 버튼

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/pet_state.dart';
import 'package:isekai_reality/core/models/vitals.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/storage/record_store.dart' show SpiritKind;
import 'package:isekai_reality/features/battle/battle_view.dart';
import 'package:isekai_reality/features/bulssi/bulssi_mood.dart';
import 'package:isekai_reality/features/map/expedition_result.dart';
import 'package:isekai_reality/features/pets/companion_pet_panel.dart';
import 'package:isekai_reality/features/pets/pet_art.dart';
import 'package:isekai_reality/features/village/hatchery.dart';

import 'batch52_test.dart' as b52;
import 'batch56_test.dart' as b56;
import 'support/village_seed.dart';

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

Map<String, dynamic> _pets({List<PetEgg> eggs = const [], PetSpecies species = PetSpecies.owl, int exp = 0}) => PetState(
      pets: [Pet(uid: 'p1', species: species, name: '부엉', exp: exp, bornAt: DateTime(2026, 11, 1))],
      companion: 'p1',
      firstPet: 'p1',
      firstSpiritName: '불씨',
      farewellAt: DateTime(2026, 11, 2),
      eggs: eggs,
      nextId: 9,
    ).toJson();

void main() {
  setUp(() => b56.now = b52.t0);

  group('#306 이야기 동료 공격 칸', () {
    test('이야기 동료만 칸 그림, 칸 시간 0.10 · 0.08 · 0.16 · 0.10 · 0.12초, 4칸부터 피해', () {
      expect(AllyAttackSheet.sheetOf('assets/images/ally_lian.webp'), 'assets/images/ally_lian_attack.webp');
      expect(AllyAttackSheet.sheetOf('assets/images/ally_job_mage.webp'), isNull);
      expect(AllyAttackSheet.sheetOf(null), isNull);
      for (final n in AllyAttackSheet.story) {
        expect(File('assets/images/ally_${n}_attack.webp').existsSync(), isTrue, reason: n);
      }
      expect(AllyAttackSheet.totalMs, 560);
      expect(AllyAttackSheet.frameAt(-1), (0, null));
      expect(AllyAttackSheet.frameAt(0).$1, 1); // 2칸 힘 모으기부터
      expect(AllyAttackSheet.frameAt(120).$1, 2);
      expect(AllyAttackSheet.frameAt(300).$1, 3);
      expect(AllyAttackSheet.frameAt(400).$1, 4);
      expect(AllyAttackSheet.frameAt(170).$2, isNull);
      final hit = AllyAttackSheet.frameAt(185);
      expect(hit.$1, 3);
      expect(hit.$2, isNotNull);
      expect(AllyAttackSheet.frameAt(500).$1, 5);
      expect(AllyAttackSheet.frameAt(560), (0, null)); // 다시 1칸
    });

    testWidgets('싸움에서 동료가 치면 2→6칸, 4칸에 동료 피해 숫자, 이름 없는 동료는 통 그림', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      final b = Battle(
        playerMaxHp: 100000,
        playerAttack: 30,
        floors: [Foe(monster: MonsterId.ashSlime, maxHp: 1000000, attack: 1)],
        rng: math.Random(3),
        allies: [
          BattleAlly(id: 'lian', name: '리안', maxHp: 1000, attack: 20),
          BattleAlly(id: 'm', name: '마법사', maxHp: 1000, attack: 20),
        ],
      );
      await tester.pumpWidget(_app(Column(children: [
        Expanded(
            child: BattleView(
                battle: b,
                fit: true,
                onFinished: () {},
                tickInterval: const Duration(milliseconds: 900),
                allyArts: const [
                  (art: 'assets/images/ally_lian.webp', face: null, color: 0xFFE8C77A),
                  (art: 'assets/images/ally_job_mage.webp', face: null, color: 0xFF9AA6D8),
                ])),
      ])));
      expect(find.byKey(const Key('allyFrame_0_0')), findsOneWidget); // 대기: 1칸
      expect(find.byKey(const Key('allyFrame_1_0')), findsNothing); // 이름 없는 동료는 통 그림
      final seen = <int>{};
      var dealt = false;
      for (var i = 0; i < 160; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        for (var f = 0; f < 6; f++) {
          if (find.byKey(Key('allyFrame_0_$f')).evaluate().isNotEmpty) seen.add(f);
        }
        if (find.byKey(const Key('allyDealt_0')).evaluate().isNotEmpty) dealt = true;
      }
      expect(seen, containsAll([0, 1, 2, 3, 4, 5]));
      expect(dealt, isTrue);
      expect(find.byKey(const Key('allyDealt_1')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('묶음 72 더하기: 전투 무대의 펫 · 정령 그림', () {
    test('전투용 그림 5종(성체·각성), 아기는 그대로 · 왼쪽을 보는 성체 15종은 뒤집기', () {
      expect(PetRules.battleArt.length, 5);
      expect(PetRules.facesLeft.length, 15);
      for (final s in PetRules.battleArt) {
        final a = PetRules.battleAsset(s, adult: true);
        expect(a, 'assets/images/pet_${s.name}_battle.webp');
        expect(File(a).existsSync(), isTrue, reason: a);
        expect(PetRules.battleAsset(s, adult: false), 'assets/images/pet_${s.name}_baby.webp');
      }
      expect(PetRules.flipInBattle(PetSpecies.dragon, adult: true), isTrue);
      expect(PetRules.flipInBattle(PetSpecies.dragon, adult: false), isFalse);
      expect(PetRules.flipInBattle(PetSpecies.golem, adult: true), isFalse);
      expect(PetRules.flipInBattle(PetSpecies.turtle, adult: true), isFalse);
      for (final k in SpiritKind.values) {
        expect(File('assets/images/spirit_${k.name}_battle.webp').existsSync(), isTrue);
      }
    });

    testWidgets('정령이면 정령 전투 그림, 펫이면 펫 (뒤집기)', (tester) async {
      Widget scoped(Widget child, {PetSpecies? pet}) => _app(BulssiScope(
          mood: BulssiMood.gold, spiritName: '불씨', kind: SpiritKind.water, petSpecies: pet, petAdult: true, child: child));
      await tester.pumpWidget(scoped(const BattleCompanion(size: 44)));
      expect(find.byKey(const Key('spiritBattle_water')), findsOneWidget);
      await tester.pumpWidget(scoped(const BattleCompanion(size: 44), pet: PetSpecies.dragon));
      expect(find.byKey(const Key('petBattle_dragon_flip')), findsOneWidget);
      await tester.pumpWidget(scoped(const BattleCompanion(size: 44), pet: PetSpecies.owl));
      expect(find.byKey(const Key('petBattle_owl')), findsOneWidget);
      final img = tester.widget<Image>(find.descendant(of: find.byType(PetBattleArt), matching: find.byType(Image)).first);
      expect((img.image as AssetImage).assetName, 'assets/images/pet_owl_battle.webp');
    });
  });

  group('작은 것', () {
    testWidgets('#308 부화장: 판은 바탕 비율 1024:640, 빈 둥지도 불투명, 둥지 바닥이 판 높이 약 88%', (tester) async {
      late AppController c;
      await tester.runAsync(() async => c = await startVillage(11, farewell: true, more: {
            'pets': _pets(eggs: [const PetEgg(id: 'e2', source: 'field')]),
          }));
      await tester.pumpWidget(_app(SingleChildScrollView(child: HatcheryPanel(controller: c))));
      await tester.pump(const Duration(milliseconds: 100));
      final panel = tester.getRect(find.byKey(const Key('shelterNests')));
      final art = tester.getRect(find.byType(AspectRatio).first);
      expect(art.width / art.height, closeTo(1024 / 640, 0.01));
      expect(find.ancestor(of: find.byKey(const Key('nestEmptyBack')), matching: find.byType(Opacity)), findsNothing);
      final nest = tester.getRect(find.byKey(const Key('nestEmptyBack')));
      expect((nest.bottom - art.top) / art.height, closeTo(0.88, 0.02));
      expect(panel.height, greaterThanOrEqualTo(art.height));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('#310 광고로 두 배를 받으면 ×2 도장 · 숫자 두 배 → 1.5초 뒤 저절로 닫힘', (tester) async {
      late AppController c;
      await tester.runAsync(() async => c = await startVillage(11));
      c.watchAd = (_) async => true;
      final ex = Expedition(
        spawnId: 's1',
        monster: MonsterId.slime.name,
        lat: 37.5,
        lng: 127,
        distanceM: 300,
        mpCost: 5,
        startedAt: vt0,
        arriveAt: vt0,
        returnAt: vt0,
        cleared: true,
        reward: const {'gold': 30, 'exp': 10},
        baseReward: const {'gold': 30, 'exp': 10},
      );
      await tester.pumpWidget(_app(Builder(
          builder: (ctx) => Center(
              child: TextButton(
                  onPressed: () => showExpeditionResult(ctx, ex, '불씨', controller: c), child: const Text('열기'))))));
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      expect(find.text('+30'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('adDouble')));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.byKey(const Key('rewardX2')), findsWidgets);
      expect(find.text('+60'), findsOneWidget);
      expect(find.byType(ExpeditionResultCard), findsOneWidget);
      // 광고에서 돌아온 뒤 1.5초 (광고 콜백 안에서 잰 실제 시간)
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1400)));
      await tester.pumpAndSettle();
      expect(find.byType(ExpeditionResultCard), findsNothing);
    });

    testWidgets('#313 상태 화면 「함께하는 펫」 · 정령이 떠나기 전엔 없음', (tester) async {
      late AppController c;
      await tester.runAsync(() async => c = await startVillage(11, farewell: true, more: {'pets': _pets()}));
      await tester.pumpWidget(_app(CompanionPetPanel(controller: c)));
      // 묶음 75 #328: 「내 펫 N마리」 3칸 격자 (함께하는 펫이 맨 앞)
      expect(find.byKey(const Key('statusPetGrid')), findsOneWidget);
      expect(find.byKey(const Key('statusPet_p1')), findsOneWidget);
      expect(find.text('내 펫 1마리'), findsOneWidget);
      late AppController before;
      await tester.runAsync(() async => before = await startVillage(9));
      await tester.pumpWidget(_app(CompanionPetPanel(controller: before)));
      expect(find.byKey(const Key('statusPets')), findsNothing);
      expect(File('lib/app.dart').readAsStringSync(), isNot(contains('onOpenPets: controller')));
    });
  });
}
