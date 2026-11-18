// 묶음 65 #251: 공성전 다듬기 — 집결 깃발 · 엿보기 · 공성 망치 · 성벽 보수 · 전황 소식 · 선봉장 · 흑등 최소 · 왕관의 무게
const test = require('node:test');
const assert = require('node:assert');
const { MemDb } = require('../src/memdb');
const { GuildService } = require('../src/guild');
const { SiegeService, siegeStart, siegeEnd, T } = require('../src/siege');

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
  return { db, g, s, mk, set: (t) => (now = t), add: (ms) => (now += ms), get now() { return now; } };
}

async function fightAs(s, uid, args) {
  await s.db.doc(`siegeTicket/${uid}`).set({ bank: 20, carry: 0, day: '', dayCounted: 0 });
  await s.db.doc(`fightTok/${uid}`).set({ estate: args.estate, slot: Number(args.slot), at: s.now() - 10000 });
  return s.fight(uid, args);
}

const own = async (w, estate, gid, name) => {
  const wd = await w.s._world();
  wd.owners[estate] = { gid, name, emblem: 0, color: 0, since: 0 };
  await w.db.doc('erbard/world').set(wd);
};

test('집결 깃발: 길드장 · 부길드장만 · 공성전 때만 · 6시간마다 바꿈 · 게시판 소식', async () => {
  const w = await world(S0 - DAY);
  await w.mk('ua', '새벽', ['ub']);
  await assert.rejects(w.s.rally('ua', { estate: 'sol_silver' }), /not_siege/);
  w.set(S0 + 3600000);
  await assert.rejects(w.s.rally('ub', { estate: 'sol_silver' }), /not_staff/);
  let st = await w.s.rally('ua', { estate: 'sol_silver' });
  assert.equal(st.rally.estate, 'sol_silver');
  assert.match(st.news[0].text, /은방패 요새에 집결/);
  await assert.rejects(w.s.rally('ua', { estate: 'sol_lily' }), /rally_wait/);
  w.add(6 * 3600000);
  st = await w.s.rally('ua', { estate: 'sol_lily' });
  assert.equal(st.rally.estate, 'sol_lily');
  const f = await (async () => {
    await w.db.doc('siegeTicket/ua').set({ bank: 5, carry: 0, day: '', dayCounted: 0 });
    return w.s.foe('ua', { estate: 'sol_silver' });
  })();
  assert.equal(f.rally, false);
});

test('공성 망치 · 성벽 보수: 공성전 동안 걸음 게이지 → 집결 영지 남은 자리 약하게 · 우리 영지 깨진 자리 되살림', async () => {
  const w = await world(S0 + 3600000);
  const ga = await w.mk('ua', '새벽');
  const gb = await w.mk('ux', '노을');
  await own(w, 'sol_lily', gb, '노을');
  await w.s.rally('ua', { estate: 'sol_lily' });
  // ua 가 sol_lily 두 자리를 깸 → 노을 게시판 「공격받고 있어요」(3시간에 한 번)
  await fightAs(w.s, 'ua', { estate: 'sol_lily', slot: 0, win: true });
  await fightAs(w.s, 'ua', { estate: 'sol_lily', slot: 1, win: true });
  let gx = (await w.db.doc(`guilds/${gb}`).get()).data();
  assert.equal(gx.news.filter((x) => /공격받고/.test(x.text)).length, 1);
  // 새벽 걸음 → 한 칸 (5명 몫) → 공성 망치: sol_lily 셋째 자리가 약해짐
  const size = T.gaugePerHead * 5;
  await w.s.state('ua', { steps: 1000, device: 'da' });
  let st = await w.s.state('ua', { steps: 1000 + size, device: 'da' });
  // 묶음 66: 힘은 쌓여 있고 길드장이 고름
  assert.equal(st.gauge.power, 1);
  assert.equal(st.gauge.rams, 0);
  assert.ok(st.news.some((x) => /게이지가 가득 찼어요/.test(x.text)));
  await assert.rejects(w.s.usePower('ux', { kind: 'ram' }), /no_power/);
  st = await w.s.usePower('ua', { kind: 'ram' });
  assert.equal(st.gauge.rams, 1);
  assert.equal(st.gauge.power, 0);
  await assert.rejects(w.s.usePower('ua', { kind: 'ram' }), /no_power/);
  assert.deepEqual(st.weak.sol_lily, [2]);
  assert.ok(st.news.some((x) => /공성 망치로 백합 들판 성 셋째 자리/.test(x.text)));
  await w.db.doc('siegeTicket/ua').set({ bank: 5, carry: 0, day: '', dayCounted: 0 });
  const f = await w.s.foe('ua', { estate: 'sol_lily' });
  assert.equal(f.slot, 2);
  assert.equal(f.weakened, true);
  assert.equal(f.rally, true);
  // 진짜 앱 확인 실패한 요청의 걸음은 넣지 않음
  st = await w.s.state('ua', { steps: 1000 + 3 * size, device: 'da', __bad: true });
  assert.equal(st.gauge.rams, 1);
  // 노을: 걸음 → 성벽 보수 (가장 많이 깨진 우리 영지, 공성전에 한 번)
  await w.s.state('ux', { steps: 10, device: 'dx' });
  st = await w.s.state('ux', { steps: 10 + size, device: 'dx' });
  assert.deepEqual(st.gauge.repairs, []);
  st = await w.s.usePower('ux', { kind: 'repair', estate: 'sol_lily' });
  assert.deepEqual(st.gauge.repairs, ['sol_lily']);
  assert.equal(st.defense.sol_lily, 1);
  assert.ok(st.news.some((x) => /성벽 보수로 백합 들판 성 둘째 자리를 되살렸어요/.test(x.text)));
  const run = (await w.db.doc('siegeRun/0_sol_lily').get()).data();
  assert.deepEqual(run.g[ga].broken, [0]);
  gx = (await w.db.doc(`guilds/${ga}`).get()).data();
  assert.ok(gx.news.some((x) => /성벽이 보수됐어요/.test(x.text)));
  // 엿보기
  const p = await w.s.peek('ua', { estate: 'sol_lily' });
  assert.deepEqual(p.slots.map((x) => x.broken), [true, false, false, false, false]);
  assert.equal(p.slots[2].weak, true);
  assert.equal(p.slots[0].kind, 'empty');
  const pn = await w.s.peek('ua', { estate: 'sol_silver' });
  assert.deepEqual(pn.slots.map((x) => x.kind), ['blackGuard', 'blackGuard', 'blackGuard', 'blackGuard', 'blackCaptain']);
});

