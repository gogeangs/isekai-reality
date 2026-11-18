// 운영자 (묶음 59): 제재 · 이름 바꾸기 · 잘못된 거래 되돌리기 · 공지 · 모두에게 보상 우편 · 운영자 행동 기록.
// 모두 운영자만(router 에서 확인). 그 사람에게는 우편(inbox)으로 알림. 기록은 운영자만 봄.
const R = require('./rules');

const DAY = 86400000;
const SANCTION = {
  1: { label: '경고', days: 0 },
  2: { label: '함께하는 기능 7일 제한', days: 7 },
  3: { label: '로그인 정지 30일', days: 30 },
  4: { label: '영구 정지', days: null },
};
const REASONS = {
  steps: '걸음 조작',
  location: '위치 조작',
  tamper: '앱 · 기록 변조',
  bug: '오류 악용',
  cash: '현금 거래',
  boost: '몰아주기',
  scam: '거래 사기',
  name: '부적절한 이름',
  text: '부적절한 글',
  impersonate: '운영자 사칭',
};
const RENAME = {
  awakened: { label: '각성자 이름', to: '각성자' },
  pet: { label: '펫 이름', to: null },
  ally: { label: '동료 이름', to: null },
  party: { label: '파티 이름', to: '새 파티' },
  guild: { label: '길드 이름', to: '새 길드' },
};

class AdminError extends Error {
  constructor(code, status = 400) {
    super(code);
    this.code = code;
    this.status = status;
  }
}
const fail = (code, status) => {
  throw new AdminError(code, status);
};
const okUid = (u) => typeof u === 'string' && /^[A-Za-z0-9]{6,128}$/.test(u);
const okId = (u) => typeof u === 'string' && /^[A-Za-z0-9_-]{1,80}$/.test(u);
const text = (s, max) => String(s || '').trim().slice(0, max);

const YEAR = 365 * 24 * 3600 * 1000;

/** 제재 기록 보관: 끝난 날부터 1년 · 영구 정지는 정지한 날부터 3년 (Firestore TTL expireAt) */
function keepUntil(rec, now) {
  if (rec.level >= 4) return new Date((rec.at || now) + 3 * YEAR);
  const end = rec.until ? Date.parse(rec.until) : rec.at || now;
  return new Date(Math.max(end, now) + YEAR);
}

class AdminService {
  constructor(db, { now = () => Date.now() } = {}) {
    this.db = db;
    this.now = now;
  }

  async log(by, action, target, detail = {}) {
    await this.db.collection('adminLog').add({ by: by || '', action, target: target || '', detail, at: this.now(), expireAt: new Date(this.now() + YEAR) });
  }

  async logs({ limit = 200 } = {}) {
    const s = await this.db.collection('adminLog').orderBy('at', 'desc').limit(Math.min(500, limit)).get();
    return { items: s.docs.map((d) => ({ id: d.id, ...d.data() })) };
  }

  async _mail(uid, msg) {
    await this.db.collection(`inbox/u_${uid}/msgs`).add({ from: '여명의 탑 운영실', at: this.now(), equips: [], reward: {}, ...msg });
  }

  // ───────────── 제재

  async sanctions({ uid } = {}) {
    if (!okUid(uid)) fail('bad_uid');
    const st = await this.db.doc(`status/${uid}`).get();
    const h = await this.db.collection(`sanctionLog/${uid}/items`).get();
    return {
      status: st.exists ? st.data() : null,
      active: R.restricted(st.exists ? st.data() : null, this.now()),
      history: h.docs.map((d) => ({ id: d.id, ...d.data() })).sort((a, b) => b.at - a.at),
      levels: SANCTION,
      reasons: REASONS,
    };
  }

  async sanction(by, { uid, level, reason, memo, days } = {}) {
    if (!okUid(uid)) fail('bad_uid');
    const lv = Number(level);
    if (!SANCTION[lv]) fail('bad_level');
    if (!REASONS[reason]) fail('bad_reason');
    const d = days != null && lv >= 2 && lv <= 3 ? Math.max(1, Math.min(365, Number(days) || SANCTION[lv].days)) : SANCTION[lv].days;
    const until = d ? new Date(this.now() + d * DAY).toISOString() : null;
    const rec = { level: lv, until, reason, memo: text(memo, 500), at: this.now(), by };
    rec.expireAt = keepUntil(rec, this.now());
    await this.db.doc(`status/${uid}`).set(rec);
    await this.db.collection(`sanctionLog/${uid}/items`).add({ ...rec, action: 'sanction' });
    const period = lv === 1 ? '' : until ? ` · ${until.slice(0, 10)}까지` : ' · 기간 없음';
    await this._mail(uid, {
      title: `운영정책에 따른 조치: ${SANCTION[lv].label}`,
      body:
        `사유: ${REASONS[reason]}${period}\n` +
        '운영정책을 지키지 않은 기록이 확인되어 조치했어요. ' +
        '잘못된 조치라고 생각되면 14일 안에 설정 → 문의에서 「제재 이의 제기」로 알려 주세요.',
      kind: 'sanction',
    });
    await this.log(by, 'sanction', uid, { level: lv, reason, until });
    return { ok: true, status: rec };
  }

