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
<header><h1>아르카 운영</h1><span class="muted">문의 · 계정 보기 · 거래 기록 · 제재 · 공지 · 의심 목록 · 대화 신고 · 공성전</span><span id="who"></span><button id="login" class="ghost">Google 로그인</button></header>
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
<section class="panel"><h3>제재</h3><p class="muted">운영정책 4단계. 그 사람 앱에 사유 · 기간 우편이 가고, 14일 안에 문의(제재 이의 제기)로 알릴 수 있어요. 제재 기록은 운영자만 봐요.</p>
<div class="row"><input id="suid" placeholder="계정 uid" style="width:260px"><button id="sload" class="ghost">기록 보기</button></div>
<div class="row"><select id="slevel"><option value="1">1 경고</option><option value="2">2 함께하는 기능 7일 제한</option><option value="3">3 로그인 정지 30일</option><option value="4">4 영구 정지</option></select>
<select id="sreason"><option value="steps">걸음 조작</option><option value="location">위치 조작</option><option value="tamper">앱 · 기록 변조</option><option value="bug">오류 악용</option><option value="cash">현금 거래</option><option value="boost">몰아주기</option><option value="scam">거래 사기</option><option value="name">부적절한 이름</option><option value="text">부적절한 글</option><option value="impersonate">운영자 사칭</option></select>
<input id="sdays" type="number" min="1" placeholder="기간(일, 2·3단계)" style="width:130px"></div>
<textarea id="smemo" rows="2" style="width:100%" placeholder="메모 (운영자만)"></textarea>
<div class="row"><button id="sapply">제재하기</button><input id="suntil" type="date"><button id="speriod" class="ghost">기간 바꾸기</button><button id="srelease" class="ghost">풀기</button><span id="sinfo" class="muted"></span></div>
<div id="shist"></div></section>
<section class="panel"><h3>이름 바꾸기</h3><p class="muted">부적절한 이름을 기본 이름으로 바꾸고 그 사람에게 우편으로 알려요. 파티 · 길드는 그 번호(id)를 넣어요.</p>
<div class="row"><select id="rtarget"><option value="awakened">각성자 이름</option><option value="pet">펫 이름</option><option value="ally">동료 이름</option><option value="party">파티 이름</option><option value="guild">길드 이름</option></select>
<input id="ruid" placeholder="계정 uid" style="width:220px"><input id="rid" placeholder="펫 · 동료 · 파티 · 길드 id (있으면)" style="width:220px"><button id="rgo">바꾸기</button><span id="rinfo" class="muted"></span></div></section>
<section class="panel"><h3>공지</h3><p class="muted">기간 동안 앱을 열면 홈 위 띠 + 공지 목록에 보여요.</p>
<input id="ntitle" placeholder="제목" style="width:100%"><textarea id="nbody" rows="3" style="width:100%" placeholder="내용"></textarea>
<div class="row">시작 <input id="nfrom" type="datetime-local"> 끝 <input id="nto" type="datetime-local"><button id="ngo">공지 올리기</button><span id="ninfo" class="muted"></span></div>
<table><tbody id="nlist"></tbody></table></section>
<section class="panel"><h3>모두에게 보상 우편</h3><p class="muted">점검 · 장애 보상. 기간 안에 앱을 연 사람이 한 번 받아요.</p>
<input id="btitle" placeholder="제목 (예: 점검 보상)" style="width:100%"><textarea id="bbody" rows="2" style="width:100%" placeholder="내용"></textarea>
<div class="row">금화 <input id="bg" type="number" min="0" style="width:90px"> 마석 <input id="bm" type="number" min="0" style="width:80px"> 발자국 표 <input id="bf" type="number" min="0" style="width:80px"> 모집권 <input id="br" type="number" min="0" style="width:70px"> 기간(일) <input id="bd" type="number" min="1" value="7" style="width:60px"><button id="bgo">보내기</button><span id="binfo" class="muted"></span></div></section>
<section class="panel" style="grid-column:1/-1"><h3>의심 목록</h3><p class="muted">다른 사람과 얽히는 곳(파티 · 길드 · 거래소 · 순위 · 공성전)에서만 모아요. 걸린 걸음 · 기여 · 위치는 그 기능에서 이미 세지 않아요. 자동 제재는 없어요 — 보고 판단해 「제재」에서 하세요 (위치 조작 · 변조는 처음이어도 3단계).</p><div class="row"><button id="xload" class="ghost">새로 보기</button><span id="xinfo" class="muted"></span></div><table><tbody id="xlist"></tbody></table></section>
<section class="panel" style="grid-column:1/-1" id="siegePanel"><h3>깃발 공성전</h3><p class="muted">이용자가 많아지면 열어요. 켜면 그다음 토요일 0시(한국)부터 2주마다 48시간, 끄면 다음 공성전부터 안 열려요(지금 하는 공성전은 끝까지). 꺼져 있으면 앱의 5막은 지도 · 영지 둘러보기까지만 보이고 공성권 · 수비대 · 전황판 · 영지 관리 · 주민 의뢰는 「곧 열려요」.</p><div class="row"><b id="sstate">-</b><button id="sopen" class="ghost">공성전 열기</button><button id="sclose" class="ghost">공성전 닫기</button></div><h4 style="margin:12px 0 4px">테스트 공성전</h4><p class="muted">적은 길드에게만 보여요(다른 사람은 그대로). 흑등 연맹은 움직이지 않고, 끝내면 그 길드들만 정리 · 보상해요.</p><div class="row"><input id="tcodes" placeholder="길드 초대 코드 (쉼표로 여러 개)" style="min-width:260px"><input id="thours" type="number" min="1" max="48" value="48" style="width:70px"><span class="muted">시간</span><button id="tstart" class="ghost">지금 시작</button><button id="tend" class="ghost">끝내기</button></div><div id="stinfo" class="muted"></div></section>
<section class="panel" style="grid-column:1/-1"><h3>대화 신고</h3><p class="muted">말풍선을 길게 눌러 신고한 줄과 앞뒤 10줄. 「대화 금지」 · 「경고」를 하면 그 사람 앱에 우편이 가요. 처리한 신고는 90일 뒤 지워져요.</p><div class="row"><button id="cload" class="ghost">새로 보기</button><span id="cinfo" class="muted"></span></div><div id="clist"></div></section>
<section class="panel" style="grid-column:1/-1"><h3>운영자 행동 기록</h3><div class="row"><button id="lload" class="ghost">새로 보기</button></div><table><tbody id="llist"></tbody></table></section>
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
const ACT={siegeOpen:'공성전 열기 · 닫기',siegeTest:'테스트 공성전',chatReport:'대화 신고 처리',sanction:'제재',period:'기간 바꿈',release:'제재 풀기',rename:'이름 바꾸기',revert:'거래 되돌리기',notice:'공지 올림',noticeDelete:'공지 내림',broadcast:'모두에게 우편',reply:'문의 답',words:'금칙어 저장'};
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
$('tlist').innerHTML=r.trades.map((t)=>'<tr><td>'+when(t.at)+'</td><td>'+(t.side==='sell'?'판매':'구매')+' · '+esc(MODE[t.mode]||t.mode)+'</td><td>'+esc(t.name)+' ×'+esc(t.qty)+'</td><td>금화 '+esc(t.price)+' (수수료 '+esc(t.fee)+')</td><td class="muted">'+esc(String(t.side==='sell'?t.buyer:t.seller).slice(0,8).toUpperCase())+'</td><td>'+(t.reverted?'<span class="muted">되돌림</span>':'<button class="ghost rv" data-id="'+esc(t.id)+'">되돌리기</button>')+'</td></tr>').join('')+r.open.map((l)=>'<tr><td>'+when(l.at)+'</td><td>올려 둠 · '+esc(MODE[l.mode]||l.mode)+'</td><td>'+esc(l.name)+' ×'+esc(l.qty)+'</td><td>금화 '+esc(l.price||l.bid||l.start)+'</td><td class="muted">~'+when(l.endsAt)+'</td></tr>').join('')||'<tr><td class="muted">거래가 없어요</td></tr>';}catch(e){$('tinfo').textContent='실패: '+e.message;}};
document.addEventListener('click',async(e)=>{const b=e.target.closest('.rv');if(!b)return;if(!confirm('이 거래를 되돌릴까요? 양쪽에 우편이 가요.'))return;b.disabled=true;try{await api('admin/revert',{logId:b.dataset.id});b.outerHTML='<span class="muted">되돌림</span>';}catch(x){alert('실패: '+x.message);b.disabled=false;}});
const LV={0:'없음',1:'경고',2:'함께하는 기능 제한',3:'로그인 정지',4:'영구 정지'};
async function loadSanctions(){const uid=$('suid').value.trim();if(!uid)return;const r=await api('admin/sanctions',{uid});$('sinfo').textContent='지금: '+(r.status?LV[r.status.level]+(r.status.until?' ~'+r.status.until.slice(0,10):''):'없음');$('shist').innerHTML='<table><tbody>'+r.history.map((h)=>'<tr><td>'+when(h.at)+'</td><td>'+esc(ACT[h.action]||h.action)+'</td><td>'+esc(LV[h.level]||h.level)+'</td><td>'+esc((r.reasons||{})[h.reason]||h.reason||'')+'</td><td class="muted">'+esc(h.memo||'')+' · '+esc(h.by||'')+'</td></tr>').join('')+'</tbody></table>';}
$('sload').onclick=()=>loadSanctions().catch((e)=>$('sinfo').textContent='실패: '+e.message);
$('sapply').onclick=async()=>{const uid=$('suid').value.trim();if(!uid||!confirm('제재할까요?'))return;try{await api('admin/sanction',{uid,level:+$('slevel').value,reason:$('sreason').value,memo:$('smemo').value,days:$('sdays').value?+$('sdays').value:undefined});await loadSanctions();}catch(e){$('sinfo').textContent='실패: '+e.message;}};
$('speriod').onclick=async()=>{const uid=$('suid').value.trim();if(!uid||!$('suntil').value)return;try{await api('admin/unsanction',{uid,until:$('suntil').value+'T00:00:00+09:00'});await loadSanctions();}catch(e){$('sinfo').textContent='실패: '+e.message;}};
$('srelease').onclick=async()=>{const uid=$('suid').value.trim();if(!uid||!confirm('풀까요?'))return;try{await api('admin/unsanction',{uid,memo:$('smemo').value});await loadSanctions();}catch(e){$('sinfo').textContent='실패: '+e.message;}};
$('rgo').onclick=async()=>{const t=$('rtarget').value;if(!confirm('이름을 기본 이름으로 바꿀까요?'))return;try{await api('admin/rename',{target:t,uid:$('ruid').value.trim()||undefined,id:$('rid').value.trim()||undefined});$('rinfo').textContent='바꿨어요';}catch(e){$('rinfo').textContent='실패: '+e.message;}};
async function loadNotices(){const r=await api('admin/notices');$('nlist').innerHTML=r.items.map((n)=>'<tr><td>'+esc(n.title)+'</td><td class="muted">'+when(n.from)+' ~ '+when(n.to)+'</td><td><button class="ghost nd" data-id="'+esc(n.id)+'">내리기</button></td></tr>').join('')||'<tr><td class="muted">공지가 없어요</td></tr>';for(const b of document.querySelectorAll('.nd'))b.onclick=async()=>{await api('admin/notice/delete',{id:b.dataset.id});await loadNotices();};}
$('ngo').onclick=async()=>{try{await api('admin/notice',{title:$('ntitle').value,body:$('nbody').value,from:$('nfrom').value?Date.parse($('nfrom').value):undefined,to:$('nto').value?Date.parse($('nto').value):undefined});$('ninfo').textContent='올렸어요';await loadNotices();}catch(e){$('ninfo').textContent='실패: '+e.message;}};
$('bgo').onclick=async()=>{if(!confirm('모두에게 보낼까요?'))return;try{await api('admin/broadcast',{title:$('btitle').value,body:$('bbody').value,days:+$('bd').value||7,reward:{gold:+$('bg').value||0,manaStone:+$('bm').value||0,footTicket:+$('bf').value||0,recruit:+$('br').value||0}});$('binfo').textContent='보냈어요';}catch(e){$('binfo').textContent='실패: '+e.message;}};
async function loadLog(){const r=await api('admin/log');$('llist').innerHTML=r.items.map((l)=>'<tr><td>'+when(l.at)+'</td><td>'+esc(l.by)+'</td><td>'+esc(ACT[l.action]||l.action)+'</td><td class="muted">'+esc(String(l.target||'').slice(0,12))+' '+esc(JSON.stringify(l.detail||{}))+'</td></tr>').join('')||'<tr><td class="muted">기록이 없어요</td></tr>';}
$('lload').onclick=loadLog;
async function loadSus(){const r=await api('admin/suspects');const ac=r.appCheck||[];const t=ac.reduce((a,x)=>({ok:a.ok+x.ok,bad:a.bad+x.bad,missing:a.missing+x.missing}),{ok:0,bad:0,missing:0});const all=t.ok+t.bad+t.missing;$('xinfo').textContent='진짜 앱 확인 (최근 14일): '+(all?Math.round(t.ok*100/all)+'% 통과 · 실패 '+t.bad+' · 없음 '+t.missing:'아직 없음');$('xlist').innerHTML=r.items.map((x)=>'<tr><td><a href="#" class="xu" style="color:#e8c46a" data-uid="'+esc(x.uid)+'">'+esc(String(x.uid).slice(0,10))+'</a></td><td>'+Object.entries(x.counts).map(([k,n])=>esc((r.kinds||{})[k]||k)+' '+n+'번').join('<br>')+'</td><td class="muted">'+Object.entries(x.last).map(([k,at])=>esc((r.kinds||{})[k]||k)+' '+when(at)).join('<br>')+'</td><td class="muted">'+x.days.map((d)=>esc(d.day.slice(5))+' '+d.steps.toLocaleString()+'보 (한 시간 최대 '+d.maxHour.toLocaleString()+(d.manual?' · 손 입력 '+d.manual.toLocaleString():'')+')').join('<br>')+'</td></tr>').join('')||'<tr><td class="muted">걸린 계정이 없어요</td></tr>';for(const a of document.querySelectorAll('.xu'))a.onclick=(e)=>{e.preventDefault();$('suid').value=a.dataset.uid;$('tuid').value=a.dataset.uid;loadSanctions();};}
$('xload').onclick=loadSus;
const CACT={mute1:'대화 금지 1일',mute7:'대화 금지 7일',mutePerm:'대화 금지 영구',warn:'경고',none:'문제없음'};
async function loadChat(){const r=await api('admin/chat/reports',{status:'open'});$('cinfo').textContent='처리 안 한 신고 '+r.items.length;$('clist').innerHTML=r.items.map((x)=>'<div class="panel" style="margin:8px 0"><div class="row"><b>'+esc((r.reasons||{})[x.reason]||x.reason)+'</b><span class="muted">'+when(x.at)+' · 방 '+esc(x.room==='server'?'세계':x.room)+' · 신고한 사람 '+esc(String(x.reporter).slice(0,8))+' · 대상 '+esc(String(x.target).slice(0,10))+'</span></div><table><tbody>'+(x.context||[]).map((l)=>'<tr'+(l.target?' class="sel"':'')+'><td class="muted">'+when(l.at)+'</td><td>'+esc(l.kind==='sys'?'(소식)':l.name)+'</td><td>'+esc(l.text)+'</td></tr>').join('')+'</tbody></table><div class="row">'+Object.entries(CACT).map(([k,v])=>'<button class="ghost cact" data-id="'+esc(x.id)+'" data-a="'+k+'">'+v+'</button>').join('')+'</div></div>').join('')||'<p class="muted">신고가 없어요</p>';for(const b of document.querySelectorAll('.cact'))b.onclick=async()=>{if(!confirm(CACT[b.dataset.a]+'(으)로 처리할까요?'))return;try{await api('admin/chat/resolve',{id:b.dataset.id,action:b.dataset.a});await loadChat();}catch(e){alert('실패: '+e.message);}};}
function showSiege(r){if(r.error){$('stinfo').textContent='실패: '+({no_guild:'그 코드의 길드가 없어요',siege_now:'정기 공성전 중이에요',test_now:'테스트 공성전이 이미 진행 중이에요'}[r.error]||r.error);return;}$('sstate').textContent=r.open?'열림'+(r.next?' · 다음 공성전 '+when(r.next.start)+(r.active?' (지금 진행 중)':''):''):(r.next?'닫는 중 · 마지막 공성전 '+when(r.next.start):'닫힘');$('sopen').disabled=!!r.open;$('sclose').disabled=!r.open;$('stinfo').textContent=r.test?'테스트 공성전 진행 중 · '+when(r.test.end)+'까지 · '+(r.guilds||[]).join(', '):'테스트 공성전 없음';}
async function loadSiege(){showSiege(await api('admin/siege/schedule'));}
$('sopen').onclick=async()=>{if(!confirm('깃발 공성전을 열까요? 그다음 토요일 0시부터 2주마다 열려요.'))return;showSiege(await api('admin/siege/open',{open:true}));};
$('sclose').onclick=async()=>{if(!confirm('깃발 공성전을 닫을까요? 다음 공성전부터 안 열려요.'))return;showSiege(await api('admin/siege/open',{open:false}));};
$('tstart').onclick=async()=>{const codes=$('tcodes').value.trim();if(!codes){$('stinfo').textContent='길드 초대 코드를 적어 주세요';return;}if(!confirm('테스트 공성전을 지금 시작할까요?'))return;showSiege(await api('admin/siege/test',{action:'start',codes,hours:Number($('thours').value)||48}));};
$('tend').onclick=async()=>{if(!confirm('테스트 공성전을 끝내고 정리할까요?'))return;showSiege(await api('admin/siege/test',{action:'end'}));};
$('cload').onclick=()=>loadChat().catch((e)=>$('cinfo').textContent='실패: '+e.message);
if(!READY){$('msg').textContent='운영 페이지 설정(웹 앱)이 아직 없어요. 개발에 알려 주세요.';$('login').style.display='none';}
else{firebase.initializeApp(CFG);const auth=firebase.auth();
$('login').onclick=()=>auth.currentUser?auth.signOut():auth.signInWithPopup(new firebase.auth.GoogleAuthProvider());
auth.onAuthStateChanged(async(u)=>{$('login').textContent=u?'로그아웃':'Google 로그인';$('who').textContent=u?u.email:'';$('app').style.display='none';$('msg').textContent='';if(!u)return;token=await u.getIdToken();try{await api('admin/me');$('app').style.display='';await load();await loadWords();await loadNotices();await loadLog();await loadSus();await loadChat();await loadSiege();}catch(e){$('msg').textContent=e.message==='not_admin'?'운영자로 등록된 계정이 아니에요.':'불러오지 못했어요: '+e.message;}});}
</script></body></html>`;
}

module.exports = { adminPage };
