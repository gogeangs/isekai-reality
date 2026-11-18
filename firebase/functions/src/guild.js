// 길드 (#246 · 묶음 59): 만들기(창설 증서 · 금화는 앱이) · 들어가기(공개 목록 · 초대 코드 · 링크) · 나가기 · 내보내기 ·
// 길드장 넘기기 · 부길드장 · 꾸미기 · 길드 레벨(모두의 걸음) · 주간 걸음 목표 · 회관(기부 · ★ · 게시판 한마디 · 창고 · 꾸미기) ·
// 레이드(빛을 먹는 거인 한 번 + 주간 돌아가며) · 보상 받기. 길드 기록은 서버만 읽고 씀. 위치는 쓰지 않음.
const R = require('./rules');

class GuildError extends Error {
  constructor(code, status = 400) {
    super(code);
    this.code = code;
    this.status = status;
  }
}
const fail = (code, status) => {
  throw new GuildError(code, status);
};

const G = {
  BASE_MEMBERS: 20,
  /** 레벨마다 늘어나는 자리: Lv.3 22 · Lv.5 24 · Lv.7 26 · Lv.9 28 · Lv.10 30 */
  SIZE: [0, 20, 20, 22, 22, 24, 24, 26, 26, 28, 30],
  /** 길드 레벨에 필요한 모두의 걸음 = 한 사람 몫 × max(5, 인원) (숨은 값) */
  LEVEL_PER_HEAD: [0, 0, 30000, 70000, 120000, 190000, 280000, 390000, 520000, 680000, 880000],
  VICES: 2,
  /** 주간 걸음 목표: 한 사람 2만 · 5만 · 8만 × 인원 → 등불 인장 10 · 20 · 30 */
  WEEK_PER_HEAD: [20000, 50000, 80000],
  WEEK_SEALS: [10, 20, 30],
  /** 회관 ★: [필요한 길드 레벨, 필요한 회관 점수] */
  STARS: [null, [1, 0], [3, 3000], [6, 10000], [10, 30000]],
  /** 기부: 금화 10당 1점 · 재료 하나 2점 → 점수 20마다 등불 인장 1, 하루 점수 한도 */
  DONATE_GOLD_PER_POINT: 10,
  DONATE_MAT_POINT: 2,
  DONATE_POINTS_PER_SEAL: 20,
  DONATE_DAY_POINTS: 400,
  /** 창고(★2): 길드원에게 재료 보내기 하루 10개까지 */
  SHARE_PER_DAY: 10,
  /** 레이드 도전권: 3,000보마다 1장 · 하루 3장 (깃대 ★4 면 하나 더) */
  RAID_TICKET_STEPS: 3000,
  RAID_TICKETS: 3,
  RAIDS: ['raidDragon', 'raidLich', 'raidTortoise'],
  /** 보상: 쓰러뜨리면 등불 인장 + 보스 재료 + 상자, Lv.7 이면 인장 더 */
  RAID_WIN: { seal: 40, raidMat: 2 },
  RAID_WIN_LV7: 15,
  BOARD_LINE_MAX: 40,
  DECOS: ['plaque', 'lights', 'flowerbed', 'fountain', 'statue', 'campfire', 'spring', 'summer', 'autumn', 'winter', 'goldLights', 'goldFountain'],
  /** 금고 쓰기 기록은 최근 50줄만 */
  TLOG_MAX: 50,
  DECO_SLOTS: 4,
};

function sizeOf(level) {
  return G.SIZE[Math.max(1, Math.min(10, level))];
}

function levelOf(total, members) {
  const heads = Math.max(5, members);
  let lv = 1;
  for (let l = 2; l <= 10; l++) if (total >= G.LEVEL_PER_HEAD[l] * heads) lv = l;
  return lv;
}

/** 다음 레벨까지 얼마나 왔는지 (0~1, 숫자는 안 보여 줌) */
function levelProgress(total, members, lv) {
  if (lv >= 10) return 1;
  const heads = Math.max(5, members);
  const a = G.LEVEL_PER_HEAD[lv] * heads;
  const b = G.LEVEL_PER_HEAD[lv + 1] * heads;
  return Math.max(0, Math.min(1, (total - a) / Math.max(1, b - a)));
}

function starOf(level, points) {
  let s = 1;
  for (let i = 2; i <= 4; i++) if (level >= G.STARS[i][0] && points >= G.STARS[i][1]) s = i;
  return s;
}

function raidOf(week) {
  const i = R.weekIndex(week);
  const n = ((i % G.RAIDS.length) + G.RAIDS.length) % G.RAIDS.length;
  return { id: G.RAIDS[n], encounter: Math.floor(i / G.RAIDS.length) + 1 };
}

