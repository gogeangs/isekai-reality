// 묶음 63: 개인정보 처리방침 4판 — 다시 동의 없이 알림만 (적용 = 빌드 날 + 7일) · /privacy 같은 글

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/mail_state.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/storage/record_store.dart';

import 'batch52_test.dart' as b52;
import 'batch56_test.dart' as b56;

void main() {
  setUp(() => b56.now = b52.t0);

  test('4판은 알림만: 3판에 동의했으면 적용 뒤에도 다시 묻지 않음 · 처음이면 4판에 동의', () {
    final v4 = LegalRules.history.last;
    expect((v4.kind, v4.version, v4.noticeOnly), (LegalKind.privacy, 4, true));
    expect(v4.effective, DateTime(2026, 11, 25), reason: '빌드 날 11-18 + 7일');
    expect(v4.noticeFrom, DateTime(2026, 11, 18));
    expect(v4.summary, contains('Play Integrity'));
    final before = DateTime(2026, 11, 20, 12), after = DateTime(2026, 11, 26, 12);
    // 알림 기간: 곧 바뀌는 문서로 보임
    expect(LegalRules.notices(before).map((v) => v.key), ['privacy@4']);
    expect(LegalRules.current(LegalKind.privacy, after).version, 4);
    final agreed3 = {LegalKind.terms: 2, LegalKind.privacy: 3, LegalKind.location: 2, LegalKind.operation: 2};
    expect(LegalRules.needed(agreed3, after), isEmpty);
    // 3판 전(2판)에 동의한 사람은 3판 때문에 다시 묻고, 글은 4판
    final agreed2 = {...agreed3, LegalKind.privacy: 2};
    expect(LegalRules.needed(agreed2, after).single.version, 4);
    // 처음 시작은 지금 판에 동의
    expect(LegalRules.needed({}, after).firstWhere((v) => v.kind == LegalKind.privacy).version, 4);
  });

  test('앱 안 글 = 정책 문서 4판 · 웹 /privacy 같은 글', () {
    final p = File('assets/legal/privacy.txt').readAsStringSync();
    for (final w in [
      '서버 기능(파티 · 문의 · 거래소 · 순위 · 길드 · 공성전 · 부정 이용 막기) 실행',
      'Google LLC (Play Integrity) · Apple Inc. (DeviceCheck · App Attest): 진짜 앱 확인(정식 앱 · 정상 기기인지 확인, 로그인하고 서버 기능을 쓸 때)',
      '앱 · 기기 확인 값(계정 정보 · 위치 · 걸음은 보내지 않음) — 미국 등',
      '국외 이전은 로그인 · 진짜 앱 확인 · 광고를 이용할 때',
      '거래 시각, 거래 지갑 금화 — 회사 서버(서울)',
      '2026년 11월 25일부터 적용',
    ]) {
      expect(p, contains(w), reason: w);
    }
    expect(p, isNot(contains('(생기면)')));
    final j = jsonDecode(File('firebase/functions/src/legal_texts.json').readAsStringSync()) as Map;
    expect(j['privacy'], p);
  });

  test('알림 우편: 다시 동의 문장 없이 바뀌는 점만 · 적용 뒤 동의 창 안 뜸', () async {
    b56.now = DateTime(2026, 11, 18, 18);
    final (c0, _) = await b56.start(login: false);
    await c0.store.saveJson('consent', {
      'docs': {
        'terms': {'v': 2, 'at': '2026-11-18T10:00:00.000'},
        'privacy': {'v': 3, 'at': '2026-11-18T10:00:00.000'},
        'location': {'v': 2, 'at': '2026-11-18T10:00:00.000'},
        'operation': {'v': 2, 'at': '2026-11-18T10:00:00.000'},
      },
      'age14': '2026-11-17T10:00:00.000',
    });
    final (c, _) = await b56.start(login: false, store: c0.store as InMemoryRecordStore);
    await c.checkLegalNotices();
    final m = c.mail.mails.firstWhere((x) => x.id == 'legal_privacy@4');
    expect(m.kind, MailKind.notice);
    expect(m.body, contains('2026년 11월 25일부터'));
    expect(m.body, contains('진짜 앱 확인'));
    expect(m.body, isNot(contains('다시 동의')));
    expect(c.legalBanner?.key, 'privacy@4');
    c.consentGate = true;
    expect(c.consentNeeded, isEmpty);
    b56.now = DateTime(2026, 11, 26, 9);
    final (c2, _) = await b56.start(login: false, store: c.store as InMemoryRecordStore);
    c2.consentGate = true;
    expect(c2.consentNeeded, isEmpty);
  });
}
