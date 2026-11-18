// 거래소 (#229 · 묶음 58): 값을 정해 올리기(48시간) · 경매(24시간) · 금화만 · 한 사람 5칸.
// 앱은 거래 바로 전에 기록을 백업하고, 서버는 그 백업으로 금화 · 물건이 정말 있는지 다시 센다.
// 같은 백업으로 여러 번 쓰지 못하게 그 백업(gen)에서 이미 쓴 몫을 marketHold/{uid} 에 적어 둔다.
// 사고판 물건 · 금화는 바르칸 이름으로 우편(inbox)으로 보낸다. 거래 기록은 1년 뒤 TTL 로 지움.
const zlib = require('zlib');
const R = require('./rules');
const CAT = require('./market_catalog.json');

const HOUR = 3600000;
const LOG_KEEP_MS = 365 * 24 * HOUR;
/** 백업이 이만큼 안에 올라와 있어야 거래 (앱이 거래 바로 전에 올림) */
const FRESH_MS = 15 * 60000;
/** 같은 두 사람끼리 하루에 거래할 수 있는 횟수 (몰아주기 막기) */
const PAIR_PER_DAY = 3;
/** 경매가 끝나기 직전 입찰은 끝나는 시간을 조금 미룸 (막판 가로채기 막기) */
const SNIPE_MS = 3 * 60000;
/** 주간 의뢰 금화 (서버가 금화 위쪽 한도를 셀 때 한 주에 더해 줌) */
const WEEKLY_GOLD = 240;

class MarketError extends Error {
  constructor(code, status = 400) {
    super(code);
    this.code = code;
    this.status = status;
  }
}
const fail = (code, status) => {
  throw new MarketError(code, status);
};

const KINDS = ['mat', 'equip', 'item', 'egg', 'alc'];

function safeName(n) {
  const s = String(n || '').trim().slice(0, 12);
  return !s || R.bannedName(s) ? '각성자' : s;
}

/** 하나의 기준 값 (잡화상에 파는 값) */
function baseOf(kind, key, equip) {
  if (kind === 'mat') return Number(CAT.mats[key] || 0);
  if (kind === 'item') return Number(CAT.items[key] || 0);
  if (kind === 'egg') return CAT.eggBase;
  if (kind === 'alc') return Number((CAT.alcs || {})[key] || 0);
  if (kind === 'equip' && equip) {
    const g = Number(CAT.equipGradeBase[equip.grade] || 0);
    return Math.round(g * (1 + 0.1 * (Number(equip.enhance) || 0)));
  }
  return 0;
}

function bounds(base, qty) {
  return {
    min: Math.max(1, Math.ceil(base * qty * CAT.minMult)),
    max: Math.max(1, Math.floor(base * qty * CAT.maxMult)),
  };
}

function listFee(price, seal) {
  const f = Math.max(CAT.listMin, Math.round(price * CAT.listRate));
  return seal ? Math.max(1, Math.round(f * CAT.sealListMult)) : f;
}

function saleFee(price, best) {
  return Math.round(price * (best ? CAT.feeRateBest : CAT.feeRate));
}

function nextBid(l) {
  return l.bidder ? l.bid + Math.max(1, Math.ceil(l.bid * CAT.bidStep)) : l.start;
}

function nameOf(kind, key, equip) {
  if (kind === 'mat') return CAT.matNames[key] || key;
  if (kind === 'item') return CAT.itemNames[key] || key;
  if (kind === 'egg') return '알';
  if (kind === 'alc') return (CAT.alcNames || {})[key] || key;
  return CAT.equipNames[(equip && equip.base) || key] || key;
}

const ms = (t) => (t == null ? 0 : typeof t.toMillis === 'function' ? t.toMillis() : t instanceof Date ? t.getTime() : Number(t) || 0);

// ───────────── 백업으로 다시 세기

