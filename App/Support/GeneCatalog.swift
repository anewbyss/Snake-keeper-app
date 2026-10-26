import Foundation
import SnakeGenetics

/// Built-in genes plus the user's custom genes.
struct GeneCatalog {
    static let otherSpecies = "Other"

    let genes: [Gene]
    let byID: [String: Gene]
    private let customSpecies: [String: String]

    init(custom: [CustomGene] = []) {
        let customGenes = custom.map(\.gene)
        genes = GeneLibrary.allGenes + customGenes
        var byID: [String: Gene] = [:]
        for gene in genes { byID[gene.id] = gene }
        self.byID = byID
        var customSpecies: [String: String] = [:]
        for gene in custom { customSpecies[gene.geneID] = gene.species }
        self.customSpecies = customSpecies
    }

    var calculator: GeneticsCalculator {
        GeneticsCalculator(genes: genes)
    }

    /// Built-in species names, any species only used by custom genes, then "Other".
    var speciesNames: [String] {
        let builtIn = GeneLibrary.species.map(\.name)
        let extra = Set(customSpecies.values).subtracting(builtIn).subtracting([Self.otherSpecies]).sorted()
        return builtIn + extra + [Self.otherSpecies]
    }

    func genes(for species: String) -> [Gene] {
        let builtIn = GeneLibrary.speciesInfo(named: species)?.genes ?? []
        let custom = genes.filter { customSpecies[$0.id] == species }
        return (builtIn + custom).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func gene(_ id: String) -> Gene? { byID[id] }

    func describe(_ traits: [TraitEntry]) -> String {
        GeneLibrary.describe(traits, genes: byID)
    }

    func cross(_ a: [TraitEntry], _ b: [TraitEntry]) -> Result<[CrossOutcome], Error> {
        Result { try calculator.cross(a, b) }
    }

    static func incubationDays(for species: String) -> Int? {
        GeneLibrary.speciesInfo(named: species)?.incubationDays ?? (species.isEmpty ? nil : 60)
    }
}
