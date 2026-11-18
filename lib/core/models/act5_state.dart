/// 5막 「흑등 연맹의 귀환」 기록 (묶음 60 #247). 따로 저장한다 ('act5'). 예전 기록엔 없으니 없으면 처음부터 (#124)
class Act5State {
  const Act5State({
    this.opened = false,
    this.chapter = 1,
    this.seen = const {},
    this.chapterSteps = 0,
    this.ticketBank = 0,
    this.ticketAt,
    this.wildWins = 0,
    this.pioneered = false,
    this.soloWild = const {},
    this.ch3Siege,
    this.ch3Used = 0,
    this.ch3Solo = 0,
    this.royalWon,
    this.done = false,
    this.lastResultSeen = -1,
  });

  /// 5막이 열렸는지 (4막 5장 뒤)
  final bool opened;

  /// 지금 장 (1~3)
  final int chapter;
  final Set<String> seen;

  /// 지금 장이 시작될 때까지 걸은 걸음 합 (2장: 「1장 뒤 2만 보」)
  final int chapterSteps;

  /// 공성권: 모아 둔 장수 + 마지막으로 센 걸음 합 (null 이면 아직 모으기 전 = 1장 끝나기 전)
  final int ticketBank;
  final int? ticketAt;

  /// 내가 이긴 야생 수비대 자리 수 · 빈 영지 다섯 자리를 모두 깬 적 있음
  final int wildWins;
  final bool pioneered;

  /// 혼자(리안의 길드 · 로그인 전) 야생 수비대: 영지 → 깬 자리(비트)
  final Map<String, int> soloWild;

  /// 3장: 참여할 공성전 번호 · 그 공성전에 쓴 공성권(길드) · 야생 수비대 싸움(혼자) · 왕성을 되찾았는지
  final int? ch3Siege;
  final int ch3Used;
  final int ch3Solo;
  final bool? royalWon;

  /// 첫 편 끝
  final bool done;

  /// 마지막으로 본 공성전 결과 번호
  final int lastResultSeen;

  bool has(String s) => seen.contains(s);

  Act5State copyWith({
    bool? opened,
    int? chapter,
    Set<String>? seen,
    int? chapterSteps,
    int? ticketBank,
    int? ticketAt,
    int? wildWins,
    bool? pioneered,
    Map<String, int>? soloWild,
    int? ch3Siege,
    int? ch3Used,
    int? ch3Solo,
    bool? royalWon,
    bool? done,
    int? lastResultSeen,
  }) =>
      Act5State(
        opened: opened ?? this.opened,
        chapter: chapter ?? this.chapter,
        seen: seen ?? this.seen,
        chapterSteps: chapterSteps ?? this.chapterSteps,
        ticketBank: ticketBank ?? this.ticketBank,
        ticketAt: ticketAt ?? this.ticketAt,
        wildWins: wildWins ?? this.wildWins,
        pioneered: pioneered ?? this.pioneered,
        soloWild: soloWild ?? this.soloWild,
        ch3Siege: ch3Siege ?? this.ch3Siege,
        ch3Used: ch3Used ?? this.ch3Used,
        ch3Solo: ch3Solo ?? this.ch3Solo,
        royalWon: royalWon ?? this.royalWon,
        done: done ?? this.done,
        lastResultSeen: lastResultSeen ?? this.lastResultSeen,
      );

  Map<String, dynamic> toJson() => {
        'v': 1,
        if (opened) 'opened': true,
        'chapter': chapter,
        if (seen.isNotEmpty) 'seen': seen.toList(),
        'chapterSteps': chapterSteps,
        'ticketBank': ticketBank,
        if (ticketAt != null) 'ticketAt': ticketAt,
        if (wildWins > 0) 'wildWins': wildWins,
        if (pioneered) 'pioneered': true,
        if (soloWild.isNotEmpty) 'soloWild': soloWild,
        if (ch3Siege != null) 'ch3Siege': ch3Siege,
        if (ch3Used > 0) 'ch3Used': ch3Used,
        if (ch3Solo > 0) 'ch3Solo': ch3Solo,
        if (royalWon != null) 'royalWon': royalWon,
        if (done) 'done': true,
        'lastResultSeen': lastResultSeen,
      };

  static Act5State fromJson(Map<String, dynamic> j) {
    int n(String k, [int d = 0]) => ((j[k] as num?) ?? d).toInt();
    return Act5State(
      opened: j['opened'] == true,
      chapter: n('chapter', 1).clamp(1, 3),
      seen: {for (final x in (j['seen'] as List?) ?? const []) '$x'},
      chapterSteps: n('chapterSteps'),
      ticketBank: n('ticketBank'),
      ticketAt: (j['ticketAt'] as num?)?.toInt(),
      wildWins: n('wildWins'),
      pioneered: j['pioneered'] == true,
      soloWild: {
        if (j['soloWild'] is Map)
          for (final e in (j['soloWild'] as Map).entries)
            if (e.value is num) '${e.key}': (e.value as num).toInt(),
      },
      ch3Siege: (j['ch3Siege'] as num?)?.toInt(),
      ch3Used: n('ch3Used'),
      ch3Solo: n('ch3Solo'),
      royalWon: j['royalWon'] as bool?,
      done: j['done'] == true,
      lastResultSeen: n('lastResultSeen', -1),
    );
  }
}
