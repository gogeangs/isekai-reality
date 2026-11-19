// 묶음 61 #250: 부정 이용 의심 목록 — 다른 사람과 얽히는 곳(파티 · 길드 · 거래소 · 순위 · 공성전)에서만 모음.
// 걸린 걸음 · 기여는 그 기능에서만 세지 않고, 제재는 운영자가 본 뒤에 (자동 제재 없음).
// 남기는 것: 걸린 종류 · 횟수 · 마지막 시각 · 하루 걸음(최대 시간당 걸음 · 손으로 입력한 걸음) — 8주 뒤 자동 삭제(expireAt)
const R = require('./rules');

const KEEP = 56 * 86400000;
const KINDS = {
  appcheck: '진짜 앱 확인 실패',
  mock: '가짜 위치',
  manual: '손으로 입력한 걸음',
  wallet: '거래 지갑 맞지 않음',
  fight: '싸움 결과 맞지 않음',
  invite: '초대 보상',
};

class SuspectService {
  constructor(db, { now = () => Date.now() } = {}) {
    this.db = db;
    this.now = now;
  }

  /** 한 번 걸림 (같은 종류는 하루 한 번만 셈) */
  async hit(uid, kind, detail = {}) {
    if (!uid || !KINDS[kind]) return;
    const ref = this.db.doc(`suspects/${uid}`);
    const day = R.dayKey(this.now());
    await this.db.runTransaction(async (t) => {
      const s = await t.get(ref);
      const d = s.exists ? s.data() : { counts: {}, last: {}, days: {} };
      d.days = d.days || {};
      const k = `${kind}:${day}`;
      if (d.days[k]) return;
      d.days[k] = 1;
      // 오래된 날 표시는 지움 (8주)
      for (const x of Object.keys(d.days)) if (x.split(':')[1] < R.dayKey(this.now() - KEEP)) delete d.days[x];
      d.counts = d.counts || {};
      d.counts[kind] = (d.counts[kind] || 0) + 1;
      d.last = d.last || {};
      d.last[kind] = { at: this.now(), detail };
      d.total = Object.values(d.counts).reduce((a, b) => a + b, 0);
      d.at = this.now();
      d.expireAt = new Date(this.now() + KEEP);
      t.set(ref, d);
    });
  }

  /** 하루 걸음 기록 (의심 목록에서 참고만) */
  async steps(uid, { steps, maxHour, manual } = {}) {
    if (!uid) return;
    const n = Math.max(0, Math.floor(Number(steps) || 0));
    if (!n && !manual) return;
    const day = R.dayKey(this.now());
    const ref = this.db.doc(`stepLog/${uid}_${day}`);
    const s = await ref.get();
    const d = s.exists ? s.data() : { uid, day };
    d.steps = Math.max(Number(d.steps || 0), n);
    d.maxHour = Math.max(Number(d.maxHour || 0), Math.floor(Number(maxHour) || 0));
    d.manual = Math.max(Number(d.manual || 0), Math.floor(Number(manual) || 0));
    d.at = this.now();
    d.expireAt = new Date(this.now() + KEEP);
    await ref.set(d);
    if (d.manual > 0) await this.hit(uid, 'manual', { manual: d.manual });
  }

  /** 진짜 앱 확인 통계 (하루마다: 통과 · 실패 · 없음) */
  async appCheckStat(result) {
    const day = R.dayKey(this.now());
    const ref = this.db.doc(`appCheckStats/${day}`);
    await this.db.runTransaction(async (t) => {
      const s = await t.get(ref);
      const d = s.exists ? s.data() : { ok: 0, bad: 0, missing: 0 };
      d[result] = (d[result] || 0) + 1;
      d.expireAt = new Date(this.now() + KEEP);
      t.set(ref, d);
    });
  }

  /** 운영자 페이지: 의심 목록 + 최근 14일 통과율 */
  async list({ limit = 100 } = {}) {
    const q = await this.db.collection('suspects').get();
    const rows = q.docs
      .map((d) => ({ uid: d.id, ...d.data() }))
      .sort((a, b) => (b.total || 0) - (a.total || 0) || (b.at || 0) - (a.at || 0))
      .slice(0, Math.min(300, limit));
    const out = [];
    for (const r of rows) {
      const days = [];
      for (let i = 0; i < 7; i++) {
        const day = R.dayKey(this.now() - i * 86400000);
        const s = await this.db.doc(`stepLog/${r.uid}_${day}`).get();
        if (s.exists) days.push({ day, steps: s.data().steps || 0, maxHour: s.data().maxHour || 0, manual: s.data().manual || 0 });
      }
      out.push({
        uid: r.uid,
        counts: r.counts || {},
        last: Object.fromEntries(Object.entries(r.last || {}).map(([k, v]) => [k, v.at])),
        total: r.total || 0,
        days,
      });
    }
    const stats = [];
    for (let i = 0; i < 14; i++) {
      const day = R.dayKey(this.now() - i * 86400000);
      const s = await this.db.doc(`appCheckStats/${day}`).get();
      if (s.exists) stats.push({ day, ok: s.data().ok || 0, bad: s.data().bad || 0, missing: s.data().missing || 0 });
    }
    return { items: out, kinds: KINDS, appCheck: stats };
  }
}

module.exports = { SuspectService, KINDS };
