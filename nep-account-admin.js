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

// Login credentials are edited inside the original account info modal, never in the local app state.
const oldEdit=window.openAccountEditModal,oldSave=window.saveAccountEdit;
let editToken=0;
const accountCache=new Map();
async function loadAccounts(){const data=await request({action:'list'});accountCache.clear();for(const a of data.accounts||[])accountCache.set(String(a.driver_key||a.login_id),a);return data.accounts||[];}
function input(labelText,id,type='text',value=''){
 const w=make('div');const l=make('label','',labelText);l.htmlFor=id;const n=make('input');n.id=id;n.type=type;n.value=value;n.autocomplete=type==='password'?'new-password':'off';w.append(l,n);return [w,n];
}
function showResult(node,message,bad=false){if(!node?.isConnected)return;node.textContent=message;node.style.color=bad?'#b42318':'#17643d';}
function loginFor(x){return accountCache.get(String(x.id))?.login_id||x.id;}
function refreshLabels(){
 if(!isAdmin())return;
 document.querySelectorAll('#users .driverAccountCard').forEach(card=>{
  const b=card.querySelector('button[onclick^="openAccountEditModal("]');const m=(b?.getAttribute('onclick')||'').match(/\((\d+)\)/);const x=m?db.users[Number(m[1])]:null;if(x?.role!=='driver')return;
  const a=accountCache.get(String(x.id));const meta=card.querySelector('.driverAccountMeta');
  if(meta&&a)meta.textContent='아이디 '+a.login_id;
  if(a){const status=card.querySelector('.nepLoginStatus');if(status)status.textContent=a.active?'로그인 허용':'로그인 차단';}
 });
}
window.renderUsers=function(){
 const result=oldRender.apply(this,arguments);if(!isAdmin())return result;
 const host=el('users');if(!host)return result;
 // The original account list remains the central screen. Keep account creation compact.
 const add=el('uid')?.closest('.card');
 if(add){
  add.innerHTML='<div class="accountCleanTop"><h3>계정 추가</h3><span class="muted">신규 기사 로그인 계정</span></div><button class="primary" type="button" id="nepCreateDriver">+ 기사 계정 추가</button>';
  el('nepCreateDriver').addEventListener('click',openCreate);
 }
 document.querySelectorAll('#users .driverAccountCard button[onclick]').forEach(b=>{
  const m=(b.getAttribute('onclick')||'').match(/^(toggleUser|deleteUser)\((\d+)\)$/);if(!m)return;
  const x=db.users[Number(m[2])];if(x?.role!=='driver')return;
  if(m[1]==='deleteUser'){b.remove();return;}
  b.removeAttribute('onclick');b.className='smallbtn ghost';b.textContent='로그인 상태';b.addEventListener('click',()=>openStatus(String(x.id)));
  const card=b.closest('.driverAccountCard'),meta=card?.querySelector('.driverAccountMeta');
  if(meta){const span=make('span','pill nepLoginStatus','로그인 상태 조회 전');span.style.marginLeft='6px';meta.parentElement?.append(span);}
 });
 refreshLabels();
 if(!host.classList.contains('hidden'))loadAccounts().then(refreshLabels).catch(()=>{});
 return result;
};
window.tab=function(id,btn){const result=oldTab.apply(this,arguments);if(id==='users'&&isAdmin())loadAccounts().then(refreshLabels).catch(()=>{});return result;};
window.openAccountEditModal=function(i){
 if(!isAdmin()||db.users[i]?.role!=='driver')return oldEdit.apply(this,arguments);
 const x=db.users[i],key=String(x.id),token=++editToken;
 oldEdit.call(this,i);
 const name=el('editName'+i),pw=el('editPw'+i),modal=el('accountModalInner'),grid=modal?.querySelector('.accountModalGrid');
 if(!name||!pw||!grid)return;
 const idInput=grid.querySelector('input[disabled]');
 if(!idInput)return;
 idInput.id='nepEditLogin'+i;idInput.value=loginFor(x);idInput.disabled=true;idInput.autocomplete='off';idInput.maxLength=32;
 pw.disabled=true;pw.type='password';pw.value='';pw.autocomplete='new-password';pw.placeholder='변경할 때만 입력 (12자 이상)';pw.maxLength=72;
 const p=modal.querySelector('.accountModalHead p');if(p)p.textContent='아이디와 비밀번호를 이곳에서 변경할 수 있습니다. 비밀번호를 비워두면 기존 비밀번호를 유지합니다.';
 const [confirmWrap,confirmInput]=input('새 비밀번호 확인','nepEditConfirm'+i,'password');confirmInput.placeholder='새 비밀번호 다시 입력';confirmInput.maxLength=72;pw.parentElement.after(confirmWrap);
 const [adminWrap,adminInput]=input('현재 관리자 비밀번호','nepEditAdmin'+i,'password');adminInput.autocomplete='current-password';adminInput.placeholder='로그인 정보 변경 시 본인 확인';adminWrap.className='wide';grid.append(adminWrap);
 const msg=make('p','wide','실제 로그인 계정 확인 중…');msg.id='nepEditMessage'+i;msg.setAttribute('role','status');msg.style.margin='8px 0';grid.append(msg);
 const saveBtn=modal.querySelector('button[onclick="saveAccountEdit('+i+')"]');
 if(saveBtn)saveBtn.disabled=true;
 loadAccounts().then(()=>{
  if(token!==editToken||!idInput.isConnected||!isAdmin())return;
  const a=accountCache.get(key);
  if(!a){showResult(msg,'실제 로그인 계정이 연결되어 있지 않습니다.',true);return;}
  idInput.value=a.login_id;idInput.disabled=false;pw.disabled=false;
  idInput.dataset.profileId=a.profile_id;idInput.dataset.originalLogin=a.login_id;idInput.dataset.driverKey=key;
  if(saveBtn)saveBtn.disabled=false;
  showResult(msg,'로그인 아이디를 변경해도 기존 수거코스와 기록은 유지됩니다.');
 }).catch(e=>showResult(msg,e.message||'계정 조회 실패',true));
};
window.saveAccountEdit=async function(i){
 const x=db.users[i];if(x?.role!=='driver')return oldSave.apply(this,arguments);
 if(!isAdmin())return;
 const login=el('nepEditLogin'+i),pw=el('editPw'+i),pw2=el('nepEditConfirm'+i),adminPw=el('nepEditAdmin'+i),name=el('editName'+i),msg=el('nepEditMessage'+i);
 if(!login||!login.dataset.profileId||login.dataset.driverKey!==String(x.id))return;
 const modal=el('accountModalInner'),button=modal?.querySelector('button[onclick="saveAccountEdit('+i+')"]');
 if(!button||button.disabled)return;
 const nextLogin=login.value.trim().toLowerCase(),nextName=name?.value.trim(),secret=pw?.value||'',current=adminPw?.value||'';
 if(!/^[a-z][a-z0-9._-]{2,31}$/.test(nextLogin)||['admin','administrator','root','nepkoreateam'].includes(nextLogin)||/^cust[0-9]+$/.test(nextLogin))return showResult(msg,'아이디는 영문 시작, 영문·숫자·점·밑줄·하이픈 3~32자로 입력하세요.',true);
 if(!nextName||nextName.length>80)return showResult(msg,'이름을 80자 이내로 입력하세요.',true);
 if(secret&&(!validPassword(secret)||secret!==pw2.value))return showResult(msg,'새 비밀번호는 영문·숫자·특수문자 포함 12자 이상이며 확인 값이 일치해야 합니다.',true);
 if(!secret&&pw2.value)return showResult(msg,'새 비밀번호를 입력하세요.',true);
 const account=accountCache.get(String(x.id));if(!account||account.profile_id!==login.dataset.profileId)return showResult(msg,'계정 정보를 다시 불러와주세요.',true);
 const authChange=nextLogin!==login.dataset.originalLogin||!!secret||nextName!==account.name;
 if(authChange&&!current)return showResult(msg,'현재 관리자 비밀번호를 입력해주세요.',true);
 if(secret&&secret===current)return showResult(msg,'관리자 비밀번호와 다르게 설정해주세요.',true);
 if(authChange&&!confirm(nextName+' 기사님의 실제 계정 정보를 변경할까요?'))return;
 button.disabled=true;showResult(msg,'저장 중…');
 let body=null;
 try{
  if(authChange){
   body={action:'edit',profile_ids:[account.profile_id],login_id:nextLogin,name:nextName,admin_password:current};if(secret)body.password=secret;
   const result=await request(body);const row=result.results?.[0];if(!row?.ok)throw Error('계정 변경 결과를 확인하지 못했습니다.');
   account.login_id=row.login_id;account.name=nextName;login.dataset.originalLogin=row.login_id;
   pw.value='';pw2.value='';adminPw.value='';
   if(result.warning||row.profile_synced===false){showResult(msg,result.warning||'로그인 정보 변경 완료. 직원정보 동기화를 다시 시도해주세요.',true);return;}
   if(row.audit===false)alert('로그인 정보는 변경되었지만 변경 이력 기록에 실패했습니다.');
  }
  if(!modal.isConnected||db.users[i]!==x)return;
  // Preserve the stable employee key. Legacy save handles only operational fields, never credentials.
  pw.value='';pw2.value='';adminPw.value='';await oldSave.call(this,i);
 }catch(e){showResult(msg,e.message||'저장 실패',true);}
 finally{if(body){body.admin_password='';if(body.password)body.password='';}pw.value='';pw2.value='';adminPw.value='';if(button.isConnected)button.disabled=false;}
};
function openCreate(){
 if(!isAdmin())return;
 showAccountModal('<div class="accountModalHead"><h3>기사 계정 추가</h3><button class="iconClose" onclick="closeAccountModal()">×</button></div><div class="accountModalBody"><div class="accountModalGrid" id="nepNewDriverFields"></div><p id="nepNewDriverMessage" role="status"></p></div><div class="accountModalFoot"><button class="smallbtn ghost" onclick="closeAccountModal()">닫기</button><button class="smallbtn green" id="nepNewDriverSave">등록</button></div>');
 const g=el('nepNewDriverFields'),msg=el('nepNewDriverMessage'),b=el('nepNewDriverSave');
 const [a,id]=input('아이디 (예: driver3)','nepNewDriverId');const [c,name]=input('이름','nepNewDriverName');const [d,pw]=input('새 비밀번호','nepNewDriverPw','password');const [e,pw2]=input('비밀번호 확인','nepNewDriverPw2','password');const [f,admin]=input('현재 관리자 비밀번호','nepNewDriverAdmin','password');f.className='wide';admin.autocomplete='current-password';g.append(a,c,d,e,f);
 b.onclick=async()=>{if(b.disabled)return;const login=id.value.trim().toLowerCase();if(!/^driver[1-9][0-9]{0,4}$/.test(login)||!name.value.trim()||!validPassword(pw.value)||pw.value!==pw2.value||!admin.value)return showResult(msg,'아이디(driver3 형식), 이름, 비밀번호(12자 이상), 관리자 비밀번호를 확인하세요.',true);
 if(!confirm(login+' 기사 계정을 등록할까요?'))return;b.disabled=true;const body={action:'create',login_id:login,name:name.value.trim(),password:pw.value,admin_password:admin.value};try{const r=await request(body);if(!r.results?.[0]?.ok)throw Error('등록 결과를 확인하지 못했습니다.');const list=await loadAccounts();const account=list.find(a=>a.login_id===login);if(account&&!db.users.some(u=>u.id===account.driver_key)){db.users.push({id:account.driver_key,name:account.name,role:'driver',active:true,monthlySalary:0,allowance:0,vehicleName:'',workStart:'',workEnd:'',workEvents:[],salaryHistory:[]});save();}closeAccountModal();renderAdmin();goAdminTab('users');}catch(err){showResult(msg,err.message||'등록 실패',true);}finally{body.password='';body.admin_password='';pw.value='';pw2.value='';admin.value='';b.disabled=false;}};
}
async function openStatus(key){
 if(!isAdmin())return;
 try{await loadAccounts();const a=accountCache.get(key);if(!a)throw Error('실제 로그인 계정이 없습니다.');
 showAccountModal('<div class="accountModalHead"><h3>기사 로그인 상태</h3><button class="iconClose" onclick="closeAccountModal()">×</button></div><div class="accountModalBody"><p id="nepStatusText"></p><div class="accountModalGrid" id="nepStatusFields"></div><p id="nepStatusMessage" role="status"></p></div><div class="accountModalFoot"><button class="smallbtn ghost" onclick="closeAccountModal()">닫기</button><button class="smallbtn green" id="nepStatusSave"></button></div>');
 el('nepStatusText').textContent=a.login_id+' · '+(a.active?'현재 로그인 허용 상태':'현재 로그인 차단 상태')+' / 기존 업무기록은 유지됩니다.';
 const [w,pw]=input('현재 관리자 비밀번호','nepStatusAdmin','password');pw.autocomplete='current-password';w.className='wide';el('nepStatusFields').append(w);
 const b=el('nepStatusSave'),msg=el('nepStatusMessage');b.textContent=a.active?'로그인 차단':'로그인 허용';
 b.onclick=async()=>{if(!pw.value)return showResult(msg,'관리자 비밀번호를 입력하세요.',true);if(!confirm(a.login_id+'의 로그인 상태를 변경할까요?'))return;b.disabled=true;const body={action:'status',profile_ids:[a.profile_id],active:!a.active,admin_password:pw.value};try{const r=await request(body);if(!r.results?.[0]?.ok)throw Error('변경 결과를 확인하지 못했습니다.');await loadAccounts();closeAccountModal();refreshLabels();}catch(e){showResult(msg,e.message||'변경 실패',true);}finally{body.admin_password='';pw.value='';b.disabled=false;}};
 }catch(e){alert(e.message||'계정 조회 실패');}
}
})();
