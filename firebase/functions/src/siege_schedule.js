// 묶음 69 #279: 깃발 공성전 일정 — 날짜를 정해 두지 않고 운영자 스위치로 연다.
//
// erbard/schedule 문서 하나:
//   anchor    — 열린 일정의 첫 공성전 시작(ms, 한국 시각 토요일 0시). 없으면 닫힘
//   firstNo   — anchor 공성전의 번호. 그다음은 2주마다 +1
//   stopAfter — 닫을 때: 이 번호까지만 (그 뒤로는 안 열림)
//   doneBefore— 지금 일정 전에 이미 끝난 가장 늦은 번호 (없으면 -1)
//   test      — 테스트 공성전 { no, start, end, gids: [길드 id] } (그 길드에게만 보임)
//
// 라우터가 요청마다 load(db) 로 읽어 두고, 시험(node --test)은 예전 고정 일정(siege_estates.json anchor)을 그대로 쓴다.
const T = require('./siege_estates.json');

const P = T.period;
const LEN = T.length;
const DAY = 86400000;

/** 시험용 기본값: 예전 고정 일정 (11-28 첫 공성전) */
const LEGACY = { anchor: T.anchor, firstNo: 0, stopAfter: null, doneBefore: -1, test: null };
const CLOSED = { anchor: null, firstNo: 0, stopAfter: null, doneBefore: -1, test: null };

let S = { ...LEGACY };

function normalize(d) {
  if (!d) return { ...CLOSED };
  return {
    anchor: typeof d.anchor === 'number' ? d.anchor : null,
    firstNo: Number(d.firstNo) || 0,
    stopAfter: typeof d.stopAfter === 'number' ? d.stopAfter : null,
    doneBefore: typeof d.doneBefore === 'number' ? d.doneBefore : -1,
    test: d.test && typeof d.test.no === 'number' ? { no: d.test.no, start: d.test.start, end: d.test.end, gids: d.test.gids || [] } : null,
  };
}

const get = () => S;
const set = (s) => {
  S = normalize(s);
};
const useLegacy = () => {
  S = { ...LEGACY };
};

async function load(db) {
  const d = (await db.doc('erbard/schedule').get()).data();
  S = normalize(d);
  return S;
}

// ───────────── 정기 일정 (2주마다 토 · 일 48시간)

const regEnded = (n) => S.stopAfter != null && n > S.stopAfter;
function regStart(n) {
  if (S.anchor == null || n < S.firstNo || regEnded(n)) return Infinity;
  return S.anchor + (n - S.firstNo) * P;
}

/** 지금(또는 다음) 정기 공성전 번호 */
function regNo(now) {
  if (S.anchor == null) return nextFree(now);
  const d = now - S.anchor;
  if (d < 0) return S.firstNo;
  const k = Math.floor(d / P);
  const n = S.firstNo + (d - k * P < LEN ? k : k + 1);
  return regEnded(n) ? S.stopAfter + 1 : n;
}

/** 정기 일정의 이미 끝난 가장 늦은 번호 */
function regLastEnded(now) {
  if (S.anchor == null || now < S.anchor + LEN) return -1;
  let n = S.firstNo + Math.floor((now - (S.anchor + LEN)) / P);
  if (S.stopAfter != null) n = Math.min(n, S.stopAfter);
  return n;
}

function nextFree(now) {
  return lastEnded(now) + 1 + (S.test && now < S.test.end ? 1 : 0);
}

// ───────────── 테스트 공성전 (그 길드에게만)

const testFor = (gid) => !!(S.test && gid && S.test.gids.includes(gid));

// ───────────── 밖에서 쓰는 셈 (예전과 같은 이름)

/** 지금 공성전 번호 (없으면 다음 번호). [gid] 가 테스트 길드면 테스트 공성전 */
function siegeNo(now, gid) {
  if (testFor(gid) && now < S.test.end) return S.test.no;
  return regNo(now);
}

function siegeStart(n) {
  if (S.test && n === S.test.no) return S.test.start;
  return regStart(n);
}

function siegeEnd(n) {
  if (S.test && n === S.test.no) return S.test.end;
  const s = regStart(n);
  return s === Infinity ? Infinity : s + LEN;
}

