import SwiftUI
import SwiftData

enum CollectionFilter: Hashable {
    case current, all
    case status(SnakeStatus)
}

enum CollectionSort: String, CaseIterable, Identifiable {
    case name = "Name", feeding = "Feeding due", age = "Oldest first", newest = "Recently added"
    var id: String { rawValue }
}

struct SnakeListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Snake.name) private var snakes: [Snake]
    @Query private var customGenes: [CustomGene]

    @State private var searchText = ""
    @State private var speciesFilter: String?
    @State private var sexFilter: Sex?
    @State private var collectionFilter = CollectionFilter.current
    @State private var sort = CollectionSort.name
    @State private var showingAdd = false

    private var catalog: GeneCatalog { GeneCatalog(custom: customGenes) }

    private func matchesStatus(_ snake: Snake) -> Bool {
        switch collectionFilter {
        case .current: return snake.isInCollection
        case .all: return true
        case .status(let status): return snake.status == status
        }
    }

    private func sorted(_ list: [Snake]) -> [Snake] {
        func rank(_ snake: Snake) -> Int {
            switch snake.feedingStatus {
            case .overdue: return 0
            case .due: return 1
            case .noRecord: return 2
            case .fed: return 3
            }
        }
        switch sort {
        case .name:
            return list
        case .feeding:
            return list.sorted {
                rank($0) != rank($1) ? rank($0) < rank($1)
                    : ($0.nextFeedingDate ?? .distantPast) < ($1.nextFeedingDate ?? .distantPast)
            }
        case .age:
            return list.sorted { ($0.hatchDate ?? .distantFuture) < ($1.hatchDate ?? .distantFuture) }
        case .newest:
            return list.sorted { $0.createdAt > $1.createdAt }
        }
    }

    private var filtered: [Snake] {
        sorted(snakes).filter { snake in
            matchesStatus(snake)
                && (speciesFilter == nil || snake.species == speciesFilter)
                && (sexFilter == nil || snake.sex == sexFilter)
                && (searchText.isEmpty
                    || snake.name.localizedCaseInsensitiveContains(searchText)
                    || snake.species.localizedCaseInsensitiveContains(searchText)
                    || catalog.describe(snake.traits).localizedCaseInsensitiveContains(searchText))
        }
    }

    private var speciesInCollection: [String] {
        Array(Set(snakes.map(\.species))).sorted()
    }

    var body: some View {
        NavigationStack {
            Group {
                if snakes.isEmpty {
                    ContentUnavailableView {
                        Label("No snakes yet", systemImage: "lizard")
                    } description: {
                        Text("Add your first animal to start tracking meals, health and pairings.")
                    } actions: {
                        Button("Add Snake") { showingAdd = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(filtered) { snake in
                            NavigationLink(value: snake) {
                                SnakeRowView(snake: snake, morph: catalog.describe(snake.traits))
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets { context.delete(filtered[index]) }
                            context.saveNow()
                        }
                    }
                    .overlay {
                        if filtered.isEmpty { ContentUnavailableView.search }
                    }
                }
            }
            .navigationTitle("Collection")
            .navigationDestination(for: Snake.self) { SnakeDetailView(snake: $0) }
            .searchable(text: $searchText, prompt: "Name, species or morph")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Species", selection: $speciesFilter) {
                            Text("All species").tag(String?.none)
                            ForEach(speciesInCollection, id: \.self) { Text($0).tag(String?.some($0)) }
                        }
                        Picker("Sex", selection: $sexFilter) {
                            Text("Any sex").tag(Sex?.none)
                            ForEach(Sex.allCases) { Text($0.displayName).tag(Sex?.some($0)) }
                        }
                        Picker("Status", selection: $collectionFilter) {
                            Text("In collection").tag(CollectionFilter.current)
                            ForEach(SnakeStatus.allCases) { Text($0.displayName).tag(CollectionFilter.status($0)) }
                            Text("All, incl. sold").tag(CollectionFilter.all)
                        }
                        Picker("Sort", selection: $sort) {
                            ForEach(CollectionSort.allCases) { Text("Sort: \($0.rawValue)").tag($0) }
                        }
                    } label: {
                        Label("Filter", systemImage: speciesFilter == nil && sexFilter == nil && collectionFilter == .current
                              ? "line.3.horizontal.decrease.circle"
                              : "line.3.horizontal.decrease.circle.fill")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAdd = true } label: { Label("Add Snake", systemImage: "plus") }
                }
            }
            .sheet(isPresented: $showingAdd) {
                NavigationStack { SnakeEditView(snake: nil) }
            }
        }
    }
}

struct SnakeRowView: View {
    let snake: Snake
    let morph: String

    var body: some View {
        HStack(spacing: 12) {
            SnakeThumbnail(photo: snake.coverPhoto, size: 56)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(snake.name).font(.headline)
                    Text(snake.sex.symbol)
                        .foregroundStyle(snake.sex.color)
                    if !snake.openConcerns.isEmpty {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                            .accessibilityLabel("Open concerns")
                    }
                    if snake.status != .active {
                        StatusBadge(status: snake.status)
                    }
                }
                Text(morph).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                HStack(spacing: 8) {
                    Text(snake.species)
                    if let age = snake.ageDescription { Text("· \(age)") }
                    if !snake.enclosure.isEmpty { Text("· \(snake.enclosure)") }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            FeedingBadge(snake: snake)
        }
    }
}

struct FeedingBadge: View {
    let snake: Snake

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Image(systemName: "fork.knife.circle.fill")
                .foregroundStyle(snake.feedingStatus.color)
            if let days = snake.daysSinceLastMeal {
                Text("\(days)d").font(.caption2).monospacedDigit().foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(snake.daysSinceLastMeal.map { "Last fed \($0) days ago" } ?? "No meals logged")
    }
}

struct SnakeThumbnail: View {
    let photo: SnakePhoto?
    var size: CGFloat = 56

    var body: some View {
        Group {
            if let photo, let image = UIImage(data: photo.thumbnailData) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "lizard.fill")
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.secondarySystemBackground))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
    }
}
