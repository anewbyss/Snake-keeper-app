import Foundation

public enum GeneticsError: Error, LocalizedError, Equatable {
    case unknownGene(String)
    case tooManyAlleles(genes: [String])

    public var errorDescription: String? {
        switch self {
        case .unknownGene(let id):
            return "Unknown gene \"\(id)\". It may have been deleted."
        case .tooManyAlleles(let genes):
            return "\(genes.joined(separator: ", ")) are allelic (same locus). A snake can only carry two copies in total there."
        }
    }
}

/// The two alleles a snake has at one locus. `GeneticsCalculator.wildType` stands for a normal allele.
public struct LocusGenotype: Hashable, Sendable {
    public let first: String
    public let second: String

    public init(_ a: String, _ b: String) {
        if a <= b {
            first = a
            second = b
        } else {
            first = b
            second = a
        }
    }

    var alleles: [String] { [first, second] }
}

/// The odds that a group of offspring carries a hidden recessive gene.
public struct HetProbability: Hashable, Sendable {
    public let geneID: String
    public let geneName: String
    public let probability: Double

    public var isProven: Bool { probability >= 0.995 }

    public var label: String {
        isProven ? "het \(geneName)" : "\(Percent.floor(probability)) poss het \(geneName)"
    }
}

/// One visually distinct group of offspring.
public struct CrossOutcome: Identifiable, Hashable, Sendable {
    public let visualTraits: [String]
    /// Ids of genes the outcome visually expresses (including compound / super forms).
    public let expressedGeneIDs: Set<String>
    public let probability: Double
    public let hets: [HetProbability]
    public let warnings: [String]

    public var id: String { name }

    public var name: String {
        visualTraits.isEmpty ? "Normal" : visualTraits.joined(separator: " ")
    }

    public var hetsDescription: String {
        hets.map(\.label).joined(separator: ", ")
    }

    /// Full description, e.g. "Pastel Clown 50% poss het Pied".
    public var fullName: String {
        hets.isEmpty ? name : "\(name) \(hetsDescription)"
    }

    /// Expected count in a clutch of `size` eggs.
    public func expected(inClutchOf size: Int) -> Double {
        probability * Double(size)
    }
}

/// Punnett-square calculator that handles any number of genes, allelic genes (e.g. the BEL complex)
/// and unproven "possible het" parents.
public struct GeneticsCalculator: Sendable {
    public static let wildType = "+"

    public let genes: [String: Gene]
    public let compoundNames: [String: String]

    public init(genes: [Gene], compoundNames: [String: String] = GeneLibrary.compoundNames) {
        var byID: [String: Gene] = [:]
        for gene in genes { byID[gene.id] = gene }
        self.genes = byID
        self.compoundNames = compoundNames
    }

    /// Every possible genotype of a parent, per locus, with its probability.
    public func genotypeDistribution(for traits: [TraitEntry]) throws -> [String: [LocusGenotype: Double]] {
        // Lists of non-wild alleles at each locus with their probabilities.
        var allelesByLocus: [String: [[String]: Double]] = [:]
        var genesByLocus: [String: [String]] = [:]

        for trait in traits {
            guard let gene = genes[trait.geneID] else { throw GeneticsError.unknownGene(trait.geneID) }
            let contribution: [[String]: Double]
            switch trait.zygosity {
            case .single:
                contribution = [[gene.id]: 1]
            case .double:
                contribution = [[gene.id, gene.id]: 1]
            case .possibleHet(let p):
                let p = min(max(p, 0), 1)
                contribution = [[gene.id]: p, []: 1 - p]
            }

            let current = allelesByLocus[gene.locus] ?? [[]: 1]
            var combined: [[String]: Double] = [:]
            for (existing, pExisting) in current {
                for (added, pAdded) in contribution where pExisting * pAdded > 0 {
                    combined[existing + added, default: 0] += pExisting * pAdded
                }
            }
            allelesByLocus[gene.locus] = combined
            genesByLocus[gene.locus, default: []].append(gene.name)
        }

        var result: [String: [LocusGenotype: Double]] = [:]
        for (locus, distribution) in allelesByLocus {
            var genotypes: [LocusGenotype: Double] = [:]
            for (alleles, p) in distribution {
                guard alleles.count <= 2 else {
                    throw GeneticsError.tooManyAlleles(genes: genesByLocus[locus] ?? [])
                }
                let padded = alleles + Array(repeating: Self.wildType, count: 2 - alleles.count)
                genotypes[LocusGenotype(padded[0], padded[1]), default: 0] += p
            }
            result[locus] = genotypes
        }
        return result
    }

    /// Throws if the traits can't describe a real snake.
    public func validate(_ traits: [TraitEntry]) throws {
        _ = try genotypeDistribution(for: traits)
    }

