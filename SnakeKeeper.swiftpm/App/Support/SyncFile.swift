import Foundation
import SwiftData

/// The sync file shared with the web app (web/js/sync.js). See SYNC.md for the format.
///
/// Every record carries an id and `updatedAt`; deletions travel as tombstones. Merging keeps the
/// newest version of each record, so syncing in either direction, any number of times, converges.
struct SyncFile: Codable {
    static let format = "snakekeeper-sync"
    static let version = 1

    var format = SyncFile.format
    var version = SyncFile.version
    var app = "ios"
    var exportedAt = Date()
    var customGenes: [CustomGeneDTO] = []
    var snakes: [SnakeDTO] = []
    var feedings: [FeedingDTO] = []
    var logs: [LogDTO] = []
    var concerns: [ConcernDTO] = []
    var photos: [PhotoDTO] = []
    var pairings: [PairingDTO] = []
    var deleted: [TombstoneDTO] = []
    var profile: ProfileDTO?

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        format = try c.decode(String.self, forKey: .format)
        version = try c.decode(Int.self, forKey: .version)
        app = try c.decodeIfPresent(String.self, forKey: .app) ?? ""
        exportedAt = try c.decodeIfPresent(Date.self, forKey: .exportedAt) ?? .now
        customGenes = try c.decodeIfPresent([CustomGeneDTO].self, forKey: .customGenes) ?? []
        snakes = try c.decodeIfPresent([SnakeDTO].self, forKey: .snakes) ?? []
        feedings = try c.decodeIfPresent([FeedingDTO].self, forKey: .feedings) ?? []
        logs = try c.decodeIfPresent([LogDTO].self, forKey: .logs) ?? []
        concerns = try c.decodeIfPresent([ConcernDTO].self, forKey: .concerns) ?? []
        photos = try c.decodeIfPresent([PhotoDTO].self, forKey: .photos) ?? []
        pairings = try c.decodeIfPresent([PairingDTO].self, forKey: .pairings) ?? []
        deleted = try c.decodeIfPresent([TombstoneDTO].self, forKey: .deleted) ?? []
        profile = try? c.decodeIfPresent(ProfileDTO.self, forKey: .profile)
    }
}

// MARK: - Records (field names match the web app)

protocol SyncDTO: Codable {
    var id: String { get }
    var updatedAt: Date { get }
}

struct TraitDTO: Codable {
    var geneID: String
    var zygosity: String
    var probability: Double?

    init(_ trait: TraitEntry) {
        geneID = trait.geneID
        switch trait.zygosity {
        case .single: zygosity = "single"
        case .double: zygosity = "double"
        case .possibleHet(let p):
            zygosity = "possibleHet"
            probability = p
        }
    }

    var trait: TraitEntry? {
        switch zygosity {
        case "single": return TraitEntry(geneID: geneID, zygosity: .single)
        case "double": return TraitEntry(geneID: geneID, zygosity: .double)
        case "possibleHet": return TraitEntry(geneID: geneID, zygosity: .possibleHet(probability ?? 0.5))
        default: return nil
        }
    }
}

struct SnakeDTO: SyncDTO {
    var id: String
    var updatedAt: Date
    var createdAt: Date?
    var name: String
    var species: String
    var sex: String
    var hatchDate: Date?
    var hatchDateIsEstimate: Bool?
    var origin: String
    var originDetails: String?
    var acquiredDate: Date?
    var weightGrams: Double?
    var feedingIntervalDays: Int?
    var traits: [TraitDTO]?
    var notes: String?
    var status: String?
    var statusNote: String?
    var enclosure: String?
    var damID: String?
    var sireID: String?
}

struct FeedingDTO: SyncDTO {
    var id: String
    var updatedAt: Date
    var snakeID: String
    var date: Date
    var preyType: String
    var preySize: String
    var preyState: String
    var preyCount: Int?
    var preyWeightGrams: Double?
    var refused: Bool?
    var notes: String?
}

struct LogDTO: SyncDTO {
    var id: String
    var updatedAt: Date
    var snakeID: String
    var date: Date
    var kind: String
    var grams: Double?
    var notes: String?
}

