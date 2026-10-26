import Foundation
import SwiftData
import SwiftUI

enum ConcernCategory: String, CaseIterable, Identifiable {
    case feeding = "Feeding / refusal"
    case regurgitation = "Regurgitation"
    case shed = "Bad shed"
    case respiratory = "Respiratory"
    case parasites = "Mites / parasites"
    case weight = "Weight loss"
    case injury = "Injury / burn"
    case neurological = "Neurological"
    case scales = "Scale rot / skin"
    case reproductive = "Reproductive"
    case behavior = "Behavior"
    case other = "Other"

    var id: String { rawValue }
}

enum ConcernSeverity: String, CaseIterable, Identifiable {
    case low = "Low", medium = "Medium", high = "High"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .low: return .yellow
        case .medium: return .orange
        case .high: return .red
        }
    }
}

@Model
final class Concern {
    var id: UUID = UUID()
    var title: String = ""
    var details: String = ""
    var category: String = ConcernCategory.other.rawValue
    var severityRaw: String = ConcernSeverity.low.rawValue
    var dateNoted: Date = Date()
    var isResolved: Bool = false
    var resolvedDate: Date?
    var vetVisit: Bool = false
    var snake: Snake?

    init(title: String, category: ConcernCategory = .other, severity: ConcernSeverity = .low, dateNoted: Date = .now) {
        self.title = title
        self.category = category.rawValue
        self.severityRaw = severity.rawValue
        self.dateNoted = dateNoted
    }

    var severity: ConcernSeverity {
        get { ConcernSeverity(rawValue: severityRaw) ?? .low }
        set { severityRaw = newValue.rawValue }
    }
}
