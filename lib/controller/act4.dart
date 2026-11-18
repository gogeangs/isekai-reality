part of '../app_controller.dart';

/// 길드 화면 (서버가 준 모양)
class GuildMember {
  const GuildMember({
    required this.uid,
    required this.name,
    this.level = 1,
    this.job,
    this.weekSteps = 0,
    this.line = '',
    this.role = 'member',
    this.me = false,
  });

  final String uid, name;
  final int level;
  final String? job;
  final int weekSteps;
  final String line;

  /// 'owner' · 'vice' · 'member'
  final String role;
  final bool me;
}

class GuildRaidView {
  const GuildRaidView({
    required this.id,
    this.started = false,
    this.progress = 0,
    this.myShare = 0,
    this.myDamage = 0,
    this.defeated = false,
    this.tickets = 0,
    this.claimed = false,
  });

  final String id;
  final bool started;

  /// 보스가 깎인 비율 (0~1, 숫자는 안 보여 줌)
  final double progress;
  final double myShare;
  final int myDamage;
  final bool defeated;
  final int tickets;
  final bool claimed;

  RaidBossInfo? get boss => GuildRules.boss(id);

  static GuildRaidView? fromJson(Object? j) {
    if (j is! Map) return null;
    double d(String k) => (j[k] as num?)?.toDouble() ?? 0;
    int n(String k) => (j[k] as num?)?.toInt() ?? 0;
    return GuildRaidView(
      id: '${j['id'] ?? ''}',
      started: j['started'] == true,
      progress: d('progress'),
      myShare: d('myShare'),
      myDamage: n('myDamage'),
      defeated: j['defeated'] == true,
      tickets: n('tickets'),
      claimed: j['claimed'] == true,
    );
  }
}

class GuildView {
  const GuildView({
    this.id,
    this.name = '',
    this.emblem = 0,
    this.color = 0,
    this.open = true,
    this.code = '',
    this.role = 'member',
    this.level = 1,
    this.progress = 0,
    this.size = 20,
    this.titles = const [],
    this.giantDone = false,
    this.members = const [],
    this.walkProgress = const [0, 0, 0],
    this.walkDone = const [false, false, false],
    this.walkClaimed = const [],
    this.star = 1,
    this.starProgress = 0,
    this.nextStarLevel,
    this.decos = const [],
    this.slots = const [null, null, null, null],
    this.raid,
    this.giant,
    this.restricted = false,
    this.lian = false,
    this.treasury = 0,
    this.treasuryLog = const [],
    this.goldFlag = false,
    this.news = const [],
  });

  /// 묶음 65: 공성전 소식 (게시판, 최근 것이 위)
  final List<({DateTime at, String text})> news;

  /// 묶음 61: 길드 금고 · 쓰기 기록 (최근 것이 위) · 금빛 깃발 문양
  final int treasury;
  final List<TreasuryLine> treasuryLog;
  final bool goldFlag;

  final String? id;
  final String name;
  final int emblem, color;
  final bool open;
  final String code;
  final String role;
  final int level;
  final double progress;
  final int size;
  final List<String> titles;
  final bool giantDone;
  final List<GuildMember> members;
  final List<double> walkProgress;
  final List<bool> walkDone;
  final List<int> walkClaimed;
  final int star;
  final double starProgress;
  final int? nextStarLevel;
  final List<String> decos;
  final List<String?> slots;
  final GuildRaidView? raid;
  final GuildRaidView? giant;
  final bool restricted;

  /// 리안의 길드 (앱 안, 서버 없이)
  final bool lian;

  bool get inGuild => id != null || lian;
  bool get staff => role == 'owner' || role == 'vice';

