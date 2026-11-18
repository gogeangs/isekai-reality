// 5막 「흑등 연맹의 귀환」 (#247 · 묶음 60): 에르바르드 영지 30 + 왕성 · 야생 수비대(빈 영지) · 깃발 공성전(격주 토·일) ·
// 수비대 배치(길드원 분신 + 동료 2) · 흑등 연맹(NPC) · 연맹(길드 3곳) · 공성 보상 · 거래소 수수료 몫(길드 금고).
// 싸움은 앱이 돌리고 이긴 자리를 알려 준다. 현실 위치는 쓰지 않는다.
// 묶음 61 #250: 공성권은 서버가 셈(함께하는 걸음 · 휴대폰 하나에 계정 하나) · 싸움은 서버가 내준 자리 · 너무 빠른 이김은 세지 않음 ·
// 수비대 레벨은 길드에 남은 레벨을 넘지 않음 · 공성전 기록은 끝난 뒤 8주에 자동 삭제(expireAt)
const R = require('./rules');
const T = require('./siege_estates.json');

class SiegeError extends Error {
  constructor(code, status = 400) {
    super(code);
    this.code = code;
    this.status = status;
  }
}
const fail = (code, status) => {
  throw new SiegeError(code, status);
};

const NPC = 'npc';
const NPC_NAME = '흑등 연맹';
const ESTATES = T.estates;
const byId = Object.fromEntries(ESTATES.map((e) => [e.id, e]));
const DAY = 86400000;
/** 거래소 수수료 중 영지를 가진 길드 금고로 가는 몫 */
const FEE_SHARE = 0.1;
/** 왕성 특별 상자 */
const ROYAL_CHEST = { gold: 1000, manaStone: 30, recruit: 1 };

// 묶음 69 #279: 공성전 일정은 운영자 스위치 (siege_schedule.js)
const SCH = require('./siege_schedule');
const { siegeNo, siegeStart, siegeEnd, siegeActive, lastEnded } = SCH;
const weight = (id) => (id === 'royal' ? T.royalWeight : 1);

/** 공성전 기록 보관: 그 공성전이 끝난 날부터 8주 */
const KEEP_RUN = 56 * DAY;
const runExpire = (n) => new Date(siegeEnd(n) + KEEP_RUN);

const ORD = ['첫째', '둘째', '셋째', '넷째', '다섯째'];

function startWorld() {
  const owners = {};
  for (const e of ESTATES) if (e.npcStart) owners[e.id] = { gid: NPC, name: NPC_NAME, emblem: 0, color: 7, since: 0 };
  return { owners, settled: -1, last: null, crown: null, avgLevel: 30 };
}

class SiegeService {
  constructor(db, { now = () => Date.now(), guild, rand = Math.random, suspect = null, chat = null } = {}) {
    this.db = db;
    this.suspect = suspect;
    // 묶음 68: 길드 소식을 길드 대화방에도 시스템 줄로
    this.chat = chat;
    this.now = now;
    this.guild = guild;
    this.rand = rand;
  }

  /** 묶음 69: 심사용 길드 영지는 다른 사람에겐 흑등 연맹 영지처럼 보임 (빼앗기지도 않음) */
  _view(o, gid) {
    if (o && o.review && o.gid !== gid) return { gid: NPC, name: NPC_NAME, emblem: 0, color: 7, since: 0 };
    return o;
  }

  async _world() {
    const s = await this.db.doc('erbard/world').get();
    if (s.exists) return s.data();
    const w = startWorld();
    await this.db.doc('erbard/world').set(w);
    return w;
  }

  async _restricted(uid) {
    const s = await this.db.doc(`status/${uid}`).get();
    return R.restricted(s.exists ? s.data() : null, this.now());
  }

  async _mine(uid) {
    const gs = await this.db.doc(`guildOf/${uid}`).get();
    const gid = gs.exists ? gs.data().gid : null;
    if (!gid) return { gid: null, g: null };
    const g = (await this.db.doc(`guilds/${gid}`).get()).data() || null;
    return { gid: g ? gid : null, g };
  }

  _count(w, gid) {
    return Object.values(w.owners).filter((o) => o && o.gid === gid).length;
  }

  async _allies(gid, g) {
    if (!g || !g.alliance) return [gid];
    const a = await this.db.doc(`alliances/${g.alliance}`).get();
    return a.exists ? a.data().guilds || [gid] : [gid];
  }

  async _avgLevel() {
    const q = await this.db.collection('guilds').get();
    const lv = [];
    for (const d of q.docs) for (const m of Object.values(d.data().members || {})) lv.push(Number(m.level) || 1);
    return lv.length ? Math.round(lv.reduce((a, b) => a + b, 0) / lv.length) : 30;
  }

  // ───────────── 공성권 (서버가 셈)

  /**
   * 함께하는 걸음(손으로 입력한 걸음 뺌)으로 2,000보마다 1장, 최대 20장.
   * 처음 한 번은 앱에 있던 장수(최대 20)를 그대로 옮김. 오늘 걸음은 그 휴대폰에서 그날 처음 올린 계정에만
   */
  async tickets(uid, me = {}) {
    const ref = this.db.doc(`siegeTicket/${uid}`);
    const now = this.now();
    const day = R.dayKey(now);
    const has = me && me.steps != null;
    const steps = has ? Math.max(0, Math.floor(Number(me.steps) || 0)) : 0;
    let counted = true;
    if (has && me.device) {
      const dref = this.db.doc(`dayclaims/s_${String(me.device).slice(0, 80)}_${day}`);
      const ds = await dref.get();
      if (!ds.exists) await dref.set({ uid, expireAt: new Date(now + 3 * DAY) });
      else if (ds.data().uid !== uid) counted = false;
    }
    let out = null;
    let added = 0;
    await this.db.runTransaction(async (t) => {
      const s = await t.get(ref);
      let d;
      if (!s.exists) {
        const bank = Math.max(0, Math.min(T.ticketMax, Math.floor(Number(me.tickets) || 0)));
        const carry = bank >= T.ticketMax ? 0 : Math.max(0, Math.min(T.ticketSteps - 1, Math.floor(Number(me.carry) || 0)));
        d = { bank, carry, day, dayCounted: steps, at: now };
      } else {
        d = s.data();
        if (d.day !== day) {
          d.day = day;
          d.dayCounted = 0;
        }
        if (has && counted && steps > (d.dayCounted || 0)) {
          added = steps - (d.dayCounted || 0);
          d.carry = (d.carry || 0) + steps - (d.dayCounted || 0);
          d.dayCounted = steps;
          d.bank = Math.min(T.ticketMax, (d.bank || 0) + Math.floor(d.carry / T.ticketSteps));
          d.carry = d.bank >= T.ticketMax ? 0 : d.carry % T.ticketSteps;
        }
      }
      t.set(ref, d);
      out = { tickets: d.bank || 0, carry: d.carry || 0 };
    });
    // 묶음 65: 공성전 동안 걸음은 길드 게이지에도 (진짜 앱 확인 실패 · 손 입력 걸음은 빼고 — 앱이 손 입력을 이미 뺌)
    if (added > 0 && !(me && me.__bad)) await this._addGauge(uid, added);
    // 묶음 65 #255: 같은 걸음이 우리 영지 주민 의뢰에도
    if (added > 0 && !(me && me.__bad)) await this._addRequestSteps(uid, added);
    return out;
  }

