import SwiftUI
import SwiftData
import Charts

private extension GrowthComparison {
    var color: Color {
        switch self {
        case .below: return .orange
        case .within: return .green
        case .above: return .blue
        }
    }
}

struct ComparisonBadge: View {
    let comparison: GrowthComparison?

    var body: some View {
        if let comparison {
            Text(comparison.label)
                .font(.caption2.bold())
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(comparison.color.opacity(0.15), in: Capsule())
                .foregroundStyle(comparison.color)
        }
    }
}

enum GrowthFormat {
    static func rate(_ rate: Double) -> String {
        "\(rate >= 0 ? "+" : "−")\(Weight.format(abs(rate)))/week"
    }

    static func range(_ range: ClosedRange<Double>) -> String {
        "\(Weight.format(range.lowerBound))–\(Weight.format(range.upperBound))"
    }
}

/// Weight against age over the species' typical range; weight over time without a hatch date.
struct GrowthChart: View {
    let snake: Snake
    let report: GrowthReport

    private struct BandPoint: Identifiable {
        let months: Double
        let low: Double
        let high: Double
        var id: Double { months }
    }

    private struct AgePoint: Identifiable {
        let months: Double
        let grams: Double
        var id: Double { months }
    }

    private var maxMonths: Double {
        let last = max(report.points.map(\.months).max() ?? 0, report.ageMonths ?? 0)
        return max(6, (last * 1.15).rounded(.up))
    }

    private var band: [BandPoint] {
        guard let guide = report.guide, let end = guide.curve.last?.months else { return [] }
        let limit = min(maxMonths, end)
        return (0...48).compactMap { i in
            let m = limit * Double(i) / 48
            return guide.reference(atMonths: m).map { BandPoint(months: m, low: $0.lowerBound, high: $0.upperBound) }
        }
    }

    var body: some View {
        if snake.hatchDate == nil || report.points.isEmpty {
            if snake.weightLogs.count > 1 { WeightChart(entries: snake.weightLogs) }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text(band.isEmpty ? "Weight by age" : "Weight by age · shaded: typical range")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Chart {
                    ForEach(band) { point in
                        AreaMark(x: .value("Age (months)", point.months),
                                 yStart: .value("Low", point.low),
                                 yEnd: .value("High", point.high))
                            .foregroundStyle(Color.accentColor.opacity(0.15))
                    }
                    ForEach(report.points.map { AgePoint(months: $0.months, grams: $0.grams) }) { point in
                        LineMark(x: .value("Age (months)", point.months), y: .value("Grams", point.grams))
                        PointMark(x: .value("Age (months)", point.months), y: .value("Grams", point.grams))
                    }
                }
                .chartXScale(domain: 0...maxMonths)
                .chartXAxisLabel("months")
                .frame(height: 170)
                .accessibilityLabel("Weight by age chart")
            }
            .padding(.vertical, 4)
        }
    }
}

/// Growth rows shared by the snake page and the full guide. Place inside a `Section`.
struct GrowthRows: View {
    let snake: Snake
    let report: GrowthReport

