// Port of SnakeGenetics (GeneticsCalculator.swift / Gene.swift). Keep the two in step.
//
// A trait is { geneID, zygosity: "single" | "double" | "possibleHet", probability? }.
// "single" = one copy (het for recessives), "double" = two copies (visual / super),
// "possibleHet" = unproven het with `probability` (0...1).

import { SPECIES, COMPOUND_NAMES } from "./genes.js";

export const WILD = "+";

export const INHERITANCE = {
  recessive: "Recessive",
  incompleteDominant: "Incomplete Dominant (Co-dom)",
  dominant: "Dominant",
};

export const BUILT_IN_GENES = SPECIES.flatMap((s) => s.genes);

export function compoundKey(a, b) {
  return [a, b].sort().join("|");
}

export function homozygousName(gene) {
  if (gene.superName) return gene.superName;
  return gene.inheritance === "recessive" ? gene.name : `Super ${gene.name}`;
}

export const Percent = {
  format(p) {
    const value = p * 100;
    if (Math.abs(value - Math.round(value)) < 0.005) return `${Math.round(value)}%`;
    return `${value.toFixed(2).replace(/0+$/, "").replace(/\.$/, "")}%`;
  },
  floor(p) {
    return `${Math.floor(p * 100 + 1e-9)}%`;
  },
};

/** Zygosity choices for a gene's picker: [{ zygosity, probability?, label }]. */
export function zygosityOptions(gene) {
  if (gene.inheritance === "recessive") {
    return [
      { zygosity: "double", label: "Visual" },
      { zygosity: "single", label: "Het" },
      { zygosity: "possibleHet", probability: 0.5, label: "50% Poss Het" },
      { zygosity: "possibleHet", probability: 2 / 3, label: "66% Poss Het" },
    ];
  }
  return gene.inheritance === "incompleteDominant"
    ? [{ zygosity: "single", label: "Single copy" }, { zygosity: "double", label: homozygousName(gene) }]
    : [{ zygosity: "single", label: "Visual" }, { zygosity: "double", label: "Homozygous" }];
}

/** "het Clown", "Super Pastel", "66% poss het Pied". */
export function traitLabel(gene, trait) {
  const recessive = gene.inheritance === "recessive";
  switch (trait.zygosity) {
    case "single": return recessive ? `het ${gene.name}` : gene.name;
    case "double": return homozygousName(gene);
    default: return `${Percent.floor(trait.probability)} poss ${recessive ? "het " : ""}${gene.name}`;
  }
}

/** Morph name: visuals, then hets, then possible hets. */
export function describe(traits, genesByID) {
  const visuals = [], hets = [], possibles = [];
  for (const trait of traits) {
    const gene = genesByID[trait.geneID];
    if (!gene) continue;
    const label = traitLabel(gene, trait);
    if (trait.zygosity === "possibleHet") possibles.push(label);
    else if (gene.inheritance === "recessive" && trait.zygosity === "single") hets.push(label);
    else visuals.push(label);
  }
  const parts = [...visuals.sort(), ...hets.sort(), ...possibles.sort()];
  return parts.length ? parts.join(" ") : "Normal";
}

export class GeneticsError extends Error {}

const genotypeKey = (a, b) => (a <= b ? `${a},${b}` : `${b},${a}`);

export class GeneticsCalculator {
  constructor(genes, compoundNames = COMPOUND_NAMES) {
    this.genes = Object.fromEntries(genes.map((g) => [g.id, g]));
    this.compoundNames = compoundNames;
  }

  /** { locus: Map(genotypeKey -> probability) } */
  genotypeDistribution(traits) {
    const allelesByLocus = {};
    const namesByLocus = {};
    for (const trait of traits) {
      const gene = this.genes[trait.geneID];
      if (!gene) throw new GeneticsError(`Unknown gene "${trait.geneID}". It may have been deleted.`);
      let contribution;
      if (trait.zygosity === "single") contribution = [[[gene.id], 1]];
      else if (trait.zygosity === "double") contribution = [[[gene.id, gene.id], 1]];
      else {
        const p = Math.min(Math.max(trait.probability ?? 0, 0), 1);
        contribution = [[[gene.id], p], [[], 1 - p]];
      }
      const current = allelesByLocus[gene.locus] ?? [[[], 1]];
      const combined = new Map();
      for (const [existing, pe] of current) {
        for (const [added, pa] of contribution) {
          if (pe * pa <= 0) continue;
          const alleles = [...existing, ...added];
          const key = alleles.join("\u0000");
          const entry = combined.get(key) ?? [alleles, 0];
          entry[1] += pe * pa;
          combined.set(key, entry);
        }
      }
      allelesByLocus[gene.locus] = [...combined.values()];
      (namesByLocus[gene.locus] ??= []).push(gene.name);
    }

    const result = {};
    for (const [locus, distribution] of Object.entries(allelesByLocus)) {
      const genotypes = new Map();
      for (const [alleles, p] of distribution) {
        if (alleles.length > 2) {
          throw new GeneticsError(
            `${namesByLocus[locus].join(", ")} are allelic (same locus). A snake can only carry two copies in total there.`
          );
        }
        const padded = [...alleles, WILD, WILD].slice(0, 2);
        const key = genotypeKey(padded[0], padded[1]);
        genotypes.set(key, (genotypes.get(key) ?? 0) + p);
      }
      result[locus] = genotypes;
    }
    return result;
  }

  validate(traits) {
    this.genotypeDistribution(traits);
  }

