// 묶음 68 #275: 대화 기능 (길드 · 연맹 · 친구 1:1 · 서버 대화방, 친구, 안전)
// (서버 판정 — 금칙어 · 개인정보 가림 · 도배 · 대화 금지 · Lv.10 · 신고 — 은 node 시험 chat68.test.js)

import 'dart:io';

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/features/chat/chat_screens.dart';

import 'batch52_test.dart' as b52;
import 'batch56_test.dart' as b56;
import 'support/fake_arca.dart';

/// 로그인한 계정 + 친구 후보 둘
Future<(AppController, FakeArca)> chatStart({bool login = true}) async {
  final a = FakeArca()
    ..chatPeople.addAll({
      'u_sol': {'name': '솔', 'level': 24, 'title': '새벽의 걸음', 'look': 'female', 'guild': '새벽걸음', 'steps': 8120, 'lastSeen': DateTime(2026, 11, 20, 8).millisecondsSinceEpoch, 'code': 'SOLA2345'},
      'u_bam': {'name': '밤비', 'level': 9, 'look': 'male', 'showSteps': false, 'steps': 3000, 'lastSeen': DateTime(2026, 11, 17, 8).millisecondsSinceEpoch, 'code': 'BAMB2345'},
    });
  final (c, _) = await b56.start(arca: a, login: login);
  return (c, a);
}

