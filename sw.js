/* The Desk — app-shell service worker.
   Cache-first with stale-while-revalidate: serve instantly from cache,
   fetch a fresh copy in the background, update the cache for next time.
   App state lives in localStorage / window.storage / Supabase, NOT here —
   this worker only makes the shell load offline and feel instant. */

const CACHE = 'thedesk-v2';
const SHELL = [
  './',
  './index.html',
  './manifest.json',
  './icon-192.png',
  './icon-512.png'
];

self.addEventListener('install', (e) => {
  e.waitUntil(
    caches.open(CACHE)
      .then((c) => c.addAll(SHELL))
      .then(() => self.skipWaiting())
      .catch(() => {}) // a missing optional asset shouldn't block install
  );
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (e) => {
  const req = e.request;
  // Only handle same-origin GETs. Let Supabase / CDN / everything else go straight to network.
  if (req.method !== 'GET' || new URL(req.url).origin !== self.location.origin) return;

  e.respondWith(
    caches.open(CACHE).then((cache) =>
      cache.match(req).then((cached) => {
        const network = fetch(req)
          .then((res) => {
            if (res && res.status === 200 && res.type === 'basic') cache.put(req, res.clone());
            return res;
          })
          .catch(() => cached); // offline: fall back to whatever we have
        // Serve cache immediately if present; otherwise wait on network.
        return cached || network;
      })
    )
  );
});
