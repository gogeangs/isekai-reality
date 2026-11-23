/// 묶음 83 #389: 구름 걷기 한 번 (오를 때마다 새 판). 앱을 다시 켜도 판 · 바람 · 조각이 이어진다.
class SkyClimb {
  const SkyClimb({
    required this.slot,
    required this.seed,
    this.floor = 1,
    this.wind = 0,
    this.opened = const [],
    this.hero = 0,
    this.shards = 0,
    this.crystals = 0,
    this.stones = 0,
    this.soldier,
    this.awake = false,
  });

  /// 어느 섬(칸)에서 올랐는지 · 판 씨앗
  final String slot;
  final int seed;

  /// 1 · 2 · 3층
  final int floor;
  final int wind;

  /// 이 층에서 밝힌 칸 (판 번호)
  final List<int> opened;

  /// 주인공이 선 칸
  final int hero;

  /// 모은 유물 조각 (층마다 하나, 가방에 들지 않음)
  final int shards;

  /// 이번에 주운 하늘 결정 · 하늘 돌 조각 (주울 때 바로 가방에, 결과 창에 합계)
  final int crystals;
  final int stones;

  /// 밝혔는데 아직 싸우지 않은 석상 병사 칸
  final int? soldier;

  /// 수호자를 깨웠는지 (싸우다 나가면 진 것으로)
  final bool awake;

  SkyClimb copyWith({
    int? floor,
    int? wind,
    List<int>? opened,
    int? hero,
    int? shards,
    int? crystals,
    int? stones,
    int? Function()? soldier,
    bool? awake,
  }) =>
      SkyClimb(
        slot: slot,
        seed: seed,
        floor: floor ?? this.floor,
        wind: wind ?? this.wind,
        opened: opened ?? this.opened,
        hero: hero ?? this.hero,
        shards: shards ?? this.shards,
        crystals: crystals ?? this.crystals,
        stones: stones ?? this.stones,
        soldier: soldier != null ? soldier() : this.soldier,
        awake: awake ?? this.awake,
      );

  Map<String, dynamic> toJson() => {
        'slot': slot,
        'seed': seed,
        'floor': floor,
        'wind': wind,
        'opened': opened,
        'hero': hero,
        if (shards > 0) 'shards': shards,
        if (crystals > 0) 'crystals': crystals,
        if (stones > 0) 'stones': stones,
        if (soldier != null) 'soldier': soldier,
        if (awake) 'awake': true,
      };

  static SkyClimb? fromJson(Object? o) {
    if (o is! Map) return null;
    final slot = o['slot'], seed = o['seed'];
    if (slot is! String || seed is! num) return null;
    int i(String k) => ((o[k] as num?) ?? 0).toInt();
    return SkyClimb(
      slot: slot,
      seed: seed.toInt(),
      floor: i('floor').clamp(1, 3),
      wind: i('wind').clamp(0, 999),
      opened: [
        for (final x in (o['opened'] as List?) ?? const [])
          if (x is num) x.toInt(),
      ],
      hero: i('hero'),
      shards: i('shards').clamp(0, 3),
      crystals: i('crystals'),
      stones: i('stones'),
      soldier: (o['soldier'] as num?)?.toInt(),
      awake: o['awake'] == true,
    );
  }
}

/// 하이랜드 기록 (묶음 50 #146). 따로 저장한다 ('highland').
/// 예전 기록에는 없으니 없으면 처음부터 (#124: 저장 칸만 더함).
class HighlandState {
  const HighlandState({
    this.sceneSeen = false,
    this.starter = false,
    this.climbedEver = false,
    this.firstLine = false,
    this.beaten = const [],
    this.slot,
    this.isle,
    this.lat,
    this.lng,
    this.climbed = false,
    this.cleared = false,
    this.amDay,
    this.amIsle,
    this.featherDay,
    this.featherGot = 0,
    this.climb,
    this.guideSeen = false,
    this.fought = const [],
  });

  /// 묶음 83: 지금 하고 있는 구름 걷기 (없으면 null)
  final SkyClimb? climb;

  /// 처음 오를 때 안내를 봤는지 (첫 카드에서 저장, #383)
  final bool guideSeen;

  /// 수호자와 한 번이라도 싸운 섬 (처음 싸울 때만 초록 힌트)
  final List<int> fought;

  /// 처음 섬이 뜰 때 짧은 장면을 봤는지
  final bool sceneSeen;

