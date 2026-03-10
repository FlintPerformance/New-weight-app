import React from 'react';

export default function UpdateBanner({ onUpdate }) {
  return (
    <div className="fixed top-0 left-0 right-0 z-[110] desktop:left-56 animate-slide-up">
      <div className="bg-surface-mid border-b border-accent/20 px-4 py-3 flex items-center justify-between max-w-lg desktop:max-w-none mx-auto shadow-sm">
        <div className="flex items-center gap-2">
          <div className="w-2 h-2 rounded-full bg-accent animate-pulse-accent"></div>
          <span className="text-cream text-sm font-medium">A new version is available</span>
        </div>
        <button
          onClick={onUpdate}
          className="bg-accent hover:bg-accent-dark text-white px-3 py-1.5 rounded-sm text-xs font-semibold transition-colors"
        >
          Update
        </button>
      </div>
    </div>
  );
}
