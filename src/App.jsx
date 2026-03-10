import React, { createContext, useContext, useState, useCallback, useMemo, useEffect, useRef } from 'react';
import { useAuth } from './hooks/useAuth';
import { useLocalData } from './hooks/useLocalData';
import { useNavigation } from './hooks/useNavigation';
import { useUpdateCheck } from './hooks/useUpdateCheck';
import { syncData, pullFromCloud } from './sync';
import AuthView from './views/AuthView';
import Onboarding from './views/Onboarding';
import Dashboard from './views/Dashboard';
import LogWeight from './views/LogWeight';
import History from './views/History';
import Goals from './views/Goals';
import Settings from './views/Settings';
import Circle from './views/Circle';
import Layout from './components/Layout';
import Toast from './components/Toast';
import ErrorBoundary from './components/ErrorBoundary';

const AppDataContext = createContext(null);
const AppActionsContext = createContext(null);

export function useAppData() { return useContext(AppDataContext); }
export function useAppActions() { return useContext(AppActionsContext); }
export function useApp() {
  return { ...useAppData(), ...useAppActions() };
}

function OfflineBanner() {
  const [offline, setOffline] = useState(!navigator.onLine);

  useEffect(() => {
    const goOffline = () => setOffline(true);
    const goOnline = () => setOffline(false);
    window.addEventListener('offline', goOffline);
    window.addEventListener('online', goOnline);
    return () => {
      window.removeEventListener('offline', goOffline);
      window.removeEventListener('online', goOnline);
    };
  }, []);

  if (!offline) return null;

  return (
    <div className="fixed top-0 left-0 right-0 z-[90] desktop:left-56">
      <div className="bg-warning/90 text-white px-4 py-1.5 text-center text-xs font-medium rounded-b-sm">
        You're offline — changes will sync when you reconnect
      </div>
    </div>
  );
}

