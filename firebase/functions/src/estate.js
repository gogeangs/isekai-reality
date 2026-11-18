// 묶음 65 (2/2) #255 영지 관리 — 공성전 사이 2주.
// 시설(영지마다 칸, 번영도로 늘어남) · 특산물(길드 창고 → 길드원이 하루 몇 개씩) · 번영도(사냥 · 기부 · 주민 의뢰) ·
// 영주의 정책(공성전 뒤 영지별 하나) · 주민 의뢰(길드원이 함께 걷기).
// 시설 · 번영도 · 정책은 영지에 붙어 있어 빼앗겨도 그대로 넘어간다. 그날 특산물은 원래 주인 창고에.
// 기부 · 사냥 · 의뢰 걸음은 서버가 하루 상한을 셈(#250). 숫자는 화면에 안 보임(시설 짓는 값은 금고 값이라 보임).
const R = require('./rules');

const E = {
  // 시설
  common: ['wall', 'tower', 'market'],
  special: { light: 'light', metal: 'metal', earth: 'earth', dark: 'dark', fire: 'fire' },
  maxLevel: 3,
  buildGold: [2000, 5000, 10000],
  buildMats: [20, 50, 100],
  // 번영도 단계: 마을 → 고을 → 도시 (칸 3 · 4 · 5)
  stageAt: [0, 300, 1000],
  slots: [3, 4, 5],
  // 특산물: 시설 단계 × 번영 단계별 하루 생산 (풍요 정책 ×1.5) · 창고 상한 · 길드원 하루 받기
  prodPer: [2, 3, 4],
  plenty: 1.5,
  storeMax: 300,
  takePerDay: 3,
  prodCatchUp: 3,
  // 번영도 오르는 값
  donatePoint: 1,
  donateDay: 20,
  hunt: 2,
  huntDay: 10,
  request: 100,
  // 수비대 단단: 성벽 · 감시탑 단계마다 · 방어 우선 정책
  wallPer: 0.04,
  towerPer: 0.04,
  defensePolicy: 0.08,
  // 거래소 수수료 몫: 시장 단계마다 · 교역 정책
  marketPer: 0.15,
  tradePolicy: 0.2,
  // 주민 의뢰: 길드원 수(5명보다 적으면 5명)에 맞춘 함께 걷기
  requests: [
    { title: '무너진 다리를 고쳐 주세요', steps: 20000 },
    { title: '우물에 새 두레박을 달아 주세요', steps: 30000 },
    { title: '장터 길에 등불을 밝혀 주세요', steps: 40000 },
    { title: '성벽 아래 밭을 함께 일궈 주세요', steps: 50000 },
  ],
  requestGold: 200,
  requestSeals: 1,
};
const MATS = { light: 'lightRelic', metal: 'metalOre', earth: 'earthWood', dark: 'darkCrystal', fire: 'fireStone' };
const POLICIES = ['defense', 'plenty', 'trade'];
const FAC_NAME = {
  wall: '성벽', tower: '감시탑', market: '시장',
  light: '빛의 성당', metal: '드워프 광산', earth: '엘프 목재소', dark: '결정 우물', fire: '용암 용광로',
};

const stageOf = (p) => {
  let s = 0;
  for (let i = 0; i < E.stageAt.length; i++) if ((p || 0) >= E.stageAt[i]) s = i;
  return s;
};
const blank = () => ({ fac: {}, prosp: 0, policy: null, req: { i: 0, steps: 0, by: {} }, prodDay: null });

