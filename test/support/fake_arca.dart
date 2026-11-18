// 시험용 아르카 서버 (묶음 56): 서버(firebase/functions/src)와 같은 길 · 같은 모양의 답을 메모리에서.
// 판정 규칙은 서버 시험(node --test)에서 따로 본다. 여기선 앱 흐름만.
import 'package:isekai_reality/data/cloud/arca_api.dart';

class FakeArca implements ArcaApi {
  FakeArca({this.uid = 'u_me'});

  /// 토큰 → uid (FakeCloudAuth 의 토큰이 무엇이든 이 uid 로 봄)
  final String uid;

  final Map<String, Map<String, dynamic>> parties = {};
  final Map<String, String> partyOf = {};
  final Map<String, int> steps = {};
  final Map<String, int> dmg = {};
  final Map<String, Set<String>> claimed = {};
  final List<Map<String, dynamic>> inquiries = [];
  final List<Map<String, dynamic>> inbox = [];
  final List<String> calls = [];
  int bossHp = 30000;
  int ticketsUsed = 0;
  bool near = false;
  bool offline = false;
  bool restricted = false;
  String? cheeredBy;

  // 묶음 58: 거래소 · 심층 순위 (판정은 서버 시험에서, 여기선 앱 흐름만)
  final List<Map<String, dynamic>> listings = [];
  final List<Map<String, dynamic>> marketBodies = [];
  String? marketFail;
  final Map<String, int> deepRows = {};
  String deepRegion = 'selenia';

  // 묶음 59: 길드 · 공지 · 제재 상태 (판정은 서버 시험에서, 여기선 앱 흐름만)
  Map<String, dynamic>? guild;
  final Map<String, Map<String, dynamic>> guildMembers = {};
  final List<Map<String, dynamic>> publicGuilds = [];
  final List<Map<String, dynamic>> notices = [];
  int guildLevel = 1;
  int guildStar = 1;
  int raidTickets = 3;
  double raidLeft = 1.0;
  bool giantDone = false;
  final Set<String> guildClaimed = {};
  final List<String> guildDecos = [];
  final List<String?> guildSlots = [null, null, null, null];
  List<bool> walkDone = [true, false, false];
  int myRaidDamage = 0;
  int statusLevel = 0;

  // 묶음 60: 에르바르드 (판정은 서버 시험에서)
  final Map<String, Map<String, dynamic>?> siegeOwners = {
    'royal': {'gid': 'npc', 'name': '흑등 연맹', 'emblem': 0, 'color': 7},
    for (final id in ['sol_silver', 'dor_bronze', 'sil_vine', 'mor_raven', 'ign_gate'])
      id: {'gid': 'npc', 'name': '흑등 연맹', 'emblem': 0, 'color': 7},
  };
  final Map<String, List<int>> siegeWild = {};
  final Map<String, List<int>> siegeRun = {};
  final Map<String, List<Map<String, dynamic>?>> garrisons = {};
  bool siegeActive = false;
  int siegeNo = 0;
  Map<String, dynamic>? siegeLast;
  Map<String, dynamic>? alliance;
  int siegeUsed = 0;
  int treasury = 0;

  // 묶음 61: 거래 지갑 · 공성권(서버가 셈) · 금고 쓰기 · 보낸 걸음 (판정은 서버 시험에서)
  int wallet = 0;
  int? siegeTickets;
  final Map<String, int> boosts = {};
  final List<Map<String, dynamic>> tlog = [];
  bool goldFlag = false;
  bool canShare = false;
  final List<Map<String, dynamic>> meSent = [];
  final List<Map<String, dynamic>> nearSent = [];
  void _tl(String what, int gold) => tlog.insert(0, {'at': DateTime(2026, 11, 30, 10).millisecondsSinceEpoch, 'name': '하루', 'what': what, 'gold': gold});

  Map<String, dynamic> _siegeState(String me) => {
        'owners': siegeOwners,
        'siege': {'no': siegeNo, 'active': siegeActive, 'start': DateTime.utc(2026, 11, 27, 15).millisecondsSinceEpoch, 'end': DateTime.utc(2026, 11, 29, 15).millisecondsSinceEpoch},
        'guild': guild == null ? null : {
          'estates': [for (final e in siegeOwners.entries) if (e.value?['gid'] == 'mine') e.key],
          'treasury': treasury,
          'staff': true,
          'owner': true,
          'canShare': canShare,
          'shareNo': 0,
        },
        'boosts': boosts,
        if (siegeTickets != null) 'tickets': siegeTickets,
        if (siegeTickets != null) 'ticketCarry': 500,
        'garrisons': {
          for (final e in siegeOwners.entries)
            if (e.value?['gid'] == 'mine') e.key: garrisons[e.key] ?? [null, null, null, null, null],
        },
        'placed': [for (final e in garrisons.entries) if (e.value.any((x) => x?['me'] == true)) e.key].firstOrNull,
        'wild': siegeWild,
        'run': siegeRun,
        'used': siegeUsed,
        'last': siegeLast,
        'alliance': alliance,
      };

