import React, { useMemo } from 'react';
import { useAppData, useAppActions } from '../App';
import { formatWeight, getWeightChange, getMovingAverage, getStreak, formatDateShort, aggregateDaily, daysAgo } from '../utils';
import { ResponsiveContainer, AreaChart, Area, XAxis, YAxis, Tooltip } from 'recharts';

function getGreeting(name) {
  const hour = new Date().getHours();
  const first = name?.split(' ')[0] || name;
  if (hour < 12) return `Good morning, ${first}!`;
  if (hour < 17) return `Hey there, ${first}!`;
  return `Good evening, ${first}!`;
}

function getStreakMessage(streak) {
  if (streak === 0) return "Let's get started today!";
  if (streak === 1) return "Great start! Day one down.";
  if (streak <= 3) return "You're building momentum!";
  if (streak <= 7) return "You're on a roll! Keep going!";
  if (streak <= 14) return "Two weeks strong! Amazing!";
  if (streak <= 30) return "Incredible consistency!";
  return "You're unstoppable!";
}

function getChangeMessage(change) {
  if (!change) return null;
  if (change.change < -2) return "You're making real progress!";
  if (change.change < 0) return "Trending in the right direction!";
  if (change.change === 0) return "Holding steady — that's great!";
  return null;
}

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

  const changeMsg = getChangeMessage(change);

  return (
    <div>
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="font-heading text-2xl font-bold text-cream">{getGreeting(displayName)}</h1>
          {streak > 0 && (
            <p className="text-cream/60 text-sm mt-0.5">{getStreakMessage(streak)}</p>
          )}
        </div>
        <button
          onClick={() => navigate('log')}
          className="bg-accent hover:bg-accent-dark text-white px-5 py-2.5 rounded-sm font-semibold text-sm transition-all shadow-soft hover:shadow-glow active:scale-95"
        >
          + Weigh In
        </button>
      </div>

      {/* Desktop two-column layout */}
      <div className="desktop:grid desktop:grid-cols-2 desktop:gap-5">
        {/* Left column */}
        <div>
          {/* Current Weight Card */}
          <div className="bg-surface-mid rounded-sm p-6 mb-4 border border-black/5 shadow-card">
            <p className="text-cream/60 text-sm font-medium mb-2">Your Weight</p>
            {latest ? (
              <>
                <div className="flex items-end gap-3">
                  <span className="font-display text-5xl font-extrabold text-cream tracking-tight">{formatWeight(latest.weight, unit)}</span>
                  {change && (
                    <span className={`text-sm font-semibold mb-2 ${change.change < 0 ? 'text-success' : change.change > 0 ? 'text-danger' : 'text-cream/50'}`}>
                      {change.change > 0 ? '+' : ''}{change.change.toFixed(1)} {unit}
                      <span className="text-cream/40 font-normal ml-1">30d</span>
                    </span>
                  )}
                </div>
                {changeMsg && (
                  <p className="text-accent text-sm font-medium mt-2">{changeMsg}</p>
                )}
              </>
            ) : (
              <div className="py-2">
                <p className="text-cream/50 text-lg mb-2">No entries yet</p>
                <p className="text-cream/40 text-sm">Tap "Weigh In" to log your first entry!</p>
              </div>
            )}
          </div>

          {/* Stats Row */}
          <div className="grid grid-cols-3 gap-3 mb-4">
            <div className="bg-surface-mid rounded-sm p-4 border border-black/5 text-center shadow-soft">
              <p className="text-cream/60 text-xs font-medium mb-1">Streak</p>
              <p className="font-display text-2xl font-bold text-accent">{streak}</p>
              <p className="text-cream/50 text-xs">{streak === 1 ? 'day' : 'days'}</p>
            </div>
            <div className="bg-surface-mid rounded-sm p-4 border border-black/5 text-center shadow-soft">
              <p className="text-cream/60 text-xs font-medium mb-1">Entries</p>
              <p className="font-display text-2xl font-bold text-cream">{weights.length}</p>
              <p className="text-cream/50 text-xs">logged</p>
            </div>
            <div
              className="bg-surface-mid rounded-sm p-4 border border-black/5 text-center cursor-pointer hover:border-accent/30 shadow-soft transition-all hover:shadow-card"
              onClick={() => navigate('goals')}
            >
              <p className="text-cream/60 text-xs font-medium mb-1">Goal</p>
              {goalProgress ? (
                <>
                  <p className="font-display text-2xl font-bold text-accent">{goalProgress.pct}%</p>
                  <p className="text-cream/50 text-xs">{goalProgress.remaining > 0 ? '+' : ''}{goalProgress.remaining.toFixed(1)} to go</p>
                </>
              ) : (
                <p className="text-accent text-sm mt-2 font-medium">Set one!</p>
              )}
            </div>
          </div>

          {/* Quick Actions */}
          <div className="grid grid-cols-2 gap-3">
            <button
              onClick={() => navigate('history')}
              className="bg-surface-mid hover:bg-surface-up border border-black/5 rounded-sm p-5 text-left transition-all shadow-soft hover:shadow-card group"
            >
              <p className="text-cream font-semibold text-sm group-hover:text-accent transition-colors">My Journey</p>
              <p className="text-cream/50 text-xs mt-1">See your progress</p>
            </button>
            <button
              onClick={() => navigate('circle')}
              className="bg-surface-mid hover:bg-surface-up border border-black/5 rounded-sm p-5 text-left transition-all shadow-soft hover:shadow-card group"
            >
              <p className="text-cream font-semibold text-sm group-hover:text-accent transition-colors">My Friends</p>
              <p className="text-cream/50 text-xs mt-1">Stay accountable</p>
            </button>
          </div>
        </div>

        {/* Right column - Chart */}
        <div>
          {chartData.length > 1 && (
            <div className="bg-surface-mid rounded-sm p-5 border border-black/5 mb-4 mt-4 desktop:mt-0 shadow-card">
              <div className="flex items-center justify-between mb-4">
                <p className="text-cream/60 text-sm font-medium">Your Week</p>
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
                    tick={{ fill: '#9B97A2', fontSize: 11 }}
                    axisLine={false}
                    tickLine={false}
                    interval="preserveStartEnd"
                  />
                  <YAxis
                    domain={['auto', 'auto']}
                    tick={{ fill: '#9B97A2', fontSize: 11 }}
                    axisLine={false}
                    tickLine={false}
                    width={42}
                  />
                  <Tooltip
                    contentStyle={{ background: '#FFFFFF', border: '1px solid rgba(0,0,0,0.08)', borderRadius: 12, color: '#2D2A33', boxShadow: '0 4px 12px rgba(0,0,0,0.08)', fontSize: 14 }}
                    labelFormatter={formatDateShort}
                    formatter={(v) => [formatWeight(v, unit)]}
                  />
                  <Area
                    type="monotone"
                    dataKey="weight"
                    stroke="#2B9B8F"
                    strokeWidth={2.5}
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
                    activeDot={{ r: 6, fill: '#2B9B8F', stroke: '#FFFFFF', strokeWidth: 2 }}
                  />
                  <Area type="monotone" dataKey="average" stroke="#7C9AB5" strokeWidth={1.5} strokeDasharray="4 4" fill="none" dot={false} />
                </AreaChart>
              </ResponsiveContainer>
              <div className="flex gap-5 mt-3 justify-center">
                <span className="flex items-center gap-1.5 text-xs text-cream/50">
                  <span className="w-4 h-0.5 bg-accent rounded"></span> Weight
                </span>
                <span className="flex items-center gap-1.5 text-xs text-cream/50">
                  <span className="w-4 h-0.5 bg-cold rounded border-dashed"></span> 7d Avg
                </span>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
