// 묶음 61 #250: 부정 이용 막기 (다른 사람과 얽히는 곳만) · 길드 금고 쓰기
const test = require('node:test');
const assert = require('node:assert');
const { MemDb } = require('../src/memdb');
const { GuildService } = require('../src/guild');
const { PartyService } = require('../src/party');
const { MarketService } = require('../src/market');
const { SuspectService } = require('../src/suspect');
const { SiegeService, siegeStart, siegeEnd, T } = require('../src/siege');
const { handle, setDeps } = require('../src/router');

const DAY = 86400000;
const S0 = siegeStart(0);

async function world(at) {
  const db = new MemDb();
  let now = at;
  const clock = () => now;
  const suspect = new SuspectService(db, { now: clock });
  const g = new GuildService(db, { now: clock });
  const s = new SiegeService(db, { now: clock, guild: g, suspect });
  const mk = async (owner, name, members = []) => {
    await g.create(owner, { name, me: { name: owner, level: 40 } });
    const st = await g.state(owner, { name: owner, level: 40 });
    for (const m of members) await g.join(m, { code: st.guild.code, me: { name: m, level: 40 } });
    return (await db.doc(`guildOf/${owner}`).get()).data().gid;
  };
  return { db, g, s, suspect, mk, set: (t) => (now = t), add: (ms) => (now += ms), get now() { return now; } };
}

test('공성권: 서버가 함께하는 걸음으로 셈 · 처음엔 앱 장수를 옮김 · 휴대폰 하나에 계정 하나', async () => {
  const w = await world(S0 - 5 * DAY);
  await w.mk('ua', '새벽', ['ub']);
  // 처음: 앱에 있던 7장 · 1,500보 진행을 그대로
  let st = await w.s.state('ua', { steps: 3000, device: 'd1', tickets: 7, carry: 1500 });
  assert.equal(st.tickets, 7);
  assert.equal(st.ticketCarry, 1500);
  // 오늘 걸음이 3,000 → 5,500 (2,500 더) → 1,500 + 2,500 = 4,000 → 2장
  st = await w.s.state('ua', { steps: 5500, device: 'd1' });
  assert.equal(st.tickets, 9);
  assert.equal(st.ticketCarry, 0);
  // 같은 걸음을 다시 보내도 늘지 않음
  st = await w.s.state('ua', { steps: 5500, device: 'd1' });
  assert.equal(st.tickets, 9);
  // 같은 휴대폰으로 다른 계정 (ub): 처음 옮김은 되지만, 오늘 걸음은 ua 에게만
  st = await w.s.state('ub', { steps: 0, device: 'd1', tickets: 0 });
  st = await w.s.state('ub', { steps: 9000, device: 'd1' });
  assert.equal(st.tickets, 0);
  // 다음 날 새로
  w.add(DAY);
  st = await w.s.state('ua', { steps: 4000, device: 'd1' });
  assert.equal(st.tickets, 11);
  // 최대 20장
  st = await w.s.state('ua', { steps: 40000, device: 'd1' });
  assert.equal(st.tickets, T.ticketMax);
  // 앱이 엉뚱하게 많이 보내도 처음 옮김은 20장까지
  await w.mk('uz', '저녁');
  st = await w.s.state('uz', { tickets: 999 });
  assert.equal(st.tickets, T.ticketMax);
});

