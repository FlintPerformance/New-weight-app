import React, { useMemo } from 'react';
import { useAppData, useAppActions } from '../App';
import { formatWeight, getWeightChange, getMovingAverage, getStreak, formatDateShort, aggregateDaily, daysAgo } from '../utils';
import { ResponsiveContainer, AreaChart, Area, XAxis, YAxis, Tooltip } from 'recharts';

export default function Dashboard() {
  const { weights, goals, unit, displayName } = useAppData();
  const { navigate } = useAppActions();

  const latest = weights[0];
  const activeGoal = goals.find(g => g.active);
  const streak = getStreak(weights);
  const last30 = weights.filter(w => w.date >= daysAgo(30));
  const change = getWeightChange(last30);

  const chartData = useMemo(() => {
    const cutoff = daysAgo(7);
    const recent = weights.filter(w => w.date >= cutoff);
    const daily = aggregateDaily(recent, 'morning');
    return getMovingAverage(daily);
  }, [weights]);

  const goalProgress = useMemo(() => {
    if (!activeGoal || !latest) return null;
    const total = Math.abs(activeGoal.startWeight - activeGoal.targetWeight);
    const current = Math.abs(activeGoal.startWeight - latest.weight);
    const pct = total === 0 ? 100 : Math.min(100, Math.round((current / total) * 100));
    return { pct, remaining: activeGoal.targetWeight - latest.weight };
  }, [activeGoal, latest]);

  return (
    <div>
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <p className="text-cream/50 text-sm">Welcome back,</p>
          <h1 className="font-heading text-2xl font-bold text-cream">{displayName}</h1>
        </div>
        <button
          onClick={() => navigate('log')}
          className="bg-accent hover:bg-accent-dark text-white px-4 py-2 rounded-sm font-semibold text-sm transition-colors shadow-sm"
        >
          + Log Weight
        </button>
      </div>

      {/* Desktop two-column layout */}
      <div className="desktop:grid desktop:grid-cols-2 desktop:gap-4">
        {/* Left column */}
        <div>
          {/* Current Weight Card */}
          <div className="bg-surface-mid rounded-sm p-5 mb-4 border border-black/5 shadow-sm">
            <p className="text-cream/50 text-xs uppercase tracking-wider mb-1">Current Weight</p>
            {latest ? (
              <div className="flex items-end gap-3">
                <span className="font-display text-5xl font-extrabold text-cream">{formatWeight(latest.weight, unit)}</span>
                {change && (
                  <span className={`text-sm font-medium mb-2 ${change.change < 0 ? 'text-success' : change.change > 0 ? 'text-danger' : 'text-cream/50'}`}>
                    {change.change > 0 ? '+' : ''}{change.change.toFixed(1)} {unit} (30d)
                  </span>
                )}
              </div>
            ) : (
              <p className="text-cream/40 text-lg">No entries yet</p>
            )}
          </div>

          {/* Stats Row */}
          <div className="grid grid-cols-3 gap-3 mb-4">
            <div className="bg-surface-mid rounded-sm p-3 border border-black/5 text-center shadow-sm">
              <p className="text-cream/50 text-[10px] uppercase tracking-wider">Streak</p>
              <p className="font-display text-2xl font-bold text-accent">{streak}</p>
              <p className="text-cream/40 text-[10px]">days</p>
            </div>
            <div className="bg-surface-mid rounded-sm p-3 border border-black/5 text-center shadow-sm">
              <p className="text-cream/50 text-[10px] uppercase tracking-wider">Entries</p>
              <p className="font-display text-2xl font-bold text-cream">{weights.length}</p>
              <p className="text-cream/40 text-[10px]">total</p>
            </div>
            <div
              className="bg-surface-mid rounded-sm p-3 border border-black/5 text-center cursor-pointer hover:border-accent/30 shadow-sm transition-colors"
              onClick={() => navigate('goals')}
            >
              <p className="text-cream/50 text-[10px] uppercase tracking-wider">Goal</p>
              {goalProgress ? (
                <>
                  <p className="font-display text-2xl font-bold text-accent">{goalProgress.pct}%</p>
                  <p className="text-cream/40 text-[10px]">{goalProgress.remaining > 0 ? '+' : ''}{goalProgress.remaining.toFixed(1)} to go</p>
                </>
              ) : (
                <p className="text-cream/40 text-xs mt-1">Set goal</p>
              )}
            </div>
          </div>

          {/* Quick Actions */}
          <div className="grid grid-cols-2 gap-3">
            <button
              onClick={() => navigate('history')}
              className="bg-surface-mid hover:bg-surface-up border border-black/5 rounded-sm p-4 text-left transition-colors shadow-sm"
            >
              <p className="text-cream font-medium text-sm">View History</p>
              <p className="text-cream/40 text-xs mt-1">All your entries</p>
            </button>
            <button
              onClick={() => navigate('circle')}
              className="bg-surface-mid hover:bg-surface-up border border-black/5 rounded-sm p-4 text-left transition-colors shadow-sm"
            >
              <p className="text-cream font-medium text-sm">My Circle</p>
              <p className="text-cream/40 text-xs mt-1">Accountability partners</p>
            </button>
          </div>
        </div>

        {/* Right column - Chart */}
        <div>
          {chartData.length > 1 && (
            <div className="bg-surface-mid rounded-sm p-4 border border-black/5 mb-4 mt-4 desktop:mt-0 shadow-sm">
              <div className="flex items-center justify-between mb-3">
                <p className="text-cream/50 text-xs uppercase tracking-wider">Last 7 Days</p>
              </div>
              <ResponsiveContainer width="100%" height={280}>
                <AreaChart data={chartData}>
                  <defs>
                    <linearGradient id="weightGrad" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="0%" stopColor="#2B9B8F" stopOpacity={0.2} />
                      <stop offset="100%" stopColor="#2B9B8F" stopOpacity={0} />
                    </linearGradient>
                  </defs>
                  <XAxis
                    dataKey="date"
                    tickFormatter={formatDateShort}
                    tick={{ fill: '#9B97A2', fontSize: 10 }}
                    axisLine={false}
                    tickLine={false}
                    interval="preserveStartEnd"
                  />
                  <YAxis
                    domain={['auto', 'auto']}
                    tick={{ fill: '#9B97A2', fontSize: 10 }}
                    axisLine={false}
                    tickLine={false}
                    width={40}
                  />
                  <Tooltip
                    contentStyle={{ background: '#FFFFFF', border: '1px solid rgba(0,0,0,0.08)', borderRadius: 8, color: '#2D2A33', boxShadow: '0 2px 8px rgba(0,0,0,0.08)' }}
                    labelFormatter={formatDateShort}
                    formatter={(v) => [formatWeight(v, unit)]}
                  />
                  <Area
                    type="monotone"
                    dataKey="weight"
                    stroke="#2B9B8F"
                    strokeWidth={2}
                    fill="url(#weightGrad)"
                    dot={(props) => {
                      const { cx, cy, index } = props;
                      const isLast = index === chartData.length - 1;
                      return (
                        <circle
                          key={index}
                          cx={cx}
                          cy={cy}
                          r={isLast ? 5 : 2.5}
                          fill="#2B9B8F"
                          stroke={isLast ? '#FFFFFF' : 'none'}
                          strokeWidth={isLast ? 2 : 0}
                        />
                      );
                    }}
                    activeDot={{ r: 5, fill: '#2B9B8F', stroke: '#FFFFFF', strokeWidth: 2 }}
                  />
                  <Area type="monotone" dataKey="average" stroke="#7C9AB5" strokeWidth={1.5} strokeDasharray="4 4" fill="none" dot={false} />
                </AreaChart>
              </ResponsiveContainer>
              <div className="flex gap-4 mt-2 justify-center">
                <span className="flex items-center gap-1 text-[10px] text-cream/40">
                  <span className="w-3 h-0.5 bg-accent rounded"></span> Weight
                </span>
                <span className="flex items-center gap-1 text-[10px] text-cream/40">
                  <span className="w-3 h-0.5 bg-cold rounded border-dashed"></span> 7d Avg
                </span>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
