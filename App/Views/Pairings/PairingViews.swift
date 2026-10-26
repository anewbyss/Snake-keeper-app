import SwiftUI
import SwiftData
import SnakeGenetics

struct PairingsListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Pairing.createdAt, order: .reverse) private var pairings: [Pairing]
    @State private var showingNew = false

    private var seasons: [Int] {
        Array(Set(pairings.map(\.season))).sorted(by: >)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        PairingFinderView()
                    } label: {
                        Label("Pairing Finder", systemImage: "sparkle.magnifyingglass")
                    }
                } footer: {
                    Text("Rank every possible pairing in your collection by the odds of producing a target gene.")
                }
                ForEach(seasons, id: \.self) { season in
                    Section(String(season)) {
                        ForEach(pairings.filter { $0.season == season }) { pairing in
                            NavigationLink {
                                PairingDetailView(pairing: pairing)
                            } label: {
                                PairingRow(pairing: pairing)
                            }
                        }
                        .onDelete { offsets in
                            let inSeason = pairings.filter { $0.season == season }
                            for index in offsets { context.delete(inSeason[index]) }
                        }
                    }
                }
            }
            .overlay {
                if pairings.isEmpty {
                    ContentUnavailableView("No pairings planned", systemImage: "heart",
                                           description: Text("Plan a pairing, or use the Pairing Finder."))
                        .padding(.top, 120)
                }
            }
            .navigationTitle("Pairings")
            .toolbar {
                Button { showingNew = true } label: { Label("New Pairing", systemImage: "plus") }
            }
            .sheet(isPresented: $showingNew) {
                NavigationStack { PairingEditView(pairing: nil) }
            }
        }
    }
}

struct PairingRow: View {
    let pairing: Pairing

    var body: some View {
        HStack {
            Image(systemName: pairing.status.systemImage)
                .foregroundStyle(pairing.status.isActive ? Color.accentColor : .secondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(pairing.title).font(.headline)
                Text("\(pairing.species) · \(pairing.status.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let hatch = pairing.estimatedHatchDate, pairing.status == .laid {
                    Text("Est. hatch \(hatch.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.tint)
                }
            }
        }
    }
}

struct PairingEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Snake.name) private var snakes: [Snake]

    let pairing: Pairing?

    @State private var female: Snake?
    @State private var male: Snake?
    @State private var season: Int
    @State private var status: PairingStatus
    @State private var introducedDate: Date?
    @State private var lockCount: Int
    @State private var lastLockDate: Date?
    @State private var ovulationDate: Date?
    @State private var preLayShedDate: Date?
    @State private var layDate: Date?
    @State private var eggCount: Int?
    @State private var fertileEggCount: Int?
    @State private var hatchDate: Date?
    @State private var notes: String

    init(pairing: Pairing?, female: Snake? = nil, male: Snake? = nil) {
        self.pairing = pairing
        _female = State(initialValue: pairing?.female ?? female)
        _male = State(initialValue: pairing?.male ?? male)
        _season = State(initialValue: pairing?.season ?? Calendar.current.component(.year, from: .now))
        _status = State(initialValue: pairing?.status ?? .planned)
        _introducedDate = State(initialValue: pairing?.introducedDate)
        _lockCount = State(initialValue: pairing?.lockCount ?? 0)
        _lastLockDate = State(initialValue: pairing?.lastLockDate)
        _ovulationDate = State(initialValue: pairing?.ovulationDate)
        _preLayShedDate = State(initialValue: pairing?.preLayShedDate)
        _layDate = State(initialValue: pairing?.layDate)
        _eggCount = State(initialValue: pairing?.eggCount)
        _fertileEggCount = State(initialValue: pairing?.fertileEggCount)
        _hatchDate = State(initialValue: pairing?.hatchDate)
        _notes = State(initialValue: pairing?.notes ?? "")
    }

    private var females: [Snake] {
        snakes.filter { $0.sex == .female && (male == nil || $0.species == male?.species) }
    }

    private var males: [Snake] {
        snakes.filter { $0.sex == .male && (female == nil || $0.species == female?.species) }
    }

    var body: some View {
        Form {
            Section("Pair") {
                Picker("♀ Female", selection: $female) {
                    Text("Choose…").tag(Snake?.none)
                    ForEach(females) { Text($0.name).tag(Snake?.some($0)) }
                }
                Picker("♂ Male", selection: $male) {
                    Text("Choose…").tag(Snake?.none)
                    ForEach(males) { Text($0.name).tag(Snake?.some($0)) }
                }
                Stepper("Season \(String(season))", value: $season, in: 2000...2100)
            }
            Section("Progress") {
                Picker("Status", selection: $status) {
                    ForEach(PairingStatus.allCases) { Label($0.rawValue, systemImage: $0.systemImage).tag($0) }
                }
                OptionalDatePicker("Introduced", date: $introducedDate)
                Stepper("Locks observed: \(lockCount)", value: $lockCount, in: 0...100)
                OptionalDatePicker("Last lock", date: $lastLockDate)
                OptionalDatePicker("Ovulation", date: $ovulationDate)
                OptionalDatePicker("Pre-lay shed", date: $preLayShedDate)
            }
            Section("Clutch") {
                OptionalDatePicker("Laid / born", date: $layDate)
                LabeledContent("Eggs / babies") {
                    TextField("–", value: $eggCount, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Good / fertile") {
                    TextField("–", value: $fertileEggCount, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }
                OptionalDatePicker("Hatched", date: $hatchDate)
            }
            Section("Notes") {
                TextField("Notes", text: $notes, axis: .vertical)
            }
        }
        .navigationTitle(pairing == nil ? "New Pairing" : "Edit Pairing")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save).disabled(female == nil || male == nil)
            }
        }
    }

    private func save() {
        let target: Pairing
        if let pairing {
            target = pairing
        } else {
            target = Pairing(female: nil, male: nil, season: season)
            context.insert(target)
        }
        target.female = female
        target.male = male
        target.season = season
        target.status = status
        target.introducedDate = introducedDate
        target.lockCount = lockCount
        target.lastLockDate = lastLockDate
        target.ovulationDate = ovulationDate
        target.preLayShedDate = preLayShedDate
        target.layDate = layDate
        target.eggCount = eggCount
        target.fertileEggCount = fertileEggCount
        target.hatchDate = hatchDate
        target.notes = notes
        dismiss()
    }
}

