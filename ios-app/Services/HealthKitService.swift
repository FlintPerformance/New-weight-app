import HealthKit

/// Integrates with Apple Health to read/write body mass and wellness data.
///
/// Capabilities:
/// - Auto-import weight from Apple Health (smart scale, other apps)
/// - Write logged weights back to Health
/// - Pull steps, active calories, sleep to correlate with weight trends
/// - Read body fat percentage
///
/// Setup: Add HealthKit capability in Xcode + NSHealthShareUsageDescription
/// and NSHealthUpdateUsageDescription in Info.plist.
actor HealthKitService {
    static let shared = HealthKitService()

    private let store = HKHealthStore()

    private let weightType = HKQuantityType(.bodyMass)
    private let stepsType = HKQuantityType(.stepCount)
    private let caloriesType = HKQuantityType(.activeEnergyBurned)
    private let bodyFatType = HKQuantityType(.bodyFatPercentage)

    private let readTypes: Set<HKObjectType> = [
        HKQuantityType(.bodyMass),
        HKQuantityType(.bodyMassIndex),
        HKQuantityType(.bodyFatPercentage),
        HKQuantityType(.stepCount),
        HKQuantityType(.activeEnergyBurned),
        HKCategoryType(.sleepAnalysis),
    ]
    private let writeTypes: Set<HKSampleType> = [
        HKQuantityType(.bodyMass),
    ]

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Authorization

    func requestAuthorization() async throws {
        guard isAvailable else { return }
        try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
    }

    // MARK: - Read weight

    /// Fetch the most recent weight from Apple Health
    func latestWeight() async throws -> (value: Double, unit: HKUnit, date: Date)? {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: weightType)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 1
        )

        let results = try await descriptor.result(for: store)
        guard let sample = results.first else { return nil }

        let lbs = sample.quantity.doubleValue(for: .pound())
        return (value: lbs, unit: .pound(), date: sample.endDate)
    }

    /// Fetch weight history from Apple Health for a date range
    func weightHistory(from startDate: Date, to endDate: Date = Date()) async throws -> [(value: Double, date: Date)] {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: weightType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .forward)]
        )

        let results = try await descriptor.result(for: store)
        return results.map { sample in
            (value: sample.quantity.doubleValue(for: .pound()), date: sample.endDate)
        }
    }

    // MARK: - Write weight

    /// Save a weight entry to Apple Health
    func saveWeight(_ value: Double, unit: WeightUnit, date: Date) async throws {
        let hkUnit: HKUnit = unit == .kg ? .gramUnit(with: .kilo) : .pound()
        let quantity = HKQuantity(unit: hkUnit, doubleValue: value)
        let sample = HKQuantitySample(
            type: weightType,
            quantity: quantity,
            start: date,
            end: date
        )

        try await store.save(sample)
    }

    // MARK: - Background delivery

    /// Enable background delivery so the app gets notified when new weight data arrives
    func enableBackgroundDelivery() async throws {
        guard isAvailable else { return }
        try await store.enableBackgroundDelivery(for: weightType, frequency: .immediate)
    }

    /// Observe new weight samples and call handler
    func observeWeightChanges(handler: @escaping @Sendable () -> Void) {
        let query = HKObserverQuery(sampleType: weightType, predicate: nil) { _, completionHandler, _ in
            handler()
            completionHandler()
        }
        store.execute(query)
    }

    // MARK: - Steps

    /// Fetch daily step counts for a date range.
    func dailySteps(from startDate: Date, to endDate: Date = Date()) async throws -> [(date: Date, steps: Int)] {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let interval = DateComponents(day: 1)

        let query = HKStatisticsCollectionQuery(
            quantityType: stepsType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: Calendar.current.startOfDay(for: startDate),
            intervalComponents: interval
        )

        return try await withCheckedThrowingContinuation { continuation in
            query.initialResultsHandler = { _, results, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                var data: [(date: Date, steps: Int)] = []
                results?.enumerateStatistics(from: startDate, to: endDate) { stats, _ in
                    let steps = Int(stats.sumQuantity()?.doubleValue(for: .count()) ?? 0)
                    data.append((date: stats.startDate, steps: steps))
                }
                continuation.resume(returning: data)
            }
            store.execute(query)
        }
    }

    // MARK: - Active Calories

    /// Fetch daily active calories burned for a date range.
    func dailyCalories(from startDate: Date, to endDate: Date = Date()) async throws -> [(date: Date, calories: Int)] {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let interval = DateComponents(day: 1)

        let query = HKStatisticsCollectionQuery(
            quantityType: caloriesType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: Calendar.current.startOfDay(for: startDate),
            intervalComponents: interval
        )

        return try await withCheckedThrowingContinuation { continuation in
            query.initialResultsHandler = { _, results, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                var data: [(date: Date, calories: Int)] = []
                results?.enumerateStatistics(from: startDate, to: endDate) { stats, _ in
                    let cals = Int(stats.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0)
                    data.append((date: stats.startDate, calories: cals))
                }
                continuation.resume(returning: data)
            }
            store.execute(query)
        }
    }

    // MARK: - Sleep

    /// Fetch total sleep hours per night for a date range.
    func dailySleep(from startDate: Date, to endDate: Date = Date()) async throws -> [(date: Date, hours: Double)] {
        let sleepType = HKCategoryType(.sleepAnalysis)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: sleepType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .forward)]
        )

        let results = try await descriptor.result(for: store)

        // Group by the night (use endDate's calendar day)
        var byDay: [String: Double] = [:]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        for sample in results {
            // Only count asleep categories, not "inBed"
            if sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
               sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
               sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
               sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue {
                let hours = sample.endDate.timeIntervalSince(sample.startDate) / 3600
                let dayKey = formatter.string(from: sample.endDate)
                byDay[dayKey, default: 0] += hours
            }
        }

        return byDay.sorted { $0.key < $1.key }.compactMap { key, hours in
            guard let date = formatter.date(from: key) else { return nil }
            return (date: date, hours: hours)
        }
    }

    // MARK: - Body Fat

    /// Fetch the most recent body fat percentage from Apple Health
    func latestBodyFat() async throws -> (value: Double, date: Date)? {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: bodyFatType)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 1
        )

        let results = try await descriptor.result(for: store)
        guard let sample = results.first else { return nil }

        let pct = sample.quantity.doubleValue(for: .percent()) * 100
        return (value: pct, date: sample.endDate)
    }
}
