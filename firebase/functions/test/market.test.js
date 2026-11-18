const test = require('node:test');
const assert = require('node:assert');
const zlib = require('zlib');
const { MemDb } = require('../src/memdb');
const { MarketService, countSnapshot, listFee, saleFee, CAT } = require('../src/market');
const { DeepService, regionOf, prizeOf } = require('../src/deep');
const { setDeps, handle } = require('../src/router');

// 2026-11-18(수) 12:00 KST
const T0 = Date.parse('2026-11-18T03:00:00Z');
const H = 3600000;

function setup() {
  const db = new MemDb();
  let now = T0;
  const s = new MarketService(db, { now: () => now });
  return { db, s, at: (ms) => (now = ms), get now() { return now; } };
}

/** 그 계정의 백업 (금화 · 재료 · 장비 · 물약 · 알) */
async function backup(db, uid, { gold = 0, mats = {}, equips = [], potions = {}, eggs = [], device = 'd_' + uid, at = T0, buildings = null } = {}) {
  const gen = 'g' + Math.random().toString(36).slice(2, 7);
  const snap = {
    'history.v1': JSON.stringify([
      {
        date: '2026-11-18',
        gains: { gold, ...mats },
        spends: {},
        goldPurchases: Object.entries(potions).flatMap(([k, n]) => Array(n).fill(k)),
        shopPurchases: [],
        itemsUsed: [],
        counters: {},
      },
    ]),
    'json.armory': JSON.stringify({ items: equips, equipped: { weapon: 'eqWorn' } }),
    'json.pets': JSON.stringify({ eggs: eggs.map((id) => ({ id })) }),
    ...(buildings ? { 'json.buildings': JSON.stringify(buildings) } : {}),
  };
  const data = zlib.gzipSync(Buffer.from(JSON.stringify(snap))).toString('base64');
  await db.doc(`users/${uid}/parts/${gen}_0`).set({ gen, data });
  await db.doc(`users/${uid}`).set({ gen, parts: 1, updatedAt: new Date(at), devices: [device] });
  // 묶음 61: 거래는 거래 지갑 금화로 (시험에선 백업 금화만큼 맡겨 둔 것으로)
  await db.doc(`tradeWallet/${uid}`).set({ gold });
}

const inbox = async (db, uid) => (await db.collection(`inbox/u_${uid}/msgs`).get()).docs.map((d) => d.data());
const sword = { uid: 'eq5', base: 'dagger', grade: 'blue', enhance: 2, durability: 90, extras: {} };

test('백업 다시 세기: 금화(위쪽 한도) · 재료 · 물약 · 장비(입은 건 빼고) · 알', () => {
  const r = countSnapshot({
    'history.v1': JSON.stringify([
      { date: '2026-11-17', gains: { gold: 500, herb: 4 }, spends: { gold: 100, herb: 1 }, goldPurchases: ['healSmall', 'healSmall', 'ironShard'], itemsUsed: ['healSmall'], counters: { 'drop:healSmall': 0 } },
    ]),
    'json.armory': JSON.stringify({ items: [{ uid: 'a', base: 'cap' }, { uid: 'b', base: 'cap' }], equipped: { head: 'b' } }),
    'json.pets': JSON.stringify({ eggs: [{ id: 'e1' }, { id: 'e2', incubatedAt: '2026-11-18' }] }),
  });
  assert.equal(r.gold, 400 + 240);
  assert.equal(r.mats.herb, 3);
  assert.equal(r.mats.ironShard, 1);
  assert.equal(r.items.healSmall, 1);
  assert.deepEqual(Object.keys(r.equips), ['a']);
  assert.deepEqual([...r.eggs], ['e1']);
});

