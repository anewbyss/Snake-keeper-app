import test from "node:test";
import assert from "node:assert/strict";
import { weightOn, clutchStats, seasonSummaries, femaleHistory } from "../js/breeding.js";

const p = (season, fields) => ({ season, ...fields });

test("clutch stats", () => {
  const s = clutchStats({ eggCount: 8, fertileEggCount: 6, hatchedCount: 5, layDate: "2026-04-01T12:00:00Z", hatchDate: "2026-05-27T12:00:00Z", introducedDate: "2025-11-15T12:00:00Z" },
    [{ date: "2025-11-01T00:00:00Z", grams: 1800 }, { date: "2025-12-01T00:00:00Z", grams: 1900 }]);
  assert.equal(s.fertileRate, 0.75);
  assert.equal(s.hatchRate, 5 / 6);
  assert.equal(s.incubationDays, 56);
  assert.equal(s.femaleWeight, 1800, "weight on or before the pairing date");
  assert.equal(clutchStats({}).hatchRate, null);
});

test("weightOn ignores later weighings", () => {
  assert.equal(weightOn([{ date: "2026-02-01T00:00:00Z", grams: 5 }], "2026-01-01T00:00:00Z"), null);
});

test("season summaries", () => {
  const [s2026, s2025] = seasonSummaries([
    p(2026, { eggCount: 6, fertileEggCount: 5, hatchedCount: 5, layDate: "x" }),
    p(2026, {}),
    p(2025, { eggCount: 4, hatchedCount: 2 }),
  ]);
  assert.deepEqual([s2026.season, s2026.pairings, s2026.clutches, s2026.eggs, s2026.hatched], [2026, 2, 1, 6, 5]);
  assert.equal(s2026.hatchRate, 1);
  assert.equal(s2025.hatchRate, 0.5, "falls back to eggs when good eggs aren't recorded");
});

test("female history", () => {
  const h = femaleHistory([p(2024, { eggCount: 6, hatchedCount: 6 }), p(2025, { eggCount: 8, hatchedCount: 7 }), p(2026, {})]);
  assert.deepEqual([h.pairings, h.clutches, h.eggs, h.hatched, h.averageClutch, h.lastClutchSeason], [3, 2, 14, 13, 7, 2025]);
});
