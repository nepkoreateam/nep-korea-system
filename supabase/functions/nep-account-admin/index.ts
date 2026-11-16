import { createClient } from "npm:@supabase/supabase-js@2.95.3";

const ORIGIN="https://nepkoreateam.github.io";
const headers={"Access-Control-Allow-Origin":ORIGIN,"Access-Control-Allow-Headers":"authorization, apikey, content-type, x-client-info","Access-Control-Allow-Methods":"POST, OPTIONS","Content-Type":"application/json; charset=utf-8","Cache-Control":"no-store","Vary":"Origin"};
const reply=(status:number,body:unknown)=>new Response(JSON.stringify(body),{status,headers});
const opts={auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false}};
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const driverId=/^driver[1-9][0-9]{0,4}$/;
const passwordOK=(p:unknown):p is string=>typeof p==="string"&&p.length>=12&&new TextEncoder().encode(p).length<=72&&/[A-Za-z]/.test(p)&&/[0-9]/.test(p)&&/[^A-Za-z0-9\s]/.test(p);
const safeFailure=(err:unknown)=>{const e=err as {code?:string;status?:number};return e?.code==="weak_password"?"인증 서버에서 보안 수준이 낮은 비밀번호로 판단했습니다. 다른 비밀번호를 사용해주세요.":e?.status===429?"요청이 너무 많습니다. 잠시 후 다시 시도해주세요.":"인증 서버에서 작업을 완료하지 못했습니다."};