  static GuildView fromJson(Map<String, dynamic> j) {
    final g = (j['guild'] as Map?)?.cast<String, dynamic>();
    if (g == null) return GuildView(restricted: j['restricted'] == true);
    final walk = (j['walk'] as Map?) ?? const {};
    final hall = (j['hall'] as Map?) ?? const {};
    return GuildView(
      id: '${g['id']}',
      name: '${g['name'] ?? ''}',
      emblem: (g['emblem'] as num?)?.toInt() ?? 0,
      color: (g['color'] as num?)?.toInt() ?? 0,
      open: g['open'] == true,
      code: '${g['code'] ?? ''}',
      role: '${g['role'] ?? 'member'}',
      level: (g['level'] as num?)?.toInt() ?? 1,
      progress: (g['progress'] as num?)?.toDouble() ?? 0,
      size: (g['size'] as num?)?.toInt() ?? 20,
      titles: [for (final t in (g['titles'] as List?) ?? const []) '$t'],
      giantDone: g['giantDone'] == true,
      members: [
        for (final m in (j['members'] as List?) ?? const [])
          if (m is Map)
            GuildMember(
              uid: '${m['uid']}',
              name: '${m['name'] ?? ''}',
              level: (m['level'] as num?)?.toInt() ?? 1,
              job: m['job'] as String?,
              weekSteps: (m['weekSteps'] as num?)?.toInt() ?? 0,
              line: '${m['line'] ?? ''}',
              role: '${m['role'] ?? 'member'}',
              me: m['me'] == true,
            ),
      ],
      walkProgress: [for (final x in (walk['progress'] as List?) ?? const [0, 0, 0]) (x as num).toDouble()],
      walkDone: [for (final x in (walk['done'] as List?) ?? const [false, false, false]) x == true],
      walkClaimed: [for (final x in (walk['claimed'] as List?) ?? const []) (x as num).toInt()],
      star: (hall['star'] as num?)?.toInt() ?? 1,
      starProgress: (hall['progress'] as num?)?.toDouble() ?? 0,
      nextStarLevel: (hall['nextLevel'] as num?)?.toInt(),
      decos: [for (final x in (hall['decos'] as List?) ?? const []) '$x'],
      slots: [for (final x in (hall['slots'] as List?) ?? const [null, null, null, null]) x as String?],
      raid: GuildRaidView.fromJson(j['raid']),
      giant: GuildRaidView.fromJson(j['giant']),
      restricted: j['restricted'] == true,
      treasury: ((j['treasury'] as Map?)?['gold'] as num?)?.toInt() ?? 0,
      treasuryLog: [
        for (final x in ((j['treasury'] as Map?)?['log'] as List?) ?? const [])
          if (x is Map)
            TreasuryLine(
              at: DateTime.fromMillisecondsSinceEpoch((x['at'] as num?)?.toInt() ?? 0),
              name: '${x['name'] ?? ''}',
              what: '${x['what'] ?? ''}',
              gold: (x['gold'] as num?)?.toInt() ?? 0,
            ),
      ],
      goldFlag: g['goldFlag'] == true,
      news: [
        for (final x in (j['news'] as List?) ?? const [])
          if (x is Map)
            (at: DateTime.fromMillisecondsSinceEpoch((x['at'] as num?)?.toInt() ?? 0), text: '${x['text'] ?? ''}'),
      ],
    );
  }
}

/// 길드 금고 쓰기 기록 한 줄 (누가 · 무엇에 · 얼마)
class TreasuryLine {
  const TreasuryLine({required this.at, required this.name, required this.what, required this.gold});
  final DateTime at;
  final String name, what;
  final int gold;
}

/// 공개 모집 길드 하나
class GuildListing {
  const GuildListing(this.gid, this.name, this.emblem, this.color, this.level, this.members, this.size);
  final String gid, name;
  final int emblem, color, level, members, size;
}

/// 레이드 한 판 결과
class RaidResult {
  const RaidResult({this.damage = 0, this.defeatedNow = false, this.error});
  final int damage;
  final bool defeatedNow;
  final String? error;
}

/// 4막 「길드 창설」 (묶음 59 #246): 장 흐름 · 장면 · 길드(서버) · 리안의 길드(앱 안) · 회관 · 레이드 · 상점 · 등불 인장
extension Act4Ops on AppController {
  Act4State get act4 => _act4;
  GuildView? get guild => _act4.lian ? _lianView : _guildView;
  bool get guildBusy => _guildBusy;
  String? get guildError => _guildError;

  Future<void> _saveAct4() => store.saveJson(AppController._act4Key, _act4.toJson());

  /// 지금까지 걸은 걸음 합
  int get _totalSteps => _history.fold<int>(0, (t, r) => t + r.steps);

  // ───────────── 열림 · 장 흐름

  /// 3막 끝 장면을 본 뒤 (레벨 상관없음)
  bool get act4Available => act3Done;

  bool get act4Open => act4Available && _act4.opened;

  Future<void> openAct4() => _serial(() async {
        if (!act4Available || _act4.opened) return;
        _act4 = _act4.copyWith(opened: true, chapter: 1, chapterSteps: _totalSteps);
        await _saveAct4();
        _notify();
      });

  int get act4Chapter => _act4.chapter;
  bool get act4Done => _act4.done;

  /// 지금 장이 시작된 뒤 걸은 걸음 · 지금 길드에서 걸은 걸음
  int get stepsInChapter => math.max(0, _totalSteps - _act4.chapterSteps);
  /// 묶음 61: 서버 길드는 손으로 입력한 걸음을 뺀 걸음으로 (리안의 길드는 그대로)
  int get stepsInGuild => guild?.inGuild ?? false
      ? math.max(0, (_act4.lian ? _totalSteps : _socialTotalSteps) - _act4.joinSteps)
      : 0;