test('싸움: 서버가 내준 자리로만 · 공성권 한 장 · 너무 빨리 이기면 세지 않고 의심 목록에', async () => {
  const w = await world(S0 - 5 * DAY);
  await w.mk('ua', '새벽');
  // 공성권이 없으면 자리를 내주지 않음
  await w.s.state('ua', { steps: 0, tickets: 0 });
  await assert.rejects(w.s.foe('ua', { estate: 'sol_lily' }), /no_ticket/);
  await w.db.doc('siegeTicket/ua').set({ bank: 2, carry: 0, day: '', dayCounted: 0 });
  // 내준 자리 없이 결과만 보내면 안 됨
  await assert.rejects(w.s.fight('ua', { estate: 'sol_lily', slot: 0, win: true }), /no_fight/);
  let f = await w.s.foe('ua', { estate: 'sol_lily' });
  assert.equal(f.slot, 0);
  await assert.rejects(w.s.fight('ua', { estate: 'sol_lily', slot: 3, win: true }), /no_fight/);
  // 1초 만에 이김 → 세지 않음
  f = await w.s.foe('ua', { estate: 'sol_lily' });
  w.add(1000);
  let r = await w.s.fight('ua', { estate: 'sol_lily', slot: f.slot, win: true });
  assert.equal(r.won, false);
  assert.deepEqual(r.broken, []);
  assert.equal(r.tickets, 1);
  const sus = (await w.db.doc('suspects/ua').get()).data();
  assert.equal(sus.counts.fight, 1);
  assert.ok(sus.expireAt instanceof Date);
  // 제대로 싸우면 셈
  f = await w.s.foe('ua', { estate: 'sol_lily' });
  w.add(30000);
  r = await w.s.fight('ua', { estate: 'sol_lily', slot: f.slot, win: true });
  assert.equal(r.won, true);
  assert.deepEqual(r.broken, [0]);
  assert.equal(r.tickets, 0);
  // 공성권을 다 쓰면 다음 자리는 없음
  await assert.rejects(w.s.foe('ua', { estate: 'sol_lily' }), /no_ticket/);
});

test('수비대: 분신 레벨은 길드에 남은 레벨까지 · 공성전 기록은 끝난 뒤 8주에 지움', async () => {
  const w = await world(S0 - 5 * DAY);
  const ga = await w.mk('ua', '새벽');
  await w.db.doc('erbard/world').set({ owners: { sol_lily: { gid: ga, name: '새벽' } }, settled: -1, last: null, crown: null, avgLevel: 30 });
  await w.s.garrison('ua', { estate: 'sol_lily', slot: 0, snap: { name: 'ua', level: 199, allies: [{ name: '세린', level: 150 }] } });
  const gs = (await w.db.doc('garrison/sol_lily').get()).data();
  assert.equal(gs.slots[0].level, 40);
  assert.equal(gs.slots[0].allies[0].level, 40);
  // 공성전 기록
  w.set(S0 + 3600000);
  await w.mk('ux', '저녁');
  await w.db.doc('siegeTicket/ux').set({ bank: 5, carry: 0, day: '', dayCounted: 0 });
  const f = await w.s.foe('ux', { estate: 'sol_lily' });
  w.add(20000);
  await w.s.fight('ux', { estate: 'sol_lily', slot: f.slot, win: true });
  const run = (await w.db.doc('siegeRun/0_sol_lily').get()).data();
  const use = (await w.db.doc('siegeUse/0').get()).data();
  assert.equal(run.expireAt.getTime(), siegeEnd(0) + 56 * DAY);
  assert.equal(use.expireAt.getTime(), siegeEnd(0) + 56 * DAY);
});

