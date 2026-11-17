// 묶음 56: 파티(서버 2단계 #236) + 문의 양식(#248) — 앱 쪽 흐름 (서버 판정은 firebase/functions 의 node 시험)

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/geo/geo.dart';
import 'package:isekai_reality/core/models/armory.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/cloud/backup_server.dart';
import 'package:isekai_reality/data/cloud/cloud_auth.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/settings/inquiry_screen.dart';
import 'package:isekai_reality/features/village/tavern_screen.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'batch52_test.dart' as b52;
import 'support/fake_arca.dart';

DateTime now = b52.t0;

/// 결말을 본 계정 · 로그인 · 가짜 서버. [steps] = 오늘 걸음
Future<(AppController, FakeArca)> start({
  int steps = 12000,
  bool login = true,
  FakeArca? arca,
  InMemoryRecordStore? store,
  bool king = true,
}) async {
  final s = store ?? b52.account(king: king, meet: king);
  final h = FakeHealthSource(stepsByDay: {b52.todayKey: steps});
  final a = arca ?? FakeArca();
  final c = AppController(
    store: s,
    health: h,
    clock: () => now,
    random: math.Random(5),
  )
    ..mailSources = const []
    ..cloudAuth = FakeCloudAuth()
    ..backupServer = (FakeBackupServer()..time = now.toUtc())
    ..arcaApi = a;
  await c.init();
  await c.markPartyNotice(); // 묶음 57: 파티 위치 안내는 batch57 시험에서
  if (login) await c.signInCloud(LoginProvider.google);
  return (c, a);
}

void win(Battle b) {
  for (var i = 0; i < 400 && !b.isOver; i++) {
    b.playerHp = 99999;
    b.tick();
  }
}

