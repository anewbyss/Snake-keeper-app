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
