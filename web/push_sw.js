// Web Push service worker. Registered by the app (web_push_service.dart)
// under its own `push/` scope so it never replaces Flutter's own
// flutter_service_worker.js at the root scope — push delivery doesn't depend
// on scope, only on this registration.

const APP_ROOT = new URL('./', self.location).href;

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

self.addEventListener('push', (event) => {
  let data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch (_) {
    data = { body: event.data ? event.data.text() : '' };
  }

  event.waitUntil(
    (async () => {
      await self.registration.showNotification(data.title || 'AquaConnect', {
        body: data.body || '',
        icon: 'icons/Icon-192.png',
        badge: 'icons/Icon-192.png',
        tag: data.id || undefined,
        data: { link: data.link || '/notifications' },
      });
      // Let an open app refresh its 알림함 / badge right away.
      const windows = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
      for (const client of windows) client.postMessage({ type: 'aquaconnect-push' });
    })(),
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const link = (event.notification.data && event.notification.data.link) || '/notifications';

  event.waitUntil(
    (async () => {
      const windows = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
      const open = windows.find((c) => c.url.startsWith(APP_ROOT));
      if (open) {
        await open.focus();
        open.postMessage({ type: 'aquaconnect-open', link });
        return;
      }
      // The app uses hash routing (go_router's default on web).
      await self.clients.openWindow(`${APP_ROOT}#${link}`);
    })(),
  );
});
