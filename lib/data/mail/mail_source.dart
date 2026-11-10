import '../../core/models/mail_state.dart';
import '../../core/rules/mail_rules.dart';

/// 운영 우편(공지·보상)을 가져오는 곳 (11-11 #65).
/// 1차: 앱 업데이트에 담은 목록 ([bundledMail], 이 파일 아래).
/// 2차: 서버 우편 (#49 서버 작업 때 [ServerMailSource] 를 채운다).
abstract class MailSource {
  Future<List<MailItem>> fetch(DateTime now);
}

/// 앱에 담아 보낸 공지·보상. 기간 안의 것만.
/// (파일을 읽지 않고 코드에 담는다: 앱 업데이트로 새 공지를 보낸다)
class AssetMailSource implements MailSource {
  const AssetMailSource();

  @override
  Future<List<MailItem>> fetch(DateTime now) async => parse(bundledMail, now);

  static List<MailItem> parse(Object? raw, DateTime now) {
    final out = <MailItem>[];
    for (final m in (raw is List ? raw : const [])) {
      if (m is! Map) continue;
      final start = DateTime.tryParse(m['start'] as String? ?? '');
      final end = DateTime.tryParse(m['end'] as String? ?? '');
      if (start != null && now.isBefore(start)) continue;
      if (end != null && now.isAfter(end)) continue;
      final kind = MailKind.values.firstWhere((k) => k.name == m['kind'],
          orElse: () => MailKind.notice);
      out.add(MailItem(
        id: 'ops_${m['id']}',
        kind: kind,
        from: m['from'] as String? ?? MailRules.operator,
        title: m['title'] as String? ?? '',
        body: m['body'] as String? ?? '',
        gifts: {
          for (final e in ((m['gifts'] as Map?) ?? const {}).entries)
            e.key as String: (e.value as num).toInt(),
        },
        sentAt: start ?? now,
        expiresAt: kind == MailKind.reward ? now.add(MailRules.rewardKeep) : null,
      ));
    }
    return out;
  }
}

/// 서버 우편 (2차). 서버가 생기기 전에는 아무것도 가져오지 않는다.
class ServerMailSource implements MailSource {
  const ServerMailSource();

  @override
  Future<List<MailItem>> fetch(DateTime now) async => const [];
}

/// 앱 업데이트에 담는 공지·운영 보상 (id 는 한 번 쓰면 바꾸지 않는다)
const List<Map<String, Object>> bundledMail = [
  {
    'id': 'welcome_mailbox',
    'kind': 'notice',
    'from': '여명의 탑 운영실',
    'title': '우편함이 열렸어요',
    'body': '이제 정령과 마을 사람들의 편지, 못 받은 의뢰 보상, 공지가 우편함으로 와요. '
        '선물은 「선물」 탭에서 받고, 편지는 「편지」 탭에 계속 남아요. '
        '보상 우편은 30일 동안 보관돼요.',
    'start': '2026-11-11T00:00:00',
  },
];
