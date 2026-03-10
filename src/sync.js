import { supabase } from './supabase';
import * as db from './db';

export async function deleteWeightFromCloud(id) {
  const { error } = await supabase
    .from('weight_entries')
    .delete()
    .eq('id', id);
  if (error) throw error;
}

export async function pushWeightToCloud(entry) {
  const { error } = await supabase
    .from('weight_entries')
    .upsert({
      id: entry.id,
      user_id: entry.userId,
      date: entry.date,
      weight: entry.weight,
      unit: entry.unit || 'lb',
      notes: entry.notes || null,
      is_morning: entry.isMorning || false,
      updated_at: new Date(entry.updatedAt).toISOString()
    });
  if (error) throw error;
}

export async function pushToCloud(userId) {
  const data = await db.exportAllDB();

  const weights = data.weights
    .filter(w => w.userId === userId)
    .map(w => ({ ...w, user_id: userId }));

  const goals = data.goals
    .filter(g => g.userId === userId)
    .map(g => ({ ...g, user_id: userId }));

  if (weights.length) {
    const { error } = await supabase
      .from('weight_entries')
      .upsert(weights.map(w => ({
        id: w.id,
        user_id: w.user_id,
        date: w.date,
        weight: w.weight,
        unit: w.unit || 'lb',
        notes: w.notes || null,
        is_morning: w.isMorning || false,
        updated_at: new Date(w.updatedAt).toISOString()
      })));
    if (error) throw error;
  }

  if (goals.length) {
    const { error } = await supabase
      .from('goals')
      .upsert(goals.map(g => ({
        id: g.id,
        user_id: g.user_id,
        target_weight: g.targetWeight,
        target_date: g.targetDate || null,
        start_weight: g.startWeight,
        start_date: g.startDate,
        unit: g.unit || 'lb',
        active: g.active ?? true,
        updated_at: new Date(g.updatedAt).toISOString()
      })));
    if (error) throw error;
  }
}

export async function pullFromCloud(userId) {
  const { data: weights, error: wErr } = await supabase
    .from('weight_entries')
    .select('*')
    .eq('user_id', userId);
  if (wErr) throw wErr;

  const { data: goals, error: gErr } = await supabase
    .from('goals')
    .select('*')
    .eq('user_id', userId);
  if (gErr) throw gErr;

  const localWeights = (weights || []).map(w => ({
    id: w.id,
    userId: w.user_id,
    date: w.date,
    weight: w.weight,
    unit: w.unit,
    notes: w.notes,
    isMorning: w.is_morning || false,
    updatedAt: new Date(w.updated_at).getTime()
  }));

  const localGoals = (goals || []).map(g => ({
    id: g.id,
    userId: g.user_id,
    targetWeight: g.target_weight,
    targetDate: g.target_date,
    startWeight: g.start_weight,
    startDate: g.start_date,
    unit: g.unit,
    active: g.active,
    updatedAt: new Date(g.updated_at).getTime()
  }));

  await db.importAllDB({ weights: localWeights, goals: localGoals });
  return { weights: localWeights, goals: localGoals };
}

export async function syncData(userId) {
  return pullFromCloud(userId);
}
