import { supabase } from './supabase';

// VAPID public key — must match the private key in the Supabase Edge Function
const VAPID_PUBLIC_KEY = 'BCdKoL8-y8AQKWEExojyoX7w9toHfvYGTZH_mm8yWsd8llXTvyOjfl6jDR4SQCy-9DMb1OQoWVPHslJ05sM85e0';

function urlBase64ToUint8Array(base64String) {
  const padding = '='.repeat((4 - (base64String.length % 4)) % 4);
  const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/');
  const raw = atob(base64);
  const arr = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) arr[i] = raw.charCodeAt(i);
  return arr;
}

/**
 * Subscribe to Web Push notifications.
 * Stores the subscription endpoint + keys in Supabase so the Edge Function
 * can send pushes even when the app is closed.
 */
export async function subscribeToPush(userId) {
  if (!('serviceWorker' in navigator) || !('PushManager' in window)) {
    throw new Error('Push notifications are not supported in this browser.');
  }

  const permission = await Notification.requestPermission();
  if (permission !== 'granted') {
    throw new Error('Notification permission denied.');
  }

  const registration = await navigator.serviceWorker.ready;
  const subscription = await registration.pushManager.subscribe({
    userVisibleOnly: true,
    applicationServerKey: urlBase64ToUint8Array(VAPID_PUBLIC_KEY),
  });

  const subJson = subscription.toJSON();

  const { error } = await supabase.from('push_subscriptions').upsert(
    {
      user_id: userId,
      endpoint: subJson.endpoint,
      keys_p256dh: subJson.keys.p256dh,
      keys_auth: subJson.keys.auth,
      updated_at: new Date().toISOString(),
    },
    { onConflict: 'user_id,endpoint' }
  );

  if (error) throw new Error('Failed to save push subscription: ' + error.message);

  return subscription;
}

/**
 * Unsubscribe from Web Push and remove the record from Supabase.
 */
export async function unsubscribeFromPush(userId) {
  try {
    const registration = await navigator.serviceWorker.ready;
    const subscription = await registration.pushManager.getSubscription();
    if (subscription) {
      const endpoint = subscription.endpoint;
      await subscription.unsubscribe();
      await supabase
        .from('push_subscriptions')
        .delete()
        .eq('user_id', userId)
        .eq('endpoint', endpoint);
    }
  } catch (err) {
    console.warn('Unsubscribe failed:', err);
  }
}

/**
 * Check if the user currently has an active push subscription.
 */
export async function getPushSubscription() {
  if (!('serviceWorker' in navigator) || !('PushManager' in window)) return null;
  try {
    const registration = await navigator.serviceWorker.ready;
    return await registration.pushManager.getSubscription();
  } catch {
    return null;
  }
}

export function isPushSupported() {
  return 'serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window;
}
