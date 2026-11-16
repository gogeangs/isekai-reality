/// 훈련장 기록 (묶음 43 #228). 따로 저장한다 ('training').
class TrainingState {
  const TrainingState({
    this.dailyDay,
    this.trialDay,
    this.trialWeek,
    this.trialBest = 0,
    this.trialMarks = const [],
    this.trialEver = 0,
    this.petUid,
    this.petEnd,
    this.petDay,
  });

  /// 하루 훈련을 한 날 ('yyyy-mm-dd')
  final String? dailyDay;

  /// 시련에 도전한 날
  final String? trialDay;

  /// 이번 주 (월요일 'yyyy-mm-dd') · 이번 주 최고 판 · 이번 주 받은 보상 판
  final String? trialWeek;
  final int trialBest;
  final List<int> trialMarks;

  /// 지금까지 가장 많이 넘긴 판
  final int trialEver;

  /// 훈련 중인 펫 · 끝나는 때 · 맡긴 날
  final String? petUid;
  final DateTime? petEnd;
  final String? petDay;

  TrainingState copyWith({
    String? dailyDay,
    String? trialDay,
    String? trialWeek,
    int? trialBest,
    List<int>? trialMarks,
    int? trialEver,
    String? petUid,
    DateTime? petEnd,
    String? petDay,
    bool clearPet = false,
  }) =>
      TrainingState(
        dailyDay: dailyDay ?? this.dailyDay,
        trialDay: trialDay ?? this.trialDay,
        trialWeek: trialWeek ?? this.trialWeek,
        trialBest: trialBest ?? this.trialBest,
        trialMarks: trialMarks ?? this.trialMarks,
        trialEver: trialEver ?? this.trialEver,
        petUid: clearPet ? null : petUid ?? this.petUid,
        petEnd: clearPet ? null : petEnd ?? this.petEnd,
        petDay: petDay ?? this.petDay,
      );

  Map<String, dynamic> toJson() => {
        'v': 1,
        if (dailyDay != null) 'daily': dailyDay,
        if (trialDay != null) 'trialDay': trialDay,
        if (trialWeek != null) 'week': trialWeek,
        'best': trialBest,
        'marks': trialMarks,
        'ever': trialEver,
        if (petUid != null) 'pet': petUid,
        if (petEnd != null) 'petEnd': petEnd!.toIso8601String(),
        if (petDay != null) 'petDay': petDay,
      };

  factory TrainingState.fromJson(Map<String, dynamic> j) => TrainingState(
        dailyDay: j['daily'] as String?,
        trialDay: j['trialDay'] as String?,
        trialWeek: j['week'] as String?,
        trialBest: ((j['best'] as num?) ?? 0).toInt(),
        trialMarks: [
          for (final x in (j['marks'] as List?) ?? const [])
            if (x is num) x.toInt(),
        ],
        trialEver: ((j['ever'] as num?) ?? 0).toInt(),
        petUid: j['pet'] as String?,
        petEnd: DateTime.tryParse('${j['petEnd'] ?? ''}'),
        petDay: j['petDay'] as String?,
      );
}
