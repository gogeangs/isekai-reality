/// 2막 진행 (묶음 34): 쓰러뜨린 분신 · 본체 단계 · 결말 · 그날 잿빛 틈 자리.
/// 저장 키 'act2'. 없으면 처음부터 (Lv.12 이상이면 분노의 잿빛 틈부터).
class Act2State {
  const Act2State({
    this.beaten = 0,
    this.kingPhase = 0,
    this.kingDone = false,
    this.endingSeen = false,
    this.bridgeShown = false,
    this.announced = 0,
    this.storiesSeen = 0,
    this.riftDay,
    this.riftFor = -1,
    this.riftLat,
    this.riftLng,
    this.riftAnchorLat,
    this.riftAnchorLng,
    this.lossDay,
    this.losses = 0,
    this.memories = const [0, 0, 0, 0, 0],
  });

  /// 묶음 82 #394: 분신마다 본 왕의 기억 조각 수 (0~3)
  final List<int> memories;

  int memoriesOf(int avatar) => avatar >= 0 && avatar < memories.length ? memories[avatar] : 0;

  /// 쓰러뜨린 분신 수 (0~5, 차례대로)
  final int beaten;

  /// 본체에서 걷어낸 감정 단계 수 (0~5)
  final int kingPhase;
  final bool kingDone;

  /// 결말 컷신을 봤는지 (한 번만)
  final bool endingSeen;

  /// 「다리 너머 세계가 곧 열려요」를 알렸는지
  final bool bridgeShown;

  /// 첫 펫이 알린 수 (분신마다 처음 한 번 1~5, 「문 앞」이 열리면 6)
  final int announced;

  /// 창으로 본 왕의 사연 수 (기록 탭에는 쓰러뜨린 만큼 남는다)
  final int storiesSeen;

  /// 그날 잿빛 틈 자리 (그날 처음 위치를 잡은 곳 둘레, 하루 고정)
  final String? riftDay;

  /// 그 자리가 어느 분신의 틈인지 (분신을 쓰러뜨리면 다음 분신은 새 자리)
  final int riftFor;
  final double? riftLat;
  final double? riftLng;

  /// 그날 처음 위치를 잡은 곳 (그날 다음 분신도 이 둘레에)
  final double? riftAnchorLat;
  final double? riftAnchorLng;

  /// 그날 진 횟수 (3번이면 내일)
  final String? lossDay;
  final int losses;

  int lossesOn(String day) => lossDay == day ? losses : 0;

  Act2State copyWith({
    int? beaten,
    int? kingPhase,
    bool? kingDone,
    bool? endingSeen,
    bool? bridgeShown,
    int? announced,
    int? storiesSeen,
    String? riftDay,
    int? riftFor,
    double? riftLat,
    double? riftLng,
    double? riftAnchorLat,
    double? riftAnchorLng,
    String? lossDay,
    int? losses,
    List<int>? memories,
  }) =>
      Act2State(
        beaten: beaten ?? this.beaten,
        kingPhase: kingPhase ?? this.kingPhase,
        kingDone: kingDone ?? this.kingDone,
        endingSeen: endingSeen ?? this.endingSeen,
        bridgeShown: bridgeShown ?? this.bridgeShown,
        announced: announced ?? this.announced,
        storiesSeen: storiesSeen ?? this.storiesSeen,
        riftDay: riftDay ?? this.riftDay,
        riftFor: riftFor ?? this.riftFor,
        riftLat: riftLat ?? this.riftLat,
        riftLng: riftLng ?? this.riftLng,
        riftAnchorLat: riftAnchorLat ?? this.riftAnchorLat,
        riftAnchorLng: riftAnchorLng ?? this.riftAnchorLng,
        lossDay: lossDay ?? this.lossDay,
        losses: losses ?? this.losses,
        memories: memories ?? this.memories,
      );

  Map<String, dynamic> toJson() => {
        'beaten': beaten,
        'kingPhase': kingPhase,
        'kingDone': kingDone,
        'endingSeen': endingSeen,
        'bridgeShown': bridgeShown,
        'announced': announced,
        'storiesSeen': storiesSeen,
        if (riftDay != null) 'riftDay': riftDay,
        'riftFor': riftFor,
        if (riftLat != null) 'riftLat': riftLat,
        if (riftLng != null) 'riftLng': riftLng,
        if (riftAnchorLat != null) 'riftAnchorLat': riftAnchorLat,
        if (riftAnchorLng != null) 'riftAnchorLng': riftAnchorLng,
        if (lossDay != null) 'lossDay': lossDay,
        'losses': losses,
        'mem': memories,
      };

  static int _i(Object? v) => v is num ? v.toInt() : 0;

  factory Act2State.fromJson(Map<String, dynamic> j) => Act2State(
        beaten: _i(j['beaten']).clamp(0, 5),
        kingPhase: _i(j['kingPhase']).clamp(0, 5),
        kingDone: j['kingDone'] == true,
        endingSeen: j['endingSeen'] == true,
        bridgeShown: j['bridgeShown'] == true,
        announced: _i(j['announced']).clamp(0, 6),
        storiesSeen: _i(j['storiesSeen']).clamp(0, 5),
        riftDay: j['riftDay'] as String?,
        riftFor: j['riftFor'] is num ? (j['riftFor'] as num).toInt() : -1,
        riftLat: (j['riftLat'] as num?)?.toDouble(),
        riftLng: (j['riftLng'] as num?)?.toDouble(),
        riftAnchorLat: (j['riftAnchorLat'] as num?)?.toDouble(),
        riftAnchorLng: (j['riftAnchorLng'] as num?)?.toDouble(),
        lossDay: j['lossDay'] as String?,
        losses: _i(j['losses']),
        memories: [
          for (var i = 0; i < 5; i++)
            j['mem'] is List && (j['mem'] as List).length > i ? _i((j['mem'] as List)[i]).clamp(0, 3) : 0,
        ],
      );
}