/// A date row that can be left empty.
struct OptionalDatePicker: View {
    let title: String
    @Binding var date: Date?

    init(_ title: String, date: Binding<Date?>) {
        self.title = title
        _date = date
    }

    var body: some View {
        if let value = date {
            HStack {
                DatePicker(title, selection: Binding(get: { value }, set: { date = $0 }), displayedComponents: .date)
                Button { date = nil } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Clear \(title)")
            }
        } else {
            Button { date = .now } label: {
                LabeledContent(title, value: "Add date")
            }
        }
    }
}

struct PairingDetailView: View {
    @Query private var customGenes: [CustomGene]
    let pairing: Pairing
    @State private var showingEdit = false

    private var catalog: GeneCatalog { GeneCatalog(custom: customGenes) }

    var body: some View {
        List {
            Section {
                ForEach([pairing.female, pairing.male].compactMap { $0 }) { snake in
                    NavigationLink {
                        SnakeDetailView(snake: snake)
                    } label: {
                        SnakeRowView(snake: snake, morph: catalog.describe(snake.traits))
                    }
                }
            }
            Section("Progress") {
                LabeledContent("Status") {
                    Label(pairing.status.rawValue, systemImage: pairing.status.systemImage)
                }
                row("Introduced", pairing.introducedDate)
                if pairing.lockCount > 0 {
                    LabeledContent("Locks", value: "\(pairing.lockCount)")
                }
                row("Last lock", pairing.lastLockDate)
                row("Ovulation", pairing.ovulationDate)
                row("Pre-lay shed", pairing.preLayShedDate)
                if let estimate = pairing.estimatedLayDate {
                    LabeledContent("Est. lay", value: "~" + estimate.formatted(date: .abbreviated, time: .omitted))
                }
                row("Laid / born", pairing.layDate)
                if let eggs = pairing.eggCount {
                    LabeledContent("Clutch", value: pairing.fertileEggCount.map { "\($0) good of \(eggs)" } ?? "\(eggs)")
                }
                if let estimate = pairing.estimatedHatchDate, pairing.hatchDate == nil {
                    LabeledContent("Est. hatch", value: "~" + estimate.formatted(date: .abbreviated, time: .omitted))
                }
                row("Hatched", pairing.hatchDate)
            }
            if let female = pairing.female, let male = pairing.male {
                Section("Predicted Offspring") {
                    OutcomeList(
                        result: catalog.cross(female.traits, male.traits),
                        clutchSize: pairing.fertileEggCount ?? pairing.eggCount
                    )
                }
            }
            if !pairing.notes.isEmpty {
                Section("Notes") { Text(pairing.notes) }
            }
        }
        .navigationTitle(pairing.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { Button("Edit") { showingEdit = true } }
        .sheet(isPresented: $showingEdit) {
            NavigationStack { PairingEditView(pairing: pairing) }
        }
    }

    @ViewBuilder
    private func row(_ title: String, _ date: Date?) -> some View {
        if let date {
            LabeledContent(title, value: date.formatted(date: .abbreviated, time: .omitted))
        }
    }
}

/// Outcomes for a hypothetical pairing, with a button to plan it.
struct PairingPreviewView: View {
    @Query private var customGenes: [CustomGene]
    let female: Snake
    let male: Snake
    @State private var showingPlan = false

