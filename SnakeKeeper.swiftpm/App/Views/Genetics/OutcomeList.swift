import SwiftUI

/// Result rows for a cross. Place inside a `List`.
struct OutcomeList: View {
    let result: Result<[CrossOutcome], Error>
    var clutchSize: Int?

    var body: some View {
        switch result {
        case .failure(let error):
            Label(error.localizedDescription, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        case .success(let outcomes):
            ForEach(outcomes) { outcome in
                OutcomeRow(outcome: outcome, clutchSize: clutchSize)
            }
            let warnings = Array(Set(outcomes.flatMap(\.warnings))).sorted()
            if !warnings.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Health notes", systemImage: "cross.case").font(.subheadline.bold())
                    ForEach(warnings, id: \.self) { Text("• \($0)").font(.caption) }
                }
                .foregroundStyle(.orange)
                .padding(.vertical, 4)
            }
        }
    }
}

struct OutcomeRow: View {
    let outcome: CrossOutcome
    var clutchSize: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(outcome.name).font(.headline)
                    if !outcome.hets.isEmpty {
                        Text(outcome.hetsDescription).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(Percent.format(outcome.probability)).font(.headline).monospacedDigit()
                    if let clutchSize {
                        Text(String(format: "≈ %.1f of %d", outcome.expected(inClutchOf: clutchSize), clutchSize))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            ProgressView(value: outcome.probability)
                .tint(outcome.warnings.isEmpty ? Color.accentColor : .orange)
            if !outcome.warnings.isEmpty {
                Label(outcome.warnings.joined(separator: "\n"), systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
