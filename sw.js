/* Service Worker: App offline verfügbar machen. Speichert nur App-Dateien, keine Einträge. */
const VERSION = 'zyklus-v2.4.2';
const SHELL = ['./', './index.html', './styles.css', './manifest.webmanifest',
  './src/main.js', './src/ui.js', './src/logic.js', './src/model.js', './src/storage.js', './src/texts.js', './src/art.js',
  './fonts/fonts.css', './fonts/dm-serif-display-latin.woff2', './fonts/outfit-latin.woff2', './fonts/playfair-display-latin.woff2', './fonts/dm-sans-latin.woff2',
  './img/zweig-ecke.png', './img/zweig-klein.png', './icons/icon.svg', './icons/icon-192.png', './icons/icon-512.png', './icons/apple-touch-icon.png'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(VERSION).then(c => c.addAll(SHELL)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', e => {
  e.waitUntil(caches.keys()
    .then(keys => Promise.all(keys.filter(k => k !== VERSION).map(k => caches.delete(k))))
    .then(() => self.clients.claim()));
});

self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);

  if (url.origin !== location.origin) return;

  // Seitenaufrufe: Netz zuerst (für Updates), offline die gespeicherte App
  if (req.mode === 'navigate') {
    e.respondWith(fetch(req).then(r => { const copy = r.clone(); caches.open(VERSION).then(c => c.put('./index.html', copy)); return r; })
      .catch(() => caches.match('./index.html')));
    return;
  }
  // App-Dateien: Cache zuerst
  e.respondWith(caches.match(req).then(hit => hit || fetch(req).then(r => {
    if (r.ok) { const copy = r.clone(); caches.open(VERSION).then(c => c.put(req, copy)); }
    return r;
  })));
});
