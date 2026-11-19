// 묶음 47: #239 게시판 포기 버튼 · #240 가방 가득 · #241 슬라임 셈 · #237 길드 → 조합

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/armory.dart';
import 'package:isekai_reality/core/models/bag_state.dart';
import 'package:isekai_reality/core/models/board_state.dart';
import 'package:isekai_reality/core/models/mail_state.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/features/village/board_screen.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'support/npc_seed.dart';
import 'support/smithy_seed.dart';

/// 재료마다 99개 (한 칸 가득) → 가방이 가득하고 쌓을 자리도 없다
Map<String, int> get _full99 => {for (final m in MaterialId.values) m.name: 99};

/// 재료마다 1개 → 가방이 가득하지만 같은 재료는 쌓인다
Map<String, int> get _full1 => {for (final m in MaterialId.values) m.name: 1};

MailItem _mail(String id, Map<String, int> gifts, {List<EquipItem> equips = const []}) =>
    MailItem(
      id: id,
      kind: MailKind.letter,
      from: MailRules.operator,
      title: '시험 우편',
      gifts: gifts,
      equips: equips,
      sentAt: t0,
    );

void main() {
  group('#240 저장 형식 (예전 기록 그대로)', () {
    test('가방 기록: hold 칸이 없으면 비어 있음 · 오가며 그대로', () {
      final old = BagState.fromJson(const {'goldExpansions': 1, 'singleSlots': 2});
      expect(old.hold, isEmpty);
      expect(old.toJson().containsKey('hold'), isFalse);
      final back = BagState.fromJson(
          old.copyWith(hold: {'herb': 3, 'item:healSmall': 1}).toJson());
      expect(back.hold, {'herb': 3, 'item:healSmall': 1});
      expect(back.singleSlots, 2);
    });

    test('우편: equips 칸이 없어도 읽음 · 장비를 맡겨도 오가며 그대로', () {
      final m = MailItem.fromJson(_mail('a', const {'gold': 1}).toJson()
        ..remove('equips'))!;
      expect(m.equips, isEmpty);
      const eq = EquipItem(uid: 'eq9', base: EquipBase.martaScarf, grade: EquipGrade.white);
      final back = MailItem.fromJson(_mail('b', const {}, equips: [eq]).toJson())!;
      expect(back.equips.single.base, EquipBase.martaScarf);
      expect(back.hasGifts, isTrue);
    });
  });

  group('#240 가방이 가득 찼을 때', () {
    test('들어가지 않는 재료는 금화로 바뀌지 않고 「가방이 가득 찼어요」 창으로', () async {
      final c = await startNpc(level: 8, mats: _full99);
      expect(c.bagFree, 0);
      final gold = c.player.gold;
      final fit = await c.admitBagForTest(const {'herb': 3, 'item:healSmall': 2});
      expect(fit, isEmpty);
      expect(c.player.gold, gold); // 금화로 바꾸지 않음
      expect(c.hasBagHold, isTrue);
      expect(c.bagHoldNew, isTrue);
      expect({for (final e in c.bagHoldList) e.key: e.count},
          {'herb': 3, 'item:healSmall': 2});
      // 이미 칸을 넘긴 가방은 그대로, 새로 넘치지 않음
      expect(c.player.materialExact(MaterialId.herb), 99);
      expect(c.bagCount(ShopItem.healSmall), 0);
    });

    test('같은 재료 칸에 쌓을 자리가 있으면 그만큼은 들어감', () async {
      final c = await startNpc(level: 8, mats: _full1);
      final fit = await c.admitBagForTest(const {'herb': 5, 'item:healSmall': 1});
      expect(fit, {'herb': 5});
      expect(c.player.materialExact(MaterialId.herb), 6);
      expect({for (final e in c.bagHoldList) e.key: e.count}, {'item:healSmall': 1});
    });

    test('알·공방 물약(팔 수 없는 것)은 창이 아니라 우편함에', () async {
      final c = await startNpc(level: 12, mats: _full99);
      await c.admitBagForTest(const {'egg': 1, 'alc:healBig': 2, 'herb': 1});
      expect({for (final e in c.bagHoldList) e.key: e.count}, {'herb': 1});
      final m = c.giftMails.firstWhere((m) => m.id.startsWith('bag_'));
      expect(m.gifts, {'egg': 1, 'alc:healBig': 2});
      expect(m.expiresAt, isNull); // 사라지지 않음
      expect(c.takeBagMailed(), 2);
    });

    test('의뢰·이야기 보상은 창 없이 모두 우편함에', () async {
      final c = await startNpc(level: 8, mats: _full99);
      await c.admitBagForTest(const {'herb': 2, 'item:spareKey': 1}, toMail: true);
      expect(c.hasBagHold, isFalse);
      final m = c.giftMails.firstWhere((m) => m.id.startsWith('bag_'));
      expect(m.gifts, {'herb': 2, 'item:spareKey': 1});
    });

    test('창: 바로 판매(잡화상 파는 값) · 버리기 · 모두 판매', () async {
      final c = await startNpc(level: 8, mats: _full99, json: {
        'bag': const BagState(hold: {'herb': 3, 'item:healSmall': 2, 'ironShard': 4}).toJson(),
      });
      expect(c.bagHoldList, hasLength(3));
      final g0 = c.player.gold;
      final got = await c.sellHold('herb');
      expect(got, 3 * BagRules.materialPrice(MaterialId.herb));
      expect(c.player.gold, g0 + got);
      await c.discardHold('item:healSmall');
      expect(c.bagHoldList.map((e) => e.key), ['ironShard']);
      final all = await c.sellAllHold();
      expect(all, 4 * BagRules.materialPrice(MaterialId.ironShard));
      expect(c.hasBagHold, isFalse);
    });

    test('가방을 정리한 뒤 「다시 받기」: 들어가는 만큼 넣고 나머지는 남김', () async {
      final c = await startNpc(level: 8, json: {
        'bag': const BagState(hold: {'herb': 3, 'item:healSmall': 2}).toJson(),
      });
      expect(c.bagFree, greaterThan(1));
      final h0 = c.player.materialCount(MaterialId.herb);
      expect(await c.retryHold(), 0);
      expect(c.player.materialCount(MaterialId.herb), h0 + 3);
      expect(c.bagCount(ShopItem.healSmall), 2);
      expect(c.hasBagHold, isFalse);
    });

    test('우편: 가방에 안 들어가는 것은 우편에 남기고, 자리가 나면 마저 받음', () async {
      final c = await startNpc(level: 12, mats: _full99, json: {
        'mail': MailState(mails: [
          _mail('m1', const {'gold': 100, 'item:healSmall': 2, 'egg': 1},
              equips: const [
                EquipItem(uid: 'eq90', base: EquipBase.martaScarf, grade: EquipGrade.white)
              ]),
        ], sent: const ['m1']).toJson(),
      });
      final g0 = c.player.gold;
      final got = await c.claimMail('m1');
      expect(got, contains('우편에 남겨 뒀어요'));
      expect(c.player.gold, g0 + 100);
      var m = c.mail.mails.firstWhere((m) => m.id == 'm1');
      expect(m.hasGifts, isTrue);
      expect(m.gifts, {'item:healSmall': 2, 'egg': 1}); // 금화는 받았으니 다시 주지 않음
      expect(m.equips, hasLength(1));
      // 자리를 만든다 (재료 몇 가지를 버림)
      final need = c.bagUsed - c.bagCapacity + 3;
      var k = 0;
      for (final mat in MaterialId.values) {
        if (k >= need) break;
        await c.discardMaterial(mat, 99);
        k++;
      }
      expect(c.bagFree, greaterThanOrEqualTo(3));
      await c.claimMail('m1');
      m = c.mail.mails.firstWhere((m) => m.id == 'm1');
      expect(m.claimed, isTrue);
      expect(c.player.gold, g0 + 100);
      expect(c.bagCount(ShopItem.healSmall), 2);
      expect(c.pets.eggs, hasLength(1));
      expect(c.armory.items.any((e) => e.uid == 'eq90'), isTrue);
    });
  });

  group('#241 · #237', () {
    test('슬라임 부탁은 속성 슬라임까지 셈 · 도르군 4 할 일 글', () {
      expect(NpcTally.slimeKill(MonsterId.ashSlime), isTrue);
      expect(NpcTally.slimeKill(MonsterId.fireSlime), isTrue);
      expect(NpcTally.slimeKill(MonsterId.poisonSlime), isTrue);
      expect(NpcTally.slimeKill(MonsterId.giantRat), isFalse);
      final steps = [
        for (final r in NpcRules.requests)
          if (r.npc == Npc.dorgun)
            for (final s in r.steps) s.label,
      ];
      expect(steps, contains('슬라임 2마리 잡기'));
      expect(steps.any((s) => s.contains('잿빛')), isFalse);
    });

    test('「길드」 → 「조합」 (화면 글자)', () {
      expect(VillageRules.facilityName('guild'), '조합');
      expect(VillageRules.npc(Npc.sera).role, '조합장');
      expect(TitleRules.info(TitleId.tradeMaster).name, '조합의 해결사');
      expect(JobRules.awakenLine, contains('조합'));
      for (final n in Npc.values) {
        final info = VillageRules.npc(n);
        expect(info.first.contains('길드'), isFalse, reason: n.name);
        for (final lines in info.lines.values) {
          for (final l in lines) {
            expect(l.contains('길드'), isFalse, reason: n.name);
          }
        }
      }
    });
  });

  testWidgets('#239 상세 창: 인장은 이름 옆, 「포기」는 또렷이 · 누르면 확인 창', (tester) async {
    tester.view.physicalSize = const Size(750, 1334);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    late AppController c;
    await tester.runAsync(() async => c = await startNpc(
          level: 15,
          json: {
            'board': const BoardState(day: '2026-11-16', seq: 2, slots: [
              ErrandSlot(templateId: 'npc_hart_0', accepted: true, baseline: 0),
              ErrandSlot(templateId: 'npc_mina_1'),
            ]).toJson(),
          },
        ));
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => TopNoticeHost(child: child!),
        home: BoardScreen(controller: c)));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.tap(find.byKey(const Key('boardTab_errand')));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    final sc = find.byKey(const Key('boardScroll_errand'));
    await tester.scrollUntilVisible(find.byKey(const Key('errandNote_0')), 200,
        scrollable: find.descendant(of: sc, matching: find.byType(Scrollable)).first);
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.tap(find.byKey(const Key('errandNote_0')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    final seal = find.byKey(const Key('detailSeal'));
    final quit = find.byKey(const Key('errandAbandon_0'));
    expect(seal, findsOneWidget);
    expect(quit, findsOneWidget);
    final a = tester.getRect(seal);
    final b = tester.getRect(quit);
    expect(a.overlaps(b), isFalse);
    expect(a.top, lessThan(b.top)); // 인장은 위쪽(이름 옆)
    // 누르면 확인 창 → 포기하기
    await tester.tap(quit);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byKey(const Key('errandAbandonYes')), findsOneWidget);
    expect(c.board.slots[0].accepted, isTrue); // 아직 그대로
    await tester.tap(find.byKey(const Key('errandAbandonYes')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(c.board.slots[0].accepted, isFalse);
    await tester.pump(const Duration(seconds: 9));
  });
}
