part of '../app_controller.dart';

/// 묶음 47 #240: 가방이 가득 찼을 때 남는 것을 어디로 보낼지.
/// [hold] 「가방이 가득 찼어요」 창(버리기 · 바로 판매하기)으로, 팔 수 없는 것만 우편함에.
/// [mail] 의뢰·이야기 보상 — 창 없이 모두 우편함에 맡긴다.
enum BagOver { hold, mail }

/// 「가방이 가득 찼어요」 창의 한 줄
class BagHoldEntry {
  const BagHoldEntry(
      {required this.key,
      required this.count,
      required this.name,
      required this.price,
      this.material,
      this.item});

  /// 우편 선물과 같은 키 (재료 이름 · 'item:<잡화상 물건>')
  final String key;
  final int count;
  final String name;

  /// 하나를 바로 팔 때 금화 (잡화상에 파는 값)
  final int price;
  final MaterialId? material;
  final ShopItem? item;
}

extension BagHoldOps on AppController {
  /// 가방이 가득해 받지 못하고 기다리는 것
  List<BagHoldEntry> get bagHoldList => [
        for (final e in _bag.hold.entries)
          if (_holdEntry(e.key, e.value) case final x?) x,
      ];

  bool get hasBagHold => _bag.hold.isNotEmpty;

  /// 새로 기다리게 된 것이 있어 창을 띄울 차례인지
  bool get bagHoldNew => _bagHoldNew && _bag.hold.isNotEmpty;

  /// 창을 띄웠다 (다음에 새로 생길 때까지 다시 띄우지 않는다)
  void seenBagHold() => _bagHoldNew = false;

  /// 가방이 가득해 우편함에 맡긴 것 수 (띠를 띄우고 0으로)
  int takeBagMailed() {
    final n = _bagMailed;
    _bagMailed = 0;
    return n;
  }

  int get pendingBagMailed => _bagMailed;

  BagHoldEntry? _holdEntry(String key, int n) {
    if (n <= 0) return null;
    if (key.startsWith('item:')) {
      final it = _shopItemNamed(key.substring(5));
      if (it == null) return null;
      return BagHoldEntry(
          key: key,
          count: n,
          name: itemName(it),
          price: BagRules.itemPrice(it),
          item: it);
    }
    final m = Materials.byName(key);
    if (m == null) return null;
    return BagHoldEntry(
        key: key,
        count: n,
        name: Materials.info(m).name,
        price: BagRules.materialPrice(m),
        material: m);
  }

  ShopItem? _shopItemNamed(String name) {
    for (final it in ShopItem.values) {
      if (it.name == name) return it;
    }
    return null;
  }

  /// 가방 칸을 쓰는 선물인지 (재료 · 잡화상 물건 · 알 · 공방 물약)
  bool _bagKey(String k) =>
      k == 'egg' ||
      k.startsWith('item:') ||
      k.startsWith('alc:') ||
      Materials.byName(k) != null;

  /// 「가방이 가득 찼어요」 창에서 고를 수 있는 것 (팔 수 있는 것). 알·공방 물약은 우편함으로
  bool _holdable(String k) => k.startsWith('item:') || Materials.byName(k) != null;

  int _haveOf(String k) {
    if (k == 'egg') return 0;
    if (k.startsWith('item:')) {
      final it = _shopItemNamed(k.substring(5));
      return it == null ? 0 : bagCount(it);
    }
    if (k.startsWith('alc:')) return _alc.potions[k.substring(4)] ?? 0;
    final m = Materials.byName(k);
    return m == null ? 0 : player.materialCount(m);
  }

  /// 지금 가방에 들어가는 만큼([fit])과 남는 것([rest])으로 나눈다.
  /// 이미 있는 칸에 쌓이는 것은 칸을 더 쓰지 않는다. 알은 하나에 한 칸.
  ({Map<String, int> fit, Map<String, int> rest}) _splitBag(
      Map<String, int> incoming) {
    final fit = <String, int>{};
    final rest = <String, int>{};
    var free = bagFree;
    for (final e in incoming.entries) {
      if (e.value <= 0) continue;
      final egg = e.key == 'egg';
      final have = _haveOf(e.key);
      final room = egg || have == 0
          ? 0
          : BagRules.stacks(have) * BagRules.stackMax - have;
      var take = math.min(room, e.value);
      var left = e.value - take;
      while (left > 0 && free > 0) {
        final n = egg ? 1 : math.min(BagRules.stackMax, left);
        take += n;
        left -= n;
        free--;
      }
      if (take > 0) fit[e.key] = take;
      if (left > 0) rest[e.key] = left;
    }
    return (fit: fit, rest: rest);
  }

  /// 가방에 넣는다 (칸은 이미 확인했다)
  Future<void> _giveBag(Map<String, int> g) async {
    if (g.isEmpty) return;
    final mats = <MaterialId, int>{};
    final counters = <String, int>{};
    var eggs = 0;
    var a = _alc;
    var alc = false;
    g.forEach((k, v) {
      if (v <= 0) return;
      if (k == 'egg') {
        eggs += v;
      } else if (k.startsWith('item:')) {
        if (_shopItemNamed(k.substring(5)) case final it?) {
          final gk = TownRules.giftKey(it);
          counters[gk] = (counters[gk] ?? 0) + v;
        }
      } else if (k.startsWith('alc:')) {
        a = a.add(k.substring(4), v);
        alc = true;
      } else if (Materials.byName(k) case final m?) {
        mats[m] = (mats[m] ?? 0) + v;
      }
    });
    if (mats.isNotEmpty || counters.isNotEmpty) {
      final today = await _todayRecord();
      await _save(today.copyWith(
        gains: mats.isEmpty
            ? null
            : DailyRecord.addCounts(
                today.gains, HuntReward.ledger(materials: mats)),
        counters: counters.isEmpty
            ? null
            : DailyRecord.addCounts(today.counters, counters),
      ));
    }
    if (alc) await _saveAlc(a);
    if (eggs > 0) {
      final p = _pets;
      await _savePets(p.copyWith(
        eggs: [
          ...p.eggs,
          for (var n = 0; n < eggs; n++)
            PetEgg(
                id: 'egg${p.nextId + n}',
                source: 'mail',
                element: mainElement?.name),
        ],
        nextId: p.nextId + eggs,
        firstEggFound: true,
      ));
      _newEgg = true;
    }
  }

