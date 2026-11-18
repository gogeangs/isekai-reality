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
    final me = uid;
    if (path.startsWith('/party/') && token == null) throw const ArcaApiError('login_required', status: 401);
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
        final fee = (p * 0.02).round() < 10 ? 10 : (p * 0.02).round();
        return {'ok': true, 'listing': l, 'fee': body['seal'] == true ? (fee / 2).round() : fee};
      case '/market/browse':
        return {
          'items': [
            for (final l in listings)
              if (l['mine'] != true && (body['auction'] == true) == (l['mode'] == 'auction')) l,
          ],
        };
      case '/market/mine':
        return {'selling': [for (final l in listings) if (l['mine'] == true) l], 'bidding': [], 'slots': 5};
      case '/market/price':
        return {'count': 2, 'min': 8, 'max': 12, 'avg': 10, 'last': 12};
      case '/market/buy':
        if (marketFail != null) throw ArcaApiError(marketFail!);
        marketBodies.add(body);
        final l = listings.firstWhere((x) => x['id'] == body['id']);
        l['status'] = 'sold';
        inbox.add({'id': 'buy${l['id']}', 'from': '바르칸', 'title': '「${l['name']}」을 샀어요', 'reward': {'${l['key']}': l['qty']}, 'equips': l['equip'] == null ? [] : [l['equip']]});
        return {'ok': true, 'charged': l['price']};
      case '/market/bid':
        if (marketFail != null) throw ArcaApiError(marketFail!);
        marketBodies.add(body);
        return {'ok': true, 'charged': body['amount'], 'sold': false};
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
      case '/inbox':
        final out = [...inbox];
        inbox.clear();
        return {'msgs': out};
    }
    throw const ArcaApiError('not_found', status: 404);
  }
}