struct ProfileDTO: Codable {
    var updatedAt: Date
    var name: String?
    var business: String?
    var location: String?
    var email: String?
    var phone: String?
    var website: String?
    var social: String?
    var photo: Data?
    var defaultSpecies: String?
    var defaultFeedingInterval: Int?
    var notes: String?
}

struct ConcernDTO: SyncDTO {
    var id: String
    var updatedAt: Date
    var snakeID: String
    var title: String
    var details: String?
    var category: String
    var severity: String
    var dateNoted: Date
    var isResolved: Bool?
    var resolvedDate: Date?
    var vetVisit: Bool?
}

struct PhotoDTO: SyncDTO {
    var id: String
    var updatedAt: Date
    var snakeID: String
    var dateTaken: Date
    var caption: String?
    var isCover: Bool?
    var image: Data
    var thumbnail: Data
}

struct PairingDTO: SyncDTO {
    var id: String
    var updatedAt: Date
    var createdAt: Date?
    var femaleID: String?
    var maleID: String?
    var season: Int
    var status: String
    var introducedDate: Date?
    var lockCount: Int?
    var lastLockDate: Date?
    var ovulationDate: Date?
    var preLayShedDate: Date?
    var layDate: Date?
    var eggCount: Int?
    var fertileEggCount: Int?
    var hatchDate: Date?
    var notes: String?
}

struct CustomGeneDTO: SyncDTO {
    var id: String
    var updatedAt: Date
    var name: String
    var species: String
    var inheritance: String
    var superName: String?
    var locus: String?
    var warning: String?
}

struct TombstoneDTO: Codable {
    var id: String
    var type: String
    var deletedAt: Date
}

struct SyncSummary {
    var added = 0
    var updated = 0
    var deleted = 0
    var unchanged = 0

    var description: String {
        var parts: [String] = []
        if added > 0 { parts.append("\(added) added") }
        if updated > 0 { parts.append("\(updated) updated") }
        if deleted > 0 { parts.append("\(deleted) deleted") }
        return parts.isEmpty ? "Already up to date" : parts.joined(separator: ", ")
    }
}

enum SyncError: LocalizedError {
    case notASyncFile
    case newerVersion

    var errorDescription: String? {
        switch self {
        case .notASyncFile: return "That file isn't a SnakeKeeper sync file."
        case .newerVersion: return "This sync file is from a newer version of SnakeKeeper. Update this app first."
        }
    }
}

// MARK: - Export / merge

