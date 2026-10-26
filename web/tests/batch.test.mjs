import test from "node:test";
import assert from "node:assert/strict";
import { applyBatch } from "../js/batch.js";
import { GeneticsCalculator, BUILT_IN_GENES } from "../js/genetics.js";

const calc = new GeneticsCalculator(BUILT_IN_GENES);
const snake = (id, traits = [], status) => ({ id, traits, ...(status ? { status } : {}) });

test("adds a gene, changes copies, and leaves unaffected snakes alone", () => {
  const a = snake("A"), b = snake("B", [{ geneID: "bp.clown", zygosity: "single" }]);
  const { updated } = applyBatch([a, b], { gene: { geneID: "bp.clown", mode: "set", zygosity: "single" } }, calc);
  assert.deepEqual(updated.map((s) => s.id), ["A"]);
  assert.deepEqual(updated[0].traits, [{ geneID: "bp.clown", zygosity: "single" }]);
  assert.deepEqual(a.traits, [], "originals are not modified");

  const { updated: u2 } = applyBatch([b], { gene: { geneID: "bp.clown", mode: "set", zygosity: "possibleHet", probability: 0.5 } }, calc);
  assert.deepEqual(u2[0].traits, [{ geneID: "bp.clown", zygosity: "possibleHet", probability: 0.5 }]);
});

test("removes a gene", () => {
  const { updated } = applyBatch([snake("A", [{ geneID: "bp.pastel", zygosity: "single" }]), snake("B")],
    { gene: { geneID: "bp.pastel", mode: "remove" } }, calc);
  assert.deepEqual(updated.map((s) => [s.id, s.traits.length]), [["A", 0]]);
});

test("skips snakes the change would make invalid", () => {
  const full = snake("A", [{ geneID: "bp.lesser", zygosity: "single" }, { geneID: "bp.mojave", zygosity: "single" }]);
  const { updated, skipped } = applyBatch([full, snake("B")], { gene: { geneID: "bp.butter", mode: "set", zygosity: "single" } }, calc);
  assert.deepEqual(updated.map((s) => s.id), ["B"]);
  assert.equal(skipped[0].snake.id, "A");
});

test("sets status alongside genes", () => {
  const { updated } = applyBatch([snake("A"), snake("B", [], "forSale")], { status: "forSale" }, calc);
  assert.deepEqual(updated.map((s) => [s.id, s.status]), [["A", "forSale"]]);
});
