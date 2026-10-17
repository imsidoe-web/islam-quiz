/* Islam Quiz – service worker (netwerk eerst, cache als terugval)
   Verhoog CACHE_VERSION bij elke release. Zo zien bezoekers altijd meteen de nieuwste versie. */
const CACHE_VERSION = "islam-quiz-v62";
const PRECACHE = [];

self.addEventListener("install", (event) => {
  event.waitUntil((async () => {
    try {
      const cache = await caches.open(CACHE_VERSION);
      await Promise.all(PRECACHE.map((u) => cache.add(u).catch(() => {})));   // ontbreekt een bestand? Dan gaat de installatie gewoon door
    } catch (e) {}
    await self.skipWaiting();
  })());
});

self.addEventListener("activate", (event) => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.filter((k) => k !== CACHE_VERSION).map((k) => caches.delete(k)));
    await self.clients.claim();
  })());
});

// Audio vraagt delen van het bestand op (Range). Zonder verbinding bouwen we die uit de cache op.
async function rangeFromCache(req) {
  const hit = await caches.match(req.url, { ignoreSearch: true });
  if (!hit) return new Response("", { status: 503 });
  const buf = await hit.arrayBuffer();
  const m = /bytes=(\d*)-(\d*)/.exec(req.headers.get("range") || "");
  let start = m && m[1] ? parseInt(m[1], 10) : 0;
  let end = m && m[2] ? parseInt(m[2], 10) : buf.byteLength - 1;
  if (m && !m[1] && m[2]) { start = Math.max(0, buf.byteLength - parseInt(m[2], 10)); end = buf.byteLength - 1; }
  end = Math.min(end, buf.byteLength - 1);
  return new Response(buf.slice(start, end + 1), {
    status: 206,
    headers: { "Content-Type": hit.headers.get("Content-Type") || "audio/mpeg", "Content-Range": "bytes " + start + "-" + end + "/" + buf.byteLength, "Content-Length": String(end - start + 1), "Accept-Ranges": "bytes" }
  });
}

self.addEventListener("fetch", (event) => {
  const req = event.request;
  if (req.method !== "GET") return;
  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return;                 // Firebase, lettertypen enz. rechtstreeks
  if (req.headers.has("range")) return;

  event.respondWith((async () => {
    try {
      const res = await fetch(req, { cache: "no-cache" });          // altijd eerst de verse versie ophalen
      if (res.ok && res.type === "basic") {
        const cache = await caches.open(CACHE_VERSION);
        cache.put(req, res.clone());
      }
      return res;
    } catch (e) {
      const hit = (await caches.match(req, { ignoreSearch: true })) || (req.mode === "navigate" ? await caches.match("index.html") || await caches.match("./") : null);
      return hit || new Response("Geen verbinding. Probeer het later opnieuw.", { status: 503, headers: { "Content-Type": "text/plain; charset=utf-8" } });
    }
  })());
});

// ───── Herinnering (Web Push): melding als de dagreeks in gevaar is ─────
self.addEventListener("push", (event) => {
  let d = {};
  try { d = event.data ? event.data.json() : {}; } catch (e) { d = { body: event.data ? event.data.text() : "" }; }
  event.waitUntil((async () => {
    const wins = await self.clients.matchAll({ type: "window", includeUncontrolled: true });
    if (wins.some((c) => c.visibilityState === "visible")) return;   // de app is open en toont zelf de herinnering
    await self.registration.showNotification(d.title || "Islam Quiz", {
      body: d.body || "Speel vandaag nog één level om je reeks te houden.",
      icon: "icon-192.png", badge: "icon-192.png", tag: "streak", renotify: false,
      data: { url: d.url || "./" }
    });
  })());
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const url = (event.notification.data && event.notification.data.url) || "./";
  event.waitUntil((async () => {
    const wins = await self.clients.matchAll({ type: "window", includeUncontrolled: true });
    for (const c of wins) { if ("focus" in c) { await c.focus(); return; } }
    if (self.clients.openWindow) await self.clients.openWindow(url);
  })());
});
