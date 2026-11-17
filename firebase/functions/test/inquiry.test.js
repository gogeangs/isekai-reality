const test = require('node:test');
const assert = require('node:assert');
const zlib = require('zlib');
const { MemDb } = require('../src/memdb');
const { InquiryService } = require('../src/inquiry');
const { AccountService, summarize } = require('../src/account');
const { PartyService } = require('../src/party');
const { handle, setDeps, isAdmin } = require('../src/router');
const { adminPage } = require('../src/admin_page');

const T0 = Date.parse('2026-11-18T03:00:00Z');
const INSTALL = 'a1b2c3d4e5f60718293a4b5c6d7e8f90';

test('문의: 로그인 없이 보냄 · 하루 3건 · 종류 · 사진 · 이메일 확인', async () => {
  const db = new MemDb();
  const s = new InquiryService(db, { now: () => T0 });
  const base = { kind: 'bug', text: '지도에서 몬스터가 안 보여요', install: INSTALL, appVersion: '1.0.0+165', model: 'iPhone15,2' };
  const a = await s.send(null, { ...base, photo: 'AAAA', email: 'me@example.com' });
  assert.ok(a.id);
  const saved = (await db.doc(`inquiries/${a.id}`).get()).data();
  assert.equal(saved.status, 'new');
  assert.equal(saved.hasPhoto, true);
  assert.equal(saved.uid, null);
  assert.ok(!('photo' in saved));
  assert.equal((await db.doc(`inquiryPhotos/${a.id}`).get()).data().data, 'AAAA');
  await s.send(null, base);
  await s.send(null, base);
  await assert.rejects(s.send(null, base), /too_many/);
  await assert.rejects(s.send(null, { ...base, install: 'x', kind: 'bug' }), /bad_install/);
  await assert.rejects(s.send(null, { ...base, kind: 'hack' }), /bad_kind/);
  await assert.rejects(s.send(null, { ...base, install: INSTALL.replace('a', 'b'), email: 'nope' }), /bad_email/);
  // 위치는 받지 않음
  assert.ok(!/lat|lng/.test(JSON.stringify(saved)));
});

test('답: 운영자 답 + 보상 → 그 휴대폰(또는 계정) 우편으로 한 번, 1년 뒤 지움', async () => {
  const db = new MemDb();
  const s = new InquiryService(db, { now: () => T0 });
  const { id } = await s.send(null, { kind: 'record', text: '기록이 사라졌어요', install: INSTALL, email: 'me@example.com' });
  const { id: id2 } = await s.send('uidA', { kind: 'etc', text: '고마워요', install: INSTALL });
  const r = await s.reply({ id, body: '확인해 보니 복구했어요!', reward: { gold: 500, manaStone: 10, hack: 9 } });
  assert.match(r.mailto, /^mailto:/);
  await s.reply({ id: id2, body: '감사합니다', reward: {} });
  const list = await s.list({ status: 'answered' });
  assert.equal(list.items.length, 2);
  const q = (await db.doc(`inquiries/${id}`).get()).data();
  assert.equal(q.expireAt.getTime(), T0 + 365 * 86400000);
  // 로그인 전 문의는 설치 번호로, 로그인 문의는 계정으로
  const box1 = await s.inbox(null, { install: INSTALL });
  assert.equal(box1.msgs.length, 1);
  assert.equal(box1.msgs[0].title, '문의에 답이 왔어요');
  assert.deepEqual(box1.msgs[0].reward, { gold: 500, manaStone: 10 });
  const box2 = await s.inbox('uidA', { install: INSTALL });
  assert.equal(box2.msgs.length, 1);
  assert.equal((await s.inbox('uidA', { install: INSTALL })).msgs.length, 0); // 한 번만
});

test('계정 삭제: 삭제 시각이 지나면 파티 · 문의 · 기록 · 로그인 계정까지', async () => {
  const db = new MemDb();
  const now = () => T0;
  const party = new PartyService(db, { now });
  const inquiry = new InquiryService(db, { now });
  const gone = [];
  const acct = new AccountService(db, { now, party, inquiry, auth: { deleteUser: async (u) => gone.push(u) } });
  await db.doc('users/u1').set({ deleteAt: new Date(T0 - 1000), gen: '3' });
  await db.doc('users/u1/parts/3_0').set({ gen: '3', data: 'x' });
  await db.doc('users/u2').set({ deleteAt: new Date(T0 + 86400000) });
  await db.doc('users/u3').set({});
  await party.create('u1', { me: { name: '하루' } });
  await inquiry.send('u1', { kind: 'etc', text: '안녕하세요', install: INSTALL });
  const r = await acct.sweep();
  assert.equal(r.deleted, 1);
  assert.deepEqual(gone, ['u1']);
  assert.equal((await db.doc('users/u1').get()).exists, false);
  assert.equal((await db.doc('users/u1/parts/3_0').get()).exists, false);
  assert.equal((await db.doc('partyOf/u1').get()).exists, false);
  assert.equal((await inquiry.list({})).items.length, 0);
  assert.equal((await db.doc('users/u2').get()).exists, true);
});

