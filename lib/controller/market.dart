part of '../app_controller.dart';

/// 거래소의 물건 하나 (서버가 준 모양)
class MarketListing {
  const MarketListing({
    required this.id,
    required this.kind,
    required this.key,
    required this.name,
    required this.qty,
    required this.mode,
    this.mine = false,
    this.sellerName = '',
    this.equip,
    this.price,
    this.start,
    this.buyNow,
    this.bid,
    this.bids = 0,
    this.myBid = false,
    this.next,
    this.status = 'open',
    this.endsAt,
  });

  final String id;
  final MarketKind kind;
  final String key;
  final String name;
  final int qty;

  /// 'fixed' 값을 정해 올림 · 'auction' 경매
  final String mode;
  final bool mine;
  final String sellerName;
  final EquipItem? equip;
  final int? price;
  final int? start;
  final int? buyNow;
  final int? bid;
  final int bids;
  final bool myBid;

  /// 경매에서 다음에 부를 수 있는 가장 낮은 값
  final int? next;

  /// 'open' · 'sold' · 'expired' · 'cancelled'
  final String status;
  final DateTime? endsAt;

  bool get auction => mode == 'auction';

  /// 지금 값 (값을 정한 것은 그 값, 경매는 지금 높은 값 또는 시작 값)
  int get now => auction ? (bid ?? start ?? 0) : (price ?? 0);

  static MarketListing? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final k = MarketKind.values.where((x) => x.name == raw['kind']).firstOrNull;
    if (k == null || raw['id'] is! String) return null;
    int? n(String f) => (raw[f] as num?)?.toInt();
    final e = raw['equip'];
    final end = n('endsAt');
    return MarketListing(
      id: raw['id'] as String,
      kind: k,
      key: '${raw['key'] ?? ''}',
      name: '${raw['name'] ?? ''}',
      qty: n('qty') ?? 1,
      mode: '${raw['mode'] ?? 'fixed'}',
      mine: raw['mine'] == true,
      sellerName: '${raw['sellerName'] ?? ''}',
      equip: e is Map ? EquipItem.fromJson(Map<String, dynamic>.from(e)) : null,
      price: n('price'),
      start: n('start'),
      buyNow: n('buyNow'),
      bid: n('bid'),
      bids: n('bids') ?? 0,
      myBid: raw['myBid'] == true,
      next: n('next'),
      status: '${raw['status'] ?? 'open'}',
      endsAt: end == null ? null : DateTime.fromMillisecondsSinceEpoch(end),
    );
  }
}

/// 거래소에 올릴 수 있는 내 물건 하나
class MarketOwn {
  const MarketOwn(this.kind, this.key, this.name, this.have, {this.equip});

  final MarketKind kind;

  /// 재료 · 물건 이름, 장비 uid, 알 id
  final String key;
  final String name;
  final int have;
  final EquipItem? equip;

  int get base => MarketRules.base(kind, key, equip: equip);
}

/// 최근 시세
class MarketPrice {
  const MarketPrice({this.count = 0, this.min = 0, this.max = 0, this.avg = 0, this.last = 0});

  final int count, min, max, avg, last;
}

/// 거래소 (묶음 58 #229): 바르칸 거래소의 「장부를 정리하는 중일세…」를 실제 거래로.
/// 로그인한 사람만. 거래 바로 전에 기록을 백업하고(서버가 그 백업으로 다시 셈), 되면 휴대폰에서도 빼고 더함.
/// 산 물건 · 판 금화 · 돌려받는 물건은 바르칸 이름으로 우편.
extension MarketOps on AppController {
  /// 묶음 67 #271: 거래소 ★ (★2 칸 7 · ★3 칸 9 + 값을 정해 올린 물건 72시간)
  int get marketStar => buildingsOpen ? buildingStar(Building.market) : 1;
  int get marketSlots => BuildingRules.marketSlots(marketStar);
  int get marketFixedHours => BuildingRules.marketFixedHours(marketStar);

  bool get marketBusy => _marketBusy;
  String? get marketError => _marketError;

  /// 처음 열 때 바르칸 한마디 (한 번)
  bool get marketIntroPending => !_village.contains('marketIntro');

  Future<void> markMarketIntro() => _markVillage(['marketIntro']);

  /// 바르칸과 단짝이면 수수료 조금 덜
  bool get marketBest => favorStage(Npc.barkan) == FavorStage.best;

