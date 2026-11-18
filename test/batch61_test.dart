// 묶음 61: 길드 금고 쓰기 · 수비대 그림 · 부정 이용 막기(#250: 거래 지갑 · 함께하는 걸음 · 가짜 위치 · 공성권 서버) — 앱 흐름
// (서버 판정은 firebase/functions 의 node 시험 fair.test.js)

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/geo/geo.dart';
import 'package:isekai_reality/core/models/act5_state.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/cloud/arca_api.dart';
import 'package:isekai_reality/data/cloud/backup_server.dart';
import 'package:isekai_reality/data/cloud/cloud_auth.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/village/market_screen.dart';

import 'batch52_test.dart' as b52;
import 'batch56_test.dart' as b56;
import 'batch60_test.dart' as b60;
import 'support/fake_arca.dart';

/// 손으로 입력한 걸음이 있는 계정
Future<(AppController, FakeArca)> start({
  int steps = 12000,
  int manual = 0,
  FakeArca? arca,
  InMemoryRecordStore? store,
  bool login = true,
}) async {
  final s = store ?? b52.account();
  final a = arca ?? FakeArca();
  final c = AppController(
    store: s,
    health: FakeHealthSource(stepsByDay: {b52.todayKey: steps}, manualByDay: {b52.todayKey: manual}),
    clock: () => b56.now,
    random: math.Random(5),
  )
    ..mailSources = const []
    ..cloudAuth = FakeCloudAuth()
    ..backupServer = (FakeBackupServer()..time = b56.now.toUtc())
    ..arcaApi = a;
  await c.init();
  await c.markPartyNotice();
  if (login) await c.signInCloud(LoginProvider.google);
  return (c, a);
}

Future<AppController> withGold(AppController c, FakeArca a, int gold) async {
  final t = c.history.last;
  await c.store.upsert(t.copyWith(gains: DailyRecord.addCounts(t.gains, {Wallet.gold: gold})));
  return (await b56.start(store: c.store as InMemoryRecordStore, arca: a)).$1;
}

