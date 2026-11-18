part of '../app_controller.dart';

/// 에르바르드 지도 한 장 (서버 · 혼자면 처음 판 + 내 개척)
class ErbardView {
  const ErbardView({
    this.owners = const {},
    this.siegeNo = 0,
    this.active = false,
    this.start,
    this.end,
    this.myEstates = const [],
    this.treasury = 0,
    this.staff = false,
    this.owner = false,
    this.garrisons = const {},
    this.placed,
    this.wild = const {},
    this.run = const {},
    this.used = 0,
    this.lastNo,
    this.lastRoyal,
    this.lastRoyalNpc = true,
    this.lastChanges = const [],
    this.alliance,
    this.restricted = false,
    this.server = false,
    this.boosts = const {},
    this.canShare = false,
    this.shareNo,
    this.tickets,
    this.ticketCarry = 0,
    this.guards = const {},
    this.rally,
    this.gauge,
    this.weak = const {},
    this.defense = const {},
    this.news = const [],
    this.crownStreak = 0,
    this.lastVanguards = const {},
  });

  /// 묶음 65 #251: 집결 깃발 (이번 공성전) · 길드 게이지 · 공성 망치로 흔든 자리 · 우리 영지 전황 · 게시판 소식
  final ({String estate, DateTime at, DateTime nextAt})? rally;
  final SiegeGauge? gauge;
  final Map<String, List<int>> weak;
  final Map<String, int> defense;
  final List<({DateTime at, String text})> news;
  final int crownStreak;

  /// 지난 공성전 선봉장 (길드 id → 이름)
  final Map<String, String> lastVanguards;

  /// 묶음 61: 우리 영지 수비대 강화 단계 (금고) · 나눠 주기 · 서버가 센 공성권
  final Map<String, int> boosts;
  final bool canShare;
  final int? shareNo;
  final int? tickets;
  final int ticketCarry;

  /// 우리 영지 수비대 직업 (분신 그림)
  final Map<String, List<String?>> guards;

  /// 영지 → 주인 (없으면 빈 영지). kind: 'mine' · 'ally' · 'npc' · 'other'
  final Map<String, ({String kind, String name, int emblem, int color, bool crown})> owners;
  final int siegeNo;
  final bool active;
  final DateTime? start, end;
  final List<String> myEstates;
  final int treasury;
  final bool staff, owner;

  /// 우리 영지의 수비대 다섯 자리 (null = 빈 자리)
  final Map<String, List<({String name, int level, List<String> allies, bool me})?>> garrisons;

  /// 내 분신이 서 있는 영지
  final String? placed;

  /// 우리 길드가 깬 야생 수비대 자리 · 이번 공성전에 깬 자리
  final Map<String, List<int>> wild, run;
  final int used;

  /// 지난 공성전 결과
  final int? lastNo;
  final String? lastRoyal;
  final bool lastRoyalNpc;
  final List<({String estate, String fromName, String toName})> lastChanges;
  final ({String name, String code, List<String> guilds, bool locked})? alliance;
  final bool restricted;

  /// 서버에서 받은 판인지 (아니면 혼자 보는 처음 판)
  final bool server;

