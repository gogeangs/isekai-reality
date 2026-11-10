/// 가마솥 하나: 넣은 재료(순서대로)와 다 끓는 때
class Brew {
  const Brew({required this.put, required this.startedAt, required this.readyAt});

  /// 넣은 재료 이름 (넣은 순서)
  final List<String> put;
  final DateTime startedAt;
  final DateTime readyAt;

  Map<String, dynamic> toJson() => {
        'put': put,
        'startedAt': startedAt.toIso8601String(),
        'readyAt': readyAt.toIso8601String(),
      };

  static Brew? fromJson(Object? j) {
    if (j is! Map) return null;
    final s = DateTime.tryParse(j['startedAt'] as String? ?? '');
    final r = DateTime.tryParse(j['readyAt'] as String? ?? '');
    if (s == null || r == null) return null;
    return Brew(
        put: [for (final p in (j['put'] as List?) ?? const []) p as String],
        startedAt: s,
        readyAt: r);
  }
}

/// 마신 물약의 남은 효과 (버프·저항·풍요·수상한 물약)
///
/// 11-11 #74: 전투·속성 물약은 남은 전투 수([battles]), 걸음 물약은
/// 마신 때 걸음([stepsFrom])부터 [stepsCap] 보까지, 나머지는 시간([until]).
class ActiveBuff {
  const ActiveBuff({
    required this.key,
    required this.until,
    this.amount = 0,
    this.battles,
    this.stepsFrom,
    this.stepsCap,
    this.day,
  });

  /// 'strength'·'resistFire'·'plenty'·'?:agility' (수상한 물약은 ?:스탯)
  final String key;
  final DateTime until;

  /// 스탯 버프 크기 (품질·수상한 물약)
  final int amount;

  /// 남은 전투 수 (전투·속성 물약)
  final int? battles;

  /// 걸음 물약: 마신 때 오늘 걸음, 늘어나는 걸음 한도, 그날
  final int? stepsFrom;
  final int? stepsCap;
  final String? day;

  ActiveBuff withBattles(int n) => ActiveBuff(
      key: key,
      until: until,
      amount: amount,
      battles: n,
      stepsFrom: stepsFrom,
      stepsCap: stepsCap,
      day: day);

  Map<String, dynamic> toJson() => {
        'key': key,
        'until': until.toIso8601String(),
        'amount': amount,
        if (battles != null) 'battles': battles,
        if (stepsFrom != null) 'stepsFrom': stepsFrom,
        if (stepsCap != null) 'stepsCap': stepsCap,
        if (day != null) 'day': day,
      };

  static ActiveBuff? fromJson(Object? j) {
    if (j is! Map) return null;
    final u = DateTime.tryParse(j['until'] as String? ?? '');
    if (u == null) return null;
    return ActiveBuff(
        key: j['key'] as String,
        until: u,
        amount: (j['amount'] as num?)?.toInt() ?? 0,
        battles: (j['battles'] as num?)?.toInt(),
        stepsFrom: (j['stepsFrom'] as num?)?.toInt(),
        stepsCap: (j['stepsCap'] as num?)?.toInt(),
        day: j['day'] as String?);
  }
}

/// 변환대에서 진행 중인 변환 (11-11 #74). 넣은 것은 시작할 때 이미 뺐다.
class ConvertJob {
  const ConvertJob({
    required this.kind,
    required this.get,
    required this.startedAt,
    required this.readyAt,
    this.getManaStones = 0,
  });

  /// ConvertKind 이름
  final String kind;

  /// 나오는 재료 (이름 → 개수)
  final Map<String, int> get;
  final int getManaStones;
  final DateTime startedAt;
  final DateTime readyAt;

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'get': get,
        'getManaStones': getManaStones,
        'startedAt': startedAt.toIso8601String(),
        'readyAt': readyAt.toIso8601String(),
      };

  static ConvertJob? fromJson(Object? j) {
    if (j is! Map) return null;
    final s = DateTime.tryParse(j['startedAt'] as String? ?? '');
    final r = DateTime.tryParse(j['readyAt'] as String? ?? '');
    if (s == null || r == null) return null;
    return ConvertJob(
      kind: j['kind'] as String? ?? '',
      get: {
        for (final e in ((j['get'] as Map?) ?? const {}).entries)
          e.key as String: (e.value as num).toInt(),
      },
      getManaStones: (j['getManaStones'] as num?)?.toInt() ?? 0,
      startedAt: s,
      readyAt: r,
    );
  }
}

/// 부르는 물약으로 나온 몬스터
class CalledSpawn {
  const CalledSpawn(
      {required this.id,
      required this.monster,
      required this.lat,
      required this.lng,
      this.mods = const []});

  final String id;
  final String monster;
  final double lat;
  final double lng;
  final List<String> mods;

  Map<String, dynamic> toJson() =>
      {'id': id, 'monster': monster, 'lat': lat, 'lng': lng, 'mods': mods};

  static CalledSpawn? fromJson(Object? j) {
    if (j is! Map) return null;
    return CalledSpawn(
      id: j['id'] as String,
      monster: j['monster'] as String,
      lat: (j['lat'] as num).toDouble(),
      lng: (j['lng'] as num).toDouble(),
      mods: [for (final m in (j['mods'] as List?) ?? const []) m as String],
    );
  }
}

/// 연금술 공방 (11-11 #57·#58). 따로 저장한다 ('alchemy').
class AlchemyState {
  const AlchemyState({
    this.potions = const {},
    this.cauldrons = 1,
    this.brews = const {},
    this.discovered = const [],
    this.noted = const [],
    this.knownSuspicious = const [],
    this.buffs = const [],
    this.called = const [],
    this.calledDays = const {},
    this.autoHp = 0,
    this.autoCure = false,
    this.saved = const [],
    this.convert,
    this.mastery = 0,
  });

