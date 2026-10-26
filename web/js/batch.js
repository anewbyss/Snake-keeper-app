// Batch edits for several snakes at once (mirrors App/Support/BatchEdit.swift).

/**
 * Applies one change to each snake and returns copies of the snakes that changed.
 *
 * change = {
 *   gene?: { geneID, mode: "set" | "remove", zygosity?, probability? },
 *   status?: "active" | "forSale" | …,
 * }
 * A snake whose genes would become invalid (e.g. three alleles at one locus) is skipped.
 */
export function applyBatch(snakes, change, calculator) {
  const updated = [], skipped = [];
  for (const snake of snakes) {
    const next = structuredClone(snake);
    next.traits ??= [];
    let changed = false;

    if (change.gene) {
      const { geneID, mode, zygosity, probability } = change.gene;
      const index = next.traits.findIndex((t) => t.geneID === geneID);
      if (mode === "remove") {
        if (index >= 0) {
          next.traits.splice(index, 1);
          changed = true;
        }
      } else {
        const trait = { geneID, zygosity, ...(zygosity === "possibleHet" ? { probability } : {}) };
        const current = index >= 0 ? next.traits[index] : null;
        if (!current || current.zygosity !== trait.zygosity || current.probability !== trait.probability) {
          if (index >= 0) next.traits[index] = trait;
          else next.traits.push(trait);
          changed = true;
        }
      }
      if (changed) {
        try {
          calculator.validate(next.traits);
        } catch (error) {
          skipped.push({ snake, reason: error.message });
          continue;
        }
      }
    }

    if (change.status && (snake.status ?? "active") !== change.status) {
      next.status = change.status;
      changed = true;
    }

    if (changed) updated.push(next);
  }
  return { updated, skipped };
}
