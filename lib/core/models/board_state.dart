/// 의뢰 게시판의 수시 의뢰 한 칸
class ErrandSlot {
  const ErrandSlot({
    this.templateId,
    this.accepted = false,
    this.baseline = 0,
    this.readyAt,
  });

  /// 올라온 의뢰 ([ErrandTemplate.id]). null 이면 빈 칸 (다음 의뢰를 기다림).
  final String? templateId;

  /// 수락했는지
  final bool accepted;

  /// 수락할 때의 진행 수 (이만큼 뺀 것이 진행)
  final int baseline;

  /// 빈 칸이면 새 의뢰가 올라오는 시각
  final DateTime? readyAt;

  bool get empty => templateId == null;

  Map<String, dynamic> toJson() => {
        'templateId': templateId,
        'accepted': accepted,
        'baseline': baseline,
        'readyAt': readyAt?.toIso8601String(),
      };

  factory ErrandSlot.fromJson(Map<String, dynamic> j) => ErrandSlot(
        templateId: j['templateId'] as String?,
        accepted: j['accepted'] as bool? ?? false,
        baseline: (j['baseline'] as num?)?.toInt() ?? 0,
        readyAt: j['readyAt'] == null
            ? null
            : DateTime.tryParse(j['readyAt'] as String),
      );
}

/// 의뢰 게시판 상태 (수시·긴급). 일일·주간은 하루 기록에서 계산한다.
/// 날짜가 바뀌면 처음부터 다시 시작한다.
class BoardState {
  const BoardState({
    this.day = '',
    this.slots = const [],
    this.doneToday = 0,
    this.seq = 0,
    this.urgentAccepted = false,
    this.urgentBaseline = 0,
    this.urgentDone = false,
  });

  /// 이 상태의 날짜 ('2026-11-10')
  final String day;
  final List<ErrandSlot> slots;

  /// 오늘 끝낸 수시 의뢰 수 (하루 4개까지)
  final int doneToday;

  /// 오늘 올라온 수시 의뢰 수 (다음 의뢰를 고를 때 쓴다)
  final int seq;

  final bool urgentAccepted;
  final int urgentBaseline;
  final bool urgentDone;

  BoardState copyWith({
    String? day,
    List<ErrandSlot>? slots,
    int? doneToday,
    int? seq,
    bool? urgentAccepted,
    int? urgentBaseline,
    bool? urgentDone,
  }) =>
      BoardState(
        day: day ?? this.day,
        slots: slots ?? this.slots,
        doneToday: doneToday ?? this.doneToday,
        seq: seq ?? this.seq,
        urgentAccepted: urgentAccepted ?? this.urgentAccepted,
        urgentBaseline: urgentBaseline ?? this.urgentBaseline,
        urgentDone: urgentDone ?? this.urgentDone,
      );

  Map<String, dynamic> toJson() => {
        'day': day,
        'slots': [for (final s in slots) s.toJson()],
        'doneToday': doneToday,
        'seq': seq,
        'urgentAccepted': urgentAccepted,
        'urgentBaseline': urgentBaseline,
        'urgentDone': urgentDone,
      };

  factory BoardState.fromJson(Map<String, dynamic> j) => BoardState(
        day: j['day'] as String? ?? '',
        slots: [
          for (final s in (j['slots'] as List?) ?? const [])
            ErrandSlot.fromJson(Map<String, dynamic>.from(s as Map)),
        ],
        doneToday: (j['doneToday'] as num?)?.toInt() ?? 0,
        seq: (j['seq'] as num?)?.toInt() ?? 0,
        urgentAccepted: j['urgentAccepted'] as bool? ?? false,
        urgentBaseline: (j['urgentBaseline'] as num?)?.toInt() ?? 0,
        urgentDone: j['urgentDone'] as bool? ?? false,
      );
}