    private var catalog: GeneCatalog { GeneCatalog(custom: customGenes) }

    var body: some View {
        List {
            Section {
                LabeledContent("♀ \(female.name)", value: catalog.describe(female.traits))
                LabeledContent("♂ \(male.name)", value: catalog.describe(male.traits))
            }
            Section("Possible Offspring") {
                OutcomeList(result: catalog.cross(female.traits, male.traits))
            }
            Section {
                Button { showingPlan = true } label: {
                    Label("Plan This Pairing", systemImage: "calendar.badge.plus")
                }
            }
        }
        .navigationTitle("\(female.name) × \(male.name)")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingPlan) {
            NavigationStack { PairingEditView(pairing: nil, female: female, male: male) }
        }
    }
}

/// Ranks every female × male pair in the collection by odds of producing a chosen gene.
struct PairingFinderView: View {
    @Query(sort: \Snake.name) private var snakes: [Snake]
    @Query private var customGenes: [CustomGene]

    @State private var species = GeneLibrary.species[0].name
    @State private var targetGeneID: String?

    private var catalog: GeneCatalog { GeneCatalog(custom: customGenes) }

    private struct Match: Identifiable {
        let female: Snake
        let male: Snake
        let probability: Double
        var id: String { "\(female.id)-\(male.id)" }
    }

    private var matches: [Match] {
        guard let targetGeneID else { return [] }
        let calculator = catalog.calculator
        let females = snakes.filter { $0.species == species && $0.sex == .female }
        let males = snakes.filter { $0.species == species && $0.sex == .male }
        var result: [Match] = []
        for female in females {
            for male in males {
                guard let p = try? calculator.probability(ofExpressing: targetGeneID, female.traits, male.traits),
                      p > 0 else { continue }
                result.append(Match(female: female, male: male, probability: p))
            }
        }
        return result.sorted { $0.probability > $1.probability }
    }

    var body: some View {
        List {
            Section {
                Picker("Species", selection: $species) {
                    ForEach(catalog.speciesNames, id: \.self) { Text($0).tag($0) }
                }
                Picker("Target gene", selection: $targetGeneID) {
                    Text("Choose…").tag(String?.none)
                    ForEach(catalog.genes(for: species)) { Text($0.name).tag(String?.some($0.id)) }
                }
            } footer: {
                Text("Odds that a baby visually shows the gene, alone or in a combo.")
            }
            if targetGeneID != nil {
                Section("Best pairings") {
                    if matches.isEmpty {
                        Text("No pairing in your collection can produce this gene visually.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(matches) { match in
                        NavigationLink {
                            PairingPreviewView(female: match.female, male: match.male)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("\(match.female.name) × \(match.male.name)")
                                    Text("\(catalog.describe(match.female.traits)) × \(catalog.describe(match.male.traits))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(Percent.format(match.probability)).font(.headline).monospacedDigit()
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Pairing Finder")
        .onChange(of: species) { _, _ in targetGeneID = nil }
    }
}