/** 백업 하나를 읽어 지금 가진 것을 셈 (금화는 위쪽 한도) */
function countSnapshot(snap) {
  const parse = (k, d) => {
    try {
      return snap[k] ? JSON.parse(snap[k]) : d;
    } catch (e) {
      return d;
    }
  };
  const hist = parse('history.v1', []);
  const armory = parse('json.armory', {});
  const pets = parse('json.pets', {});
  const alchemy = parse('json.alchemy', {});
  let gold = 0;
  const mats = {};
  const items = {};
  const weeks = new Set();
  for (const r of hist) {
    const g = r.gains || {};
    const s = r.spends || {};
    gold += (Number(g.gold) || 0) - (Number(s.gold) || 0);
    for (const [k, v] of Object.entries(g)) if (k in CAT.mats) mats[k] = (mats[k] || 0) + (Number(v) || 0);
    for (const [k, v] of Object.entries(s)) if (k in CAT.mats) mats[k] = (mats[k] || 0) - (Number(v) || 0);
    for (const n of r.goldPurchases || []) {
      if (CAT.shopMats[n]) mats[CAT.shopMats[n]] = (mats[CAT.shopMats[n]] || 0) + 1;
      if (n in CAT.items) items[n] = (items[n] || 0) + 1;
    }
    for (const n of r.shopPurchases || []) if (n in CAT.items) items[n] = (items[n] || 0) + 1;
    for (const n of r.itemsUsed || []) if (n in CAT.items) items[n] = (items[n] || 0) - 1;
    const c = r.counters || {};
    for (const n of Object.keys(CAT.items)) {
      items[n] = (items[n] || 0) + (Number(c['gift:' + n]) || 0) - (Number(c['drop:' + n]) || 0);
    }
    if (r.date) weeks.add(R.weekKey(Date.parse(r.date + 'T03:00:00Z')));
  }
  gold += weeks.size * WEEKLY_GOLD;
  const worn = new Set(Object.values(armory.equipped || {}));
  const equips = {};
  for (const it of armory.items || []) if (it && it.uid && !worn.has(it.uid)) equips[it.uid] = it;
  const eggs = new Set((pets.eggs || []).filter((e) => e && e.id && !e.incubatedAt).map((e) => e.id));
  const alcs = {};
  for (const [k, v] of Object.entries(alchemy.potions || {})) if (k in (CAT.alcs || {})) alcs[k] = Number(v) || 0;
  return { gold: Math.max(0, gold), mats, items, equips, eggs, alcs };
}

class MarketService {
  constructor(db, { now = () => Date.now() } = {}) {
    this.db = db;
    this.now = now;
  }

  async _restricted(uid) {
    const s = await this.db.doc(`status/${uid}`).get();
    return R.restricted(s.exists ? s.data() : null, this.now());
  }

  async _devices(uid) {
    const u = await this.db.doc(`users/${uid}`).get();
    const d = u.exists ? u.data() : {};
    return new Set([...(d.devices || []), ...(d.device ? [d.device] : [])]);
  }

  async _sameDevice(a, b) {
    const x = await this._devices(a);
    for (const d of await this._devices(b)) if (x.has(d)) return true;
    return false;
  }

  /** 가장 최근 백업과 그 백업에서 이미 쓴 몫 */
  async _wallet(uid) {
    const u = await this.db.doc(`users/${uid}`).get();
    if (!u.exists || !u.data().gen) fail('need_backup', 409);
    const meta = u.data();
    if (this.now() - ms(meta.updatedAt) > FRESH_MS) fail('need_backup', 409);
    const parts = await this.db.collection(`users/${uid}/parts`).get();
    const text = parts.docs
      .filter((p) => String(p.data().gen) === String(meta.gen))
      .sort((a, b) => Number(a.id.split('_')[1]) - Number(b.id.split('_')[1]))
      .map((p) => p.data().data || '')
      .join('');
    let snap;
    try {
      snap = JSON.parse(zlib.gunzipSync(Buffer.from(text, 'base64')).toString('utf8'));
    } catch (e) {
      fail('need_backup', 409);
    }
    const have = countSnapshot(snap);
    const h = await this.db.doc(`marketHold/${uid}`).get();
    const hold = h.exists && h.data().gen === meta.gen ? h.data() : { gen: meta.gen, gold: 0, mats: {}, items: {}, equips: [], eggs: [], alcs: {} };
    hold.alcs = hold.alcs || {};
    return { gen: meta.gen, have, hold };
  }

  _saveHold(uid, hold, t) {
    const ref = this.db.doc(`marketHold/${uid}`);
    return t ? t.set(ref, hold) : ref.set(hold);
  }

