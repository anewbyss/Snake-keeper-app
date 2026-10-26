import SwiftUI

/// Rows for editing a snake's genes. Place inside a `Section`.
struct TraitsEditor: View {
    @Binding var traits: [TraitEntry]
    let species: String
    let catalog: GeneCatalog

    @State private var showingPicker = false

    private var validationError: String? {
        do {
            try catalog.calculator.validate(traits)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    var body: some View {
        ForEach($traits) { $trait in
            if let gene = catalog.gene(trait.geneID) {
                TraitRow(gene: gene, zygosity: $trait.zygosity)
            } else {
                Text("Unknown gene (deleted?)").foregroundStyle(.secondary)
            }
        }
        .onDelete { traits.remove(atOffsets: $0) }

        if let validationError {
            Label(validationError, systemImage: "exclamationmark.triangle.fill")
                .font(.footnote)
                .foregroundStyle(.red)
        }

        Button { showingPicker = true } label: {
            Label(traits.isEmpty ? "Add Gene (Normal if none)" : "Add Gene", systemImage: "plus.circle")
        }
        .sheet(isPresented: $showingPicker) {
            GenePickerView(
                genes: catalog.genes(for: species),
                excluded: Set(traits.map(\.geneID))
            ) { gene in
                traits.append(TraitEntry(geneID: gene.id, zygosity: .single))
            }
        }
    }
}

struct TraitRow: View {
    let gene: Gene
    @Binding var zygosity: Zygosity

    private var options: [Zygosity] {
        gene.zygosityOptions.contains(zygosity) ? gene.zygosityOptions : gene.zygosityOptions + [zygosity]
    }

    var body: some View {
        Picker(selection: $zygosity) {
            ForEach(options, id: \.self) { option in
                Text(gene.zygosityName(option)).tag(option)
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(gene.name)
                Text(gene.inheritance.displayName).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct GenePickerView: View {
    @Environment(\.dismiss) private var dismiss
    let genes: [Gene]
    let excluded: Set<String>
    let onPick: (Gene) -> Void

    @State private var search = ""

    private func matches(_ inheritance: Inheritance) -> [Gene] {
        genes.filter {
            $0.inheritance == inheritance && !excluded.contains($0.id)
                && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(Inheritance.allCases) { inheritance in
                    let list = matches(inheritance)
                    if !list.isEmpty {
                        Section(inheritance.displayName) {
                            ForEach(list) { gene in
                                Button {
                                    onPick(gene)
                                    dismiss()
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(gene.name).foregroundStyle(.primary)
                                        if let warning = gene.warning {
                                            Label(warning, systemImage: "exclamationmark.triangle")
                                                .font(.caption)
                                                .foregroundStyle(.orange)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .overlay {
                if genes.isEmpty {
                    ContentUnavailableView(
                        "No genes for this species",
                        systemImage: "square.grid.3x3",
                        description: Text("Add custom genes in the Settings tab.")
                    )
                }
            }
            .searchable(text: $search)
            .navigationTitle("Add Gene")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}
