import SwiftUI
import SwiftData
import Charts

/// Last shed, weight trend, recent entries and quick-log buttons. Used inside the snake's `List`.
struct CareLogSection: View {
    let snake: Snake

    @State private var newKind: LogKind?
    @State private var editing: LogEntry?

    var body: some View {
        Section {
            if let shed = snake.lastShed {
                LabeledContent("Last shed", value: shed.date.daysAgoString)
            }
            if snake.weightLogs.count > 1 {
                WeightChart(entries: snake.weightLogs)
            }
            ForEach(snake.sortedLogs.prefix(3)) { entry in
                Button { editing = entry } label: { LogEntryRow(entry: entry) }
                    .buttonStyle(.plain)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(LogKind.allCases) { kind in
                        Button { newKind = kind } label: {
                            Label(kind.shortName, systemImage: kind.systemImage).font(.subheadline)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            if snake.logs.count > 3 {
                NavigationLink {
                    CareLogHistoryView(snake: snake)
                } label: {
                    LabeledContent("All entries", value: "\(snake.logs.count)")
                }
            }
        } header: {
            Text("Care Log")
        }
        .sheet(item: $newKind) { kind in
            NavigationStack { LogEntryEditView(snake: snake, entry: nil, kind: kind) }
        }
        .sheet(item: $editing) { entry in
            NavigationStack { LogEntryEditView(snake: snake, entry: entry, kind: entry.kind) }
        }
    }
}

struct WeightChart: View {
    /// Newest first, as `Snake.weightLogs` returns them.
    let entries: [LogEntry]

    private var points: [LogEntry] { Array(entries.prefix(24).reversed()) }

    private var change: Double {
        guard let first = points.first?.grams, let last = points.last?.grams else { return 0 }
        return last - first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let first = points.first {
                Text("Weight trend · \(change >= 0 ? "+" : "−")\(Weight.format(abs(change))) since \(first.date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Chart(points) { entry in
                LineMark(x: .value("Date", entry.date), y: .value("Grams", entry.grams ?? 0))
                PointMark(x: .value("Date", entry.date), y: .value("Grams", entry.grams ?? 0))
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .frame(height: 120)
            .accessibilityLabel("Weight trend")
        }
        .padding(.vertical, 4)
    }
}

struct LogEntryRow: View {
    let entry: LogEntry

    var body: some View {
        HStack {
            Image(systemName: entry.kind.systemImage)
                .foregroundStyle(.tint)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                if entry.kind == .weight, let grams = entry.grams {
                    Text("\(entry.kind.displayName) · \(Weight.format(grams))")
                } else {
                    Text(entry.kind.displayName)
                }
                if !entry.notes.isEmpty {
                    Text(entry.notes).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }
}

struct CareLogHistoryView: View {
    @Environment(\.modelContext) private var context
    let snake: Snake
    @State private var editing: LogEntry?

    var body: some View {
        List {
            if snake.weightLogs.count > 1 {
                Section { WeightChart(entries: snake.weightLogs) }
            }
            Section("Entries") {
                ForEach(snake.sortedLogs) { entry in
                    Button { editing = entry } label: { LogEntryRow(entry: entry) }
                        .buttonStyle(.plain)
                }
                .onDelete { offsets in
                    let logs = snake.sortedLogs
                    for index in offsets { context.delete(logs[index]) }
                    context.saveNow()
                    snake.syncWeightFromLog()
                    context.saveNow()
                }
            }
        }
        .navigationTitle("Care Log")
        .sheet(item: $editing) { entry in
            NavigationStack { LogEntryEditView(snake: snake, entry: entry, kind: entry.kind) }
        }
    }
}

struct LogEntryEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let snake: Snake
    let entry: LogEntry?

    @State private var kind: LogKind
    @State private var date: Date
    @State private var grams: Double?
    @State private var notes: String

    init(snake: Snake, entry: LogEntry?, kind: LogKind) {
        self.snake = snake
        self.entry = entry
        _kind = State(initialValue: entry?.kind ?? kind)
        _date = State(initialValue: entry?.date ?? .now)
        _grams = State(initialValue: entry?.grams)
        _notes = State(initialValue: entry?.notes ?? "")
    }

    var body: some View {
        Form {
            Section {
                Picker("Type", selection: $kind) {
                    ForEach(LogKind.allCases) { Label($0.displayName, systemImage: $0.systemImage).tag($0) }
                }
                DatePicker("Date", selection: $date, in: ...Date.now, displayedComponents: .date)
                if kind == .weight {
                    LabeledContent("Weight (g)") {
                        TextField(snake.weightGrams.map { Weight.format($0) } ?? "Grams", value: $grams, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            Section("Notes") {
                TextField(kind.notesPrompt, text: $notes, axis: .vertical)
                    .lineLimit(3...10)
            }
            if let entry {
                Section {
                    Button("Delete Entry", role: .destructive) {
                        context.delete(entry)
                        context.saveNow()
                        snake.syncWeightFromLog()
                        context.saveNow()
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle(entry == nil ? kind.displayName : "Edit Entry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save).disabled(kind == .weight && (grams ?? 0) <= 0)
            }
        }
    }

    private func save() {
        let target: LogEntry
        if let entry {
            target = entry
        } else {
            target = LogEntry(date: date, kind: kind)
            context.insert(target)
            target.snake = snake
        }
        target.kind = kind
        target.date = date
        target.grams = kind == .weight ? grams : nil
        target.notes = notes
        context.saveNow()
        // Recalculate after saving so the snake's log list includes this entry.
        snake.syncWeightFromLog()
        context.saveNow()
        dismiss()
    }
}
