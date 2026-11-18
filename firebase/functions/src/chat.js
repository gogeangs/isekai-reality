// 묶음 68 #275 대화 · 친구 (로그인한 사람만)
// 방: 길드(g_<길드>) · 연맹(a_<연맹>) · 친구 1:1(f_<uid>_<uid>) · 서버(server, Lv.10부터 쓰기)
// 쓰기는 모두 이 서버 함수로: 금칙어 · 개인정보 가림 · 도배 · 대화 금지 · Lv.10 · 진짜 앱 확인.
// 읽기도 이 함수로 (그 방 사람만) — 방마다 최근 100줄, 위로 올리면 더 불러오기.
// 기록: 대화 30일(expireAt) · 신고된 줄은 처리 뒤 90일 · 대화 금지 · 차단은 계정이 있는 동안 · 계정 지우기 때 함께 지움
const words = require('./words');

const DAY = 86400000;
const C = {
  maxLen: 100,
  page: 100,
  keepDays: 30,
  reportKeepDays: 90,
  serverLevel: 10,
  gapMs: 10000,
  repeatN: 3,
  repeatRestMs: 60000,
  maxFriends: 50,
  codeLen: 8,
  quietFrom: 22,
  quietTo: 8,
};
const REASONS = { abuse: '욕설', bully: '괴롭힘', sexual: '음란', ad: '광고', privacy: '개인정보 요구', etc: '기타' };
const CODE_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

class ChatError extends Error {
  constructor(code, status = 400) {
    super(code);
    this.code = code;
    this.status = status;
  }
}
const fail = (code, status) => {
  throw new ChatError(code, status);
};

/** 개인정보처럼 보이는 말 → ○○ (전화번호 · 이메일 · 링크 · 메신저 아이디) */
function maskPrivate(text) {
  let t = String(text || '');
  const rules = [
    /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/g, // 이메일
    /(https?:\/\/|www\.)\S+/gi, // 링크
    /\b[A-Za-z0-9-]+\.(com|net|org|kr|co|io|me|gg|ly|app|link|xyz)(\/\S*)?\b/gi, // 주소
    /(\+?82[-\s.]?)?0?1[016789][-\s.]?\d{3,4}[-\s.]?\d{4}/g, // 휴대폰
    /\d{2,4}[-\s.]\d{3,4}[-\s.]\d{4}/g, // 전화
    /\d{9,}/g, // 긴 숫자
    /(카톡|카카오톡|카카오|오픈채팅|오픈톡|kakao|kakaotalk|라인|line|텔레그램|telegram|디스코드|discord|인스타|instagram|insta)\s*(아이디|id|ID|Id)?\s*[:：]?\s*[A-Za-z0-9._-]{3,}/gi,
    /(아이디|id)\s*[:：]\s*[A-Za-z0-9._-]{3,}/gi,
  ];
  for (const r of rules) t = t.replace(r, '○○');
  return t;
}

/** 금칙어 → ○○ (이름 금칙어 목록 그대로, 낱말 단위로 가림) */
function maskBanned(text, list) {
  const lst = list || null;
  return String(text || '')
    .split(/(\s+)/)
    .map((w) => (w.trim() && words.banned(w, lst || undefined) ? '○○' : w))
    .join('');
}

const friendRoom = (a, b) => `f_${[a, b].sort().join('_')}`;

class ChatService {
  constructor(db, { now = () => Date.now(), guild = null } = {}) {
    this.db = db;
    this.now = now;
    this.guild = guild;
  }

  _uref(uid) {
    return this.db.doc(`chatUser/${uid}`);
  }
  async _user(uid) {
    const s = await this._uref(uid).get();
    return s.exists ? s.data() : { friends: [], blocked: [], reads: {}, showSteps: true, push: { dm: true, mention: true, staff: true } };
  }
  _msgs(room) {
    return this.db.collection(`chatRooms/${room}/msgs`);
  }

  async _guildOf(uid) {
    const gs = await this.db.doc(`guildOf/${uid}`).get();
    const gid = gs.exists ? gs.data().gid : null;
    if (!gid) return { gid: null, g: null };
    const g = (await this.db.doc(`guilds/${gid}`).get()).data() || null;
    return { gid: g ? gid : null, g };
  }

