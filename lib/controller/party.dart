part of '../app_controller.dart';

/// 파티 결과 (보스 한 판)
class PartyBossResult {
  const PartyBossResult({required this.damage, this.defeatedNow = false, this.error});

  /// 서버에 보탠 피해
  final int damage;

  /// 이번 판으로 보스가 쓰러졌는지
  final bool defeatedNow;

  /// 서버에 못 보탰으면 오류 이름
  final String? error;
}

/// 파티 (묶음 56 #236): 주점 「파티」 탭. 판정은 서버(arcaApi)가 하고, 보상은 여기서 준다.
/// 결말(본체) 뒤 · 로그인해야 쓸 수 있다. 파티원 위치는 어디에도 보이지 않는다.
extension PartyOps on AppController {
  PartyView? get party => _partyView;
  PartyLocal get partyLocal => _partyLocal;
  String? get partyError => _partyError;
  bool get partyBusy => _partyBusy;

  /// 주점 「파티」 탭이 보이는 때 (본체를 쓰러뜨린 뒤 만남 장면을 지나면)
  bool get partyOpen => tavernOpen;

  /// 서버를 쓸 수 있는지 (로그인 + 서버 주소)
  bool get partyReady => arcaApi != null && cloudAuth != null && _cloud.signedIn;

  bool get partyNear {
    final u = _partyLocal.nearUntil;
    return u != null && _clock().isBefore(u) && (_partyView?.inParty ?? _partyLocal.joined);
  }

  String get _partyWeek => DailyRecord.dayKeyOf(TownRules.weekStart(_clock()));

  Future<Map<String, dynamic>> _partyMe() async => {
        'name': _profile.name,
        'level': player.level.level,
        'steps': player.today?.steps ?? 0,
        'device': await deviceId(),
      };

  /// 서버에 묻는다. 실패하면 [partyError] 를 남기고 null
  Future<Map<String, dynamic>?> _partyCall(String path, [Map<String, dynamic> body = const {}]) async {
    final api = arcaApi, a = cloudAuth;
    if (api == null || a == null || !_cloud.signedIn) {
      _partyError = 'login_required';
      _notify();
      return null;
    }
    _partyBusy = true;
    _notify();
    try {
      final token = await a.idToken();
      if (token == null) throw const ArcaApiError('login_required');
      final j = await api.post(path, {...body, 'me': await _partyMe()}, token: token);
      _partyError = null;
      final view = j.containsKey('party') || j.containsKey('restricted')
          ? j
          : (j['state'] as Map?)?.cast<String, dynamic>();
      if (view != null) await _setPartyView(PartyView.fromJson(view));
      return j;
    } on ArcaApiError catch (e) {
      _partyError = e.code;
      return null;
    } catch (e) {
      _partyError = 'offline';
      return null;
    } finally {
      _partyBusy = false;
      _notify();
    }
  }

  Future<void> _setPartyView(PartyView v) async {
    _partyView = v;
    if (v.cheers.isNotEmpty) _partyNotice = PartyRules.cheerFrom(v.cheers.join(', '));
    if (_partyLocal.joined != v.inParty) {
      await _savePartyLocal(_partyLocal.copyWith(joined: v.inParty));
    }
  }

  /// 응원 받은 소식 (한 번)
  String? takePartyNotice() {
    final n = _partyNotice;
    _partyNotice = null;
    return n;
  }

  /// 파티 화면을 새로 (오늘 걸음도 함께 올림)
  Future<void> refreshParty() async {
    if (!partyOpen || !partyReady) return;
    await _partyCall('/party/state');
  }

  Future<bool> createParty(String name) async =>
      await _partyCall('/party/create', {'name': name}) != null;

  Future<bool> joinParty(String code) async =>
      await _partyCall('/party/join', {'code': code.trim().toUpperCase()}) != null;

  Future<bool> leaveParty() async {
    final ok = await _partyCall('/party/leave') != null;
    if (ok) await _setPartyView(const PartyView());
    return ok;
  }

  Future<bool> kickMember(String uid) async =>
      await _partyCall('/party/kick', {'target': uid}) != null;

  Future<bool> styleParty({String? name, int? emblem, int? color}) async =>
      await _partyCall('/party/style', {
        if (name != null) 'name': name,
        if (emblem != null) 'emblem': emblem,
        if (color != null) 'color': color,
      }) !=
      null;

  Future<bool> cheerMember(String uid) async =>
      await _partyCall('/party/cheer', {'target': uid}) != null;

  // ───────────── 파티 보스 (각자 자기 화면에서 정해진 턴, 준 피해가 합쳐짐)

