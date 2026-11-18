// 묶음 64: Play · App Store 심사용 계정 기록 만들기 (flutter test tool/make_review_record_test.dart)
// → firebase/functions/scripts/review_record.json (앱 백업과 같은 모양, 위치 없음)
// 5막 1~3장 · 길드 · 거래소에 올릴 재료 · 금화. 서버 쪽(길드 · 영지 · 지갑 · 파티)은 scripts/review_seed.js 가 넣음
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/act5_state.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/cloud/backup_scrub.dart';
import 'package:isekai_reality/data/storage/record_store.dart';

import '../test/batch52_test.dart' as b52;
import '../test/batch56_test.dart' as b56;
import '../test/batch59_test.dart' as b59;
import '../test/batch60_test.dart' as b60;

void main() {
  test('심사용 기록', () async {
    b56.now = b52.t0;
    final (c0, _) = await b59.act4(level: 38, state: b60.act4Done.copyWith(lian: false), login: false);
    await c0.store.saveJson(
        'act5',
        const Act5State(
          opened: true,
          chapter: 3,
          seen: {'e1a', 'e1b', 'e1c', 'e2a', 'e2b'},
          chapterSteps: 0,
          ticketAt: -16000, // 앱만으로도 공성권 8장 (서버가 다시 맞춤)
          wildWins: 4,
          pioneered: true,
        ).toJson());
    final t = c0.history.last;
    await c0.store.upsert(t.copyWith(
        gains: DailyRecord.addCounts(t.gains, {
      Wallet.gold: 6000,
      MaterialId.herb.name: 15,
      MaterialId.hardWood.name: 10,
      MaterialId.ironShard.name: 10,
      MaterialId.slimeJelly.name: 20,
    })));
    final (c, _) = await b56.start(store: c0.store as InMemoryRecordStore, login: false);
    // 심사 때 쓰는 판 (처리방침 4판까지) 에 동의한 기록
    await c.agreeLegal(LegalRules.needed(const {}, DateTime(2026, 12, 1)));
    await c.agreeBackup();
    await c.markPartyNotice();
    await c.markMarketIntro();
    expect(c.act5Open, isTrue);
    expect(c.player.level.level, greaterThanOrEqualTo(38));
    final snap = BackupScrub.scrub(await c.store.exportAll());
    File('firebase/functions/scripts/review_record.json').writeAsStringSync(jsonEncode({
      'level': c.player.level.level,
      'lastDay': c.history.last.dayKey,
      'snapshot': snap,
    }));
  });
}
