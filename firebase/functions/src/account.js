// 계정: 삭제 요청 7일 뒤 로그인 계정(Auth)까지 지우기(매일 한 번) · 운영자 계정 보기(읽기 전용)
const zlib = require('zlib');

class AccountService {
  constructor(db, { now = () => Date.now(), auth, party, inquiry, guild } = {}) {
    this.db = db;
    this.now = now;
    this.auth = auth; // { deleteUser(uid) }
    this.party = party;
    this.inquiry = inquiry;
    this.guild = guild;
  }

  /** 삭제 시각이 지난 계정: 파티에서 빼고 · 문의 지우고 · 기록 지우고 · 로그인 계정 지움 */
  async sweep() {
    const now = new Date(this.now());
    const q = await this.db.collection('users').where('deleteAt', '<=', now).get();
    const done = [];
    for (const d of q.docs) {
      const uid = d.id;
      try {
        if (this.party) await this.party.leave(uid);
        // 묶음 60: 길드에서 빼고 · 거래 기록의 내 계정 번호를 지움(기록은 상대 쪽에 1년)
        if (this.guild) {
          try {
            await this.guild.leave(uid);
          } catch (e) {
            if (!/no_guild|not_in_guild/.test(String(e && (e.code || e.message)))) throw e;
          }
        }
        for (const side of ['seller', 'buyer']) {
          const q2 = await this.db.collection('marketLog').where(side, '==', uid).get();
          for (const x of q2.docs) await x.ref.set({ ...x.data(), [side]: 'deleted' });
        }
        if (this.inquiry) await this.inquiry.deleteFor(uid);
        await this.db.doc(`presence/${uid}`).delete();
        const parts = await this.db.collection(`users/${uid}/parts`).get();
        for (const p of parts.docs) await p.ref.delete();
        await d.ref.delete();
        if (this.auth) {
          try {
            await this.auth.deleteUser(uid);
          } catch (e) {
            if (!String(e && e.code).includes('user-not-found')) throw e;
          }
        }
        done.push(uid);
      } catch (e) {
        console.error('계정 삭제 실패', uid, e);
      }
    }
    return { deleted: done.length };
  }

  /** 운영자: 계정 기록 보기 (읽기 전용 요약) */
  async view({ uid }) {
    if (typeof uid !== 'string' || !/^[A-Za-z0-9]{6,128}$/.test(uid)) return { found: false };
    const u = await this.db.doc(`users/${uid}`).get();
    if (!u.exists) return { found: false };
    const meta = u.data();
    const st = await this.db.doc(`status/${uid}`).get();
    const po = await this.db.doc(`partyOf/${uid}`).get();
    let summary = null;
    try {
      const parts = await this.db.collection(`users/${uid}/parts`).get();
      const mine = parts.docs
        .filter((p) => String(p.data().gen) === String(meta.gen))
        .sort((a, b) => Number(a.id.split('_')[1]) - Number(b.id.split('_')[1]))
        .map((p) => p.data().data || '')
        .join('');
      if (mine) summary = summarize(JSON.parse(zlib.gunzipSync(Buffer.from(mine, 'base64')).toString('utf8')));
    } catch (e) {
      summary = { error: '기록을 읽지 못했어요' };
    }
    const ts = (v) => (v && v.toDate ? v.toDate().toISOString() : v instanceof Date ? v.toISOString() : v || null);
    return {
      found: true,
      uid,
      level: meta.level || null,
      lastDay: meta.lastDay || null,
      updatedAt: ts(meta.updatedAt),
      deleteAt: ts(meta.deleteAt),
      devices: (meta.devices || []).length,
      status: st.exists ? st.data() : null,
      party: po.exists ? po.data().pid : null,
      summary,
    };
  }
}

/** 백업 스냅숏 → 운영자가 볼 요약 (위치는 넣지 않음) */
function summarize(snap) {
  const j = (k) => {
    try {
      return snap[k] ? JSON.parse(snap[k]) : null;
    } catch (e) {
      return null;
    }
  };
  const profile = j('profile.v1') || {};
  const history = j('history.v1') || [];
  const days = Array.isArray(history) ? history.length : 0;
  const gold = Array.isArray(history)
    ? history.reduce((s, r) => s + Number(((r.gains || {}).gold) || 0) - Number(((r.spends || {}).gold) || 0), 0)
    : 0;
  const steps = Array.isArray(history) ? history.reduce((s, r) => s + Number(r.steps || 0), 0) : 0;
  return {
    name: profile.name || null,
    spirit: profile.spiritName || null,
    days,
    steps,
    goldFromRecords: gold,
    keys: Object.keys(snap).length,
  };
}

module.exports = { AccountService, summarize };