  async _spendTicket(uid) {
    const ref = this.db.doc(`siegeTicket/${uid}`);
    await this.db.runTransaction(async (t) => {
      const s = await t.get(ref);
      const d = s.exists ? s.data() : { bank: 0, carry: 0 };
      if (!(d.bank > 0)) fail('no_ticket');
      d.bank -= 1;
      t.set(ref, d);
    });
  }

  // ───────────── 묶음 65 #251: 집결 깃발 · 공성 망치 · 성벽 보수 · 전황 소식

  /** 길드 게시판 소식 한 줄 (최근 30줄) */
  async _news(gid, text, key = null) {
    if (!gid || gid === NPC) return;
    const ref = this.db.doc(`guilds/${gid}`);
    let wrote = false;
    await this.db.runTransaction(async (t) => {
      const s = await t.get(ref);
      if (!s.exists) return;
      const g = s.data();
      if (key) {
        // 같은 소식은 3시간에 한 번 (공격받고 있어요)
        g.newsAt = g.newsAt || {};
        if (g.newsAt[key] && this.now() - g.newsAt[key] < 3 * 3600000) return;
        g.newsAt[key] = this.now();
      }
      g.news = [...(g.news || []), { at: this.now(), text }].slice(-30);
      t.set(ref, g);
      wrote = true;
    });
    if (wrote && this.chat) await this.chat.system(`g_${gid}`, text);
  }

  _gaugeRef(n, gid) {
    return this.db.doc(`siegeGauge/${n}_${gid}`);
  }

  /** 길드 게이지 한 칸 (인원에 맞춤) */
  async _gaugeSize(gid) {
    const g = (await this.db.doc(`guilds/${gid}`).get()).data() || {};
    return T.gaugePerHead * Math.max(5, Object.keys(g.members || {}).length);
  }

  /** 공성전 동안 걸은 걸음 → 길드 게이지 (공성 망치 · 성벽 보수 둘 다) */
  async _addGauge(uid, steps) {
    const now = this.now();
    if (steps <= 0) return;
    const { gid } = await this._mine(uid);
    if (!gid || !siegeActive(now, gid)) return;
    const n = siegeNo(now, gid);
    const ref = this._gaugeRef(n, gid);
    await this.db.runTransaction(async (t) => {
      const s = await t.get(ref);
      const d = s.exists ? s.data() : { no: n, gid, steps: 0, rams: 0, repairs: {} };
      d.steps = (d.steps || 0) + steps;
      d.by = d.by || {};
      d.by[uid] = (d.by[uid] || 0) + steps;
      d.expireAt = runExpire(n);
      t.set(ref, d);
    });
    await this._applyGauge(n, gid);
  }

  /** 묶음 66: 가득 찬 게이지 = 「쓸 수 있는 힘」. 길드장 · 부길드장이 공성 망치 · 성벽 보수 중 고름 (공성전이 끝나면 사라짐) */
  async _power(n, gid) {
    const d = (await this._gaugeRef(n, gid).get()).data() || { steps: 0, rams: 0, repairs: {} };
    const full = Math.floor((d.steps || 0) / (await this._gaugeSize(gid)));
    const used = (d.rams || 0) + Object.keys(d.repairs || {}).length;
    return { d, full, left: Math.max(0, full - used) };
  }

  /** 힘이 새로 모이면 게시판에 한 줄 (자동으로 쓰지 않음) */
  async _applyGauge(n, gid) {
    if (!gid || gid === NPC) return;
    const { d, full, left } = await this._power(n, gid);
    if (left > 0 && full > (d.told || 0)) {
      await this._gaugeRef(n, gid).set({ ...d, told: full });
      await this._news(gid, '길드 걸음 게이지가 가득 찼어요. 공성 망치나 성벽 보수에 쓸 수 있어요');
    }
  }

