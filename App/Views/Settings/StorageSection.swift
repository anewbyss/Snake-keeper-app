import SwiftUI
import SwiftData

/// Shows what's saved on the device so it's easy to confirm data survives a restart.
struct StorageSection: View {
    @Environment(\.modelContext) private var context
    @Query private var snakes: [Snake]
    @Query private var feedings: [FeedingRecord]
    @Query private var logs: [LogEntry]
    @Query private var photos: [SnakePhoto]
    @Query private var pairings: [Pairing]

    private let persistence = Persistence.shared

    var body: some View {
        Section {
            LabeledContent("Snakes", value: "\(snakes.count)")
            LabeledContent("Feedings", value: "\(feedings.count)")
            LabeledContent("Care log entries", value: "\(logs.count)")
            LabeledContent("Photos", value: "\(photos.count)")
            LabeledContent("Pairings", value: "\(pairings.count)")
            LabeledContent("On disk", value: persistence.isTemporary
                           ? "Not saved (memory only)"
                           : ByteCountFormatter.string(fromByteCount: persistence.storeSize, countStyle: .file))
            if let lastSaved = persistence.lastSaved {
                LabeledContent("Last saved", value: lastSaved.formatted(date: .omitted, time: .standard))
            }
            if let error = persistence.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
            Button {
                context.saveNow()
            } label: {
                Label("Save Now", systemImage: "square.and.arrow.down")
            }
        } header: {
            Text("Storage")
        } footer: {
            Text("Everything is saved on this device as soon as you make a change. Deleting Swift Playgrounds or this project deletes the data, so export a backup now and then.")
        }
    }
}
