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
async function backup(db, uid, { gold = 0, mats = {}, equips = [], potions = {}, eggs = [], device = 'd_' + uid, at = T0 } = {}) {
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
  };
  const data = zlib.gzipSync(Buffer.from(JSON.stringify(snap))).toString('base64');
  await db.doc(`users/${uid}/parts/${gen}_0`).set({ gen, data });
  await db.doc(`users/${uid}`).set({ gen, parts: 1, updatedAt: new Date(at), devices: [device] });
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
  assert.deepEqual(sm[0].reward, { gold: price - saleFee(price, false) });
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
  assert.deepEqual((await inbox(db, 'b1'))[0].reward, { gold: 150 });
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
  await assert.rejects(s.buy('poor', { id: pricey }), /no_gold/, '금화 위쪽 한도(주간 의뢰 몫 포함)보다 비쌈');
  await assert.rejects(s.buy('old', { id: ids[0] }), /need_backup/);
  await assert.rejects(s.buy('bad', { id: ids[0] }), /restricted/);
  await backup(db, 'bb', { gold: 5000 });
  for (let i = 0; i < 3; i++) await s.buy('bb', { id: ids[i] });
  await assert.rejects(s.buy('bb', { id: ids[3] }), /pair_limit/);
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