  /** 풀기 · 기간 바꾸기 */
  async unsanction(by, { uid, until, memo } = {}) {
    if (!okUid(uid)) fail('bad_uid');
    const st = await this.db.doc(`status/${uid}`).get();
    if (!st.exists) fail('no_status', 404);
    const cur = st.data();
    if (until) {
      const t = Date.parse(until);
      if (!t) fail('bad_until');
      const rec = { ...cur, until: new Date(t).toISOString(), memo: text(memo, 500) || cur.memo };
      rec.expireAt = keepUntil(rec, this.now());
      await this.db.doc(`status/${uid}`).set(rec);
      await this.db.collection(`sanctionLog/${uid}/items`).add({ ...rec, action: 'period', at: this.now(), by });
      await this._mail(uid, { title: '조치 기간이 바뀌었어요', body: `${rec.until.slice(0, 10)}까지로 바뀌었어요.`, kind: 'sanction' });
      await this.log(by, 'period', uid, { until: rec.until });
      return { ok: true, status: rec };
    }
    const rec = { level: 0, until: null, reason: cur.reason, memo: text(memo, 500), at: this.now(), by };
    rec.expireAt = new Date(this.now() + YEAR);
    await this.db.doc(`status/${uid}`).set(rec);
    await this.db.collection(`sanctionLog/${uid}/items`).add({ ...rec, action: 'release' });
    await this._mail(uid, { title: '조치가 풀렸어요', body: '이제 모든 기능을 다시 쓸 수 있어요.', kind: 'sanction' });
    await this.log(by, 'release', uid, {});
    return { ok: true, status: rec };
  }

  /** 앱이 묻는 내 상태 (로그인 정지면 앱이 로그인 기능을 막음) */
  async myStatus(uid) {
    const st = await this.db.doc(`status/${uid}`).get();
    const s = st.exists ? st.data() : null;
    const active = R.restricted(s, this.now());
    return {
      level: active ? Number(s.level) : s && Number(s.level) === 1 ? 1 : 0,
      until: active ? s.until : null,
      reason: s && REASONS[s.reason] ? REASONS[s.reason] : null,
    };
  }

  // ───────────── 이름 바꾸기

  async rename(by, { uid, target, id } = {}) {
    if (!RENAME[target]) fail('bad_target');
    if (target === 'party' || target === 'guild') {
      if (!okId(id)) fail('bad_id');
      const col = target === 'party' ? 'parties' : 'guilds';
      const ref = this.db.doc(`${col}/${id}`);
      const s = await ref.get();
      if (!s.exists) fail('not_found', 404);
      const g = s.data();
      await ref.set({ ...g, name: RENAME[target].to });
      for (const m of Object.keys(g.members || {})) {
        await this._mail(m, {
          title: `${RENAME[target].label}이 바뀌었어요`,
          body: `운영정책에 맞지 않는 이름이라 「${RENAME[target].to}」으로 바꿨어요. 길드장 · 파티장은 꾸미기에서 다시 정할 수 있어요.`,
        });
      }
      await this.log(by, 'rename', id, { target, old: g.name });
      return { ok: true };
    }
    if (!okUid(uid)) fail('bad_uid');
    await this._mail(uid, {
      title: `${RENAME[target].label}이 바뀌었어요`,
      body: '운영정책에 맞지 않는 이름이라 기본 이름으로 바꿨어요. 다시 지을 수 있어요.',
      op: { rename: { target, id: id ? String(id).slice(0, 40) : null } },
    });
    await this.log(by, 'rename', uid, { target, id: id || null });
    return { ok: true };
  }

  // ───────────── 잘못된 거래 되돌리기

  /** 거래 기록 하나를 되돌림: 산 사람은 금화를 돌려받고 물건을 내놓음, 판 사람은 물건을 돌려받고 금화를 내놓음.
   * 이미 쓴 것은 남은 만큼만 가져가고 나머지는 없던 일로(기록에 남김) — 앱이 우편을 받을 때 처리 */
  async revert(by, { logId, memo } = {}) {
    if (!okId(logId)) fail('bad_id');
    const ref = this.db.doc(`marketLog/${logId}`);
    const s = await ref.get();
    if (!s.exists) fail('not_found', 404);
    const t = s.data();
    if (t.reverted) fail('already_reverted', 409);
    const l = t.listing ? (await this.db.doc(`market/${t.listing}`).get()).data() || {} : {};
    const goods = goodsOf(t, l);
    const net = t.price - (t.fee || 0);
    // 묶음 61: 거래는 거래 지갑으로 했으니 금화도 지갑으로 돌려주고 거둠 (지갑에 모자라면 남은 만큼 휴대폰 금화에서)
    const purse = (uid) => this.db.doc(`tradeWallet/${uid}`);
    const purseAdd = async (uid, n) => {
      let took = 0;
      await this.db.runTransaction(async (tx) => {
        const s0 = await tx.get(purse(uid));
        const g = s0.exists ? Number(s0.data().gold || 0) : 0;
        const next = Math.max(0, g + n);
        took = n < 0 ? g - next : 0;
        tx.set(purse(uid), { gold: next, at: this.now() });
      });
      return took;
    };
    if (t.buyer && t.buyer !== 'deleted') {
      await purseAdd(t.buyer, t.price);
      await this._mail(t.buyer, {
        from: '바르칸',
        title: `「${t.name}」 거래가 되돌려졌어요`,
        body: `운영 확인 뒤 거래를 되돌렸네. 낸 금화 ${t.price}은 거래 지갑에 돌려주고, 받은 물건은 장부에서 거두네.`,
        reward: {},
        op: { take: goods.take },
      });
    }
    const fromPurse = t.seller === 'deleted' ? 0 : await purseAdd(t.seller, -net);
    await this._mail(t.seller, {
      from: '바르칸',
      title: `「${t.name}」 거래가 되돌려졌어요`,
      body: `운영 확인 뒤 거래를 되돌렸네. 물건은 돌려주고, 받은 금화 ${net}은 거래 지갑에서 거두네.`,
      reward: goods.reward,
      equips: goods.equips,
      ...(net - fromPurse > 0 ? { op: { take: { gold: net - fromPurse } } } : {}),
    });
    await ref.set({ ...t, reverted: { at: this.now(), by, memo: text(memo, 300) } });
    await this.log(by, 'revert', logId, { seller: t.seller, buyer: t.buyer, price: t.price, name: t.name });
    return { ok: true };
  }