void main() {
  setUp(() => b56.now = b52.t0);

  group('0 묶음 60 확인 답', () {
    test('대륙 지도는 3072 그대로 (끌어서 · 확대해도 흐리지 않게)', () {
      final py = File('tool/optimize_images.py').readAsStringSync();
      expect(py, contains("('map_erbard', 3072)"));
      final b = File('assets/images/map_erbard.webp').readAsBytesSync();
      // VP8/VP8L/VP8X 머리말에서 크기 대신 파일 크기로 (1536이면 0.5MB 안팎)
      expect(b.length, greaterThan(900000));
      expect(ErbardRules.mapW, 3072);
    });

    test('공성전 기록은 끝난 날부터 8주 · 서버 표 = 앱 표', () {
      final js = File('firebase/functions/src/siege.js').readAsStringSync();
      expect(js, contains('const KEEP_RUN = 56 * DAY'));
      expect(File('firebase/functions/src/siege_estates.json').readAsStringSync(), ErbardRules.estatesJson());
    });
  });

  group('1 길드 금고', () {
    test('수비대 강화 · 회관 공사 · 금고 상점 · 나눠 주기 → 게시판 기록 · 금빛 깃발', () async {
      final (c, a) = await b60.act5(
          guild: true, state: const Act5State(opened: true, chapter: 3, seen: {'e1a', 'e1b', 'e1c', 'e2a', 'e2b'}, ticketAt: 0));
      a.siegeOwners['sol_lily'] = {'gid': 'mine', 'name': '새벽걸음', 'emblem': 0, 'color': 0};
      a.treasury = 30000;
      await c.refreshErbard();
      await c.refreshGuild();
      expect(c.guild!.treasury, 30000);
      expect(await c.boostGarrison('sol_lily', 1), isTrue);
      expect(c.erbard.boosts['sol_lily'], 1);
      expect(await c.boostGarrison('sol_lily', 2), isTrue);
      expect(c.guild!.treasury, 30000 - ErbardRules.boostCost[1]);
      expect(await c.treasuryHall(GuildRules.treasuryHallStep), isTrue);
      expect(await c.treasuryShop('goldFlag'), isTrue);
      expect(c.guild!.goldFlag, isTrue);
      expect(await c.treasuryShop('goldLights'), isTrue);
      expect(c.guild!.decos, contains('goldLights'));
      expect(GuildRules.decoImage('goldLights'), GuildRules.decoImage('lights'), reason: '있는 그림을 금빛으로');
      expect(GuildRules.goldDeco('goldLights'), isTrue);
      // 나눠 주기: 공성전이 끝난 뒤 한 번
      expect(await c.treasuryShare(3000), isFalse);
      expect(GuildRules.errorText(c.guildError!), contains('이미 나눠'));
      a.canShare = true;
      await c.refreshErbard();
      expect(c.erbard.canShare, isTrue);
      expect(await c.treasuryShare(3000), isTrue);
      final log = c.guild!.treasuryLog;
      expect(log.first.what, contains('나눠 주기'));
      expect(log.map((l) => l.gold), [3000, 4000, 5000, 1000, 4000, 3000]);
      expect(log.every((l) => l.name.isNotEmpty), isTrue);
      // 모자라면
      a.treasury = 10;
      await c.refreshGuild();
      expect(await c.treasuryShop('goldFountain'), isFalse);
      expect(GuildRules.errorText(c.guildError!), '길드 금고 금화가 모자라요');
    });
  });

  group('2 수비대 그림', () {
    test('분신은 주 직업 그림 6장 (히든 · 생산은 가까운 전투 직업) · 흑등 1~4 용병 · 5와 왕성 지휘관', () {
      expect(ErbardRules.cloneOf('warrior'), MonsterId.cloneWarrior);
      expect(ErbardRules.cloneOf('knight'), MonsterId.cloneKnight);
      expect(ErbardRules.cloneOf('gateHeir'), MonsterId.cloneKnight);
      expect(ErbardRules.cloneOf('ashHunter'), MonsterId.cloneArcher);
      expect(ErbardRules.cloneOf('alchemist'), MonsterId.cloneMage);
      expect(ErbardRules.cloneOf('herbalist'), MonsterId.cloneArcher);
      expect(ErbardRules.cloneOf('nightWalker'), MonsterId.cloneRogue);
      expect(ErbardRules.cloneOf('blacksmith'), MonsterId.cloneWarrior);
      expect(ErbardRules.cloneOf(null), MonsterId.cloneWarrior);
      for (final j in JobId.values) {
        final m = ErbardRules.cloneOf(j.name);
        expect(File(Monsters.info(m).asset).existsSync(), isTrue, reason: j.name);
      }
      final lily = ErbardRules.estate('sol_lily')!;
      expect(ErbardRules.blackOf(lily, 0), MonsterId.blackGuard);
      expect(ErbardRules.blackOf(lily, 4), MonsterId.blackCaptain);
      expect(ErbardRules.blackOf(ErbardRules.estate('royal')!, 0), MonsterId.blackCaptain);
      expect(Monsters.info(MonsterId.blackGuard).asset, 'assets/images/monster_blackGuard.webp');
      expect(File(Monsters.info(MonsterId.blackGuard).asset).existsSync(), isTrue);
      expect(File(Monsters.info(MonsterId.blackCaptain).asset).existsSync(), isTrue);
      expect(Monsters.info(MonsterId.blackGuard).tint, isNull, reason: '새 그림이 와서 물들이지 않음');
    });

    test('공성: 다른 길드 수비대는 그 사람 직업 그림 · 흑등 5자리는 지휘관', () async {
      final (c, a) = await b60.act5(
          guild: true, state: const Act5State(opened: true, chapter: 3, seen: {'e1a', 'e1b', 'e1c', 'e2a', 'e2b'}, ticketAt: -60000));
      a.siegeActive = true;
      a.siegeOwners['dor_wind'] = {'gid': 'other', 'name': '노을', 'emblem': 1, 'color': 2};
      b56.now = DateTime(2026, 11, 28, 10);
      await c.refreshErbard();
      final b = (await c.startErbardFight(ErbardRules.estate('dor_wind')!))!;
      expect(b.floors.map((f) => f.monster), [MonsterId.cloneMage, MonsterId.cloneKnight]);
      b60.win(b);
      await c.finishErbardFight(b);
      a.siegeRun['sol_silver'] = [0, 1, 2, 3];
      final b2 = (await c.startErbardFight(ErbardRules.estate('sol_silver')!))!;
      expect(b2.foe.monster, MonsterId.blackCaptain);
      expect(b2.foe.name, '흑등 연맹 지휘관');
    });
  });

  group('3 부정 이용 막기 (#250)', () {
    test('손으로 입력한 걸음: 혼자 하는 걸음엔 그대로 · 함께하는 기능(파티 · 길드 · 공성)엔 뺌 · 최대 시간당 걸음도 보냄', () async {
      final (c, a) = await start(steps: 12000, manual: 3000);
      expect(c.player.today!.steps, 12000, reason: '혼자 하는 플레이는 그대로');
      expect(c.player.today!.counters[AppController.manualStepsKey], 3000);
      expect(c.socialTodaySteps, 9000);
      expect(await c.createParty(''), isTrue);
      final me = a.meSent.last;
      expect(me['steps'], 9000);
      expect(me['manual'], 3000);
      expect(me['maxHour'], isA<int>());
      expect(me.containsKey('mock'), isFalse);
      // 손 입력이 없으면 기록에 남기지 않음
      final (c2, _) = await start();
      expect(c2.player.today!.counters.containsKey(AppController.manualStepsKey), isFalse);
      expect(c2.socialTodaySteps, 12000);
    });

    test('가짜 위치: 「함께 있어요」 칸을 보내지 않고 표시만 · 띠는 한 번 · 혼자 탐험은 그대로', () async {
      final (c, a) = await start();
      await c.createParty('');
      expect(c.takeMockBanner(), isFalse);
      await c.handleFix(const LocationFix(point: GeoPoint(37.3, 126.83), mocked: true));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(a.nearSent.last, {'mock': true});
      expect(c.mockLocation, isTrue);
      expect(c.takeMockBanner(), isTrue);
      expect(c.takeMockBanner(), isFalse);
      expect(FairOps.mockLine, '가짜 위치가 켜져 있어 친구와 함께하는 기능에는 반영되지 않아요');
      await c.handleFix(const LocationFix(point: GeoPoint(37.3002, 126.83), mocked: true));
      expect(c.takeMockBanner(), isFalse, reason: '띠는 한 번만');
      // 함께하는 기능 요청에 표시
      await c.refreshParty();
      expect(a.meSent.last['mock'], isTrue);
      // 10분 지나 진짜 위치면 다시 칸을 보냄
      b56.now = b56.now.add(const Duration(minutes: 11));
      await c.handleFix(const LocationFix(point: GeoPoint(37.3, 126.83)));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(a.nearSent.last.keys.toSet(), {'r', 'c'});
      expect(c.mockLocation, isFalse);
    });

    test('공성권: 서버가 센 장수로 맞춤 · 처음엔 앱 장수 · 진행 걸음을 보냄', () async {
      final (c, a) = await b60.act5(
          guild: true, state: const Act5State(opened: true, chapter: 2, seen: {'e1a', 'e1b', 'e1c'}, ticketAt: -4500));
      final me = a.meSent.last;
      expect(me['tickets'], c.siegeTickets);
      expect(me['carry'], isA<int>());
      expect(me['device'], isNotNull);
      a.siegeTickets = 3;
      await c.refreshErbard();
      expect(c.siegeTickets, 3);
      expect((c.siegeTicketProgress * ErbardRules.ticketSteps).round(), 500);
      final b = (await c.startErbardFight(ErbardRules.estate('sol_lily')!))!;
      b60.win(b);
      await c.finishErbardFight(b);
      expect(a.siegeTickets, 2);
      expect(c.siegeTickets, 2);
      expect(ErbardRules.errorText('no_fight'), contains('다시 시작'));
    });

    test('거래 지갑: 맡기면 휴대폰 금화에서 빠짐 · 사기 · 올리기 · 입찰은 지갑으로 · 꺼내면 바르칸 우편', () async {
      final (c0, a) = await b56.start();
      final c = await withGold(c0, a, 2000);
      final g0 = c.player.gold;
      expect(await c.refreshWallet(), 0);
      expect(await c.depositWallet(g0 + 1), isFalse);
      expect(c.marketError, 'no_gold');
      expect(await c.depositWallet(800), isTrue);
      expect(c.player.gold, g0 - 800);
      expect(c.marketWallet, 800);
      expect(a.marketBodies.last, {'amount': 800});
      // 지갑보다 비싸면 서버에 묻지도 않음
      a.listings.add({'id': 'x1', 'kind': 'mat', 'key': 'herb', 'name': '약초', 'qty': 1, 'mode': 'fixed', 'price': 900, 'status': 'open'});
      final rows = await c.browseMarket();
      expect(await c.buyOnMarket(rows!.single), isFalse);
      expect(c.marketError, 'no_wallet_gold');
      expect(MarketOps.marketErrorText('no_wallet_gold'), contains('맡겨'));
      // 꺼내기
      expect(await c.withdrawWallet(300), isTrue);
      expect(c.marketWallet, 500);
      final m = c.mail.mails.firstWhere((x) => x.from == '바르칸');
      expect(m.title, contains('꺼냈어요'));
      await c.claimMail(m.id);
      expect(c.player.gold, g0 - 800 + 300);
      expect(await c.withdrawWallet(501), isFalse);
    });

    test('회관 기부 금화도 지갑에서 (휴대폰 금화 그대로)', () async {
      final (c, a) = await b60.act5(guild: true);
      final g0 = c.player.gold;
      a.wallet = 50;
      await c.refreshWallet();
      expect(await c.donateGuild(gold: GuildRules.donateGoldStep), isNull);
      expect(c.guildError, 'no_wallet_gold');
      a.wallet = 500;
      await c.refreshWallet();
      expect(await c.donateGuild(gold: GuildRules.donateGoldStep), isNotNull);
      expect(c.player.gold, g0);
      expect(a.wallet, 500 - GuildRules.donateGoldStep);
      expect(c.marketWallet, 500 - GuildRules.donateGoldStep);
    });

    test('진짜 앱 확인: 토큰을 머리말로 (못 받으면 그냥 보냄)', () async {
      expect(await AppCheckToken.get(), isNull);
      AppCheckToken.provider = () async => 'tok';
      expect(await AppCheckToken.get(), 'tok');
      AppCheckToken.provider = () async => throw Exception('x');
      expect(await AppCheckToken.get(), isNull);
      AppCheckToken.provider = null;
      final api = File('lib/data/cloud/arca_api.dart').readAsStringSync();
      expect(api, contains("'X-Firebase-AppCheck'"));
    });

    testWidgets('거래소 위 「지갑 ○ 금화 · 맡기기 · 꺼내기」 · 처음 바르칸 한마디', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      late AppController c;
      late FakeArca a;
      await tester.runAsync(() async {
        final r = await b56.start();
        c = await withGold(r.$1, r.$2, 1000);
        a = r.$2;
        a.wallet = 1200;
        await c.markMarketIntro();
      });
      await tester.pumpWidget(b60.host(MarketScreen(controller: c)));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('walletIntro')), findsOneWidget);
      await tester.tap(find.text('알겠어요'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('walletBar')), findsOneWidget);
      expect(find.text('금화 1,200'), findsOneWidget);
      await tester.tap(find.byKey(const Key('walletDeposit')));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      await tester.enterText(find.byKey(const Key('walletAmount')), '300');
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('walletOk')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('walletOk')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump(const Duration(milliseconds: 400));
      expect(c.marketWallet, 1500);
      expect(find.text('금화 1,500'), findsOneWidget);
    });
  });
}
