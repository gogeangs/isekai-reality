// 묶음 64: Play · App Store 심사용 계정 준비 (GitHub Actions 「심사용 계정 준비」에서만 실행)
// 계정을 이메일로 찾아 ① 앱 기록(5막 1~3장 · 재료 · 금화) ② 길드(Lv.4 · 회관 ★2 · 금고) ③ 에르바르드 영지 하나 + 수비대
// ④ 공성권 · 거래 지갑 금화 ⑤ 파티 를 넣는다. 로그에는 계정 정보 · 서버 응답을 남기지 않는다.
const zlib = require('zlib');
const { GuildService, G } = require('../src/guild');
const { PartyService } = require('../src/party');
const { SiegeService } = require('../src/siege');
const REC = require('./review_record.json');

const ESTATE = 'sol_lily';
const CHUNK = 700000;

/** 서버 기록에 넣기 (시험은 MemDb 로) */
async function seed(db, uid, { stamp = () => new Date() } = {}) {
  const me = { name: '하루', level: REC.level, job: 'warrior' };

  // ① 앱 기록 (앱 백업과 같은 모양: gzip + base64 조각)
  const text = zlib.gzipSync(Buffer.from(JSON.stringify(REC.snapshot), 'utf8')).toString('base64');
  const gen = `${Date.now().toString(36)}rv`;
  const parts = [];
  for (let i = 0; i < text.length; i += CHUNK) parts.push(text.slice(i, i + CHUNK));
  const uref = db.doc(`users/${uid}`);
  const old = (await uref.get()).data() || {};
  for (const [i, p] of parts.entries()) await db.doc(`users/${uid}/parts/${gen}_${i}`).set({ data: p, gen });
  await uref.set(
    { gen, parts: parts.length, level: REC.level, lastDay: REC.lastDay, updatedAt: stamp(), review: true },
    { merge: true },
  );
  if (old.gen && old.gen !== gen && !(old.kept && old.kept.gen === old.gen)) {
    for (let i = 0; i < (old.parts || 0); i++) await db.doc(`users/${uid}/parts/${old.gen}_${i}`).delete();
  }
  await db.doc(`marketHold/${uid}`).delete();

  // ② 길드 (없으면 만들고, 비공개 · Lv.4 · 회관 ★2 · 금고 조금)
  const guild = new GuildService(db);
  let gid = ((await db.doc(`guildOf/${uid}`).get()).data() || {}).gid;
  if (!gid || !(await db.doc(`guilds/${gid}`).get()).exists) {
    await guild.create(uid, { name: '여명 심사단', emblem: 2, color: 3, open: false, me });
    gid = (await db.doc(`guildOf/${uid}`).get()).data().gid;
  }
  const gref = db.doc(`guilds/${gid}`);
  const g = (await gref.get()).data();
  g.open = false;
  g.steps = Math.max(Number(g.steps || 0), G.LEVEL_PER_HEAD[4] * 5);
  g.hall = { ...(g.hall || {}), points: Math.max(Number((g.hall || {}).points || 0), G.STARS[2][1]) };
  g.treasury = Math.max(Number(g.treasury || 0), 20000);
  g.members[uid] = { ...g.members[uid], name: me.name, level: me.level, job: me.job, line: g.members[uid].line || '함께 걸어요' };
  await gref.set(g);

  // ③ 에르바르드: 빈 영지 하나를 이 길드에 · 수비대 첫 자리에 내 분신
  const siege = new SiegeService(db, { guild });
  const w = await siege._world();
  const o = w.owners[ESTATE];
  if (!o || o.gid === gid) {
    w.owners[ESTATE] = { gid, name: g.name, emblem: g.emblem || 0, color: g.color || 0, since: 0 };
    await db.doc('erbard/world').set(w);
    const garr = (await db.doc(`garrison/${ESTATE}`).get()).data();
    const slots = garr && garr.gid === gid ? garr.slots || [null, null, null, null, null] : [null, null, null, null, null];
    slots[0] = { uid, name: me.name, level: me.level, job: me.job, allies: [], at: Date.now() };
    await db.doc(`garrison/${ESTATE}`).set({ gid, slots });
  }

  // ④ 공성권 · 거래 지갑 금화
  await db.doc(`siegeTicket/${uid}`).set({ bank: 10, carry: 0, day: '', dayCounted: 0, at: Date.now() });
  const wref = db.doc(`tradeWallet/${uid}`);
  const wg = Number(((await wref.get()).data() || {}).gold || 0);
  await wref.set({ gold: Math.max(wg, 3000), at: Date.now() });

  // ⑤ 파티 (혼자여도 화면이 보이게)
  const party = new PartyService(db);
  if (!(await party._partyId(uid))) await party.create(uid, { name: '심사 파티', me });
  return { gid };
}

/** 이메일로 계정 찾기 (Google 로그인 정보의 이메일까지) */
async function findUid(admin, email) {
  try {
    return (await admin.auth().getUserByEmail(email)).uid;
  } catch (e) {
    if (!e || e.code !== 'auth/user-not-found') throw new Error(`계정을 찾지 못했어요 (${(e && e.code) || 'unknown'})`);
  }
  let token;
  do {
    const page = await admin.auth().listUsers(1000, token);
    for (const u of page.users) {
      const mails = [u.email, ...(u.providerData || []).map((x) => x.email)].filter(Boolean).map((m) => String(m).toLowerCase());
      if (mails.includes(email)) return u.uid;
    }
    token = page.pageToken;
  } while (token);
  return null;
}

async function countUsers(admin) {
  let n = 0;
  let token;
  do {
    const page = await admin.auth().listUsers(1000, token);
    n += page.users.length;
    token = page.pageToken;
  } while (token);
  return n;
}

async function main() {
  const admin = require('firebase-admin');
  const email = String(process.env.REVIEW_EMAIL || '').trim().toLowerCase();
  if (!email) throw new Error('REVIEW_EMAIL 없음');
  // 서비스 계정 파일의 프로젝트가 아니라 아르카 프로젝트로 (함수 배포와 같은 곳)
  if (!admin.apps.length) admin.initializeApp({ projectId: process.env.PROJECT_ID || 'arca-d0cab' });
  const db = admin.firestore();
  db.settings({ ignoreUndefinedProperties: true });
  const uid = await findUid(admin, email);
  if (!uid) {
    const docs = (await db.collection('users').count().get()).data().count;
    const cols = (await db.listCollections()).map((c) => c.id).join(',');
    console.log(`프로젝트 ${admin.app().options.projectId || '?'} · 모음: ${cols}`);
    throw new Error(`그 이메일로 로그인한 계정이 없어요 (로그인 계정 ${await countUsers(admin)}개 · 백업 기록 ${docs}개 중에서 못 찾음)`);
  }
  await seed(db, uid, { stamp: () => admin.firestore.FieldValue.serverTimestamp() });
  console.log('심사용 계정 준비 끝');
}

module.exports = { seed };

if (require.main === module) main().then(
  () => process.exit(0),
  (e) => {
    console.error('준비 실패:', e.message);
    process.exit(1);
  },
);