  static ErbardView fromJson(Map<String, dynamic> j) {
    final s = (j['siege'] as Map?) ?? const {};
    final g = j['guild'] as Map?;
    final last = j['last'] as Map?;
    final al = j['alliance'] as Map?;
    DateTime? t(Object? x) => x is num ? DateTime.fromMillisecondsSinceEpoch(x.toInt()) : null;
    return ErbardView(
      server: true,
      owners: {
        for (final e in ((j['owners'] as Map?) ?? const {}).entries)
          if (e.value is Map)
            '${e.key}': (
              kind: '${(e.value as Map)['gid'] ?? 'other'}',
              name: '${(e.value as Map)['name'] ?? ''}',
              emblem: ((e.value as Map)['emblem'] as num?)?.toInt() ?? 0,
              color: ((e.value as Map)['color'] as num?)?.toInt() ?? 0,
              crown: (e.value as Map)['crown'] == true,
            ),
      },
      siegeNo: (s['no'] as num?)?.toInt() ?? 0,
      active: s['active'] == true,
      start: t(s['start']),
      end: t(s['end']),
      myEstates: [for (final x in (g?['estates'] as List?) ?? const []) '$x'],
      treasury: (g?['treasury'] as num?)?.toInt() ?? 0,
      staff: g?['staff'] == true,
      owner: g?['owner'] == true,
      garrisons: {
        for (final e in ((j['garrisons'] as Map?) ?? const {}).entries)
          '${e.key}': [
            for (final x in (e.value as List?) ?? const [])
              x is Map
                  ? (
                      name: '${x['name'] ?? ''}',
                      level: (x['level'] as num?)?.toInt() ?? 1,
                      allies: [for (final a in (x['allies'] as List?) ?? const []) '$a'],
                      me: x['me'] == true,
                    )
                  : null,
          ],
      },
      placed: j['placed'] as String?,
      wild: {
        for (final e in ((j['wild'] as Map?) ?? const {}).entries)
          '${e.key}': [for (final x in (e.value as List?) ?? const []) (x as num).toInt()],
      },
      run: {
        for (final e in ((j['run'] as Map?) ?? const {}).entries)
          '${e.key}': [for (final x in (e.value as List?) ?? const []) (x as num).toInt()],
      },
      used: (j['used'] as num?)?.toInt() ?? 0,
      lastNo: (last?['no'] as num?)?.toInt(),
      lastRoyal: (last?['royal'] as Map?)?['name'] as String?,
      lastRoyalNpc: ((last?['royal'] as Map?)?['gid'] ?? 'npc') == 'npc',
      lastChanges: [
        for (final c in (last?['changes'] as List?) ?? const [])
          if (c is Map) (estate: '${c['estate']}', fromName: '${c['fromName'] ?? ''}', toName: '${c['toName'] ?? ''}'),
      ],
      alliance: al == null
          ? null
          : (
              name: '${al['name'] ?? ''}',
              code: '${al['code'] ?? ''}',
              guilds: [for (final x in (al['guilds'] as List?) ?? const []) '$x'],
              locked: al['locked'] == true,
            ),
      restricted: j['restricted'] == true,
      boosts: {
        for (final e in ((j['boosts'] as Map?) ?? const {}).entries) '${e.key}': (e.value as num).toInt(),
      },
      canShare: g?['canShare'] == true,
      shareNo: (g?['shareNo'] as num?)?.toInt(),
      tickets: (j['tickets'] as num?)?.toInt(),
      ticketCarry: (j['ticketCarry'] as num?)?.toInt() ?? 0,
      rally: (j['rally'] as Map?) == null
          ? null
          : (
              estate: '${(j['rally'] as Map)['estate']}',
              at: t((j['rally'] as Map)['at']) ?? DateTime(2026),
              nextAt: t((j['rally'] as Map)['nextAt']) ?? DateTime(2026),
            ),
      gauge: SiegeGauge.fromJson(j['gauge']),
      weak: {
        for (final e in ((j['weak'] as Map?) ?? const {}).entries)
          '${e.key}': [for (final x in (e.value as List?) ?? const []) (x as num).toInt()],
      },
      defense: {
        for (final e in ((j['defense'] as Map?) ?? const {}).entries) '${e.key}': (e.value as num).toInt(),
      },
      news: [
        for (final x in (j['news'] as List?) ?? const [])
          if (x is Map) (at: t(x['at']) ?? DateTime(2026), text: '${x['text'] ?? ''}'),
      ],
      crownStreak: (j['crownStreak'] as num?)?.toInt() ?? 0,
      lastVanguards: {
        for (final e in (((last?['vanguards']) as Map?) ?? const {}).entries) '${e.key}': '${e.value}',
      },
      guards: {
        for (final e in ((j['garrisons'] as Map?) ?? const {}).entries)
          '${e.key}': [for (final x in (e.value as List?) ?? const []) x is Map ? x['job'] as String? : null],
      },
    );
  }
}

/// 묶음 65 #251: 공성전 동안 길드 걸음 게이지 (공성 망치 · 성벽 보수)
class SiegeGauge {
  const SiegeGauge({this.progress = 0, this.full = 0, this.rams = 0, this.ramMax = 2, this.repairs = const [], this.repairTarget});
  final double progress;
  final int full, rams, ramMax;
  final List<String> repairs;
  final String? repairTarget;