  Map<String, dynamic> _siegePost(String me, String path, Map<String, dynamic> body) {
    final id = '${body['estate'] ?? ''}';
    switch (path) {
      case '/siege/state':
        return _siegeState(me);
      case '/siege/foe':
        if (guild == null) throw const ArcaApiError('no_guild');
        final o = siegeOwners[id];
        if (o == null) {
          final b = siegeWild[id] ?? [];
          return {'kind': 'wild', 'slot': [0, 1, 2, 3, 4].firstWhere((k) => !b.contains(k)), 'level': 30, 'broken': b};
        }
        if (!siegeActive) throw const ArcaApiError('not_siege');
        final b = siegeRun[id] ?? [];
        return {
          'kind': 'siege',
          'slot': [0, 1, 2, 3, 4].firstWhere((k) => !b.contains(k)),
          'level': 30,
          'broken': b,
          if (o['gid'] == 'npc') 'npc': true,
          if (o['gid'] != 'npc') 'guard': {'name': '별하', 'level': 31, 'job': 'mage', 'allies': [{'name': '도윤', 'level': 28, 'job': 'knight'}]},
          'bonus': 0.1,
        };
      case '/siege/fight':
        if (siegeTickets != null) {
          if (siegeTickets! <= 0) throw const ArcaApiError('no_ticket');
          siegeTickets = siegeTickets! - 1;
        }
        final k = (body['slot'] as num).toInt();
        final win = body['win'] == true;
        if (siegeActive) siegeUsed++;
        if (siegeOwners[id] == null) {
          final b = siegeWild.putIfAbsent(id, () => []);
          if (win) b.add(k);
          final full = b.length >= 5;
          if (full) {
            siegeOwners[id] = {'gid': 'mine', 'name': guild?['name'] ?? '', 'emblem': 0, 'color': 0};
            siegeWild.remove(id);
          }
          return {'kind': 'wild', 'won': win, 'broken': b, 'captured': full, 'full': full, 'clearSeals': full ? 15 : 0};
        }
        final b = siegeRun.putIfAbsent(id, () => []);
        if (win) b.add(k);
        return {'kind': 'siege', 'won': win, 'broken': b, 'full': b.length >= 5};
      case '/siege/garrison':
        if (siegeActive) throw const ArcaApiError('siege_lock');
        final snap = (body['snap'] as Map).cast<String, dynamic>();
        final g = garrisons.putIfAbsent(id, () => [null, null, null, null, null]);
        for (final e in garrisons.values) {
          for (var i = 0; i < e.length; i++) {
            if (e[i]?['me'] == true) e[i] = null;
          }
        }
        g[(body['slot'] as num).toInt()] = {
          'name': snap['name'],
          'level': snap['level'],
          'job': snap['job'],
          'allies': [for (final a in (snap['allies'] as List)) (a as Map)['name']],
          'me': true,
        };
        return _siegeState(me);
      case '/siege/ungarrison':
        for (final e in garrisons.values) {
          for (var i = 0; i < e.length; i++) {
            if (e[i]?['me'] == true) e[i] = null;
          }
        }
        return _siegeState(me);
      case '/siege/alliance':
        if (body['action'] == 'create') alliance = {'name': body['name'], 'code': 'ALY234', 'guilds': [guild?['name']], 'locked': false};
        if (body['action'] == 'leave') alliance = null;
        return _siegeState(me);
    }
    throw const ArcaApiError('not_found', status: 404);
  }

