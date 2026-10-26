import SwiftUI
import SwiftData

struct FeedingLogView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let snake: Snake
    let record: FeedingRecord?

    @State private var date: Date
    @State private var preyType: String
    @State private var preySize: String
    @State private var preyState: String
    @State private var preyCount: Int
    @State private var preyWeightGrams: Double?
    @State private var refused: Bool
    @State private var notes: String
    @State private var snakeWeightGrams: Double?

    init(snake: Snake, record: FeedingRecord? = nil) {
        self.snake = snake
        self.record = record
        // New records default to whatever the snake ate last.
        let template = record ?? snake.lastMeal
        _date = State(initialValue: record?.date ?? .now)
        _preyType = State(initialValue: template?.preyType ?? PreyType.mouse.rawValue)
        _preySize = State(initialValue: template?.preySize ?? PreySize.small.rawValue)
        _preyState = State(initialValue: template?.preyState ?? PreyState.frozenThawed.rawValue)
        _preyCount = State(initialValue: template?.preyCount ?? 1)
        _preyWeightGrams = State(initialValue: template?.preyWeightGrams)
        _refused = State(initialValue: record?.refused ?? false)
        _notes = State(initialValue: record?.notes ?? "")
        _snakeWeightGrams = State(initialValue: nil)
    }

    var body: some View {
        Form {
            Section {
                DatePicker("Date", selection: $date, in: ...Date.now)
                Toggle("Refused", isOn: $refused)
            }
            Section("Prey") {
                Picker("Type", selection: $preyType) {
                    ForEach(PreyType.allCases) { Text($0.rawValue).tag($0.rawValue) }
                }
                Picker("Size", selection: $preySize) {
                    ForEach(PreySize.allCases) { Text($0.rawValue).tag($0.rawValue) }
                }
                Picker("Offered", selection: $preyState) {
                    ForEach(PreyState.allCases) { Text($0.rawValue).tag($0.rawValue) }
                }
                Stepper("Count: \(preyCount)", value: $preyCount, in: 1...10)
                LabeledContent("Prey weight (g)") {
                    TextField("Optional", value: $preyWeightGrams, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            }
            if record == nil {
                Section {
                    LabeledContent("Snake weight (g)") {
                        TextField(snake.weightGrams.map { Weight.format($0) } ?? "Optional",
                                  value: $snakeWeightGrams, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                } footer: {
                    Text("Updates \(snake.name)'s current weight.")
                }
            }
            Section("Notes") {
                TextField("Strike, regurge, shed status…", text: $notes, axis: .vertical)
            }
        }
        .navigationTitle(record == nil ? "Log Feeding" : "Edit Feeding")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
        }
    }

    private func save() {
        let target: FeedingRecord
        if let record {
            target = record
        } else {
            target = FeedingRecord(date: date, preyType: preyType, preySize: preySize, preyState: preyState)
            context.insert(target)
            target.snake = snake
        }
        target.date = date
        target.preyType = preyType
        target.preySize = preySize
        target.preyState = preyState
        target.preyCount = preyCount
        target.preyWeightGrams = preyWeightGrams
        target.refused = refused
        target.notes = notes
        if let snakeWeightGrams { snake.weightGrams = snakeWeightGrams }
        dismiss()
    }
}

struct FeedingHistoryView: View {
    @Environment(\.modelContext) private var context
    let snake: Snake
    @State private var editing: FeedingRecord?

    private var records: [FeedingRecord] {
        snake.feedings.sorted { $0.date > $1.date }
    }

    private var acceptanceRate: Double {
        guard !snake.feedings.isEmpty else { return 0 }
        return Double(snake.feedings.filter { !$0.refused }.count) / Double(snake.feedings.count)
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Records", value: "\(records.count)")
                LabeledContent("Acceptance", value: "\(Int((acceptanceRate * 100).rounded()))%")
            }
            Section {
                ForEach(records) { record in
                    Button { editing = record } label: {
                        HStack {
                            Image(systemName: record.refused ? "xmark.circle.fill" : "checkmark.circle.fill")
                                .foregroundStyle(record.refused ? .red : .green)
                            VStack(alignment: .leading) {
                                Text(record.summary)
                                if !record.notes.isEmpty {
                                    Text(record.notes).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text(record.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { offsets in
                    for index in offsets { context.delete(records[index]) }
                }
            }
        }
        .navigationTitle("Feeding History")
        .sheet(item: $editing) { record in
            NavigationStack { FeedingLogView(snake: snake, record: record) }
        }
    }
}

/// Every snake ordered by how urgently it needs feeding.
struct FeedingScheduleView: View {
    @Query(sort: \Snake.name) private var snakes: [Snake]
    @State private var feeding: Snake?

    private func rank(_ snake: Snake) -> Int {
        switch snake.feedingStatus {
        case .overdue: return 0
        case .due: return 1
        case .noRecord: return 2
        case .fed: return 3
        }
    }

    private var sorted: [Snake] {
        snakes.sorted {
            let (a, b) = (rank($0), rank($1))
            if a != b { return a < b }
            return ($0.nextFeedingDate ?? .distantPast) < ($1.nextFeedingDate ?? .distantPast)
        }
    }

    var body: some View {
        NavigationStack {
            List(sorted) { snake in
                HStack {
                    SnakeThumbnail(photo: snake.coverPhoto, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(snake.name).font(.headline)
                        if let meal = snake.lastMeal {
                            Text("\(meal.summary) · \(meal.date.daysAgoString)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if snake.refusalStreak > 0 {
                            Text("\(snake.refusalStreak) refusal\(snake.refusalStreak == 1 ? "" : "s") in a row")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    Spacer()
                    Text(snake.feedingStatus.label)
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(snake.feedingStatus.color.opacity(0.15), in: Capsule())
                        .foregroundStyle(snake.feedingStatus.color)
                }
                .swipeActions(edge: .leading) {
                    Button { feeding = snake } label: { Label("Log", systemImage: "fork.knife") }
                        .tint(.green)
                }
                .contextMenu {
                    Button { feeding = snake } label: { Label("Log Feeding", systemImage: "fork.knife") }
                }
            }
            .overlay {
                if snakes.isEmpty {
                    ContentUnavailableView("Nothing to feed", systemImage: "fork.knife",
                                           description: Text("Add snakes in the Collection tab."))
                }
            }
            .navigationTitle("Feeding")
            .sheet(item: $feeding) { snake in
                NavigationStack { FeedingLogView(snake: snake) }
            }
        }
    }
}
