import { useEffect } from 'react';

const CURRENT_BUILD = typeof __APP_BUILD__ !== 'undefined' ? __APP_BUILD__ : 'dev';
const CHECK_INTERVAL = 5 * 60 * 1000; // 5 minutes
// Jitter ±60s to avoid thundering herd
const JITTER = () => Math.floor(Math.random() * 120_000 - 60_000);

function applyUpdate(waitingWorker) {
  if (waitingWorker) {
    waitingWorker.postMessage('SKIP_WAITING');
  } else {
    window.location.reload();
  }
}

export function useUpdateCheck() {
  // Poll version.json for new builds — auto-reload when found
  useEffect(() => {
    if (CURRENT_BUILD === 'dev') return;

    const checkVersion = async () => {
      try {
        const res = await fetch(`/version.json?t=${Date.now()}`);
        if (!res.ok) return;
        const data = await res.json();
        if (data.build && data.build !== CURRENT_BUILD) {
          applyUpdate(null);
        }
      } catch {}
    };

    const initialTimeout = setTimeout(checkVersion, 10_000 + Math.random() * 5000);
    const interval = setInterval(checkVersion, CHECK_INTERVAL + JITTER());

    return () => {
      clearTimeout(initialTimeout);
      clearInterval(interval);
    };
  }, []);

  // Listen for service worker updates — auto-activate
  useEffect(() => {
    if (!('serviceWorker' in navigator)) return;

    const handleControllerChange = () => {
      window.location.reload();
    };

    navigator.serviceWorker.addEventListener('controllerchange', handleControllerChange);

    navigator.serviceWorker.ready.then(registration => {
      if (registration.waiting) {
        applyUpdate(registration.waiting);
      }

      registration.addEventListener('updatefound', () => {
        const newWorker = registration.installing;
        if (!newWorker) return;

        newWorker.addEventListener('statechange', () => {
          if (newWorker.state === 'installed' && navigator.serviceWorker.controller) {
            applyUpdate(newWorker);
          }
        });
      });
    });

    return () => {
      navigator.serviceWorker.removeEventListener('controllerchange', handleControllerChange);
    };
  }, []);
}
