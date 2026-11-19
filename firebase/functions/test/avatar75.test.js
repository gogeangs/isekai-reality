// 묶음 75 #335: 프로필 사진 (앱 안 그림 이름만) — 대화 카드 · 파티 · 길드에 올림
const test = require('node:test');
const assert = require('node:assert');
const { MemDb } = require('../src/memdb');
const { PartyService } = require('../src/party');
const { GuildService } = require('../src/guild');
const { ChatService } = require('../src/chat');

const T0 = Date.parse('2026-11-20T03:00:00Z');
const rnd = () => (() => { let i = 0; return () => ((i++ * 0.37) % 1); })();

test('파티: 들어갈 때 · 새로 할 때 얼굴이 따라옴 · 모양이 다르면 빈 값', async () => {
  const db = new MemDb();
  const s = new PartyService(db, { now: () => T0, rand: rnd() });
  const a = await s.create('a', { name: '얼굴 파티', me: { name: '하루', level: 20, face: 'pet_slime_baby' } });
  await s.join('b', { code: a.party.code, me: { name: '별', level: 20, face: '../../etc/passwd' } });
  let v = await s.state('a', { name: '하루', level: 20, face: 'pet_slime_baby' });
  const face = (uid) => v.members.find((m) => m.uid === uid).face;
  assert.equal(face('a'), 'pet_slime_baby');
  assert.equal(face('b'), '');
  v = await s.state('b', { name: '별', level: 20, face: 'npc_marta' });
  assert.equal(face('b'), 'npc_marta');
});

test('길드: 들어갈 때 · 걸음 보낼 때 얼굴 · 목록에 보임', async () => {
  const db = new MemDb();
  const g = new GuildService(db, { now: () => T0, rand: rnd() });
  await g.create('a', { name: '얼굴 길드', open: true, me: { name: '하루', level: 30, face: 'title_awakened' } });
  let v = await g.state('a', { name: '하루', level: 30 });
  assert.equal(v.members.find((x) => x.uid === 'a').face, 'title_awakened');
  v = await g.state('a', { name: '하루', level: 30, face: 'pet_slime_adult' });
  assert.equal(v.members.find((x) => x.uid === 'a').face, 'pet_slime_adult');
});

test('대화 카드: 얼굴 · 이상한 값은 빈 값', async () => {
  const db = new MemDb();
  const guild = new GuildService(db, { now: () => T0 });
  const c = new ChatService(db, { now: () => T0, guild });
  await c.me('ua', { name: '하루', level: 12, face: 'npc_lian' });
  assert.equal(c._card('ua', await c._user('ua')).face, 'npc_lian');
  await c.me('ua', { face: '<img src=x>' });
  assert.equal(c._card('ua', await c._user('ua')).face, '');
});