  /** 계정 상태(운영 제재)로 함께하는 기능이 막혔는지 */
  async _restricted(uid) {
    const R = require('./rules');
    const s = await this.db.doc(`status/${uid}`).get();
    return R.restricted(s.exists ? s.data() : null, this.now());
  }

  /** 그 방을 읽고 쓸 수 있는지 */
  async _canRoom(uid, room) {
    if (room === 'server') return true;
    if (room.startsWith('g_')) {
      const { gid } = await this._guildOf(uid);
      return !!gid && room === `g_${gid}`;
    }
    if (room.startsWith('a_')) {
      const { g } = await this._guildOf(uid);
      return !!(g && g.alliance) && room === `a_${g.alliance}`;
    }
    if (room.startsWith('f_')) {
      const ids = room.slice(2).split('_');
      if (ids.length !== 2 || !ids.includes(uid)) return false;
      const other = ids[0] === uid ? ids[1] : ids[0];
      const me = await this._user(uid);
      const them = await this._user(other);
      return (me.friends || []).includes(other) && !(them.blocked || []).includes(uid) && !(me.blocked || []).includes(other);
    }
    return false;
  }

  /** 앱이 함께 보낸 내 모습 (이름 · 레벨 · 대표 칭호 · 얼굴 · 오늘 걸음) */
  async _touch(uid, me = {}) {
    const R = require('./rules');
    const u = await this._user(uid);
    const now = this.now();
    const { g } = await this._guildOf(uid);
    const next = {
      ...u,
      name: me.name ? String(me.name).slice(0, 12) : u.name || '각성자',
      level: me.level != null ? Math.max(1, Math.floor(Number(me.level) || 1)) : u.level || 1,
      title: me.title != null ? String(me.title).slice(0, 20) : u.title || '',
      look: me.look != null ? String(me.look).slice(0, 12) : u.look || '',
      guild: g ? g.name || '' : '',
      lastSeen: now,
    };
    if (me.steps != null) {
      next.day = R.dayKey(now);
      next.steps = Math.max(0, Math.floor(Number(me.steps) || 0));
    }
    if (!next.friendCode) next.friendCode = await this._newCode(uid);
    await this._uref(uid).set(next);
    return next;
  }

  async _newCode(uid) {
    for (let i = 0; i < 20; i++) {
      let c = '';
      for (let k = 0; k < C.codeLen; k++) c += CODE_CHARS[Math.floor(Math.random() * CODE_CHARS.length)];
      const ref = this.db.doc(`friendCode/${c}`);
      if (!(await ref.get()).exists) {
        await ref.set({ uid });
        return c;
      }
    }
    fail('busy', 503);
  }

  _card(uid, u, viewer) {
    const R = require('./rules');
    const today = R.dayKey(this.now());
    return {
      uid,
      name: u.name || '각성자',
      level: u.level || 1,
      title: u.title || '',
      look: u.look || '',
      guild: u.guild || '',
      steps: u.showSteps !== false && u.day === today ? u.steps || 0 : null,
      lastSeen: u.lastSeen || 0,
      room: viewer ? friendRoom(viewer, uid) : null,
    };
  }

  // ───────────── 내 대화 · 친구 한눈에

  async me(uid, me = {}) {
    const u = await this._touch(uid, me);
    const friends = [];
    for (const f of u.friends || []) friends.push(this._card(f, await this._user(f), uid));
    const inbox = await this.db.collection('friendReq').where('to', '==', uid).get();
    const requests = [];
    for (const d of inbox.docs) {
      const r = d.data();
      if ((u.blocked || []).includes(r.from)) continue;
      requests.push({ ...this._card(r.from, await this._user(r.from)), at: r.at });
    }
    const blocked = [];
    for (const b of u.blocked || []) blocked.push({ uid: b, name: (await this._user(b)).name || '각성자' });
    const { gid, g } = await this._guildOf(uid);
    const rooms = [];
    const add = async (room, kind, name) => {
      const last = await this._msgs(room).orderBy('at', 'desc').limit(1).get();
      const l = last.docs[0] ? last.docs[0].data() : null;
      const read = (u.reads || {})[room] || 0;
      let unread = 0;
      if (l && l.at > read && kind !== 'server') {
        const q = await this._msgs(room).where('at', '>', read).get();
        unread = q.docs.filter((x) => x.data().uid !== uid && !(u.blocked || []).includes(x.data().uid)).length;
      }
      rooms.push({ room, kind, name, unread, last: l ? { text: l.text, name: l.name, at: l.at, kind: l.kind } : null });
    };
    if (gid) await add(`g_${gid}`, 'guild', g.name || '길드');
    if (g && g.alliance) {
      const a = (await this.db.doc(`alliances/${g.alliance}`).get()).data();
      if (a) await add(`a_${g.alliance}`, 'alliance', a.name || '연맹');
    }
    await add('server', 'server', '서버 대화방');
    for (const f of friends) await add(f.room, 'friend', f.name);
    return {
      uid,
      friendCode: u.friendCode,
      showSteps: u.showSteps !== false,
      push: u.push || { dm: true, mention: true, staff: true },
      rulesSeen: !!u.rulesSeen,
      mutedUntil: u.mutePerm ? -1 : u.mutedUntil && u.mutedUntil > this.now() ? u.mutedUntil : null,
      level: u.level || 1,
      friends,
      requests,
      blocked,
      rooms,
      maxFriends: C.maxFriends,
    };
  }

