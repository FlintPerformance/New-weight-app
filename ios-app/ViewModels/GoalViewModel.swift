import SwiftUI
import SwiftData

@MainActor
class GoalViewModel: ObservableObject {
    @Published var goals: [Goal] = []

    private var modelContext: ModelContext?

    func configure(context: ModelContext) {
        self.modelContext = context
        fetchGoals()
    }

    var activeGoal: Goal? {
        goals.first { $0.isActive }
    }

    func fetchGoals() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<Goal>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        goals = (try? context.fetch(descriptor)) ?? []
    }

    func createGoal(targetWeight: Double, startWeight: Double, unit: WeightUnit, targetDate: String) throws {
        guard let context = modelContext else { return }

        // Deactivate existing active goal
        if let existing = activeGoal {
            existing.isActive = false
        }

        let goal = Goal(targetWeight: targetWeight, startWeight: startWeight, unit: unit, targetDate: targetDate)
        context.insert(goal)
        try context.save()
        fetchGoals()
    }

    func removeGoal(_ goal: Goal) throws {
        guard let context = modelContext else { return }
        context.delete(goal)
        try context.save()
        fetchGoals()
    }

    // MARK: - Milestones

    struct Milestone {
        let percentage: Int
        let label: String
        let icon: String
        let reached: Bool
    }

    func milestones(currentProgress: Int, totalChange: Double, unit: WeightUnit) -> [Milestone] {
        var items: [(pct: Int, label: String, icon: String)] = [
            (25, "Quarter way there!", "🏁"),
            (50, "Halfway — amazing!", "⚡"),
            (75, "Almost there!", "🔥"),
            (90, "So close!", "🎯"),
            (100, "You did it!", "🏆"),
        ]

        if totalChange >= 10 {
            let pct = Int(((totalChange - 5) / totalChange) * 100)
            items.append((pct, "5 \(unit.rawValue) to go", "💪"))
        }

        return items
            .sorted { $0.pct < $1.pct }
            .map { Milestone(percentage: $0.pct, label: $0.label, icon: $0.icon, reached: currentProgress >= $0.pct) }
    }
}
