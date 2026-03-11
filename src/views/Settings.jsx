import React, { useState, useEffect } from 'react';
import { useAppData, useAppActions } from '../App';
import { supabase } from '../supabase';
import { exportAllDB, importAllDB, clearAllDB } from '../db';
import Avatar from '../components/Avatar';
import { subscribeToPush, unsubscribeFromPush, isPushSupported } from '../notifications';

function compressImage(file, maxSize = 800, quality = 0.8) {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => {
      let { width, height } = img;
      if (width > maxSize || height > maxSize) {
        const ratio = Math.min(maxSize / width, maxSize / height);
        width = Math.round(width * ratio);
        height = Math.round(height * ratio);
      }
      const canvas = document.createElement('canvas');
      canvas.width = width;
      canvas.height = height;
      canvas.getContext('2d').drawImage(img, 0, 0, width, height);
      canvas.toBlob(
        blob => blob ? resolve(new File([blob], 'avatar.webp', { type: 'image/webp' })) : reject(new Error('Compression failed')),
        'image/webp',
        quality
      );
    };
    img.onerror = () => reject(new Error('Failed to load image'));
    img.src = URL.createObjectURL(file);
  });
}

const GRAPH_COLORS = [
  { value: '#2B9B8F', label: 'Teal' },
  { value: '#3b82f6', label: 'Blue' },
  { value: '#22c55e', label: 'Green' },
  { value: '#a855f7', label: 'Purple' },
  { value: '#f59e0b', label: 'Amber' },
  { value: '#ec4899', label: 'Pink' },
  { value: '#06b6d4', label: 'Cyan' },
  { value: '#ef4444', label: 'Red' },
];

