import SwiftUI
import SwiftData

struct SnakeListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Snake.name) private var snakes: [Snake]
    @Query private var customGenes: [CustomGene]

    @State private var searchText = ""
    @State private var speciesFilter: String?
    @State private var sexFilter: Sex?
    @State private var showingAdd = false

    private var catalog: GeneCatalog { GeneCatalog(custom: customGenes) }

    private var filtered: [Snake] {
        snakes.filter { snake in
            (speciesFilter == nil || snake.species == speciesFilter)
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
                    } label: {
                        Label("Filter", systemImage: speciesFilter == nil && sexFilter == nil
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
                }
                Text(morph).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                HStack(spacing: 8) {
                    Text(snake.species)
                    if let age = snake.ageDescription { Text("· \(age)") }
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