/** 레이드 체력: 파티 보스보다 큼 (인원 · 평균 레벨) */
function raidHp(members, avgLevel, id, encounter = 1) {
  const k = id === 'raidGiant' ? 8 : 12;
  return Math.round(R.perFight(avgLevel) * k * Math.max(3, members) * (1 + 0.1 * (Math.max(1, encounter) - 1)));
}

function safeName(n) {
  const s = String(n || '').trim().slice(0, 12);
  return !s || R.bannedName(s) ? '각성자' : s;
}

function cleanGuildName(name) {
  const n = String(name || '').trim().replace(/\s+/g, ' ');
  if (n.length < 2 || n.length > 12) return null;
  if (R.bannedName(n)) return null;
  return n;
}

class GuildService {
  constructor(db, { now = () => Date.now(), rand = Math.random } = {}) {
    this.db = db;
    this.now = now;
    this.rand = rand;
  }

  async _restricted(uid) {
    const s = await this.db.doc(`status/${uid}`).get();
    return R.restricted(s.exists ? s.data() : null, this.now());
  }

  async _block(uid) {
    if (await this._restricted(uid)) fail('restricted', 403);
  }

  async _devices(uid) {
    const u = await this.db.doc(`users/${uid}`).get();
    const d = u.exists ? u.data() : {};
    return new Set([...(d.devices || []), ...(d.device ? [d.device] : [])]);
  }

  async _gid(uid) {
    const s = await this.db.doc(`guildOf/${uid}`).get();
    return s.exists ? s.data().gid : null;
  }

  async _guild(gid) {
    const s = await this.db.doc(`guilds/${gid}`).get();
    return s.exists ? s.data() : null;
  }

  async _mine(uid) {
    const gid = await this._gid(uid);
    const g = gid && (await this._guild(gid));
    if (!g) fail('no_guild', 404);
    return { gid, g };
  }

  _role(g, uid) {
    if (g.owner === uid) return 'owner';
    if ((g.vices || []).includes(uid)) return 'vice';
    return 'member';
  }

  _needStaff(g, uid) {
    if (this._role(g, uid) === 'member') fail('not_staff', 403);
  }

  // ───────────── 만들기 · 들어가기 · 나가기

  async create(uid, { name, emblem = 0, color = 0, open = true, me = {} } = {}) {
    await this._block(uid);
    if (await this._gid(uid)) fail('already_in_guild');
    if (name && R.bannedName(name)) fail('banned_word');
    const nm = cleanGuildName(name);
    if (!nm) fail('bad_name');
    let code;
    for (let i = 0; i < 10; i++) {
      const c = R.makeCode(this.rand);
      if (!(await this.db.doc(`guildCodes/${c}`).get()).exists) {
        code = c;
        break;
      }
    }
    if (!code) fail('busy', 503);
    const gid = `g_${code}_${this.now()}`;
    const at = this.now();
    await this.db.runTransaction(async (t) => {
      t.set(this.db.doc(`guilds/${gid}`), {
        name: nm,
        emblem: Number(emblem) % R.EMBLEMS.length || 0,
        color: Number(color) % R.COLORS || 0,
        open: !!open,
        owner: uid,
        vices: [],
        code,
        createdAt: at,
        steps: 0,
        hall: { points: 0, decos: [], slots: [null, null, null, null] },
        titles: [],
        members: { [uid]: memberOf(me, at) },
      });
      t.set(this.db.doc(`guildCodes/${code}`), { gid });
      t.set(this.db.doc(`guildOf/${uid}`), { gid });
    });
    return this.state(uid, me);
  }

  async _join(uid, gid, me) {
    await this._block(uid);
    if (await this._gid(uid)) fail('already_in_guild');
    const g = await this._guild(gid);
    if (!g) fail('no_guild', 404);
    const lv = levelOf(g.steps || 0, Object.keys(g.members || {}).length);
    if (Object.keys(g.members || {}).length >= sizeOf(lv)) fail('full');
    // 운영정책: 같은 휴대폰에서 로그인한 계정끼리는 같은 길드에 못 들어감
    const mine = await this._devices(uid);
    for (const other of Object.keys(g.members || {})) {
      const theirs = await this._devices(other);
      for (const d of mine) if (theirs.has(d)) fail('same_device');
    }
    await this.db.runTransaction(async (t) => {
      const s = await t.get(this.db.doc(`guilds/${gid}`));
      const cur = s.data();
      cur.members = { ...cur.members, [uid]: memberOf(me, this.now()) };
      t.set(this.db.doc(`guilds/${gid}`), cur);
      t.set(this.db.doc(`guildOf/${uid}`), { gid });
    });
    return this.state(uid, me);
  }