  /// 변환대 (11-11 #74, 1칸)
  final ConvertJob? convert;

  /// 연금술사 숙련도 점수 (11-11 #74). 직업 각성 전에는 모아 두기만 한다.
  final int mastery;

  /// 가방의 공방 물약: 'healBig', 'healBig*'(완벽한 조제), '?:herb+herb'(수상한 물약)
  final Map<String, int> potions;

  /// 가진 가마솥 수 (1~3)
  final int cauldrons;

  /// 가마솥 번호 → 끓는 중인 것
  final Map<int, Brew> brews;

  /// 레시피를 안 물약 (재료·개수)
  final List<String> discovered;

  /// 레시피 쪽지로 재료만 안 물약
  final List<String> noted;

  /// 마셔 봐서 효과를 아는 수상한 물약 조합
  final List<String> knownSuspicious;

  final List<ActiveBuff> buffs;

  /// 부르는 물약으로 나온 오늘의 몬스터
  final List<CalledSpawn> called;

  /// 부르는 물약을 마신 날 ('callMonsters' → 'yyyy-mm-dd')
  final Map<String, String> calledDays;

  /// 자동 마시기: HP 이 % 아래면 회복 물약 (0이면 끔)
  final int autoHp;

  /// 자동 마시기: 중독·화상·눈부심이면 해독제·연고·맑은 눈 물약
  final bool autoCure;

  /// 연금술사 전용: 이름 붙여 저장한 조합 (직업 각성 전에는 쓰지 않는다)
  final List<Map<String, dynamic>> saved;

  int count(String key) => potions[key] ?? 0;

  AlchemyState copyWith({
    Map<String, int>? potions,
    int? cauldrons,
    Map<int, Brew>? brews,
    List<String>? discovered,
    List<String>? noted,
    List<String>? knownSuspicious,
    List<ActiveBuff>? buffs,
    List<CalledSpawn>? called,
    Map<String, String>? calledDays,
    int? autoHp,
    bool? autoCure,
    ConvertJob? convert,
    bool clearConvert = false,
    int? mastery,
  }) =>
      AlchemyState(
        potions: potions ?? this.potions,
        cauldrons: cauldrons ?? this.cauldrons,
        brews: brews ?? this.brews,
        discovered: discovered ?? this.discovered,
        noted: noted ?? this.noted,
        knownSuspicious: knownSuspicious ?? this.knownSuspicious,
        buffs: buffs ?? this.buffs,
        called: called ?? this.called,
        calledDays: calledDays ?? this.calledDays,
        autoHp: autoHp ?? this.autoHp,
        autoCure: autoCure ?? this.autoCure,
        saved: saved,
        convert: clearConvert ? null : (convert ?? this.convert),
        mastery: mastery ?? this.mastery,
      );

  /// [key] 를 [n] 개 더한다 (빼면 0개는 지운다)
  AlchemyState add(String key, int n) {
    final m = {...potions};
    final v = (m[key] ?? 0) + n;
    if (v <= 0) {
      m.remove(key);
    } else {
      m[key] = v;
    }
    return copyWith(potions: m);
  }

  Map<String, dynamic> toJson() => {
        'potions': potions,
        'cauldrons': cauldrons,
        'brews': {for (final e in brews.entries) '${e.key}': e.value.toJson()},
        'discovered': discovered,
        'noted': noted,
        'knownSuspicious': knownSuspicious,
        'buffs': [for (final b in buffs) b.toJson()],
        'called': [for (final c in called) c.toJson()],
        'calledDays': calledDays,
        'autoHp': autoHp,
        'autoCure': autoCure,
        'saved': saved,
        if (convert != null) 'convert': convert!.toJson(),
        'mastery': mastery,
      };

  factory AlchemyState.fromJson(Map<String, dynamic> j) {
    List<String> strings(Object? v) =>
        [for (final s in (v as List?) ?? const []) s as String];
    return AlchemyState(
      potions: {
        for (final e in ((j['potions'] as Map?) ?? const {}).entries)
          e.key as String: (e.value as num).toInt(),
      },
      cauldrons: (j['cauldrons'] as num?)?.toInt() ?? 1,
      brews: {
        for (final e in ((j['brews'] as Map?) ?? const {}).entries)
          if (Brew.fromJson(e.value) case final b?)
            int.tryParse(e.key as String) ?? 0: b,
      },
      discovered: strings(j['discovered']),
      noted: strings(j['noted']),
      knownSuspicious: strings(j['knownSuspicious']),
      buffs: [
        for (final b in (j['buffs'] as List?) ?? const [])
          if (ActiveBuff.fromJson(b) case final x?) x,
      ],
      called: [
        for (final c in (j['called'] as List?) ?? const [])
          if (CalledSpawn.fromJson(c) case final x?) x,
      ],
      calledDays: {
        for (final e in ((j['calledDays'] as Map?) ?? const {}).entries)
          e.key as String: e.value as String,
      },
      autoHp: (j['autoHp'] as num?)?.toInt() ?? 0,
      autoCure: j['autoCure'] as bool? ?? false,
      saved: [
        for (final s in (j['saved'] as List?) ?? const [])
          Map<String, dynamic>.from(s as Map),
      ],
      convert: ConvertJob.fromJson(j['convert']),
      mastery: (j['mastery'] as num?)?.toInt() ?? 0,
    );
  }
}