Deno.serve(async(req:Request)=>{
  const origin=req.headers.get("origin");
  if(origin&&origin!==ORIGIN)return reply(403,{error:"허용되지 않은 접속 주소입니다."});
  if(req.method==="OPTIONS")return new Response(null,{status:204,headers});
  if(req.method!=="POST")return reply(405,{error:"POST 요청만 지원합니다."});
  const authorization=req.headers.get("authorization")||"";
  if(!authorization.startsWith("Bearer "))return reply(401,{error:"관리자 로그인이 필요합니다."});
  const url=Deno.env.get("SUPABASE_URL"),service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"),anon=Deno.env.get("SUPABASE_ANON_KEY");
  if(!url||!service||!anon)return reply(503,{error:"인증 서버 설정을 확인해주세요."});
  const admin=createClient(url,service,opts);
  try{
    // Never authorize from client-provided role, email, or user_metadata.
    const {data:auth,error:authError}=await admin.auth.getUser(authorization.slice(7));
    const user=auth?.user;
    if(authError||!user?.id||!user.email)return reply(401,{error:"로그인 세션이 만료되었습니다. 다시 로그인해주세요."});
    const {data:actor,error:actorError}=await admin.from("profiles").select("id,role,active").eq("auth_user_id",user.id).maybeSingle();
    if(actorError)return reply(503,{error:"계정 권한을 확인하지 못했습니다."});
    if(actor?.role!=="admin"||actor.active!==true)return reply(403,{error:"활성 관리자만 계정을 관리할 수 있습니다."});
    const raw=await req.text();
    if(raw.length>20000)return reply(413,{error:"요청이 너무 큽니다."});
    let body:any;
    try{body=JSON.parse(raw)}catch{return reply(400,{error:"잘못된 요청입니다."})}
    if(!body||typeof body!=="object")return reply(400,{error:"잘못된 요청입니다."});
    const action=body.action;
    async function accountList(){
      const {data:profiles,error}=await admin.from("profiles").select("id,role,name,email,active,auth_user_id,linked_driver_id").eq("role","driver").not("auth_user_id","is",null).order("name");
      if(error)throw error;
      const {data:drivers,error:driverError}=await admin.from("drivers").select("id,app_driver_id,name,active").order("app_driver_id");
      if(driverError)throw driverError;
      const byId=new Map((drivers||[]).map(d=>[d.id,d]));
      return (profiles||[]).filter(p=>p.linked_driver_id&&byId.has(p.linked_driver_id)&&p.auth_user_id!==user.id).map(p=>({profile_id:p.id,login_id:byId.get(p.linked_driver_id)?.app_driver_id||p.email,name:p.name,email:p.email,active:p.active,driver_active:byId.get(p.linked_driver_id)?.active}));
    }
    if(action==="list"){
      const accounts=await accountList();
      const {data:history,error:historyError}=await admin.from("audit_logs").select("action,record_id,after_data,created_at").in("action",["nep.driver.password_reset","nep.driver.login_status","nep.driver.account_create"]).order("created_at",{ascending:false}).limit(20);
      return reply(200,{accounts,history:historyError?[]:history||[],history_available:!historyError});
    }
    if(!["reset","status","create"].includes(action))return reply(400,{error:"지원하지 않는 작업입니다."});
    // Step-up authentication: the signed-in administrator must re-enter their own password.
    if(typeof body.admin_password!=="string"||!body.admin_password||body.admin_password.length>256)return reply(400,{error:"현재 관리자 비밀번호를 입력해주세요."});
    const reauth=createClient(url,anon,opts);
    const {data:reauthData,error:reauthError}=await reauth.auth.signInWithPassword({email:user.email,password:body.admin_password});
    if(reauthError||reauthData?.user?.id!==user.id)return reply(403,{error:"관리자 비밀번호가 맞지 않거나 인증 요청이 제한되었습니다."});
    // Revoke only the fresh, server-side reauthentication session, not the user's browser session.
    await reauth.auth.signOut({scope:"local"});
    if((action==="reset"||action==="create")&&!passwordOK(body.password))return reply(400,{error:"새 비밀번호는 영문, 숫자, 특수문자를 포함해 12자 이상, 72바이트 이하여야 합니다."});
    if((action==="reset"||action==="create")&&body.password===body.admin_password)return reply(400,{error:"기사 비밀번호는 관리자 비밀번호와 다르게 설정해주세요."});
    // Re-check live role after the step-up authentication.
    const {data:live,error:liveError}=await admin.from("profiles").select("id,role,active").eq("id",actor.id).eq("auth_user_id",user.id).maybeSingle();
    if(liveError||live?.role!=="admin"||!live.active)return reply(403,{error:"관리자 권한이 변경되었습니다."});
    async function audit(event:string,profile:string,details:Record<string,unknown>){
      const {error}=await admin.from("audit_logs").insert({actor_profile_id:actor.id,action:event,table_name:"profiles",record_id:profile,after_data:details});
      return !error;
    }
    if(action==="create"){
      const login=String(body.login_id||"").trim().toLowerCase(),name=String(body.name||"").trim();
      if(!driverId.test(login)||!name||name.length>80)return reply(400,{error:"기사 아이디는 driver3과 같은 형식, 이름은 80자 이하로 입력해주세요."});
      const email=login+"@nepkorea.local";
      const {data:existing,error:existingError}=await admin.from("drivers").select("id,profile_id,app_driver_id,name,active").eq("app_driver_id",login).maybeSingle();
      if(existingError)throw existingError;
      if(existing?.profile_id)return reply(409,{error:"이미 연결된 기사 계정입니다."});
      if(existing){
        const {count,error}=await admin.from("profiles").select("id",{count:"exact",head:true}).eq("linked_driver_id",existing.id);
        if(error)throw error;if(count)return reply(409,{error:"이미 로그인 계정이 연결되어 있습니다."});
        if(existing.name!==name)return reply(409,{error:"기존 기사 정보와 이름이 다릅니다. 기존 기사 이름을 확인해주세요."});
      }
      // Auth API is used for all credential changes; never write auth.users directly.
      const created=await admin.auth.admin.createUser({email,password:body.password,email_confirm:true});
      if(created.error||!created.data.user)return reply(409,{error:"계정을 만들지 못했습니다. 이미 등록된 아이디인지 확인하거나 다른 비밀번호로 시도해주세요."});
      const authId=created.data.user.id;
      let madeDriver:string|null=null, madeProfile:string|null=null, linked=false;
      try{
        let did=existing?.id;
        if(!did){
          const {data:d,error}=await admin.from("drivers").insert({name,app_driver_id:login,active:true,salary_amount:0}).select("id").single();
          if(error||!d)throw error||new Error("driver creation");
          did=d.id;madeDriver=did;
        }
        const {data:p,error:pError}=await admin.from("profiles").insert({auth_user_id:authId,role:"driver",name,email,active:true,linked_driver_id:did}).select("id").single();
        if(pError||!p)throw pError||new Error("profile creation");
        madeProfile=p.id;
        const {data:link,error:linkError}=await admin.from("drivers").update({profile_id:p.id}).eq("id",did).is("profile_id",null).select("id").maybeSingle();
        if(linkError||!link)throw linkError||new Error("driver link");
        linked=true;
      }catch{
        // Only undo rows created by this failed operation; never delete an existing driver.
        if(madeProfile&&!linked)await admin.from("profiles").delete().eq("id",madeProfile).eq("auth_user_id",authId);
        if(madeDriver&&!linked)await admin.from("drivers").delete().eq("id",madeDriver).is("profile_id",null);
        if(!linked)await admin.auth.admin.deleteUser(authId);
        return reply(500,{error:"기사 계정 연결에 실패했습니다. 기존 정보는 변경하지 않았습니다. 다시 등록하기 전에 목록을 확인해주세요."});
      }
      const logged=await audit("nep.driver.account_create",madeProfile!,{login_id:login,name,active:true});
      return reply(200,{results:[{login_id:login,ok:true,audit:logged}],message:"기사 계정이 등록되었습니다."});
    }
    const ids=Array.isArray(body.profile_ids)?[...new Set(body.profile_ids)]:[];
    if(!ids.length||ids.length>50||ids.some(x=>typeof x!=="string"||!uuid.test(x)))return reply(400,{error:"기사 계정을 1~50개 선택해주세요."});
    if(action==="status"&&(ids.length!==1||typeof body.active!=="boolean"))return reply(400,{error:"로그인 상태는 한 계정씩 변경해주세요."});
    const {data:targets,error:targetError}=await admin.from("profiles").select("id,auth_user_id,role,active,linked_driver_id,name,email").in("id",ids).eq("role","driver").not("auth_user_id","is",null);
    if(targetError)throw targetError;
    // Reject the whole request unless every ID is a real linked driver, never admin/customer.
    if(targets?.length!==ids.length||targets.some(p=>!p.linked_driver_id||p.auth_user_id===user.id))return reply(403,{error:"선택한 계정 중 변경할 수 없는 계정이 있습니다."});
    const {data:driverRows,error:driverError}=await admin.from("drivers").select("id,app_driver_id,profile_id").in("id",targets.map(p=>p.linked_driver_id));
    if(driverError)throw driverError;
    const byDriver=new Map((driverRows||[]).map(d=>[d.id,d]));
    if(targets.some(p=>{const d=byDriver.get(p.linked_driver_id);return !d||(d.profile_id!==null&&d.profile_id!==p.id)}))return reply(409,{error:"기사 계정과 직원 정보 연결을 확인해주세요."});
    const {data:links,error:linksError}=await admin.from("profiles").select("id,linked_driver_id").in("linked_driver_id",targets.map(p=>p.linked_driver_id));
    if(linksError)throw linksError;
    if(targets.some(p=>(links||[]).filter(x=>x.linked_driver_id===p.linked_driver_id).length!==1))return reply(409,{error:"중복 연결된 기사 계정이 있습니다."});
    if(action==="reset"&&targets.some(p=>!p.active))return reply(409,{error:"로그인이 차단된 계정은 먼저 로그인 허용으로 변경해주세요."});
    const results=[];
    for(const target of targets){
      const login=byDriver.get(target.linked_driver_id)?.app_driver_id||target.email||target.name;
      if(action==="reset"){
        const {error}=await admin.auth.admin.updateUserById(target.auth_user_id,{password:body.password});
        if(error){results.push({login_id:login,ok:false,error:safeFailure(error)});continue;}
        const logged=await audit("nep.driver.password_reset",target.id,{login_id:login,name:target.name});
        results.push({login_id:login,ok:true,audit:logged});
      }else{
        const {data:changed,error}=await admin.from("profiles").update({active:body.active}).eq("id",target.id).eq("role","driver").eq("auth_user_id",target.auth_user_id).select("id").maybeSingle();
        if(error||!changed){results.push({login_id:login,ok:false,error:"로그인 상태 변경 실패"});continue;}
        const logged=await audit("nep.driver.login_status",target.id,{login_id:login,name:target.name,active:body.active});
        results.push({login_id:login,ok:true,audit:logged});
      }
    }
    return reply(200,{results});
  }catch{
    // Do not log request bodies, auth tokens, passwords, or raw database errors.
    return reply(500,{error:"계정관리 서버 처리에 실패했습니다. 목록을 새로고침하여 상태를 확인해주세요."});
  }
});