  /// 길드 레벨 (리안의 길드는 레벨 대신 걸음만 봄 → 조건은 늘 맞음)
  bool _levelOk(int need) => _act4.lian || (_guildView?.level ?? 0) >= need;

  /// 그 장의 장면을 볼 수 있는지 (앞 장을 다 봤고 조건이 맞음)
  bool chapterUnlocked(int n) {
    if (!act4Open) return false;
    if (n < _act4.chapter) return true;
    if (n > _act4.chapter) return false;
    final c = GuildRules.chapter(n);
    return switch (n) {
      1 => true,
      2 => stepsInChapter >= c.steps,
      3 || 4 => (guild?.inGuild ?? false) && _levelOk(c.guildLevel) && stepsInGuild >= c.steps,
      _ => _act4.giant && stepsInChapter >= c.steps,
    };
  }

  /// 지금 볼 장면 (없으면 null)
  Act4Scene? get pendingAct4Scene {
    if (!act4Open || _act4.done) return null;
    if (_act4.giant && !_act4.has(GuildRules.giantDown.id)) return GuildRules.giantDown;
    if (!chapterUnlocked(_act4.chapter)) return null;
    for (final s in GuildRules.chapter(_act4.chapter).scenes) {
      if (!_act4.has(s.id)) return s;
    }
    return null;
  }

  /// 다음 장까지 얼마나 왔는지 (일지 막대, 숫자 없이 0~1)
  double get act4Progress {
    final n = _act4.chapter;
    final c = GuildRules.chapter(n);
    if (n == 1) return 1;
    final s = n == 2 || n == 5 ? stepsInChapter : stepsInGuild;
    return (s / math.max(1, c.steps)).clamp(0.0, 1.0);
  }

  /// 일지 한 줄 (숫자 없이)
  String get act4Goal {
    if (_act4.done) return '4막을 모두 끝냈어요. ${GuildRules.act5Teaser}';
    final n = _act4.chapter;
    final c = GuildRules.chapter(n);
    if (n >= 3 && n <= 4 && !(guild?.inGuild ?? false)) return '길드에 들어가거나 만들어요 · 리안의 길드도 있어요';
    if (n >= 3 && n <= 4 && !_levelOk(c.guildLevel)) return '길드원과 함께 걸어 길드 레벨을 올려요';
    if (n == 4 && chapterUnlocked(4) && _act4.has('c4a') && !_act4.giant) return '길드 레이드에서 빛을 먹는 거인을 쓰러뜨려요';
    return c.goal;
  }

  /// 장면을 봤을 때
  Future<void> markAct4Scene(Act4Scene s) => _serial(() async {
        if (_act4.has(s.id)) return;
        var a = _act4.copyWith(seen: {..._act4.seen, s.id});
        if (s.giveCharter) a = a.copyWith(charter: true);
        final ch = GuildRules.chapter(a.chapter);
        final all = ch.scenes.every((x) => a.has(x.id));
        if (all && a.chapter < 4) {
          a = a.copyWith(chapter: a.chapter + 1, chapterSteps: _totalSteps);
        } else if (all && a.chapter == 5) {
          a = a.copyWith(done: true, seals: a.seals + GuildRules.oathSeals);
          final t = await _todayRecord();
          await _save(t.copyWith(
              counters: DailyRecord.addCounts(t.counters, {TitleRules.skyCounter(TitleId.lanternOath): 1})));
        }
        _act4 = a;
        await _saveAct4();
        // 묶음 60: 4막을 끝내면 5막이 바로 열림
        if (a.done && !_act5.opened) {
          _act5 = _act5.copyWith(opened: true, chapter: 1, chapterSteps: _totalSteps);
          await _saveAct5();
        }
        _notify();
      });

  /// 거인을 쓰러뜨렸을 때 (내 길드 · 리안의 길드)
  Future<void> _giantDown() async {
    if (_act4.giant) return;
    _act4 = _act4.copyWith(giant: true, chapter: 5, chapterSteps: _totalSteps);
    await _saveAct4();
    final t = await _todayRecord();
    await _save(t.copyWith(
        counters: DailyRecord.addCounts(t.counters, {TitleRules.skyCounter(TitleId.raidGiant): 1})));
  }

  // ───────────── 등불 인장 · 증서

  int get lanternSeals => _act4.seals;
  bool get hasCharter => _act4.charter;

  Future<void> _addSeals(int n) async {
    if (n == 0) return;
    _act4 = _act4.copyWith(seals: math.max(0, _act4.seals + n));
    await _saveAct4();
  }