  /** 힘 쓰기: kind 'ram'(집결 영지 다음 자리 흔들기, 공성전당 2번) · 'repair'(우리 영지 깨진 자리 하나, 영지마다 1번) */
  async usePower(uid, { kind, estate } = {}) {
    const { gid, g } = await this._mine(uid);
    if (!gid) fail('no_guild');
    if (!(g.owner === uid || (g.vices || []).includes(uid))) fail('not_staff', 403);
    const now = this.now();
    if (!siegeActive(now, gid)) fail('not_siege');
    const n = siegeNo(now, gid);
    const ref = this._gaugeRef(n, gid);
    const { d, left } = await this._power(n, gid);
    if (left <= 0) fail('no_power');
    const w = await this._world();
    if (kind === 'ram') {
      if ((d.rams || 0) >= T.ramMax) fail('ram_max');
      const rally = (await this.db.doc(`siegeRally/${n}_${gid}`).get()).data();
      if (!rally || !w.owners[rally.estate] || w.owners[rally.estate].gid === gid) fail('no_rally');
      const rref = this.db.doc(`siegeRun/${n}_${rally.estate}`);
      let hit = null;
      await this.db.runTransaction(async (t) => {
        const rs = await t.get(rref);
        const r = rs.exists ? rs.data() : { no: n, estate: rally.estate, g: {} };
        const x = r.g[gid] || { broken: [] };
        x.weak = x.weak || [];
        const k = [0, 1, 2, 3, 4].find((i) => !x.broken.includes(i) && !x.weak.includes(i));
        if (k == null) return;
        x.weak.push(k);
        r.g[gid] = x;
        r.expireAt = runExpire(n);
        t.set(rref, r);
        hit = k;
      });
      if (hit == null) fail('no_target');
      await ref.set({ ...d, rams: (d.rams || 0) + 1, expireAt: runExpire(n) });
      await this._news(gid, `공성 망치로 ${byId[rally.estate].name} ${ORD[hit]} 자리를 흔들었어요`);
    } else if (kind === 'repair') {
      const mine = ESTATES.filter((e) => w.owners[e.id] && w.owners[e.id].gid === gid).map((e) => e.id);
      const left2 = mine.filter((id) => !(d.repairs || {})[id]);
      const runs = {};
      for (const id of left2) runs[id] = (await this.db.doc(`siegeRun/${n}_${id}`).get()).data() || null;
      const most = (id) => Math.max(0, ...Object.values((runs[id] || {}).g || {}).map((x) => (x.broken || []).length));
      const pick = estate ? (left2.includes(estate) && most(estate) > 0 ? estate : null) : left2.filter((id) => most(id) > 0).sort((a, b) => most(b) - most(a))[0];
      if (!pick) fail(estate && (d.repairs || {})[estate] ? 'repaired' : 'no_target');
      const rref = this.db.doc(`siegeRun/${n}_${pick}`);
      let fixed = null;
      let from = null;
      await this.db.runTransaction(async (t) => {
        const r = (await t.get(rref)).data();
        const top = Object.entries(r.g || {}).sort((a, b) => (b[1].broken || []).length - (a[1].broken || []).length)[0];
        if (!top || !(top[1].broken || []).length) return;
        fixed = top[1].broken.pop();
        from = top[0];
        delete top[1].doneAt;
        t.set(rref, r);
      });
      if (fixed == null) fail('no_target');
      await ref.set({ ...d, repairs: { ...(d.repairs || {}), [pick]: true }, expireAt: runExpire(n) });
      await this._news(gid, `성벽 보수로 ${byId[pick].name} ${ORD[fixed]} 자리를 되살렸어요`);
      await this._news(from, `${byId[pick].name}의 성벽이 보수됐어요. ${ORD[fixed]} 자리가 다시 섰어요`);
    } else {
      fail('bad_kind');
    }
    return this.state(uid);
  }

  /** 집결 깃발 (길드장 · 부길드장, 공성전 동안 6시간마다 바꿈) */
  async rally(uid, { estate } = {}) {
    const e = byId[estate];
    if (!e) fail('bad_estate');
    if (await this._restricted(uid)) fail('restricted', 403);
    const { gid, g } = await this._mine(uid);
    if (!gid) fail('no_guild');
    if (!(g.owner === uid || (g.vices || []).includes(uid))) fail('not_staff', 403);
    const now = this.now();
    if (!siegeActive(now, gid)) fail('not_siege');
    const w = await this._world();
    const o = this._view(w.owners[e.id], gid);
    if (o && o.gid === gid) fail('own');
    if (o && (await this._allies(gid, g)).includes(o.gid)) fail('ally');
    const n = siegeNo(now, gid);
    const ref = this.db.doc(`siegeRally/${n}_${gid}`);
    const cur = (await ref.get()).data();
    if (cur && cur.estate !== e.id && now - cur.at < T.rallyHours * 3600000) fail('rally_wait');
    await ref.set({ estate: e.id, at: cur && cur.estate === e.id ? cur.at : now, by: uid, expireAt: runExpire(n) });
    if (!cur || cur.estate !== e.id) await this._news(gid, `${(g.members[uid] || {}).name || '길드원'}님이 ${e.name}에 집결 깃발을 꽂았어요. ${e.name}에 집결해요`);
    await this._applyGauge(n, gid);
    return this.state(uid);
  }

  /** 성벽 보수할 영지 고르기 (길드장 · 부길드장) */
  async repairTarget(uid, { estate } = {}) {
    if (!byId[estate]) fail('bad_estate');
    const { gid, g } = await this._mine(uid);
    if (!gid) fail('no_guild');
    if (!(g.owner === uid || (g.vices || []).includes(uid))) fail('not_staff', 403);
    const n = siegeNo(this.now(), gid);
    await this.db.doc(`guilds/${gid}`).set({ ...g, repairTarget: { n, estate } });
    await this._applyGauge(n, gid);
    return this.state(uid);
  }

  /** 엿보기: 수비대 다섯 자리 (주 직업 · 함께 선 동료 수, 능력치는 숨김) */
  async peek(uid, { estate } = {}) {
    const e = byId[estate];
    if (!e) fail('bad_estate');
    const { gid } = await this._mine(uid);
    const w = await this._world();
    const o = this._view(w.owners[e.id], gid);
    const n = siegeNo(this.now(), gid);
    const run = gid ? ((((await this.db.doc(`siegeRun/${n}_${e.id}`).get()).data() || {}).g || {})[gid] || {}) : {};
    const gs = o && o.gid !== NPC ? (await this.db.doc(`garrison/${e.id}`).get()).data() || {} : {};
    return {
      estate: e.id,
      slots: [0, 1, 2, 3, 4].map((k) => {
        const x = (gs.slots || [])[k];
        return {
          broken: (run.broken || []).includes(k),
          weak: (run.weak || []).includes(k),
          kind: !o ? 'wild' : o.gid === NPC ? (e.id === 'royal' || k === 4 ? 'blackCaptain' : 'blackGuard') : x ? 'clone' : 'empty',
          job: x ? x.job || null : null,
          allies: x ? (x.allies || []).length : 0,
        };
      }),
    };
  }

  /** 끝난 공성전 정리 (state · 매일 정리 때) */
  async settleDue() {
    const w = await this._world();
    const last = lastEnded(this.now());
    let done = 0;
    for (let n = w.settled + 1; n <= last; n++) {
      await this.settle(n);
      done++;
    }
    return { settled: done };
  }

