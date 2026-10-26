// Spreadsheet tabs; same columns as App/Support/SpreadsheetExport.swift.

import { data } from "./db.js";
import * as M from "./model.js";
import { growthReport } from "./growth.js";
import { clutchStats } from "./breeding.js";

const date = (iso) => (iso ? new Date(iso) : null);
const yesNo = (b) => (b ? "Yes" : "No");

export function workbookSheets() {
  const cat = M.catalog();
  const snakes = M.sortedSnakes();

  const snakesSheet = {
    name: "Snakes",
    columns: ["Name", "Species", "Sex", "Morph", "Status", "Status note", "Enclosure", "Dam", "Sire", "Hatch date", "Hatch date estimated", "Age", "Origin", "Origin details",
      "Acquired", "Weight (g)", "Feed every (days)", "Last meal", "Last meal prey", "Days since meal", "Feeding status",
      "Last shed", "Growth (g/week)", "Vs typical for age", "Open concerns", "Photos", "Notes"],
    rows: snakes.map((s) => {
      const meal = M.lastMeal(s);
      const growth = growthReport(s, M.weightsFor(s).map((l) => ({ date: l.date, grams: l.grams })));
      return [s.name, s.species, M.SEX[s.sex]?.label ?? s.sex, cat.describe(s.traits), M.STATUS[M.statusOf(s)].label,
        s.statusNote || null, s.enclosure || null, M.snakeByID(s.damID)?.name ?? null, M.snakeByID(s.sireID)?.name ?? null, date(s.hatchDate),
        s.hatchDate ? yesNo(s.hatchDateIsEstimate) : null, M.ageDescription(s), M.ORIGIN[s.origin]?.label ?? s.origin,
        s.originDetails, date(s.acquiredDate), s.weightGrams ?? null, s.feedingIntervalDays, date(meal?.date),
        meal ? M.feedingSummary(meal) : null, M.daysSinceMeal(s), M.FEEDING_STATUS_LABEL[M.feedingStatus(s)],
        date(M.lastShed(s)?.date), growth.rate == null ? null : Math.round(growth.rate * 10) / 10,
        { below: "Below typical", within: "On track", above: "Above typical" }[growth.comparison] ?? null, M.openConcerns(s).map((c) => c.title).join("; "), M.photosFor(s).length, s.notes];
    }),
  };

  const feedingsSheet = {
    name: "Feedings",
    columns: ["Snake", "Date", "Result", "Prey", "Size", "Offered", "Count", "Prey weight (g)", "Notes"],
    rows: snakes.flatMap((s) => M.feedingsFor(s).map((r) => [s.name, date(r.date), r.refused ? "Refused" : "Ate", r.preyType,
      r.preySize, r.preyState, r.preyCount, r.preyWeightGrams ?? null, r.notes])),
  };

  const careLogSheet = {
    name: "Care Log",
    columns: ["Snake", "Date", "Type", "Weight (g)", "Notes"],
    rows: snakes.flatMap((s) => M.logsFor(s).map((l) => [s.name, date(l.date), M.LOG_KINDS[l.kind]?.label ?? l.kind,
      l.grams ?? null, l.notes])),
  };

  const concernsSheet = {
    name: "Concerns",
    columns: ["Snake", "Concern", "Category", "Severity", "Noticed", "Status", "Resolved on", "Vet visit", "Details"],
    rows: snakes.flatMap((s) => M.concernsFor(s).map((c) => [s.name, c.title, c.category, c.severity, date(c.dateNoted),
      c.isResolved ? "Resolved" : "Open", date(c.resolvedDate), yesNo(c.vetVisit), c.details])),
  };

  const pairingsSheet = {
    name: "Pairings",
    columns: ["Season", "Female", "Female morph", "Male", "Male morph", "Species", "Status", "Introduced", "Locks", "Last lock",
      "Ovulation", "Pre-lay shed", "Laid / born", "Eggs", "Good eggs", "Est. hatch", "Hatched", "Hatched / born",
      "Hatch rate", "Incubation temp (°F)", "Incubation days", "Female weight at pairing (g)", "Notes"],
    rows: [...data.pairings]
      .sort((a, b) => b.season - a.season || b.createdAt.localeCompare(a.createdAt))
      .map((p) => {
        const female = M.snakeByID(p.femaleID), male = M.snakeByID(p.maleID);
        const c = clutchStats(p, data.logs.filter((l) => l.snakeID === p.femaleID && l.kind === "weight").map((l) => ({ date: l.date, grams: l.grams })));
        return [p.season, female?.name ?? null, female ? cat.describe(female.traits) : null, male?.name ?? null,
          male ? cat.describe(male.traits) : null, M.pairingSpecies(p), p.status, date(p.introducedDate), p.lockCount,
          date(p.lastLockDate), date(p.ovulationDate), date(p.preLayShedDate), date(p.layDate), p.eggCount ?? null,
          p.fertileEggCount ?? null, date(M.estimatedHatch(p)), date(p.hatchDate), c.hatched,
          c.hatchRate == null ? null : `${Math.round(c.hatchRate * 100)}%`, p.incubationTempF ?? null, c.incubationDays, c.femaleWeight, p.notes];
      }),
  };

  return [snakesSheet, feedingsSheet, careLogSheet, concernsSheet, pairingsSheet];
}
