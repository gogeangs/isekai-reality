// 길 나누기: /party/* (로그인) · /inquiry · /inbox (로그인 없어도) · /admin* (운영자) · /cron/daily (예약 작업)
const { PartyService } = require('./party');
const { InquiryService } = require('./inquiry');
const { AccountService } = require('./account');
const { MarketService } = require('./market');
const { DeepService } = require('./deep');
const { GuildService } = require('./guild');
const { AdminService } = require('./admin');
const { ChatService } = require('./chat');
const { SiegeService } = require('./siege');
const SCH = require('./siege_schedule');
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
  // 묶음 68: 대화 · 친구
  const chat = new ChatService(db, { guild });
  _deps = {
    db,
    party,
    inquiry,
    account: new AccountService(db, { auth: admin.auth(), party, inquiry, guild, chat }),
    chat,
    market,
    deep: new DeepService(db),
    guild,
    siege: new SiegeService(db, { guild, suspect, chat }),
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
const SOCIAL = ['/party/', '/guild/', '/market/', '/siege/', '/deep/', '/chat/'];

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

/** 테스트 공성전 길드 이름 (운영자 페이지) */
async function siegeGuildNames(deps, S) {
  const out = [];
  for (const gid of (S.test && S.test.gids) || []) {
    const g = (await deps.db.doc(`guilds/${gid}`).get()).data();
    out.push(g ? `${g.name} (${g.code || ''})` : gid);
  }
  return out;
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
      const mf = /^\/join\/f\/([A-Za-z0-9]{1,12})$/.exec(path);
      if (mf) {
        res.set('Content-Type', 'text/html; charset=utf-8');
        return res.send(links.joinPage(mf[1].toUpperCase(), 'friend'));
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
    // 묶음 69 #279: 공성전 일정 (운영자 스위치) — 공성전 · 길드 · 정리 요청마다 새로 읽음
    if (/^\/(siege|guild)\//.test(path)) (deps.db && (await SCH.load(deps.db)));
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
      // 묶음 69 #279: 공성전이 닫혀 있으면 공성권 · 수비대 · 전황 · 영지 관리는 막음 (지도 · 연맹은 그대로)
      if (/^\/siege\/(foe|fight|garrison|ungarrison|rally|repair|power|peek|estate)/.test(path)) {
        const { gid } = await s._mine(uid);
        if (!SCH.openFor(gid, Date.now())) return res.status(403).json({ error: 'siege_closed' });
      }
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
        '/siege/power': () => s.usePower(uid, body),
        // 묶음 65 #255: 영지 관리
        '/siege/estate': () => s.estateState(uid),
        '/siege/estate/build': () => s.estateBuild(uid, body),
        '/siege/estate/donate': () => s.estateDonate(uid, body),
        '/siege/estate/hunt': () => s.estateHunt(uid, body),
        '/siege/estate/policy': () => s.estatePolicy(uid, body),
        '/siege/estate/take': () => s.estateTake(uid, body),
        '/siege/estate/help': () => s.estateHelp(uid, body),
      }[path];
      if (!r) return res.status(404).json({ error: 'not_found' });
      return res.json(await r());
    }
    // 묶음 68 #275: 대화 · 친구
    if (path.startsWith('/chat/')) {
      const tok = await caller(req, deps, true);
      const uid = tok.uid;
      const ch = deps.chat;
      const r = {
        '/chat/me': () => ch.me(uid, body.me || {}),
        '/chat/rules': () => ch.rules(uid),
        '/chat/settings': () => ch.settings(uid, body),
        '/chat/read': () => ch.read(uid, body),
        '/chat/send': () => ch.send(uid, { ...body, appCheckBad: !!req.appCheckBad }),
        '/chat/friend/add': () => ch.friendAdd(uid, body),
        '/chat/friend/accept': () => ch.friendAccept(uid, body),
        '/chat/friend/decline': () => ch.friendDecline(uid, body),
        '/chat/friend/remove': () => ch.friendRemove(uid, body),
        '/chat/block': () => ch.block(uid, body),
        '/chat/unblock': () => ch.unblock(uid, body),
        '/chat/report': () => ch.report(uid, body),
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
    if (path === '/notices') {
      // 묶음 69 #279: 정기 공성전 일정도 함께 (로그인 안 한 사람의 5막도 같은 일정)
      if (deps.db) await SCH.load(deps.db);
      return res.json({ ...(await deps.admin.notices({})), siege: SCH.publicView() });
    }
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
        // 묶음 68: 대화 신고
        '/admin/chat/reports': () => deps.chat.reports(body),
        // 묶음 69 #279: 공성전 열기 스위치 · 테스트 공성전
        '/admin/siege/schedule': async () => ((deps.db && (await SCH.load(deps.db))), { ...SCH.view(Date.now()), guilds: await siegeGuildNames(deps, SCH.get()) }),
        '/admin/siege/open': async () => {
          (deps.db && (await SCH.load(deps.db)));
          const next = SCH.toggled(Date.now(), !!body.open);
          await deps.db.doc('erbard/schedule').set(next);
          SCH.set(next);
          if (deps.admin) await deps.admin.log(tok.email, 'siegeOpen', body.open ? 'open' : 'close', {});
          return { ...SCH.view(Date.now()), guilds: await siegeGuildNames(deps, SCH.get()) };
        },
        '/admin/siege/test': async () => {
          (deps.db && (await SCH.load(deps.db)));
          const now = Date.now();
          let next;
          if (body.action === 'start') {
            const codes = String(body.codes || '').toUpperCase().split(/[\s,]+/).filter(Boolean);
            const gids = [];
            for (const c of codes) {
              const q = await deps.db.collection('guilds').where('code', '==', c).get();
              if (q.docs.length) gids.push(q.docs[0].id);
            }
            if (!gids.length) return { error: 'no_guild' };
            try {
              next = SCH.testStarted(now, gids, Math.min(48, Math.max(1, Number(body.hours) || 48)));
            } catch (e) {
              return { error: e.code || 'bad' };
            }
          } else {
            next = SCH.testEnded(now);
          }
          await deps.db.doc('erbard/schedule').set(next);
          SCH.set(next);
          if (body.action !== 'start' && deps.siege) await deps.siege.settleDue();
          if (deps.admin) await deps.admin.log(tok.email, 'siegeTest', body.action === 'start' ? 'start' : 'end', {});
          return { ...SCH.view(now), guilds: await siegeGuildNames(deps, SCH.get()) };
        },
        '/admin/chat/resolve': async () => {
          const r = await deps.chat.resolve(tok.email, body);
          if (deps.admin) await deps.admin.log(tok.email, 'chatReport', body.id, { action: body.action });
          return r;
        },
      }[path];
      if (!r) return res.status(404).json({ error: 'not_found' });
      return res.json(await r());
    }
    if (path === '/cron/daily') {
      const key = req.get ? req.get('X-Cron-Key') : (req.headers || {})['x-cron-key'];
      if (!deps.env.CRON_KEY || key !== deps.env.CRON_KEY) return res.status(403).json({ error: 'forbidden' });
      (deps.db && (await SCH.load(deps.db)));
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