  async _mail(uid, msg) {
    await this.db.collection(`inbox/u_${uid}/msgs`).add({ from: '바르칸', at: this.now(), ...msg });
  }

  /** 물건을 우편으로 돌려줌 · 보냄 */
  async _sendGoods(uid, l, title, body) {
    const reward = {};
    const equips = [];
    if (l.kind === 'mat') reward[l.key] = l.qty;
    if (l.kind === 'item') reward['item:' + l.key] = l.qty;
    if (l.kind === 'egg') reward.egg = l.qty;
    if (l.kind === 'alc') reward['alc:' + l.key] = l.qty;
    if (l.kind === 'equip' && l.equip) equips.push(l.equip);
    await this._mail(uid, { title, body, reward, equips });
  }

  async _log(l, buyer, price, fee) {
    await this.db.collection('marketLog').add({
      listing: l.id,
      seller: l.seller,
      buyer,
      kind: l.kind,
      key: l.key,
      name: l.name,
      qty: l.qty,
      mode: l.mode,
      price,
      fee,
      at: this.now(),
      expireAt: new Date(this.now() + LOG_KEEP_MS),
    });
    const pk = `${l.kind}_${l.kind === 'equip' ? l.equip.base : l.key}`;
    const ref = this.db.doc(`marketPrice/${pk}`);
    const s = await ref.get();
    const last = s.exists ? s.data().last || [] : [];
    last.push({ unit: Math.round(price / Math.max(1, l.qty)), at: this.now() });
    await ref.set({ last: last.slice(-10) });
  }

  async _pairOk(a, b) {
    const k = [a, b].sort().join('_') + '_' + R.dayKey(this.now());
    const ref = this.db.doc(`marketPair/${k}`);
    const s = await ref.get();
    const n = s.exists ? s.data().n || 0 : 0;
    if (n >= PAIR_PER_DAY) return false;
    await ref.set({ n: n + 1, expireAt: new Date(this.now() + 2 * 24 * HOUR) });
    return true;
  }

  // ───────────── 올리기

  async list(uid, body = {}) {
    if (await this._restricted(uid)) fail('restricted', 403);
    const { kind, key, mode, me = {} } = body;
    const qty = Math.floor(Number(body.qty) || 1);
    if (!KINDS.includes(kind)) fail('bad_item');
    if (mode !== 'fixed' && mode !== 'auction') fail('bad_mode');
    if (qty < 1 || qty > CAT.maxQty || ((kind === 'equip' || kind === 'egg') && qty !== 1)) fail('bad_qty');
    const open = await this._openOf(uid);
    if (open.length >= CAT.slots) fail('slots_full');
    const w = await this._wallet(uid);
    const { have, hold } = w;
    let equip = null;
    let k = String(key || '');
    if (kind === 'mat') {
      if (!(k in CAT.mats)) fail('not_tradable');
      if ((have.mats[k] || 0) - (hold.mats[k] || 0) < qty) fail('not_owned', 409);
    } else if (kind === 'item') {
      if (!(k in CAT.items)) fail('not_tradable');
      if ((have.items[k] || 0) - (hold.items[k] || 0) < qty) fail('not_owned', 409);
    } else if (kind === 'alc') {
      if (!(k in (CAT.alcs || {}))) fail('not_tradable');
      if ((have.alcs[k] || 0) - (hold.alcs[k] || 0) < qty) fail('not_owned', 409);
    } else if (kind === 'equip') {
      equip = have.equips[k];
      if (!equip || hold.equips.includes(k)) fail('not_owned', 409);
      // 묶음 59: 받은 선물(첫 무기 · 우편 선물)은 못 팖
      if (!CAT.equipBases.includes(equip.base) || equip.gift) fail('not_tradable');
    } else {
      if (!have.eggs.has(k) || hold.eggs.includes(k)) fail('not_owned', 409);
    }
    const base = baseOf(kind, k, equip);
    if (base <= 0) fail('not_tradable');
    const b = bounds(base, qty);
    const price = Math.floor(Number(mode === 'fixed' ? body.price : body.start) || 0);
    if (price < b.min || price > b.max) fail('bad_price');
    let buyNow = null;
    if (mode === 'auction' && body.buyNow != null) {
      buyNow = Math.floor(Number(body.buyNow) || 0);
      if (buyNow <= price || buyNow > b.max) fail('bad_price');
    }
    const fee = listFee(price, !!body.seal);
    if (have.gold - hold.gold < fee) fail('no_gold', 409);
    const at = this.now();
    const ref = this.db.collection('market').doc(`m_${at.toString(36)}_${Math.random().toString(36).slice(2, 8)}`);
    const l = {
      id: ref.id,
      seller: uid,
      sellerName: safeName(me.name),
      kind,
      key: kind === 'equip' ? equip.base : k,
      itemId: k,
      name: nameOf(kind, k, equip),
      qty,
      equip,
      mode,
      price: mode === 'fixed' ? price : null,
      start: mode === 'auction' ? price : null,
      buyNow,
      bid: null,
      bidder: null,
      bids: 0,
      best: !!body.best,
      status: 'open',
      at,
      endsAt: at + (mode === 'fixed' ? CAT.fixedHours : CAT.auctionHours) * HOUR,
    };
    hold.gold += fee;
    if (kind === 'mat') hold.mats[k] = (hold.mats[k] || 0) + qty;
    if (kind === 'item') hold.items[k] = (hold.items[k] || 0) + qty;
    if (kind === 'alc') hold.alcs[k] = (hold.alcs[k] || 0) + qty;
    if (kind === 'equip') hold.equips.push(k);
    if (kind === 'egg') hold.eggs.push(k);
    await this.db.runTransaction(async (t) => {
      t.set(ref, l);
      this._saveHold(uid, hold, t);
    });
    return { ok: true, listing: view(l, uid), fee };
  }

