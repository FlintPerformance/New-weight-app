const BUILD = '__SW_VERSION__';
const CACHE_NAME = `steady-${BUILD}`;

const PRECACHE = ['/', '/index.html'];

self.addEventListener('install', (e) => {
  e.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => cache.addAll(PRECACHE))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k)))
    ).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (e) => {
  if (e.request.method !== 'GET') return;

  // Never cache version.json — always fetch fresh
  if (e.request.url.includes('version.json')) {
    e.respondWith(fetch(e.request));
    return;
  }

  e.respondWith(
    fetch(e.request)
      .then(res => {
        if (res.ok) {
          const clone = res.clone();
          caches.open(CACHE_NAME).then(cache => cache.put(e.request, clone));
        }
        return res;
      })
      .catch(() => caches.match(e.request))
  );
});

// Web Push notification handler
self.addEventListener('push', (e) => {
  if (!e.data) return;
  let data;
  try {
    data = e.data.json();
  } catch {
    data = { title: 'Steady', body: e.data.text() };
  }
  const title = data.title || 'Steady';
  const options = {
    body: data.body || 'Time to log your weight!',
    icon: '/favicon.svg',
    badge: '/favicon.svg',
    tag: data.tag || 'weight-reminder',
    data: { url: data.url || '/' },
    vibrate: [100, 50, 100],
    actions: [
      { action: 'open', title: 'Open App' },
      { action: 'dismiss', title: 'Dismiss' },
    ],
  };
  e.waitUntil(self.registration.showNotification(title, options));
});

// Handle notification click — open or focus the app
self.addEventListener('notificationclick', (e) => {
  e.notification.close();
  if (e.action === 'dismiss') return;
  e.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(clients => {
      for (const client of clients) {
        if (client.url.includes(self.location.origin) && 'focus' in client) {
          return client.focus();
        }
      }
      return self.clients.openWindow(e.notification.data?.url || '/');
    })
  );
});

// Listen for skip-waiting message from the app
self.addEventListener('message', (e) => {
  if (e.data === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});
