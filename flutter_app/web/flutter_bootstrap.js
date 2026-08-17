{{flutter_js}}
{{flutter_build_config}}

async function registerOfflineServiceWorker() {
  if (!('serviceWorker' in navigator)) {
    return;
  }

  try {
    await navigator.serviceWorker.register(
      'offline_service_worker.js',
      {
        scope: './',
      },
    );

    console.log('Gas Flow Control offline service worker registered.');
  } catch (error) {
    console.error(
      'Unable to register offline service worker:',
      error,
    );
  }
}

registerOfflineServiceWorker();

_flutter.loader.load();