  static SiegeGauge? fromJson(Object? o) {
    if (o is! Map) return null;
    return SiegeGauge(
      progress: (o['progress'] as num?)?.toDouble() ?? 0,
      full: (o['full'] as num?)?.toInt() ?? 0,
      rams: (o['rams'] as num?)?.toInt() ?? 0,
      ramMax: (o['ramMax'] as num?)?.toInt() ?? 2,
      repairs: [for (final x in (o['repairs'] as List?) ?? const []) '$x'],
      repairTarget: o['repairTarget'] as String?,
    );
  }
}

/// 엿보기: 수비대 한 자리 (능력치는 숨김)
class PeekSlot {
  const PeekSlot({this.broken = false, this.weak = false, this.kind = 'wild', this.job, this.allies = 0});
  final bool broken, weak;

  /// 'wild' · 'blackGuard' · 'blackCaptain' · 'clone' · 'empty'
  final String kind;
  final String? job;
  final int allies;

  /// 그림으로 쓸 몬스터 (빈 자리 · 야생은 null)
  MonsterId? get monster => switch (kind) {
        'blackGuard' => MonsterId.blackGuard,
        'blackCaptain' => MonsterId.blackCaptain,
        'clone' => ErbardRules.cloneOf(job),
        _ => null,
      };
}

/// 공성권 한 장 싸움의 결과
class ErbardFightResult {
  const ErbardFightResult({this.won = false, this.captured = false, this.full = false, this.lines = const [], this.error});
  final bool won, captured, full;
  final List<String> lines;
  final String? error;
}

/// 싸우려는 자리 (서버가 준 상대)
class _ErbardFight {
  const _ErbardFight(this.estate, this.slot, this.kind, {this.solo = false});
  final String estate;
  final int slot;
  final String kind;
  final bool solo;
}

/// 5막 첫 편 「흑등 연맹의 귀환」 (묶음 60 #247): 장 흐름 · 장면 · 공성권 · 에르바르드(서버) · 혼자 개척 · 수비대 · 연맹 · 사냥
extension Act5Ops on AppController {
  Act5State get act5 => _act5;
  ErbardView get erbard => _erbardView ?? _soloErbard;
  String? get erbardError => _erbardError;
  bool get erbardBusy => _erbardBusy;

  Future<void> _saveAct5() => store.saveJson(AppController._act5Key, _act5.toJson());

  /// 4막 5장 뒤
  bool get act5Available => _act4.done;
  bool get act5Open => act5Available && _act5.opened;

  Future<void> openAct5() => _serial(() async {
        if (!act5Available || _act5.opened) return;
        _act5 = _act5.copyWith(opened: true, chapter: 1, chapterSteps: _totalSteps);
        await _saveAct5();
        _notify();
      });

  int get act5Chapter => _act5.chapter;
  bool get act5Done => _act5.done;
  int get act5StepsInChapter => math.max(0, _totalSteps - _act5.chapterSteps);

  /// 진짜 길드(서버)에 있는지 — 아니면 혼자(리안의 길드 · 로그인 전)
  bool get erbardGuild => !_act4.lian && (_guildView?.id != null) && guildReady;

  // ───────────── 공성권 (5막 1장부터 2,000보마다 1장, 최대 20장)

  int get siegeTickets {
    final at = _act5.ticketAt;
    if (at == null) return 0;
    return math.min(ErbardRules.ticketMax, _act5.ticketBank + math.max(0, _totalSteps - at) ~/ ErbardRules.ticketSteps);
  }

  /// 다음 한 장까지 (0~1, 숫자 없이 막대)
  double get siegeTicketProgress {
    final at = _act5.ticketAt;
    if (at == null || siegeTickets >= ErbardRules.ticketMax) return 1;
    return (math.max(0, _totalSteps - at) % ErbardRules.ticketSteps) / ErbardRules.ticketSteps;
  }

  Act5State _spendTicket(Act5State a) {
    final at = a.ticketAt ?? _totalSteps;
    final walked = math.max(0, _totalSteps - at);
    final cur = math.min(ErbardRules.ticketMax, a.ticketBank + walked ~/ ErbardRules.ticketSteps);
    final keep = cur >= ErbardRules.ticketMax ? 0 : walked % ErbardRules.ticketSteps;
    return a.copyWith(ticketBank: math.max(0, cur - 1), ticketAt: _totalSteps - keep);
  }

  // ───────────── 장 흐름 · 장면

  bool _guildHasEstate() => erbard.myEstates.isNotEmpty;

