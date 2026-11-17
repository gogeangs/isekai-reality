// 묶음 57: 이름 금칙어 (planning/arca_banned_words.txt). 서버 판정이 기준이고, 앱도 같은 목록으로 먼저 거른다.
// 운영 중엔 Firestore config/bannedWords {text} 로 바꿀 수 있다 (관리 페이지). 없으면 함께 넣은 파일.
const fs = require('fs');
const path = require('path');

const BUNDLED = fs.readFileSync(path.join(__dirname, 'banned_words.txt'), 'utf8');

/** 비교용: 공백 · 특수문자 · 숫자 · 이모지 빼고, 영어는 소문자 */
function normalize(s) {
  return String(s || '')
    .toLowerCase()
    .replace(/[^a-zㄱ-ㆎ가-힣]/g, '');
}

/** 목록 글 → {part, whole}. 「## … [전체]」 아래는 이름 전체일 때만 */
function parse(text) {
  const part = [];
  const whole = [];
  let mode = 'part';
  for (const raw of String(text || '').split(/\r?\n/)) {
    const line = raw.trim();
    if (!line) continue;
    if (line.startsWith('##')) {
      mode = line.includes('[전체]') ? 'whole' : 'part';
      continue;
    }
    if (line.startsWith('#')) continue;
    const w = normalize(line);
    if (!w) continue;
    (mode === 'whole' ? whole : part).push(w);
  }
  return { part, whole };
}

let current = parse(BUNDLED);
let currentText = BUNDLED;
let loadedAt = 0;
const TTL = 5 * 60000;

function banned(name, list = current) {
  const n = normalize(name);
  if (!n) return false;
  if (list.whole.includes(n)) return true;
  return list.part.some((w) => n.includes(w));
}

/** Firestore 에 바꾼 목록이 있으면 (5분마다 다시 봄) */
async function refresh(db, now = Date.now()) {
  if (!db || now - loadedAt < TTL) return current;
  loadedAt = now;
  try {
    const d = await db.doc('config/bannedWords').get();
    const t = d.exists ? (d.data() || {}).text : null;
    if (t && t !== currentText) {
      current = parse(t);
      currentText = t;
    } else if (!t && currentText !== BUNDLED) {
      current = parse(BUNDLED);
      currentText = BUNDLED;
    }
  } catch (e) {
    // 못 읽으면 지금 목록 그대로
  }
  return current;
}

/** 관리 페이지: 지금 목록 · 바꾸기 */
async function view(db) {
  await refresh(db, Infinity);
  return { text: currentText, part: current.part.length, whole: current.whole.length };
}

async function save(db, text) {
  const t = String(text || '');
  if (t.length < 10 || t.length > 200000) {
    throw Object.assign(new Error('bad_text'), { status: 400, code: 'bad_text' });
  }
  await db.doc('config/bannedWords').set({ text: t, at: new Date() });
  current = parse(t);
  currentText = t;
  loadedAt = Date.now();
  return { ok: true, part: current.part.length, whole: current.whole.length };
}

function _reset() {
  current = parse(BUNDLED);
  currentText = BUNDLED;
  loadedAt = 0;
}

module.exports = { normalize, parse, banned, refresh, view, save, currentText: () => currentText, _reset };
