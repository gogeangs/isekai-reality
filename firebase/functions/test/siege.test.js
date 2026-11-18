const test = require('node:test');
const assert = require('node:assert');
const { MemDb } = require('../src/memdb');
const { GuildService } = require('../src/guild');
const { SiegeService, siegeNo, siegeStart, siegeEnd, siegeActive, lastEnded, T } = require('../src/siege');

const DAY = 86400000;
const S0 = siegeStart(0); // 2026-11-28 0시 (한국)

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
  return { db, g, s, mk, set: (t) => (now = t), get now() { return now; } };
}

async function clearWild(s, uid, estate) {
  for (let k = 0; k < 5; k++) {
    const f = await s.foe(uid, { estate });
    assert.equal(f.kind, 'wild');
    await s.fight(uid, { estate, slot: f.slot, win: true });
  }
}

test('공성전 때: 2주마다 토·일 48시간 · 번호', () => {
  assert.equal(new Date(S0).toISOString(), '2026-11-27T15:00:00.000Z');
  assert.equal(siegeNo(S0 - DAY), 0);
  assert.ok(!siegeActive(S0 - 1));
  assert.ok(siegeActive(S0));
  assert.ok(siegeActive(S0 + 47 * 3600000));
  assert.ok(!siegeActive(siegeEnd(0)));
  assert.equal(siegeNo(siegeEnd(0)), 1);
  assert.equal(siegeStart(1) - S0, 14 * DAY);
  assert.equal(lastEnded(siegeEnd(0) - 1), -1);
  assert.equal(lastEnded(siegeEnd(0)), 0);
  assert.equal(T.estates.length, 31);
  assert.equal(T.estates.filter((e) => e.npcStart).length, 6);
});

test('빈 영지: 야생 수비대 5자리를 깨면 길드가 차지 · 세 곳까지 · 흑등 영지는 공성전 때만', async () => {
  const w = await world(S0 - 5 * DAY);
  const ga = await w.mk('ua', '새벽', ['ub']);
  let st = await w.s.state('ua');
  assert.equal(st.owners.royal.gid, 'npc');
  assert.equal(st.owners.sol_lily, null);
  // 둘이 나눠서
  await w.s.fight('ua', { estate: 'sol_lily', slot: 0, win: true });
  await w.s.fight('ua', { estate: 'sol_lily', slot: 1, win: false });
  await w.s.fight('ub', { estate: 'sol_lily', slot: 1, win: true });
  await assert.rejects(w.s.fight('ub', { estate: 'sol_lily', slot: 0, win: true }), /broken/);
  await w.s.fight('ub', { estate: 'sol_lily', slot: 2, win: true });
  await w.s.fight('ua', { estate: 'sol_lily', slot: 3, win: true });
  const r = await w.s.fight('ua', { estate: 'sol_lily', slot: 4, win: true });
  assert.ok(r.captured);
  st = await w.s.state('ub');
  assert.equal(st.owners.sol_lily.gid, 'mine');
  assert.deepEqual(st.guild.estates, ['sol_lily']);
  await clearWild(w.s, 'ua', 'sol_bell');
  await clearWild(w.s, 'ua', 'dor_wind');
  const four = await (async () => {
    for (let k = 0; k < 5; k++) await w.s.fight('ua', { estate: 'mor_mill', slot: k, win: true });
    return (await w.s.state('ua')).owners.mor_mill;
  })();
  assert.equal(four, null, '세 곳까지');
  await assert.rejects(w.s.foe('ua', { estate: 'sol_silver' }), /not_siege/);
  assert.ok(ga);
});

test('공성전: 수비대 배치(분신 + 동료 2) · 공성 중엔 못 바꿈 · 다섯 자리를 먼저 깬 길드가 차지 · 보상 우편', async () => {
  const w = await world(S0 - 5 * DAY);
  await w.mk('ua', '새벽', ['ub']);
  await w.mk('uc', '노을', ['ud']);
  await clearWild(w.s, 'ua', 'sol_lily');
  let st = await w.s.garrison('ub', { estate: 'sol_lily', slot: 0, snap: { name: '별하', level: 45, job: 'knight', allies: [{ name: '도윤', level: 40 }, { name: '하린', level: 40 }, { name: '셋째', level: 1 }] } });
  assert.equal(st.garrisons.sol_lily[0].name, '별하');
  assert.deepEqual(st.garrisons.sol_lily[0].allies, ['도윤', '하린'], '동료는 둘까지');
  assert.equal(st.placed, 'sol_lily');
  await assert.rejects(w.s.garrison('uc', { estate: 'sol_lily', slot: 1, snap: {} }), /not_yours/);
  // 공성전 시작
  w.set(S0 + 3600000);
  await assert.rejects(w.s.garrison('ub', { estate: 'sol_lily', slot: 1, snap: {} }), /siege_lock/);
  const f0 = await w.s.foe('uc', { estate: 'sol_lily' });
  assert.equal(f0.kind, 'siege');
  assert.equal(f0.guard.name, '별하');
  assert.equal(f0.guard.allies.length, 2);
  for (let k = 0; k < 5; k++) await w.s.fight(k % 2 ? 'ud' : 'uc', { estate: 'sol_lily', slot: k, win: true });
  // 흑등 영지도
  const fn = await w.s.foe('ua', { estate: 'sol_silver' });
  assert.ok(fn.npc);
  await assert.rejects(w.s.foe('ua', { estate: 'royal' }), /royal_locked/);
  st = await w.s.state('uc');
  assert.equal(st.used, 3);
  assert.deepEqual(st.run.sol_lily, [0, 1, 2, 3, 4]);
  // 끝나고 정리
  w.set(siegeEnd(0) + 1000);
  st = await w.s.state('uc');
  assert.equal(st.owners.sol_lily.gid, 'mine');
  assert.equal(st.last.no, 0);
  assert.ok(st.last.changes.some((c) => c.estate === 'sol_lily' && c.toName === '노을'));
  assert.ok(st.last.changes.some((c) => c.to === 'npc'), '흑등 연맹이 빈 영지 하나를 가져감');
  const box = (await w.db.collection('inbox/u_uc/msgs').get()).docs.map((d) => d.data());
  assert.ok(box.some((m) => m.reward.lanternSeal === T.siegeSealsPerEstate + T.siegeTicketSeals));
  const lost = (await w.db.collection('inbox/u_ua/msgs').get()).docs.map((d) => d.data());
  assert.equal(lost.length, 0, '영지를 잃고 공성권도 안 쓴 길드는 보상 없음');
  // 수비대는 새 주인으로 비워짐
  const gs = (await w.db.doc('garrison/sol_lily').get()).data();
  assert.ok(gs.slots.every((x) => x === null));
});

