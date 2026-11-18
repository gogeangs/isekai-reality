// 묶음 59: 거래 범위(받은 것 · 공방 물약 · 지역 무기 조각) · 4막 「길드 창설」 · 길드 · 리안의 길드 · 운영(되돌림 · 이름 · 공지 · 정지)

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/act4_state.dart';
import 'package:isekai_reality/core/models/armory.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/features/act4/act4_screens.dart';
import 'package:isekai_reality/features/notice/notice_screen.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'batch52_test.dart' as b52;
import 'batch56_test.dart' as b56;
import 'support/fake_arca.dart';

Widget host(Widget home) =>
    MaterialApp(builder: (context, child) => TopNoticeHost(child: child!), home: home);

/// 3막을 끝낸 Lv.[level] 계정 (4막 기록 [state]) · 로그인 · 가짜 서버
Future<(AppController, FakeArca)> act4({
  bool login = true,
  Act4State? state,
  FakeArca? arca,
  int level = 30,
}) async {
  final s = b52.account(level: level);
  final c0 = (await b52.start(s)).$1;
  await c0.openAct3();
  await s.saveJson('act3', c0.act3.copyWith(flags: {...c0.act3.flags, 'act3End'}).toJson());
  if (state != null) await s.saveJson('act4', state.toJson());
  return b56.start(store: s, login: login, arca: arca);
}

/// 그 장의 장면을 모두 본다
Future<void> seeChapter(AppController c, int n) async {
  for (final s in GuildRules.chapter(n).scenes) {
    await c.markAct4Scene(s);
  }
}

const ch2Ready = Act4State(opened: true, chapter: 2, seen: {'c1a', 'c1b'}, chapterSteps: -40000);
const ch2Done = Act4State(
    opened: true, chapter: 3, seen: {'c1a', 'c1b', 'c2a', 'c2b', 'c2c'}, charter: true, chapterSteps: 0);

