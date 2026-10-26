// Sync file shared with the native app (App/Support/SyncFile.swift). See SYNC.md.
//
// Every record has a stable `id` and an `updatedAt` timestamp; deletions are kept as
// tombstones ({ id, type, deletedAt }). Merging keeps the newest version of each record, so
// exporting from one app and importing into the other (in either order) converges.

export const FORMAT = "snakekeeper-sync";
export const VERSION = 1;
export const RECORD_STORES = ["customGenes", "snakes", "feedings", "logs", "concerns", "photos", "pairings"];

const time = (iso) => (iso ? Date.parse(iso) || 0 : 0);

export function buildSyncFile(data, app = "web") {
  const file = { format: FORMAT, version: VERSION, app, exportedAt: new Date().toISOString() };
  for (const store of RECORD_STORES) file[store] = data[store];
  file.deleted = data.deleted;
  file.profile = data.profile?.[0] ?? null;
  return file;
}

export function parseSyncFile(text) {
  let file;
  try {
    file = JSON.parse(text);
  } catch {
    throw new Error("That file isn't a SnakeKeeper sync file (not valid JSON).");
  }
  if (file?.format !== FORMAT) throw new Error("That file isn't a SnakeKeeper sync file.");
  if (file.version > VERSION) throw new Error("This sync file is from a newer version of SnakeKeeper. Update this app first.");
  for (const store of [...RECORD_STORES, "deleted"]) file[store] = Array.isArray(file[store]) ? file[store] : [];
  if (typeof file.profile !== "object" || Array.isArray(file.profile)) file.profile = null;
  return file;
}

/**
 * Works out what to change locally. Returns
 * { put: { store: [records] }, remove: { store: [ids] }, tombstones: [..], profile, summary }.
 * Pure: doesn't touch `local`.
 */
export function planMerge(local, incoming) {
  const put = {}, remove = {};
  const summary = { added: 0, updated: 0, deleted: 0, unchanged: 0 };

  const tombstones = new Map(local.deleted.map((t) => [t.id, t]));
  const newTombstones = [];
  for (const t of incoming.deleted) {
    const existing = tombstones.get(t.id);
    if (!existing || time(t.deletedAt) > time(existing.deletedAt)) {
      tombstones.set(t.id, t);
      newTombstones.push(t);
    }
  }

  for (const store of RECORD_STORES) {
    const localByID = new Map(local[store].map((r) => [r.id, r]));
    put[store] = [];
    remove[store] = [];

    for (const record of incoming[store]) {
      if (!record?.id) continue;
      const tombstone = tombstones.get(record.id);
      if (tombstone && time(tombstone.deletedAt) >= time(record.updatedAt)) continue;
      const mine = localByID.get(record.id);
      if (!mine) {
        put[store].push(record);
        summary.added++;
      } else if (time(record.updatedAt) > time(mine.updatedAt)) {
        put[store].push(record);
        summary.updated++;
      } else {
        summary.unchanged++;
      }
    }

    for (const mine of local[store]) {
      const tombstone = tombstones.get(mine.id);
      if (tombstone && time(tombstone.deletedAt) >= time(mine.updatedAt)) {
        remove[store].push(mine.id);
        summary.deleted++;
      }
    }
  }

  // The breeder profile is a single record: newest wins.
  const mine = local.profile?.[0];
  const theirs = incoming.profile && !Array.isArray(incoming.profile) ? incoming.profile : null;
  let profile = null;
  if (theirs && (!mine || time(theirs.updatedAt) > time(mine.updatedAt))) {
    profile = { ...theirs, id: "profile" };
    summary.updated++;
  }

  return { put, remove, tombstones: newTombstones, profile, summary };
}

export function describeSummary({ added, updated, deleted }) {
  const parts = [];
  if (added) parts.push(`${added} added`);
  if (updated) parts.push(`${updated} updated`);
  if (deleted) parts.push(`${deleted} deleted`);
  return parts.length ? parts.join(", ") : "Already up to date";
}