  async join(uid, { code, gid, me = {} } = {}) {
    if (gid) {
      const g = await this._guild(String(gid));
      if (!g || !g.open) fail('no_guild', 404);
      return this._join(uid, String(gid), me);
    }
    const c = String(code || '').trim().toUpperCase();
    const ref = await this.db.doc(`guildCodes/${c}`).get();
    if (!ref.exists) fail('no_guild', 404);
    return this._join(uid, ref.data().gid, me);
  }

  /** 공개 모집 길드 목록 (이름 찾기) */
  async list(uid, { q } = {}) {
    const s = await this.db.collection('guilds').where('open', '==', true).get();
    const word = String(q || '').trim();
    const items = s.docs
      .map((d) => ({ gid: d.id, ...d.data() }))
      .filter((g) => !word || String(g.name).includes(word))
      .map((g) => {
        const n = Object.keys(g.members || {}).length;
        const lv = levelOf(g.steps || 0, n);
        return { gid: g.gid, name: g.name, emblem: g.emblem, color: g.color, level: lv, members: n, size: sizeOf(lv) };
      })
      .filter((g) => g.members < g.size)
      .sort((a, b) => b.level - a.level || b.members - a.members)
      .slice(0, 50);
    return { items };
  }

  async _remove(gid, uid) {
    await this.db.runTransaction(async (t) => {
      const s = await t.get(this.db.doc(`guilds/${gid}`));
      if (!s.exists) return;
      const g = s.data();
      const members = { ...(g.members || {}) };
      delete members[uid];
      t.delete(this.db.doc(`guildOf/${uid}`));
      if (Object.keys(members).length === 0) {
        t.delete(this.db.doc(`guilds/${gid}`));
        t.delete(this.db.doc(`guildCodes/${g.code}`));
        return;
      }
      let owner = g.owner;
      let vices = (g.vices || []).filter((v) => v !== uid);
      if (owner === uid) {
        owner = vices[0] || Object.entries(members).sort((a, b) => (a[1].joinedAt || 0) - (b[1].joinedAt || 0))[0][0];
        vices = vices.filter((v) => v !== owner);
      }
      t.set(this.db.doc(`guilds/${gid}`), { ...g, members, owner, vices });
    });
  }

  async leave(uid) {
    const gid = await this._gid(uid);
    if (!gid) return { guild: null };
    await this._remove(gid, uid);
    return { guild: null };
  }

  async kick(uid, { target, me = {} } = {}) {
    const { gid, g } = await this._mine(uid);
    this._needStaff(g, uid);
    if (!target || target === uid || !(g.members || {})[target]) fail('bad_target');
    if (target === g.owner || (this._role(g, uid) === 'vice' && (g.vices || []).includes(target))) fail('not_owner', 403);
    await this._remove(gid, target);
    return this.state(uid, me);
  }

  /** 길드장만: 부길드장 정하기 · 풀기 · 길드장 넘기기 */
  async role(uid, { target, role, me = {} } = {}) {
    const { gid, g } = await this._mine(uid);
    if (g.owner !== uid) fail('not_owner', 403);
    if (!target || target === uid || !(g.members || {})[target]) fail('bad_target');
    let vices = (g.vices || []).filter((v) => v !== target);
    let owner = g.owner;
    if (role === 'vice') {
      if (vices.length >= G.VICES) fail('vices_full');
      vices.push(target);
    } else if (role === 'owner') {
      owner = target;
      vices = vices.filter((v) => v !== uid);
    } else if (role !== 'member') {
      fail('bad_role');
    }
    await this.db.doc(`guilds/${gid}`).set({ ...g, owner, vices });
    return this.state(uid, me);
  }

  async style(uid, { name, emblem, color, open, me = {} } = {}) {
    const { gid, g } = await this._mine(uid);
    this._needStaff(g, uid);
    const next = { ...g };
    if (name !== undefined) {
      if (R.bannedName(name)) fail('banned_word');
      const n = cleanGuildName(name);
      if (!n) fail('bad_name');
      next.name = n;
    }
    const lv = levelOf(g.steps || 0, Object.keys(g.members || {}).length);
    if (emblem !== undefined) {
      const e = Number(emblem);
      // Lv.9 깃발 꾸미기 더: 그 전엔 앞의 넷만
      if (!(e >= 0 && e < R.EMBLEMS.length) || (lv < 9 && e >= 4)) fail('bad_style');
      next.emblem = e;
    }
    if (color !== undefined) {
      const c = Number(color);
      if (!(c >= 0 && c < R.COLORS) || (lv < 9 && c >= 4)) fail('bad_style');
      next.color = c;
    }
    if (open !== undefined) next.open = !!open;
    await this.db.doc(`guilds/${gid}`).set(next);
    return this.state(uid, me);
  }

  // ───────────── 보기 + 걸음 올리기