test('값을 정해 올리기 → 다른 사람이 사기 → 우편(물건 · 금화 − 수수료) · 시세 · 기록', async () => {
  const { db, s } = setup();
  await backup(db, 'sel', { gold: 100, mats: { herb: 10 } });
  await backup(db, 'buy', { gold: 1000 });
  const base = CAT.mats.herb;
  await assert.rejects(s.list('sel', { kind: 'mat', key: 'herb', qty: 3, mode: 'fixed', price: base * 3 * 10 }), /bad_price/);
  await assert.rejects(s.list('sel', { kind: 'mat', key: 'herb', qty: 11, mode: 'fixed', price: base * 11 }), /not_owned/);
  const price = base * 3 * 2;
  const r = await s.list('sel', { kind: 'mat', key: 'herb', qty: 3, mode: 'fixed', price, me: { name: '하루' } });
  assert.equal(r.fee, listFee(price, false));
  // 같은 백업으로 또 올리면 이미 맡긴 몫을 뺌
  await assert.rejects(s.list('sel', { kind: 'mat', key: 'herb', qty: 8, mode: 'fixed', price: base * 8 }), /not_owned/);
  const b = await s.browse('buy', { cat: 'mat' });
  assert.equal(b.items.length, 1);
  assert.equal(b.items[0].sellerName, '하루');
  assert.equal(b.items[0].seller, undefined, '파는 사람 uid 는 안 보냄');
  assert.equal((await s.browse('sel', {})).items.length, 0, '내 물건은 사기 목록에 안 나옴');
  await assert.rejects(s.buy('sel', { id: r.listing.id }), /own_item/);
  const got = await s.buy('buy', { id: r.listing.id });
  assert.equal(got.charged, price);
  await assert.rejects(s.buy('buy', { id: r.listing.id }), /gone/);
  const bm = await inbox(db, 'buy');
  assert.equal(bm[0].from, '바르칸');
  assert.deepEqual(bm[0].reward, { herb: 3 });
  const sm = await inbox(db, 'sel');
  assert.deepEqual(sm[0].reward, {}, '묶음 61: 판 금화는 거래 지갑으로');
  assert.equal(await s.purse('sel'), 100 - r.fee + price - saleFee(price, false));
  assert.equal(await s.purse('buy'), 1000 - price);
  const p = await s.price('buy', { kind: 'mat', key: 'herb' });
  assert.equal(p.last, price / 3);
  const log = await s.trades({ uid: 'buyxyz' });
  assert.equal(log.found, true);
  const t = await s.trades({ uid: 'selxyz' });
  assert.equal(t.trades.length, 0);
});

test('장비: 입은 건 · 보스 장비는 못 올림 · 서버가 백업의 장비 그대로 · 못 팔면 48시간 뒤 우편으로 돌아옴', async () => {
  const { db, s, at } = setup();
  await backup(db, 'sel', {
    gold: 50,
    equips: [sword, { uid: 'eqWorn', base: 'cap', grade: 'white' }, { uid: 'eqBoss', base: 'wardenHead', grade: 'orange' }],
  });
  await assert.rejects(s.list('sel', { kind: 'equip', key: 'eqWorn', mode: 'fixed', price: 30 }), /not_owned/);
  await assert.rejects(s.list('sel', { kind: 'equip', key: 'eqBoss', mode: 'fixed', price: 500 }), /not_tradable/);
  const r = await s.list('sel', { kind: 'equip', key: 'eq5', mode: 'fixed', price: 200 });
  assert.equal(r.listing.equip.grade, 'blue');
  assert.equal(r.listing.name, CAT.equipNames.dagger);
  at(T0 + 49 * H);
  await s.settleDue();
  const m = await inbox(db, 'sel');
  assert.equal(m[0].equips[0].uid, 'eq5');
  assert.match(m[0].title, /팔리지 않았어요/);
});

test('경매: 입찰 · 더 높은 입찰이면 앞사람 금화 돌려줌 · 바로 사기 · 끝나면 낙찰', async () => {
  const { db, s, at } = setup();
  await backup(db, 'sel', { gold: 50, eggs: ['egg1', 'egg2'] });
  await backup(db, 'b1', { gold: 1000 });
  await backup(db, 'b2', { gold: 1000 });
  const a = await s.list('sel', { kind: 'egg', key: 'egg1', mode: 'auction', start: 150, buyNow: 600 });
  await assert.rejects(s.bid('b1', { id: a.listing.id, amount: 100 }), /outbid/);
  await s.bid('b1', { id: a.listing.id, amount: 150 });
  await assert.rejects(s.bid('b2', { id: a.listing.id, amount: 151 }), /outbid/);
  const r2 = await s.bid('b2', { id: a.listing.id, amount: 200 });
  assert.equal(r2.charged, 200);
  assert.deepEqual((await inbox(db, 'b1'))[0].reward, {});
  assert.equal(await s.purse('b1'), 1000, '돌려받는 입찰 금화는 지갑으로');
  assert.equal(await s.purse('b2'), 800);
  await assert.rejects(s.cancel('sel', { id: a.listing.id }), /cannot_cancel/);
  at(T0 + 25 * H);
  await s.settleDue();
  assert.deepEqual((await inbox(db, 'b2'))[0].reward, { egg: 1 });
  // 바로 사기
  at(T0);
  await backup(db, 'sel', { gold: 50, eggs: ['egg2'] });
  await backup(db, 'b1', { gold: 1000 });
  const c = await s.list('sel', { kind: 'egg', key: 'egg2', mode: 'auction', start: 150, buyNow: 400 });
  const r = await s.bid('b1', { id: c.listing.id, amount: 999 });
  assert.equal(r.charged, 400);
  assert.equal(r.sold, true);
});