  /// 증서를 다시 받음 (길드를 나온 뒤 리안에게)
  bool get canAskCharter => act4Open && _act4.chapter >= 2 && _act4.has('c2a') && !_act4.charter && !(guild?.inGuild ?? false);

  Future<void> askCharter() => _serial(() async {
        if (!canAskCharter) return;
        _act4 = _act4.copyWith(charter: true);
        await _saveAct4();
        _notify();
      });

  // ───────────── 내 길드 (서버)

  Future<Map<String, dynamic>> _guildMe() async {
    final sub = subJob;
    return {
      'name': _profile.name,
      'level': player.level.level,
      ...await _socialSteps(),
      'device': await deviceId(),
      if (mainJob != null) 'job': mainJob!.name,
      'sub': sub?.name,
      if (gear.sets.lanternSteps > 0) 'boost': true,
    };
  }

  bool get guildReady => _cloud.signedIn && arcaApi != null && cloudAuth != null;

  Future<Map<String, dynamic>?> _guildCall(String path, [Map<String, dynamic> body = const {}]) async {
    final api = arcaApi, a = cloudAuth;
    if (api == null || a == null || !_cloud.signedIn) {
      _guildError = 'login_required';
      _notify();
      return null;
    }
    _guildBusy = true;
    _notify();
    try {
      final token = await a.idToken();
      if (token == null) throw const ArcaApiError('login_required');
      final j = await api.post(path, {...body, 'me': await _guildMe()}, token: token);
      _guildError = null;
      final view = j.containsKey('guild') ? j : (j['state'] as Map?)?.cast<String, dynamic>();
      if (view != null) await _setGuildView(GuildView.fromJson(view));
      return j;
    } on ArcaApiError catch (e) {
      _guildError = e.code;
      return null;
    } catch (_) {
      _guildError = 'offline';
      return null;
    } finally {
      _guildBusy = false;
      _notify();
    }
  }

  Future<void> _setGuildView(GuildView v) async {
    _guildView = v;
    // 길드가 바뀌면 「길드에서 걸은 걸음」을 새로 셈
    if (v.id != null && v.id != _act4.guildId) {
      _act4 = _act4.copyWith(guildId: v.id, joinSteps: _socialTotalSteps, lian: false);
      await _saveAct4();
    } else if (v.id == null && _act4.guildId != null) {
      _act4 = _act4.copyWith(clearGuild: true);
      await _saveAct4();
    }
    if (v.giantDone && !_act4.giant) await _giantDown();
    // Lv.10 전설의 길드 칭호
    if (v.level >= 10) {
      final k = TitleRules.skyCounter(TitleId.guildLegend);
      if (!_history.any((d) => (d.counters[k] ?? 0) > 0)) {
        final t = await _todayRecord();
        await _save(t.copyWith(counters: DailyRecord.addCounts(t.counters, {k: 1})));
      }
    }
  }

  Future<void> refreshGuild() async {
    if (!act4Open || _act4.lian || !guildReady) return;
    await _guildCall('/guild/state');
  }

  /// 길드 만들기: 금화 + 길드 창설 증서
  bool get canCreateGuild =>
      act4Open && _act4.chapter >= 2 && _act4.charter && player.gold >= GuildRules.createGold;

  Future<bool> createGuild(String name, {int emblem = 0, int color = 0, bool open = true}) async {
    if (!canCreateGuild) {
      _guildError = _act4.charter ? 'no_gold' : 'no_charter';
      _notify();
      return false;
    }
    final j = await _guildCall('/guild/create', {'name': name, 'emblem': emblem, 'color': color, 'open': open});
    if (j == null) return false;
    await _serial(() async {
      final today = await _todayRecord();
      await _save(today.copyWith(spends: DailyRecord.addCounts(today.spends, {Wallet.gold: GuildRules.createGold})));
      _act4 = _act4.copyWith(charter: false, lian: false);
      await _saveAct4();
    });
    _notify();
    return true;
  }

  Future<List<GuildListing>?> listGuilds({String query = ''}) async {
    final j = await _guildCall('/guild/list', {if (query.trim().isNotEmpty) 'q': query.trim()});
    if (j == null) return null;
    return [
      for (final g in (j['items'] as List?) ?? const [])
        if (g is Map)
          GuildListing('${g['gid']}', '${g['name']}', (g['emblem'] as num?)?.toInt() ?? 0,
              (g['color'] as num?)?.toInt() ?? 0, (g['level'] as num?)?.toInt() ?? 1,
              (g['members'] as num?)?.toInt() ?? 1, (g['size'] as num?)?.toInt() ?? 20),
    ];
  }

