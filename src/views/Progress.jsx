import React, { useState, useMemo } from 'react';
import { useAppData, useAppActions } from '../App';
import { formatDate, formatWeight, getMovingAverage, getWeightChange, formatDateShort, aggregateDaily, buildCandlestickData, daysAgo, isValidWeight, todayStr } from '../utils';
import { ResponsiveContainer, LineChart, ComposedChart, Line, Bar, XAxis, YAxis, Tooltip, ReferenceLine } from 'recharts';

const PAGE_SIZE = 50;

/* ─── Candlestick Shape (from History) ─── */
function CandlestickShape({ x, y, width, height, payload }) {
  if (!payload) return null;
  const { low, high, open, close, morning, count } = payload;
  const cx = x + width / 2;
  const absH = Math.abs(height);
  const top = height >= 0 ? y : y + height;

  if (count === 1 || low === high) {
    return (
      <g>
        <line x1={cx - width * 0.3} y1={top} x2={cx + width * 0.3} y2={top} stroke="#2B9B8F" strokeWidth={2} strokeLinecap="round" />
        <circle cx={cx} cy={top} r={Math.max(3, width * 0.25)} fill="#2B9B8F" stroke="#2D2A33" strokeWidth={1.5} />
      </g>
    );
  }

  const pxPerUnit = absH / (high - low);
  const wickWidth = Math.max(1, width * 0.12);
  const bodyWidth = Math.max(4, width * 0.55);
  const openY = top + (high - open) * pxPerUnit;
  const closeY = top + (high - close) * pxPerUnit;
  const bodyTop = Math.min(openY, closeY);
  const bodyH = Math.max(2, Math.abs(closeY - openY));
  const bullish = close <= open;

  return (
    <g>
      <rect x={cx - wickWidth / 2} y={top} width={wickWidth} height={absH} fill="#2D2A3320" rx={1} />
      <rect x={cx - bodyWidth / 2} y={bodyTop} width={bodyWidth} height={bodyH} fill={bullish ? '#2B9B8F' : 'transparent'} stroke="#2B9B8F" strokeWidth={1.5} rx={1.5} opacity={0.9} />
      {morning != null && (
        <circle cx={cx} cy={top + (high - morning) * pxPerUnit} r={Math.max(3, width * 0.22)} fill="#2B9B8F" stroke="#2D2A33" strokeWidth={1.5} />
      )}
    </g>
  );
}

/* ─── Goal Sparkline ─── */
function GoalSparkline({ data, startWeight, targetWeight }) {
  const W = 280;
  const H = 80;
  const PAD = 4;

  const allWeights = [...data.map(d => d.actual), ...data.map(d => d.ideal), startWeight, targetWeight];
  const minW = Math.min(...allWeights);
  const maxW = Math.max(...allWeights);
  const range = maxW - minW || 1;

  const scaleX = (i) => PAD + (i / Math.max(1, data.length - 1)) * (W - PAD * 2);
  const scaleY = (w) => H - PAD - ((w - minW) / range) * (H - PAD * 2);

  let actualPath = `M${scaleX(0)},${scaleY(data[0].actual)}`;
  for (let i = 1; i < data.length; i++) {
    const cp = ((W - PAD * 2) / Math.max(1, data.length - 1)) * 0.3;
    actualPath += ` C${scaleX(i - 1) + cp},${scaleY(data[i - 1].actual)} ${scaleX(i) - cp},${scaleY(data[i].actual)} ${scaleX(i)},${scaleY(data[i].actual)}`;
  }

  const fillPath = `${actualPath} L${scaleX(data.length - 1)},${H} L${scaleX(0)},${H} Z`;

  return (
    <svg viewBox={`0 0 ${W} ${H}`} className="w-full h-20" preserveAspectRatio="none">
      <defs>
        <linearGradient id="goalSparkGrad" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#2B9B8F" stopOpacity="0.15" />
          <stop offset="100%" stopColor="#2B9B8F" stopOpacity="0" />
        </linearGradient>
      </defs>
      <line x1={scaleX(0)} y1={scaleY(data[0].ideal)} x2={scaleX(data.length - 1)} y2={scaleY(data[data.length - 1].ideal)}
        stroke="rgba(45,42,51,0.15)" strokeWidth="1.5" strokeDasharray="4 3" />
      <path d={fillPath} fill="url(#goalSparkGrad)" />
      <path d={actualPath} fill="none" stroke="#2B9B8F" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
      <circle cx={scaleX(data.length - 1)} cy={scaleY(data[data.length - 1].actual)} r="3" fill="#2B9B8F" stroke="#2D2A33" strokeWidth="1.5" />
    </svg>
  );
}

