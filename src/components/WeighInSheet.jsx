import React, { useState, useMemo, useEffect, useRef } from 'react';
import { useAppData, useAppActions } from '../App';
import { todayStr, isValidWeight, sanitizeText } from '../utils';

export default function WeighInSheet({ onClose, onSuccess }) {
  const { unit, weights } = useAppData();
  const { addWeight, showToast } = useAppActions();
  const [weight, setWeight] = useState('');
  const [date, setDate] = useState(todayStr());
  const [notes, setNotes] = useState('');
  const [isMorning, setIsMorning] = useState(false);
  const [saving, setSaving] = useState(false);
  const [visible, setVisible] = useState(false);
  const backdropRef = useRef(null);

  const lastWeight = weights[0]?.weight;

  useEffect(() => {
    requestAnimationFrame(() => setVisible(true));
  }, []);

  const hasMorningForDate = useMemo(() => {
    return weights.some(w => w.date === date && w.isMorning);
  }, [weights, date]);

  const close = () => {
    setVisible(false);
    setTimeout(onClose, 300);
  };

  const handleBackdropClick = (e) => {
    if (e.target === backdropRef.current) close();
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!weight || isNaN(weight)) {
      showToast('Enter a valid weight', 'error');
      return;
    }
    if (!isValidWeight(weight, unit)) {
      showToast(`Weight must be between ${unit === 'kg' ? '0.5–680' : '1–1500'} ${unit}`, 'error');
      return;
    }
    if (isMorning && hasMorningForDate) {
      showToast('Morning weight already logged for this date', 'error');
      return;
    }
    setSaving(true);
    try {
      await addWeight(weight, unit, date, sanitizeText(notes), isMorning);
      setVisible(false);
      setTimeout(() => {
        onSuccess({ weight: Number(weight), unit, date, isMorning });
      }, 300);
    } catch {
      showToast('Failed to save', 'error');
    } finally {
      setSaving(false);
    }
  };

  const diff = lastWeight && weight ? (Number(weight) - lastWeight) : null;

  return (
    <div
      ref={backdropRef}
      onClick={handleBackdropClick}
      className="fixed inset-0 z-[80] flex items-end justify-center"
      style={{
        backgroundColor: visible ? 'rgba(0,0,0,0.4)' : 'transparent',
        transition: 'background-color 0.3s',
      }}
    >
      <div
        className="w-full max-w-lg bg-surface-mid rounded-t-2xl shadow-xl overflow-hidden"
        style={{
          transform: visible ? 'translateY(0)' : 'translateY(100%)',
          transition: 'transform 0.3s cubic-bezier(0.32, 0.72, 0, 1)',
        }}
      >
        {/* Handle bar */}
        <div className="flex justify-center pt-3 pb-2">
          <div className="w-10 h-1 rounded-full bg-cream/20" />
        </div>

        <form onSubmit={handleSubmit} className="px-6 pb-8 safe-bottom">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h2 className="font-heading text-xl font-bold text-cream">Weigh In</h2>
              <p className="text-cream/50 text-sm">Every check-in is progress!</p>
            </div>
            <button
              type="button"
              onClick={close}
              className="p-2 -mr-2 text-cream/40 hover:text-cream transition-colors"
            >
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <line x1="18" y1="6" x2="6" y2="18" />
                <line x1="6" y1="6" x2="18" y2="18" />
              </svg>
            </button>
          </div>

          {/* Weight input */}
          <div className="bg-surface rounded-sm px-4 py-5 border border-black/5 text-center mb-3 shadow-soft">
            <input
              type="text"
              inputMode="decimal"
              pattern="[0-9.]*"
              value={weight}
              onChange={e => setWeight(e.target.value)}
              placeholder={lastWeight ? lastWeight.toFixed(1) : '0.0'}
              className="bg-transparent border-none text-center font-display text-5xl font-bold text-cream w-full focus:ring-0 focus:outline-none"
              autoFocus
            />
            <p className="text-cream/40 text-xs mt-1">{unit}</p>
            {diff !== null && (
              <p className={`text-sm font-medium mt-1 ${diff < 0 ? 'text-success' : diff > 0 ? 'text-danger' : 'text-cream/40'}`}>
                {diff > 0 ? '+' : ''}{diff.toFixed(1)} {unit} from last
                {diff < 0 && ' — nice!'}
              </p>
            )}
          </div>

          {/* Slider */}
          {lastWeight && (
            <div className="bg-surface rounded-sm px-4 py-3 border border-black/5 mb-3 shadow-soft">
              <div className="flex justify-between text-xs text-cream/50 mb-1">
                <span>{(lastWeight - 3).toFixed(1)}</span>
                <span className="text-cream/70 font-semibold">{weight || lastWeight.toFixed(1)} {unit}</span>
                <span>{(lastWeight + 3).toFixed(1)}</span>
              </div>
              <input
                type="range"
                min={(lastWeight - 3).toFixed(1)}
                max={(lastWeight + 3).toFixed(1)}
                step="0.1"
                value={weight || lastWeight}
                onChange={e => setWeight(Number(e.target.value).toFixed(1))}
                className="w-full"
              />
            </div>
          )}

          {/* Options row */}
          <div className="flex gap-3 mb-3">
            {/* Morning toggle */}
            <div className="flex-1 bg-surface rounded-sm px-4 py-3 border border-black/5 shadow-soft">
              <label className="flex items-center gap-2.5 cursor-pointer select-none">
                <div className="relative">
                  <input
                    type="checkbox"
                    checked={isMorning}
                    onChange={e => setIsMorning(e.target.checked)}
                    disabled={hasMorningForDate && !isMorning}
                    className="sr-only peer"
                  />
                  <div className="w-9 h-5 bg-surface-up rounded-full border border-black/10 peer-checked:bg-accent peer-checked:border-accent transition-colors" />
                  <div className="absolute top-0.5 left-0.5 w-4 h-4 bg-white rounded-full shadow peer-checked:translate-x-4 transition-transform" />
                </div>
                <div>
                  <span className="text-cream text-sm font-medium">Morning</span>
                  {hasMorningForDate && !isMorning && (
                    <p className="text-accent text-xs">Already logged</p>
                  )}
                </div>
              </label>
            </div>

            {/* Date */}
            <div className="flex-1 bg-surface rounded-sm px-4 py-3 border border-black/5 shadow-soft">
              <label className="block text-cream/50 text-xs mb-1">Date</label>
              <input
                type="date"
                value={date}
                onChange={e => setDate(e.target.value)}
                max={todayStr()}
                className="w-full bg-transparent border-none text-cream text-sm p-0 focus:ring-0 focus:outline-none"
              />
            </div>
          </div>

          {/* Notes */}
          <div className="bg-surface rounded-sm px-4 py-3 border border-black/5 mb-4 shadow-soft">
            <input
              type="text"
              value={notes}
              onChange={e => setNotes(e.target.value)}
              placeholder="How are you feeling?"
              maxLength={200}
              className="w-full bg-transparent border-none text-cream text-sm p-0 focus:ring-0 focus:outline-none placeholder:text-cream/30"
            />
          </div>

          {/* Submit */}
          <button
            type="submit"
            disabled={saving}
            className="w-full bg-accent hover:bg-accent-dark text-white font-bold py-3.5 rounded-sm transition-all disabled:opacity-50 shadow-soft hover:shadow-glow active:scale-[0.98] text-base"
          >
            {saving ? 'Saving...' : 'Log It!'}
          </button>
        </form>
      </div>
    </div>
  );
}
