// IndexedDB storage. Everything is loaded into `data` at start-up and written through on change.

import { RECORD_STORES } from "./sync.js";

const DB_NAME = "snakekeeper";
const DB_VERSION = 1;
const ALL_STORES = [...RECORD_STORES, "deleted"];

export const data = Object.fromEntries(ALL_STORES.map((s) => [s, []]));

let db;

function request(req) {
  return new Promise((resolve, reject) => {
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

function done(tx) {
  return new Promise((resolve, reject) => {
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
    tx.onabort = () => reject(tx.error ?? new Error("Save was cancelled"));
  });
}

export async function open() {
  const req = indexedDB.open(DB_NAME, DB_VERSION);
  req.onupgradeneeded = () => {
    for (const store of ALL_STORES) {
      if (!req.result.objectStoreNames.contains(store)) req.result.createObjectStore(store, { keyPath: "id" });
    }
  };
  db = await request(req);
  const tx = db.transaction(ALL_STORES, "readonly");
  for (const store of ALL_STORES) data[store] = await request(tx.objectStore(store).getAll());
  // Ask the browser not to evict our data under storage pressure.
  navigator.storage?.persist?.().catch(() => {});
}

export const now = () => new Date().toISOString();

/** Same format as Swift's UUID().uuidString, so custom gene ids match across apps. */
export const newID = () => crypto.randomUUID().toUpperCase();

/** Insert or update records, stamping `updatedAt` unless `keepTimestamps`. */
export async function save(store, records, { keepTimestamps = false } = {}) {
  records = Array.isArray(records) ? records : [records];
  if (!records.length) return;
  const tx = db.transaction(store, "readwrite");
  for (const record of records) {
    if (!keepTimestamps) record.updatedAt = now();
    tx.objectStore(store).put(record);
  }
  await done(tx);
  const byID = new Map(data[store].map((r) => [r.id, r]));
  for (const record of records) byID.set(record.id, record);
  data[store] = [...byID.values()];
}

/** Delete records and leave tombstones so the deletion syncs. */
export async function remove(store, ids, { tombstone = true } = {}) {
  ids = Array.isArray(ids) ? ids : [ids];
  if (!ids.length) return;
  const tx = db.transaction([store, "deleted"], "readwrite");
  const stamps = ids.map((id) => ({ id, type: store, deletedAt: now() }));
  for (const id of ids) tx.objectStore(store).delete(id);
  if (tombstone) for (const t of stamps) tx.objectStore("deleted").put(t);
  await done(tx);
  const gone = new Set(ids);
  data[store] = data[store].filter((r) => !gone.has(r.id));
  if (tombstone) {
    const byID = new Map(data.deleted.map((t) => [t.id, t]));
    for (const t of stamps) byID.set(t.id, t);
    data.deleted = [...byID.values()];
  }
}

/** Applies a plan from sync.planMerge. */
export async function applyMerge(plan) {
  for (const store of RECORD_STORES) {
    await save(store, plan.put[store], { keepTimestamps: true });
    await remove(store, plan.remove[store], { tombstone: false });
  }
  await save("deleted", plan.tombstones, { keepTimestamps: true });
}

export async function storageEstimate() {
  try {
    const estimate = await navigator.storage.estimate();
    const persisted = await navigator.storage.persisted?.();
    return { usage: estimate.usage ?? 0, persisted: !!persisted };
  } catch {
    return null;
  }
}