  bool act5ChapterUnlocked(int n) {
    if (!act5Open) return false;
    if (n < _act5.chapter) return true;
    if (n > _act5.chapter) return false;
    return switch (n) {
      1 => true,
      2 => act5StepsInChapter >= ErbardRules.ch2Steps && (_act5.pioneered || _act5.wildWins >= ErbardRules.slots || _guildHasEstate()),
      _ => _ch3Ready,
    };
  }

  /// 3장: 정한 공성전이 끝났고 참여했으면 (결과를 아는 경우)
  bool get _ch3Ready {
    final n = _act5.ch3Siege;
    if (n == null) return false;
    if (_clock().toUtc().isBefore(ErbardRules.siegeEnd(n))) return false;
    return _act5.ch3Used > 0 || _act5.ch3Solo >= ErbardRules.soloSiegeFights;
  }

  List<Act4Scene> _act5Scenes(int n) => switch (n) {
        1 => const [ErbardRules.e1a, ErbardRules.e1b, ErbardRules.e1c],
        2 => [ErbardRules.e2a, if (!erbardGuild) ErbardRules.e2bSolo],
        _ => [(_act5.royalWon ?? false) ? ErbardRules.e3aWin : ErbardRules.e3aLose, ErbardRules.e3b],
      };

  Act4Scene? get pendingAct5Scene {
    if (!act5Open || _act5.done) return null;
    _rollCh3();
    if (!act5ChapterUnlocked(_act5.chapter)) return null;
    for (final s in _act5Scenes(_act5.chapter)) {
      if (!_act5.has(s.id)) return s;
    }
    return null;
  }

  /// 3장 공성전에 참여하지 못하고 끝났으면 다음 공성전으로
  void _rollCh3() {
    final n = _act5.ch3Siege;
    if (_act5.chapter != 3 || n == null) return;
    if (_clock().toUtc().isBefore(ErbardRules.siegeEnd(n))) return;
    if (_act5.ch3Used > 0 || _act5.ch3Solo >= ErbardRules.soloSiegeFights) {
      // 결과: 서버에서 본 그 공성전의 왕성 주인
      final v = _erbardView;
      if (_act5.royalWon == null && v != null && v.lastNo != null && v.lastNo! >= n) {
        _act5 = _act5.copyWith(royalWon: !v.lastRoyalNpc);
        unawaited(_saveAct5());
      }
      return;
    }
    _act5 = _act5.copyWith(ch3Siege: ErbardRules.siegeNo(_clock()), ch3Used: 0, ch3Solo: 0);
    unawaited(_saveAct5());
  }

  /// 일지 한 줄 (숫자 없이)
  String get act5Goal {
    if (_act5.done) return ErbardRules.erbardTeaser;
    return switch (_act5.chapter) {
      1 => '리안과 함께 다리 너머 에르바르드로 가요',
      2 when !_act5.has('e2a') && act5StepsInChapter < ErbardRules.ch2Steps => '걸으며 공성권을 모으고, 빈 영지의 야생 수비대를 깨요',
      2 when !_act5.has('e2a') => '빈 영지 하나의 야생 수비대 다섯 자리를 모두 깨요',
      2 => '세라의 이야기를 들어요',
      _ => erbardGuild
          ? '다음 깃발 공성전에 공성권을 한 장 이상 써요'
          : '다음 깃발 공성전 기간에 야생 수비대와 세 번 싸워요',
    };
  }

  double get act5Progress {
    if (_act5.chapter == 2) return (act5StepsInChapter / ErbardRules.ch2Steps).clamp(0.0, 1.0);
    return 1;
  }

  Future<void> markAct5Scene(Act4Scene s) => _serial(() async {
        if (_act5.has(s.id)) return;
        var a = _act5.copyWith(seen: {..._act5.seen, s.id});
        final gifts = <String, int>{};
        if (s.id == 'e1c') {
          a = a.copyWith(chapter: 2, chapterSteps: _totalSteps, ticketAt: a.ticketAt ?? _totalSteps);
        }
        if (s.id == 'e2b' && s.lianOnly) {
          gifts[Wallet.gold] = ErbardRules.pioneerGold;
          a = a.copyWith(pioneered: true);
        }
        if (a.chapter == 2 && _act5Scenes(2).every((x) => a.has(x.id))) {
          final now = _clock();
          final next = ErbardRules.siegeActive(now) ? ErbardRules.siegeNo(now) + 1 : ErbardRules.siegeNo(now);
          a = a.copyWith(chapter: 3, ch3Siege: next, ch3Used: 0, ch3Solo: 0);
        }
        if (s.id == 'e3b') {
          a = a.copyWith(done: true);
          final t = await _todayRecord();
          await _save(t.copyWith(
              counters: DailyRecord.addCounts(t.counters, {TitleRules.skyCounter(TitleId.pioneer): 1})));
        }
        _act5 = a;
        await _saveAct5();
        if (s.id == 'e2b' && s.lianOnly) {
          _act4 = _act4.copyWith(seals: _act4.seals + ErbardRules.pioneerSeals);
          await _saveAct4();
        }
        if (gifts.isNotEmpty) await _applyGifts(gifts);
        _notify();
      });

