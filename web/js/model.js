// Domain helpers. Raw values match the native app (App/Models) so the sync file is shared.

import { data } from "./db.js";
import { SPECIES } from "./genes.js";
import { GeneticsCalculator, BUILT_IN_GENES, describe as describeTraits } from "./genetics.js";
import { daysBetween, addDays, ageString } from "./ui.js";

export const OTHER_SPECIES = "Other";

export const SEX = {
  male: { label: "Male", symbol: "♂" },
  female: { label: "Female", symbol: "♀" },
  unknown: { label: "Unsexed", symbol: "?" },
};

export const ORIGIN = {
  homeBred: { label: "Bred by me", prompt: "Clutch / parents" },
  purchased: { label: "Purchased", prompt: "Breeder or seller" },
  traded: { label: "Traded", prompt: "Breeder or seller" },
  rescue: { label: "Rescue / rehome", prompt: "Previous owner / organization" },
  wildCaught: { label: "Wild caught / import", prompt: "Locality / importer" },
  other: { label: "Other", prompt: "Details" },
};

/** Collection status. Sold and deceased animals are hidden from day-to-day lists. */
export const STATUS = {
  active: { label: "Active", color: "var(--green)" },
  forSale: { label: "For Sale", color: "var(--blue)" },
  onHold: { label: "On Hold", color: "var(--orange)" },
  sold: { label: "Sold", color: "var(--muted)" },
  deceased: { label: "Deceased", color: "var(--muted)" },
};
export const statusOf = (snake) => (STATUS[snake.status] ? snake.status : "active");
export const isInCollection = (snake) => !["sold", "deceased"].includes(statusOf(snake));

export const LOG_KINDS = {
  shed: { label: "Shed", icon: "🐍" },
  weight: { label: "Weight", icon: "⚖︎" },
  cleaning: { label: "Enclosure cleaned", icon: "🧽" },
  medication: { label: "Medication / treatment", icon: "💊" },
  note: { label: "Note", icon: "📝" },
};

export const PREY_TYPES = ["Mouse", "Rat", "ASF", "Gerbil", "Chick", "Quail", "Rabbit", "Fish", "Other"];
export const PREY_SIZES = ["Pinky", "Fuzzy", "Hopper", "Weaned", "Small", "Medium", "Large", "X-Large", "Jumbo"];
export const PREY_STATES = { "Frozen/thawed": "F/T", "Pre-killed": "P/K", Live: "Live" };

export const CONCERN_CATEGORIES = [
  "Feeding / refusal", "Regurgitation", "Bad shed", "Respiratory", "Mites / parasites", "Weight loss",
  "Injury / burn", "Neurological", "Scale rot / skin", "Reproductive", "Behavior", "Other",
];
export const SEVERITIES = { Low: "var(--yellow)", Medium: "var(--orange)", High: "var(--red)" };

export const PAIRING_STATUSES = {
  Planned: "📅", Introduced: "🤝", "Locks observed": "🔗", Ovulated: "◌", "Pre-lay shed": "✨",
  "Eggs laid / born": "🥚", Hatched: "🎉", Unsuccessful: "✕",
};
export const isActivePairing = (p) => p.status !== "Hatched" && p.status !== "Unsuccessful";

// MARK: Genes

export function customToGene(custom) {
  const id = `custom.${custom.id}`;
  const gene = { id, name: custom.name, inheritance: custom.inheritance, locus: custom.locus || id };
  if (custom.superName) gene.superName = custom.superName;
  if (custom.warning) gene.warning = custom.warning;
  return gene;
}

let cachedCatalog, cachedFrom;

/** Built-in genes plus the user's custom genes. */
export function catalog() {
  if (cachedCatalog && cachedFrom === data.customGenes) return cachedCatalog;
  const custom = data.customGenes.map(customToGene);
  const genes = [...BUILT_IN_GENES, ...custom];
  const byID = Object.fromEntries(genes.map((g) => [g.id, g]));
  const customSpecies = Object.fromEntries(data.customGenes.map((c) => [`custom.${c.id}`, c.species]));
  const builtIn = SPECIES.map((s) => s.name);
  const extra = [...new Set(Object.values(customSpecies))].filter((s) => !builtIn.includes(s) && s !== OTHER_SPECIES).sort();
  cachedFrom = data.customGenes;
  cachedCatalog = {
    genes,
    byID,
    calculator: new GeneticsCalculator(genes),
    speciesNames: [...builtIn, ...extra, OTHER_SPECIES],
    genesFor(species) {
      const own = SPECIES.find((s) => s.name === species)?.genes ?? [];
      const customs = custom.filter((g) => customSpecies[g.id] === species);
      return [...own, ...customs].sort((a, b) => a.name.localeCompare(b.name));
    },
    describe: (traits) => describeTraits(traits ?? [], byID),
    cross(a, b) {
      try {
        return { outcomes: this.calculator.cross(a ?? [], b ?? []) };
      } catch (error) {
        return { error: error.message };
      }
    },
  };
  return cachedCatalog;
}

