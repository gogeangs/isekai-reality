// 묶음 57: 약관 · 동의 — 문서 판(버전)과 적용일, 바뀔 때 알리는 날
//
// 문서를 고칠 때: 아래 목록에 같은 문서의 새 판을 더한다(지난 판은 지우지 않음).
//  - 적용일 7일 전부터(불리하게 바뀌면 30일 전부터) 배너 · 우편으로 알린다
//  - 적용일이 지나 처음 켜면, 바뀐 문서만 다시 동의를 받는다
//  - 글은 assets/legal/<파일>.txt 를 그 판으로 바꿔 둔다

/// 동의를 받는 문서 · 설정에서 보는 문서
enum LegalKind {
  terms('이용약관', 'assets/legal/terms.txt', required: true),
  privacy('개인정보 처리방침', 'assets/legal/privacy.txt', required: true),
  location('위치기반서비스 이용약관', 'assets/legal/location_terms.txt', required: true),
  operation('운영정책', 'assets/legal/operation.txt', required: false);

  const LegalKind(this.title, this.asset, {required this.required});
  final String title;
  final String asset;

  /// 처음 시작할 때 동의를 받는 문서 (운영정책은 설정에서 보기만)
  final bool required;

  static LegalKind? parse(String s) {
    for (final k in values) {
      if (k.name == s) return k;
    }
    return null;
  }
}

/// 문서 한 판
class LegalVersion {
  const LegalVersion(this.kind, this.version, this.effective,
      {this.unfavorable = false, this.summary = '', this.noticeOnly = false});

  /// 묶음 63: 다시 동의 없이 알림만 하는 판 (예전 판에 동의했으면 그대로 이어서)
  final bool noticeOnly;
  final LegalKind kind;
  final int version;

  /// 적용일 (그날 0시, 한국 시각)
  final DateTime effective;

  /// 이용자에게 불리하게 바뀜 → 30일 전에 알림
  final bool unfavorable;

  /// 바뀐 점 한 줄 (알림 · 다시 동의 창)
  final String summary;

  String get key => '${kind.name}@$version';
  int get noticeDays => unfavorable ? 30 : 7;
  DateTime get noticeFrom => effective.subtract(Duration(days: noticeDays));
}

abstract final class LegalRules {
  /// 모든 판 (문서마다 오래된 것부터)
  static final List<LegalVersion> history = [
    LegalVersion(LegalKind.terms, 1, DateTime(2026, 11, 17)),
    LegalVersion(LegalKind.privacy, 1, DateTime(2026, 11, 17)),
    LegalVersion(LegalKind.location, 1, DateTime(2026, 11, 17)),
    LegalVersion(LegalKind.operation, 1, DateTime(2026, 11, 17)),
    // 묶음 60: 정책 문서 최신본(거래소 · 순위 · 길드 · 공성 · 운영 기록, 만 14세 확인은 동의 화면, 이용약관 보강). 적용일 = 빌드 날
    LegalVersion(LegalKind.terms, 2, v2Date, summary: '계약 거절 · 회사 의무 · 광고성 알림 · 확인 중 임시 제한 · 글의 권리 · 이용자 배상 문구를 더했어요'),
    LegalVersion(LegalKind.privacy, 2, v2Date, summary: '거래소 · 심층 순위 · 길드 · 공성전 · 운영 기록과 보관 기간을 더했어요'),
    LegalVersion(LegalKind.location, 2, v2Date, summary: '만 14세 확인을 동의 화면에서 해요'),
    LegalVersion(LegalKind.operation, 2, v2Date),
    // 묶음 62: 개인정보 처리방침만 3판 (공성전 · 부정 이용 막기 · 마법 돋보기 ML Kit · 보관 기간)
    LegalVersion(LegalKind.privacy, 3, v3Date, summary: '공성전 · 부정 이용 막기 기록과 보관 기간, 마법 돋보기 처리 방식을 더했어요'),
    // 묶음 63: 처리방침 4판 — 알림만 (적용 = 빌드 날 + 7일)
    LegalVersion(LegalKind.privacy, 4, v4Date,
        noticeOnly: true,
        summary: '처리 위탁에 진짜 앱 확인(Google Play Integrity · Apple DeviceCheck · App Attest)을 더하고, 서버 기능 목록에 공성전 · 부정 이용 막기를 적었어요'),
  ];

  /// 묶음 63 판의 적용일 (빌드 날 11-18 + 7일)
  static final DateTime v4Date = DateTime(2026, 11, 25);

  /// 묶음 62 판의 적용일 (빌드가 나가는 날)
  static final DateTime v3Date = DateTime(2026, 11, 18);

  /// 묶음 60 판의 적용일 (빌드가 나가는 날)
  static final DateTime v2Date = DateTime(2026, 11, 18);

  /// 로그인 백업 동의 판 (문구가 바뀌면 올림)
  static const int backupVersion = 1;

  /// 시험용: 판 목록 바꿔 끼우기
  static List<LegalVersion>? testHistory;
  static List<LegalVersion> get _all => testHistory ?? history;

  static DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

  /// [now] 에 적용 중인 판 (적용일이 지난 가장 새 판)
  static LegalVersion current(LegalKind k, DateTime now) {
    LegalVersion? best;
    for (final v in _all) {
      if (v.kind != k || v.effective.isAfter(_day(now))) continue;
      if (best == null || v.version > best.version) best = v;
    }
    return best ?? _all.firstWhere((v) => v.kind == k);
  }

  /// 곧 적용될 판 (알림 기간 안) — 없으면 null
  static LegalVersion? upcoming(LegalKind k, DateTime now) {
    final cur = current(k, now);
    LegalVersion? next;
    for (final v in _all) {
      if (v.kind != k || v.version <= cur.version) continue;
      if (_day(now).isBefore(v.noticeFrom)) continue;
      if (next == null || v.version < next.version) next = v;
    }
    return next;
  }

  /// 알릴 것 (알림 기간 안의 새 판들)
  static List<LegalVersion> notices(DateTime now) => [
        for (final k in LegalKind.values)
          if (upcoming(k, now) case final v?) v,
      ];

  /// 동의가 있어야 하는 가장 새 판 (알림만 하는 판은 건너뜀)
  static int requiredVersion(LegalKind k, DateTime now) {
    var best = 1;
    for (final v in _all) {
      if (v.kind != k || v.noticeOnly || v.effective.isAfter(_day(now))) continue;
      if (v.version > best) best = v.version;
    }
    return best;
  }

  /// 다시(또는 처음) 동의받을 문서: 동의한 판이 동의가 있어야 하는 판보다 낮은 필수 문서 (보여 주는 글은 지금 판)
  static List<LegalVersion> needed(Map<LegalKind, int> agreed, DateTime now) => [
        for (final k in LegalKind.values)
          if (k.required && (agreed[k] ?? 0) < requiredVersion(k, now)) current(k, now),
      ];

  static String dateLabel(DateTime d) => '${d.year}년 ${d.month}월 ${d.day}일';

  /// 사업자 정보 (설정 「약관 · 정책」 아래)
  static const businessLines = [
    '상호 주식회사 프로젝트서티즈 · 대표 고경민',
    '사업자등록번호 156-81-03105',
    '경기도 안산시 상록구 한양대학로 55 창업보육센터 524호',
    'biz@project30s.co.kr · 개인정보 보호책임자 김지원',
  ];

  /// 파티 「함께 있어요」 위치 안내 (처음 파티 화면에서 한 번)
  static const partyLocationNotice =
      '함께 있어요는 내 위치 대신 약 100m 칸 번호만 10분 동안 써요. 파티원에게 내 위치는 보이지 않아요.';
}
