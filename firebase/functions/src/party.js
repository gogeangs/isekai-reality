// 파티 (#236): 만들기 · 들어가기(초대 코드) · 나가기 · 내보내기 · 꾸미기 · 함께 걷기 · 응원 · 파티 보스 · 함께 있어요
// 모든 파티 기록은 서버만 읽고 쓴다(규칙에서 막음). 파티원 위치는 어디에도 돌려주지 않는다.
const R = require('./rules');

class PartyError extends Error {
  constructor(code, status = 400) {
    super(code);
    this.code = code;
    this.status = status;
  }
}

const fail = (code, status) => {
  throw new PartyError(code, status);
};

/** 묶음 57: 다른 파티원에게 보이는 각성자 이름 (금칙어면 「각성자」) */
function safeName(n) {
  const s = String(n || '').trim().slice(0, 12);
  return !s || R.bannedName(s) ? '각성자' : s;
}

/** 묶음 75 #335: 프로필 사진 그림 이름 (앱 안 그림만, 모양이 다르면 빈 값) */
function safeFace(f) {
  return typeof f === 'string' && /^[A-Za-z0-9_]{1,48}$/.test(f) ? f : '';
}

function memberList(p) {
  return Object.entries(p.members || {})
    .map(([uid, m]) => ({ uid, ...m }))
    .sort((a, b) => (a.joinedAt || 0) - (b.joinedAt || 0));
}

/** 보스 체력: 지금 파티 인원 · 평균 레벨에 맞춤 */
function hpOf(p, b) {
  const ms = Object.values(p.members || {});
  const avg = ms.reduce((s, x) => s + (Number(x.level) || 1), 0) / Math.max(1, ms.length);
  return R.bossHp(ms.length, Math.round(avg), b.encounter);
}

function weekSteps(week, uid) {
  const days = (week.days || {})[uid] || {};
  const base = Object.values(days).reduce((t, n) => t + (Number(n) || 0), 0);
  const bonus = Math.floor(Number(((week.cheer || {})[uid] || {}).bonus || 0));
  return base + bonus;
}

class PartyService {
  constructor(db, { now = () => Date.now(), rand = Math.random } = {}) {
    this.db = db;
    this.now = now;
    this.rand = rand;
  }

  async _status(uid) {
    const s = await this.db.doc(`status/${uid}`).get();
    return s.exists ? s.data() : null;
  }

  async _restricted(uid) {
    return R.restricted(await this._status(uid), this.now());
  }

  async _devices(uid) {
    const u = await this.db.doc(`users/${uid}`).get();
    const d = u.exists ? u.data() : {};
    return new Set([...(d.devices || []), ...(d.device ? [d.device] : [])]);
  }

  async _partyId(uid) {
    const s = await this.db.doc(`partyOf/${uid}`).get();
    return s.exists ? s.data().pid : null;
  }

  async _party(pid) {
    const s = await this.db.doc(`parties/${pid}`).get();
    return s.exists ? s.data() : null;
  }

  async _week(pid, wk) {
    const s = await this.db.doc(`parties/${pid}/weeks/${wk}`).get();
    return s.exists ? s.data() : {};
  }

  /** 제재 중인 파티원 (기여를 셈에서 뺌) */
  async _restrictedSet(p) {
    const out = new Set();
    for (const uid of Object.keys(p.members || {})) {
      if (await this._restricted(uid)) out.add(uid);
    }
    return out;
  }

  async _blockIfRestricted(uid) {
    if (await this._restricted(uid)) fail('restricted', 403);
  }

  // ───────────── 만들기 · 들어가기 · 나가기

  async create(uid, { name, me = {} } = {}) {
    await this._blockIfRestricted(uid);
    if (await this._partyId(uid)) fail('already_in_party');
    if (name && R.bannedName(name)) fail('banned_word');
    const nm = R.cleanName(name || `${me.name || '각성자'}의 파티`) || '새 파티';
    let code;
    for (let i = 0; i < 10; i++) {
      const c = R.makeCode(this.rand);
      if (!(await this.db.doc(`codes/${c}`).get()).exists) {
        code = c;
        break;
      }
    }
    if (!code) fail('busy', 503);
    const pid = `p_${code}_${this.now()}`;
    const at = this.now();
    await this.db.runTransaction(async (t) => {
      t.set(this.db.doc(`parties/${pid}`), {
        name: nm,
        emblem: 0,
        color: 0,
        owner: uid,
        code,
        createdAt: at,
        members: { [uid]: { name: safeName(me.name), level: Number(me.level) || 1, face: safeFace(me.face), joinedAt: at } },
      });
      t.set(this.db.doc(`codes/${code}`), { pid });
      t.set(this.db.doc(`partyOf/${uid}`), { pid });
    });
    return this.state(uid, me);
  }

