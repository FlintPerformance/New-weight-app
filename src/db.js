import { openDB } from 'idb';

let dbPromise;

function getDB() {
  if (!dbPromise) {
    dbPromise = openDB('subtle-db', 2, {
      upgrade(db, oldVersion) {
        if (oldVersion < 1) {
          const weights = db.createObjectStore('weights', { keyPath: 'id' });
          weights.createIndex('date', 'date');
          weights.createIndex('userId', 'userId');

          const goals = db.createObjectStore('goals', { keyPath: 'id' });
          goals.createIndex('userId', 'userId');
        }
        if (oldVersion < 2) {
          const circles = db.createObjectStore('circles', { keyPath: 'id' });
          circles.createIndex('userId', 'userId');
        }
      }
    });
  }
  return dbPromise;
}

// Weight entries
export async function saveWeight(entry) {
  const db = await getDB();
  await db.put('weights', { ...entry, updatedAt: Date.now() });
}

export async function getWeight(id) {
  const db = await getDB();
  return db.get('weights', id);
}

export async function getAllWeights() {
  const db = await getDB();
  return db.getAll('weights');
}

export async function deleteWeight(id) {
  const db = await getDB();
  await db.delete('weights', id);
}

// Goals
export async function saveGoal(goal) {
  const db = await getDB();
  await db.put('goals', { ...goal, updatedAt: Date.now() });
}

export async function getAllGoals() {
  const db = await getDB();
  return db.getAll('goals');
}

export async function deleteGoal(id) {
  const db = await getDB();
  await db.delete('goals', id);
}

// Circle cache
export async function saveCircleCache(userId, data) {
  const db = await getDB();
  await db.put('circles', { id: userId, ...data, updatedAt: Date.now() });
}

export async function getCircleCache(userId) {
  const db = await getDB();
  return db.get('circles', userId);
}

// Export/Import
export async function exportAllDB() {
  const db = await getDB();
  const weights = await db.getAll('weights');
  const goals = await db.getAll('goals');
  return { weights, goals };
}

export async function importAllDB(data) {
  const db = await getDB();
  const tx = db.transaction(['weights', 'goals'], 'readwrite');
  if (data.weights) for (const w of data.weights) await tx.objectStore('weights').put(w);
  if (data.goals) for (const g of data.goals) await tx.objectStore('goals').put(g);
  await tx.done;
}

export async function clearAllDB() {
  const db = await getDB();
  const tx = db.transaction(['weights', 'goals'], 'readwrite');
  await tx.objectStore('weights').clear();
  await tx.objectStore('goals').clear();
  await tx.done;
}