  // ───────────── 에르바르드 (서버)

  /// 혼자 보는 판: 흑등 연맹 처음 자리 + 내가 깬 야생 수비대
  ErbardView get _soloErbard {
    final now = _clock();
    final n = ErbardRules.siegeNo(now);
    return ErbardView(
      owners: {
        for (final e in ErbardRules.startOwners.entries)
          e.key: (kind: 'npc', name: ErbardRules.npcName, emblem: 0, color: 7, crown: false),
      },
      siegeNo: n,
      active: ErbardRules.siegeActive(now),
      start: ErbardRules.siegeStart(n),
      end: ErbardRules.siegeEnd(n),
      wild: {
        for (final e in _act5.soloWild.entries)
          e.key: [for (var k = 0; k < ErbardRules.slots; k++) if (e.value & (1 << k) != 0) k],
      },
    );
  }

  Future<Map<String, dynamic>?> _siegeCall(String path, [Map<String, dynamic> body = const {}]) async {
    final api = arcaApi, a = cloudAuth;
    if (api == null || a == null || !_cloud.signedIn) {
      _erbardError = 'login_required';
      _notify();
      return null;
    }
    _erbardBusy = true;
    _notify();
    try {
      final token = await a.idToken();
      if (token == null) throw const ArcaApiError('login_required');
      // 묶음 61: 공성권은 서버가 셈 (함께하는 걸음 · 처음 한 번은 앱 장수를 옮김)
      final me = {
        ...await _socialSteps(),
        'device': await deviceId(),
        'tickets': siegeTickets,
        'carry': (siegeTicketProgress * ErbardRules.ticketSteps).floor(),
      };
      final j = await api.post(path, {...body, 'me': me}, token: token);
      _erbardError = null;
      if (j.containsKey('owners')) _erbardView = ErbardView.fromJson(j);
      if (j['tickets'] is num) await _syncTickets((j['tickets'] as num).toInt(), (j['ticketCarry'] as num?)?.toInt());
      return j;
    } on ArcaApiError catch (e) {
      _erbardError = e.code;
      return null;
    } catch (_) {
      _erbardError = 'offline';
      return null;
    } finally {
      _erbardBusy = false;
      _notify();
    }
  }

  /// 서버가 센 공성권으로 앱 장수를 맞춤 (진행 걸음도)
  Future<void> _syncTickets(int n, int? carry) async {
    final c = (carry ?? (siegeTicketProgress * ErbardRules.ticketSteps).floor()).clamp(0, ErbardRules.ticketSteps - 1);
    if (_act5.ticketAt == null || n == siegeTickets) return;
    _act5 = _act5.copyWith(ticketBank: n, ticketAt: _totalSteps - c);
    await _saveAct5();
  }

  Future<void> refreshErbard() async {
    if (!act5Open || !guildReady) return;
    if (!_siegeSeenLoaded) {
      _siegeSeenLoaded = true;
      await _loadSiegeSeen();
    }
    await _siegeCall('/siege/state');
    _rollCh3();
  }

  /// 아직 안 본 공성전 결과 (5막 2장부터)
  bool get siegeResultPending {
    final v = _erbardView;
    return act5Open && _act5.chapter >= 2 && v != null && v.lastNo != null && v.lastNo! > _act5.lastResultSeen;
  }

  Future<void> markSiegeResultSeen() async {
    final v = _erbardView;
    if (v?.lastNo == null) return;
    _act5 = _act5.copyWith(lastResultSeen: v!.lastNo);
    await _saveAct5();
    _notify();
  }

