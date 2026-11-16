/* NEP v65.1 — actual Supabase driver account management. Passwords never enter app_states/localStorage. */
(function(){
'use strict';
const el=id=>document.getElementById(id);
const isAdmin=()=>typeof me!=='undefined'&&me?.role==='admin';
const make=(tag,cls,text)=>{const n=document.createElement(tag);if(cls)n.className=cls;if(text!=null)n.textContent=String(text);return n;};
let flash='',selectedLogin='';
const oldRender=window.renderUsers, oldTab=window.tab;
async function request(body){
  if(!isAdmin())throw Error('관리자 로그인이 필요합니다.');
  const {data,error}=await nepSupa.auth.getSession();
  if(error||!data?.session?.access_token)throw Error('로그인 세션이 만료되었습니다. 다시 로그인해주세요.');
  const controller=new AbortController(),timer=setTimeout(()=>controller.abort(),45000);
  try{
    const r=await fetch(NEP_SUPABASE_URL+'/functions/v1/nep-account-admin',{method:'POST',headers:{Authorization:'Bearer '+data.session.access_token,apikey:NEP_SUPABASE_PUBLISHABLE_KEY,'Content-Type':'application/json'},body:JSON.stringify(body),cache:'no-store',credentials:'omit',signal:controller.signal});
    let result;try{result=await r.json()}catch{throw Error('계정관리 서버 응답을 확인할 수 없습니다. 목록을 새로고침해주세요.');}
    if(!r.ok)throw Error(typeof result.error==='string'?result.error:r.status===401?'다시 로그인해주세요.':'계정관리 요청에 실패했습니다.');
    return result;
  }catch(e){
    if(e.name==='AbortError')throw Error('응답 시간이 초과되었습니다. 변경 여부를 목록과 이력에서 확인한 후 다시 시도해주세요.');
    throw e;
  }finally{clearTimeout(timer);}
}
const validPassword=p=>typeof p==='string'&&p.length>=12&&new TextEncoder().encode(p).length<=72&&/[A-Za-z]/.test(p)&&/[0-9]/.test(p)&&/[^A-Za-z0-9\s]/.test(p);
function updateLegacyButtons(){
  document.querySelectorAll('#users .driverAccountCard button[onclick]').forEach(b=>{
    const m=(b.getAttribute('onclick')||'').match(/^(toggleUser|deleteUser)\((\d+)\)$/);
    if(!m)return;
    const u=db.users[Number(m[2])];if(u?.role!=='driver')return;
    if(m[1]==='deleteUser'){b.remove();return;}
    b.removeAttribute('onclick');b.className='smallbtn ghost';b.textContent='로그인 관리';
    b.addEventListener('click',()=>{selectedLogin=String(u.id);const card=el('nepActualAccounts');if(card){card.scrollIntoView({behavior:'smooth',block:'start'});card.nepFocusAccount?.(selectedLogin);}});
  });
}
function buildPanel(host){
  const panel=make('section','card');panel.id='nepActualAccounts';
  panel.innerHTML=`<div class="nepAcctHeader"><div><h3>기사 로그인 계정 관리</h3><div class="muted">실제 서버 계정 · 관리자 전용</div></div><button type="button" class="ghost smallbtn" data-nep="refresh">새로고침</button></div>
  <div class="nepAcctHint">기사 계정의 비밀번호 변경, 신규 발급, 로그인 차단을 여기서 처리합니다. 급여·퇴사 이력과 수거코스는 기존 직원관리에서 별도로 관리하세요.</div>
  <div class="nepAcctToolbar"><label class="nepAcctCheck"><input type="checkbox" data-nep="all"> 사용 중인 기사 전체 선택</label><button type="button" class="ghost smallbtn" data-nep="new">+ 신규 기사 계정</button></div>
  <div data-nep="accounts" aria-live="polite" class="nepAcctRows">계정 목록을 확인하려면 새로고침을 누르세요.</div>
  <form class="nepAcctForm" autocomplete="off" novalidate>
    <h4 data-nep="formTitle">선택한 기사 비밀번호 재설정</h4>
    <p class="muted" data-nep="target">선택한 기사에게 같은 새 비밀번호를 설정합니다.</p>
    <div data-nep="newFields" hidden class="nepAcctFields"><label>기사 아이디<input data-nep="login" autocomplete="off" placeholder="예: driver3" maxlength="11"></label><label>기사 이름<input data-nep="name" autocomplete="off" maxlength="80" placeholder="이름"></label></div>
    <div data-nep="passwordFields" class="nepAcctFields">
      <label>새 비밀번호<input data-nep="pw" type="password" autocomplete="new-password" maxlength="72" placeholder="영문·숫자·특수문자 포함 12자 이상"></label>
      <label>새 비밀번호 확인<input data-nep="pw2" type="password" autocomplete="new-password" maxlength="72" placeholder="다시 입력"></label>
    </div>
    <label class="nepAcctAdminPw">현재 관리자 비밀번호<input data-nep="adminPw" type="password" autocomplete="current-password" maxlength="256" placeholder="본인 확인용 · 서버에 저장하지 않음"></label>
    <div class="nepAcctActions"><button type="submit" class="primary" data-nep="submit">비밀번호 재설정</button><button type="button" class="ghost" data-nep="cancel" hidden>취소</button></div>
  </form>
  <p data-nep="message" role="status" class="nepAcctMessage" aria-live="polite"></p>
  <details class="nepAcctHistory"><summary>최근 계정관리 이력</summary><div data-nep="history" class="nepAcctRows">계정 목록을 조회하면 변경 이력이 표시됩니다.</div></details>
  <p class="muted" style="font-size:12px;margin:10px 0 0">관리자·고객 계정 발급은 Supabase에서 별도 관리합니다. 관리자 비밀번호와 기사 비밀번호는 서로 다르게 설정해주세요.</p>`;
  const old=el('uid')?.closest('.card');if(old&&host.contains(old))old.replaceWith(panel);else host.prepend(panel);
  const q=k=>panel.querySelector('[data-nep="'+k+'"]');
  let accounts=[],chosen=new Set(),mode='reset',target=null,busy=false,loaded=false;
  const form=panel.querySelector('form');
  function message(text,bad=false){if(!panel.isConnected)return;q('message').textContent=text||'';q('message').classList.toggle('nepAcctError',bad);}
  function clearPasswords(){q('pw').value='';q('pw2').value='';q('adminPw').value='';}
  function setBusy(on){busy=on;panel.querySelectorAll('button,input').forEach(n=>{n.disabled=on;});if(!on){panel.querySelectorAll('[data-inactive="1"]').forEach(n=>n.disabled=true);}}
  function updateSelect(){
    const active=accounts.filter(a=>a.active);
    q('all').checked=active.length>0&&active.every(a=>chosen.has(a.profile_id));
    q('all').indeterminate=active.some(a=>chosen.has(a.profile_id))&&!q('all').checked;
    if(mode==='reset')q('target').textContent=chosen.size?chosen.size+'명 선택 · 동일한 새 비밀번호 설정':'먼저 비밀번호를 변경할 기사 계정을 선택하세요.';
  }
  function setMode(next,a=null,focus=false){
    mode=next;target=a;clearPasswords();q('newFields').hidden=mode!=='create';q('passwordFields').hidden=mode==='status';q('cancel').hidden=mode==='reset';
    q('formTitle').textContent=mode==='create'?'신규 기사 로그인 계정 발급':mode==='status'?(a?.active?'기사 로그인 차단':'기사 로그인 허용'):'선택한 기사 비밀번호 재설정';
    q('submit').textContent=mode==='create'?'신규 계정 등록':mode==='status'?(a?.active?'로그인 차단':'로그인 허용'):'비밀번호 재설정';
    if(mode==='create'){q('login').value='';q('name').value='';q('target').textContent='실제 기사 계정과 직원 DB 정보를 연결합니다.';}
    else if(mode==='status')q('target').textContent=a.name+' ('+a.login_id+') · '+(a.active?'차단하면 업무 앱 접근이 제한됩니다. 기존 수거기록과 코스는 삭제하지 않습니다.':'로그인 접근을 다시 허용합니다.');
    else updateSelect();
    if(focus)form.scrollIntoView({behavior:'smooth',block:'nearest'});
  }
  function draw(){
    const rows=q('accounts');rows.replaceChildren();
    if(!accounts.length){rows.append(make('div','muted','실제 등록된 기사 로그인 계정이 없습니다.'));updateSelect();return;}
    for(const a of accounts){
      const row=make('div','nepAcctRow');
      const input=make('input');input.type='checkbox';input.checked=chosen.has(a.profile_id);input.disabled=!a.active||busy;if(!a.active)input.dataset.inactive='1';input.setAttribute('aria-label',a.name+' 선택');
      input.addEventListener('change',()=>{input.checked?chosen.add(a.profile_id):chosen.delete(a.profile_id);if(mode!=='reset')setMode('reset');updateSelect();});
      const info=make('div','nepAcctInfo');info.append(make('b','',a.name),make('span','muted',a.login_id));
      const status=make('span',a.active?'pill ok':'pill bad',a.active?'로그인 허용':'로그인 차단');
      const action=make('button','smallbtn ghost',a.active?'차단':'허용');action.type='button';action.disabled=busy;action.addEventListener('click',()=>setMode('status',a,true));
      row.append(input,info,status,action);rows.append(row);
    }
    updateSelect();
  }
  function drawHistory(history,available){
    const box=q('history');box.replaceChildren();
    if(!available){box.append(make('p','muted','변경 이력을 조회하지 못했습니다.'));return;}
    if(!history?.length){box.append(make('p','muted','아직 기록된 계정관리 변경이 없습니다.'));return;}
    const names={'nep.driver.password_reset':'비밀번호 변경','nep.driver.login_status':'로그인 상태 변경','nep.driver.account_create':'계정 발급'};
    for(const h of history){const row=make('div','nepAcctLog');const details=h.after_data||{};row.append(make('b','',String(details.login_id||'기사')+' · '+(names[h.action]||'계정 변경')),make('span','muted',new Date(h.created_at).toLocaleString('ko-KR',{timeZone:'Asia/Seoul'})+(typeof details.active==='boolean'?' · '+(details.active?'허용':'차단'):'')));box.append(row);}
  }
  function mergeNewDrivers(){
    if(!Array.isArray(db.users))return false;
    let changed=false;
    for(const a of accounts){if(!db.users.some(u=>u.id===a.login_id)){db.users.push({id:a.login_id,name:a.name,role:'driver',active:a.driver_active!==false,monthlySalary:0,allowance:0,vehicleName:'',workStart:'',workEnd:'',workEvents:[],salaryHistory:[]});changed=true;}}
    return changed;
  }
  async function refresh(keepMessage=false){
    if(busy||!isAdmin()||!panel.isConnected)return;
    setBusy(true);if(!keepMessage)message('실제 계정 조회 중…');
    try{
      const data=await request({action:'list'});if(!panel.isConnected||!isAdmin())return;
      accounts=Array.isArray(data.accounts)?data.accounts:[];loaded=true;
      chosen=new Set([...chosen].filter(id=>accounts.some(a=>a.profile_id===id&&a.active)));
      if(selectedLogin){const a=accounts.find(x=>x.login_id===selectedLogin);selectedLogin='';if(a){if(a.active){chosen=new Set([a.profile_id]);setMode('reset');}else setMode('status',a);}}
      draw();drawHistory(data.history,data.history_available);
      if(mergeNewDrivers()){try{renderAssign();renderDash();}catch{}}
      if(!keepMessage)message(flash||'실제 기사 계정 '+accounts.length+'명 조회 완료');
      flash='';
    }catch(e){message(e.message||'계정 조회 실패',true);}
    finally{setBusy(false);if(panel.isConnected)draw();}
  }
  panel.nepRefresh=()=>refresh();
  panel.nepFocusAccount=login=>{selectedLogin=login;if(!loaded){refresh();return;}const a=accounts.find(x=>x.login_id===login);if(a){selectedLogin='';if(a.active){chosen=new Set([a.profile_id]);setMode('reset',null,true);}else setMode('status',a,true);draw();}else refresh();};
  q('refresh').addEventListener('click',()=>refresh());
  q('all').addEventListener('change',()=>{chosen=new Set(q('all').checked?accounts.filter(a=>a.active).map(a=>a.profile_id):[]);setMode('reset');draw();});
  q('new').addEventListener('click',()=>setMode('create',null,true));
  q('cancel').addEventListener('click',()=>setMode('reset'));
  form.addEventListener('submit',async e=>{
    e.preventDefault();if(busy||!isAdmin())return;
    let body={action:mode,admin_password:q('adminPw').value};
    const secret=q('pw').value;
    if(!body.admin_password){message('현재 관리자 비밀번호를 입력해주세요.',true);q('adminPw').focus();return;}
    if(mode!=='status'){
      if(!validPassword(secret)){message('새 비밀번호는 영문·숫자·특수문자를 포함해 12자 이상으로 입력해주세요.',true);return;}
      if(secret!==q('pw2').value){message('새 비밀번호 확인이 일치하지 않습니다.',true);return;}
      if(secret===body.admin_password){message('관리자 비밀번호와 다르게 설정해주세요.',true);return;}
      body.password=secret;
    }
    let confirmation='';
    if(mode==='reset'){
      body.profile_ids=[...chosen];if(!body.profile_ids.length){message('기사 계정을 먼저 선택해주세요.',true);return;}
      confirmation=accounts.filter(a=>chosen.has(a.profile_id)).map(a=>a.login_id).join(', ')+'의 실제 비밀번호를 변경할까요?';
    }else if(mode==='create'){
      body.login_id=q('login').value.trim().toLowerCase();body.name=q('name').value.trim();
      if(!/^driver[1-9][0-9]{0,4}$/.test(body.login_id)||!body.name){message('driver3과 같은 아이디와 이름을 입력해주세요.',true);return;}
      if(db.users.some(u=>u.id===body.login_id&&u.role!=='driver')){message('이미 다른 역할에서 사용 중인 아이디입니다.',true);return;}
      confirmation=body.login_id+' 실제 기사 계정을 발급할까요?';
    }else{
      if(!target)return;body.profile_ids=[target.profile_id];body.active=!target.active;
      confirmation=target.login_id+'의 로그인 '+(body.active?'허용':'차단')+'을 적용할까요? 기존 업무 기록은 유지됩니다.';
    }
    if(!confirm(confirmation))return;
    const action=mode;clearPasswords();setBusy(true);message('인증 서버에 변경 요청 중…');
    try{
      const result=await request(body);const rows=Array.isArray(result.results)?result.results:[];
      const good=rows.filter(x=>x.ok),bad=rows.filter(x=>!x.ok),auditFailed=good.filter(x=>x.audit===false);
      if(!rows.length)throw Error('변경 결과를 확인하지 못했습니다. 목록을 새로고침해주세요.');
      const summary='성공 '+good.length+'명'+(good.length?' ('+good.map(x=>x.login_id).join(', ')+')':'')+(bad.length?' · 실패 '+bad.map(x=>x.login_id+': '+(x.error||'확인 필요')).join(' / '):'')+(auditFailed.length?' · 일부 변경 이력 저장 실패':'');
      message(summary,!!bad.length||!!auditFailed.length);
      setMode('reset');chosen.clear();
      if(action==='create'&&good.length){
        flash=summary+' · 신규 기사 계정이 등록되었습니다.';
        setBusy(false);window.renderUsers();return;
      }
      setBusy(false);await refresh(true);
    }catch(e){message(e.message||'계정 변경 실패',true);}
    finally{body.admin_password='';if(body.password)body.password='';clearPasswords();setBusy(false);}
  });
  if(flash)message(flash);
  if(!host.classList.contains('hidden'))refresh();
  updateLegacyButtons();
  return panel;
}
window.renderUsers=function(){
  const result=oldRender.apply(this,arguments);
  if(isAdmin()){const host=el('users');if(host)buildPanel(host);}
  return result;
};
window.tab=function(id,btn){
  const result=oldTab.apply(this,arguments);
  if(id==='users'&&isAdmin()){const p=el('nepActualAccounts');if(p)p.nepRefresh?.();}
  return result;
};
})();
