// 문의 (#248): 앱에서 보내기(로그인 안 해도 됨, 하루 3건) · 답 우편 받기 · 운영자 답 · 계정 삭제 때 함께 지움
const R = require('./rules');

class InquiryError extends Error {
  constructor(code, status = 400) {
    super(code);
    this.code = code;
    this.status = status;
  }
}
const fail = (code, status) => {
  throw new InquiryError(code, status);
};

const okId = (s) => typeof s === 'string' && /^[A-Za-z0-9_-]{6,128}$/.test(s);

class InquiryService {
  constructor(db, { now = () => Date.now() } = {}) {
    this.db = db;
    this.now = now;
  }

  /** 문의 보내기. [uid] 는 로그인했을 때만 */
  async send(uid, body = {}) {
    const { kind, text, photo, install, appVersion, model, email } = body;
    if (!R.INQUIRY_KINDS.includes(kind)) fail('bad_kind');
    if (!okId(install)) fail('bad_install');
    const t = String(text || '').trim();
    if (t.length < 2 || t.length > 2000) fail('bad_text');
    if (photo != null && (typeof photo !== 'string' || photo.length > R.PHOTO_MAX)) fail('bad_photo');
    const mail = email ? String(email).trim() : '';
    if (mail && (mail.length > 120 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(mail))) fail('bad_email');
    const now = this.now();
    const day = R.dayKey(now);
    // 하루 3건 (설치 번호 · 계정마다)
    const keys = [`i_${install}_${day}`, ...(uid ? [`u_${uid}_${day}`] : [])];
    for (const k of keys) {
      const s = await this.db.doc(`inquiryDays/${k}`).get();
      if (s.exists && (s.data().n || 0) >= R.INQUIRY_PER_DAY) fail('too_many', 429);
    }
    const ref = await this.db.collection('inquiries').add({
      kind,
      text: t,
      hasPhoto: !!photo,
      install,
      uid: uid || null,
      appVersion: String(appVersion || '').slice(0, 40),
      model: String(model || '').slice(0, 60),
      email: mail || null,
      at: now,
      status: 'new',
    });
    if (photo) await this.db.doc(`inquiryPhotos/${ref.id}`).set({ data: photo, uid: uid || null, install });
    for (const k of keys) {
      const s = await this.db.doc(`inquiryDays/${k}`).get();
      await this.db
        .doc(`inquiryDays/${k}`)
        .set({ n: ((s.exists && s.data().n) || 0) + 1, expireAt: new Date(now + 2 * 86400000) });
    }
    return { ok: true, id: ref.id };
  }

  /** 답 우편 받기: 설치 번호와 (로그인했으면) 계정으로 온 것. 받으면 지움 */
  async inbox(uid, { install } = {}) {
    const boxes = [...(okId(install) ? [`i_${install}`] : []), ...(uid ? [`u_${uid}`] : [])];
    const out = [];
    for (const b of boxes) {
      const q = await this.db.collection(`inbox/${b}/msgs`).get();
      for (const d of q.docs) {
        out.push({ id: d.id, ...d.data() });
        await d.ref.delete();
      }
    }
    out.sort((a, b) => (a.at || 0) - (b.at || 0));
    return { msgs: out };
  }

  // ───────────── 운영자

  async list({ kind, status, limit = 100 } = {}) {
    // 복합 색인 없이: 최근 500건에서 거름
    const s = await this.db.collection('inquiries').orderBy('at', 'desc').limit(500).get();
    const items = s.docs
      .map((d) => ({ id: d.id, ...d.data() }))
      .filter((x) => (!kind || x.kind === kind) && (!status || x.status === status))
      .slice(0, Math.min(200, limit));
    return { items };
  }

  async photo({ id }) {
    if (!okId(id)) fail('bad_id');
    const s = await this.db.doc(`inquiryPhotos/${id}`).get();
    return { data: s.exists ? s.data().data : null };
  }

  /** 답 쓰기 + 보상 우편. 답한 날부터 1년 뒤 TTL 로 지움 */
  async reply({ id, body, reward = {} } = {}) {
    if (!okId(id)) fail('bad_id');
    const text = String(body || '').trim();
    if (text.length < 1 || text.length > 3000) fail('bad_text');
    const s = await this.db.doc(`inquiries/${id}`).get();
    if (!s.exists) fail('no_inquiry', 404);
    const q = s.data();
    const clean = {};
    for (const k of ['gold', 'manaStone', 'footTicket']) {
      const n = Math.floor(Number(reward[k] || 0));
      if (n > 0) clean[k] = Math.min(n, 100000);
    }
    const now = this.now();
    const box = q.uid ? `u_${q.uid}` : `i_${q.install}`;
    await this.db.collection(`inbox/${box}/msgs`).add({
      kind: 'inquiryReply',
      inquiry: id,
      title: '문의에 답이 왔어요',
      body: text,
      reward: clean,
      at: now,
    });
    const expireAt = new Date(now + R.INQUIRY_KEEP_MS);
    await this.db.doc(`inquiries/${id}`).set({ ...q, status: 'answered', reply: text, reward: clean, answeredAt: now, expireAt });
    if (q.hasPhoto) {
      const p = await this.db.doc(`inquiryPhotos/${id}`).get();
      if (p.exists) await this.db.doc(`inquiryPhotos/${id}`).set({ ...p.data(), expireAt });
    }
    const mailto = q.email
      ? `mailto:${encodeURIComponent(q.email)}?subject=${encodeURIComponent('[아르카] 문의 답변')}&body=${encodeURIComponent(text)}`
      : null;
    return { ok: true, mailto };
  }

  /** 계정 삭제 때: 그 계정 문의 · 사진 · 받지 않은 답을 함께 지움 */
  async deleteFor(uid) {
    const q = await this.db.collection('inquiries').where('uid', '==', uid).get();
    for (const d of q.docs) {
      await this.db.doc(`inquiryPhotos/${d.id}`).delete();
      await d.ref.delete();
    }
    const m = await this.db.collection(`inbox/u_${uid}/msgs`).get();
    for (const d of m.docs) await d.ref.delete();
    return q.size;
  }
}

module.exports = { InquiryService, InquiryError };