function siegeActive(now, gid) {
  const n = siegeNo(now, gid);
  return now >= siegeStart(n) && now < siegeEnd(n);
}

/** 이미 끝난 가장 늦은 공성전 번호 (없으면 -1) */
function lastEnded(now) {
  let n = Math.max(S.doneBefore, regLastEnded(now));
  if (S.test && now >= S.test.end) n = Math.max(n, S.test.no);
  return n;
}

/** 열려 있나 (정기 일정이 돌고 있음) */
const isOpen = () => S.anchor != null && S.stopAfter == null;

/** 이 길드에게 공성전이 열려 있나 (정기 · 테스트) */
const openFor = (gid, now) => isOpen() || (testFor(gid) && now < S.test.end);

// ───────────── 운영자

/** now 다음 토요일 0시 (한국 시각) */
function nextSaturday(now) {
  const kst = now + 9 * 3600000;
  const day0 = Math.floor(kst / DAY) * DAY; // 한국 시각 오늘 0시 (UTC 기준 ms + 9h)
  const dow = new Date(day0).getUTCDay(); // 0 일 ... 6 토
  let add = (6 - dow + 7) % 7;
  if (add === 0) add = 7;
  return day0 + add * DAY - 9 * 3600000;
}

/** 공성전 열기 / 닫기 → 저장할 일정 */
function toggled(now, open) {
  const s = { ...S };
  if (open) {
    if (isOpen()) return s;
    const done = lastEnded(now);
    const busyTest = s.test && now < s.test.end ? s.test.no : -1;
    return { ...s, anchor: nextSaturday(now), firstNo: Math.max(done, busyTest) + 1, stopAfter: null, doneBefore: done };
  }
  if (!isOpen()) return s;
  const n = regNo(now);
  const active = now >= regStart(n) && now < regStart(n) + LEN;
  const stop = active ? n : n - 1;
  if (stop < s.firstNo) return { ...s, anchor: null, stopAfter: null, doneBefore: lastEnded(now) };
  return { ...s, stopAfter: stop };
}

/** 테스트 공성전 시작 (정기 공성전 중엔 안 됨) → 저장할 일정 */
function testStarted(now, gids, hours = 48) {
  if (siegeActive(now)) throw Object.assign(new Error('siege_now'), { status: 400, code: 'siege_now' });
  if (S.test && now < S.test.end) throw Object.assign(new Error('test_now'), { status: 400, code: 'test_now' });
  const s = { ...S };
  const done = lastEnded(now);
  const no = done + 1;
  if (s.anchor != null) {
    // 다가오는 정기 공성전은 번호만 하나 뒤로 (시작 시각은 그대로)
    const up = regNo(now);
    const at = regStart(up);
    if (at !== Infinity) {
      s.anchor = at;
      s.firstNo = no + 1;
      if (s.stopAfter != null) s.stopAfter += no + 1 - up;
    } else {
      s.anchor = null;
    }
  }
  s.doneBefore = done;
  s.test = { no, start: now, end: now + hours * 3600000, gids };
  return s;
}

function testEnded(now) {
  if (!S.test || now >= S.test.end) return { ...S };
  return { ...S, test: { ...S.test, end: now } };
}

/** 앱에 알려 주는 정기 일정 (테스트 공성전은 빼고) */
const publicView = () => ({ anchor: S.anchor, firstNo: S.firstNo, stopAfter: S.stopAfter, doneBefore: S.doneBefore });

/** 운영자 페이지 · 앱에 보여 줄 모양 */
function view(now) {
  const n = regNo(now);
  return {
    open: isOpen(),
    next: regStart(n) === Infinity ? null : { no: n, start: regStart(n), end: regStart(n) + LEN },
    active: siegeActive(now),
    stopAfter: S.stopAfter,
    test: S.test && now < S.test.end ? { no: S.test.no, start: S.test.start, end: S.test.end, gids: S.test.gids } : null,
  };
}

module.exports = {
  get, set, load, useLegacy, normalize, siegeNo, siegeStart, siegeEnd, siegeActive, lastEnded, isOpen, openFor, testFor,
  nextSaturday, toggled, testStarted, testEnded, view, publicView, CLOSED, LEGACY,
};
