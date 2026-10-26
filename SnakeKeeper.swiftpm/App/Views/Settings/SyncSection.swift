import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Export / import the sync file shared with the SnakeKeeper web app. Place inside a `List`.
struct SyncSection: View {
    @Environment(\.modelContext) private var context

    @State private var shareItems: ShareItems?
    @State private var importing = false
    @State private var message: String?

    var body: some View {
        Section {
            Button {
                exportFile()
            } label: {
                Label("Export Sync File", systemImage: "square.and.arrow.up")
            }
            Button {
                importing = true
            } label: {
                Label("Import & Merge Sync File", systemImage: "square.and.arrow.down")
            }
            if let message {
                Text(message).font(.footnote).foregroundStyle(.secondary)
            }
        } header: {
            Text("Sync with the Web App")
        } footer: {
            Text("Export here and import in the other SnakeKeeper app (or the other way round). Records are matched, and the newest version of each one wins, so you can sync in either direction as often as you like. Includes photos.")
        }
        .sheet(item: $shareItems) { items in
            ActivityView(items: items.urls)
                .presentationDetents([.medium, .large])
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                importFile(url)
            case .failure(let error):
                message = "Import failed: \(error.localizedDescription)"
            }
        }
    }

    private func exportFile() {
        do {
            context.saveNow()
            let data = try SyncService.export(from: context)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("SnakeKeeper Sync \(formatter.string(from: .now)).json")
            try data.write(to: url, options: .atomic)
            message = nil
            shareItems = ShareItems(urls: [url])
        } catch {
            message = "Export failed: \(error.localizedDescription)"
        }
    }

    private func importFile(_ url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            context.saveNow()
            let data = try Data(contentsOf: url)
            let summary = try SyncService.merge(data, into: context)
            message = "Synced: \(summary.description)"
        } catch {
            message = error.localizedDescription
        }
    }
}
