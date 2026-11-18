const test = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const path = require('path');
const { handle, setDeps } = require('../src/router');
const legal = require('../src/legal_pages');
const { MemDb } = require('../src/memdb');
const { AdminService, keepUntil } = require('../src/admin');

function call(p, method = 'GET') {
  return new Promise((resolve) => {
    const res = {
      code: 200,
      headers: {},
      set(k, v) { this.headers[k] = v; return this; },
      status(c) { this.code = c; return this; },
      send(b) { resolve({ code: this.code, body: b, headers: this.headers }); },
      json(b) { resolve({ code: this.code, body: b, headers: this.headers }); },
    };
    handle({ method, path: p, body: {}, headers: {}, get: () => '' }, res);
  });
}

test('약관 웹 페이지 4개는 앱 안 문서와 같은 글', () => {
  const dir = path.join(__dirname, '../../../assets/legal');
  const map = { privacy: 'privacy', location: 'location_terms', terms: 'terms', policy: 'operation' };
  for (const [k, f] of Object.entries(map)) {
    assert.equal(legal.TEXTS[k], fs.readFileSync(path.join(dir, f + '.txt'), 'utf8'), k);
  }
});

test('웹 페이지 5개는 로그인 없이 열림 · 휴대폰 화면', async () => {
  setDeps({ env: {} });
  for (const p of ['/privacy', '/location-terms', '/terms', '/policy', '/delete-account']) {
    const r = await call(p);
    assert.equal(r.code, 200, p);
    assert.match(r.headers['Content-Type'], /text\/html/);
    assert.match(r.body, /width=device-width/);
    assert.match(r.body, /주식회사 프로젝트서티즈/);
  }
  const d = await call('/delete-account');
  assert.match(d.body, /이세계가 현실이라면\? : 여명의 탑 아르카/);
  assert.match(d.body, /설정/);
  assert.match(d.body, /7일/);
  assert.match(d.body, /biz@project30s\.co\.kr/);
  assert.match(d.body, /3년/);
  const p = await call('/privacy');
  assert.match(p.body, /<h2>제3조 \(보유 기간과 파기\)<\/h2>/);
  const g = await call('/join/g/ABC234');
  assert.match(g.body, /길드에 초대받았어요/);
  assert.match(g.body, /ABC234/);
});

test('보관 기간: 제재 끝난 날부터 1년 · 영구 3년 · 운영자 기록 1년', async () => {
  const Y = 365 * 86400000;
  const T = Date.parse('2026-11-18T00:00:00Z');
  assert.equal(keepUntil({ level: 4, at: T }, T).getTime(), T + 3 * Y);
  assert.equal(keepUntil({ level: 2, at: T, until: new Date(T + 7 * 86400000).toISOString() }, T).getTime(), T + 7 * 86400000 + Y);
  const db = new MemDb();
  const a = new AdminService(db, { now: () => T });
  await a.sanction('op@x', { uid: 'u1abcdef', level: 3, reason: 'steps', memo: '' });
  const st = (await db.doc('status/u1abcdef').get()).data();
  assert.equal(st.expireAt.getTime(), T + 30 * 86400000 + Y);
  const logs = await db.collection('adminLog').get();
  assert.ok(logs.docs.every((d) => d.data().expireAt.getTime() === T + Y));
});
