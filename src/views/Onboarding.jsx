import React, { useState, useRef, useCallback, useEffect } from 'react';

const SLIDES = [
  {
    key: 'install',
    Icon: InstallIcon,
    title: 'Make It Yours',
    body: 'Add Steady to your home screen for the best experience. It works just like a native app!',
    hint: 'iOS: Safari \u2192 Share \u2192 Add to Home Screen\nAndroid: Chrome \u2192 Menu \u2192 Add to Home Screen',
  },
  {
    key: 'log',
    Icon: ScaleIcon,
    title: 'Step On, Log In',
    body: 'Just tap "Weigh In" and enter your number. Toggle "Morning Weight" for the most accurate tracking.',
    hint: 'Pro tip: Same time each morning = best results!',
  },
  {
    key: 'chart',
    Icon: ChartIcon,
    title: 'Watch Your Progress',
    body: 'Your dashboard shows your weight trend with a smooth 7-day average. You can also view daily ranges in candlestick mode!',
    hint: 'Remember: focus on the trend, not daily ups and downs!',
  },
  {
    key: 'goals',
    Icon: TargetIcon,
    title: 'Dream Big',
    body: 'Set your target weight and pick a date. We\'ll track your progress and celebrate every milestone along the way!',
    hint: null,
  },
  {
    key: 'circle',
    Icon: CircleIcon,
    title: 'Better Together',
    body: 'Create or join a circle with friends. Share your wins, cheer each other on, and stay motivated together!',
    hint: null,
  },
];

export default function Onboarding({ onComplete }) {
  const [current, setCurrent] = useState(0);
  const containerRef = useRef(null);
  const touchStartX = useRef(0);
  const touchDeltaX = useRef(0);
  const [dragging, setDragging] = useState(false);

  const goTo = useCallback((idx) => {
    setCurrent(Math.max(0, Math.min(SLIDES.length - 1, idx)));
  }, []);

  const handleTouchStart = (e) => {
    touchStartX.current = e.touches[0].clientX;
    touchDeltaX.current = 0;
    setDragging(true);
  };

  const handleTouchMove = (e) => {
    touchDeltaX.current = e.touches[0].clientX - touchStartX.current;
  };

  const handleTouchEnd = () => {
    setDragging(false);
    if (touchDeltaX.current < -50) goTo(current + 1);
    else if (touchDeltaX.current > 50) goTo(current - 1);
    touchDeltaX.current = 0;
  };

  const isLast = current === SLIDES.length - 1;
  const slide = SLIDES[current];

  return (
    <div className="min-h-screen bg-surface flex flex-col">
      {/* Skip button */}
      <div className="flex justify-end p-4 safe-top">
        <button
          onClick={onComplete}
          className="text-cream/50 text-xs uppercase tracking-wider hover:text-cream/60 transition-colors"
        >
          Skip
        </button>
      </div>

      {/* Slide area */}
      <div
        className="flex-1 flex flex-col items-center justify-center px-8 select-none"
        onTouchStart={handleTouchStart}
        onTouchMove={handleTouchMove}
        onTouchEnd={handleTouchEnd}
        ref={containerRef}
      >
        {/* Icon */}
        <div className="w-24 h-24 rounded-2xl bg-accent/10 border border-accent/20 flex items-center justify-center mb-8">
          <slide.Icon />
        </div>

        {/* Title */}
        <h2 className="font-heading text-3xl font-bold text-cream text-center mb-3">
          {slide.title}
        </h2>

        {/* Body */}
        <p className="text-cream/70 text-center font-body text-base leading-relaxed max-w-sm">
          {slide.body}
        </p>

        {/* Hint */}
        {slide.hint && (
          <div className="mt-4 bg-surface-mid rounded-sm px-4 py-3 border border-black/5 max-w-sm w-full shadow-sm">
            <p className="text-cream/60 text-xs font-body whitespace-pre-line">{slide.hint}</p>
          </div>
        )}
      </div>

      {/* Bottom controls */}
      <div className="px-8 pb-8 safe-bottom">
        {/* Dots */}
        <div className="flex justify-center gap-2 mb-6">
          {SLIDES.map((_, i) => (
            <button
              key={i}
              onClick={() => goTo(i)}
              className={`h-1.5 rounded-full transition-all ${
                i === current ? 'w-6 bg-accent' : 'w-2 bg-cream/30'
              }`}
              aria-label={`Go to slide ${i + 1}`}
            />
          ))}
        </div>

        {/* Action buttons */}
        <div className="flex gap-3">
          {current > 0 && (
            <button
              onClick={() => goTo(current - 1)}
              className="flex-1 border border-black/10 text-cream/60 font-heading font-bold uppercase tracking-wider py-3.5 rounded-sm transition-colors hover:border-black/20 text-sm"
            >
              Back
            </button>
          )}
          <button
            onClick={isLast ? onComplete : () => goTo(current + 1)}
            className="flex-1 bg-accent hover:bg-accent-dark text-white font-heading font-bold uppercase tracking-wider py-3.5 rounded-sm transition-colors text-sm shadow-sm"
          >
            {isLast ? "Let's Go!" : 'Next'}
          </button>
        </div>
      </div>
    </div>
  );
}

/* --- Slide Icons --- */

function InstallIcon() {
  return (
    <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" className="text-accent">
      <path d="M12 5v10M8 11l4 4 4-4" />
      <path d="M4 17v2a2 2 0 002 2h12a2 2 0 002-2v-2" />
    </svg>
  );
}

function ScaleIcon() {
  return (
    <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" className="text-accent">
      <path d="M12 3v17M5 8l7-5 7 5" />
      <rect x="4" y="14" width="16" height="6" rx="1" />
    </svg>
  );
}

function ChartIcon() {
  return (
    <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" className="text-accent">
      <polyline points="22 12 18 12 15 21 9 3 6 12 2 12" />
    </svg>
  );
}

function TargetIcon() {
  return (
    <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" className="text-accent">
      <circle cx="12" cy="12" r="10" />
      <circle cx="12" cy="12" r="6" />
      <circle cx="12" cy="12" r="2" />
    </svg>
  );
}

function CircleIcon() {
  return (
    <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" className="text-accent">
      <path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2" />
      <circle cx="9" cy="7" r="4" />
      <path d="M23 21v-2a4 4 0 00-3-3.87" />
      <path d="M16 3.13a4 4 0 010 7.75" />
    </svg>
  );
}