  /** [me] = {name, level, steps(오늘), job, device, boost(등불 수호단 2부위)} */
  async state(uid, me = {}) {
    const restricted = await this._restricted(uid);
    const gid = await this._gid(uid);
    const g0 = gid && (await this._guild(gid));
    if (!g0) return { guild: null, restricted };
    const now = this.now();
    const day = R.dayKey(now);
    const wk = R.weekKey(now);
    let counted = true;
    if (!restricted) {
      if (me.device) {
        const dref = this.db.doc(`dayclaims/g_${me.device}_${day}`);
        const ds = await dref.get();
        if (!ds.exists) await dref.set({ uid, expireAt: new Date(now + 3 * 86400000) });
        else if (ds.data().uid !== uid) counted = false;
      }
      await this.db.runTransaction(async (t) => {
        const gs = await t.get(this.db.doc(`guilds/${gid}`));
        const g = gs.data();
        const m = (g.members || {})[uid];
        if (!m) return;
        const steps = Math.max(0, Math.floor(Number(me.steps) || 0));
        m.days = m.days || {};
        const before = Number(m.days[day] || 0);
        if (counted && steps > before) {
          let add = steps - before;
          if (me.boost) add = Math.round(add * 1.1);
          m.days = { [day]: steps };
          m.total = Number(m.total || 0) + add;
          // 묶음 60: 지난주 걸음도 남김 (5막 수비대가 두 주 걸음으로 튼튼해짐)
          if (m.weekKey && m.weekKey !== wk) m.prevWeek = m.weekKey === R.weekKey(now - 7 * 86400000) ? Number(m.week || 0) : 0;
          m.week = m.weekKey === wk ? Number(m.week || 0) + add : add;
          m.weekKey = wk;
          g.steps = Number(g.steps || 0) + add;
        }
        if (me.name) m.name = safeName(me.name);
        if (me.level) m.level = Number(me.level) || m.level;
        if (me.job) m.job = String(me.job).slice(0, 20);
        if (me.sub !== undefined) m.sub = me.sub ? String(me.sub).slice(0, 20) : null;
        t.set(this.db.doc(`guilds/${gid}`), g);
      });
    }
    const g = await this._guild(gid);
    return { ...(await this._view(uid, gid, g, wk, day)), restricted, counted };
  }

  async _week(gid, wk) {
    const s = await this.db.doc(`guilds/${gid}/weeks/${wk}`).get();
    return s.exists ? s.data() : {};
  }

  async _raidDoc(gid, wk, giant) {
    const ref = this.db.doc(giant ? `guilds/${gid}/raids/giant` : `guilds/${gid}/weeks/${wk}`);
    const s = await ref.get();
    return { ref, w: s.exists ? s.data() : {} };
  }

  async _view(uid, gid, g, wk, day) {
    const n = Object.keys(g.members || {}).length;
    const lv = levelOf(g.steps || 0, n);
    const star = starOf(lv, (g.hall || {}).points || 0);
    const members = Object.entries(g.members || {})
      .map(([id, m]) => ({
        uid: id,
        name: m.name,
        level: m.level,
        job: m.job || null,
        weekSteps: m.weekKey === wk ? m.week || 0 : 0,
        line: star >= 1 ? m.line || '' : '',
        role: this._role(g, id),
        me: id === uid,
        joinedAt: m.joinedAt,
      }))
      .sort((a, b) => b.weekSteps - a.weekSteps);
    const weekTotal = members.reduce((s, m) => s + m.weekSteps, 0);
    const w = await this._week(gid, wk);
    const claimed = (w.claimed || {})[uid] || [];
    const goals = G.WEEK_PER_HEAD.map((x) => x * Math.max(1, n));
    const me = (g.members || {})[uid] || {};
    const raid = lv >= 4 ? await this._raidView(uid, gid, g, wk, day, false) : null;
    const giant = lv >= 4 ? await this._raidView(uid, gid, g, wk, day, true) : null;
    return {
      guild: {
        id: gid,
        name: g.name,
        emblem: g.emblem || 0,
        color: g.color || 0,
        open: !!g.open,
        code: g.code,
        role: this._role(g, uid),
        level: lv,
        progress: levelProgress(g.steps || 0, n, lv),
        size: sizeOf(lv),
        titles: g.titles || [],
        giantDone: !!g.giantDone,
        goldFlag: !!g.goldFlag,
      },
      // 묶음 61: 길드 금고 (모두가 봄) · 쓰기 기록은 게시판에
      treasury: { gold: Number(g.treasury || 0), log: (g.tlog || []).slice(-20).reverse() },
      // 묶음 65: 공성전 소식 (게시판)
      news: (g.news || []).slice(-10).reverse(),
      week: wk,
      members,
      myTotal: me.total || 0,
      joinedAt: me.joinedAt || 0,
      walk: {
        progress: goals.map((x) => Math.min(1, weekTotal / x)),
        done: goals.map((x) => weekTotal >= x),
        claimed: claimed.filter((c) => c.startsWith('walk')).map((c) => Number(c.slice(4))),
        seals: G.WEEK_SEALS,
      },
      hall: {
        star,
        progress: star >= 4 ? 1 : Math.min(1, ((g.hall || {}).points || 0) / G.STARS[star + 1][1]),
        nextLevel: star >= 4 ? null : G.STARS[star + 1][0],
        decos: (g.hall || {}).decos || [],
        slots: (g.hall || {}).slots || [null, null, null, null],
      },
      raid,
      giant,
    };
  }

