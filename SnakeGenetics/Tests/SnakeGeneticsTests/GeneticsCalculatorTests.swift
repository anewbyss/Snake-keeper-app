import XCTest
@testable import SnakeGenetics

final class GeneticsCalculatorTests: XCTestCase {
    let calculator = GeneticsCalculator(genes: GeneLibrary.allGenes)

    private func t(_ id: String, _ zygosity: Zygosity) -> TraitEntry {
        TraitEntry(geneID: "bp.\(id)", zygosity: zygosity)
    }

    private func outcome(_ name: String, in outcomes: [CrossOutcome]) -> CrossOutcome? {
        outcomes.first { $0.name == name }
    }

    func testNormalByNormal() throws {
        let outcomes = try calculator.cross([], [])
        XCTAssertEqual(outcomes.count, 1)
        XCTAssertEqual(outcomes[0].name, "Normal")
        XCTAssertEqual(outcomes[0].probability, 1, accuracy: 1e-9)
    }

    func testHetByHetRecessive() throws {
        let outcomes = try calculator.cross([t("albino", .single)], [t("albino", .single)])
        XCTAssertEqual(outcomes.count, 2)
        let normal = try XCTUnwrap(outcome("Normal", in: outcomes))
        XCTAssertEqual(normal.probability, 0.75, accuracy: 1e-9)
        XCTAssertEqual(normal.hets.first?.probability ?? 0, 2.0 / 3.0, accuracy: 1e-9)
        XCTAssertEqual(normal.hetsDescription, "66% poss het Albino")
        let albino = try XCTUnwrap(outcome("Albino", in: outcomes))
        XCTAssertEqual(albino.probability, 0.25, accuracy: 1e-9)
        XCTAssertTrue(albino.hets.isEmpty)
    }

    func testVisualByNormalGivesAllHets() throws {
        let outcomes = try calculator.cross([t("clown", .double)], [])
        XCTAssertEqual(outcomes.count, 1)
        XCTAssertEqual(outcomes[0].fullName, "Normal het Clown")
    }

    func testVisualByHet() throws {
        let outcomes = try calculator.cross([t("pied", .double)], [t("pied", .single)])
        XCTAssertEqual(outcome("Piebald", in: outcomes)?.probability ?? 0, 0.5, accuracy: 1e-9)
        XCTAssertEqual(outcome("Normal", in: outcomes)?.fullName, "Normal het Piebald")
    }

    func testIncompleteDominant() throws {
        let outcomes = try calculator.cross([t("pastel", .single)], [t("pastel", .single)])
        XCTAssertEqual(outcome("Super Pastel", in: outcomes)?.probability ?? 0, 0.25, accuracy: 1e-9)
        XCTAssertEqual(outcome("Pastel", in: outcomes)?.probability ?? 0, 0.5, accuracy: 1e-9)
        XCTAssertEqual(outcome("Normal", in: outcomes)?.probability ?? 0, 0.25, accuracy: 1e-9)
    }

    func testSuperByNormalIsAllSingle() throws {
        let outcomes = try calculator.cross([t("pastel", .double)], [])
        XCTAssertEqual(outcomes.map(\.name), ["Pastel"])
    }

    func testAllelicGenesFormCompound() throws {
        let outcomes = try calculator.cross([t("lesser", .single)], [t("mojave", .single)])
        XCTAssertEqual(outcomes.count, 4)
        for name in ["Blue Eyed Leucistic", "Lesser", "Mojave", "Normal"] {
            XCTAssertEqual(outcome(name, in: outcomes)?.probability ?? 0, 0.25, accuracy: 1e-9, name)
        }
    }

    func testAllelicSnakeCanCarryOnlyTwo() {
        XCTAssertThrowsError(try calculator.validate([t("lesser", .single), t("mojave", .single), t("butter", .single)]))
        XCTAssertNoThrow(try calculator.validate([t("lesser", .single), t("mojave", .single)]))
        XCTAssertThrowsError(try calculator.validate([t("lesser", .double), t("mojave", .single)]))
    }

    func testPossibleHetParent() throws {
        // 50% poss het × het: albino odds = 0.5 × 0.25
        let outcomes = try calculator.cross([t("albino", .possibleHet(0.5))], [t("albino", .single)])
        XCTAssertEqual(outcome("Albino", in: outcomes)?.probability ?? 0, 0.125, accuracy: 1e-9)
        XCTAssertEqual(outcome("Normal", in: outcomes)?.probability ?? 0, 0.875, accuracy: 1e-9)
    }

    func testIndependentLoci() throws {
        // Pastel het Clown × Clown
        let outcomes = try calculator.cross(
            [t("pastel", .single), t("clown", .single)],
            [t("clown", .double)]
        )
        XCTAssertEqual(outcomes.count, 4)
        for name in ["Clown Pastel", "Pastel", "Clown", "Normal"] {
            XCTAssertEqual(outcome(name, in: outcomes)?.probability ?? 0, 0.25, accuracy: 1e-9, name)
        }
        XCTAssertEqual(outcome("Pastel", in: outcomes)?.hetsDescription, "het Clown")
        XCTAssertEqual(outcomes.reduce(0) { $0 + $1.probability }, 1, accuracy: 1e-9)
    }