test('운영정책: 같은 휴대폰 계정끼리 · 제재 중 · 금화가 모자라면 · 백업이 오래되면 · 5칸 · 같은 둘이 하루 3번까지', async () => {
  const { db, s } = setup();
  await backup(db, 'sel', { gold: 500, mats: { herb: 50 }, equips: [sword] });
  await backup(db, 'alt', { gold: 1000, device: 'd_sel' });
  await backup(db, 'poor', { gold: 1 });
  await backup(db, 'old', { gold: 1000, at: T0 - 60 * 60000 });
  await backup(db, 'bad', { gold: 1000 });
  await db.doc('status/bad').set({ level: 2 });
  const ids = [];
  for (let i = 0; i < 4; i++) ids.push((await s.list('sel', { kind: 'mat', key: 'herb', qty: 2, mode: 'fixed', price: CAT.mats.herb * 2 })).listing.id);
  const pricey = (await s.list('sel', { kind: 'equip', key: 'eq5', mode: 'fixed', price: 700 })).listing.id;
  await assert.rejects(s.list('sel', { kind: 'mat', key: 'herb', qty: 2, mode: 'fixed', price: CAT.mats.herb * 2 }), /slots_full/);
  await assert.rejects(s.buy('alt', { id: ids[0] }), /same_device/);
  await assert.rejects(s.buy('poor', { id: pricey }), /no_wallet_gold/, '거래 지갑 금화보다 비쌈');
  await assert.rejects(s.deposit('old', { amount: 10 }), /need_backup/, '맡길 때는 최근 백업으로 확인');
  await assert.rejects(s.buy('bad', { id: ids[0] }), /restricted/);
  await backup(db, 'bb', { gold: 5000 });
  for (let i = 0; i < 3; i++) await s.buy('bb', { id: ids[i] });
  await assert.rejects(s.buy('bb', { id: ids[3] }), /pair_limit/);
});

test('거래 지갑: 맡기기(백업으로 확인 · 같은 백업으로 두 번 못 맡김) · 꺼내기(우편) · 지갑 금화로만 거래', async () => {
  const { db, s } = setup();
  await backup(db, 'u1', { gold: 300 });
  await db.doc('tradeWallet/u1').set({ gold: 0 });
  await assert.rejects(s.deposit('u1', { amount: 1000 }), /no_gold/);
  const d = await s.deposit('u1', { amount: 400 });
  assert.equal(d.wallet, 400);
  assert.ok(d.depositId);
  await assert.rejects(s.deposit('u1', { amount: 400 }), /no_gold/, '같은 백업으로 맡긴 몫은 뺌');
  const w = await s.withdraw('u1', { amount: 50 });
  assert.equal(w.wallet, 350);
  const m = await inbox(db, 'u1');
  assert.deepEqual(m[0].reward, { gold: 50 });
  await assert.rejects(s.withdraw('u1', { amount: 999 }), /no_wallet_gold/);
});

