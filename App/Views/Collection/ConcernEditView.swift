import SwiftUI
import SwiftData

struct ConcernEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let snake: Snake
    let concern: Concern?

    @State private var title: String
    @State private var category: String
    @State private var severity: ConcernSeverity
    @State private var dateNoted: Date
    @State private var details: String
    @State private var vetVisit: Bool
    @State private var isResolved: Bool
    @State private var resolvedDate: Date

    init(snake: Snake, concern: Concern?) {
        self.snake = snake
        self.concern = concern
        _title = State(initialValue: concern?.title ?? "")
        _category = State(initialValue: concern?.category ?? ConcernCategory.other.rawValue)
        _severity = State(initialValue: concern?.severity ?? .low)
        _dateNoted = State(initialValue: concern?.dateNoted ?? .now)
        _details = State(initialValue: concern?.details ?? "")
        _vetVisit = State(initialValue: concern?.vetVisit ?? false)
        _isResolved = State(initialValue: concern?.isResolved ?? false)
        _resolvedDate = State(initialValue: concern?.resolvedDate ?? .now)
    }

    var body: some View {
        Form {
            Section {
                TextField("What's going on?", text: $title)
                Picker("Category", selection: $category) {
                    ForEach(ConcernCategory.allCases) { Text($0.rawValue).tag($0.rawValue) }
                }
                Picker("Severity", selection: $severity) {
                    ForEach(ConcernSeverity.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                DatePicker("Noticed", selection: $dateNoted, in: ...Date.now, displayedComponents: .date)
            }
            Section("Details") {
                TextField("Symptoms, treatment, follow-up", text: $details, axis: .vertical)
                    .lineLimit(3...12)
                Toggle("Vet visit", isOn: $vetVisit)
            }
            Section {
                Toggle("Resolved", isOn: $isResolved)
                if isResolved {
                    DatePicker("Resolved on", selection: $resolvedDate, in: dateNoted...Date.now,
                               displayedComponents: .date)
                }
            }
            if let concern {
                Section {
                    Button("Delete Concern", role: .destructive) {
                        context.delete(concern)
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle(concern == nil ? "New Concern" : "Concern")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func save() {
        let target: Concern
        if let concern {
            target = concern
        } else {
            target = Concern(title: title)
            context.insert(target)
            target.snake = snake
        }
        target.title = title.trimmingCharacters(in: .whitespaces)
        target.category = category
        target.severity = severity
        target.dateNoted = dateNoted
        target.details = details
        target.vetVisit = vetVisit
        target.isResolved = isResolved
        target.resolvedDate = isResolved ? max(resolvedDate, dateNoted) : nil
        dismiss()
    }
}