  async _raidView(uid, gid, g, wk, day, giant) {
    const { w } = await this._raidDoc(gid, wk, giant);
    const b = w.boss;
    if (!b) return { id: giant ? 'raidGiant' : raidOf(wk).id, started: false, defeated: !!(giant && g.giantDone) };
    const total = Object.values(b.dmg || {}).reduce((s, x) => s + x, 0);
    const me = (g.members || {})[uid] || {};
    const steps = me.days ? me.days[day] || 0 : 0;
    const used = ((b.used || {})[uid] || {})[day] || 0;
    const lv = levelOf(g.steps || 0, Object.keys(g.members || {}).length);
    const extra = starOf(lv, (g.hall || {}).points || 0) >= 4 ? 1 : 0;
    return {
      id: b.id,
      started: true,
      progress: Math.min(1, total / Math.max(1, b.hp)),
      myShare: total > 0 ? ((b.dmg || {})[uid] || 0) / total : 0,
      myDamage: (b.dmg || {})[uid] || 0,
      defeated: !!b.defeatedAt,
      tickets: Math.max(0, Math.min(G.RAID_TICKETS + extra, Math.floor(steps / G.RAID_TICKET_STEPS) + 0) - used),
      claimed: ((w.claimed || {})[uid] || []).includes('raid'),
    };
  }

  // ───────────── 한마디 (★1 게시판)

  async line(uid, { text, me = {} } = {}) {
    await this._block(uid);
    const { gid, g } = await this._mine(uid);
    const t = String(text || '').trim().slice(0, G.BOARD_LINE_MAX);
    if (t && R.bannedName(t)) fail('banned_word');
    g.members[uid] = { ...g.members[uid], line: t, lineAt: this.now() };
    await this.db.doc(`guilds/${gid}`).set(g);
    return this.state(uid, me);
  }

  // ───────────── 회관 기부 · 꾸미기 · 창고

  /** 기부: 금화(묶음 61부터 거래 지갑에서) · 재료(앱이 뺌) → 회관 점수 · 등불 인장 */
  async donate(uid, { gold = 0, mats = {}, me = {} } = {}) {
    await this._block(uid);
    const { gid } = await this._mine(uid);
    const day = R.dayKey(this.now());
    let points = Math.floor(Math.max(0, Number(gold) || 0) / G.DONATE_GOLD_PER_POINT);
    for (const v of Object.values(mats || {})) points += Math.max(0, Math.floor(Number(v) || 0)) * G.DONATE_MAT_POINT;
    if (points <= 0) fail('bad_amount');
    let seals = 0;
    const goldN = Math.floor(Math.max(0, Number(gold) || 0));
    await this.db.runTransaction(async (t) => {
      const s = await t.get(this.db.doc(`guilds/${gid}`));
      const wref = this.db.doc(`tradeWallet/${uid}`);
      const ws = goldN > 0 ? await t.get(wref) : null;
      const g = s.data();
      const m = g.members[uid];
      if (goldN > 0) {
        const have = ws && ws.exists ? Number(ws.data().gold || 0) : 0;
        if (have < goldN) fail('no_wallet_gold');
        t.set(wref, { ...(ws.exists ? ws.data() : {}), gold: have - goldN, at: this.now() });
      }
      const today = m.donateDay === day ? m.donatePts || 0 : 0;
      if (today + points > G.DONATE_DAY_POINTS) fail('donate_limit');
      const prevSeals = Math.floor(today / G.DONATE_POINTS_PER_SEAL);
      m.donateDay = day;
      m.donatePts = today + points;
      seals = Math.floor(m.donatePts / G.DONATE_POINTS_PER_SEAL) - prevSeals;
      g.hall = { ...(g.hall || {}), points: ((g.hall || {}).points || 0) + points };
      t.set(this.db.doc(`guilds/${gid}`), g);
    });
    return { points, seals, state: await this.state(uid, me) };
  }

