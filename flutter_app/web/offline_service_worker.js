const CACHE_NAME = 'gas-flow-control-v3';

const CORE_FILES = [
  './',
  './index.html',
  './flutter.js',
  './flutter_bootstrap.js',
  './main.dart.js',
  './manifest.json',
  './version.json',

  './favicon.png',

  './icons/Icon-192.png',
  './icons/Icon-512.png',
  './icons/Icon-maskable-192.png',
  './icons/Icon-maskable-512.png',

  './assets/AssetManifest.bin',
  './assets/AssetManifest.bin.json',
  './assets/FontManifest.json',

  './assets/fonts/MaterialIcons-Regular.otf',
  './assets/packages/cupertino_icons/assets/CupertinoIcons.ttf',

  './assets/shaders/ink_sparkle.frag',
  './assets/shaders/stretch_effect.frag',

  './canvaskit/canvaskit.js',
  './canvaskit/canvaskit.wasm',
  './canvaskit/skwasm.js',
  './canvaskit/skwasm.wasm',
  './canvaskit/skwasm_heavy.js',
  './canvaskit/skwasm_heavy.wasm',
  './canvaskit/wimp.js',
  './canvaskit/wimp.wasm',

  './canvaskit/chromium/canvaskit.js',
  './canvaskit/chromium/canvaskit.wasm',

  './canvaskit/experimental_webparagraph/canvaskit.js',
  './canvaskit/experimental_webparagraph/canvaskit.wasm',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(CORE_FILES);
    }),
  );

  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((names) => {
      return Promise.all(
        names
          .filter((name) => name !== CACHE_NAME)
          .map((name) => caches.delete(name)),
      );
    }),
  );

  self.clients.claim();
});

self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') {
    return;
  }

  const url = new URL(event.request.url);

  if (url.origin !== self.location.origin) {
    return;
  }

  if (event.request.mode === 'navigate') {
    event.respondWith(
      caches.match('./index.html').then((cached) => {
        return (
          cached ||
          fetch(event.request)
        );
      }),
    );

    return;
  }

  event.respondWith(
    caches.match(event.request).then((cached) => {
      if (cached) {
        return cached;
      }

      return fetch(event.request)
        .then((response) => {
          if (
            response &&
            response.status === 200
          ) {
            const copy = response.clone();

            caches.open(CACHE_NAME).then((cache) => {
              cache.put(
                event.request,
                copy,
              );
            });
          }

          return response;
        });
    }),
  );
});