export default function Progress() {
  const { weights, goals, unit } = useAppData();
  const { removeWeight, updateWeight, addGoal, removeGoal, showToast } = useAppActions();

  // --- History state ---
  const [range, setRange] = useState('30');
  const [confirmDelete, setConfirmDelete] = useState(null);
  const [chartMode, setChartMode] = useState('line');
  const [editingId, setEditingId] = useState(null);
  const [editWeight, setEditWeight] = useState('');
  const [editNotes, setEditNotes] = useState('');
  const [page, setPage] = useState(1);

  // --- Goals state ---
  const [showGoalForm, setShowGoalForm] = useState(false);
  const [showGoalDetails, setShowGoalDetails] = useState(false);
  const [targetWeight, setTargetWeight] = useState('');
  const [targetDate, setTargetDate] = useState('');
  const [confirmRemoveId, setConfirmRemoveId] = useState(null);

  const activeGoal = goals.find(g => g.active);
  const latest = weights[0];

  // --- History data ---
  const filtered = useMemo(() => {
    if (range === 'all') return weights;
    const days = parseInt(range);
    const cutoff = daysAgo(days);
    return weights.filter(w => w.date >= cutoff);
  }, [weights, range]);

  const handleRangeChange = (val) => {
    setRange(val);
    setPage(1);
  };

  const pagedEntries = useMemo(() => filtered.slice(0, page * PAGE_SIZE), [filtered, page]);
  const hasMore = pagedEntries.length < filtered.length;

  const chartData = useMemo(() => {
    const daily = aggregateDaily([...filtered], 'morning');
    return getMovingAverage(daily);
  }, [filtered]);

  const candlestickData = useMemo(() => {
    if (chartMode !== 'candle') return [];
    return buildCandlestickData([...filtered]);
  }, [filtered, chartMode]);

  const candleDomain = useMemo(() => {
    if (!candlestickData.length) return ['auto', 'auto'];
    const allLows = candlestickData.map(d => d.low);
    const allHighs = candlestickData.map(d => d.high);
    return [Math.floor(Math.min(...allLows) - 1), Math.ceil(Math.max(...allHighs) + 1)];
  }, [candlestickData]);

  const stats = useMemo(() => {
    if (filtered.length === 0) return null;
    const sorted = [...filtered].sort((a, b) => a.date.localeCompare(b.date));
    const allWeights = sorted.map(e => e.weight);
    const avg = allWeights.reduce((s, w) => s + w, 0) / allWeights.length;
    const highest = sorted.reduce((max, e) => e.weight > max.weight ? e : max, sorted[0]);
    const lowest = sorted.reduce((min, e) => e.weight < min.weight ? e : min, sorted[0]);
    const change = getWeightChange(sorted);
    return { count: filtered.length, avg, highest, lowest, change };
  }, [filtered]);

  // --- Goals data ---
  const goalWeights = useMemo(() => {
    if (!activeGoal) return [];
    return weights.filter(w => w.date >= activeGoal.startDate).sort((a, b) => a.date.localeCompare(b.date));
  }, [activeGoal, weights]);

  const progress = useMemo(() => {
    if (!activeGoal || !latest) return null;
    const total = Math.abs(activeGoal.startWeight - activeGoal.targetWeight);
    const current = Math.abs(activeGoal.startWeight - latest.weight);
    const pct = total === 0 ? 100 : Math.min(100, Math.round((current / total) * 100));
    const remaining = activeGoal.targetWeight - latest.weight;
    const direction = activeGoal.targetWeight < activeGoal.startWeight ? 'lose' : 'gain';

    let daysLeft = null, totalDays = null, daysPassed = null;
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

  const milestones = useMemo(() => {
    if (!activeGoal || !progress) return [];
    const items = [
      { pct: 25, label: 'Quarter way there!', icon: '🏁' },
      { pct: 50, label: 'Halfway — amazing!', icon: '⚡' },
      { pct: 75, label: 'Almost there!', icon: '🔥' },
      { pct: 90, label: 'So close!', icon: '🎯' },
      { pct: 100, label: 'You did it!', icon: '🏆' },
    ];
    const totalChange = Math.abs(activeGoal.targetWeight - activeGoal.startWeight);
    if (totalChange >= 10) {
      items.push({
        pct: Math.round(((totalChange - 5) / totalChange) * 100),
        label: `5 ${unit} to go`,
        icon: '💪',
      });
    }
    return items.sort((a, b) => a.pct - b.pct).map(m => ({ ...m, reached: progress.pct >= m.pct }));
  }, [activeGoal, progress, unit]);

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
          progress.direction === 'lose' ? actual <= targetW + 0.5 : actual >= targetW - 0.5
        ),
        date: weekEndStr,
      });
    }
    return targets;
  }, [activeGoal, progress, goalWeights]);

  const sparklineData = useMemo(() => {
    if (!activeGoal || !activeGoal.targetDate || goalWeights.length < 2) return null;
    const startDate = new Date(activeGoal.startDate + 'T00:00:00');
    const endDate = new Date(activeGoal.targetDate + 'T00:00:00');
    const totalMs = endDate.getTime() - startDate.getTime();
    const weightDiff = activeGoal.targetWeight - activeGoal.startWeight;
    const byDate = {};
    goalWeights.forEach(w => { byDate[w.date] = w.weight; });
    const points = [];
    Object.keys(byDate).sort().forEach(d => {
      const dayMs = new Date(d + 'T00:00:00').getTime() - startDate.getTime();
      const prog = dayMs / totalMs;
      const ideal = activeGoal.startWeight + weightDiff * Math.min(1, prog);
      points.push({ date: d, actual: byDate[d], ideal: Number(ideal.toFixed(1)), progress: prog });
    });
    return points;
  }, [activeGoal, goalWeights]);

  const consistency = useMemo(() => {
    if (!activeGoal || !progress) return null;
    const daysActive = progress.daysActive;
    const uniqueDays = new Set(goalWeights.map(w => w.date)).size;
    const pct = Math.round((uniqueDays / Math.max(1, daysActive)) * 100);
    const weekStart = daysAgo(new Date().getDay());
    const thisWeekLogs = goalWeights.filter(w => w.date >= weekStart).length;
    const dayOfWeek = new Date().getDay() || 7;
    return { uniqueDays, daysActive, pct, thisWeekLogs, dayOfWeek };
  }, [activeGoal, goalWeights, progress]);

  // --- Handlers ---
  const handleDelete = async (id) => {
    await removeWeight(id);
    setConfirmDelete(null);
  };

  const startEdit = (entry) => {
    setEditingId(entry.id);
    setEditWeight(String(entry.weight));
    setEditNotes(entry.notes || '');
  };

  const saveEdit = async (id) => {
    const num = Number(editWeight);
    if (isNaN(num) || num <= 0) {
      showToast('Invalid weight', 'error');
      return;
    }
    await updateWeight(id, { weight: num, notes: editNotes });
    setEditingId(null);
    showToast('Entry updated');
  };

  const handleCreateGoal = async (e) => {
    e.preventDefault();
    if (!targetWeight) { showToast('Enter a target weight', 'error'); return; }
    if (!targetDate) { showToast('Set a target date', 'error'); return; }
    if (!isValidWeight(targetWeight, unit)) {
      showToast(`Target must be between ${unit === 'kg' ? '0.5–680' : '1–1500'} ${unit}`, 'error');
      return;
    }
    if (targetDate <= todayStr()) {
      showToast('Target date must be in the future', 'error');
      return;
    }
    if (activeGoal) {
      showToast('New goal set! Previous goal moved to history.');
    } else {
      showToast('Goal set!');
    }
    await addGoal(targetWeight, unit, targetDate);
    setShowGoalForm(false);
    setTargetWeight('');
    setTargetDate('');
  };

  const handleRemoveGoal = async (id) => {
    await removeGoal(id);
    setConfirmRemoveId(null);
    showToast('Goal removed');
  };

  return (
    <div className="max-w-3xl">
      {/* Header */}
      <div className="flex items-center justify-between mb-5">
        <h1 className="font-heading text-2xl font-bold text-cream">Progress</h1>
        <div className="flex gap-1 bg-surface-up rounded-sm p-0.5">
          {[['7', '7d'], ['30', '30d'], ['90', '90d'], ['all', 'All']].map(([val, label]) => (
            <button
              key={val}
              onClick={() => handleRangeChange(val)}
              className={`px-2.5 py-1 rounded-sm text-xs font-medium transition-colors ${
                range === val ? 'bg-accent text-white' : 'text-cream/60 hover:text-cream'
              }`}
            >
              {label}
            </button>
          ))}
        </div>
      </div>

      {/* Chart */}
      {chartData.length > 1 && (
        <div className="bg-surface-mid rounded-sm p-4 border border-black/5 mb-4 shadow-card">
          <div className="flex items-center justify-end mb-2">
            <div className="flex gap-1 bg-surface-up rounded-sm p-0.5">
              <button
                onClick={() => setChartMode('line')}
                className={`px-2 py-0.5 rounded-sm text-xs font-medium transition-colors ${chartMode === 'line' ? 'bg-accent text-white' : 'text-cream/60 hover:text-cream'}`}
              >
                Line
              </button>
              <button
                onClick={() => setChartMode('candle')}
                className={`px-2 py-0.5 rounded-sm text-xs font-medium transition-colors ${chartMode === 'candle' ? 'bg-accent text-white' : 'text-cream/60 hover:text-cream'}`}
              >
                Candle
              </button>
            </div>
          </div>

          {chartMode === 'line' ? (
            <ResponsiveContainer width="100%" height={200}>
              <LineChart data={chartData}>
                <XAxis dataKey="date" tickFormatter={formatDateShort} tick={{ fill: '#2D2A3366', fontSize: 11 }} axisLine={false} tickLine={false} interval="preserveStartEnd" />
                <YAxis domain={['auto', 'auto']} tick={{ fill: '#2D2A3366', fontSize: 11 }} axisLine={false} tickLine={false} width={40} />
                <Tooltip contentStyle={{ background: '#FFFFFF', border: '1px solid rgba(0,0,0,0.08)', borderRadius: 12, fontSize: 14, color: '#2D2A33' }} labelFormatter={formatDateShort} />
                {activeGoal && (
                  <ReferenceLine y={activeGoal.targetWeight} stroke="#E5A63E" strokeDasharray="6 3" label={{ value: 'Goal', fill: '#E5A63E', fontSize: 10 }} />
                )}
                <Line type="monotone" dataKey="weight" stroke="#2B9B8F" strokeWidth={2} dot={{ r: 3, fill: '#2B9B8F', stroke: '#2D2A3344', strokeWidth: 1 }} activeDot={{ r: 5, fill: '#2B9B8F', stroke: '#2D2A33', strokeWidth: 2 }} />
                <Line type="monotone" dataKey="average" stroke="#7C9AB5" strokeWidth={1.5} strokeDasharray="4 4" dot={false} />
              </LineChart>
            </ResponsiveContainer>
          ) : (
            <ResponsiveContainer width="100%" height={200}>
              <ComposedChart data={candlestickData}>
                <XAxis dataKey="date" tickFormatter={formatDateShort} tick={{ fill: '#2D2A3366', fontSize: 11 }} axisLine={false} tickLine={false} interval="preserveStartEnd" />
                <YAxis domain={candleDomain} tick={{ fill: '#2D2A3366', fontSize: 11 }} axisLine={false} tickLine={false} width={40} />
                <Tooltip
                  contentStyle={{ background: '#FFFFFF', border: '1px solid rgba(0,0,0,0.08)', borderRadius: 12, fontSize: 14, color: '#2D2A33' }}
                  labelFormatter={formatDateShort}
                  formatter={(value, name, { payload }) => {
                    if (name === 'range') {
                      const items = [`Low: ${formatWeight(payload.low, unit)}`, `High: ${formatWeight(payload.high, unit)}`];
                      if (payload.morning != null) items.push(`AM: ${formatWeight(payload.morning, unit)}`);
                      return [items.join('  ·  '), null];
                    }
                    return null;
                  }}
                />
                {activeGoal && (
                  <ReferenceLine y={activeGoal.targetWeight} stroke="#E5A63E" strokeDasharray="6 3" label={{ value: 'Goal', fill: '#E5A63E', fontSize: 10 }} />
                )}
                <Bar dataKey="range" fill="transparent" isAnimationActive={false} shape={<CandlestickShape />} />
              </ComposedChart>
            </ResponsiveContainer>
          )}
        </div>
      )}

      {/* Goal Progress Card (compact, integrated) */}
      {activeGoal && progress ? (
        <div className="bg-surface-mid rounded-sm p-5 border border-black/5 mb-4 shadow-card">
          <div className="flex items-center gap-5">
            {/* Mini progress ring */}
            <div className="relative w-16 h-16 shrink-0">
              <svg viewBox="0 0 100 100" className="transform -rotate-90 w-full h-full">
                <circle cx="50" cy="50" r="42" fill="none" stroke="rgba(43,155,143,0.08)" strokeWidth="8" />
                <circle
                  cx="50" cy="50" r="42" fill="none" stroke="#2B9B8F" strokeWidth="8"
                  strokeLinecap="round"
                  strokeDasharray={`${progress.pct * 2.64} ${264 - progress.pct * 2.64}`}
                />
              </svg>
              <div className="absolute inset-0 flex items-center justify-center">
                <span className="font-display text-lg font-bold text-accent">{progress.pct}%</span>
              </div>
            </div>

            {/* Goal summary */}
            <div className="flex-1 min-w-0">
              <div className="flex items-center justify-between">
                <p className="text-cream font-semibold">
                  {progress.direction === 'lose' ? 'Lose' : 'Gain'} {formatWeight(progress.total, unit)}
                </p>
                <div className={`rounded-full px-2.5 py-0.5 text-xs font-medium ${
                  progress.paceStatus === 'ahead' ? 'bg-success/10 text-success' :
                  progress.paceStatus === 'behind' ? 'bg-danger/10 text-danger' :
                  'bg-accent/10 text-accent'
                }`}>
                  {progress.paceStatus === 'ahead' && 'Ahead'}
                  {progress.paceStatus === 'on_track' && 'On track'}
                  {progress.paceStatus === 'behind' && 'Behind'}
                </div>
              </div>
              <p className="text-cream/50 text-sm">
                {Math.abs(progress.remaining).toFixed(1)} {unit} remaining
                {progress.daysLeft !== null && ` · ${progress.daysLeft}d left`}
              </p>
            </div>
          </div>

          {/* Expandable details */}
          <div className="flex items-center gap-3 mt-3 pt-3 border-t border-black/5">
            <button
              onClick={() => setShowGoalDetails(!showGoalDetails)}
              className="text-accent text-xs font-medium hover:underline"
            >
              {showGoalDetails ? 'Hide details' : 'Show details'}
            </button>
            <button
              onClick={() => setShowGoalForm(true)}
              className="text-cream/50 text-xs hover:text-cream"
            >
              New goal
            </button>
            {confirmRemoveId === activeGoal.id ? (
              <div className="flex gap-2 ml-auto">
                <button onClick={() => handleRemoveGoal(activeGoal.id)} className="text-danger text-xs font-medium">Confirm</button>
                <button onClick={() => setConfirmRemoveId(null)} className="text-cream/60 text-xs">Cancel</button>
              </div>
            ) : (
              <button onClick={() => setConfirmRemoveId(activeGoal.id)} className="text-cream/30 hover:text-danger text-xs ml-auto">Remove</button>
            )}
          </div>
        </div>
      ) : (
        <div className="bg-surface-mid rounded-sm p-5 border border-black/5 mb-4 shadow-soft flex items-center justify-between">
          <div>
            <p className="text-cream font-medium text-sm">No active goal</p>
            <p className="text-cream/50 text-xs">Set a target to track your progress!</p>
          </div>
          <button
            onClick={() => setShowGoalForm(true)}
            className="bg-accent hover:bg-accent-dark text-white px-4 py-2 rounded-sm font-semibold text-sm transition-colors"
          >
            Set Goal
          </button>
        </div>
      )}

      {/* Goal Details (expanded) */}
      {showGoalDetails && activeGoal && progress && (
        <div className="space-y-3 mb-4 animate-fade-in">
          {/* Timeline */}
          {progress.totalDays && (
            <div className="bg-surface-mid rounded-sm p-4 border border-black/5 shadow-soft">
              <div className="flex items-center justify-between mb-2">
                <p className="text-cream/60 text-xs uppercase tracking-wider">Timeline</p>
                <p className="text-cream/60 text-xs">{progress.daysLeft} days remaining</p>
              </div>
              <div className="relative">
                <div className="h-2 bg-black/5 rounded-full overflow-hidden">
                  <div className="h-full bg-accent rounded-full transition-all" style={{ width: `${Math.min(100, (progress.daysPassed / progress.totalDays) * 100)}%` }} />
                </div>
                <div className="flex justify-between mt-1.5">
                  <span className="text-cream/30 text-xs">{formatDateShort(activeGoal.startDate)}</span>
                  <span className="text-cream/60 text-xs font-medium">Today</span>
                  <span className="text-cream/30 text-xs">{formatDateShort(activeGoal.targetDate)}</span>
                </div>
              </div>
            </div>
          )}

          {/* Pace */}
          <div className="bg-surface-mid rounded-sm p-4 border border-black/5 shadow-soft">
            <p className="text-cream/60 text-xs uppercase tracking-wider mb-3">Pace</p>
            <div className="grid grid-cols-2 gap-3 mb-3">
              <div className="bg-surface-up rounded-sm p-3 shadow-soft">
                <p className="text-cream/60 text-xs uppercase">Your Rate</p>
                <p className="font-display text-lg font-bold text-cream">{progress.ratePerWeek.toFixed(1)}</p>
                <p className="text-cream/30 text-xs">{unit}/week</p>
              </div>
              <div className="bg-surface-up rounded-sm p-3 shadow-soft">
                <p className="text-cream/60 text-xs uppercase">Needed</p>
                <p className="font-display text-lg font-bold text-cream">{progress.neededRatePerWeek.toFixed(1)}</p>
                <p className="text-cream/30 text-xs">{unit}/week</p>
              </div>
            </div>
            <div className={`rounded-sm px-3 py-2 text-xs font-medium ${
              progress.paceStatus === 'ahead' ? 'bg-success/10 text-success border border-success/20' :
              progress.paceStatus === 'behind' ? 'bg-danger/10 text-danger border border-danger/20' :
              'bg-accent/10 text-accent border border-accent/20'
            }`}>
              {progress.paceStatus === 'ahead' && "You're crushing it — ahead of pace!"}
              {progress.paceStatus === 'on_track' && "Right on track — you're doing amazing!"}
              {progress.paceStatus === 'behind' && "Let's pick up the pace — you've got this!"}
            </div>
          </div>

          {/* Progress vs Plan */}
          {sparklineData && sparklineData.length >= 2 && (
            <div className="bg-surface-mid rounded-sm p-4 border border-black/5 shadow-soft">
              <p className="text-cream/60 text-xs uppercase tracking-wider mb-3">Progress vs Plan</p>
              <GoalSparkline data={sparklineData} startWeight={activeGoal.startWeight} targetWeight={activeGoal.targetWeight} />
              <div className="flex gap-4 mt-2 justify-center">
                <span className="flex items-center gap-1 text-xs text-cream/60"><span className="w-3 h-0.5 bg-accent rounded" /> Actual</span>
                <span className="flex items-center gap-1 text-xs text-cream/60"><span className="w-3 h-0.5 bg-cream/20 rounded" /> Ideal</span>
              </div>
            </div>
          )}

          {/* Milestones */}
          <div className="bg-surface-mid rounded-sm p-4 border border-black/5 shadow-soft">
            <p className="text-cream/60 text-xs uppercase tracking-wider mb-3">Milestones</p>
            <div className="space-y-1.5">
              {milestones.map((m, i) => (
                <div key={i} className={`flex items-center gap-3 px-3 py-2 rounded-sm ${m.reached ? 'bg-success/5' : 'bg-black/[0.02]'}`}>
                  <span className={`text-base ${m.reached ? '' : 'grayscale opacity-40'}`}>{m.icon}</span>
                  <span className={`text-sm flex-1 ${m.reached ? 'text-cream' : 'text-cream/30'}`}>{m.label}</span>
                  {m.reached ? (
                    <span className="text-success text-xs font-medium">Done</span>
                  ) : (
                    <span className="text-cream/20 text-xs">{m.pct}%</span>
                  )}
                </div>
              ))}
            </div>
          </div>

          {/* Weekly Targets */}
          {weeklyTargets.length > 0 && (
            <div className="bg-surface-mid rounded-sm p-4 border border-black/5 shadow-soft">
              <p className="text-cream/60 text-xs uppercase tracking-wider mb-3">Weekly Targets</p>
              <div className="space-y-1.5">
                {weeklyTargets.map(wt => (
                  <div key={wt.week} className={`flex items-center gap-3 px-3 py-2 rounded-sm ${
                    wt.isCurrent ? 'bg-accent/10 border border-accent/20' :
                    wt.isPast ? (wt.hit ? 'bg-success/5' : 'bg-black/[0.02]') : 'bg-black/[0.02]'
                  }`}>
                    <span className={`text-xs font-medium w-10 shrink-0 ${wt.isCurrent ? 'text-accent' : 'text-cream/30'}`}>Wk {wt.week}</span>
                    <span className={`text-sm flex-1 ${wt.isCurrent ? 'text-cream font-medium' : 'text-cream/60'}`}>{formatWeight(wt.target, unit)}</span>
                    {wt.actual !== null && <span className={`text-xs ${wt.hit ? 'text-success' : 'text-danger'}`}>{formatWeight(wt.actual, unit)}</span>}
                    <span className="text-cream/20 text-xs w-14 text-right shrink-0">{formatDateShort(wt.date)}</span>
                    {wt.isPast && <span className={`text-xs w-4 text-center ${wt.hit ? 'text-success' : 'text-danger'}`}>{wt.actual !== null ? (wt.hit ? '✓' : '✗') : '—'}</span>}
                    {wt.isCurrent && <span className="text-accent text-xs font-medium w-4 text-center">→</span>}
                    {!wt.isPast && !wt.isCurrent && <span className="w-4" />}
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Consistency */}
          {consistency && (
            <div className="bg-surface-mid rounded-sm p-4 border border-black/5 shadow-soft">
              <p className="text-cream/60 text-xs uppercase tracking-wider mb-3">Consistency</p>
              <div className="grid grid-cols-3 gap-3">
                <div className="bg-surface-up rounded-sm p-3 text-center shadow-soft">
                  <p className="text-cream/60 text-xs uppercase">Days Active</p>
                  <p className="font-display text-lg font-bold text-cream">{consistency.uniqueDays}</p>
                  <p className="text-cream/30 text-xs">of {consistency.daysActive}</p>
                </div>
                <div className="bg-surface-up rounded-sm p-3 text-center shadow-soft">
                  <p className="text-cream/60 text-xs uppercase">Consistency</p>
                  <p className={`font-display text-lg font-bold ${consistency.pct >= 80 ? 'text-success' : consistency.pct >= 50 ? 'text-warning' : 'text-danger'}`}>{consistency.pct}%</p>
                </div>
                <div className="bg-surface-up rounded-sm p-3 text-center shadow-soft">
                  <p className="text-cream/60 text-xs uppercase">This Week</p>
                  <p className="font-display text-lg font-bold text-cream">{consistency.thisWeekLogs}</p>
                  <p className="text-cream/30 text-xs">of {consistency.dayOfWeek} days</p>
                </div>
              </div>
            </div>
          )}
        </div>
      )}

      {/* Goal Form */}
      {showGoalForm && (
        <form onSubmit={handleCreateGoal} className="bg-surface-mid rounded-sm p-5 border border-black/5 space-y-4 mb-4 shadow-soft animate-fade-in">
          <h2 className="font-heading text-lg font-semibold text-cream">Set Your Target</h2>
          {activeGoal && (
            <p className="text-warning/80 text-xs bg-warning/10 border border-warning/20 rounded-sm px-3 py-2">
              Setting a new goal will move your current goal to history.
            </p>
          )}
          <div>
            <label className="block text-cream/60 text-xs font-medium mb-1 uppercase tracking-wider">Target Weight ({unit})</label>
            <input type="number" step="0.1" value={targetWeight} onChange={e => setTargetWeight(e.target.value)} placeholder="e.g. 175.0" className="w-full" required />
          </div>
          <div>
            <label className="block text-cream/60 text-xs font-medium mb-1 uppercase tracking-wider">Target Date</label>
            <input type="date" value={targetDate} onChange={e => setTargetDate(e.target.value)} min={todayStr()} className="w-full" required />
          </div>
          <div className="flex gap-3">
            <button type="submit" className="flex-1 bg-accent hover:bg-accent-dark text-white font-semibold py-2.5 rounded-sm transition-colors hover:shadow-glow">
              Let's Do This!
            </button>
            <button type="button" onClick={() => setShowGoalForm(false)} className="px-4 py-2.5 text-cream/60 hover:text-cream text-sm">Cancel</button>
          </div>
        </form>
      )}

      {/* Stats */}
      {stats && (
        <div className="grid grid-cols-2 desktop:grid-cols-4 gap-2 mb-4">
          <div className="bg-surface-mid rounded-sm p-4 border border-black/5 text-center shadow-soft">
            <p className="text-cream/60 text-xs uppercase tracking-wider">Logged</p>
            <p className="font-display text-xl text-cream">{stats.count}</p>
          </div>
          <div className="bg-surface-mid rounded-sm p-4 border border-black/5 text-center shadow-soft">
            <p className="text-cream/60 text-xs uppercase tracking-wider">Average</p>
            <p className="font-display text-xl text-cream">{formatWeight(stats.avg, unit)}</p>
          </div>
          <div className="bg-surface-mid rounded-sm p-4 border border-black/5 text-center shadow-soft">
            <p className="text-cream/60 text-xs uppercase tracking-wider">Lowest</p>
            <p className="font-display text-xl text-success">{formatWeight(stats.lowest.weight, unit)}</p>
            <p className="text-cream/30 text-xs">{formatDateShort(stats.lowest.date)}</p>
          </div>
          <div className="bg-surface-mid rounded-sm p-4 border border-black/5 text-center shadow-soft">
            <p className="text-cream/60 text-xs uppercase tracking-wider">Progress</p>
            {stats.change ? (
              <p className={`font-display text-xl ${stats.change.change < 0 ? 'text-success' : stats.change.change > 0 ? 'text-danger' : 'text-cream/60'}`}>
                {stats.change.change > 0 ? '+' : ''}{stats.change.change.toFixed(1)} {unit}
              </p>
            ) : (
              <p className="text-cream/30 text-xs">--</p>
            )}
          </div>
        </div>
      )}

      {/* Past Goals */}
      {goals.filter(g => !g.active).length > 0 && (
        <div className="mb-4">
          <p className="text-cream/60 text-xs uppercase tracking-wider mb-2">Past Goals</p>
          <div className="space-y-2">
            {goals.filter(g => !g.active).map(g => (
              <div key={g.id} className="bg-surface-up rounded-sm p-4 border border-black/5 flex justify-between items-center shadow-soft">
                <div>
                  <p className="text-cream/60 text-sm">Target: {formatWeight(g.targetWeight, unit)}</p>
                  <p className="text-cream/30 text-xs">From {formatWeight(g.startWeight, unit)}</p>
                </div>
                {confirmRemoveId === g.id ? (
                  <div className="flex gap-2">
                    <button onClick={() => handleRemoveGoal(g.id)} className="text-danger text-xs font-medium">Confirm</button>
                    <button onClick={() => setConfirmRemoveId(null)} className="text-cream/60 text-xs">Cancel</button>
                  </div>
                ) : (
                  <button onClick={() => setConfirmRemoveId(g.id)} className="text-cream/30 hover:text-danger text-xs">Remove</button>
                )}
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Entry List */}
      <div className="space-y-2">
        <p className="text-cream/60 text-xs uppercase tracking-wider mb-2">History</p>
        {filtered.length === 0 && (
          <div className="text-center py-12">
            <p className="text-cream/60">Nothing here yet — let's change that!</p>
            <p className="text-cream/40 text-sm mt-1">Use the + button to log your first entry!</p>
          </div>
        )}
        {pagedEntries.map(entry => (
          <div key={entry.id} className="bg-surface-mid rounded-sm p-4 border border-black/5 group shadow-soft hover:border-accent/20 transition-all">
            {editingId === entry.id ? (
              <div className="space-y-2">
                <div className="flex gap-2 items-center">
                  <input type="text" inputMode="decimal" value={editWeight} onChange={e => setEditWeight(e.target.value)} className="flex-1 text-sm py-1.5" autoFocus />
                  <span className="text-cream/60 text-xs">{unit}</span>
                </div>
                <input type="text" value={editNotes} onChange={e => setEditNotes(e.target.value)} placeholder="Notes (optional)" maxLength={200} className="w-full text-sm py-1.5" />
                <div className="flex gap-2">
                  <button onClick={() => saveEdit(entry.id)} className="text-accent text-xs font-medium">Save</button>
                  <button onClick={() => setEditingId(null)} className="text-cream/60 text-xs">Cancel</button>
                </div>
              </div>
            ) : (
              <div className="flex items-center justify-between">
                <div className="flex-1 cursor-pointer" onClick={() => startEdit(entry)}>
                  <div className="flex items-baseline gap-2">
                    <span className="text-cream font-semibold">{formatWeight(entry.weight, unit)}</span>
                    {entry.isMorning && <span className="text-accent text-xs uppercase tracking-wider font-medium">AM</span>}
                    <span className="text-cream/60 text-xs">{formatDate(entry.date)}</span>
                  </div>
                  {entry.notes && <p className="text-cream/60 text-xs mt-0.5">{entry.notes}</p>}
                </div>
                <div className="flex items-center gap-2">
                  <button onClick={() => startEdit(entry)} className="text-cream/20 hover:text-accent text-xs opacity-0 group-hover:opacity-100 transition-opacity">Edit</button>
                  {confirmDelete === entry.id ? (
                    <div className="flex gap-2">
                      <button onClick={() => handleDelete(entry.id)} className="text-danger text-xs font-medium">Delete</button>
                      <button onClick={() => setConfirmDelete(null)} className="text-cream/60 text-xs">Cancel</button>
                    </div>
                  ) : (
                    <button onClick={() => setConfirmDelete(entry.id)} className="text-cream/20 hover:text-danger text-xs opacity-0 group-hover:opacity-100 transition-opacity">Remove</button>
                  )}
                </div>
              </div>
            )}
          </div>
        ))}

        {hasMore && (
          <button onClick={() => setPage(p => p + 1)} className="w-full py-3 text-center text-accent text-sm font-medium hover:bg-surface-mid rounded-sm transition-colors">
            Show more ({filtered.length - pagedEntries.length} remaining)
          </button>
        )}
      </div>
    </div>
  );
}