  async settle(n) {
    const w = await this._world();
    if (w.settled >= n) return w.last;
    // 묶음 65 #255: 주인이 바뀌기 전에 그날 특산물까지 원래 주인 창고에
    await this._produceAll(w);
    const changes = [];
    const runs = await this.db.collection('siegeRun').where('no', '==', n).get();
    const guilds = {};
    const guildOf = async (gid) => {
      if (!(gid in guilds)) guilds[gid] = (await this.db.doc(`guilds/${gid}`).get()).data() || null;
      return guilds[gid];
    };
    // 1. 다섯 자리를 모두 먼저 깬 길드가 차지 (영지 세 곳까지 · 왕성은 두 곳 이상)
    const runList = runs.docs.map((d) => d.data()).sort((a, b) => (a.estate === 'royal') - (b.estate === 'royal'));
    for (const r of runList) {
      const owner = w.owners[r.estate];
      const done = Object.entries(r.g || {})
        .filter(([, x]) => x.doneAt)
        .sort((a, b) => a[1].doneAt - b[1].doneAt);
      for (const [gid] of done) {
        if (owner && owner.gid === gid) break;
        const g = await guildOf(gid);
        if (!g) continue;
        const cnt = this._count(w, gid);
        if (cnt >= T.maxEstates) continue;
        if (r.estate === 'royal' && cnt < T.royalNeeds) continue;
        w.owners[r.estate] = { gid, name: g.name, emblem: g.emblem || 0, color: g.color || 0, since: n };
        changes.push({ estate: r.estate, from: owner ? owner.gid : null, fromName: owner ? owner.name : '', to: gid, toName: g.name });
        await this.db.doc(`garrison/${r.estate}`).set({ gid, slots: [null, null, null, null, null] });
        break;
      }
    }
    // 묶음 69: 테스트 공성전이면 그 길드들만 (흑등 연맹은 움직이지 않음)
    const tst = SCH.get().test && SCH.get().test.no === n ? new Set(SCH.get().test.gids) : null;
    // 2. 흑등 연맹: 빈 영지 하나, 없으면 가장 약한 영지 하나를 노림.
    //    묶음 65: 왕관의 무게 — 왕성을 세 번 이상 연속 가지면 왕성부터 노림 · 연맹 영지는 늘 npcMin 곳 이상
    if (!tst) {
    const prevCrown = w.crown;
    const royalNow = w.owners.royal;
    w.crownStreak = royalNow && royalNow.gid !== NPC ? (royalNow.gid === prevCrown ? (w.crownStreak || 0) + 1 : 1) : 0;
    const npcTake = async (id, o) => {
      w.owners[id] = { gid: NPC, name: NPC_NAME, emblem: 0, color: 7, since: n };
      changes.push({ estate: id, from: o ? o.gid : null, fromName: o ? o.name : '', to: NPC, toName: NPC_NAME });
      if (o) await this.db.doc(`garrison/${id}`).set({ gid: NPC, slots: [null, null, null, null, null] });
    };
    const filledOf = async (id) => {
      const gs = await this.db.doc(`garrison/${id}`).get();
      return gs.exists ? (gs.data().slots || []).filter(Boolean).length : 0;
    };
    let took = false;
    if (w.crownStreak >= 3 && royalNow && (await filledOf('royal')) < Math.min(T.slots, w.crownStreak)) {
      await npcTake('royal', royalNow);
      w.crownStreak = 0;
      took = true;
    }
    const npcCount = () => ESTATES.filter((e) => w.owners[e.id] && w.owners[e.id].gid === NPC).length;
    let guard = 0;
    while ((!took || npcCount() < T.npcMin) && guard++ < 40) {
      const empty = ESTATES.filter((e) => !w.owners[e.id]);
      if (empty.length) {
        const e = empty[(n * 7 + 3 + guard) % empty.length];
        await npcTake(e.id, null);
        took = true;
        continue;
      }
      let weakest = null;
      for (const e of ESTATES) {
        const o = w.owners[e.id];
        if (!o || o.gid === NPC || o.review || e.id === 'royal') continue;
        const filled = await filledOf(e.id);
        if (!weakest || filled < weakest.filled) weakest = { id: e.id, filled, o };
      }
      // 한 곳만 노릴 때는 수비가 약한 곳만 (예전 그대로) · 최소를 채울 때는 가장 약한 곳
      if (!weakest || (!took && weakest.filled >= 3 && npcCount() >= T.npcMin)) break;
      await npcTake(weakest.id, weakest.o);
      took = true;
    }
    }
    // 3. 보상: 영지 1곳당(왕성 3곳분) 길드원 모두 등불 인장 · 공성권을 쓴 사람은 더 · 져도 참여 보상. 연맹은 점수를 나눔
    const weights = {};
    for (const [id, o] of Object.entries(w.owners)) if (o && o.gid !== NPC && !o.review && (!tst || tst.has(o.gid))) weights[o.gid] = (weights[o.gid] || 0) + weight(id);
    const use = (await this.db.doc(`siegeUse/${n}`).get()).data() || { u: {} };
    const users = use.u || {};
    const gids = new Set([...Object.keys(weights), ...Object.values(users).map((x) => x.gid).filter(Boolean)]);
    for (const gid of Object.keys(weights)) {
      const g = await guildOf(gid);
      for (const x of await this._allies(gid, g)) gids.add(x);
    }
    const royal = w.owners.royal;
    for (const gid of gids) {
      const g = await guildOf(gid);
      if (!g) continue;
      const team = await this._allies(gid, g);
      const wsum = team.reduce((a, x) => a + (weights[x] || 0), 0);
      for (const uid of Object.keys(g.members || {})) {
        const used = users[uid] && users[uid].n > 0;
        const seal = wsum * T.siegeSealsPerEstate + (used ? T.siegeTicketSeals : 0) + (!wsum && used ? T.siegeJoinSeals : 0);
        if (seal <= 0) continue;
        await this.db.collection(`inbox/u_${uid}/msgs`).add({
          from: '세라',
          title: `제${n + 1}회 깃발 공성전 보상`,
          body: wsum ? `길드가 지킨 영지만큼 등불 인장을 보내네. 다음 공성전도 함께하자.` : '이번엔 영지를 얻지 못했지만, 함께 걸은 걸음은 남는다.',
          reward: { lanternSeal: seal },
          equips: [],
          at: this.now(),
          kind: 'siege',
        });
      }
      if (royal && royal.gid === gid) {
        for (const uid of Object.keys(g.members || {})) {
          await this.db.collection(`inbox/u_${uid}/msgs`).add({
            from: '세라',
            title: '왕성 특별 상자',
            body: '에르바르드 왕성을 지킨 길드에게. 다음 공성전까지 깃발에 왕관이 걸려.',
            reward: ROYAL_CHEST,
            equips: [],
            op: { title: 'erbardCrown' },
            at: this.now(),
            kind: 'siege',
          });
        }
      }
    }
    // 4. 두 주 거래소 수수료 합계의 10%를 영지 수 비율로 길드 금고에 (왕성 3곳분)
    const to = siegeEnd(n);
    const from = to - T.period;
    const logs = await this.db.collection('marketLog').where('at', '>=', from).get();
    const fees = logs.docs.map((d) => d.data()).filter((x) => x.at < to).reduce((a, x) => a + (Number(x.fee) || 0), 0);
    // 묶음 65 #255: 시장 · 교역 정책이 있으면 몫이 조금 더
    const feeW = {};
    for (const [id, o] of Object.entries(w.owners)) if (o && o.gid !== NPC && !o.review) feeW[o.gid] = (feeW[o.gid] || 0) + weight(id) * (await this._devFee(id));
    const wall = Object.values(feeW).reduce((a, b) => a + b, 0);
    if (fees > 0 && wall > 0) {
      for (const [gid, wt] of Object.entries(feeW)) {
        const add = Math.floor((fees * FEE_SHARE * wt) / wall);
        if (add <= 0) continue;
        const ref = this.db.doc(`guilds/${gid}`);
        await this.db.runTransaction(async (t) => {
          const s = await t.get(ref);
          if (!s.exists) return;
          t.set(ref, { ...s.data(), treasury: Number(s.data().treasury || 0) + add });
        });
      }
    }
    // 묶음 66: 선봉장 칭호는 공성전에 참여한 길드(공성권을 쓴 길드원이 있는 길드)의 길드장 (대표 결정).
    // 자리를 가장 많이 깬 사람(같으면 먼저 깬 사람)은 길드 소식에 이름만 한 줄
    const best = {};
    const joined = new Set();
    for (const [uid, x] of Object.entries(users)) {
      if (!x.gid) continue;
      if (x.n > 0) joined.add(x.gid);
      if (!(x.wins > 0)) continue;
      const b = best[x.gid];
      if (!b || x.wins > b.wins || (x.wins === b.wins && (x.firstWinAt || 0) < (b.firstWinAt || 0))) best[x.gid] = { uid, ...x };
    }
    const vanguards = {};
    for (const gid of joined) {
      const g = await guildOf(gid);
      if (!g || !g.owner) continue;
      const name = ((g.members || {})[g.owner] || {}).name || '';
      vanguards[gid] = name;
      await this.db.collection(`inbox/u_${g.owner}/msgs`).add({
        from: '세라',
        title: `제${n + 1}회 깃발 공성전 선봉장`,
        body: '길드를 이끌고 공성전에 나선 당신에게. 다음 공성전이 끝날 때까지 「선봉장」이라 불릴 거야.',
        reward: {},
        equips: [],
        op: { vanguard: n },
        at: this.now(),
        kind: 'siege',
      });
      await this._news(gid, `${name}님이 제${n + 1}회 공성전 선봉장이 됐어요`);
      const b = best[gid];
      const top = b && (g.members || {})[b.uid] ? g.members[b.uid].name : '';
      if (top) await this._news(gid, `제${n + 1}회 공성전에서 자리를 가장 많이 깬 사람 · ${top}님`);
    }
    w.crown = royal && royal.gid !== NPC ? royal.gid : null;
    w.last = { no: n, royal: royal ? { gid: royal.gid, name: royal.name } : null, changes, at: this.now(), vanguards };
    w.settled = n;
    w.avgLevel = await this._avgLevel();
    await this.db.doc('erbard/world').set(w);
    return w.last;
  }

