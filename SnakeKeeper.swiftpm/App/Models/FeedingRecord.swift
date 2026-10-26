import Foundation
import SwiftData

enum PreyType: String, CaseIterable, Identifiable {
    case mouse = "Mouse", rat = "Rat", asf = "ASF", gerbil = "Gerbil", chick = "Chick",
         quail = "Quail", rabbit = "Rabbit", fish = "Fish", other = "Other"
    var id: String { rawValue }
}

enum PreySize: String, CaseIterable, Identifiable {
    case pinky = "Pinky", fuzzy = "Fuzzy", hopper = "Hopper", weaned = "Weaned",
         small = "Small", medium = "Medium", large = "Large", xLarge = "X-Large", jumbo = "Jumbo"
    var id: String { rawValue }
}

enum PreyState: String, CaseIterable, Identifiable {
    case frozenThawed = "Frozen/thawed", preKilled = "Pre-killed", live = "Live"
    var id: String { rawValue }

    var shortName: String {
        switch self {
        case .frozenThawed: return "F/T"
        case .preKilled: return "P/K"
        case .live: return "Live"
        }
    }
}

@Model
final class FeedingRecord {
    var id: UUID = UUID()
    var date: Date = Date()
    var preyType: String = PreyType.mouse.rawValue
    var preySize: String = PreySize.small.rawValue
    var preyState: String = PreyState.frozenThawed.rawValue
    var preyCount: Int = 1
    var preyWeightGrams: Double?
    var refused: Bool = false
    var notes: String = ""
    var snake: Snake?

    init(date: Date, preyType: String, preySize: String, preyState: String, preyCount: Int = 1,
         preyWeightGrams: Double? = nil, refused: Bool = false, notes: String = "") {
        self.date = date
        self.preyType = preyType
        self.preySize = preySize
        self.preyState = preyState
        self.preyCount = preyCount
        self.preyWeightGrams = preyWeightGrams
        self.refused = refused
        self.notes = notes
    }

    /// e.g. "2× Small Rat (F/T)".
    var summary: String {
        let count = preyCount > 1 ? "\(preyCount)× " : ""
        let state = PreyState(rawValue: preyState)?.shortName ?? preyState
        return "\(count)\(preySize) \(preyType) (\(state))"
    }
}