  /** 꾸미기를 회관에 들임 (길드장 · 부길드장이 자기 등불 인장으로 산 것) */
  async decoAdd(uid, { id, me = {} } = {}) {
    const { gid, g } = await this._mine(uid);
    this._needStaff(g, uid);
    if (!G.DECOS.includes(id) || String(id).startsWith('gold')) fail('bad_deco');
    const decos = new Set((g.hall || {}).decos || []);
    if (decos.has(id)) fail('owned');
    decos.add(id);
    g.hall = { ...(g.hall || {}), decos: [...decos] };
    await this.db.doc(`guilds/${gid}`).set(g);
    return this.state(uid, me);
  }

  /** 꾸미기 자리 4곳 (길드장) */
  async decoPlace(uid, { slot, id, me = {} } = {}) {
    const { gid, g } = await this._mine(uid);
    if (g.owner !== uid) fail('not_owner', 403);
    const i = Number(slot);
    if (!(i >= 0 && i < G.DECO_SLOTS)) fail('bad_slot');
    const decos = (g.hall || {}).decos || [];
    if (id != null && id !== 'flag' && !decos.includes(id)) fail('bad_deco');
    const slots = [...((g.hall || {}).slots || [null, null, null, null])];
    for (let k = 0; k < slots.length; k++) if (id != null && slots[k] === id) slots[k] = null;
    slots[i] = id || null;
    g.hall = { ...(g.hall || {}), slots };
    await this.db.doc(`guilds/${gid}`).set(g);
    return this.state(uid, me);
  }

  /** 창고(★2): 길드원에게 재료 보내기 (하루 한도, 우편으로) */
  async share(uid, { target, mat, qty, me = {} } = {}) {
    await this._block(uid);
    const { gid, g } = await this._mine(uid);
    const n = (await this.state(uid, me)).hall.star;
    if (n < 2) fail('need_star');
    if (!target || target === uid || !(g.members || {})[target]) fail('bad_target');
    const q = Math.floor(Number(qty) || 0);
    if (q < 1 || !/^[A-Za-z0-9]{1,40}$/.test(String(mat || ''))) fail('bad_amount');
    const day = R.dayKey(this.now());
    const ref = this.db.doc(`guildShare/${uid}_${day}`);
    const s = await ref.get();
    const used = s.exists ? s.data().n || 0 : 0;
    if (used + q > G.SHARE_PER_DAY) fail('share_limit');
    await ref.set({ n: used + q, expireAt: new Date(this.now() + 2 * 86400000) });
    await this.db.collection(`inbox/u_${target}/msgs`).add({
      from: g.members[uid].name || '길드원',
      title: '길드 창고에서 재료가 왔어요',
      body: `${g.name} 길드원이 나눠 준 재료예요.`,
      reward: { [mat]: q },
      equips: [],
      at: this.now(),
    });
    return { ok: true, left: G.SHARE_PER_DAY - used - q };
  }

  // ───────────── 묶음 61: 길드 금고 쓰기 (수비대 강화 · 회관 공사 · 나눠 주기 · 금고 상점). 쓸 때마다 게시판에 한 줄

