// 묶음 70: #291 #292 세계 · 친구 · 초대 · 안내 / #293 도감 / #294 나는 펫 / #295 #296 열쇠 · 던전 /
// #297 #298 연금술 작업대 · 레시피 / #300 #301 게시판 탭 / #299 #302 도구
// (서버 판정 — 친구 Lv.8 · 세계 Lv.11 · 초대 보상 · 부정 · 첫 인사 — 은 node 시험 chat70.test.js)

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/vitals.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/cloud/cloud_auth.dart' show LoginProvider;
import 'package:isekai_reality/features/alchemy/alchemy_screen.dart';
import 'package:isekai_reality/features/alchemy/workbench.dart';
import 'package:isekai_reality/features/chat/chat_screens.dart';
import 'package:isekai_reality/features/codex/codex_screen.dart';
import 'package:isekai_reality/features/village/board_screen.dart';

import 'batch52_test.dart' as b52;
import 'batch56_test.dart' as b56;
import 'batch68_test.dart' as b68;
import 'support/fake_arca.dart';
import 'support/village_seed.dart';

Future<(AppController, FakeArca)> chatAt(int level, {bool login = true}) async {
  final (_, a0) = await b68.chatStart(login: false);
  final a = a0..chatLevel = level;
  final (c, _) = await b56.start(arca: a, store: b52.account(level: level), login: login);
  return (c, a);
}

