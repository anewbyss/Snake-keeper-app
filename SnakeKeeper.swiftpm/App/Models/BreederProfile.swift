import Foundation
import SwiftData

/// The breeder's own details and app defaults. There is one per device; it syncs (newest wins).
@Model
final class BreederProfile {
    var name: String = ""
    var business: String = ""
    var location: String = ""
    var email: String = ""
    var phone: String = ""
    var website: String = ""
    var social: String = ""
    @Attribute(.externalStorage) var photoData: Data?
    var defaultSpecies: String = "Ball Python"
    var defaultFeedingInterval: Int = 7
    var notes: String = ""
    /// Last edit, for sync.
    var updatedAt: Date = Date()

    init() {}

    /// "Scale Tales Reptiles" / "Alex Smith" / "".
    var displayName: String {
        business.isEmpty ? name : business
    }

    /// The profile, created on first use.
    static func current(in context: ModelContext) -> BreederProfile {
        if let existing = try? context.fetch(FetchDescriptor<BreederProfile>()).first { return existing }
        let profile = BreederProfile()
        context.insert(profile)
        return profile
    }
}

extension BreederProfile: Timestamped {}
