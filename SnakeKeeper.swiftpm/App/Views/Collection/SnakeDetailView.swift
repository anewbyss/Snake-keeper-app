import SwiftUI
import SwiftData

struct SnakeDetailView: View {
    @Query private var customGenes: [CustomGene]
    @Query(sort: \Snake.name) private var allSnakes: [Snake]

    let snake: Snake

    @State private var showingEdit = false
    @State private var showingFeeding = false
    @State private var showingNewConcern = false
    @State private var editingConcern: Concern?

    private var catalog: GeneCatalog { GeneCatalog(custom: customGenes) }

    private var pairingCandidates: [Snake] {
        guard let opposite = snake.sex.opposite else { return [] }
        return allSnakes.filter { $0.species == snake.species && $0.sex == opposite && $0.id != snake.id }
    }

    var body: some View {
        List {
            header
            detailsSection
            feedingSection
            concernsSection
            Section("Photos") { PhotoSection(snake: snake) }
            pairingsSection
            if !snake.notes.isEmpty {
                Section("Notes") { Text(snake.notes) }
            }
        }
        .navigationTitle(snake.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Edit") { showingEdit = true }
        }
        .sheet(isPresented: $showingEdit) {
            NavigationStack { SnakeEditView(snake: snake) }
        }
        .sheet(isPresented: $showingFeeding) {
            NavigationStack { FeedingLogView(snake: snake) }
        }
        .sheet(isPresented: $showingNewConcern) {
            NavigationStack { ConcernEditView(snake: snake, concern: nil) }
        }
        .sheet(item: $editingConcern) { concern in
            NavigationStack { ConcernEditView(snake: snake, concern: concern) }
        }
    }

    // MARK: Sections

