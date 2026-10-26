// Growth calculations (mirrors SnakeGenetics/GrowthGuide.swift). Data: growth-data.js.

import { GROWTH_GUIDES, GENERAL_TIPS } from "./growth-data.js";

export { GENERAL_TIPS };

const DAY = 86400000;
const DAYS_PER_MONTH = 30.4375;

/** Prey size guideline when a species has no guide. */
export const DEFAULT_PREY_PERCENT = [10, 15];

export function guideFor(species) {
  return GROWTH_GUIDES.find((g) => g.species === species) ?? null;
}

export function ageInMonths(hatchISO, atISO = new Date().toISOString()) {
  return (Date.parse(atISO) - Date.parse(hatchISO)) / DAY / DAYS_PER_MONTH;
}

/** Feeding stage for a weight: the first stage whose limit is above it. */
export function stageFor(guide, grams) {
  if (!guide || !(grams > 0)) return null;
  return guide.stages.find((s) => s.upTo == null || grams < s.upTo) ?? null;
}

/** Typical weight range at an age, interpolated along the guide's curve. Null outside the curve. */
export function referenceAt(guide, months) {
  if (!guide || months == null || months < 0) return null;
  const curve = guide.curve;
  for (let i = 0; i < curve.length - 1; i++) {
    const a = curve[i], b = curve[i + 1];
    if (months >= a.months && months <= b.months) {
      const t = (months - a.months) / (b.months - a.months);
      return { low: a.low + (b.low - a.low) * t, high: a.high + (b.high - a.high) * t };
    }
  }
  return null;
}

/** "below" | "within" | "above" */
export function compareToRange(grams, range) {
  if (!range || !(grams > 0)) return null;
  if (grams < range.low) return "below";
  if (grams > range.high) return "above";
  return "within";
}

/**
 * Average growth in grams per week (least-squares slope) over the `windowDays` before the
 * latest weighing. Needs two or more weighings at least 14 days apart.
 */
export function growthRate(weights, windowDays = 90) {
  const points = weights.filter((w) => w.grams > 0 && w.date).map((w) => ({ t: Date.parse(w.date) / DAY, g: w.grams }));
  if (points.length < 2) return null;
  const latest = Math.max(...points.map((p) => p.t));
  const recent = points.filter((p) => p.t >= latest - windowDays);
  if (recent.length < 2) return null;
  const span = latest - Math.min(...recent.map((p) => p.t));
  if (span < 14) return null;
  const mt = recent.reduce((s, p) => s + p.t, 0) / recent.length;
  const mg = recent.reduce((s, p) => s + p.g, 0) / recent.length;
  const num = recent.reduce((s, p) => s + (p.t - mt) * (p.g - mg), 0);
  const den = recent.reduce((s, p) => s + (p.t - mt) ** 2, 0);
  return den ? (num / den) * 7 : null;
}

/** Suggested prey weight range in grams. */
export function preyRange(guide, grams) {
  if (!(grams > 0)) return null;
  const [low, high] = guide?.preyPercent ?? DEFAULT_PREY_PERCENT;
  return { low: (grams * low) / 100, high: (grams * high) / 100 };
}

/** Whole weeks to reach `target` at `ratePerWeek`; 0 if already there, null if not growing. */
export function weeksToTarget(current, target, ratePerWeek) {
  if (!(current > 0) || !(target > 0)) return null;
  if (current >= target) return 0;
  if (!(ratePerWeek > 0)) return null;
  return Math.ceil((target - current) / ratePerWeek);
}

/** Breeding weight / age target for a sex, or null for unsexed snakes. */
export function breedingTarget(guide, sex) {
  if (!guide) return null;
  if (sex === "female") return guide.breedingFemale;
  if (sex === "male") return guide.breedingMale;
  return null;
}

/**
 * Everything the growth screens show for one snake.
 * weights: [{ date, grams }], any order.
 */
export function growthReport({ species, sex, hatchDate, weightGrams }, weights, now = new Date().toISOString()) {
  const guide = guideFor(species);
  const sorted = [...weights].filter((w) => w.grams > 0).sort((a, b) => a.date.localeCompare(b.date));
  const latest = sorted[sorted.length - 1];
  const grams = latest?.grams ?? weightGrams ?? null;
  const ageMonths = hatchDate ? ageInMonths(hatchDate, now) : null;
  const reference = referenceAt(guide, ageMonths);
  const rate = growthRate(sorted);
  const target = breedingTarget(guide, sex);
  return {
    guide,
    grams,
    ageMonths,
    stage: stageFor(guide, grams),
    reference,
    comparison: compareToRange(grams, reference),
    rate,
    prey: preyRange(guide, grams),
    target,
    weeksToTarget: target ? weeksToTarget(grams, target.grams, rate) : null,
    // Age-for-weight points for charts: { months, grams }.
    points: hatchDate ? sorted.map((w) => ({ months: ageInMonths(hatchDate, w.date), grams: w.grams, date: w.date })) : [],
  };
}
