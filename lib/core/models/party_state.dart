/// 파티 화면에 보이는 것 (묶음 56 #236). 서버가 준 값을 그대로 담는다 (저장하지 않음).
class PartyView {
  const PartyView({
    this.id,
    this.name = '',
    this.emblem = 0,
    this.color = 0,
    this.code = '',
    this.owner = false,
    this.members = const [],
    this.walkTotal = 0,
    this.walkGoals = const [],
    this.walkClaimed = const [],
    this.boss,
    this.lastBoss,
    this.cheers = const [],
    this.canCheer = false,
    this.restricted = false,
    this.stepsCounted = true,
  });

  /// 파티가 없으면 null
  final String? id;
  final String name;
  final int emblem;
  final int color;
  final String code;

  /// 내가 파티장인지
  final bool owner;
  final List<PartyMember> members;
  final int walkTotal;
  final List<int> walkGoals;
  final List<int> walkClaimed;
  final PartyBoss? boss;

  /// 지난주 못 쓰러뜨린 보스: 준 피해만큼 발자국 표 (받을 것이 있으면)
  final ({String week, String id, int footTicket})? lastBoss;

  /// 나를 응원한 사람 (이번에 처음 보는 것만)
  final List<String> cheers;

  /// 오늘 응원할 수 있는지 (하루 한 사람에게 한 번)
  final bool canCheer;

  /// 제재 중 (함께하는 기능을 못 씀)
  final bool restricted;

  /// 오늘 이 휴대폰 걸음이 이 계정에 쌓였는지 (운영정책: 그날 처음 받은 계정만)
  final bool stepsCounted;

  bool get inParty => id != null;

  static PartyView fromJson(Map<String, dynamic> j) {
    final p = (j['party'] as Map?)?.cast<String, dynamic>();
    final walk = (j['walk'] as Map?)?.cast<String, dynamic>() ?? const {};
    final b = (j['boss'] as Map?)?.cast<String, dynamic>();
    final l = (j['lastBoss'] as Map?)?.cast<String, dynamic>();
    int n(Object? x) => (x as num?)?.toInt() ?? 0;
    return PartyView(
      id: p?['id'] as String?,
      name: (p?['name'] as String?) ?? '',
      emblem: n(p?['emblem']),
      color: n(p?['color']),
      code: (p?['code'] as String?) ?? '',
      owner: p?['owner'] == true,
      members: [
        for (final m in (j['members'] as List?) ?? const [])
          if (m is Map) PartyMember.fromJson(m.cast<String, dynamic>()),
      ],
      walkTotal: n(walk['total']),
      walkGoals: [for (final g in (walk['goals'] as List?) ?? const []) n(g)],
      walkClaimed: [for (final g in (walk['claimed'] as List?) ?? const []) n(g)],
      boss: b == null ? null : PartyBoss.fromJson(b),
      lastBoss: l == null
          ? null
          : (week: '${l['week']}', id: '${l['id']}', footTicket: n(l['footTicket'])),
      cheers: [for (final c in (j['cheers'] as List?) ?? const []) '$c'],
      canCheer: j['canCheer'] == true,
      restricted: j['restricted'] == true,
      stepsCounted: j['stepsCounted'] != false,
    );
  }
}

class PartyMember {
  const PartyMember({
    required this.uid,
    required this.name,
    this.level = 1,
    this.steps = 0,
    this.me = false,
    this.owner = false,
    this.cheeredToday = false,
  });

  final String uid;
  final String name;
  final int level;

  /// 이번 주 함께 걷기에 보탠 걸음
  final int steps;
  final bool me;
  final bool owner;

  /// 오늘 내가 이 사람을 응원했는지
  final bool cheeredToday;

  static PartyMember fromJson(Map<String, dynamic> j) => PartyMember(
        uid: '${j['uid']}',
        name: '${j['name'] ?? '각성자'}',
        level: (j['level'] as num?)?.toInt() ?? 1,
        steps: (j['steps'] as num?)?.toInt() ?? 0,
        me: j['me'] == true,
        owner: j['owner'] == true,
        cheeredToday: j['cheeredToday'] == true,
      );
}

