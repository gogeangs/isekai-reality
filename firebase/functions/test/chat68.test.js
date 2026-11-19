// 묶음 68 #275: 대화 · 친구 — 방 접근 · 가림 · 도배 · Lv.10 · 신고 · 대화 금지 · 차단 · 친구 · 길드 소식 · 계정 지우기
const test = require('node:test');
const assert = require('node:assert');
const { MemDb } = require('../src/memdb');
const { GuildService } = require('../src/guild');
const { SiegeService } = require('../src/siege');
const { ChatService, maskPrivate, friendRoom } = require('../src/chat');

const T0 = Date.parse('2026-11-20T03:00:00Z');

async function world() {
  const db = new MemDb();
  let now = T0;
  const clock = () => now;
  const g = new GuildService(db, { now: clock });
  const c = new ChatService(db, { now: clock, guild: g });
  const s = new SiegeService(db, { now: clock, guild: g, chat: c });
  const join = async (uid, level = 12) => {
    await c.me(uid, { name: uid, level });
    await c.rules(uid);
  };
  return { db, g, c, s, join, add: (ms) => (now += ms), get now() { return now; } };
}

test('가림: 전화번호 · 이메일 · 링크 · 메신저 아이디', () => {
  assert.equal(maskPrivate('번호 010-1234-5678 줘'), '번호 ○○ 줘');
  assert.equal(maskPrivate('a.b@gmail.com'), '○○');
  assert.equal(maskPrivate('여기 www.abc.com 와'), '여기 ○○ 와');
  assert.equal(maskPrivate('naver.com 봐'), '○○ 봐');
  assert.equal(maskPrivate('카톡 아이디: hello123'), '○○');
  assert.equal(maskPrivate('오늘 3,000보 걸었어요'), '오늘 3,000보 걸었어요');
});

test('서버 대화방: 대화 예절 먼저 · Lv.10부터 쓰기 · 10초에 한 번 · 같은 글 세 번이면 1분 쉼 · 100자', async () => {
  const w = await world();
  await w.c.me('ua', { name: '하루', level: 12 });
  await assert.rejects(w.c.send('ua', { room: 'server', text: '안녕하세요!' }), /rules_first/);
  await w.c.rules('ua');
  const r = await w.c.send('ua', { room: 'server', text: '안녕하세요!' });
  assert.equal(r.line.text, '안녕하세요!');
  await assert.rejects(w.c.send('ua', { room: 'server', text: '또' }), /too_fast/);
  w.add(11000);
  await w.c.send('ua', { room: 'server', text: '안녕하세요!' });
  w.add(11000);
  await assert.rejects(w.c.send('ua', { room: 'server', text: '안녕하세요!' }), /rest/);
  w.add(30000);
  await assert.rejects(w.c.send('ua', { room: 'server', text: '다른 말' }), /rest/);
  w.add(31000);
  await w.c.send('ua', { room: 'server', text: '다른 말' });
  w.add(11000);
  await assert.rejects(w.c.send('ua', { room: 'server', text: 'x'.repeat(101) }), /too_long/);
  await w.join('low', 5);
  await assert.rejects(w.c.send('low', { room: 'server', text: '안녕' }), /level/);
  // 묶음 70 #292: 「세계」는 Lv.11부터 읽기도
  await assert.rejects(w.c.read('low', { room: 'server' }), /level/);
  const read = await w.c.read('ua', { room: 'server' });
  assert.equal(read.lines.length, 3);
  // 진짜 앱 확인 실패한 요청은 못 씀
  w.add(11000);
  await assert.rejects(w.c.send('ua', { room: 'server', text: '하이', appCheckBad: true }), /app_check/);
});

test('길드 · 연맹 방은 그 사람만 · 길드 소식은 시스템 줄로', async () => {
  const w = await world();
  await w.g.create('ua', { name: '새벽', me: { name: 'ua', level: 30 } });
  const st = await w.g.state('ua', { name: 'ua', level: 30 });
  await w.g.join('ub', { code: st.guild.code, me: { name: 'ub', level: 20 } });
  const gid = (await w.db.doc('guildOf/ua').get()).data().gid;
  await w.join('ua');
  await w.join('ub');
  await w.join('ux');
  await w.c.send('ua', { room: `g_${gid}`, text: '집결해요' });
  await assert.rejects(w.c.read('ux', { room: `g_${gid}` }), /no_room/);
  const r = await w.c.read('ub', { room: `g_${gid}` });
  assert.equal(r.lines.at(-1).text, '집결해요');
  w.add(1000);
  await w.s._news(gid, '하루님이 바람 언덕에 집결 깃발을 꽂았어요');
  const r2 = await w.c.read('ub', { room: `g_${gid}` });
  assert.equal(r2.lines.at(-1).kind, 'sys');
  const me = await w.c.me('ub', {});
  const room = me.rooms.find((x) => x.kind === 'guild');
  assert.equal(room.unread, 0, '읽은 뒤');
  w.add(11000);
  await w.c.send('ua', { room: `g_${gid}`, text: '하이' });
  assert.equal((await w.c.me('ub', {})).rooms.find((x) => x.kind === 'guild').unread, 1);
});