  /// 이 영지에서 지금 할 수 있는 싸움 ('wild' · 'siege' · null)
  String? erbardFightKind(EstateInfo e) {
    final v = erbard;
    final o = v.owners[e.id];
    if (o == null) return e.royal ? null : 'wild';
    if (!erbardGuild || !v.active) return null;
    if (o.kind == 'mine' || o.kind == 'ally') return null;
    return 'siege';
  }

  /// 공성권 한 장으로 싸움을 시작한다 (못 하면 null, 까닭은 [erbardError])
  Future<Battle?> startErbardFight(EstateInfo e) async {
    if (!act5Open || _act5.ticketAt == null) return null;
    if (siegeTickets <= 0) {
      _erbardError = 'no_ticket';
      _notify();
      return null;
    }
    final kind = erbardFightKind(e);
    if (kind == null) {
      _erbardError = erbard.owners[e.id] == null ? 'not_siege' : 'not_siege';
      _notify();
      return null;
    }
    final lv = player.level.level;
    if (!erbardGuild) {
      // 혼자: 야생 수비대만 (영지는 빈 채로)
      final mask = _act5.soloWild[e.id] ?? 0;
      final slot = [for (var k = 0; k < ErbardRules.slots; k++) k].where((k) => mask & (1 << k) == 0).firstOrNull ?? 0;
      _erbardFight = _ErbardFight(e.id, slot, 'wild', solo: true);
      return _erbardBattle([_wildFoe(e, slot, math.max(20, lv))]);
    }
    final j = await _siegeCall('/siege/foe', {'estate': e.id});
    if (j == null) return null;
    final slot = (j['slot'] as num?)?.toInt();
    if (slot == null) {
      _erbardError = 'broken';
      _notify();
      return null;
    }
    final level = (j['level'] as num?)?.toInt() ?? lv;
    _erbardFight = _ErbardFight(e.id, slot, '${j['kind']}');
    final guard = j['guard'] as Map?;
    // 묶음 65: 공성 망치로 흔들린 자리는 약하게
    final bonus = ((j['bonus'] as num?)?.toDouble() ?? 0);
    final ram = j['weakened'] == true ? ErbardRules.ramWeak : 1.0;
    final List<Foe> foes;
    if (j['kind'] == 'wild') {
      foes = [_wildFoe(e, slot, level)];
    } else if (j['npc'] == true) {
      final m = ErbardRules.blackOf(e, slot);
      foes = [_guardFoe(m, e, slot, level, 1.15 * ram, label: m == MonsterId.blackCaptain ? '흑등 연맹 지휘관' : '흑등 연맹 수비대')];
    } else if (guard != null) {
      foes = [
        _guardFoe(ErbardRules.cloneOf(guard['job'] as String?), e, slot, (guard['level'] as num?)?.toInt() ?? level,
            1.1 * (1 + bonus) * ram,
            label: '${guard['name']}의 분신'),
        for (final a in (guard['allies'] as List?) ?? const [])
          if (a is Map)
            _guardFoe(ErbardRules.cloneOf(a['job'] as String?), e, slot, (a['level'] as num?)?.toInt() ?? level,
                0.6 * (1 + bonus) * ram,
                label: '${a['name']}'),
      ];
    } else {
      foes = [_wildFoe(e, slot, level, mult: (1 + bonus) * ram)];
    }
    final b = _erbardBattle(foes);
    // 묶음 65: 집결 깃발 영지면 조금 강하게 · 수비대 상성 (주 직업 +25% · 받는 피해 −30%, 보조면 절반, 숨김)
    if (j['rally'] == true) b.dealMult *= 1 + ErbardRules.rallyBonus;
    final w = siegeWeakness(foes.first.monster);
    if (w > 0) {
      b.dealMult *= 1 + GuildRules.weakDeal * w;
      b.takenMult *= 1 - GuildRules.weakTaken * w;
    }
    return b;
  }

  /// 수비대 상성: 내 주 직업이 그 수비대에 강하면 1, 보조 직업이면 0.5, 아니면 0
  double siegeWeakness(MonsterId m) {
    final weak = ErbardRules.cloneWeakTo[m.name] ?? const <JobId>[];
    return weak.contains(mainJob) ? 1.0 : weak.contains(subJob) ? 0.5 : 0.0;
  }