  Map<String, dynamic> _guildState(String me) {
    final g = guild;
    if (g == null || !guildMembers.containsKey(me)) return {'guild': null};
    final raidDone = raidLeft <= 0;
    return {
      'guild': {
        ...g,
        'role': guildMembers[me]!['role'],
        'level': guildLevel,
        'progress': 0.4,
        'size': 20 + 2 * ((guildLevel - 1) ~/ 2),
        'giantDone': giantDone,
        'titles': [if (giantDone) 'raidGiant'],
        'goldFlag': goldFlag,
      },
      'members': [
        for (final e in guildMembers.entries) {...e.value, 'uid': e.key, 'me': e.key == me},
      ],
      'walk': {
        'progress': [for (final d in walkDone) d ? 1.0 : 0.5],
        'done': walkDone,
        'claimed': [for (var i = 0; i < 3; i++) if (guildClaimed.contains('walk$i')) i],
      },
      'treasury': {'gold': treasury, 'log': tlog},
      'hall': {'star': guildStar, 'progress': 0.3, 'nextLevel': guildStar < 4 ? [0, 0, 3, 6, 10][guildStar + 1] : null, 'decos': guildDecos, 'slots': guildSlots},
      if (guildLevel >= 4)
        'raid': {
          'id': 'raidDragon',
          'started': true,
          'progress': 1 - raidLeft,
          'myDamage': myRaidDamage,
          'myShare': 0.2,
          'defeated': raidDone,
          'tickets': raidTickets,
          'claimed': guildClaimed.contains('raid'),
        },
      if (guildLevel >= 4)
        'giant': {
          'id': 'raidGiant',
          'progress': giantDone ? 1 : 1 - raidLeft,
          'myDamage': myRaidDamage,
          'defeated': giantDone,
          'tickets': raidTickets,
          'claimed': guildClaimed.contains('giant'),
        },
    };
  }

  Map<String, dynamic> _guildPost(String me, String path, Map<String, dynamic> body) {
    void staff() {
      final r = guildMembers[me]?['role'];
      if (r != 'owner' && r != 'vice') throw const ArcaApiError('not_staff');
    }

    switch (path) {
      case '/guild/state':
        break;
      case '/guild/create':
        if (guildMembers.containsKey(me)) throw const ArcaApiError('already_in_guild');
        guild = {'id': 'g1', 'name': body['name'], 'emblem': body['emblem'] ?? 0, 'color': body['color'] ?? 0, 'open': body['open'] ?? true, 'code': 'GLD001'};
        guildMembers[me] = {'name': (body['me'] as Map?)?['name'] ?? '나', 'level': 30, 'weekSteps': 12000, 'role': 'owner', 'line': ''};
      case '/guild/list':
        return {'items': publicGuilds};
      case '/guild/join':
        if (guild == null || (body['code'] != null && body['code'] != guild!['code'])) throw const ArcaApiError('no_guild');
        guildMembers[me] = {'name': (body['me'] as Map?)?['name'] ?? '나', 'level': 30, 'weekSteps': 12000, 'role': 'member', 'line': ''};
      case '/guild/leave':
        guildMembers.remove(me);
        return {'guild': null};
      case '/guild/kick':
        staff();
        guildMembers.remove(body['target']);
      case '/guild/role':
        if (guildMembers[me]?['role'] != 'owner') throw const ArcaApiError('not_owner');
        guildMembers[body['target']]!['role'] = body['role'];
        if (body['role'] == 'owner') guildMembers[me]!['role'] = 'vice';
      case '/guild/style':
        staff();
        for (final k in ['name', 'emblem', 'color', 'open']) {
          if (body[k] != null) guild![k] = body[k];
        }
      case '/guild/line':
        if ('${body['text']}'.contains('바보')) throw const ArcaApiError('banned_word');
        guildMembers[me]!['line'] = body['text'];
      case '/guild/donate':
        final dg = ((body['gold'] as num?) ?? 0).toInt();
        if (dg > wallet) throw const ArcaApiError('no_wallet_gold');
        wallet -= dg;
        return {'seals': ((body['gold'] as num?) ?? 0) >= 100 ? 2 : 1, 'state': _guildState(me)};
      case '/guild/deco/add':
        staff();
        guildDecos.add('${body['id']}');
      case '/guild/deco/place':
        staff();
        guildSlots[(body['slot'] as num).toInt()] = body['id'] as String?;
      case '/guild/share':
        if (guildStar < 2) throw const ArcaApiError('need_star');
      case '/guild/treasury':
        staff();
        int spend(int n) {
          if (treasury < n) throw const ArcaApiError('no_treasury');
          treasury -= n;
          return n;
        }
        switch (body['action']) {
          case 'boost':
            final lv = (body['level'] as num).toInt();
            final cur = boosts['${body['estate']}'] ?? 0;
            final n = spend([3000, 7000, 12000][lv - 1] - (cur > 0 ? [3000, 7000, 12000][cur - 1] : 0));
            boosts['${body['estate']}'] = lv;
            _tl('수비대 강화 $lv단계', n);
          case 'hall':
            _tl('회관 공사', spend((body['amount'] as num).toInt()));
          case 'share':
            if (!canShare) throw const ArcaApiError('shared');
            canShare = false;
            _tl('제1회 공성전 나눠 주기 (3명)', spend(((body['amount'] as num).toInt() ~/ 3) * 3));
          case 'shop':
            final id = '${body['id']}';
            final n = spend(const {'goldLights': 4000, 'goldFountain': 6000, 'goldFlag': 5000}[id]!);
            if (id == 'goldFlag') {
              goldFlag = true;
            } else {
              guildDecos.add(id);
            }
            _tl('금고 상점', n);
        }
      case '/guild/raid':
        if (raidTickets <= 0) throw const ArcaApiError('no_ticket');
        raidTickets--;
        myRaidDamage += (body['damage'] as num).toInt();
        raidLeft -= 0.5;
        if (body['giant'] == true && raidLeft <= 0) giantDone = true;
      case '/guild/claim':
        final k = body['kind'] == 'walk' ? 'walk${body['tier']}' : '${body['kind']}';
        if (guildClaimed.contains(k)) throw const ArcaApiError('claimed');
        if (body['kind'] == 'walk' && !walkDone[(body['tier'] as num).toInt()]) throw const ArcaApiError('not_yet');
        guildClaimed.add(k);
        return {
          'reward': k.startsWith('walk')
              ? {'seal': [10, 20, 30][(body['tier'] as num).toInt()]}
              : {'seal': 40, 'raidMat': 2, 'raid': body['kind'] == 'giant' ? 'raidGiant' : 'raidDragon', 'chest': 'gold'},
          'state': _guildState(me),
        };
      default:
        throw const ArcaApiError('not_found', status: 404);
    }
    return _guildState(me);
  }

