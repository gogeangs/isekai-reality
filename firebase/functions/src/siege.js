// 5막 「흑등 연맹의 귀환」 (#247 · 묶음 60): 에르바르드 영지 30 + 왕성 · 야생 수비대(빈 영지) · 깃발 공성전(격주 토·일) ·
// 수비대 배치(길드원 분신 + 동료 2) · 흑등 연맹(NPC) · 연맹(길드 3곳) · 공성 보상 · 거래소 수수료 몫(길드 금고).
// 싸움은 앱이 돌리고 이긴 자리를 알려 준다(공성권 · 이김 판정 확인은 다음 묶음 #250). 현실 위치는 쓰지 않는다.
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

function siegeNo(now) {
  const d = now - T.anchor;
  if (d < 0) return 0;
  const n = Math.floor(d / T.period);
  return d - n * T.period < T.length ? n : n + 1;
}
const siegeStart = (n) => T.anchor + n * T.period;
const siegeEnd = (n) => siegeStart(n) + T.length;
const siegeActive = (now) => {
  const n = siegeNo(now);
  return now >= siegeStart(n) && now < siegeEnd(n);
};
/** 이미 끝난 가장 늦은 공성전 번호 (없으면 -1) */
function lastEnded(now) {
  if (now < siegeEnd(0)) return -1;
  return Math.floor((now - siegeEnd(0)) / T.period);
}
const weight = (id) => (id === 'royal' ? T.royalWeight : 1);

function startWorld() {
  const owners = {};
  for (const e of ESTATES) if (e.npcStart) owners[e.id] = { gid: NPC, name: NPC_NAME, emblem: 0, color: 7, since: 0 };
  return { owners, settled: -1, last: null, crown: null, avgLevel: 30 };
}

