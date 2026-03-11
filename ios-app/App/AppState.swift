import SwiftUI
import Combine

/// Global app state shared across views
@MainActor
class AppState: ObservableObject {
    @Published var showOnboarding = false
    @Published var unit: WeightUnit = .lb
    @Published var isSyncing = false

    private var container: ModelContainer?

    func configure(container: ModelContainer) {
        self.container = container

        // Load saved unit preference
        if let saved = UserDefaults.standard.string(forKey: "weight-unit"),
           let unit = WeightUnit(rawValue: saved) {
            self.unit = unit
        }

        // Check if onboarding needed
        if !UserDefaults.standard.bool(forKey: "onboarding-done") {
            showOnboarding = true
        }
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "onboarding-done")
        showOnboarding = false
    }

    func changeUnit(_ newUnit: WeightUnit) {
        unit = newUnit
        UserDefaults.standard.set(newUnit.rawValue, forKey: "weight-unit")
    }
}
