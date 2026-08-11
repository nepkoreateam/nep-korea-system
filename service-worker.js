
const CACHE_NAME = 'nep-korea-v44-final-clean';
self.addEventListener('install', event => {
  self.skipWaiting();
  event.waitUntil(caches.open(CACHE_NAME).then(cache => cache.addAll([
    './',
    './index.html?v=44',
    './manifest.webmanifest',
    './apple-touch-icon-v29.png',
    './favicon-v29.png',
    './icons/nep-v29-180.png',
    './icons/nep-v29-192.png',
    './icons/nep-v29-512.png'
  ]).catch(()=>{})));
});
self.addEventListener('activate', event => {
  event.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k)))));
  self.clients.claim();
});
self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);
  if (url.pathname.includes('/api/')) return;
  event.respondWith(fetch(event.request).catch(() => caches.match(event.request).then(res => res || caches.match('./index.html'))));
});