  /// 다른 파티원 (시험에서 넣음)
  void addMember(String code, String id, String name, {int stepsWeek = 0}) {
    final p = parties[code]!;
    (p['members'] as Map)[id] = {'name': name, 'level': 22};
    partyOf[id] = code;
    steps[id] = stepsWeek;
  }

  Map<String, dynamic> _state(String me, Map<String, dynamic> body) {
    final my = (body['me'] as Map?) ?? const {};
    if (my['steps'] is num) steps[me] = (my['steps'] as num).toInt();
    final code = partyOf[me];
    if (restricted) return {'party': null, 'restricted': true};
    if (code == null) return {'party': null, 'restricted': false};
    final p = parties[code]!;
    final members = (p['members'] as Map).cast<String, Map>();
    final total = members.keys.fold<int>(0, (t, u) => t + (steps[u] ?? 0));
    final dealt = dmg.values.fold<int>(0, (t, n) => t + n);
    final cheers = cheeredBy == null ? <String>[] : [cheeredBy!];
    cheeredBy = null;
    return {
      'party': {
        'id': code,
        'name': p['name'],
        'emblem': p['emblem'] ?? 0,
        'color': p['color'] ?? 0,
        'code': code,
        'owner': p['owner'] == me,
      },
      'members': [
        for (final e in members.entries)
          {
            'uid': e.key,
            'name': e.value['name'],
            'level': e.value['level'],
            'steps': steps[e.key] ?? 0,
            'me': e.key == me,
            'owner': p['owner'] == e.key,
            'cheeredToday': (p['cheered'] as Set?)?.contains(e.key) ?? false,
          },
      ],
      'walk': {
        'total': total,
        'goals': [for (final s in [30000, 70000, 100000]) s * members.length],
        'claimed': [
          for (var i = 0; i < 3; i++)
            if ((claimed[me] ?? {}).contains('walk$i')) i,
        ],
      },
      'boss': {
        'id': 'partyGolem',
        'encounter': 1,
        'hp': bossHp,
        'damage': dealt,
        'myDamage': dmg[me] ?? 0,
        'defeated': dealt >= bossHp,
        'tickets': ((steps[me] ?? 0) ~/ 3000).clamp(0, 3) - ticketsUsed,
        'claimed': (claimed[me] ?? {}).contains('boss'),
      },
      'lastBoss': null,
      'cheers': cheers,
      'canCheer': !((p['cheered'] as Set?)?.isNotEmpty ?? false),
      'restricted': false,
      'stepsCounted': true,
    };
  }

