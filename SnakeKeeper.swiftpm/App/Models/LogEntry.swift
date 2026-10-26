import Foundation
import SwiftData

enum LogKind: String, CaseIterable, Identifiable {
    case shed, weight, cleaning, medication, note

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .shed: return "Shed"
        case .weight: return "Weight"
        case .cleaning: return "Enclosure cleaned"
        case .medication: return "Medication / treatment"
        case .note: return "Note"
        }
    }

    var shortName: String {
        switch self {
        case .cleaning: return "Cleaned"
        case .medication: return "Meds"
        default: return displayName
        }
    }

    var systemImage: String {
        switch self {
        case .shed: return "sparkles"
        case .weight: return "scalemass"
        case .cleaning: return "bubbles.and.sparkles"
        case .medication: return "pills"
        case .note: return "note.text"
        }
    }

    var notesPrompt: String {
        switch self {
        case .shed: return "One piece? Eye caps? Stuck tail?"
        case .medication: return "Drug, dose, schedule"
        default: return "Notes"
        }
    }
}

/// Care log entry: sheds, weights, cleanings, treatments and notes.
@Model
final class LogEntry {
    var id: UUID = UUID()
    var date: Date = Date()
    var kindRaw: String = LogKind.note.rawValue
    var grams: Double?
    var notes: String = ""
    /// Last edit, for sync.
    var updatedAt: Date = Date()
    var snake: Snake?

    init(date: Date = .now, kind: LogKind, grams: Double? = nil, notes: String = "") {
        self.date = date
        self.kindRaw = kind.rawValue
        self.grams = grams
        self.notes = notes
    }

    var kind: LogKind {
        get { LogKind(rawValue: kindRaw) ?? .note }
        set { kindRaw = newValue.rawValue }
    }
}

extension LogEntry: Syncable {
    static let syncType = "logs"
}
