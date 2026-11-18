// 운영자 웹 관리 페이지 (#248): 문의 목록 · 계정 기록 보기(읽기 전용) · 답 + 보상 우편 · 이메일 답
// 운영자만: Google 로그인 → 서버가 ADMIN_EMAILS 에 있는 계정인지 확인

function adminPage(env) {
  let cfg = {};
  try {
    cfg = JSON.parse(env.WEB_CONFIG || '{}');
  } catch (e) {
    cfg = {};
  }
  const ready = !!(cfg.apiKey && cfg.authDomain);
  return `<!doctype html>
<html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>아르카 운영</title>
<style>
:root{--bg:#14122b;--panel:#1f1c3d;--line:#3a3566;--text:#eee8d8;--muted:#a59fc2;--gold:#e8c46a;--red:#ff8a80}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);font:14px/1.5 -apple-system,"Apple SD Gothic Neo","Noto Sans KR",sans-serif}
header{display:flex;gap:12px;align-items:center;padding:12px 18px;border-bottom:1px solid var(--line)}
header h1{font-size:18px;margin:0;color:var(--gold)}#who{margin-left:auto;color:var(--muted)}
button{background:var(--gold);color:#241a08;border:0;border-radius:8px;padding:6px 12px;font-weight:700;cursor:pointer}
button.ghost{background:transparent;color:var(--text);border:1px solid var(--line)}
select,input,textarea{background:#0f0d22;color:var(--text);border:1px solid var(--line);border-radius:6px;padding:6px}
main{display:grid;grid-template-columns:minmax(320px,42%) 1fr;gap:14px;padding:14px 18px}
.panel{background:var(--panel);border:1px solid var(--line);border-radius:10px;padding:12px}
table{width:100%;border-collapse:collapse}td{padding:6px 4px;border-bottom:1px solid var(--line);vertical-align:top}
tr{cursor:pointer}tr:hover{background:#2a2650}tr.sel{background:#332e60}
.tag{display:inline-block;border-radius:6px;padding:0 6px;font-size:12px;background:#3a3566}.new{background:#7a3b3b}.answered{background:#2f5b3a}
.muted{color:var(--muted)}pre{white-space:pre-wrap;word-break:break-word;margin:0}
img.shot{max-width:100%;max-height:420px;border-radius:8px;margin-top:8px}
.row{display:flex;gap:8px;flex-wrap:wrap;align-items:center;margin:6px 0}
@media (max-width:800px){main{grid-template-columns:1fr}}
</style></head><body>
<header><h1>아르카 운영</h1><span class="muted">문의 · 계정 보기 · 거래 기록</span><span id="who"></span><button id="login" class="ghost">Google 로그인</button></header>
<div id="msg" style="padding:8px 18px;color:var(--red)"></div>
<main id="app" style="display:none">
<section class="panel">
<div class="row"><select id="fkind"><option value="">종류 모두</option>
<option value="bug">오류</option><option value="record">기록·계정</option><option value="trade">거래</option><option value="party">파티·길드</option>
<option value="report">신고</option><option value="appeal">제재 이의 제기</option><option value="etc">기타</option></select>
<select id="fstatus"><option value="">상태 모두</option><option value="new">새 문의</option><option value="answered">답함</option></select>
<button id="reload" class="ghost">새로 보기</button></div>
<table><tbody id="list"></tbody></table>
</section>
<section class="panel" id="detail"><p class="muted">왼쪽에서 문의를 고르세요.</p></section>
<section class="panel" style="grid-column:1/-1"><h3>이름 금칙어</h3><p class="muted">「## … [전체]」 아래는 이름 전체가 그 말일 때만, 나머지는 이름 안에 들어 있으면 막아요. 저장하면 5분 안에 서버와 앱에 적용돼요.</p>
<textarea id="words" rows="12" style="width:100%"></textarea><div class="row"><button id="wsave">금칙어 저장</button><span id="winfo" class="muted"></span></div></section>
<section class="panel" style="grid-column:1/-1"><h3>거래 기록 (읽기 전용)</h3><p class="muted">계정 번호(uid)를 넣으면 그 계정이 사고판 기록과 올려 둔 물건이 보여요. 문의 「거래」에 답할 때 써요.</p>
<div class="row"><input id="tuid" placeholder="계정 uid" style="width:320px"><button id="tload">거래 보기</button><span id="tinfo" class="muted"></span></div>
<table><tbody id="tlist"></tbody></table></section>
</main>
<script src="https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/10.14.1/firebase-auth-compat.js"></script>
<script>
const CFG=${JSON.stringify(cfg)};
const READY=${ready ? 'true' : 'false'};
const KIND={bug:'오류',record:'기록·계정',trade:'거래',party:'파티·길드',report:'신고',appeal:'제재 이의 제기',etc:'기타'};
const $=(id)=>document.getElementById(id);
const esc=(s)=>String(s==null?'':s).replace(/[&<>"']/g,(c)=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
let token=null,items=[],cur=null;
async function api(path,body){const r=await fetch(path,{method:'POST',headers:{'Content-Type':'application/json',Authorization:'Bearer '+token},body:JSON.stringify(body||{})});const j=await r.json().catch(()=>({}));if(!r.ok)throw new Error(j.error||r.status);return j;}
function when(ms){return ms?new Date(ms).toLocaleString('ko-KR'):''}
async function load(){const j=await api('admin/list',{kind:$('fkind').value||undefined,status:$('fstatus').value||undefined});items=j.items;$('list').innerHTML=items.map((q)=>'<tr data-id="'+esc(q.id)+'"'+(cur&&cur.id===q.id?' class="sel"':'')+'><td><span class="tag '+esc(q.status)+'">'+(q.status==='new'?'새 문의':'답함')+'</span><br><span class="muted">'+esc(KIND[q.kind]||q.kind)+'</span></td><td>'+esc(String(q.text).slice(0,60))+'<br><span class="muted">'+when(q.at)+'</span></td></tr>').join('')||'<tr><td class="muted">문의가 없어요</td></tr>';for(const tr of document.querySelectorAll('#list tr[data-id]'))tr.onclick=()=>show(tr.dataset.id);}
async function show(id){cur=items.find((x)=>x.id===id);if(!cur)return;for(const tr of document.querySelectorAll('#list tr'))tr.classList.toggle('sel',tr.dataset.id===id);const q=cur;
$('detail').innerHTML='<div class="row"><b>'+esc(KIND[q.kind]||q.kind)+'</b><span class="tag '+esc(q.status)+'">'+(q.status==='new'?'새 문의':'답함')+'</span><span class="muted">'+when(q.at)+'</span></div>'+
'<pre>'+esc(q.text)+'</pre><div id="photo"></div>'+
'<p class="muted">계정 '+(q.uid?'<a href="#" id="acct">'+esc(q.uid.slice(0,8).toUpperCase())+'</a>':'(로그인 전)')+' · 설치 '+esc(String(q.install).slice(0,8).toUpperCase())+' · 앱 '+esc(q.appVersion)+' · '+esc(q.model)+(q.email?' · 답받을 이메일 '+esc(q.email):'')+'</p>'+
'<div id="acctbox"></div>'+
(q.reply?'<div class="panel"><b>보낸 답</b><pre>'+esc(q.reply)+'</pre></div>':'')+
'<h3>답 쓰기</h3><textarea id="body" rows="6" style="width:100%" placeholder="게임 안 우편 「문의에 답이 왔어요」로 가요"></textarea>'+
'<div class="row">보상 금화 <input id="rg" type="number" min="0" style="width:90px"> 마석 <input id="rm" type="number" min="0" style="width:80px"> 발자국 표 <input id="rf" type="number" min="0" style="width:80px"></div>'+
'<div class="row"><button id="send">답 보내기</button>'+(q.email?'<a id="mail" class="muted" href="#">이메일로 답(메일 앱)</a>':'')+'<span id="sent" class="muted"></span></div>';
if(q.hasPhoto){api('admin/photo',{id:q.id}).then((p)=>{if(p.data)$('photo').innerHTML='<img class="shot" src="data:image/jpeg;base64,'+p.data+'">';});}
if(q.uid)$('acct').onclick=async(e)=>{e.preventDefault();const a=await api('admin/account',{uid:q.uid});$('acctbox').innerHTML='<div class="panel"><b>계정 기록 (읽기 전용)</b><pre>'+esc(JSON.stringify(a,null,2))+'</pre></div>';$('tuid').value=q.uid;};
$('send').onclick=async()=>{const body=$('body').value.trim();if(!body)return;$('send').disabled=true;try{const r=await api('admin/reply',{id:q.id,body,reward:{gold:+$('rg').value||0,manaStone:+$('rm').value||0,footTicket:+$('rf').value||0}});$('sent').textContent='보냈어요';if(r.mailto&&$('mail'))$('mail').href=r.mailto;await load();}catch(e){$('sent').textContent='실패: '+e.message;}finally{$('send').disabled=false;}};
if($('mail'))$('mail').onclick=(e)=>{if($('mail').getAttribute('href')==='#'){e.preventDefault();const b=$('body').value.trim();location.href='mailto:'+encodeURIComponent(q.email)+'?subject='+encodeURIComponent('[아르카] 문의 답변')+'&body='+encodeURIComponent(b);}};}
$('reload').onclick=load;$('fkind').onchange=load;$('fstatus').onchange=load;
async function loadWords(){const w=await api('admin/words');$('words').value=w.text;$('winfo').textContent='부분 '+w.part+' · 전체 '+w.whole;}
$('wsave').onclick=async()=>{$('wsave').disabled=true;try{const r=await api('admin/words/save',{text:$('words').value});$('winfo').textContent='저장했어요 · 부분 '+r.part+' · 전체 '+r.whole;}catch(e){$('winfo').textContent='실패: '+e.message;}finally{$('wsave').disabled=false;}};
const MODE={fixed:'값 정함',auction:'경매'};
$('tload').onclick=async()=>{const uid=$('tuid').value.trim();if(!uid)return;$('tinfo').textContent='불러오는 중…';try{const r=await api('admin/trades',{uid});if(!r.found){$('tinfo').textContent='기록이 없어요';$('tlist').innerHTML='';return;}$('tinfo').textContent='거래 '+r.trades.length+' · 올려 둔 것 '+r.open.length;
$('tlist').innerHTML=r.trades.map((t)=>'<tr><td>'+when(t.at)+'</td><td>'+(t.side==='sell'?'판매':'구매')+' · '+esc(MODE[t.mode]||t.mode)+'</td><td>'+esc(t.name)+' ×'+esc(t.qty)+'</td><td>금화 '+esc(t.price)+' (수수료 '+esc(t.fee)+')</td><td class="muted">'+esc(String(t.side==='sell'?t.buyer:t.seller).slice(0,8).toUpperCase())+'</td></tr>').join('')+r.open.map((l)=>'<tr><td>'+when(l.at)+'</td><td>올려 둠 · '+esc(MODE[l.mode]||l.mode)+'</td><td>'+esc(l.name)+' ×'+esc(l.qty)+'</td><td>금화 '+esc(l.price||l.bid||l.start)+'</td><td class="muted">~'+when(l.endsAt)+'</td></tr>').join('')||'<tr><td class="muted">거래가 없어요</td></tr>';}catch(e){$('tinfo').textContent='실패: '+e.message;}};
if(!READY){$('msg').textContent='운영 페이지 설정(웹 앱)이 아직 없어요. 개발에 알려 주세요.';$('login').style.display='none';}
else{firebase.initializeApp(CFG);const auth=firebase.auth();
$('login').onclick=()=>auth.currentUser?auth.signOut():auth.signInWithPopup(new firebase.auth.GoogleAuthProvider());
auth.onAuthStateChanged(async(u)=>{$('login').textContent=u?'로그아웃':'Google 로그인';$('who').textContent=u?u.email:'';$('app').style.display='none';$('msg').textContent='';if(!u)return;token=await u.getIdToken();try{await api('admin/me');$('app').style.display='';await load();await loadWords();}catch(e){$('msg').textContent=e.message==='not_admin'?'운영자로 등록된 계정이 아니에요.':'불러오지 못했어요: '+e.message;}});}
</script></body></html>`;
}

module.exports = { adminPage };
