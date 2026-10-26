import Foundation
import SwiftData

/// A model that takes part in sync (see Support/SyncFile.swift).
protocol Syncable: PersistentModel {
    var id: UUID { get set }
    var updatedAt: Date { get set }
    /// Collection name in the sync file, shared with the web app.
    static var syncType: String { get }
}

/// Remembers a deletion so it can be passed on when syncing ("tombstone").
@Model
final class DeletedRecord {
    var recordID: String = ""
    var type: String = ""
    var deletedAt: Date = Date()

    init(recordID: String, type: String, deletedAt: Date) {
        self.recordID = recordID
        self.type = type
        self.deletedAt = deletedAt
    }
}
