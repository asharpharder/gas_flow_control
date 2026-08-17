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

    await navigator.serviceWorker.ready;

    console.log(
      'Gas Flow Control offline service worker ready.',
    );
  } catch (error) {
    console.error(
      'Unable to register offline service worker:',
      error,
    );
  }
}

async function startFlutter() {
  await registerOfflineServiceWorker();

  _flutter.loader.load({
    config: {
      canvasKitBaseUrl: 'canvaskit/',
    },
  });
}

startFlutter();
