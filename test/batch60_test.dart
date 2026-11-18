// 묶음 60: 묶음 59 확인 답(보관 기간 · 길드 초대 링크) · 약관 4종 다시 동의 · 5막 첫 편 「흑등 연맹의 귀환」

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/act4_state.dart';
import 'package:isekai_reality/core/models/act5_state.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/act5/erbard_screens.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'batch52_test.dart' as b52;
import 'batch56_test.dart' as b56;
import 'batch59_test.dart' as b59;
import 'support/fake_arca.dart';

Widget host(Widget home) =>
    MaterialApp(builder: (context, child) => TopNoticeHost(child: child!), home: home);

const act4Done = Act4State(
  opened: true,
  chapter: 5,
  seen: {'c1a', 'c1b', 'c2a', 'c2b', 'c2c', 'c3a', 'c3b', 'c3c', 'c4a', 'c4b', 'c5a', 'c5b', 'c5c'},
  giant: true,
  done: true,
  charter: true,
  lian: true,
);

/// 4막을 끝낸 계정 (5막 기록 [act5]) · [guild] 면 로그인 + 길드
Future<(AppController, FakeArca)> act5({Act5State? state, bool guild = false, bool login = true, FakeArca? arca}) async {
  final a = arca ?? FakeArca();
  var (c, _) = await b59.act4(state: guild ? act4Done.copyWith(lian: false) : act4Done, arca: a, login: login || guild);
  if (state != null) {
    await c.store.saveJson('act5', state.toJson());
    c = (await b56.start(store: c.store as InMemoryRecordStore, arca: a, login: login || guild)).$1;
  }
  if (guild) {
    // 길드 만들기는 4막 증서로
    expect(await c.createGuild('새벽걸음'), isTrue, reason: c.guildError);
    await c.refreshErbard();
  }
  return (c, a);
}

/// 싸움을 꼭 이기게
void win(Battle b) {
  for (var i = 0; i < 2000 && !b.isOver; i++) {
    b.playerHp = 99999;
    b.foeHp = 1;
    b.tick();
  }
}

Future<void> seeAll(AppController c) async {
  for (var i = 0; i < 6; i++) {
    final s = c.pendingAct5Scene;
    if (s == null) return;
    await c.markAct5Scene(s);
  }
}