test('길드 금고: 수비대 강화 · 회관 공사 · 나눠 주기 · 금고 상점 · 게시판 기록', async () => {
  const w = await world(S0 - 5 * DAY);
  const ga = await w.mk('ua', '새벽', ['ub', 'uc']);
  const gb = await w.mk('ux', '저녁');
  await w.db.doc('erbard/world').set({ owners: { sol_lily: { gid: ga, name: '새벽' } }, settled: -1, last: null, crown: null, avgLevel: 30 });
  const gref = w.db.doc(`guilds/${ga}`);
  await gref.set({ ...(await gref.get()).data(), treasury: 30000 });
  // 길드원은 못 씀
  await assert.rejects(w.g.treasury('ub', { action: 'boost', estate: 'sol_lily', level: 1 }), /not_staff/);
  await assert.rejects(w.g.treasury('ua', { action: 'boost', estate: 'sol_bell', level: 1 }), /not_yours/);
  // 강화 1단계 → 2단계 (차이만)
  await w.g.treasury('ua', { action: 'boost', estate: 'sol_lily', level: 1 });
  await assert.rejects(w.g.treasury('ua', { action: 'boost', estate: 'sol_lily', level: 1 }), /owned/);
  let v = await w.g.treasury('ua', { action: 'boost', estate: 'sol_lily', level: 2 });
  assert.equal(v.treasury.gold, 30000 - T.boostCost[1]);
  const boost = (await w.db.doc('garrison/sol_lily').get()).data().boost;
  assert.equal(boost.level, 2);
  assert.equal(boost.until, siegeEnd(0));
  // 공성 중 상대가 보는 세기에 더해짐 (숫자는 앱이 숨김)
  w.set(S0 + 3600000);
  await w.db.doc('siegeTicket/ux').set({ bank: 5, carry: 0, day: '', dayCounted: 0 });
  const f = await w.s.foe('ux', { estate: 'sol_lily' });
  assert.ok(f.bonus >= T.boostMult[1]);
  await assert.rejects(w.g.treasury('ua', { action: 'boost', estate: 'sol_lily', level: 3 }), /siege_lock/);
  // 회관 공사: 금화 10당 1점, 하루 한도
  const before = (await gref.get()).data().hall.points || 0;
  v = await w.g.treasury('ua', { action: 'hall', amount: 1000 });
  assert.equal((await gref.get()).data().hall.points, before + 100);
  await assert.rejects(w.g.treasury('ua', { action: 'hall', amount: 4000 }), /donate_limit/);
  // 금고 상점
  await w.g.treasury('ub', { action: 'shop', id: 'goldFlag' }).catch((e) => assert.match(e.message, /not_staff/));
  v = await w.g.treasury('ua', { action: 'shop', id: 'goldFlag' });
  assert.equal(v.guild.goldFlag, true);
  await assert.rejects(w.g.treasury('ua', { action: 'shop', id: 'goldFlag' }), /owned/);
  v = await w.g.treasury('ua', { action: 'shop', id: 'goldLights' });
  assert.ok(v.hall.decos.includes('goldLights'));
  await assert.rejects(w.g.decoAdd('ua', { id: 'goldFountain' }), /bad_deco/);
  // 나눠 주기: 공성전이 끝난 뒤, 공성권을 쓴 길드원에게 똑같이 (금고 절반까지 · 한 사람 2,000까지)
  await assert.rejects(w.g.treasury('ua', { action: 'share', amount: 1000 }), /not_yet/);
  w.set(siegeEnd(0) + 3600000);
  await w.db.doc('siegeUse/0').set({ no: 0, u: { ua: { n: 3, gid: ga }, ub: { n: 1, gid: ga }, ux: { n: 2, gid: gb } } });
  await assert.rejects(w.g.treasury('ub', { action: 'share', amount: 1000 }), /not_owner/);
  const gold = (await gref.get()).data().treasury;
  await assert.rejects(w.g.treasury('ua', { action: 'share', amount: gold }), /bad_amount/);
  v = await w.g.treasury('ua', { action: 'share', amount: 6000 });
  assert.equal(v.treasury.gold, gold - 2 * T.sharePerHeadMax);
  await assert.rejects(w.g.treasury('ua', { action: 'share', amount: 100 }), /shared/);
  const mail = (await w.db.collection('inbox/u_ub/msgs').get()).docs.map((d) => d.data());
  assert.equal(mail.find((m) => m.kind === 'treasury').reward.gold, T.sharePerHeadMax);
  assert.equal((await w.db.collection('inbox/u_uc/msgs').get()).docs.filter((d) => d.data().kind === 'treasury').length, 0);
  // 게시판 기록: 누가 · 무엇에 · 얼마 (최근 것이 위)
  assert.deepEqual(
    v.treasury.log.map((l) => [l.name, l.gold]),
    [
      ['ua', 2 * T.sharePerHeadMax],
      ['ua', T.treasuryShop.goldLights],
      ['ua', T.treasuryShop.goldFlag],
      ['ua', 1000],
      ['ua', T.boostCost[1] - T.boostCost[0]],
      ['ua', T.boostCost[0]],
    ],
  );
  assert.match(v.treasury.log[0].what, /나눠 주기/);
  // 금고가 모자라면
  await gref.set({ ...(await gref.get()).data(), treasury: 10 });
  await assert.rejects(w.g.treasury('ua', { action: 'shop', id: 'goldFountain' }), /no_treasury/);
});

