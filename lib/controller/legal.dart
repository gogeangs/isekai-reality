part of '../app_controller.dart';

/// 묶음 57: 약관 · 동의 (처음 시작 동의 · 바뀐 문서 다시 동의 · 로그인 백업 동의 · 파티 위치 안내)
extension LegalOps on AppController {
  static const _consentKey = 'consent';

  ConsentState get consent => _consent;

  Future<void> _loadConsent() async {
    _consent = await _load(_consentKey, ConsentState.fromJson, const ConsentState());
  }

  Future<void> _saveConsent(ConsentState s) async {
    _consent = s;
    await store.saveJson(_consentKey, s.toJson());
    _notify();
  }

  /// 지금 동의받아야 할 문서 (없으면 빈 목록). 처음이면 필수 3개, 바뀐 뒤엔 바뀐 것만
  List<LegalVersion> get consentNeeded =>
      consentGate ? LegalRules.needed(_consent.agreed, _clock()) : const [];

  /// 동의 창에 「만 14세 이상」 줄을 보일지 (아직 확인하지 않았으면)
  bool get consentAskAge => _consent.ageAt == null;

  /// 동의 창 「동의하고 시작」
  Future<void> agreeLegal(List<LegalVersion> docs) async {
    final now = _clock();
    await _saveConsent(_consent.copyWith(
      docs: {..._consent.docs, for (final v in docs) v.kind: (v.version, now)},
      ageAt: _consent.ageAt ?? now,
    ));
    if (_cloud.signedIn) unawaited(autoBackup());
  }

  /// 로그인 백업 동의 (두 칸 모두 체크했을 때)
  Future<void> agreeBackup() async {
    await _saveConsent(_consent.copyWith(backupVersion: LegalRules.backupVersion, backupAt: _clock()));
  }

  bool get partyNoticeSeen => _consent.partyNotice;
  Future<void> markPartyNotice() async {
    if (_consent.partyNotice) return;
    await _saveConsent(_consent.copyWith(partyNotice: true));
  }

  /// 곧 바뀌는 문서 배너 (닫지 않은 것 하나)
  LegalVersion? get legalBanner {
    for (final v in LegalRules.notices(_clock())) {
      if (!_consent.dismissed.contains(v.key)) return v;
    }
    return null;
  }

  Future<void> dismissLegalBanner(LegalVersion v) async {
    await _saveConsent(_consent.copyWith(dismissed: {..._consent.dismissed, v.key}));
  }

  /// 곧 바뀌는 문서를 우편으로 한 번 알린다 (앱을 켤 때 · 돌아올 때)
  Future<void> checkLegalNotices() async {
    if (!_ready || _needsAwakening) return;
    final todo = [
      for (final v in LegalRules.notices(_clock()))
        if (!_consent.noticed.contains(v.key)) v,
    ];
    if (todo.isEmpty) return;
    for (final v in todo) {
      await _sendMail(MailItem(
        id: 'legal_${v.key}',
        kind: MailKind.notice,
        from: '여명의 탑 운영실',
        title: '${v.kind.title}이 바뀌어요',
        body: [
          '${LegalRules.dateLabel(v.effective)}부터 ${v.kind.title}이 바뀌어요.',
          if (v.summary.isNotEmpty) v.summary,
          '바뀐 내용은 설정 → 약관 · 정책에서 볼 수 있어요.',
          if (v.kind.required && !v.noticeOnly) '적용일 뒤 처음 켤 때 바뀐 문서에 다시 동의를 받아요.',
        ].join('\n'),
        sentAt: _clock(),
      ));
    }
    await _saveConsent(_consent.copyWith(noticed: {..._consent.noticed, for (final v in todo) v.key}));
  }

  /// 「기록 지키기」 (Lv.3 레벨업 창 뒤, 로그인 안 했으면 Lv.8 에 한 번 더): 물어볼 레벨, 없으면 null
  int? loginAskFor(int from, int to) {
    if (!cloudAvailable || _cloud.signedIn) return null;
    // 묶음 70 #291: Lv.8은 친구 장면이 함께 물음
    for (final l in const [3]) {
      if (from < l && to >= l && !_consent.loginAsked.contains(l)) return l;
    }
    return null;
  }

  Future<void> markLoginAsked(int level) async {
    // 3 을 건너 8 에서 처음 물으면 3 도 한 것으로
    await _saveConsent(_consent.copyWith(loginAsked: {..._consent.loginAsked, level, if (level == 8) 3}));
  }
}