test('왕성: 영지 2곳 이상이면 공성 · 차지하면 왕성 상자 + 칭호 + 왕관 · 수수료 몫은 길드 금고에', async () => {
  const w = await world(S0 - 5 * DAY);
  const ga = await w.mk('ua', '새벽', ['ub']);
  await clearWild(w.s, 'ua', 'sol_lily');
  await clearWild(w.s, 'ub', 'sol_bell');
  await w.db.collection('marketLog').add({ fee: 1000, at: S0 - DAY, seller: 'x', buyer: 'y' });
  w.set(S0 + 1000);
  for (let k = 0; k < 5; k++) await w.s.fight('ua', { estate: 'royal', slot: k, win: true });
  w.set(siegeEnd(0) + 1000);
  const st = await w.s.state('ua');
  assert.equal(st.owners.royal.gid, 'mine');
  assert.ok(st.owners.royal.crown);
  const box = (await w.db.collection('inbox/u_ub/msgs').get()).docs.map((d) => d.data());
  const chest = box.find((m) => m.op && m.op.title === 'erbardCrown');
  assert.ok(chest);
  assert.equal(chest.reward.gold, 1000);
  // 왕성 3 + 영지 2 = 5곳분 × 10
  assert.ok(box.some((m) => m.reward.lanternSeal === 5 * T.siegeSealsPerEstate));
  const g = (await w.db.doc(`guilds/${ga}`).get()).data();
  assert.equal(g.treasury, 100);
  assert.equal(st.guild.treasury, 100);
});

test('연맹: 길드 3곳 · 연맹 영지는 못 침 · 점수를 나눔 · 공성전 4번마다 다시', async () => {
  const w = await world(S0 - 5 * DAY);
  await w.mk('ua', '새벽');
  await w.mk('uc', '노을');
  let st = await w.s.alliance('ua', { action: 'create', name: '별빛 연맹' });
  const code = st.alliance.code;
  await assert.rejects(w.s.alliance('ub', { action: 'join', code }), /no_guild/);
  st = await w.s.alliance('uc', { action: 'join', code });
  assert.deepEqual(st.alliance.guilds, ['새벽', '노을']);
  await clearWild(w.s, 'ua', 'sol_lily');
  w.set(S0 + 1000);
  await assert.rejects(w.s.foe('uc', { estate: 'sol_lily' }), /ally/);
  assert.equal((await w.s.state('uc')).owners.sol_lily.gid, 'ally');
  w.set(siegeEnd(0) + 1000);
  await w.s.state('ua');
  const box = (await w.db.collection('inbox/u_uc/msgs').get()).docs.map((d) => d.data());
  assert.ok(box.some((m) => m.reward.lanternSeal === T.siegeSealsPerEstate), '연맹 길드도 영지 몫을 나눔');
  w.set(siegeStart(1) + 1000);
  await assert.rejects(w.s.alliance('uc', { action: 'leave' }), /alliance_locked/);
  w.set(siegeStart(4) + 1000);
  st = await w.s.alliance('uc', { action: 'leave' });
  assert.equal(st.alliance, null);
});

test('제재 2단계 이상은 공성 · 수비대 못 씀', async () => {
  const w = await world(S0 - 5 * DAY);
  await w.mk('ua', '새벽');
  await w.db.doc('status/ua').set({ level: 2, until: new Date(S0 + 30 * DAY).toISOString() });
  await assert.rejects(w.s.foe('ua', { estate: 'sol_lily' }), /restricted/);
  await assert.rejects(w.s.fight('ua', { estate: 'sol_lily', slot: 0, win: true }), /restricted/);
});
