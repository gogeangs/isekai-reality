const test = require('node:test');
const assert = require('node:assert');
const { MemDb } = require('../src/memdb');
const { PartyService } = require('../src/party');
const R = require('../src/rules');

// 2026-11-18(수) 12:00 KST
const T0 = Date.parse('2026-11-18T03:00:00Z');

function setup() {
  const db = new MemDb();
  let now = T0;
  const s = new PartyService(db, { now: () => now, rand: (() => { let i = 0; return () => ((i++ * 0.37) % 1); })() });
  return { db, s, at: (ms) => (now = ms), get now() { return now; } };
}

const me = (name, steps = 0, device) => ({ name, level: 22, steps, device });

test('날짜 · 주: 한국 시간, 월요일에 새로', () => {
  assert.equal(R.dayKey(T0), '2026-11-18');
  assert.equal(R.weekKey(T0), '2026-11-16');
  assert.equal(R.weekKey(Date.parse('2026-11-22T14:59:00Z')), '2026-11-16'); // 일 23:59
  assert.equal(R.weekKey(Date.parse('2026-11-22T15:00:00Z')), '2026-11-23'); // 월 00:00
  const b = [0, 1, 2, 3, 4].map((k) => R.bossOf(R.weekKey(T0 + k * 7 * 86400000)));
  assert.deepEqual(new Set(b.slice(0, 4).map((x) => x.id)).size, 4);
  assert.equal(b[4].id, b[0].id);
  assert.equal(b[4].encounter, b[0].encounter + 1);
});

test('만들기 · 초대 코드로 들어가기 · 4명까지 · 한 번에 한 파티', async () => {
  const { s } = setup();
  const a = await s.create('a', { name: '새벽 원정대', me: me('하루') });
  assert.equal(a.party.name, '새벽 원정대');
  assert.equal(a.party.owner, true);
  const code = a.party.code;
  assert.match(code, /^[A-Z2-9]{6}$/);
  await assert.rejects(s.create('a', { me: me('하루') }), /already_in_party/);
  await s.join('b', { code: code.toLowerCase(), me: me('별') });
  await s.join('c', { code, me: me('달') });
  const d = await s.join('d', { code, me: me('해') });
  assert.equal(d.members.length, 4);
  assert.equal(d.party.owner, false);
  await assert.rejects(s.join('e', { code, me: me('구름') }), /full/);
  await assert.rejects(s.join('e', { code: 'ZZZZZZ', me: me('구름') }), /no_party/);
  // 위치는 어디에도 없음
  assert.ok(!/"(lat|lng|r|c|cell)":/.test(JSON.stringify(d)), JSON.stringify(d));
});

test('나가기 · 파티장이 내보내기 · 파티장이 나가면 다음 사람이 파티장', async () => {
  const { s } = setup();
  const { party } = await s.create('a', { me: me('하루') });
  await s.join('b', { code: party.code, me: me('별') });
  await s.join('c', { code: party.code, me: me('달') });
  await assert.rejects(s.kick('b', { target: 'c' }), /not_owner/);
  const k = await s.kick('a', { target: 'c', me: me('하루') });
  assert.equal(k.members.length, 2);
  assert.equal((await s.state('c')).party, null);
  await s.leave('a');
  const b = await s.state('b', me('별'));
  assert.equal(b.party.owner, true);
  await s.leave('b');
  assert.equal((await s.state('b')).party, null);
});

test('운영정책: 같은 휴대폰 계정끼리 같은 파티 안 됨 · 휴대폰 걸음은 그날 처음 계정만', async () => {
  const { s, db } = setup();
  await db.doc('users/a').set({ devices: ['dev1'] });
  await db.doc('users/b').set({ devices: ['dev1', 'dev2'] });
  const { party } = await s.create('a', { me: me('하루') });
  await assert.rejects(s.join('b', { code: party.code, me: me('별') }), /same_device/);
  await s.join('c', { code: party.code, me: me('달') });
  const x = await s.state('a', me('하루', 5000, 'dev1'));
  assert.equal(x.stepsCounted, true);
  // 같은 휴대폰으로 다른 계정이 그날 걸음을 올리면 셈 안 됨
  const y = await s.state('c', me('달', 4000, 'dev1'));
  assert.equal(y.stepsCounted, false);
  assert.equal(y.walk.total, 5000);
});

