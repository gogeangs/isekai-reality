// 길 나누기: /party/* (로그인) · /inquiry · /inbox (로그인 없어도) · /admin* (운영자) · /cron/daily (예약 작업)
const { PartyService } = require('./party');
const { InquiryService } = require('./inquiry');
const { AccountService } = require('./account');
const { adminPage } = require('./admin_page');
const words = require('./words');
const links = require('./links');

let _deps = null;

/** 실제 Firebase (처음 부를 때 한 번) */
function realDeps() {
  if (_deps) return _deps;
  const admin = require('firebase-admin');
  if (!admin.apps.length) admin.initializeApp();
  const db = admin.firestore();
  db.settings({ ignoreUndefinedProperties: true });
  const party = new PartyService(db);
  const inquiry = new InquiryService(db);
  _deps = {
    db,
    party,
    inquiry,
    account: new AccountService(db, { auth: admin.auth(), party, inquiry }),
    verify: (token) => admin.auth().verifyIdToken(token),
    env: process.env,
  };
  return _deps;
}

function setDeps(d) {
  _deps = d;
}

async function caller(req, deps, required) {
  const h = req.get ? req.get('Authorization') || '' : (req.headers || {}).authorization || '';
  const m = /^Bearer (.+)$/.exec(h);
  if (!m) {
    if (required) throw Object.assign(new Error('login_required'), { status: 401, code: 'login_required' });
    return null;
  }
  try {
    return await deps.verify(m[1]);
  } catch (e) {
    if (required) throw Object.assign(new Error('login_required'), { status: 401, code: 'login_required' });
    return null;
  }
}

function isAdmin(tok, env) {
  const list = String(env.ADMIN_EMAILS || '')
    .split(',')
    .map((s) => s.trim().toLowerCase())
    .filter(Boolean);
  return !!(tok && tok.email && tok.email_verified !== false && list.includes(String(tok.email).toLowerCase()));
}

async function handle(req, res) {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Headers', 'Authorization, Content-Type, X-Cron-Key');
  if (req.method === 'OPTIONS') return res.status(204).send('');
  const path = (req.path || '/').replace(/\/+$/, '') || '/';
  const body = (req.body && typeof req.body === 'object' ? req.body : {}) || {};
  try {
    if (path === '/ping') return res.json({ ok: true, at: Date.now() });
    // 묶음 57: 파티 초대 링크 (앱이 있으면 앱이 열리고, 없으면 안내 페이지)
    if (req.method === 'GET') {
      const env = (_deps && _deps.env) || process.env;
      if (path === '/.well-known/apple-app-site-association' || path === '/apple-app-site-association') {
        res.set('Content-Type', 'application/json');
        return res.send(JSON.stringify(links.aasa(env)));
      }
      if (path === '/.well-known/assetlinks.json') {
        res.set('Content-Type', 'application/json');
        return res.send(JSON.stringify(links.assetLinks(env)));
      }
      const m = /^\/join\/([A-Za-z0-9]{1,12})$/.exec(path);
      if (m) {
        res.set('Content-Type', 'text/html; charset=utf-8');
        return res.send(links.joinPage(m[1].toUpperCase()));
      }
    }
    const deps = realDeps();

    if (path === '/admin' && req.method === 'GET') {
      res.set('Content-Type', 'text/html; charset=utf-8');
      res.set('Cache-Control', 'no-store');
      return res.send(adminPage(deps.env));
    }
    if (req.method !== 'POST') return res.status(405).json({ error: 'method' });
    // 묶음 57: 금칙어 목록 (5분마다 다시 읽음)
    await words.refresh(deps.db);
    if (path === '/words') return res.json({ text: words.currentText() });

    if (path.startsWith('/party/')) {
      const tok = await caller(req, deps, true);
      const uid = tok.uid;
      const me = body.me || {};
      const p = deps.party;
      const r = {
        '/party/state': () => p.state(uid, me),
        '/party/create': () => p.create(uid, body),
        '/party/join': () => p.join(uid, body),
        '/party/leave': () => p.leave(uid),
        '/party/kick': () => p.kick(uid, body),
        '/party/style': () => p.style(uid, body),
        '/party/cheer': () => p.cheer(uid, body),
        '/party/boss': () => p.bossHit(uid, body),
        '/party/claim': () => p.claim(uid, body),
        '/party/near': () => p.near(uid, body),
      }[path];
      if (!r) return res.status(404).json({ error: 'not_found' });
      return res.json(await r());
    }
    if (path === '/inquiry') {
      const tok = await caller(req, deps, false);
      return res.json(await deps.inquiry.send(tok && tok.uid, body));
    }
    if (path === '/inbox') {
      const tok = await caller(req, deps, false);
      return res.json(await deps.inquiry.inbox(tok && tok.uid, body));
    }
    if (path.startsWith('/admin/')) {
      const tok = await caller(req, deps, true);
      if (!isAdmin(tok, deps.env)) return res.status(403).json({ error: 'not_admin' });
      const r = {
        '/admin/me': async () => ({ ok: true, email: tok.email }),
        '/admin/list': () => deps.inquiry.list(body),
        '/admin/photo': () => deps.inquiry.photo(body),
        '/admin/reply': () => deps.inquiry.reply(body),
        '/admin/account': () => deps.account.view(body),
        '/admin/words': () => words.view(deps.db),
        '/admin/words/save': () => words.save(deps.db, body.text),
      }[path];
      if (!r) return res.status(404).json({ error: 'not_found' });
      return res.json(await r());
    }
    if (path === '/cron/daily') {
      const key = req.get ? req.get('X-Cron-Key') : (req.headers || {})['x-cron-key'];
      if (!deps.env.CRON_KEY || key !== deps.env.CRON_KEY) return res.status(403).json({ error: 'forbidden' });
      return res.json(await deps.account.sweep());
    }
    return res.status(404).json({ error: 'not_found' });
  } catch (e) {
    const status = e.status || 500;
    if (status >= 500) console.error(e);
    return res.status(status).json({ error: e.code || 'server' });
  }
}

module.exports = { handle, setDeps, isAdmin };