  async rules(uid) {
    const u = await this._user(uid);
    await this._uref(uid).set({ ...u, rulesSeen: true });
    return { ok: true };
  }

  async settings(uid, { showSteps, push } = {}) {
    const u = await this._user(uid);
    const next = { ...u };
    if (typeof showSteps === 'boolean') next.showSteps = showSteps;
    if (push && typeof push === 'object') {
      next.push = { ...(u.push || {}) };
      for (const k of ['dm', 'mention', 'staff']) if (typeof push[k] === 'boolean') next.push[k] = push[k];
    }
    await this._uref(uid).set(next);
    return { ok: true, showSteps: next.showSteps !== false, push: next.push || {} };
  }

  // ───────────── 읽기 · 쓰기

  _view(id, m) {
    return { id, uid: m.uid || null, name: m.name || '', title: m.title || '', level: m.level || 0, text: m.text, kind: m.kind || 'user', at: m.at };
  }

  async read(uid, { room, after, before } = {}) {
    room = String(room || '');
    if (!(await this._canRoom(uid, room))) fail('no_room', 403);
    const u = await this._user(uid);
    let q = this._msgs(room);
    if (after) q = q.where('at', '>', Number(after));
    else if (before) q = q.where('at', '<', Number(before));
    const s = await q.orderBy('at', 'desc').limit(C.page).get();
    const rows = s.docs
      .map((d) => this._view(d.id, d.data()))
      .filter((m) => !(u.blocked || []).includes(m.uid))
      .reverse();
    if (!before) await this._uref(uid).set({ ...u, reads: { ...(u.reads || {}), [room]: this.now() } });
    return { room, lines: rows, more: s.docs.length >= C.page };
  }

  async send(uid, { room, text, appCheckBad = false } = {}) {
    room = String(room || '');
    let t = String(text || '').replace(/\s+/g, ' ').trim();
    if (!t) fail('empty');
    if (t.length > C.maxLen) fail('too_long');
    if (appCheckBad) fail('app_check', 403);
    if (await this._restricted(uid)) fail('restricted', 403);
    const u = await this._user(uid);
    const now = this.now();
    if (!u.rulesSeen) fail('rules_first');
    if (u.mutePerm || (u.mutedUntil && u.mutedUntil > now)) fail('muted', 403);
    if (!(await this._canRoom(uid, room))) fail('no_room', 403);
    if (room === 'server' && (u.level || 1) < C.serverLevel) fail('level');
    if (u.restUntil && u.restUntil > now) fail('rest');
    if (u.lastSendAt && now - u.lastSendAt < C.gapMs) fail('too_fast');
    const same = u.lastText === t ? (u.repeatN || 1) + 1 : 1;
    if (same >= C.repeatN) {
      await this._uref(uid).set({ ...u, restUntil: now + C.repeatRestMs, repeatN: 0, lastText: '' });
      fail('rest');
    }
    const list = await words.refresh(this.db, now);
    const shown = maskPrivate(maskBanned(t, list));
    const msg = { room, uid, name: u.name || '각성자', title: u.title || '', level: u.level || 1, text: shown, kind: 'user', at: now, expireAt: new Date(now + C.keepDays * DAY) };
    const ref = await this._msgs(room).add(msg);
    const rooms = new Set(u.rooms || []);
    rooms.add(room);
    await this._uref(uid).set({ ...u, lastSendAt: now, lastText: t, repeatN: same, rooms: [...rooms], reads: { ...(u.reads || {}), [room]: now } });
    return { ok: true, line: this._view(ref.id, msg), masked: shown !== t };
  }