export default function Settings() {
  const { user, displayName, unit, syncing } = useAppData();
  const { signOut, sync, changeUnit, showToast, reload } = useAppActions();
  const [confirmClear, setConfirmClear] = useState(false);
  const [avatarUrl, setAvatarUrl] = useState(null);
  const [graphColor, setGraphColor] = useState('#2B9B8F');
  const [pushEnabled, setPushEnabled] = useState(() => localStorage.getItem('subtle-push-enabled') === '1');
  const [pushLoading, setPushLoading] = useState(false);

  useEffect(() => {
    const loadProfile = async () => {
      const { data } = await supabase
        .from('profiles')
        .select('avatar_url, graph_color')
        .eq('id', user.id)
        .single();
      if (data?.avatar_url) setAvatarUrl(data.avatar_url);
      if (data?.graph_color) setGraphColor(data.graph_color);
    };
    loadProfile();
  }, [user.id]);

  const handleGraphColorChange = async (color) => {
    setGraphColor(color);
    try {
      await supabase
        .from('profiles')
        .update({ graph_color: color })
        .eq('id', user.id);
      showToast('Graph color updated');
    } catch {
      showToast('Failed to save color', 'error');
    }
  };

  const handleAvatarUpload = async (file) => {
    try {
      const compressed = await compressImage(file, 800, 0.8);
      file = compressed;

      const filePath = `${user.id}/avatar.webp`;

      const { error: uploadError } = await supabase.storage
        .from('avatars')
        .upload(filePath, file, { upsert: true });

      if (uploadError) throw uploadError;

      const { data: { publicUrl } } = supabase.storage
        .from('avatars')
        .getPublicUrl(filePath);

      const url = `${publicUrl}?t=${Date.now()}`;

      await supabase
        .from('profiles')
        .upsert({ id: user.id, avatar_url: url, display_name: displayName });

      setAvatarUrl(url);
      showToast('Photo updated!');
    } catch (err) {
      showToast('Upload failed: ' + err.message, 'error');
    }
  };

  const handleExport = async () => {
    try {
      const data = await exportAllDB();
      const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `subtle-backup-${new Date().toISOString().slice(0, 10)}.json`;
      a.click();
      URL.revokeObjectURL(url);
      showToast('Data exported');
    } catch {
      showToast('Export failed', 'error');
    }
  };

  const validateImportData = (data) => {
    if (!data || typeof data !== 'object') return false;
    if (data.weights && !Array.isArray(data.weights)) return false;
    if (data.goals && !Array.isArray(data.goals)) return false;
    if (data.weights) {
      for (const w of data.weights) {
        if (!w.id || !w.date || typeof w.weight !== 'number') return false;
      }
    }
    if (data.goals) {
      for (const g of data.goals) {
        if (!g.id || typeof g.targetWeight !== 'number') return false;
      }
    }
    return true;
  };

  const handleImport = async () => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = '.json';
    input.onchange = async (e) => {
      try {
        const file = e.target.files[0];
        if (!file) return;
        if (file.size > 10 * 1024 * 1024) {
          showToast('File too large (max 10MB)', 'error');
          return;
        }
        const text = await file.text();
        const data = JSON.parse(text);
        if (!validateImportData(data)) {
          showToast('Invalid backup file format', 'error');
          return;
        }
        await importAllDB(data);
        await reload();
        showToast(`Imported ${(data.weights || []).length} entries, ${(data.goals || []).length} goals`);
      } catch {
        showToast('Import failed — check file format', 'error');
      }
    };
    input.click();
  };

  async function enableNotifications() {
    setPushLoading(true);
    try {
      await subscribeToPush(user.id);
      setPushEnabled(true);
      localStorage.setItem('subtle-push-enabled', '1');
      showToast('Reminders enabled');
    } catch (err) {
      showToast(err.message, 'error');
    } finally {
      setPushLoading(false);
    }
  }

  async function disableNotifications() {
    setPushLoading(true);
    try {
      await unsubscribeFromPush(user.id);
      setPushEnabled(false);
      localStorage.removeItem('subtle-push-enabled');
      showToast('Reminders disabled');
    } catch (err) {
      showToast('Failed to disable notifications: ' + err.message, 'error');
    } finally {
      setPushLoading(false);
    }
  }

  const handleClear = async () => {
    await clearAllDB();
    await reload();
    showToast('All local data cleared');
    setConfirmClear(false);
  };

  return (
    <div className="max-w-2xl">
      <h1 className="font-heading text-2xl font-bold text-cream mb-6">Your Settings</h1>

      {/* Profile */}
      <div className="bg-surface-mid rounded-sm p-5 border border-black/5 mb-5 shadow-card">
        <div className="flex items-center gap-4">
          <Avatar
            url={avatarUrl}
            name={displayName}
            size="xl"
            editable
            onUpload={handleAvatarUpload}
          />
          <div className="flex-1">
            <p className="text-cream font-medium text-xl">{displayName}</p>
            <p className="text-cream/50 text-xs">{user.email}</p>
            <p className="text-cream/50 text-xs mt-1">Tap to update your photo</p>
          </div>
        </div>
      </div>

      {/* Desktop two-column layout for settings cards */}
      <div className="desktop:grid desktop:grid-cols-2 desktop:gap-4">
        {/* Unit Preference */}
        <div className="bg-surface-mid rounded-sm p-5 border border-black/5 mb-5 desktop:mb-0 shadow-soft">
          <p className="text-cream/60 text-xs uppercase tracking-wider mb-3">Preferred Unit</p>
          <div className="flex gap-2">
            {['lb', 'kg'].map(u => (
              <button
                key={u}
                onClick={() => changeUnit(u)}
                className={`flex-1 py-2.5 rounded-sm font-semibold text-sm transition-colors ${
                  unit === u ? 'bg-accent text-white shadow-sm' : 'bg-surface-up text-cream/60 border border-black/10 hover:border-accent/30'
                }`}
              >
                {u === 'lb' ? 'Pounds (lb)' : 'Kilograms (kg)'}
              </button>
            ))}
          </div>
        </div>

        {/* Graph Color */}
        <div className="bg-surface-mid rounded-sm p-5 border border-black/5 mb-5 desktop:mb-0 shadow-soft">
          <p className="text-cream/60 text-xs uppercase tracking-wider mb-3">Your Chart Color</p>
          <p className="text-cream/50 text-xs mb-3">Pick your color for charts with friends</p>
          <div className="flex gap-2 flex-wrap">
            {GRAPH_COLORS.map(c => (
              <button
                key={c.value}
                onClick={() => handleGraphColorChange(c.value)}
                className={`w-9 h-9 rounded-full transition-all ${graphColor === c.value ? 'ring-2 ring-cream ring-offset-2 ring-offset-surface-mid scale-110' : 'hover:scale-110'}`}
                style={{ backgroundColor: c.value }}
                title={c.label}
              />
            ))}
          </div>
        </div>
      </div>

      <div className="desktop:grid desktop:grid-cols-2 desktop:gap-4 mt-0 desktop:mt-4">
        {/* Sync */}
        <div className="bg-surface-mid rounded-sm p-5 border border-black/5 mb-5 desktop:mb-0 shadow-soft">
          <p className="text-cream/60 text-xs uppercase tracking-wider mb-3">Stay in Sync</p>
          <button
            onClick={sync}
            disabled={syncing}
            className="w-full bg-surface-up border border-black/10 hover:border-accent/30 text-cream py-2.5 rounded-sm font-medium text-sm transition-colors disabled:opacity-50"
          >
            {syncing ? 'Syncing...' : 'Sync Now'}
          </button>
        </div>
      </div>

      {/* Notifications */}
      {isPushSupported() && (
        <div className="bg-surface-mid rounded-sm p-5 border border-black/5 mb-5 mt-0 desktop:mt-4 shadow-soft">
          <div className="flex items-start gap-4">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" className="text-warning mt-0.5 flex-shrink-0">
              <path d="M18 8A6 6 0 006 8c0 7-3 9-3 9h18s-3-2-3-9" />
              <path d="M13.73 21a2 2 0 01-3.46 0" />
            </svg>
            <div className="flex-1">
              <h3 className="text-sm font-medium text-cream mb-1">Daily Reminders</h3>
              <p className="text-xs text-cream/50 mb-3">
                {pushEnabled
                  ? 'Reminders are active. You will get a daily reminder to log your weight and a weekly progress summary — even when the app is closed.'
                  : 'Get daily reminders to log your weight and weekly progress summaries. Works even when the app is closed.'}
              </p>
              {pushEnabled ? (
                <button
                  onClick={disableNotifications}
                  disabled={pushLoading}
                  className="px-4 py-2 border border-black/10 text-cream/60 hover:text-cream disabled:opacity-50 text-sm rounded-sm transition-colors"
                >
                  {pushLoading ? 'Wait...' : 'Disable Reminders'}
                </button>
              ) : (
                <button
                  onClick={enableNotifications}
                  disabled={pushLoading}
                  className="px-4 py-2 bg-accent hover:bg-accent-dark disabled:opacity-50 text-white text-sm font-medium rounded-sm transition-colors"
                >
                  {pushLoading ? 'Setting up...' : 'Enable Reminders'}
                </button>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Data Management */}
      <div className="bg-surface-mid rounded-sm p-5 border border-black/5 mb-5 mt-0 desktop:mt-4 shadow-soft">
        <p className="text-cream/60 text-xs uppercase tracking-wider mb-3">Your Data</p>
        <div className="space-y-2">
          <button onClick={handleExport} className="w-full bg-surface-up border border-black/10 text-cream py-2.5 rounded-sm text-sm hover:border-accent/30 transition-colors">
            Back Up My Data
          </button>
          <button onClick={handleImport} className="w-full bg-surface-up border border-black/10 text-cream py-2.5 rounded-sm text-sm hover:border-accent/30 transition-colors">
            Restore From Backup
          </button>
          {!confirmClear ? (
            <button onClick={() => setConfirmClear(true)} className="w-full bg-surface-up border border-black/10 text-danger/60 py-2.5 rounded-sm text-sm hover:border-danger/30 transition-colors">
              Start Fresh
            </button>
          ) : (
            <div className="flex gap-2">
              <button onClick={handleClear} className="flex-1 bg-danger text-white py-2.5 rounded-sm text-sm font-semibold">
                Yes, Clear Everything
              </button>
              <button onClick={() => setConfirmClear(false)} className="px-4 text-cream/50 text-sm">Cancel</button>
            </div>
          )}
        </div>
      </div>

      {/* Sign Out */}
      <button
        onClick={signOut}
        className="w-full bg-surface-up border border-black/10 text-cream/60 py-3 rounded-sm font-medium text-sm hover:text-cream hover:border-black/20 transition-colors"
      >
        Log Out
      </button>

      <p className="text-center text-cream/40 text-xs mt-6 mb-4">
        Subtle v1.0.0 · Build {typeof __APP_BUILD__ !== 'undefined' ? __APP_BUILD__ : 'dev'}
      </p>
    </div>
  );
}
