import SwiftUI
import SwiftData

struct SnakeEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var customGenes: [CustomGene]

    let snake: Snake?

    @State private var name: String
    @State private var species: String
    @State private var sex: Sex
    @State private var hasHatchDate: Bool
    @State private var hatchDate: Date
    @State private var hatchDateIsEstimate: Bool
    @State private var origin: Origin
    @State private var originDetails: String
    @State private var hasAcquiredDate: Bool
    @State private var acquiredDate: Date
    @State private var weightGrams: Double?
    @State private var feedingIntervalDays: Int
    @State private var traits: [TraitEntry]
    @State private var notes: String

    init(snake: Snake?) {
        self.snake = snake
        _name = State(initialValue: snake?.name ?? "")
        _species = State(initialValue: snake?.species ?? GeneLibrary.species[0].name)
        _sex = State(initialValue: snake?.sex ?? .unknown)
        _hasHatchDate = State(initialValue: snake?.hatchDate != nil)
        _hatchDate = State(initialValue: snake?.hatchDate ?? .now)
        _hatchDateIsEstimate = State(initialValue: snake?.hatchDateIsEstimate ?? false)
        _origin = State(initialValue: snake?.origin ?? .purchased)
        _originDetails = State(initialValue: snake?.originDetails ?? "")
        _hasAcquiredDate = State(initialValue: snake?.acquiredDate != nil)
        _acquiredDate = State(initialValue: snake?.acquiredDate ?? .now)
        _weightGrams = State(initialValue: snake?.weightGrams)
        _feedingIntervalDays = State(initialValue: snake?.feedingIntervalDays ?? 7)
        _traits = State(initialValue: snake?.traits ?? [])
        _notes = State(initialValue: snake?.notes ?? "")
    }

    private var catalog: GeneCatalog { GeneCatalog(custom: customGenes) }

    private var traitsError: String? {
        do {
            try catalog.calculator.validate(traits)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    var body: some View {
        Form {
            Section("Identity") {
                TextField("Name or ID", text: $name)
                Picker("Species", selection: $species) {
                    ForEach(catalog.speciesNames, id: \.self) { Text($0).tag($0) }
                }
                Picker("Sex", selection: $sex) {
                    ForEach(Sex.allCases) { Text("\($0.symbol) \($0.displayName)").tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Section("Age") {
                Toggle("Hatch date known", isOn: $hasHatchDate)
                if hasHatchDate {
                    DatePicker("Hatched", selection: $hatchDate, in: ...Date.now, displayedComponents: .date)
                    Toggle("Estimated", isOn: $hatchDateIsEstimate)
                    LabeledContent("Age", value: Date.ageString(from: hatchDate))
                }
            }

            Section("Origin") {
                Picker("Origin", selection: $origin) {
                    ForEach(Origin.allCases) { Text($0.displayName).tag($0) }
                }
                TextField(origin.detailsPrompt, text: $originDetails)
                Toggle("Acquired date", isOn: $hasAcquiredDate)
                if hasAcquiredDate {
                    DatePicker("Acquired", selection: $acquiredDate, in: ...Date.now, displayedComponents: .date)
                }
            }

            Section("Husbandry") {
                LabeledContent("Weight (g)") {
                    TextField("Grams", value: $weightGrams, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                Stepper("Feed every \(feedingIntervalDays) days", value: $feedingIntervalDays, in: 1...60)
            }

            Section {
                TraitsEditor(traits: $traits, species: species, catalog: catalog)
            } header: {
                Text("Genetics")
            } footer: {
                Text(catalog.describe(traits))
            }

            Section("Notes") {
                TextField("Temperament, husbandry, anything else", text: $notes, axis: .vertical)
                    .lineLimit(3...10)
            }
        }
        .navigationTitle(snake == nil ? "New Snake" : "Edit \(snake?.name ?? "")")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: species) { _, newSpecies in
            let valid = Set(catalog.genes(for: newSpecies).map(\.id))
            traits.removeAll { !valid.contains($0.geneID) }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || traitsError != nil)
            }
        }
    }

    private func save() {
        let target: Snake
        if let snake {
            target = snake
        } else {
            target = Snake(name: name, species: species, sex: sex)
            context.insert(target)
        }
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.species = species
        target.sex = sex
        target.hatchDate = hasHatchDate ? hatchDate : nil
        target.hatchDateIsEstimate = hasHatchDate && hatchDateIsEstimate
        target.origin = origin
        target.originDetails = originDetails
        target.acquiredDate = hasAcquiredDate ? acquiredDate : nil
        target.weightGrams = weightGrams
        target.feedingIntervalDays = feedingIntervalDays
        target.traits = traits
        target.notes = notes
        dismiss()
    }
}