    var body: some View {
        if let grams = report.grams {
            LabeledContent("Current weight",
                           value: Weight.format(grams) + (snake.ageDescription.map { " at \($0)" } ?? ""))
        }
        if let rate = report.rate {
            LabeledContent("Growth", value: GrowthFormat.rate(rate))
        } else {
            Text("Log two weights at least two weeks apart to see the growth rate.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        if let reference = report.reference {
            LabeledContent("Typical at this age") {
                HStack {
                    Text(GrowthFormat.range(reference))
                    ComparisonBadge(comparison: report.comparison)
                }
            }
        }
        if let stage = report.stage {
            let outside = snake.feedingIntervalDays < stage.minDays || snake.feedingIntervalDays > stage.maxDays
            LabeledContent("Stage · feed", value: "\(stage.label) · \(stage.intervalDescription)"
                           + (outside ? " · you feed every \(snake.feedingIntervalDays)" : ""))
        }
        if let prey = report.prey {
            LabeledContent("Suggested prey", value: "\(GrowthFormat.range(prey)) per meal")
        }
        if let target = report.target {
            VStack(alignment: .leading, spacing: 6) {
                LabeledContent("Breeding weight") {
                    Text("\(report.grams.map { Weight.format($0) } ?? "?") / \(Weight.format(target.grams))"
                         + weeksText)
                }
                if let grams = report.grams {
                    ProgressView(value: min(1, grams / target.grams))
                }
                Text("Usual minimum: \(Weight.format(target.grams)) and about \(target.months) months old.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var weeksText: String {
        switch report.weeksToTarget {
        case 0?: return " · reached"
        case let weeks?: return " · ~\(weeks) weeks at this rate"
        case nil: return ""
        }
    }
}

struct GrowthSection: View {
    let snake: Snake

    var body: some View {
        let report = snake.growthReport
        Section("Growth") {
            GrowthChart(snake: snake, report: report)
            GrowthRows(snake: snake, report: report)
            NavigationLink {
                GrowthGuideView(snake: snake)
            } label: {
                Label("Growth Guide", systemImage: "chart.line.uptrend.xyaxis")
            }
        }
    }
}

struct GrowthGuideView: View {
    let snake: Snake
    @State private var loggingWeight = false

    var body: some View {
        let report = snake.growthReport
        List {
            Section {
                GrowthChart(snake: snake, report: report)
                GrowthRows(snake: snake, report: report)
                Button { loggingWeight = true } label: { Label("Log Weight", systemImage: "scalemass") }
            } footer: {
                if snake.hatchDate == nil {
                    Text("Add a hatch date (even an estimate) to compare weight with age.")
                }
            }
            if let guide = report.guide {
                Section("\(guide.species) Guide") {
                    LabeledContent("Hatchling weight", value: GrowthFormat.range(guide.hatchling))
                    LabeledContent("Hot spot", value: guide.hotSpot)
                    LabeledContent("Prey size", value: "\(Int(guide.preyPercent.lowerBound))–\(Int(guide.preyPercent.upperBound))% of body weight")
                    LabeledContent("Breeding ♀", value: "\(Weight.format(guide.breedingFemale.grams))+ · ~\(guide.breedingFemale.months) months")
                    LabeledContent("Breeding ♂", value: "\(Weight.format(guide.breedingMale.grams))+ · ~\(guide.breedingMale.months) months")
                }
                Section("Feeding by Size") {
                    ForEach(Array(guide.stages.enumerated()), id: \.offset) { index, stage in
                        let from = index > 0 ? guide.stages[index - 1].upTo ?? 0 : 0
                        let isCurrent = report.stage == stage
                        LabeledContent {
                            Text(stage.intervalDescription)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(stage.label + (isCurrent ? " (now)" : ""))
                                Text(stage.upTo.map { "\(Weight.format(from))–\(Weight.format($0))" } ?? "\(Weight.format(from))+")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .listRowBackground(isCurrent ? Color.accentColor.opacity(0.12) : nil)
                    }
                }
                if !guide.tips.isEmpty {
                    Section("\(guide.species) Tips") {
                        ForEach(guide.tips, id: \.self) { Text($0) }
                    }
                }
            }
            Section {
                ForEach(GrowthGuide.generalTips, id: \.self) { Text($0) }
            } header: {
                Text("Healthy Growth")
            } footer: {
                Text(report.guide == nil
                     ? "There's no growth guide for \(snake.species) yet, so only general advice is shown. These are rough hobby guidelines, not veterinary advice."
                     : "These are rough hobby guidelines, not veterinary advice. Individual snakes, lines and sexes grow at different rates.")
            }
        }
        .navigationTitle("Growth Guide")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $loggingWeight) {
            NavigationStack { LogEntryEditView(snake: snake, entry: nil, kind: .weight) }
        }
    }
}

struct GrowthOverviewView: View {
    @Query(sort: \Snake.name) private var snakes: [Snake]

    private var rows: [(snake: Snake, report: GrowthReport)] {
        func rank(_ c: GrowthComparison?) -> Int {
            switch c {
            case .below?: return 0
            case .above?: return 1
            case .within?: return 2
            case nil: return 3
            }
        }
        return snakes.filter(\.isInCollection)
            .map { (snake: $0, report: $0.growthReport) }
            .sorted { rank($0.report.comparison) < rank($1.report.comparison) }
    }

    var body: some View {
        List {
            Section {
                ForEach(rows, id: \.snake.id) { row in
                    NavigationLink {
                        GrowthGuideView(snake: row.snake)
                    } label: {
                        HStack(spacing: 12) {
                            SnakeThumbnail(photo: row.snake.coverPhoto, size: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(row.snake.name).font(.headline)
                                    ComparisonBadge(comparison: row.report.comparison)
                                }
                                Text([row.snake.species, row.snake.ageDescription,
                                      row.report.grams.map { Weight.format($0) } ?? "no weight yet"]
                                        .compactMap { $0 }.joined(separator: " · "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let rate = row.report.rate {
                                    Text(GrowthFormat.rate(rate) + targetText(row.report))
                                        .font(.caption)
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                }
            } footer: {
                Text("Snakes below the typical range for their age are listed first. Log weights in each snake's care log.")
            }
        }
        .navigationTitle("Growth Overview")
    }

    private func targetText(_ report: GrowthReport) -> String {
        switch report.weeksToTarget {
        case 0?: return " · at breeding weight"
        case let weeks?: return " · breeding weight in ~\(weeks) wk"
        case nil: return ""
        }
    }
}

struct BreedingRecordsView: View {
    @Query private var pairings: [Pairing]

    private var females: [(snake: Snake, history: FemaleHistory)] {
        var grouped: [UUID: (Snake, [Pairing])] = [:]
        for pairing in pairings {
            guard let female = pairing.female else { continue }
            grouped[female.id, default: (female, [])].1.append(pairing)
        }
        return grouped.values
            .map { (snake: $0.0, history: FemaleHistory($0.1)) }
            .sorted { $0.history.clutches != $1.history.clutches ? $0.history.clutches > $1.history.clutches : $0.snake.name < $1.snake.name }
    }

    private var clutches: [Pairing] {
        pairings.filter(\.hasClutch).sorted {
            $0.season != $1.season ? $0.season > $1.season : ($0.layDate ?? .distantPast) > ($1.layDate ?? .distantPast)
        }
    }

    var body: some View {
        let seasons = SeasonSummary.summaries(pairings)
        List {
            if seasons.isEmpty {
                ContentUnavailableView("No breeding records yet", systemImage: "oval.portrait",
                                       description: Text("Add pairings (past ones too) in the Pairings tab and fill in their clutch details."))
            }
            ForEach(seasons) { season in
                Section("\(String(season.season)) Season") {
                    HStack {
                        stat("Pairings", "\(season.pairings)")
                        stat("Clutches", "\(season.clutches)")
                        stat("Eggs", "\(season.eggs)")
                        stat("Hatched", "\(season.hatched)")
                        stat("Hatch rate", ClutchStats.percent(season.hatchRate))
                    }
                }
            }
            if !females.isEmpty {
                Section("Females") {
                    ForEach(females, id: \.snake.id) { row in
                        NavigationLink {
                            SnakeDetailView(snake: row.snake)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.snake.name).font(.headline)
                                Text(femaleSummary(row.history)).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            if !clutches.isEmpty {
                Section {
                    ForEach(clutches) { pairing in
                        NavigationLink {
                            PairingDetailView(pairing: pairing)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(String(pairing.season)) · \(pairing.title)")
                                Text(clutchSummary(pairing)).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Clutches")
                } footer: {
                    Text("To record a past season, add a pairing with that season's year, set its status to Hatched, and fill in the dates and counts.")
                }
            }
        }
        .navigationTitle("Breeding Records")
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack {
            Text(value).font(.title3.bold())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func femaleSummary(_ h: FemaleHistory) -> String {
        var parts = ["\(h.clutches) clutch\(h.clutches == 1 ? "" : "es")"]
        if let average = h.averageClutch { parts.append(String(format: "avg %.1f eggs", average)) }
        parts.append("\(h.hatched) hatched")
        if let last = h.lastClutchSeason { parts.append("last \(String(last))") }
        return parts.joined(separator: " · ")
    }

    private func clutchSummary(_ pairing: Pairing) -> String {
        let c = ClutchStats(pairing)
        var parts = ["\(c.eggs.map { "\($0)" } ?? "?") eggs"]
        if let good = c.good { parts.append("\(good) good") }
        if let hatched = c.hatched { parts.append("\(hatched) hatched (\(ClutchStats.percent(c.hatchRate)))") }
        if let days = c.incubationDays { parts.append("\(days) days") }
        if let temp = pairing.incubationTempF { parts.append(String(format: "%.1f°F", temp)) }
        if let weight = c.femaleWeight { parts.append("♀ \(Weight.format(weight))") }
        return parts.joined(separator: " · ")
    }
}