void main() {
  setUp(() => now = b52.t0);

  group('규칙', () {
    test('파티 보스 4 · 재료 4 · 동행 세트 6부위 · 깃발 8 · 색 8 · 서버와 같은 값', () {
      expect(PartyRules.bosses.map((b) => Monsters.info(b).name),
          ['거대 골렘', '히드라', '잿빛 와이번', '크라켄']);
      for (final b in PartyRules.bosses) {
        expect(Materials.info(PartyRules.bossMat(b)).rare, isTrue);
      }
      expect(BossGearRules.partySet.parts, hasLength(6));
      expect(BossGearRules.setOf(EquipBase.partyAcc), BossSet.party);
      expect(PartyRules.emblems, hasLength(8));
      expect(PartyRules.colors, hasLength(8));
      expect(PartyRules.walkPerHead, [30000, 70000, 100000]);
      expect(PartyRules.fightHp(22), (900 + 140 * 22) * 3);
      // 위치 칸은 백업과 같은 크기
      expect(PartyRules.cellLat, 0.0009);
      expect(PartyRules.cellLng, 0.001125);
      // 세트 효과
      final six = SetBonus.of([
        for (final p in BossGearRules.partySet.parts)
          EquipItem(uid: p.$1.name, base: p.$1, grade: EquipGrade.white),
      ]);
      expect(six.partyBoss, PartyRules.set6Boss);
      expect(six.togetherExp, PartyRules.set4Together);
      expect(PartyRules.errorText('same_device'), PartyRules.sameDevice);
    });
  });

  group('파티', () {
    test('결말 뒤 · 로그인 안 하면 서버를 부르지 않음', () async {
      final (c, a) = await start(login: false);
      expect(c.partyOpen, isTrue);
      expect(c.partyReady, isFalse);
      await c.refreshParty();
      expect(a.calls, isEmpty);
      final (c2, _) = await start(king: false);
      expect(c2.partyOpen, isFalse);
    });

    test('만들기 → 함께 걷기 받기(발자국 표) → 응원 알림 → 나가기', () async {
      final (c, a) = await start(steps: 40000);
      await c.refreshParty();
      expect(c.party!.inParty, isFalse);
      expect(await c.createParty(''), isTrue);
      expect(c.party!.name, '하루의 파티');
      expect(c.party!.owner, isTrue);
      a.addMember('ABC234', 'u_star', '별', stepsWeek: 25000);
      await c.refreshParty();
      expect(c.party!.walkTotal, 65000);
      expect(c.party!.walkGoals, [60000, 140000, 200000]);
      final gold0 = c.player.gold;
      final got = await c.claimParty('walk', tier: 0);
      expect(got, contains('발자국 표 10'));
      expect(c.player.gold, gold0 + 200);
      expect(c.partyLocal.tickets, 10);
      expect(await c.claimParty('walk', tier: 0), isNull);
      expect(c.partyError, 'claimed');
      a.cheeredBy = '별';
      await c.refreshParty();
      expect(c.takePartyNotice(), PartyRules.cheerFrom('별'));
      expect(await c.cheerMember('u_star'), isTrue);
      expect(await c.cheerMember('u_star'), isFalse);
      expect(c.partyError, 'cheered_today');
      expect(await c.leaveParty(), isTrue);
      expect(c.party!.inParty, isFalse);
    });

    test('파티 보스: 도전권 → 정해진 턴 → 준 피해 보탬 → 쓰러지면 상자 · 보스 재료', () async {
      final (c, a) = await start(steps: 9000);
      await c.createParty('새벽');
      expect(c.party!.boss!.tickets, 3);
      a.bossHp = 100;
      final b = c.startPartyBoss()!;
      expect(b.tickLimit, PartyRules.fightTicks);
      win(b);
      expect(b.isOver, isTrue);
      final r = await c.finishPartyBoss(b);
      expect(r.error, isNull);
      expect(r.damage, greaterThan(0));
      expect(r.damage, lessThanOrEqualTo((PartyRules.fightHp(21) * 1.2).round()));
      expect(a.dmg['u_me'], r.damage);
      expect(c.party!.boss!.tickets, 2);
      expect(c.party!.boss!.defeated, isTrue);
      expect(r.defeatedNow, isTrue);
      final core0 = c.player.materialCount(MaterialId.golemCore);
      final got = (await c.claimParty('boss'))!;
      expect(got.first, '금빛 상자를 열었어요');
      expect(c.player.materialCount(MaterialId.golemCore), core0 + 4);
      expect(c.partyLocal.tickets, 40);
      // 보스 재료가 생기면 대장간에 「동행」 세트가 보임
      expect(c.bossSetOpen(BossSet.party), isTrue);
    });

    test('정해진 턴이 지나면 거기까지 (쓰러뜨리지 못해도)', () async {
      final (c, _) = await start(steps: 3000);
      await c.createParty('');
      final b = c.startPartyBoss()!;
      for (var i = 0; i < 400 && !b.isOver; i++) {
        b.playerHp = 99999;
        b.foeHp = b.foe.maxHp; // 피해가 남지 않게
        b.tick();
      }
      expect(b.timeUp, isTrue);
      expect(b.ticks, PartyRules.fightTicks + 1);
    });

    test('파티 상점 · 깃발 문양 · 색 (발자국 표, 모집권은 주 2장)', () async {
      final (c, _) = await start(steps: 40000);
      await c.store.saveJson('party', {'tickets': 200});
      final (c2, a2) = await start(store: c.store as InMemoryRecordStore);
      expect(c2.partyLocal.tickets, 200);
      final recruit = PartyRules.shop.firstWhere((i) => i.id == 'recruit');
      final t0 = c2.recruitTickets;
      expect(await c2.buyPartyItem(recruit), isNull);
      expect(await c2.buyPartyItem(recruit), isNull);
      expect(await c2.buyPartyItem(recruit), contains('이번 주'));
      expect(c2.recruitTickets, t0 + 2);
      expect(c2.hasEmblem(7), isFalse);
      expect(await c2.buyEmblem(7), isNull);
      expect(c2.hasEmblem(7), isTrue);
      expect(await c2.buyColor(4), isNull);
      expect(c2.partyLocal.tickets, 200 - 80 - PartyRules.emblemPrice - PartyRules.colorPrice);
      await c2.createParty('별빛');
      expect(await c2.styleParty(emblem: 7, color: 4), isTrue);
      expect(c2.party!.emblem, 7);
      expect(a2.calls, contains('/party/style'));
    });

    test('함께 있어요: 몇 분에 한 번 칸만 보냄 → 사냥 경험치 · 재료 조금 더 + 함께 잡은 몬스터', () async {
      final arca = FakeArca()..near = true;
      final (c, a) = await start(arca: arca);
      await c.createParty('');
      await c.handleFix(const LocationFix(point: GeoPoint(37.3, 126.83)));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(c.partyNear, isTrue);
      expect(a.calls.where((x) => x == '/party/near'), hasLength(1));
      // 3분 안에는 다시 안 보냄
      await c.handleFix(const LocationFix(point: GeoPoint(37.3001, 126.83)));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(a.calls.where((x) => x == '/party/near'), hasLength(1));
      expect(c.takePartyNotice(), PartyRules.nearOn);
      now = now.add(PartyRules.nearFor + const Duration(minutes: 1));
      expect(c.partyNear, isFalse);
    });

    test('오류 글: 가득 찬 파티 · 같은 휴대폰 · 인터넷', () async {
      final arca = FakeArca()..offline = true;
      final (c, _) = await start(arca: arca);
      await c.refreshParty();
      expect(c.partyError, 'offline');
      expect(PartyRules.errorText('offline'), PartyRules.offlineLine);
      expect(PartyRules.errorText('full'), contains('4명'));
    });
  });

  group('문의', () {
    test('로그인 없이 보냄 (설치 번호 · 앱 버전 · 기종, 위치 없음) · 하루 3건 · 답은 우편으로', () async {
      final (c, a) = await start(login: false);
      final r = await c.sendInquiry(
          kind: 'bug', text: '지도가 안 보여요', photo: [1, 2, 3], email: 'me@example.com', model: 'iPhone15,2');
      expect(r, InquirySend.ok);
      final q = a.inquiries.single;
      expect(q['install'], hasLength(32));
      expect(q['token'], isNull);
      expect(q['photo'], 'AQID');
      expect(q['model'], 'iPhone15,2');
      expect(q.keys.any((k) => k.contains('lat') || k.contains('lng')), isFalse);
      expect(await c.sendInquiry(kind: 'etc', text: '둘'), InquirySend.ok);
      expect(await c.sendInquiry(kind: 'etc', text: '셋'), InquirySend.ok);
      expect(await c.sendInquiry(kind: 'etc', text: '넷'), InquirySend.tooMany);
      expect(a.inquiries, hasLength(3));
      expect(await c.accountCode(), startsWith('I-'));
      // 답 우편
      a.inbox.add({
        'id': 'r1',
        'title': '문의에 답이 왔어요',
        'body': '고쳤어요!',
        'reward': {'gold': 300, 'footTicket': 5},
      });
      expect(await c.checkInquiryInbox(), 1);
      final m = c.allMails.firstWhere((x) => x.id == 'inq_r1');
      expect(m.title, '문의에 답이 왔어요');
      expect(m.gifts, {'gold': 300, 'footTicket': 5});
      await c.claimMail(m.id);
      expect(c.partyLocal.tickets, 5);
      expect(await c.checkInquiryInbox(), 0);
    });

    test('로그인했으면 토큰을 함께 (계정으로 답)', () async {
      final (c, a) = await start();
      await c.sendInquiry(kind: 'record', text: '기록이 이상해요');
      expect(a.inquiries.single['token'], isNotNull);
      expect(await c.accountCode(), 'U1');
    });
  });

  group('화면', () {
    testWidgets('주점 파티 탭: 로그인 안내 → (로그인) 만들기 → 파티 화면', (tester) async {
      tester.view.physicalSize = const Size(750, 1334);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      late AppController c;
      await tester.runAsync(() async => c = (await start(login: false)).$1);
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => TopNoticeHost(child: child!),
          home: TavernScreen(controller: c, partyTab: true)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('tavernTab_party')), findsOneWidget);
      expect(find.byKey(const Key('partyLogin')), findsOneWidget);
      await tester.runAsync(() async {
        await c.signInCloud(LoginProvider.google);
        await c.refreshParty();
      });
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('partyStart')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('partyNameField')), '새벽 원정대');
      await tester.tap(find.byKey(const Key('partyCreate')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('partyHeader')), findsOneWidget);
      expect(find.text('ABC234'), findsOneWidget);
      expect(find.byKey(const Key('partyWalk')), findsOneWidget);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('partyBoss')), findsOneWidget);
      expect(find.byKey(const Key('partyTogether')), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('설정 → 문의: 종류 · 내용 · 사진 · 보내기', (tester) async {
      tester.view.physicalSize = const Size(750, 1334);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      late AppController c;
      late FakeArca a;
      await tester.runAsync(() async {
        final r = await start(login: false);
        c = r.$1;
        a = r.$2;
      });
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => TopNoticeHost(child: child!),
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: TextButton(
                    onPressed: () => Navigator.of(ctx).push(MaterialPageRoute<void>(
                        builder: (_) => InquiryScreen(
                            controller: c,
                            model: 'iPhone15,2',
                            picker: () async => Uint8List.fromList([9, 9, 9])))),
                    child: const Text('열기')),
              ),
            ),
          )));
      await tester.tap(find.text('열기'));
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(find.byKey(const Key('inquiryScreen')), findsOneWidget);
      await tester.tap(find.byKey(const Key('inquiryKind_bug')));
      await tester.enterText(find.byKey(const Key('inquiryText')), '원정이 안 돌아와요');
      await tester.tap(find.byKey(const Key('inquiryPick')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('inquiryPhoto')), findsOneWidget);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('inquiryAuto')), findsOneWidget);
      expect(find.text('iPhone15,2'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('inquirySend')));
      await tester.tap(find.byKey(const Key('inquirySend')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();
      expect(a.inquiries.single['kind'], 'bug');
      expect(a.inquiries.single['photo'], 'CQkJ');
      expect(find.byKey(const Key('inquiryScreen')), findsNothing);
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