test('친구: 코드로 신청 · 수락 · 1:1 · 끊기 · 차단하면 글도 신청도 막힘', async () => {
  const w = await world();
  await w.join('ua');
  await w.join('ub');
  const code = (await w.c.me('ub', { steps: 4200 })).friendCode;
  assert.match(code, /^[A-Z0-9]{8}$/);
  assert.deepEqual(await w.c.friendAdd('ua', { code }), { ok: true, sent: true });
  await assert.rejects(w.c.read('ua', { room: friendRoom('ua', 'ub') }), /no_room/, '수락 전엔 1:1 없음');
  const inb = await w.c.me('ub', {});
  assert.equal(inb.requests[0].uid, 'ua');
  await w.c.friendAccept('ub', { from: 'ua' });
  const me = await w.c.me('ua', {});
  assert.equal(me.friends[0].name, 'ub');
  assert.equal(me.friends[0].steps, 4200);
  await w.c.settings('ub', { showSteps: false });
  assert.equal((await w.c.me('ua', {})).friends[0].steps, null, '걸음 보여 주기를 끄면 안 보임');
  await w.c.send('ua', { room: friendRoom('ua', 'ub'), text: '같이 사냥해요' });
  assert.equal((await w.c.read('ub', { room: friendRoom('ua', 'ub') })).lines.length, 1);
  // 차단: 서버 방 글도 안 보이고 신청도 막힘
  w.add(11000);
  await w.c.send('ua', { room: 'server', text: '안녕하세요!' });
  await w.c.block('ub', { to: 'ua' });
  assert.equal((await w.c.read('ub', { room: 'server' })).lines.length, 0);
  await assert.rejects(w.c.friendAdd('ua', { to: 'ub' }), /blocked/);
  await assert.rejects(w.c.read('ua', { room: friendRoom('ua', 'ub') }), /no_room/);
  assert.equal((await w.c.me('ub', {})).blocked[0].uid, 'ua');
  await w.c.unblock('ub', { to: 'ua' });
  assert.equal((await w.c.read('ub', { room: 'server' })).lines.length, 1);
});

test('금칙어 · 개인정보는 ○○로 가려져 저장', async () => {
  const w = await world();
  await w.join('ua');
  const r = await w.c.send('ua', { room: 'server', text: '내 번호 01012345678 이야' });
  assert.equal(r.line.text, '내 번호 ○○ 이야');
  assert.equal(r.masked, true);
});

test('신고 → 운영자 대화 금지 7일 · 경고 · 신고된 줄과 앞뒤 10줄 · 우편', async () => {
  const w = await world();
  await w.join('ua');
  await w.join('ub');
  for (let i = 0; i < 12; i++) {
    await w.c.send('ua', { room: 'server', text: `말 ${i}` });
    w.add(11000);
  }
  const lines = (await w.c.read('ub', { room: 'server' })).lines;
  await w.c.report('ub', { room: 'server', id: lines[5].id, reason: 'abuse' });
  const rep = await w.c.reports({});
  assert.equal(rep.items.length, 1);
  assert.equal(rep.items[0].context.length, 12, '앞 5줄 + 그 줄 + 뒤 6줄 (있는 만큼 10줄까지)');
  assert.equal(rep.items[0].reason, 'abuse');
  await w.c.resolve('op@x', { id: rep.items[0].id, action: 'mute7' });
  await assert.rejects(w.c.send('ua', { room: 'server', text: '하이' }), /muted/);
  const me = await w.c.me('ua', {});
  assert.ok(me.mutedUntil > w.now);
  const mails = await w.db.collection('inbox/u_ua/msgs').get();
  assert.ok(mails.docs.some((d) => /대화 금지 7일/.test(d.data().title)));
  assert.equal((await w.c.reports({})).items.length, 0, '처리 끝');
});

test('계정 지우기: 내 대화 · 친구 · 신청 · 코드', async () => {
  const w = await world();
  await w.join('ua');
  await w.join('ub');
  const code = (await w.c.me('ua', {})).friendCode;
  await w.c.friendAdd('ub', { code });
  await w.c.friendAccept('ua', { from: 'ub' });
  await w.c.send('ua', { room: 'server', text: '안녕' });
  await w.c.deleteFor('ua');
  assert.equal((await w.c.read('ub', { room: 'server' })).lines.length, 0);
  assert.equal((await w.c.me('ub', {})).friends.length, 0);
  assert.equal((await w.db.doc(`friendCode/${code}`).get()).exists, false);
});

test('문서 자리 줄은 웹 페이지에 보이지 않음', () => {
  const L = require('../src/legal_pages.js');
  for (const k of ['privacy', 'terms', 'policy']) {
    assert.ok(L.TEXTS[k].includes('<!-- 자리(묶음 68'), k);
    assert.ok(!JSON.stringify(L.render(L.TEXTS[k])).includes('자리(묶음 68'), k);
  }
});
