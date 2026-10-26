import Foundation
import SwiftData
import SnakeGenetics

enum Sex: String, CaseIterable, Identifiable, Codable {
    case male, female, unknown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .unknown: return "Unsexed"
        }
    }

    var symbol: String {
        switch self {
        case .male: return "♂"
        case .female: return "♀"
        case .unknown: return "?"
        }
    }

    var opposite: Sex? {
        switch self {
        case .male: return .female
        case .female: return .male
        case .unknown: return nil
        }
    }
}

enum Origin: String, CaseIterable, Identifiable, Codable {
    case homeBred, purchased, traded, rescue, wildCaught, other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .homeBred: return "Bred by me"
        case .purchased: return "Purchased"
        case .traded: return "Traded"
        case .rescue: return "Rescue / rehome"
        case .wildCaught: return "Wild caught / import"
        case .other: return "Other"
        }
    }

    /// Hint for the free-text details field.
    var detailsPrompt: String {
        switch self {
        case .homeBred: return "Clutch / parents"
        case .purchased, .traded: return "Breeder or seller"
        case .rescue: return "Previous owner / organization"
        case .wildCaught: return "Locality / importer"
        case .other: return "Details"
        }
    }
}

enum FeedingStatus {
    case noRecord, fed, due, overdue
}

@Model
final class Snake {
    var id: UUID = UUID()
    var name: String = ""
    var species: String = ""
    var sexRaw: String = Sex.unknown.rawValue
    var hatchDate: Date?
    var hatchDateIsEstimate: Bool = false
    var originRaw: String = Origin.purchased.rawValue
    var originDetails: String = ""
    var acquiredDate: Date?
    var weightGrams: Double?
    var feedingIntervalDays: Int = 7
    /// JSON-encoded `[TraitEntry]`.
    var traitsData: Data = Data()
    var notes: String = ""
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \FeedingRecord.snake)
    var feedings: [FeedingRecord] = []

    @Relationship(deleteRule: .cascade, inverse: \SnakePhoto.snake)
    var photos: [SnakePhoto] = []

    @Relationship(deleteRule: .cascade, inverse: \Concern.snake)
    var concerns: [Concern] = []

    @Relationship(deleteRule: .nullify, inverse: \Pairing.male)
    var pairingsAsSire: [Pairing] = []

    @Relationship(deleteRule: .nullify, inverse: \Pairing.female)
    var pairingsAsDam: [Pairing] = []

    init(name: String, species: String, sex: Sex) {
        self.name = name
        self.species = species
        self.sexRaw = sex.rawValue
    }

    var sex: Sex {
        get { Sex(rawValue: sexRaw) ?? .unknown }
        set { sexRaw = newValue.rawValue }
    }

    var origin: Origin {
        get { Origin(rawValue: originRaw) ?? .other }
        set { originRaw = newValue.rawValue }
    }

    var traits: [TraitEntry] {
        get { (try? JSONDecoder().decode([TraitEntry].self, from: traitsData)) ?? [] }
        set { traitsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    // MARK: Feeding

    var lastMeal: FeedingRecord? {
        feedings.filter { !$0.refused }.max { $0.date < $1.date }
    }

    var daysSinceLastMeal: Int? {
        lastMeal.map { Date.daysBetween($0.date, .now) }
    }

    var nextFeedingDate: Date? {
        lastMeal.flatMap { Calendar.current.date(byAdding: .day, value: feedingIntervalDays, to: $0.date) }
    }

    var feedingStatus: FeedingStatus {
        guard let days = daysSinceLastMeal else { return .noRecord }
        if days > feedingIntervalDays + max(2, feedingIntervalDays / 2) { return .overdue }
        if days >= feedingIntervalDays { return .due }
        return .fed
    }

    /// Consecutive refusals since the last accepted meal.
    var refusalStreak: Int {
        var streak = 0
        for record in feedings.sorted(by: { $0.date > $1.date }) {
            guard record.refused else { break }
            streak += 1
        }
        return streak
    }

    // MARK: Other

    var openConcerns: [Concern] {
        concerns.filter { !$0.isResolved }.sorted { $0.dateNoted > $1.dateNoted }
    }

    var coverPhoto: SnakePhoto? {
        photos.first(where: \.isCover) ?? photos.max { $0.dateTaken < $1.dateTaken }
    }

    var pairings: [Pairing] {
        (pairingsAsSire + pairingsAsDam).sorted { $0.createdAt > $1.createdAt }
    }

    var ageDescription: String? {
        guard let hatchDate else { return nil }
        let text = Date.ageString(from: hatchDate)
        return hatchDateIsEstimate ? "~\(text)" : text
    }
}
