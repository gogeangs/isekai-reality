// 묶음 55: 서버 1단계 — 로그인 · 기록 백업 · 처음 로그인 기록 고르기 · 서버 날짜 · 계정 삭제 (#245)

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/act2_state.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/cloud/backup_server.dart';
import 'package:isekai_reality/data/cloud/cloud_auth.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/settings/account_section.dart';
import 'package:isekai_reality/theme/top_notice.dart';

final t0 = DateTime(2026, 11, 17, 10);

/// 기록이 있는 계정 (Lv.[level], 마지막으로 걸은 날 [last])
InMemoryRecordStore account({int level = 12, String name = '하루', DateTime? last}) =>
    InMemoryRecordStore(
      profile: PlayerProfile(
          name: name, spiritName: '불씨', spiritKind: SpiritKind.water, lastSeenLevel: 99),
      history: [
        DailyRecord(date: last ?? DateTime(2026, 11, 16), steps: 4000, gains: {
          Wallet.exp: LevelRules.totalExpToReach(level),
          Wallet.gold: 500,
        }),
      ],
      json: {
        'tutorial': {'step': TutorialStep.done.index},
        'gates': {
          'legacy': false,
          'v28': true,
          'seen': [for (final f in Feature.values) f.name],
        },
        'act2': const Act2State().toJson(),
      },
    );

class Rig {
  Rig(this.c, this.store, this.auth, this.server, this.clock);
  final AppController c;
  final InMemoryRecordStore store;
  final FakeCloudAuth auth;
  final FakeBackupServer server;
  final ServerClock clock;
}

/// [device] 휴대폰 시계, server.time 서버 시계
Future<Rig> start(InMemoryRecordStore s,
    {FakeBackupServer? server, FakeCloudAuth? auth, DateTime Function()? device}) async {
  final srv = server ?? (FakeBackupServer()..time = t0.toUtc());
  final a = auth ?? FakeCloudAuth();
  final clock = ServerClock(device: device ?? () => t0);
  final c = AppController(
    store: s,
    health: FakeHealthSource(),
    clock: clock.now,
  )
    ..mailSources = const []
    ..cloudAuth = a
    ..backupServer = srv
    ..serverClock = clock;
  await c.init();
  return Rig(c, s, a, srv, clock);
}

