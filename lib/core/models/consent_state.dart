import '../rules/legal_rules.dart';

/// 묶음 57: 동의 기록 (어떤 문서의 몇 판에 언제 동의했는지). 로그인하면 게임 기록과 함께 백업된다.
class ConsentState {
  const ConsentState({
    this.docs = const {},
    this.ageAt,
    this.backupVersion = 0,
    this.backupAt,
    this.partyNotice = false,
    this.noticed = const {},
    this.dismissed = const {},
    this.loginAsked = const {},
  });

  /// 「기록 지키기」 로그인 권유를 한 레벨 (3 · 8)
  final Set<int> loginAsked;

  /// 문서 → (판, 동의한 때)
  final Map<LegalKind, (int, DateTime)> docs;

  /// 만 14세 이상 확인한 때
  final DateTime? ageAt;

  /// 로그인 백업 동의 (판 · 때). 0 이면 아직
  final int backupVersion;
  final DateTime? backupAt;

  /// 파티 위치 안내를 봤는지
  final bool partyNotice;

  /// 바뀜 알림을 우편으로 보낸 판 ('terms@2')
  final Set<String> noticed;

  /// 배너를 닫은 판
  final Set<String> dismissed;

  Map<LegalKind, int> get agreed => {for (final e in docs.entries) e.key: e.value.$1};

  bool get backupAgreed => backupVersion >= LegalRules.backupVersion;

  ConsentState copyWith({
    Map<LegalKind, (int, DateTime)>? docs,
    DateTime? ageAt,
    int? backupVersion,
    DateTime? backupAt,
    bool? partyNotice,
    Set<String>? noticed,
    Set<String>? dismissed,
    Set<int>? loginAsked,
  }) =>
      ConsentState(
        docs: docs ?? this.docs,
        ageAt: ageAt ?? this.ageAt,
        backupVersion: backupVersion ?? this.backupVersion,
        backupAt: backupAt ?? this.backupAt,
        partyNotice: partyNotice ?? this.partyNotice,
        noticed: noticed ?? this.noticed,
        dismissed: dismissed ?? this.dismissed,
        loginAsked: loginAsked ?? this.loginAsked,
      );

  Map<String, dynamic> toJson() => {
        'docs': {
          for (final e in docs.entries) e.key.name: {'v': e.value.$1, 'at': e.value.$2.toIso8601String()},
        },
        if (ageAt != null) 'age14': ageAt!.toIso8601String(),
        if (backupVersion > 0) 'backup': {'v': backupVersion, 'at': backupAt?.toIso8601String()},
        if (partyNotice) 'party': true,
        if (noticed.isNotEmpty) 'noticed': noticed.toList(),
        if (dismissed.isNotEmpty) 'dismissed': dismissed.toList(),
        if (loginAsked.isNotEmpty) 'loginAsked': loginAsked.toList(),
      };

  static DateTime? _t(Object? s) => s is String ? DateTime.tryParse(s) : null;

  factory ConsentState.fromJson(Map<String, dynamic> j) {
    final docs = <LegalKind, (int, DateTime)>{};
    for (final e in ((j['docs'] as Map?) ?? const {}).entries) {
      final k = LegalKind.parse('${e.key}');
      final v = e.value;
      if (k == null || v is! Map) continue;
      docs[k] = ((v['v'] as num?)?.toInt() ?? 0, _t(v['at']) ?? DateTime(2026));
    }
    final b = j['backup'];
    return ConsentState(
      docs: docs,
      ageAt: _t(j['age14']),
      backupVersion: b is Map ? ((b['v'] as num?)?.toInt() ?? 0) : 0,
      backupAt: b is Map ? _t(b['at']) : null,
      partyNotice: j['party'] == true,
      noticed: {for (final s in (j['noticed'] as List?) ?? const []) '$s'},
      dismissed: {for (final s in (j['dismissed'] as List?) ?? const []) '$s'},
      loginAsked: {for (final s in (j['loginAsked'] as List?) ?? const []) if (s is num) s.toInt()},
    );
  }
}
