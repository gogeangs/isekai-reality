// 묶음 64: 심사용 계정 준비 스크립트 (MemDb 로)
const test = require('node:test');
const assert = require('node:assert');
const zlib = require('zlib');
const { MemDb } = require('../src/memdb');
const { seed } = require('../scripts/review_seed');
const { GuildService, levelOf, starOf } = require('../src/guild');
const { SiegeService } = require('../src/siege');
const { PartyService } = require('../src/party');

test('심사용 계정: 앱 기록 · 길드 Lv.4 회관 ★2 · 영지 + 수비대 · 공성권 · 지갑 · 파티 (두 번 돌려도 그대로)', async () => {
  const db = new MemDb();
  await db.doc('users/rv').set({ gen: 'old1', parts: 1, level: 1, lastDay: '2026-11-18' });
  await db.doc('users/rv/parts/old1_0').set({ data: 'x', gen: 'old1' });
  const { gid } = await seed(db, 'rv');
  const u = (await db.doc('users/rv').get()).data();
  assert.equal(u.level >= 38, true);
  assert.equal((await db.doc('users/rv/parts/old1_0').get()).exists, false, '예전 조각은 지움');
  let text = '';
  for (let i = 0; i < u.parts; i++) text += (await db.doc(`users/rv/parts/${u.gen}_${i}`).get()).data().data;
  const snap = JSON.parse(zlib.gunzipSync(Buffer.from(text, 'base64')).toString('utf8'));
  assert.ok(JSON.parse(snap['json.act5']).opened);
  assert.equal(JSON.parse(snap['json.act5']).chapter, 3);
  assert.ok(!JSON.stringify(snap).includes('"lat"'), '위치 없음');
  const g = (await db.doc(`guilds/${gid}`).get()).data();
  assert.equal(g.open, false, '공개 목록에 안 보임');
  const lv = levelOf(g.steps, Object.keys(g.members).length);
  assert.equal(lv, 4);
  assert.equal(starOf(lv, g.hall.points), 2);
  const siege = new SiegeService(db, { guild: new GuildService(db) });
  const st = await siege.state('rv', {});
  assert.equal(st.owners.sol_lily.gid, 'mine');
  assert.equal(st.garrisons.sol_lily[0].me, true);
  assert.equal(st.tickets, 10);
  assert.equal((await db.doc('tradeWallet/rv').get()).data().gold, 3000);
  const p = await new PartyService(db).state('rv', {});
  assert.equal(p.party.name, '심사 파티');
  // 다시 돌려도 길드 · 파티는 하나
  await seed(db, 'rv');
  assert.equal((await db.doc('guildOf/rv').get()).data().gid, gid);
  assert.equal((await db.collection('guilds').get()).docs.length, 1);
});
