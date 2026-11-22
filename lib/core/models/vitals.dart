import 'dart:math' as math;

/// 정령·펫 원정 하나 (11-11 #38: 펫마다 하나씩 동시에)
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
    this.escaped = false,
    this.reward = const {},
    this.newSpecies = false,
    this.route = const [],
    this.petUid,
    this.petName,
    this.baseReward = const {},
    this.adUsed = const {},
    this.sky = false,
    bool? back,
  }) : back = back ?? cleared != null;

  /// 돌아왔는지 (묶음 23 #172: 싸움 결과는 도착할 때 정하고, 결과 카드는 돌아온 뒤).
  /// 예전 기록은 결과가 있으면 돌아온 것으로 본다
  final bool back;

  /// 싸움 결과를 정했는지 (도착한 뒤)
  bool get decided => cleared != null;

  /// 돌아온 것으로 표시
  Expedition returned() => copy(back: true);

  /// 기본 보상 (펫 특기로 더 가져온 것 빼고). 광고 보고 두 배는 이것만 (묶음 15 #103)
  final Map<String, int> baseReward;

  /// 이 원정에 이미 쓴 광고 보상 ('half' 시간 절반 · 'double' 보상 두 배 · 'again' 한 번 더)
  final Set<String> adUsed;

  /// 시간을 [cut] 만큼 앞당긴다 (아직 돌아오지 않았을 때, 남은 시간 안에서)
  Expedition shortened(Duration cut, DateTime now, {String? ad}) {
    final arrive = arriveAt.isAfter(now) ? arriveAt.subtract(cut) : arriveAt;
    return copy(
      arriveAt: arrive.isBefore(now) ? now : arrive,
      returnAt: returnAt.subtract(cut).isBefore(now) ? now : returnAt.subtract(cut),
      adUsed: ad == null ? null : {...adUsed, ad},
    );
  }

  Expedition copy({
    DateTime? arriveAt,
    DateTime? returnAt,
    Set<String>? adUsed,
    bool? back,
  }) =>
      Expedition(
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
        arriveAt: arriveAt ?? this.arriveAt,
        returnAt: returnAt ?? this.returnAt,
        cleared: cleared,
        escaped: escaped,
        reward: reward,
        newSpecies: newSpecies,
        route: route,
        petUid: petUid,
        petName: petName,
        baseReward: baseReward,
        adUsed: adUsed ?? this.adUsed,
        sky: sky,
        back: back ?? this.back,
      );

  /// 묶음 70 #294: 하늘을 나는 펫이 곧장 날아가는 원정 (지도에 살짝 굽은 하늘 점선)
  final bool sky;

  /// 원정을 간 펫 (null 이면 정령)
  final String? petUid;
  final String? petName;

  /// 정령이 따라가는 길 (위도, 경도) 점들. 비어 있으면 직선 (11-11 #42)
  final List<(double, double)> route;

  /// 몬스터가 도망쳤는지 (황금빛 등, 11-11 #51)
  final bool escaped;

  /// 받은 보상 ('exp'·'manaStone'·'gold'·재료 이름 → 수)
  final Map<String, int> reward;

  /// 도감에 새로 오른 몬스터인지
  final bool newSpecies;

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

  /// 싸움 결과 (이김). 도착하기 전에는 null.
  final bool? cleared;

  /// 돌아와서 결과 카드를 볼 차례인지
  bool get finished => cleared != null && back;

  /// 가는 길 점들 (출발 → 몬스터). 끝은 언제나 몬스터 자리에 정확히 닿는다 (11-11 #90)
  List<(double, double)> get path {
    if (sky) return skyArc((fromLat ?? lat, fromLng ?? lng), (lat, lng));
    if (route.length < 2) return [(fromLat ?? lat, fromLng ?? lng), (lat, lng)];
    final last = route.last;
    if ((last.$1 - lat).abs() < 1e-7 && (last.$2 - lng).abs() < 1e-7) {
      return route;
    }
    return [...route, (lat, lng)];
  }

  /// 묶음 70 #294 · 72 #304: 두 점 사이를 살짝 굽은 하늘 길로 (가운데가 직선 길이의 10%만큼, 늘 가는 방향 왼쪽으로)
  static List<(double, double)> skyArc((double, double) a, (double, double) b) {
    final dy = b.$1 - a.$1, dx = b.$2 - a.$2;
    // 가는 방향의 왼쪽으로 (경도 보정은 대략)
    final cy = (a.$1 + b.$1) / 2 + dx * 0.8 * 0.2;
    final cx = (a.$2 + b.$2) / 2 - dy / 0.8 * 0.2;
    return [
      for (var i = 0; i <= 16; i++)
        () {
          final t = i / 16, u = 1 - t;
          return (
            u * u * a.$1 + 2 * u * t * cy + t * t * b.$1,
            u * u * a.$2 + 2 * u * t * cx + t * t * b.$2,
          );
        }()
    ];
  }

  /// 길 위에서 지금 있는 비율 (0 = 출발점, 1 = 몬스터)
  double tAt(DateTime now) {
    if (now.isBefore(arriveAt)) {
      final total = arriveAt.difference(startedAt).inMilliseconds;
      return (total <= 0 ? 1.0 : now.difference(startedAt).inMilliseconds / total)
          .clamp(0.0, 1.0);
    }
    if (now.isBefore(returnAt)) {
      final total = returnAt.difference(arriveAt).inMilliseconds;
      return (1 - (total <= 0 ? 1.0 : now.difference(arriveAt).inMilliseconds / total))
          .clamp(0.0, 1.0);
    }
    return 0;
  }

  /// 남은 길 (11-11 #92): 갈 때는 지금 자리 → 몬스터, 돌아올 때는 지금 자리 → 출발점.
  /// 발자국이 가는 방향을 가리키도록 언제나 지금 자리에서 시작한다.
  /// [skip] 만큼(0~1, 길 전체 비율) 앞부분을 건너뛴다 (발자국이 흘러가는 연출).
  List<(double, double)> remainingAt(DateTime now, {double skip = 0}) {
    final going = goingAt(now);
    final t = tAt(now);
    final pts = path;
    final from = going ? (t + skip).clamp(0.0, 1.0) : (t - skip).clamp(0.0, 1.0);
    final to = going ? 1.0 : 0.0;
    return subPath(pts, from, to);
  }

  /// 길의 [a]~[b] 구간 (b < a 면 거꾸로)
  static List<(double, double)> subPath(
      List<(double, double)> pts, double a, double b) {
    if (a > b) return subPath(pts, b, a).reversed.toList();
    if (pts.length < 2) return pts;
    final lens = <double>[0];
    var total = 0.0;
    for (var i = 1; i < pts.length; i++) {
      final dy = pts[i].$1 - pts[i - 1].$1;
      final dx = (pts[i].$2 - pts[i - 1].$2) * 0.8;
      total += math.sqrt(dx * dx + dy * dy);
      lens.add(total);
    }
    final out = <(double, double)>[pointAlong(pts, a)];
    for (var i = 1; i < pts.length - 1; i++) {
      final f = total == 0 ? 0 : lens[i] / total;
      if (f > a && f < b) out.add(pts[i]);
    }
    out.add(pointAlong(pts, b));
    return out;
  }

  /// 지금 정령이 있는 곳 (가는 길 → 몬스터 자리 → 돌아오는 길). (위도, 경도)
  (double, double) positionAt(DateTime now) => pointAlong(path, tAt(now));

  /// 점들을 이은 길에서 [t] (0~1) 만큼 간 곳
  static (double, double) pointAlong(List<(double, double)> pts, double t) {
    if (pts.length == 1) return pts.first;
    final lens = <double>[];
    var total = 0.0;
    for (var i = 1; i < pts.length; i++) {
      final dy = pts[i].$1 - pts[i - 1].$1;
      final dx = (pts[i].$2 - pts[i - 1].$2) * 0.8; // 위도 37° 언저리 경도 보정
      final d = math.sqrt(dx * dx + dy * dy);
      lens.add(d);
      total += d;
    }
    if (total == 0) return pts.first;
    var left = t * total;
    for (var i = 0; i < lens.length; i++) {
      if (left <= lens[i] || i == lens.length - 1) {
        final f = lens[i] == 0 ? 0.0 : (left / lens[i]).clamp(0.0, 1.0);
        final a = pts[i], b = pts[i + 1];
        return (a.$1 + (b.$1 - a.$1) * f, a.$2 + (b.$2 - a.$2) * f);
      }
      left -= lens[i];
    }
    return pts.last;
  }

  /// 몬스터에게 가는 중인지 (아니면 돌아오는 중)
  bool goingAt(DateTime now) => now.isBefore(arriveAt);

  Expedition withResult(bool cleared,
          {bool escaped = false,
          Map<String, int> reward = const {},
          Map<String, int>? baseReward,
          bool newSpecies = false}) =>
      Expedition(
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
        escaped: escaped,
        reward: reward,
        newSpecies: newSpecies,
        route: route,
        petUid: petUid,
        petName: petName,
        baseReward: baseReward ?? reward,
        adUsed: adUsed,
        sky: sky,
        back: false,
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
        'escaped': escaped,
        'reward': reward,
        'newSpecies': newSpecies,
        if (route.isNotEmpty) 'route': [for (final p in route) [p.$1, p.$2]],
        if (petUid != null) 'petUid': petUid,
        if (petName != null) 'petName': petName,
        if (baseReward.isNotEmpty) 'baseReward': baseReward,
        if (adUsed.isNotEmpty) 'adUsed': adUsed.toList(),
        if (sky) 'sky': true,
        'back': back,
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
        escaped: j['escaped'] as bool? ?? false,
        reward: {
          for (final e in ((j['reward'] as Map?) ?? const {}).entries)
            e.key as String: (e.value as num).toInt(),
        },
        newSpecies: j['newSpecies'] as bool? ?? false,
        petUid: j['petUid'] as String?,
        petName: j['petName'] as String?,
        sky: j['sky'] == true,
        baseReward: {
          for (final e in ((j['baseReward'] as Map?) ?? const {}).entries)
            e.key as String: (e.value as num).toInt(),
        },
        adUsed: {
          for (final a in (j['adUsed'] as List?) ?? const []) a as String,
        },
        route: [
          for (final p in (j['route'] as List?) ?? const [])
            (((p as List)[0] as num).toDouble(), (p[1] as num).toDouble()),
        ],
        back: j['back'] as bool?,
      );
}

