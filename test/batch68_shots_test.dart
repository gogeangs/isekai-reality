// 묶음 68 #275 대화 · 친구 (build/screenshots/b68_*)
// 작은 iPhone(SE) · 큰 iPhone · Android

import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/features/chat/chat_screens.dart';
import 'package:isekai_reality/features/mail/mail_screen.dart';
import 'package:isekai_reality/features/profile/profile_screen.dart';
import 'package:isekai_reality/features/status/status_screen.dart';
import 'package:isekai_reality/theme/ornaments.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'batch52_test.dart' as b52;
import 'batch56_test.dart' as b56;
import 'batch60_test.dart' as b60;
import 'batch68_test.dart' show chatStart;
import 'support/fake_arca.dart';
import 'package:isekai_reality/core/models/act5_state.dart';

final _root = GlobalKey();

Future<void> _loadFonts() async {
  final korean = FontLoader('Roboto');
  for (final f in [
    'NanumGothic-Regular',
    'NanumGothic-Bold',
    'NanumGothic-ExtraBold',
  ]) {
    korean.addFont(File('test/fonts/$f.ttf')
        .readAsBytes()
        .then((b) => ByteData.view(b.buffer)));
  }
  await korean.load();
  final manifest =
      jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final family in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(family['family'] as String);
    for (final font in (family['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      final image = element.widget as Image;
      await precacheImage(image.image, element, onError: (_, __) {});
    }
  });
  await tester.pump();
  for (var i = 0; i < 2; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 400)));
    await tester.pump();
  }
  final boundary =
      tester.renderObject(find.byKey(_root)) as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.5);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  File('build/screenshots/b68_$name.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!);
}

/// (이름, 화면 픽셀, 배율, 위·아래 여백(픽셀))
const _devices = [
  ('SE', Size(750, 1334), 2.0, 40.0, 0.0),
  ('큰iPhone', Size(1290, 2796), 3.0, 177.0, 102.0),
  ('Android', Size(1080, 2400), 2.625, 63.0, 63.0),
];

void _device(WidgetTester tester, (String, Size, double, double, double) d,
    {double text = 1}) {
  tester.platformDispatcher.textScaleFactorTestValue = text;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  tester.view.physicalSize = d.$2;
  tester.view.devicePixelRatio = d.$3;
  tester.view.padding = FakeViewPadding(top: d.$4, bottom: d.$5);
  tester.view.viewPadding = FakeViewPadding(top: d.$4, bottom: d.$5);
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester, [int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}


Future<void> _page(WidgetTester tester, Widget home) async {
  await tester.pumpWidget(RepaintBoundary(
    key: _root,
    child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => TopNoticeHost(child: child!),
        home: home),
  ));
  await _settle(tester);
}

const _ch3 = Act5State(opened: true, chapter: 3, seen: {'e1a', 'e1b', 'e1c', 'e2a', 'e2b'}, ticketAt: -60000);

int _ms(int h, int m) => DateTime(2026, 11, 20, h, m).millisecondsSinceEpoch;