  /** 길드 소식을 대화방에도 시스템 줄로 (공성전 · 영지 소식) */
  async system(room, text) {
    const now = this.now();
    await this._msgs(room).add({ room, uid: null, name: '', text: String(text).slice(0, 140), kind: 'sys', at: now, expireAt: new Date(now + C.keepDays * DAY) });
  }

  // ───────────── 친구

  async friendAdd(uid, { code, to } = {}) {
    if (await this._restricted(uid)) fail('restricted', 403);
    let target = to ? String(to) : null;
    if (!target && code) {
      const s = await this.db.doc(`friendCode/${String(code).toUpperCase().replace(/[^A-Z0-9]/g, '')}`).get();
      target = s.exists ? s.data().uid : null;
    }
    if (!target || !(await this._uref(target).get()).exists) fail('no_user', 404);
    if (target === uid) fail('self');
    const me = await this._user(uid);
    const them = await this._user(target);
    if ((me.friends || []).includes(target)) fail('already');
    if ((them.blocked || []).includes(uid) || (me.blocked || []).includes(target)) fail('blocked', 403);
    if ((me.friends || []).length >= C.maxFriends) fail('full');
    // 상대가 이미 나에게 신청했으면 바로 친구
    const back = this.db.doc(`friendReq/${uid}_${target}`);
    if ((await back.get()).exists) return this.friendAccept(uid, { from: target });
    await this.db.doc(`friendReq/${target}_${uid}`).set({ from: uid, to: target, at: this.now() });
    return { ok: true, sent: true };
  }

  async friendAccept(uid, { from } = {}) {
    const ref = this.db.doc(`friendReq/${uid}_${from}`);
    if (!(await ref.get()).exists) fail('no_request', 404);
    const me = await this._user(uid);
    const them = await this._user(from);
    if ((me.friends || []).length >= C.maxFriends || (them.friends || []).length >= C.maxFriends) fail('full');
    await this._uref(uid).set({ ...me, friends: [...new Set([...(me.friends || []), from])] });
    await this._uref(from).set({ ...them, friends: [...new Set([...(them.friends || []), uid])] });
    await ref.delete();
    await this.db.doc(`friendReq/${from}_${uid}`).delete();
    return { ok: true, friend: true };
  }

  async friendDecline(uid, { from } = {}) {
    await this.db.doc(`friendReq/${uid}_${from}`).delete();
    return { ok: true };
  }

  async friendRemove(uid, { to } = {}) {
    const me = await this._user(uid);
    const them = await this._user(to);
    await this._uref(uid).set({ ...me, friends: (me.friends || []).filter((x) => x !== to) });
    if ((await this._uref(to).get()).exists) await this._uref(to).set({ ...them, friends: (them.friends || []).filter((x) => x !== uid) });
    return { ok: true };
  }

  async block(uid, { to } = {}) {
    if (!to || to === uid) fail('bad_user');
    const me = await this._user(uid);
    await this._uref(uid).set({ ...me, blocked: [...new Set([...(me.blocked || []), to])], friends: (me.friends || []).filter((x) => x !== to) });
    const them = await this._user(to);
    if ((await this._uref(to).get()).exists) await this._uref(to).set({ ...them, friends: (them.friends || []).filter((x) => x !== uid) });
    await this.db.doc(`friendReq/${uid}_${to}`).delete();
    await this.db.doc(`friendReq/${to}_${uid}`).delete();
    return { ok: true };
  }

  async unblock(uid, { to } = {}) {
    const me = await this._user(uid);
    await this._uref(uid).set({ ...me, blocked: (me.blocked || []).filter((x) => x !== to) });
    return { ok: true };
  }

  // ───────────── 신고 · 운영