  /// 초대 코드로 들어갈 수 있는 때 (4막 2장 빈 터 장면 뒤)
  bool get canJoinGuildByCode => act4Open && _act4.chapter >= 2 && _act4.has('c2c');

  Future<bool> joinGuild({String? code, String? gid}) async {
    if (!act4Open || _act4.chapter < 2) return false;
    final j = await _guildCall('/guild/join', {if (code != null) 'code': code, if (gid != null) 'gid': gid});
    if (j == null) return false;
    _act4 = _act4.copyWith(lian: false);
    await _saveAct4();
    return true;
  }

  Future<bool> leaveGuild() async {
    if (_act4.lian) {
      _act4 = _act4.copyWith(lian: false, clearGuild: true);
      await _saveAct4();
      _notify();
      return true;
    }
    final j = await _guildCall('/guild/leave');
    if (j == null) return false;
    _guildView = const GuildView();
    _act4 = _act4.copyWith(clearGuild: true);
    await _saveAct4();
    _notify();
    return true;
  }

  Future<bool> kickGuildMember(String uid) async => await _guildCall('/guild/kick', {'target': uid}) != null;
  Future<bool> setGuildRole(String uid, String role) async =>
      await _guildCall('/guild/role', {'target': uid, 'role': role}) != null;
  Future<bool> styleGuild({String? name, int? emblem, int? color, bool? open}) async =>
      await _guildCall('/guild/style', {
        if (name != null) 'name': name,
        if (emblem != null) 'emblem': emblem,
        if (color != null) 'color': color,
        if (open != null) 'open': open,
      }) !=
      null;
  Future<bool> postGuildLine(String text) async => await _guildCall('/guild/line', {'text': text}) != null;

  // ───────────── 리안의 길드 (앱 안)

  bool get canJoinLian => act4Open && _act4.chapter >= 2 && _act4.has('c2c') && !(_guildView?.id != null);

  Future<void> joinLianGuild() => _serial(() async {
        if (!canJoinLian) return;
        _act4 = _act4.copyWith(lian: true, joinSteps: _totalSteps, clearGuild: true);
        await _saveAct4();
        _notify();
      });

  String get _week => DailyRecord.dayKeyOf(TownRules.weekStart(_clock()));

  int get _weekSteps {
    final start = TownRules.weekStart(_clock());
    return _history.where((d) => !d.date.isBefore(start)).fold<int>(0, (t, d) => t + d.steps);
  }

  /// 리안의 길드 화면 (레벨 없이 · 내 걸음만 · 회관은 리안의 회관)
  GuildView get _lianView {
    final w = _weekSteps;
    final mul = 1 + gear.sets.lanternSteps;
    final steps = (w * mul).round();
    return GuildView(
      name: GuildRules.lianGuildName,
      emblem: 2,
      color: 3,
      role: 'member',
      level: 4,
      progress: 0,
      lian: true,
      members: [
        GuildMember(uid: 'me', name: _profile.name, level: player.level.level, weekSteps: w, me: true, job: mainJob?.name),
        const GuildMember(uid: 'lian', name: '리안', level: 30, role: 'owner', line: '자리는 늘 비워 둘게요.'),
      ],
      walkProgress: [for (final g in GuildRules.weekSteps) (steps / g).clamp(0.0, 1.0)],
      walkDone: [for (final g in GuildRules.weekSteps) steps >= g],
      walkClaimed: [
        for (var i = 0; i < 3; i++)
          if (_act4.lianClaimed.contains('walk$_week:$i')) i,
      ],
      raid: _lianRaidView(false),
      giant: _lianRaidView(true),
      giantDone: _act4.giant,
    );
  }

  String _lianRaidKey(bool giant) => giant ? 'giant' : '$_week:${_weeklyRaid.id}';

  RaidBossInfo get _weeklyRaid {
    final start = TownRules.weekStart(_clock());
    final i = start.difference(DateTime(2026, 11, 16)).inDays ~/ 7;
    return GuildRules.raids[i % GuildRules.raids.length];
  }

  GuildRaidView _lianRaidView(bool giant) {
    final key = _lianRaidKey(giant);
    final r = _act4.lianRaid[key] ?? const {};
    final total = giant ? GuildRules.lianGiantFights : GuildRules.lianRaidFights;
    final dmg = (r['dmg'] ?? 0) / 1000;
    final day = DailyRecord.dayKeyOf(_clock());
    final used = r['used:$day'] ?? 0;
    final earned = math.min(GuildRules.raidTicketsPerDay, (player.today?.steps ?? 0) ~/ GuildRules.raidTicketSteps);
    return GuildRaidView(
      id: giant ? GuildRules.giant.id : _weeklyRaid.id,
      started: r.isNotEmpty,
      progress: (dmg / total).clamp(0.0, 1.0),
      myShare: 0.3,
      myDamage: r['dmg'] ?? 0,
      defeated: giant ? _act4.giant || dmg >= total : dmg >= total,
      tickets: math.max(0, earned - used),
      claimed: _act4.lianClaimed.contains('raid:$key'),
    );
  }

