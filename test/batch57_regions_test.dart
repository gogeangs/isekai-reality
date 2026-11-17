// 묶음 57 (2~6): 직업 개편 · 이름 금칙어 · 전설 펫 · 3막 지역 2~5 · 3막 끝 · 심층

import 'dart:io';

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/act3_state.dart';
import 'package:isekai_reality/core/models/armory.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/act3/region_screens.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'batch52_test.dart' as b52;
import 'batch53_test.dart' as b53;

/// 3막 기록을 바꿔 다시 연다 (여정 기력도 가득)
Future<AppController> reload(AppController c, Act3State Function(Act3State) f) async {
  await c.store.saveJson('act3', f(c.act3).copyWith(energy: 100).toJson());
  return (await b52.start(c.store as InMemoryRecordStore)).$1;
}

Future<AppController> full(AppController c) => reload(c, (s) => s);

/// 발드린 등불까지 켠 Lv.[level] 계정, 길도 다 걸음
Future<AppController> baldrinDone({int level = 30}) async {
  final c = await b53.opened(level: level);
  return reload(c, (s) => s.copyWith(flags: {...s.flags, 'lamp'}, roadSteps: Act3Rules.roadSteps));
}

/// 지역 [r] 에 들어와 있는 계정 (앞 지역 등불은 다 켬)
Future<AppController> inRegion(RegionContent r, {Set<String> more = const {}}) async {
  final c = await b53.opened(level: 30);
  return reload(
      c,
      (s) => s.copyWith(region: r.region.index, flags: {
            ...s.flags,
            'lamp',
            for (final x in RegionRules.all)
              if (x.region.index < r.region.index) ...{'reach:${x.prefix}', '${x.prefix}:lamp'},
            'reach:${r.prefix}',
            ...more,
          }));
}

Future<void> clearDungeonTo(AppController c, RegionContent r, int to) async {
  while (c.regionFloorBest(r) < to) {
    final fights = c.regionEnterFloor(r);
    expect(fights, isNotNull, reason: '층에 들어가기 (기력 ${c.journeyEnergy}, HP ${c.hp})');
    for (final e in fights!) {
      await b53.fight(c, e);
    }
    await c.regionTakeBranch(r, Branch.story);
    await c.regionClearFloor(r);
  }
}

