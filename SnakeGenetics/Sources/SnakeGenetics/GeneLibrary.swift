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
    /// Ball python first (the default), then alphabetical.
    public static let species: [Species] = [
        ballPython, bloodPython, boa, burmese, kingsnake, carpet, childrens, cornSnake, gartersnake,
        greenTree, kenyanSandBoa, milkSnake, reticulated, rosyBoa, hognose,
    ]

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
            rec("bp", "Axanthic (Jolliff)", id: "axanthicjolliff"),
            rec("bp", "Axanthic (MJ)", id: "axanthicmj"),
            rec("bp", "Axanthic (TSK)", id: "axanthictsk"),
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
            rec("bp", "Rainbow"),
            rec("bp", "Sunset"),
            rec("bp", "Toffee", locus: "candino"),
            rec("bp", "Tri-Stripe", id: "tristripe"),
            rec("bp", "Ultramel"),

            inc("bp", "Acid"),
            inc("bp", "Arroyo"),
            inc("bp", "Asphalt", locus: "yb"),
            inc("bp", "Bamboo"),
            inc("bp", "Banana (Coral Glow)", id: "banana", superName: "Super Banana",
                warning: "sex-linked: watch for male/female maker effects"),
            inc("bp", "Black Pastel", id: "blackpastel", homozygousWarning: "may show kinking or duckbill"),
            inc("bp", "Blade"),
            inc("bp", "Bongo"),
            inc("bp", "Butter", locus: "bel", superName: "Blue Eyed Leucistic"),
            inc("bp", "Chocolate"),
            inc("bp", "Cinnamon", homozygousWarning: "may show kinking or duckbill"),
            inc("bp", "Cryptic"),
            inc("bp", "Cypress"),
            inc("bp", "Disco"),
            inc("bp", "Enchi"),
            inc("bp", "Enhancer"),
            inc("bp", "Fader"),
            inc("bp", "Fire", superName: "Black Eyed Leucistic"),
            inc("bp", "GHI"),
            inc("bp", "Granite"),
            inc("bp", "Gravel", locus: "yb"),
            inc("bp", "Huffman"),
            inc("bp", "Hurricane"),
            inc("bp", "Leopard"),
            inc("bp", "Lesser", locus: "bel", superName: "Blue Eyed Leucistic"),
            inc("bp", "Lori"),
            inc("bp", "Mahogany"),
            inc("bp", "Mocha"),
            inc("bp", "Mojave", locus: "bel", superName: "Blue Eyed Leucistic"),
            inc("bp", "Mystic", locus: "bel"),
            inc("bp", "Orange Belly", id: "orangebelly"),
            inc("bp", "Orange Dream", id: "orangedream"),
            inc("bp", "Pastel", superName: "Super Pastel"),
            inc("bp", "Phantom", locus: "bel"),
            inc("bp", "Red Stripe", id: "redstripe"),
            inc("bp", "Rhino"),
            inc("bp", "Russo", locus: "bel", superName: "Blue Eyed Leucistic"),
            inc("bp", "Sable", homozygousWarning: "Super Sable is linked to kinking and eye issues"),
            inc("bp", "Special", locus: "bel"),
            inc("bp", "Specter"),
            inc("bp", "Spotnose"),
            inc("bp", "Static"),
            inc("bp", "Sugar"),
            inc("bp", "Trick"),
            inc("bp", "Vanilla"),
            inc("bp", "Woma", warning: "neurological wobble reported",
                homozygousWarning: "Super Woma is rarely if ever produced and is thought to be lethal"),
            inc("bp", "Yellow Belly", id: "yellowbelly", locus: "yb", superName: "Ivory"),

            dom("bp", "Calico"),
            dom("bp", "Champagne", warning: "neurological wobble reported"),
            dom("bp", "Hidden Gene Woma (HGW)", id: "hgw", warning: "neurological wobble reported"),
            dom("bp", "Pinstripe"),
            dom("bp", "Spider", warning: "neurological wobble in essentially all Spiders"),
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
            rec("corn", "Dilute"),
            rec("corn", "Hypomelanistic", id: "hypo"),
            rec("corn", "Kastanie"),
            rec("corn", "Lava"),
            rec("corn", "Lavender"),
            rec("corn", "Microscale"),
            rec("corn", "Motley", locus: "motley"),
            rec("corn", "Palmetto"),
            rec("corn", "Scaleless"),
            rec("corn", "Stripe", locus: "motley"),
            rec("corn", "Sunkissed"),
            rec("corn", "Toffee"),
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
            rec("hog", "Evans Hypo", id: "evanshypo"),
            rec("hog", "Lavender"),
            rec("hog", "Lemon Ghost", id: "lemonghost"),
            rec("hog", "Pink Pastel", id: "pinkpastel"),
            rec("hog", "Sable"),
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

    // MARK: - Burmese python

    static let burmese = Species(
        name: "Burmese Python",
        scientificName: "Python bivittatus",
        incubationDays: 60,
        genes: [
            rec("burm", "Albino"),
            rec("burm", "Caramel"),
            rec("burm", "Granite"),
            rec("burm", "Green (Patternless)", id: "green"),
            rec("burm", "Labyrinth"),
        ]
    )

    // MARK: - California kingsnake

    static let kingsnake = Species(
        name: "California Kingsnake",
        scientificName: "Lampropeltis californiae",
        incubationDays: 60,
        genes: [
            rec("king", "Albino"),
            rec("king", "Banana"),
            rec("king", "Hypomelanistic", id: "hypo"),
            rec("king", "Lavender"),
        ]
    )

    // MARK: - Carpet python

    static let carpet = Species(
        name: "Carpet Python",
        scientificName: "Morelia spilota",
        incubationDays: 55,
        genes: [
            rec("carpet", "Albino"),
            rec("carpet", "Axanthic"),
            inc("carpet", "Jaguar", warning: "neurological issues (head tremors) reported",
                homozygousWarning: "Super Jaguar (leucistic) is reported to be non-viable"),
        ]
    )

    // MARK: - Kenyan sand boa

    static let kenyanSandBoa = Species(
        name: "Kenyan Sand Boa",
        scientificName: "Eryx colubrinus",
        incubationDays: nil,
        genes: [
            rec("ksb", "Albino"),
            rec("ksb", "Anerythristic", id: "anery"),
            rec("ksb", "Splash"),
        ]
    )

    // MARK: - Milk snake

    static let milkSnake = Species(
        name: "Milk Snake",
        scientificName: "Lampropeltis triangulum complex",
        incubationDays: 60,
        genes: [
            rec("milk", "Albino"),
            rec("milk", "Anerythristic", id: "anery"),
            rec("milk", "Hypomelanistic", id: "hypo"),
        ]
    )

    // MARK: - Reticulated python

    static let reticulated = Species(
        name: "Reticulated Python",
        scientificName: "Malayopython reticulatus",
        incubationDays: 88,
        genes: [
            rec("retic", "Albino"),
            rec("retic", "Anerythristic", id: "anery"),
            rec("retic", "Genetic Stripe", id: "geneticstripe"),
            inc("retic", "Golden Child", id: "goldenchild"),
            inc("retic", "Motley"),
            inc("retic", "Platinum"),
            inc("retic", "Sunfire"),
            inc("retic", "Tiger", superName: "Super Tiger"),
            inc("retic", "Titanium"),
        ]
    )

    // MARK: - Species tracked without a gene library (add custom genes as needed)

    static let bloodPython = Species(name: "Blood Python", scientificName: "Python brongersmai", incubationDays: 75, genes: [
        ]
    )

    static let childrens = Species(name: "Children's Python", scientificName: "Antaresia childreni", incubationDays: 55, genes: [
        ]
    )

    static let gartersnake = Species(name: "Garter Snake", scientificName: "Thamnophis spp.", incubationDays: nil, genes: [
        ]
    )

    static let greenTree = Species(name: "Green Tree Python", scientificName: "Morelia viridis", incubationDays: 50, genes: [
        ]
    )

    static let rosyBoa = Species(name: "Rosy Boa", scientificName: "Lichanura spp.", incubationDays: nil, genes: [
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
