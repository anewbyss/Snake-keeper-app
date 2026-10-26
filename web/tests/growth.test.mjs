import test from "node:test";
import assert from "node:assert/strict";
import { guideFor, stageFor, referenceAt, compareToRange, growthRate, preyRange, weeksToTarget, growthReport } from "../js/growth.js";

const bp = guideFor("Ball Python");
const close = (a, b) => assert.ok(Math.abs(a - b) < 1e-6, `${a} != ${b}`);

test("stages by weight", () => {
  assert.equal(stageFor(bp, 90).label, "Hatchling");
  assert.equal(stageFor(bp, 200).label, "Juvenile");
  assert.equal(stageFor(bp, 2000).label, "Adult");
  assert.equal(stageFor(null, 100), null);
});

test("reference range interpolates and stops at the curve's ends", () => {
  const at9 = referenceAt(bp, 9);              // between 6 [200,400] and 12 [400,900]
  close(at9.low, 300); close(at9.high, 650);
  assert.equal(referenceAt(bp, 60), null);
  assert.equal(referenceAt(bp, -1), null);
  assert.equal(compareToRange(250, at9), "below");
  assert.equal(compareToRange(500, at9), "within");
  assert.equal(compareToRange(700, at9), "above");
});

test("growth rate is a least-squares slope per week", () => {
  const w = [{ date: "2026-01-01T00:00:00Z", grams: 100 }, { date: "2026-01-15T00:00:00Z", grams: 120 }, { date: "2026-01-29T00:00:00Z", grams: 140 }];
  close(growthRate(w), 10);
  assert.equal(growthRate(w.slice(0, 1)), null);
  assert.equal(growthRate([{ date: "2026-01-01T00:00:00Z", grams: 100 }, { date: "2026-01-05T00:00:00Z", grams: 110 }]), null, "needs 14 days");
});

test("prey range and weeks to target", () => {
  const prey = preyRange(bp, 1000);
  close(prey.low, 100); close(prey.high, 150);
  assert.deepEqual(preyRange(null, 100), { low: 10, high: 15 });
  assert.equal(weeksToTarget(1000, 1500, 25), 20);
  assert.equal(weeksToTarget(1600, 1500, 25), 0);
  assert.equal(weeksToTarget(1000, 1500, 0), null);
});

test("report ties it together", () => {
  const r = growthReport({ species: "Ball Python", sex: "female", hatchDate: "2025-01-01T00:00:00Z" },
    [{ date: "2026-01-01T00:00:00Z", grams: 700 }, { date: "2026-02-01T00:00:00Z", grams: 800 }], "2026-02-01T00:00:00Z");
  assert.equal(r.grams, 800);
  assert.equal(r.stage.label, "Subadult");
  assert.equal(r.comparison, "within");
  assert.equal(r.target.grams, 1500);
  assert.ok(r.weeksToTarget > 0);
  assert.equal(r.points.length, 2);
  assert.equal(growthReport({ species: "Rosy Boa", sex: "male" }, []).guide, null);
});
