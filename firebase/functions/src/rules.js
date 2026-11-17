// 파티 · 문의 규칙 (숫자는 숨은 값, 테스트로 조정). 입출력 없는 순수 함수만.

const DAY_MS = 86400000;
const KST = 9 * 3600000;

/** 서버 날짜 (한국 시간) 'yyyy-mm-dd' */
function dayKey(ms) {
  return new Date(ms + KST).toISOString().slice(0, 10);
}

/** 이번 주 월요일 (한국 시간) 'yyyy-mm-dd' — 월요일에 새로 */
function weekKey(ms) {
  const d = new Date(ms + KST);
  const dow = (d.getUTCDay() + 6) % 7; // 월 0 … 일 6
  return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()) - dow * DAY_MS)
    .toISOString()
    .slice(0, 10);
}

/** 기준 월요일부터 몇 번째 주인지 */
function weekIndex(week) {
  return Math.floor((Date.parse(week + 'T00:00:00Z') - Date.parse('2026-11-16T00:00:00Z')) / (7 * DAY_MS));
}

const MAX_MEMBERS = 4;

// ① 함께 걷기: 1인당 3만 · 7만 · 10만 보 × 인원
const WALK_PER_HEAD = [30000, 70000, 100000];
function walkGoals(members) {
  return WALK_PER_HEAD.map((s) => s * Math.max(1, members));
}
const WALK_REWARDS = [
  { gold: 200, footTicket: 10 },
  { manaStone: 10, matBundle: 1, footTicket: 20 },
  { partyChest: 1, footTicket: 30 },
];

// 응원: 다음 1,000보가 1.2배
const CHEER_STEPS = 1000;
const CHEER_RATE = 0.2;

// ② 파티 보스 (주마다 차례로)
const BOSSES = ['partyGolem', 'partyHydra', 'partyWyvern', 'partyKraken'];
function bossOf(week) {
  const i = weekIndex(week);
  const n = ((i % BOSSES.length) + BOSSES.length) % BOSSES.length;
  return { id: BOSSES[n], encounter: Math.floor(i / BOSSES.length) + 1 };
}

/** 보스 체력: 인원 · 평균 레벨 · ○번째 만남 */
/** 한 판에 그 레벨이 보통 주는 피해 (보스 체력·한도의 단위) */
function perFight(level) {
  return 900 + 140 * Math.max(1, level);
}

function bossHp(members, avgLevel, encounter) {
  return Math.round(perFight(avgLevel) * 10 * Math.max(1, members) * (1 + 0.12 * (Math.max(1, encounter) - 1)));
}

/** 한 판 피해 한도 = 앱의 보스 한 판 체력 (지나치게 큰 값은 잘라 냄) */
function hitCap(level) {
  return Math.round(perFight(level) * 3);
}

const TICKET_STEPS = 3000;
const TICKETS_PER_DAY = 3;
function ticketsEarned(steps) {
  return Math.min(TICKETS_PER_DAY, Math.floor(Math.max(0, steps) / TICKET_STEPS));
}

/** 보스 상자: 내가 준 피해 비율 (동 · 은 · 금) */
function chestOf(share) {
  if (share >= 0.35) return 'gold';
  if (share >= 0.15) return 'silver';
  return 'bronze';
}
const BOSS_WIN = { footTicket: 40, bossMat: 2 };
/** 못 쓰러뜨렸을 때: 준 피해만큼 발자국 표 조금 */
function bossLoseTickets(damage, hp) {
  return Math.min(15, Math.floor((damage / Math.max(1, hp)) * 40));
}

// ③ 함께 있어요: 100m 칸, 이웃 칸까지 · 10분 안
const CELL_LAT = 0.0009;
const CELL_LNG = 0.001125;
const NEAR_MS = 10 * 60000;
function near(a, b) {
  return Math.abs(a.r - b.r) <= 1 && Math.abs(a.c - b.c) <= 1;
}

// ④ 꾸미기
const EMBLEMS = ['sword', 'paw', 'lantern', 'tower', 'leaf', 'star', 'moon', 'wing'];
const COLORS = 8;
// 묶음 57: 금칙어는 words.js (기획 목록 · 운영 중 바꿀 수 있음)
const words = require('./words');
function cleanName(name) {
  const n = String(name || '').trim().replace(/\s+/g, ' ');
  if (n.length < 1 || n.length > 12) return null;
  if (words.banned(n)) return null;
  return n;
}
/** 이름이 금칙어에 걸리는지 (길이는 따로) */
function bannedName(name) {
  return words.banned(name);
}

/** 초대 코드: 헷갈리는 글자(0 O 1 I) 뺀 6자리 */
const CODE_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
function makeCode(rand = Math.random) {
  let s = '';
  for (let i = 0; i < 6; i++) s += CODE_CHARS[Math.floor(rand() * CODE_CHARS.length)];
  return s;
}

/** 제재 2단계 이상(함께하는 기능 제한) 중인지 */
function restricted(status, now) {
  if (!status) return false;
  const lv = Number(status.level || 0);
  if (lv >= 4) return true;
  if (lv < 2) return false;
  const until = status.until ? Date.parse(status.until) : 0;
  return !until || until > now;
}

// 문의
const INQUIRY_KINDS = ['bug', 'record', 'trade', 'party', 'report', 'appeal', 'etc'];
const INQUIRY_PER_DAY = 3;
const INQUIRY_KEEP_MS = 365 * DAY_MS;
const PHOTO_MAX = 700000; // base64 글자 수

module.exports = {
  dayKey,
  weekKey,
  weekIndex,
  MAX_MEMBERS,
  walkGoals,
  WALK_REWARDS,
  CHEER_STEPS,
  CHEER_RATE,
  BOSSES,
  bossOf,
  perFight,
  bossHp,
  hitCap,
  TICKET_STEPS,
  TICKETS_PER_DAY,
  ticketsEarned,
  chestOf,
  BOSS_WIN,
  bossLoseTickets,
  CELL_LAT,
  CELL_LNG,
  NEAR_MS,
  near,
  EMBLEMS,
  COLORS,
  cleanName,
  bannedName,
  makeCode,
  restricted,
  INQUIRY_KINDS,
  INQUIRY_PER_DAY,
  INQUIRY_KEEP_MS,
  PHOTO_MAX,
};