class SiegeService {
  constructor(db, { now = () => Date.now(), guild, rand = Math.random } = {}) {
    this.db = db;
    this.now = now;
    this.guild = guild;
    this.rand = rand;
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
    // 2. 흑등 연맹: 빈 영지 하나, 없으면 가장 약한 영지 하나를 노림
    const empty = ESTATES.filter((e) => !w.owners[e.id]);
    if (empty.length) {
      const e = empty[(n * 7 + 3) % empty.length];
      w.owners[e.id] = { gid: NPC, name: NPC_NAME, emblem: 0, color: 7, since: n };
      changes.push({ estate: e.id, from: null, fromName: '', to: NPC, toName: NPC_NAME });
    } else {
      let weakest = null;
      for (const e of ESTATES) {
        const o = w.owners[e.id];
        if (!o || o.gid === NPC || e.id === 'royal') continue;
        const gs = await this.db.doc(`garrison/${e.id}`).get();
        const filled = gs.exists ? (gs.data().slots || []).filter(Boolean).length : 0;
        if (!weakest || filled < weakest.filled) weakest = { id: e.id, filled, o };
      }
      if (weakest && weakest.filled < 3) {
        w.owners[weakest.id] = { gid: NPC, name: NPC_NAME, emblem: 0, color: 7, since: n };
        changes.push({ estate: weakest.id, from: weakest.o.gid, fromName: weakest.o.name, to: NPC, toName: NPC_NAME });
        await this.db.doc(`garrison/${weakest.id}`).set({ gid: NPC, slots: [null, null, null, null, null] });
      }
    }
    // 3. 보상: 영지 1곳당(왕성 3곳분) 길드원 모두 등불 인장 · 공성권을 쓴 사람은 더 · 져도 참여 보상. 연맹은 점수를 나눔
    const weights = {};
    for (const [id, o] of Object.entries(w.owners)) if (o && o.gid !== NPC) weights[o.gid] = (weights[o.gid] || 0) + weight(id);
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
    const from = siegeEnd(n - 1);
    const to = siegeEnd(n);
    const logs = await this.db.collection('marketLog').where('at', '>=', from).get();
    const fees = logs.docs.map((d) => d.data()).filter((x) => x.at < to).reduce((a, x) => a + (Number(x.fee) || 0), 0);
    const wall = Object.values(weights).reduce((a, b) => a + b, 0);
    if (fees > 0 && wall > 0) {
      for (const [gid, wt] of Object.entries(weights)) {
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
    w.crown = royal && royal.gid !== NPC ? royal.gid : null;
    w.last = { no: n, royal: royal ? { gid: royal.gid, name: royal.name } : null, changes, at: this.now() };
    w.settled = n;
    w.avgLevel = await this._avgLevel();
    await this.db.doc('erbard/world').set(w);
    return w.last;
  }

  // ───────────── 지도 · 내 길드

  async state(uid) {
    await this.settleDue();
    const now = this.now();
    const w = await this._world();
    const { gid, g } = await this._mine(uid);
    const n = siegeNo(now);
    const team = gid ? await this._allies(gid, g) : [];
    const mine = gid ? ESTATES.filter((e) => w.owners[e.id] && w.owners[e.id].gid === gid).map((e) => e.id) : [];
    const garrisons = {};
    let placed = null;
    for (const id of mine) {
      const s = await this.db.doc(`garrison/${id}`).get();
      const slots = s.exists ? s.data().slots || [] : [];
      garrisons[id] = slots.map((x) => (x ? { uid: x.uid, name: x.name, level: x.level, allies: (x.allies || []).map((a) => a.name), me: x.uid === uid } : null));
      if (slots.some((x) => x && x.uid === uid)) placed = id;
    }
    const wild = {};
    const run = {};
    if (gid) {
      const ws = await this.db.collection('wild').get();
      for (const d of ws.docs) if (d.data().g && d.data().g[gid]) wild[d.id] = d.data().g[gid];
      const rs = await this.db.collection('siegeRun').where('no', '==', n).get();
      for (const d of rs.docs) if (d.data().g && d.data().g[gid]) run[d.data().estate] = d.data().g[gid].broken;
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
        Object.entries(w.owners).map(([id, o]) => [id, o ? { gid: o.gid === gid ? 'mine' : team.includes(o.gid) ? 'ally' : o.gid === NPC ? NPC : 'other', name: o.name, emblem: o.emblem, color: o.color, crown: id === 'royal' && !!w.crown } : null]),
      ),
      siege: { no: n, active: siegeActive(now), start: siegeStart(n), end: siegeEnd(n) },
      guild: gid ? { estates: mine, treasury: Number(g.treasury || 0), staff: g.owner === uid || (g.vices || []).includes(uid), owner: g.owner === uid } : null,
      garrisons,
      placed,
      wild,
      run,
      used: (use.u[uid] || {}).n || 0,
      last: w.last,
      alliance,
      restricted: await this._restricted(uid),
    };
  }

  /** 다음 싸울 자리 · 상대 (앱이 이걸로 싸움을 만든다) */
  async foe(uid, { estate } = {}) {
    const e = byId[estate];
    if (!e) fail('bad_estate');
    if (await this._restricted(uid)) fail('restricted', 403);
    const { gid, g } = await this._mine(uid);
    if (!gid) fail('no_guild');
    const now = this.now();
    const w = await this._world();
    const o = w.owners[e.id];
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
    if (!siegeActive(now)) fail('not_siege');
    const n = siegeNo(now);
    const cnt = this._count(w, gid);
    if (cnt >= T.maxEstates) fail('full');
    if (e.id === 'royal' && cnt < T.royalNeeds) fail('royal_locked');
    const rs = (await this.db.doc(`siegeRun/${n}_${e.id}`).get()).data() || { g: {} };
    const broken = ((rs.g || {})[gid] || {}).broken || [];
    const slot = [0, 1, 2, 3, 4].find((k) => !broken.includes(k));
    if (o.gid === NPC) return { kind: 'siege', slot, level: lv, broken, npc: true };
    const gs = (await this.db.doc(`garrison/${e.id}`).get()).data() || { slots: [] };
    const guard = slot == null ? null : (gs.slots || [])[slot] || null;
    const og = (await this.db.doc(`guilds/${o.gid}`).get()).data() || {};
    const ms = Object.values(og.members || {});
    const steps = ms.reduce((a, m) => a + (Number(m.week) || 0) + (Number(m.prevWeek) || 0), 0);
    const bonus = Math.min(T.garrisonStepMax, (T.garrisonStepBonus * steps) / Math.max(1, ms.length * T.garrisonStepsPer));
    const avg = ms.length ? Math.round(ms.reduce((a, m) => a + (Number(m.level) || 1), 0) / ms.length) : lv;
    return {
      kind: 'siege',
      slot,
      level: guard ? guard.level : avg,
      broken,
      guard: guard ? { name: guard.name, level: guard.level, job: guard.job || null, allies: guard.allies || [] } : null,
      bonus,
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
    const n = siegeNo(now);
    const k = Number(slot);
    if (!(k >= 0 && k < T.slots)) fail('bad_slot');
    const useRef = this.db.doc(`siegeUse/${n}`);
    const markUse = async () => {
      if (!siegeActive(now)) return;
      await this.db.runTransaction(async (t) => {
        const s = await t.get(useRef);
        const d = s.exists ? s.data() : { no: n, u: {} };
        const u = d.u[uid] || { n: 0, gid };
        d.u[uid] = { n: u.n + 1, gid };
        t.set(useRef, d);
      });
    };
    let w = await this._world();
    const o = w.owners[e.id];
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
      return { kind: 'wild', won: !!win, broken, captured, full: broken.length >= T.slots, clearSeals: broken.length >= T.slots ? T.wildClearSeals : 0 };
    }
    if (!siegeActive(now)) fail('not_siege');
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
      broken = x.broken.slice();
      t.set(ref, d);
    });
    await markUse();
    return { kind: 'siege', won: !!win, broken, full: broken.length >= T.slots };
  }

  /** 수비대 배치: 우리 길드 영지 한 자리에 내 분신(+ 동료 2) */
  async garrison(uid, { estate, slot, snap = {} } = {}) {
    const e = byId[estate];
    if (!e) fail('bad_estate');
    if (await this._restricted(uid)) fail('restricted', 403);
    const { gid } = await this._mine(uid);
    if (!gid) fail('no_guild');
    if (siegeActive(this.now())) fail('siege_lock');
    const w = await this._world();
    if (!w.owners[e.id] || w.owners[e.id].gid !== gid) fail('not_yours');
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
    const name = String(snap.name || '각성자').slice(0, 12);
    d.slots[k] = {
      uid,
      name: R.bannedName(name) ? '각성자' : name,
      level: Math.max(1, Math.min(200, Number(snap.level) || 1)),
      job: snap.job ? String(snap.job).slice(0, 20) : null,
      allies: (Array.isArray(snap.allies) ? snap.allies : []).slice(0, T.garrisonAllies).map((a) => ({
        name: R.bannedName(String(a.name || '')) ? '동료' : String(a.name || '동료').slice(0, 12),
        level: Math.max(1, Math.min(200, Number(a.level) || 1)),
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
    if (siegeActive(this.now())) fail('siege_lock');
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
    const n = siegeNo(this.now());
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

module.exports = { SiegeService, SiegeError, siegeNo, siegeStart, siegeEnd, siegeActive, lastEnded, NPC, ESTATES, T, startWorld };
