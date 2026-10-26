import Foundation

/// How a gene is passed on and expressed.
public enum Inheritance: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Needs two copies to be visible (e.g. Albino, Clown, Piebald).
    case recessive
    /// Visible with one copy, a different "super" form with two (e.g. Pastel, Mojave). Often called "co-dom".
    case incompleteDominant
    /// Looks the same with one or two copies (e.g. Spider, Pinstripe).
    case dominant

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .recessive: return "Recessive"
        case .incompleteDominant: return "Incomplete Dominant (Co-dom)"
        case .dominant: return "Dominant"
        }
    }

    public var shortName: String {
        switch self {
        case .recessive: return "Rec"
        case .incompleteDominant: return "Inc-Dom"
        case .dominant: return "Dom"
        }
    }
}

/// A single morph gene.
public struct Gene: Hashable, Codable, Identifiable, Sendable {
    /// Stable identifier, e.g. `"bp.pastel"`.
    public var id: String
    public var name: String
    public var inheritance: Inheritance
    /// Genes that share a locus are allelic: a snake can carry at most two of them
    /// (e.g. Lesser and Mojave in the BEL complex). Defaults to the gene's own id.
    public var locus: String
    /// Name of the two-copy form, e.g. "Super Pastel" or "Ivory".
    public var superName: String?
    /// Shown whenever offspring visually express this gene.
    public var warning: String?
    /// Shown when offspring carry two copies.
    public var homozygousWarning: String?

    public init(
        id: String,
        name: String,
        inheritance: Inheritance,
        locus: String? = nil,
        superName: String? = nil,
        warning: String? = nil,
        homozygousWarning: String? = nil
    ) {
        self.id = id
        self.name = name
        self.inheritance = inheritance
        self.locus = locus ?? id
        self.superName = superName
        self.warning = warning
        self.homozygousWarning = homozygousWarning
    }

    /// Display name for a snake carrying two copies.
    public var homozygousName: String {
        if let superName, !superName.isEmpty { return superName }
        switch inheritance {
        case .recessive: return name
        case .incompleteDominant, .dominant: return "Super \(name)"
        }
    }

    /// The zygosity choices that make sense for this gene, for pickers.
    public var zygosityOptions: [Zygosity] {
        switch inheritance {
        case .recessive:
            return [.double, .single, .possibleHet(0.5), .possibleHet(2.0 / 3.0)]
        case .incompleteDominant, .dominant:
            return [.single, .double]
        }
    }

    /// Short label for the zygosity alone, e.g. "Het", "Visual", "Super", "66% Poss Het".
    public func zygosityName(_ zygosity: Zygosity) -> String {
        switch (inheritance, zygosity) {
        case (.recessive, .single): return "Het"
        case (.recessive, .double): return "Visual"
        case (.incompleteDominant, .single): return "Single copy"
        case (.incompleteDominant, .double): return homozygousName
        case (.dominant, .single): return "Visual"
        case (.dominant, .double): return "Homozygous"
        case (_, .possibleHet(let p)): return "\(Percent.floor(p)) Poss Het"
        }
    }

    /// Full label, e.g. "het Clown", "Super Pastel", "66% poss het Pied".
    public func label(for zygosity: Zygosity) -> String {
        switch (inheritance, zygosity) {
        case (.recessive, .single): return "het \(name)"
        case (.recessive, .double): return name
        case (_, .single): return name
        case (_, .double): return homozygousName
        case (.recessive, .possibleHet(let p)): return "\(Percent.floor(p)) poss het \(name)"
        case (_, .possibleHet(let p)): return "\(Percent.floor(p)) poss \(name)"
        }
    }
}

/// How many copies of a gene a snake carries.
public enum Zygosity: Codable, Hashable, Sendable {
    /// One copy: het for recessives, visual for (incomplete) dominants.
    case single
    /// Two copies: visual recessive, super / homozygous form otherwise.
    case double
    /// Unproven: the probability (0...1) that the snake carries one copy.
    case possibleHet(Double)
}

/// One gene on one snake.
public struct TraitEntry: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var geneID: String
    public var zygosity: Zygosity

    public init(id: UUID = UUID(), geneID: String, zygosity: Zygosity) {
        self.id = id
        self.geneID = geneID
        self.zygosity = zygosity
    }
}

public enum Percent {
    /// "25%", "6.25%", "66.67%".
    public static func format(_ probability: Double) -> String {
        let value = probability * 100
        if abs(value - value.rounded()) < 0.005 {
            return "\(Int(value.rounded()))%"
        }
        var text = String(format: "%.2f", value)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text + "%"
    }

    /// Rounded down to a whole percent the way breeders write it: 2/3 → "66%".
    public static func floor(_ probability: Double) -> String {
        "\(Int((probability * 100 + 1e-9).rounded(.down)))%"
    }
}
