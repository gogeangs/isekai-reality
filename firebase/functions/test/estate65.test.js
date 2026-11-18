// 묶음 65 #255: 영지 관리 — 시설 · 특산물 · 번영도 · 정책 · 주민 의뢰 · 빼앗겨도 그대로
const test = require('node:test');
const assert = require('node:assert');
const { MemDb } = require('../src/memdb');
const { GuildService } = require('../src/guild');
const { SiegeService, siegeStart, siegeEnd } = require('../src/siege');
const { E } = require('../src/estate');

const DAY = 86400000;
const S0 = siegeStart(0);

async function world(at) {
  const db = new MemDb();
  let now = at;
  const clock = () => now;
  const g = new GuildService(db, { now: clock });
  const s = new SiegeService(db, { now: clock, guild: g });
  const mk = async (owner, name, members = []) => {
    await g.create(owner, { name, me: { name: owner, level: 40 } });
    const st = await g.state(owner, { name: owner, level: 40 });
    for (const m of members) await g.join(m, { code: st.guild.code, me: { name: m, level: 40 } });
    return (await db.doc(`guildOf/${owner}`).get()).data().gid;
  };
  const own = async (estate, gid, name) => {
    const wd = await s._world();
    wd.owners[estate] = { gid, name, emblem: 0, color: 0, since: 0 };
    await db.doc('erbard/world').set(wd);
  };
  return { db, g, s, mk, own, set: (t) => (now = t), add: (ms) => (now += ms), get now() { return now; } };
}
const money = async (w, gid, gold, pool = 0) => {
  const r = w.db.doc(`guilds/${gid}`);
  const x = (await r.get()).data();
  await r.set({ ...x, treasury: gold, matPool: pool });
};

test('시설: 길드장 · 부길드장만 · 금고 금화 + 기부 재료 · 칸 3개 · 공성전 중엔 못 지음 · 금고 기록', async () => {
  const w = await world(siegeEnd(0) + DAY);
  const ga = await w.mk('ua', '새벽', ['ub']);
  await w.own('sol_lily', ga, '새벽');
  await assert.rejects(w.s.estateBuild('ub', { estate: 'sol_lily', kind: 'wall' }), /not_staff/);
  await assert.rejects(w.s.estateBuild('ua', { estate: 'sol_lily', kind: 'wall' }), /no_treasury/);
  await money(w, ga, 100000, 0);
  await assert.rejects(w.s.estateBuild('ua', { estate: 'sol_lily', kind: 'wall' }), /no_mats/);
  // 길드원 기부 (하루 상한)
  await assert.rejects(w.s.estateDonate('ub', { estate: 'sol_lily', mats: { ironShard: E.donateDay + 1 } }), /donate_limit/);
  await w.s.estateDonate('ub', { estate: 'sol_lily', mats: { ironShard: E.donateDay } });
  await w.s.estateDonate('ua', { estate: 'sol_lily', mats: { herb: E.donateDay } });
  let st = await w.s.estateBuild('ua', { estate: 'sol_lily', kind: 'wall' });
  assert.equal(st.estates[0].fac.wall, 1);
  assert.equal(st.treasury, 100000 - E.buildGold[0]);
  assert.equal(st.matPool, 2 * E.donateDay - E.buildMats[0]);
  const g = (await w.db.doc(`guilds/${ga}`).get()).data();
  assert.match(g.tlog.at(-1).what, /백합 들판 성 성벽 1단계/);
  // 다른 지방 특산 시설은 못 지음
  await assert.rejects(w.s.estateBuild('ua', { estate: 'sol_lily', kind: 'fire' }), /bad_kind/);
  await money(w, ga, 100000, 1000);
  await w.s.estateBuild('ua', { estate: 'sol_lily', kind: 'tower' });
  await w.s.estateBuild('ua', { estate: 'sol_lily', kind: 'light' });
  await assert.rejects(w.s.estateBuild('ua', { estate: 'sol_lily', kind: 'market' }), /no_slot/, '마을은 칸 3개');
  // 성벽 · 감시탑 → 수비대 단단
  assert.ok((await w.s._devDefense('sol_lily')) > 0.07);
  // 공성전 중엔 못 지음
  w.set(siegeStart(1) + 3600000);
  await assert.rejects(w.s.estateBuild('ua', { estate: 'sol_lily', kind: 'wall' }), /siege_lock/);
});

test('특산물: 하루에 한 번 길드 창고로 · 길드원 하루 몇 개 · 빼앗기면 그날 몫은 원래 주인 · 시설은 그대로', async () => {
  const w = await world(siegeEnd(0) + DAY);
  const ga = await w.mk('ua', '새벽', ['ub']);
  const gb = await w.mk('uc', '노을');
  await w.own('sol_lily', ga, '새벽');
  await money(w, ga, 100000, 1000);
  await w.s.estateBuild('ua', { estate: 'sol_lily', kind: 'light' });
  w.add(DAY);
  let st = await w.s.estateState('ub');
  const made = st.store.lightRelic;
  assert.ok(made > 0, '풍요(기본 정책) 생산');
  st = await w.s.estateState('ub');
  assert.equal(st.store.lightRelic, made, '같은 날 두 번 안 생김');
  const r = await w.s.estateTake('ub', { mat: 'lightRelic', n: 99 });
  assert.equal(r.got.lightRelic, Math.min(made, E.takePerDay));
  await assert.rejects(w.s.estateTake('ub', { mat: 'lightRelic' }), /take_limit|empty/);
  // 공성전 결과로 빼앗김: 그날 몫은 새벽 창고, 시설 · 번영도는 노을에게 그대로
  w.add(DAY);
  const wd = await w.s._world();
  await w.s._produceAll(wd);
  const before = ((await w.db.doc(`guilds/${ga}`).get()).data().store || {}).lightRelic;
  await w.own('sol_lily', gb, '노을');
  st = await w.s.estateState('uc');
  assert.equal(st.estates[0].fac.light, 1);
  assert.equal(((await w.db.doc(`guilds/${ga}`).get()).data().store || {}).lightRelic, before);
  assert.equal((st.store || {}).lightRelic || 0, 0, '그날 몫은 이미 원래 주인에게');
});

