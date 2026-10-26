import Foundation

public struct Species: Identifiable, Hashable, Sendable {
    public let name: String
    public let scientificName: String
    /// Typical egg incubation in days at ~88–89°F; `nil` for live-bearers.
    public let incubationDays: Int?
    public let genes: [Gene]

    public var id: String { name }
}

/// Built-in morph genes for common species. Users can add their own genes in the app.
///
/// Health notes are the commonly reported issues in the hobby, not veterinary advice.
public enum GeneLibrary {
    public static let species: [Species] = [ballPython, cornSnake, hognose, boa]

    public static var allGenes: [Gene] { species.flatMap(\.genes) }

    public static func speciesInfo(named name: String) -> Species? {
        species.first { $0.name == name }
    }

    public static func compoundKey(_ a: String, _ b: String) -> String {
        [a, b].sorted().joined(separator: "|")
    }

    /// Names for two different allelic genes together, keyed by `compoundKey`.
    public static let compoundNames: [String: String] = {
        var names: [String: String] = [:]
        let bel = ["bp.lesser", "bp.butter", "bp.mojave", "bp.russo"]
        for a in bel {
            for b in bel where a < b {
                names[GeneLibrary.compoundKey(a, b)] = "Blue Eyed Leucistic"
            }
        }
        names[GeneLibrary.compoundKey("bp.mojave", "bp.phantom")] = "Purple Passion"
        names[GeneLibrary.compoundKey("bp.mojave", "bp.mystic")] = "Mystic Potion"
        names[GeneLibrary.compoundKey("bp.yellowbelly", "bp.gravel")] = "Highway"
        names[GeneLibrary.compoundKey("bp.yellowbelly", "bp.asphalt")] = "Freeway"
        names[GeneLibrary.compoundKey("corn.amel", "corn.ultra")] = "Ultramel"
        return names
    }()

    /// Morph name for a set of traits, e.g. "Pastel Enchi het Clown 66% poss het Pied".
    public static func describe(_ traits: [TraitEntry], genes: [String: Gene]) -> String {
        var visuals: [String] = []
        var hets: [String] = []
        var possibles: [String] = []
        for trait in traits {
            guard let gene = genes[trait.geneID] else { continue }
            let label = gene.label(for: trait.zygosity)
            switch (gene.inheritance, trait.zygosity) {
            case (.recessive, .single): hets.append(label)
            case (_, .possibleHet): possibles.append(label)
            default: visuals.append(label)
            }
        }
        let parts = visuals.sorted() + hets.sorted() + possibles.sorted()
        return parts.isEmpty ? "Normal" : parts.joined(separator: " ")
    }

    // MARK: - Ball python

    static let ballPython = Species(
        name: "Ball Python",
        scientificName: "Python regius",
        incubationDays: 56,
        genes: [
            rec("bp", "Albino"),
            rec("bp", "Axanthic (VPI)", id: "axanthic"),
            rec("bp", "Candy", locus: "candino"),
            rec("bp", "Caramel Albino", id: "caramel", warning: "kinking and fertility issues reported"),
            rec("bp", "Clown"),
            rec("bp", "Desert Ghost", warning: "females often reported to have reproductive issues"),
            rec("bp", "Genetic Stripe", id: "geneticstripe"),
            rec("bp", "Ghost (Hypo)", id: "ghost"),
            rec("bp", "Lavender Albino", id: "lavender"),
            rec("bp", "Monarch"),
            rec("bp", "Monsoon"),
            rec("bp", "Piebald", id: "pied"),
            rec("bp", "Puzzle"),
            rec("bp", "Sunset"),
            rec("bp", "Toffee", locus: "candino"),
            rec("bp", "Tri-Stripe", id: "tristripe"),
            rec("bp", "Ultramel"),

            inc("bp", "Asphalt", locus: "yb"),
            inc("bp", "Banana", superName: "Super Banana", warning: "sex-linked: watch for male/female maker effects"),
            inc("bp", "Black Pastel", id: "blackpastel", homozygousWarning: "may show kinking or duckbill"),
            inc("bp", "Butter", locus: "bel", superName: "Blue Eyed Leucistic"),
            inc("bp", "Cinnamon", homozygousWarning: "may show kinking or duckbill"),
            inc("bp", "Enchi"),
            inc("bp", "Fire", superName: "Black Eyed Leucistic"),
            inc("bp", "GHI"),
            inc("bp", "Gravel", locus: "yb"),
            inc("bp", "Leopard"),
            inc("bp", "Lesser", locus: "bel", superName: "Blue Eyed Leucistic"),
            inc("bp", "Mojave", locus: "bel", superName: "Blue Eyed Leucistic"),
            inc("bp", "Mystic", locus: "bel"),
            inc("bp", "Orange Dream", id: "orangedream"),
            inc("bp", "Pastel", superName: "Super Pastel"),
            inc("bp", "Phantom", locus: "bel"),
            inc("bp", "Russo", locus: "bel", superName: "Blue Eyed Leucistic"),
            inc("bp", "Sable", homozygousWarning: "Super Sable is linked to kinking and eye issues"),
            inc("bp", "Spotnose"),
            inc("bp", "Vanilla"),
            inc("bp", "Yellow Belly", id: "yellowbelly", locus: "yb", superName: "Ivory"),

            dom("bp", "Calico"),
            dom("bp", "Champagne", warning: "neurological wobble reported"),
            dom("bp", "Hidden Gene Woma (HGW)", id: "hgw", warning: "neurological wobble reported"),
            dom("bp", "Pinstripe"),
            dom("bp", "Spider", warning: "neurological wobble in essentially all Spiders"),
            dom("bp", "Woma", warning: "neurological wobble reported"),
        ]
    )

