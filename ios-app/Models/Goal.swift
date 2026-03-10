import Foundation
import SwiftData

@Model
final class Goal {
    var id: String
    var targetWeight: Double
    var startWeight: Double
    var unit: String
    var startDate: String     // "YYYY-MM-DD"
    var targetDate: String    // "YYYY-MM-DD"
    var isActive: Bool
    var createdAt: Date

    init(
        targetWeight: Double,
        startWeight: Double,
        unit: WeightUnit = .lb,
        targetDate: String
    ) {
        self.id = WeightEntry.generateId()
        self.targetWeight = targetWeight
        self.startWeight = startWeight
        self.unit = unit.rawValue
        self.startDate = DateHelpers.todayString()
        self.targetDate = targetDate
        self.isActive = true
        self.createdAt = Date()
    }
}

// MARK: - Progress calculation

extension Goal {
    struct Progress {
        let percentage: Int
        let remaining: Double
        let direction: Direction
        let daysLeft: Int?
        let totalDays: Int?
        let daysPassed: Int?
        let ratePerWeek: Double
        let neededRatePerWeek: Double
        let paceStatus: PaceStatus
        let totalChange: Double
    }

    enum Direction: String {
        case lose, gain
    }

    enum PaceStatus: String {
        case ahead, onTrack, behind
    }

    func calculateProgress(currentWeight: Double) -> Progress {
        let total = abs(startWeight - targetWeight)
        let current = abs(startWeight - currentWeight)
        let pct = total == 0 ? 100 : min(100, Int((current / total) * 100))
        let remaining = targetWeight - currentWeight
        let direction: Direction = targetWeight < startWeight ? .lose : .gain

        let startMs = DateHelpers.date(from: startDate)?.timeIntervalSince1970 ?? 0
        let targetMs = DateHelpers.date(from: targetDate)?.timeIntervalSince1970 ?? 0
        let now = Date().timeIntervalSince1970

        let daysLeft = max(0, Int(ceil((targetMs - now) / 86400)))
        let totalDays = max(1, Int(ceil((targetMs - startMs) / 86400)))
        let daysPassed = min(totalDays, Int(ceil((now - startMs) / 86400)))

        let daysActive = max(1, daysPassed)
        let ratePerDay = Double(daysActive) > 0 ? current / Double(daysActive) : 0
        let ratePerWeek = ratePerDay * 7
        let neededRatePerDay = daysLeft > 0 ? abs(remaining) / Double(daysLeft) : 0
        let neededRatePerWeek = neededRatePerDay * 7

        var paceStatus: PaceStatus = .onTrack
        if neededRatePerWeek > 0 && ratePerWeek > 0 {
            let ratio = ratePerWeek / neededRatePerWeek
            if ratio >= 1.15 { paceStatus = .ahead }
            else if ratio <= 0.85 { paceStatus = .behind }
        }

        return Progress(
            percentage: pct,
            remaining: remaining,
            direction: direction,
            daysLeft: daysLeft,
            totalDays: totalDays,
            daysPassed: daysPassed,
            ratePerWeek: ratePerWeek,
            neededRatePerWeek: neededRatePerWeek,
            paceStatus: paceStatus,
            totalChange: total
        )
    }
}