  @override
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body, {String? token}) async {
    calls.add(path);
    if (offline) throw const ArcaApiError('offline');
    if (body['me'] is Map) meSent.add((body['me'] as Map).cast<String, dynamic>());
    final me = uid;
    if (path.startsWith('/party/') && token == null) throw const ArcaApiError('login_required', status: 401);
    if (path.startsWith('/siege/')) {
      if (token == null) throw const ArcaApiError('login_required', status: 401);
      return _siegePost(me, path, body);
    }
    if (path.startsWith('/guild/')) {
      if (token == null) throw const ArcaApiError('login_required', status: 401);
      return _guildPost(me, path, body);
    }
    switch (path) {
      case '/party/state':
        return _state(me, body);
      case '/party/create':
        if (partyOf[me] != null) throw const ArcaApiError('already_in_party');
        const code = 'ABC234';
        final my = (body['me'] as Map?) ?? const {};
        final name = '${body['name'] ?? ''}'.isEmpty ? '${my['name']}의 파티' : '${body['name']}';
        parties[code] = {
          'name': name,
          'owner': me,
          'members': {
            me: {'name': my['name'] ?? '나', 'level': my['level'] ?? 1},
          },
          'cheered': <String>{},
        };
        partyOf[me] = code;
        return _state(me, body);
      case '/party/join':
        final code = '${body['code']}';
        final p = parties[code];
        if (p == null) throw const ArcaApiError('no_party');
        if ((p['members'] as Map).length >= 4) throw const ArcaApiError('full');
        final my = (body['me'] as Map?) ?? const {};
        (p['members'] as Map)[me] = {'name': my['name'] ?? '나', 'level': my['level'] ?? 1};
        partyOf[me] = code;
        return _state(me, body);
      case '/party/leave':
        final code = partyOf.remove(me);
        if (code != null) (parties[code]!['members'] as Map).remove(me);
        return {'party': null};
      case '/party/kick':
        final code = partyOf[me]!;
        (parties[code]!['members'] as Map).remove(body['target']);
        partyOf.remove(body['target']);
        return _state(me, body);
      case '/party/style':
        final p = parties[partyOf[me]!]!;
        if (p['owner'] != me) throw const ArcaApiError('not_owner');
        if (body['name'] != null) p['name'] = body['name'];
        if (body['emblem'] != null) p['emblem'] = body['emblem'];
        if (body['color'] != null) p['color'] = body['color'];
        return _state(me, body);
      case '/party/cheer':
        final p = parties[partyOf[me]!]!;
        final s = p['cheered'] as Set<String>;
        if (s.isNotEmpty) throw const ArcaApiError('cheered_today');
        s.add('${body['target']}');
        return _state(me, body);
      case '/party/boss':
        final st = _state(me, body);
        if (((st['boss'] as Map)['tickets'] as int) <= 0) throw const ArcaApiError('no_ticket');
        ticketsUsed++;
        dmg[me] = (dmg[me] ?? 0) + ((body['damage'] as num?)?.toInt() ?? 0);
        return _state(me, body);
      case '/party/claim':
        final st = _state(me, body);
        final kind = body['kind'];
        final key = kind == 'walk' ? 'walk${body['tier']}' : 'boss';
        final set = claimed[me] ??= {};
        if (set.contains(key)) throw const ArcaApiError('claimed');
        Map<String, dynamic> reward;
        if (kind == 'walk') {
          final i = (body['tier'] as num).toInt();
          final w = st['walk'] as Map;
          if ((w['total'] as int) < (w['goals'] as List)[i]) throw const ArcaApiError('not_yet');
          reward = [
            {'gold': 200, 'footTicket': 10},
            {'manaStone': 10, 'matBundle': 1, 'footTicket': 20},
            {'partyChest': 1, 'footTicket': 30},
          ][i];
        } else {
          final b = st['boss'] as Map;
          if (b['defeated'] != true) throw const ArcaApiError('not_yet');
          reward = {'footTicket': 40, 'bossMat': 2, 'boss': 'partyGolem', 'chest': 'gold'};
        }
        set.add(key);
        return {'reward': reward, 'state': _state(me, body)};
      case '/party/near':
        nearSent.add(body);
        return {'near': near};
      case '/inquiry':
        inquiries.add({...body, 'token': token});
        return {'ok': true, 'id': 'q${inquiries.length}'};
      case '/market/list':
        if (marketFail != null) throw ArcaApiError(marketFail!);
        marketBodies.add(body);
        final l = {
          'id': 'm${listings.length + 1}',
          'mine': true,
          'kind': body['kind'],
          'key': body['key'],
          'name': '${body['key']}',
          'qty': body['qty'],
          'mode': body['mode'],
          'price': body['price'],
          'start': body['start'],
          'buyNow': body['buyNow'],
          'status': 'open',
          'endsAt': DateTime(2026, 11, 20).millisecondsSinceEpoch,
        };
        listings.add(l);
        final p = ((body['price'] ?? body['start']) as num).toInt();
        final fee0 = (p * 0.02).round() < 10 ? 10 : (p * 0.02).round();
        final fee = body['seal'] == true ? (fee0 / 2).round() : fee0;
        wallet -= fee;
        return {'ok': true, 'listing': l, 'fee': fee, 'wallet': wallet};
      case '/market/browse':
        return {
          'items': [
            for (final l in listings)
              if (l['mine'] != true && (body['auction'] == true) == (l['mode'] == 'auction')) l,
          ],
          'wallet': wallet,
        };
      case '/market/mine':
        return {'selling': [for (final l in listings) if (l['mine'] == true) l], 'bidding': [], 'slots': 5, 'wallet': wallet};
      case '/market/wallet':
        return {'wallet': wallet};
      case '/market/deposit':
        if (marketFail != null) throw ArcaApiError(marketFail!);
        marketBodies.add(body);
        wallet += (body['amount'] as num).toInt();
        return {'ok': true, 'wallet': wallet, 'amount': body['amount'], 'depositId': 'd1'};
      case '/market/withdraw':
        final a = (body['amount'] as num).toInt();
        if (a > wallet) throw const ArcaApiError('no_wallet_gold');
        wallet -= a;
        inbox.add({'id': 'w$wallet', 'from': '바르칸', 'title': '거래 지갑에서 금화 $a을 꺼냈어요', 'reward': {'gold': a}, 'equips': []});
        return {'ok': true, 'wallet': wallet};
      case '/market/price':
        return {'count': 2, 'min': 8, 'max': 12, 'avg': 10, 'last': 12};
      case '/market/buy':
        if (marketFail != null) throw ArcaApiError(marketFail!);
        marketBodies.add(body);
        final l = listings.firstWhere((x) => x['id'] == body['id']);
        if (wallet < (l['price'] as num)) throw const ArcaApiError('no_wallet_gold');
        wallet -= (l['price'] as num).toInt();
        l['status'] = 'sold';
        inbox.add({'id': 'buy${l['id']}', 'from': '바르칸', 'title': '「${l['name']}」을 샀어요', 'reward': {'${l['key']}': l['qty']}, 'equips': l['equip'] == null ? [] : [l['equip']]});
        return {'ok': true, 'charged': l['price'], 'wallet': wallet};
      case '/market/bid':
        if (marketFail != null) throw ArcaApiError(marketFail!);
        marketBodies.add(body);
        if (wallet < (body['amount'] as num)) throw const ArcaApiError('no_wallet_gold');
        wallet -= (body['amount'] as num).toInt();
        return {'ok': true, 'charged': body['amount'], 'sold': false, 'wallet': wallet};
      case '/market/cancel':
        return {'ok': true};
      case '/deep/submit':
        if (body['region'] == deepRegion) {
          final f = (body['floor'] as num).toInt();
          if (f > (deepRows[me] ?? 0)) deepRows[me] = f;
        }
        return {'ok': true, 'region': deepRegion};
      case '/deep/board':
        return {
          'week': '2026-11-16',
          'region': deepRegion,
          'top': [
            {'rank': 1, 'name': '별', 'floor': 20, 'me': false},
            if (deepRows[me] != null) {'rank': 2, 'name': '하루', 'floor': deepRows[me], 'me': true},
          ],
          'me': deepRows[me] == null ? null : {'rank': 2, 'floor': deepRows[me]},
          'total': deepRows[me] == null ? 1 : 2,
        };
      case '/notices':
        return {'items': notices};
      case '/status':
        return {'level': statusLevel, if (statusLevel >= 3) 'until': '2026-12-18T00:00:00Z'};
      case '/inbox':
        final out = [...inbox];
        inbox.clear();
        return {'msgs': out};
    }
    throw const ArcaApiError('not_found', status: 404);
  }
}
