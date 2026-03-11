import Foundation

/// Central engine for computing advanced weight tracking insights:
/// predicted goal date, consistency score, weight variance, milestones, rate alerts.
enum InsightsEngine {

    // MARK: - Predicted Goal Date

    /// Projects when the user will reach their goal weight based on current EMA rate.
    /// Returns nil if there's no clear trend or the goal is already reached.
    static func predictedGoalDate(
        weights: [(date: String, weight: Double)],
        goal: (target: Double, start: Double)
    ) -> (date: Date, daysAway: Int, ratePerWeek: Double)? {
        // Need at least 7 days of data for a meaningful projection
        guard weights.count >= 3 else { return nil }

        let emaValues = WeightViewModel.ema(data: weights)
        guard emaValues.count >= 2 else { return nil }

        // Use the last 7 EMA points (or fewer) to compute rate
        let recentEma = Array(emaValues.suffix(min(7, emaValues.count)))
        guard let firstEma = recentEma.first,
              let lastEma = recentEma.last,
              let firstDate = DateHelpers.date(from: firstEma.date),
              let lastDate = DateHelpers.date(from: lastEma.date) else { return nil }

        let daysBetween = Calendar.current.dateComponents([.day], from: firstDate, to: lastDate).day ?? 0
        guard daysBetween > 0 else { return nil }

        let ratePerDay = (lastEma.ema - firstEma.ema) / Double(daysBetween)
        guard abs(ratePerDay) > 0.001 else { return nil }  // Essentially flat

        let direction: Double = goal.target < goal.start ? -1 : 1
        // If rate is in wrong direction, can't project
        guard ratePerDay * direction > 0 || abs(lastEma.ema - goal.target) < abs(ratePerDay) else {
            // Rate is wrong direction — no projection
            return nil
        }

        let remaining = goal.target - lastEma.ema
        let daysToGoal = Int(ceil(remaining / ratePerDay))

        guard daysToGoal > 0, daysToGoal < 3650 else { return nil }  // Cap at 10 years

        let ratePerWeek = ratePerDay * 7
        let projectedDate = Calendar.current.date(byAdding: .day, value: daysToGoal, to: Date()) ?? Date()

        return (date: projectedDate, daysAway: daysToGoal, ratePerWeek: ratePerWeek)
    }

    // MARK: - Consistency Score

    /// Rolling percentage of days logged in the last N days (default 30).
    static func consistencyScore(dates: [String], window: Int = 30) -> (score: Int, daysLogged: Int, total: Int) {
        let uniqueDates = Set(dates)
        let total = window
        var daysLogged = 0

        for i in 0..<window {
            let dateStr = DateHelpers.daysAgo(i)
            if uniqueDates.contains(dateStr) {
                daysLogged += 1
            }
        }

        let score = total > 0 ? Int(round(Double(daysLogged) / Double(total) * 100)) : 0
        return (score: score, daysLogged: daysLogged, total: total)
    }

    // MARK: - Weight Variance

    /// Computes daily fluctuation stats over recent entries.
    static func weightVariance(
        weights: [(date: String, weight: Double)],
        days: Int = 7
    ) -> (range: Double, stdDev: Double, min: Double, max: Double)? {
        let cutoff = DateHelpers.daysAgo(days)
        let recent = weights.filter { $0.date >= cutoff }
        guard recent.count >= 2 else { return nil }

        let values = recent.map(\.weight)
        let lo = values.min()!
        let hi = values.max()!
        let range = hi - lo
        let mean = values.reduce(0, +) / Double(values.count)
        let sumSquares = values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +)
        let stdDev = sqrt(sumSquares / Double(values.count))

