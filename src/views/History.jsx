import React, { useState, useMemo } from 'react';
import { useAppData, useAppActions } from '../App';
import { formatDate, formatWeight, getMovingAverage, getWeightChange, formatDateShort, aggregateDaily, buildCandlestickData, daysAgo } from '../utils';
import { ResponsiveContainer, LineChart, ComposedChart, Line, Bar, XAxis, YAxis, Tooltip, ReferenceLine } from 'recharts';

const PAGE_SIZE = 50;

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

export default function History() {
  const { weights, goals, unit } = useAppData();
  const { removeWeight, updateWeight, navigate, showToast } = useAppActions();
  const [range, setRange] = useState('30');
  const [confirmDelete, setConfirmDelete] = useState(null);
  const [chartMode, setChartMode] = useState('line');
  const [editingId, setEditingId] = useState(null);
  const [editWeight, setEditWeight] = useState('');
  const [editNotes, setEditNotes] = useState('');
  const [page, setPage] = useState(1);

  const activeGoal = goals.find(g => g.active);

  const filtered = useMemo(() => {
    if (range === 'all') return weights;
    const days = parseInt(range);
    const cutoff = daysAgo(days);
    return weights.filter(w => w.date >= cutoff);
  }, [weights, range]);

  // Reset page when range changes
  const handleRangeChange = (val) => {
    setRange(val);
    setPage(1);
  };

  const pagedEntries = useMemo(() => {
    return filtered.slice(0, page * PAGE_SIZE);
  }, [filtered, page]);

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
    const min = Math.floor(Math.min(...allLows) - 1);
    const max = Math.ceil(Math.max(...allHighs) + 1);
    return [min, max];
  }, [candlestickData]);

  // Stats for the filtered range
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

  return (
    <div className="max-w-3xl">
      <div className="flex items-center justify-between mb-5">
        <h1 className="font-heading text-2xl font-bold text-cream">Your Journey</h1>
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
        <div className="bg-surface-mid rounded-sm p-4 border border-black/5 mb-5 shadow-card">
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
                <Tooltip
                  contentStyle={{ background: '#F0EFEB', border: '1px solid rgba(45,42,51,0.06)', borderRadius: 12, fontSize: 14, color: '#2D2A33' }}
                  labelFormatter={formatDateShort}
                />
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
                  contentStyle={{ background: '#F0EFEB', border: '1px solid rgba(45,42,51,0.06)', borderRadius: 12, fontSize: 14, color: '#2D2A33' }}
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

      {/* Stats Panel */}
      {stats && (
        <div className="grid grid-cols-2 desktop:grid-cols-4 gap-2 mb-5">
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

      {/* Entry List */}
      <div className="space-y-2">
        {filtered.length === 0 && (
          <div className="text-center py-12">
            <p className="text-cream/60">Nothing here yet — let's change that!</p>
            <button onClick={() => navigate('log')} className="text-accent text-sm mt-2 hover:underline">Start your journey</button>
          </div>
        )}
        {pagedEntries.map(entry => (
          <div key={entry.id} className="bg-surface-mid rounded-sm p-4 border border-black/5 group shadow-soft hover:border-accent/20 transition-all">
            {editingId === entry.id ? (
              <div className="space-y-2">
                <div className="flex gap-2 items-center">
                  <input
                    type="text"
                    inputMode="decimal"
                    value={editWeight}
                    onChange={e => setEditWeight(e.target.value)}
                    className="flex-1 text-sm py-1.5"
                    autoFocus
                  />
                  <span className="text-cream/60 text-xs">{unit}</span>
                </div>
                <input
                  type="text"
                  value={editNotes}
                  onChange={e => setEditNotes(e.target.value)}
                  placeholder="Notes (optional)"
                  maxLength={200}
                  className="w-full text-sm py-1.5"
                />
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
                    {entry.isMorning && (
                      <span className="text-accent text-xs uppercase tracking-wider font-medium">AM</span>
                    )}
                    <span className="text-cream/60 text-xs">{formatDate(entry.date)}</span>
                  </div>
                  {entry.notes && <p className="text-cream/60 text-xs mt-0.5">{entry.notes}</p>}
                </div>
                <div className="flex items-center gap-2">
                  <button
                    onClick={() => startEdit(entry)}
                    className="text-cream/20 hover:text-accent text-xs opacity-0 group-hover:opacity-100 transition-opacity"
                  >
                    Edit
                  </button>
                  {confirmDelete === entry.id ? (
                    <div className="flex gap-2">
                      <button onClick={() => handleDelete(entry.id)} className="text-danger text-xs font-medium">Delete</button>
                      <button onClick={() => setConfirmDelete(null)} className="text-cream/60 text-xs">Cancel</button>
                    </div>
                  ) : (
                    <button
                      onClick={() => setConfirmDelete(entry.id)}
                      className="text-cream/20 hover:text-danger text-xs opacity-0 group-hover:opacity-100 transition-opacity"
                    >
                      Remove
                    </button>
                  )}
                </div>
              </div>
            )}
          </div>
        ))}

        {/* Load More */}
        {hasMore && (
          <button
            onClick={() => setPage(p => p + 1)}
            className="w-full py-3 text-center text-accent text-sm font-medium hover:bg-surface-mid rounded-sm transition-colors"
          >
            Show me more ({filtered.length - pagedEntries.length} remaining)
          </button>
        )}
      </div>
    </div>
  );
}