  async _openOf(uid) {
    const q = await this.db.collection('market').where('seller', '==', uid).get();
    return q.docs.map((d) => d.data()).filter((l) => l.status === 'open');
  }

  // ───────────── 둘러보기

  /** 끝난 것 정리 (시간이 지난 값 매긴 물건은 돌려주고, 입찰이 있는 경매는 낙찰) */
  async settleDue() {
    const q = await this.db.collection('market').where('status', '==', 'open').get();
    let n = 0;
    for (const d of q.docs) {
      const l = d.data();
      if (l.endsAt > this.now()) continue;
      await this._settle(l.id);
      n++;
    }
    return { settled: n };
  }

  async _settle(id) {
    const ref = this.db.doc(`market/${id}`);
    let done = null;
    await this.db.runTransaction(async (t) => {
      const s = await t.get(ref);
      if (!s.exists) return;
      const l = s.data();
      if (l.status !== 'open' || l.endsAt > this.now()) return;
      l.status = l.bidder ? 'sold' : 'expired';
      l.buyer = l.bidder || null;
      l.soldAt = this.now();
      t.set(ref, l);
      done = l;
    });
    if (!done) return;
    const l = done;
    if (l.status === 'sold') {
      await this._paySeller(l, l.bid);
      await this._sendGoods(l.bidder, l, `경매에서 「${l.name}」을 낙찰받았어요`, '자네가 가장 높은 값을 불렀네. 물건은 여기 있네.');
    } else {
      await this._sendGoods(l.seller, l, `「${l.name}」이 팔리지 않았어요`, '이번엔 손님이 없었네. 물건은 돌려주겠네. 올릴 때 낸 금화는 장부 값이라 돌려주지 못하네.');
    }
  }

  async _paySeller(l, price) {
    const fee = saleFee(price, l.best);
    await this._mail(l.seller, {
      title: `「${l.name}」이 팔렸어요`,
      body: `금화 ${price}에 팔렸네. 수수료 ${fee}을 떼고 보내네.`,
      reward: { gold: price - fee },
      equips: [],
    });
    await this._log(l, l.buyer, price, fee);
  }

