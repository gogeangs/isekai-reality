import '../rules/stat_rules.dart';

/// 레벨업 포인트로 나눈 스탯과 초기화 횟수 (11-11 #50)
class StatAlloc {
  const StatAlloc({
    this.allocated = Stats.zero,
    this.resets = 0,
    this.seenLife,
  });

  /// 포인트로 올린 값
  final Stats allocated;

  /// 초기화한 횟수 (처음 1번은 무료)
  final int resets;

  /// 정령이 알려 준 생활 보너스 (이보다 오르면 정령이 한 줄 말한다). 예전 저장본은 null.
  final Stats? seenLife;

  StatAlloc copyWith({Stats? allocated, int? resets, Stats? seenLife}) =>
      StatAlloc(
        allocated: allocated ?? this.allocated,
        resets: resets ?? this.resets,
        seenLife: seenLife ?? this.seenLife,
      );

  Map<String, dynamic> toJson() => {
        'allocated': allocated.toJson(),
        'resets': resets,
        if (seenLife != null) 'seenLife': seenLife!.toJson(),
      };

  factory StatAlloc.fromJson(Map<String, dynamic> j) => StatAlloc(
        allocated: Stats.fromJson(
            (j['allocated'] as Map?)?.cast<String, dynamic>()),
        resets: (j['resets'] as num?)?.toInt() ?? 0,
        seenLife: j['seenLife'] == null
            ? null
            : Stats.fromJson((j['seenLife'] as Map).cast<String, dynamic>()),
      );
}