test('함께 걷기: 인원 × 3만·7만·10만, 합계 · 각자 막대, 단계 보상은 한 사람이 한 번', async () => {
  const { s } = setup();
  const { party } = await s.create('a', { me: me('하루') });
  await s.join('b', { code: party.code, me: me('별') });
  let v = await s.state('a', me('하루', 40000));
  v = await s.state('b', me('별', 25000));
  assert.deepEqual(v.walk.goals, [60000, 140000, 200000]);
  assert.equal(v.walk.total, 65000);
  assert.deepEqual(v.members.map((m) => m.steps), [40000, 25000]);
  const c = await s.claim('a', { kind: 'walk', tier: 0, me: me('하루', 40000) });
  assert.equal(c.reward.footTicket, 10);
  await assert.rejects(s.claim('a', { kind: 'walk', tier: 0, me: me('하루', 40000) }), /claimed/);
  await assert.rejects(s.claim('a', { kind: 'walk', tier: 1, me: me('하루', 40000) }), /not_yet/);
  const cb = await s.claim('b', { kind: 'walk', tier: 0, me: me('별', 25000) });
  assert.equal(cb.reward.gold, 200);
});

test('응원: 하루 한 번, 받은 사람 다음 1,000보는 1.2배 + 알림 한 번', async () => {
  const { s } = setup();
  const { party } = await s.create('a', { me: me('하루') });
  await s.join('b', { code: party.code, me: me('별') });
  await s.state('b', me('별', 2000));
  await s.cheer('a', { target: 'b', me: me('하루') });
  await assert.rejects(s.cheer('a', { target: 'b', me: me('하루') }), /cheered_today/);
  const b1 = await s.state('b', me('별', 4000));
  assert.deepEqual(b1.cheers, ['하루']);
  assert.equal(b1.members.find((m) => m.me).steps, 4000 + 200);
  const b2 = await s.state('b', me('별', 4500));
  assert.deepEqual(b2.cheers, []);
  assert.equal(b2.members.find((m) => m.me).steps, 4700);
});

test('파티 보스: 3,000보마다 도전권(하루 3장), 피해가 합쳐짐, 쓰러뜨리면 상자 등급', async () => {
  const x = setup();
  const s = x.s;
  const { party } = await s.create('a', { me: me('하루') });
  await s.join('b', { code: party.code, me: me('별') });
  await s.join('c', { code: party.code, me: me('달') });
  let v = await s.state('a', me('하루', 2000));
  assert.equal(v.boss.tickets, 0);
  await assert.rejects(s.bossHit('a', { damage: 100, me: me('하루', 2000) }), /no_ticket/);
  v = await s.state('a', me('하루', 12000));
  assert.equal(v.boss.tickets, 3);
  const hp = v.boss.hp;
  const cap = R.hitCap(22);
  assert.equal(hp, R.perFight(22) * 10 * 3);
  v = await s.bossHit('a', { damage: 10 ** 9, me: me('하루', 12000) });
  assert.equal(v.boss.myDamage, cap); // 한도로 잘림
  assert.equal(v.boss.tickets, 2);
  await s.state('b', me('별', 9000));
  for (let i = 0; i < 3; i++) await s.bossHit('b', { damage: 1000, me: me('별', 9000) });
  await assert.rejects(s.bossHit('b', { damage: 1000, me: me('별', 9000) }), /no_ticket/);
  v = await s.state('a', me('하루', 12000));
  assert.equal(v.boss.damage, cap + 3000);
  assert.equal(v.boss.defeated, false);
  await assert.rejects(s.claim('a', { kind: 'boss', me: me('하루', 12000) }), /not_yet/);
  // 다음 날 도전권이 새로 생기고, 다 깎으면 쓰러짐
  for (let d = 1; d < 6 && !v.boss.defeated; d++) {
    x.at(T0 + d * 86400000);
    v = await s.state('a', me('하루', 9000));
    for (let i = 0; i < 3 && !v.boss.defeated; i++) v = await s.bossHit('a', { damage: cap, me: me('하루', 9000) });
  }
  assert.equal(v.boss.defeated, true);
  await assert.rejects(s.bossHit('a', { damage: cap, me: me('하루', 9000) }), /defeated|no_ticket/);
  const c = await s.claim('a', { kind: 'boss', me: me('하루', 9000) });
  assert.equal(c.reward.chest, 'gold');
  assert.equal(c.reward.footTicket, 40);
  const cb = await s.claim('b', { kind: 'boss', me: me('별', 0) });
  assert.equal(cb.reward.chest, 'bronze');
  await assert.rejects(s.claim('c', { kind: 'boss', me: me('달', 0) }), /no_damage/);
});