void main() {
  setUp(() => b56.now = b52.t0);

  group('규칙', () {
    test('숫자 · 빠른 말 · 공성전 빠른 말(집결 영지 자동)', () {
      expect(ChatRules.maxLen, 100);
      expect(ChatRules.serverLevel, 10);
      expect(ChatRules.gap, const Duration(seconds: 10));
      expect(ChatRules.maxFriends, 50);
      expect(ChatRules.quick, ['안녕하세요!', '고마워요!', '같이 사냥해요', '잠깐 걷고 올게요', '좋아요!', '수고했어요']);
      expect(ChatRules.siegeQuick('은빛 언덕'), ['은빛 언덕에 집결!', '망치 써 주세요', '성벽 보수 부탁해요', '마지막 6시간, 힘내요!']);
      expect(ChatRules.siegeQuick(null), hasLength(3));
      expect(ChatRules.reasons.values, ['욕설', '괴롭힘', '음란', '광고', '개인정보 요구', '기타']);
    });

    test('대화 금지 줄 · 최근 접속', () {
      final until = DateTime(2026, 11, 21, 15).millisecondsSinceEpoch;
      expect(ChatRules.mutedLine(until), '11월 21일 15시까지 대화할 수 없어요');
      expect(ChatRules.mutedLine(-1), '대화할 수 없어요 (운영정책)');
      final now = DateTime(2026, 11, 20, 10);
      expect(ChatRules.seenText(DateTime(2026, 11, 20, 1).millisecondsSinceEpoch, now), '오늘');
      expect(ChatRules.seenText(DateTime(2026, 11, 19, 23).millisecondsSinceEpoch, now), '어제');
      expect(ChatRules.seenText(DateTime(2026, 11, 17, 8).millisecondsSinceEpoch, now), '3일 전');
    });

    test('친구 초대 링크 (파티 링크와 같은 곳) · 파티 초대 줄', () {
      expect(ChatRules.friendCodeFromLink(Uri.parse(ChatRules.friendLink('HARU2026'))), 'HARU2026');
      expect(ChatRules.friendCodeFromLink(Uri.parse('arca://join/f/haru2026')), 'HARU2026');
      expect(ChatRules.friendCodeFromLink(Uri.parse('https://${PartyRules.linkHost}/join/ABC234')), isNull);
      expect(ChatRules.friendInviteText('하루', 'HARU2026'), contains('HARU2026'));
      final line = ChatRules.partyInviteLine('아침 산책', 'ABC234');
      expect(ChatRules.partyInvite.firstMatch(line)?.group(1), 'ABC234');
    });
  });

  test('문서: 대화 · 친구 문안 자리만 (화면 · 웹에는 안 보이는 줄)', () {
    for (final f in ['privacy', 'terms', 'operation']) {
      final t = File('assets/legal/$f.txt').readAsStringSync();
      expect(t, contains('<!-- 자리(묶음 68 대화 · 친구)'), reason: f);
    }
  });

  group('대화 흐름 (앱)', () {
    test('로그인하지 않으면 대화가 닫혀 있음', () async {
      final (c, _) = await chatStart(login: false);
      expect(c.chatOpen, isFalse);
      expect(await c.refreshChat(), isFalse);
      expect(c.chatError, 'login_required');
    });

    test('처음엔 대화 예절부터 → 「알겠어요」 뒤 말하기 · 가림은 서버가', () async {
      final (c, a) = await chatStart();
      expect(await c.refreshChat(), isTrue);
      expect(c.chatMe!.rooms.map((r) => r.kind), ['server']);
      expect(c.chatMe!.rulesSeen, isFalse);
      expect(await c.sendChat('server', '안녕하세요!'), isFalse);
      expect(c.chatError, 'rules_first');
      expect(await c.seeChatRules(), isTrue);
      expect(c.chatMe!.rulesSeen, isTrue);
      expect(await c.sendChat('server', '내 번호 010-1234-5678 바보'), isTrue);
      expect(c.chatLines('server').last.text, '내 번호 ○○ ○○');
      // 보낼 때 이름 · 레벨 · 칭호를 함께 (방 줄에 보임)
      expect(a.meSent.last['name'], '하루');
    });

    test('서버 대화방은 Lv.10부터 쓰기 (읽기는 누구나)', () async {
      final (c, a) = await chatStart();
      a
        ..chatRulesSeen = true
        ..chatLevel = 9;
      a.chatSay('server', 'u_sol', '모두 안녕!');
      await c.refreshChat();
      expect(await c.readChat('server'), isTrue);
      expect(c.chatLines('server').single.text, '모두 안녕!');
      expect(await c.sendChat('server', '안녕'), isFalse);
      expect(ChatRules.errorText(c.chatError), '서버 대화방은 Lv.10부터 쓸 수 있어요 (읽기는 누구나)');
    });

    test('친구: 코드로 신청 · 받은 신청 수락 → 1:1 방 · 걸음 보여 주기 · 끊기', () async {
      final (c, a) = await chatStart();
      expect(await c.addFriend(code: 'sola2345'), isTrue);
      expect(a.chatSent.last, {'friendReq': 'u_sol'});
      expect(c.chatMe!.friends, isEmpty, reason: '받은 사람이 수락해야 친구');
      a.chatRequests.add('u_bam');
      await c.refreshChat();
      expect(c.chatMe!.requests.single.name, '밤비');
      expect(c.chatMe!.unread, 1, reason: '받은 신청도 빨간 점');
      expect(await c.acceptFriend('u_bam'), isTrue);
      a.chatFriends.add('u_sol');
      await c.refreshChat();
      final sol = c.chatMe!.friends.firstWhere((f) => f.uid == 'u_sol');
      final bam = c.chatMe!.friends.firstWhere((f) => f.uid == 'u_bam');
      expect(sol.steps, 8120);
      expect(bam.steps, isNull, reason: '「걸음 보여 주기」를 끈 친구');
      expect(sol.room, a.chatFriendRoom('u_me', 'u_sol'));
      expect(c.chatMe!.rooms.where((r) => r.kind == 'friend').map((r) => r.name), ['밤비', '솔']);
      expect(await c.removeFriend('u_bam'), isTrue);
      expect(c.chatMe!.friends.map((f) => f.name), ['솔']);
    });

    test('새 1:1 줄은 보고 있지 않을 때만 위쪽 알림 · 읽으면 빨간 점이 사라짐', () async {
      final (c, a) = await chatStart();
      a.chatFriends.add('u_sol');
      await c.refreshChat();
      final room = a.chatFriendRoom('u_me', 'u_sol');
      a.chatSay(room, 'u_sol', '같이 사냥해요');
      final got = <String>[];
      await c.refreshChat(onNew: got.add);
      expect(got, ['솔: 같이 사냥해요']);
      expect(c.chatMe!.unread, 1);
      c.chatOpenRoom = room;
      a.chatSay(room, 'u_sol', '어디예요?');
      await c.refreshChat(onNew: got.add);
      expect(got, hasLength(1));
      await c.readChat(room);
      expect(c.chatMe!.unread, 0);
      c.chatOpenRoom = null;
    });

    test('차단: 그 사람 글이 모든 방에서 숨고, 설정에서 풀기', () async {
      final (c, a) = await chatStart();
      a.chatSay('server', 'u_bam', '광고 보세요');
      a.chatSay('server', 'u_sol', '안녕');
      await c.readChat('server');
      expect(c.chatLines('server'), hasLength(2));
      expect(await c.blockUser('u_bam'), isTrue);
      expect(c.chatLines('server').map((l) => l.name), ['솔']);
      expect(c.chatMe!.blocked.single.name, '밤비');
      expect(await c.unblockUser('u_bam'), isTrue);
      expect(c.chatMe!.blocked, isEmpty);
    });

    test('신고는 그 줄 · 사유를 서버로', () async {
      final (c, a) = await chatStart();
      a.chatSay('server', 'u_bam', '바보야');
      await c.readChat('server');
      final l = c.chatLines('server').single;
      expect(await c.reportChat('server', l.id, 'abuse'), isTrue);
      expect(a.chatReports.single, {'room': 'server', 'id': l.id, 'reason': 'abuse'});
    });

    test('대화 금지면 서버가 막고, 끝나는 시각을 앎', () async {
      final (c, a) = await chatStart();
      a
        ..chatRulesSeen = true
        ..chatMutedUntil = DateTime(2026, 11, 21, 15).millisecondsSinceEpoch;
      await c.refreshChat();
      expect(ChatRules.mutedLine(c.chatMe!.mutedUntil!), '11월 21일 15시까지 대화할 수 없어요');
      expect(await c.sendChat('server', '안녕'), isFalse);
      expect(c.chatError, 'muted');
    });

    test('길드에 들어가면 길드 대화방 (길드 소식은 시스템 줄)', () async {
      final (c, a) = await chatStart();
      a.guild = {'id': 'g1', 'name': '새벽걸음', 'emblem': 0, 'color': 0, 'open': true, 'code': 'GLD001'};
      a.chatSay('g_g1', '', '「새벽걸음」 집결 깃발: 은빛 언덕', kind: 'sys');
      await c.refreshChat();
      expect(c.chatMe!.guildRoom?.room, 'g_g1');
      expect(c.chatMe!.guildRoom?.unread, 0, reason: '시스템 줄은 빨간 점에 세지 않음');
      await c.readChat('g_g1');
      expect(c.chatLines('g_g1').single.system, isTrue);
    });

    test('친구 초대 링크로 열리면 친구 코드가 기다림', () async {
      final (c, _) = await chatStart();
      c.handleInviteLink(Uri.parse(ChatRules.friendLink('SOLA2345')));
      expect(c.pendingFriendCode, 'SOLA2345');
      expect(c.pendingInvite, isNull);
      expect(c.takeFriendCode(), 'SOLA2345');
      expect(c.pendingFriendCode, isNull);
    });
  });

  group('화면', () {
    testWidgets('말풍선 버튼: 안 읽은 수 빨간 점 · 로그인 안 했으면 없음', (tester) async {
      late AppController c;
      await tester.runAsync(() async {
        final (cc, a) = await chatStart();
        c = cc;
        a.chatFriends.add('u_sol');
        a.chatSay(a.chatFriendRoom('u_me', 'u_sol'), 'u_sol', '안녕!');
        a.chatRequests.add('u_bam');
        await c.refreshChat();
      });
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: ChatButton(controller: c)))));
      await tester.pump();
      expect(find.byKey(const Key('chatButton')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('chatUnread')), matching: find.text('2')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('대화 예절 → 「알겠어요」', (tester) async {
      late AppController c;
      await tester.runAsync(() async => c = (await chatStart()).$1);
      await tester.pumpWidget(MaterialApp(home: EtiquetteScreen(controller: c)));
      expect(find.text('대화 예절'), findsOneWidget);
      expect(find.byKey(const Key('etiquetteOk')), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('etiquetteOk')));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      expect(c.chatMe?.rulesSeen, isTrue);
    });

    testWidgets('대화방: 빠른 말 · 대화 금지면 입력창 대신 안내 · Lv.10 전 서버방', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      late AppController c;
      late FakeArca a;
      await tester.runAsync(() async {
        final r = await chatStart();
        c = r.$1;
        a = r.$2..chatRulesSeen = true;
        a.chatSay('server', 'u_sol', '모두 안녕!');
        await c.refreshChat();
        await c.readChat('server');
      });
      await tester.pumpWidget(MaterialApp(home: ChatRoomScreen(controller: c, room: 'server', name: '서버 대화방', kind: 'server')));
      await tester.pump();
      expect(find.text('모두 안녕!'), findsOneWidget);
      expect(find.byKey(const Key('chatInput')), findsOneWidget);
      expect(find.text('안녕하세요!'), findsOneWidget);
      expect(find.text('망치 써 주세요'), findsNothing, reason: '공성전 빠른 말은 길드 · 연맹 방에서 공성전 중에만');
      await tester.pumpWidget(const SizedBox());

      await tester.runAsync(() async {
        a.chatMutedUntil = DateTime(2026, 11, 21, 15).millisecondsSinceEpoch;
        await c.refreshChat();
      });
      await tester.pumpWidget(MaterialApp(home: ChatRoomScreen(controller: c, room: 'server', name: '서버 대화방', kind: 'server')));
      await tester.pump();
      expect(find.byKey(const Key('chatInput')), findsNothing);
      expect(find.text('11월 21일 15시까지 대화할 수 없어요'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());

      await tester.runAsync(() async {
        a
          ..chatMutedUntil = null
          ..chatLevel = 7;
        await c.refreshChat();
      });
      await tester.pumpWidget(MaterialApp(home: ChatRoomScreen(controller: c, room: 'server', name: '서버 대화방', kind: 'server')));
      await tester.pump();
      expect(find.byKey(const Key('chatLevelLock')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
