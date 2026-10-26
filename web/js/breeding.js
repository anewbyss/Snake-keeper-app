// Clutch and breeding-history figures (mirrors App/Support/BreedingStats.swift).

const DAY = 86400000;
const ratio = (a, b) => (a != null && b > 0 ? a / b : null);

/** The female's latest weighing on or before `iso` (her weight when the pairing started). */
export function weightOn(weights, iso) {
  if (!iso) return null;
  const before = weights.filter((w) => w.grams > 0 && w.date <= iso).sort((a, b) => b.date.localeCompare(a.date));
  return before[0]?.grams ?? null;
}

/** Figures for one pairing's clutch. */
export function clutchStats(pairing, femaleWeights = []) {
  const eggs = pairing.eggCount ?? null;
  const good = pairing.fertileEggCount ?? null;
  const hatched = pairing.hatchedCount ?? null;
  return {
    eggs,
    good,
    hatched,
    fertileRate: ratio(good, eggs),
    // Hatch rate is measured against good eggs when known.
    hatchRate: ratio(hatched, good ?? eggs),
    incubationDays: pairing.layDate && pairing.hatchDate
      ? Math.round((Date.parse(pairing.hatchDate) - Date.parse(pairing.layDate)) / DAY) : null,
    femaleWeight: weightOn(femaleWeights, pairing.introducedDate ?? pairing.layDate),
  };
}

const hasClutch = (p) => p.layDate != null || p.eggCount != null;

/** Totals per season, newest first. */
export function seasonSummaries(pairings) {
  const seasons = new Map();
  for (const p of pairings) {
    const s = seasons.get(p.season) ?? { season: p.season, pairings: 0, clutches: 0, eggs: 0, good: 0, hatched: 0, goodKnown: 0 };
    s.pairings++;
    if (hasClutch(p)) s.clutches++;
    s.eggs += p.eggCount ?? 0;
    s.good += p.fertileEggCount ?? p.eggCount ?? 0;
    s.hatched += p.hatchedCount ?? 0;
    seasons.set(p.season, s);
  }
  return [...seasons.values()]
    .map((s) => ({ ...s, hatchRate: ratio(s.hatched, s.good), averageClutch: ratio(s.eggs, s.clutches) }))
    .sort((a, b) => b.season - a.season);
}

/** Lifetime figures for one female. */
export function femaleHistory(pairings) {
  const clutches = pairings.filter(hasClutch);
  const eggs = clutches.reduce((n, p) => n + (p.eggCount ?? 0), 0);
  const hatched = clutches.reduce((n, p) => n + (p.hatchedCount ?? 0), 0);
  const seasons = clutches.map((p) => p.season);
  return {
    pairings: pairings.length,
    clutches: clutches.length,
    eggs,
    hatched,
    averageClutch: ratio(eggs, clutches.length),
    lastClutchSeason: seasons.length ? Math.max(...seasons) : null,
  };
}