test('보스를 못 쓰러뜨린 주: 다음 주에 준 피해만큼 발자국 표', async () => {
  const x = setup();
  const { party } = await x.s.create('a', { me: me('하루') });
  await x.s.state('a', me('하루', 3000));
  await x.s.bossHit('a', { damage: 1000, me: me('하루', 3000) });
  x.at(T0 + 7 * 86400000);
  const v = await x.s.state('a', me('하루', 0));
  assert.ok(v.lastBoss && v.lastBoss.footTicket >= 0);
  const c = await x.s.claim('a', { kind: 'bossLast', me: me('하루', 0) });
  assert.equal(c.reward.boss, v.lastBoss.id);
  const again = await x.s.state('a', me('하루', 0));
  assert.equal(again.lastBoss, null);
  assert.ok(party.code);
});

test('제재 2단계: 파티 기능 막힘 · 그 사람 기여만 빼고 다른 사람 보상은 그대로', async () => {
  const { s, db } = setup();
  const { party } = await s.create('a', { me: me('하루') });
  await s.join('b', { code: party.code, me: me('별') });
  await s.state('a', me('하루', 30000));
  await s.state('b', me('별', 30000));
  await db.doc('status/b').set({ level: 2, until: new Date(T0 + 7 * 86400000).toISOString() });
  const v = await s.state('a', me('하루', 30000));
  assert.equal(v.walk.total, 30000);
  assert.equal(v.members.find((m) => m.uid === 'b').steps, 0);
  const vb = await s.state('b', me('별', 31000));
  assert.equal(vb.restricted, true);
  await assert.rejects(s.cheer('b', { target: 'a' }), /restricted/);
  await assert.rejects(s.bossHit('b', { damage: 1 }), /restricted/);
});

test('함께 있어요: 같은 칸 · 이웃 칸, 10분 안, 위치는 돌려주지 않음', async () => {
  const x = setup();
  const { party } = await x.s.create('a', { me: me('하루') });
  await x.s.join('b', { code: party.code, me: me('별') });
  assert.deepEqual(await x.s.near('a', { r: 100, c: 200 }), { near: false });
  assert.deepEqual(await x.s.near('b', { r: 101, c: 199 }), { near: true });
  assert.deepEqual(await x.s.near('b', { r: 103, c: 199 }), { near: false });
  x.at(T0 + 11 * 60000);
  assert.deepEqual(await x.s.near('a', { r: 103, c: 199 }), { near: false });
  assert.deepEqual(await x.s.near('c', { r: 103, c: 199 }), { near: false }); // 파티 없음
});

test('꾸미기: 파티장만, 금칙어 걸러냄, 문양 8 · 색 8', async () => {
  const { s } = setup();
  const { party } = await s.create('a', { me: me('하루') });
  await s.join('b', { code: party.code, me: me('별') });
  await assert.rejects(s.style('b', { name: '우리' }), /not_owner/);
  await assert.rejects(s.style('a', { name: '운영자 파티' }), /banned_word/);
  await assert.rejects(s.style('a', { emblem: 8 }), /bad_style/);
  const v = await s.style('a', { name: '별빛 동행', emblem: 7, color: 5, me: me('하루') });
  assert.equal(v.party.name, '별빛 동행');
  assert.equal(v.party.emblem, 7);
  assert.equal(v.party.color, 5);
});
