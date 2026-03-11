import Foundation
import SwiftData

@Model
final class WeightEntry {
    var id: String
    var weight: Double
    var unit: String          // "lb" or "kg"
    var date: String          // "YYYY-MM-DD"
    var notes: String
    var isMorning: Bool
    var createdAt: Date
    var syncedAt: Date?

    init(
        weight: Double,
        unit: WeightUnit = .lb,
        date: String? = nil,
        notes: String = "",
        isMorning: Bool = false
    ) {
        self.id = Self.generateId()
        self.weight = weight
        self.unit = unit.rawValue
        self.date = date ?? DateHelpers.todayString()
        self.notes = notes
        self.isMorning = isMorning
        self.createdAt = Date()
        self.syncedAt = nil
    }

    static func generateId() -> String {
        let timestamp = String(Int(Date().timeIntervalSince1970 * 1000), radix: 36)
        let random = String(Int.random(in: 100000...999999), radix: 36)
        return "\(timestamp)\(random)"
    }
}

// MARK: - Computed helpers

extension WeightEntry {
    func weightInUnit(_ targetUnit: WeightUnit) -> Double {
        let currentUnit = WeightUnit(rawValue: unit) ?? .lb
        return WeightConverter.convert(weight, from: currentUnit, to: targetUnit)
    }

    var formattedWeight: String {
        String(format: "%.1f %@", weight, unit)
    }

    var parsedDate: Date {
        DateHelpers.date(from: date) ?? Date()
    }
}