    func testTripleHetSumsToOne() throws {
        let parent = [t("albino", .single), t("clown", .single), t("pied", .single)]
        let outcomes = try calculator.cross(parent, parent)
        XCTAssertEqual(outcomes.count, 8)
        XCTAssertEqual(outcome("Albino Clown Piebald", in: outcomes)?.probability ?? 0, 1.0 / 64, accuracy: 1e-9)
        XCTAssertEqual(outcomes.reduce(0) { $0 + $1.probability }, 1, accuracy: 1e-9)
    }

    func testWarningsAndExpression() throws {
        let outcomes = try calculator.cross([t("spider", .single)], [])
        let spider = try XCTUnwrap(outcome("Spider", in: outcomes))
        XCTAssertFalse(spider.warnings.isEmpty)
        XCTAssertEqual(try calculator.probability(ofExpressing: "bp.spider", [t("spider", .single)], []), 0.5, accuracy: 1e-9)
    }

    func testDescribe() {
        let genes = calculator.genes
        let traits = [t("pied", .possibleHet(2.0 / 3.0)), t("clown", .single), t("pastel", .single), t("enchi", .single)]
        XCTAssertEqual(GeneLibrary.describe(traits, genes: genes), "Enchi Pastel het Clown 66% poss het Piebald")
        XCTAssertEqual(GeneLibrary.describe([], genes: genes), "Normal")
    }

    func testPercentFormatting() {
        XCTAssertEqual(Percent.format(0.25), "25%")
        XCTAssertEqual(Percent.format(0.0625), "6.25%")
        XCTAssertEqual(Percent.format(1.0 / 64), "1.56%")
        XCTAssertEqual(Percent.floor(2.0 / 3.0), "66%")
    }

    func testGeneIDsAreUnique() {
        let ids = GeneLibrary.allGenes.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }
}

final class BatchGeneChangeTests: XCTestCase {
    let calculator = GeneticsCalculator(genes: GeneLibrary.allGenes)

    func testSetAddsOrChangesCopies() {
        let change = BatchGeneChange.set(geneID: "bp.clown", zygosity: .single)
        XCTAssertEqual(change.apply(to: [])?.map(\.geneID), ["bp.clown"])
        XCTAssertNil(change.apply(to: [TraitEntry(geneID: "bp.clown", zygosity: .single)]))
        let visual = BatchGeneChange.set(geneID: "bp.clown", zygosity: .double)
        XCTAssertEqual(visual.apply(to: [TraitEntry(geneID: "bp.clown", zygosity: .single)])?.first?.zygosity, .double)
    }

    func testRemove() {
        let change = BatchGeneChange.remove(geneID: "bp.pastel")
        XCTAssertEqual(change.apply(to: [TraitEntry(geneID: "bp.pastel", zygosity: .single)])?.count, 0)
        XCTAssertNil(change.apply(to: []))
    }

    func testInvalidResultIsCaughtByValidation() throws {
        let traits = [TraitEntry(geneID: "bp.lesser", zygosity: .single), TraitEntry(geneID: "bp.mojave", zygosity: .single)]
        let result = try XCTUnwrap(BatchGeneChange.set(geneID: "bp.butter", zygosity: .single).apply(to: traits))
        XCTAssertThrowsError(try calculator.validate(result))
    }
}

final class GrowthTests: XCTestCase {
    let bp = GrowthGuide.guide(for: "Ball Python")!
    private func day(_ d: Int) -> Date { Date(timeIntervalSince1970: Double(d) * 86400) }

    func testStages() {
        XCTAssertEqual(bp.stage(for: 90)?.label, "Hatchling")
        XCTAssertEqual(bp.stage(for: 200)?.label, "Juvenile")
        XCTAssertEqual(bp.stage(for: 2000)?.label, "Adult")
    }

    func testReferenceInterpolates() throws {
        let range = try XCTUnwrap(bp.reference(atMonths: 9))
        XCTAssertEqual(range.lowerBound, 300, accuracy: 1e-6)
        XCTAssertEqual(range.upperBound, 650, accuracy: 1e-6)
        XCTAssertNil(bp.reference(atMonths: 60))
        XCTAssertEqual(Growth.compare(250, to: range), .below)
        XCTAssertEqual(Growth.compare(500, to: range), .within)
    }

    func testRate() {
        let w = [Weighing(date: day(0), grams: 100), Weighing(date: day(14), grams: 120), Weighing(date: day(28), grams: 140)]
        XCTAssertEqual(Growth.rate(w) ?? 0, 10, accuracy: 1e-6)
        XCTAssertNil(Growth.rate([Weighing(date: day(0), grams: 100), Weighing(date: day(4), grams: 110)]))
    }

    func testPreyAndWeeks() {
        let prey = Growth.preyRange(for: 1000, guide: bp)
        XCTAssertEqual(prey?.lowerBound ?? 0, 100, accuracy: 1e-6)
        XCTAssertEqual(Growth.weeksToTarget(current: 1000, target: 1500, ratePerWeek: 25), 20)
        XCTAssertEqual(Growth.weeksToTarget(current: 1600, target: 1500, ratePerWeek: 25), 0)
        XCTAssertNil(Growth.weeksToTarget(current: 1000, target: 1500, ratePerWeek: 0))
    }

    func testEveryGuideMatchesASpecies() {
        for guide in GrowthGuide.all {
            XCTAssertNotNil(GeneLibrary.speciesInfo(named: guide.species), guide.species)
        }
    }
}