  async browse(uid, { cat, q, auction = false } = {}) {
    await this.settleDue();
    const s = await this.db.collection('market').where('status', '==', 'open').get();
    const word = String(q || '').trim();
    const rows = s.docs
      .map((d) => d.data())
      .filter((l) => l.seller !== uid)
      .filter((l) => (auction ? l.mode === 'auction' : l.mode === 'fixed'))
      .filter((l) => !cat || l.kind === cat)
      .filter((l) => !word || String(l.name).includes(word))
      .sort((a, b) => (auction ? a.endsAt - b.endsAt : unitOf(a) - unitOf(b)))
      .slice(0, 100)
      .map((l) => view(l, uid));
    return { items: rows };
  }

  async mine(uid) {
    await this.settleDue();
    const sold = await this.db.collection('market').where('seller', '==', uid).get();
    const bids = await this.db.collection('market').where('bidder', '==', uid).get();
    const recent = this.now() - 7 * 24 * HOUR;
    const mineRows = sold.docs.map((d) => d.data()).filter((l) => l.status === 'open' || (l.soldAt || 0) > recent);
    return {
      selling: mineRows.sort((a, b) => b.at - a.at).map((l) => view(l, uid)),
      bidding: bids.docs.map((d) => d.data()).filter((l) => l.status === 'open').map((l) => view(l, uid)),
      slots: CAT.slots,
    };
  }

  async price(_uid, { kind, key } = {}) {
    const s = await this.db.doc(`marketPrice/${kind}_${key}`).get();
    const last = s.exists ? s.data().last || [] : [];
    if (!last.length) return { count: 0 };
    const units = last.map((x) => x.unit);
    return {
      count: units.length,
      min: Math.min(...units),
      max: Math.max(...units),
      avg: Math.round(units.reduce((a, b) => a + b, 0) / units.length),
      last: units[units.length - 1],
    };
  }

  // ───────────── 사기 · 입찰

  async _buyerCheck(uid, l) {
    if (await this._restricted(uid)) fail('restricted', 403);
    if (l.seller === uid) fail('own_item');
    if (await this._sameDevice(uid, l.seller)) fail('same_device', 403);
  }

  async buy(uid, { id } = {}) {
    const ref = this.db.doc(`market/${String(id || '')}`);
    const s0 = await ref.get();
    if (!s0.exists) fail('gone', 404);
    const l0 = s0.data();
    if (l0.mode !== 'fixed') fail('bad_mode');
    await this._buyerCheck(uid, l0);
    const w = await this._wallet(uid);
    if (w.have.gold - w.hold.gold < l0.price) fail('no_gold', 409);
    if (!(await this._pairOk(uid, l0.seller))) fail('pair_limit', 429);
    let l = null;
    await this.db.runTransaction(async (t) => {
      const s = await t.get(ref);
      const x = s.exists ? s.data() : null;
      if (!x || x.status !== 'open' || x.endsAt <= this.now()) return;
      x.status = 'sold';
      x.buyer = uid;
      x.soldAt = this.now();
      t.set(ref, x);
      w.hold.gold += x.price;
      this._saveHold(uid, w.hold, t);
      l = x;
    });
    if (!l) fail('gone', 409);
    await this._paySeller(l, l.price);
    await this._sendGoods(uid, l, `「${l.name}」을 샀어요`, '좋은 물건을 골랐군. 우편으로 보내 두었네.');
    return { ok: true, charged: l.price };
  }