/// 시간에 따라 바뀌는 상태: HP, 정령 MP, 여관 휴식, 정령 원정.
///
/// 묶음 81 #375: 잿빛 틈 · 하이랜드 섬으로 보낸 펫 (가서 기다리다가, 싸우거나 기다림이 끝나면 돌아옴)
class SpotTrip {
  const SpotTrip({
    required this.kind,
    required this.key,
    required this.petUid,
    required this.petName,
    required this.lat,
    required this.lng,
    required this.distanceM,
    required this.mpCost,
    required this.startedAt,
    required this.arriveAt,
    required this.oneWaySec,
    required this.waitUntil,
    this.foughtAt,
    this.arrivalSeen = false,
  });

  /// 'rift' 잿빛 틈 · 'sky' 하이랜드 섬
  final String kind;

  /// 그 자리 (잿빛 틈: 날짜:분신, 섬: 날짜:섬) — 자리가 바뀌면 그 펫은 돌아옴
  final String key;
  final String petUid;
  final String petName;
  final double lat;
  final double lng;
  final double distanceM;
  final int mpCost;
  final DateTime startedAt;
  final DateTime arriveAt;
  final int oneWaySec;

  /// 그 자리에서 기다리는 끝 (잿빛 틈 30분 · 섬은 섬이 질 때까지 중 짧은 쪽)
  final DateTime waitUntil;

