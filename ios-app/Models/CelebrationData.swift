import Foundation

struct CelebrationData: Identifiable {
    let id = UUID()
    let weight: Double
    let unit: WeightUnit
    let date: String
    let isMorning: Bool
    var milestones: [InsightsEngine.Milestone] = []
}