  /// 「이 자리는 ○○에게 약해 보여요」 (강한 직업 이름)
  String? weakLine(MonsterId m) {
    final weak = ErbardRules.cloneWeakTo[m.name];
    if (weak == null || weak.isEmpty) return null;
    return '이 자리는 ${weak.map((j) => JobRules.info(j).name).join(' · ')}에게 약해 보여요';
  }

  // ───────────── 묶음 65 #251: 집결 깃발 · 성벽 보수 영지 · 엿보기

  Future<bool> setRally(String estate) async => await _siegeCall('/siege/rally', {'estate': estate}) != null;

  Future<bool> setRepairTarget(String estate) async => await _siegeCall('/siege/repair', {'estate': estate}) != null;

  Future<List<PeekSlot>?> peekEstate(String estate) async {
    final j = await _siegeCall('/siege/peek', {'estate': estate});
    if (j == null) return null;
    return [
      for (final x in (j['slots'] as List?) ?? const [])
        if (x is Map)
          PeekSlot(
            broken: x['broken'] == true,
            weak: x['weak'] == true,
            kind: '${x['kind'] ?? 'wild'}',
            job: x['job'] as String?,
            allies: (x['allies'] as num?)?.toInt() ?? 0,
          ),
    ];
  }

  /// 마지막 6시간 (일요일 18~24시)
  bool get siegeFinal => ErbardRules.siegeFinal(_clock());

  /// 「○○ 영지에 집결해요」: 공성전 · 영지마다 한 번 (이 휴대폰)
  bool takeRallyNotice(int siege, String estate) {
    final k = 'rally:$siege:$estate';
    if (_siegeSeen.contains(k)) return false;
    _siegeSeen.add(k);
    unawaited(store.saveSide('siegeSeen', _siegeSeen.join(',')));
    return true;
  }

  /// 「마지막 6시간」: 공성전마다 한 번
  bool takeFinalNotice(int siege) {
    final k = 'final:$siege';
    if (_siegeSeen.contains(k)) return false;
    _siegeSeen.add(k);
    unawaited(store.saveSide('siegeSeen', _siegeSeen.join(',')));
    return true;
  }

  Future<void> _loadSiegeSeen() async {
    final s = await store.loadSide('siegeSeen');
    _siegeSeen
      ..clear()
      ..addAll((s ?? '').split(',').where((x) => x.isNotEmpty));
  }

  Foe _wildFoe(EstateInfo e, int slot, int level, {double mult = 1}) =>
      _guardFoe(ErbardRules.wildMonster(e, slot), e, slot, level, mult);

  Foe _guardFoe(MonsterId m, EstateInfo e, int slot, int level, double mult, {String? label}) {
    final b = BattleRules.fieldFoe(level: level, monster: m);
    final k = ErbardRules.guardMult(e, slot) * mult;
    return Foe(
      monster: m,
      maxHp: math.max(1, (b.maxHp * ErbardRules.wildHp * k).round()),
      attack: math.max(1, (b.attack * ErbardRules.wildAtk * math.sqrt(k)).round()),
      defense: b.defense,
      speed: b.speed,
      label: label,
      tint: Monsters.info(m).tint,
    );
  }

  Battle _erbardBattle(List<Foe> foes) {
    final b = _trainingBattle(foes, potions: true)..hideFoeNumbers = true;
    return b;
  }

