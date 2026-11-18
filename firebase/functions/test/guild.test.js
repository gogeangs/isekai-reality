const test = require('node:test');
const assert = require('node:assert');
const { MemDb } = require('../src/memdb');
const { GuildService, G, levelOf, sizeOf, starOf, raidOf } = require('../src/guild');
const { AdminService } = require('../src/admin');
const { MarketService } = require('../src/market');

const T0 = Date.parse('2026-11-18T03:00:00Z');

function setup() {
  const db = new MemDb();
  let now = T0;
  const g = new GuildService(db, { now: () => now, rand: (() => { let i = 0; return () => ((i++ * 0.37) % 1); })() });
  const a = new AdminService(db, { now: () => now });
  return { db, g, a, at: (ms) => (now = ms), get now() { return now; } };
}
const me = (name, steps = 0, extra = {}) => ({ name, level: 30, steps, ...extra });
const inbox = async (db, uid) => (await db.collection(`inbox/u_${uid}/msgs`).get()).docs.map((d) => d.data());

test('길드 규칙: 레벨(인원에 맞춘 걸음) · 크기 20→30 · 회관 ★ · 레이드 차례', () => {
  assert.equal(levelOf(0, 1), 1);
  assert.equal(levelOf(G.LEVEL_PER_HEAD[2] * 5, 1), 2, '적은 인원도 5명 몫');
  assert.equal(levelOf(G.LEVEL_PER_HEAD[4] * 10, 10), 4);
  assert.deepEqual([1, 3, 5, 7, 9, 10].map(sizeOf), [20, 22, 24, 26, 28, 30]);
  assert.equal(starOf(2, 99999), 1, '★2 는 Lv.3 부터');
  assert.equal(starOf(3, 3000), 2);
  assert.equal(starOf(10, 30000), 4);
  assert.deepEqual([0, 1, 2, 3].map((k) => raidOf(require('../src/rules').weekKey(T0 + k * 7 * 86400000)).id), ['raidDragon', 'raidLich', 'raidTortoise', 'raidDragon']);
});

test('만들기 · 이름 금칙어 · 공개 목록 · 초대 코드 · 같은 휴대폰 · 길드장 넘기기 · 부길드장 · 내보내기', async () => {
  const { db, g } = setup();
  await assert.rejects(g.create('a', { name: '시 발 길드', me: me('하루') }), /banned_word/);
  const s = await g.create('a', { name: '새벽 등불', open: true, me: me('하루') });
  assert.equal(s.guild.role, 'owner');
  assert.equal(s.guild.level, 1);
  const list = await g.list('z', { q: '등불' });
  assert.equal(list.items.length, 1);
  await g.join('b', { gid: list.items[0].gid, me: me('별') });
  await db.doc('users/a').set({ devices: ['d1'] });
  await db.doc('users/c').set({ devices: ['d1'] });
  await assert.rejects(g.join('c', { code: s.guild.code, me: me('달') }), /same_device/);
  await g.join('d', { code: s.guild.code.toLowerCase(), me: me('해') });
  await assert.rejects(g.kick('b', { target: 'd' }), /not_staff/);
  await g.role('a', { target: 'b', role: 'vice' });
  await g.kick('b', { target: 'd' });
  await assert.rejects(g.kick('b', { target: 'a' }), /not_owner/);
  const t = await g.role('a', { target: 'b', role: 'owner' });
  assert.equal(t.guild.role, 'member');
  assert.equal((await g.state('b')).guild.role, 'owner');
  await g.leave('b');
  assert.equal((await g.state('a')).guild.role, 'owner', '길드장이 나가면 다음 사람');
});

