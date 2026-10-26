import Foundation

/// Clutch and breeding-history figures. Mirrors web/js/breeding.js.
struct ClutchStats {
    let eggs: Int?
    let good: Int?
    let hatched: Int?
    let fertileRate: Double?
    /// Measured against good eggs when known.
    let hatchRate: Double?
    let incubationDays: Int?
    /// The female's latest weighing on or before the pairing started.
    let femaleWeight: Double?

    init(_ pairing: Pairing) {
        eggs = pairing.eggCount
        good = pairing.fertileEggCount
        hatched = pairing.hatchedCount
        fertileRate = Self.ratio(good, eggs)
        hatchRate = Self.ratio(hatched, good ?? eggs)
        if let lay = pairing.layDate, let hatch = pairing.hatchDate {
            incubationDays = Int((hatch.timeIntervalSince(lay) / 86400).rounded())
        } else {
            incubationDays = nil
        }
        let start = pairing.introducedDate ?? pairing.layDate
        femaleWeight = start.flatMap { start in
            pairing.female?.weightLogs.first { $0.date <= start }?.grams
        }
    }

    static func ratio(_ a: Int?, _ b: Int?) -> Double? {
        guard let a, let b, b > 0 else { return nil }
        return Double(a) / Double(b)
    }

    static func percent(_ value: Double?) -> String {
        value.map { "\(Int(($0 * 100).rounded()))%" } ?? "–"
    }
}

extension Pairing {
    var hasClutch: Bool { layDate != nil || eggCount != nil }
}

struct SeasonSummary: Identifiable {
    let season: Int
    var pairings = 0
    var clutches = 0
    var eggs = 0
    var good = 0
    var hatched = 0

    var id: Int { season }
    var hatchRate: Double? { good > 0 ? Double(hatched) / Double(good) : nil }

    /// Totals per season, newest first.
    static func summaries(_ pairings: [Pairing]) -> [SeasonSummary] {
        var bySeason: [Int: SeasonSummary] = [:]
        for p in pairings {
            var s = bySeason[p.season] ?? SeasonSummary(season: p.season)
            s.pairings += 1
            if p.hasClutch { s.clutches += 1 }
            s.eggs += p.eggCount ?? 0
            s.good += p.fertileEggCount ?? p.eggCount ?? 0
            s.hatched += p.hatchedCount ?? 0
            bySeason[p.season] = s
        }
        return bySeason.values.sorted { $0.season > $1.season }
    }
}

struct FemaleHistory {
    let pairings: Int
    let clutches: Int
    let eggs: Int
    let hatched: Int
    let lastClutchSeason: Int?

    var averageClutch: Double? { clutches > 0 ? Double(eggs) / Double(clutches) : nil }

    init(_ pairings: [Pairing]) {
        let clutches = pairings.filter(\.hasClutch)
        self.pairings = pairings.count
        self.clutches = clutches.count
        eggs = clutches.reduce(0) { $0 + ($1.eggCount ?? 0) }
        hatched = clutches.reduce(0) { $0 + ($1.hatchedCount ?? 0) }
        lastClutchSeason = clutches.map(\.season).max()
    }
}

extension Snake {
    var weighings: [Weighing] {
        weightLogs.compactMap { entry in entry.grams.map { Weighing(date: entry.date, grams: $0) } }
    }

    var growthReport: GrowthReport {
        GrowthReport(species: species,
                     isFemale: sex == .female ? true : sex == .male ? false : nil,
                     hatchDate: hatchDate,
                     currentWeight: weightGrams,
                     weighings: weighings)
    }
}
