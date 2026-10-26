import Foundation
import SwiftUI

extension Date {
    /// Whole calendar days from `start` to `end`.
    static func daysBetween(_ start: Date, _ end: Date) -> Int {
        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: end)).day ?? 0
    }

    /// "2 yr 3 mo", "5 mo", "3 wk", "4 days".
    static func ageString(from start: Date, to end: Date = .now) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: start, to: end)
        let years = parts.year ?? 0, months = parts.month ?? 0, days = parts.day ?? 0
        if years > 0 { return months > 0 ? "\(years) yr \(months) mo" : "\(years) yr" }
        if months > 0 { return "\(months) mo" }
        if days >= 7 { return "\(days / 7) wk" }
        return days == 1 ? "1 day" : "\(max(days, 0)) days"
    }

    /// "Today", "Yesterday", "12 days ago".
    var daysAgoString: String {
        let days = Date.daysBetween(self, .now)
        switch days {
        case 0: return "Today"
        case 1: return "Yesterday"
        case ..<0: return "in \(-days) days"
        default: return "\(days) days ago"
        }
    }
}

extension FeedingStatus {
    var color: Color {
        switch self {
        case .noRecord: return .secondary
        case .fed: return .green
        case .due: return .orange
        case .overdue: return .red
        }
    }

    var label: String {
        switch self {
        case .noRecord: return "No meals logged"
        case .fed: return "Fed"
        case .due: return "Due"
        case .overdue: return "Overdue"
        }
    }
}

extension Sex {
    var color: Color {
        switch self {
        case .male: return .blue
        case .female: return .pink
        case .unknown: return .gray
        }
    }
}

enum Weight {
    static func format(_ grams: Double) -> String {
        grams >= 1000
            ? String(format: "%.2f kg", grams / 1000)
            : "\(Int(grams.rounded())) g"
    }
}