  /** Offspring outcomes, most likely first. */
  cross(parent1, parent2) {
    const first = this.genotypeDistribution(parent1);
    const second = this.genotypeDistribution(parent2);
    const normal = new Map([[genotypeKey(WILD, WILD), 1]]);
    const loci = [...new Set([...Object.keys(first), ...Object.keys(second)])].sort();

    // state: { visuals:Set, expressed:Set, carried:Set, warnings:Set }
    let states = new Map([[stateKey(emptyState()), [emptyState(), 1]]]);
    for (const locus of loci) {
      const offspring = new Map();
      for (const [g1, p1] of first[locus] ?? normal) {
        for (const [g2, p2] of second[locus] ?? normal) {
          for (const a of g1.split(",")) {
            for (const b of g2.split(",")) {
              const key = genotypeKey(a, b);
              offspring.set(key, (offspring.get(key) ?? 0) + p1 * p2 * 0.25);
            }
          }
        }
      }
      const locusStates = new Map();
      for (const [genotype, p] of offspring) {
        const state = this.phenotype(genotype.split(","));
        const key = stateKey(state);
        const entry = locusStates.get(key) ?? [state, 0];
        entry[1] += p;
        locusStates.set(key, entry);
      }
      const next = new Map();
      for (const [state, ps] of states.values()) {
        for (const [locusState, pl] of locusStates.values()) {
          const merged = mergeStates(state, locusState);
          const key = stateKey(merged);
          const entry = next.get(key) ?? [merged, 0];
          entry[1] += ps * pl;
          next.set(key, entry);
        }
      }
      states = next;
    }

    const groups = new Map();
    for (const [state, p] of states.values()) {
      if (p <= 1e-12) continue;
      const key = [...state.visuals].sort().join("\u0000");
      const group = groups.get(key) ?? { visuals: [...state.visuals].sort(), probability: 0, expressed: new Set(), carried: new Map(), warnings: new Set() };
      group.probability += p;
      state.expressed.forEach((x) => group.expressed.add(x));
      state.warnings.forEach((x) => group.warnings.add(x));
      state.carried.forEach((id) => group.carried.set(id, (group.carried.get(id) ?? 0) + p));
      groups.set(key, group);
    }

    return [...groups.values()]
      .map((group) => {
        const hets = [...group.carried]
          .map(([geneID, p]) => {
            const probability = p / group.probability;
            const proven = probability >= 0.995;
            const geneName = this.genes[geneID]?.name ?? geneID;
            return { geneID, geneName, probability, proven, label: proven ? `het ${geneName}` : `${Percent.floor(probability)} poss het ${geneName}` };
          })
          .sort((a, b) => (a.proven !== b.proven ? (a.proven ? -1 : 1) : a.geneName < b.geneName ? -1 : a.geneName > b.geneName ? 1 : 0));
        const name = group.visuals.length ? group.visuals.join(" ") : "Normal";
        const hetsDescription = hets.map((h) => h.label).join(", ");
        return {
          name,
          visualTraits: group.visuals,
          expressedGeneIDs: group.expressed,
          probability: group.probability,
          hets,
          hetsDescription,
          fullName: hets.length ? `${name} ${hetsDescription}` : name,
          warnings: [...group.warnings].sort(),
        };
      })
      .sort((a, b) => (a.probability !== b.probability ? b.probability - a.probability : a.name < b.name ? -1 : 1));
  }

  probabilityOfExpressing(geneID, parent1, parent2) {
    return this.cross(parent1, parent2)
      .filter((o) => o.expressedGeneIDs.has(geneID))
      .reduce((sum, o) => sum + o.probability, 0);
  }

  phenotype(alleles) {
    const present = alleles.filter((a) => a !== WILD).map((a) => this.genes[a]).filter(Boolean);
    const state = emptyState();
    const express = (gene, homozygous = false) => {
      state.expressed.add(gene.id);
      if (gene.warning) state.warnings.add(`${gene.name}: ${gene.warning}`);
      if (homozygous && gene.homozygousWarning) state.warnings.add(`${homozygousName(gene)}: ${gene.homozygousWarning}`);
    };

    if (present.length === 1) {
      const [gene] = present;
      if (gene.inheritance === "recessive") state.carried.add(gene.id);
      else { state.visuals.add(gene.name); express(gene); }
    } else if (present.length === 2 && present[0].id === present[1].id) {
      state.visuals.add(homozygousName(present[0]));
      express(present[0], true);
    } else if (present.length === 2) {
      const [a, b] = present;
      const compound = this.compoundNames[compoundKey(a.id, b.id)];
      const aRec = a.inheritance === "recessive", bRec = b.inheritance === "recessive";
      if (compound) { state.visuals.add(compound); express(a); express(b); }
      else if (aRec && bRec) { state.visuals.add([a.name, b.name].sort().join("/")); express(a); express(b); }
      else if (aRec) { state.visuals.add(b.name); state.carried.add(a.id); express(b); }
      else if (bRec) { state.visuals.add(a.name); state.carried.add(b.id); express(a); }
      else { state.visuals.add(a.name); state.visuals.add(b.name); express(a); express(b); }
    }
    return state;
  }
}

function emptyState() {
  return { visuals: new Set(), expressed: new Set(), carried: new Set(), warnings: new Set() };
}

function mergeStates(a, b) {
  const union = (x, y) => new Set([...x, ...y]);
  return { visuals: union(a.visuals, b.visuals), expressed: union(a.expressed, b.expressed), carried: union(a.carried, b.carried), warnings: union(a.warnings, b.warnings) };
}

function stateKey(s) {
  return [s.visuals, s.expressed, s.carried, s.warnings].map((set) => [...set].sort().join("\u0001")).join("\u0002");
}
