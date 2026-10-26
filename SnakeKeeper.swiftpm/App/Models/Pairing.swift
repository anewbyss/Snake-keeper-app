import Foundation
import SwiftData

enum PairingStatus: String, CaseIterable, Identifiable {
    case planned = "Planned"
    case introduced = "Introduced"
    case locked = "Locks observed"
    case ovulated = "Ovulated"
    case preLayShed = "Pre-lay shed"
    case laid = "Eggs laid / born"
    case hatched = "Hatched"
    case unsuccessful = "Unsuccessful"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .planned: return "calendar"
        case .introduced: return "arrow.triangle.merge"
        case .locked: return "link"
        case .ovulated: return "circle.dashed"
        case .preLayShed: return "sparkles"
        case .laid: return "oval.portrait"
        case .hatched: return "party.popper"
        case .unsuccessful: return "xmark.circle"
        }
    }

    var isActive: Bool { self != .hatched && self != .unsuccessful }
}

@Model
final class Pairing {
    var id: UUID = UUID()
    var female: Snake?
    var male: Snake?
    var season: Int = 0
    var statusRaw: String = PairingStatus.planned.rawValue
    var introducedDate: Date?
    var lockCount: Int = 0
    var lastLockDate: Date?
    var ovulationDate: Date?
    var preLayShedDate: Date?
    var layDate: Date?
    var eggCount: Int?
    var fertileEggCount: Int?
    var hatchDate: Date?
    var notes: String = ""
    var createdAt: Date = Date()

    init(female: Snake?, male: Snake?, season: Int) {
        self.female = female
        self.male = male
        self.season = season
    }

    var status: PairingStatus {
        get { PairingStatus(rawValue: statusRaw) ?? .planned }
        set { statusRaw = newValue.rawValue }
    }

    var title: String {
        "\(female?.name ?? "?") × \(male?.name ?? "?")"
    }

    var species: String {
        female?.species ?? male?.species ?? ""
    }

    /// Estimated hatch date from the lay date and the species' typical incubation.
    var estimatedHatchDate: Date? {
        guard let layDate, let days = GeneCatalog.incubationDays(for: species) else { return nil }
        return Calendar.current.date(byAdding: .day, value: days, to: layDate)
    }

    /// Ball python rule of thumb: eggs ~30 days after the pre-lay shed.
    var estimatedLayDate: Date? {
        guard layDate == nil, let preLayShedDate else { return nil }
        return Calendar.current.date(byAdding: .day, value: 30, to: preLayShedDate)
    }
}
