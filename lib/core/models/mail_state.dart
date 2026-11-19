import 'armory.dart';

/// 우편 종류 (11-11 #65)
enum MailKind {
  /// 보상 우편 (못 받은 의뢰 보상, 운영 보상): 30일 뒤 사라진다
  reward,

  /// 편지 (정령·마을 사람): 계속 보관
  letter,

  /// 공지사항: 계속 보관
  notice,
}

/// 우편 하나
class MailItem {
  const MailItem({
    required this.id,
    required this.kind,
    required this.from,
    required this.title,
    this.body = '',
    this.gifts = const {},
    this.equips = const [],
    required this.sentAt,
    this.expiresAt,
    this.claimed = false,
    this.read = false,
    this.taken = const {},
    this.takenEquips = const [],
  });

  /// 묶음 75 #333: 가방이 가득해 일부만 받았을 때 이미 받은 선물 (그림을 흐리게)
  final Map<String, int> taken;
  final List<EquipItem> takenEquips;

  /// 같은 우편을 두 번 보내지 않으려고 쓰는 id
  final String id;
  final MailKind kind;

  /// 보낸 사람 ('하르트', '정령 이름', '여명의 탑 운영실')
  final String from;
  final String title;
  final String body;

  /// 선물: 'gold' · 'manaStone' · 'exp' · 'egg' · 'note' · 'item:<잡화상 물건>' · 재료 이름
  final Map<String, int> gifts;

  /// 묶음 47 #240: 가방이 가득해 우편으로 맡긴 장비 (받으면 그대로 가방에)
  final List<EquipItem> equips;
  final DateTime sentAt;

  /// 보상 우편이 사라지는 때 (편지·공지는 null)
  final DateTime? expiresAt;
  final bool claimed;
  final bool read;

  bool get hasGifts => (gifts.isNotEmpty || equips.isNotEmpty) && !claimed;

  MailItem copyWith(
          {bool? claimed,
          bool? read,
          Map<String, int>? gifts,
          List<EquipItem>? equips,
          Map<String, int>? taken,
          List<EquipItem>? takenEquips}) =>
      MailItem(
        id: id,
        kind: kind,
        from: from,
        title: title,
        body: body,
        gifts: gifts ?? this.gifts,
        equips: equips ?? this.equips,
        sentAt: sentAt,
        expiresAt: expiresAt,
        claimed: claimed ?? this.claimed,
        read: read ?? this.read,
        taken: taken ?? this.taken,
        takenEquips: takenEquips ?? this.takenEquips,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'from': from,
        'title': title,
        'body': body,
        'gifts': gifts,
        if (equips.isNotEmpty) 'equips': [for (final e in equips) e.toJson()],
        'sentAt': sentAt.toIso8601String(),
        if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
        'claimed': claimed,
        'read': read,
        if (taken.isNotEmpty) 'taken': taken,
        if (takenEquips.isNotEmpty)
          'takenEquips': [for (final e in takenEquips) e.toJson()],
      };

  static MailItem? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final sent = DateTime.tryParse(raw['sentAt'] as String? ?? '');
    if (raw['id'] is! String || sent == null) return null;
    return MailItem(
      id: raw['id'] as String,
      kind: MailKind.values.firstWhere((k) => k.name == raw['kind'],
          orElse: () => MailKind.letter),
      from: raw['from'] as String? ?? '',
      title: raw['title'] as String? ?? '',
      body: raw['body'] as String? ?? '',
      gifts: {
        for (final e in ((raw['gifts'] as Map?) ?? const {}).entries)
          e.key as String: (e.value as num).toInt(),
      },
      equips: [
        for (final e in (raw['equips'] as List?) ?? const [])
          if (e is Map)
            if (EquipItem.fromJson(Map<String, dynamic>.from(e)) case final x?) x,
      ],
      sentAt: sent,
      expiresAt: DateTime.tryParse(raw['expiresAt'] as String? ?? ''),
      claimed: raw['claimed'] as bool? ?? false,
      read: raw['read'] as bool? ?? false,
      taken: {
        for (final e in ((raw['taken'] as Map?) ?? const {}).entries)
          if (e.value is num) e.key as String: (e.value as num).toInt(),
      },
      takenEquips: [
        for (final e in (raw['takenEquips'] as List?) ?? const [])
          if (e is Map)
            if (EquipItem.fromJson(Map<String, dynamic>.from(e)) case final x?) x,
      ],
    );
  }
}

/// 우편함 (11-11 #65). 따로 저장한다 ('mail').
class MailState {
  const MailState({this.mails = const [], this.sent = const []});

  /// 받은 우편 (최근 것이 앞)
  final List<MailItem> mails;

  /// 이미 보낸 우편 id (지워진 뒤에도 다시 보내지 않는다)
  final List<String> sent;

  MailState copyWith({List<MailItem>? mails, List<String>? sent}) =>
      MailState(mails: mails ?? this.mails, sent: sent ?? this.sent);

  Map<String, dynamic> toJson() => {
        'mails': [for (final m in mails) m.toJson()],
        'sent': sent,
      };

  factory MailState.fromJson(Map<String, dynamic> j) => MailState(
        mails: [
          for (final m in (j['mails'] as List?) ?? const [])
            if (MailItem.fromJson(m) case final x?) x,
        ],
        sent: [for (final s in (j['sent'] as List?) ?? const []) s as String],
      );
}