void phone(WidgetTester t) {
  t.view.physicalSize = const Size(750, 1334);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
}

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 10; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() => b56.now = b52.t0);

  group('#291 #292 세계 · 친구', () {
    test('숫자: 친구 Lv.8 · 세계 Lv.11 · 초대 Lv.5 · 5명 · 칭호 3명 · 방 이름', () {
      expect(ChatRules.friendLevel, 8);
      expect(ChatRules.serverLevel, 11);
      expect(ChatRules.inviteLevel, 5);
      expect(ChatRules.inviteMax, 5);
      expect(ChatRules.inviteTitleN, 3);
      expect(ChatRules.worldTitle, '세계 · 모든 각성자');
      expect(ChatRules.errorText('friend_level'), '친구는 Lv.8부터 사귈 수 있어요');
      expect(TitleRules.info(TitleId.wayfarers).name, '길동무를 모은 자');
      expect(TitleRules.info(TitleId.firstHello).name, '첫 인사');
    });

    test('Lv.7 친구 없음 · Lv.9 친구만 · Lv.11 세계까지', () async {
      final (c7, _) = await chatAt(7);
      expect([c7.friendsOpen, c7.worldOpen], [false, false]);
      final (c9, _) = await chatAt(9);
      expect([c9.friendsOpen, c9.worldOpen], [true, false]);
      await c9.refreshChat();
      expect(c9.chatMe!.room('server'), isNull);
      final (c11, _) = await chatAt(11);
      expect([c11.friendsOpen, c11.worldOpen], [true, true]);
      await c11.refreshChat();
      expect(c11.chatMe!.room('server')?.name, '세계');
    });

    test('초대 링크: Lv.2라도 바로 친구 (서버에 코드 · 기기 표시) · 로그인 전이면 기다렸다가', () async {
      final (c, a) = await chatAt(2, login: false);
      c.handleInviteLink(Uri.parse(ChatRules.friendLink('SOLA2345')));
      expect(await c.claimInvite(), isNull, reason: '로그인 전');
      expect(a.chatInviteClaims, isEmpty);
      await c.signInCloud(LoginProvider.google);
      expect(await c.claimInvite(), '솔');
      expect(a.chatInviteClaims.single['code'], 'SOLA2345');
      expect((a.chatInviteClaims.single['me'] as Map)['device'], isNotEmpty);
      expect(c.chatMe!.friends.single.name, '솔');
      expect(await c.claimInvite(), isNull, reason: '한 번만');
    });

    test('숨은 칭호: 초대 보상 3명 「길동무를 모은 자」 · 세계 첫 인사 「첫 인사」', () async {
      final (c, a) = await chatAt(12);
      a.chatRulesSeen = true;
      await c.refreshChat();
      expect(c.player.titles, isNot(contains(TitleId.wayfarers)));
      a.chatInvitePaid = 3;
      await c.refreshChat();
      expect(c.player.titles, contains(TitleId.wayfarers));
      expect(await c.sendChat('server', '안녕하세요!'), isTrue);
      expect(c.player.titles, contains(TitleId.firstHello));
    });

    test('「세계」 안내: 이별 → 쉼터 안내 뒤 한 번 (Lv.11 · 첫 펫)', () async {
      final c = await startVillage(11, farewell: true, village: {'seen': ['intro', 'farewell', 'lit', 'shelterCard']});
      expect(c.chatTourPending, isTrue);
      await c.markChatTour();
      expect(c.chatTourPending, isFalse);
      final low = await startVillage(10, farewell: true, village: {'seen': ['intro', 'farewell', 'lit', 'shelterCard']});
      expect(low.chatTourPending, isFalse);
    });

    testWidgets('상태 화면 버튼: Lv.7 없음 · Lv.9 친구(사람 모양) · Lv.11 말풍선 · 친구 화면 「초대한 친구」', (tester) async {
      for (final (lv, key) in [(7, null), (9, 'friendButton'), (11, 'chatButton')]) {
        late AppController c;
        await tester.runAsync(() async {
          c = (await chatAt(lv)).$1;
          await c.refreshChat();
        });
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: ChatButton(key: UniqueKey(), controller: c)))));
        await tester.pump();
        expect(find.byKey(const Key('friendButton')), key == 'friendButton' ? findsOneWidget : findsNothing, reason: 'Lv.$lv');
        expect(find.byKey(const Key('chatButton')), key == 'chatButton' ? findsOneWidget : findsNothing, reason: 'Lv.$lv');
        await tester.pumpWidget(const SizedBox());
      }
      late AppController c;
      await tester.runAsync(() async {
        final r = await chatAt(9);
        c = r.$1;
        r.$2
          ..chatInvited = 2
          ..chatInvitePaid = 1;
        await c.refreshChat();
      });
      phone(tester);
      await tester.pumpWidget(MaterialApp(home: ChatHubScreen(controller: c, tab: 1)));
      await tester.pump();
      expect(find.text('초대한 친구 2/5 · 보상 받음 1'), findsOneWidget);
      expect(find.byKey(const Key('chatTab_0')), findsNothing, reason: 'Lv.11 전엔 대화방 탭 없음');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 20));
    });
  });

  group('#293 도감', () {
    test('갈래: 필드 · 하이랜드 · 공성전 · 3막 지역 … (분신은 없음)', () {
      expect(Monsters.codexGroup(MonsterId.guardWind), '하이랜드');
      expect(Monsters.codexGroups.first, '필드');
      for (final m in MonsterId.values) {
        final g = Monsters.codexGroup(m);
        if (g != null) expect(Monsters.codexGroups, contains(g), reason: m.name);
      }
    });

    testWidgets('발견한 것만 · 「발견 ○종」 · 갈래 「○종」 · 새로 오른 칸 반짝임 + 점 · 펫은 등급 갈래', (tester) async {
      phone(tester);
      final seen = <String>[];
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: CodexScreen(
        purifiedMonsters: const {MonsterId.guardWind},
        fresh: const {'m:guardWind'},
        onSeen: () => seen.add('x'),
        petsSeen: const {PetSpecies.owl, PetSpecies.griffin},
        petsOpen: true,
      ))));
      await tester.pump();
      expect(find.text('몬스터 도감 · 발견 1종'), findsOneWidget);
      expect(find.text('하이랜드 · 1종'), findsOneWidget);
      expect(find.text('필드 · 1종'), findsNothing, reason: '발견한 것이 없는 갈래는 제목도 없음');
      expect(find.text('???'), findsNothing);
      expect(find.descendant(of: find.byKey(const Key('codexTile_guardWind')), matching: find.byKey(const Key('codexNew'))), findsOneWidget);
      expect(seen, ['x'], reason: '열면 본 것으로');
      await tester.tap(find.text('펫'));
      await tester.pump();
      expect(find.text('펫 도감 · 발견 2종'), findsOneWidget);
      expect(find.text('일반 · 1종'), findsOneWidget);
      expect(find.text('희귀 · 1종'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('#294 나는 펫', () {
    test('나는 펫 7종 · 하늘 길은 살짝 굽고 끝은 몬스터 자리 · 기록에 남음', () {
      expect(PetRules.flyers, {
        PetSpecies.crow,
        PetSpecies.owl,
        PetSpecies.griffin,
        PetSpecies.drake,
        PetSpecies.phoenix,
        PetSpecies.pegasus,
        PetSpecies.dragon,
      });
      expect(PetRules.info(PetSpecies.direwolf).flies, isFalse);
      final ex = Expedition(
        spawnId: 's',
        monster: 'slime',
        lat: 37.51,
        lng: 127.01,
        fromLat: 37.50,
        fromLng: 127.0,
        distanceM: 1400,
        mpCost: 10,
        startedAt: DateTime(2026, 11, 20, 9),
        arriveAt: DateTime(2026, 11, 20, 9, 20),
        returnAt: DateTime(2026, 11, 20, 9, 40),
        sky: true,
      );
      final p = ex.path;
      expect(p.first, (37.50, 127.0));
      expect(p.last.$1, closeTo(37.51, 1e-9));
      expect(p.last.$2, closeTo(127.01, 1e-9));
      final mid = p[p.length ~/ 2];
      expect((mid.$1 - 37.505).abs() + (mid.$2 - 127.005).abs(), greaterThan(0.0005), reason: '가운데가 비켜남');
      expect(Expedition.fromJson(ex.toJson()).sky, isTrue);
    });
  });

  group('#297 #298 연금술', () {
    test('물 색 · 레시피 갈래 · 레시피대로 넣을 재료 (만들어 본 것은 순서대로)', () async {
      expect(brewTint(const []), isNot(brewTint(const [MaterialId.fireJelly])));
      expect(RecipeGroup.of(PotionId.healSmall), RecipeGroup.heal);
      expect(RecipeGroup.of(PotionId.resistFire), RecipeGroup.resist);
      expect(RecipeGroup.of(PotionId.weaponFire), RecipeGroup.weapon);
      expect(RecipeGroup.of(PotionId.strength), RecipeGroup.buff);
      final c = await startVillage(12, more: {
        'alchemy': {'discovered': ['healSmall']},
      });
      expect(c.recipeFill(PotionId.healSmall), isNull, reason: '재료 없음');
    });

    testWidgets('작업대: 「가마솥 1 · 비어 있어요」 · 넘기면 증류기 · 변환 제단 · 레시피 3칸 · 상세에서 「가마솥에 넣기」', (tester) async {
      phone(tester);
      late AppController c;
      await tester.runAsync(() async {
        c = await startVillage(12, more: {
          'alchemy': {'discovered': ['healSmall']},
        }, gains: {MaterialId.herb.name: 4, MaterialId.slimeJelly.name: 2});
      });
      await tester.pumpWidget(MaterialApp(home: AlchemyScreen(controller: c)));
      await tester.pump();
      expect(find.text('작업대'), findsOneWidget);
      expect(find.text('레시피'), findsOneWidget);
      expect(find.text('가공'), findsNothing);
      expect(find.text('가마솥 1 · 비어 있어요'), findsOneWidget);
      // 선반에서 눌러 넣기
      await tester.tap(find.byKey(const Key('shelf_herb')));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.descendant(of: find.byKey(const Key('brewSlots')), matching: find.byType(Image)), findsWidgets);
      await tester.tap(find.byKey(const Key('benchNext')));
      await settle(tester);
      expect(find.text('증류기 · 가공'), findsOneWidget);
      await tester.tap(find.byKey(const Key('benchNext')));
      await settle(tester);
      expect(find.text('변환 제단 · 변환'), findsOneWidget);
      // 레시피
      await tester.tap(find.byKey(const Key('alchemyTab_1')));
      await tester.pump();
      expect(find.byKey(const Key('recipeGrid')), findsOneWidget);
      expect(find.text('(쪽지)'), findsNothing);
      await tester.tap(find.byKey(const Key('recipeTile_healSmall')));
      await settle(tester);
      expect(find.byKey(const Key('recipeFill')), findsOneWidget);
      await tester.tap(find.byKey(const Key('recipeFill')));
      await settle(tester);
      expect(find.text('가마솥 1 · 비어 있어요'), findsOneWidget, reason: '작업대로 돌아옴');
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('#300 #301 게시판', () {
    testWidgets('탭 「오늘 · 주간」 (조합은 Lv.15부터 · 마을 사람은 부탁이 있을 때만)', (tester) async {
      phone(tester);
      late AppController c;
      await tester.runAsync(() async => c = await startVillage(12));
      await tester.pumpWidget(MaterialApp(home: BoardScreen(controller: c)));
      await tester.pump();
      expect(find.byKey(const Key('boardTab_today')), findsOneWidget);
      expect(find.byKey(const Key('boardTab_errand')), findsNothing);
      expect(find.byKey(const Key('boardTab_npc')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async => c = await startVillage(16));
      await tester.pumpWidget(MaterialApp(home: BoardScreen(key: UniqueKey(), controller: c)));
      await tester.pump();
      expect(find.byKey(const Key('boardTab_errand')), findsOneWidget);
      await tester.tap(find.byKey(const Key('boardTab_errand')));
      await tester.pumpAndSettle();
      expect(find.text('조합 의뢰'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('#295 #296', () {
    test('여분의 열쇠 하루 1개', () {
      expect(TownRules.info(ShopItem.spareKey).limit, ShopLimit.perDay);
      expect(TownRules.info(ShopItem.spareKey).description, '던전 열쇠가 하나 늘어나요.');
    });
  });
}
