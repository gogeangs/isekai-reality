// 묶음 64: 심사용 계정 기록 · 처음 각성 화면에서 「다른 휴대폰에서 하던 기록 불러오기」

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/cloud/backup_server.dart';
import 'package:isekai_reality/data/cloud/cloud_auth.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/awakening/awakening_screen.dart';

import 'batch52_test.dart' as b52;

Map<String, Object> _snap() {
  final j = jsonDecode(File('firebase/functions/scripts/review_record.json').readAsStringSync()) as Map;
  return {
    for (final e in (j['snapshot'] as Map).entries)
      '${e.key}': e.value is List ? [for (final x in e.value as List) '$x'] : '${e.value}',
  };
}

void main() {
  test('심사용 기록: 새 휴대폰에서 로그인하면 바로 5막 1~3장 · 재료 · 금화로 이어짐', () async {
    final server = FakeBackupServer()..time = b52.t0.toUtc();
    final j = jsonDecode(File('firebase/functions/scripts/review_record.json').readAsStringSync()) as Map;
    await server.upload('u1', 't', _snap(), level: j['level'] as int, lastDay: j['lastDay'] as String);
    final c = AppController(
      store: InMemoryRecordStore(),
      health: FakeHealthSource(),
      clock: () => DateTime(2026, 12, 1, 10),
      random: math.Random(1),
    )
      ..mailSources = const []
      ..cloudAuth = FakeCloudAuth()
      ..backupServer = server;
    await c.init();
    expect(c.needsAwakening, isTrue);
    expect(await c.signInCloud(LoginProvider.google), CloudLogin.restored);
    expect(c.needsAwakening, isFalse);
    expect(c.act5Open, isTrue);
    expect(c.act5.chapter, 3);
    expect(c.player.level.level, greaterThanOrEqualTo(38));
    expect(c.player.gold, greaterThanOrEqualTo(6000));
    expect(c.marketOwn(MarketKind.mat).length, greaterThanOrEqualTo(3));
    c.consentGate = true;
    expect(c.consentNeeded, isEmpty, reason: '약관 동의가 기록에 들어 있음');
  });

  test('심사용 기록 · 준비 스크립트가 같은 기록을 씀 (위치 없음)', () {
    final s = File('firebase/functions/scripts/review_record.json').readAsStringSync();
    expect(s, isNot(contains('"lat"')));
    expect(File('firebase/functions/scripts/review_seed.js').readAsStringSync(), contains("require('./review_record.json')"));
    final wf = File('.github/workflows/review-seed.yml').readAsStringSync();
    expect(wf, contains('workflow_dispatch'));
    expect(wf, contains('rm -f'));
  });

  testWidgets('처음 각성 화면: 「다른 휴대폰에서 하던 기록이 있어요」 버튼', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    var asked = 0;
    await tester.pumpWidget(MaterialApp(
      home: AwakeningScreen(
        onAwaken: (_, __, ___, ____) async {},
        now: () => DateTime(2026, 12, 1),
        onLoadRecord: (_) async => asked++,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('건너뛰기 ›'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('물의 정령'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('이 정령과 함께하기'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('이 정령과 함께하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('확정'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('이 이름으로'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('이 이름으로'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('확정'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('awakenLoadRecord')), findsNothing, reason: '약관 동의 뒤 이름 칸에서');
    await tester.tap(find.byKey(const Key('consentAll')).first);
    await tester.ensureVisible(find.byKey(const Key('birthYear')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('birthYear_2000')));
    await tester.pump();
    await tester.scrollUntilVisible(find.text('동의하고 다음'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('동의하고 다음'));
    await tester.pump();
    await tester.scrollUntilVisible(find.byKey(const Key('awakenLoadRecord')), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('awakenLoadRecord')));
    await tester.pump();
    expect(asked, 1);
  });
}