test('선봉장: 참여한 길드의 길드장 · 가장 많이 깬 사람은 소식에 이름만 · 우편 op', async () => {
  const w = await world(S0 + 3600000);
  await w.mk('ua', '새벽', ['ub', 'uc']);
  await fightAs(w.s, 'ub', { estate: 'sol_silver', slot: 0, win: true });
  w.add(1000);
  await fightAs(w.s, 'uc', { estate: 'sol_silver', slot: 1, win: true });
  w.add(1000);
  await fightAs(w.s, 'uc', { estate: 'sol_silver', slot: 2, win: false });
  await fightAs(w.s, 'ub', { estate: 'sol_silver', slot: 2, win: true });
  await fightAs(w.s, 'uc', { estate: 'sol_silver', slot: 3, win: true });
  w.set(siegeEnd(0) + 1000);
  const st = await w.s.state('ua');
  const mail = (uid) => w.db.collection(`inbox/u_${uid}/msgs`).get().then((q) => q.docs.map((d) => d.data()).filter((m) => m.op && m.op.vanguard === 0));
  assert.equal((await mail('ua')).length, 1, '길드장이 칭호');
  assert.equal((await mail('ub')).length, 0);
  assert.equal((await mail('uc')).length, 0);
  assert.ok(Object.values(st.last.vanguards).includes('ua'));
  assert.ok(st.news.some((x) => /가장 많이 깬 사람 · ub님/.test(x.text)), 'ub 2 · uc 2 → 먼저 깬 ub');
});

test('흑등 연맹은 늘 3곳 이상 · 왕관의 무게: 세 번 연속이면 왕성부터 노림', async () => {
  const w = await world(S0 - DAY);
  const ga = await w.mk('ua', '새벽');
  const wd = await w.s._world();
  for (const e of T.estates) if (wd.owners[e.id] && wd.owners[e.id].gid === 'npc') wd.owners[e.id] = { gid: ga, name: '새벽' };
  for (const e of T.estates) if (!wd.owners[e.id]) wd.owners[e.id] = { gid: ga, name: '새벽' };
  wd.crown = ga;
  wd.crownStreak = 2;
  await w.db.doc('erbard/world').set(wd);
  w.set(siegeEnd(0) + 1000);
  const st = await w.s.state('ua');
  const npc = Object.values(st.owners).filter((o) => o && o.gid === 'npc').length;
  assert.ok(npc >= T.npcMin, `흑등 ${npc}곳`);
  assert.equal(st.owners.royal.gid, 'npc', '세 번째 왕관 → 왕성을 먼저');
});
