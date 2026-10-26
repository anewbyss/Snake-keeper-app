// Offline support: serve the app from cache, refresh the cache in the background.
// Bump VERSION when files are added or renamed.
const VERSION = "snakekeeper-v1";
const FILES = [
  "./", "index.html", "styles.css", "manifest.webmanifest",
  "js/app.js", "js/db.js", "js/export.js", "js/genes.js", "js/genetics.js", "js/model.js", "js/sync.js", "js/ui.js", "js/xlsx.js",
  "icons/icon-192.png", "icons/icon-512.png", "icons/apple-touch-icon.png",
];

self.addEventListener("install", (event) => {
  event.waitUntil(caches.open(VERSION).then((cache) => cache.addAll(FILES)).then(() => self.skipWaiting()));
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== VERSION).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", (event) => {
  if (event.request.method !== "GET" || new URL(event.request.url).origin !== location.origin) return;
  event.respondWith(
    caches.open(VERSION).then(async (cache) => {
      const cached = await cache.match(event.request, { ignoreSearch: true });
      const network = fetch(event.request)
        .then((response) => {
          if (response.ok) cache.put(event.request, response.clone());
          return response;
        })
        .catch(() => cached);
      return cached ?? network;
    })
  );
});
