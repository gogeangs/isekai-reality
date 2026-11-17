// 묶음 53: 3막 지역 1 「발드린 관문」 (#243) — 야영지 · 주민 · 메인 ②~⑤ · 서브 4 · 지하 요새 ·
// 큰 고르기 · 바람의 굴 · 등불 · 지역 무기 · 이름 있는 장비 + 운영정책 기기 ID

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/geo/geo.dart';
import 'package:isekai_reality/core/models/board_state.dart';
import 'package:isekai_reality/core/models/act3_state.dart';
import 'package:isekai_reality/core/models/armory.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/cloud/backup_server.dart';
import 'package:isekai_reality/data/cloud/cloud_auth.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/act3/act3_screen.dart';
import 'package:isekai_reality/features/act3/act3_town.dart';
import 'package:isekai_reality/features/map/korea_area.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'batch52_test.dart' as b52;

/// 3막이 열린 계정 (Lv.[level])
Future<AppController> opened({int level = 22}) async {
  final s = b52.account(level: level);
  final c = (await b52.start(s)).$1;
  await c.openAct3();
  return c;
}

/// 싸움을 꼭 이기게 (몬스터 HP를 1로 · 내 HP 넉넉히)
void win(Battle b) {
  for (var i = 0; i < 400 && !b.isOver; i++) {
    b.playerHp = 99999;
    b.foeHp = 1;
    b.tick();
  }
}

void lose(Battle b) {
  for (var i = 0; i < 400 && !b.isOver; i++) {
    b.playerHp = 0;
    b.tick();
  }
}

Future<Act3FightResult> fight(AppController c, A3Enc e) async {
  final b = c.startEncounter(e)!;
  win(b);
  return c.finishAct3Fight(b);
}

Future<void> field(AppController c, String place) async {
  final b = c.startAct3Fight(place)!;
  win(b);
  await c.finishAct3Fight(b);
}

/// 여정 기력을 넉넉히 (시험용: 저장 칸을 직접)
Future<AppController> withEnergy(AppController c) async {
  await c.store.saveJson('act3', c.act3.copyWith(energy: 100).toJson());
  return c;
}

