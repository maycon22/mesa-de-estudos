/* Mesa de Estudos: guarda os arquivos do app para abrir sem internet.
   Os dados ficam no Supabase (nunca passam por este cache). */
const CACHE = "mesa-v1";
const BASICO = ["./", "./index.html", "./manifest.webmanifest", "./icon-192.png", "./icon-512.png"];

self.addEventListener("install", e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(BASICO)));
  self.skipWaiting();
});
self.addEventListener("activate", e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k)))));
  self.clients.claim();
});
self.addEventListener("fetch", e => {
  const req = e.request; if (req.method !== "GET") return;
  const url = new URL(req.url);
  if (url.hostname.endsWith("supabase.co") || url.hostname.endsWith("supabase.in")) return;
  const guardavel = url.origin === location.origin || /(^|\.)(jsdelivr\.net|cdnjs\.cloudflare\.com|fonts\.googleapis\.com|fonts\.gstatic\.com)$/.test(url.hostname);
  if (!guardavel) return;
  // rede primeiro (sempre a versão mais nova); sem internet, usa a cópia guardada
  e.respondWith(fetch(req).then(r => {
    if (r.ok || r.type === "opaque") { const c = r.clone(); caches.open(CACHE).then(ca => ca.put(req, c)); }
    return r;
  }).catch(() => caches.match(req).then(r => r || (req.mode === "navigate" ? caches.match("./index.html") : Response.error()))));
});
