const test = require('node:test');
const assert = require('node:assert');
const words = require('../src/words');
const R = require('../src/rules');
const { MemDb } = require('../src/memdb');

test('금칙어: 공백 · 기호 · 숫자 빼고 비교, [부분] 은 안에 있어도 · [전체] 는 이름 전체만', () => {
  words._reset();
  assert.equal(words.banned('시 1 발'), true);
  assert.equal(words.banned('s.h.i.t'), true);
  assert.equal(words.banned('Shit🙂'), true);
  assert.equal(words.banned('새벽 원정대'), false);
  const list = words.parse('## 1 [부분]\n나쁜말\n## 2 [전체]\n바보\n');
  assert.equal(words.banned('나쁜말쟁이', list), true);
  assert.equal(words.banned('바보', list), true);
  assert.equal(words.banned('바보온달', list), false);
  assert.equal(R.cleanName('씨 발 파티'), null);
  assert.equal(R.cleanName('새벽 원정대'), '새벽 원정대');
});

test('금칙어: 운영 중 바꾸기 (Firestore) → 바로 적용', async () => {
  words._reset();
  const db = new MemDb();
  assert.equal(words.banned('달고나'), false);
  await words.save(db, '## 1 [부분]\n달고나\n');
  assert.equal(words.banned('달고나파티'), true);
  words._reset();
  await words.refresh(db, Date.now());
  assert.equal(words.banned('달고나파티'), true);
  words._reset();
});

test('초대 링크: 앱 연결 파일 · 안내 페이지', () => {
  const links = require('../src/links');
  const a = links.aasa({ APPLE_TEAM_ID: 'ABCDE12345' });
  assert.deepEqual(a.applinks.details[0].appIDs, ['ABCDE12345.kr.itso.isekaiReality']);
  assert.deepEqual(links.aasa({}).applinks.details, []);
  const fp = 'D9:BE:05:87:0C:59:93:00:2C:A2:FA:93:52:9E:2B:7B:DD:68:EA:FE:C1:B0:9E:F3:27:C4:43:C5:DC:6B:34:30';
  assert.equal(links.assetLinks({ ANDROID_CERT_SHA256: fp })[0].target.package_name, 'kr.itso.isekai_reality');
  assert.equal(links.assetLinks({ ANDROID_CERT_SHA256: 'bad' }).length, 0);
  const html = links.joinPage('ABC234');
  assert.match(html, /ABC234/);
  assert.match(html, /Google Play/);
  assert.doesNotMatch(links.joinPage('<x>'), /<x>/);
});