  // ───────────── 지도 · 내 길드

  async state(uid, me = {}) {
    await this.settleDue();
    const tk = await this.tickets(uid, me);
    const now = this.now();
    const w = await this._world();
    const { gid, g } = await this._mine(uid);
    const n = siegeNo(now, gid);
    const team = gid ? await this._allies(gid, g) : [];
    const mine = gid ? ESTATES.filter((e) => w.owners[e.id] && w.owners[e.id].gid === gid).map((e) => e.id) : [];
    const garrisons = {};
    let placed = null;
    const boosts = {};
    for (const id of mine) {
      const s = await this.db.doc(`garrison/${id}`).get();
      const slots = s.exists ? s.data().slots || [] : [];
      const b = s.exists ? s.data().boost : null;
      if (b && b.until > now) boosts[id] = b.level;
      garrisons[id] = slots.map((x) => (x ? { uid: x.uid, name: x.name, level: x.level, job: x.job || null, allies: (x.allies || []).map((a) => a.name), me: x.uid === uid } : null));
      if (slots.some((x) => x && x.uid === uid)) placed = id;
    }
    const wild = {};
    const run = {};
    const weak = {};
    const defense = {};
    let rally = null;
    let gauge = null;
    if (gid) {
      const ws = await this.db.collection('wild').get();
      for (const d of ws.docs) if (d.data().g && d.data().g[gid]) wild[d.id] = d.data().g[gid];
      const rs = await this.db.collection('siegeRun').where('no', '==', n).get();
      for (const d of rs.docs) {
        const r = d.data();
        if (r.g && r.g[gid]) {
          run[r.estate] = r.g[gid].broken;
          if ((r.g[gid].weak || []).length) weak[r.estate] = r.g[gid].weak;
        }
        // 묶음 65 전황판: 우리 영지마다 가장 많이 깨진 자리 수
        if (mine.includes(r.estate)) defense[r.estate] = Math.max(0, ...Object.values(r.g || {}).map((x) => (x.broken || []).length));
      }
      const rd = (await this.db.doc(`siegeRally/${n}_${gid}`).get()).data();
      if (rd && siegeActive(now, gid)) rally = { estate: rd.estate, at: rd.at, nextAt: rd.at + T.rallyHours * 3600000 };
      const gd = (await this._gaugeRef(n, gid).get()).data() || { steps: 0, rams: 0, repairs: {} };
      const size = await this._gaugeSize(gid);
      const full = Math.floor((gd.steps || 0) / size);
      gauge = {
        progress: ((gd.steps || 0) % size) / size,
        full,
        // 묶음 66: 쓸 수 있는 힘 (고르기 전까지 쌓임)
        power: Math.max(0, full - (gd.rams || 0) - Object.keys(gd.repairs || {}).length),
        rams: gd.rams || 0,
        ramMax: T.ramMax,
        repairs: Object.keys(gd.repairs || {}),
        repairTarget: g.repairTarget && g.repairTarget.n === n ? g.repairTarget.estate : null,
      };
    }
    const use = (await this.db.doc(`siegeUse/${n}`).get()).data() || { u: {} };
    let alliance = null;
    if (g && g.alliance) {
      const a = await this.db.doc(`alliances/${g.alliance}`).get();
      if (a.exists) {
        const names = [];
        for (const x of a.data().guilds || []) names.push(((await this.db.doc(`guilds/${x}`).get()).data() || {}).name || '');
        alliance = { id: g.alliance, name: a.data().name, code: a.data().code, guilds: names, locked: n - (a.data().formed || 0) < T.allianceLock && n >= (a.data().formed || 0) };
      }
    }
    return {
      owners: Object.fromEntries(
        Object.entries(w.owners).map(([id, raw]) => [id, raw, this._view(raw, gid)]).map(([id, , o]) => [id, o ? { gid: o.gid === gid ? 'mine' : team.includes(o.gid) ? 'ally' : o.gid === NPC ? NPC : 'other', name: o.name, emblem: o.emblem, color: o.color, crown: id === 'royal' && !!w.crown } : null]),
      ),
      // 묶음 69 #279: 닫혀 있으면 start · end 가 없음 (null) · open 이 false → 앱은 「곧 열려요」
      siege: {
        no: n,
        active: siegeActive(now, gid),
        start: Number.isFinite(siegeStart(n)) ? siegeStart(n) : null,
        end: Number.isFinite(siegeEnd(n)) ? siegeEnd(n) : null,
        open: SCH.openFor(gid, now),
        test: SCH.testFor(gid) && now < SCH.get().test.end,
        schedule: SCH.publicView(),
      },
      guild: gid
        ? {
            estates: mine,
            treasury: Number(g.treasury || 0),
            staff: g.owner === uid || (g.vices || []).includes(uid),
            owner: g.owner === uid,
            shareNo: lastEnded(now),
            canShare: g.owner === uid && lastEnded(now) >= 0 && !siegeActive(now, gid) && (g.treasuryShare ?? -1) < lastEnded(now),
            goldFlag: !!g.goldFlag,
            log: (g.tlog || []).slice(-20).reverse(),
          }
        : null,
      garrisons,
      boosts,
      tickets: tk.tickets,
      ticketCarry: tk.carry,
      placed,
      wild,
      run,
      used: (use.u[uid] || {}).n || 0,
      last: w.last,
      alliance,
      // 묶음 65 #251
      rally,
      gauge,
      weak,
      defense,
      news: g ? (g.news || []).slice(-15).reverse() : [],
      crownStreak: w.crown && w.crown === gid ? w.crownStreak || 0 : 0,
      // 묶음 65 #255: 영지 번영 단계 (지도 아이콘이 커짐)
      stages: ((await this.db.doc('erbard/stages').get()).data() || {}).s || {},
      restricted: await this._restricted(uid),
    };
  }

