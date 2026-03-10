export function generateId() {
  return Date.now().toString(36) + Math.random().toString(36).slice(2, 8);
}

export function formatDate(dateStr) {
  const d = new Date(dateStr + 'T00:00:00');
  return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
}

export function formatDateShort(dateStr) {
  const d = new Date(dateStr + 'T00:00:00');
  return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
}

export function localDateStr(d) {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

export function todayStr() {
  return localDateStr(new Date());
}

export function daysAgo(n) {
  const d = new Date();
  d.setDate(d.getDate() - n);
  return localDateStr(d);
}

export function convertWeight(value, from, to) {
  if (from === to) return value;
  if (from === 'lb' && to === 'kg') return value * 0.453592;
  if (from === 'kg' && to === 'lb') return value / 0.453592;
  return value;
}

export function formatWeight(value, unit) {
  return `${Number(value).toFixed(1)} ${unit}`;
}

export function getWeightChange(entries) {
  if (entries.length < 2) return null;
  const sorted = [...entries].sort((a, b) => a.date.localeCompare(b.date));
  const first = sorted[0].weight;
  const last = sorted[sorted.length - 1].weight;
  const change = Number((last - first).toFixed(2));
  return { change, percent: Number(((change / first) * 100).toFixed(2)) };
}

export function getMovingAverage(entries, window = 7) {
  const sorted = [...entries].sort((a, b) => a.date.localeCompare(b.date));
  return sorted.map((entry, i) => {
    const start = Math.max(0, i - window + 1);
    const slice = sorted.slice(start, i + 1);
    const avg = slice.reduce((sum, e) => sum + e.weight, 0) / slice.length;
    return { ...entry, average: Number(avg.toFixed(1)) };
  });
}

export function getStreak(entries) {
  if (!entries.length) return 0;
  const sorted = [...entries].sort((a, b) => b.date.localeCompare(a.date));
  // Deduplicate by date
  const uniqueDates = [];
  for (const e of sorted) {
    if (!uniqueDates.length || uniqueDates[uniqueDates.length - 1] !== e.date) {
      uniqueDates.push(e.date);
    }
  }
  if (!uniqueDates.length) return 0;
  // Check if most recent entry is today or yesterday (to not break streak mid-day)
  const today = todayStr();
  const yesterday = daysAgo(1);
  if (uniqueDates[0] !== today && uniqueDates[0] !== yesterday) return 0;
  let streak = 1;
  for (let i = 1; i < uniqueDates.length; i++) {
    const prev = new Date(uniqueDates[i - 1] + 'T00:00:00');
    const curr = new Date(uniqueDates[i] + 'T00:00:00');
    const diff = Math.round((prev - curr) / (1000 * 60 * 60 * 24));
    if (diff === 1) streak++;
    else break;
  }
  return streak;
}

/** Validate weight value is reasonable (1-1500 lbs or 0.5-680 kg) */
export function isValidWeight(value, unit = 'lb') {
  const num = Number(value);
  if (isNaN(num) || !isFinite(num)) return false;
  if (unit === 'kg') return num >= 0.5 && num <= 680;
  return num >= 1 && num <= 1500;
}

/** Sanitize text input - strip HTML tags and trim */
export function sanitizeText(text) {
  if (!text) return '';
  return text.replace(/<[^>]*>/g, '').trim();
}

/** Aggregate entries to one point per day. Uses morning weight if available, otherwise averages all weights for the day. */
export function aggregateDaily(entries, mode = 'morning') {
  const byDate = {};
  for (const e of entries) {
    if (!byDate[e.date]) byDate[e.date] = [];
    byDate[e.date].push(e);
  }
  const sorted = Object.keys(byDate).sort();
  return sorted.map(date => {
    const dayEntries = byDate[date];
    const morning = dayEntries.find(e => e.isMorning);
    const weights = dayEntries.map(e => e.weight);
    const avg = weights.reduce((s, w) => s + w, 0) / weights.length;
    const weight = mode === 'morning' && morning ? morning.weight : Number(avg.toFixed(1));
    return { date, weight, unit: dayEntries[0].unit };
  });
}

/** Build candlestick data: for each day, compute open (first), close (last), high, low.
 *  range is a [low, high] tuple for Recharts ranged Bar rendering. */
export function buildCandlestickData(entries) {
  const byDate = {};
  for (const e of entries) {
    if (!byDate[e.date]) byDate[e.date] = [];
    byDate[e.date].push(e);
  }
  const sorted = Object.keys(byDate).sort();
  return sorted.map(date => {
    const dayEntries = byDate[date];
    const weights = dayEntries.map(e => e.weight);
    const morning = dayEntries.find(e => e.isMorning);
    const low = Math.min(...weights);
    const high = Math.max(...weights);
    return {
      date,
      low,
      high,
      open: weights[0],
      close: weights[weights.length - 1],
      morning: morning ? morning.weight : null,
      count: weights.length,
      unit: dayEntries[0].unit,
      range: [low, high],
    };
  });
}

export function getTimeAgo(timestamp) {
  const seconds = Math.floor((Date.now() - timestamp) / 1000);
  if (seconds < 60) return 'just now';
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  if (days < 7) return `${days}d ago`;
  return `${Math.floor(days / 7)}w ago`;
}