        return (range: range, stdDev: stdDev, min: lo, max: hi)
    }

    // MARK: - Milestone Detection

    enum Milestone: Equatable {
        case newLowest(Double)
        case newHighest(Double)
        case halfwayToGoal
        case goalReached
        case poundsMilestone(Int)   // Every 5 lbs / ~2 kg milestone
        case longestStreak(Int)
        case centuryClub            // 100 entries
        case entryMilestone(Int)    // 250, 500, 1000
    }

    /// Detects milestones for the latest weigh-in.
    static func detectMilestones(
        latestWeight: Double,
        previousWeights: [Double],
        streak: Int,
        longestStreak: Int,
        totalEntries: Int,
        goal: (target: Double, start: Double, direction: WeightGoalDirection)?,
        unit: WeightUnit
    ) -> [Milestone] {
        var milestones: [Milestone] = []

        // New lowest / highest weight (depending on goal)
        if let goalInfo = goal {
            switch goalInfo.direction {
            case .lose:
                if !previousWeights.isEmpty, latestWeight < (previousWeights.min() ?? .infinity) {
                    milestones.append(.newLowest(latestWeight))
                }
            case .gain:
                if !previousWeights.isEmpty, latestWeight > (previousWeights.max() ?? -.infinity) {
                    milestones.append(.newHighest(latestWeight))
                }
            }

            // Halfway to goal
            let total = abs(goalInfo.start - goalInfo.target)
            let current = abs(goalInfo.start - latestWeight)
            if total > 0 {
                let pct = current / total
                // Check if we just crossed 50%
                if let prevWeight = previousWeights.first {
                    let prevPct = abs(goalInfo.start - prevWeight) / total
                    if prevPct < 0.5 && pct >= 0.5 {
                        milestones.append(.halfwayToGoal)
                    }
                }
                // Goal reached
                if pct >= 1.0 {
                    if let prevWeight = previousWeights.first {
                        let prevPct = abs(goalInfo.start - prevWeight) / total
                        if prevPct < 1.0 {
                            milestones.append(.goalReached)
                        }
                    }
                }
            }

            // Every 5 lbs (or ~2 kg) from start
            let step: Double = unit == .kg ? 2.0 : 5.0
            let changeFromStart = abs(latestWeight - goalInfo.start)
            let milestoneCount = Int(changeFromStart / step)
            if milestoneCount > 0, let prevWeight = previousWeights.first {
                let prevChange = abs(prevWeight - goalInfo.start)
                let prevMilestoneCount = Int(prevChange / step)
                if milestoneCount > prevMilestoneCount {
                    milestones.append(.poundsMilestone(milestoneCount * Int(step)))
                }
            }
        } else {
            // No goal — just track all-time lowest
            if !previousWeights.isEmpty, latestWeight < (previousWeights.min() ?? .infinity) {
                milestones.append(.newLowest(latestWeight))
            }
        }

        // Longest streak
        if streak > longestStreak && streak >= 7 {
            milestones.append(.longestStreak(streak))
        }

        // Entry milestones
        if totalEntries == 100 { milestones.append(.centuryClub) }
        if [250, 500, 1000].contains(totalEntries) { milestones.append(.entryMilestone(totalEntries)) }

        return milestones
    }

    /// Human-readable message for a milestone.
    static func milestoneMessage(_ milestone: Milestone, unit: WeightUnit) -> (title: String, body: String) {
        switch milestone {
        case .newLowest(let w):
            return ("New Low!", "You hit \(WeightConverter.format(w, unit: unit)) — your lowest weight yet!")
        case .newHighest(let w):
            return ("New High!", "You reached \(WeightConverter.format(w, unit: unit)) — your highest weight yet!")
        case .halfwayToGoal:
            return ("Halfway There!", "You've crossed the 50% mark on your goal. Keep going!")
        case .goalReached:
            return ("Goal Reached!", "You did it! You've reached your target weight!")
        case .poundsMilestone(let lbs):
            return ("\(lbs) \(unit.rawValue) Down!", "You've changed \(lbs) \(unit.rawValue) from your start. Amazing progress!")
        case .longestStreak(let days):
            return ("New Record!", "A \(days)-day streak — your longest ever!")
        case .centuryClub:
            return ("Century Club!", "100 weigh-ins logged. You're truly committed!")
        case .entryMilestone(let n):
            return ("\(n) Entries!", "\(n) weigh-ins and counting. Incredible dedication!")
        }
    }

    // MARK: - Rate of Change Alerts

    enum RateAlert {
        case tooFast(ratePerWeek: Double)
        case plateau(weeks: Int)
    }

    /// Checks if the EMA rate is concerning.
    /// - Too fast: losing/gaining more than 2 lbs/week (or 1 kg/week)
    /// - Plateau: less than 0.1 lb/week change for 2+ weeks
    static func checkRateAlerts(
        weights: [(date: String, weight: Double)],
        unit: WeightUnit,
        goalDirection: WeightGoalDirection?
    ) -> [RateAlert] {
        var alerts: [RateAlert] = []

        let emaValues = WeightViewModel.ema(data: weights)
        guard emaValues.count >= 14 else { return alerts }

        // Compute weekly rate from last 14 days of EMA
        let recent14 = Array(emaValues.suffix(14))
        guard let first = recent14.first, let last = recent14.last,
              let firstDate = DateHelpers.date(from: first.date),
              let lastDate = DateHelpers.date(from: last.date) else { return alerts }

        let days = Calendar.current.dateComponents([.day], from: firstDate, to: lastDate).day ?? 0
        guard days > 0 else { return alerts }

        let ratePerDay = abs(last.ema - first.ema) / Double(days)
        let ratePerWeek = ratePerDay * 7

        let fastThreshold: Double = unit == .kg ? 1.0 : 2.0
        let plateauThreshold: Double = unit == .kg ? 0.05 : 0.1

        if ratePerWeek > fastThreshold {
            alerts.append(.tooFast(ratePerWeek: ratePerWeek))
        }

        if ratePerWeek < plateauThreshold {
            // Check how long the plateau has been going on
            let ema21 = Array(emaValues.suffix(min(21, emaValues.count)))
            if ema21.count >= 14 {
                let midEma = ema21[ema21.count / 2]
                let midRate = abs(last.ema - midEma.ema)
                if midRate < plateauThreshold * 3 {
                    alerts.append(.plateau(weeks: days >= 21 ? 3 : 2))
                }
            } else {
                alerts.append(.plateau(weeks: 2))
            }
        }

        return alerts
    }
}
