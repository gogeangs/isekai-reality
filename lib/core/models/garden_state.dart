/// 약초밭 한 칸에 심은 씨앗 (묶음 48 #230)
class GardenPlot {
  const GardenPlot({required this.seed, required this.day, required this.steps});

  /// 심은 씨앗 (재료 이름: 'herbSeed' 등)
  final String seed;

  /// 심은 날 ('yyyy-mm-dd') · 심을 때 그날 걸음 (심은 뒤 걸음만 센다)
  final String day;
  final int steps;

  Map<String, dynamic> toJson() => {'seed': seed, 'day': day, 'steps': steps};

  static GardenPlot? fromJson(Object? raw) {
    if (raw is! Map || raw['seed'] is! String || raw['day'] is! String) return null;
    return GardenPlot(
      seed: raw['seed'] as String,
      day: raw['day'] as String,
      steps: ((raw['steps'] as num?) ?? 0).toInt(),
    );
  }
}

/// 약초밭 기록 (묶음 48 #230). 따로 저장한다 ('garden').
class GardenState {
  const GardenState({
    this.plots = const {},
    this.harvested = 0,
    this.seenSeeds = const [],
    this.starter = false,
    this.openWeek,
    this.glowWeeks = const [],
  });

  /// 칸 번호(0부터) → 심은 씨앗. 빈 칸은 없음
  final Map<int, GardenPlot> plots;

  /// 지금까지 거둔 횟수
  final int harvested;

  /// 얻어 본 씨앗 (처음 보는 씨앗이면 포포 작은 부탁)
  final List<String> seenSeeds;

  /// 처음 열릴 때 포포가 나눠 준 씨앗을 받았는지
  final bool starter;

  /// 약초밭이 열린 주 (월요일 'yyyy-mm-dd'): 이 주부터 주간 의뢰 빛나는 씨앗
  final String? openWeek;

  /// 빛나는 씨앗을 준 주 (월요일 'yyyy-mm-dd')
  final List<String> glowWeeks;

  GardenState copyWith({
    Map<int, GardenPlot>? plots,
    int? harvested,
    List<String>? seenSeeds,
    bool? starter,
    String? openWeek,
    List<String>? glowWeeks,
  }) =>
      GardenState(
        plots: plots ?? this.plots,
        harvested: harvested ?? this.harvested,
        seenSeeds: seenSeeds ?? this.seenSeeds,
        starter: starter ?? this.starter,
        openWeek: openWeek ?? this.openWeek,
        glowWeeks: glowWeeks ?? this.glowWeeks,
      );

  Map<String, dynamic> toJson() => {
        'plots': {for (final e in plots.entries) '${e.key}': e.value.toJson()},
        'harvested': harvested,
        if (seenSeeds.isNotEmpty) 'seen': seenSeeds,
        if (starter) 'starter': true,
        if (openWeek != null) 'openWeek': openWeek,
        if (glowWeeks.isNotEmpty) 'glowWeeks': glowWeeks,
      };

  static GardenState fromJson(Map<String, dynamic> j) => GardenState(
        plots: {
          for (final e in ((j['plots'] as Map?) ?? const {}).entries)
            if (int.tryParse('${e.key}') case final i?)
              if (GardenPlot.fromJson(e.value) case final p?) i: p,
        },
        harvested: ((j['harvested'] as num?) ?? 0).toInt(),
        seenSeeds: [for (final s in (j['seen'] as List?) ?? const []) '$s'],
        starter: j['starter'] == true,
        openWeek: j['openWeek'] as String?,
        glowWeeks: [for (final s in (j['glowWeeks'] as List?) ?? const []) '$s'],
      );
}
