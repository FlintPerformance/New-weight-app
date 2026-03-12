import SwiftUI
import SwiftData
import Combine

/// Global app state shared across views
@MainActor
class AppState: ObservableObject {
    @Published var showOnboarding = false
    @Published var unit: WeightUnit = .lb
    @Published var isSyncing = false
    @Published var syncError: String?
    @Published var chartColor: Color = AppColors.accent
    @Published var chartColorHex: String = "#2B9B8F"

    private var container: ModelContainer?

    func configure(container: ModelContainer) {
        self.container = container

        // Load saved unit preference
        if let saved = UserDefaults.standard.string(forKey: "weight-unit"),
           let unit = WeightUnit(rawValue: saved) {
            self.unit = unit
        }

        // Load saved chart color
        if let savedHex = UserDefaults.standard.string(forKey: "chart-color") {
            chartColorHex = savedHex
            chartColor = Color(hex: savedHex)
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

    func changeChartColor(hex: String, color: Color) {
        chartColorHex = hex
        chartColor = color
        UserDefaults.standard.set(hex, forKey: "chart-color")
    }
}