export default function App() {
  const { user, loading: authLoading, signUp, signIn, signOut } = useAuth();
  const { view, navigate, goBack } = useNavigation('dashboard');
  useUpdateCheck();
  const data = useLocalData(user?.id);
  const [syncing, setSyncing] = useState(false);
  const [toast, setToast] = useState(null);
  const [unit, setUnit] = useState(() => localStorage.getItem('steady-unit') || 'lb');
  const [showOnboarding, setShowOnboarding] = useState(false);
  const [pendingInvite, setPendingInvite] = useState(() => {
    const code = new URLSearchParams(window.location.search).get('join');
    if (code) {
      sessionStorage.setItem('pending-invite', code);
      window.history.replaceState({}, '', window.location.pathname);
      return code;
    }
    return sessionStorage.getItem('pending-invite') || null;
  });

  const [syncedOnce, setSyncedOnce] = useState(false);

  // Auto-sync from cloud when user signs in
  useEffect(() => {
    if (!user || !data.loaded) return;
    let cancelled = false;
    (async () => {
      setSyncing(true);
      try {
        await pullFromCloud(user.id);
        if (!cancelled) await data.reload();
      } catch (err) {
        console.error('Auto-sync failed:', err);
      } finally {
        if (!cancelled) {
          setSyncing(false);
          setSyncedOnce(true);
        }
      }
    })();
    return () => { cancelled = true; };
  }, [user?.id, data.loaded]); // eslint-disable-line react-hooks/exhaustive-deps

  // Show onboarding for new users who haven't completed it and have no weight data
  // Wait until cloud sync finishes so we don't falsely show it to returning users
  const checkOnboarding = useCallback(() => {
    if (user && data.loaded && syncedOnce && data.weights.length === 0 && !localStorage.getItem('steady-onboarding-done')) {
      setShowOnboarding(true);
    }
  }, [user, data.loaded, syncedOnce, data.weights.length]);

  // Run check when data loads
  useEffect(() => { checkOnboarding(); }, [checkOnboarding]);

  // Auto-navigate to circle if invite code in URL
  useEffect(() => {
    if (pendingInvite && user) navigate('circle');
  }, [pendingInvite, user, navigate]);

  const completeOnboarding = useCallback(() => {
    localStorage.setItem('steady-onboarding-done', '1');
    setShowOnboarding(false);
  }, []);

  const toastTimerRef = React.useRef(null);
  const visitedViews = useRef(new Set(['dashboard']));

  const showToast = useCallback((message, type = 'success') => {
    if (toastTimerRef.current) clearTimeout(toastTimerRef.current);
    setToast({ message, type, key: Date.now() });
    toastTimerRef.current = setTimeout(() => setToast(null), 3000);
  }, []);

  const handleSync = useCallback(async () => {
    if (!user) return;
    setSyncing(true);
    try {
      await syncData(user.id);
      await data.reload();
      showToast('Synced successfully');
    } catch (err) {
      showToast('Sync failed: ' + err.message, 'error');
    } finally {
      setSyncing(false);
    }
  }, [user, data, showToast]);

  const changeUnit = useCallback((u) => {
    setUnit(u);
    localStorage.setItem('steady-unit', u);
  }, []);

  const displayName = user?.user_metadata?.display_name || user?.email?.split('@')[0] || 'User';

  const dataValue = useMemo(() => ({
    user,
    displayName,
    weights: data.weights,
    goals: data.goals,
    loaded: data.loaded,
    syncing,
    unit,
    view,
    pendingInvite
  }), [user, displayName, data.weights, data.goals, data.loaded, syncing, unit, view, pendingInvite]);

  const actionsValue = useMemo(() => ({
    navigate,
    goBack,
    signUp,
    signIn,
    signOut,
    addWeight: data.addWeight,
    updateWeight: data.updateWeight,
    removeWeight: data.removeWeight,
    addGoal: data.addGoal,
    removeGoal: data.removeGoal,
    reload: data.reload,
    sync: handleSync,
    showToast,
    changeUnit,
    clearPendingInvite: () => { sessionStorage.removeItem('pending-invite'); setPendingInvite(null); }
  }), [navigate, goBack, signUp, signIn, signOut, data, handleSync, showToast, changeUnit]);

  if (authLoading) {
    return (
      <div className="min-h-screen bg-surface flex items-center justify-center">
        <div className="text-center">
          <h1 className="font-logo text-4xl font-extrabold text-accent">steady</h1>
          <p className="text-cream/40 mt-2 font-body text-sm">Loading...</p>
        </div>
      </div>
    );
  }

  if (!user) {
    return (
      <AppActionsContext.Provider value={actionsValue}>
        <AuthView />
        {toast && <Toast key={toast.key} message={toast.message} type={toast.type} />}
      </AppActionsContext.Provider>
    );
  }

  if (view) visitedViews.current.add(view);

  const VIEW_COMPONENTS = {
    dashboard: Dashboard,
    log: LogWeight,
    history: History,
    goals: Goals,
    circle: Circle,
    settings: Settings,
  };

  const renderViews = () => {
    return Array.from(visitedViews.current).map(v => {
      const Component = VIEW_COMPONENTS[v];
      if (!Component) return null;
      return (
        <div key={v} style={{ display: v === view ? 'block' : 'none' }}>
          <ErrorBoundary>
            <Component />
          </ErrorBoundary>
        </div>
      );
    });
  };

  if (showOnboarding) {
    return (
      <AppDataContext.Provider value={dataValue}>
        <AppActionsContext.Provider value={actionsValue}>
          <Onboarding onComplete={completeOnboarding} />
          {toast && <Toast key={toast.key} message={toast.message} type={toast.type} />}
        </AppActionsContext.Provider>
      </AppDataContext.Provider>
    );
  }

  return (
    <AppDataContext.Provider value={dataValue}>
      <AppActionsContext.Provider value={actionsValue}>
        <Layout>
          {!data.loaded ? (
            <div className="flex items-center justify-center min-h-[60vh]">
              <div className="animate-pulse-accent text-accent font-display text-3xl">Loading data...</div>
            </div>
          ) : (
            <div className="animate-fade-in">
              {renderViews()}
            </div>
          )}
        </Layout>
        <OfflineBanner />
        {toast && <Toast key={toast.key} message={toast.message} type={toast.type} />}
      </AppActionsContext.Provider>
    </AppDataContext.Provider>
  );
}
