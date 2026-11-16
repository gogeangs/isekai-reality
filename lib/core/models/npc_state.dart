/// 받은 마을 사람 부탁 하나 (묶음 42 #226)
class ActiveRequest {
  const ActiveRequest({
    required this.index,
    required this.day,
    this.base = const {},
    this.innDays = const [],
    this.steps = 0,
    this.clonesDone = false,
  });

  /// 몇 번째 부탁 (0~3)
  final int index;

  /// 받은 날 ('yyyy-mm-dd')
  final String day;

  /// 받을 때의 셈 (받은 뒤부터 센다)
  final Map<String, int> base;

  /// 받은 뒤 여관에서 쉰 날 (연속 휴식)
  final List<String> innDays;

  /// 받을 때 그날 걸음 (받은 뒤 걸음을 센다)
  final int steps;

  /// 받을 때 이미 분신을 모두 쓰러뜨렸는지
  final bool clonesDone;

  ActiveRequest copyWith({List<String>? innDays}) => ActiveRequest(
        index: index,
        day: day,
        base: base,
        innDays: innDays ?? this.innDays,
        steps: steps,
        clonesDone: clonesDone,
      );

  Map<String, dynamic> toJson() => {
        'i': index,
        'day': day,
        'base': base,
        if (innDays.isNotEmpty) 'inn': innDays,
        'steps': steps,
        if (clonesDone) 'clones': true,
      };

  static ActiveRequest? fromJson(Object? raw) {
    if (raw is! Map || raw['i'] is! num || raw['day'] is! String) return null;
    return ActiveRequest(
      index: (raw['i'] as num).toInt(),
      day: raw['day'] as String,
      base: {
        for (final e in ((raw['base'] as Map?) ?? const {}).entries)
          if (e.value is num) '${e.key}': (e.value as num).toInt(),
      },
      innDays: [for (final d in (raw['inn'] as List?) ?? const []) '$d'],
      steps: ((raw['steps'] as num?) ?? 0).toInt(),
      clonesDone: raw['clones'] == true,
    );
  }
}

/// 마을 사람 친해지기 · 부탁 (묶음 42 #226). 따로 저장한다 ('npc').
/// 점수·단계는 화면에 보이지 않는다.
class NpcState {
  const NpcState({
    this.points = const {},
    this.shown = const {},
    this.day,
    this.visited = const [],
    this.uses = const {},
    this.done = const {},
    this.active = const {},
    this.tally = const {},
    this.whetstones = 0,
    this.perks = const [],
  });

  /// 마을 사람마다 숨은 점수
  final Map<String, int> points;

  /// 알린(선물 우편을 보낸) 단계 (FavorStage index)
  final Map<String, int> shown;

  /// 오늘 ('yyyy-mm-dd') · 오늘 들른 사람 · 오늘 쓴 횟수
  final String? day;
  final List<String> visited;
  final Map<String, int> uses;

  /// 끝낸 부탁 수 (= 모은 사연 조각 수)
  final Map<String, int> done;

  /// 받은 부탁 (사람마다 하나)
  final Map<String, ActiveRequest> active;

  /// 부탁이 세는 일 (계속 쌓임)
  final Map<String, int> tally;

  /// 도르군의 숫돌 (강화 한 번 꼭 성공)
  final int whetstones;

  /// 계속 듣는 특별 보상 ('minaPouch' · 'lumiNest')
  final List<String> perks;

  int pointsOf(String npc) => points[npc] ?? 0;
  int doneOf(String npc) => done[npc] ?? 0;

  NpcState copyWith({
    Map<String, int>? points,
    Map<String, int>? shown,
    String? day,
    List<String>? visited,
    Map<String, int>? uses,
    Map<String, int>? done,
    Map<String, ActiveRequest>? active,
    Map<String, int>? tally,
    int? whetstones,
    List<String>? perks,
  }) =>
      NpcState(
        points: points ?? this.points,
        shown: shown ?? this.shown,
        day: day ?? this.day,
        visited: visited ?? this.visited,
        uses: uses ?? this.uses,
        done: done ?? this.done,
        active: active ?? this.active,
        tally: tally ?? this.tally,
        whetstones: whetstones ?? this.whetstones,
        perks: perks ?? this.perks,
      );

  Map<String, dynamic> toJson() => {
        'v': 1,
        'points': points,
        'shown': shown,
        if (day != null) 'day': day,
        'visited': visited,
        'uses': uses,
        'done': done,
        'active': {for (final e in active.entries) e.key: e.value.toJson()},
        'tally': tally,
        'whet': whetstones,
        'perks': perks,
      };

  static Map<String, int> _ints(Object? raw) => {
        for (final e in ((raw as Map?) ?? const {}).entries)
          if (e.value is num) '${e.key}': (e.value as num).toInt(),
      };

  factory NpcState.fromJson(Map<String, dynamic> j) => NpcState(
        points: _ints(j['points']),
        shown: _ints(j['shown']),
        day: j['day'] as String?,
        visited: [for (final x in (j['visited'] as List?) ?? const []) '$x'],
        uses: _ints(j['uses']),
        done: _ints(j['done']),
        active: {
          for (final e in ((j['active'] as Map?) ?? const {}).entries)
            if (ActiveRequest.fromJson(e.value) case final a?) '${e.key}': a,
        },
        tally: _ints(j['tally']),
        whetstones: ((j['whet'] as num?) ?? 0).toInt(),
        perks: [for (final x in (j['perks'] as List?) ?? const []) '$x'],
      );
}
