import SwiftUI
import SwiftData

/// Pre-filled values for a new hatchling added from a pairing.
struct HatchlingPreset {
    var species: String
    var damID: UUID?
    var sireID: UUID?
    var hatchDate: Date
    var originDetails: String
}

struct SnakeEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var customGenes: [CustomGene]
    @Query(sort: \Snake.name) private var allSnakes: [Snake]
    @Query private var profiles: [BreederProfile]

    let snake: Snake?
    let preset: HatchlingPreset?

    @State private var name: String
    @State private var species: String
    @State private var sex: Sex
    @State private var status: SnakeStatus
    @State private var statusNote: String
    @State private var enclosure: String
    @State private var hasHatchDate: Bool
    @State private var hatchDate: Date
    @State private var hatchDateIsEstimate: Bool
    @State private var origin: Origin
    @State private var originDetails: String
    @State private var hasAcquiredDate: Bool
    @State private var acquiredDate: Date
    @State private var damID: UUID?
    @State private var sireID: UUID?
    @State private var weightGrams: Double?
    @State private var feedingIntervalDays: Int
    @State private var traits: [TraitEntry]
    @State private var notes: String
    @State private var appliedDefaults = false

    init(snake: Snake?, preset: HatchlingPreset? = nil) {
        self.snake = snake
        self.preset = preset
        _name = State(initialValue: snake?.name ?? "")
        _species = State(initialValue: snake?.species ?? preset?.species ?? GeneLibrary.species[0].name)
        _sex = State(initialValue: snake?.sex ?? .unknown)
        _status = State(initialValue: snake?.status ?? .active)
        _statusNote = State(initialValue: snake?.statusNote ?? "")
        _enclosure = State(initialValue: snake?.enclosure ?? "")
        _hasHatchDate = State(initialValue: snake?.hatchDate != nil || preset != nil)
        _hatchDate = State(initialValue: snake?.hatchDate ?? preset?.hatchDate ?? .now)
        _hatchDateIsEstimate = State(initialValue: snake?.hatchDateIsEstimate ?? false)
        _origin = State(initialValue: snake?.origin ?? (preset != nil ? .homeBred : .purchased))
        _originDetails = State(initialValue: snake?.originDetails ?? preset?.originDetails ?? "")
        _hasAcquiredDate = State(initialValue: snake?.acquiredDate != nil)
        _acquiredDate = State(initialValue: snake?.acquiredDate ?? .now)
        _damID = State(initialValue: snake?.damID ?? preset?.damID)
        _sireID = State(initialValue: snake?.sireID ?? preset?.sireID)
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

    private func parents(_ parentSex: Sex, selected: UUID?) -> [Snake] {
        allSnakes.filter { $0.sex == parentSex && $0.id != snake?.id && ($0.species == species || $0.id == selected) }
    }

    private var title: String {
        if let snake { return "Edit \(snake.name)" }
        return preset == nil ? "New Snake" : "New Hatchling"
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

            Section("Status") {
                Picker("Status", selection: $status) {
                    ForEach(SnakeStatus.allCases) { Text($0.displayName).tag($0) }
                }
                TextField("Status note (price, buyer, date…)", text: $statusNote)
                TextField("Enclosure (rack / tub / tank)", text: $enclosure)
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
                Picker("Dam ♀", selection: $damID) {
                    Text("None").tag(UUID?.none)
                    ForEach(parents(.female, selected: damID)) { Text($0.name).tag(UUID?.some($0.id)) }
                }
                Picker("Sire ♂", selection: $sireID) {
                    Text("None").tag(UUID?.none)
                    ForEach(parents(.male, selected: sireID)) { Text($0.name).tag(UUID?.some($0.id)) }
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
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // New snakes start from the breeder profile's defaults.
            guard snake == nil, !appliedDefaults, let profile = profiles.first else { return }
            appliedDefaults = true
            if preset == nil { species = profile.defaultSpecies }
            feedingIntervalDays = profile.defaultFeedingInterval
        }
        .onChange(of: species) { _, newSpecies in
            let valid = Set(catalog.genes(for: newSpecies).map(\.id))
            traits.removeAll { !valid.contains($0.geneID) }
        }
        .onChange(of: origin) { _, newOrigin in
            if newOrigin == .homeBred, originDetails.isEmpty, let name = profiles.first?.displayName, !name.isEmpty {
                originDetails = name
            }
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
        let weightChanged = weightGrams != nil && weightGrams != target.weightGrams
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.species = species
        target.sex = sex
        target.status = status
        target.statusNote = statusNote.trimmingCharacters(in: .whitespaces)
        target.enclosure = enclosure.trimmingCharacters(in: .whitespaces)
        target.hatchDate = hasHatchDate ? hatchDate : nil
        target.hatchDateIsEstimate = hasHatchDate && hatchDateIsEstimate
        target.origin = origin
        target.originDetails = originDetails
        target.acquiredDate = hasAcquiredDate ? acquiredDate : nil
        target.damID = damID
        target.sireID = sireID
        target.weightGrams = weightGrams
        target.feedingIntervalDays = feedingIntervalDays
        target.traits = traits
        target.notes = notes
        // Keep weight history: a new or changed weight goes into the care log too.
        if weightChanged, let weightGrams { target.logWeight(weightGrams, in: context) }
        context.saveNow()
        dismiss()
    }
}