  /** 다음 싸울 자리 · 상대 (앱이 이걸로 싸움을 만든다) */
  async foe(uid, { estate } = {}) {
    const r = await this._foe(uid, { estate });
    // 묶음 61: 서버가 내준 자리 · 시각 (fight 에서 맞춰 봄)
    if (r.slot != null) {
      const tk = await this.tickets(uid, {});
      if (tk.tickets <= 0) fail('no_ticket');
      await this.db.doc(`fightTok/${uid}`).set({ estate, slot: r.slot, kind: r.kind, at: this.now(), expireAt: new Date(this.now() + DAY) });
    }
    return r;
  }

  async _foe(uid, { estate } = {}) {
    const e = byId[estate];
    if (!e) fail('bad_estate');
    if (await this._restricted(uid)) fail('restricted', 403);
    const { gid, g } = await this._mine(uid);
    if (!gid) fail('no_guild');
    const now = this.now();
    const w = await this._world();
    const o = this._view(w.owners[e.id], gid);
    const lv = Math.max(20, w.avgLevel || 30);
    if (!o) {
      const ws = (await this.db.doc(`wild/${e.id}`).get()).data() || { g: {} };
      const broken = (ws.g || {})[gid] || [];
      const slot = [0, 1, 2, 3, 4].find((k) => !broken.includes(k));
      return { kind: 'wild', slot, level: lv, broken };
    }
    if (o.gid === gid) fail('own');
    const team = await this._allies(gid, g);
    if (team.includes(o.gid)) fail('ally');
    if (!siegeActive(now, gid)) fail('not_siege');
    const n = siegeNo(now, gid);
    const cnt = this._count(w, gid);
    if (cnt >= T.maxEstates) fail('full');
    if (e.id === 'royal' && cnt < T.royalNeeds) fail('royal_locked');
    const rs = (await this.db.doc(`siegeRun/${n}_${e.id}`).get()).data() || { g: {} };
    const broken = ((rs.g || {})[gid] || {}).broken || [];
    const weakSlots = ((rs.g || {})[gid] || {}).weak || [];
    const slot = [0, 1, 2, 3, 4].find((k) => !broken.includes(k));
    const rally = ((await this.db.doc(`siegeRally/${n}_${gid}`).get()).data() || {}).estate === e.id;
    const weakened = slot != null && weakSlots.includes(slot);
    if (o.gid === NPC) return { kind: 'siege', slot, level: lv, broken, npc: true, rally, weakened };
    const gs = (await this.db.doc(`garrison/${e.id}`).get()).data() || { slots: [] };
    const guard = slot == null ? null : (gs.slots || [])[slot] || null;
    const og = (await this.db.doc(`guilds/${o.gid}`).get()).data() || {};
    const ms = Object.values(og.members || {});
    const steps = ms.reduce((a, m) => a + (Number(m.week) || 0) + (Number(m.prevWeek) || 0), 0);
    let stepBonus = Math.min(T.garrisonStepMax, (T.garrisonStepBonus * steps) / Math.max(1, ms.length * T.garrisonStepsPer));
    // 묶음 65: 왕관의 무게 — 왕성을 연속으로 가질수록 걸음 강화가 약해짐
    if (e.id === 'royal' && (w.crownStreak || 0) > 1) stepBonus *= Math.max(0.4, 1 - T.crownDecay * (w.crownStreak - 1));
    // 묶음 61: 길드 금고로 강화한 수비대 (다음 공성전 끝까지)
    const boost = gs.boost && gs.boost.until > now ? T.boostMult[Math.max(0, Math.min(T.boostMult.length - 1, gs.boost.level - 1))] || 0 : 0;
    // 묶음 65 #255: 성벽 · 감시탑 · 방어 우선 정책
    const bonus = stepBonus + boost + (await this._devDefense(e.id));
    const avg = ms.length ? Math.round(ms.reduce((a, m) => a + (Number(m.level) || 1), 0) / ms.length) : lv;
    return {
      kind: 'siege',
      slot,
      level: guard ? guard.level : avg,
      broken,
      guard: guard ? { name: guard.name, level: guard.level, job: guard.job || null, allies: guard.allies || [] } : null,
      bonus,
      rally,
      weakened,
    };
  }

