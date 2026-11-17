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
  });

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
      );
}
