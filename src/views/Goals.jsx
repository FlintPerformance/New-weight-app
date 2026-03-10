import React, { useState, useMemo } from 'react';
import { useAppData, useAppActions } from '../App';
import { formatWeight, formatDateShort, isValidWeight, todayStr, daysAgo } from '../utils';

export default function Goals() {
  const { goals, weights, unit } = useAppData();
  const { addGoal, removeGoal, showToast } = useAppActions();
  const [targetWeight, setTargetWeight] = useState('');
  const [targetDate, setTargetDate] = useState('');
  const [showForm, setShowForm] = useState(false);
  const [confirmRemoveId, setConfirmRemoveId] = useState(null);

  const activeGoal = goals.find(g => g.active);
  const latest = weights[0];

  // All weights since goal started, sorted oldest first
  const goalWeights = useMemo(() => {
    if (!activeGoal) return [];
    return weights
      .filter(w => w.date >= activeGoal.startDate)
      .sort((a, b) => a.date.localeCompare(b.date));
  }, [activeGoal, weights]);

  const progress = useMemo(() => {
    if (!activeGoal || !latest) return null;
    const total = Math.abs(activeGoal.startWeight - activeGoal.targetWeight);
    const current = Math.abs(activeGoal.startWeight - latest.weight);
    const pct = total === 0 ? 100 : Math.min(100, Math.round((current / total) * 100));
    const remaining = activeGoal.targetWeight - latest.weight;
    const direction = activeGoal.targetWeight < activeGoal.startWeight ? 'lose' : 'gain';

    let daysLeft = null;
    let totalDays = null;
    let daysPassed = null;
    if (activeGoal.targetDate) {
      const targetMs = new Date(activeGoal.targetDate + 'T00:00:00').getTime();
      const startMs = new Date(activeGoal.startDate + 'T00:00:00').getTime();
      daysLeft = Math.max(0, Math.ceil((targetMs - Date.now()) / 86400000));
      totalDays = Math.max(1, Math.ceil((targetMs - startMs) / 86400000));
      daysPassed = Math.min(totalDays, Math.ceil((Date.now() - startMs) / 86400000));
    }

    const daysActive = Math.max(1, Math.ceil((Date.now() - new Date(activeGoal.startDate + 'T00:00:00').getTime()) / 86400000));
    const ratePerDay = daysActive > 0 ? current / daysActive : 0;
    const ratePerWeek = ratePerDay * 7;
    const neededRatePerDay = daysLeft && daysLeft > 0 ? Math.abs(remaining) / daysLeft : 0;
    const neededRatePerWeek = neededRatePerDay * 7;

    let paceStatus = 'on_track';
    if (neededRatePerWeek > 0 && ratePerWeek > 0) {
      const ratio = ratePerWeek / neededRatePerWeek;
      if (ratio >= 1.15) paceStatus = 'ahead';
      else if (ratio <= 0.85) paceStatus = 'behind';
    }

    return { pct, remaining, direction, daysLeft, totalDays, daysPassed, total, current, ratePerWeek, neededRatePerWeek, paceStatus, daysActive };
  }, [activeGoal, latest]);

  // Weekly micro-targets
  const weeklyTargets = useMemo(() => {
    if (!activeGoal || !activeGoal.targetDate || !progress) return [];
    const startDate = new Date(activeGoal.startDate + 'T00:00:00');
    const endDate = new Date(activeGoal.targetDate + 'T00:00:00');
    const totalMs = endDate.getTime() - startDate.getTime();
    const totalWeeks = Math.ceil(totalMs / (7 * 86400000));
    if (totalWeeks <= 0) return [];

    const weightDiff = activeGoal.targetWeight - activeGoal.startWeight;
    const weeklyChange = weightDiff / totalWeeks;
    const today = new Date();
    const targets = [];

    for (let w = 1; w <= totalWeeks; w++) {
      const weekEndDate = new Date(startDate.getTime() + w * 7 * 86400000);
      if (weekEndDate > endDate) break;
      const targetW = activeGoal.startWeight + weeklyChange * w;
      const weekEndStr = weekEndDate.toISOString().slice(0, 10);
      const weekStartStr = new Date(startDate.getTime() + (w - 1) * 7 * 86400000).toISOString().slice(0, 10);

      // Find actual weight closest to this week's end
      const weekWeights = goalWeights.filter(gw => gw.date >= weekStartStr && gw.date <= weekEndStr);
      const actual = weekWeights.length > 0 ? weekWeights[weekWeights.length - 1].weight : null;

      const isPast = weekEndDate < today;
      const isCurrent = !isPast && new Date(startDate.getTime() + (w - 1) * 7 * 86400000) <= today;

      targets.push({
        week: w,
        target: Number(targetW.toFixed(1)),
        actual,
        isPast,
        isCurrent,
        hit: actual !== null && (
          progress.direction === 'lose'
            ? actual <= targetW + 0.5
            : actual >= targetW - 0.5
        ),
        date: weekEndStr,
      });
    }
    return targets;
  }, [activeGoal, progress, goalWeights]);

  // Milestones
  const milestones = useMemo(() => {
    if (!activeGoal || !progress) return [];
    const items = [
      { pct: 25, label: 'Quarter way there!', icon: '🏁' },
      { pct: 50, label: 'Halfway — amazing!', icon: '⚡' },
      { pct: 75, label: 'Almost there!', icon: '🔥' },
      { pct: 90, label: 'So close!', icon: '🎯' },
      { pct: 100, label: 'You did it!', icon: '🏆' },
    ];

    // Add weight-based milestones
    const totalChange = Math.abs(activeGoal.targetWeight - activeGoal.startWeight);
    if (totalChange >= 10) {
      const fiveToGo = progress.direction === 'lose'
        ? activeGoal.targetWeight + 5
        : activeGoal.targetWeight - 5;
      items.push({
        pct: Math.round(((totalChange - 5) / totalChange) * 100),
        label: `5 ${unit} to go`,
        icon: '💪',
      });
    }

    return items
      .sort((a, b) => a.pct - b.pct)
      .map(m => ({ ...m, reached: progress.pct >= m.pct }));
  }, [activeGoal, progress, unit]);

  // Consistency stats since goal started
  const consistency = useMemo(() => {
    if (!activeGoal || !progress) return null;
    const daysActive = progress.daysActive;
    const uniqueDays = new Set(goalWeights.map(w => w.date)).size;
    const pct = Math.round((uniqueDays / Math.max(1, daysActive)) * 100);

    // Current week logging
    const weekStart = daysAgo(new Date().getDay()); // Sunday
    const thisWeekLogs = goalWeights.filter(w => w.date >= weekStart).length;
    const dayOfWeek = new Date().getDay() || 7; // 1-7

    return { uniqueDays, daysActive, pct, thisWeekLogs, dayOfWeek };
  }, [activeGoal, goalWeights, progress]);

  // Sparkline data: actual vs ideal path
  const sparklineData = useMemo(() => {
    if (!activeGoal || !activeGoal.targetDate || goalWeights.length < 2) return null;
    const startDate = new Date(activeGoal.startDate + 'T00:00:00');
    const endDate = new Date(activeGoal.targetDate + 'T00:00:00');
    const totalMs = endDate.getTime() - startDate.getTime();
    const weightDiff = activeGoal.targetWeight - activeGoal.startWeight;

    // Build actual data points (one per day, use latest of day)
    const byDate = {};
    goalWeights.forEach(w => { byDate[w.date] = w.weight; });

    const points = [];
    const dates = Object.keys(byDate).sort();
    dates.forEach(d => {
      const dayMs = new Date(d + 'T00:00:00').getTime() - startDate.getTime();
      const progress = dayMs / totalMs;
      const ideal = activeGoal.startWeight + weightDiff * Math.min(1, progress);
      points.push({ date: d, actual: byDate[d], ideal: Number(ideal.toFixed(1)), progress });
    });

    return points;
  }, [activeGoal, goalWeights]);

  const handleCreate = async (e) => {
    e.preventDefault();
    if (!targetWeight) { showToast('Enter a target weight', 'error'); return; }
    if (!targetDate) { showToast('Set a target date', 'error'); return; }
    if (!isValidWeight(targetWeight, unit)) {
      showToast(`Target must be between ${unit === 'kg' ? '0.5–680' : '1–1500'} ${unit}`, 'error');
      return;
    }
    const today = todayStr();
    if (targetDate <= today) {
      showToast('Target date must be in the future', 'error');
      return;
    }
    if (activeGoal) {
      showToast('New goal set! Previous goal moved to history.');
    } else {
      showToast('Goal set!');
    }
    await addGoal(targetWeight, unit, targetDate);
    setShowForm(false);
    setTargetWeight('');
    setTargetDate('');
  };

  const handleRemove = async (id) => {
    await removeGoal(id);
    setConfirmRemoveId(null);
    showToast('Goal removed');
  };

  return (
    <div className="max-w-2xl">
      <h1 className="font-heading text-2xl font-bold text-cream mb-6">Your Goals</h1>

      {activeGoal && progress ? (
        <div className="space-y-4">
          {/* Main Progress Card */}
          <div className="bg-surface-mid rounded-sm p-6 border border-black/5 shadow-card">
            <div className="flex items-center justify-between mb-4">
              <p className="text-cream/60 text-xs uppercase tracking-wider">You're Working Toward</p>
              {confirmRemoveId === activeGoal.id ? (
                <div className="flex gap-2">
                  <button onClick={() => handleRemove(activeGoal.id)} className="text-danger text-xs font-medium">Confirm</button>
                  <button onClick={() => setConfirmRemoveId(null)} className="text-cream/60 text-xs">Cancel</button>
                </div>
              ) : (
                <div className="flex gap-3">
                  <button onClick={() => setShowForm(true)} className="text-accent text-xs font-medium">New Goal</button>
                  <button onClick={() => setConfirmRemoveId(activeGoal.id)} className="text-cream/50 hover:text-danger text-xs">Remove</button>
                </div>
              )}
            </div>

            {/* Progress Ring + Summary */}
            <div className="flex items-center gap-6 mb-4">
              <div className="relative w-24 h-24 shrink-0">
                <svg viewBox="0 0 100 100" className="transform -rotate-90 w-full h-full">
                  <circle cx="50" cy="50" r="42" fill="none" stroke="rgba(43,155,143,0.08)" strokeWidth="8" />
                  <circle
                    cx="50" cy="50" r="42" fill="none" stroke="#2B9B8F" strokeWidth="8"
                    strokeLinecap="round"
                    strokeDasharray={`${progress.pct * 2.64} ${264 - progress.pct * 2.64}`}
                  />
                </svg>
                <div className="absolute inset-0 flex items-center justify-center">
                  <span className="font-display text-2xl text-accent">{progress.pct}%</span>
                </div>
              </div>
              <div>
                <p className="text-cream text-lg font-semibold">
                  {progress.direction === 'lose' ? 'Lose' : 'Gain'} {formatWeight(progress.total, unit)}
                </p>
                <p className="text-cream/50 text-sm">
                  Target: {formatWeight(activeGoal.targetWeight, unit)}
                </p>
                <p className="text-cream/60 text-xs mt-1">
                  {Math.abs(progress.remaining).toFixed(1)} {unit} remaining
                </p>
              </div>
            </div>

            {/* Stats Grid */}
            <div className="grid grid-cols-2 gap-3">
              <div className="bg-surface-up rounded-sm p-3">
                <p className="text-cream/60 text-xs uppercase">Started at</p>
                <p className="text-cream font-medium">{formatWeight(activeGoal.startWeight, unit)}</p>
                <p className="text-cream/50 text-xs">{formatDateShort(activeGoal.startDate)}</p>
              </div>
              <div className="bg-surface-up rounded-sm p-3">
                <p className="text-cream/60 text-xs uppercase">Current</p>
                <p className="text-cream font-medium">{latest ? formatWeight(latest.weight, unit) : '—'}</p>
                <p className="text-cream/50 text-xs">{latest ? formatDateShort(latest.date) : ''}</p>
              </div>
            </div>
          </div>

          {/* Timeline Bar */}
          {progress.totalDays && (
            <div className="bg-surface-mid rounded-sm p-4 border border-black/5">
              <div className="flex items-center justify-between mb-2">
                <p className="text-cream/50 text-xs uppercase tracking-wider">Timeline</p>
                <p className="text-cream/60 text-xs">
                  {progress.daysLeft} days remaining
                </p>
              </div>
              <div className="relative">
                <div className="h-2 bg-black/5 rounded-full overflow-hidden">
                  <div
                    className="h-full bg-accent rounded-full transition-all"
                    style={{ width: `${Math.min(100, (progress.daysPassed / progress.totalDays) * 100)}%` }}
                  />
                </div>
                {/* Markers */}
                <div className="flex justify-between mt-1.5">
                  <span className="text-cream/50 text-xs">{formatDateShort(activeGoal.startDate)}</span>
                  <span className="text-cream/50 text-xs font-medium">Today</span>
                  <span className="text-cream/50 text-xs">{formatDateShort(activeGoal.targetDate)}</span>
                </div>
              </div>
            </div>
          )}

          {/* Pace Analysis */}
          <div className="bg-surface-mid rounded-sm p-4 border border-black/5">
            <p className="text-cream/50 text-xs uppercase tracking-wider mb-3">Pace</p>
            <div className="grid grid-cols-2 gap-3 mb-3">
              <div className="bg-surface-up rounded-sm p-3">
                <p className="text-cream/60 text-xs uppercase">Your Rate</p>
                <p className="font-display text-xl text-cream">
                  {progress.ratePerWeek.toFixed(1)}
                </p>
                <p className="text-cream/50 text-xs">{unit}/week</p>
              </div>
              <div className="bg-surface-up rounded-sm p-3">
                <p className="text-cream/60 text-xs uppercase">Needed Rate</p>
                <p className="font-display text-xl text-cream">
                  {progress.neededRatePerWeek.toFixed(1)}
                </p>
                <p className="text-cream/50 text-xs">{unit}/week</p>
              </div>
            </div>
            <div className={`rounded-sm px-3 py-2 text-xs font-medium ${
              progress.paceStatus === 'ahead' ? 'bg-success/10 text-success border border-success/20' :
              progress.paceStatus === 'behind' ? 'bg-danger/10 text-danger border border-danger/20' :
              'bg-accent/10 text-accent border border-accent/20'
            }`}>
              {progress.paceStatus === 'ahead' && `You're crushing it — ahead of pace!`}
              {progress.paceStatus === 'on_track' && `Right on track — you're doing amazing!`}
              {progress.paceStatus === 'behind' && `Let's pick up the pace — you've got this!`}
            </div>
          </div>

          {/* Weight vs Ideal Sparkline */}
          {sparklineData && sparklineData.length >= 2 && (
            <div className="bg-surface-mid rounded-sm p-4 border border-black/5">
              <p className="text-cream/50 text-xs uppercase tracking-wider mb-3">Progress vs Plan</p>
              <GoalSparkline
                data={sparklineData}
                direction={progress.direction}
                startWeight={activeGoal.startWeight}
                targetWeight={activeGoal.targetWeight}
              />
              <div className="flex gap-4 mt-2 justify-center">
                <span className="flex items-center gap-1 text-xs text-cream/60">
                  <span className="w-3 h-0.5 bg-accent rounded" /> Actual
                </span>
                <span className="flex items-center gap-1 text-xs text-cream/60">
                  <span className="w-3 h-0.5 bg-cream/20 rounded border-dashed" /> Ideal
                </span>
              </div>
            </div>
          )}

          {/* Milestones */}
          <div className="bg-surface-mid rounded-sm p-4 border border-black/5">
            <p className="text-cream/50 text-xs uppercase tracking-wider mb-3">Milestones</p>
            <div className="space-y-2">
              {milestones.map((m, i) => (
                <div key={i} className={`flex items-center gap-3 px-3 py-2 rounded-sm transition-colors ${
                  m.reached ? 'bg-success/5' : 'bg-black/[0.02]'
                }`}>
                  <span className={`text-base ${m.reached ? '' : 'grayscale opacity-40'}`}>{m.icon}</span>
                  <span className={`text-sm flex-1 ${m.reached ? 'text-cream' : 'text-cream/50'}`}>{m.label}</span>
                  {m.reached ? (
                    <span className="text-success text-xs font-medium">Done</span>
                  ) : (
                    <span className="text-cream/50 text-xs">{m.pct}%</span>
                  )}
                </div>
              ))}
            </div>
          </div>

          {/* Weekly Micro-Targets */}
          {weeklyTargets.length > 0 && (
            <div className="bg-surface-mid rounded-sm p-4 border border-black/5">
              <p className="text-cream/50 text-xs uppercase tracking-wider mb-3">Weekly Targets</p>
              <div className="space-y-1.5">
                {weeklyTargets.map(wt => (
                  <div key={wt.week} className={`flex items-center gap-3 px-3 py-2 rounded-sm ${
                    wt.isCurrent ? 'bg-accent/10 border border-accent/20' :
                    wt.isPast ? (wt.hit ? 'bg-success/5' : 'bg-black/[0.02]') :
                    'bg-black/[0.02]'
                  }`}>
                    <span className={`text-xs font-medium w-10 shrink-0 ${
                      wt.isCurrent ? 'text-accent' : 'text-cream/50'
                    }`}>
                      Wk {wt.week}
                    </span>
                    <span className={`text-sm flex-1 ${wt.isCurrent ? 'text-cream font-medium' : 'text-cream/50'}`}>
                      {formatWeight(wt.target, unit)}
                    </span>
                    {wt.actual !== null && (
                      <span className={`text-xs ${wt.hit ? 'text-success' : 'text-danger'}`}>
                        {formatWeight(wt.actual, unit)}
                      </span>
                    )}
                    <span className="text-cream/50 text-xs w-14 text-right shrink-0">
                      {formatDateShort(wt.date)}
                    </span>
                    {wt.isPast && (
                      <span className={`text-xs w-4 text-center ${wt.hit ? 'text-success' : 'text-danger'}`}>
                        {wt.actual !== null ? (wt.hit ? '✓' : '✗') : '—'}
                      </span>
                    )}
                    {wt.isCurrent && (
                      <span className="text-accent text-xs font-medium w-4 text-center">→</span>
                    )}
                    {!wt.isPast && !wt.isCurrent && (
                      <span className="w-4" />
                    )}
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Consistency */}
          {consistency && (
            <div className="bg-surface-mid rounded-sm p-4 border border-black/5">
              <p className="text-cream/50 text-xs uppercase tracking-wider mb-3">Consistency</p>
              <div className="grid grid-cols-3 gap-3">
                <div className="bg-surface-up rounded-sm p-3 text-center">
                  <p className="text-cream/60 text-xs uppercase">Days Active</p>
                  <p className="font-display text-xl text-cream">{consistency.uniqueDays}</p>
                  <p className="text-cream/50 text-xs">of {consistency.daysActive}</p>
                </div>
                <div className="bg-surface-up rounded-sm p-3 text-center">
                  <p className="text-cream/60 text-xs uppercase">Consistency</p>
                  <p className={`font-display text-xl ${
                    consistency.pct >= 80 ? 'text-success' : consistency.pct >= 50 ? 'text-warning' : 'text-danger'
                  }`}>{consistency.pct}%</p>
                  <p className="text-cream/50 text-xs">consistency</p>
                </div>
                <div className="bg-surface-up rounded-sm p-3 text-center">
                  <p className="text-cream/60 text-xs uppercase">This Week's Logs</p>
                  <p className="font-display text-xl text-cream">{consistency.thisWeekLogs}</p>
                  <p className="text-cream/50 text-xs">of {consistency.dayOfWeek} days</p>
                </div>
              </div>
            </div>
          )}
        </div>
      ) : (
        <div className="bg-surface-mid rounded-sm p-6 border border-black/5 text-center mb-4">
          <p className="text-cream/60 text-lg mb-3">Ready to set a target? Let's do it!</p>
          {!showForm && (
            <button
              onClick={() => setShowForm(true)}
              className="bg-accent hover:bg-accent-dark text-white px-6 py-3 rounded-sm font-bold text-sm transition-all hover:shadow-glow active:scale-[0.98]"
            >
              Let's Go!
            </button>
          )}
        </div>
      )}

      {/* Create Goal Form */}
      {showForm && (
        <form onSubmit={handleCreate} className="bg-surface-mid rounded-sm p-5 border border-black/5 space-y-4 mt-4">
          <h2 className="font-heading text-lg font-semibold text-cream">Set Your Target</h2>
          {activeGoal && (
            <p className="text-warning/80 text-xs bg-warning/10 border border-warning/20 rounded-sm px-3 py-2">
              Setting a new goal will move your current goal to history.
            </p>
          )}
          <div>
            <label className="block text-cream/60 text-xs font-medium mb-1 uppercase tracking-wider">Target Weight ({unit})</label>
            <input
              type="number"
              step="0.1"
              value={targetWeight}
              onChange={e => setTargetWeight(e.target.value)}
              placeholder="e.g. 175.0"
              className="w-full"
              required
            />
          </div>
          <div>
            <label className="block text-cream/60 text-xs font-medium mb-1 uppercase tracking-wider">Target Date</label>
            <input
              type="date"
              value={targetDate}
              onChange={e => setTargetDate(e.target.value)}
              min={todayStr()}
              className="w-full"
              required
            />
          </div>
          <div className="flex gap-3">
            <button type="submit" className="flex-1 bg-accent hover:bg-accent-dark text-white font-bold py-3 rounded-sm transition-all hover:shadow-glow active:scale-[0.98]">
              Let's Do This!
            </button>
            <button type="button" onClick={() => setShowForm(false)} className="px-4 py-2.5 text-cream/60 hover:text-cream text-sm">
              Cancel
            </button>
          </div>
        </form>
      )}

      {/* Past Goals */}
      {goals.filter(g => !g.active).length > 0 && (
        <div className="mt-6">
          <p className="text-cream/60 text-xs uppercase tracking-wider mb-3">Past Goals</p>
          <div className="space-y-2">
            {goals.filter(g => !g.active).map(g => (
              <div key={g.id} className="bg-surface-up rounded-sm p-3 border border-black/5 flex justify-between items-center">
                <div>
                  <p className="text-cream/60 text-sm">Target: {formatWeight(g.targetWeight, unit)}</p>
                  <p className="text-cream/50 text-xs">From {formatWeight(g.startWeight, unit)}</p>
                </div>
                {confirmRemoveId === g.id ? (
                  <div className="flex gap-2">
                    <button onClick={() => handleRemove(g.id)} className="text-danger text-xs font-medium">Confirm</button>
                    <button onClick={() => setConfirmRemoveId(null)} className="text-cream/60 text-xs">Cancel</button>
                  </div>
                ) : (
                  <button onClick={() => setConfirmRemoveId(g.id)} className="text-cream/50 hover:text-danger text-xs">Remove</button>
                )}
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

// SVG sparkline comparing actual weight path vs ideal linear path
function GoalSparkline({ data, direction, startWeight, targetWeight }) {
  const W = 280;
  const H = 80;
  const PAD = 4;

  const allWeights = [...data.map(d => d.actual), ...data.map(d => d.ideal), startWeight, targetWeight];
  const minW = Math.min(...allWeights);
  const maxW = Math.max(...allWeights);
  const range = maxW - minW || 1;

  const scaleX = (i) => PAD + (i / Math.max(1, data.length - 1)) * (W - PAD * 2);
  const scaleY = (w) => H - PAD - ((w - minW) / range) * (H - PAD * 2);

  // Ideal line (straight from first to last)
  const idealStart = `${scaleX(0)},${scaleY(data[0].ideal)}`;
  const idealEnd = `${scaleX(data.length - 1)},${scaleY(data[data.length - 1].ideal)}`;

  // Actual path
  let actualPath = `M${scaleX(0)},${scaleY(data[0].actual)}`;
  for (let i = 1; i < data.length; i++) {
    const cp = ((W - PAD * 2) / Math.max(1, data.length - 1)) * 0.3;
    actualPath += ` C${scaleX(i - 1) + cp},${scaleY(data[i - 1].actual)} ${scaleX(i) - cp},${scaleY(data[i].actual)} ${scaleX(i)},${scaleY(data[i].actual)}`;
  }

  // Fill area under actual
  const fillPath = `${actualPath} L${scaleX(data.length - 1)},${H} L${scaleX(0)},${H} Z`;

  const lastPt = data[data.length - 1];

  return (
    <svg viewBox={`0 0 ${W} ${H}`} className="w-full h-20" preserveAspectRatio="none">
      <defs>
        <linearGradient id="goalSparkGrad" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#2B9B8F" stopOpacity="0.15" />
          <stop offset="100%" stopColor="#2B9B8F" stopOpacity="0" />
        </linearGradient>
      </defs>
      {/* Ideal line */}
      <line x1={scaleX(0)} y1={scaleY(data[0].ideal)} x2={scaleX(data.length - 1)} y2={scaleY(data[data.length - 1].ideal)}
        stroke="rgba(45,42,51,0.15)" strokeWidth="1.5" strokeDasharray="4 3" />
      {/* Actual fill + line */}
      <path d={fillPath} fill="url(#goalSparkGrad)" />
      <path d={actualPath} fill="none" stroke="#2B9B8F" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
      {/* Current point */}
      <circle cx={scaleX(data.length - 1)} cy={scaleY(lastPt.actual)} r="3" fill="#2B9B8F" stroke="#2D2A33" strokeWidth="1.5" />
    </svg>
  );
}
