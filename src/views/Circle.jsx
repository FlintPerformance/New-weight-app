import React, { useState, useEffect, useCallback, useMemo } from 'react';
import { useAppData, useAppActions } from '../App';
import { supabase } from '../supabase';
import { formatWeight, formatDateShort, formatDate, getWeightChange, getStreak, generateId, todayStr, daysAgo, localDateStr, aggregateDaily, sanitizeText } from '../utils';
import { saveCircleCache, getCircleCache } from '../db';
import { ResponsiveContainer, LineChart, Line, XAxis, YAxis, Tooltip } from 'recharts';
import Avatar from '../components/Avatar';

const REACTIONS = [
  { emoji: '🔥', label: 'Fire' },
  { emoji: '💪', label: 'Strong' },
  { emoji: '👏', label: 'Clap' },
  { emoji: '🎯', label: 'Target' },
  { emoji: '❤️', label: 'Love' }
];

const DEFAULT_COLORS = ['#3b82f6', '#22c55e', '#a855f7', '#f59e0b', '#ec4899', '#06b6d4', '#ef4444', '#2B9B8F'];

export default function Circle() {
  const { user, unit, weights: localWeights, displayName, pendingInvite, view } = useAppData();
  const { showToast, clearPendingInvite } = useAppActions();
  const [tab, setTab] = useState('feed');
  const [circles, setCircles] = useState([]);
  const [members, setMembers] = useState([]);
  const [feed, setFeed] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showCreate, setShowCreate] = useState(false);
  const [showJoin, setShowJoin] = useState(false);
  const [circleName, setCircleName] = useState('');
  const [joinCode, setJoinCode] = useState('');
  const [reactions, setReactions] = useState({});
  const [showReactionPicker, setShowReactionPicker] = useState(null);
  const [selectedCircle, setSelectedCircle] = useState(null);
  const [compareRange, setCompareRange] = useState('7');
  const [showCircleInfo, setShowCircleInfo] = useState(false);
  const [predictions, setPredictions] = useState([]);
  const [predictionVotes, setPredictionVotes] = useState({});
  const [showNewPrediction, setShowNewPrediction] = useState(false);
  const [predictionWeight, setPredictionWeight] = useState('');
  const [predictionDeadline, setPredictionDeadline] = useState('30');
  const [predictionMessage, setPredictionMessage] = useState('');
  const [feedPage, setFeedPage] = useState(1);
  const FEED_PAGE_SIZE = 30;

  // Load cached circle data from IndexedDB on mount
  useEffect(() => {
    let cancelled = false;
    getCircleCache(user.id).then(cached => {
      if (cancelled || !cached) return;
      setCircles(cached.circles || []);
      setMembers(cached.members || []);
      setFeed(cached.feed || []);
      setReactions(cached.reactions || {});
      setPredictions(cached.predictions || []);
      setPredictionVotes(cached.predictionVotes || {});
      setLoading(false);
    }).catch(() => {});
    return () => { cancelled = true; };
  }, [user.id]);

  const loadCircleData = useCallback(async () => {
    try {
      const { data: memberRows } = await supabase
        .from('circle_members')
        .select('circle_id, role, circles(id, name, invite_code, created_by)')
        .eq('user_id', user.id);

      const userCircles = (memberRows || []).map(m => ({ ...m.circles, role: m.role }));
      setCircles(userCircles);

      if (userCircles.length === 0) { setLoading(false); return; }

      const circleIds = userCircles.map(c => c.id);

      const { data: allMembers, error: membersErr } = await supabase
        .from('circle_members')
        .select('user_id, circle_id, role')
        .in('circle_id', circleIds);

      if (membersErr) console.error('Members query error:', membersErr);

      const memberIds = [...new Set((allMembers || []).map(m => m.user_id))];

      let profileRows = [];
      let sharedWeights = [];
      if (memberIds.length > 0) {
        const [profileRes, weightsRes] = await Promise.all([
          supabase.from('profiles').select('id, display_name, avatar_url, graph_color').in('id', memberIds),
          supabase.from('weight_entries').select('*').in('user_id', memberIds).order('date', { ascending: false }).limit(500),
        ]);
        if (profileRes.error) console.error('Profiles query error:', profileRes.error);
        if (weightsRes.error) console.error('Weight entries query error:', weightsRes.error);
        profileRows = profileRes.data || [];
        sharedWeights = weightsRes.data || [];
      }

      const profileById = {};
      profileRows.forEach(p => { profileById[p.id] = p; });

      const membersWithProfiles = (allMembers || []).map(m => ({
        ...m,
        profiles: profileById[m.user_id] || { display_name: 'Unknown', avatar_url: null, graph_color: null }
      }));

      setMembers(membersWithProfiles);

      let reactionMap = {};
      const entryIds = sharedWeights.map(w => w.id);
      if (entryIds.length) {
        const { data: cheerData } = await supabase
          .from('cheers')
          .select('entry_id, user_id, emoji')
          .in('entry_id', entryIds);
        (cheerData || []).forEach(c => {
          if (!reactionMap[c.entry_id]) reactionMap[c.entry_id] = [];
          reactionMap[c.entry_id].push({ user_id: c.user_id, emoji: c.emoji || '🔥' });
        });
        setReactions(reactionMap);
      }

      // Load predictions for all circles
      const { data: predictionData } = await supabase
        .from('predictions')
        .select('*')
        .in('circle_id', circleIds)
        .order('created_at', { ascending: false });

      setPredictions(predictionData || []);

      // Load votes for all predictions
      let voteMap = {};
      const predictionIds = (predictionData || []).map(p => p.id);
      if (predictionIds.length) {
        const { data: voteData } = await supabase
          .from('prediction_votes')
          .select('prediction_id, user_id, vote')
          .in('prediction_id', predictionIds);
        (voteData || []).forEach(v => {
          if (!voteMap[v.prediction_id]) voteMap[v.prediction_id] = [];
          voteMap[v.prediction_id].push(v);
        });
        setPredictionVotes(voteMap);
      }

      const profileMap = {};
      const avatarMap = {};
      membersWithProfiles.forEach(m => {
        profileMap[m.user_id] = m.profiles?.display_name || 'Unknown';
        avatarMap[m.user_id] = m.profiles?.avatar_url || null;
      });

      const cloudIds = new Set(sharedWeights.map(w => w.id));
      const localOnly = localWeights
        .filter(w => !cloudIds.has(w.id))
        .map(w => ({
          id: w.id, user_id: user.id, date: w.date, weight: w.weight,
          unit: w.unit, notes: w.notes, is_morning: w.isMorning || false,
          updated_at: new Date(w.updatedAt).toISOString()
        }));

      const allWeights = [...sharedWeights, ...localOnly]
        .sort((a, b) => b.updated_at.localeCompare(a.updated_at))
        .slice(0, 500);

      const feedItems = allWeights.map(w => ({
        ...w,
        displayName: profileMap[w.user_id] || displayName,
        avatarUrl: avatarMap[w.user_id] || null,
        isOwn: w.user_id === user.id
      }));

      setFeed(feedItems);

      // Cache to IndexedDB for instant load next time
      saveCircleCache(user.id, {
        circles: userCircles,
        members: membersWithProfiles,
        feed: feedItems,
        reactions: reactionMap,
        predictions: predictionData || [],
        predictionVotes: voteMap || {},
      }).catch(() => {});
    } catch (err) {
      console.error('Circle load error:', err);
    } finally {
      setLoading(false);
    }
  }, [user.id, localWeights, displayName]);

  useEffect(() => { loadCircleData(); }, [loadCircleData]);

  // Refresh feed when user navigates to the circle tab
  const prevView = React.useRef(view);
  useEffect(() => {
    if (view === 'circle' && prevView.current !== 'circle') {
      loadCircleData();
    }
    prevView.current = view;
  }, [view, loadCircleData]);

  useEffect(() => {
    if (!pendingInvite || loading) return;
    const autoJoin = async () => {
      try {
        const { data: circle, error } = await supabase
          .from('circles').select('id')
          .eq('invite_code', pendingInvite.trim().toUpperCase()).single();
        if (error || !circle) { showToast('Invalid invite code', 'error'); return; }
        const { error: joinErr } = await supabase.from('circle_members').insert({
          circle_id: circle.id, user_id: user.id, role: 'member'
        });
        if (joinErr) {
          if (joinErr.code === '23505') showToast('Already in this circle');
          else throw joinErr;
        } else { showToast('Joined circle!'); }
        await loadCircleData();
      } catch (err) { showToast(err.message, 'error'); }
      finally { clearPendingInvite(); }
    };
    autoJoin();
  }, [pendingInvite, loading, user.id, showToast, clearPendingInvite, loadCircleData]);

  const createCircle = async (e) => {
    e.preventDefault();
    if (!circleName.trim()) return;
    try {
      const inviteCode = generateId().toUpperCase().slice(0, 6);
      const { data: circle, error } = await supabase
        .from('circles').insert({ name: sanitizeText(circleName), created_by: user.id, invite_code: inviteCode })
        .select().single();
      if (error) throw error;
      const { error: memberErr } = await supabase.from('circle_members').insert({
        circle_id: circle.id, user_id: user.id, role: 'owner'
      });
      if (memberErr) throw memberErr;
      showToast('Circle created!');
      setCircleName('');
      setShowCreate(false);
      await loadCircleData();
    } catch (err) { showToast(err.message, 'error'); }
  };

  const joinCircle = async (e) => {
    e.preventDefault();
    if (!joinCode.trim()) return;
    try {
      const { data: circle, error } = await supabase
        .from('circles').select('id')
        .eq('invite_code', joinCode.trim().toUpperCase()).single();
      if (error || !circle) { showToast('Invalid invite code', 'error'); return; }
      const { error: joinErr } = await supabase.from('circle_members').insert({
        circle_id: circle.id, user_id: user.id, role: 'member'
      });
      if (joinErr) {
        if (joinErr.code === '23505') showToast('Already in this circle', 'warning');
        else throw joinErr;
        return;
      }
      showToast('Joined circle!');
      setJoinCode('');
      setShowJoin(false);
      await loadCircleData();
    } catch (err) { showToast(err.message, 'error'); }
  };

  const handleReaction = async (entryId, emoji) => {
    try {
      const entryReactions = reactions[entryId] || [];
      const existing = entryReactions.find(r => r.user_id === user.id && r.emoji === emoji);
      if (existing) {
        await supabase.from('cheers').delete()
          .eq('entry_id', entryId).eq('user_id', user.id).eq('emoji', emoji);
      } else {
        await supabase.from('cheers').insert({ entry_id: entryId, user_id: user.id, emoji });

        // Send push notification to the entry owner (fire and forget)
        const entry = filteredFeed.find(f => f.id === entryId);
        if (entry && entry.user_id !== user.id) {
          supabase.functions.invoke('send-reaction-notification', {
            body: { entry_owner_id: entry.user_id, reactor_name: displayName, emoji },
          }).then(({ error }) => {
            if (error) console.error('Reaction notification failed:', error);
          }).catch(err => console.error('Reaction notification error:', err));
        }
      }
      setReactions(prev => {
        const list = [...(prev[entryId] || [])];
        if (existing) {
          return { ...prev, [entryId]: list.filter(r => !(r.user_id === user.id && r.emoji === emoji)) };
        }
        return { ...prev, [entryId]: [...list, { user_id: user.id, emoji }] };
      });
      setShowReactionPicker(null);
    } catch (err) { showToast('Failed to react', 'error'); }
  };

  const VOTE_OPTIONS = [
    { key: 'nails_it', emoji: '🎯', label: 'Nails it', desc: 'Within 0.5 lb' },
    { key: 'overshoots', emoji: '📈', label: 'Overshoots', desc: '0.5–1.5 lb past' },
    { key: 'falls_short', emoji: '📉', label: 'Falls short', desc: "Doesn't reach" },
    { key: 'crushes_it', emoji: '🔥', label: 'Crushes it', desc: '1.5+ lb past' },
  ];

  const resolvePrediction = (prediction) => {
    if (!prediction.actual_weight) return null;
    const target = Number(prediction.predicted_weight);
    const actual = Number(prediction.actual_weight);
    const start = Number(prediction.start_weight);
    // Direction: losing if target < start, gaining if target > start
    const isLosing = target < start;
    const diff = isLosing ? target - actual : actual - target;
    // diff > 0 means overshot (went past target in the intended direction)
    // diff < 0 means fell short
    const absDiff = Math.abs(diff);

    if (absDiff <= 0.5) return 'nails_it';
    if (diff > 0 && absDiff <= 1.5) return 'overshoots';
    if (diff > 0 && absDiff > 1.5) return 'crushes_it';
    return 'falls_short';
  };

  const createPrediction = async () => {
    if (!predictionWeight || !circles.length) return;
    const targetCircle = selectedCircle || circles[0].id;
    const latestWeight = localWeights.length > 0
      ? [...localWeights].sort((a, b) => b.date.localeCompare(a.date))[0].weight
      : null;
    if (!latestWeight) {
      showToast('Log a weight first', 'error');
      return;
    }
    const deadlineDate = new Date();
    deadlineDate.setDate(deadlineDate.getDate() + parseInt(predictionDeadline));
    try {
      const { error } = await supabase.from('predictions').insert({
        user_id: user.id,
        circle_id: targetCircle,
        predicted_weight: parseFloat(predictionWeight),
        start_weight: latestWeight,
        unit,
        deadline: localDateStr(deadlineDate),
        message: sanitizeText(predictionMessage) || null,
      });
      if (error) throw error;
      showToast('Prediction locked in!');
      setShowNewPrediction(false);
      setPredictionWeight('');
      setPredictionMessage('');
      await loadCircleData();
    } catch (err) { showToast(err.message, 'error'); }
  };

  const handleVote = async (predictionId, vote) => {
    try {
      const existing = (predictionVotes[predictionId] || []).find(v => v.user_id === user.id);
      if (existing) {
        if (existing.vote === vote) {
          await supabase.from('prediction_votes').delete()
            .eq('prediction_id', predictionId).eq('user_id', user.id);
        } else {
          await supabase.from('prediction_votes')
            .update({ vote })
            .eq('prediction_id', predictionId).eq('user_id', user.id);
        }
      } else {
        await supabase.from('prediction_votes').insert({
          prediction_id: predictionId, user_id: user.id, vote,
        });
      }
      // Optimistic update
      setPredictionVotes(prev => {
        const list = [...(prev[predictionId] || [])];
        const idx = list.findIndex(v => v.user_id === user.id);
        if (idx >= 0) {
          if (list[idx].vote === vote) list.splice(idx, 1);
          else list[idx] = { ...list[idx], vote };
        } else {
          list.push({ prediction_id: predictionId, user_id: user.id, vote });
        }
        return { ...prev, [predictionId]: list };
      });
    } catch (err) { showToast('Failed to vote', 'error'); }
  };

  const checkAndResolvePredictions = useCallback(async () => {
    const today = todayStr();
    const toResolve = predictions.filter(p => p.status === 'active' && p.deadline <= today);
    for (const pred of toResolve) {
      // Get 3-day average around deadline for fairness
      const deadlineDate = new Date(pred.deadline + 'T00:00:00');
      const dayBefore = new Date(deadlineDate); dayBefore.setDate(dayBefore.getDate() - 1);
      const dayAfter = new Date(deadlineDate); dayAfter.setDate(dayAfter.getDate() + 1);
      const range = [dayBefore, deadlineDate, dayAfter].map(d => localDateStr(d));

      const { data: weights } = await supabase
        .from('weight_entries')
        .select('weight')
        .eq('user_id', pred.user_id)
        .in('date', range);

      if (!weights || weights.length === 0) continue;

      const avg = weights.reduce((s, w) => s + Number(w.weight), 0) / weights.length;
      const actualWeight = Number(avg.toFixed(1));
      const result = resolvePrediction({ ...pred, actual_weight: actualWeight });

      await supabase.from('predictions').update({
        status: 'resolved',
        actual_weight: actualWeight,
        result,
        resolved_at: new Date().toISOString(),
      }).eq('id', pred.id);
    }
    if (toResolve.length > 0) await loadCircleData();
  }, [predictions, loadCircleData]);

  useEffect(() => { if (predictions.length) checkAndResolvePredictions(); }, [predictions.length]);

  const [confirmLeaveId, setConfirmLeaveId] = useState(null);

  const leaveCircle = async (circleId) => {
    try {
      await supabase.from('circle_members').delete().eq('circle_id', circleId).eq('user_id', user.id);
      showToast('Left circle');
      setConfirmLeaveId(null);
      await loadCircleData();
    } catch (err) { showToast(err.message, 'error'); }
  };

  const filteredPredictions = useMemo(() => {
    if (!selectedCircle) return predictions;
    return predictions.filter(p => p.circle_id === selectedCircle);
  }, [predictions, selectedCircle]);

  // Check if user has an active prediction in the current circle scope
  const hasActivePrediction = useMemo(() => {
    return filteredPredictions.some(p => p.user_id === user.id && p.status === 'active');
  }, [filteredPredictions, user.id]);

  // Predictor leaderboard — accuracy across all visible predictions
  const predictorStats = useMemo(() => {
    const resolved = filteredPredictions.filter(p => p.status === 'resolved' && p.result);
    if (!resolved.length) return [];
    const stats = {};
    resolved.forEach(pred => {
      const votes = predictionVotes[pred.id] || [];
      votes.forEach(v => {
        if (!stats[v.user_id]) stats[v.user_id] = { correct: 0, total: 0 };
        stats[v.user_id].total++;
        if (v.vote === pred.result) stats[v.user_id].correct++;
      });
    });
    return Object.entries(stats)
      .map(([userId, s]) => ({ userId, ...s, accuracy: s.total > 0 ? s.correct / s.total : 0 }))
      .sort((a, b) => b.accuracy - a.accuracy || b.total - a.total);
  }, [filteredPredictions, predictionVotes]);

  const filteredMembers = useMemo(() => {
    if (!selectedCircle) return members;
    return members.filter(m => m.circle_id === selectedCircle);
  }, [members, selectedCircle]);

  const filteredFeed = useMemo(() => {
    if (!selectedCircle) return feed;
    const circleMemberIds = new Set(filteredMembers.map(m => m.user_id));
    return feed.filter(f => circleMemberIds.has(f.user_id));
  }, [feed, selectedCircle, filteredMembers]);

  // Compute feed badges (milestones, streaks, new lows)
  const feedWithBadges = useMemo(() => {
    // Group all entries by user to compute context
    const byUser = {};
    filteredFeed.forEach(e => {
      if (!byUser[e.user_id]) byUser[e.user_id] = [];
      byUser[e.user_id].push(e);
    });

    return filteredFeed.map(entry => {
      const userEntries = byUser[entry.user_id] || [];
      const idx = userEntries.indexOf(entry);
      const badges = [];

      // New personal low (within user's history)
      const allBefore = userEntries.slice(idx);
      if (allBefore.length > 1) {
        const minBefore = Math.min(...allBefore.slice(1).map(e => e.weight));
        if (entry.weight < minBefore) badges.push({ icon: '⬇️', text: 'New Low' });
      }

      // Streak milestones
      const entriesBefore = userEntries.slice(idx);
      const streak = getStreak(entriesBefore);
      if (streak > 0 && streak % 7 === 0) badges.push({ icon: '🔥', text: `${streak}-day streak` });

      // Entry count milestones
      const totalAfter = userEntries.length - idx;
      if ([10, 25, 50, 100, 200].includes(totalAfter)) badges.push({ icon: '🏆', text: `${totalAfter} entries` });

      // Morning check-in
      if (entry.is_morning) badges.push({ icon: '🌅', text: 'Morning weigh-in' });

      return { ...entry, badges };
    });
  }, [filteredFeed]);

  const memberStats = useMemo(() => {
    let unique = filteredMembers.filter((m, i, arr) => arr.findIndex(x => x.user_id === m.user_id) === i);
    const activeCircles = selectedCircle ? circles.filter(c => c.id === selectedCircle) : circles;
    if (activeCircles.length > 0 && !unique.some(m => m.user_id === user.id)) {
      unique = [...unique, {
        user_id: user.id, circle_id: activeCircles[0].id,
        role: activeCircles[0].role || 'member',
        profiles: { display_name: displayName, avatar_url: null, graph_color: null }
      }];
    }
    const today = todayStr();
    const d7 = daysAgo(7);
    const d30 = daysAgo(30);

    return unique.map((member, i) => {
      const allWeights = filteredFeed.filter(f => f.user_id === member.user_id);
      const latest = allWeights[0];
      const streak = getStreak(allWeights);
      const totalEntries = allWeights.length;
      const last7 = allWeights.filter(w => w.date >= d7);
      const last30 = allWeights.filter(w => w.date >= d30);
      const change7 = getWeightChange(last7);
      const change30 = getWeightChange(last30);
      const loggedToday = allWeights.some(w => w.date === today);
      const recentDays = allWeights.slice(0, 7).reverse();
      const color = member.profiles?.graph_color || DEFAULT_COLORS[i % DEFAULT_COLORS.length];
      const avg7 = last7.length > 0 ? last7.reduce((s, w) => s + w.weight, 0) / last7.length : null;

      return {
        ...member, latest, streak, avg7, change7, change30,
        loggedToday, recentDays, isYou: member.user_id === user.id, color,
      };
    }).sort((a, b) => b.streak - a.streak);
  }, [filteredMembers, filteredFeed, user.id, circles, selectedCircle, displayName]);

  // Compare chart data — one line per member
  const compareData = useMemo(() => {
    if (tab !== 'compare') return [];
    const days = parseInt(compareRange);
    const cutoff = daysAgo(days);
    const dateSet = new Set();
    const byUserDate = {};

    filteredFeed.forEach(e => {
      if (e.date < cutoff) return;
      dateSet.add(e.date);
      const key = `${e.user_id}:${e.date}`;
      // Keep first (most recent) entry per user per day
      if (!byUserDate[key]) byUserDate[key] = e.weight;
    });

    const dates = [...dateSet].sort();
    return dates.map(date => {
      const point = { date };
      memberStats.forEach(m => {
        const key = `${m.user_id}:${date}`;
        if (byUserDate[key] != null) point[m.user_id] = byUserDate[key];
      });
      return point;
    });
  }, [tab, compareRange, filteredFeed, memberStats]);

  if (loading) {
    return (
      <div className="max-w-3xl">
        <h1 className="font-heading text-2xl font-bold text-cream mb-6">My Circle</h1>
        <div className="text-cream/60 text-center py-12 animate-pulse-accent">Loading circles...</div>
      </div>
    );
  }

  return (
    <div className="max-w-3xl">
      <div className="flex items-center justify-between mb-4">
        <h1 className="font-heading text-2xl font-bold text-cream">My Circle</h1>
        <div className="flex gap-2">
          {circles.length > 0 && (
            <button onClick={() => setShowCircleInfo(!showCircleInfo)} className="text-cream/60 hover:text-cream text-xs transition-colors">
              {showCircleInfo ? 'Hide info' : 'Manage'}
            </button>
          )}
          <button onClick={() => { setShowJoin(true); setShowCreate(false); }} className="text-accent text-xs font-medium hover:underline">Join</button>
          <button onClick={() => { setShowCreate(true); setShowJoin(false); }} className="bg-accent hover:bg-accent-dark text-white px-3 py-1.5 rounded-sm text-xs font-semibold transition-colors">
            + Start
          </button>
        </div>
      </div>

      {/* Circle Info Panel (replaces old Circles tab) */}
      {showCircleInfo && circles.length > 0 && (
        <div className="space-y-2 mb-4 animate-slide-up">
          {circles.map(circle => {
            const circleMembers = members.filter(m => m.circle_id === circle.id);
            return (
              <div key={circle.id} className="bg-surface-mid rounded-sm p-4 border border-black/5 shadow-soft flex items-center justify-between">
                <div className="flex items-center gap-3 min-w-0">
                  <div className="flex -space-x-1.5">
                    {circleMembers.slice(0, 4).map(m => (
                      <Avatar key={m.user_id} url={m.profiles?.avatar_url} name={m.profiles?.display_name || '?'} size="xs" />
                    ))}
                  </div>
                  <div className="min-w-0">
                    <p className="text-cream text-sm font-medium truncate">{circle.name}</p>
                    <p className="text-cream/50 text-xs">{circleMembers.length} members · Code: {circle.invite_code}</p>
                  </div>
                </div>
                <div className="flex items-center gap-2 shrink-0">
                  <button
                    onClick={() => {
                      navigator.clipboard.writeText(`${window.location.origin}?join=${circle.invite_code}`);
                      showToast('Invite link copied!');
                    }}
                    className="text-accent text-xs hover:underline"
                  >
                    Copy link
                  </button>
                  {confirmLeaveId === circle.id ? (
                    <span className="flex gap-1.5">
                      <button onClick={() => leaveCircle(circle.id)} className="text-danger text-xs font-medium">Confirm</button>
                      <button onClick={() => setConfirmLeaveId(null)} className="text-cream/50 text-xs">Cancel</button>
                    </span>
                  ) : (
                    <button onClick={() => setConfirmLeaveId(circle.id)} className="text-cream/40 hover:text-danger text-xs">Leave Circle</button>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Create Circle Form */}
      {showCreate && (
        <form onSubmit={createCircle} className="bg-surface-mid rounded-sm p-5 border border-black/5 shadow-soft mb-4 animate-slide-up">
          <p className="text-cream text-sm font-medium mb-3">Start a Circle</p>
          <input type="text" value={circleName} onChange={e => setCircleName(e.target.value)}
            placeholder="Circle name (e.g. Gym Buddies)" className="w-full mb-3" autoFocus />
          <div className="flex gap-2">
            <button type="submit" className="bg-accent text-white px-4 py-2 rounded-sm text-sm font-semibold">Create</button>
            <button type="button" onClick={() => setShowCreate(false)} className="text-cream/60 text-sm">Cancel</button>
          </div>
        </form>
      )}

      {/* Join Circle Form */}
      {showJoin && (
        <form onSubmit={joinCircle} className="bg-surface-mid rounded-sm p-5 border border-black/5 shadow-soft mb-4 animate-slide-up">
          <p className="text-cream text-sm font-medium mb-3">Join Friends</p>
          <input type="text" value={joinCode} onChange={e => setJoinCode(e.target.value)}
            placeholder="Enter 6-character invite code" maxLength={6}
            className="w-full mb-3 uppercase tracking-widest text-center font-mono" autoFocus />
          <div className="flex gap-2">
            <button type="submit" className="bg-accent text-white px-4 py-2 rounded-sm text-sm font-semibold">Join</button>
            <button type="button" onClick={() => setShowJoin(false)} className="text-cream/60 text-sm">Cancel</button>
          </div>
        </form>
      )}

      {circles.length === 0 && !showCreate && !showJoin ? (
        <div className="bg-surface-mid rounded-sm p-8 border border-black/5 shadow-soft text-center">
          <div className="text-4xl mb-3">👥</div>
          <p className="text-cream font-medium mb-1">No circles yet</p>
          <p className="text-cream/60 text-sm mb-4">Create a circle and invite friends to share progress and stay accountable together.</p>
          <div className="flex gap-3 justify-center">
            <button onClick={() => setShowCreate(true)} className="bg-accent hover:bg-accent-dark text-white px-5 py-2.5 rounded-sm font-semibold text-sm transition-colors">Start a Circle</button>
            <button onClick={() => setShowJoin(true)} className="bg-surface-up border border-black/10 text-cream px-5 py-2.5 rounded-sm font-semibold text-sm transition-colors hover:border-accent/30">Join Friends</button>
          </div>
        </div>
      ) : (
        <>
          {/* Circle Picker */}
          {circles.length > 1 && (
            <div className="mb-3">
              <select
                value={selectedCircle || ''}
                onChange={e => setSelectedCircle(e.target.value || null)}
                className="w-full bg-surface-up border border-black/10 text-cream text-sm rounded-sm px-3 py-2 appearance-none cursor-pointer hover:border-accent/30 transition-colors"
                style={{ backgroundImage: `url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 24 24' fill='none' stroke='%23888' stroke-width='2'%3E%3Cpath d='M6 9l6 6 6-6'/%3E%3C/svg%3E")`, backgroundRepeat: 'no-repeat', backgroundPosition: 'right 12px center' }}
              >
                <option value="">All Circles</option>
                {circles.map(c => <option key={c.id} value={c.id}>{c.name}</option>)}
              </select>
            </div>
          )}

          {/* Tab Bar */}
          <div className="flex gap-1 bg-surface-up rounded-sm p-0.5 mb-4">
            {[['feed', 'Feed'], ['predictions', 'Bets'], ['members', 'Squad'], ['compare', 'Compare']].map(([id, label]) => (
              <button
                key={id}
                onClick={() => setTab(id)}
                className={`flex-1 py-2 rounded-sm text-xs font-medium transition-colors ${
                  tab === id ? 'bg-accent text-white' : 'text-cream/50 hover:text-cream'
                }`}
              >
                {label}
              </button>
            ))}
          </div>

          {/* Feed Tab */}
          {tab === 'feed' && (
            <div className="space-y-3 desktop:grid desktop:grid-cols-2 desktop:gap-3 desktop:space-y-0">
              {feedWithBadges.length === 0 ? (
                <p className="text-cream/60 text-center py-8 text-sm desktop:col-span-2">Nothing here yet — be the first to log!</p>
              ) : (
                feedWithBadges.slice(0, feedPage * FEED_PAGE_SIZE).map(entry => {
                  const entryReactions = reactions[entry.id] || [];
                  const groupedReactions = {};
                  entryReactions.forEach(r => {
                    if (!groupedReactions[r.emoji]) groupedReactions[r.emoji] = [];
                    groupedReactions[r.emoji].push(r.user_id);
                  });

                  return (
                    <div key={entry.id} className={`bg-surface-mid rounded-sm p-4 border ${entry.isOwn ? 'border-accent/20' : 'border-black/5'}`}>
                      <div className="flex items-start justify-between mb-2">
                        <div className="flex items-center gap-2">
                          <Avatar url={entry.avatarUrl} name={entry.displayName} size="sm" />
                          <div>
                            <p className="text-cream text-sm font-medium">
                              {entry.isOwn ? 'You' : entry.displayName}
                            </p>
                            <p className="text-cream/50 text-xs">{formatDateShort(entry.date)}</p>
                          </div>
                        </div>
                        <span className="font-display text-2xl text-cream">
                          {formatWeight(entry.weight, entry.unit || unit)}
                        </span>
                      </div>

                      {/* Badges */}
                      {entry.badges.length > 0 && (
                        <div className="flex flex-wrap gap-1.5 mb-2">
                          {entry.badges.map((b, i) => (
                            <span key={i} className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-warning/10 border border-warning/20 text-xs text-warning font-medium">
                              <span>{b.icon}</span> {b.text}
                            </span>
                          ))}
                        </div>
                      )}

                      {entry.notes && <p className="text-cream/50 text-xs mb-2">{entry.notes}</p>}

                      {/* Reactions */}
                      <div className="flex items-center gap-2 pt-2 border-t border-black/5 flex-wrap">
                        {Object.entries(groupedReactions).map(([emoji, userIds]) => {
                          const hasReacted = userIds.includes(user.id);
                          return (
                            <button
                              key={emoji}
                              onClick={() => handleReaction(entry.id, emoji)}
                              className={`flex items-center gap-1 px-2 py-1 rounded-full text-xs transition-colors ${
                                hasReacted
                                  ? 'bg-accent/15 border border-accent/30'
                                  : 'bg-black/5 border border-black/5 hover:border-accent/20'
                              }`}
                            >
                              <span>{emoji}</span>
                              <span className={hasReacted ? 'text-accent' : 'text-cream/60'}>{userIds.length}</span>
                            </button>
                          );
                        })}

                        <div className="relative">
                          <button
                            onClick={() => setShowReactionPicker(showReactionPicker === entry.id ? null : entry.id)}
                            className="w-7 h-7 rounded-full bg-black/5 border border-black/5 flex items-center justify-center text-cream/50 hover:text-cream/60 hover:border-accent/20 transition-colors text-sm"
                          >
                            +
                          </button>
                          {showReactionPicker === entry.id && (
                            <div className="absolute bottom-full left-0 mb-1 bg-surface-up border border-black/10 rounded-sm p-1.5 flex gap-1 shadow-lg z-10 animate-slide-up">
                              {REACTIONS.map(r => (
                                <button
                                  key={r.emoji}
                                  onClick={() => handleReaction(entry.id, r.emoji)}
                                  className="w-8 h-8 rounded-sm hover:bg-black/10 flex items-center justify-center text-lg transition-colors"
                                  title={r.label}
                                >
                                  {r.emoji}
                                </button>
                              ))}
                            </div>
                          )}
                        </div>
                      </div>
                    </div>
                  );
                })
              )}
              {feedWithBadges.length > feedPage * FEED_PAGE_SIZE && (
                <button
                  onClick={() => setFeedPage(p => p + 1)}
                  className="w-full py-3 text-center text-accent text-sm font-medium hover:bg-surface-mid rounded-sm transition-colors desktop:col-span-2"
                >
                  Load more ({feedWithBadges.length - feedPage * FEED_PAGE_SIZE} more)
                </button>
              )}
            </div>
          )}

          {/* Predictions Tab */}
          {tab === 'predictions' && (
            <div className="space-y-3">
              {/* Create Prediction Button */}
              {!showNewPrediction && !hasActivePrediction && (
                <button
                  onClick={() => setShowNewPrediction(true)}
                  className="w-full bg-surface-mid hover:bg-surface-up border border-dashed border-accent/30 rounded-sm p-4 text-center transition-colors"
                >
                  <p className="text-accent font-semibold text-sm">Make a Prediction</p>
                  <p className="text-cream/60 text-xs mt-0.5">Lock in a weight prediction for your circle</p>
                </button>
              )}

              {hasActivePrediction && !showNewPrediction && (
                <p className="text-cream/50 text-xs text-center py-1">You have an active prediction — resolve it before making another.</p>
              )}

              {/* Create Prediction Form */}
              {showNewPrediction && (
                <div className="bg-surface-mid rounded-sm p-5 border border-accent/20 animate-slide-up">
                  <p className="text-cream font-medium text-sm mb-3">Make a Prediction</p>
                  <div className="space-y-3">
                    <div>
                      <label className="text-cream/60 text-xs uppercase tracking-wider block mb-1">I'll be at</label>
                      <div className="flex items-center gap-2">
                        <input
                          type="number"
                          step="0.1"
                          value={predictionWeight}
                          onChange={e => setPredictionWeight(e.target.value)}
                          placeholder={localWeights.length ? String(localWeights.sort((a, b) => b.date.localeCompare(a.date))[0].weight) : '175'}
                          className="flex-1"
                          autoFocus
                        />
                        <span className="text-cream/50 text-sm">{unit}</span>
                      </div>
                    </div>
                    <div>
                      <label className="text-cream/60 text-xs uppercase tracking-wider block mb-1">By</label>
                      <div className="flex gap-1 bg-surface-up rounded-sm p-0.5">
                        {[['14', '2 weeks'], ['30', '30 days'], ['60', '60 days'], ['90', '90 days']].map(([val, label]) => (
                          <button
                            key={val}
                            onClick={() => setPredictionDeadline(val)}
                            className={`flex-1 py-1.5 rounded-sm text-xs font-medium transition-colors ${
                              predictionDeadline === val ? 'bg-accent text-white' : 'text-cream/50 hover:text-cream'
                            }`}
                          >
                            {label}
                          </button>
                        ))}
                      </div>
                    </div>
                    <div>
                      <label className="text-cream/60 text-xs uppercase tracking-wider block mb-1">Message (optional)</label>
                      <input
                        type="text"
                        value={predictionMessage}
                        onChange={e => setPredictionMessage(e.target.value)}
                        placeholder="Cutting season starts now..."
                        className="w-full"
                        maxLength={300}
                      />
                    </div>
                    <div className="flex gap-2 pt-1">
                      <button onClick={createPrediction} className="bg-accent hover:bg-accent-dark text-white px-4 py-2 rounded-sm text-sm font-semibold transition-colors">
                        Lock It In
                      </button>
                      <button onClick={() => setShowNewPrediction(false)} className="text-cream/60 text-sm">Cancel</button>
                    </div>
                  </div>
                </div>
              )}

              {/* Active Predictions */}
              {filteredPredictions.filter(p => p.status === 'active').length > 0 && (
                <div>
                  <p className="text-cream/60 text-xs uppercase tracking-wider mb-2">Active</p>
                  <div className="space-y-3">
                    {filteredPredictions.filter(p => p.status === 'active').map(pred => {
                      const profile = members.find(m => m.user_id === pred.user_id)?.profiles;
                      const votes = predictionVotes[pred.id] || [];
                      const myVote = votes.find(v => v.user_id === user.id);
                      const isOwn = pred.user_id === user.id;
                      const daysLeft = Math.max(0, Math.ceil((new Date(pred.deadline + 'T00:00:00') - new Date()) / 86400000));
                      const totalDays = Math.ceil((new Date(pred.deadline + 'T00:00:00') - new Date(pred.created_at)) / 86400000);
                      const progress = totalDays > 0 ? Math.min(1, 1 - daysLeft / totalDays) : 1;
                      const diff = (pred.predicted_weight - pred.start_weight).toFixed(1);
                      const direction = diff > 0 ? '+' : '';

                      return (
                        <div key={pred.id} className={`bg-surface-mid rounded-sm border ${isOwn ? 'border-accent/20' : 'border-black/5'} overflow-hidden`}>
                          <div className="p-4">
                            <div className="flex items-start justify-between mb-2">
                              <div className="flex items-center gap-2">
                                <Avatar url={profile?.avatar_url} name={profile?.display_name || '?'} size="sm" />
                                <div>
                                  <p className="text-cream text-sm font-medium">
                                    {isOwn ? 'You' : profile?.display_name || 'Unknown'}
                                  </p>
                                  <p className="text-cream/50 text-xs">{formatDateShort(pred.created_at?.slice(0, 10))}</p>
                                </div>
                              </div>
                              <div className="text-right">
                                <p className="font-display text-xl text-cream">{formatWeight(pred.predicted_weight, pred.unit)}</p>
                                <p className="text-cream/50 text-xs">from {formatWeight(pred.start_weight, pred.unit)} ({direction}{diff})</p>
                              </div>
                            </div>

                            {pred.message && (
                              <p className="text-cream/50 text-xs mb-3 italic">"{pred.message}"</p>
                            )}

                            {/* Progress bar */}
                            <div className="mb-3">
                              <div className="flex justify-between text-xs text-cream/50 mb-1">
                                <span>{daysLeft} days left</span>
                                <span>Due {formatDateShort(pred.deadline)}</span>
                              </div>
                              <div className="h-1.5 bg-black/5 rounded-full overflow-hidden">
                                <div
                                  className="h-full bg-accent rounded-full transition-all"
                                  style={{ width: `${progress * 100}%` }}
                                />
                              </div>
                            </div>

                            {/* Voting (can't vote on own prediction) */}
                            {!isOwn && (
                              <div>
                                <p className="text-cream/60 text-xs uppercase tracking-wider mb-2">What do you think?</p>
                                <div className="grid grid-cols-2 gap-1.5">
                                  {VOTE_OPTIONS.map(opt => {
                                    const voteCount = votes.filter(v => v.vote === opt.key).length;
                                    const isMyVote = myVote?.vote === opt.key;
                                    return (
                                      <button
                                        key={opt.key}
                                        onClick={() => handleVote(pred.id, opt.key)}
                                        className={`flex items-center gap-2 px-3 py-2 rounded-sm text-xs transition-colors ${
                                          isMyVote
                                            ? 'bg-accent/15 border border-accent/30'
                                            : 'bg-black/5 border border-black/5 hover:border-accent/20'
                                        }`}
                                      >
                                        <span>{opt.emoji}</span>
                                        <span className={isMyVote ? 'text-accent font-medium' : 'text-cream/60'}>{opt.label}</span>
                                        {voteCount > 0 && (
                                          <span className={`ml-auto text-xs ${isMyVote ? 'text-accent' : 'text-cream/50'}`}>{voteCount}</span>
                                        )}
                                      </button>
                                    );
                                  })}
                                </div>
                              </div>
                            )}

                            {/* Show vote counts for own prediction */}
                            {isOwn && votes.length > 0 && (
                              <div>
                                <p className="text-cream/60 text-xs uppercase tracking-wider mb-2">Circle thinks</p>
                                <div className="flex gap-2 flex-wrap">
                                  {VOTE_OPTIONS.map(opt => {
                                    const voteCount = votes.filter(v => v.vote === opt.key).length;
                                    if (voteCount === 0) return null;
                                    return (
                                      <span key={opt.key} className="flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-black/5 border border-black/5 text-xs">
                                        <span>{opt.emoji}</span>
                                        <span className="text-cream/50">{opt.label}</span>
                                        <span className="text-cream/50">{voteCount}</span>
                                      </span>
                                    );
                                  })}
                                </div>
                              </div>
                            )}
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </div>
              )}

              {/* Resolved Predictions */}
              {filteredPredictions.filter(p => p.status === 'resolved').length > 0 && (
                <div>
                  <p className="text-cream/60 text-xs uppercase tracking-wider mb-2">Resolved</p>
                  <div className="space-y-3">
                    {filteredPredictions.filter(p => p.status === 'resolved').map(pred => {
                      const profile = members.find(m => m.user_id === pred.user_id)?.profiles;
                      const votes = predictionVotes[pred.id] || [];
                      const isOwn = pred.user_id === user.id;
                      const resultOption = VOTE_OPTIONS.find(o => o.key === pred.result);
                      const correctVoters = votes.filter(v => v.vote === pred.result);

                      return (
                        <div key={pred.id} className={`bg-surface-mid rounded-sm border ${isOwn ? 'border-accent/20' : 'border-black/5'} overflow-hidden`}>
                          <div className="p-4">
                            <div className="flex items-start justify-between mb-2">
                              <div className="flex items-center gap-2">
                                <Avatar url={profile?.avatar_url} name={profile?.display_name || '?'} size="sm" />
                                <div>
                                  <p className="text-cream text-sm font-medium">
                                    {isOwn ? 'You' : profile?.display_name || 'Unknown'}
                                  </p>
                                  <p className="text-cream/50 text-xs">Resolved {pred.resolved_at ? formatDateShort(pred.resolved_at.slice(0, 10)) : ''}</p>
                                </div>
                              </div>
                              {resultOption && (
                                <span className={`flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium ${
                                  pred.result === 'nails_it' ? 'bg-success/15 border border-success/30 text-success' :
                                  pred.result === 'crushes_it' ? 'bg-accent/15 border border-accent/30 text-accent' :
                                  pred.result === 'overshoots' ? 'bg-warning/15 border border-warning/30 text-warning' :
                                  'bg-black/5 border border-black/10 text-cream/50'
                                }`}>
                                  <span>{resultOption.emoji}</span> {resultOption.label}
                                </span>
                              )}
                            </div>

                            {pred.message && (
                              <p className="text-cream/50 text-xs mb-3 italic">"{pred.message}"</p>
                            )}

                            <div className="grid grid-cols-3 gap-px bg-black/5 rounded-sm overflow-hidden mb-3">
                              <div className="bg-surface-up p-2.5 text-center">
                                <p className="text-cream/60 text-xs uppercase">Predicted</p>
                                <p className="font-display text-lg text-cream">{formatWeight(pred.predicted_weight, pred.unit)}</p>
                              </div>
                              <div className="bg-surface-up p-2.5 text-center">
                                <p className="text-cream/60 text-xs uppercase">Actual</p>
                                <p className="font-display text-lg text-cream">{formatWeight(pred.actual_weight, pred.unit)}</p>
                              </div>
                              <div className="bg-surface-up p-2.5 text-center">
                                <p className="text-cream/60 text-xs uppercase">Diff</p>
                                <p className={`font-display text-lg ${
                                  Math.abs(pred.actual_weight - pred.predicted_weight) <= 0.5 ? 'text-success' : 'text-cream/50'
                                }`}>
                                  {Math.abs(pred.actual_weight - pred.predicted_weight).toFixed(1)} {pred.unit}
                                </p>
                              </div>
                            </div>

                            {/* Who called it right */}
                            {votes.length > 0 && (
                              <div>
                                <p className="text-cream/60 text-xs uppercase tracking-wider mb-1.5">Who called it?</p>
                                <div className="space-y-1">
                                  {VOTE_OPTIONS.map(opt => {
                                    const optVoters = votes.filter(v => v.vote === opt.key);
                                    if (optVoters.length === 0) return null;
                                    const isCorrect = opt.key === pred.result;
                                    return (
                                      <div key={opt.key} className={`flex items-center gap-2 text-xs px-2 py-1 rounded-sm ${isCorrect ? 'bg-success/10' : ''}`}>
                                        <span>{opt.emoji}</span>
                                        <span className={isCorrect ? 'text-success' : 'text-cream/60'}>{opt.label}</span>
                                        <span className="text-cream/50 ml-auto">
                                          {optVoters.map(v => {
                                            const vProfile = members.find(m => m.user_id === v.user_id)?.profiles;
                                            return vProfile?.display_name || 'Unknown';
                                          }).join(', ')}
                                          {isCorrect && ' ✓'}
                                        </span>
                                      </div>
                                    );
                                  })}
                                </div>
                              </div>
                            )}
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </div>
              )}

              {/* Predictor Leaderboard */}
              {predictorStats.length > 0 && (
                <div className="bg-surface-mid rounded-sm border border-black/5 shadow-soft p-4">
                  <p className="text-cream/60 text-xs uppercase tracking-wider mb-2">Best Predictors</p>
                  <div className="space-y-1.5">
                    {predictorStats.slice(0, 5).map((stat, i) => {
                      const profile = members.find(m => m.user_id === stat.userId)?.profiles;
                      return (
                        <div key={stat.userId} className="flex items-center gap-2 text-xs">
                          <span className="text-cream/50 w-4">{i + 1}.</span>
                          <Avatar url={profile?.avatar_url} name={profile?.display_name || '?'} size="xs" />
                          <span className="text-cream">{stat.userId === user.id ? 'You' : profile?.display_name || 'Unknown'}</span>
                          <span className="text-cream/50 ml-auto">{stat.correct}/{stat.total} ({Math.round(stat.accuracy * 100)}%)</span>
                        </div>
                      );
                    })}
                  </div>
                </div>
              )}

              {filteredPredictions.length === 0 && !showNewPrediction && (
                <p className="text-cream/60 text-center py-8 text-sm">No predictions yet. Be the first to make one!</p>
              )}
            </div>
          )}

          {/* Members Tab */}
          {tab === 'members' && (
            <div className="space-y-3">
              {memberStats.length === 0 ? (
                <p className="text-cream/60 text-center py-8 text-sm">No members yet.</p>
              ) : (
                memberStats.map(member => (
                  <div key={member.user_id} className={`bg-surface-mid rounded-sm border ${member.isYou ? 'border-accent/20' : 'border-black/5'}`}>
                    <div className="flex items-center justify-between p-4 pb-3">
                      <div className="flex items-center gap-3">
                        <div className="relative">
                          <Avatar url={member.profiles?.avatar_url} name={member.profiles?.display_name || '?'} size="md" />
                          {member.loggedToday && (
                            <span className="absolute -bottom-0.5 -right-0.5 w-3 h-3 bg-success rounded-full border-2 border-surface-mid" />
                          )}
                        </div>
                        <div>
                          <div className="flex items-center gap-2">
                            <p className="text-cream font-medium text-sm">
                              {member.profiles?.display_name || 'Unknown'}
                              {member.isYou && <span className="text-accent/60 ml-1">(you)</span>}
                            </p>
                            <span className="w-2.5 h-2.5 rounded-full shrink-0" style={{ backgroundColor: member.color }} title="Graph color" />
                          </div>
                          <p className="text-cream/50 text-xs">
                            {member.loggedToday ? 'Logged today' : member.latest ? `Last log ${formatDateShort(member.latest.date)}` : 'No entries yet'}
                          </p>
                        </div>
                      </div>
                      {member.latest && (
                        <p className="font-display text-2xl text-cream">{formatWeight(member.latest.weight, member.latest.unit || unit)}</p>
                      )}
                    </div>

                    <div className="grid grid-cols-4 gap-px bg-black/5 border-t border-black/5">
                      <div className="bg-surface-mid p-2.5 text-center">
                        <p className="text-cream/60 text-xs uppercase tracking-wider">Streak</p>
                        <p className="font-display text-lg text-accent">{member.streak}</p>
                        <p className="text-cream/50 text-xs">days</p>
                      </div>
                      <div className="bg-surface-mid p-2.5 text-center">
                        <p className="text-cream/60 text-xs uppercase tracking-wider">7d Avg</p>
                        {member.avg7 ? (
                          <>
                            <p className="font-display text-lg text-cream">{formatWeight(member.avg7, unit)}</p>
                          </>
                        ) : <p className="text-cream/40 text-xs mt-1">--</p>}
                      </div>
                      <div className="bg-surface-mid p-2.5 text-center">
                        <p className="text-cream/60 text-xs uppercase tracking-wider">7 Day</p>
                        {member.change7 ? (
                          <>
                            <p className={`font-display text-lg ${member.change7.change < 0 ? 'text-success' : member.change7.change > 0 ? 'text-danger' : 'text-cream/50'}`}>
                              {member.change7.change > 0 ? '+' : ''}{member.change7.change.toFixed(1)}
                            </p>
                            <p className="text-cream/50 text-xs">{unit}</p>
                          </>
                        ) : <p className="text-cream/40 text-xs mt-1">--</p>}
                      </div>
                      <div className="bg-surface-mid p-2.5 text-center">
                        <p className="text-cream/60 text-xs uppercase tracking-wider">30 Day</p>
                        {member.change30 ? (
                          <>
                            <p className={`font-display text-lg ${member.change30.change < 0 ? 'text-success' : member.change30.change > 0 ? 'text-danger' : 'text-cream/50'}`}>
                              {member.change30.change > 0 ? '+' : ''}{member.change30.change.toFixed(1)}
                            </p>
                            <p className="text-cream/50 text-xs">{unit}</p>
                          </>
                        ) : <p className="text-cream/40 text-xs mt-1">--</p>}
                      </div>
                    </div>

                    {member.recentDays.length > 1 && (
                      <div className="px-4 py-2.5 border-t border-black/5">
                        <div className="flex items-center justify-between mb-1.5">
                          <span className="text-cream/50 text-xs uppercase tracking-wider">Recent trend</span>
                          <span className="text-cream/50 text-xs">Last {member.recentDays.length} entries</span>
                        </div>
                        <MiniSparkline data={member.recentDays} color={member.color} />
                      </div>
                    )}
                  </div>
                ))
              )}
            </div>
          )}

          {/* Compare Tab */}
          {tab === 'compare' && (
            <div className="bg-surface-mid rounded-sm p-5 border border-black/5 shadow-soft">
              <div className="flex items-center justify-between mb-3">
                <p className="text-cream/50 text-xs uppercase tracking-wider">Weight Comparison</p>
                <div className="flex gap-1 bg-surface-up rounded-sm p-0.5">
                  {[['7', '7d'], ['30', '30d'], ['90', '90d']].map(([val, label]) => (
                    <button
                      key={val}
                      onClick={() => setCompareRange(val)}
                      className={`px-2 py-0.5 rounded-sm text-xs font-medium transition-colors ${
                        compareRange === val ? 'bg-accent text-white' : 'text-cream/50 hover:text-cream'
                      }`}
                    >
                      {label}
                    </button>
                  ))}
                </div>
              </div>

              {compareData.length > 1 ? (
                <ResponsiveContainer width="100%" height={280}>
                  <LineChart data={compareData}>
                    <XAxis
                      dataKey="date"
                      tickFormatter={formatDateShort}
                      tick={{ fill: '#2D2A3366', fontSize: 11 }}
                      axisLine={false}
                      tickLine={false}
                      interval="preserveStartEnd"
                    />
                    <YAxis
                      domain={['auto', 'auto']}
                      tick={{ fill: '#2D2A3366', fontSize: 11 }}
                      axisLine={false}
                      tickLine={false}
                      width={40}
                    />
                    <Tooltip
                      contentStyle={{ background: '#F0EFEB', border: '1px solid rgba(45,42,51,0.06)', borderRadius: 12, fontSize: 14, color: '#2D2A33' }}
                      labelFormatter={formatDateShort}
                      formatter={(value, name) => {
                        const m = memberStats.find(ms => ms.user_id === name);
                        return [formatWeight(value, unit), m?.profiles?.display_name || 'Unknown'];
                      }}
                    />
                    {memberStats.map(m => (
                      <Line
                        key={m.user_id}
                        type="monotone"
                        dataKey={m.user_id}
                        stroke={m.color}
                        strokeWidth={m.isYou ? 2.5 : 1.5}
                        dot={{ r: 2.5, fill: m.color }}
                        connectNulls
                        activeDot={{ r: 4, stroke: '#2D2A33', strokeWidth: 1.5 }}
                      />
                    ))}
                  </LineChart>
                </ResponsiveContainer>
              ) : (
                <p className="text-cream/60 text-center py-12 text-sm">Not enough data to compare yet.</p>
              )}

              {/* Legend */}
              <div className="flex flex-wrap gap-3 mt-3 justify-center">
                {memberStats.map(m => (
                  <span key={m.user_id} className="flex items-center gap-1.5 text-xs text-cream/50">
                    <span className="w-3 h-0.5 rounded" style={{ backgroundColor: m.color }} />
                    {m.isYou ? 'You' : m.profiles?.display_name || 'Unknown'}
                  </span>
                ))}
              </div>
            </div>
          )}
        </>
      )}
    </div>
  );
}

function MiniSparkline({ data, color }) {
  if (!data || data.length < 2) return null;
  const weights = data.map(d => d.weight);
  const min = Math.min(...weights);
  const max = Math.max(...weights);
  const range = max - min || 1;
  const h = 32;
  const w = 120;
  const pad = 3;
  const step = (w - pad * 2) / (weights.length - 1);

  const pts = weights.map((v, i) => ({
    x: pad + i * step,
    y: h - pad - ((v - min) / range) * (h - pad * 2),
  }));

  // Build smooth cubic bezier path
  let d = `M${pts[0].x},${pts[0].y}`;
  for (let i = 0; i < pts.length - 1; i++) {
    const cp = step * 0.4;
    d += ` C${pts[i].x + cp},${pts[i].y} ${pts[i + 1].x - cp},${pts[i + 1].y} ${pts[i + 1].x},${pts[i + 1].y}`;
  }

  // Closed path for gradient fill area
  const fillD = `${d} L${pts[pts.length - 1].x},${h} L${pts[0].x},${h} Z`;

  const first = weights[0];
  const last = weights[weights.length - 1];
  const strokeColor = color || (last < first ? '#34d399' : last > first ? '#f87171' : 'rgba(45,42,51,0.4)');
  const gradId = `sg-${(data[0]?.date || '').replace(/\D/g, '')}`;
  const lastPt = pts[pts.length - 1];

  return (
    <div className="flex items-center gap-3">
      <svg viewBox={`0 0 ${w} ${h}`} className="flex-1 h-8" preserveAspectRatio="none">
        <defs>
          <linearGradient id={gradId} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor={strokeColor} stopOpacity="0.15" />
            <stop offset="100%" stopColor={strokeColor} stopOpacity="0" />
          </linearGradient>
        </defs>
        <path d={fillD} fill={`url(#${gradId})`} />
        <path d={d} fill="none" stroke={strokeColor} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
        <circle cx={lastPt.x} cy={lastPt.y} r="2" fill={strokeColor} />
      </svg>
      <div className="text-xs font-medium whitespace-nowrap" style={{ color: strokeColor }}>
        {last > first ? '+' : ''}{(last - first).toFixed(1)}
      </div>
    </div>
  );
}
