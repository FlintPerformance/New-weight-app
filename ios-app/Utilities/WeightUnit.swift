import Foundation

enum WeightUnit: String, Codable, CaseIterable {
    case lb, kg

    var label: String {
        switch self {
        case .lb: return "Pounds (lb)"
        case .kg: return "Kilograms (kg)"
        }
    }

    var shortLabel: String { rawValue }
}

enum WeightConverter {
    static func convert(_ value: Double, from: WeightUnit, to: WeightUnit) -> Double {
        if from == to { return value }
        switch (from, to) {
        case (.lb, .kg): return value * 0.453592
        case (.kg, .lb): return value / 0.453592
        default: return value
        }
    }

    static func isValid(_ value: Double, unit: WeightUnit) -> Bool {
        switch unit {
        case .lb: return value >= 1 && value <= 1500
        case .kg: return value >= 0.5 && value <= 680
        }
    }

    static func format(_ value: Double, unit: WeightUnit) -> String {
        String(format: "%.1f %@", value, unit.rawValue)
    }
}
