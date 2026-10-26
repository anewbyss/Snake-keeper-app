import Foundation
import SwiftData
import Observation

/// Owns the on-disk store and saves explicitly.
///
/// SwiftData's autosave runs on a timer, and Swift Playgrounds kills the app instantly when it is
/// stopped or closed, so unsaved edits were lost. Every edit now calls `context.saveNow()`.
@Observable
final class Persistence {
    static let shared = Persistence()

    let container: ModelContainer
    private(set) var lastSaved: Date?
    private(set) var lastError: String?
    /// True when the store couldn't be opened and data is only kept in memory.
    private(set) var isTemporary = false

    static let schema = Schema([
        Snake.self,
        FeedingRecord.self,
        SnakePhoto.self,
        Concern.self,
        Pairing.self,
        CustomGene.self,
        DeletedRecord.self,
    ])

    static var storeURL: URL {
        URL.documentsDirectory.appending(path: "SnakeKeeper.store")
    }

    private init() {
        Self.migrateDefaultStoreIfNeeded()
        do {
            container = try ModelContainer(for: Self.schema, configurations: ModelConfiguration(url: Self.storeURL))
        } catch {
            // Keep the app usable, and say loudly that nothing will be kept.
            container = try! ModelContainer(for: Self.schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            isTemporary = true
            lastError = "Couldn't open saved data: \(error.localizedDescription)"
        }
    }

    /// Saves pending changes. Unless `stamp` is false (sync merges), edited records get a fresh
    /// `updatedAt` and deletions are remembered so they can be synced.
    func save(_ context: ModelContext, stamp: Bool = true) {
        guard context.hasChanges else { return }
        if stamp {
            let now = Date()
            for model in context.insertedModelsArray + context.changedModelsArray {
                (model as? any Syncable)?.updatedAt = now
            }
            for model in context.deletedModelsArray {
                guard let record = model as? any Syncable else { continue }
                context.insert(DeletedRecord(recordID: record.id.uuidString,
                                             type: type(of: record).syncType, deletedAt: now))
            }
        }
        do {
            try context.save()
            lastSaved = .now
            if !isTemporary { lastError = nil }
        } catch {
            lastError = "Save failed: \(error.localizedDescription)"
        }
    }

    var storeSize: Int64 {
        let directory = Self.storeURL.deletingLastPathComponent()
        let prefix = Self.storeURL.lastPathComponent
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        return files
            .filter { $0.lastPathComponent.hasPrefix(prefix) }
            .compactMap { try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize }
            .reduce(0) { $0 + Int64($1) }
    }

    /// Earlier versions used SwiftData's default location; copy it once so nothing is stranded.
    private static func migrateDefaultStoreIfNeeded() {
        let fileManager = FileManager.default
        let old = URL.applicationSupportDirectory.appending(path: "default.store")
        guard !fileManager.fileExists(atPath: storeURL.path(percentEncoded: false)),
              fileManager.fileExists(atPath: old.path(percentEncoded: false)) else { return }
        for suffix in ["", "-wal", "-shm"] {
            let source = URL(fileURLWithPath: old.path(percentEncoded: false) + suffix)
            let destination = URL(fileURLWithPath: storeURL.path(percentEncoded: false) + suffix)
            if fileManager.fileExists(atPath: source.path(percentEncoded: false)) {
                try? fileManager.copyItem(at: source, to: destination)
            }
        }
    }
}

extension ModelContext {
    /// Writes pending changes to disk immediately.
    func saveNow() {
        Persistence.shared.save(self)
    }
}
