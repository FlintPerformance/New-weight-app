import SwiftUI
import SwiftData
import Combine

@MainActor
class WeightViewModel: ObservableObject {
    @Published var weights: [WeightEntry] = []
    @Published var isLoading = false

    private var modelContext: ModelContext?

    func configure(context: ModelContext) {
        self.modelContext = context
        fetchWeights()
    }

    // MARK: - CRUD

    func addWeight(_ value: Double, unit: WeightUnit, date: String, notes: String = "", isMorning: Bool = false) throws {
        guard let context = modelContext else { return }
        guard WeightConverter.isValid(value, unit: unit) else {
            throw WeightError.invalidWeight
        }

        let entry = WeightEntry(weight: value, unit: unit, date: date, notes: notes, isMorning: isMorning)
        context.insert(entry)
        try context.save()
        fetchWeights()
    }

    func updateWeight(_ entry: WeightEntry, weight: Double? = nil, notes: String? = nil) throws {
        guard let context = modelContext else { return }
        if let weight { entry.weight = weight }
        if let notes { entry.notes = notes }
        try context.save()
        fetchWeights()
    }

    func deleteWeight(_ entry: WeightEntry) throws {
        guard let context = modelContext else { return }
        context.delete(entry)
        try context.save()
        fetchWeights()
    }

    // MARK: - Queries

    func fetchWeights() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<WeightEntry>(
            sortBy: [SortDescriptor(\.date, order: .reverse), SortDescriptor(\.createdAt, order: .reverse)]
        )
        weights = (try? context.fetch(descriptor)) ?? []
    }

    func weightsInRange(days: Int?) -> [WeightEntry] {
        guard let days else { return weights }
        let cutoff = DateHelpers.daysAgo(days)
        return weights.filter { $0.date >= cutoff }
    }

    // MARK: - Computed stats

    var latest: WeightEntry? { weights.first }

    var streak: Int {
        guard !weights.isEmpty else { return 0 }

        let uniqueDates = Array(Set(weights.map(\.date))).sorted(by: >)
        guard !uniqueDates.isEmpty else { return 0 }

        let today = DateHelpers.todayString()
        let yesterday = DateHelpers.daysAgo(1)
        guard uniqueDates[0] == today || uniqueDates[0] == yesterday else { return 0 }

        var count = 1
        for i in 1..<uniqueDates.count {
            guard let prev = DateHelpers.date(from: uniqueDates[i - 1]),
                  let curr = DateHelpers.date(from: uniqueDates[i]) else { break }
            let diff = Calendar.current.dateComponents([.day], from: curr, to: prev).day ?? 0
            if diff == 1 { count += 1 }
            else { break }
        }
        return count
    }

    func weightChange(days: Int) -> (change: Double, percent: Double)? {
        let cutoff = DateHelpers.daysAgo(days)
        let filtered = weights.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }
        guard filtered.count >= 2 else { return nil }
        let first = filtered.first!.weight
        let last = filtered.last!.weight
        let change = last - first
        return (change: change, percent: (change / first) * 100)
    }

    func movingAverage(entries: [WeightEntry], window: Int = 7) -> [(date: String, weight: Double, average: Double)] {
        let sorted = entries.sorted { $0.date < $1.date }
        return sorted.enumerated().map { i, entry in
            let start = max(0, i - window + 1)
            let slice = sorted[start...i]
            let avg = slice.map(\.weight).reduce(0, +) / Double(slice.count)
            return (date: entry.date, weight: entry.weight, average: avg)
        }
    }

    var hasMorningWeightToday: Bool {
        let today = DateHelpers.todayString()
        return weights.contains { $0.date == today && $0.isMorning }
    }
}

enum WeightError: LocalizedError {
    case invalidWeight

    var errorDescription: String? {
        switch self {
        case .invalidWeight: return "Weight is out of valid range"
        }
    }
}
