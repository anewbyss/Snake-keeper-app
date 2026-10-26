import test from "node:test";
import assert from "node:assert/strict";
import { planMerge, parseSyncFile, buildSyncFile } from "../js/sync.js";

const empty = () => ({ customGenes: [], snakes: [], feedings: [], logs: [], concerns: [], photos: [], pairings: [], deleted: [], profile: [] });
const snake = (id, updatedAt, name = id) => ({ id, updatedAt, name });

test("adds new records and keeps the newer version", () => {
  const local = { ...empty(), snakes: [snake("A", "2026-01-02T00:00:00Z", "local A"), snake("B", "2026-01-05T00:00:00Z", "local B")] };
  const incoming = { ...empty(), snakes: [snake("A", "2026-01-03T00:00:00.000Z", "remote A"), snake("B", "2026-01-01T00:00:00Z"), snake("C", "2026-01-01T00:00:00Z")] };
  const plan = planMerge(local, incoming);
  assert.deepEqual(plan.put.snakes.map((s) => s.name), ["remote A", "C"]);
  assert.deepEqual(plan.summary, { added: 1, updated: 1, deleted: 0, unchanged: 1 });
});

test("incoming tombstone deletes an older local record", () => {
  const local = { ...empty(), snakes: [snake("A", "2026-01-01T00:00:00Z")] };
  const incoming = { ...empty(), deleted: [{ id: "A", type: "snakes", deletedAt: "2026-01-02T00:00:00Z" }] };
  const plan = planMerge(local, incoming);
  assert.deepEqual(plan.remove.snakes, ["A"]);
  assert.equal(plan.tombstones.length, 1);
});

test("an edit made after the deletion wins", () => {
  const local = { ...empty(), snakes: [snake("A", "2026-01-03T00:00:00Z")] };
  const incoming = { ...empty(), deleted: [{ id: "A", type: "snakes", deletedAt: "2026-01-02T00:00:00Z" }] };
  assert.deepEqual(planMerge(local, incoming).remove.snakes, []);
});

test("local tombstone stops a deleted record coming back", () => {
  const local = { ...empty(), deleted: [{ id: "A", type: "snakes", deletedAt: "2026-01-02T00:00:00Z" }] };
  const incoming = { ...empty(), snakes: [snake("A", "2026-01-01T00:00:00Z")] };
  assert.deepEqual(planMerge(local, incoming).put.snakes, []);
});

test("round trip converges", () => {
  const a = { ...empty(), snakes: [snake("A", "2026-01-01T00:00:00Z")] };
  const file = parseSyncFile(JSON.stringify(buildSyncFile(a)));
  const plan = planMerge(a, file);
  assert.deepEqual(plan.summary, { added: 0, updated: 0, deleted: 0, unchanged: 1 });
});

test("rejects other files", () => {
  assert.throws(() => parseSyncFile("{}"));
  assert.throws(() => parseSyncFile("nope"));
  assert.throws(() => parseSyncFile(JSON.stringify({ format: "snakekeeper-sync", version: 99 })));
});

test("profile: newest wins", () => {
  const local = { ...empty(), profile: [{ id: "profile", name: "Old", updatedAt: "2026-01-01T00:00:00Z" }] };
  assert.equal(planMerge(local, { ...empty(), profile: { name: "New", updatedAt: "2026-02-01T00:00:00Z" } }).profile.name, "New");
  assert.equal(planMerge(local, { ...empty(), profile: { name: "Older", updatedAt: "2025-01-01T00:00:00Z" } }).profile, null);
  assert.equal(planMerge(empty(), { ...empty(), profile: null }).profile, null);
});

test("care log entries sync like other records", () => {
  const incoming = { ...empty(), logs: [{ id: "L", snakeID: "A", kind: "shed", updatedAt: "2026-01-01T00:00:00Z" }] };
  assert.equal(planMerge(empty(), incoming).put.logs.length, 1);
});
