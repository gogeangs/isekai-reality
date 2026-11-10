/// 정령 원정 하나 (한 번에 한 곳만)
class Expedition {
  const Expedition({
    required this.spawnId,
    required this.monster,
    this.mods = const [],
    required this.lat,
    required this.lng,
    this.fromLat,
    this.fromLng,
    required this.distanceM,
    required this.mpCost,
    required this.startedAt,
    required this.arriveAt,
    required this.returnAt,
    this.cleared,
  });

  /// 보낸 필드 몬스터 자리 id ([FieldSpawn.id])
  final String spawnId;

  /// 몬스터 종류 ([MonsterId] 이름)
  final String monster;

  /// 몬스터 수식어 ([ModifierId] 이름, 11-10)
  final List<String> mods;
  final double lat;
  final double lng;

  /// 정령이 떠난 곳 (보낼 때 각성자 위치)
  final double? fromLat;
  final double? fromLng;
  final double distanceM;
  final int mpCost;
  final DateTime startedAt;
  final DateTime arriveAt;
  final DateTime returnAt;

  /// 결과. 돌아오기 전에는 null.
  final bool? cleared;

  bool get finished => cleared != null;

  /// 지금 정령이 있는 곳 (가는 길 → 몬스터 자리 → 돌아오는 길). (위도, 경도)
  (double, double) positionAt(DateTime now) {
    final fLat = fromLat ?? lat;
    final fLng = fromLng ?? lng;
    double t;
    if (now.isBefore(arriveAt)) {
      final total = arriveAt.difference(startedAt).inSeconds;
      t = total <= 0 ? 1 : now.difference(startedAt).inSeconds / total;
    } else if (now.isBefore(returnAt)) {
      final total = returnAt.difference(arriveAt).inSeconds;
      t = 1 - (total <= 0 ? 1 : now.difference(arriveAt).inSeconds / total);
    } else {
      t = 0;
    }
    t = t.clamp(0.0, 1.0);
    return (fLat + (lat - fLat) * t, fLng + (lng - fLng) * t);
  }

  /// 몬스터에게 가는 중인지 (아니면 돌아오는 중)
  bool goingAt(DateTime now) => now.isBefore(arriveAt);

  Expedition withResult(bool cleared) => Expedition(
        spawnId: spawnId,
        monster: monster,
        mods: mods,
        lat: lat,
        lng: lng,
        fromLat: fromLat,
        fromLng: fromLng,
        distanceM: distanceM,
        mpCost: mpCost,
        startedAt: startedAt,
        arriveAt: arriveAt,
        returnAt: returnAt,
        cleared: cleared,
      );

  Map<String, dynamic> toJson() => {
        'spawnId': spawnId,
        'monster': monster,
        'mods': mods,
        'lat': lat,
        'lng': lng,
        'fromLat': fromLat,
        'fromLng': fromLng,
        'distanceM': distanceM,
        'mpCost': mpCost,
        'startedAt': startedAt.toIso8601String(),
        'arriveAt': arriveAt.toIso8601String(),
        'returnAt': returnAt.toIso8601String(),
        'cleared': cleared,
      };

  factory Expedition.fromJson(Map<String, dynamic> j) => Expedition(
        spawnId: j['spawnId'] as String,
        monster: j['monster'] as String,
        mods: ((j['mods'] as List?) ?? const []).map((e) => e as String).toList(),
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        fromLat: (j['fromLat'] as num?)?.toDouble(),
        fromLng: (j['fromLng'] as num?)?.toDouble(),
        distanceM: (j['distanceM'] as num).toDouble(),
        mpCost: j['mpCost'] as int,
        startedAt: DateTime.parse(j['startedAt'] as String),
        arriveAt: DateTime.parse(j['arriveAt'] as String),
        returnAt: DateTime.parse(j['returnAt'] as String),
        cleared: j['cleared'] as bool?,
      );
}

/// 시간에 따라 바뀌는 상태: HP, 정령 MP, 여관 휴식, 정령 원정.
///
/// 하루 기록과 달리 '지금 값'을 그대로 저장한다.
class Vitals {
  const Vitals({
    this.hp,
    this.lastMaxHp,
    this.mp,
    this.mpAt,
    this.stepsDay,
    this.stepsCounted = 0,
    this.restStartedAt,
    this.expedition,
    this.compassReady = false,
  });

  /// 지금 HP. null 이면 가득.
  final int? hp;

  /// 마지막으로 본 최대 HP (레벨이 올라 최대 HP가 늘면 그만큼 지금 HP도 늘린다)
  final int? lastMaxHp;

  /// 정령 MP. null 이면 가득.
  final int? mp;

  /// MP 자연 회복을 마지막으로 계산한 때
  final DateTime? mpAt;

  /// 걷기 HP 회복에 이미 쓴 걸음 (그날 [stepsDay] 기준)
  final String? stepsDay;
  final int stepsCounted;

  /// 여관 체크인 시각. 쉬는 중이 아니면 null.
  final DateTime? restStartedAt;

  /// 진행 중이거나 결과를 아직 보지 않은 원정
  final Expedition? expedition;

  /// 원정 나침반을 써 두었는지 (다음 원정의 이동 시간 절반, 11-10)
  final bool compassReady;

  Vitals copyWith({
    int? hp,
    int? lastMaxHp,
    int? mp,
    DateTime? mpAt,
    String? stepsDay,
    int? stepsCounted,
    DateTime? restStartedAt,
    bool clearRest = false,
    Expedition? expedition,
    bool clearExpedition = false,
    bool? compassReady,
  }) =>
      Vitals(
        hp: hp ?? this.hp,
        lastMaxHp: lastMaxHp ?? this.lastMaxHp,
        mp: mp ?? this.mp,
        mpAt: mpAt ?? this.mpAt,
        stepsDay: stepsDay ?? this.stepsDay,
        stepsCounted: stepsCounted ?? this.stepsCounted,
        restStartedAt: clearRest ? null : (restStartedAt ?? this.restStartedAt),
        expedition: clearExpedition ? null : (expedition ?? this.expedition),
        compassReady: compassReady ?? this.compassReady,
      );

  Map<String, dynamic> toJson() => {
        'hp': hp,
        'lastMaxHp': lastMaxHp,
        'mp': mp,
        'mpAt': mpAt?.toIso8601String(),
        'stepsDay': stepsDay,
        'stepsCounted': stepsCounted,
        'restStartedAt': restStartedAt?.toIso8601String(),
        'expedition': expedition?.toJson(),
        'compassReady': compassReady,
      };

  factory Vitals.fromJson(Map<String, dynamic> j) => Vitals(
        hp: j['hp'] as int?,
        lastMaxHp: j['lastMaxHp'] as int?,
        mp: j['mp'] as int?,
        mpAt: j['mpAt'] == null ? null : DateTime.parse(j['mpAt'] as String),
        stepsDay: j['stepsDay'] as String?,
        stepsCounted: j['stepsCounted'] as int? ?? 0,
        restStartedAt: j['restStartedAt'] == null
            ? null
            : DateTime.parse(j['restStartedAt'] as String),
        expedition: j['expedition'] == null
            ? null
            : Expedition.fromJson(
                Map<String, dynamic>.from(j['expedition'] as Map)),
        compassReady: j['compassReady'] as bool? ?? false,
      );
}