  // ───────────── 공지 · 모두에게 보상

  async notices({ all = false } = {}) {
    const s = await this.db.collection('notices').get();
    const now = this.now();
    const items = s.docs
      .map((d) => ({ id: d.id, ...d.data() }))
      .filter((n) => all || (n.from <= now && n.to > now))
      .sort((a, b) => b.from - a.from);
    return { items };
  }

  async notice(by, { title, body, from, to } = {}) {
    const t = text(title, 60);
    const b = text(body, 2000);
    if (!t || !b) fail('bad_text');
    const f = Number(from) || this.now();
    const e = Number(to) || f + 7 * DAY;
    if (e <= f) fail('bad_period');
    const r = await this.db.collection('notices').add({ title: t, body: b, from: f, to: e, at: this.now(), by });
    await this.log(by, 'notice', r.id, { title: t });
    return { ok: true, id: r.id };
  }

  async noticeDelete(by, { id } = {}) {
    if (!okId(id)) fail('bad_id');
    await this.db.doc(`notices/${id}`).delete();
    await this.log(by, 'noticeDelete', id, {});
    return { ok: true };
  }

  /** 모두에게 보상 우편 (점검 · 장애 보상): 기간 안에 앱을 연 사람이 한 번 받음 */
  async broadcast(by, { title, body, reward = {}, days = 7 } = {}) {
    const t = text(title, 60);
    if (!t) fail('bad_text');
    const clean = {};
    for (const k of ['gold', 'manaStone', 'footTicket', 'recruit']) {
      const v = Math.floor(Number(reward[k]) || 0);
      if (v > 0) clean[k] = Math.min(v, k === 'gold' ? 100000 : 1000);
    }
    const at = this.now();
    const r = await this.db.collection('broadcasts').add({
      title: t,
      body: text(body, 1000),
      reward: clean,
      from: at,
      to: at + Math.max(1, Math.min(30, Number(days) || 7)) * DAY,
      at,
      by,
    });
    await this.log(by, 'broadcast', r.id, { title: t, reward: clean });
    return { ok: true, id: r.id };
  }

  /** 앱이 우편을 받을 때 함께: 지금 받을 수 있는 모두에게 보상 */
  async activeBroadcasts() {
    const s = await this.db.collection('broadcasts').get();
    const now = this.now();
    return s.docs
      .map((d) => ({ id: d.id, ...d.data() }))
      .filter((b) => b.from <= now && b.to > now)
      .map((b) => ({ id: 'bc_' + b.id, from: '여명의 탑 운영실', title: b.title, body: b.body, reward: b.reward, equips: [], at: b.at }));
  }
}

/** 되돌릴 물건 (판 사람에게 돌려줄 것 · 산 사람에게서 거둘 것) */
function goodsOf(t, l) {
  const reward = {};
  const equips = [];
  const take = {};
  if (t.kind === 'mat') {
    reward[t.key] = t.qty;
    take.mats = { [t.key]: t.qty };
  } else if (t.kind === 'item') {
    reward['item:' + t.key] = t.qty;
    take.items = { [t.key]: t.qty };
  } else if (t.kind === 'alc') {
    reward['alc:' + t.key] = t.qty;
    take.alcs = { [t.key]: t.qty };
  } else if (t.kind === 'egg') {
    reward.egg = t.qty;
    take.eggs = t.qty;
  } else if (t.kind === 'equip') {
    if (l.equip) equips.push(l.equip);
    take.equip = l.equip ? { base: l.equip.base, grade: l.equip.grade, enhance: l.equip.enhance || 0 } : { base: t.key };
  }
  return { reward, equips, take };
}

module.exports = {
  keepUntil,
  AdminService,
  AdminError,
  SANCTION,
  REASONS,
  RENAME,
};
