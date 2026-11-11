/// 걸음 주머니 · 길가의 발견 · 떠돌이 상인 (11-11 #59). 따로 저장한다 ('gather').
class GatherState {
  const GatherState({
    this.pouches = 0,
    this.day,
    this.pouchesGiven = 0,
    this.stepsChecked = 0,
    this.findsToday = 0,
    this.merchantToday = 0,
    this.findUntil,
    this.merchantUntil,
    this.offers = const {},
    this.noteOffer = false,
    this.notify = true,
    this.merchantLat,
    this.merchantLng,
    this.sold = const [],
  });

  /// 떠돌이 상인이 선 자리 (11-11 #84, 지도에 보인다)
  final double? merchantLat;
  final double? merchantLng;

  /// 이번 상인에게서 이미 산 것 (재료 이름, 레시피 쪽지는 'note'). 「팔렸어요」로 보인다.
  final List<String> sold;

  /// 가방의 걸음 주머니 수
  final int pouches;

  /// 아래 수를 센 날 ('yyyy-mm-dd')
  final String? day;
  final int pouchesGiven;

  /// 무작위 이벤트를 굴린 걸음 (그날)
  final int stepsChecked;
  final int findsToday;
  final int merchantToday;

  /// 길가의 발견: 이때까지 열어야 받는다 (없으면 null)
  final DateTime? findUntil;

  /// 떠돌이 상인: 이때까지만 판다
  final DateTime? merchantUntil;

  /// 상인이 파는 재료 이름 → 금화
  final Map<String, int> offers;

  /// 상인이 레시피 쪽지도 파는지
  final bool noteOffer;

  /// 걸을 때 알림 (설정)
  final bool notify;

  GatherState copyWith({
    int? pouches,
    String? day,
    int? pouchesGiven,
    int? stepsChecked,
    int? findsToday,
    int? merchantToday,
    DateTime? findUntil,
    bool clearFind = false,
    DateTime? merchantUntil,
    bool clearMerchant = false,
    Map<String, int>? offers,
    bool? noteOffer,
    bool? notify,
    double? merchantLat,
    double? merchantLng,
    List<String>? sold,
  }) =>
      GatherState(
        pouches: pouches ?? this.pouches,
        day: day ?? this.day,
        pouchesGiven: pouchesGiven ?? this.pouchesGiven,
        stepsChecked: stepsChecked ?? this.stepsChecked,
        findsToday: findsToday ?? this.findsToday,
        merchantToday: merchantToday ?? this.merchantToday,
        findUntil: clearFind ? null : (findUntil ?? this.findUntil),
        merchantUntil:
            clearMerchant ? null : (merchantUntil ?? this.merchantUntil),
        offers: offers ?? this.offers,
        noteOffer: noteOffer ?? this.noteOffer,
        notify: notify ?? this.notify,
        merchantLat: merchantLat ?? this.merchantLat,
        merchantLng: merchantLng ?? this.merchantLng,
        sold: sold ?? this.sold,
      );

  Map<String, dynamic> toJson() => {
        'pouches': pouches,
        if (day != null) 'day': day,
        'pouchesGiven': pouchesGiven,
        'stepsChecked': stepsChecked,
        'findsToday': findsToday,
        'merchantToday': merchantToday,
        if (findUntil != null) 'findUntil': findUntil!.toIso8601String(),
        if (merchantUntil != null)
          'merchantUntil': merchantUntil!.toIso8601String(),
        'offers': offers,
        'noteOffer': noteOffer,
        'notify': notify,
        if (merchantLat != null) 'merchantLat': merchantLat,
        if (merchantLng != null) 'merchantLng': merchantLng,
        if (sold.isNotEmpty) 'sold': sold,
      };

  factory GatherState.fromJson(Map<String, dynamic> j) => GatherState(
        pouches: (j['pouches'] as num?)?.toInt() ?? 0,
        day: j['day'] as String?,
        pouchesGiven: (j['pouchesGiven'] as num?)?.toInt() ?? 0,
        stepsChecked: (j['stepsChecked'] as num?)?.toInt() ?? 0,
        findsToday: (j['findsToday'] as num?)?.toInt() ?? 0,
        merchantToday: (j['merchantToday'] as num?)?.toInt() ?? 0,
        findUntil: DateTime.tryParse(j['findUntil'] as String? ?? ''),
        merchantUntil: DateTime.tryParse(j['merchantUntil'] as String? ?? ''),
        offers: {
          for (final e in ((j['offers'] as Map?) ?? const {}).entries)
            e.key as String: (e.value as num).toInt(),
        },
        noteOffer: j['noteOffer'] as bool? ?? false,
        notify: j['notify'] as bool? ?? true,
        merchantLat: (j['merchantLat'] as num?)?.toDouble(),
        merchantLng: (j['merchantLng'] as num?)?.toDouble(),
        sold: [for (final x in (j['sold'] as List?) ?? const []) '$x'],
      );
}
