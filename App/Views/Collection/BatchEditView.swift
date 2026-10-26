import SwiftUI
import SwiftData
import SnakeGenetics

/// Change a gene and/or the status of several snakes at once.
struct BatchEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var customGenes: [CustomGene]

    let snakes: [Snake]
    /// Called once a change has been saved (the selection is cleared when the sheet closes).
    let onApplied: () -> Void

    enum Mode: String, CaseIterable, Identifiable {
        case set = "Add / set", remove = "Remove"
        var id: String { rawValue }
    }

    @State private var geneID: String?
    @State private var mode = Mode.set
    @State private var zygosity = Zygosity.single
    @State private var status: SnakeStatus?
    @State private var result: String?

    private var catalog: GeneCatalog { GeneCatalog(custom: customGenes) }

    /// Only genes every selected species can carry.
    private var genes: [Gene] {
        let species = Set(snakes.map(\.species))
        guard let first = species.first else { return [] }
        let others = species.subtracting([first]).map { Set(catalog.genes(for: $0).map(\.id)) }
        return catalog.genes(for: first).filter { gene in others.allSatisfy { $0.contains(gene.id) } }
    }

    private var selectedGene: Gene? { geneID.flatMap { catalog.gene($0) } }

    var body: some View {
        Form {
            Section {
                Text(snakes.map(\.name).sorted().joined(separator: ", "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section {
                if genes.isEmpty {
                    Text(Set(snakes.map(\.species)).count > 1
                         ? "The selected snakes are different species with no genes in common."
                         : "No genes for this species. Add custom genes in Settings.")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Gene", selection: $geneID) {
                        Text("Don't change genes").tag(String?.none)
                        ForEach(genes) { Text($0.name).tag(String?.some($0.id)) }
                    }
                    if geneID != nil {
                        Picker("Action", selection: $mode) {
                            ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        if mode == .set, let gene = selectedGene {
                            Picker("Copies", selection: $zygosity) {
                                ForEach(gene.zygosityOptions, id: \.self) { Text(gene.zygosityName($0)).tag($0) }
                            }
                        }
                    }
                }
            } header: {
                Text("Gene")
            } footer: {
                Text("Snakes the change would make impossible (e.g. a third gene at the same locus) are skipped and listed.")
            }
            Section("Status") {
                Picker("Status", selection: $status) {
                    Text("Don't change").tag(SnakeStatus?.none)
                    ForEach(SnakeStatus.allCases) { Text($0.displayName).tag(SnakeStatus?.some($0)) }
                }
            }
            if let result {
                Section { Text(result).foregroundStyle(.secondary) }
            }
        }
        .navigationTitle("Edit \(snakes.count) Snake\(snakes.count == 1 ? "" : "s")")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: geneID) { _, _ in
            zygosity = .single
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button(result == nil ? "Cancel" : "Done") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Apply", action: apply).disabled(geneID == nil && status == nil)
            }
        }
    }

    private func apply() {
        let change: BatchGeneChange? = geneID.map { id in
            mode == .set ? .set(geneID: id, zygosity: zygosity) : .remove(geneID: id)
        }
        let calculator = catalog.calculator
        var updated = 0
        var skipped: [String] = []
        for snake in snakes {
            var changed = false
            if let change, let traits = change.apply(to: snake.traits) {
                guard (try? calculator.validate(traits)) != nil else {
                    skipped.append(snake.name)
                    continue
                }
                snake.traits = traits
                changed = true
            }
            if let status, snake.status != status {
                snake.status = status
                changed = true
            }
            if changed { updated += 1 }
        }
        context.saveNow()
        onApplied()
        if skipped.isEmpty {
            dismiss()
        } else {
            // Stay open so the skipped names can be read.
            result = "Updated \(updated). Skipped \(skipped.joined(separator: ", ")): the gene would exceed two copies at one locus."
            geneID = nil
            status = nil
        }
    }
}

/// The SnakeKeeper snake, drawn in code so it needs no image assets.
struct SnakeGlyph: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            var body = Path()
            let steps = 60
            for i in 0...steps {
                let t = Double(i) / Double(steps)
                let point = CGPoint(x: w * (0.12 + t * 0.62), y: h * (0.5 + sin(t * .pi * 2.2 + 0.3) * 0.17))
                if i == 0 { body.move(to: point) } else { body.addLine(to: point) }
            }
            let line = max(w, h) * 0.11
            context.stroke(body, with: .color(Color(red: 0.96, green: 0.83, blue: 0.37)),
                           style: StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round))
            let head = CGPoint(x: w * 0.74, y: h * (0.5 + sin(.pi * 2.2 + 0.3) * 0.17))
            context.fill(Path(ellipseIn: CGRect(x: head.x - line * 0.75, y: head.y - line * 0.65,
                                                width: line * 1.6, height: line * 1.3)),
                         with: .color(Color(red: 0.96, green: 0.83, blue: 0.37)))
            context.fill(Path(ellipseIn: CGRect(x: head.x + line * 0.05, y: head.y - line * 0.4,
                                                width: line * 0.32, height: line * 0.32)),
                         with: .color(.black))
            var tongue = Path()
            tongue.move(to: CGPoint(x: head.x + line * 0.85, y: head.y))
            tongue.addLine(to: CGPoint(x: head.x + line * 1.4, y: head.y))
            tongue.move(to: CGPoint(x: head.x + line * 1.3, y: head.y))
            tongue.addLine(to: CGPoint(x: head.x + line * 1.6, y: head.y - line * 0.25))
            tongue.move(to: CGPoint(x: head.x + line * 1.3, y: head.y))
            tongue.addLine(to: CGPoint(x: head.x + line * 1.6, y: head.y + line * 0.25))
            context.stroke(tongue, with: .color(.red), lineWidth: line * 0.14)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
