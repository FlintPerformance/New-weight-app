import { useState, useEffect, useCallback } from 'react';
import * as db from '../db';
import { pushWeightToCloud, deleteWeightFromCloud } from '../sync';
import { generateId, todayStr } from '../utils';

export function useLocalData(userId) {
  const [weights, setWeights] = useState([]);
  const [goals, setGoals] = useState([]);
  const [loaded, setLoaded] = useState(false);

  const reload = useCallback(async () => {
    const [allWeights, allGoals] = await Promise.all([
      db.getAllWeights(),
      db.getAllGoals()
    ]);
    setWeights(allWeights.filter(w => w.userId === userId).sort((a, b) => b.date.localeCompare(a.date)));
    setGoals(allGoals.filter(g => g.userId === userId));
    setLoaded(true);
  }, [userId]);

  useEffect(() => {
    if (userId) reload();
  }, [userId, reload]);

  const addWeight = useCallback(async (weight, unit = 'lb', date, notes = '', isMorning = false) => {
    const entry = {
      id: generateId(),
      userId,
      date: date || todayStr(),
      weight: Number(weight),
      unit,
      notes,
      isMorning,
      updatedAt: Date.now()
    };
    await db.saveWeight(entry);
    pushWeightToCloud(entry).catch(err => console.error('Failed to push weight to cloud:', err));
    await reload();
    return entry;
  }, [userId, reload]);

  const updateWeight = useCallback(async (id, updates) => {
    const existing = await db.getWeight(id);
    if (!existing) return;
    const updated = { ...existing, ...updates, updatedAt: Date.now() };
    await db.saveWeight(updated);
    pushWeightToCloud(updated).catch(err => console.error('Failed to push weight update to cloud:', err));
    await reload();
  }, [reload]);

  const removeWeight = useCallback(async (id) => {
    await db.deleteWeight(id);
    deleteWeightFromCloud(id).catch(err => console.error('Failed to delete weight from cloud:', err));
    await reload();
  }, [reload]);

  const addGoal = useCallback(async (targetWeight, unit = 'lb', targetDate = null) => {
    // Deactivate existing goals
    for (const g of goals) {
      if (g.active) await db.saveGoal({ ...g, active: false, updatedAt: Date.now() });
    }
    const currentWeight = weights.length ? weights[0].weight : targetWeight;
    const goal = {
      id: generateId(),
      userId,
      targetWeight: Number(targetWeight),
      targetDate,
      startWeight: currentWeight,
      startDate: todayStr(),
      unit,
      active: true,
      updatedAt: Date.now()
    };
    await db.saveGoal(goal);
    await reload();
    return goal;
  }, [userId, goals, weights, reload]);

  const removeGoal = useCallback(async (id) => {
    await db.deleteGoal(id);
    await reload();
  }, [reload]);

  return { weights, goals, loaded, reload, addWeight, updateWeight, removeWeight, addGoal, removeGoal };
}