/// 친구 둘 · 받은 신청 하나 · 1:1 대화 · 서버 대화(가림)
void _seed(FakeArca a) {
  a.chatRulesSeen = true;
  a.chatPeople.addAll({
    'u_bom': {'name': '봄비', 'level': 18, 'look': 'female', 'title': '꽃길 산책자', 'steps': 2400, 'lastSeen': _ms(9, 0)},
    'u_lune': {'name': '루네', 'level': 41, 'look': 'male', 'title': '탑의 정복자', 'guild': '별빛원정대', 'steps': 15300, 'lastSeen': _ms(10, 0)},
    'u_wolf': {'name': '검은늑대', 'level': 15, 'look': 'male'},
    'u_mist': {'name': '안개', 'level': 22, 'look': 'female'},
  });
  a.chatFriends.addAll(['u_sol', 'u_bam', 'u_lune']);
  a.chatRequests.add('u_bom');
  final dm = a.chatFriendRoom('u_me', 'u_sol');
  a.chatSay(dm, 'u_sol', '오늘 몇 걸음 걸었어요?', at: _ms(9, 10));
  a.chatSay(dm, 'u_me', '아직 6천 보요 😅', at: _ms(9, 11));
  a.chatSay(dm, 'u_sol', '저녁에 같이 사냥해요!', at: _ms(9, 12));
  a.chatSay(dm, 'u_me', ChatRules.partyInviteLine('아침 산책', 'ABC234'), at: _ms(9, 13));
  a.chatSay(dm, 'u_sol', '좋아요! 👍', at: _ms(9, 14));
  a.chatSay('server', 'u_lune', '여명의 탑 30층 넘은 분 계세요?', at: _ms(9, 20));
  a.chatSay('server', 'u_mist', '저 32층이요!', at: _ms(9, 21));
  a.chatSay('server', 'u_wolf', '연락해요 ${FakeArca.chatMask('010-1234-5678')}', at: _ms(9, 22));
  a.chatSay('server', 'u_wolf', FakeArca.chatMask('이 바보들아'), at: _ms(9, 23));
  a.chatSay('server', 'u_bom', '처음 왔어요! 안녕하세요', at: _ms(9, 24));
  a.chatReads['server'] = _ms(9, 30);
  a.chatNow = _ms(9, 40);
}

Widget _top(AppController c) => Scaffold(
      body: Stack(children: [
        NightBackground(header: true, child: StatusScreen(player: c.player, look: c.profile.look)),
        Positioned(top: MediaQuery.paddingOf(_ctx!).top + 6, left: 12, child: ProfileButton(look: c.profile.look, level: c.player.level.level, onTap: () {})),
        Positioned(top: MediaQuery.paddingOf(_ctx!).top + 6, right: 120, child: ChatButton(controller: c)),
        Positioned(top: MediaQuery.paddingOf(_ctx!).top + 6, right: 66, child: MailButton(hasNew: false, onTap: () {})),
        Positioned(top: MediaQuery.paddingOf(_ctx!).top + 6, right: 12, child: SettingsButton(onTap: () {})),
      ]),
    );
BuildContext? _ctx;