class PartyBoss {
  const PartyBoss({
    required this.id,
    this.encounter = 1,
    this.hp = 1,
    this.damage = 0,
    this.myDamage = 0,
    this.defeated = false,
    this.tickets = 0,
    this.claimed = false,
  });

  final String id;

  /// ○번째 만남
  final int encounter;
  final int hp;

  /// 파티 모두가 준 피해 · 내가 준 피해
  final int damage;
  final int myDamage;
  final bool defeated;

  /// 오늘 남은 도전권
  final int tickets;
  final bool claimed;

  double get left => hp <= 0 ? 0 : ((hp - damage) / hp).clamp(0.0, 1.0);

  static PartyBoss fromJson(Map<String, dynamic> j) => PartyBoss(
        id: '${j['id']}',
        encounter: (j['encounter'] as num?)?.toInt() ?? 1,
        hp: (j['hp'] as num?)?.toInt() ?? 1,
        damage: (j['damage'] as num?)?.toInt() ?? 0,
        myDamage: (j['myDamage'] as num?)?.toInt() ?? 0,
        defeated: j['defeated'] == true,
        tickets: (j['tickets'] as num?)?.toInt() ?? 0,
        claimed: j['claimed'] == true,
      );
}

/// 휴대폰에 남기는 파티 기록 ('party'): 발자국 표 · 가진 깃발 문양 · 색 · 상점 · 함께 잡은 몬스터
class PartyLocal {
  const PartyLocal({
    this.tickets = 0,
    this.emblems = const [],
    this.colors = const [],
    this.shopWeek,
    this.shopBought = const {},
    this.together = 0,
    this.nearUntil,
    this.joined = false,
  });

  /// 발자국 표
  final int tickets;

  /// 더 얻은 깃발 문양 · 색 (처음 3개씩은 늘 가짐)
  final List<int> emblems;
  final List<int> colors;

  /// 이번 주(월요일) · 그 주에 산 개수 (모집권 주 2장)
  final String? shopWeek;
  final Map<String, int> shopBought;

  /// 함께 잡은 몬스터 수
  final int together;

  /// 「함께 있어요」가 이어지는 때
  final DateTime? nearUntil;

  /// 마지막으로 본 파티가 있었는지 (위치 칸을 서버에 알릴지)
  final bool joined;

  PartyLocal copyWith({
    int? tickets,
    List<int>? emblems,
    List<int>? colors,
    String? shopWeek,
    Map<String, int>? shopBought,
    int? together,
    DateTime? nearUntil,
    bool clearNear = false,
    bool? joined,
  }) =>
      PartyLocal(
        tickets: tickets ?? this.tickets,
        emblems: emblems ?? this.emblems,
        colors: colors ?? this.colors,
        shopWeek: shopWeek ?? this.shopWeek,
        shopBought: shopBought ?? this.shopBought,
        together: together ?? this.together,
        nearUntil: clearNear ? null : nearUntil ?? this.nearUntil,
        joined: joined ?? this.joined,
      );

  Map<String, dynamic> toJson() => {
        'v': 1,
        if (tickets > 0) 'tickets': tickets,
        if (emblems.isNotEmpty) 'emblems': emblems,
        if (colors.isNotEmpty) 'colors': colors,
        if (shopWeek != null) 'shopWeek': shopWeek,
        if (shopBought.isNotEmpty) 'shopBought': shopBought,
        if (together > 0) 'together': together,
        if (nearUntil != null) 'nearUntil': nearUntil!.toIso8601String(),
        if (joined) 'joined': true,
      };

  static PartyLocal fromJson(Map<String, dynamic> j) => PartyLocal(
        tickets: ((j['tickets'] as num?) ?? 0).toInt(),
        emblems: [for (final x in (j['emblems'] as List?) ?? const []) if (x is num) x.toInt()],
        colors: [for (final x in (j['colors'] as List?) ?? const []) if (x is num) x.toInt()],
        shopWeek: j['shopWeek'] as String?,
        shopBought: {
          for (final e in ((j['shopBought'] as Map?) ?? const {}).entries)
            if (e.value is num) '${e.key}': (e.value as num).toInt(),
        },
        together: ((j['together'] as num?) ?? 0).toInt(),
        nearUntil: j['nearUntil'] is String ? DateTime.tryParse(j['nearUntil'] as String) : null,
        joined: j['joined'] == true,
      );
}