/** SiegeService 에 붙이는 영지 관리 (this.db · _mine · _world · _news · now 를 씀) */
const EstateMixin = {
  _devRef(id) {
    return this.db.doc(`estateDev/${id}`);
  },
  async _dev(id) {
    const s = await this._devRef(id).get();
    return s.exists ? { ...blank(), ...s.data() } : blank();
  },

  /** 수비대가 얼마나 단단한지 (공성전 싸움에 더함) */
  async _devDefense(id) {
    const d = await this._dev(id);
    const policy = this._policyNow(d);
    return (d.fac.wall || 0) * E.wallPer + (d.fac.tower || 0) * E.towerPer + (policy === 'defense' ? E.defensePolicy : 0);
  },

  /** 거래소 수수료 몫 배수 */
  async _devFee(id) {
    const d = await this._dev(id);
    return 1 + (d.fac.market || 0) * E.marketPer + (this._policyNow(d) === 'trade' ? E.tradePolicy : 0);
  },

  /** 지금 정책 (안 고르면 풍요) */
  _policyNow(d) {
    const S = require('./siege');
    const p = d.policy;
    if (!p) return 'plenty';
    // 고른 공성전이 끝난 뒤부터 다음 공성전 끝까지
    return p.n >= S.lastEnded(this.now()) ? p.kind : 'plenty';
  },

  /** 특산물: 지난 날들 몫을 지금 주인 창고에 (하루에 한 번 · 최대 사흘치) */
  async _produce(id, w) {
    const S = require('./siege');
    const e = S.ESTATES.find((x) => x.id === id);
    const o = (w.owners || {})[id];
    const kind = e && e.province ? E.special[e.province] : null;
    const ref = this._devRef(id);
    const now = this.now();
    const today = R.dayKey(now);
    const d = await this._dev(id);
    if (d.prodDay === today) return;
    let days = 1;
    if (d.prodDay) {
      const gap = Math.round((Date.parse(today) - Date.parse(d.prodDay)) / 86400000);
      days = Math.max(0, Math.min(E.prodCatchUp, gap));
    }
    const lv = kind ? d.fac[kind] || 0 : 0;
    if (o && o.gid !== S.NPC && lv > 0 && days > 0) {
      let n = lv * E.prodPer[stageOf(d.prosp)] * days;
      if (this._policyNow(d) === 'plenty') n = Math.round(n * E.plenty);
      const gref = this.db.doc(`guilds/${o.gid}`);
      await this.db.runTransaction(async (t) => {
        const s = await t.get(gref);
        if (!s.exists) return;
        const g = s.data();
        const store = { ...(g.store || {}) };
        const m = MATS[e.province];
        store[m] = Math.min(E.storeMax, (store[m] || 0) + n);
        t.set(gref, { ...g, store });
      });
    }
    await ref.set({ ...d, prodDay: today });
  },

  /** 공성전 결과로 주인이 바뀌기 전에 그날 몫까지 원래 주인에게 */
  async _produceAll(w) {
    const S = require('./siege');
    for (const e of S.ESTATES) if ((w.owners || {})[e.id]) await this._produce(e.id, w);
  },

  async _ownEstate(uid, estate, staff = false) {
    const S = require('./siege');
    const e = S.ESTATES.find((x) => x.id === estate);
    if (!e) this._fail('bad_estate');
    if (await this._restricted(uid)) this._fail('restricted', 403);
    const { gid, g } = await this._mine(uid);
    if (!gid) this._fail('no_guild');
    const w = await this._world();
    const o = w.owners[estate];
    if (!o || o.gid !== gid) this._fail('not_yours');
    if (staff && !(g.owner === uid || (g.vices || []).includes(uid))) this._fail('not_staff', 403);
    return { e, gid, g, w };
  },

  _fail(code, status = 400) {
    const S = require('./siege');
    throw new S.SiegeError(code, status);
  },

  /** 영지 관리 화면: 우리 영지들 · 길드 창고 · 오늘 받은 수 · 모든 영지 단계(지도 아이콘) */
  async estateState(uid) {
    const S = require('./siege');
    const { gid, g } = await this._mine(uid);
    const w = await this._world();
    const now = this.now();
    const today = R.dayKey(now);
    const stages = {};
    const mine = [];
    for (const e of S.ESTATES) {
      const o = w.owners[e.id];
      if (!o) continue;
      if (gid && o.gid === gid) await this._produce(e.id, w);
      const d = await this._dev(e.id);
      const st = stageOf(d.prosp);
      if (st > 0) stages[e.id] = st;
      if (gid && o.gid === gid) {
        const members = Math.max(5, Object.keys((g && g.members) || {}).length);
        const rq = E.requests[(d.req.i || 0) % E.requests.length];
        const goal = Math.round((rq.steps * members) / 5);
        mine.push({
          estate: e.id,
          stage: st,
          // 번영도는 다음 단계까지 몇 할인지만 (숫자는 숨김)
          progress: st >= E.stageAt.length - 1 ? 1 : Math.min(1, ((d.prosp || 0) - E.stageAt[st]) / (E.stageAt[st + 1] - E.stageAt[st])),
          slots: E.slots[st],
          fac: d.fac,
          special: e.province ? E.special[e.province] : null,
          policy: this._policyNow(d),
          canPolicy: !S.siegeActive(now, gid) && S.lastEnded(now) >= 0 && !(d.policy && d.policy.n >= S.lastEnded(now)),
          request: { no: d.req.i || 0, title: rq.title, goal, steps: Math.min(goal, d.req.steps || 0), mine: (d.req.by || {})[uid] || 0, people: Object.keys(d.req.by || {}).length },
        });
      }
    }
    const m = gid ? ((g.members || {})[uid] || {}) : {};
    const fresh = gid ? (await this.db.doc(`guilds/${gid}`).get()).data() || {} : {};
    return {
      stages,
      estates: mine,
      help: gid ? await this._helpEstate(gid, fresh, w) : null,
      treasury: Number(fresh.treasury || 0),
      matPool: Number(fresh.matPool || 0),
      store: fresh.store || {},
      take: { left: Math.max(0, E.takePerDay - (m.takeDay === today ? m.takeN || 0 : 0)), per: E.takePerDay },
      donateLeft: Math.max(0, E.donateDay - (m.estDonDay === today ? m.estDonPts || 0 : 0)),
      staff: !!(g && (g.owner === uid || (g.vices || []).includes(uid))),
      buildGold: E.buildGold,
      buildMats: E.buildMats,
      siege: S.siegeActive(now, gid),
    };
  },

  /** 시설 짓기 · 올리기 (길드장 · 부길드장, 공성전 중엔 못 함) — 금고 금화 + 기부 재료 */
  async estateBuild(uid, { estate, kind } = {}) {
    const S = require('./siege');
    const { e, gid, g } = await this._ownEstate(uid, estate, true);
    if (S.siegeActive(this.now(), gid)) this._fail('siege_lock');
    const allowed = [...E.common, ...(e.province ? [E.special[e.province]] : [])];
    if (!allowed.includes(kind)) this._fail('bad_kind');
    const ref = this._devRef(estate);
    const d = await this._dev(estate);
    const cur = d.fac[kind] || 0;
    if (cur >= E.maxLevel) this._fail('max');
    const built = Object.keys(d.fac).filter((k) => d.fac[k] > 0).length;
    if (!cur && built >= E.slots[stageOf(d.prosp)]) this._fail('no_slot');
    const gold = E.buildGold[cur];
    const mats = E.buildMats[cur];
    const who = ((g.members || {})[uid] || {}).name || '길드원';
    const gref = this.db.doc(`guilds/${gid}`);
    const now = this.now();
    await this.db.runTransaction(async (t) => {
      const s = await t.get(gref);
      const x = s.data();
      if (Number(x.treasury || 0) < gold) this._fail('no_treasury');
      if (Number(x.matPool || 0) < mats) this._fail('no_mats');
      x.treasury = Number(x.treasury || 0) - gold;
      x.matPool = Number(x.matPool || 0) - mats;
      x.tlog = [...(x.tlog || []), { at: now, name: who, what: `${e.name} ${FAC_NAME[kind]} ${cur + 1}단계`, gold }].slice(-30);
      t.set(gref, x);
    });
    await ref.set({ ...d, fac: { ...d.fac, [kind]: cur + 1 } });
    await this._news(gid, `${who}님이 ${e.name}에 ${FAC_NAME[kind]}${cur ? `을 ${cur + 1}단계로 올렸어요` : '을 지었어요'}`);
    return this.estateState(uid);
  },

  /** 재료 기부 → 길드 기부 재료 + 그 영지 번영도 (하루 상한) */
  async estateDonate(uid, { estate, mats = {} } = {}) {
    const { e, gid } = await this._ownEstate(uid, estate);
    let points = 0;
    for (const v of Object.values(mats || {})) points += Math.max(0, Math.floor(Number(v) || 0)) * E.donatePoint;
    if (points <= 0) this._fail('bad_amount');
    const today = R.dayKey(this.now());
    const gref = this.db.doc(`guilds/${gid}`);
    await this.db.runTransaction(async (t) => {
      const s = await t.get(gref);
      const g = s.data();
      const m = g.members[uid];
      const used = m.estDonDay === today ? m.estDonPts || 0 : 0;
      if (used + points > E.donateDay) this._fail('donate_limit');
      m.estDonDay = today;
      m.estDonPts = used + points;
      g.matPool = Number(g.matPool || 0) + points;
      t.set(gref, g);
    });
    await this._prosper(estate, points);
    void e;
    return this.estateState(uid);
  },

  /** 그 영지에서 사냥 한 번 → 번영도 (하루 상한) */
  async estateHunt(uid, { estate } = {}) {
    const { gid } = await this._ownEstate(uid, estate);
    const today = R.dayKey(this.now());
    const gref = this.db.doc(`guilds/${gid}`);
    let ok = false;
    await this.db.runTransaction(async (t) => {
      const s = await t.get(gref);
      const g = s.data();
      const m = g.members[uid];
      const used = m.estHuntDay === today ? m.estHuntN || 0 : 0;
      if (used >= E.huntDay) return;
      m.estHuntDay = today;
      m.estHuntN = used + 1;
      ok = true;
      t.set(gref, g);
    });
    if (ok) await this._prosper(estate, E.hunt);
    return { ok };
  },

  async _prosper(estate, n) {
    const ref = this._devRef(estate);
    const d = await this._dev(estate);
    const before = stageOf(d.prosp);
    await ref.set({ ...d, prosp: (d.prosp || 0) + n });
    const after = stageOf((d.prosp || 0) + n);
    if (after !== before) await this._setStage(estate, after);
  },

  /** 지도 아이콘용 단계 (한 문서에 모아 둠) */
  async _setStage(estate, st) {
    const ref = this.db.doc('erbard/stages');
    await this.db.runTransaction(async (t) => {
      const s = await t.get(ref);
      const x = s.exists ? s.data() : { s: {} };
      const m = { ...(x.s || {}) };
      if (st > 0) m[estate] = st;
      else delete m[estate];
      t.set(ref, { s: m });
    });
  },

  /** 영주의 정책 (공성전이 끝난 뒤 영지별 하나, 다음 공성전 끝까지) */
  async estatePolicy(uid, { estate, kind } = {}) {
    const S = require('./siege');
    const { e, gid, g } = await this._ownEstate(uid, estate, true);
    if (!POLICIES.includes(kind)) this._fail('bad_kind');
    const now = this.now();
    const n = S.lastEnded(now);
    if (S.siegeActive(now, gid) || n < 0) this._fail('not_yet');
    const d = await this._dev(estate);
    if (d.policy && d.policy.n >= n) this._fail('chosen');
    await this._devRef(estate).set({ ...d, policy: { kind, n, by: uid } });
    const who = ((g.members || {})[uid] || {}).name || '길드원';
    const name = { defense: '방어 우선', plenty: '풍요', trade: '교역' }[kind];
    await this._news(gid, `${who}님이 ${e.name}의 정책을 「${name}」으로 정했어요`);
    return this.estateState(uid);
  },

  /** 길드 창고에서 특산물 받기 (길드원 하루 몇 개) */
  async estateTake(uid, { mat, n = 1 } = {}) {
    const { gid } = await this._mine(uid);
    if (!gid) this._fail('no_guild');
    if (!Object.values(MATS).includes(mat)) this._fail('bad_mat');
    const want = Math.max(1, Math.floor(Number(n) || 1));
    const today = R.dayKey(this.now());
    const gref = this.db.doc(`guilds/${gid}`);
    let got = 0;
    await this.db.runTransaction(async (t) => {
      const s = await t.get(gref);
      const g = s.data();
      const m = g.members[uid];
      const used = m.takeDay === today ? m.takeN || 0 : 0;
      const store = { ...(g.store || {}) };
      got = Math.min(want, E.takePerDay - used, store[mat] || 0);
      if (got <= 0) this._fail(used >= E.takePerDay ? 'take_limit' : 'empty');
      store[mat] -= got;
      m.takeDay = today;
      m.takeN = used + got;
      t.set(gref, { ...g, store });
    });
    return { got: { [mat]: got }, state: await this.estateState(uid) };
  },

  /** 묶음 66: 주민 의뢰를 돕는 영지 (길드장 · 부길드장이 고름, 안 고르면 진행이 가장 많이 된 영지) */
  async _helpEstate(gid, g, w) {
    const mine = Object.entries(w.owners || {}).filter(([, o]) => o && o.gid === gid).map(([id]) => id);
    if (!mine.length) return null;
    if (g && g.helpEstate && mine.includes(g.helpEstate)) return g.helpEstate;
    let best = mine[0];
    let bestSteps = -1;
    for (const id of mine) {
      const d = await this._dev(id);
      if ((d.req.steps || 0) > bestSteps) {
        best = id;
        bestSteps = d.req.steps || 0;
      }
    }
    return best;
  },

  async estateHelp(uid, { estate } = {}) {
    const { gid } = await this._ownEstate(uid, estate, true);
    const gref = this.db.doc(`guilds/${gid}`);
    const g = (await gref.get()).data();
    await gref.set({ ...g, helpEstate: estate });
    return this.estateState(uid);
  },

  /** 걸음 → 돕는 영지 한 곳의 주민 의뢰 (공성권 셈과 같은 걸음, 진짜 앱 확인 실패 걸음은 빼고) */
  async _addRequestSteps(uid, steps) {
    if (steps <= 0) return;
    const { gid, g } = await this._mine(uid);
    if (!gid) return;
    const w = await this._world();
    const members = Math.max(5, Object.keys(g.members || {}).length);
    const help = await this._helpEstate(gid, g, w);
    for (const [id, o] of Object.entries(w.owners || {})) {
      if (!o || o.gid !== gid || id !== help) continue;
      const d = await this._dev(id);
      const rq = E.requests[(d.req.i || 0) % E.requests.length];
      const goal = Math.round((rq.steps * members) / 5);
      const by = { ...(d.req.by || {}) };
      by[uid] = (by[uid] || 0) + steps;
      let req = { ...d.req, steps: (d.req.steps || 0) + steps, by };
      let prosp = d.prosp || 0;
      if (req.steps >= goal) {
        // 다 걸으면: 번영도 + 함께 걸은 길드원 보상 → 다음 의뢰
        prosp += E.request;
        const S = require('./siege');
        const e = S.ESTATES.find((x) => x.id === id);
        for (const u of Object.keys(by)) {
          if (!(g.members || {})[u]) continue;
          await this.db.collection(`inbox/u_${u}/msgs`).add({
            from: `${e.name} 주민`,
            title: `「${rq.title}」 고마워요`,
            body: '길드원이 함께 걸어 준 덕분에 영지가 조금 더 살기 좋아졌어요.',
            reward: { gold: E.requestGold, lanternSeal: E.requestSeals },
            equips: [],
            at: this.now(),
            kind: 'estate',
          });
        }
        await this._news(gid, `${e.name} 주민 의뢰 「${rq.title}」를 함께 해냈어요`);
        req = { i: (d.req.i || 0) + 1, steps: 0, by: {} };
      }
      await this._devRef(id).set({ ...d, req, prosp });
      if (stageOf(prosp) !== stageOf(d.prosp)) await this._setStage(id, stageOf(prosp));
    }
  },
};

module.exports = { EstateMixin, E, MATS, POLICIES, stageOf };
