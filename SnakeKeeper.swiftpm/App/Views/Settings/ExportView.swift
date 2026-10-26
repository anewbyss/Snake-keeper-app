import SwiftUI
import SwiftData

/// Export rows for the Settings screen. Place inside a `List`.
struct ExportSection: View {
    @Query private var snakes: [Snake]
    @Query private var pairings: [Pairing]
    @Query private var customGenes: [CustomGene]

    @State private var shareItems: ShareItems?
    @State private var errorMessage: String?

    private var export: SpreadsheetExport {
        SpreadsheetExport(snakes: snakes, pairings: pairings, catalog: GeneCatalog(custom: customGenes))
    }

    var body: some View {
        Section {
            Button {
                run { [try export.writeWorkbook()] }
            } label: {
                Label("Excel Workbook (.xlsx)", systemImage: "tablecells")
            }
            Button {
                run { try export.writeCSVs() }
            } label: {
                Label("CSV Files", systemImage: "doc.plaintext")
            }
            if let errorMessage {
                Text(errorMessage).font(.footnote).foregroundStyle(.red)
            }
        } header: {
            Text("Export")
        } footer: {
            Text("The workbook has Snakes, Feedings, Concerns and Pairings tabs. Open it in Excel or Numbers, or in Google Sheets: share to the Sheets app, or save to Google Drive and open it from there.")
        }
        .disabled(snakes.isEmpty && pairings.isEmpty)
        .sheet(item: $shareItems) { items in
            ActivityView(items: items.urls)
                .presentationDetents([.medium, .large])
        }
    }

    private func run(_ makeFiles: () throws -> [URL]) {
        do {
            errorMessage = nil
            shareItems = ShareItems(urls: try makeFiles())
        } catch {
            errorMessage = "Export failed: \(error.localizedDescription)"
        }
    }
}

struct ShareItems: Identifiable {
    let id = UUID()
    let urls: [URL]
}

/// The system share sheet (Save to Files, AirDrop, Mail, Excel, Sheets…).
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