void main() {
  setUp(() => b56.now = b52.t0);

  group('0 묶음 59 확인 답 · 약관', () {
    test('약관 4종 2판: 적용일부터 바뀐 필수 문서 셋을 다시 동의 · 운영정책은 보기만', () {
      final now = DateTime(2026, 11, 18, 12);
      final need = LegalRules.needed({for (final k in LegalKind.values) k: 1}, now);
      expect(need.map((v) => v.kind).toSet(), {LegalKind.terms, LegalKind.privacy, LegalKind.location});
      expect(need.every((v) => v.version == 2), isTrue);
      expect(LegalRules.needed({for (final k in LegalKind.values) k: 1}, DateTime(2026, 11, 17, 12)), isEmpty);
    });

    test('앱 안 문서 = 정책 문서 최신본 (거래소 · 순위 · 길드 · 공성 · 운영 기록 · 보관 기간 · 만 14세 확인)', () {
      final p = File('assets/legal/privacy.txt').readAsStringSync();
      for (final w in ['거래소(로그인하고', '심층 주간 순위', '공성전 기록', '약관 동의 기록', '운영(제재·공지·보상)', '다른 이용자에게 보이는 정보',
        '거래가 끝난 날부터 1년', '순위 보상을 보낸 뒤 4주', '정지한 날부터 3년', '운영자 행동 기록: 1년', '거래소 · 순위 · 길드) 실행', '2026년 11월 18일']) {
        expect(p, contains(w), reason: w);
      }
      expect(p, isNot(contains('출생 연도')));
      expect(File('assets/legal/location_terms.txt').readAsStringSync(), isNot(contains('출생 연도')));
      final t = File('assets/legal/terms.txt').readAsStringSync();
      for (final w in ['영구 정지된 적이 있으면', '안정적으로 제공하기 위해 노력', '광고성 정보', '잠시 세지 않을 수 있습니다', '권리는 쓴 사람에게', '그 손해를 배상']) {
        expect(t, contains(w), reason: w);
      }
    });

    test('웹 페이지 글 = 앱 안 문서 · 서버 영지 표 = 앱 영지 표', () {
      final j = jsonDecode(File('firebase/functions/src/legal_texts.json').readAsStringSync()) as Map;
      expect(j['privacy'], File('assets/legal/privacy.txt').readAsStringSync());
      expect(j['terms'], File('assets/legal/terms.txt').readAsStringSync());
      expect(j['location'], File('assets/legal/location_terms.txt').readAsStringSync());
      expect(j['policy'], File('assets/legal/operation.txt').readAsStringSync());
      expect(File('firebase/functions/src/siege_estates.json').readAsStringSync(), ErbardRules.estatesJson());
    });

    test('길드 초대 링크 /join/g/코드 → 「길드에 들어갈까요?」 · 파티 링크는 그대로', () async {
      expect(PartyRules.guildCodeFromLink(Uri.parse('https://${PartyRules.linkHost}/join/g/abc234')), 'ABC234');
      expect(PartyRules.guildCodeFromLink(Uri.parse('arca://join/g/ABC234')), 'ABC234');
      expect(PartyRules.guildCodeFromLink(Uri.parse('https://${PartyRules.linkHost}/join/ABC234')), isNull);
      expect(PartyRules.guildInviteText('새벽', 'ABC234'), contains('/join/g/ABC234'));
      final (c, _) = await act5();
      c.handleInviteLink(Uri.parse('https://${PartyRules.linkHost}/join/g/ABC234'));
      expect(c.pendingGuildInvite, 'ABC234');
      expect(c.pendingInvite, isNull);
      expect(c.canJoinGuildByCode, isTrue);
    });
  });

  group('1 5막 혼자 (리안의 길드)', () {
    test('4막 5장 뒤 바로 1장 · 장면 셋 뒤 2장 · 공성권 2,000보마다 (최대 20장)', () async {
      final (c, _) = await act5(login: false);
      expect(c.act5Open, isTrue);
      expect(c.pendingAct5Scene?.id, 'e1a');
      expect(c.siegeTickets, 0, reason: '1장 끝나기 전엔 모으지 않음');
      await seeAll(c);
      expect(c.act5Chapter, 2);
      expect(c.act5.has('e1c'), isTrue);
      // 걸음을 오래 걸었다고 치고
      await c.store.saveJson('act5', c.act5.copyWith(ticketAt: -9000).toJson());
      final (c2, _) = await b56.start(store: c.store as InMemoryRecordStore, login: false);
      expect(c2.siegeTickets, (9000 + 12000) ~/ 2000);
      await c2.store.saveJson('act5', c2.act5.copyWith(ticketAt: -100000).toJson());
      final (c3, _) = await b56.start(store: c2.store as InMemoryRecordStore, login: false);
      expect(c3.siegeTickets, ErbardRules.ticketMax);
    });

    test('빈 영지 개척: 야생 수비대 5자리 (영지는 빈 채로) → 2만 보 뒤 2장 · 리안 한마디 · 개척 보상', () async {
      final (c, _) = await act5(
          login: false,
          state: const Act5State(opened: true, chapter: 2, seen: {'e1a', 'e1b', 'e1c'}, chapterSteps: -10000, ticketAt: -20000));
      final e = ErbardRules.estate('sol_lily')!;
      expect(c.erbardFightKind(e), 'wild');
      expect(c.erbardFightKind(ErbardRules.estate('sol_silver')!), isNull, reason: '흑등 영지는 길드 공성전');
      final t0 = c.siegeTickets;
      for (var k = 0; k < 5; k++) {
        final b = (await c.startErbardFight(e))!;
        win(b);
        final r = await c.finishErbardFight(b);
        expect(r.won, isTrue);
        if (k == 4) expect(r.full, isTrue);
      }
      expect(c.siegeTickets, t0 - 5);
      expect(c.act5.pioneered, isTrue);
      expect(c.erbard.owners['sol_lily'], isNull, reason: '혼자는 영지를 갖지 않음');
      expect(c.pendingAct5Scene?.id, 'e2a');
      final seals = c.lanternSeals;
      await seeAll(c);
      expect(c.act5.has('e2b'), isTrue);
      expect(c.lanternSeals, seals + ErbardRules.pioneerSeals + 0);
      expect(c.act5Chapter, 3);
      expect(c.act5.ch3Siege, 0, reason: '처음 열리는 공성전');
    });

    test('3장: 공성전 기간에 야생 수비대 세 번 → 끝나면 카스파르(못 찾음) · 리안 → 칭호 「에르바르드의 개척자」', () async {
      final (c0, _) = await act5(
          login: false,
          state: const Act5State(
              opened: true, chapter: 3, seen: {'e1a', 'e1b', 'e1c', 'e2a', 'e2b'}, ticketAt: -40000, ch3Siege: 0, pioneered: true));
      expect(c0.pendingAct5Scene, isNull);
      b56.now = DateTime(2026, 11, 28, 10);
      final (c, _) = await b56.start(store: c0.store as InMemoryRecordStore, login: false);
      expect(ErbardRules.siegeActive(c.now), isTrue);
      for (var k = 0; k < 3; k++) {
        final b = (await c.startErbardFight(ErbardRules.estate('mor_mill')!))!;
        win(b);
        await c.finishErbardFight(b);
      }
      expect(c.act5.ch3Solo, 3);
      expect(c.pendingAct5Scene, isNull, reason: '공성전이 끝나야');
      b56.now = DateTime(2026, 11, 30, 9);
      final (c2, _) = await b56.start(store: c.store as InMemoryRecordStore, login: false);
      expect(c2.pendingAct5Scene, ErbardRules.e3aLose);
      await seeAll(c2);
      expect(c2.act5Done, isTrue);
      expect(c2.titlesNewestFirst, contains(TitleId.pioneer));
      expect(c2.act5Goal, ErbardRules.erbardTeaser);
    });

    test('3장 공성전에 참여하지 못하고 끝나면 다음 공성전으로', () async {
      b56.now = DateTime(2026, 12, 1, 9);
      final (c, _) = await act5(
          login: false,
          state: const Act5State(opened: true, chapter: 3, seen: {'e1a', 'e1b', 'e1c', 'e2a', 'e2b'}, ticketAt: 0, ch3Siege: 0));
      expect(c.pendingAct5Scene, isNull);
      expect(c.act5.ch3Siege, 1);
    });
  });

  group('2 5막 길드 (서버)', () {
    test('빈 영지를 길드원이 깨면 길드 영지 · 수비대 배치(분신 + 동료 둘) · 연맹 · 공성전 · 결과', () async {
      final (c, a) = await act5(
          guild: true, state: const Act5State(opened: true, chapter: 2, seen: {'e1a', 'e1b', 'e1c'}, chapterSteps: -30000, ticketAt: -30000));
      expect(c.erbardGuild, isTrue);
      expect(c.erbard.server, isTrue);
      expect(c.erbard.owners['royal']?.kind, 'npc');
      final e = ErbardRules.estate('sol_lily')!;
      for (var k = 0; k < 5; k++) {
        final b = (await c.startErbardFight(e))!;
        expect(b.foe.monster, k == 4 ? MonsterId.wildKnightCaptain : MonsterId.wildGriffin);
        win(b);
        final r = await c.finishErbardFight(b);
        if (k == 4) expect(r.captured, isTrue);
      }
      expect(c.erbard.myEstates, ['sol_lily']);
      expect(c.erbard.owners['sol_lily']?.kind, 'mine');
      // 2장 → 세라 → 수비대 배치
      await seeAll(c);
      expect(c.garrisonOpen, isTrue);
      expect(c.act5Chapter, 3);
      expect(await c.placeGarrison('sol_lily', 2, const []), isTrue);
      expect(c.erbard.garrisons['sol_lily']![2]!.me, isTrue);
      expect(c.erbard.placed, 'sol_lily');
      expect(await c.allianceAction('create', name: '별빛'), isTrue);
      expect(c.erbard.alliance?.code, 'ALY234');
      // 공성전: 흑등 영지 · 다른 길드 영지(분신 + 동료)
      a.siegeActive = true;
      a.siegeOwners['dor_wind'] = {'gid': 'other', 'name': '노을', 'emblem': 1, 'color': 2};
      b56.now = DateTime(2026, 11, 28, 10);
      await c.refreshErbard();
      expect(c.erbardFightKind(ErbardRules.estate('sol_silver')!), 'siege');
      final b1 = (await c.startErbardFight(ErbardRules.estate('dor_wind')!))!;
      expect(b1.floors.length, 2);
      expect(b1.foe.name, '별하의 분신');
      win(b1);
      await c.finishErbardFight(b1);
      expect(c.act5.ch3Used, 1);
      expect(await c.placeGarrison('sol_lily', 1, const []), isFalse, reason: '공성전 중엔 못 바꿈');
      // 끝 → 결과
      a.siegeActive = false;
      a.siegeLast = {
        'no': 0,
        'royal': {'gid': 'g1', 'name': '새벽걸음'},
        'changes': [
          {'estate': 'royal', 'fromName': '흑등 연맹', 'toName': '새벽걸음'},
        ],
      };
      b56.now = DateTime(2026, 11, 30, 9);
      await c.refreshErbard();
      expect(c.siegeResultPending, isTrue);
      expect(c.pendingAct5Scene, ErbardRules.e3aWin);
      await c.markSiegeResultSeen();
      expect(c.siegeResultPending, isFalse);
    });

    test('에르바르드 사냥: 우리 길드 영지면 조금 더', () async {
      final (c, a) = await act5(
          guild: true, state: const Act5State(opened: true, chapter: 2, seen: {'e1a', 'e1b', 'e1c'}, ticketAt: 0));
      a.siegeOwners['sil_deer'] = {'gid': 'mine', 'name': '새벽걸음', 'emblem': 0, 'color': 0};
      await c.refreshErbard();
      final e = ErbardRules.estate('sil_deer')!;
      expect(c.canErbardHunt(e), isTrue);
      final b = c.startErbardHunt(e)!;
      expect(b.foe.monster, MonsterId.wildBoar);
      win(b);
      final r = await c.finishErbardHunt(b);
      expect(r.won, isTrue);
      expect(r.lines.last, contains('우리 길드 영지라'));
    });
  });

  group('3 화면', () {
    testWidgets('대륙 지도: 영지 31 · 공성권 · 이야기 카드 · 영지 창', (tester) async {
      late AppController c;
      await tester.runAsync(() async {
        (c, _) = await act5(
            guild: true, state: const Act5State(opened: true, chapter: 2, seen: {'e1a', 'e1b', 'e1c'}, ticketAt: -10000));
      });
      await tester.pumpWidget(host(ErbardScreen(controller: c)));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      expect(find.byKey(const Key('siegeTickets')), findsOneWidget);
      expect(find.byKey(const Key('act5Story')), findsOneWidget);
      expect(find.byKey(const Key('estate_royal')), findsOneWidget);
      await tester.tap(find.byKey(const Key('estate_royal')), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('estateSheet_royal')), findsOneWidget);
    });

    testWidgets('공성전 결과 화면', (tester) async {
      late AppController c;
      late FakeArca a;
      await tester.runAsync(() async {
        (c, a) = await act5(guild: true, state: const Act5State(opened: true, chapter: 3, seen: {'e1a', 'e1b', 'e1c', 'e2a'}, ticketAt: 0));
        a.siegeLast = {'no': 0, 'royal': {'gid': 'npc', 'name': '흑등 연맹'}, 'changes': []};
        await c.refreshErbard();
      });
      await tester.pumpWidget(host(SiegeResultScreen(controller: c)));
      await tester.pump();
      expect(find.text('제1회 깃발 공성전'), findsOneWidget);
      expect(find.text('왕성은 아직 흑등 연맹이 쥐고 있어요'), findsOneWidget);
    });
  });
}