  // ───────────── 길드 걸음 목표 · 보상

  Future<List<String>?> claimGuild(String kind, {int? tier}) async {
    if (_act4.lian) return _claimLian(kind, tier: tier);
    final j = await _guildCall('/guild/claim', {'kind': kind, if (tier != null) 'tier': tier});
    final r = (j?['reward'] as Map?)?.cast<String, dynamic>();
    if (r == null) return null;
    return _guildReward(r);
  }

  Future<List<String>?> _claimLian(String kind, {int? tier}) async {
    final v = _lianView;
    Map<String, dynamic>? reward;
    String? key;
    if (kind == 'walk' && tier != null && tier >= 0 && tier < 3) {
      key = 'walk$_week:$tier';
      if (!v.walkDone[tier] || _act4.lianClaimed.contains(key)) return null;
      reward = {'seal': GuildRules.weekSeals[tier]};
    } else if (kind == 'raid' || kind == 'giant') {
      final r = kind == 'giant' ? v.giant! : v.raid!;
      key = 'raid:${_lianRaidKey(kind == 'giant')}';
      if (!r.defeated || _act4.lianClaimed.contains(key) || r.myDamage <= 0) return null;
      reward = {'seal': GuildRules.raidWinSeals, 'raidMat': GuildRules.raidWinMats, 'raid': r.id, 'chest': 'silver'};
    }
    if (reward == null || key == null) return null;
    _act4 = _act4.copyWith(lianClaimed: {..._act4.lianClaimed, key});
    await _saveAct4();
    return _guildReward(reward);
  }

  /// 서버(또는 리안의 길드)가 준 보상 → 등불 인장 · 재료 · 상자
  Future<List<String>> _guildReward(Map<String, dynamic> r) async {
    int n(String k) => (r[k] as num?)?.toInt() ?? 0;
    final got = <String>[];
    final seals = n('seal');
    if (seals > 0) {
      await _addSeals(seals);
      got.add('등불 인장 $seals');
    }
    final gifts = <String, int>{};
    final boss = GuildRules.boss('${r['raid'] ?? ''}');
    if (boss != null && n('raidMat') > 0) gifts[boss.mat.name] = n('raidMat');
    switch (r['chest']) {
      case 'gold':
        gifts[Wallet.gold] = (gifts[Wallet.gold] ?? 0) + 600;
        gifts[Wallet.manaStone] = 20;
        if (boss != null) gifts[boss.mat.name] = (gifts[boss.mat.name] ?? 0) + 2;
        if (_random.nextDouble() < 0.25) gifts['recruit'] = 1;
        got.add('금빛 상자를 열었어요');
      case 'silver':
        gifts[Wallet.gold] = (gifts[Wallet.gold] ?? 0) + 350;
        gifts[Wallet.manaStone] = 12;
        if (boss != null) gifts[boss.mat.name] = (gifts[boss.mat.name] ?? 0) + 1;
        got.add('은빛 상자를 열었어요');
      case 'bronze':
        gifts[Wallet.gold] = (gifts[Wallet.gold] ?? 0) + 180;
        gifts[Wallet.manaStone] = 6;
        got.add('동빛 상자를 열었어요');
    }
    if (gifts.isNotEmpty) got.addAll(await _applyGifts(gifts, over: BagOver.mail));
    _notify();
    return got;
  }

  // ───────────── 회관 (기부 · 꾸미기 · 창고)

  /// 마을 빈 터의 길드 회관이 보이는지
  bool get guildHallOpen => act4Open && (_act4.has('c2c') || (guild?.inGuild ?? false));

  /// 회관 그림 ★ (리안의 길드 · 길드 없음은 ★1)
  int get guildHallStar => _act4.lian ? 1 : (_guildView?.star ?? 1);

