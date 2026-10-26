import Foundation
import SwiftData
import SnakeGenetics

/// A gene the user adds for morphs that aren't in the built-in library.
@Model
final class CustomGene {
    var id: UUID = UUID()
    var name: String = ""
    var species: String = ""
    var inheritanceRaw: String = Inheritance.recessive.rawValue
    var superName: String = ""
    /// Locus shared with an allelic gene; empty means its own locus.
    var locus: String = ""
    var warning: String = ""

    init(name: String, species: String, inheritance: Inheritance) {
        self.name = name
        self.species = species
        self.inheritanceRaw = inheritance.rawValue
    }

    var inheritance: Inheritance {
        get { Inheritance(rawValue: inheritanceRaw) ?? .recessive }
        set { inheritanceRaw = newValue.rawValue }
    }

    var geneID: String { "custom.\(id.uuidString)" }

    var gene: Gene {
        Gene(
            id: geneID,
            name: name,
            inheritance: inheritance,
            locus: locus.isEmpty ? nil : locus,
            superName: superName.isEmpty ? nil : superName,
            warning: warning.isEmpty ? nil : warning
        )
    }
}
