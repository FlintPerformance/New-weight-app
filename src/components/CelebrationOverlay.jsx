import React, { useState, useEffect, useMemo } from 'react';
import { useAppData } from '../App';
import { formatWeight, getStreak } from '../utils';

export default function CelebrationOverlay({ weightData, onClose }) {
  const { weights, goals, unit } = useAppData();
  const [visible, setVisible] = useState(false);

  const streak = getStreak(weights);
  const activeGoal = goals.find(g => g.active);

  const goalProgress = useMemo(() => {
    if (!activeGoal || !weights[0]) return null;
    const total = Math.abs(activeGoal.startWeight - activeGoal.targetWeight);
    const current = Math.abs(activeGoal.startWeight - weights[0].weight);
    const pct = total === 0 ? 100 : Math.min(100, Math.round((current / total) * 100));
    return pct;
  }, [activeGoal, weights]);

  // Previous weight (second entry, since first is the one just logged)
  const prevWeight = weights[1]?.weight;
  const diff = prevWeight ? weightData.weight - prevWeight : null;

  useEffect(() => {
    requestAnimationFrame(() => setVisible(true));
    const timer = setTimeout(() => {
      setVisible(false);
      setTimeout(onClose, 400);
    }, 3500);
    return () => clearTimeout(timer);
  }, []); // eslint-disable-line

  const dismiss = () => {
    setVisible(false);
    setTimeout(onClose, 400);
  };

  const getMessage = () => {
    if (streak >= 14) return "Absolutely unstoppable!";
    if (streak >= 7) return "You're on fire!";
    if (streak >= 3) return "Keep it rolling!";
    if (diff !== null && diff < -0.5) return "Trending down — nice!";
    if (diff !== null && diff < 0) return "Every bit counts!";
    if (weights.length === 1) return "First one down!";
    return "Logged! You got this!";
  };

  return (
    <div
      className="fixed inset-0 z-[90] flex items-center justify-center cursor-pointer"
      onClick={dismiss}
      style={{
        backgroundColor: visible ? 'rgba(0,0,0,0.5)' : 'transparent',
        transition: 'background-color 0.4s',
      }}
    >
      <div
        className="bg-surface-mid rounded-2xl p-8 mx-6 max-w-sm w-full text-center shadow-xl border border-black/5"
        style={{
          transform: visible ? 'scale(1) translateY(0)' : 'scale(0.8) translateY(20px)',
          opacity: visible ? 1 : 0,
          transition: 'all 0.4s cubic-bezier(0.34, 1.56, 0.64, 1)',
        }}
      >
        {/* Checkmark */}
        <div className="w-16 h-16 rounded-full bg-accent/10 border-2 border-accent flex items-center justify-center mx-auto mb-4 animate-pop">
          <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="#2B9B8F" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
            <polyline points="20 6 9 17 4 12" />
          </svg>
        </div>

        {/* Weight */}
        <p className="font-display text-4xl font-extrabold text-cream mb-1">
          {formatWeight(weightData.weight, unit)}
        </p>

        {/* Diff */}
        {diff !== null && (
          <p className={`text-sm font-medium mb-3 ${diff < 0 ? 'text-success' : diff > 0 ? 'text-danger' : 'text-cream/50'}`}>
            {diff > 0 ? '+' : ''}{diff.toFixed(1)} {unit}
          </p>
        )}

        {/* Message */}
        <p className="text-accent font-heading font-semibold text-lg mb-5">{getMessage()}</p>

        {/* Stats row */}
        <div className="flex justify-center gap-6">
          <div className="text-center">
            <p className="font-display text-2xl font-bold text-cream">{streak}</p>
            <p className="text-cream/50 text-xs">day streak</p>
          </div>
          {goalProgress !== null && (
            <div className="text-center">
              <p className="font-display text-2xl font-bold text-accent">{goalProgress}%</p>
              <p className="text-cream/50 text-xs">goal</p>
            </div>
          )}
          <div className="text-center">
            <p className="font-display text-2xl font-bold text-cream">{weights.length}</p>
            <p className="text-cream/50 text-xs">total</p>
          </div>
        </div>

        <p className="text-cream/30 text-xs mt-5">Tap anywhere to continue</p>
      </div>
    </div>
  );
}
