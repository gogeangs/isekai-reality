// 묶음 70 #291·#292: 친구 Lv.8 · 「세계」 · 친구 1:1 Lv.11 · 초대 (바로 친구 · Lv.5 보상 · 5명까지 · 같은 기기 · 자란 계정 · 진짜 앱) · 첫 인사
const test = require('node:test');
const assert = require('node:assert');
const { MemDb } = require('../src/memdb');
const { GuildService } = require('../src/guild');
const { SuspectService } = require('../src/suspect');
const { ChatService, friendRoom } = require('../src/chat');

const T0 = Date.parse('2026-11-20T03:00:00Z');

function world() {
  const db = new MemDb();
  let now = T0;
  const clock = () => now;
  const g = new GuildService(db, { now: clock });
  const suspect = new SuspectService(db, { now: clock });
  const c = new ChatService(db, { now: clock, guild: g, suspect });
  const mails = async (uid) => (await db.collection(`inbox/u_${uid}/msgs`).get()).docs.map((d) => d.data());
  return { db, c, suspect, mails, add: (ms) => (now += ms) };
}

test('친구는 Lv.8부터 · 「세계」 · 친구 1:1은 Lv.11부터 (방 목록에도 그때부터)', async () => {
  const w = world();
  const a = await w.c.me('ua', { name: '하루', level: 7 });
  await w.c.me('ub', { name: '나리', level: 12 });
  await w.c.rules('ua');
  await w.c.rules('ub');
  assert.equal(a.rooms.length, 0, 'Lv.11 전엔 세계 방 없음');
  await assert.rejects(w.c.friendAdd('ua', { to: 'ub' }), /friend_level/);
  await w.c.me('ua', { level: 8 });
  await w.c.friendAdd('ua', { to: 'ub' });
  await w.c.friendAccept('ub', { from: 'ua' });
  const m8 = await w.c.me('ua', { level: 8 });
  assert.equal(m8.friends.length, 1, 'Lv.8 친구 목록');
  assert.equal(m8.rooms.length, 0, '1:1은 아직');
  await assert.rejects(w.c.send('ua', { room: friendRoom('ua', 'ub'), text: '안녕' }), /no_room/);
  await assert.rejects(w.c.send('ua', { room: 'server', text: '안녕' }), /level/);
  const m11 = await w.c.me('ua', { level: 11 });
  assert.deepEqual(m11.rooms.map((r) => r.name), ['세계', '나리']);
  await w.c.send('ua', { room: friendRoom('ua', 'ub'), text: '안녕' });
});

test('첫 인사: 세계에 처음 쓰면 우편 「첫 인사」 금화 100 (한 번만)', async () => {
  const w = world();
  await w.c.me('ua', { name: '하루', level: 11 });
  await w.c.rules('ua');
  const r = await w.c.send('ua', { room: 'server', text: '안녕하세요!' });
  assert.equal(r.firstHello, true);
  w.add(11000);
  await w.c.send('ua', { room: 'server', text: '반가워요' });
  const m = await w.mails('ua');
  assert.equal(m.length, 1);
  assert.equal(m[0].title, '첫 인사');
  assert.deepEqual(m[0].reward, { gold: 100 });
  assert.equal((await w.c.me('ua', {})).firstHello, true);
});

test('초대: Lv.8 전이라도 바로 친구 · Lv.5가 되면 둘 다 우편 (금화 300 · 마석 5 · 정령 물약 1)', async () => {
  const w = world();
  const host = await w.c.me('host', { name: '하루', level: 12, dev: 'D1' });
  await w.c.me('kid', { name: '새싹', level: 1, dev: 'D2' });
  const r = await w.c.inviteClaim('kid', { code: host.friendCode, level: 1, dev: 'D2' });
  assert.equal(r.friend, true);
  assert.equal((await w.c.me('kid', { level: 2 })).friends.length, 1, 'Lv.2인데 친구');
  assert.equal((await w.mails('kid')).length, 0);
  await w.c.me('kid', { level: 5 });
  const km = await w.mails('kid');
  const hm = await w.mails('host');
  assert.equal(km.length, 1);
  assert.equal(hm.length, 1);
  assert.deepEqual(km[0].reward, { gold: 300, manaStone: 5, 'item:bulssiPotion': 1 });
  await w.c.me('kid', { level: 6 });
  assert.equal((await w.mails('kid')).length, 1, '한 번만');
  const h = await w.c.me('host', {});
  assert.equal(h.invited, 1);
  assert.equal(h.invitePaid, 1);
  // 두 번째 초대 코드는 무시
  assert.equal((await w.c.inviteClaim('kid', { code: host.friendCode })).already, true);
});

test('초대한 사람 보상은 5명까지 (초대받은 사람은 그대로)', async () => {
  const w = world();
  const host = await w.c.me('host', { name: '하루', level: 12 });
  for (let i = 0; i < 6; i++) {
    await w.c.me(`k${i}`, { name: `k${i}`, level: 1 });
    await w.c.inviteClaim(`k${i}`, { code: host.friendCode, level: 1 });
    await w.c.me(`k${i}`, { level: 5 });
    assert.equal((await w.mails(`k${i}`)).length, 1);
  }
  assert.equal((await w.mails('host')).length, 5);
  const h = await w.c.me('host', {});
  assert.equal(h.invited, 6);
  assert.equal(h.invitePaid, 5);
});

test('부정: 같은 기기 · 이미 자란 계정 · 진짜 앱 실패 → 친구는 되고 보상 없음 · 의심 목록 「초대 보상」', async () => {
  const w = world();
  const host = await w.c.me('host', { name: '하루', level: 12, dev: 'SAME' });
  await w.c.me('k1', { level: 1 });
  await w.c.inviteClaim('k1', { code: host.friendCode, level: 1, dev: 'SAME' });
  await w.c.me('k2', { level: 9 });
  await w.c.inviteClaim('k2', { code: host.friendCode, level: 9, dev: 'X' });
  await w.c.me('k3', { level: 1 });
  await w.c.inviteClaim('k3', { code: host.friendCode, level: 1, dev: 'Y', appCheckBad: true });
  for (const k of ['k1', 'k2', 'k3']) {
    await w.c.me(k, { level: 10 });
    assert.equal((await w.mails(k)).length, 0, k);
    assert.equal((await w.c.me(k, {})).friends.length, 1, k);
    const s = (await w.db.doc(`suspects/${k}`).get()).data();
    assert.equal(s.counts.invite, 1, k);
  }
  assert.equal((await w.mails('host')).length, 0);
  // Lv.5가 될 때 진짜 앱 확인 실패해도 보상 없음
  await w.c.me('k4', { level: 1 });
  await w.c.inviteClaim('k4', { code: host.friendCode, level: 1, dev: 'Z' });
  await w.c.me('k4', { level: 5 }, { appCheckBad: true });
  assert.equal((await w.mails('k4')).length, 0);
});

test('계정 지우기: 초대 기록도 함께', async () => {
  const w = world();
  const host = await w.c.me('host', { name: '하루', level: 12 });
  await w.c.me('kid', { level: 1 });
  await w.c.inviteClaim('kid', { code: host.friendCode, level: 1 });
  await w.c.deleteFor('host');
  assert.equal((await w.db.doc('invites/kid').get()).exists, false);
  await w.c.me('k2', { level: 1 });
  await assert.rejects(w.c.inviteClaim('k2', { code: host.friendCode }), /no_user/);
});