  async join(uid, { code, me = {} } = {}) {
    await this._blockIfRestricted(uid);
    if (await this._partyId(uid)) fail('already_in_party');
    const c = String(code || '').trim().toUpperCase();
    const ref = await this.db.doc(`codes/${c}`).get();
    if (!ref.exists) fail('no_party', 404);
    const pid = ref.data().pid;
    const p = await this._party(pid);
    if (!p) fail('no_party', 404);
    if (Object.keys(p.members || {}).length >= R.MAX_MEMBERS) fail('full');
    // 운영정책: 같은 휴대폰에서 로그인한 계정끼리는 같은 파티에 못 들어감
    const mine = await this._devices(uid);
    for (const other of Object.keys(p.members || {})) {
      const theirs = await this._devices(other);
      for (const d of mine) if (theirs.has(d)) fail('same_device');
    }
    await this.db.runTransaction(async (t) => {
      const snap = await t.get(this.db.doc(`parties/${pid}`));
      const cur = snap.data();
      if (Object.keys(cur.members || {}).length >= R.MAX_MEMBERS) fail('full');
      cur.members = {
        ...cur.members,
        [uid]: { name: safeName(me.name), level: Number(me.level) || 1, face: safeFace(me.face), joinedAt: this.now() },
      };
      t.set(this.db.doc(`parties/${pid}`), cur);
      t.set(this.db.doc(`partyOf/${uid}`), { pid });
    });
    return this.state(uid, me);
  }

  async _remove(pid, uid) {
    await this.db.runTransaction(async (t) => {
      const snap = await t.get(this.db.doc(`parties/${pid}`));
      if (!snap.exists) return;
      const p = snap.data();
      const members = { ...(p.members || {}) };
      delete members[uid];
      t.delete(this.db.doc(`partyOf/${uid}`));
      if (Object.keys(members).length === 0) {
        t.delete(this.db.doc(`parties/${pid}`));
        t.delete(this.db.doc(`codes/${p.code}`));
        return;
      }
      let owner = p.owner;
      if (owner === uid) {
        owner = Object.entries(members).sort((a, b) => (a[1].joinedAt || 0) - (b[1].joinedAt || 0))[0][0];
      }
      t.set(this.db.doc(`parties/${pid}`), { ...p, members, owner });
    });
  }

  async leave(uid) {
    const pid = await this._partyId(uid);
    if (!pid) return { party: null };
    await this._remove(pid, uid);
    return { party: null };
  }

  async kick(uid, { target, me = {} } = {}) {
    const pid = await this._partyId(uid);
    const p = pid && (await this._party(pid));
    if (!p) fail('no_party', 404);
    if (p.owner !== uid) fail('not_owner', 403);
    if (!target || target === uid || !(p.members || {})[target]) fail('bad_target');
    await this._remove(pid, target);
    return this.state(uid, me);
  }

  async style(uid, { name, emblem, color, me = {} } = {}) {
    const pid = await this._partyId(uid);
    const p = pid && (await this._party(pid));
    if (!p) fail('no_party', 404);
    if (p.owner !== uid) fail('not_owner', 403);
    const next = { ...p };
    if (name !== undefined) {
      if (R.bannedName(name)) fail('banned_word');
      const n = R.cleanName(name);
      if (!n) fail('bad_name');
      next.name = n;
    }
    if (emblem !== undefined) {
      const e = Number(emblem);
      if (!(e >= 0 && e < R.EMBLEMS.length)) fail('bad_style');
      next.emblem = e;
    }
    if (color !== undefined) {
      const c = Number(color);
      if (!(c >= 0 && c < R.COLORS)) fail('bad_style');
      next.color = c;
    }
    await this.db.doc(`parties/${pid}`).set(next);
    return this.state(uid, me);
  }

