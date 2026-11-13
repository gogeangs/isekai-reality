import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/geo/geo.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/models/drive_state.dart';
import 'package:isekai_reality/core/models/mail_state.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/location/location_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/map/korea_area.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DateTime now;
  late InMemoryRecordStore store;
  AppController make({List<DailyRecord>? history}) {
    store = InMemoryRecordStore(
      profile: const PlayerProfile(name: '하루'),
      history: history ??
          [DailyRecord(date: DateTime(2026, 11, 10), gains: {Wallet.gold: 1000})],
    );
    return AppController(
      area: KoreaArea.area,
      store: store,
      health: FakeHealthSource(stepsByDay: {'2026-11-11': 3000}),
      location: FakeLocationSource(),
      clock: () => now,
      random: Random(3),
    )..mailSources = const [];
  }

  setUp(() => now = DateTime(2026, 11, 11, 14));

  group('채집 (11-11 #56)', () {
    test('자리마다 3번, 2시간마다 하나씩 다시 찬다', () {
      final t0 = DateTime(2026, 11, 11, 10);
      var c = SpotCharge(charges: 3, at: t0);
      c = c.use(t0).use(t0).use(t0);
      expect(c.current(t0), 0);
      expect(c.current(t0.add(const Duration(hours: 2))), 1);
      expect(c.current(t0.add(const Duration(hours: 6))), 3);
      final later = c.use(t0.add(const Duration(hours: 3)));
      // 2시간에 하나 찼고 하나 썼다. 다음은 1시간 뒤
      expect(later.current(t0.add(const Duration(hours: 3))), 0);
      expect(later.current(t0.add(const Duration(hours: 4))), 1);
    });

    test('채집 자리는 누구에게나 같고, 4종이 섞여 있다', () {
      const center = GeoPoint(37.3219, 126.8309);
      final a = HarvestRules.spotsAround(center);
      final b = HarvestRules.spotsAround(center);
      expect(a.map((s) => s.id), b.map((s) => s.id));
      expect(a.length, greaterThan(80));
      expect({for (final s in a) s.kind}, HarvestKind.values.toSet());
    });

    test('기본 재료는 늘, 미니게임을 잘하면 더 많이', () {
      final rng = Random(1);
      var quick = 0, perfect = 0;
      for (var i = 0; i < 300; i++) {
        quick += HarvestRules.yieldOf(HarvestKind.herb, HarvestGrade.quick, rng)[MaterialId.herb]!;
        perfect += HarvestRules.yieldOf(HarvestKind.herb, HarvestGrade.perfect, rng)[MaterialId.herb]!;
      }
      expect(perfect, greaterThan(quick + 500));
    });

    test('빠른 채집·미니게임·도구 내구도', () async {
      final c = make();
      await c.init();
      await c.makeFirstTools(); // 묶음 22: 도구가 있어야 채집
      final spot = c.harvestSpots.first;
      expect(c.canHarvest(spot), HarvestCheck.far);
      await c.handleFix(LocationFix(point: spot.point));
      final base = spot.info.base;
      final before = c.player.materialCount(base);
      expect(await c.harvestAt(spot, HarvestGrade.quick), isNotNull);
      expect(c.player.materialCount(base), greaterThan(before));
      expect(c.harvest.granted, isTrue);
      expect(c.toolDurability(spot.info.tool), HarvestRules.toolMax); // 빠른 채집은 안 닳음
      // 걷는 중이면 미니게임 불가
      await c.handleFix(LocationFix(point: spot.point, speedMps: 1.2));
      expect(c.canHarvest(spot, minigame: true), HarvestCheck.moving);
      now = now.add(const Duration(seconds: 11));
      await c.handleFix(LocationFix(point: spot.point));
      expect(c.canHarvest(spot, minigame: true), HarvestCheck.ok);
      await c.harvestAt(spot, HarvestGrade.perfect);
      expect(c.toolDurability(spot.info.tool), HarvestRules.toolMax - 1);
      expect(c.harvestCharges(spot), 1);
      await c.harvestAt(spot, HarvestGrade.quick);
      expect(c.canHarvest(spot), HarvestCheck.empty);
    });
  });

  group('승객 확인 (11-11 #61)', () {
    test('시속 20km 10초면 묻고, 승객이면 보상 제한, 멈추면 끝', () async {
      final c = make();
      await c.init();
      await c.makeFirstTools(); // 묶음 22: 도구가 있어야 채집
      const p = GeoPoint(37.3219, 126.8309);
      await c.handleFix(const LocationFix(point: p, speedMps: 8));
      now = now.add(const Duration(seconds: 11));
      await c.handleFix(const LocationFix(point: p, speedMps: 8));
      expect(c.driveMode, DriveMode.asking);
      expect(c.driveBlocked, isTrue);
      await c.answerDrive(passenger: true);
      expect(c.passengerMode, isTrue);
      expect(c.driveBlocked, isFalse);
      final spot = c.harvestSpots.first;
      await c.handleFix(LocationFix(point: spot.point, speedMps: 0));
      expect(c.canHarvest(spot, minigame: true), HarvestCheck.passenger);
      expect(c.canHarvest(spot), HarvestCheck.ok);
      now = now.add(const Duration(minutes: 3));
      await c.handleFix(LocationFix(point: spot.point, speedMps: 0));
      expect(c.driveMode, DriveMode.none);
      // 다시 달리면 다시 묻는다
      await c.handleFix(const LocationFix(point: p, speedMps: 9));
      now = now.add(const Duration(seconds: 12));
      await c.handleFix(const LocationFix(point: p, speedMps: 9));
      expect(c.driveMode, DriveMode.asking);
      // 답이 없으면 안전 운전
      now = now.add(const Duration(seconds: 20));
      await c.handleFix(const LocationFix(point: p, speedMps: 9));
      expect(c.driveMode, DriveMode.driving);
    });
  });

  group('우편 (11-11 #65)', () {
    test('의뢰 10건 감사 편지, 선물 받기, 편지 탭에 남음', () async {
      final c = make(history: [
        DailyRecord(date: DateTime(2026, 11, 10), counters: {'errandDone': 10}),
      ]);
      await c.init();
      await c.refreshVitals();
      expect(c.hasNewMail, isTrue);
      final m = c.giftMails.firstWhere((x) => x.id == 'npc_errand10');
      expect(m.from, MailRules.hart);
      final got = await c.claimMail(m.id);
      expect(got, contains('작은 회복 물약'));
      expect(c.bagCount(ShopItem.healSmall), 2);
      expect(c.giftMails.where((x) => x.id == m.id), isEmpty);
      expect(c.letterMails.any((x) => x.id == m.id && x.claimed), isTrue);
      // 다시 보내지 않는다
      await c.refreshVitals();
      expect(c.mail.mails.where((x) => x.id == m.id).length, 1);
    });

    test('보상 우편은 30일 뒤 사라지고, 가방이 가득하면 금화로', () async {
      final c = make();
      await c.init();
      await store.saveJson('mail', MailState(mails: [
        MailItem(
          id: 'r1',
          kind: MailKind.reward,
          from: MailRules.operator,
          title: '점검 보상',
          gifts: const {'gold': 100, 'herb': 2},
          sentAt: now,
          expiresAt: now.add(MailRules.rewardKeep),
        ),
      ], sent: const ['r1']).toJson());
      final c2 = AppController(
        area: KoreaArea.area,
        store: store,
        health: FakeHealthSource(stepsByDay: {'2026-11-11': 3000}),
        location: FakeLocationSource(),
        clock: () => now,
      )..mailSources = const [];
      await c2.init();
      // 묶음 22: 도구가 없는 기존 사용자는 채집 도구 우편도 받는다
      expect(c2.giftMails.where((m) => m.id != 'toolsGift').single.id, 'r1');
      now = now.add(const Duration(days: 31));
      await c2.refreshVitals();
      expect(c2.giftMails.where((m) => m.id == 'r1'), isEmpty);
    });
  });
}