void main() {
  group('기록 묶기', () {
    test('휴대폰 기록 전체를 내보내고 그대로 되돌림 (이 휴대폰만의 값은 빼고)', () async {
      final a = account(level: 9);
      await a.saveRevealedCells('ansan', {'c1', 'c2'});
      await a.saveSide('cloud', '{"uid":"u1"}');
      final snap = await a.exportAll();
      expect(snap.keys, containsAll(['profile.v1', 'history.v1', 'vitals.v1', 'cells.ansan.v1']));
      expect(snap.keys.any((k) => k.contains('cloud')), isFalse);
      final b = InMemoryRecordStore();
      await b.saveSide('cloud', 'mine');
      await b.importAll(SnapshotCodec.decode(SnapshotCodec.encode(snap)));
      expect((await b.loadProfile())!.name, '하루');
      expect(await b.loadRevealedCells('ansan'), {'c1', 'c2'});
      expect((await b.loadHistory()).single.steps, 4000);
      expect(await b.loadSide('cloud'), 'mine');
    });

    test('큰 기록은 조각으로 나눔 (문서 하나 1MiB 아래)', () {
      final text = 'x' * (SnapshotCodec.chunk * 2 + 5);
      final parts = SnapshotCodec.split(text);
      expect(parts, hasLength(3));
      expect(parts.join(), text);
      expect(SnapshotCodec.split(''), ['']);
    });
  });

  group('처음 로그인 (#124 기록이 날아가면 안 됨)', () {
    test('서버에 기록이 없으면 휴대폰 기록을 그대로 올림', () async {
      final r = await start(account(level: 12));
      expect(r.c.cloudAvailable, isTrue);
      expect(await r.c.signInCloud(LoginProvider.google), CloudLogin.uploaded);
      expect(r.c.cloud.signedIn, isTrue);
      expect(r.server.metas['u1']!.current!.level, 12);
      expect(r.server.metas['u1']!.current!.lastDay, startsWith('2026-11-1'));
      expect(r.c.cloud.lastBackup, isNotNull);
      expect(r.c.profile.name, '하루');
    });

    test('휴대폰을 바꾼 사람: 새 휴대폰에서 로그인하면 서버 기록으로 이어서', () async {
      final server = FakeBackupServer()..time = t0.toUtc();
      final old = await start(account(level: 15, name: '옛폰'), server: server);
      await old.c.signInCloud(LoginProvider.apple);
      final fresh = InMemoryRecordStore();
      final r = await start(fresh, server: server);
      expect(r.c.needsAwakening, isTrue);
      expect(await r.c.signInCloud(LoginProvider.apple), CloudLogin.restored);
      expect(r.c.needsAwakening, isFalse);
      expect(r.c.profile.name, '옛폰');
      expect(r.c.player.level.level, 15);
      expect(r.c.cloud.signedIn, isTrue, reason: '이 휴대폰만의 로그인 값은 복원으로 안 지워짐');
    });

    test('둘 다 있으면 고르기 → 휴대폰 기록: 서버 것은 7일 보관', () async {
      final server = FakeBackupServer()..time = t0.toUtc();
      final other = await start(account(level: 20, name: '서버'), server: server);
      await other.c.signInCloud(LoginProvider.google);
      final r = await start(account(level: 8, name: '폰'), server: server);
      expect(await r.c.signInCloud(LoginProvider.google), CloudLogin.choose);
      expect(r.c.cloud.choosing, isTrue);
      expect(r.c.phoneSummary.level, 8);
      expect((await r.c.serverSummary())!.level, 20);
      expect(await r.c.backupNow(), CloudBackup.notReady, reason: '고르기 전엔 백업 안 함');
      expect(await r.c.chooseRecord(useServer: false), isTrue);
      final m = server.metas['u1']!;
      expect(m.current!.level, 8);
      expect(m.kept!.level, 20);
      expect(m.kept!.from, 'server');
      expect(r.c.cloud.choosing, isFalse);
      expect(r.c.profile.name, '폰');
    });

    test('둘 다 있으면 고르기 → 서버 기록: 휴대폰 것은 7일 보관하고 서버 기록으로', () async {
      final server = FakeBackupServer()..time = t0.toUtc();
      final other = await start(account(level: 20, name: '서버'), server: server);
      await other.c.signInCloud(LoginProvider.google);
      final r = await start(account(level: 8, name: '폰'), server: server);
      await r.c.signInCloud(LoginProvider.google);
      expect(await r.c.chooseRecord(useServer: true), isTrue);
      expect(server.metas['u1']!.kept!.level, 8);
      expect(server.metas['u1']!.kept!.from, 'phone');
      expect(r.c.profile.name, '서버');
      expect(r.c.player.level.level, 20);
      expect((await r.store.loadProfile())!.name, '서버');
    });

    test('로그인을 그만두거나 인터넷이 없으면 휴대폰 기록 그대로', () async {
      final r = await start(account(), auth: FakeCloudAuth(result: LoginStatus.cancelled));
      expect(await r.c.signInCloud(LoginProvider.google), CloudLogin.cancelled);
      expect(r.c.cloud.signedIn, isFalse);
      final off = await start(account(), server: FakeBackupServer()..offline = true);
      expect(await off.c.signInCloud(LoginProvider.google), CloudLogin.offline);
      expect(off.c.cloud.signedIn, isFalse);
      expect(off.c.profile.name, '하루');
    });
  });

  group('백업', () {
    test('지금 백업 · 조용한 백업은 바뀐 것만 · 인터넷이 없으면 다음에', () async {
      final r = await start(account());
      await r.c.signInCloud(LoginProvider.google);
      expect(r.server.uploads, 1);
      await r.c.autoBackup();
      expect(r.server.uploads, 1, reason: '바뀐 게 없으면 안 올림');
      await r.c.updateProfile(r.c.profile.copyWith(name: '바뀜'));
      r.server.offline = true;
      await r.c.autoBackup();
      expect(r.server.uploads, 1);
      expect(await r.c.backupNow(), CloudBackup.offline);
      r.server.offline = false;
      await r.c.autoBackup();
      expect(r.server.uploads, 2);
      expect(await r.c.backupNow(), CloudBackup.ok);
    });

    test('로그인 상태는 앱을 다시 켜도 그대로 · 로그아웃해도 휴대폰 기록은 그대로', () async {
      final s = account();
      final r = await start(s);
      await r.c.signInCloud(LoginProvider.google);
      final again = await start(s, server: r.server, auth: r.auth);
      expect(again.c.cloud.signedIn, isTrue);
      expect(again.c.cloud.lastBackup, isNotNull);
      await again.c.signOutCloud();
      expect(again.c.cloud.signedIn, isFalse);
      expect(again.c.profile.name, '하루');
      expect(await s.loadSide('cloud'), isNull);
    });

    test('보관본은 7일이 지나면 다음 백업 때 지움', () async {
      final server = FakeBackupServer()..time = t0.toUtc();
      final other = await start(account(level: 20), server: server);
      await other.c.signInCloud(LoginProvider.google);
      var now = t0;
      final r = await start(account(level: 8), server: server, device: () => now);
      await r.c.signInCloud(LoginProvider.google);
      await r.c.chooseRecord(useServer: false);
      expect(server.metas['u1']!.kept, isNotNull);
      now = t0.add(const Duration(days: 8));
      server.time = now.toUtc();
      await r.c.backupNow();
      expect(server.metas['u1']!.kept, isNull);
    });
  });

  group('서버 날짜', () {
    test('휴대폰 날짜를 앞당겨도 서버 날짜로 셈 → 무료 감정을 다시 받지 못함', () async {
      var device = t0;
      final r = await start(account(), device: () => device);
      await r.c.refreshServerTime();
      for (var i = 0; i < LensRules.freePerDay; i++) {
        await r.c.appraise([Race.elf]);
      }
      expect(r.c.lensFreeLeft, 0);
      // 휴대폰 날짜만 하루 뒤로
      device = t0.add(const Duration(days: 1));
      await r.c.refreshServerTime();
      expect(DailyRecord.dayKeyOf(r.c.now), '2026-11-17');
      expect(r.c.lensFreeLeft, 0);
      // 인터넷이 끊겨도 마지막으로 받은 차이를 씀
      r.server.offline = true;
      await r.c.refreshServerTime();
      expect(r.c.lensFreeLeft, 0);
      // 서버도 하루가 지나면 다시
      r.server
        ..offline = false
        ..time = t0.add(const Duration(days: 1)).toUtc();
      await r.c.refreshServerTime();
      expect(r.c.lensFreeLeft, LensRules.freePerDay);
    });

    test('서버 시간 차이는 다음에 켤 때도 씀 (인터넷 없이 시작)', () async {
      var device = t0.add(const Duration(days: 3));
      final s = account();
      final r = await start(s, device: () => device);
      await r.c.refreshServerTime();
      expect(DailyRecord.dayKeyOf(r.c.now), '2026-11-17');
      final again = await start(s,
          server: FakeBackupServer()..offline = true, device: () => device);
      expect(DailyRecord.dayKeyOf(again.c.now), '2026-11-17');
    });
  });

  group('계정 삭제', () {
    test('요청 → 7일 뒤 지움 표시 · 로그아웃 · 휴대폰 기록 남기기', () async {
      final r = await start(account());
      await r.c.signInCloud(LoginProvider.apple);
      expect(await r.c.requestAccountDeletion(keepPhone: true), isTrue);
      final m = r.server.metas['u1']!;
      expect(m.deleteAt, t0.toUtc().add(const Duration(days: 7)));
      expect(r.c.cloud.signedIn, isFalse);
      expect(r.auth.revoked, 1);
      expect(r.c.profile.name, '하루');
    });

    test('7일 안에 다시 로그인하면 취소 · 휴대폰 기록도 지우기를 고르면 처음부터', () async {
      final r = await start(account());
      await r.c.signInCloud(LoginProvider.google);
      await r.c.requestAccountDeletion(keepPhone: false);
      expect(r.c.needsAwakening, isTrue);
      expect(await r.c.signInCloud(LoginProvider.google), CloudLogin.restored);
      expect(r.server.metas['u1']!.deleteAt, isNull);
      expect(r.c.cloud.cancelledDelete, isTrue);
      expect(r.c.profile.name, '하루');
    });

    test('7일이 지나 로그인하면 서버 기록은 없는 것으로 (새로 올림)', () async {
      var now = t0;
      final server = FakeBackupServer()..time = t0.toUtc();
      final r = await start(account(level: 12), server: server, device: () => now);
      await r.c.signInCloud(LoginProvider.google);
      await r.c.requestAccountDeletion(keepPhone: true);
      now = t0.add(const Duration(days: 8));
      server.time = now.toUtc();
      await r.c.refreshServerTime();
      expect(await r.c.signInCloud(LoginProvider.google), CloudLogin.uploaded);
      expect(server.metas['u1']!.deleteAt, isNull);
      expect(server.metas['u1']!.kept, isNull);
    });
  });

  group('화면', () {
    testWidgets('설정 「계정」: 로그인 전 버튼 → 로그인 뒤 마지막 백업 · 지금 백업', (tester) async {
      tester.view.physicalSize = const Size(750, 1334);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      late Rig r;
      await tester.runAsync(() async => r = await start(account()));
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => TopNoticeHost(child: child!),
          home: Scaffold(body: ListView(children: [AccountSection(controller: r.c)]))));
      await tester.pump();
      expect(find.byKey(const Key('login_apple')), findsOneWidget);
      expect(find.byKey(const Key('login_google')), findsOneWidget);
      await tester.tap(find.byKey(const Key('login_google')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('accountWho')), findsOneWidget);
      expect(find.byKey(const Key('accountLast')), findsOneWidget);
      expect(find.byKey(const Key('accountBackup')), findsOneWidget);
      expect(find.byKey(const Key('accountDelete')), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('두 기록 고르기 화면: 레벨 · 마지막 날짜 둘', (tester) async {
      tester.view.physicalSize = const Size(750, 1334);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      late Rig r;
      await tester.runAsync(() async {
        final server = FakeBackupServer()..time = t0.toUtc();
        final other = await start(account(level: 20), server: server);
        await other.c.signInCloud(LoginProvider.google);
        r = await start(account(level: 8), server: server);
        await r.c.signInCloud(LoginProvider.google);
      });
      await tester.pumpWidget(MaterialApp(home: RecordChoiceScreen(controller: r.c)));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('choicePhone')), findsOneWidget);
      expect(find.byKey(const Key('choiceServer')), findsOneWidget);
      expect(find.text('Lv.8'), findsOneWidget);
      expect(find.text('Lv.20'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    test('마지막 백업 문구', () {
      final now = DateTime(2026, 11, 17, 12);
      expect(backupAgo(null, now), '아직 없어요');
      expect(backupAgo(now.subtract(const Duration(seconds: 20)), now), '방금 전');
      expect(backupAgo(now.subtract(const Duration(minutes: 7)), now), '7분 전');
      expect(backupAgo(now.subtract(const Duration(hours: 3)), now), '3시간 전');
      expect(backupAgo(now.subtract(const Duration(days: 2)), now), '2일 전');
    });
  });
}