  /// 거래소에 올릴 수 있는 내 물건
  List<MarketOwn> marketOwn(MarketKind k) => switch (k) {
        MarketKind.mat => [
            for (final e in player.materials.entries)
              if (e.value > 0 && MarketRules.matTradable(e.key)) MarketOwn(k, e.key.name, Materials.info(e.key).name, e.value),
          ],
        MarketKind.item => [
            for (final i in ShopItem.values)
              if (MarketRules.itemTradable(i) && bagCount(i) > 0)
                MarketOwn(k, i.name, TownRules.info(i).name, bagCount(i)),
          ],
        MarketKind.equip => [
            for (final e in _armory.items)
              if (!_armory.isWorn(e) && MarketRules.equipTradable(e))
                MarketOwn(k, e.uid, EquipmentRules.info(e.base).name, 1, equip: e),
          ],
        MarketKind.egg => [
            for (final e in _pets.eggs)
              if (e.incubatedAt == null) MarketOwn(k, e.id, e.grade.label, 1),
          ],
        // 묶음 59: 공방 물약
        MarketKind.alc => [
            for (final p in PotionId.values)
              if (MarketRules.alcTradable(p) && _alc.count(p.name) > 0)
                MarketOwn(k, p.name, AlchemyRules.info(p).name, _alc.count(p.name)),
          ],
      };

  /// 서버에 묻는다. 거래(돈 · 물건이 움직임)면 먼저 백업. 실패하면 [marketError] 를 남기고 null
  Future<Map<String, dynamic>?> _marketCall(String path, Map<String, dynamic> body,
      {bool trade = false}) async {
    final api = arcaApi, a = cloudAuth;
    if (api == null || a == null || !_cloud.signedIn) {
      _marketError = 'login_required';
      _notify();
      return null;
    }
    _marketBusy = true;
    _notify();
    try {
      if (trade) {
        final b = await _upload(force: true);
        if (b != CloudBackup.ok && b != CloudBackup.unchanged) throw const ArcaApiError('need_backup');
      }
      final token = await a.idToken();
      if (token == null) throw const ArcaApiError('login_required');
      final j = await api.post(path, body, token: token);
      _marketError = null;
      if (j['wallet'] is num) _walletGold = (j['wallet'] as num).toInt();
      return j;
    } on ArcaApiError catch (e) {
      _marketError = e.code;
      return null;
    } catch (_) {
      _marketError = 'offline';
      return null;
    } finally {
      _marketBusy = false;
      _notify();
    }
  }

  /// 사기 목록 (묶음 칩 · 이름 찾기 · 경매 따로)
  Future<List<MarketListing>?> browseMarket({MarketKind? kind, String query = '', bool auction = false}) async {
    final j = await _marketCall('/market/browse', {
      if (kind != null) 'cat': kind.name,
      if (query.trim().isNotEmpty) 'q': query.trim(),
      'auction': auction,
    });
    if (j == null) return null;
    return [
      for (final x in (j['items'] as List?) ?? const [])
        if (MarketListing.fromJson(x) case final l?) l,
    ];
  }

  /// 내가 올린 것 · 입찰한 것
  Future<({List<MarketListing> selling, List<MarketListing> bidding})?> myMarket() async {
    final j = await _marketCall('/market/mine', const {});
    if (j == null) return null;
    List<MarketListing> rows(String k) => [
          for (final x in (j[k] as List?) ?? const [])
            if (MarketListing.fromJson(x) case final l?) l,
        ];
    return (selling: rows('selling'), bidding: rows('bidding'));
  }

  Future<MarketPrice?> marketPrice(MarketKind kind, String key) async {
    final j = await _marketCall('/market/price', {'kind': kind.name, 'key': key});
    if (j == null) return null;
    int n(String f) => (j[f] as num?)?.toInt() ?? 0;
    return MarketPrice(count: n('count'), min: n('min'), max: n('max'), avg: n('avg'), last: n('last'));
  }

  int marketListFee(int price) => MarketRules.listFee(price, seal: hasBarkanSeal);

