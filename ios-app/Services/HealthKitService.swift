import HealthKit

/// Integrates with Apple Health to read/write body mass data.
///
/// Capabilities this enables:
/// - Auto-import weight from Apple Health (smart scale, other apps)
/// - Write logged weights back to Health
/// - Show weight from Health on Dashboard if newer than last manual log
///
/// Setup: Add HealthKit capability in Xcode + NSHealthShareUsageDescription
/// and NSHealthUpdateUsageDescription in Info.plist.
actor HealthKitService {
    static let shared = HealthKitService()

    private let store = HKHealthStore()

    private let weightType = HKQuantityType(.bodyMass)
    private let readTypes: Set<HKObjectType> = [
        HKQuantityType(.bodyMass),
        HKQuantityType(.bodyMassIndex),
        HKQuantityType(.bodyFatPercentage),
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
}