void main() {
  group('규칙 · 그림', () {
    test('지역 넷: 주민 4 · 필드 3 · 던전 5층 · 숨은 장소 · 메인 5 · 서브 4 + 동료 퀘스트', () {
      for (final r in RegionRules.all) {
        final places = Act3Rules.region(r.region).places;
        expect(places, hasLength(6), reason: r.prefix);
        expect(places.where((p) => p.kind == SpotKind.field), hasLength(3));
        expect(places.where((p) => p.kind == SpotKind.dungeon), hasLength(1));
        expect(places.where((p) => p.kind == SpotKind.hidden).single.id, r.hidden.place);
        expect(r.residents, hasLength(4));
        expect(r.mains, hasLength(5));
        expect(r.floors, hasLength(5));
        expect(r.floors[2].boss, isTrue);
        expect(r.floors[4].lamp, isTrue);
        expect(r.quests.where((q) => q.giver != null), hasLength(4));
        expect(r.quests.where((q) => q.ally != null),
            hasLength(r.region == Region.selenia ? 2 : 1)); // 셀레니아: 니아 · 바르칸
        expect(r.gear, hasLength(6));
        expect(r.uniques, hasLength(3));
        expect(r.quests.any((q) => q.id == r.hidden.unlockBy), isTrue);
        for (final m in [r.mains.first.place, r.eventPlace, for (final q in r.quests) q.place]) {
          expect(Act3Rules.place(m!), isNotNull, reason: m);
        }
      }
      expect(RegionRules.aurel.floors[4].foes, [MonsterId.orben, MonsterId.orbenAsh]);
      expect(RegionRules.aurel.choice.afterLamp, isTrue);
      final ids = [for (final r in RegionRules.all) for (final q in r.quests) q.id];
      expect(ids.toSet(), hasLength(ids.length));
      expect(EquipmentRules.info(EquipBase.seleniaAxe).name, '장터의 저울 도끼');
      expect(EquipmentRules.info(EquipBase.aurelBow).name, '여명의 불꽃 활');
      expect(MasteryRules.weaponKind(EquipBase.aurelBow), 'bow');
    });

    test('그림이 다 있다 (지도 · 마을 · 얼굴 · 장비 · 몬스터 · 칭호 · 장면)', () {
      bool has(String a) => File(a).existsSync();
      final missing = <String>[
        for (final r in RegionRules.all) ...[
          if (!has(Act3Rules.region(r.region).map)) Act3Rules.region(r.region).map,
          if (!has(r.town)) r.town,
          if (!has(r.dungeonBg)) r.dungeonBg,
          for (final p in r.residents)
            if (!has(p.faceAsset)) p.faceAsset,
          for (final b in [...r.gear, ...r.uniques, r.weapon])
            if (!has('assets/images/${EquipmentRules.info(b).asset}.webp'))
              EquipmentRules.info(b).asset,
          for (final m in [...r.normals, for (final f in r.floors) ...f.foes, r.hidden.boss])
            if (!has('assets/images/monster_${m.name}.webp')) m.name,
          for (final p in Act3Rules.region(r.region).places)
            if (p.background != null && !has(p.background!)) p.background!,
          if (!has('assets/images/${TitleRules.asset(r.lampTitle)}.webp')) r.lampTitle.name,
        ],
        if (!has(RegionRules.fiveLampsScene)) RegionRules.fiveLampsScene,
        if (!has(RegionRules.teoMartaScene)) RegionRules.teoMartaScene,
      ];
      expect(missing, isEmpty);
    });

    test('세트: 지역 일반 장비 6개 → 잿빛에게 받는 피해 ↓ · 주는 피해 ↑ · 테오 망토', () {
      EquipItem it(EquipBase b) => EquipItem(uid: b.name, base: b, grade: EquipGrade.white);
      final six = SetBonus.of([for (final b in RegionRules.selenia.gear) it(b)]);
      expect(six.ashTaken, RegionRules.set6Taken);
      expect(six.ashDealt, RegionRules.set6Dealt);
      final two = SetBonus.of([for (final b in RegionRules.elowin.gear.take(2)) it(b)]);
      expect(two.ashTaken, RegionRules.set2Taken);
      expect(two.ashDealt, 0);
      expect(SetBonus.of([it(EquipBase.uniqTeoCloak)]).ashTaken, RegionRules.teoCloakAsh);
    });

    test('직업: 전투 6 · 숨은 특별 짝 10 · 활은 Lv.15', () {
      expect(JobPairRules.combat, hasLength(6));
      expect(JobPairRules.specials, hasLength(10));
      expect(TitleRules.pairTitles, hasLength(10));
    });

    test('이름 금칙어: 띄어쓰기 · 기호를 빼고 비교', () {
      NameRules.load(File('assets/data/banned_words.txt').readAsStringSync());
      expect(NameRules.loaded, isTrue);
      expect(NameRules.banned('하루'), isFalse);
      expect(NameRules.banned('시 1 발'), isTrue);
      expect(NameRules.banned('s.h.i.t'), isTrue);
    });
  });

  group('지역 2 셀레니아 흐름', () {
    test('길 → 들어가기 → 바르칸 합류 → ① 대상의 길 → ② 에니 → ③ 니아 「보내 주기」 → 금고 → 등불', () async {
      var c = await baldrinDone();
      expect(c.regionNow, isNull);
      expect(c.canEnterNext, isTrue);
      final r = (await c.enterNextRegion())!;
      expect(r.region, Region.selenia);
      expect(c.regionNow, same(RegionRules.selenia));
      expect(c.act3.roadSteps, 0);
      expect(c.regionArrivePending(r), isTrue);
      await c.markRegionArrive(r);
      expect(c.storyJoined(StoryAlly.barkan), isTrue);
      expect(c.storyJoined(StoryAlly.nia), isFalse);
      expect(c.regionStep(r), 0);

      c = await full(c);
      await b53.field(c, 'selenia_caravan');
      expect(c.regionStep(r), 1);
      expect(c.regionTalkPending(r), isTrue);
      await c.markRegionTalk(r);
      expect(c.regionStep(r), 2);
      expect(c.regionEventPending(r), isTrue);
      expect(c.regionDungeonOpen(r), isFalse);
      final ev = await b53.fight(c, c.regionEventFight(r));
      expect(ev.lines, contains(r.eventLines.first));
      expect(c.regionChoicePending(r), isTrue);
      final t0 = c.recruitTickets;
      await c.chooseRegion(r, r.choice.b);
      expect(c.regionChoice(r), 'free');
      expect(c.storyJoined(StoryAlly.nia), isTrue);
      expect(c.recruitTickets, t0 + 1);
      expect(c.regionDungeonOpen(r), isTrue);
      // 한 번 고르면 끝
      expect(await c.chooseRegion(r, r.choice.a), isNull);
      expect(c.regionChoice(r), 'free');

      for (var k = 0; k < 5; k++) {
        c = await full(c);
        if (c.regionFloorBest(r) >= 5) break;
        await clearDungeonTo(c, r, c.regionFloorBest(r) + 1);
      }
      expect(c.regionLit(Region.selenia), isTrue);
      expect(c.regionStep(r), 5);
      expect(c.player.materialCount(MaterialId.cartWheel), greaterThanOrEqualTo(RegionRules.pieceFirst));
      final again = (await b52.start(c.store as InMemoryRecordStore)).$1;
      expect(again.history.last.counters[TitleRules.skyCounter(TitleId.seleniaLamp)], 1);
      expect(again.lampMonsters, containsAll(RegionRules.selenia.normals));
      expect(again.regionShopDark(r), isFalse);
      expect(again.auctionLot, isNotNull);
      expect(again.litRegionWeapons, [r]);
      // 다음 지역 길은 다시 걸어야
      expect(again.canEnterNext, isFalse);
    });

    test('「상회에 넘기기」: 니아는 금고 3층에서 합류', () async {
      var c = await inRegion(RegionRules.selenia,
          more: {'selenia:arrive', 'selenia:first', 'selenia:talk', 'selenia:event'});
      final r = RegionRules.selenia;
      await c.chooseRegion(r, r.choice.a);
      expect(c.storyJoined(StoryAlly.nia), isFalse);
      c = await full(c);
      await clearDungeonTo(c, r, 3);
      expect(c.storyJoined(StoryAlly.nia), isTrue);
    });

    test('서브: 사냥 3번 → 보고(모집권 · 금화) · 자장가를 끝내면 별가루 광맥이 열림 → 금속 거인 · 칭호', () async {
      var c = await inRegion(RegionRules.selenia,
          more: {'selenia:arrive', 'selenia:first', 'selenia:talk'});
      final r = RegionRules.selenia;
      final ledger = r.quest('sel_ledger');
      expect(c.regionOffer(r, r.resident('eni')), same(ledger));
      await c.acceptQuest(ledger);
      for (var i = 0; i < 3; i++) {
        await b53.field(c, 'selenia_caravan');
      }
      expect(c.questReady(ledger), isTrue);
      final t = c.recruitTickets, g = c.player.gold;
      expect(await c.reportQuest(r, ledger), isTrue);
      expect(c.recruitTickets, t + 1);
      expect(c.player.gold, g + RegionRules.sideGold);
      expect(c.questState(ledger), 2);

      final lull = r.quest('sel_lullaby');
      await c.acceptQuest(lull);
      c = await full(c);
      for (var i = 0; i < 3; i++) {
        await b53.field(c, 'selenia_stardust');
      }
      expect(c.regionHiddenOpen(r), isFalse);
      await c.reportQuest(r, lull);
      expect(c.regionHiddenOpen(r), isTrue);
      final res = await b53.fight(c, c.regionHiddenFight(r));
      expect(res.won, isTrue);
      expect(res.items.any((i) => r.uniques.contains(i.base)), isTrue, reason: '처음 숨은 보스는 이름 있는 장비를 꼭');
      expect(c.regionHiddenCleared(r), isTrue);
      final again = (await b52.start(c.store as InMemoryRecordStore)).$1;
      expect(again.history.last.counters[TitleRules.skyCounter(TitleId.stardustFinder)], 1);
    });

    test('동료 퀘스트(걷기): 바르칸 「상단의 깃발」 → 스킬 ④', () async {
      var c = await inRegion(RegionRules.selenia,
          more: {'selenia:arrive', 'selenia:first', 'selenia:talk'});
      final r = RegionRules.selenia;
      c = await reload(c, (s) => s.copyWith(allies: [
            ...s.allies,
            const AllyData(id: 'barkan', story: 'barkan', name: '바르칸', level: 29, joinLevel: 20),
          ]));
      final q = r.quest('sel_barkan');
      expect(c.regionAllyOffers(r), [q]);
      expect(c.allyQuestDone(StoryAlly.barkan), isFalse);
      final barkan = c.act3.ally('barkan')!;
      expect(c.canUnlockSkill(barkan.copyWith(skills: [0, 1, 2]), 3), isFalse);
      await c.acceptQuest(q);
      c = await reload(c, (s) => s.copyWith(prog: {...s.prog, q.id: q.target}));
      expect(c.questReady(q), isTrue);
      await c.reportQuest(r, q);
      expect(c.allyQuestDone(StoryAlly.barkan), isTrue);
      expect(c.allyQuestDone(StoryAlly.lian), isTrue);
    });
  });

  group('3막 끝 · 자유 이동 · 심층', () {
    test('아우렐 등불(오르벤 두 모습) → 큰 고르기 → 3막 끝 → 칭호 · 자유 이동 · 심층', () async {
      final r = RegionRules.aurel;
      var c = await inRegion(r, more: {
        'aurel:arrive', 'aurel:first', 'aurel:talk', 'aurel:event',
        for (final x in RegionRules.all) 'reach:${x.prefix}',
      });
      expect(c.regionDungeonOpen(r), isTrue);
      expect(c.regionChoicePending(r), isFalse, reason: '아우렐은 등불 뒤에 고름');
      for (var k = 0; k < 5 && c.regionFloorBest(r) < 5; k++) {
        c = await full(c);
        await clearDungeonTo(c, r, c.regionFloorBest(r) + 1);
      }
      expect(c.regionLit(Region.aurel), isTrue);
      expect(c.regionChoicePending(r), isTrue);
      expect(c.act3EndPending, isFalse);
      await c.chooseRegion(r, r.choice.b);
      expect(c.act3EndPending, isTrue);
      expect(c.canTravelTo(Region.baldrin), isFalse);
      await c.finishAct3Story();
      expect(c.act3Done, isTrue);
      expect(c.canTravelTo(Region.baldrin), isTrue);
      expect(await c.travelTo(Region.elowin), isTrue);
      expect(c.regionNow, same(RegionRules.elowin));
      final again = (await b52.start(c.store as InMemoryRecordStore)).$1;
      expect(again.history.last.counters[TitleRules.skyCounter(TitleId.fiveLamps)], 1);
      expect(again.act3NpcLines(Npc.marta), contains(RegionRules.martaAfterEnd));
      // 심층: 5층을 끝내면 6층으로 (3막 뒤)
      c = await reload(again, (s) => s.copyWith(region: Region.aurel.index, prog: {
            ...s.prog, 'aurel:floorNow': 5,
          }));
      for (final e in c.regionEnterFloor(r)!) {
        await b53.fight(c, e);
      }
      await c.regionClearFloor(r);
      expect(c.regionFloorNow(r), RegionRules.deepStart);
      expect(c.regionFloor(r, 10).boss, isTrue);
      expect(c.regionFloor(r, 7).name, '심층 7층');
      final deep = c.regionEnterFloor(r)!;
      for (final e in deep) {
        await b53.fight(c, e);
      }
      await c.regionClearFloor(r);
      expect(c.regionDeepBest(r), RegionRules.deepStart);
      await c.leaveDeep(r);
      expect(c.regionFloorNow(r), 1);
    });

    test('예전 3막 기록(지역 1)은 그대로 · 지역 2~5 기록이 없어도 열림 (#124)', () async {
      final c = await b53.opened();
      expect(c.regionNow, isNull);
      expect(c.act3Done, isFalse);
      expect(c.regionReached(Region.selenia), isFalse);
      expect(c.lampMonsters, isEmpty);
      expect(c.uniqueBook, hasLength(1));
      expect(Act3State.fromJson(c.act3.toJson()).flags, c.act3.flags);
    });
  });

  group('화면', () {
    testWidgets('셀레니아 마을: 주민 넷 · 흑등 상회 빛 가게(등불 전) · 의뢰판', (tester) async {
      late AppController c;
      await tester.runAsync(() async {
        c = await inRegion(RegionRules.selenia, more: {'selenia:arrive', 'selenia:first'});
      });
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => TopNoticeHost(child: child!),
          home: RegionTownScreen(controller: c, region: RegionRules.selenia)));
      await tester.pump();
      for (final p in RegionRules.selenia.residents) {
        expect(find.byKey(Key('resident_${p.id}')), findsOneWidget);
      }
      await tester.scrollUntilVisible(find.byKey(const Key('townBoard')), 300);
      expect(find.text('흑등 상회 빛 가게'), findsOneWidget);
      expect(find.byKey(const Key('townAuction')), findsNothing);
      await tester.scrollUntilVisible(find.byKey(const Key('resident_eni')), -300);
      await tester.tap(find.byKey(const Key('resident_eni')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('regionTalk')), findsOneWidget);
    });
  });
}
