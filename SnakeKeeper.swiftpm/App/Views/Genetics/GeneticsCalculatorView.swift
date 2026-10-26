import SwiftUI
import SwiftData

struct GeneticsCalculatorView: View {
    @Query(sort: \Snake.name) private var snakes: [Snake]
    @Query private var customGenes: [CustomGene]

    @State private var species = GeneLibrary.species[0].name
    @State private var femaleTraits: [TraitEntry] = []
    @State private var maleTraits: [TraitEntry] = []
    @State private var femaleName: String?
    @State private var maleName: String?
    @State private var clutchSize = 6

    private var catalog: GeneCatalog { GeneCatalog(custom: customGenes) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Species", selection: $species) {
                        ForEach(catalog.speciesNames, id: \.self) { Text($0).tag($0) }
                    }
                }

                parentSection(title: "♀ Female", sex: .female, traits: $femaleTraits, name: $femaleName)
                parentSection(title: "♂ Male", sex: .male, traits: $maleTraits, name: $maleName)

                Section {
                    Stepper("Clutch size: \(clutchSize)", value: $clutchSize, in: 1...40)
                    OutcomeList(result: catalog.cross(femaleTraits, maleTraits), clutchSize: clutchSize)
                } header: {
                    Text("Possible Offspring")
                } footer: {
                    Text("Odds are per egg; every egg is an independent roll. Health notes are commonly reported issues, not a diagnosis.")
                }
            }
            .navigationTitle("Genetics")
            .toolbar {
                Button("Reset") {
                    femaleTraits = []
                    maleTraits = []
                    femaleName = nil
                    maleName = nil
                }
            }
            .onChange(of: species) { _, _ in
                femaleTraits = []
                maleTraits = []
                femaleName = nil
                maleName = nil
            }
        }
    }

    private func parentSection(title: String, sex: Sex, traits: Binding<[TraitEntry]>,
                               name: Binding<String?>) -> some View {
        let candidates = snakes.filter { $0.species == species && ($0.sex == sex || $0.sex == .unknown) }
        return Section {
            TraitsEditor(traits: traits, species: species, catalog: catalog)
        } header: {
            HStack {
                Text(name.wrappedValue.map { "\(title): \($0)" } ?? title)
                Spacer()
                if !candidates.isEmpty {
                    Menu("From Collection") {
                        ForEach(candidates) { snake in
                            Button("\(snake.name) — \(catalog.describe(snake.traits))") {
                                traits.wrappedValue = snake.traits
                                name.wrappedValue = snake.name
                            }
                        }
                    }
                    .font(.caption)
                    .textCase(nil)
                }
            }
        } footer: {
            Text(catalog.describe(traits.wrappedValue))
        }
    }
}