enum SyncService {
    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(fractionalFormatter.string(from: date))
        }
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            if let date = fractionalFormatter.date(from: text) ?? plainFormatter.date(from: text) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Bad date \(text)"))
        }
        return decoder
    }

    private static let fractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let plainFormatter = ISO8601DateFormatter()

    static func export(from context: ModelContext) throws -> Data {
        var file = SyncFile()
        file.customGenes = try context.fetch(FetchDescriptor<CustomGene>()).map {
            CustomGeneDTO(id: $0.id.uuidString, updatedAt: $0.updatedAt, name: $0.name, species: $0.species,
                          inheritance: $0.inheritanceRaw, superName: $0.superName, locus: $0.locus, warning: $0.warning)
        }
        file.snakes = try context.fetch(FetchDescriptor<Snake>()).map {
            SnakeDTO(id: $0.id.uuidString, updatedAt: $0.updatedAt, createdAt: $0.createdAt, name: $0.name,
                     species: $0.species, sex: $0.sexRaw, hatchDate: $0.hatchDate,
                     hatchDateIsEstimate: $0.hatchDateIsEstimate, origin: $0.originRaw, originDetails: $0.originDetails,
                     acquiredDate: $0.acquiredDate, weightGrams: $0.weightGrams,
                     feedingIntervalDays: $0.feedingIntervalDays, traits: $0.traits.map(TraitDTO.init), notes: $0.notes,
                     status: $0.statusRaw, statusNote: $0.statusNote, enclosure: $0.enclosure,
                     damID: $0.damID?.uuidString, sireID: $0.sireID?.uuidString)
        }
        file.logs = try context.fetch(FetchDescriptor<LogEntry>()).compactMap { l in
            guard let snake = l.snake else { return nil }
            return LogDTO(id: l.id.uuidString, updatedAt: l.updatedAt, snakeID: snake.id.uuidString, date: l.date,
                          kind: l.kindRaw, grams: l.grams, notes: l.notes)
        }
        if let p = try context.fetch(FetchDescriptor<BreederProfile>()).first {
            file.profile = ProfileDTO(updatedAt: p.updatedAt, name: p.name, business: p.business, location: p.location,
                                      email: p.email, phone: p.phone, website: p.website, social: p.social,
                                      photo: p.photoData, defaultSpecies: p.defaultSpecies,
                                      defaultFeedingInterval: p.defaultFeedingInterval, notes: p.notes)
        }
        file.feedings = try context.fetch(FetchDescriptor<FeedingRecord>()).compactMap { r in
            guard let snake = r.snake else { return nil }
            return FeedingDTO(id: r.id.uuidString, updatedAt: r.updatedAt, snakeID: snake.id.uuidString, date: r.date,
                              preyType: r.preyType, preySize: r.preySize, preyState: r.preyState, preyCount: r.preyCount,
                              preyWeightGrams: r.preyWeightGrams, refused: r.refused, notes: r.notes)
        }
        file.concerns = try context.fetch(FetchDescriptor<Concern>()).compactMap { c in
            guard let snake = c.snake else { return nil }
            return ConcernDTO(id: c.id.uuidString, updatedAt: c.updatedAt, snakeID: snake.id.uuidString, title: c.title,
                              details: c.details, category: c.category, severity: c.severityRaw, dateNoted: c.dateNoted,
                              isResolved: c.isResolved, resolvedDate: c.resolvedDate, vetVisit: c.vetVisit)
        }
        file.photos = try context.fetch(FetchDescriptor<SnakePhoto>()).compactMap { p in
            guard let snake = p.snake else { return nil }
            return PhotoDTO(id: p.id.uuidString, updatedAt: p.updatedAt, snakeID: snake.id.uuidString,
                            dateTaken: p.dateTaken, caption: p.caption, isCover: p.isCover,
                            image: p.imageData, thumbnail: p.thumbnailData)
        }
        file.pairings = try context.fetch(FetchDescriptor<Pairing>()).map { p in
            PairingDTO(id: p.id.uuidString, updatedAt: p.updatedAt, createdAt: p.createdAt,
                       femaleID: p.female?.id.uuidString, maleID: p.male?.id.uuidString, season: p.season,
                       status: p.statusRaw, introducedDate: p.introducedDate, lockCount: p.lockCount,
                       lastLockDate: p.lastLockDate, ovulationDate: p.ovulationDate, preLayShedDate: p.preLayShedDate,
                       layDate: p.layDate, eggCount: p.eggCount, fertileEggCount: p.fertileEggCount,
                       hatchDate: p.hatchDate, notes: p.notes)
        }
        file.deleted = try context.fetch(FetchDescriptor<DeletedRecord>()).map {
            TombstoneDTO(id: $0.recordID, type: $0.type, deletedAt: $0.deletedAt)
        }
        return try encoder().encode(file)
    }

    static func merge(_ data: Data, into context: ModelContext) throws -> SyncSummary {
        guard let header = try? JSONDecoder().decode(Header.self, from: data), header.format == SyncFile.format else {
            throw SyncError.notASyncFile
        }
        guard header.version <= SyncFile.version else { throw SyncError.newerVersion }
        let file = try decoder().decode(SyncFile.self, from: data)

        // Deletions known on either side.
        var tombstones: [UUID: Date] = [:]
        var localTombstones: [UUID: DeletedRecord] = [:]
        for record in try context.fetch(FetchDescriptor<DeletedRecord>()) {
            guard let id = UUID(uuidString: record.recordID) else { continue }
            localTombstones[id] = record
            tombstones[id] = max(tombstones[id] ?? .distantPast, record.deletedAt)
        }
        for incoming in file.deleted {
            guard let id = UUID(uuidString: incoming.id) else { continue }
            if let existing = localTombstones[id] {
                if incoming.deletedAt > existing.deletedAt { existing.deletedAt = incoming.deletedAt }
            } else {
                let record = DeletedRecord(recordID: id.uuidString, type: incoming.type, deletedAt: incoming.deletedAt)
                context.insert(record)
                localTombstones[id] = record
            }
            tombstones[id] = max(tombstones[id] ?? .distantPast, incoming.deletedAt)
        }

        var summary = SyncSummary()

        /// Adds or updates records of one type, then removes local ones with a newer tombstone.
        func mergeRecords<Model: Syncable, DTO: SyncDTO>(
            _ incoming: [DTO], make: (DTO) -> Model?, apply: (DTO, Model) -> Void
        ) throws -> [UUID: Model] {
            var local: [UUID: Model] = [:]
            for model in try context.fetch(FetchDescriptor<Model>()) { local[model.id] = model }
            for dto in incoming {
                guard let id = UUID(uuidString: dto.id) else { continue }
                if let deletedAt = tombstones[id], deletedAt >= dto.updatedAt { continue }
                if let model = local[id] {
                    guard dto.updatedAt > model.updatedAt else { summary.unchanged += 1; continue }
                    apply(dto, model)
                    model.updatedAt = dto.updatedAt
                    summary.updated += 1
                } else if let model = make(dto) {
                    model.id = id
                    context.insert(model)
                    apply(dto, model)
                    model.updatedAt = dto.updatedAt
                    local[id] = model
                    summary.added += 1
                }
            }
            for (id, model) in local {
                if let deletedAt = tombstones[id], deletedAt >= model.updatedAt {
                    context.delete(model)
                    local[id] = nil
                    summary.deleted += 1
                }
            }
            return local
        }

        _ = try mergeRecords(file.customGenes, make: { CustomGene(name: $0.name, species: $0.species, inheritance: .recessive) }) { dto, gene in
            gene.name = dto.name
            gene.species = dto.species
            gene.inheritanceRaw = dto.inheritance
            gene.superName = dto.superName ?? ""
            gene.locus = dto.locus ?? ""
            gene.warning = dto.warning ?? ""
        }

        let snakes: [UUID: Snake] = try mergeRecords(file.snakes, make: { Snake(name: $0.name, species: $0.species, sex: .unknown) }) { dto, snake in
            snake.name = dto.name
            snake.species = dto.species
            snake.sexRaw = dto.sex
            snake.hatchDate = dto.hatchDate
            snake.hatchDateIsEstimate = dto.hatchDateIsEstimate ?? false
            snake.originRaw = dto.origin
            snake.originDetails = dto.originDetails ?? ""
            snake.acquiredDate = dto.acquiredDate
            snake.weightGrams = dto.weightGrams
            snake.feedingIntervalDays = dto.feedingIntervalDays ?? 7
            snake.traits = (dto.traits ?? []).compactMap(\.trait)
            snake.notes = dto.notes ?? ""
            snake.statusRaw = dto.status ?? SnakeStatus.active.rawValue
            snake.statusNote = dto.statusNote ?? ""
            snake.enclosure = dto.enclosure ?? ""
            snake.damID = dto.damID.flatMap(UUID.init(uuidString:))
            snake.sireID = dto.sireID.flatMap(UUID.init(uuidString:))
            if let createdAt = dto.createdAt { snake.createdAt = createdAt }
        }
        let snake = { (id: String?) in id.flatMap(UUID.init(uuidString:)).flatMap { snakes[$0] } }

        _ = try mergeRecords(file.feedings, make: { dto -> FeedingRecord? in
            snake(dto.snakeID) == nil ? nil : FeedingRecord(date: dto.date, preyType: dto.preyType, preySize: dto.preySize, preyState: dto.preyState)
        }) { dto, record in
            record.snake = snake(dto.snakeID)
            record.date = dto.date
            record.preyType = dto.preyType
            record.preySize = dto.preySize
            record.preyState = dto.preyState
            record.preyCount = dto.preyCount ?? 1
            record.preyWeightGrams = dto.preyWeightGrams
            record.refused = dto.refused ?? false
            record.notes = dto.notes ?? ""
        }

        _ = try mergeRecords(file.logs, make: { dto -> LogEntry? in
            snake(dto.snakeID) == nil ? nil : LogEntry(date: dto.date, kind: .note)
        }) { dto, entry in
            entry.snake = snake(dto.snakeID)
            entry.date = dto.date
            entry.kindRaw = dto.kind
            entry.grams = dto.grams
            entry.notes = dto.notes ?? ""
        }

        _ = try mergeRecords(file.concerns, make: { dto -> Concern? in
            snake(dto.snakeID) == nil ? nil : Concern(title: dto.title)
        }) { dto, concern in
            concern.snake = snake(dto.snakeID)
            concern.title = dto.title
            concern.details = dto.details ?? ""
            concern.category = dto.category
            concern.severityRaw = dto.severity
            concern.dateNoted = dto.dateNoted
            concern.isResolved = dto.isResolved ?? false
            concern.resolvedDate = dto.resolvedDate
            concern.vetVisit = dto.vetVisit ?? false
        }

        _ = try mergeRecords(file.photos, make: { dto -> SnakePhoto? in
            snake(dto.snakeID) == nil ? nil : SnakePhoto(imageData: dto.image, thumbnailData: dto.thumbnail)
        }) { dto, photo in
            photo.snake = snake(dto.snakeID)
            photo.imageData = dto.image
            photo.thumbnailData = dto.thumbnail
            photo.dateTaken = dto.dateTaken
            photo.caption = dto.caption ?? ""
            photo.isCover = dto.isCover ?? false
        }

        _ = try mergeRecords(file.pairings, make: { Pairing(female: nil, male: nil, season: $0.season) }) { dto, pairing in
            pairing.female = snake(dto.femaleID)
            pairing.male = snake(dto.maleID)
            pairing.season = dto.season
            pairing.statusRaw = dto.status
            pairing.introducedDate = dto.introducedDate
            pairing.lockCount = dto.lockCount ?? 0
            pairing.lastLockDate = dto.lastLockDate
            pairing.ovulationDate = dto.ovulationDate
            pairing.preLayShedDate = dto.preLayShedDate
            pairing.layDate = dto.layDate
            pairing.eggCount = dto.eggCount
            pairing.fertileEggCount = dto.fertileEggCount
            pairing.hatchDate = dto.hatchDate
            pairing.notes = dto.notes ?? ""
            if let createdAt = dto.createdAt { pairing.createdAt = createdAt }
        }

        // The breeder profile is a single record: newest wins.
        if let incoming = file.profile {
            let existing = try context.fetch(FetchDescriptor<BreederProfile>()).first
            if existing == nil || incoming.updatedAt > existing!.updatedAt {
                let profile = existing ?? BreederProfile()
                if existing == nil { context.insert(profile) }
                profile.name = incoming.name ?? ""
                profile.business = incoming.business ?? ""
                profile.location = incoming.location ?? ""
                profile.email = incoming.email ?? ""
                profile.phone = incoming.phone ?? ""
                profile.website = incoming.website ?? ""
                profile.social = incoming.social ?? ""
                profile.photoData = incoming.photo
                profile.defaultSpecies = incoming.defaultSpecies ?? profile.defaultSpecies
                profile.defaultFeedingInterval = incoming.defaultFeedingInterval ?? profile.defaultFeedingInterval
                profile.notes = incoming.notes ?? ""
                profile.updatedAt = incoming.updatedAt
                summary.updated += 1
            }
        }

        // Keep each snake's current weight in step with its newest logged weight.
        for snake in snakes.values { snake.syncWeightFromLog() }

        Persistence.shared.save(context, stamp: false)
        return summary
    }

    private struct Header: Decodable {
        var format: String
        var version: Int
    }
}