test('정책: 공성전이 끝난 뒤 영지마다 한 번 · 다음 공성전 끝까지 · 안 고르면 풍요', async () => {
  const w = await world(siegeEnd(0) + DAY);
  const ga = await w.mk('ua', '새벽');
  await w.own('sol_lily', ga, '새벽');
  let st = await w.s.estateState('ua');
  assert.equal(st.estates[0].policy, 'plenty');
  assert.equal(st.estates[0].canPolicy, true);
  st = await w.s.estatePolicy('ua', { estate: 'sol_lily', kind: 'defense' });
  assert.equal(st.estates[0].policy, 'defense');
  await assert.rejects(w.s.estatePolicy('ua', { estate: 'sol_lily', kind: 'trade' }), /chosen/);
  assert.ok((await w.s._devDefense('sol_lily')) > 0);
  // 다음 공성전 중에도 그대로, 끝나면 다시 고름 (안 고르면 풍요)
  w.set(siegeStart(1) + 3600000);
  assert.equal((await w.s.estateState('ua')).estates[0].policy, 'defense');
  w.set(siegeEnd(1) + 3600000);
  st = await w.s.estateState('ua');
  assert.equal(st.estates[0].policy, 'plenty');
  assert.equal(st.estates[0].canPolicy, true);
});

test('주민 의뢰: 함께 걸은 걸음 → 다 걸으면 번영도 · 보상 우편 · 다음 의뢰 · 번영 단계가 지도에', async () => {
  const w = await world(siegeEnd(0) + DAY);
  const ga = await w.mk('ua', '새벽', ['ub']);
  await w.own('sol_lily', ga, '새벽');
  await w.s.tickets('ua', { steps: 100 });
  await w.s.tickets('ua', { steps: 12100 });
  await w.s.tickets('ub', { steps: 100 });
  await w.s.tickets('ub', { steps: 8100 });
  let st = await w.s.estateState('ua');
  assert.equal(st.estates[0].request.no, 1, '2만 보 → 첫 의뢰 끝');
  const mails = await w.db.collection('inbox/u_ub/msgs').get();
  assert.ok(mails.docs.some((d) => /고마워요/.test(d.data().title)));
  // 사냥 · 기부로 번영도 → 고을
  for (let i = 0; i < E.huntDay + 2; i++) await w.s.estateHunt('ub', { estate: 'sol_lily' });
  const d = await w.s._dev('sol_lily');
  assert.equal(d.prosp, E.request + E.huntDay * E.hunt, '사냥은 하루 상한');
  await w.s._prosper('sol_lily', 300);
  st = await w.s.estateState('ua');
  assert.equal(st.estates[0].stage, 1);
  assert.equal(st.estates[0].slots, 4);
  assert.equal(st.stages.sol_lily, 1);
  assert.equal((await w.s.state('ua', {})).stages.sol_lily, 1);
  // 진짜 앱 확인 실패 걸음은 빼기
  const before = (await w.s._dev('sol_lily')).req.steps;
  await w.s.tickets('ua', { steps: 20000, __bad: true });
  assert.equal((await w.s._dev('sol_lily')).req.steps, before);
});

test('묶음 66: 주민 의뢰는 돕는 영지 한 곳에만 · 안 고르면 진행이 가장 많은 곳 · 바꾸면 그때부터', async () => {
  const w = await world(siegeEnd(0) + DAY);
  const ga = await w.mk('ua', '새벽', ['ub']);
  await w.own('sol_lily', ga, '새벽');
  await w.own('sol_bell', ga, '새벽');
  await w.s.tickets('ua', { steps: 100 });
  await w.s.tickets('ua', { steps: 5100 });
  const a1 = (await w.s._dev('sol_lily')).req.steps;
  const b1 = (await w.s._dev('sol_bell')).req.steps;
  assert.equal(a1 + b1, 5000, '한 곳에만');
  await assert.rejects(w.s.estateHelp('ub', { estate: 'sol_bell' }), /not_staff/);
  const st = await w.s.estateHelp('ua', { estate: a1 ? 'sol_bell' : 'sol_lily' });
  assert.equal(st.help, a1 ? 'sol_bell' : 'sol_lily');
  await w.s.tickets('ua', { steps: 8100 });
  assert.equal((await w.s._dev(a1 ? 'sol_lily' : 'sol_bell')).req.steps, 5000, '앞서 쌓인 건 그대로');
  assert.equal((await w.s._dev(st.help)).req.steps, 3000);
});