  /// 싸움이 끝났을 때 (이기든 지든 공성권 한 장)
  Future<ErbardFightResult> finishErbardFight(Battle b) async {
    final f = _erbardFight;
    _erbardFight = null;
    if (f == null) return const ErbardFightResult();
    await _consumeBattlePotions(b);
    final won = b.phase == BattlePhase.cleared;
    final now = _clock();
    final siegeNow = ErbardRules.siegeActive(now);
    final inCh3 = _act5.chapter == 3 && siegeNow && _act5.ch3Siege == ErbardRules.siegeNo(now);
    var a = _spendTicket(_act5);
    final lines = <String>[];
    var captured = false, full = false;
    if (f.solo) {
      var mask = a.soloWild[f.estate] ?? 0;
      if (won) mask |= 1 << f.slot;
      full = mask == (1 << ErbardRules.slots) - 1;
      a = a.copyWith(
        soloWild: {...a.soloWild, f.estate: full ? 0 : mask},
        wildWins: a.wildWins + (won ? 1 : 0),
        pioneered: a.pioneered || full,
        ch3Solo: inCh3 ? a.ch3Solo + 1 : null,
      );
      _act5 = a;
      await _saveAct5();
    } else {
      final j = await _siegeCall('/siege/fight', {'estate': f.estate, 'slot': f.slot, 'win': won});
      if (j == null) {
        // 서버가 받지 못했으면 공성권은 그대로
        return ErbardFightResult(won: won, error: _erbardError);
      }
      captured = j['captured'] == true;
      full = j['full'] == true;
      a = a.copyWith(
        wildWins: a.wildWins + (won && f.kind == 'wild' ? 1 : 0),
        pioneered: a.pioneered || (full && f.kind == 'wild'),
        ch3Used: inCh3 ? a.ch3Used + 1 : null,
      );
      _act5 = a;
      await _saveAct5();
      await refreshErbard();
    }
    final gifts = <String, int>{};
    if (won && f.kind == 'wild') {
      gifts[Wallet.gold] = ErbardRules.wildWinGold;
      final e = ErbardRules.estate(f.estate);
      final d = e?.province == null ? null : LootRules.dropsOf(ErbardRules.wildMonster(e!, f.slot));
      if (d != null) gifts[d.common.first.name] = 1;
    }
    if (full && f.kind == 'wild') {
      _act4 = _act4.copyWith(seals: _act4.seals + ErbardRules.wildClearSeals);
      await _saveAct4();
      lines.add('등불 인장 ${ErbardRules.wildClearSeals}');
    }
    if (gifts.isNotEmpty) lines.insertAll(0, await _applyGifts(gifts, over: BagOver.mail));
    await gainMastery(Mastery.combat, TrainingRules.dailyMastery);
    _notify();
    return ErbardFightResult(won: won, captured: captured, full: full, lines: lines);
  }

  // ───────────── 수비대 (우리 길드 영지 한 자리에 내 분신 + 동료 2)

  bool get garrisonOpen => _act5.has('e2a');

  Future<bool> placeGarrison(String estate, int slot, List<String> allyIds) async {
    final allies = [
      for (final id in allyIds.take(ErbardRules.garrisonAllies))
        if (_act3.ally(id) case final a?) {'name': a.name, 'level': a.level, 'job': a.job},
    ];
    final j = await _siegeCall('/siege/garrison', {
      'estate': estate,
      'slot': slot,
      'snap': {
        'name': _profile.name,
        'level': player.level.level,
        if (mainJob != null) 'job': mainJob!.name,
        'allies': allies,
      },
    });
    return j != null;
  }

  Future<bool> removeGarrison() async => await _siegeCall('/siege/ungarrison') != null;

  // ───────────── 연맹

  Future<bool> allianceAction(String action, {String? name, String? code}) async =>
      await _siegeCall('/siege/alliance', {'action': action, if (name != null) 'name': name, if (code != null) 'code': code}) !=
      null;

  // ───────────── 에르바르드 사냥 (여정 기력) — 우리 길드 영지면 경험치 · 재료 조금 더

  bool canErbardHunt(EstateInfo e) => act5Open && !e.royal && _act3.energy >= ErbardRules.huntEnergy && hp > 0;

  Battle? startErbardHunt(EstateInfo e) {
    if (!canErbardHunt(e)) return null;
    _erbardHunt = e.id;
    return startEncounter(A3Enc(
      kind: A3Kind.field,
      foes: [ErbardRules.province(e.province!).outer],
      energy: ErbardRules.huntEnergy,
    ));
  }

  Future<Act3FightResult> finishErbardHunt(Battle b) async {
    final id = _erbardHunt;
    _erbardHunt = null;
    final r = await finishAct3Fight(b);
    final e = id == null ? null : ErbardRules.estate(id);
    if (!r.won || e == null || !erbard.myEstates.contains(e.id)) return r;
    final extra = (Act3Rules.fieldExp * ErbardRules.ownedHuntBonus).round();
    final gifts = <String, int>{Wallet.exp: math.max(1, extra)};
    if (_random.nextDouble() < 0.3) gifts[ErbardRules.provinceMat(e.province!).name] = 1;
    final got = await _applyGifts(gifts, over: BagOver.mail);
    return Act3FightResult(
      won: true,
      exp: r.exp,
      gold: r.gold,
      items: r.items,
      allyLevels: r.allyLevels,
      lines: [...r.lines, '우리 길드 영지라 조금 더 얻었어요 · ${got.join(' · ')}'],
      tickets: r.tickets,
    );
  }
}