  async treasury(uid, { action, estate, level, amount, id, me = {} } = {}) {
    await this._block(uid);
    const S = require('./siege');
    const T = S.T;
    const { gid, g } = await this._mine(uid);
    const now = this.now();
    const who = ((g.members || {})[uid] || {}).name || '길드원';
    const ref = this.db.doc(`guilds/${gid}`);
    const spend = async (cost, what, mutate) => {
      await this.db.runTransaction(async (t) => {
        const s = await t.get(ref);
        const x = s.data();
        if (Number(x.treasury || 0) < cost) fail('no_treasury');
        x.treasury = Number(x.treasury || 0) - cost;
        if (mutate) mutate(x);
        x.tlog = [...(x.tlog || []), { at: now, name: who, what, gold: cost }].slice(-G.TLOG_MAX);
        t.set(ref, x);
      });
    };
    if (action === 'boost') {
      this._needStaff(g, uid);
      if (S.siegeActive(now, gid)) fail('siege_lock');
      const w = (await this.db.doc('erbard/world').get()).data() || { owners: {} };
      const o = (w.owners || {})[estate];
      if (!o || o.gid !== gid) fail('not_yours');
      const lv = Math.floor(Number(level) || 0);
      if (!(lv >= 1 && lv <= T.boostCost.length)) fail('bad_level');
      const gref = this.db.doc(`garrison/${estate}`);
      const gs = (await gref.get()).data() || { gid, slots: [null, null, null, null, null] };
      const cur = gs.boost && gs.boost.until > now ? gs.boost.level : 0;
      if (cur >= lv) fail('owned');
      // 올리면 차이만큼만
      const cost = T.boostCost[lv - 1] - (cur ? T.boostCost[cur - 1] : 0);
      const name = (S.ESTATES.find((e) => e.id === estate) || {}).name || '영지';
      await spend(cost, `${name} 수비대 강화 ${lv}단계`);
      await gref.set({ ...gs, boost: { level: lv, until: Number.isFinite(S.siegeEnd(S.siegeNo(now, gid))) ? S.siegeEnd(S.siegeNo(now, gid)) : now + 14 * 86400000, by: uid } });
    } else if (action === 'hall') {
      this._needStaff(g, uid);
      const gold = Math.floor(Number(amount) || 0);
      const points = Math.floor(gold / G.DONATE_GOLD_PER_POINT);
      if (points <= 0) fail('bad_amount');
      const day = R.dayKey(now);
      const today = g.hallTDay === day ? g.hallTPts || 0 : 0;
      if (today + points > T.hallTreasuryDayPoints) fail('donate_limit');
      await spend(points * G.DONATE_GOLD_PER_POINT, '회관 공사', (x) => {
        x.hallTDay = day;
        x.hallTPts = today + points;
        x.hall = { ...(x.hall || {}), points: ((x.hall || {}).points || 0) + points };
      });
    } else if (action === 'share') {
      if (g.owner !== uid) fail('not_owner', 403);
      const n = S.lastEnded(now);
      if (n < 0 || S.siegeActive(now, gid)) fail('not_yet');
      if ((g.treasuryShare ?? -1) >= n) fail('shared');
      const use = (await this.db.doc(`siegeUse/${n}`).get()).data() || { u: {} };
      const users = Object.entries(use.u || {})
        .filter(([u, x]) => x.gid === gid && x.n > 0 && (g.members || {})[u])
        .map(([u]) => u);
      if (!users.length) fail('no_users');
      const want = Math.floor(Number(amount) || 0);
      const cap = Math.floor(Number(g.treasury || 0) * T.shareMaxRate);
      if (want <= 0 || want > cap) fail('bad_amount');
      const per = Math.min(T.sharePerHeadMax, Math.floor(want / users.length));
      if (per <= 0) fail('bad_amount');
      await spend(per * users.length, `제${n + 1}회 공성전 나눠 주기 (${users.length}명)`, (x) => {
        if ((x.treasuryShare ?? -1) >= n) fail('shared');
        x.treasuryShare = n;
      });
      for (const u of users) {
        await this.db.collection(`inbox/u_${u}/msgs`).add({
          from: g.name || '길드',
          title: `제${n + 1}회 깃발 공성전 금고 나눔`,
          body: `${who}님이 길드 금고에서 공성전에 나선 길드원에게 똑같이 나눠 준 금화예요.`,
          reward: { gold: per },
          equips: [],
          at: now,
          kind: 'treasury',
        });
      }
    } else if (action === 'shop') {
      this._needStaff(g, uid);
      const price = T.treasuryShop[id];
      if (!price) fail('bad_deco');
      const name = { goldLights: '금빛 등불 줄', goldFountain: '금빛 분수', goldFlag: '금빛 깃발 문양' }[id] || id;
      if (id === 'goldFlag' ? g.goldFlag : ((g.hall || {}).decos || []).includes(id)) fail('owned');
      await spend(price, `금고 상점 · ${name}`, (x) => {
        if (id === 'goldFlag') x.goldFlag = true;
        else x.hall = { ...(x.hall || {}), decos: [...new Set([...((x.hall || {}).decos || []), id])] };
      });
    } else {
      fail('bad_action');
    }
    return this.state(uid, me);
  }

  // ───────────── 레이드 (도전권으로 한 판씩, 피해가 길드 전체로 합쳐짐)