test('의심 목록: 손으로 입력한 걸음 · 하루 걸음 · 가짜 위치 · 같은 종류는 하루 한 번 · 통과율', async () => {
  const db = new MemDb();
  let now = Date.UTC(2026, 10, 20, 3);
  const sus = new SuspectService(db, { now: () => now });
  await sus.steps('u1', { steps: 12000, maxHour: 4000, manual: 0 });
  await sus.steps('u1', { steps: 9000, maxHour: 9000, manual: 3000 });
  await sus.hit('u1', 'mock');
  await sus.hit('u1', 'mock');
  await sus.hit('u2', 'wallet');
  await sus.hit('u2', 'nope');
  await sus.appCheckStat('ok');
  await sus.appCheckStat('ok');
  await sus.appCheckStat('bad');
  const r = await sus.list();
  assert.equal(r.items[0].uid, 'u1');
  assert.deepEqual(r.items[0].counts, { manual: 1, mock: 1 });
  assert.deepEqual(r.items[0].days[0], { day: r.items[0].days[0].day, steps: 12000, maxHour: 9000, manual: 3000 });
  assert.deepEqual(r.items[1].counts, { wallet: 1 });
  assert.deepEqual(r.appCheck[0].ok, 2);
  now += DAY;
  await sus.hit('u1', 'mock');
  assert.equal((await db.doc('suspects/u1').get()).data().counts.mock, 2);
});

test('길: 진짜 앱 확인은 기록만 (통과율) · 막기로 바꿀 수 있음 · 가짜 위치는 칸을 받지 않음 · 운영자 의심 목록', async () => {
  const db = new MemDb();
  const now = () => Date.UTC(2026, 10, 20, 3);
  const party = new PartyService(db, { now });
  const suspect = new SuspectService(db, { now });
  const market = new MarketService(db, { now });
  market.suspect = suspect;
  const env = { ADMIN_EMAILS: 'boss@example.com' };
  setDeps({
    db,
    party,
    market,
    suspect,
    appCheck: async (t) => {
      if (t !== 'good') throw new Error('bad');
      return true;
    },
    verify: async (t) => (t === 'admin' ? { uid: 'adm', email: 'boss@example.com' } : t === 'u' ? { uid: 'u1' } : Promise.reject(new Error('bad'))),
    env,
  });
  const call = async (path, { auth, body = {}, headers = {} } = {}) => {
    const out = {};
    const res = {
      set() {},
      status(c) {
        out.status = c;
        return res;
      },
      json(j) {
        out.json = j;
        out.status = out.status || 200;
        return res;
      },
      send() {
        return res;
      },
    };
    const h = { ...headers, ...(auth ? { Authorization: `Bearer ${auth}` } : {}) };
    await handle({ method: 'POST', path, body, get: (k) => h[k] || h[k.toLowerCase()] }, res);
    return out;
  };
  await call('/party/create', { auth: 'u', body: { me: { name: '하루', steps: 3000, maxHour: 2000 } } });
  assert.equal((await call('/party/state', { auth: 'u', body: { me: { steps: 3000 } }, headers: { 'X-Firebase-AppCheck': 'good' } })).status, 200);
  assert.equal((await call('/party/state', { auth: 'u', body: { me: {} }, headers: { 'X-Firebase-AppCheck': 'forged' } })).status, 200);
  // 가짜 위치: 칸을 보내지 않고 표시만
  const n = await call('/party/near', { auth: 'u', body: { mock: true } });
  assert.equal(n.json.near, false);
  assert.equal((await db.doc('presence/u1').get()).exists, false);
  const list = await call('/admin/suspects', { auth: 'admin' });
  assert.deepEqual(list.json.items[0].counts, { appcheck: 1, mock: 1 });
  assert.equal(list.json.items[0].days[0].steps, 3000);
  const st = list.json.appCheck[0];
  assert.deepEqual([st.ok, st.bad, st.missing], [1, 1, 2]);
  assert.equal((await call('/admin/suspects', { auth: 'u' })).status, 403);
  // 막기로 바꾸면
  env.APPCHECK_MODE = 'block';
  assert.equal((await call('/party/state', { auth: 'u', body: {} })).status, 401);
  assert.equal((await call('/party/state', { auth: 'u', body: {}, headers: { 'X-Firebase-AppCheck': 'good' } })).status, 200);
  // 응답 · 기록에 토큰을 남기지 않음
  assert.ok(!JSON.stringify((await db.doc('suspects/u1').get()).data()).includes('forged'));
});
