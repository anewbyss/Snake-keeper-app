import Foundation

/// Turns the collection into spreadsheet tabs.
struct SpreadsheetExport {
    let snakes: [Snake]
    let pairings: [Pairing]
    let catalog: GeneCatalog

    var worksheets: [Worksheet] {
        [snakesSheet, feedingsSheet, concernsSheet, pairingsSheet]
    }

    /// Writes an .xlsx to a temporary file and returns its URL.
    func writeWorkbook() throws -> URL {
        let url = Self.exportDirectory().appendingPathComponent("SnakeKeeper \(Self.stamp()).xlsx")
        try XLSXWriter.data(for: worksheets).write(to: url, options: .atomic)
        return url
    }

    /// Writes one CSV per tab and returns their URLs.
    func writeCSVs() throws -> [URL] {
        let directory = Self.exportDirectory()
        return try worksheets.map { sheet in
            let url = directory.appendingPathComponent("SnakeKeeper \(sheet.name) \(Self.stamp()).csv")
            try Data(XLSXWriter.csv(for: sheet).utf8).write(to: url, options: .atomic)
            return url
        }
    }

    // MARK: Sheets

    private var sortedSnakes: [Snake] {
        snakes.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var snakesSheet: Worksheet {
        Worksheet(
            name: "Snakes",
            columns: ["Name", "Species", "Sex", "Morph", "Hatch date", "Hatch date estimated", "Age",
                      "Origin", "Origin details", "Acquired", "Weight (g)", "Feed every (days)",
                      "Last meal", "Last meal prey", "Days since meal", "Feeding status",
                      "Open concerns", "Photos", "Notes"],
            rows: sortedSnakes.map { snake in
                [
                    .text(snake.name),
                    .text(snake.species),
                    .text(snake.sex.displayName),
                    .text(catalog.describe(snake.traits)),
                    date(snake.hatchDate),
                    snake.hatchDate == nil ? .empty : .text(snake.hatchDateIsEstimate ? "Yes" : "No"),
                    text(snake.ageDescription),
                    .text(snake.origin.displayName),
                    .text(snake.originDetails),
                    date(snake.acquiredDate),
                    number(snake.weightGrams),
                    .number(Double(snake.feedingIntervalDays)),
                    date(snake.lastMeal?.date),
                    text(snake.lastMeal?.summary),
                    number(snake.daysSinceLastMeal.map { Double($0) }),
                    .text(snake.feedingStatus.label),
                    .text(snake.openConcerns.map(\.title).joined(separator: "; ")),
                    .number(Double(snake.photos.count)),
                    .text(snake.notes),
                ]
            }
        )
    }

    private var feedingsSheet: Worksheet {
        let rows = sortedSnakes.flatMap { snake in
            snake.feedings.sorted { $0.date > $1.date }.map { record -> [Cell] in
                [
                    .text(snake.name),
                    .date(record.date),
                    .text(record.refused ? "Refused" : "Ate"),
                    .text(record.preyType),
                    .text(record.preySize),
                    .text(record.preyState),
                    .number(Double(record.preyCount)),
                    number(record.preyWeightGrams),
                    .text(record.notes),
                ]
            }
        }
        return Worksheet(
            name: "Feedings",
            columns: ["Snake", "Date", "Result", "Prey", "Size", "Offered", "Count", "Prey weight (g)", "Notes"],
            rows: rows
        )
    }

    private var concernsSheet: Worksheet {
        let rows = sortedSnakes.flatMap { snake in
            snake.concerns.sorted { $0.dateNoted > $1.dateNoted }.map { concern -> [Cell] in
                [
                    .text(snake.name),
                    .text(concern.title),
                    .text(concern.category),
                    .text(concern.severity.rawValue),
                    .date(concern.dateNoted),
                    .text(concern.isResolved ? "Resolved" : "Open"),
                    date(concern.resolvedDate),
                    .text(concern.vetVisit ? "Yes" : "No"),
                    .text(concern.details),
                ]
            }
        }
        return Worksheet(
            name: "Concerns",
            columns: ["Snake", "Concern", "Category", "Severity", "Noticed", "Status", "Resolved on",
                      "Vet visit", "Details"],
            rows: rows
        )
    }

    private var pairingsSheet: Worksheet {
        let rows = pairings
            .sorted { ($0.season, $0.createdAt) > ($1.season, $1.createdAt) }
            .map { pairing -> [Cell] in
                [
                    .number(Double(pairing.season)),
                    text(pairing.female?.name),
                    text(pairing.female.map { catalog.describe($0.traits) }),
                    text(pairing.male?.name),
                    text(pairing.male.map { catalog.describe($0.traits) }),
                    .text(pairing.species),
                    .text(pairing.status.rawValue),
                    date(pairing.introducedDate),
                    .number(Double(pairing.lockCount)),
                    date(pairing.lastLockDate),
                    date(pairing.ovulationDate),
                    date(pairing.preLayShedDate),
                    date(pairing.layDate),
                    number(pairing.eggCount.map { Double($0) }),
                    number(pairing.fertileEggCount.map { Double($0) }),
                    date(pairing.estimatedHatchDate),
                    date(pairing.hatchDate),
                    .text(pairing.notes),
                ]
            }
        return Worksheet(
            name: "Pairings",
            columns: ["Season", "Female", "Female morph", "Male", "Male morph", "Species", "Status",
                      "Introduced", "Locks", "Last lock", "Ovulation", "Pre-lay shed", "Laid / born",
                      "Eggs", "Good eggs", "Est. hatch", "Hatched", "Notes"],
            rows: rows
        )
    }

    // MARK: Helpers

    private func date(_ value: Date?) -> Cell { value.map(Cell.date) ?? .empty }
    private func number(_ value: Double?) -> Cell { value.map(Cell.number) ?? .empty }
    private func text(_ value: String?) -> Cell { value.map(Cell.text) ?? .empty }

    private static func stamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: .now)
    }

    private static func exportDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Export", isDirectory: true)
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