    private var header: some View {
        Section {
            HStack(spacing: 16) {
                SnakeThumbnail(photo: snake.coverPhoto, size: 96)
                VStack(alignment: .leading, spacing: 4) {
                    Text(catalog.describe(snake.traits)).font(.headline)
                    Text(snake.species).foregroundStyle(.secondary)
                    if let scientific = GeneLibrary.speciesInfo(named: snake.species)?.scientificName {
                        Text(scientific).font(.caption).italic().foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var detailsSection: some View {
        Section("Details") {
            LabeledContent("Sex") {
                Text("\(snake.sex.symbol) \(snake.sex.displayName)").foregroundStyle(snake.sex.color)
            }
            if let hatchDate = snake.hatchDate {
                LabeledContent("Age", value: snake.ageDescription ?? "")
                LabeledContent("Hatched", value: hatchDate.formatted(date: .abbreviated, time: .omitted)
                               + (snake.hatchDateIsEstimate ? " (est.)" : ""))
            } else {
                LabeledContent("Age", value: "Unknown")
            }
            LabeledContent("Origin", value: snake.origin.displayName)
            if !snake.originDetails.isEmpty {
                LabeledContent(snake.origin.detailsPrompt, value: snake.originDetails)
            }
            if let acquired = snake.acquiredDate {
                LabeledContent("Acquired", value: acquired.formatted(date: .abbreviated, time: .omitted))
            }
            if let weight = snake.weightGrams {
                LabeledContent("Weight", value: Weight.format(weight))
            }
        }
    }

    private var feedingSection: some View {
        Section {
            if let meal = snake.lastMeal {
                LabeledContent("Last meal") {
                    VStack(alignment: .trailing) {
                        Text(meal.date.daysAgoString).foregroundStyle(snake.feedingStatus.color)
                        Text(meal.summary).font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let next = snake.nextFeedingDate {
                    LabeledContent("Next feeding", value: next.formatted(date: .abbreviated, time: .omitted))
                }
            } else {
                Text("No meals logged").foregroundStyle(.secondary)
            }
            if snake.refusalStreak > 0 {
                Label("Refused last \(snake.refusalStreak) offer\(snake.refusalStreak == 1 ? "" : "s")",
                      systemImage: "hand.raised")
                    .foregroundStyle(.orange)
            }
            Button { showingFeeding = true } label: {
                Label("Log Feeding", systemImage: "plus.circle.fill")
            }
            if !snake.feedings.isEmpty {
                NavigationLink {
                    FeedingHistoryView(snake: snake)
                } label: {
                    LabeledContent("History", value: "\(snake.feedings.count) records")
                }
            }
        } header: {
            Text("Feeding · every \(snake.feedingIntervalDays) days")
        }
    }

    private var concernsSection: some View {
        Section {
            ForEach(snake.openConcerns) { concern in
                Button { editingConcern = concern } label: { ConcernRow(concern: concern) }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button("Resolve") {
                            concern.isResolved = true
                            concern.resolvedDate = .now
                        }
                        .tint(.green)
                    }
            }
            Button { showingNewConcern = true } label: {
                Label("Add Concern", systemImage: "plus.circle")
            }
            let resolved = snake.concerns.filter(\.isResolved).sorted { $0.dateNoted > $1.dateNoted }
            if !resolved.isEmpty {
                DisclosureGroup("Resolved (\(resolved.count))") {
                    ForEach(resolved) { concern in
                        Button { editingConcern = concern } label: { ConcernRow(concern: concern) }
                            .buttonStyle(.plain)
                    }
                }
            }
        } header: {
            Text("Health & Concerns")
        }
    }

    private var pairingsSection: some View {
        Section {
            if snake.sex == .unknown {
                Text("Set this snake's sex to see potential pairings.").foregroundStyle(.secondary)
            } else if pairingCandidates.isEmpty {
                Text("No \(snake.sex.opposite?.displayName.lowercased() ?? "") \(snake.species) in your collection yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(pairingCandidates) { partner in
                    let female = snake.sex == .female ? snake : partner
                    let male = snake.sex == .male ? snake : partner
                    NavigationLink {
                        PairingPreviewView(female: female, male: male)
                    } label: {
                        PotentialPairingRow(partner: partner, female: female, male: male, catalog: catalog)
                    }
                }
            }
            ForEach(snake.pairings) { pairing in
                NavigationLink {
                    PairingDetailView(pairing: pairing)
                } label: {
                    Label("\(String(pairing.season)): \(pairing.title) — \(pairing.status.rawValue)",
                          systemImage: pairing.status.systemImage)
                }
            }
        } header: {
            Text("Potential Pairings")
        }
    }
}

struct ConcernRow: View {
    let concern: Concern

    var body: some View {
        HStack(alignment: .top) {
            Circle()
                .fill(concern.isResolved ? Color.green : concern.severity.color)
                .frame(width: 10, height: 10)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 2) {
                Text(concern.title).font(.body)
                Text("\(concern.category) · \(concern.dateNoted.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !concern.details.isEmpty {
                    Text(concern.details).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Spacer()
            if concern.vetVisit {
                Image(systemName: "cross.case.fill").foregroundStyle(.red).accessibilityLabel("Vet visit")
            }
        }
        .contentShape(Rectangle())
    }
}

struct PotentialPairingRow: View {
    let partner: Snake
    let female: Snake
    let male: Snake
    let catalog: GeneCatalog

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(partner.sex.symbol) \(partner.name)").font(.body)
            Text(catalog.describe(partner.traits)).font(.caption).foregroundStyle(.secondary)
            switch catalog.cross(female.traits, male.traits) {
            case .success(let outcomes):
                let visual = outcomes.filter { !$0.visualTraits.isEmpty }
                if let best = visual.max(by: { $0.visualTraits.count < $1.visualTraits.count }) {
                    Text("\(outcomes.count) outcomes · up to \(best.name) (\(Percent.format(best.probability)))")
                        .font(.caption2)
                        .foregroundStyle(.tint)
                } else {
                    Text("\(outcomes.count) outcome\(outcomes.count == 1 ? "" : "s")").font(.caption2).foregroundStyle(.tint)
                }
            case .failure(let error):
                Text(error.localizedDescription).font(.caption2).foregroundStyle(.red)
            }
        }
    }
}
