// 묶음 60: 스토어 등록용 웹 페이지 (로그인 없이 · 휴대폰 화면에 맞게)
//  /privacy · /location-terms · /terms · /policy — 앱 안 문서와 같은 글(assets/legal → legal_texts.json, 시험이 같은지 봄)
//  /delete-account — 계정 삭제 안내 (Play 「계정 삭제 요청 URL」)
const TEXTS = require('./legal_texts.json');

const APP = '이세계가 현실이라면? : 여명의 탑 아르카';
const DEV = '주식회사 프로젝트서티즈';
const MAIL = 'biz@project30s.co.kr';

const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);

const PAGES = {
  '/privacy': 'privacy',
  '/location-terms': 'location',
  '/terms': 'terms',
  '/policy': 'policy',
};

const NAV = [
  ['/terms', '이용약관'],
  ['/privacy', '개인정보 처리방침'],
  ['/location-terms', '위치기반서비스 이용약관'],
  ['/policy', '운영정책'],
  ['/delete-account', '계정 삭제'],
];

function shell(title, body, here) {
  return `<!doctype html><html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(title)} · 아르카</title><style>
:root{color-scheme:light dark;--bg:#fbf8f1;--fg:#221d14;--muted:#6b6355;--line:#e4dccb;--accent:#8a5a00}
@media (prefers-color-scheme:dark){:root{--bg:#0f1024;--fg:#efe9da;--muted:#a9a293;--line:#2a2b48;--accent:#f2c14e}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--fg);font:16px/1.7 -apple-system,BlinkMacSystemFont,"Apple SD Gothic Neo","Noto Sans KR",sans-serif;word-break:keep-all;overflow-wrap:anywhere}
main{max-width:760px;margin:0 auto;padding:20px 16px 56px}header{border-bottom:1px solid var(--line);padding-bottom:12px;margin-bottom:8px}
.app{font-size:13px;color:var(--muted)}h1{font-size:24px;margin:4px 0 0}h2{font-size:17px;margin:26px 0 6px;color:var(--accent)}
p,li{margin:6px 0}ul,ol{padding-left:22px}nav{display:flex;flex-wrap:wrap;gap:6px 14px;font-size:14px;margin:10px 0 0}
nav a{color:var(--muted);text-decoration:none}nav a.on{color:var(--accent);font-weight:700}a{color:var(--accent)}
.box{border:1px solid var(--line);border-radius:12px;padding:12px 16px;margin:14px 0}footer{margin-top:36px;font-size:13px;color:var(--muted);border-top:1px solid var(--line);padding-top:12px}
</style></head><body><main><header><div class="app">${esc(APP)} · ${esc(DEV)}</div><h1>${esc(title)}</h1>
<nav>${NAV.map(([h, t]) => `<a href="${h}"${h === here ? ' class="on"' : ''}>${esc(t)}</a>`).join('')}</nav></header>
${body}
<footer>${esc(DEV)} · 대표 고경민 · 사업자등록번호 156-81-03105 · 경기도 안산시 상록구 한양대학로 55 창업보육센터 524호 · <a href="mailto:${MAIL}">${MAIL}</a></footer>
</main></body></html>`;
}

/** 앱 안 문서 글(# 제목 · ## 조 · - 줄) → HTML */
function render(text) {
  const lines = String(text).split('\n');
  let title = '';
  const out = [];
  let list = false;
  const close = () => {
    if (list) out.push('</ul>');
    list = false;
  };
  for (const raw of lines) {
    const l = raw.trimEnd();
    if (!l.trim()) {
      close();
      continue;
    }
    if (l.startsWith('# ')) {
      title = l.slice(2).trim();
      continue;
    }
    if (l.startsWith('## ')) {
      close();
      out.push(`<h2>${esc(l.slice(3).trim())}</h2>`);
      continue;
    }
    if (l.startsWith('- ')) {
      if (!list) out.push('<ul>');
      list = true;
      out.push(`<li>${esc(l.slice(2).trim())}</li>`);
      continue;
    }
    close();
    out.push(`<p>${esc(l)}</p>`);
  }
  close();
  return { title, html: out.join('\n') };
}

function legalPage(path) {
  const key = PAGES[path];
  if (!key) return null;
  const { title, html } = render(TEXTS[key]);
  return shell(title, html, path);
}

function deletePage() {
  const body = `
<div class="box"><b>앱 이름</b> ${esc(APP)}<br><b>개발자</b> ${esc(DEV)}</div>
<h2>앱 안에서 계정 지우기</h2>
<ol>
<li>앱을 열고 설정으로 가요.</li>
<li>계정 → 「계정 삭제」를 눌러요.</li>
<li>삭제를 요청한 날부터 7일 뒤에 지워져요. 7일 안에 다시 로그인하면 요청이 취소돼요.</li>
</ol>
<h2>앱이 없을 때</h2>
<p><a href="mailto:${MAIL}?subject=${encodeURIComponent('[아르카] 계정 삭제 요청')}">${MAIL}</a> 로 계정 번호(앱 설정 → 문의 화면 아래에 보이는 짧은 코드)나 로그인한 이메일(Apple · Google)을 적어 보내 주세요. 본인 확인 뒤 지우고 답장으로 알려 드려요. 비밀번호는 묻지 않아요.</p>
<h2>지워지는 것</h2>
<ul>
<li>로그인 정보(Apple · Google 계정 식별값 · 이메일)</li>
<li>서버에 백업한 게임 기록(걸음 수 · 지도 칸 번호 포함)</li>
<li>파티 · 길드 기록(길드원 기록 · 공성전 기록에서 빠짐)</li>
<li>문의 기록(내용 · 사진 · 이메일)</li>
</ul>
<h2>남는 것과 기간</h2>
<ul>
<li>거래 기록: 상대가 있는 거래는 상대 쪽에 거래가 끝난 날부터 1년 남아요. 내 계정 번호는 지워요.</li>
<li>제재 기록: 제재가 끝난 날부터 1년, 영구 정지는 정지한 날부터 3년 남아요(다시 가입해 부정 이용을 되풀이하는 것을 막기 위해).</li>
<li>심층 순위 기록: 순위 보상을 보낸 뒤 4주에 지워져요.</li>
</ul>
<p>로그인하지 않고 쓴 기록은 휴대폰에만 있어요. 앱의 설정 → 「모든 기록 지우고 처음부터」나 앱 삭제로 지울 수 있어요.</p>`;
  return shell('계정 삭제 안내', body, '/delete-account');
}

module.exports = { legalPage, deletePage, render, PAGES, TEXTS };