void main() {
  group('규칙', () {
    test('주민 4 · 서브 4 + 가렌 · 요새 5층(3층 중간 보스 · 5층 등불 보스) · 이름 있는 장비 3', () {
      expect([for (final r in BaldrinRules.residents) r.name], ['볼크', '한나', '피피', '오름']);
      expect(BaldrinRules.sides, hasLength(5));
      expect(BaldrinRules.side(SideQuest.roster).garen, isTrue);
      expect(BaldrinRules.floors, hasLength(5));
      expect(BaldrinRules.floors[2].boss, isTrue);
      expect(BaldrinRules.floors[2].foes, [MonsterId.ashHounds]);
      expect(BaldrinRules.floors[4].lamp, isTrue);
      expect(BaldrinRules.floors[4].foes, [MonsterId.ashArmor]);
      expect(BaldrinRules.floors[0].foes, [MonsterId.ogre]);
      expect([for (final b in BaldrinRules.uniques) EquipmentRules.info(b).name],
          ['볼크의 금 간 투구', '테오의 예비 창', '바람의 은빛 목걸이']);
      expect(EquipmentRules.info(EquipBase.baldrinSpear).name, '관문의 빛 창');
      expect(BaldrinRules.mains, hasLength(5));
      expect(BaldrinRules.choiceNote, '한 번 고르면 바꿀 수 없어요');
      expect(BaldrinRules.lampTickets, 5);
    });

    test('세트 · 이름 있는 장비 숨은 효과', () {
      EquipItem it(EquipBase b) => EquipItem(uid: b.name, base: b, grade: EquipGrade.white);
      final six = SetBonus.of([
        for (final b in Act3Rules.baldrinGear) it(b),
      ]);
      expect(six.ashTaken, BaldrinRules.set6Taken);
      expect(six.ashDealt, BaldrinRules.set6Dealt);
      final two = SetBonus.of([it(EquipBase.baldrinHead), it(EquipBase.baldrinBody)]);
      expect(two.ashTaken, BaldrinRules.set2Taken);
      expect(two.ashDealt, 0);
      final u = SetBonus.of([
        it(EquipBase.uniqVolkHelm),
        it(EquipBase.uniqTeoSpear),
        it(EquipBase.uniqWindPendant),
      ]);
      expect(u.guardFlash, BaldrinRules.volkFlash);
      expect(u.ashDealt, BaldrinRules.teoAsh);
      expect(u.petFaster, 1);
      expect(MasteryRules.weaponKind(EquipBase.uniqTeoSpear), 'spear');
    });

    test('직업에 잘 맞는 무기 (확정 표)', () {
      expect(Act3Rules.jobWeapons[AllyJob.warrior], {'sword', 'axe'});
      expect(Act3Rules.jobWeapons[AllyJob.knight], {'sword', 'spear'});
      expect(Act3Rules.jobWeapons[AllyJob.rogue], {'dagger'});
      expect(Act3Rules.jobWeapons[AllyJob.mage], {'staff'});
    });
  });

  group('메인 흐름', () {
    test('① 첫 싸움 → ② 볼크 → ③ 성벽길 편지 → 큰 고르기(가렌) → ④ 요새 → ⑤ 등불', () async {
      final c = await withEnergy(await opened());
      final again = (await b52.start(c.store as InMemoryRecordStore)).$1;
      expect(again.mainStep, 0);
      await field(again, 'baldrin_ashplain');
      expect(again.mainStep, 1);
      expect(again.volkTalkPending, isTrue);
      expect(again.wallPending, isFalse);
      await again.markVolkTalk();
      expect(again.mainStep, 2);
      expect(again.wallPending, isTrue);
      expect(again.dungeonOpen, isFalse);
      final r = await fight(again, again.wallFight);
      expect(r.lines, contains(BaldrinRules.letterLine));
      expect(again.choicePending, isTrue);
      final spear = await again.chooseLetter(marta: false);
      expect(spear!.base, EquipBase.uniqTeoSpear);
      expect(again.uniqueFound(EquipBase.uniqTeoSpear), isTrue);
      expect(await again.chooseLetter(marta: true), isNull, reason: '한 번 고르면 바꿀 수 없음');
      expect(again.act3.choice, 'garen');
      expect(again.mainStep, 3);
      expect(again.dungeonOpen, isTrue);
      expect(again.act3NpcLines(Npc.garen), BaldrinRules.garenAfterGaren);
      expect(again.act3NpcLines(Npc.marta), BaldrinRules.martaAfterGaren);
    });

    test('큰 고르기 마르타: 도시락 3개 → 여정 기력 +40', () async {
      final c = await opened();
      await c.store.saveJson(
          'act3', c.act3.copyWith(energy: 30, firstFight: true, flags: {'volk', 'wallFought'}).toJson());
      final r = (await b52.start(c.store as InMemoryRecordStore)).$1;
      expect(r.choicePending, isTrue);
      await r.chooseLetter(marta: true);
      expect(r.lunchCount, BaldrinRules.lunchCount);
      expect(await r.eatLunch(), isTrue);
      expect(r.journeyEnergy, 70);
      expect(r.lunchCount, 2);
      expect(r.act3NpcLines(Npc.marta), BaldrinRules.martaAfterMarta);
    });
  });

  group('지하 요새', () {
    Future<AppController> atFort() async {
      final c = await opened();
      await c.store.saveJson(
          'act3',
          c.act3
              .copyWith(energy: 100, firstFight: true, flags: {'volk', 'wallFought'}, choice: 'garen')
              .toJson());
      return (await b52.start(c.store as InMemoryRecordStore)).$1;
    }

    test('층마다 기력 10 · 갈림길 · 도달한 층 기억 · 지면 층 그대로', () async {
      final c = await atFort();
      expect(c.floorNow, 1);
      final fights = c.enterFloor()!;
      expect(c.journeyEnergy, 90);
      expect(fights.first.foes, [MonsterId.ogre]);
      for (final e in fights) {
        await fight(c, e);
      }
      final br = await c.takeBranch(Branch.story);
      expect(br.text, BaldrinRules.floorStories[0]);
      await c.clearFloor();
      expect(c.floorBest, 1);
      expect(c.floorNow, 2);
      // 2층에서 짐 → 층은 그대로
      final f2 = c.enterFloor()!;
      final b = c.startEncounter(f2.first)!;
      lose(b);
      final r = await c.finishAct3Fight(b);
      expect(r.won, isFalse);
      expect(c.floorNow, 2);
      expect(c.floorBest, 1);
    });

    test('3층 중간 보스 → 오름 빛 이슬 · 5층 등불 보스 → 등불 · 칭호 · 모집권 6 · 빈 갑주 조각', () async {
      final c = await atFort();
      await c.acceptSide(SideQuest.dew);
      await c.store.saveJson('act3', c.act3.copyWith(floorNow: 3, floorBest: 2).toJson());
      final r1 = (await b52.start(c.store as InMemoryRecordStore)).$1;
      final mid = r1.enterFloor()!;
      expect(mid, hasLength(1));
      expect(mid.first.kind, A3Kind.mid);
      final res = await fight(r1, mid.first);
      expect(r1.sideReady(SideQuest.dew), isTrue);
      expect(res.lines.any((l) => l.contains('빛 이슬')), isTrue);
      await r1.store.saveJson('act3', r1.act3.copyWith(floorNow: 5, floorBest: 4, energy: 100).toJson());
      final r2 = (await b52.start(r1.store as InMemoryRecordStore)).$1;
      expect(r2.mainStep, 4);
      final tickets = r2.recruitTickets;
      final boss = r2.enterFloor()!;
      expect(boss.first.kind, A3Kind.lamp);
      final lamp = await fight(r2, boss.first);
      expect(lamp.lamp, isTrue);
      expect(lamp.tickets, BaldrinRules.lampTickets + BaldrinRules.dungeonTicket);
      expect(r2.recruitTickets, tickets + 6);
      expect(r2.baldrinLit, isTrue);
      expect(r2.mainStep, 5);
      expect(r2.player.materialCount(MaterialId.hollowPlate), BaldrinRules.plateFirst);
      expect(r2.lampMonsters, BaldrinRules.normals);
      expect(r2.history.last.counters[TitleRules.skyCounter(TitleId.baldrinLamp)], 1);
      // 다시 잡으면 등불 보상은 없고 조각 1
      await r2.store.saveJson('act3', r2.act3.copyWith(floorNow: 5, energy: 100).toJson());
      final r3 = (await b52.start(r2.store as InMemoryRecordStore)).$1;
      final again = await fight(r3, r3.enterFloor()!.first);
      expect(again.lamp, isFalse);
      expect(again.tickets, 0);
    });

    test('지역 무기 「관문의 빛 창」: 등불 뒤 · 재료가 있으면 만듦 (빛 속성)', () async {
      final c = await atFort();
      expect(c.spearCraftable, isFalse);
      await c.store.saveJson('act3', c.act3.copyWith(flags: {...c.act3.flags, 'lamp'}).toJson());
      final s = c.store as InMemoryRecordStore;
      await s.upsert(DailyRecord(date: DateTime(2026, 11, 2), gains: {
        MaterialId.hollowPlate.name: 3,
        MaterialId.ironIngot.name: 2,
        Wallet.manaStone: 50,
        Wallet.gold: 1000,
      }));
      final r = (await b52.start(s)).$1;
      expect(r.spearCraftable, isTrue);
      final spear = await r.craftSpear();
      expect(spear!.base, EquipBase.baldrinSpear);
      expect(spear.element, Element.light);
      expect(r.player.materialCount(MaterialId.hollowPlate), 0);
    });
  });

  group('서브 퀘스트 · 바람의 굴', () {
    test('볼크 봉화대 3 · 한나 하피 둥지 · 피피 재료 3종 · 가렌 이름표 4 → 가렌 ④', () async {
      final c = await opened();
      await c.store.saveJson(
          'act3', c.act3.copyWith(energy: 100, firstFight: true, flags: {'volk'}).toJson());
      final s = c.store as InMemoryRecordStore;
      await s.upsert(DailyRecord(date: DateTime(2026, 11, 3), gains: {
        MaterialId.slimeJelly.name: 5,
        MaterialId.ratHide.name: 5,
        MaterialId.batWing.name: 5,
      }));
      final r = (await b52.start(s)).$1;
      expect(r.residentOffer(Resident.volk)!.id, SideQuest.beacon);
      for (final q in [SideQuest.beacon, SideQuest.child, SideQuest.stall, SideQuest.roster]) {
        await r.acceptSide(q);
      }
      expect(r.residentOffer(Resident.volk), isNull);
      for (var i = 0; i < 3; i++) {
        await field(r, 'baldrin_ashplain');
      }
      expect(r.sideReady(SideQuest.beacon), isTrue);
      final t0 = r.recruitTickets;
      expect(await r.reportSide(SideQuest.beacon), isTrue);
      expect(r.recruitTickets, t0 + 1);
      expect(r.sideState(SideQuest.beacon), 2);
      expect(r.nestPending, isTrue);
      await fight(r, r.nestFight);
      expect(r.sideReady(SideQuest.child), isTrue);
      expect(r.stallMats, isNotNull);
      expect(await r.reportSide(SideQuest.stall), isTrue);
      expect(r.stallItems, containsAll(BaldrinRules.stallMore));
      expect(r.player.materialCount(MaterialId.slimeJelly), 3);
      // 가렌 ④는 명부를 끝내야
      final garen = r.act3.ally('garen')!;
      await r.store.saveJson('act3',
          r.act3.replaceAlly(garen.copyWith(level: 30, skills: [0, 1, 2])).toJson());
      final r2 = (await b52.start(s)).$1;
      expect(r2.canUnlockSkill(r2.act3.ally('garen')!, 3), isFalse);
      for (var i = 0; i < 4; i++) {
        await field(r2, 'baldrin_wallroad');
      }
      final r4 = (await b52.start(s)).$1;
      expect(r4.sideReady(SideQuest.roster), isTrue);
      await r4.reportSide(SideQuest.roster);
      expect(r4.garenRosterDone, isTrue);
      expect(r4.canUnlockSkill(r4.act3.ally('garen')!, 3), isTrue);
    });

    test('은빛 털 → 루미(펫 쉼터) → 바람의 굴 → 숨은 보스: 칭호 · 목걸이 (처음은 꼭)', () async {
      final c = await opened();
      await c.store.saveJson(
          'act3', c.act3.copyWith(energy: 100, firstFight: true, flags: {'fur'}).toJson());
      final r = (await b52.start(c.store as InMemoryRecordStore)).$1;
      expect(r.hasSilverFur, isTrue);
      expect(r.denOpen, isFalse);
      expect(r.takeNpcLine(Npc.lumi), BaldrinRules.lumiFur);
      await Future<void>.delayed(Duration.zero);
      expect(r.denOpen, isTrue);
      final res = await fight(r, r.denFight);
      expect(res.items.any((i) => i.base == EquipBase.uniqWindPendant), isTrue);
      expect(r.denCleared, isTrue);
      expect(r.history.last.counters[TitleRules.skyCounter(TitleId.windMemory)], 1);
      expect(r.act3NpcLines(Npc.lumi), [BaldrinRules.lumiAfterDen]);
    });

    test('천막 여관: HP 가득 · 하루 한 번 여정 기력 +30', () async {
      final c = await opened();
      await c.store.saveJson('act3', c.act3.copyWith(energy: 50).toJson());
      final r = (await b52.start(c.store as InMemoryRecordStore)).$1;
      expect(await r.restAtTent(), BaldrinRules.innEnergy);
      expect(r.journeyEnergy, 80);
      expect(await r.restAtTent(), 0);
      expect(r.hp, r.maxHp);
    });
  });

  group('현실 쪽', () {
    test('등불 뒤 현실 지도에 지역 몬스터가 가끔 · 예전 자리는 그대로', () {
      const area = KoreaArea.area;
      const home = GeoPoint(37.3219, 126.8309);
      final day = DateTime(2026, 11, 17, 10);
      final plain = FieldMonsterRules.spawnsFor(area, day, center: home, radiusM: 3000);
      final lit = FieldMonsterRules.spawnsFor(area, day,
          center: home,
          radiusM: 3000,
          lampMonsters: BaldrinRules.normals,
          lampShare: BaldrinRules.realMapShare);
      expect([for (final s in lit) (s.point.lat, s.point.lng)],
          [for (final s in plain) (s.point.lat, s.point.lng)]);
      final changed = [
        for (var i = 0; i < lit.length; i++)
          if (lit[i].monster != plain[i].monster) lit[i].monster,
      ];
      expect(changed, isNotEmpty);
      expect(changed.every(BaldrinRules.normals.contains), isTrue);
      expect(changed.length, lessThan(lit.length ~/ 4));
    });

    test('의뢰 게시판: 3막이 열리면 지역 의뢰가 섞이고 모집권 보상', () {
      final t = BoardRules.template('baldrinFloor2')!;
      expect(t.tickets, 1);
      expect(t.rewardLabel, contains('모집권 1'));
      var seen = 0;
      for (var d = 1; d <= 20; d++) {
        final b = BoardRules.refresh(const BoardState(), DateTime(2026, 12, d, 10), region: true);
        seen += b.slots.where((s) => s.templateId?.startsWith('baldrin') ?? false).length;
      }
      expect(seen, greaterThan(0));
      final none = [
        for (var d = 1; d <= 20; d++)
          ...BoardRules.refresh(const BoardState(), DateTime(2026, 12, d, 10)).slots,
      ];
      expect(none.any((s) => s.templateId?.startsWith('baldrin') ?? false), isFalse);
    });

    test('운영정책: 백업에 무작위 기기 ID (휴대폰마다 하나, 그대로)', () async {
      final s = b52.account();
      final server = FakeBackupServer()..time = DateTime.utc(2026, 11, 17, 1);
      final c = AppController(
          store: s, health: FakeHealthSource(), clock: () => DateTime(2026, 11, 17, 10))
        ..mailSources = const []
        ..cloudAuth = FakeCloudAuth()
        ..backupServer = server;
      await c.init();
      final id = await c.deviceId();
      expect(id, hasLength(32));
      expect(await c.deviceId(), id);
      await c.signInCloud(LoginProvider.google);
      expect(server.devices['u1'], {id});
      final snap = await s.exportAll();
      expect(snap.values.any((v) => v == id), isFalse, reason: '기기 ID는 백업 기록에 안 들어감');
    });

    test('예전 3막 기록(묶음 52)도 그대로 읽음', () {
      final old = Act3State.fromJson({'opened': true, 'energy': 40, 'firstFight': true});
      expect(old.flags, isEmpty);
      expect(old.floorNow, 1);
      expect(old.choice, isNull);
      final back = Act3State.fromJson(old.copyWith(flags: {'volk'}, prog: {'beacon': 2}).toJson());
      expect(back.has('volk'), isTrue);
      expect(back.prog['beacon'], 2);
    });
  });

  group('화면', () {
    testWidgets('야영지: 볼크 이야기 → 퀘스트 맡기 · 여관 · 노점 · 의뢰판', (tester) async {
      tester.view.physicalSize = const Size(750, 1334);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      late AppController c;
      await tester.runAsync(() async {
        final a = await opened();
        await a.store.saveJson('act3', a.act3.copyWith(firstFight: true).toJson());
        c = (await b52.start(a.store as InMemoryRecordStore)).$1;
      });
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => TopNoticeHost(child: child!),
          home: TownScreen(controller: c)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('resident_volk')), findsOneWidget);
      await tester.tap(find.byKey(const Key('resident_volk')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('volkTalk')), findsOneWidget);
      for (var i = 0; i < BaldrinRules.volkTalk.length; i++) {
        await tester.tap(find.byKey(const Key('talkNext')));
        await tester.pump(const Duration(milliseconds: 300));
      }
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(c.mainStep, 2);
      await tester.tap(find.byKey(const Key('resident_volk')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('questOffer')), findsOneWidget);
      await tester.tap(find.byKey(const Key('questTake')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(c.sideState(SideQuest.beacon), 1);
      await tester.scrollUntilVisible(find.byKey(const Key('townBoard')), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.byKey(const Key('garenQuest')), findsOneWidget);
      expect(find.byKey(const Key('innRest')), findsOneWidget);
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('지하 요새: 층 표시 · 들어가기 · 큰 고르기 화면 두 카드', (tester) async {
      tester.view.physicalSize = const Size(750, 1334);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      late AppController c;
      await tester.runAsync(() async {
        final a = await opened();
        await a.store.saveJson(
            'act3',
            a.act3
                .copyWith(firstFight: true, flags: {'volk', 'wallFought'}, energy: 100)
                .toJson());
        c = (await b52.start(a.store as InMemoryRecordStore)).$1;
      });
      await tester.pumpWidget(MaterialApp(home: LetterChoiceScreen(controller: c)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('choiceMarta')), findsOneWidget);
      expect(find.byKey(const Key('choiceGaren')), findsOneWidget);
      await tester.runAsync(() async => c.chooseLetter(marta: false));
      await tester.pumpWidget(MaterialApp(home: FortScreen(controller: c)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('floor_1')), findsOneWidget);
      expect(find.byKey(const Key('floor_5')), findsOneWidget);
      expect(find.byKey(const Key('enterFloor')), findsOneWidget);
      await tester.pumpWidget(MaterialApp(home: UniqueBookScreen(controller: c)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('unique_uniqTeoSpear')), findsOneWidget);
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('지역 지도: 「!」 표시 · 바람의 굴 이름', (tester) async {
      tester.view.physicalSize = const Size(750, 1334);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      late AppController c;
      await tester.runAsync(() async {
        final a = await opened();
        await a.store.saveJson(
            'act3', a.act3.copyWith(firstFight: true, flags: {'den'}).toJson());
        c = (await b52.start(a.store as InMemoryRecordStore)).$1;
      });
      await tester.pumpWidget(MaterialApp(home: Act3Screen(controller: c)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('placeAlert_baldrin_town')), findsOneWidget);
      expect(find.byKey(const Key('placeAlert_baldrin_windden')), findsOneWidget);
      expect(find.text('바람의 굴'), findsOneWidget);
      await tester.pump(const Duration(seconds: 9));
    });
  });
}
