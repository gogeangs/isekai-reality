/// 4막 「길드 창설」 기록 (묶음 59 #246). 따로 저장한다 ('act4'). 예전 기록엔 없으니 없으면 처음부터 (#124)
class Act4State {
  const Act4State({
    this.opened = false,
    this.chapter = 1,
    this.seen = const {},
    this.chapterSteps = 0,
    this.joinSteps = 0,
    this.charter = false,
    this.lian = false,
    this.seals = 0,
    this.giant = false,
    this.done = false,
    this.lianRaid = const {},
    this.lianClaimed = const {},
    this.shopWeek,
    this.shopBuys = const {},
    this.guildId,
  });

  /// 4막이 열렸는지 (3막 끝 장면 뒤)
  final bool opened;

  /// 지금 장 (1~5)
  final int chapter;

  /// 본 장면 id
  final Set<String> seen;

  /// 지금 장이 시작될 때까지 걸은 걸음 합 (2장 · 5장: 「그 뒤 ○만 보」)
  final int chapterSteps;

  /// 지금 길드에 들어갈 때까지 걸은 걸음 합 (3 · 4장: 「길드에서 걸은 걸음」)
  final int joinSteps;

  /// 길드 창설 증서 (2장에서 리안에게)
  final bool charter;

  /// 리안의 길드(NPC)에 있는지
  final bool lian;

  /// 등불 인장 (길드 화폐)
  final int seals;

  /// 빛을 먹는 거인을 쓰러뜨렸는지 (내 길드든 리안의 길드든)
  final bool giant;

  /// 5장까지 끝냄
  final bool done;

  /// 리안의 길드 레이드: 'giant' · '<주>:<보스>' → {dmg: 내 피해 합(한 판 몫 단위), used:<날>:<수>}
  final Map<String, Map<String, int>> lianRaid;

  /// 리안의 길드 보상 받은 것 ('walk<주>:<단계>' · 'raid:<키>')
  final Set<String> lianClaimed;

  /// 길드 상점 주간 한도 (주 · 물건별 개수)
  final String? shopWeek;
  final Map<String, int> shopBuys;

  /// 마지막으로 본 내 길드 번호 (길드를 바꾸면 길드 걸음을 다시 셈)
  final String? guildId;

  bool has(String s) => seen.contains(s);

  Act4State copyWith({
    bool? opened,
    int? chapter,
    Set<String>? seen,
    int? chapterSteps,
    int? joinSteps,
    bool? charter,
    bool? lian,
    int? seals,
    bool? giant,
    bool? done,
    Map<String, Map<String, int>>? lianRaid,
    Set<String>? lianClaimed,
    String? shopWeek,
    Map<String, int>? shopBuys,
    String? guildId,
    bool clearGuild = false,
  }) =>
      Act4State(
        opened: opened ?? this.opened,
        chapter: chapter ?? this.chapter,
        seen: seen ?? this.seen,
        chapterSteps: chapterSteps ?? this.chapterSteps,
        joinSteps: joinSteps ?? this.joinSteps,
        charter: charter ?? this.charter,
        lian: lian ?? this.lian,
        seals: seals ?? this.seals,
        giant: giant ?? this.giant,
        done: done ?? this.done,
        lianRaid: lianRaid ?? this.lianRaid,
        lianClaimed: lianClaimed ?? this.lianClaimed,
        shopWeek: shopWeek ?? this.shopWeek,
        shopBuys: shopBuys ?? this.shopBuys,
        guildId: clearGuild ? null : (guildId ?? this.guildId),
      );

  Map<String, dynamic> toJson() => {
        'v': 1,
        if (opened) 'opened': true,
        'chapter': chapter,
        if (seen.isNotEmpty) 'seen': seen.toList(),
        'chapterSteps': chapterSteps,
        'joinSteps': joinSteps,
        if (charter) 'charter': true,
        if (lian) 'lian': true,
        if (seals > 0) 'seals': seals,
        if (giant) 'giant': true,
        if (done) 'done': true,
        if (lianRaid.isNotEmpty) 'lianRaid': lianRaid,
        if (lianClaimed.isNotEmpty) 'lianClaimed': lianClaimed.toList(),
        if (shopWeek != null) 'shopWeek': shopWeek,
        if (shopBuys.isNotEmpty) 'shopBuys': shopBuys,
        if (guildId != null) 'guildId': guildId,
      };

  static Act4State fromJson(Map<String, dynamic> j) => Act4State(
        opened: j['opened'] == true,
        chapter: ((j['chapter'] as num?) ?? 1).toInt().clamp(1, 5),
        seen: {for (final x in (j['seen'] as List?) ?? const []) '$x'},
        chapterSteps: ((j['chapterSteps'] as num?) ?? 0).toInt(),
        joinSteps: ((j['joinSteps'] as num?) ?? 0).toInt(),
        charter: j['charter'] == true,
        lian: j['lian'] == true,
        seals: ((j['seals'] as num?) ?? 0).toInt(),
        giant: j['giant'] == true,
        done: j['done'] == true,
        lianRaid: {
          if (j['lianRaid'] is Map)
            for (final e in (j['lianRaid'] as Map).entries)
              if (e.value is Map)
                '${e.key}': {
                  for (final x in (e.value as Map).entries)
                    if (x.value is num) '${x.key}': (x.value as num).toInt(),
                },
        },
        lianClaimed: {for (final x in (j['lianClaimed'] as List?) ?? const []) '$x'},
        shopWeek: j['shopWeek'] as String?,
        shopBuys: {
          if (j['shopBuys'] is Map)
            for (final e in (j['shopBuys'] as Map).entries)
              if (e.value is num) '${e.key}': (e.value as num).toInt(),
        },
        guildId: j['guildId'] as String?,
      );
}
