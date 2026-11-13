import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/core/geo/geo.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/mail_state.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/location/location_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/map/korea_area.dart';

void main() {
  group('C7 장소 종류 격자', () {
    final g = PlaceGrid.tryParse(
        File('test/fixtures/place_grid_small.bin').readAsBytesSync())!;
    GeoPoint at(int r, int c) =>
        GeoPoint(37.4 - (r + 0.5) * 0.001, 126.8 + (c + 0.5) * 0.001);

    test('칸마다 종류를 읽는다 (타일 경계 넘어도)', () {
      expect(g.kindAt(at(0, 0)), LandKind.village);
      expect(g.kindAt(at(15, 15)), LandKind.park);
      expect(g.kindAt(at(80, 120)), LandKind.sea);
      expect(g.kindAt(at(50, 120)), LandKind.city);
      expect(g.kindAt(at(99, 149)), LandKind.mountain);
      expect(g.kindAt(at(65, 70)), LandKind.village);
    });

    test('격자 밖은 null, 틀린 자료는 null', () {
      expect(g.kindAt(const GeoPoint(30, 120)), isNull);
      expect(PlaceGrid.tryParse(File('pubspec.yaml').readAsBytesSync()), isNull);
    });
  });

  group('C7 장소 종류별 채집 자리', () {
    test('공원·숲은 약초·나무·버섯·꽃, 도심은 광석·보석이 대부분', () {
      final rng = Random(1);
      int count(LandKind p, Set<HarvestKind> want) {
        var n = 0;
        for (var i = 0; i < 2000; i++) {
          if (want.contains(HarvestRules.kindAt(
              p, rng.nextDouble(), rng.nextDouble()))) {
            n++;
          }
        }
        return n;
      }

      expect(
          count(LandKind.park, {
            HarvestKind.herb,
            HarvestKind.wood,
            HarvestKind.mushroom,
            HarvestKind.flower
          }),
          greaterThan(1600));
      expect(count(LandKind.city, {HarvestKind.ore, HarvestKind.gem}),
          greaterThan(1600));
      expect(count(LandKind.sea, {HarvestKind.water}), greaterThan(1600));
    });
  });

  group('#100 우편함 한 목록', () {
    test('받은 보상 편지는 지우지 않고 보관, 받지 않은 것만 30일 뒤 사라짐', () async {
      var now = DateTime(2026, 11, 11, 12);
      final store = InMemoryRecordStore(profile: const PlayerProfile(name: '하루'));
      await store.saveJson(
          'mail',
          MailState(mails: [
            MailItem(
                id: 'r1',
                kind: MailKind.reward,
                from: MailRules.operator,
                title: '점검 보상',
                gifts: const {'gold': 100},
                sentAt: now,
                expiresAt: now.add(MailRules.rewardKeep)),
            MailItem(
                id: 'r2',
                kind: MailKind.reward,
                from: MailRules.operator,
                title: '두 번째 보상',
                gifts: const {'gold': 50},
                sentAt: now,
                expiresAt: now.add(MailRules.rewardKeep)),
          ], sent: const [
            'r1',
            'r2'
          ]).toJson());
      final c = AppController(
        area: KoreaArea.area,
        store: store,
        health: FakeHealthSource(stepsByDay: {'2026-11-11': 3000}),
        location: FakeLocationSource(),
        clock: () => now,
      )..mailSources = const [];
      await c.init();
      // 묶음 22: 도구가 없는 기존 사용자는 채집 도구 우편도 받는다
      expect(c.giftMails.where((m) => m.id != 'toolsGift').length, 2);
      expect(await c.claimMail('r1'), isNotNull);
      expect(c.allMails.any((m) => m.id == 'r1' && m.claimed), isTrue);
      now = now.add(const Duration(days: 31));
      await c.refreshVitals();
      final ids = c.allMails.map((m) => m.id).toList();
      expect(ids, contains('r1')); // 받은 것은 남고
      expect(ids, isNot(contains('r2'))); // 받지 않은 것만 사라짐
    });
  });
}