  // ───────────── 보기 + 오늘 걸음 올리기

  /**
   * 내 파티 화면. [me] = {name, level, steps(오늘 걸음), device}
   * 오늘 걸음은 운영정책대로 그 휴대폰에서 그날 처음 걸음을 올린 계정에만 셈
   */
  async state(uid, me = {}) {
    const restricted = await this._restricted(uid);
    const pid = await this._partyId(uid);
    const p = pid && (await this._party(pid));
    if (!p) return { party: null, restricted };
    const now = this.now();
    const day = R.dayKey(now);
    const wk = R.weekKey(now);
    const wref = this.db.doc(`parties/${pid}/weeks/${wk}`);
    let stepsCounted = true;
    if (!restricted) {
      // 이 휴대폰의 오늘 걸음은 처음 받은 계정에만
      if (me.device) {
        const dref = this.db.doc(`dayclaims/${me.device}_${day}`);
        const ds = await dref.get();
        if (!ds.exists) await dref.set({ uid, expireAt: new Date(now + 3 * 86400000) });
        else if (ds.data().uid !== uid) stepsCounted = false;
      }
      await this.db.runTransaction(async (t) => {
        const snap = await t.get(wref);
        const w = snap.exists ? snap.data() : {};
        const steps = Math.max(0, Math.floor(Number(me.steps) || 0));
        w.days = w.days || {};
        w.days[uid] = w.days[uid] || {};
        const before = Number(w.days[uid][day] || 0);
        if (stepsCounted && steps > before) {
          w.days[uid][day] = steps;
          // 응원 받은 뒤 다음 1,000보는 1.2배
          const ch = (w.cheer || {})[uid];
          if (ch && ch.left > 0 && ch.day === day) {
            const base = Math.max(before, Number(ch.base || 0));
            const add = Math.min(ch.left, Math.max(0, steps - base));
            ch.bonus = Number(ch.bonus || 0) + add * R.CHEER_RATE;
            ch.left -= add;
            ch.base = steps;
          }
        }
        // 이름 · 레벨 새로
        const m = (p.members || {})[uid];
        if (m && (me.name || me.level || (me.face !== undefined && safeFace(me.face) !== (m.face || '')))) {
          p.members[uid] = {
            ...m,
            name: me.name ? safeName(me.name) : m.name,
            level: Number(me.level) || m.level,
            ...(me.face !== undefined ? { face: safeFace(me.face) } : {}),
          };
          t.set(this.db.doc(`parties/${pid}`), p);
        }
        // 보스: 이번 주 처음이면 인원 · 평균 레벨로 체력을 정함
        if (!w.boss) w.boss = { ...R.bossOf(wk), dmg: {}, used: {} };
        t.set(wref, w);
      });
    }
    const w = await this._week(pid, wk);
    return { ...(await this._view(uid, pid, p, w, wk, day)), restricted, stepsCounted };
  }

