// Mirrors SnakeGenetics/Tests/SnakeGeneticsTests/GeneticsCalculatorTests.swift.
// Run: node --test web/tests
import test from "node:test";
import assert from "node:assert/strict";
import { GeneticsCalculator, BUILT_IN_GENES, describe, Percent } from "../js/genetics.js";

const calc = new GeneticsCalculator(BUILT_IN_GENES);
const t = (id, zygosity, probability) => ({ geneID: `bp.${id}`, zygosity, probability });
const find = (name, outcomes) => outcomes.find((o) => o.name === name);
const close = (a, b, msg) => assert.ok(Math.abs(a - b) < 1e-9, `${msg ?? ""} ${a} != ${b}`);

test("normal x normal", () => {
  const o = calc.cross([], []);
  assert.equal(o.length, 1); assert.equal(o[0].name, "Normal"); close(o[0].probability, 1);
});

test("het x het recessive", () => {
  const o = calc.cross([t("albino", "single")], [t("albino", "single")]);
  assert.equal(o.length, 2);
  close(find("Normal", o).probability, 0.75);
  close(find("Normal", o).hets[0].probability, 2 / 3);
  assert.equal(find("Normal", o).hetsDescription, "66% poss het Albino");
  close(find("Albino", o).probability, 0.25);
  assert.equal(find("Albino", o).hets.length, 0);
});

test("visual x normal gives all hets", () => {
  const o = calc.cross([t("clown", "double")], []);
  assert.equal(o.length, 1); assert.equal(o[0].fullName, "Normal het Clown");
});

test("visual x het", () => {
  const o = calc.cross([t("pied", "double")], [t("pied", "single")]);
  close(find("Piebald", o).probability, 0.5);
  assert.equal(find("Normal", o).fullName, "Normal het Piebald");
});

test("incomplete dominant", () => {
  const o = calc.cross([t("pastel", "single")], [t("pastel", "single")]);
  close(find("Super Pastel", o).probability, 0.25);
  close(find("Pastel", o).probability, 0.5);
  close(find("Normal", o).probability, 0.25);
});

test("super x normal", () => {
  assert.deepEqual(calc.cross([t("pastel", "double")], []).map((o) => o.name), ["Pastel"]);
});

test("allelic compound", () => {
  const o = calc.cross([t("lesser", "single")], [t("mojave", "single")]);
  assert.equal(o.length, 4);
  for (const name of ["Blue Eyed Leucistic", "Lesser", "Mojave", "Normal"]) close(find(name, o).probability, 0.25, name);
});

test("allelic snake can carry only two", () => {
  assert.throws(() => calc.validate([t("lesser", "single"), t("mojave", "single"), t("butter", "single")]));
  calc.validate([t("lesser", "single"), t("mojave", "single")]);
  assert.throws(() => calc.validate([t("lesser", "double"), t("mojave", "single")]));
});

test("possible het parent", () => {
  const o = calc.cross([t("albino", "possibleHet", 0.5)], [t("albino", "single")]);
  close(find("Albino", o).probability, 0.125);
  close(find("Normal", o).probability, 0.875);
});

test("independent loci", () => {
  const o = calc.cross([t("pastel", "single"), t("clown", "single")], [t("clown", "double")]);
  assert.equal(o.length, 4);
  for (const name of ["Clown Pastel", "Pastel", "Clown", "Normal"]) close(find(name, o).probability, 0.25, name);
  assert.equal(find("Pastel", o).hetsDescription, "het Clown");
  close(o.reduce((s, x) => s + x.probability, 0), 1);
});

test("triple het sums to one", () => {
  const p = [t("albino", "single"), t("clown", "single"), t("pied", "single")];
  const o = calc.cross(p, p);
  assert.equal(o.length, 8);
  close(find("Albino Clown Piebald", o).probability, 1 / 64);
  close(o.reduce((s, x) => s + x.probability, 0), 1);
});

test("warnings and expression", () => {
  const o = calc.cross([t("spider", "single")], []);
  assert.ok(find("Spider", o).warnings.length > 0);
  close(calc.probabilityOfExpressing("bp.spider", [t("spider", "single")], []), 0.5);
});

test("describe", () => {
  const traits = [t("pied", "possibleHet", 2 / 3), t("clown", "single"), t("pastel", "single"), t("enchi", "single")];
  assert.equal(describe(traits, calc.genes), "Enchi Pastel het Clown 66% poss het Piebald");
  assert.equal(describe([], calc.genes), "Normal");
});

test("percent formatting", () => {
  assert.equal(Percent.format(0.25), "25%");
  assert.equal(Percent.format(0.0625), "6.25%");
  assert.equal(Percent.format(1 / 64), "1.56%");
  assert.equal(Percent.floor(2 / 3), "66%");
});

test("gene ids are unique", () => {
  const ids = BUILT_IN_GENES.map((g) => g.id);
  assert.equal(ids.length, new Set(ids).size);
});
