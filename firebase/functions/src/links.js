// 묶음 57 #236: 파티 초대 링크 — https://<서버>/join/<코드>
// 앱이 있으면 iOS Universal Links · Android App Links 로 앱이 열려 「파티에 들어갈까요?」,
// 앱이 없으면 이 페이지(코드 + 스토어 안내)가 보인다.
const IOS_BUNDLE = 'kr.itso.isekaiReality';
const ANDROID_PACKAGE = 'kr.itso.isekai_reality';
const APP_STORE = 'https://apps.apple.com/kr/search?term=%EC%9D%B4%EC%84%B8%EA%B3%84%EA%B0%80%20%ED%98%84%EC%8B%A4%EC%9D%B4%EB%9D%BC%EB%A9%B4';
const PLAY_STORE = `https://play.google.com/store/apps/details?id=${ANDROID_PACKAGE}`;

const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);

function aasa(env) {
  const team = String(env.APPLE_TEAM_ID || '').trim();
  return {
    applinks: {
      apps: [],
      details: team ? [{ appIDs: [`${team}.${IOS_BUNDLE}`], components: [{ '/': '/join/*' }], appID: `${team}.${IOS_BUNDLE}`, paths: ['/join/*'] }] : [],
    },
  };
}

function assetLinks(env) {
  const prints = String(env.ANDROID_CERT_SHA256 || '')
    .split(',')
    .map((s) => s.trim().toUpperCase())
    .filter((s) => /^([0-9A-F]{2}:){31}[0-9A-F]{2}$/.test(s));
  if (!prints.length) return [];
  return [
    {
      relation: ['delegate_permission/common.handle_all_urls'],
      target: { namespace: 'android_app', package_name: ANDROID_PACKAGE, sha256_cert_fingerprints: prints },
    },
  ];
}

/** 앱이 없을 때 보이는 초대 페이지 (묶음 60: 길드 초대 /join/g/<코드> 도 같은 모양) */
function joinPage(code, kind = 'party') {
  const guild = kind === 'guild';
  const c = (guild ? /^[A-Z0-9]{6}$/ : /^[A-Z2-9]{6}$/).test(code) ? code : '';
  return `<!doctype html><html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>아르카 ${guild ? '길드' : '파티'} 초대</title><style>
body{margin:0;font-family:-apple-system,BlinkMacSystemFont,"Apple SD Gothic Neo","Noto Sans KR",sans-serif;background:#0b0d26;color:#f3eede;display:grid;place-items:center;min-height:100vh}
main{max-width:380px;padding:28px 22px;text-align:center}h1{font-size:22px;color:#f2c14e;margin:0 0 8px}
.code{font-size:34px;letter-spacing:8px;font-weight:800;margin:18px 0;padding:12px;border:1.5px solid #f2c14e;border-radius:14px}
a.btn{display:block;margin:10px 0;padding:13px;border-radius:12px;background:#f2c14e;color:#1a1405;font-weight:700;text-decoration:none}
a.ghost{background:transparent;color:#f2c14e;border:1px solid #f2c14e}p{color:#c9c3b4;line-height:1.6;font-size:14px}
</style></head><body><main>
<h1>${guild ? '길드' : '파티'}에 초대받았어요</h1>
<p>「이세계가 현실이라면? : 여명의 탑 아르카」에서 함께 걸어요.</p>
${c ? `<div class="code">${esc(c)}</div><p>${guild ? '앱을 연 뒤 마을 → 길드 회관 → 「초대 코드」에 이 코드를 넣어 주세요. (4막 2장 뒤에 열려요)' : '앱을 연 뒤 주점 → 파티 → 「초대 코드로 들어가기」에 이 코드를 넣어 주세요.'}</p>` : ''}
<a class="btn" href="${APP_STORE}">App Store에서 받기</a>
<a class="btn ghost" href="${PLAY_STORE}">Google Play에서 받기</a>
</main></body></html>`;
}

module.exports = { aasa, assetLinks, joinPage, IOS_BUNDLE, ANDROID_PACKAGE };
