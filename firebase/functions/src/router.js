// 길 나누기: /party/* (로그인) · /inquiry · /inbox (로그인 없어도) · /admin* (운영자) · /cron/daily (예약 작업)
const { PartyService } = require('./party');
const { InquiryService } = require('./inquiry');
const { AccountService } = require('./account');
const { MarketService } = require('./market');
const { DeepService } = require('./deep');
const { GuildService } = require('./guild');
const { AdminService } = require('./admin');
const { SiegeService } = require('./siege');
const { SuspectService } = require('./suspect');
const { adminPage } = require('./admin_page');
const words = require('./words');
const legal = require('./legal_pages');
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
  const guild = new GuildService(db);
  const suspect = new SuspectService(db);
  const market = new MarketService(db);
  market.suspect = suspect;
  _deps = {
    db,
    party,
    inquiry,
    account: new AccountService(db, { auth: admin.auth(), party, inquiry, guild }),
    market,
    deep: new DeepService(db),
    guild,
    siege: new SiegeService(db, { guild, suspect }),
    suspect,
    // 묶음 61: 진짜 앱 확인 (App Check). 처음엔 기록만
    appCheck: async (token) => {
      await admin.appCheck().verifyToken(token);
      return true;
    },
    admin: new AdminService(db),
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

/** 다른 사람과 얽히는 길 (진짜 앱 확인 · 걸음 기록) */
const SOCIAL = ['/party/', '/guild/', '/market/', '/siege/', '/deep/'];

/**
 * 묶음 61 #250: 진짜 앱 확인 (Firebase App Check). APPCHECK_MODE=block 이면 막고, 아니면 기록만 (통과율 · 의심 목록)
 * 걸린 결과는 서버 기록에만 남기고 응답 · 로그에 토큰을 찍지 않는다
 */
async function appCheck(req, deps, uid) {
  if (!deps.appCheck || !deps.suspect) return true;
  const h = req.get ? req.get('X-Firebase-AppCheck') : (req.headers || {})['x-firebase-appcheck'];
  let result = 'missing';
  if (h) {
    try {
      result = (await deps.appCheck(String(h))) ? 'ok' : 'bad';
    } catch (e) {
      result = 'bad';
    }
  }
  try {
    await deps.suspect.appCheckStat(result);
    if (result === 'bad') await deps.suspect.hit(uid, 'appcheck', {});
  } catch (e) {
    // 기록이 안 돼도 이어서
  }
  req.appCheckBad = result === 'bad';
  const block = String((deps.env || {}).APPCHECK_MODE || 'log') === 'block';
  return !(block && result !== 'ok');
}

/** 앱이 함께 보낸 걸음 기록 · 가짜 위치 표시 (참고용) */
async function noteMe(deps, uid, me) {
  if (!deps.suspect || !me || typeof me !== 'object') return;
  try {
    if (me.steps != null || me.manual) await deps.suspect.steps(uid, { steps: me.steps, maxHour: me.maxHour, manual: me.manual });
    if (me.mock) await deps.suspect.hit(uid, 'mock', {});
  } catch (e) {
    // 기록이 안 돼도 이어서
  }
}

async function handle(req, res) {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Headers', 'Authorization, Content-Type, X-Cron-Key, X-Firebase-AppCheck');
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
      // 묶음 60: 약관 · 정책 · 계정 삭제 안내 (스토어 등록용)
      const lp = legal.legalPage(path) || (path === '/delete-account' ? legal.deletePage() : null);
      if (lp) {
        res.set('Content-Type', 'text/html; charset=utf-8');
        res.set('Cache-Control', 'public, max-age=600');
        return res.send(lp);
      }
      const mg = /^\/join\/g\/([A-Za-z0-9]{1,12})$/.exec(path);
      if (mg) {
        res.set('Content-Type', 'text/html; charset=utf-8');
        return res.send(links.joinPage(mg[1].toUpperCase(), 'guild'));
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
    if (SOCIAL.some((x) => path.startsWith(x))) {
      const tok = await caller(req, deps, true);
      if (!(await appCheck(req, deps, tok.uid))) return res.status(401).json({ error: 'app_check' });
      await noteMe(deps, tok.uid, body.me);
      // 묶음 65: 진짜 앱 확인에 실패한 요청의 걸음은 공성 게이지에 넣지 않음
      if (body.me && typeof body.me === 'object') body.me.__bad = !!req.appCheckBad;
    }

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
        '/party/near': () => p.near(uid, body, deps.suspect),
      }[path];
      if (!r) return res.status(404).json({ error: 'not_found' });
      return res.json(await r());
    }
    // 묶음 58: 거래소 (#229)
    if (path.startsWith('/market/')) {
      const tok = await caller(req, deps, true);
      const uid = tok.uid;
      const m = deps.market;
      const r = {
        '/market/list': () => m.list(uid, body),
        '/market/browse': () => m.browse(uid, body),
        '/market/mine': () => m.mine(uid),
        '/market/price': () => m.price(uid, body),
        '/market/buy': () => m.buy(uid, body),
        '/market/bid': () => m.bid(uid, body),
        '/market/cancel': () => m.cancel(uid, body),
        '/market/wallet': () => m.walletState(uid),
        '/market/deposit': () => m.deposit(uid, body),
        '/market/withdraw': () => m.withdraw(uid, body),
      }[path];
      if (!r) return res.status(404).json({ error: 'not_found' });
      return res.json(await r());
    }
    // 묶음 59: 길드 (#246)
    // 묶음 60: 5막 에르바르드 (영지 · 야생 수비대 · 공성전 · 수비대 · 연맹)
    if (path.startsWith('/siege/')) {
      const tok = await caller(req, deps, true);
      const uid = tok.uid;
      const s = deps.siege;
      const r = {
        '/siege/state': () => s.state(uid, body.me || {}),
        '/siege/foe': () => s.foe(uid, body),
        '/siege/fight': () => s.fight(uid, body),
        '/siege/garrison': () => s.garrison(uid, body),
        '/siege/ungarrison': () => s.ungarrison(uid),
        '/siege/alliance': () => s.alliance(uid, body),
        '/siege/rally': () => s.rally(uid, body),
        '/siege/repair': () => s.repairTarget(uid, body),
        '/siege/peek': () => s.peek(uid, body),
      }[path];
      if (!r) return res.status(404).json({ error: 'not_found' });
      return res.json(await r());
    }
    if (path.startsWith('/guild/')) {
      const tok = await caller(req, deps, true);
      const uid = tok.uid;
      const me = body.me || {};
      const g = deps.guild;
      const r = {
        '/guild/state': () => g.state(uid, me),
        '/guild/create': () => g.create(uid, body),
        '/guild/join': () => g.join(uid, body),
        '/guild/list': () => g.list(uid, body),
        '/guild/leave': () => g.leave(uid),
        '/guild/kick': () => g.kick(uid, body),
        '/guild/role': () => g.role(uid, body),
        '/guild/style': () => g.style(uid, body),
        '/guild/line': () => g.line(uid, body),
        '/guild/donate': () => g.donate(uid, body),
        '/guild/deco/add': () => g.decoAdd(uid, body),
        '/guild/deco/place': () => g.decoPlace(uid, body),
        '/guild/share': () => g.share(uid, body),
        '/guild/raid': () => g.raidHit(uid, body),
        '/guild/claim': () => g.claim(uid, body),
        '/guild/treasury': () => g.treasury(uid, body),
      }[path];
      if (!r) return res.status(404).json({ error: 'not_found' });
      return res.json(await r());
    }
    // 묶음 59: 공지 (로그인 없어도) · 내 제재 상태
    if (path === '/notices') return res.json(await deps.admin.notices({}));
    if (path === '/status') {
      const tok = await caller(req, deps, true);
      return res.json(await deps.admin.myStatus(tok.uid));
    }
    // 묶음 58: 심층 주간 순위
    if (path === '/deep/board' || path === '/deep/submit') {
      const tok = await caller(req, deps, true);
      return res.json(
        path === '/deep/board' ? await deps.deep.board(tok.uid) : await deps.deep.submit(tok.uid, body),
      );
    }
    if (path === '/inquiry') {
      const tok = await caller(req, deps, false);
      return res.json(await deps.inquiry.send(tok && tok.uid, body));
    }
    if (path === '/inbox') {
      const tok = await caller(req, deps, false);
      const box = await deps.inquiry.inbox(tok && tok.uid, body);
      // 묶음 59: 모두에게 보상 우편 (앱이 우편 번호로 한 번만 받음)
      const bc = deps.admin ? await deps.admin.activeBroadcasts() : [];
      return res.json({ msgs: [...box.msgs, ...bc] });
    }
    if (path.startsWith('/admin/')) {
      const tok = await caller(req, deps, true);
      if (!isAdmin(tok, deps.env)) return res.status(403).json({ error: 'not_admin' });
      const r = {
        '/admin/me': async () => ({ ok: true, email: tok.email }),
        '/admin/list': () => deps.inquiry.list(body),
        '/admin/photo': () => deps.inquiry.photo(body),
        '/admin/reply': async () => {
          const r = await deps.inquiry.reply(body);
          if (deps.admin) await deps.admin.log(tok.email, 'reply', body.id, {});
          return r;
        },
        '/admin/account': () => deps.account.view(body),
        '/admin/words': () => words.view(deps.db),
        '/admin/words/save': async () => {
          const r = await words.save(deps.db, body.text);
          if (deps.admin) await deps.admin.log(tok.email, 'words', '', {});
          return r;
        },
        '/admin/trades': () => deps.market.trades(body),
        '/admin/sanctions': () => deps.admin.sanctions(body),
        '/admin/sanction': () => deps.admin.sanction(tok.email, body),
        '/admin/unsanction': () => deps.admin.unsanction(tok.email, body),
        '/admin/rename': () => deps.admin.rename(tok.email, body),
        '/admin/revert': () => deps.admin.revert(tok.email, body),
        '/admin/notices': () => deps.admin.notices({ all: true }),
        '/admin/notice': () => deps.admin.notice(tok.email, body),
        '/admin/notice/delete': () => deps.admin.noticeDelete(tok.email, body),
        '/admin/broadcast': () => deps.admin.broadcast(tok.email, body),
        '/admin/log': () => deps.admin.logs(body),
        '/admin/suspects': () => deps.suspect.list(body),
      }[path];
      if (!r) return res.status(404).json({ error: 'not_found' });
      return res.json(await r());
    }
    if (path === '/cron/daily') {
      const key = req.get ? req.get('X-Cron-Key') : (req.headers || {})['x-cron-key'];
      if (!deps.env.CRON_KEY || key !== deps.env.CRON_KEY) return res.status(403).json({ error: 'forbidden' });
      const swept = await deps.account.sweep();
      const market = deps.market ? await deps.market.settleDue() : null;
      const deep = deps.deep ? await deps.deep.payLastWeek() : null;
      const siege = deps.siege ? await deps.siege.settleDue() : null;
      return res.json({ ...swept, market, deep, siege });
    }
    return res.status(404).json({ error: 'not_found' });
  } catch (e) {
    const status = e.status || 500;
    if (status >= 500) console.error(e);
    return res.status(status).json({ error: e.code || 'server' });
  }
}

module.exports = { handle, setDeps, isAdmin };
