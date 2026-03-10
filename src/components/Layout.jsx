import React from 'react';
import { useAppData, useAppActions } from '../App';

const NAV = [
  { id: 'dashboard', label: 'Home', Icon: DashboardIcon },
  { id: 'log', label: 'Log', Icon: PlusIcon },
  { id: 'history', label: 'History', Icon: ChartIcon },
  { id: 'goals', label: 'Goals', Icon: TargetIcon },
  { id: 'circle', label: 'Circle', Icon: UsersIcon },
];

export default function Layout({ children }) {
  const { view } = useAppData();
  const { navigate } = useAppActions();

  return (
    <div className="fixed top-0 left-0 right-0 bottom-0 h-[100dvh] flex flex-col desktop:flex-row bg-surface overscroll-none touch-manipulation">
      {/* Desktop Sidebar */}
      <aside className="hidden desktop:flex desktop:flex-col desktop:w-56 desktop:shrink-0 bg-surface-mid border-r border-black/[0.06] z-40 shadow-sm">
        <div className="p-5 border-b border-black/[0.06]">
          <span className="font-logo text-2xl font-extrabold text-accent" aria-label="Steady">
            steady
          </span>
          <p className="text-[10px] uppercase tracking-[0.2em] text-muted mt-1" aria-hidden="true">Weight Tracker</p>
        </div>
        <nav className="flex-1 py-4" aria-label="Primary">
          {NAV.map(({ id, label, Icon }) => (
            <button
              key={id}
              onClick={() => navigate(id)}
              aria-current={view === id ? 'page' : undefined}
              className={`w-full flex items-center gap-3 px-5 py-2.5 text-sm transition-colors ${
                view === id ? 'text-accent bg-accent/[0.08] font-semibold' : 'text-muted hover:text-cream hover:bg-black/[0.03]'
              }`}
            >
              <Icon className="w-[18px] h-[18px]" />
              {label}
            </button>
          ))}
        </nav>
        <div className="border-t border-black/[0.06]">
          <button
            onClick={() => navigate('settings')}
            aria-current={view === 'settings' ? 'page' : undefined}
            className={`w-full flex items-center gap-3 px-5 py-3 text-sm transition-colors ${
              view === 'settings' ? 'text-accent bg-accent/[0.08] font-semibold' : 'text-muted hover:text-cream hover:bg-black/[0.03]'
            }`}
          >
            <GearIcon className="w-[18px] h-[18px]" />
            Settings
          </button>
        </div>
      </aside>

      {/* Mobile Header */}
      <header className="desktop:hidden shrink-0 bg-surface-mid border-b border-black/[0.06] safe-top shadow-sm">
        <div className="flex items-center justify-between px-4 h-11">
          <span className="font-logo text-xl font-extrabold text-accent" aria-label="Steady">
            steady
          </span>
          <button
            onClick={() => navigate('settings')}
            aria-label="Settings"
            aria-current={view === 'settings' ? 'page' : undefined}
            className={`p-2 -mr-1 transition-colors ${view === 'settings' ? 'text-accent' : 'text-muted hover:text-cream'}`}
          >
            <GearIcon className="w-5 h-5" />
          </button>
        </div>
      </header>

      {/* Main Content */}
      <main className="flex-1 min-h-0 overflow-y-auto overflow-x-hidden overscroll-contain bg-surface">
        <div className="max-w-[1400px] mx-auto px-4 desktop:px-8 py-4 desktop:py-6">
          {children}
        </div>
      </main>

      {/* Mobile Bottom Nav */}
      <nav className="desktop:hidden shrink-0 bg-surface-mid border-t border-black/[0.06] nav-extend-bottom shadow-[0_-1px_3px_rgba(0,0,0,0.05)]" aria-label="Primary">
        <div className="flex" style={{ height: '50px' }}>
          {NAV.map(({ id, label, Icon }) => (
            <button
              key={id}
              onClick={() => navigate(id)}
              aria-label={label}
              aria-current={view === id ? 'page' : undefined}
              className={`relative flex-1 flex flex-col items-center justify-center gap-0.5 leading-none transition-colors min-h-[44px] ${
                view === id ? 'text-accent' : 'text-muted'
              }`}
            >
              {view === id && (
                <span className="absolute top-0 left-1/2 -translate-x-1/2 w-5 h-0.5 bg-accent rounded-full" />
              )}
              <Icon className="w-5 h-5" />
              <span className="text-[10px]">{label}</span>
            </button>
          ))}
        </div>
      </nav>
    </div>
  );
}

function DashboardIcon({ className }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <rect x="3" y="3" width="7" height="9" rx="1" />
      <rect x="14" y="3" width="7" height="5" rx="1" />
      <rect x="3" y="16" width="7" height="5" rx="1" />
      <rect x="14" y="12" width="7" height="9" rx="1" />
    </svg>
  );
}

function PlusIcon({ className }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="12" r="10" />
      <line x1="12" y1="8" x2="12" y2="16" />
      <line x1="8" y1="12" x2="16" y2="12" />
    </svg>
  );
}

function ChartIcon({ className }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <polyline points="22 12 18 12 15 21 9 3 6 12 2 12" />
    </svg>
  );
}

function TargetIcon({ className }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="12" r="10" />
      <circle cx="12" cy="12" r="6" />
      <circle cx="12" cy="12" r="2" />
    </svg>
  );
}

function UsersIcon({ className }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4-4v2" />
      <circle cx="9" cy="7" r="4" />
      <path d="M23 21v-2a4 4 0 00-3-3.87" />
      <path d="M16 3.13a4 4 0 010 7.75" />
    </svg>
  );
}

function GearIcon({ className }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="12" r="3" />
      <path d="M19.4 15a1.65 1.65 0 00.33 1.82l.06.06a2 2 0 010 2.83 2 2 0 01-2.83 0l-.06-.06a1.65 1.65 0 00-1.82-.33 1.65 1.65 0 00-1 1.51V21a2 2 0 01-4 0v-.09A1.65 1.65 0 009 19.4a1.65 1.65 0 00-1.82.33l-.06.06a2 2 0 01-2.83 0 2 2 0 010-2.83l.06-.06A1.65 1.65 0 004.68 15a1.65 1.65 0 00-1.51-1H3a2 2 0 010-4h.09A1.65 1.65 0 004.6 9a1.65 1.65 0 00-.33-1.82l-.06-.06a2 2 0 012.83-2.83l.06.06A1.65 1.65 0 009 4.68a1.65 1.65 0 001-1.51V3a2 2 0 014 0v.09a1.65 1.65 0 001 1.51 1.65 1.65 0 001.82-.33l.06-.06a2 2 0 012.83 2.83l-.06.06A1.65 1.65 0 0019.4 9a1.65 1.65 0 001.51 1H21a2 2 0 010 4h-.09a1.65 1.65 0 00-1.51 1z" />
    </svg>
  );
}