  /// 올리기: 값을 정해(48시간) 또는 경매(24시간, 시작 값 · 바로 사기 값). 되면 휴대폰에서 물건 · 올리는 금화를 뺌
  Future<bool> listOnMarket(MarketOwn own,
      {required int qty, required bool auction, required int price, int? buyNow}) async {
    final fee = marketListFee(price);
    if (_walletGold != null && _walletGold! < fee) {
      _marketError = 'no_wallet_gold';
      _notify();
      return false;
    }
    final j = await _marketCall(
        '/market/list',
        {
          'kind': own.kind.name,
          'key': own.key,
          'qty': qty,
          'mode': auction ? 'auction' : 'fixed',
          if (auction) 'start': price else 'price': price,
          if (auction && buyNow != null) 'buyNow': buyNow,
          'seal': hasBarkanSeal,
          'best': marketBest,
          'me': {'name': profile.name},
        },
        trade: true);
    if (j == null) return false;
    // 묶음 61: 올리는 금화는 거래 지갑에서 (휴대폰 금화는 그대로)
    await _serial(() async {
      final today = await _todayRecord();
      switch (own.kind) {
        case MarketKind.mat:
          await _save(today.copyWith(spends: DailyRecord.addCounts(today.spends, {own.key: qty})));
        case MarketKind.item:
          final i = ShopItem.values.byName(own.key);
          await _save(today.copyWith(
            counters: DailyRecord.addCounts(today.counters, {TownRules.dropKey(i): qty}),
          ));
        case MarketKind.equip:
          await _saveArmory(_armory.copyWith(items: [
            for (final i in _armory.items)
              if (i.uid != own.key) i,
          ]));
        case MarketKind.alc:
          await _saveAlc(_alc.add(own.key, -qty));
        case MarketKind.egg:
          await _savePets(_pets.copyWith(eggs: [
            for (final e in _pets.eggs)
              if (e.id != own.key) e,
          ]));
      }
      await _count('marketList');
      await _npcUse(Npc.barkan);
    });
    _notify();
    return true;
  }

  Future<void> _payMarket(int gold) => _serial(() async {
        if (gold <= 0) return;
        await _npcUse(Npc.barkan);
      });

  // ───────────── 묶음 61 #250: 거래 지갑 (바르칸이 맡아 둔 금화, 거래소에서만)

  /// 지갑 금화 (아직 모르면 null)
  int? get marketWallet => _walletGold;

  /// 처음 지갑을 볼 때 바르칸 한마디 (한 번)
  bool get walletIntroPending => !_village.contains('walletIntro');
  Future<void> markWalletIntro() => _markVillage(['walletIntro']);

  Future<int?> refreshWallet() async {
    final j = await _marketCall('/market/wallet', const {});
    return j == null ? null : _walletGold;
  }

  /// 맡기기: 서버가 백업으로 한 번 확인한 뒤 휴대폰 금화에서 뺌
  Future<bool> depositWallet(int amount) async {
    if (amount <= 0 || player.gold < amount) {
      _marketError = 'no_gold';
      _notify();
      return false;
    }
    final j = await _marketCall('/market/deposit', {'amount': amount}, trade: true);
    if (j == null) return false;
    final a = (j['amount'] as num?)?.toInt() ?? amount;
    await _serial(() async {
      final today = await _todayRecord();
      await _save(today.copyWith(spends: DailyRecord.addCounts(today.spends, {Wallet.gold: a})));
      await _npcUse(Npc.barkan);
    });
    // 뺀 기록을 바로 서버에도 (다음 맡기기 확인이 맞도록)
    unawaited(_upload(force: true).then((_) {}, onError: (_) {}));
    _notify();
    return true;
  }

  /// 꺼내기: 지갑 → 바르칸 우편 (금화)
  Future<bool> withdrawWallet(int amount) async {
    if (amount <= 0 || (_walletGold != null && amount > _walletGold!)) {
      _marketError = 'no_wallet_gold';
      _notify();
      return false;
    }
    final j = await _marketCall('/market/withdraw', {'amount': amount});
    if (j == null) return false;
    await checkInquiryInbox();
    _notify();
    return true;
  }

  /// 값을 정한 물건 사기 (물건은 바르칸 우편으로 바로) — 금화는 거래 지갑에서
  Future<bool> buyOnMarket(MarketListing l) async {
    if (_walletGold != null && _walletGold! < (l.price ?? 0)) {
      _marketError = 'no_wallet_gold';
      _notify();
      return false;
    }
    final j = await _marketCall('/market/buy', {'id': l.id}, trade: true);
    if (j == null) return false;
    await _payMarket((j['charged'] as num?)?.toInt() ?? l.price ?? 0);
    await checkInquiryInbox();
    _notify();
    return true;
  }