test('심층 주간 순위: 그 주 지역만 · 같은 휴대폰은 하나 · 지난주 보상 한 번', async () => {
  const db = new MemDb();
  let now = T0;
  const d = new DeepService(db, { now: () => now });
  const { region } = d.week();
  assert.equal(region, regionOf('2026-11-16'));
  await db.doc('users/a').set({ devices: ['x'] });
  await db.doc('users/b').set({ devices: ['x'] });
  await db.doc('users/c').set({ devices: ['y'] });
  assert.equal((await d.submit('a', { region: 'nope', floor: 9 })).ok, false);
  await d.submit('a', { region, floor: 12, me: { name: '하루' } });
  await d.submit('b', { region, floor: 15, me: { name: '시 발' } });
  await d.submit('c', { region, floor: 8, me: { name: '별' } });
  await d.submit('c', { region, floor: 7 });
  const bd = await d.board('c');
  assert.deepEqual(bd.top.map((x) => [x.name, x.floor]), [['각성자', 15], ['별', 8]]);
  assert.deepEqual(bd.me, { rank: 2, floor: 8 });
  now = T0 + 7 * 86400000;
  assert.equal((await d.payLastWeek()).paid, 2);
  assert.equal((await d.payLastWeek()).paid, 0);
  const m = (await db.collection('inbox/u_b/msgs').get()).docs[0].data();
  assert.deepEqual(m.reward, prizeOf(1));
});

test('길: /market/* 는 로그인 필요', async () => {
  setDeps({ db: new MemDb(), verify: async () => { throw new Error('x'); }, env: {}, market: new MarketService(new MemDb()) });
  const out = {};
  const res = { set() {}, status(c) { out.code = c; return this; }, json(j) { out.j = j; return this; }, send() { return this; } };
  await handle({ method: 'POST', path: '/market/browse', body: {}, get: () => '' }, res);
  assert.equal(out.code, 401);
});

test('묶음 67 #271: 거래소 ★2 칸 7 · ★3 칸 9 + 값을 정해 올린 물건 72시간 (백업의 건물 ★ · 고치는 시각이 지나면 한 단계 위)', async () => {
  const { marketStar } = require('../src/market');
  assert.equal(marketStar({}, T0), 1);
  assert.equal(marketStar({ stars: { market: 2 } }, T0), 2);
  assert.equal(marketStar({ stars: { market: 2 }, fixing: { market: '2026-11-18T11:00:00.000' } }, T0), 3, 'KST 11시 = T0 이전');
  assert.equal(marketStar({ stars: { market: 2 }, fixing: { market: '2026-11-18T13:00:00.000' } }, T0), 2);
  const { db, s } = setup();
  await backup(db, 'b2', { gold: 100000, mats: { herb: 50 }, buildings: { stars: { market: 2 } } });
  for (let i = 0; i < 7; i++) await s.list('b2', { kind: 'mat', key: 'herb', qty: 1, mode: 'fixed', price: CAT.mats.herb * 2 });
  await assert.rejects(s.list('b2', { kind: 'mat', key: 'herb', qty: 1, mode: 'fixed', price: CAT.mats.herb * 2 }), /slots_full/);
  await backup(db, 'b3', { gold: 100000, mats: { herb: 50 }, buildings: { stars: { market: 3 } } });
  const r = await s.list('b3', { kind: 'mat', key: 'herb', qty: 1, mode: 'fixed', price: CAT.mats.herb * 2 });
  assert.equal(r.listing.endsAt - T0, 72 * H);
  for (let i = 0; i < 8; i++) await s.list('b3', { kind: 'mat', key: 'herb', qty: 1, mode: 'fixed', price: CAT.mats.herb * 2 });
  await assert.rejects(s.list('b3', { kind: 'mat', key: 'herb', qty: 1, mode: 'fixed', price: CAT.mats.herb * 2 }), /slots_full/);
  const a = await s.list('b3', { kind: 'mat', key: 'herb', qty: 1, mode: 'auction', start: CAT.mats.herb * 2 }).catch((e) => e);
  assert.match(String(a.code || a), /slots_full/);
});

test('묶음 67 #273: 「약초」로 쓴 건 다른 약초에서 흔한 것부터 뺌 (앱과 같은 셈)', () => {
  const r = countSnapshot({
    'history.v1': JSON.stringify([
      { date: '2026-11-19', gains: { herb: 1, gortRoot: 2, silvaFern: 3 }, spends: {} },
      { date: '2026-11-20', gains: {}, spends: { herb: 4 } },
    ]),
  });
  assert.equal(r.mats.herb, 0);
  assert.equal(r.mats.gortRoot, 0);
  assert.equal(r.mats.silvaFern, 2);
});
