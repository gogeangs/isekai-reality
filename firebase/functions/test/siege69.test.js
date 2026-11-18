// 묶음 69 #279: 공성전은 운영자 스위치로 — 닫힘 · 열기(그다음 토요일부터 격주) · 닫기(다음부터 안 열림) · 테스트 공성전(그 길드만)
const test = require('node:test');
const assert = require('node:assert');
const { MemDb } = require('../src/memdb');
const { GuildService } = require('../src/guild');
const { SiegeService } = require('../src/siege');
const SCH = require('../src/siege_schedule');

const DAY = 86400000;
const H = 3600000;
// 2026-11-19(목) 12시 한국
const T0 = Date.parse('2026-11-19T03:00:00Z');

async function world(at) {
  const db = new MemDb();
  let now = at;
  const clock = () => now;
  const g = new GuildService(db, { now: clock });
  const s = new SiegeService(db, { now: clock, guild: g });
  const mk = async (owner, name) => {
    await g.create(owner, { name, me: { name: owner, level: 40 } });
    await db.doc(`siegeTicket/${owner}`).set({ bank: 20, carry: 0, day: '', dayCounted: 0 });
    return (await db.doc(`guildOf/${owner}`).get()).data().gid;
  };
  return { db, g, s, mk, set: (t) => (now = t) };
}

test.afterEach(() => SCH.useLegacy());

test('닫혀 있으면 공성전이 없음 · 앱에 open false · 시작 시각 없음', async () => {
  SCH.set(null);
  const w = await world(T0);
  await w.mk('ua', '새벽');
  const st = await w.s.state('ua');
  assert.equal(st.siege.open, false);
  assert.equal(st.siege.active, false);
  assert.equal(st.siege.start, null);
  assert.equal(SCH.lastEnded(T0 + 100 * DAY), -1);
  await assert.rejects(w.s.foe('ua', { estate: 'royal' }), /not_siege/);
});

test('열기: 그다음 토요일 0시(한국)부터 2주마다 48시간 · 닫기: 지금 공성전까지만', () => {
  SCH.set(null);
  assert.equal(new Date(SCH.nextSaturday(T0)).toISOString(), '2026-11-20T15:00:00.000Z'); // 11-21(토) 0시
  // 토요일에 켜면 그다음 주 토요일
  assert.equal(new Date(SCH.nextSaturday(Date.parse('2026-11-21T05:00:00Z'))).toISOString(), '2026-11-27T15:00:00.000Z');
  SCH.set(SCH.toggled(T0, true));
  const s0 = Date.parse('2026-11-20T15:00:00Z');
  assert.ok(SCH.isOpen());
  assert.equal(SCH.siegeNo(T0), 0);
  assert.ok(!SCH.siegeActive(T0));
  assert.ok(SCH.siegeActive(s0 + H));
  assert.ok(!SCH.siegeActive(s0 + 2 * DAY));
  assert.equal(SCH.siegeNo(s0 + 3 * DAY), 1);
  assert.equal(SCH.siegeStart(1), s0 + 14 * DAY);
  assert.equal(SCH.lastEnded(s0 + 3 * DAY), 0);
  // 두 번째 공성전 중에 닫음 → 두 번째는 끝까지, 세 번째부터 안 열림
  const mid = s0 + 14 * DAY + H;
  SCH.set(SCH.toggled(mid, false));
  assert.ok(!SCH.isOpen());
  assert.ok(SCH.siegeActive(mid + H));
  assert.ok(!SCH.siegeActive(s0 + 28 * DAY + H));
  assert.equal(SCH.siegeStart(2), Infinity);
  assert.equal(SCH.lastEnded(s0 + 60 * DAY), 1);
  // 다시 열면 번호가 이어짐
  const again = s0 + 40 * DAY;
  SCH.set(SCH.toggled(again, true));
  assert.equal(SCH.siegeNo(again), 2);
  assert.ok(SCH.siegeStart(2) > again);
});

test('테스트 공성전: 그 길드에게만 보이고, 끝나면 그 길드만 정리 (흑등 연맹 그대로)', async () => {
  SCH.set(null);
  const w = await world(T0);
  const ga = await w.mk('ua', '시험단');
  await w.mk('ub', '바깥');
  const world0 = JSON.stringify((await w.s._world()).owners);
  SCH.set(SCH.testStarted(T0, [ga], 2));
  const mine = await w.s.state('ua');
  assert.equal(mine.siege.active, true);
  assert.equal(mine.siege.test, true);
  assert.equal(mine.siege.open, true);
  const other = await w.s.state('ub');
  assert.equal(other.siege.active, false);
  assert.equal(other.siege.open, false);
  const f = await w.s.foe('ua', { estate: 'sol_silver' });
  assert.ok(f);
  await assert.rejects(w.s.foe('ub', { estate: 'sol_silver' }), /not_siege/);
  // 끝내기 → 정리
  w.set(T0 + H);
  SCH.set(SCH.testEnded(T0 + H));
  assert.equal(SCH.lastEnded(T0 + H), 0);
  await w.s.settleDue();
  const after = await w.s._world();
  assert.equal(after.settled, 0);
  assert.equal(JSON.stringify(after.owners), world0, '흑등 연맹은 움직이지 않음');
  // 테스트 중엔 두 번째 테스트 · 정기 공성전 중엔 테스트 안 됨
  SCH.set(SCH.testStarted(T0 + 2 * H, [ga], 1));
  assert.throws(() => SCH.testStarted(T0 + 2 * H + 1, [ga]), /test_now/);
});

test('테스트 공성전이 끼어도 열린 정기 일정은 시각 그대로 · 번호만 하나 뒤로', () => {
  SCH.set(null);
  SCH.set(SCH.toggled(T0, true));
  const s0 = Date.parse('2026-11-20T15:00:00Z');
  SCH.set(SCH.testStarted(T0, ['g1'], 2));
  assert.equal(SCH.siegeNo(T0, 'g1'), 0);
  assert.equal(SCH.siegeNo(T0, 'g2'), 1);
  assert.equal(SCH.siegeStart(1), s0);
  assert.throws(() => SCH.testStarted(s0 + H, ['g1']), /siege_now/);
});