  /// 들어가는 만큼 넣고, 남는 것은 [over] 대로 보낸다. 넣은 것을 돌려준다
  Future<Map<String, int>> _admitBag(Map<String, int> g,
      {BagOver over = BagOver.hold, String? title}) async {
    final s = _splitBag(g);
    await _giveBag(s.fit);
    await _bagOverflowTo(s.rest, over: over, title: title);
    return s.fit;
  }

  /// 가방에 들어가지 못한 것: 창에서 고르게 맡겨 두거나 우편함으로
  Future<void> _bagOverflowTo(Map<String, int> rest,
      {required BagOver over,
      String? title,
      List<EquipItem> equips = const []}) async {
    if (rest.isEmpty && equips.isEmpty) return;
    final toHold = <String, int>{};
    final toMail = <String, int>{};
    rest.forEach((k, v) {
      if (v <= 0) return;
      if (over == BagOver.hold && _holdable(k)) {
        toHold[k] = v;
      } else {
        toMail[k] = v;
      }
    });
    if (toHold.isNotEmpty) {
      final h = {..._bag.hold};
      toHold.forEach((k, v) => h[k] = (h[k] ?? 0) + v);
      _bag = _bag.copyWith(hold: h);
      await store.saveJson(AppController._bagKey, _bag.toJson());
      _bagHoldNew = true;
    }
    if (toMail.isNotEmpty || equips.isNotEmpty) {
      await _mailBagRest(toMail, equips: equips, title: title);
    }
    _notify();
  }

  /// 가방이 가득해 우편함에 맡긴다 (사라지지 않음, 자리가 나면 받기)
  Future<void> _mailBagRest(Map<String, int> gifts,
      {List<EquipItem> equips = const [], String? title}) async {
    final now = _clock();
    await _sendMail(MailItem(
      id: 'bag_${now.microsecondsSinceEpoch}_${_mail.sent.length}',
      kind: MailKind.letter,
      from: MailRules.operator,
      title: title ?? '가방이 가득해 맡아 둔 것',
      body: '가방이 가득 차서 우편함에 맡아 두었어요. '
          '가방에 자리를 만든 뒤 받아 가세요.',
      gifts: gifts,
      equips: equips,
      sentAt: now,
    ));
    _bagMailed += gifts.length + equips.length;
  }

  /// 장비 보상 (마을 사람 특별 보상 · 유품 · 왕관): 칸이 없으면 우편함에
  Future<bool> _giveEquipOrMail(EquipItem item, {String? title}) async {
    if (bagFree > 0) {
      final a = _armory;
      await _saveArmory(a.copyWith(items: [...a.items, item]));
      return true;
    }
    await _mailBagRest(const {}, equips: [item], title: title);
    _notify();
    return false;
  }

  /// 시험용: 선물을 가방에 넣어 본다 (남는 것은 창 또는 우편함으로)
  @visibleForTesting
  Future<Map<String, int>> admitBagForTest(Map<String, int> g,
          {bool toMail = false}) =>
      _admitBag(g, over: toMail ? BagOver.mail : BagOver.hold);

  // ───────────── 「가방이 가득 찼어요」 창에서

  /// 하나 줄을 바로 판다 (잡화상에 파는 값). 받은 금화
  Future<int> sellHold(String key) => _serial(() async {
        final e = _holdEntry(key, _bag.hold[key] ?? 0);
        if (e == null) return 0;
        final gold = e.price * e.count;
        await _dropHold([key], gold);
        return gold;
      });

  /// 하나 줄을 버린다
  Future<void> discardHold(String key) => _serial(() async {
        if (!_bag.hold.containsKey(key)) return;
        await _dropHold([key], 0);
      });

  /// 모두 판다. 받은 금화
  Future<int> sellAllHold() => _serial(() async {
        var gold = 0;
        for (final e in bagHoldList) {
          gold += e.price * e.count;
        }
        await _dropHold(_bag.hold.keys.toList(), gold);
        return gold;
      });

  /// 모두 버린다
  Future<void> discardAllHold() => _serial(() async {
        await _dropHold(_bag.hold.keys.toList(), 0);
      });

  Future<void> _dropHold(List<String> keys, int gold) async {
    if (gold > 0) {
      final today = await _todayRecord();
      await _save(today.copyWith(
          gains: DailyRecord.addCounts(today.gains, {Wallet.gold: gold})));
    }
    final h = {..._bag.hold};
    for (final k in keys) {
      h.remove(k);
    }
    _bag = _bag.copyWith(hold: h);
    await store.saveJson(AppController._bagKey, _bag.toJson());
    _notify();
  }

  /// 가방을 정리한 뒤 다시 받는다. 아직 남은 줄 수
  Future<int> retryHold() => _serial(() async {
        if (_bag.hold.isEmpty) return 0;
        final s = _splitBag(_bag.hold);
        await _giveBag(s.fit);
        _bag = _bag.copyWith(hold: s.rest);
        await store.saveJson(AppController._bagKey, _bag.toJson());
        _notify();
        return s.rest.length;
      });
}