  /// 기부: 금화(묶음 61부터 거래 지갑에서) · 재료 → 회관 점수 · 등불 인장
  Future<int?> donateGuild({int gold = 0, Map<MaterialId, int> mats = const {}}) async {
    if (_act4.lian) return null;
    if (gold > 0 && _walletGold != null && gold > _walletGold!) {
      _guildError = 'no_wallet_gold';
      _notify();
      return null;
    }
    for (final e in mats.entries) {
      if (player.materialCount(e.key) < e.value) return null;
    }
    final j = await _guildCall('/guild/donate', {
      'gold': gold,
      'mats': {for (final e in mats.entries) e.key.name: e.value},
    });
    if (j == null) return null;
    final seals = (j['seals'] as num?)?.toInt() ?? 0;
    if (gold > 0 && _walletGold != null) _walletGold = math.max(0, _walletGold! - gold);
    await _serial(() async {
      final today = await _todayRecord();
      await _save(today.copyWith(
          spends: DailyRecord.addCounts(today.spends, {
        for (final e in mats.entries) e.key.name: e.value,
      })));
      await _addSeals(seals);
    });
    _notify();
    return seals;
  }

  // ───────────── 묶음 61: 길드 금고 쓰기 (길드장 · 부길드장, 나눠 주기는 길드장)

  Future<bool> _treasury(Map<String, dynamic> body) async {
    final j = await _guildCall('/guild/treasury', body);
    if (j == null) return false;
    await refreshErbard();
    return true;
  }

  /// 우리 영지 수비대 강화 (다음 공성전 끝까지)
  Future<bool> boostGarrison(String estate, int level) => _treasury({'action': 'boost', 'estate': estate, 'level': level});

  /// 회관 공사: 금고 금화로 회관 점수
  Future<bool> treasuryHall(int gold) => _treasury({'action': 'hall', 'amount': gold});

  /// 공성전이 끝난 뒤 공성권을 쓴 길드원에게 똑같이
  Future<bool> treasuryShare(int gold) => _treasury({'action': 'share', 'amount': gold});

  /// 금고 상점
  Future<bool> treasuryShop(String id) => _treasury({'action': 'shop', 'id': id});

  Future<bool> placeDeco(int slot, String? id) async =>
      await _guildCall('/guild/deco/place', {'slot': slot, 'id': id}) != null;

  /// 창고(★2): 길드원에게 재료 보내기 (하루 한도)
  Future<bool> shareToMember(String uid, MaterialId m, int qty) async {
    if (player.materialCount(m) < qty) return false;
    final j = await _guildCall('/guild/share', {'target': uid, 'mat': m.name, 'qty': qty});
    if (j == null) return false;
    await _serial(() async {
      final today = await _todayRecord();
      await _save(today.copyWith(spends: DailyRecord.addCounts(today.spends, {m.name: qty})));
    });
    _notify();
    return true;
  }

  // ───────────── 길드 상점 (등불 인장)

  int _shopBought(GuildShopItem i) => _act4.shopWeek == _week ? _act4.shopBuys[i.name] ?? 0 : 0;

  /// 살 수 있는지 (null 이면 됨, 아니면 까닭)
  String? guildShopBlock(GuildShopInfo s) {
    final g = guild;
    if (g == null || !g.inGuild) return '길드에 들어가면 열려요';
    if (!g.lian && g.level < s.minLevel) return '길드 Lv.${s.minLevel}에 열려요';
    if (s.perWeek > 0 && _shopBought(s.item) >= s.perWeek) return '이번 주는 다 샀어요';
    if (s.deco != null) {
      if (g.lian) return '내 길드 회관에 놓는 꾸미기예요';
      if (!g.staff) return '길드장 · 부길드장이 회관에 들여요';
      if (g.decos.contains(s.deco)) return '회관에 이미 있어요';
    }
    if (_act4.seals < s.seals) return '등불 인장이 모자라요';
    for (final e in s.mats.entries) {
      if (player.materialCount(e.key) < e.value) return '${Materials.info(e.key).name}이(가) 모자라요';
    }
    return null;
  }

  Future<String?> buyGuildShop(GuildShopInfo s) async {
    final block = guildShopBlock(s);
    if (block != null) return block;
    if (s.deco != null) {
      final j = await _guildCall('/guild/deco/add', {'id': s.deco});
      if (j == null) return GuildRules.errorText(_guildError ?? '');
    }
    await _serial(() async {
      _act4 = _act4.copyWith(
        seals: _act4.seals - s.seals,
        shopWeek: _week,
        shopBuys: {
          if (_act4.shopWeek == _week) ..._act4.shopBuys,
          s.item.name: _shopBought(s.item) + 1,
        },
      );
      await _saveAct4();
      if (s.mats.isNotEmpty) {
        final today = await _todayRecord();
        await _save(today.copyWith(
            spends: DailyRecord.addCounts(today.spends, {for (final e in s.mats.entries) e.key.name: e.value})));
      }
      if (s.equip case final b?) await _a3Gear(b, rare: true, element: Element.light);
      switch (s.item) {
        case GuildShopItem.gold:
          await _applyGifts({Wallet.gold: 500});
        case GuildShopItem.manaStone:
          await _applyGifts({Wallet.manaStone: 10});
        case GuildShopItem.matBundle:
          await _applyGifts({
            MaterialId.hardWood.name: 2,
            MaterialId.ironShard.name: 2,
            MaterialId.herb.name: 2,
          }, over: BagOver.mail);
        case GuildShopItem.recruit:
          _act3 = _act3.copyWith(tickets: _act3.tickets + 1);
          await _saveAct3();
        default:
          break;
      }
    });
    _notify();
    return null;
  }

