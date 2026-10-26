import SwiftUI
import SwiftData
import SnakeGenetics

/// Export data, browse the built-in gene library and manage custom genes.
struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \CustomGene.name) private var customGenes: [CustomGene]
    @State private var showingNew = false
    @State private var editing: CustomGene?

    var body: some View {
        NavigationStack {
            List {
                ExportSection()

                Section {
                    ForEach(customGenes) { gene in
                        Button { editing = gene } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(gene.name).foregroundStyle(.primary)
                                Text("\(gene.species) · \(gene.inheritance.displayName)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets { context.delete(customGenes[index]) }
                    }
                    Button { showingNew = true } label: {
                        Label("Add Custom Gene", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Custom Genes")
                } footer: {
                    Text("Add morphs that aren't built in, or genes for other species. Snakes using a deleted gene will show it as unknown.")
                }

                Section("Built-in Library") {
                    ForEach(GeneLibrary.species) { species in
                        NavigationLink {
                            GeneLibraryView(species: species)
                        } label: {
                            LabeledContent(species.name, value: "\(species.genes.count) genes")
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingNew) {
                NavigationStack { CustomGeneEditView(gene: nil) }
            }
            .sheet(item: $editing) { gene in
                NavigationStack { CustomGeneEditView(gene: gene) }
            }
        }
    }
}

struct GeneLibraryView: View {
    let species: Species

    var body: some View {
        List {
            ForEach(Inheritance.allCases) { inheritance in
                let genes = species.genes.filter { $0.inheritance == inheritance }
                if !genes.isEmpty {
                    Section(inheritance.displayName) {
                        ForEach(genes) { gene in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(gene.name)
                                if inheritance != .recessive {
                                    Text("Two copies: \(gene.homozygousName)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                let allelic = species.genes.filter { $0.locus == gene.locus && $0.id != gene.id }
                                if !allelic.isEmpty {
                                    Text("Allelic with \(allelic.map(\.name).joined(separator: ", "))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                ForEach([gene.warning, gene.homozygousWarning].compactMap { $0 }, id: \.self) { warning in
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
        .navigationTitle(species.name)
    }
}

struct CustomGeneEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var customGenes: [CustomGene]

    let gene: CustomGene?

    @State private var name: String
    @State private var species: String
    @State private var inheritance: Inheritance
    @State private var superName: String
    @State private var locus: String
    @State private var warning: String
    @State private var newSpecies = ""

    init(gene: CustomGene?) {
        self.gene = gene
        _name = State(initialValue: gene?.name ?? "")
        _species = State(initialValue: gene?.species ?? GeneLibrary.species[0].name)
        _inheritance = State(initialValue: gene?.inheritance ?? .recessive)
        _superName = State(initialValue: gene?.superName ?? "")
        _locus = State(initialValue: gene?.locus ?? "")
        _warning = State(initialValue: gene?.warning ?? "")
    }

    private var catalog: GeneCatalog { GeneCatalog(custom: customGenes) }

    private var allelicCandidates: [Gene] {
        catalog.genes(for: species).filter { $0.id != gene?.geneID }
    }

    var body: some View {
        Form {
            Section {
                TextField("Gene name", text: $name)
                Picker("Species", selection: $species) {
                    ForEach(catalog.speciesNames, id: \.self) { Text($0).tag($0) }
                }
                if species == GeneCatalog.otherSpecies {
                    TextField("Species name (e.g. Kingsnake)", text: $newSpecies)
                }
                Picker("Inheritance", selection: $inheritance) {
                    ForEach(Inheritance.allCases) { Text($0.displayName).tag($0) }
                }
                if inheritance != .recessive {
                    TextField("Two-copy name (default: Super \(name.isEmpty ? "…" : name))", text: $superName)
                }
            }
            Section {
                Picker("Allelic with", selection: $locus) {
                    Text("None (own locus)").tag("")
                    ForEach(allelicCandidates) { Text($0.name).tag($0.locus) }
                }
            } footer: {
                Text("Pick a gene this one shares a locus with, like Lesser and Mojave. Leave as None if unsure.")
            }
            Section("Health note") {
                TextField("e.g. wobble, kinking", text: $warning, axis: .vertical)
            }
        }
        .navigationTitle(gene == nil ? "New Gene" : "Edit Gene")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save).disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func save() {
        let target: CustomGene
        if let gene {
            target = gene
        } else {
            target = CustomGene(name: name, species: species, inheritance: inheritance)
            context.insert(target)
        }
        let trimmedSpecies = newSpecies.trimmingCharacters(in: .whitespaces)
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.species = species == GeneCatalog.otherSpecies && !trimmedSpecies.isEmpty ? trimmedSpecies : species
        target.inheritance = inheritance
        target.superName = inheritance == .recessive ? "" : superName.trimmingCharacters(in: .whitespaces)
        target.locus = locus
        target.warning = warning.trimmingCharacters(in: .whitespaces)
        dismiss()
    }
}