void main() {
  setUpAll(_loadFonts);
  setUp(() => b56.now = b52.t0);

  for (final d in _devices) {
    final n = d.$1;

    testWidgets('b68 $n: 말풍선 빨간 점 · 위쪽 알림 · 친구 · 대화방 목록', (tester) async {
      _device(tester, d);
      late AppController c;
      late FakeArca a;
      await tester.runAsync(() async {
        final r = await chatStart();
        c = r.$1;
        a = r.$2;
        _seed(a);
        await c.refreshChat();
      });
      await _page(tester, Builder(builder: (ctx) {
        _ctx = ctx;
        return _top(c);
      }));
      await _shot(tester, '${n}_01_말풍선_빨간점');
      showTopNotice(tester.element(find.byKey(const Key('chatButton'))), '솔: 저녁에 같이 사냥해요!', icon: Icons.chat_bubble_rounded);
      await _settle(tester, 3);
      await _shot(tester, '${n}_02_새1대1_알림');
      await tester.pump(const Duration(seconds: 5));

      await _page(tester, ChatHubScreen(key: ObjectKey('h$n'), controller: c));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await _settle(tester);
      await _shot(tester, '${n}_03_대화방_목록');
      await tester.tap(find.byKey(const Key('chatTab_1')));
      await _settle(tester);
      await _shot(tester, '${n}_04_친구_목록_신청');
      await tester.tap(find.byKey(const Key('friend_u_sol')));
      await _settle(tester);
      await _shot(tester, '${n}_05_친구_누르면');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('b68 $n: 1:1 · 서버(가림) · 신고 · 차단 · 대화 금지 · 예절', (tester) async {
      _device(tester, d);
      late AppController c;
      late FakeArca a;
      await tester.runAsync(() async {
        final r = await chatStart();
        c = r.$1;
        a = r.$2;
        _seed(a);
        await c.refreshChat();
      });
      final dm = a.chatFriendRoom('u_me', 'u_sol');
      await _page(tester, ChatRoomScreen(key: ObjectKey('d$n'), controller: c, room: dm, name: '솔', kind: 'friend'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await _settle(tester);
      await _shot(tester, '${n}_06_1대1');
      await _page(tester, ChatRoomScreen(key: ObjectKey('s$n'), controller: c, room: 'server', name: '서버 대화방', kind: 'server'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await _settle(tester);
      await _shot(tester, '${n}_07_서버_가림');
      final wolf = c.chatLines('server').lastWhere((l) => l.uid == 'u_wolf');
      await tester.longPress(find.byKey(Key('chatLine_${wolf.id}')));
      await _settle(tester);
      await _shot(tester, '${n}_08_길게눌러_신고차단');
      await tester.tap(find.byKey(const Key('lineReport')));
      await _settle(tester);
      await _shot(tester, '${n}_09_신고_사유');
      await tester.tap(find.byKey(const Key('reason_abuse')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await _settle(tester, 3);
      await _shot(tester, '${n}_10_신고했어요');
      await tester.pump(const Duration(seconds: 5));
      await tester.runAsync(() async {
        await c.blockUser('u_wolf');
        a.chatMutedUntil = DateTime(2026, 11, 21, 15).millisecondsSinceEpoch;
        await c.refreshChat();
      });
      await _settle(tester);
      await _shot(tester, '${n}_11_차단뒤_대화금지');
      await _page(tester, ChatSettingsScreen(key: ObjectKey('st$n'), controller: c));
      await _shot(tester, '${n}_12_설정_차단목록');
      await _page(tester, EtiquetteScreen(key: ObjectKey('e$n'), controller: c));
      await _shot(tester, '${n}_13_대화예절');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('b68 $n: 길드 · 연맹 방 (공성전 줄 고정 · 빠른 말)', (tester) async {
      _device(tester, d);
      late AppController c;
      late FakeArca a;
      await tester.runAsync(() async {
        final r = await b60.act5(guild: true, state: _ch3);
        c = r.$1;
        a = r.$2;
        a.siegeActive = true;
        a.rallyEstate = 'dor_deep';
        a.alliance = {'id': 'al1', 'name': '새벽 연합', 'code': 'ALY234', 'guilds': ['새벽걸음', '별빛원정대', '푸른등불'], 'locked': true};
        a.chatRulesSeen = true;
        a.chatPeople.addAll({
          'u_sol': {'name': '솔', 'level': 24, 'title': '새벽의 걸음'},
          'u_lune': {'name': '루네', 'level': 41, 'title': '탑의 정복자'},
          'u_bam': {'name': '밤비', 'level': 19},
        });
        a.chatSay('g_g1', '', '하루 님이 집결 깃발을 꽂았어요 · 깊은 골짜기', kind: 'sys', at: _ms(9, 0));
        a.chatSay('g_g1', 'u_sol', '깊은 골짜기로 가요!', at: _ms(9, 2));
        a.chatSay('g_g1', 'u_bam', '@하루 망치 언제 써요?', at: _ms(9, 4));
        a.chatSay('g_g1', '', '성벽 보수: 백합 들판 한 자리를 되살렸어요', kind: 'sys', at: _ms(9, 6));
        a.chatSay('g_g1', 'u_sol', '마지막 6시간, 힘내요!', at: _ms(9, 8));
        a.chatSay('a_al1', 'u_lune', '별빛원정대는 남쪽 영지 맡을게요', at: _ms(9, 10));
        a.chatSay('a_al1', 'u_sol', '고마워요!', at: _ms(9, 11));
        b56.now = DateTime(2026, 11, 28, 10);
        await c.refreshErbard();
        await c.refreshChat();
      });
      await _page(tester, ChatRoomScreen(key: ObjectKey('g$n'), controller: c, room: 'g_g1', name: '길드 · 새벽걸음', kind: 'guild'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await _settle(tester);
      await _shot(tester, '${n}_14_길드_공성전');
      await _page(tester, ChatRoomScreen(key: ObjectKey('a$n'), controller: c, room: 'a_al1', name: '연맹 · 새벽 연합', kind: 'alliance'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await _settle(tester);
      await _shot(tester, '${n}_15_연맹');
      await tester.pumpWidget(const SizedBox());
    });
  }
}