  /// 경매 입찰 (그 금화는 묶어 둠 · 지면 우편으로 돌려받음). 바로 사기 값 이상이면 바로 삼
  Future<({bool ok, bool sold})> bidOnMarket(MarketListing l, int amount) async {
    if (_walletGold != null && _walletGold! < amount) {
      _marketError = 'no_wallet_gold';
      _notify();
      return (ok: false, sold: false);
    }
    final j = await _marketCall('/market/bid', {'id': l.id, 'amount': amount}, trade: true);
    if (j == null) return (ok: false, sold: false);
    await _payMarket((j['charged'] as num?)?.toInt() ?? amount);
    final sold = j['sold'] == true;
    if (sold) await checkInquiryInbox();
    _notify();
    return (ok: true, sold: sold);
  }

  /// 내린다 (경매는 입찰이 없을 때만). 물건은 우편으로 돌아옴
  Future<bool> cancelMarket(MarketListing l) async {
    final j = await _marketCall('/market/cancel', {'id': l.id});
    if (j == null) return false;
    await checkInquiryInbox();
    return true;
  }

  /// 오류 → 한 줄
  static String marketErrorText(String? code) => switch (code) {
        'login_required' => '거래소는 로그인한 뒤에 쓸 수 있어요',
        'need_backup' => '기록을 서버에 맞추지 못했어요. 잠시 뒤 다시 해 주세요',
        'no_gold' => '금화가 모자라요',
        'no_wallet_gold' => '거래 지갑 금화가 모자라요. 바르칸에게 맡겨 채워 주세요',
        'bad_amount' => '그 금화로는 할 수 없어요',
        'app_check' => '앱을 최신으로 바꾼 뒤 다시 해 주세요',
        'not_owned' => '그 물건이 기록에 없어요. 잠시 뒤 다시 해 주세요',
        'not_tradable' => '거래소에 올릴 수 없는 물건이에요',
        'bad_price' => '그 값으로는 올릴 수 없어요',
        'slots_full' => '올리는 칸이 다 찼어요. 팔리거나 거둬들이면 다시 올릴 수 있어요',
        'same_device' => '같은 휴대폰으로 로그인한 계정끼리는 거래할 수 없어요',
        'restricted' => '지금은 거래소를 쓸 수 없어요',
        'own_item' => '내가 올린 물건이에요',
        'gone' => '이미 팔렸거나 끝난 물건이에요',
        'outbid' => '다른 손님이 먼저 더 높게 불렀어요',
        'pair_limit' => '같은 손님과는 하루 거래 횟수를 넘었어요. 내일 다시 해 주세요',
        'cannot_cancel' => '입찰이 있는 경매는 내릴 수 없어요',
        'offline' => '인터넷이 연결되지 않았어요',
        _ => '잠시 뒤 다시 해 주세요',
      };

  // ───────────── 묶음 58: 심층 주간 순위

  /// 이번 주 심층 순위 (로그인했을 때)
  Future<DeepBoard?> deepBoard() async {
    final j = await _marketCall('/deep/board', const {});
    if (j == null) return null;
    final reg = Region.values.where((r) => r.name == j['region']).firstOrNull;
    _deepRegion = reg;
    return DeepBoard(
      region: reg,
      top: [
        for (final r in (j['top'] as List?) ?? const [])
          if (r is Map)
            (rank: (r['rank'] as num).toInt(), name: '${r['name']}', floor: (r['floor'] as num).toInt(), me: r['me'] == true),
      ],
      myRank: ((j['me'] as Map?)?['rank'] as num?)?.toInt(),
      myFloor: ((j['me'] as Map?)?['floor'] as num?)?.toInt(),
      total: (j['total'] as num?)?.toInt() ?? 0,
    );
  }

  /// 이번 주 심층 지역 (서버 기준, 서버에 못 물었으면 앱이 같은 규칙으로)
  Region get deepRegion => _deepRegion ?? RegionRules.deepRegionOf(_clock());

  /// 심층 층을 끝냈을 때 (그 주 지역이면 서버에 기록)
  Future<void> _submitDeep(RegionContent r, int floor) async {
    final api = arcaApi, a = cloudAuth;
    if (api == null || a == null || !_cloud.signedIn || r.region != deepRegion) return;
    try {
      final token = await a.idToken();
      if (token == null) return;
      await api.post('/deep/submit', {
        'region': r.prefix,
        'floor': floor,
        'me': {'name': profile.name},
      }, token: token);
    } catch (_) {}
  }
}

/// 심층 주간 순위
class DeepBoard {
  const DeepBoard({this.region, this.top = const [], this.myRank, this.myFloor, this.total = 0});

  final Region? region;
  final List<({int rank, String name, int floor, bool me})> top;
  final int? myRank, myFloor;
  final int total;
}