  async _view(uid, pid, p, w, wk, day) {
    const out = await this._restrictedSet(p);
    const members = memberList(p).map((m) => ({
      uid: m.uid,
      name: m.name,
      level: m.level,
      face: m.face || '',
      steps: out.has(m.uid) ? 0 : weekSteps(w, m.uid),
      me: m.uid === uid,
      owner: m.uid === p.owner,
      cheeredToday: ((w.cheeredBy || {})[uid] || {})[m.uid] === day,
    }));
    const total = members.reduce((s, m) => s + m.steps, 0);
    const goals = R.walkGoals(members.length);
    const claimed = ((w.claimed || {})[uid]) || [];
    const boss = w.boss || null;
    let bossView = null;
    if (boss) {
      const dmg = Object.entries(boss.dmg || {})
        .filter(([u]) => !out.has(u))
        .reduce((s, [, n]) => s + n, 0);
      const myDays = ((w.days || {})[uid]) || {};
      const used = (((boss.used || {})[uid]) || {})[day] || 0;
      const hp = boss.defeatedHp || hpOf(p, boss);
      bossView = {
        id: boss.id,
        encounter: boss.encounter,
        hp,
        damage: dmg,
        myDamage: (boss.dmg || {})[uid] || 0,
        defeated: !!boss.defeatedAt || dmg >= hp,
        tickets: Math.max(0, R.ticketsEarned(myDays[day] || 0) - used),
        usedToday: used,
        claimed: claimed.includes('boss'),
      };
    }
    // 지난주 보스를 못 쓰러뜨렸으면 준 피해만큼 (한 번)
    const last = await this._lastWeekBoss(pid, uid, wk);
    const cheers = (((w.cheerLog || {})[uid]) || []).filter((c) => !c.seen);
    if (cheers.length) {
      const ref = this.db.doc(`parties/${pid}/weeks/${wk}`);
      await this.db.runTransaction(async (t) => {
        const s = await t.get(ref);
        const x = s.data();
        x.cheerLog[uid] = (x.cheerLog[uid] || []).map((c) => ({ ...c, seen: true }));
        t.set(ref, x);
      });
    }
    return {
      party: {
        id: pid,
        name: p.name,
        emblem: p.emblem || 0,
        color: p.color || 0,
        code: p.code,
        owner: p.owner === uid,
      },
      week: wk,
      day,
      members,
      walk: { total, goals, claimed: claimed.filter((c) => c.startsWith('walk')).map((c) => Number(c.slice(4))) },
      boss: bossView,
      lastBoss: last,
      cheers: cheers.map((c) => c.from),
      canCheer: !(w.cheeredBy || {})[uid] || !Object.values((w.cheeredBy || {})[uid]).includes(day),
    };
  }

  async _lastWeekBoss(pid, uid, wk) {
    const prev = R.weekKey(Date.parse(wk + 'T00:00:00Z') - 9 * 3600000 - 86400000 + 12 * 3600000);
    if (prev === wk) return null;
    const w = await this._week(pid, prev);
    const b = w.boss;
    if (!b) return null;
    const mine = (b.dmg || {})[uid] || 0;
    const claimed = (((w.claimed || {})[uid]) || []).includes('boss');
    if (claimed || mine <= 0 || b.defeatedAt) return null;
    const p = await this._party(pid);
    return { week: prev, id: b.id, footTicket: R.bossLoseTickets(mine, hpOf(p, b)) };
  }

  // ───────────── 응원 (하루 한 사람에게 한 번)

  async cheer(uid, { target, me = {} } = {}) {
    await this._blockIfRestricted(uid);
    const pid = await this._partyId(uid);
    const p = pid && (await this._party(pid));
    if (!p) fail('no_party', 404);
    if (!target || target === uid || !(p.members || {})[target]) fail('bad_target');
    const now = this.now();
    const day = R.dayKey(now);
    const wk = R.weekKey(now);
    const ref = this.db.doc(`parties/${pid}/weeks/${wk}`);
    await this.db.runTransaction(async (t) => {
      const s = await t.get(ref);
      const w = s.exists ? s.data() : {};
      w.cheeredBy = w.cheeredBy || {};
      const mine = w.cheeredBy[uid] || {};
      if (Object.values(mine).includes(day)) fail('cheered_today');
      w.cheeredBy[uid] = { ...mine, [target]: day };
      w.cheer = w.cheer || {};
      const today = ((((w.days || {})[target]) || {})[day]) || 0;
      const cur = w.cheer[target] || {};
      w.cheer[target] = {
        ...cur,
        day,
        base: today,
        left: R.CHEER_STEPS,
        bonus: Number(cur.bonus || 0),
      };
      w.cheerLog = w.cheerLog || {};
      w.cheerLog[target] = [...(w.cheerLog[target] || []), { from: p.members[uid].name, at: now }].slice(-10);
      t.set(ref, w);
    });
    return this.state(uid, me);
  }

  // ───────────── 파티 보스 (도전권: 3,000보마다 1장, 하루 3장)

