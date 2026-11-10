/// 차량 속도 이동 확인 (11-11 #61)
enum DriveMode {
  none,

  /// 「운전 중이 아닌 승객인가요?」 묻는 중 (화면을 가린다)
  asking,

  /// 승객이라고 답함: 플레이는 되지만 보상 제한
  passenger,

  /// 운전 중이거나 답이 없음: 「안전 운전하세요」 화면, 조작 막음
  driving,
}

/// 승객 확인 규칙 (제안서 4 확정)
class DriveRules {
  DriveRules._();

  /// 시속 20km 이상이 10초 넘게 이어지면 묻는다
  static const double carSpeedMps = 20 / 3.6;
  static const Duration carFor = Duration(seconds: 10);

  /// 시속 10km 아래가 2분 이어지면 차량 이동이 끝난 것으로 본다
  static const double endSpeedMps = 10 / 3.6;
  static const Duration endAfter = Duration(minutes: 2);

  /// 묻고 15초 동안 답이 없으면 「안전 운전하세요」
  static const Duration askTimeout = Duration(seconds: 15);
}

/// 따로 저장한다 ('drive')
class DriveState {
  const DriveState({
    this.mode = DriveMode.none,
    this.askedAt,
    this.passengerSpawns = const [],
  });

  final DriveMode mode;
  final DateTime? askedAt;

  /// 승객 모드에서 보낸 원정 (보상 절반)
  final List<String> passengerSpawns;

  DriveState copyWith({
    DriveMode? mode,
    DateTime? askedAt,
    List<String>? passengerSpawns,
  }) =>
      DriveState(
        mode: mode ?? this.mode,
        askedAt: askedAt ?? this.askedAt,
        passengerSpawns: passengerSpawns ?? this.passengerSpawns,
      );

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        if (askedAt != null) 'askedAt': askedAt!.toIso8601String(),
        // 오래된 것은 30개만 남긴다
        'passengerSpawns': passengerSpawns.length > 30
            ? passengerSpawns.sublist(passengerSpawns.length - 30)
            : passengerSpawns,
      };

  factory DriveState.fromJson(Map<String, dynamic> j) => DriveState(
        mode: DriveMode.values.firstWhere((m) => m.name == j['mode'],
            orElse: () => DriveMode.none),
        askedAt: DateTime.tryParse(j['askedAt'] as String? ?? ''),
        passengerSpawns: [
          for (final s in (j['passengerSpawns'] as List?) ?? const []) s as String,
        ],
      );
}