  /// 싸운 때 (이기든 지든). 그때부터 돌아오는 길
  final DateTime? foughtAt;

  /// 「닿았어!」 위쪽 띠를 보였는지
  final bool arrivalSeen;

  Duration get oneWay => Duration(seconds: oneWaySec);

  /// 돌아오는 때 (싸웠으면 싸운 뒤, 아니면 기다림이 끝난 뒤 + 가는 시간)
  DateTime get returnAt => (foughtAt ?? waitUntil).add(oneWay);

  /// 그 자리에서 기다리는 중 (싸울 수 있음)
  bool waiting(DateTime now) =>
      foughtAt == null && !now.isBefore(arriveAt) && now.isBefore(waitUntil);

  bool going(DateTime now) => now.isBefore(arriveAt);
  bool done(DateTime now) => !now.isBefore(returnAt);

  SpotTrip copy({DateTime? foughtAt, bool? arrivalSeen}) => SpotTrip(
        kind: kind,
        key: key,
        petUid: petUid,
        petName: petName,
        lat: lat,
        lng: lng,
        distanceM: distanceM,
        mpCost: mpCost,
        startedAt: startedAt,
        arriveAt: arriveAt,
        oneWaySec: oneWaySec,
        waitUntil: waitUntil,
        foughtAt: foughtAt ?? this.foughtAt,
        arrivalSeen: arrivalSeen ?? this.arrivalSeen,
      );

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'key': key,
        'petUid': petUid,
        'petName': petName,
        'lat': lat,
        'lng': lng,
        'distanceM': distanceM,
        'mpCost': mpCost,
        'startedAt': startedAt.toIso8601String(),
        'arriveAt': arriveAt.toIso8601String(),
        'oneWaySec': oneWaySec,
        'waitUntil': waitUntil.toIso8601String(),
        'foughtAt': foughtAt?.toIso8601String(),
        'arrivalSeen': arrivalSeen,
      };

  static SpotTrip? fromJson(Map<String, dynamic> j) {
    try {
      return SpotTrip(
        kind: j['kind'] as String,
        key: j['key'] as String,
        petUid: j['petUid'] as String,
        petName: j['petName'] as String? ?? '',
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        distanceM: (j['distanceM'] as num?)?.toDouble() ?? 0,
        mpCost: (j['mpCost'] as num?)?.toInt() ?? 0,
        startedAt: DateTime.parse(j['startedAt'] as String),
        arriveAt: DateTime.parse(j['arriveAt'] as String),
        oneWaySec: (j['oneWaySec'] as num).toInt(),
        waitUntil: DateTime.parse(j['waitUntil'] as String),
        foughtAt: j['foughtAt'] == null ? null : DateTime.parse(j['foughtAt'] as String),
        arrivalSeen: j['arrivalSeen'] as bool? ?? false,
      );
    } catch (_) {
      return null;
    }
  }
}

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
    this.restAt,
    this.restCarry = const [0, 0, 0],
    this.restAds = 0,
    this.restSec = 0,
    this.restCounted,
    this.restFullSeen = false,
    this.expeditions = const [],
    this.compassReady = false,
    this.trips = const [],
  });

  /// 묶음 81 #375: 잿빛 틈 · 섬으로 보낸 펫 (자리마다 하나)
  final List<SpotTrip> trips;

  /// 묶음 81 #373: 여관 회복을 마지막으로 셈한 때 (체크인 뒤)
  final DateTime? restAt;

  /// 여관 회복 소수 (HP · 기력 · 직업 MP)
  final List<double> restCarry;

  /// 이번 체크인에 본 「광고 보고 바로 회복」 수
  final int restAds;

  /// 이번 체크인에 실제로 회복한 시간(초, 원정으로 멈춘 시간 뺌)
  final int restSec;

  /// 「쉬었다」로 센 날 (같은 체크인에 하루 한 번)
  final String? restCounted;

  /// 이번 체크인에 「가득 찼어요」를 알렸는지
  final bool restFullSeen;

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

  /// 진행 중이거나 결과를 아직 보지 않은 원정 (펫마다 하나, 11-11 #38)
  final List<Expedition> expeditions;

  /// 첫 원정 (예전 코드·테스트용)
  Expedition? get expedition => expeditions.isEmpty ? null : expeditions.first;

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
    DateTime? restAt,
    List<double>? restCarry,
    int? restAds,
    int? restSec,
    String? restCounted,
    bool? restFullSeen,
    bool clearRest = false,
    Expedition? expedition,
    bool clearExpedition = false,
    List<Expedition>? expeditions,
    bool? compassReady,
    List<SpotTrip>? trips,
  }) =>
      Vitals(
        hp: hp ?? this.hp,
        lastMaxHp: lastMaxHp ?? this.lastMaxHp,
        mp: mp ?? this.mp,
        mpAt: mpAt ?? this.mpAt,
        stepsDay: stepsDay ?? this.stepsDay,
        stepsCounted: stepsCounted ?? this.stepsCounted,
        restStartedAt: clearRest ? null : (restStartedAt ?? this.restStartedAt),
        restAt: clearRest ? null : (restAt ?? this.restAt),
        restCarry: clearRest ? const [0, 0, 0] : (restCarry ?? this.restCarry),
        restAds: clearRest ? 0 : (restAds ?? this.restAds),
        restSec: clearRest ? 0 : (restSec ?? this.restSec),
        restCounted: clearRest ? null : (restCounted ?? this.restCounted),
        restFullSeen: clearRest ? false : (restFullSeen ?? this.restFullSeen),
        expeditions: expeditions ??
            (clearExpedition
                ? const []
                : expedition != null
                    ? [expedition]
                    : this.expeditions),
        compassReady: compassReady ?? this.compassReady,
        trips: trips ?? this.trips,
      );

  Map<String, dynamic> toJson() => {
        'hp': hp,
        'lastMaxHp': lastMaxHp,
        'mp': mp,
        'mpAt': mpAt?.toIso8601String(),
        'stepsDay': stepsDay,
        'stepsCounted': stepsCounted,
        'restStartedAt': restStartedAt?.toIso8601String(),
        'restAt': restAt?.toIso8601String(),
        'restCarry': restCarry,
        'restAds': restAds,
        'restSec': restSec,
        'restCounted': restCounted,
        'restFullSeen': restFullSeen,
        'expeditions': [for (final e in expeditions) e.toJson()],
        'compassReady': compassReady,
        'trips': [for (final t in trips) t.toJson()],
      };

  factory Vitals.fromJson(Map<String, dynamic> j) => Vitals(
        hp: (j['hp'] as num?)?.toInt(),
        lastMaxHp: (j['lastMaxHp'] as num?)?.toInt(),
        mp: (j['mp'] as num?)?.toInt(),
        mpAt: j['mpAt'] == null ? null : DateTime.parse(j['mpAt'] as String),
        stepsDay: j['stepsDay'] as String?,
        stepsCounted: (j['stepsCounted'] as num?)?.toInt() ?? 0,
        restStartedAt: j['restStartedAt'] == null
            ? null
            : DateTime.parse(j['restStartedAt'] as String),
        restAt: j['restAt'] is String ? DateTime.tryParse(j['restAt'] as String) : null,
        restCarry: [
          for (final x in (j['restCarry'] as List?) ?? const [0, 0, 0]) (x as num).toDouble(),
        ],
        restAds: (j['restAds'] as num?)?.toInt() ?? 0,
        restSec: (j['restSec'] as num?)?.toInt() ?? 0,
        restCounted: j['restCounted'] as String?,
        restFullSeen: j['restFullSeen'] as bool? ?? false,
        // 예전 저장본은 원정 하나 ('expedition')
        expeditions: [
          for (final e in (j['expeditions'] as List?) ??
              [if (j['expedition'] != null) j['expedition']])
            Expedition.fromJson(Map<String, dynamic>.from(e as Map)),
        ],
        compassReady: j['compassReady'] as bool? ?? false,
        trips: [
          for (final t in (j['trips'] as List?) ?? const [])
            if (t is Map)
              if (SpotTrip.fromJson(Map<String, dynamic>.from(t)) case final x?) x,
        ],
      );
}