  async report(uid, { room, id, reason } = {}) {
    if (!REASONS[reason]) fail('bad_reason');
    room = String(room || '');
    if (!(await this._canRoom(uid, room))) fail('no_room', 403);
    const target = (await this._msgs(room).doc(id).get()).data();
    if (!target || target.kind !== 'user') fail('no_line', 404);
    const before = await this._msgs(room).where('at', '<', target.at).orderBy('at', 'desc').limit(10).get();
    const after = await this._msgs(room).where('at', '>', target.at).orderBy('at', 'asc').limit(10).get();
    const line = (d) => ({ id: d.id, uid: d.data().uid, name: d.data().name, text: d.data().text, at: d.data().at, kind: d.data().kind });
    await this.db.collection('chatReport').add({
      room,
      line: { id, uid: target.uid, name: target.name, text: target.text, at: target.at },
      context: [...before.docs.map(line).reverse(), { id, uid: target.uid, name: target.name, text: target.text, at: target.at, kind: 'user', target: true }, ...after.docs.map(line)],
      reason,
      reporter: uid,
      target: target.uid,
      status: 'open',
      at: this.now(),
    });
    // 신고된 줄은 처리가 끝날 때까지 지우지 않음 (처리 뒤 90일)
    await this._msgs(room).doc(id).set({ ...target, expireAt: null, reported: true });
    return { ok: true };
  }

  async reports({ status = 'open' } = {}) {
    const s = await this.db.collection('chatReport').orderBy('at', 'desc').limit(200).get();
    return {
      items: s.docs.map((d) => ({ id: d.id, ...d.data() })).filter((r) => !status || r.status === status),
      reasons: REASONS,
    };
  }

  /** 운영자: 「대화 금지 1일 · 7일 · 영구」 · 「경고」 · 「문제없음」 */
  async resolve(by, { id, action } = {}) {
    const ref = this.db.doc(`chatReport/${id}`);
    const r = (await ref.get()).data();
    if (!r) fail('no_report', 404);
    const now = this.now();
    const u = await this._user(r.target);
    let note = '';
    if (action === 'mute1' || action === 'mute7') {
      u.mutedUntil = Math.max(u.mutedUntil || 0, now) + (action === 'mute1' ? 1 : 7) * DAY;
      note = `대화 금지 ${action === 'mute1' ? 1 : 7}일`;
    } else if (action === 'mutePerm') {
      u.mutePerm = true;
      note = '대화 금지 (영구)';
    } else if (action === 'warn') {
      u.warns = (u.warns || 0) + 1;
      note = '경고';
    } else if (action !== 'none') {
      fail('bad_action');
    }
    if (action !== 'none') {
      await this._uref(r.target).set(u);
      await this.db.collection(`inbox/u_${r.target}/msgs`).add({
        from: '운영자',
        title: `대화 ${note}`,
        body: `대화방에서 운영정책에 맞지 않는 글이 신고되어 「${note}」 조치를 했어요. 이의가 있으면 설정 → 문의(제재 이의 제기)로 14일 안에 알려 주세요.`,
        reward: {},
        equips: [],
        at: now,
        kind: 'sanction',
      });
    }
    await ref.set({ ...r, status: 'done', action, by, doneAt: now, expireAt: new Date(now + C.reportKeepDays * DAY) });
    const mref = this._msgs(r.room).doc(r.line.id);
    const m = (await mref.get()).data();
    if (m) await mref.set({ ...m, expireAt: new Date(now + C.reportKeepDays * DAY) });
    return { ok: true };
  }

  /** 계정 지우기: 내 대화 · 친구 · 차단 · 신청 */
  async deleteFor(uid) {
    const u = await this._user(uid);
    for (const room of u.rooms || []) {
      const q = await this._msgs(room).where('uid', '==', uid).get();
      for (const d of q.docs) await d.ref.delete();
    }
    for (const f of u.friends || []) {
      const t = await this._user(f);
      if ((await this._uref(f).get()).exists) await this._uref(f).set({ ...t, friends: (t.friends || []).filter((x) => x !== uid) });
    }
    for (const side of ['to', 'from']) {
      const q = await this.db.collection('friendReq').where(side, '==', uid).get();
      for (const d of q.docs) await d.ref.delete();
    }
    if (u.friendCode) await this.db.doc(`friendCode/${u.friendCode}`).delete();
    await this._uref(uid).delete();
  }
}

module.exports = { ChatService, ChatError, maskPrivate, maskBanned, friendRoom, C, REASONS };