  async bossHit(uid, { damage, me = {} } = {}) {
    await this._blockIfRestricted(uid);
    const pid = await this._partyId(uid);
    const p = pid && (await this._party(pid));
    if (!p) fail('no_party', 404);
    await this.state(uid, me);
    const now = this.now();
    const day = R.dayKey(now);
    const wk = R.weekKey(now);
    const ref = this.db.doc(`parties/${pid}/weeks/${wk}`);
    const level = Number(((p.members || {})[uid] || {}).level) || 1;
    await this.db.runTransaction(async (t) => {
      const s = await t.get(ref);
      const w = s.data();
      const b = w.boss;
      const steps = ((((w.days || {})[uid]) || {})[day]) || 0;
      b.used = b.used || {};
      const used = ((b.used[uid] || {})[day]) || 0;
      if (R.ticketsEarned(steps) - used <= 0) fail('no_ticket');
      const total = Object.values(b.dmg || {}).reduce((x, n) => x + n, 0);
      const hp = hpOf(p, b);
      if (b.defeatedAt || total >= hp) fail('defeated');
      const d = Math.max(0, Math.min(R.hitCap(level), Math.floor(Number(damage) || 0)));
      b.dmg = { ...(b.dmg || {}), [uid]: ((b.dmg || {})[uid] || 0) + d };
      b.used[uid] = { ...(b.used[uid] || {}), [day]: used + 1 };
      if (total + d >= hp && !b.defeatedAt) {
        b.defeatedAt = now;
        b.defeatedHp = hp;
      }
      t.set(ref, w);
    });
    return this.state(uid, me);
  }

  // ───────────── 보상 받기 (한 사람이 한 번씩)

  async claim(uid, { kind, tier, me = {} } = {}) {
    await this._blockIfRestricted(uid);
    const pid = await this._partyId(uid);
    const p = pid && (await this._party(pid));
    if (!p) fail('no_party', 404);
    const view = await this.state(uid, me);
    let key;
    let reward;
    let wk = view.week;
    if (kind === 'walk') {
      const i = Number(tier);
      if (!(i >= 0 && i < 3)) fail('bad_tier');
      if (view.walk.total < view.walk.goals[i]) fail('not_yet');
      if (view.walk.claimed.includes(i)) fail('claimed');
      key = `walk${i}`;
      reward = R.WALK_REWARDS[i];
    } else if (kind === 'boss') {
      const b = view.boss;
      if (!b || !b.defeated) fail('not_yet');
      if (b.claimed) fail('claimed');
      if (b.myDamage <= 0) fail('no_damage');
      key = 'boss';
      reward = { ...R.BOSS_WIN, boss: b.id, chest: R.chestOf(b.myDamage / Math.max(1, b.damage)) };
    } else if (kind === 'bossLast') {
      const l = view.lastBoss;
      if (!l) fail('not_yet');
      key = 'boss';
      wk = l.week;
      reward = { footTicket: l.footTicket, boss: l.id };
    } else {
      fail('bad_kind');
    }
    const ref = this.db.doc(`parties/${pid}/weeks/${wk}`);
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

  // ───────────── 함께 있어요 (100m 칸만 비교, 위치는 돌려주지 않음)

  async near(uid, { r, c, mock } = {}, suspect = null) {
    // 묶음 61 #250: 가짜 위치가 잡힌 동안은 칸을 받지 않음 (의심 목록에만 남김)
    if (mock) {
      if (suspect) await suspect.hit(uid, 'mock', {});
      await this.db.doc(`presence/${uid}`).delete();
      return { near: false, mock: true };
    }
    const pid = await this._partyId(uid);
    const p = pid && (await this._party(pid));
    if (!p || (await this._restricted(uid))) return { near: false };
    const now = this.now();
    const cell = { r: Math.floor(Number(r)), c: Math.floor(Number(c)) };
    if (!Number.isFinite(cell.r) || !Number.isFinite(cell.c)) fail('bad_cell');
    // 마지막 칸 하나만 덮어쓰고, 10분 뒤엔 TTL 로 지워짐 (기록으로 남기지 않음)
    await this.db.doc(`presence/${uid}`).set({ ...cell, at: now, expireAt: new Date(now + R.NEAR_MS) });
    for (const other of Object.keys(p.members || {})) {
      if (other === uid) continue;
      const s = await this.db.doc(`presence/${other}`).get();
      if (!s.exists) continue;
      const o = s.data();
      if (now - o.at <= R.NEAR_MS && R.near(cell, o) && !(await this._restricted(other))) {
        return { near: true };
      }
    }
    return { near: false };
  }
}

module.exports = { PartyService, PartyError, weekSteps };
