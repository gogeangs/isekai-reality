/// 던전 한 번의 결과
class DungeonRun {
  const DungeonRun({required this.cleared, this.atGate = false});

  /// 클리어했으면 true, 실패했으면 false
  final bool cleared;

  /// 지도의 미궁 입구 근처에서 열었는지 (보상 1.5배)
  final bool atGate;

  Map<String, dynamic> toJson() => {'cleared': cleared, 'atGate': atGate};

  factory DungeonRun.fromJson(Map<String, dynamic> json) => DungeonRun(
        cleared: json['cleared'] as bool? ?? false,
        atGate: json['atGate'] as bool? ?? false,
      );
}

/// 하루 동안의 활동 기록. 규칙 엔진의 입력값이다.
///
/// 걸음·수면은 건강 앱(HealthKit / Health Connect)에서 읽고,
/// 공부는 직접 기록, 나머지는 게임 안에서 쌓인다.
class DailyRecord {
  const DailyRecord({
    required this.date,
    this.steps = 0,
    this.stepsAfter8pm = 0,
    this.sleepMinutes,
    this.studyMinutes = 0,
    this.stepGoal = 5000,
    this.dungeonRuns = const [],
    this.fieldMonstersPurified = 0,
    this.newPlacesVisited = 0,
    this.placesRevisited = 0,
    this.questsCompleted = 0,
    this.openedApp = true,
    this.visitedPlaceIds = const [],
    this.purifiedMonsterIds = const [],
    this.purifiedSpawnIds = const [],
    this.shopPurchases = const [],
    this.restedAtInn = false,
  });

  final DateTime date;
  final int steps;
  final int stepsAfter8pm;

  /// 지난밤 수면(분). 기록이 없으면 null.
  final int? sleepMinutes;

  final int studyMinutes;

  /// 그날 적용된 걸음 목표
  final int stepGoal;

  final List<DungeonRun> dungeonRuns;
  final int fieldMonstersPurified;
  final int newPlacesVisited;

  /// 다시 방문한 서로 다른 장소 수 (장소마다 하루 한 번만 센다)
  final int placesRevisited;

  final int questsCompleted;
  final bool openedApp;

  /// 오늘 방문한 장소 id (같은 장소는 하루 한 번만 센다)
  final List<String> visitedPlaceIds;

  /// 오늘 정화한 몬스터 종류 (던전·필드 모두, 도감용. [MonsterId] 이름)
  final List<String> purifiedMonsterIds;

  /// 오늘 정화한 필드 몬스터 자리 id (같은 자리는 다시 나오지 않음)
  final List<String> purifiedSpawnIds;

  /// 오늘 잡화상에서 산 물건 ([ShopItem] 이름, 산 순서대로)
  final List<String> shopPurchases;

  /// 오늘 밤 여관에 체크인했는지 (다음 날 수면 보상 +10)
  final bool restedAtInn;

  /// 날짜만 남긴 키 (예: '2026-11-08')
  String get dayKey => dayKeyOf(date);

  static String dayKeyOf(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
        'date': dayKey,
        'steps': steps,
        'stepsAfter8pm': stepsAfter8pm,
        'sleepMinutes': sleepMinutes,
        'studyMinutes': studyMinutes,
        'stepGoal': stepGoal,
        'dungeonRuns': dungeonRuns.map((r) => r.toJson()).toList(),
        'fieldMonstersPurified': fieldMonstersPurified,
        'newPlacesVisited': newPlacesVisited,
        'placesRevisited': placesRevisited,
        'questsCompleted': questsCompleted,
        'openedApp': openedApp,
        'visitedPlaceIds': visitedPlaceIds,
        'purifiedMonsterIds': purifiedMonsterIds,
        'purifiedSpawnIds': purifiedSpawnIds,
        'shopPurchases': shopPurchases,
        'restedAtInn': restedAtInn,
      };

  factory DailyRecord.fromJson(Map<String, dynamic> json) {
    final parts = (json['date'] as String).split('-').map(int.parse).toList();
    return DailyRecord(
      date: DateTime(parts[0], parts[1], parts[2]),
      steps: json['steps'] as int? ?? 0,
      stepsAfter8pm: json['stepsAfter8pm'] as int? ?? 0,
      sleepMinutes: json['sleepMinutes'] as int?,
      studyMinutes: json['studyMinutes'] as int? ?? 0,
      stepGoal: json['stepGoal'] as int? ?? 5000,
      dungeonRuns: ((json['dungeonRuns'] as List?) ?? const [])
          .map((e) => DungeonRun.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      fieldMonstersPurified: json['fieldMonstersPurified'] as int? ?? 0,
      newPlacesVisited: json['newPlacesVisited'] as int? ?? 0,
      placesRevisited: json['placesRevisited'] as int? ?? 0,
      questsCompleted: json['questsCompleted'] as int? ?? 0,
      openedApp: json['openedApp'] as bool? ?? true,
      visitedPlaceIds: ((json['visitedPlaceIds'] as List?) ?? const [])
          .map((e) => e as String)
          .toList(),
      purifiedMonsterIds: ((json['purifiedMonsterIds'] as List?) ?? const [])
          .map((e) => e as String)
          .toList(),
      purifiedSpawnIds: ((json['purifiedSpawnIds'] as List?) ?? const [])
          .map((e) => e as String)
          .toList(),
      shopPurchases: ((json['shopPurchases'] as List?) ?? const [])
          .map((e) => e as String)
          .toList(),
      restedAtInn: json['restedAtInn'] as bool? ?? false,
    );
  }

  bool get stepGoalAchieved => steps >= stepGoal;

  bool get sleptWell => (sleepMinutes ?? 0) >= 7 * 60;

  DailyRecord copyWith({
    int? steps,
    int? stepsAfter8pm,
    int? sleepMinutes,
    int? studyMinutes,
    int? stepGoal,
    List<DungeonRun>? dungeonRuns,
    int? fieldMonstersPurified,
    int? newPlacesVisited,
    int? placesRevisited,
    int? questsCompleted,
    bool? openedApp,
    List<String>? visitedPlaceIds,
    List<String>? purifiedMonsterIds,
    List<String>? purifiedSpawnIds,
    List<String>? shopPurchases,
    bool? restedAtInn,
  }) {
    return DailyRecord(
      date: date,
      steps: steps ?? this.steps,
      stepsAfter8pm: stepsAfter8pm ?? this.stepsAfter8pm,
      sleepMinutes: sleepMinutes ?? this.sleepMinutes,
      studyMinutes: studyMinutes ?? this.studyMinutes,
      stepGoal: stepGoal ?? this.stepGoal,
      dungeonRuns: dungeonRuns ?? this.dungeonRuns,
      fieldMonstersPurified:
          fieldMonstersPurified ?? this.fieldMonstersPurified,
      newPlacesVisited: newPlacesVisited ?? this.newPlacesVisited,
      placesRevisited: placesRevisited ?? this.placesRevisited,
      questsCompleted: questsCompleted ?? this.questsCompleted,
      openedApp: openedApp ?? this.openedApp,
      visitedPlaceIds: visitedPlaceIds ?? this.visitedPlaceIds,
      purifiedMonsterIds: purifiedMonsterIds ?? this.purifiedMonsterIds,
      purifiedSpawnIds: purifiedSpawnIds ?? this.purifiedSpawnIds,
      shopPurchases: shopPurchases ?? this.shopPurchases,
      restedAtInn: restedAtInn ?? this.restedAtInn,
    );
  }
}
