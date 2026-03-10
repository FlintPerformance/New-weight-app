import React, { useState, useMemo } from 'react';
import { useAppData, useAppActions } from '../App';
import { todayStr, isValidWeight, sanitizeText } from '../utils';

export default function LogWeight() {
  const { unit, weights } = useAppData();
  const { addWeight, navigate, showToast } = useAppActions();
  const [weight, setWeight] = useState('');
  const [date, setDate] = useState(todayStr());
  const [notes, setNotes] = useState('');
  const [isMorning, setIsMorning] = useState(false);
  const [saving, setSaving] = useState(false);

  const lastWeight = weights[0]?.weight;

  const hasMorningForDate = useMemo(() => {
    return weights.some(w => w.date === date && w.isMorning);
  }, [weights, date]);

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
      showToast('Logged! Keep it up!');
      navigate('dashboard');
    } catch {
      showToast('Failed to save', 'error');
    } finally {
      setSaving(false);
    }
  };

  const diff = lastWeight && weight ? (Number(weight) - lastWeight) : null;

  return (
    <div className="max-w-xl">
      <div className="mb-5">
        <h1 className="font-heading text-2xl font-bold text-cream">Weigh In</h1>
        <p className="text-cream/50 text-sm mt-1">Every check-in is progress. You got this!</p>
      </div>

      <form onSubmit={handleSubmit} className="space-y-3">
        {/* Weight Input */}
        <div className="bg-surface-mid rounded-sm px-5 py-5 border border-black/5 text-center shadow-card">
          <label className="block text-cream/60 text-xs font-medium mb-2">Weight ({unit})</label>
          <input
            type="text"
            inputMode="decimal"
            pattern="[0-9.]*"
            value={weight}
            onChange={e => setWeight(e.target.value)}
            placeholder={lastWeight ? lastWeight.toFixed(1) : '0.0'}
            className="bg-transparent border-none text-center font-display text-5xl font-bold text-cream w-full focus:ring-0 focus:outline-none"
          />
          {diff !== null && (
            <p className={`text-sm font-medium mt-2 ${diff < 0 ? 'text-success' : diff > 0 ? 'text-danger' : 'text-cream/40'}`}>
              {diff > 0 ? '+' : ''}{diff.toFixed(1)} {unit} from last
              {diff < 0 && ' — nice!'}
            </p>
          )}
        </div>

        {/* Weight Slider */}
        {lastWeight && (
          <div className="bg-surface-mid rounded-sm px-5 py-4 border border-black/5 shadow-soft">
            <div className="flex justify-between text-xs text-cream/50 mb-2">
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

        {/* Morning Weight Toggle */}
        <div className="bg-surface-mid rounded-sm px-5 py-4 border border-black/5 shadow-soft">
          <label className="flex items-center gap-3 cursor-pointer select-none">
            <div className="relative">
              <input
                type="checkbox"
                checked={isMorning}
                onChange={e => setIsMorning(e.target.checked)}
                disabled={hasMorningForDate && !isMorning}
                className="sr-only peer"
              />
              <div className="w-10 h-[22px] bg-surface-up rounded-full border border-black/10 peer-checked:bg-accent peer-checked:border-accent transition-colors" />
              <div className="absolute top-0.5 left-0.5 w-[18px] h-[18px] bg-white rounded-full shadow peer-checked:translate-x-[18px] transition-transform" />
            </div>
            <div className="flex-1">
              <span className="text-cream text-sm font-semibold">Morning Weight</span>
              <p className="text-cream/50 text-xs mt-0.5">Best for tracking your true trend</p>
            </div>
            {hasMorningForDate && !isMorning && (
              <span className="text-accent text-xs font-medium">Already logged</span>
            )}
          </label>
        </div>

        {/* Date & Notes row */}
        <div className="grid grid-cols-2 gap-3">
          <div className="bg-surface-mid rounded-sm px-5 py-4 border border-black/5 shadow-soft">
            <label className="block text-cream/60 text-xs font-medium mb-2">Date</label>
            <input
              type="date"
              value={date}
              onChange={e => setDate(e.target.value)}
              max={todayStr()}
              className="w-full bg-transparent border-none text-cream text-sm p-0 focus:ring-0 focus:outline-none"
            />
          </div>
          <div className="bg-surface-mid rounded-sm px-5 py-4 border border-black/5 shadow-soft">
            <label className="block text-cream/60 text-xs font-medium mb-2">Notes</label>
            <input
              type="text"
              value={notes}
              onChange={e => setNotes(e.target.value)}
              placeholder="How are you feeling?"
              maxLength={200}
              className="w-full bg-transparent border-none text-cream text-sm p-0 focus:ring-0 focus:outline-none placeholder:text-cream/30"
            />
          </div>
        </div>

        <button
          type="submit"
          disabled={saving}
          className="w-full bg-accent hover:bg-accent-dark text-white font-bold py-3.5 rounded-sm transition-all disabled:opacity-50 shadow-soft hover:shadow-glow active:scale-[0.98] text-base"
        >
          {saving ? 'Saving...' : 'Log It!'}
        </button>
      </form>
    </div>
  );
}