    /// Offspring outcomes of breeding two snakes, most likely first.
    public func cross(_ parent1: [TraitEntry], _ parent2: [TraitEntry]) throws -> [CrossOutcome] {
        let first = try genotypeDistribution(for: parent1)
        let second = try genotypeDistribution(for: parent2)
        let normal = [LocusGenotype(Self.wildType, Self.wildType): 1.0]
        let loci = Set(first.keys).union(second.keys).sorted()

        var states: [PhenotypeState: Double] = [PhenotypeState(): 1]
        for locus in loci {
            var offspring: [LocusGenotype: Double] = [:]
            for (g1, p1) in first[locus] ?? normal {
                for (g2, p2) in second[locus] ?? normal {
                    for a in g1.alleles {
                        for b in g2.alleles {
                            offspring[LocusGenotype(a, b), default: 0] += p1 * p2 * 0.25
                        }
                    }
                }
            }

            var locusStates: [PhenotypeState: Double] = [:]
            for (genotype, p) in offspring {
                locusStates[phenotype(of: genotype), default: 0] += p
            }

            var next: [PhenotypeState: Double] = [:]
            for (state, pState) in states {
                for (locusState, pLocus) in locusStates {
                    next[state.merged(with: locusState), default: 0] += pState * pLocus
                }
            }
            states = next
        }

        // Group by what the babies look like, and work out het odds within each group.
        struct Group {
            var probability = 0.0
            var expressed: Set<String> = []
            var carried: [String: Double] = [:]
            var warnings: Set<String> = []
        }
        var groups: [Set<String>: Group] = [:]
        for (state, p) in states where p > 1e-12 {
            var group = groups[state.visuals] ?? Group()
            group.probability += p
            group.expressed.formUnion(state.expressed)
            group.warnings.formUnion(state.warnings)
            for geneID in state.carried {
                group.carried[geneID, default: 0] += p
            }
            groups[state.visuals] = group
        }

        return groups.map { visuals, group in
            let hets = group.carried
                .map { geneID, p in
                    HetProbability(
                        geneID: geneID,
                        geneName: genes[geneID]?.name ?? geneID,
                        probability: p / group.probability
                    )
                }
                .sorted { ($0.isProven ? 0 : 1, $0.geneName) < ($1.isProven ? 0 : 1, $1.geneName) }
            return CrossOutcome(
                visualTraits: visuals.sorted(),
                expressedGeneIDs: group.expressed,
                probability: group.probability,
                hets: hets,
                warnings: group.warnings.sorted()
            )
        }
        .sorted { $0.probability != $1.probability ? $0.probability > $1.probability : $0.name < $1.name }
    }

    /// Probability that offspring visually express `geneID` (alone or as part of a combo / super form).
    public func probability(ofExpressing geneID: String, _ parent1: [TraitEntry], _ parent2: [TraitEntry]) throws -> Double {
        try cross(parent1, parent2)
            .filter { $0.expressedGeneIDs.contains(geneID) }
            .reduce(0) { $0 + $1.probability }
    }

    // MARK: - Phenotype

    struct PhenotypeState: Hashable {
        var visuals: Set<String> = []
        var expressed: Set<String> = []
        var carried: Set<String> = []
        var warnings: Set<String> = []

        func merged(with other: PhenotypeState) -> PhenotypeState {
            PhenotypeState(
                visuals: visuals.union(other.visuals),
                expressed: expressed.union(other.expressed),
                carried: carried.union(other.carried),
                warnings: warnings.union(other.warnings)
            )
        }
    }

    func phenotype(of genotype: LocusGenotype) -> PhenotypeState {
        let present = genotype.alleles.filter { $0 != Self.wildType }.compactMap { genes[$0] }
        var state = PhenotypeState()

        func express(_ gene: Gene, homozygous: Bool = false) {
            state.expressed.insert(gene.id)
            if let warning = gene.warning { state.warnings.insert("\(gene.name): \(warning)") }
            if homozygous, let warning = gene.homozygousWarning {
                state.warnings.insert("\(gene.homozygousName): \(warning)")
            }
        }

        switch present.count {
        case 1:
            let gene = present[0]
            if gene.inheritance == .recessive {
                state.carried.insert(gene.id)
            } else {
                state.visuals.insert(gene.name)
                express(gene)
            }
        case 2 where present[0].id == present[1].id:
            let gene = present[0]
            state.visuals.insert(gene.homozygousName)
            express(gene, homozygous: true)
        case 2:
            let a = present[0], b = present[1]
            if let compound = compoundNames[GeneLibrary.compoundKey(a.id, b.id)] {
                state.visuals.insert(compound)
                express(a)
                express(b)
                break
            }
            switch (a.inheritance == .recessive, b.inheritance == .recessive) {
            case (true, true):
                // Two different recessive alleles at one locus express together.
                state.visuals.insert([a.name, b.name].sorted().joined(separator: "/"))
                express(a)
                express(b)
            case (true, false):
                state.visuals.insert(b.name)
                state.carried.insert(a.id)
                express(b)
            case (false, true):
                state.visuals.insert(a.name)
                state.carried.insert(b.id)
                express(a)
            case (false, false):
                state.visuals.insert(a.name)
                state.visuals.insert(b.name)
                express(a)
                express(b)
            }
        default:
            break
        }
        return state
    }
}