void main() {
  setUp(() => b56.now = b52.t0);

  group('0 거래 범위', () {
    test('받은 것(첫 무기 · 우편 장비)은 못 팔고, 대장간에서 만든 같은 종류는 팔 수 있다', () {
      const gift = EquipItem(uid: 'a', base: EquipBase.ironSword, grade: EquipGrade.white, gift: true);
      const made = EquipItem(uid: 'b', base: EquipBase.ironSword, grade: EquipGrade.white);
      expect(MarketRules.equipTradable(gift), isFalse);
      expect(MarketRules.equipTradable(made), isTrue);
      expect(EquipItem.fromJson(gift.toJson())!.gift, isTrue, reason: '「받은 것」 표시는 저장된다');
    });

    test('공방 물약은 팔 수 있고 · 지역 무기 조각 넷은 못 판다', () {
      expect(PotionId.values.where(MarketRules.alcTradable), isNotEmpty);
      for (final m in [MaterialId.cartWheel, MaterialId.elderBark, MaterialId.captainCrest, MaterialId.undyingEmber]) {
        expect(MarketRules.matTradable(m), isFalse, reason: m.name);
      }
      expect(MarketRules.matTradable(MaterialId.herb), isTrue);
    });
  });

  group('1 4막 장 흐름', () {
    test('3막 끝 장면 뒤 4막이 열리고(레벨 상관없음) 1장 장면부터', () async {
      final (c, _) = await act4(level: 22);
      expect(c.act4Open, isTrue);
      expect(c.pendingAct4Scene?.id, 'c1a');
      await seeChapter(c, 1);
      expect(c.act4Chapter, 2);
      expect(c.pendingAct4Scene, isNull, reason: '2장은 1장 뒤 3만 보');
      expect(c.act4Goal.contains(RegExp(r'\d')), isFalse, reason: '일지엔 숫자 없음');
    });

    test('3만 보를 걸으면 2장: 리안이 증서를 주고, 빈 터 장면 뒤 회관이 생긴다', () async {
      final (c, _) = await act4(state: ch2Ready);
      expect(c.pendingAct4Scene?.id, 'c2a');
      expect(c.guildHallOpen, isFalse);
      await c.markAct4Scene(c.pendingAct4Scene!);
      expect(c.hasCharter, isTrue);
      await seeChapter(c, 2);
      expect(c.guildHallOpen, isTrue);
      expect(c.act4Chapter, 3);
      expect(c.pendingAct4Scene, isNull, reason: '3장은 길드에 들어 길드 Lv.2 + 길드에서 5만 보');
    });

    test('3장은 길드 Lv.2 · 4장은 Lv.4 (리안의 길드는 걸음만)', () async {
      final a = FakeArca();
      final (c, _) = await act4(state: ch2Done.copyWith(joinSteps: -60000), arca: a);
      expect(await c.createGuild('등불지기'), isTrue);
      expect(c.pendingAct4Scene, isNull, reason: '길드에 막 들어오면 길드 걸음을 새로 셈');
      // 오래 걸었다고 치고 다시 연다 (길드에서 걸은 걸음 기록)
      await c.store.saveJson('act4', c.act4.copyWith(joinSteps: -60000).toJson());
      final (c2, _) = await b56.start(store: c.store as dynamic, arca: a);
      await c2.refreshGuild();
      expect(c2.pendingAct4Scene, isNull, reason: '길드 Lv.1');
      a.guildLevel = 2;
      await c2.refreshGuild();
      expect(c2.pendingAct4Scene?.id, 'c3a');
    });

    test('거인을 쓰러뜨리면 도르군 장면 → 5장 · 끝나면 칭호 「등불의 맹세」 · 인장', () async {
      final (c, _) = await act4(
          state: const Act4State(
              opened: true,
              chapter: 4,
              seen: {'c1a', 'c1b', 'c2a', 'c2b', 'c2c', 'c3a', 'c3b', 'c3c', 'c4a'},
              lian: true,
              joinSteps: -200000,
              // 리안과 동료들이 며칠 동안 깎아 둔 거인 (한 판이면 쓰러짐)
              lianRaid: {
                'giant': {'dmg': 7990}
              }));
      expect(c.guild!.lian, isTrue);
      expect(c.guild!.giant!.tickets, 3, reason: '오늘 걸음으로 도전권');
      final b = c.startRaid(giant: true)!;
      expect(b.raidBoss, 'raidGiant');
      b56.win(b);
      final r = await c.finishRaid(b);
      expect(r.defeatedNow, isTrue);
      expect(c.act4.giant, isTrue);
      expect(await c.claimGuild('giant'), contains('등불 인장 40'));
      expect(c.pendingAct4Scene?.id, 'c4b');
      await c.markAct4Scene(c.pendingAct4Scene!);
      expect(c.act4Chapter, 5);
      await c.store.saveJson('act4', c.act4.copyWith(chapterSteps: -200000).toJson());
      final (c2, _) = await b56.start(store: c.store as dynamic);
      final seals = c2.lanternSeals;
      await seeChapter(c2, 5);
      expect(c2.act4Done, isTrue);
      expect(c2.lanternSeals, seals + GuildRules.oathSeals);
      expect(c2.act4Goal, contains(GuildRules.act5Teaser));
      expect(c2.titlesNewestFirst, contains(TitleId.lanternOath));
    });
  });

  group('2 길드', () {
    test('로그인 안 하면 길드를 못 만들고, 리안의 길드는 된다', () async {
      final (c, _) = await act4(state: ch2Done, login: false);
      expect(await c.createGuild('등불지기'), isFalse);
      expect(c.guildError, 'login_required');
      await c.joinLianGuild();
      expect(c.guild!.inGuild, isTrue);
      expect(c.guild!.name, GuildRules.lianGuildName);
    });

    test('만들기: 금화 + 증서를 쓰고 길드장 · 한마디 · 금칙어', () async {
      final (c, a) = await act4(state: ch2Done);
      final gold = c.player.gold;
      expect(await c.createGuild('등불지기', emblem: 1, color: 2), isTrue);
      expect(c.player.gold, gold - GuildRules.createGold);
      expect(c.hasCharter, isFalse);
      expect(c.guild!.role, 'owner');
      expect(c.guild!.code, 'GLD001');
      expect(await c.postGuildLine('같이 걸어요'), isTrue);
      expect(c.guild!.members.first.line, '같이 걸어요');
      expect(await c.postGuildLine('바보'), isFalse);
      expect(GuildRules.errorText(c.guildError!), contains('쓸 수 없는 말'));
      expect(a.calls, contains('/guild/create'));
    });

    test('길드를 나오면 증서를 리안에게 다시 받을 수 있다', () async {
      final (c, _) = await act4(state: ch2Done);
      await c.createGuild('등불지기');
      expect(c.canAskCharter, isFalse);
      await c.leaveGuild();
      expect(c.canAskCharter, isTrue);
      await c.askCharter();
      expect(c.hasCharter, isTrue);
    });

    test('걸음 목표 · 기부 → 등불 인장 · 상점에서 사기', () async {
      final (c, a) = await act4(state: ch2Done);
      await c.createGuild('등불지기');
      a.guildLevel = 2;
      a.walkDone = [true, true, false];
      await c.refreshGuild();
      expect(await c.claimGuild('walk', tier: 0), ['등불 인장 10']);
      expect(await c.claimGuild('walk', tier: 1), ['등불 인장 20']);
      expect(await c.claimGuild('walk', tier: 2), isNull, reason: '3단계는 아직');
      expect(await c.claimGuild('walk', tier: 0), isNull, reason: '한 번만');
      a.wallet = 100; // 묶음 61: 기부 금화는 거래 지갑에서
      expect(await c.donateGuild(gold: 100), 2);
      expect(c.lanternSeals, 32);
      final gold = c.player.gold;
      final s = GuildRules.shopInfo(GuildShopItem.gold);
      expect(c.guildShopBlock(s), isNull);
      expect(await c.buyGuildShop(s), isNull);
      expect(c.player.gold, gold + 500);
      expect(c.lanternSeals, 32 - s.seals);
      final deco = GuildRules.shopInfo(GuildShopItem.decoFountain);
      expect(c.guildShopBlock(deco), '등불 인장이 모자라요');
    });

    test('길드 레이드: Lv.4부터 · 약점 직업 한 줄 · 쓰러뜨리면 보상(인장 · 보스 재료)', () async {
      final (c, a) = await act4(state: ch2Done);
      await c.createGuild('등불지기');
      expect(c.startRaid(), isNull, reason: '길드 Lv.1');
      a.guildLevel = 4;
      await c.refreshGuild();
      final b = c.startRaid()!;
      expect(b.raidBoss, 'raidDragon');
      expect(b.tickLimit, GuildRules.fightTicks);
      b56.win(b);
      final r1 = await c.finishRaid(b);
      expect(r1.damage, greaterThan(0));
      final b2 = c.startRaid()!;
      b56.win(b2);
      final r2 = await c.finishRaid(b2);
      expect(r2.defeatedNow, isTrue);
      final got = await c.claimGuild('raid');
      expect(got, contains('등불 인장 40'));
      expect(c.player.materialCount(MaterialId.ancientScale), greaterThan(0));
    });
  });

  group('3 운영', () {
    test('되돌린 거래 우편: 남은 만큼만 거두고 · 이름 바꾸기', () async {
      final (c, a) = await act4();
      final gold = c.player.gold;
      a.inbox.add({
        'id': 'rv1',
        'from': '여명의 탑 운영실',
        'title': '거래를 되돌렸어요',
        'body': '잘못된 거래를 되돌렸어요.',
        'op': {
          'take': {'gold': 300}
        },
      });
      a.inbox.add({
        'id': 'rn1',
        'from': '여명의 탑 운영실',
        'title': '이름을 바꿨어요',
        'body': '운영정책에 맞지 않는 이름이라 기본 이름으로 바꿨어요.',
        'op': {
          'rename': {'target': 'awakened'}
        },
      });
      await c.checkInquiryInbox();
      expect(c.player.gold, gold - 300);
      expect(c.profile.name, '각성자');
      // 같은 우편을 다시 받아도 한 번만
      a.inbox.add({'id': 'rv1', 'op': {'take': {'gold': 300}}});
      await c.checkInquiryInbox();
      expect(c.player.gold, gold - 300);
    });

    testWidgets('공지: 홈 띠 · 닫으면 다시 안 보임 · 목록', (tester) async {
      late AppController c;
      late FakeArca a;
      await tester.runAsync(() async {
        (c, a) = await act4();
        a.notices.add({'id': 'n1', 'title': '점검 안내', 'body': '11월 20일 새벽 점검이 있어요.', 'from': 0});
        await c.refreshNotices();
      });
      expect(c.noticeBanner?.title, '점검 안내');
      await tester.pumpWidget(host(Scaffold(body: Stack(children: [NoticeBanner(controller: c)]))));
      expect(find.byKey(const Key('noticeBanner')), findsOneWidget);
      await tester.runAsync(() => c.dismissNotice('n1'));
      expect(c.noticeBanner, isNull);
      await tester.pumpWidget(host(NoticeScreen(controller: c)));
      expect(find.byKey(const Key('notice_n1')), findsOneWidget);
    });

    test('로그인 정지(3단계)면 로그인을 풀고 안내 한 줄', () async {
      final (c, a) = await act4();
      a.statusLevel = 3;
      await c.refreshMyStatus();
      expect(c.cloud.signedIn, isFalse);
      expect(c.suspendedLine, contains('로그인이 정지'));
    });
  });

  group('4 화면', () {
    testWidgets('회관: 길드가 없으면 만들기 · 들어가기 · 리안의 길드', (tester) async {
      late AppController c;
      await tester.runAsync(() async => (c, _) = await act4(state: ch2Done));
      await tester.pumpWidget(host(GuildHallScreen(controller: c)));
      await tester.pump();
      expect(find.byKey(const Key('act4Story')), findsOneWidget);
      expect(find.byKey(const Key('guildCreatePanel')), findsOneWidget);
      await tester.dragUntilVisible(
          find.byKey(const Key('lianGuildPanel')), find.byType(ListView), const Offset(0, -200));
      expect(find.byKey(const Key('guildJoinPanel')), findsOneWidget);
      expect(find.byKey(const Key('lianGuildPanel')), findsOneWidget);
    });

    testWidgets('회관: 길드 탭 네 개 · 레이드 · 상점', (tester) async {
      late AppController c;
      late FakeArca a;
      await tester.runAsync(() async {
        (c, a) = await act4(state: ch2Done);
        await c.createGuild('등불지기');
        a.guildLevel = 4;
        await c.refreshGuild();
      });
      await tester.pumpWidget(host(GuildHallScreen(controller: c)));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      expect(find.byKey(const Key('guildHeader')), findsOneWidget);
      await tester.tap(find.byKey(const Key('guildTab_1')));
      await tester.pump();
      expect(find.byKey(const Key('guildHallView')), findsOneWidget);
      await tester.tap(find.byKey(const Key('guildTab_2')));
      await tester.pump();
      expect(find.byKey(const Key('guildRaid')), findsOneWidget);
      await tester.tap(find.byKey(const Key('guildTab_3')));
      await tester.pump();
      expect(find.byKey(const Key('guildShop')), findsOneWidget);
    });
  });
}