  async bid(uid, { id, amount } = {}) {
    const ref = this.db.doc(`market/${String(id || '')}`);
    const s0 = await ref.get();
    if (!s0.exists) fail('gone', 404);
    const l0 = s0.data();
    if (l0.mode !== 'auction') fail('bad_mode');
    await this._buyerCheck(uid, l0);
    let want = Math.floor(Number(amount) || 0);
    if (l0.buyNow && want >= l0.buyNow) want = l0.buyNow;
    const w = await this._wallet(uid);
    if (w.have.gold - w.hold.gold < want) fail('no_gold', 409);
    if (l0.bidder !== uid && !(await this._pairOk(uid, l0.seller))) fail('pair_limit', 429);
    let res = null;
    let prev = null;
    await this.db.runTransaction(async (t) => {
      const s = await t.get(ref);
      const x = s.exists ? s.data() : null;
      if (!x || x.status !== 'open' || x.endsAt <= this.now()) {
        res = 'gone';
        return;
      }
      // 동시에 들어온 입찰: 먼저 적힌 값보다 낮으면 「다른 사람이 더 높게」
      if (want < nextBid(x)) {
        res = 'outbid';
        return;
      }
      prev = x.bidder ? { uid: x.bidder, bid: x.bid } : null;
      x.bid = want;
      x.bidder = uid;
      x.bids = (x.bids || 0) + 1;
      if (x.buyNow && want >= x.buyNow) {
        x.status = 'sold';
        x.buyer = uid;
        x.soldAt = this.now();
      } else if (x.endsAt - this.now() < SNIPE_MS) {
        x.endsAt = this.now() + SNIPE_MS;
      }
      t.set(ref, x);
      w.hold.gold += want;
      this._saveHold(uid, w.hold, t);
      res = x;
    });
    if (res === 'gone') fail('gone', 409);
    if (res === 'outbid') fail('outbid', 409);
    if (prev) {
      await this._mail(prev.uid, {
        title: `「${res.name}」 경매에서 더 높은 값이 나왔어요`,
        body: '다른 손님이 더 높게 불렀네. 묶어 두었던 금화를 돌려주겠네.',
        reward: { gold: prev.bid },
        equips: [],
      });
    }
    if (res.status === 'sold') {
      await this._paySeller(res, res.bid);
      await this._sendGoods(uid, res, `「${res.name}」을 바로 샀어요`, '바로 사기 값이군. 우편으로 보내 두었네.');
    }
    return { ok: true, charged: want, sold: res.status === 'sold', listing: view(res, uid) };
  }

  /** 값을 정해 올린 물건을 내림 (경매는 입찰이 없을 때만). 물건은 우편으로 돌아감 */
  async cancel(uid, { id } = {}) {
    const ref = this.db.doc(`market/${String(id || '')}`);
    let l = null;
    await this.db.runTransaction(async (t) => {
      const s = await t.get(ref);
      const x = s.exists ? s.data() : null;
      if (!x || x.seller !== uid || x.status !== 'open' || x.bidder) return;
      x.status = 'cancelled';
      x.soldAt = this.now();
      t.set(ref, x);
      l = x;
    });
    if (!l) fail('cannot_cancel', 409);
    await this._sendGoods(uid, l, `「${l.name}」을 내렸어요`, '물건은 돌려주겠네. 올릴 때 낸 금화는 돌려주지 못하네.');
    return { ok: true };
  }

  // ───────────── 운영자

  async trades({ uid } = {}) {
    if (typeof uid !== 'string' || !/^[A-Za-z0-9]{6,128}$/.test(uid)) return { found: false };
    const a = await this.db.collection('marketLog').where('seller', '==', uid).get();
    const b = await this.db.collection('marketLog').where('buyer', '==', uid).get();
    const o = await this.db.collection('market').where('seller', '==', uid).get();
    const rows = [...a.docs, ...b.docs]
      .map((d) => ({ id: d.id, ...d.data(), side: d.data().seller === uid ? 'sell' : 'buy' }))
      .sort((x, y) => y.at - x.at)
      .slice(0, 200)
      .map((x) => ({ ...x, expireAt: undefined }));
    return {
      found: true,
      trades: rows,
      open: o.docs.map((d) => d.data()).filter((l) => l.status === 'open').map((l) => view(l, null)),
    };
  }
}

function unitOf(l) {
  return Math.round((l.mode === 'fixed' ? l.price : l.bid || l.start) / Math.max(1, l.qty));
}

/** 앱에 보여 줄 모양 (파는 사람 uid 는 빼고, 내 것인지만) */
function view(l, uid) {
  return {
    id: l.id,
    mine: l.seller === uid,
    sellerName: l.sellerName,
    kind: l.kind,
    key: l.key,
    name: l.name,
    qty: l.qty,
    equip: l.equip || null,
    mode: l.mode,
    price: l.price,
    start: l.start,
    buyNow: l.buyNow,
    bid: l.bid,
    bids: l.bids || 0,
    myBid: !!uid && l.bidder === uid,
    next: l.mode === 'auction' ? nextBid(l) : null,
    status: l.status,
    endsAt: l.endsAt,
    at: l.at,
  };
}

module.exports = { MarketService, MarketError, countSnapshot, baseOf, bounds, listFee, saleFee, CAT };
