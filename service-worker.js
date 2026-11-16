const CACHE_PREFIX='nep-korea-';
self.addEventListener('install',()=>self.skipWaiting());
self.addEventListener('activate',event=>event.waitUntil((async()=>{for(const k of await caches.keys()){if(k.startsWith(CACHE_PREFIX))await caches.delete(k);}await self.clients.claim();})()));
self.addEventListener('fetch',event=>{
 const request=event.request;
 if(request.method!=='GET'||new URL(request.url).origin!==self.location.origin||request.mode!=='navigate')return;
 event.respondWith(fetch(request,{cache:'no-store'}).catch(()=>new Response('<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>NEP 연결 확인</title><h1>인터넷 연결을 확인해주세요.</h1><p>운영 데이터 보호를 위해 오프라인에서는 새 수거기록을 저장할 수 없습니다. 인터넷을 연결한 후 앱을 다시 열어주세요.</p><button onclick="location.reload()">다시 연결</button></html>',{status:503,headers:{'Content-Type':'text/html; charset=utf-8'}})));
});