export function speciesInfo(name) {
  return SPECIES.find((s) => s.name === name);
}

export function incubationDays(species) {
  const info = speciesInfo(species);
  if (info) return info.incubationDays;
  return species ? 60 : null;
}

// MARK: Snakes

export const snakeByID = (id) => data.snakes.find((s) => s.id === id);
export const sortedSnakes = () => [...data.snakes].sort((a, b) => a.name.localeCompare(b.name, undefined, { sensitivity: "base" }));
export const feedingsFor = (snake) => data.feedings.filter((f) => f.snakeID === snake.id).sort((a, b) => b.date.localeCompare(a.date));
export const concernsFor = (snake) => data.concerns.filter((c) => c.snakeID === snake.id).sort((a, b) => b.dateNoted.localeCompare(a.dateNoted));
export const photosFor = (snake) => data.photos.filter((p) => p.snakeID === snake.id).sort((a, b) => b.dateTaken.localeCompare(a.dateTaken));
export const logsFor = (snake) => data.logs.filter((l) => l.snakeID === snake.id).sort((a, b) => b.date.localeCompare(a.date));
export const weightsFor = (snake) => logsFor(snake).filter((l) => l.kind === "weight" && l.grams > 0);
export const lastShed = (snake) => logsFor(snake).find((l) => l.kind === "shed");
export const offspringOf = (snake) => sortedSnakes().filter((s) => s.damID === snake.id || s.sireID === snake.id);
export const openConcerns = (snake) => concernsFor(snake).filter((c) => !c.isResolved);
export const coverPhoto = (snake) => { const photos = photosFor(snake); return photos.find((p) => p.isCover) ?? photos[0]; };
export const pairingsFor = (snake) => data.pairings.filter((p) => p.femaleID === snake.id || p.maleID === snake.id).sort((a, b) => b.createdAt.localeCompare(a.createdAt));

export function lastMeal(snake) {
  return feedingsFor(snake).find((f) => !f.refused);
}

export function daysSinceMeal(snake) {
  const meal = lastMeal(snake);
  return meal ? daysBetween(meal.date) : null;
}

export function nextFeeding(snake) {
  const meal = lastMeal(snake);
  return meal ? addDays(meal.date, snake.feedingIntervalDays) : null;
}

/** "none" | "fed" | "due" | "overdue" — same thresholds as the native app. */
export function feedingStatus(snake) {
  const days = daysSinceMeal(snake);
  if (days == null) return "none";
  const interval = snake.feedingIntervalDays;
  if (days > interval + Math.max(2, Math.floor(interval / 2))) return "overdue";
  if (days >= interval) return "due";
  return "fed";
}

export const FEEDING_STATUS_LABEL = { none: "No meals logged", fed: "Fed", due: "Due", overdue: "Overdue" };

export function refusalStreak(snake) {
  let streak = 0;
  for (const record of feedingsFor(snake)) {
    if (!record.refused) break;
    streak++;
  }
  return streak;
}

export function ageDescription(snake) {
  if (!snake.hatchDate) return null;
  const text = ageString(snake.hatchDate);
  return snake.hatchDateIsEstimate ? `~${text}` : text;
}

export function feedingSummary(record) {
  const count = record.preyCount > 1 ? `${record.preyCount}× ` : "";
  return `${count}${record.preySize} ${record.preyType} (${PREY_STATES[record.preyState] ?? record.preyState})`;
}

// MARK: Pairings

export const pairingByID = (id) => data.pairings.find((p) => p.id === id);

export function pairingTitle(p) {
  return `${snakeByID(p.femaleID)?.name ?? "?"} × ${snakeByID(p.maleID)?.name ?? "?"}`;
}

export function pairingSpecies(p) {
  return snakeByID(p.femaleID)?.species ?? snakeByID(p.maleID)?.species ?? "";
}

export function estimatedHatch(p) {
  const days = incubationDays(pairingSpecies(p));
  return p.layDate && days ? addDays(p.layDate, days) : null;
}

export function estimatedLay(p) {
  return !p.layDate && p.preLayShedDate ? addDays(p.preLayShedDate, 30) : null;
}

// MARK: Profile

export const DEFAULT_PROFILE = {
  id: "profile", name: "", business: "", location: "", email: "", phone: "", website: "", social: "",
  photo: null, defaultSpecies: SPECIES[0].name, defaultFeedingInterval: 7, notes: "",
};

export function profile() {
  return { ...DEFAULT_PROFILE, ...(data.profile[0] ?? {}) };
}

/** "Morph Market Reptiles" / "Alex Smith" / "" */
export function breederName() {
  const p = profile();
  return p.business || p.name || "";
}