  /// 한 판을 시작한다 (도전권이 있을 때). 보스 체력은 한 판 몫
  Battle? startPartyBoss() {
    final b = _partyView?.boss;
    if (b == null || b.defeated || b.tickets <= 0 || !(_partyView?.inParty ?? false)) return null;
    final boss = PartyRules.bossOf(b.id) ?? MonsterId.partyGolem;
    final lv = player.level.level;
    final f = BattleRules.fieldFoe(level: lv, monster: boss);
    final foe = Foe(
      monster: boss,
      maxHp: math.max(1, f.maxHp * 8),
      attack: math.max(1, (f.attack * 1.4).round()),
      defense: f.defense,
      speed: f.speed,
    );
    final battle = _trainingBattle([foe], potions: true);
    battle.tickLimit = PartyRules.fightTicks;
    return battle;
  }

  /// 한 판을 마침: 준 피해(서버 단위로)를 보탠다. 쓴 물약은 쓴 것으로
  Future<PartyBossResult> finishPartyBoss(Battle b) async {
    await _consumeBattlePotions(b);
    final lv = player.level.level;
    final frac = b.foe.maxHp <= 0 ? 0.0 : b.dealtToFoe / b.foe.maxHp;
    final bonus = 1 + gear.sets.partyBoss;
    final damage = (frac * PartyRules.fightHp(lv) * bonus).round();
    final before = _partyView?.boss?.defeated ?? false;
    final j = await _partyCall('/party/boss', {'damage': damage});
    await gainMastery(Mastery.combat, TrainingRules.dailyMastery);
    if (j == null) return PartyBossResult(damage: 0, error: _partyError);
    return PartyBossResult(
        damage: damage, defeatedNow: !before && (_partyView?.boss?.defeated ?? false));
  }

  // ───────────── 보상

  /// 받기: 함께 걷기 단계([tier] 0~2) · 보스(쓰러뜨림) · 지난주 보스(못 쓰러뜨림)
  Future<List<String>?> claimParty(String kind, {int? tier}) async {
    final j = await _partyCall('/party/claim', {'kind': kind, if (tier != null) 'tier': tier});
    final r = (j?['reward'] as Map?)?.cast<String, dynamic>();
    if (r == null) return null;
    return _partyReward(r);
  }

  /// 서버가 준 보상 → 가방 · 지갑 (받은 것 글 목록)
  Future<List<String>> _partyReward(Map<String, dynamic> r) async {
    int n(String k) => (r[k] as num?)?.toInt() ?? 0;
    final gifts = <String, int>{};
    void add(String k, int v) {
      if (v > 0) gifts[k] = (gifts[k] ?? 0) + v;
    }

    add(Wallet.gold, n('gold'));
    add(Wallet.manaStone, n('manaStone'));
    final got = <String>[];
    final tickets = n('footTicket');
    add('recruit', n('recruit'));
    for (var i = 0; i < n('matBundle'); i++) {
      _bundle(add);
    }
    final boss = PartyRules.bossOf('${r['boss'] ?? ''}');
    if (boss != null) add(PartyRules.bossMat(boss).name, n('bossMat'));
    var recruit = 0;
    int? emblem;
    if (n('partyChest') > 0) {
      // 파티 상자: 금화 · 마석 · 재료 + 가끔 모집권 · 드문 깃발 문양
      add(Wallet.gold, 300 + _random.nextInt(201));
      add(Wallet.manaStone, 8);
      _bundle(add);
      if (_random.nextDouble() < 0.15) recruit++;
      if (_random.nextDouble() < 0.10) emblem = _newEmblem();
    }
    switch (r['chest']) {
      case 'gold':
        add(Wallet.gold, 500);
        add(Wallet.manaStone, 15);
        if (boss != null) add(PartyRules.bossMat(boss).name, 2);
        if (_random.nextDouble() < 0.2) recruit++;
      case 'silver':
        add(Wallet.gold, 300);
        add(Wallet.manaStone, 10);
        if (boss != null) add(PartyRules.bossMat(boss).name, 1);
      case 'bronze':
        add(Wallet.gold, 150);
        add(Wallet.manaStone, 5);
    }
    final chest = switch (r['chest']) {
      'gold' => '금빛 상자를 열었어요',
      'silver' => '은빛 상자를 열었어요',
      'bronze' => '동빛 상자를 열었어요',
      _ => n('partyChest') > 0 ? '파티 상자를 열었어요' : null,
    };
    if (chest != null) got.add(chest);
    if (gifts.isNotEmpty) got.addAll(await _applyGifts(gifts, over: BagOver.mail, title: '파티 보상'));
    var local = _partyLocal;
    if (tickets > 0) {
      local = local.copyWith(tickets: local.tickets + tickets);
      got.add('발자국 표 $tickets');
    }
    if (emblem != null) {
      local = local.copyWith(emblems: [...local.emblems, emblem]);
      got.add('깃발 문양 「${PartyRules.emblemNames[emblem]}」');
    }
    await _savePartyLocal(local);
    if (recruit > 0) {
      _act3 = _act3.copyWith(tickets: _act3.tickets + recruit);
      await _saveAct3();
      got.add('모집권 $recruit');
    }
    _notify();
    return got;
  }