  async raidHit(uid, { giant = false, damage, me = {} } = {}) {
    await this._block(uid);
    const { gid } = await this._mine(uid);
    const view = await this.state(uid, me);
    if (view.guild.level < 4) fail('need_level');
    if (giant && view.guild.giantDone) fail('defeated');
    const r = giant ? view.giant : view.raid;
    if (r.started && r.tickets <= 0) fail('no_ticket');
    if (!r.started) {
      const g = await this._guild(gid);
      if ((Math.floor((((g.members[uid] || {}).days || {})[R.dayKey(this.now())] || 0) / G.RAID_TICKET_STEPS)) <= 0) fail('no_ticket');
    }
    const now = this.now();
    const day = R.dayKey(now);
    const wk = R.weekKey(now);
    const g = await this._guild(gid);
    const level = Number((g.members[uid] || {}).level) || 1;
    const { ref } = await this._raidDoc(gid, wk, giant);
    let defeatedNow = false;
    await this.db.runTransaction(async (t) => {
      const s = await t.get(ref);
      const w = s.exists ? s.data() : {};
      if (!w.boss) {
        const ms = Object.values(g.members || {});
        const avg = Math.round(ms.reduce((x, m) => x + (Number(m.level) || 1), 0) / Math.max(1, ms.length));
        const info = giant ? { id: 'raidGiant', encounter: 1 } : raidOf(wk);
        w.boss = { ...info, hp: raidHp(ms.length, avg, info.id, info.encounter), dmg: {}, used: {} };
      }
      const b = w.boss;
      if (b.defeatedAt) fail('defeated');
      const used = ((b.used[uid] || {})[day]) || 0;
      b.used[uid] = { ...(b.used[uid] || {}), [day]: used + 1 };
      const d = Math.max(0, Math.min(Math.round(R.perFight(level) * 3), Math.floor(Number(damage) || 0)));
      b.dmg[uid] = (b.dmg[uid] || 0) + d;
      const total = Object.values(b.dmg).reduce((x, n) => x + n, 0);
      if (total >= b.hp) {
        b.defeatedAt = now;
        defeatedNow = true;
      }
      t.set(ref, w);
    });
    if (defeatedNow) {
      const g2 = await this._guild(gid);
      const bid = giant ? 'raidGiant' : raidOf(wk).id;
      const titles = new Set(g2.titles || []);
      const first = !titles.has(bid);
      titles.add(bid);
      await this.db.doc(`guilds/${gid}`).set({ ...g2, titles: [...titles], ...(giant ? { giantDone: true } : {}) });
      if (first) {
        for (const m of Object.keys(g2.members || {})) {
          await this.db.collection(`inbox/u_${m}/msgs`).add({
            from: '리안',
            title: '길드가 레이드 보스를 처음 쓰러뜨렸어요',
            body: '함께 해낸 걸음이에요. 길드 화면에서 보상을 받아요.',
            reward: {},
            equips: [],
            op: { title: bid },
            at: this.now(),
          });
        }
      }
    }
    return this.state(uid, me);
  }

  // ───────────── 보상 받기

  async claim(uid, { kind, tier, me = {} } = {}) {
    await this._block(uid);
    const { gid } = await this._mine(uid);
    const view = await this.state(uid, me);
    const wk = view.week;
    let key;
    let reward;
    let ref = this.db.doc(`guilds/${gid}/weeks/${wk}`);
    if (kind === 'walk') {
      const i = Number(tier);
      if (!(i >= 0 && i < 3)) fail('bad_tier');
      if (!view.walk.done[i]) fail('not_yet');
      if (view.walk.claimed.includes(i)) fail('claimed');
      key = `walk${i}`;
      reward = { seal: G.WEEK_SEALS[i] };
    } else if (kind === 'raid' || kind === 'giant') {
      const r = kind === 'giant' ? view.giant : view.raid;
      if (!r || !r.defeated) fail('not_yet');
      if (r.claimed) fail('claimed');
      if (r.myDamage <= 0) fail('no_damage');
      key = 'raid';
      if (kind === 'giant') ref = this.db.doc(`guilds/${gid}/raids/giant`);
      reward = {
        seal: G.RAID_WIN.seal + (view.guild.level >= 7 ? G.RAID_WIN_LV7 : 0),
        raidMat: G.RAID_WIN.raidMat,
        raid: r.id,
        chest: R.chestOf(r.myShare),
      };
    } else if (kind === 'raidLast') {
      const prev = R.weekKey(Date.parse(wk + 'T00:00:00Z') - 3 * 86400000);
      ref = this.db.doc(`guilds/${gid}/weeks/${prev}`);
      const s = await ref.get();
      const w = s.exists ? s.data() : {};
      const b = w.boss;
      const mine = b ? (b.dmg || {})[uid] || 0 : 0;
      if (!b || b.defeatedAt || mine <= 0) fail('not_yet');
      key = 'raid';
      reward = { seal: Math.min(15, Math.floor((mine / Math.max(1, b.hp)) * 60)), raid: b.id };
    } else {
      fail('bad_kind');
    }
    await this.db.runTransaction(async (t) => {
      const s = await t.get(ref);
      const w = s.exists ? s.data() : {};
      w.claimed = w.claimed || {};
      const mine = w.claimed[uid] || [];
      if (mine.includes(key)) fail('claimed');
      w.claimed[uid] = [...mine, key];
      t.set(ref, w);
    });
    return { reward, state: await this.state(uid, me) };
  }
}

function memberOf(me, at) {
  return {
    name: safeName(me.name),
    level: Number(me.level) || 1,
    job: me.job ? String(me.job).slice(0, 20) : null,
    joinedAt: at,
    total: 0,
    days: {},
  };
}

module.exports = { GuildService, GuildError, G, levelOf, sizeOf, starOf, raidOf, raidHp, levelProgress };
