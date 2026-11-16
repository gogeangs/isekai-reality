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
    this.smallOffer = const {},
    this.smallBoard = const [],
    this.small = const {},
    this.smallDone = const {},
    this.smallLast = const {},
    this.boardDone = const {},
    this.relicMiss = const {},
    this.relicOffer = const [],
    this.relic = const {},
    this.relics = const [],
    this.walkDay,
    this.walkSteps = 0,
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

  // ───────────── 묶음 45 #231·#232

  /// 받을 수 있는 작은 부탁 (사람 → 작은 부탁 번호)
  final Map<String, int> smallOffer;

  /// 게시판 쪽지를 여러 번 끝내서 생긴 작은 부탁 (「자주 해결」 말풍선)
  final List<String> smallBoard;

  /// 받은 작은 부탁 (사람마다 하나, index = 작은 부탁 번호)
  final Map<String, ActiveRequest> small;

  /// 끝낸 작은 부탁 수 · 마지막으로 준 작은 부탁 번호 (같은 걸 연달아 주지 않게)
  final Map<String, int> smallDone;
  final Map<String, int> smallLast;

  /// 끝낸 게시판 마을 사람 쪽지 수
  final Map<String, int> boardDone;

  /// 전용 퀘스트가 안 나온 횟수 (확률이 조금씩 오름)
  final Map<String, int> relicMiss;

  /// 받을 수 있는 전용 퀘스트 · 받은 전용 퀘스트(index = 단계) · 받은 전용 아이템
  final List<String> relicOffer;
  final Map<String, ActiveRequest> relic;
  final List<String> relics;

  /// 전용 아이템 걷기 효과를 센 날 · 그날 센 걸음
  final String? walkDay;
  final int walkSteps;

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
    Map<String, int>? smallOffer,
    List<String>? smallBoard,
    Map<String, ActiveRequest>? small,
    Map<String, int>? smallDone,
    Map<String, int>? smallLast,
    Map<String, int>? boardDone,
    Map<String, int>? relicMiss,
    List<String>? relicOffer,
    Map<String, ActiveRequest>? relic,
    List<String>? relics,
    String? walkDay,
    int? walkSteps,
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
        smallOffer: smallOffer ?? this.smallOffer,
        smallBoard: smallBoard ?? this.smallBoard,
        small: small ?? this.small,
        smallDone: smallDone ?? this.smallDone,
        smallLast: smallLast ?? this.smallLast,
        boardDone: boardDone ?? this.boardDone,
        relicMiss: relicMiss ?? this.relicMiss,
        relicOffer: relicOffer ?? this.relicOffer,
        relic: relic ?? this.relic,
        relics: relics ?? this.relics,
        walkDay: walkDay ?? this.walkDay,
        walkSteps: walkSteps ?? this.walkSteps,
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
        if (smallOffer.isNotEmpty) 'sOffer': smallOffer,
        if (smallBoard.isNotEmpty) 'sBoard': smallBoard,
        if (small.isNotEmpty)
          'small': {for (final e in small.entries) e.key: e.value.toJson()},
        if (smallDone.isNotEmpty) 'sDone': smallDone,
        if (smallLast.isNotEmpty) 'sLast': smallLast,
        if (boardDone.isNotEmpty) 'bDone': boardDone,
        if (relicMiss.isNotEmpty) 'rMiss': relicMiss,
        if (relicOffer.isNotEmpty) 'rOffer': relicOffer,
        if (relic.isNotEmpty)
          'relic': {for (final e in relic.entries) e.key: e.value.toJson()},
        if (relics.isNotEmpty) 'relics': relics,
        if (walkDay != null) 'walkDay': walkDay,
        if (walkSteps > 0) 'walk': walkSteps,
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
        smallOffer: _ints(j['sOffer']),
        smallBoard: [for (final x in (j['sBoard'] as List?) ?? const []) '$x'],
        small: _actives(j['small']),
        smallDone: _ints(j['sDone']),
        smallLast: _ints(j['sLast']),
        boardDone: _ints(j['bDone']),
        relicMiss: _ints(j['rMiss']),
        relicOffer: [for (final x in (j['rOffer'] as List?) ?? const []) '$x'],
        relic: _actives(j['relic']),
        relics: [for (final x in (j['relics'] as List?) ?? const []) '$x'],
        walkDay: j['walkDay'] as String?,
        walkSteps: ((j['walk'] as num?) ?? 0).toInt(),
      );

  static Map<String, ActiveRequest> _actives(Object? raw) => {
        for (final e in ((raw as Map?) ?? const {}).entries)
          if (ActiveRequest.fromJson(e.value) case final a?) '${e.key}': a,
      };
}
