// 묶음 57: 약관·동의 · 직업 개편 · 1막 다듬기 · 파티 마무리 · 전설 펫 · 3막 지역 2~5

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/cloud/cloud_auth.dart';
import 'package:isekai_reality/features/legal/consent_screen.dart';
import 'package:isekai_reality/features/settings/account_section.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'batch52_test.dart' as b52;
import 'batch56_test.dart' as b56;

Widget host(Widget home) =>
    MaterialApp(builder: (context, child) => TopNoticeHost(child: child!), home: home);

void main() {
  setUp(() {
    b56.now = b52.t0;
    LegalRules.testHistory = null;
  });
  tearDown(() => LegalRules.testHistory = null);

  group('약관 · 동의', () {
    // 묶음 60: 2판이 생겼으니 이 시험은 1판만 있던 때로 본다
    final v1 = [for (final v in LegalRules.history) if (v.version == 1) v];
    setUp(() => LegalRules.testHistory = v1);
    test('판 · 적용일 · 알림 기간 · 다시 동의는 바뀐 문서만', () {
      final t = DateTime(2026, 11, 18);
      expect(LegalRules.needed(const {}, t).map((v) => v.kind),
          [LegalKind.terms, LegalKind.privacy, LegalKind.location]);
      final ok = {LegalKind.terms: 1, LegalKind.privacy: 1, LegalKind.location: 1};
      expect(LegalRules.needed(ok, t), isEmpty);
      LegalRules.testHistory = [
        ...v1,
        LegalVersion(LegalKind.privacy, 2, DateTime(2026, 12, 1)),
        LegalVersion(LegalKind.terms, 2, DateTime(2027, 1, 1), unfavorable: true),
      ];
      // 12-1 의 7일 전부터 알림, 1-1 은 30일 전부터
      expect(LegalRules.notices(DateTime(2026, 11, 23)), isEmpty);
      expect(LegalRules.notices(DateTime(2026, 11, 24)).map((v) => v.key), ['privacy@2']);
      expect(LegalRules.notices(DateTime(2026, 12, 2)).map((v) => v.key), ['terms@2']);
      // 적용일이 지나면 바뀐 문서만 다시
      expect(LegalRules.needed(ok, DateTime(2026, 12, 1)).map((v) => v.key), ['privacy@2']);
      expect(LegalRules.needed(ok, DateTime(2027, 1, 1)).map((v) => v.key), ['terms@2', 'privacy@2']);
    });

    test('동의 기록 저장 · 다시 읽기 · 바뀜 알림 우편 한 번', () async {
      final store = b52.account();
      final (c, _) = await b56.start(store: store, login: false);
      c.consentGate = true;
      expect(c.consentNeeded, hasLength(3));
      expect(c.consentAskAge, isTrue);
      await c.agreeLegal(c.consentNeeded);
      expect(c.consentNeeded, isEmpty);
      final saved = await store.loadJson('consent');
      expect((saved!['docs'] as Map).keys, containsAll(['terms', 'privacy', 'location']));
      expect(saved['age14'], isNotNull);

      LegalRules.testHistory = [
        ...v1,
        LegalVersion(LegalKind.location, 2, DateTime(2026, 11, 20), summary: '함께 있어요 안내를 더했어요'),
      ];
      await c.checkLegalNotices();
      await c.checkLegalNotices();
      expect(c.mail.mails.where((m) => m.id == 'legal_location@2'), hasLength(1));
      expect(c.legalBanner?.key, 'location@2');
      await c.dismissLegalBanner(c.legalBanner!);
      expect(c.legalBanner, isNull);
      // 적용일 뒤 → 위치 약관만 다시
      b56.now = DateTime(2026, 11, 20, 9);
      expect(c.consentNeeded.map((v) => v.key), ['location@2']);
      expect(c.consentAskAge, isFalse);
    });

    test('기록 지키기: Lv.3 에 한 번, 로그인 안 했으면 Lv.8 에 한 번 더', () async {
      final (c, _) = await b56.start(login: false);
      expect(c.loginAskFor(2, 3), 3);
      await c.markLoginAsked(3);
      expect(c.loginAskFor(2, 3), isNull);
      // 묶음 70 #291: Lv.8은 친구 장면이 「기록 지키기」를 함께 물음
      expect(c.loginAskFor(7, 8), isNull);
      final (d, _) = await b56.start();
      expect(d.loginAskFor(2, 3), isNull, reason: '로그인했으면 묻지 않음');
    });

    testWidgets('동의 창: 모두 동의 + 만 14세 → 동의하고 시작', (tester) async {
      late AppController c;
      await tester.runAsync(() async => c = (await b56.start(login: false)).$1);
      c.consentGate = true;
      await tester.pumpWidget(host(ConsentScreen(controller: c)));
      await tester.pump();
      expect(find.byKey(const Key('consent_terms')), findsOneWidget);
      expect(find.byKey(const Key('consentView_privacy')), findsOneWidget);
      final agree = find.byKey(const Key('consentAgree'));
      await tester.tap(find.descendant(of: find.byKey(const Key('consent_terms')), matching: find.byType(Checkbox)));
      await tester.pump();
      await tester.tap(agree);
      expect(c.consentNeeded, hasLength(3), reason: '하나만 체크하면 안 넘어감');
      await tester.tap(find.byKey(const Key('consentAll')));
      await tester.pump();
      await tester.ensureVisible(agree);
      await tester.pump();
      await tester.tap(agree);
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(c.consentNeeded, isEmpty);
    });

    testWidgets('로그인 백업 동의: 두 칸 모두 체크해야 로그인, 그만두면 로그인 안 함', (tester) async {
      late AppController c;
      await tester.runAsync(() async => c = (await b56.start(login: false)).$1);
      await tester.pumpWidget(host(Builder(
          builder: (ctx) => Scaffold(
              body: TextButton(
                  onPressed: () => signInFlow(ctx, c, LoginProvider.google), child: const Text('로그인'))))));
      await tester.tap(find.text('로그인'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('backupConsent')), findsOneWidget);
      await tester.tap(find.text('그만두기'));
      await tester.pumpAndSettle();
      expect(c.cloud.signedIn, isFalse);
      await tester.tap(find.text('로그인'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byKey(const Key('backupConsent_server')), matching: find.byType(Checkbox)));
      await tester.pump();
      await tester.tap(find.byKey(const Key('backupConsentOk')));
      await tester.pump();
      expect(find.byKey(const Key('backupConsent')), findsOneWidget, reason: '한 칸만으로는 안 됨');
      await tester.tap(find.byKey(const Key('backupConsent_steps')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('backupConsentOk')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();
      expect(c.consent.backupAgreed, isTrue);
      expect(c.cloud.signedIn, isTrue);
      await tester.pump(const Duration(seconds: 5));
    });
  });
}