  /// 처음 열릴 때 첫 펫이 주운 깃털을 받았는지
  final bool starter;

  /// 섬에 한 번이라도 올랐는지 (첫 펫 한마디 · 칭호)
  final bool climbedEver;

  /// 처음 섬에 올랐을 때 한마디를 봤는지
  final bool firstLine;

  /// 수호자를 쓰러뜨린 섬 (Isle 순서 번호). 비문도 이 섬들
  final List<int> beaten;

  /// 지금(마지막) 떠오른 섬의 칸 ('yyyy-mm-dd-am') · 섬 · 자리
  final String? slot;
  final int? isle;
  final double? lat;
  final double? lng;

  /// 이 칸의 섬에 올랐는지 (떠 있는 동안 몇 번이든 다시 도전) · 수호자를 쓰러뜨렸는지
  final bool climbed;
  final bool cleared;

  /// 그날 아침 섬 (저녁은 다른 섬)
  final String? amDay;
  final int? amIsle;

  /// 걸어서 받은 깃털 (그날 · 개수)
  final String? featherDay;
  final int featherGot;

  /// 첫 섬이 아직 안 떴는지 (첫 섬은 바람 고정)
  bool get firstIsle => slot == null;

  HighlandState copyWith({
    bool? sceneSeen,
    bool? starter,
    bool? climbedEver,
    bool? firstLine,
    List<int>? beaten,
    String? slot,
    int? isle,
    double? lat,
    double? lng,
    bool? climbed,
    bool? cleared,
    String? amDay,
    int? amIsle,
    String? featherDay,
    int? featherGot,
    SkyClimb? Function()? climb,
    bool? guideSeen,
    List<int>? fought,
  }) =>
      HighlandState(
        sceneSeen: sceneSeen ?? this.sceneSeen,
        starter: starter ?? this.starter,
        climbedEver: climbedEver ?? this.climbedEver,
        firstLine: firstLine ?? this.firstLine,
        beaten: beaten ?? this.beaten,
        slot: slot ?? this.slot,
        isle: isle ?? this.isle,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        climbed: climbed ?? this.climbed,
        cleared: cleared ?? this.cleared,
        amDay: amDay ?? this.amDay,
        amIsle: amIsle ?? this.amIsle,
        featherDay: featherDay ?? this.featherDay,
        featherGot: featherGot ?? this.featherGot,
        climb: climb != null ? climb() : this.climb,
        guideSeen: guideSeen ?? this.guideSeen,
        fought: fought ?? this.fought,
      );

  Map<String, dynamic> toJson() => {
        'v': 1,
        if (sceneSeen) 'scene': true,
        if (starter) 'starter': true,
        if (climbedEver) 'climbedEver': true,
        if (firstLine) 'firstLine': true,
        'beaten': beaten,
        if (slot != null) 'slot': slot,
        if (isle != null) 'isle': isle,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (climbed) 'climbed': true,
        if (cleared) 'cleared': true,
        if (amDay != null) 'amDay': amDay,
        if (amIsle != null) 'amIsle': amIsle,
        if (featherDay != null) 'featherDay': featherDay,
        if (featherGot > 0) 'featherGot': featherGot,
        if (climb != null) 'climb': climb!.toJson(),
        if (guideSeen) 'guide': true,
        if (fought.isNotEmpty) 'fought': fought,
      };

  static HighlandState fromJson(Map<String, dynamic> j) => HighlandState(
        sceneSeen: j['scene'] == true,
        starter: j['starter'] == true,
        climbedEver: j['climbedEver'] == true,
        firstLine: j['firstLine'] == true,
        beaten: [
          for (final x in (j['beaten'] as List?) ?? const [])
            if (x is num && x >= 0 && x < 5) x.toInt(),
        ],
        slot: j['slot'] as String?,
        isle: (j['isle'] as num?)?.toInt(),
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        climbed: j['climbed'] == true,
        cleared: j['cleared'] == true,
        amDay: j['amDay'] as String?,
        amIsle: (j['amIsle'] as num?)?.toInt(),
        featherDay: j['featherDay'] as String?,
        featherGot: ((j['featherGot'] as num?) ?? 0).toInt(),
        climb: SkyClimb.fromJson(j['climb']),
        guideSeen: j['guide'] == true,
        fought: [
          for (final x in (j['fought'] as List?) ?? const [])
            if (x is num && x >= 0 && x < 5) x.toInt(),
        ],
      );
}
