import Foundation
import SwiftData

@Model
final class BodyComposition {
    var id: String
    var date: String              // "YYYY-MM-DD"
    var bodyFatPercent: Double?
    var muscleMass: Double?       // in user's unit
    var waist: Double?            // inches or cm
    var hips: Double?
    var chest: Double?
    var arms: Double?
    var thighs: Double?
    var unit: String              // "lb" or "kg" — for muscle mass
    var measurementUnit: String   // "in" or "cm" — for tape measurements
    var createdAt: Date

    init(
        date: String? = nil,
        bodyFatPercent: Double? = nil,
        muscleMass: Double? = nil,
        waist: Double? = nil,
        hips: Double? = nil,
        chest: Double? = nil,
        arms: Double? = nil,
        thighs: Double? = nil,
        unit: WeightUnit = .lb,
        measurementUnit: MeasurementSystem = .imperial
    ) {
        self.id = WeightEntry.generateId()
        self.date = date ?? DateHelpers.todayString()
        self.bodyFatPercent = bodyFatPercent
        self.muscleMass = muscleMass
        self.waist = waist
        self.hips = hips
        self.chest = chest
        self.arms = arms
        self.thighs = thighs
        self.unit = unit.rawValue
        self.measurementUnit = measurementUnit.rawValue
        self.createdAt = Date()
    }
}

enum MeasurementSystem: String, Codable, CaseIterable {
    case imperial = "in"
    case metric = "cm"

    var label: String {
        switch self {
        case .imperial: return "Inches"
        case .metric: return "Centimeters"
        }
    }
}