    // MARK: - Corn snake

    static let cornSnake = Species(
        name: "Corn Snake",
        scientificName: "Pantherophis guttatus",
        incubationDays: 60,
        genes: [
            rec("corn", "Amelanistic", id: "amel", locus: "amel"),
            rec("corn", "Anerythristic", id: "anery"),
            rec("corn", "Caramel"),
            rec("corn", "Charcoal"),
            rec("corn", "Cinder"),
            rec("corn", "Diffused (Bloodred)", id: "diffused"),
            rec("corn", "Hypomelanistic", id: "hypo"),
            rec("corn", "Kastanie"),
            rec("corn", "Lava"),
            rec("corn", "Lavender"),
            rec("corn", "Motley", locus: "motley"),
            rec("corn", "Palmetto"),
            rec("corn", "Stripe", locus: "motley"),
            rec("corn", "Sunkissed"),
            rec("corn", "Ultra", locus: "amel"),
            dom("corn", "Tessera"),
        ]
    )

    // MARK: - Western hognose

    static let hognose = Species(
        name: "Western Hognose",
        scientificName: "Heterodon nasicus",
        incubationDays: 55,
        genes: [
            rec("hog", "Albino"),
            rec("hog", "Axanthic"),
            rec("hog", "Lavender"),
            rec("hog", "Pink Pastel", id: "pinkpastel"),
            rec("hog", "Toffeebelly"),
            inc("hog", "Anaconda", superName: "Superconda"),
            inc("hog", "Arctic", superName: "Super Arctic"),
        ]
    )

    // MARK: - Boa

    static let boa = Species(
        name: "Boa Constrictor",
        scientificName: "Boa imperator / constrictor",
        incubationDays: nil,
        genes: [
            rec("boa", "Anery"),
            rec("boa", "Kahl Albino", id: "kahl"),
            rec("boa", "Sharp Albino", id: "sharp"),
            rec("boa", "VPI T+ Albino", id: "tplus"),
            inc("boa", "Arabesque"),
            inc("boa", "Hypo", superName: "Super Hypo"),
            inc("boa", "IMG"),
            inc("boa", "Jungle"),
            inc("boa", "Leopard"),
            inc("boa", "Motley"),
        ]
    )

    // MARK: - Helpers

    private static func makeID(_ prefix: String, _ name: String, _ id: String?) -> String {
        "\(prefix).\(id ?? name.lowercased().filter { $0.isLetter || $0.isNumber })"
    }

    private static func rec(_ prefix: String, _ name: String, id: String? = nil, locus: String? = nil,
                            warning: String? = nil) -> Gene {
        let geneID = makeID(prefix, name, id)
        return Gene(id: geneID, name: name, inheritance: .recessive,
                    locus: locus.map { "\(prefix).\($0)" }, warning: warning)
    }

    private static func inc(_ prefix: String, _ name: String, id: String? = nil, locus: String? = nil,
                            superName: String? = nil, warning: String? = nil,
                            homozygousWarning: String? = nil) -> Gene {
        let geneID = makeID(prefix, name, id)
        return Gene(id: geneID, name: name, inheritance: .incompleteDominant,
                    locus: locus.map { "\(prefix).\($0)" }, superName: superName,
                    warning: warning, homozygousWarning: homozygousWarning)
    }

    private static func dom(_ prefix: String, _ name: String, id: String? = nil, warning: String? = nil) -> Gene {
        let geneID = makeID(prefix, name, id)
        return Gene(id: geneID, name: name, inheritance: .dominant, warning: warning)
    }
}
