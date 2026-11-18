// 묶음 65 (1/2): 화면 고침 5건 · 공성전 다듬기 (#251) — 앱 흐름 (서버 판정은 node 시험 siege65.test.js)

import 'dart:io';

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/act5_state.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/features/act5/erbard_screens.dart';
import 'package:isekai_reality/features/village/board_parchment.dart';
import 'package:isekai_reality/features/village/village_screen.dart';
import 'package:isekai_reality/theme/ornaments.dart';

import 'batch52_test.dart' as b52;
import 'batch56_test.dart' as b56;
import 'batch60_test.dart' as b60;

const _ch3 = Act5State(opened: true, chapter: 3, seen: {'e1a', 'e1b', 'e1c', 'e2a', 'e2b'}, ticketAt: -60000);

void main() {
  setUp(() => b56.now = b52.t0);

  group('1 화면 고침', () {
    testWidgets('#253 양피지: 그림 비율 2:1 그대로 (모서리 · 찢긴 테두리가 다 보임)', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Center(child: ParchmentSheet(width: 340, child: Text('저편의 빛이 다하는 날, 그 나라의 왕이 일어서리라.'))),
      ));
      expect(tester.getSize(find.byType(ParchmentSheet)), const Size(340, 170));
      for (final f in ['lib/features/harvest/harvest_sheet.dart', 'lib/features/act2/ash_battle_screen.dart']) {
        final src = File(f).readAsStringSync();
        expect(src, contains('ParchmentSheet('), reason: f);
        expect(src, isNot(contains('centerSlice: const Rect.fromLTRB(110, 92, 690, 308)')), reason: f);
      }
    });

    test('#256 막기: 막지 못한 강한 공격 표시 · 그림 3장 · 막기 안내는 「막았다!」 뒤에', () {
      final src = File('lib/features/battle/battle_view.dart').readAsStringSync();
      for (final a in ['fx_guard.webp', 'fx_guardHit.webp', 'fx_guardBreak.webp']) {
        expect(src, contains(a));
        expect(File('assets/images/$a').existsSync(), isTrue, reason: a);
      }
      expect(src, contains("if (widget.warning != null && !(widget.guard != null && !idle))"));
      expect(src, contains('top: math.max(monTop - 46, 50.0)'), reason: 'BOSS 표 아래로');
    });

    test('#258 약초밭 · 훈련장은 말뚝 공터 가운데 (길 위에서 옮김) · #259 게시판 장식 고정 높이', () {
      FacilityInfo f(Facility x) => VillageScreen.facilities.firstWhere((i) => i.facility == x);
      expect(f(Facility.garden).spot, (x: 342.0, y: 728.0, w: 140.0));
      expect(f(Facility.training).spot, (x: 1272.0, y: 745.0, w: 140.0));
      expect(WoodBoard.fixedTop, greaterThanOrEqualTo(330));
      expect(WoodBoard.fixedBottom, greaterThanOrEqualTo(240));
      expect(WoodBoard.artTop, 220, reason: '내용 시작 자리는 그대로');
    });
  });

  group('2 공성전 다듬기', () {
    test('집결 깃발 · 엿보기 · 상성 · 공성 망치 · 집결 강화가 싸움에 들어감', () async {
      final (c, a) = await b60.act5(guild: true, state: _ch3);
      await c.awakenJob(JobId.mage);
      a.siegeActive = true;
      a.siegeOwners['dor_wind'] = {'gid': 'other', 'name': '노을', 'emblem': 1, 'color': 1};
      b56.now = DateTime(2026, 11, 28, 10);
      await c.refreshErbard();
      expect(await c.setRally('dor_wind'), isTrue);
      expect(c.erbard.rally?.estate, 'dor_wind');
      expect(c.takeRallyNotice(c.erbard.siegeNo, 'dor_wind'), isTrue);
      expect(c.takeRallyNotice(c.erbard.siegeNo, 'dor_wind'), isFalse, reason: '한 번만');
      // 엿보기: 직업 그림 · 동료 수 · 상성 한 줄
      final p = (await c.peekEstate('dor_wind'))!;
      expect(p.map((x) => x.monster), [MonsterId.cloneMage, MonsterId.cloneArcher, MonsterId.cloneKnight, null, null]);
      expect(p.first.allies, 2);
      expect(c.weakLine(MonsterId.cloneMage), '이 자리는 도적 · 궁수에게 약해 보여요');
      // 상성: 마법사 주 직업 → 전사 분신에 강함
      expect(c.siegeWeakness(MonsterId.cloneWarrior), 1.0);
      expect(c.siegeWeakness(MonsterId.cloneMage), 0.0);
      // 공성 망치로 흔들린 첫 자리 + 집결 깃발 영지
      a.siegeWeak['dor_wind'] = [0];
      final weak = (await c.startErbardFight(ErbardRules.estate('dor_wind')!))!;
      final hpWeak = weak.foe.maxHp;
      expect(weak.dealMult, closeTo(1 + ErbardRules.rallyBonus, 1e-9), reason: '마법사 vs 마법사 분신: 상성 없음, 집결만');
      b60.win(weak);
      await c.finishErbardFight(weak);
      a.siegeWeak.clear();
      a.siegeRun['dor_wind'] = [];
      final normal = (await c.startErbardFight(ErbardRules.estate('dor_wind')!))!;
      expect(hpWeak, lessThan(normal.foe.maxHp), reason: '흔들린 자리는 약함');
    });

    test('마지막 6시간 · 게이지 · 전황 · 소식 · 성벽 보수 영지', () async {
      final (c, a) = await b60.act5(guild: true, state: _ch3);
      a.siegeActive = true;
      a.siegeOwners['sol_lily'] = {'gid': 'mine', 'name': '새벽걸음', 'emblem': 0, 'color': 0};
      a.gauge = {'progress': 0.4, 'full': 1, 'rams': 1, 'ramMax': 2, 'repairs': ['sol_lily']};
      a.siegeDefense['sol_lily'] = 2;
      a.siegeNews.add({'at': DateTime.utc(2026, 11, 28, 2).millisecondsSinceEpoch, 'text': '우리 영지 백합 들판 성가 공격받고 있어요'});
      b56.now = DateTime(2026, 11, 28, 10);
      await c.refreshErbard();
      expect(c.siegeFinal, isFalse);
      expect(c.erbard.gauge!.rams, 1);
      expect(c.erbard.defense['sol_lily'], 2);
      expect(c.erbard.news.single.text, contains('공격받고'));
      expect(await c.setRepairTarget('sol_lily'), isTrue);
      expect(c.erbard.gauge!.repairTarget, 'sol_lily');
      b56.now = DateTime(2026, 11, 29, 19); // 일요일 19시
      expect(c.siegeFinal, isTrue);
      expect(c.takeFinalNotice(0), isTrue);
      expect(c.takeFinalNotice(0), isFalse);
      // 길드 게시판에도 소식
      await c.refreshGuild();
      expect(c.guild!.news.single.text, contains('공격받고'));
    });

    test('선봉장: 우편 op → 칭호, 다음 공성전 끝까지', () async {
      final (c, a) = await b60.act5(guild: true, state: _ch3);
      b56.now = DateTime(2026, 11, 30, 10);
      a.inbox.add({'id': 'v0', 'from': '세라', 'title': '제1회 깃발 공성전 선봉장', 'reward': <String, int>{}, 'equips': [], 'op': {'vanguard': 0}});
      await c.checkInquiryInbox();
      final m = c.mail.mails.firstWhere((x) => x.title.contains('선봉장'));
      await c.claimMail(m.id);
      await c.sync();
      expect(c.player.titles, contains(TitleId.vanguard));
      expect(File('assets/images/title_vanguard.webp').existsSync(), isTrue);
      // 다음 공성전(제2회)이 끝나면 사라짐
      final hist = [for (final d in c.history) d];
      hist.add(DailyRecord(date: DateTime(2026, 12, 14)));
      expect(TitleRules.earned(hist, 40), isNot(contains(TitleId.vanguard)));
      hist.removeLast();
      hist.add(DailyRecord(date: DateTime(2026, 12, 13)));
      expect(TitleRules.earned(hist, 40), contains(TitleId.vanguard));
    });

    testWidgets('결과 장면: 그림 · 깃발 · 누르면 닫힘', (tester) async {
      late AppController c;
      await tester.runAsync(() async {
        final r = await b60.act5(guild: true, state: _ch3);
        c = r.$1;
        r.$2.siegeOwners['sol_lily'] = {'gid': 'mine', 'name': '새벽걸음', 'emblem': 0, 'color': 0};
        r.$2.siegeLast = {
          'no': 0,
          'royal': {'gid': 'npc', 'name': '흑등 연맹'},
          'changes': [
            {'estate': 'sol_lily', 'fromName': '흑등 연맹', 'toName': '새벽걸음'},
          ],
        };
        b56.now = DateTime(2026, 11, 30, 10);
        await c.refreshErbard();
      });
      await tester.pumpWidget(MaterialApp(home: SiegeResultScene(controller: c)));
      await tester.pump(const Duration(milliseconds: 2500));
      expect(find.text('제1회 깃발 공성전이 끝났어요'), findsOneWidget);
      expect(File(ErbardRules.resultScene).existsSync(), isTrue);
    });
  });
}
