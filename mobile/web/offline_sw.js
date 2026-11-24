// Versioned offline app-shell Service Worker for AI Gardening Mentor Web.
// Built for `--no-web-resources-cdn` so CanvasKit renderer files are local and
// strictly precached. Never caches cross-origin or authenticated API responses.
const CACHE_NAME = "agm-app-shell-v5";

// Critical startup resources required for offline cold start (including Chrome's
// `canvaskit/chromium/` renderer files). Installation fails if any critical
// asset cannot be fetched cleanly.
const CRITICAL_APP_SHELL_URLS = [
  "/",
  "/index.html",
  "/manifest.json",
  "/favicon.png",
  "/flutter_bootstrap.js",
  "/main.dart.js",
  "/hybrid_ai.bundle.js",
  "/canvaskit/canvaskit.js",
  "/canvaskit/canvaskit.wasm",
  "/canvaskit/chromium/canvaskit.js",
  "/canvaskit/chromium/canvaskit.wasm",
  "/assets/FontManifest.json",
  "/assets/assets/branding/logo_icon.png",
  "/assets/fonts/MaterialIcons-Regular.otf",
];

// Secondary static assets cached best-effort after critical shell succeeds.
const OPTIONAL_STATIC_URLS = [
  "/icons/Icon-192.png",
  "/icons/Icon-512.png",
  "/assets/AssetManifest.bin.json",
];

const NETWORK_FIRST_PATHS = new Set([
  "/",
  "/index.html",
  "/manifest.json",
  "/flutter_bootstrap.js",
  "/main.dart.js",
  "/hybrid_ai.bundle.js",
]);

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then(async (cache) => {
      await Promise.all(
        CRITICAL_APP_SHELL_URLS.map(async (url) => {
          const res = await fetch(new Request(url, { cache: "reload" }));
          if (!res || !res.ok) {
            throw new Error(`Critical app-shell precache failed (${res?.status}) for ${url}`);
          }
          await cache.put(url, res);
        })
      );
      await Promise.allSettled(
        OPTIONAL_STATIC_URLS.map(async (url) => {
          const res = await fetch(new Request(url, { cache: "reload" }));
          if (res && res.ok) {
            await cache.put(url, res);
          }
        })
      );
    })
  );
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((key) => key !== CACHE_NAME)
          .map((oldKey) => caches.delete(oldKey))
      )
    )
  );
  self.clients.claim();
});

self.addEventListener("fetch", (event) => {
  const req = event.request;
  if (req.method !== "GET") return;

  const url = new URL(req.url);
  // Never cache cross-origin authenticated Firebase / Google API responses
  if (url.origin !== self.location.origin) return;

  // Navigation requests & core HTML/JS bundles: network-first with cache fallback
  // so online refreshes deliver fresh deploys while offline cold start still works.
  if (req.mode === "navigate" || NETWORK_FIRST_PATHS.has(url.pathname)) {
    const cacheKey = req.mode === "navigate" ? "/index.html" : url.pathname;
    event.respondWith(
      fetch(req)
        .then((res) => {
          if (res && res.status === 200) {
            const copy = res.clone();
            caches.open(CACHE_NAME).then((c) => c.put(cacheKey, copy));
          }
          return res;
        })
        .catch(() => caches.match(cacheKey))
    );
    return;
  }

  // Same-origin static runtime assets (CanvasKit WASM, fonts, icons): cache-first with background refresh
  event.respondWith(
    caches.match(req).then((cached) => {
      const fetchPromise = fetch(req)
        .then((res) => {
          if (res && res.status === 200) {
            const copy = res.clone();
            caches.open(CACHE_NAME).then((c) => c.put(req, copy));
          }
          return res;
        })
        .catch(() => cached);
      return cached || fetchPromise;
    })
  );
});
