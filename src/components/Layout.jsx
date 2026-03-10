import React from 'react';
import { useAppData, useAppActions } from '../App';

const NAV = [
  { id: 'dashboard', label: 'Home', Icon: HomeIcon },
  { id: 'progress', label: 'Progress', Icon: ChartIcon },
  { id: '_fab', label: '', Icon: null }, // FAB placeholder for spacing
  { id: 'circle', label: 'Friends', Icon: UsersIcon },
  { id: 'profile', label: 'Profile', Icon: ProfileIcon },
];

const SIDEBAR_NAV = [
  { id: 'dashboard', label: 'Home', Icon: HomeIcon },
  { id: 'progress', label: 'Progress', Icon: ChartIcon },
  { id: 'circle', label: 'Friends', Icon: UsersIcon },
  { id: 'profile', label: 'Profile', Icon: ProfileIcon },
];

export default function Layout({ children }) {
  const { view } = useAppData();
  const { navigate, openWeighIn } = useAppActions();

  return (
    <div className="fixed top-0 left-0 right-0 bottom-0 h-[100dvh] flex flex-col desktop:flex-row bg-surface overscroll-none touch-manipulation">
      {/* Desktop Sidebar */}
      <aside className="hidden desktop:flex desktop:flex-col desktop:w-60 desktop:shrink-0 bg-surface-mid border-r border-black/[0.06] z-40 shadow-soft">
        <div className="p-6 border-b border-black/[0.06]">
          <span className="font-logo text-2xl font-extrabold text-accent" aria-label="Steady">
            steady
          </span>
          <p className="text-xs text-muted mt-1.5" aria-hidden="true">Your weight, your way</p>
        </div>

        {/* Desktop Weigh In Button */}
        <div className="px-4 py-4">
          <button
            onClick={openWeighIn}
            className="w-full bg-accent hover:bg-accent-dark text-white font-bold py-3 rounded-sm transition-all shadow-soft hover:shadow-glow active:scale-[0.98] flex items-center justify-center gap-2"
          >
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
              <line x1="12" y1="5" x2="12" y2="19" />
              <line x1="5" y1="12" x2="19" y2="12" />
            </svg>
            Weigh In
          </button>
        </div>

        <nav className="flex-1 py-1" aria-label="Primary">
          {SIDEBAR_NAV.map(({ id, label, Icon }) => (
            <button
              key={id}
              onClick={() => navigate(id)}
              aria-current={view === id ? 'page' : undefined}
              className={`w-full flex items-center gap-3 px-6 py-3 text-sm transition-all ${
                view === id ? 'text-accent bg-accent/[0.08] font-semibold border-r-2 border-accent' : 'text-cream/60 hover:text-cream hover:bg-black/[0.03]'
              }`}
            >
              <Icon className="w-5 h-5" />
              {label}
            </button>
          ))}
        </nav>
      </aside>

      {/* Mobile Header */}
      <header className="desktop:hidden shrink-0 bg-surface-mid border-b border-black/[0.06] safe-top shadow-soft">
        <div className="flex items-center justify-center px-5 h-12">
          <span className="font-logo text-xl font-extrabold text-accent" aria-label="Steady">
            steady
          </span>
        </div>
      </header>

      {/* Main Content */}
      <main className="flex-1 min-h-0 overflow-y-auto overflow-x-hidden overscroll-contain bg-surface">
        <div className="max-w-[1400px] mx-auto px-5 desktop:px-8 py-5 desktop:py-6">
          {children}
        </div>
      </main>

      {/* Mobile Bottom Nav + FAB */}
      <nav className="desktop:hidden shrink-0 bg-surface-mid border-t border-black/[0.06] nav-extend-bottom shadow-[0_-2px_8px_rgba(0,0,0,0.04)]" aria-label="Primary">
        <div className="flex relative" style={{ height: '56px' }}>
          {NAV.map(({ id, label, Icon }) => {
            if (id === '_fab') {
              return (
                <div key={id} className="flex-1 relative">
                  {/* FAB Button */}
                  <button
                    onClick={openWeighIn}
                    className="absolute left-1/2 -translate-x-1/2 -top-5 w-14 h-14 bg-accent hover:bg-accent-dark rounded-full shadow-lg flex items-center justify-center transition-all active:scale-90 hover:shadow-glow z-10"
                    aria-label="Weigh In"
                  >
                    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                      <line x1="12" y1="5" x2="12" y2="19" />
                      <line x1="5" y1="12" x2="19" y2="12" />
                    </svg>
                  </button>
                </div>
              );
            }

            return (
              <button
                key={id}
                onClick={() => navigate(id)}
                aria-label={label}
                aria-current={view === id ? 'page' : undefined}
                className={`relative flex-1 flex flex-col items-center justify-center gap-1 leading-none transition-all min-h-[48px] ${
                  view === id ? 'text-accent' : 'text-cream/40'
                }`}
              >
                {view === id && (
                  <span className="absolute top-0 left-1/2 -translate-x-1/2 w-8 h-[3px] bg-accent rounded-full" />
                )}
                <Icon className={`w-5 h-5 transition-transform ${view === id ? 'scale-110' : ''}`} />
                <span className={`text-[11px] ${view === id ? 'font-semibold' : ''}`}>{label}</span>
              </button>
            );
          })}
        </div>
      </nav>
    </div>
  );
}

/* ─── Nav Icons ─── */

function HomeIcon({ className }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z" />
      <polyline points="9 22 9 12 15 12 15 22" />
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

function ProfileIcon({ className }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M20 21v-2a4 4 0 00-4-4H8a4 4 0 00-4-4v2" />
      <circle cx="12" cy="7" r="4" />
    </svg>
  );
}