  /** 한 판 결과 (공성권 한 장) */
  async fight(uid, { estate, slot, win, me = {} } = {}) {
    const e = byId[estate];
    if (!e) fail('bad_estate');
    if (await this._restricted(uid)) fail('restricted', 403);
    const { gid, g } = await this._mine(uid);
    if (!gid) fail('no_guild');
    const now = this.now();
    const n = siegeNo(now, gid);
    const k = Number(slot);
    if (!(k >= 0 && k < T.slots)) fail('bad_slot');
    // 묶음 69: 심사용 길드 영지는 다른 길드가 칠 수 없음 (흑등 연맹처럼만 보임)
    const rv = (await this._world()).owners[e.id];
    if (rv && rv.review && rv.gid !== gid) fail('not_siege');
    // 묶음 61: 서버가 내준 자리여야 하고, 공성권 한 장을 씀. 너무 빨리 끝난 이김은 세지 않음 (의심 목록에 남김)
    const tokRef = this.db.doc(`fightTok/${uid}`);
    const tok = (await tokRef.get()).data();
    if (!tok || tok.estate !== estate || tok.slot !== k) fail('no_fight');
    await tokRef.delete();
    await this._spendTicket(uid);
    if (win && now - tok.at < T.minFightMs) {
      win = false;
      if (this.suspect) await this.suspect.hit(uid, 'fight', { estate, ms: now - tok.at });
    }
    const useRef = this.db.doc(`siegeUse/${n}`);
    const markUse = async () => {
      if (!siegeActive(now, gid)) return;
      await this.db.runTransaction(async (t) => {
        const s = await t.get(useRef);
        const d = s.exists ? s.data() : { no: n, u: {} };
        const u = d.u[uid] || { n: 0, gid };
        // 묶음 65: 깬 자리 수 · 처음 깬 때 (선봉장)
        const wins = (u.wins || 0) + (win ? 1 : 0);
        d.u[uid] = { n: u.n + 1, gid, wins, firstWinAt: u.firstWinAt || (win ? now : null) };
        d.expireAt = runExpire(n);
        t.set(useRef, d);
      });
    };
    let w = await this._world();
    const o = this._view(w.owners[e.id], gid);
    if (!o) {
      // 빈 영지: 야생 수비대 (언제든)
      const ref = this.db.doc(`wild/${e.id}`);
      let captured = false;
      let broken = [];
      await this.db.runTransaction(async (t) => {
        const s = await t.get(ref);
        const d = s.exists ? s.data() : { g: {} };
        broken = (d.g[gid] || []).slice();
        if (broken.includes(k)) fail('broken');
        if (win) broken.push(k);
        d.g[gid] = broken;
        t.set(ref, d);
      });
      await markUse();
      if (broken.length >= T.slots) {
        w = await this._world();
        const cnt = this._count(w, gid);
        if (!w.owners[e.id] && cnt < T.maxEstates && e.id !== 'royal') {
          w.owners[e.id] = { gid, name: g.name, emblem: g.emblem || 0, color: g.color || 0, since: n };
          await this.db.doc('erbard/world').set(w);
          await this.db.doc(`wild/${e.id}`).set({ g: {} });
          await this.db.doc(`garrison/${e.id}`).set({ gid, slots: [null, null, null, null, null] });
          captured = true;
        }
      }
      return { kind: 'wild', won: !!win, tickets: (await this.tickets(uid, {})).tickets, broken, captured, full: broken.length >= T.slots, clearSeals: broken.length >= T.slots ? T.wildClearSeals : 0 };
    }
    if (!siegeActive(now, gid)) fail('not_siege');
    if (o.gid === gid) fail('own');
    const team = await this._allies(gid, g);
    if (team.includes(o.gid)) fail('ally');
    const ref = this.db.doc(`siegeRun/${n}_${e.id}`);
    let broken = [];
    await this.db.runTransaction(async (t) => {
      const s = await t.get(ref);
      const d = s.exists ? s.data() : { no: n, estate: e.id, g: {} };
      const x = d.g[gid] || { broken: [] };
      if (x.broken.includes(k)) fail('broken');
      if (win) x.broken.push(k);
      if (x.broken.length >= T.slots && !x.doneAt) x.doneAt = now;
      d.g[gid] = x;
      d.expireAt = runExpire(n);
      broken = x.broken.slice();
      t.set(ref, d);
    });
    await markUse();
    if (win) {
      const who = ((g.members || {})[uid] || {}).name || '길드원';
      await this._news(gid, `${who}님이 ${e.name} ${ORD[k]} 자리를 깼어요`);
      if (o.gid !== NPC) await this._news(o.gid, `우리 영지 ${e.name}가 공격받고 있어요`, `atk_${e.id}`);
      await this._applyGauge(n, gid);
      if (o.gid !== NPC) await this._applyGauge(n, o.gid);
    }
    return { kind: 'siege', won: !!win, broken, full: broken.length >= T.slots, tickets: (await this.tickets(uid, {})).tickets };
  }