test('운영자: 계정 보기는 읽기 전용 요약 (위치 없음)', async () => {
  const db = new MemDb();
  const snap = {
    'profile.v1': JSON.stringify({ name: '하루', spiritName: '불씨' }),
    'history.v1': JSON.stringify([{ steps: 1000, gains: { gold: 300 }, spends: { gold: 100 } }]),
    'json.nearAnchor': JSON.stringify({ lat: 37.1, lng: 127.1 }),
  };
  const data = zlib.gzipSync(Buffer.from(JSON.stringify(snap))).toString('base64');
  await db.doc('users/uidAAAA').set({ gen: '5', level: 22, devices: ['d1'] });
  await db.doc('users/uidAAAA/parts/5_0').set({ gen: '5', data });
  const a = await new AccountService(db).view({ uid: 'uidAAAA' });
  assert.equal(a.found, true);
  assert.equal(a.summary.name, '하루');
  assert.equal(a.summary.goldFromRecords, 200);
  assert.ok(!/37\.1|127\.1/.test(JSON.stringify(a)));
  assert.equal(summarize({}).name, null);
});

test('길: 파티는 로그인 필요 · 운영자만 /admin · 예약 작업 열쇠', async () => {
  const db = new MemDb();
  const now = () => T0;
  const party = new PartyService(db, { now });
  const inquiry = new InquiryService(db, { now });
  setDeps({
    party,
    inquiry,
    account: new AccountService(db, { now, party, inquiry }),
    verify: async (t) => (t === 'admin' ? { uid: 'adm', email: 'boss@example.com' } : t === 'u' ? { uid: 'u1' } : Promise.reject(new Error('bad'))),
    env: { ADMIN_EMAILS: 'boss@example.com', CRON_KEY: 'k', WEB_CONFIG: '{"apiKey":"x","authDomain":"y"}' },
  });
  const call = async (method, path, { auth, body, headers = {} } = {}) => {
    const out = {};
    const res = {
      set() {},
      status(c) {
        out.status = c;
        return res;
      },
      json(j) {
        out.json = j;
        out.status = out.status || 200;
        return res;
      },
      send(t) {
        out.text = t;
        out.status = out.status || 200;
        return res;
      },
    };
    const h = { ...headers, ...(auth ? { Authorization: `Bearer ${auth}` } : {}) };
    await handle({ method, path, body, get: (k) => h[k] || h[k.toLowerCase()] }, res);
    return out;
  };
  assert.equal((await call('POST', '/party/state', { body: {} })).status, 401);
  const st = await call('POST', '/party/create', { auth: 'u', body: { me: { name: '하루' } } });
  assert.equal(st.status, 200);
  assert.ok(st.json.party.code);
  assert.equal((await call('POST', '/inquiry', { body: { kind: 'bug', text: '안녕', install: INSTALL } })).status, 200);
  assert.equal((await call('POST', '/admin/list', { auth: 'u' })).status, 403);
  const l = await call('POST', '/admin/list', { auth: 'admin' });
  assert.equal(l.json.items.length, 1);
  assert.equal((await call('POST', '/cron/daily', { headers: { 'X-Cron-Key': 'no' } })).status, 403);
  assert.equal((await call('POST', '/cron/daily', { headers: { 'X-Cron-Key': 'k' } })).status, 200);
  const page = await call('GET', '/admin');
  assert.match(page.text, /아르카 운영/);
  assert.ok(isAdmin({ email: 'BOSS@example.com' }, { ADMIN_EMAILS: 'boss@example.com' }));
  assert.ok(!isAdmin({ email: 'x@example.com' }, { ADMIN_EMAILS: '' }));
  assert.match(adminPage({}), /설정\(웹 앱\)이 아직 없어요/);
});
