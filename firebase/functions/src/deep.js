// 심층 주간 순위 (묶음 58 #243): 주마다 한 지역이 그 주의 심층. 그 지역 심층에서 가장 깊이 간 층.
// 로그인한 사람만 · 이름은 금칙어 판정 · 같은 휴대폰 계정은 가장 깊은 하나만 순위에 · 제재 중이면 빠짐.
// 주가 끝나면(매일 새벽 정리 때) 지난주 순위별로 우편 보상.
const R = require('./rules');

const REGIONS = ['selenia', 'elowin', 'morval', 'aurel'];
const MAX_FLOOR = 999;
const TOP = 50;
/** 순위별 보상 (개발 초안): [몇 위까지, 금화, 마석] · 그 밖 참가 */
const PRIZES = [
  [1, 1000, 30],
  [3, 700, 20],
  [10, 400, 10],
  [50, 250, 5],
];
const JOIN_PRIZE = { gold: 100 };

function regionOf(week) {
  const i = R.weekIndex(week);
  return REGIONS[((i % REGIONS.length) + REGIONS.length) % REGIONS.length];
}

function prizeOf(rank) {
  for (const [upTo, gold, manaStone] of PRIZES) if (rank <= upTo) return { gold, manaStone };
  return JOIN_PRIZE;
}

function safeName(n) {
  const s = String(n || '').trim().slice(0, 12);
  return !s || R.bannedName(s) ? '각성자' : s;
}

class DeepService {
  constructor(db, { now = () => Date.now() } = {}) {
    this.db = db;
    this.now = now;
  }

  week() {
    const w = R.weekKey(this.now());
    return { week: w, region: regionOf(w) };
  }

  async _devices(uid) {
    const u = await this.db.doc(`users/${uid}`).get();
    const d = u.exists ? u.data() : {};
    return [...new Set([...(d.devices || []), ...(d.device ? [d.device] : [])])];
  }

  async submit(uid, { region, floor, me = {} } = {}) {
    const { week, region: want } = this.week();
    if (region !== want) return { ok: false, week, region: want };
    const f = Math.floor(Number(floor) || 0);
    if (f < 6 || f > MAX_FLOOR) return { ok: false, week, region: want };
    const st = await this.db.doc(`status/${uid}`).get();
    if (R.restricted(st.exists ? st.data() : null, this.now())) return { ok: false, restricted: true, week, region: want };
    const ref = this.db.doc(`deepRank/${week}/rows/${uid}`);
    const s = await ref.get();
    const old = s.exists ? s.data().floor || 0 : 0;
    if (f > old) {
      await ref.set({ floor: f, name: safeName(me.name), at: this.now(), devices: await this._devices(uid), expireAt: new Date(this.now() + 6 * 7 * 86400000) });
    }
    return { ok: true, week, region: want, floor: Math.max(f, old) };
  }

  /** 순위 (같은 휴대폰 계정은 가장 깊은 하나만) */
  async _ranked(week) {
    const q = await this.db.collection(`deepRank/${week}/rows`).get();
    const rows = q.docs
      .map((d) => ({ uid: d.id, ...d.data() }))
      .sort((a, b) => b.floor - a.floor || a.at - b.at);
    const seen = new Set();
    const out = [];
    for (const r of rows) {
      const ds = r.devices || [];
      if (ds.some((d) => seen.has(d))) continue;
      ds.forEach((d) => seen.add(d));
      const st = await this.db.doc(`status/${r.uid}`).get();
      if (R.restricted(st.exists ? st.data() : null, this.now())) continue;
      out.push(r);
    }
    return out;
  }

  async board(uid) {
    const { week, region } = this.week();
    const ranked = await this._ranked(week);
    const i = ranked.findIndex((r) => r.uid === uid);
    return {
      week,
      region,
      top: ranked.slice(0, TOP).map((r, k) => ({ rank: k + 1, name: r.name, floor: r.floor, me: r.uid === uid })),
      me: i < 0 ? null : { rank: i + 1, floor: ranked[i].floor },
      total: ranked.length,
    };
  }

  /** 지난주 보상 (한 번만) */
  async payLastWeek() {
    const last = R.weekKey(this.now() - 7 * 86400000);
    const ref = this.db.doc(`deepPaid/${last}`);
    if ((await ref.get()).exists) return { paid: 0 };
    const ranked = await this._ranked(last);
    await ref.set({ at: this.now(), n: ranked.length });
    for (const [k, r] of ranked.entries()) {
      const reward = prizeOf(k + 1);
      await this.db.collection(`inbox/u_${r.uid}/msgs`).add({
        from: '하르트',
        title: `지난주 심층 순위 ${k + 1}위`,
        body: `지난주 심층에서 ${r.floor}층까지 내려갔네. 수고했네, 각성자.`,
        reward,
        equips: [],
        at: this.now(),
      });
    }
    // 묶음 60: 보상을 보낸 뒤 4주에 지움 (Firestore TTL: rows.expireAt)
    const all = await this.db.collection(`deepRank/${last}/rows`).get();
    for (const d of all.docs) await d.ref.set({ ...d.data(), expireAt: new Date(this.now() + 28 * 86400000) });
    return { paid: ranked.length };
  }
}

module.exports = { DeepService, regionOf, prizeOf, REGIONS };