test('걸음 → 길드 레벨 · 주간 목표 등불 인장 · 같은 휴대폰 걸음은 한 계정만 · 숫자 대신 진행 비율', async () => {
  const { db, g } = setup();
  await g.create('a', { name: '걷는 사람들', me: me('하루') });
  let v = await g.state('a', me('하루', 30000, { device: 'x' }));
  assert.equal(v.guild.level, 1);
  assert.ok(v.guild.progress > 0 && v.guild.progress < 1);
  v = await g.state('a', me('하루', 160000, { device: 'x' }));
  assert.equal(v.guild.level, 2);
  assert.equal(v.walk.done[0], true);
  const c = await g.claim('a', { kind: 'walk', tier: 0 });
  assert.deepEqual(c.reward, { seal: G.WEEK_SEALS[0] });
  await assert.rejects(g.claim('a', { kind: 'walk', tier: 0 }), /claimed/);
  await assert.rejects(g.claim('a', { kind: 'walk', tier: 5 }), /bad_tier/);
  assert.equal(v.members[0].steps, undefined, '다른 사람 정확한 걸음 대신 이번 주 걸음만');
});

test('회관: 기부 → 점수 · 등불 인장 · 하루 한도 · 한마디(금칙어) · 꾸미기 4자리', async () => {
  const { g } = setup();
  await g.create('a', { name: '회관 짓기', me: me('하루') });
  const d = await g.donate('a', { gold: 400, mats: { herb: 5 } });
  assert.equal(d.points, 40 + 10);
  assert.equal(d.seals, 2);
  await assert.rejects(g.donate('a', { gold: 4000 }), /donate_limit/);
  await assert.rejects(g.line('a', { text: '시발' }), /banned_word/);
  const v = await g.line('a', { text: '오늘도 걸어요' });
  assert.equal(v.members[0].line, '오늘도 걸어요');
  await assert.rejects(g.decoPlace('a', { slot: 0, id: 'fountain' }), /bad_deco/);
  await g.decoAdd('a', { id: 'fountain' });
  const p = await g.decoPlace('a', { slot: 2, id: 'fountain' });
  assert.deepEqual(p.hall.slots, [null, null, 'fountain', null]);
});

test('레이드: Lv.4 부터 · 도전권(걸음) · 피해가 합쳐짐 · 쓰러뜨리면 보상 · 처음이면 칭호 우편 · 거인은 한 번', async () => {
  const { db, g, at } = setup();
  await g.create('a', { name: '레이드', me: me('하루') });
  await g.join('b', { code: (await g.state('a')).guild.code, me: me('별') });
  await assert.rejects(g.raidHit('a', { damage: 100 }), /need_level/);
  await g.state('a', me('하루', 400000));
  await g.state('b', me('별', 400000));
  const v = await g.state('a', me('하루', 400000));
  assert.equal(v.guild.level >= 4, true);
  let r;
  for (let day = 0; day < 3 && !(r && r.giant.defeated); day++) {
    at(T0 + day * 86400000);
    for (const [u, n] of [['a', '하루'], ['b', '별']]) {
      for (let k = 0; k < 3; k++) {
        try {
          r = await g.raidHit(u, { giant: true, damage: 1e9, me: me(n, 400000) });
        } catch (e) {
          if (e.code !== 'no_ticket' && e.code !== 'defeated') throw e;
        }
      }
    }
  }
  assert.equal(r.giant.defeated, true, '둘이 이틀 동안 나눠 쓰러뜨림');
  if (r.giant.defeated) {
    assert.equal(r.guild.giantDone, true);
    const c = await g.claim('a', { kind: 'giant' });
    assert.equal(c.reward.raid, 'raidGiant');
    assert.ok(['gold', 'silver', 'bronze'].includes(c.reward.chest));
    assert.ok((await inbox(db, 'b')).some((m) => m.op && m.op.title === 'raidGiant'));
    await assert.rejects(g.raidHit('a', { giant: true, damage: 1 }), /defeated/);
  } else {
    assert.ok(r.giant.progress > 0);
  }
});