  // ───────────── 레이드 (내 화면에서 정해진 턴, 피해가 길드로 합쳐짐)

  /// 레이드 한 판을 시작한다. [giant] 빛을 먹는 거인
  Battle? startRaid({bool giant = false}) {
    final g = guild;
    final r = giant ? g?.giant : g?.raid;
    if (g == null || r == null || r.defeated || r.tickets <= 0) return null;
    if (!g.lian && g.level < 4) return null;
    if (giant && !(act4Chapter >= 4 && _act4.has('c4a'))) return null;
    final info = r.boss ?? GuildRules.giant;
    final lv = player.level.level;
    final f = BattleRules.fieldFoe(level: lv, monster: info.monster);
    final foe = Foe(
      monster: info.monster,
      maxHp: math.max(1, f.maxHp * 10),
      attack: math.max(1, (f.attack * 1.5).round()),
      defense: f.defense,
      speed: f.speed,
    );
    final b = _trainingBattle([foe], potions: true);
    b.tickLimit = GuildRules.fightTicks;
    b.raidBoss = info.id;
    b.raidSpecialEvery = GuildRules.specialEvery;
    // 약점 직업: 주 직업이면 피해 더 · 특별 공격 덜, 보조면 절반 (숨김)
    final w = info.weak.contains(mainJob) ? 1.0 : info.weak.contains(subJob) ? 0.5 : 0.0;
    b.dealMult *= 1 + GuildRules.weakDeal * w + gear.sets.guildRaid;
    b.raidTakenMult = 1 - GuildRules.weakTaken * w;
    _raidGiant = giant;
    return b;
  }

  /// 내 주 · 보조 직업이 그 보스의 약점인지 (화면 한 줄)
  String? raidWeakLine(RaidBossInfo b) {
    if (b.weak.contains(mainJob)) return '내 주 직업이 이 보스의 약점이에요';
    if (b.weak.contains(subJob)) return '내 보조 직업이 이 보스의 약점이에요';
    return null;
  }

  Future<RaidResult> finishRaid(Battle b) async {
    await _consumeBattlePotions(b);
    final giant = _raidGiant;
    final lv = player.level.level;
    final frac = b.foe.maxHp <= 0 ? 0.0 : (b.dealtToFoe / b.foe.maxHp).clamp(0.0, 1.0);
    await gainMastery(Mastery.combat, TrainingRules.dailyMastery);
    if (_act4.lian) {
      final key = _lianRaidKey(giant);
      final day = DailyRecord.dayKeyOf(_clock());
      final r = {...(_act4.lianRaid[key] ?? const <String, int>{})};
      final add = (frac * (1 + GuildRules.lianHelpers) * 1000).round();
      final before = _lianRaidView(giant).defeated;
      r['dmg'] = (r['dmg'] ?? 0) + add;
      r['used:$day'] = (r['used:$day'] ?? 0) + 1;
      _act4 = _act4.copyWith(lianRaid: {..._act4.lianRaid, key: r});
      await _saveAct4();
      final after = _lianRaidView(giant).defeated;
      if (giant && after) await _giantDown();
      _notify();
      return RaidResult(damage: (frac * PartyRules.fightHp(lv)).round(), defeatedNow: !before && after);
    }
    final damage = (frac * PartyRules.fightHp(lv)).round();
    final before = (giant ? _guildView?.giant : _guildView?.raid)?.defeated ?? false;
    final j = await _guildCall('/guild/raid', {'giant': giant, 'damage': damage});
    if (j == null) return RaidResult(error: _guildError);
    final after = (giant ? _guildView?.giant : _guildView?.raid)?.defeated ?? false;
    return RaidResult(damage: damage, defeatedNow: !before && after);
  }

  /// 길드 Lv.5: 함께 걸으면 여정 기력 조금 더 · ★3 훈련소 경험치 (숨김)
  double get guildEnergyBonus => (_guildView?.level ?? 0) >= 5 && !_act4.lian ? GuildRules.lv5Energy : 0;
  double get guildExpBonus => (_guildView?.star ?? 0) >= 3 && !_act4.lian ? GuildRules.trainingExp : 0;
}