  /** 수비대 배치: 우리 길드 영지 한 자리에 내 분신(+ 동료 2) */
  async garrison(uid, { estate, slot, snap = {} } = {}) {
    const e = byId[estate];
    if (!e) fail('bad_estate');
    if (await this._restricted(uid)) fail('restricted', 403);
    const { gid, g } = await this._mine(uid);
    if (!gid) fail('no_guild');
    if (siegeActive(this.now(), gid)) fail('siege_lock');
    const w = await this._world();
    if (!w.owners[e.id] || w.owners[e.id].gid !== gid) fail('not_yours');
    // 묶음 61: 분신 · 동료 레벨은 길드에 남은 내 레벨을 넘지 않음
    const cap = Math.max(1, Number(((g.members || {})[uid] || {}).level) || 1);
    const k = Number(slot);
    if (!(k >= 0 && k < T.slots)) fail('bad_slot');
    // 다른 자리에 있던 내 분신은 뺌
    for (const x of ESTATES) {
      if (!w.owners[x.id] || w.owners[x.id].gid !== gid) continue;
      const ref = this.db.doc(`garrison/${x.id}`);
      const s = await ref.get();
      if (!s.exists) continue;
      const d = s.data();
      if ((d.slots || []).some((y) => y && y.uid === uid)) {
        d.slots = d.slots.map((y) => (y && y.uid === uid ? null : y));
        await ref.set(d);
      }
    }
    const ref = this.db.doc(`garrison/${e.id}`);
    const s = await ref.get();
    const d = s.exists ? s.data() : { gid, slots: [null, null, null, null, null] };
    d.slots = d.slots || [null, null, null, null, null];
    const name = String(snap.name || '각성자').slice(0, 12);
    d.slots[k] = {
      uid,
      name: R.bannedName(name) ? '각성자' : name,
      level: Math.max(1, Math.min(cap, Number(snap.level) || 1)),
      job: snap.job ? String(snap.job).slice(0, 20) : null,
      allies: (Array.isArray(snap.allies) ? snap.allies : []).slice(0, T.garrisonAllies).map((a) => ({
        name: R.bannedName(String(a.name || '')) ? '동료' : String(a.name || '동료').slice(0, 12),
        level: Math.max(1, Math.min(cap, Number(a.level) || 1)),
        job: a.job ? String(a.job).slice(0, 20) : null,
      })),
      at: this.now(),
    };
    await ref.set(d);
    return this.state(uid);
  }

  async ungarrison(uid) {
    const { gid } = await this._mine(uid);
    if (!gid) fail('no_guild');
    if (siegeActive(this.now(), gid)) fail('siege_lock');
    const w = await this._world();
    for (const x of ESTATES) {
      if (!w.owners[x.id] || w.owners[x.id].gid !== gid) continue;
      const ref = this.db.doc(`garrison/${x.id}`);
      const s = await ref.get();
      if (!s.exists) continue;
      const d = s.data();
      d.slots = (d.slots || []).map((y) => (y && y.uid === uid ? null : y));
      await ref.set(d);
    }
    return this.state(uid);
  }

  // ───────────── 연맹 (길드 3곳 · 공성전 4번마다 다시 고름)

  async alliance(uid, { action, name, code } = {}) {
    const { gid, g } = await this._mine(uid);
    if (!gid) fail('no_guild');
    if (g.owner !== uid) fail('not_owner', 403);
    const n = siegeNo(this.now(), gid);
    const gref = this.db.doc(`guilds/${gid}`);
    if (action === 'create') {
      if (g.alliance) fail('already');
      const nm = String(name || '').trim().slice(0, 12);
      if (nm.length < 2 || R.bannedName(nm)) fail('bad_name');
      const c = R.makeCode(this.rand);
      const id = `a_${c}_${this.now()}`;
      await this.db.doc(`alliances/${id}`).set({ name: nm, code: c, guilds: [gid], formed: n, owner: gid });
      await this.db.doc(`allianceCodes/${c}`).set({ id });
      await gref.set({ ...g, alliance: id });
    } else if (action === 'join') {
      if (g.alliance) fail('already');
      const cs = await this.db.doc(`allianceCodes/${String(code || '').toUpperCase()}`).get();
      if (!cs.exists) fail('no_alliance', 404);
      const id = cs.data().id;
      const ref = this.db.doc(`alliances/${id}`);
      await this.db.runTransaction(async (t) => {
        const s = await t.get(ref);
        if (!s.exists) fail('no_alliance', 404);
        const a = s.data();
        if ((a.guilds || []).length >= T.allianceMax) fail('alliance_full');
        a.guilds = [...a.guilds, gid];
        t.set(ref, a);
      });
      await gref.set({ ...g, alliance: id });
    } else if (action === 'leave') {
      if (!g.alliance) fail('no_alliance', 404);
      const ref = this.db.doc(`alliances/${g.alliance}`);
      const s = await ref.get();
      if (s.exists) {
        const a = s.data();
        if (n - (a.formed || 0) < T.allianceLock && n > (a.formed || 0)) fail('alliance_locked');
        a.guilds = (a.guilds || []).filter((x) => x !== gid);
        await ref.set(a);
      }
      const ng = { ...g };
      delete ng.alliance;
      await gref.set(ng);
    } else fail('bad_action');
    return this.state(uid);
  }
}

Object.assign(SiegeService.prototype, require('./estate').EstateMixin);

module.exports = {
  runExpire,
  SiegeService, SiegeError, siegeNo, siegeStart, siegeEnd, siegeActive, lastEnded, NPC, ESTATES, T, startWorld, SCH };