  void _bundle(void Function(String, int) add) {
    final mats = [...PartyRules.bundleMats]..shuffle(_random);
    for (final m in mats.take(3)) {
      add(m.name, 2);
    }
  }

  /// 아직 없는 깃발 문양 하나 (다 있으면 null)
  int? _newEmblem() {
    final left = [
      for (var i = PartyRules.freeEmblems; i < PartyRules.emblems.length; i++)
        if (!_partyLocal.emblems.contains(i)) i,
    ];
    return left.isEmpty ? null : left[_random.nextInt(left.length)];
  }

  // ───────────── 꾸미기 · 상점 (발자국 표)

  bool hasEmblem(int i) => i < PartyRules.freeEmblems || _partyLocal.emblems.contains(i);
  bool hasColor(int i) => i < PartyRules.freeColors || _partyLocal.colors.contains(i);

  int partyBought(String id) =>
      _partyLocal.shopWeek == _partyWeek ? (_partyLocal.shopBought[id] ?? 0) : 0;

  /// 상점에서 산다. 못 사면 이유(글), 사면 null
  Future<String?> buyPartyItem(PartyShopItem item) => _serial(() async {
        if (_partyLocal.tickets < item.price) return '발자국 표가 모자라요';
        if (item.weekLimit > 0 && partyBought(item.id) >= item.weekLimit) {
          return '이번 주에는 다 샀어요 · 월요일에 다시';
        }
        final week = _partyWeek;
        final bought = _partyLocal.shopWeek == week ? {..._partyLocal.shopBought} : <String, int>{};
        bought[item.id] = (bought[item.id] ?? 0) + 1;
        await _savePartyLocal(_partyLocal.copyWith(
            tickets: _partyLocal.tickets - item.price, shopWeek: week, shopBought: bought));
        await _partyReward(item.gifts);
        return null;
      });

  Future<String?> buyEmblem(int i) => _serial(() async {
        if (hasEmblem(i)) return null;
        if (_partyLocal.tickets < PartyRules.emblemPrice) return '발자국 표가 모자라요';
        await _savePartyLocal(_partyLocal.copyWith(
            tickets: _partyLocal.tickets - PartyRules.emblemPrice,
            emblems: [..._partyLocal.emblems, i]));
        return null;
      });

  Future<String?> buyColor(int i) => _serial(() async {
        if (hasColor(i)) return null;
        if (_partyLocal.tickets < PartyRules.colorPrice) return '발자국 표가 모자라요';
        await _savePartyLocal(_partyLocal.copyWith(
            tickets: _partyLocal.tickets - PartyRules.colorPrice,
            colors: [..._partyLocal.colors, i]));
        return null;
      });

  // ───────────── 함께 있어요 (서버가 100m 칸만 비교, 지도에는 표시하지 않음)

  /// 위치가 바뀔 때 몇 분에 한 번 지금 칸을 서버에 알리고, 파티원이 가까이 있는지 받는다
  Future<void> partyNearPing() async {
    final fix = _lastFix;
    final api = arcaApi, a = cloudAuth;
    if (fix == null || api == null || a == null || !_cloud.signedIn) return;
    if (!partyOpen || !_partyLocal.joined) return;
    final now = _clock();
    final last = _partyPingAt;
    if (last != null && now.difference(last) < PartyRules.nearPing) return;
    _partyPingAt = now;
    try {
      final token = await a.idToken();
      if (token == null) return;
      final (r, c) = PartyRules.cellOf(fix.point.lat, fix.point.lng);
      final j = await api.post('/party/near', {'r': r, 'c': c}, token: token);
      final near = j['near'] == true;
      final was = partyNear;
      await _savePartyLocal(near
          ? _partyLocal.copyWith(nearUntil: now.add(PartyRules.nearFor))
          : _partyLocal.copyWith(clearNear: true));
      if (near && !was) _partyNotice = PartyRules.nearOn;
      _notify();
    } catch (_) {
      // 인터넷이 없으면 다음에
    }
  }

  /// 함께 잡은 몬스터 하나 (사냥 보상 쪽에서)
  Future<void> _countTogether() async {
    await _savePartyLocal(_partyLocal.copyWith(together: _partyLocal.together + 1));
  }

  Future<void> _savePartyLocal(PartyLocal s) async {
    _partyLocal = s;
    await store.saveJson(AppController._partyKey, s.toJson());
  }
}
