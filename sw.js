/* Islam Quiz – service worker (netwerk eerst, cache als terugval)
   Verhoog CACHE_VERSION bij elke release. Zo zien bezoekers altijd meteen de nieuwste versie. */
const CACHE_VERSION = "islam-quiz-v10";

self.addEventListener("install", (event) => { event.waitUntil(self.skipWaiting()); });

self.addEventListener("activate", (event) => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.filter((k) => k !== CACHE_VERSION).map((k) => caches.delete(k)));
    await self.clients.claim();
  })());
});

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
