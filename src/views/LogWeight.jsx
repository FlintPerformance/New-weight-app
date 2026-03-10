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
      showToast('Weight logged!');
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
      <h1 className="font-heading text-xl font-bold text-cream mb-3">Log Weight</h1>

      <form onSubmit={handleSubmit} className="space-y-2">
        {/* Weight Input */}
        <div className="bg-surface-mid rounded-sm px-4 py-3 border border-black/5 text-center shadow-sm">
          <label className="block text-cream/50 text-xs uppercase tracking-wider mb-1">Weight ({unit})</label>
          <input
            type="text"
            inputMode="decimal"
            pattern="[0-9.]*"
            value={weight}
            onChange={e => setWeight(e.target.value)}
            placeholder={lastWeight ? lastWeight.toFixed(1) : '0.0'}
            className="bg-transparent border-none text-center font-display text-4xl font-bold text-cream w-full focus:ring-0 focus:outline-none"
          />
          {diff !== null && (
            <p className={`text-xs mt-1 ${diff < 0 ? 'text-success' : diff > 0 ? 'text-danger' : 'text-cream/40'}`}>
              {diff > 0 ? '+' : ''}{diff.toFixed(1)} {unit} from last
            </p>
          )}
        </div>

        {/* Weight Slider */}
        {lastWeight && (
          <div className="bg-surface-mid rounded-sm px-4 py-3 border border-black/5 shadow-sm">
            <div className="flex justify-between text-xs text-cream/40 mb-1.5">
              <span>{(lastWeight - 3).toFixed(1)}</span>
              <span className="text-cream/60 font-medium">{weight || lastWeight.toFixed(1)} {unit}</span>
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
        <div className="bg-surface-mid rounded-sm px-4 py-3 border border-black/5 shadow-sm">
          <label className="flex items-center gap-3 cursor-pointer select-none">
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
            <div className="flex-1">
              <span className="text-cream text-sm font-medium">Morning Weight</span>
              <p className="text-cream/40 text-xs mt-0.5">Used for progress tracking &amp; charts</p>
            </div>
            {hasMorningForDate && !isMorning && (
              <span className="text-accent text-[10px] uppercase tracking-wider">Already logged</span>
            )}
          </label>
        </div>

        {/* Date & Notes row */}
        <div className="grid grid-cols-2 gap-2">
          <div className="bg-surface-mid rounded-sm px-4 py-3 border border-black/5 shadow-sm">
            <label className="block text-cream/50 text-xs uppercase tracking-wider mb-1.5">Date</label>
            <input
              type="date"
              value={date}
              onChange={e => setDate(e.target.value)}
              max={todayStr()}
              className="w-full bg-transparent border-none text-cream text-sm p-0 focus:ring-0 focus:outline-none"
            />
          </div>
          <div className="bg-surface-mid rounded-sm px-4 py-3 border border-black/5 shadow-sm">
            <label className="block text-cream/50 text-xs uppercase tracking-wider mb-1.5">Notes</label>
            <input
              type="text"
              value={notes}
              onChange={e => setNotes(e.target.value)}
              placeholder="Optional"
              maxLength={200}
              className="w-full bg-transparent border-none text-cream text-sm p-0 focus:ring-0 focus:outline-none placeholder:text-cream/30"
            />
          </div>
        </div>

        <button
          type="submit"
          disabled={saving}
          className="w-full bg-accent hover:bg-accent-dark text-white font-semibold py-3 rounded-sm transition-colors disabled:opacity-50 shadow-sm"
        >
          {saving ? 'Saving...' : 'Save Entry'}
        </button>
      </form>
    </div>
  );
}
