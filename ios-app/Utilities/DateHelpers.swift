import Foundation

enum DateHelpers {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    private static let shortFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    static func todayString() -> String {
        dateFormatter.string(from: Date())
    }

    static func formatDate(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }

    static func daysAgo(_ n: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: -n, to: Date()) ?? Date()
        return dateFormatter.string(from: date)
    }

    static func date(from string: String) -> Date? {
        dateFormatter.date(from: string)
    }

    static func format(_ dateStr: String) -> String {
        guard let date = date(from: dateStr) else { return dateStr }
        return displayFormatter.string(from: date)
    }

    static func formatShort(_ dateStr: String) -> String {
        guard let date = date(from: dateStr) else { return dateStr }
        return shortFormatter.string(from: date)
    }

    static func timeAgo(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "just now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        let days = hours / 24
        if days < 7 { return "\(days)d ago" }
        return "\(days / 7)w ago"
    }

    /// Offset a "yyyy-MM-dd" date string by a number of days, returning another string.
    static func offsetDate(_ dateStr: String, days: Int) -> String {
        guard let d = date(from: dateStr),
              let offset = Calendar.current.date(byAdding: .day, value: days, to: d) else {
            return dateStr
        }
        return dateFormatter.string(from: offset)
    }

    static func greeting(for name: String) -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let first = name.components(separatedBy: " ").first ?? name
        if hour < 12 { return "Good morning, \(first)!" }
        if hour < 17 { return "Hey there, \(first)!" }
        return "Good evening, \(first)!"
    }
}
