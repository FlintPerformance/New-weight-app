import Foundation
import SwiftData

@Model
final class WeeklyCheckIn {
    var id: String
    var weekOf: String            // "YYYY-MM-DD" (Monday of the week)
    var energyLevel: Int          // 1-5
    var sleepQuality: Int         // 1-5
    var hungerRating: Int         // 1-5
    var stressLevel: Int          // 1-5
    var notes: String
    var photoPath: String?        // local file path for progress photo
    var createdAt: Date

    init(
        weekOf: String? = nil,
        energyLevel: Int = 3,
        sleepQuality: Int = 3,
        hungerRating: Int = 3,
        stressLevel: Int = 3,
        notes: String = ""
    ) {
        self.id = WeightEntry.generateId()
        self.weekOf = weekOf ?? WeeklyCheckIn.currentWeekStart()
        self.energyLevel = energyLevel
        self.sleepQuality = sleepQuality
        self.hungerRating = hungerRating
        self.stressLevel = stressLevel
        self.notes = notes
        self.createdAt = Date()
    }

    static func currentWeekStart() -> String {
        let cal = Calendar.current
        let today = Date()
        let weekday = cal.component(.weekday, from: today)
        // Monday = 2 in Calendar
        let daysToSubtract = (weekday + 5) % 7
        let monday = cal.date(byAdding: .day, value: -daysToSubtract, to: today) ?? today
        return DateHelpers.formatDate(monday)
    }
}

// MARK: - Rating Labels

extension WeeklyCheckIn {
    static func energyLabel(_ level: Int) -> String {
        switch level {
        case 1: return "Exhausted"
        case 2: return "Low"
        case 3: return "Normal"
        case 4: return "Good"
        case 5: return "Energized"
        default: return "Normal"
        }
    }

    static func sleepLabel(_ level: Int) -> String {
        switch level {
        case 1: return "Terrible"
        case 2: return "Poor"
        case 3: return "Okay"
        case 4: return "Good"
        case 5: return "Great"
        default: return "Okay"
        }
    }

    static func hungerLabel(_ level: Int) -> String {
        switch level {
        case 1: return "Never hungry"
        case 2: return "Rarely"
        case 3: return "Normal"
        case 4: return "Often"
        case 5: return "Always hungry"
        default: return "Normal"
        }
    }

    static func stressLabel(_ level: Int) -> String {
        switch level {
        case 1: return "Very calm"
        case 2: return "Relaxed"
        case 3: return "Normal"
        case 4: return "Stressed"
        case 5: return "Very stressed"
        default: return "Normal"
        }
    }

    static func emoji(for level: Int) -> String {
        switch level {
        case 1: return "😫"
        case 2: return "😕"
        case 3: return "😐"
        case 4: return "🙂"
        case 5: return "😊"
        default: return "😐"
        }
    }
}