test('운영자: 제재 4단계(우편 · 기록) · 풀기 · 내 상태 · 이름 바꾸기 · 공지 · 모두에게 보상 · 행동 기록', async () => {
  const { db, a } = setup();
  await assert.rejects(a.sanction('op@x', { uid: 'user01', level: 5, reason: 'cash' }), /bad_level/);
  await a.sanction('op@x', { uid: 'user01', level: 2, reason: 'boost', memo: '같은 휴대폰 의심' });
  let st = await a.myStatus('user01');
  assert.equal(st.level, 2);
  assert.equal(st.reason, '몰아주기');
  const m = await inbox(db, 'user01');
  assert.match(m[0].title, /함께하는 기능 7일 제한/);
  assert.match(m[0].body, /14일 안에/);
  await a.unsanction('op@x', { uid: 'user01', until: '2026-11-20T00:00:00Z' });
  await a.unsanction('op@x', { uid: 'user01' });
  st = await a.myStatus('user01');
  assert.equal(st.level, 0);
  const h = await a.sanctions({ uid: 'user01' });
  assert.equal(h.history.length, 3);
  await a.rename('op@x', { uid: 'user01', target: 'pet', id: 'p3' });
  assert.deepEqual((await inbox(db, 'user01')).pop().op, { rename: { target: 'pet', id: 'p3' } });
  await a.notice('op@x', { title: '점검 안내', body: '내일 새벽 점검해요', from: T0 - 1000, to: T0 + 86400000 });
  assert.equal((await a.notices()).items.length, 1);
  await a.broadcast('op@x', { title: '점검 보상', reward: { gold: 500, manaStone: 10, hack: 9 } });
  const bc = await a.activeBroadcasts();
  assert.deepEqual(bc[0].reward, { gold: 500, manaStone: 10 });
  assert.match(bc[0].id, /^bc_/);
  const log = await a.logs();
  assert.deepEqual(log.items.map((x) => x.action).sort(), ['broadcast', 'notice', 'period', 'release', 'rename', 'sanction']);
});

test('운영자: 잘못된 거래 되돌리기 — 산 사람 금화 돌려받고 물건 거둠 · 판 사람 물건 돌려받고 금화 거둠 · 한 번만', async () => {
  const { db, a } = setup();
  await db.doc('marketLog/L1').set({ listing: 'm1', seller: 'sel', buyer: 'buy', kind: 'mat', key: 'herb', name: '약초', qty: 3, price: 60, fee: 6, at: T0 });
  await a.revert('op@x', { logId: 'L1' });
  const b = (await inbox(db, 'buy'))[0];
  assert.deepEqual(b.reward, { gold: 60 });
  assert.deepEqual(b.op, { take: { mats: { herb: 3 } } });
  const s = (await inbox(db, 'sel'))[0];
  assert.deepEqual(s.reward, { herb: 3 });
  assert.deepEqual(s.op, { take: { gold: 54 } });
  await assert.rejects(a.revert('op@x', { logId: 'L1' }), /already_reverted/);
});

test('거래 범위(묶음 59): 받은 선물 장비 · 지역 무기 조각은 못 올림 · 공방 물약은 올림', async () => {
  const zlib = require('zlib');
  const db = new MemDb();
  const s = new MarketService(db, { now: () => T0 });
  const snap = {
    'history.v1': JSON.stringify([{ date: '2026-11-18', gains: { gold: 500, cartWheel: 3 }, spends: {} }]),
    'json.armory': JSON.stringify({ items: [{ uid: 'eq1', base: 'ironSword', grade: 'white', gift: true }, { uid: 'eq2', base: 'ironSword', grade: 'white' }], equipped: {} }),
    'json.alchemy': JSON.stringify({ potions: { antidote: 4 } }),
  };
  await db.doc('users/u1/parts/g1_0').set({ gen: 'g1', data: zlib.gzipSync(Buffer.from(JSON.stringify(snap))).toString('base64') });
  await db.doc('users/u1').set({ gen: 'g1', updatedAt: new Date(T0), devices: ['x'] });
  await assert.rejects(s.list('u1', { kind: 'equip', key: 'eq1', mode: 'fixed', price: 30 }), /not_tradable/);
  await s.list('u1', { kind: 'equip', key: 'eq2', mode: 'fixed', price: 30 });
  await assert.rejects(s.list('u1', { kind: 'mat', key: 'cartWheel', qty: 1, mode: 'fixed', price: 30 }), /not_tradable/);
  const r = await s.list('u1', { kind: 'alc', key: 'antidote', qty: 2, mode: 'fixed', price: 120 });
  assert.equal(r.listing.kind, 'alc');
});
