import SwiftUI

/// Lightweight direction enum used by AppColors and StreakMessages
/// so Constants.swift has no dependency on the Goal model.
enum WeightGoalDirection {
    case lose, gain
}

enum AppColors {
    static let accent = Color(hex: "#2B9B8F")
    static let accentDark = Color(hex: "#238079")
    static let success = Color(hex: "#22C55E")
    static let danger = Color(hex: "#EF4444")
    static let warning = Color(hex: "#E5A63E")

    /// Returns green/red based on whether the change aligns with the goal direction.
    /// When gaining, positive change is good. When losing (or no goal), negative change is good.
    static func changeColor(_ change: Double, goalDirection: WeightGoalDirection? = nil) -> Color {
        guard change != 0 else { return .secondary }
        let isGood: Bool
        switch goalDirection {
        case .gain:
            isGood = change > 0
        case .lose, .none:
            isGood = change < 0
        }
        return isGood ? success : danger
    }

    static let graphColors: [(color: Color, hex: String, label: String)] = [
        (Color(hex: "#2B9B8F"), "#2B9B8F", "Teal"),
        (Color(hex: "#3b82f6"), "#3b82f6", "Blue"),
        (Color(hex: "#22c55e"), "#22c55e", "Green"),
        (Color(hex: "#a855f7"), "#a855f7", "Purple"),
        (Color(hex: "#f59e0b"), "#f59e0b", "Amber"),
        (Color(hex: "#ec4899"), "#ec4899", "Pink"),
        (Color(hex: "#06b6d4"), "#06b6d4", "Cyan"),
        (Color(hex: "#ef4444"), "#ef4444", "Red"),
    ]
}

// MARK: - Color hex init

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Chart helpers

enum ChartHelpers {
    /// Computes a Y-axis domain that centers the data vertically with generous padding
    /// so the trend curve is visible rather than looking like a flat line.
    /// Uses at least ±2 units of padding, or 3x the data range, whichever is larger.
    static func yDomain(for values: [Double]) -> ClosedRange<Double> {
        guard let lo = values.min(), let hi = values.max() else { return 0...1 }
        let dataRange = hi - lo
        let mid = (hi + lo) / 2.0
        // At least 2 units of breathing room on each side, or 1.5x the data spread
        let halfSpan = max(2.0, dataRange * 1.5)
        return (mid - halfSpan)...(mid + halfSpan)
    }
}

// MARK: - Streak messages

enum StreakMessages {
    static func message(for streak: Int) -> String {
        switch streak {
        case 0: return "Let's get started today!"
        case 1: return "Great start! Day one down."
        case 2...3: return "You're building momentum!"
        case 4...7: return "You're on a roll! Keep going!"
        case 8...14: return "Two weeks strong! Amazing!"
        case 15...30: return "Incredible consistency!"
        default: return "You're unstoppable!"
        }
    }

    static func celebrationMessage(streak: Int, diff: Double?, goalDirection: WeightGoalDirection? = nil) -> String {
        if streak >= 14 { return "Absolutely unstoppable!" }
        if streak >= 7 { return "You're on fire!" }
        if streak >= 3 { return "Keep it rolling!" }
        if let diff {
            let movingRight: Bool
            switch goalDirection {
            case .gain: movingRight = diff > 0
            case .lose, .none: movingRight = diff < 0
            }
            if movingRight && abs(diff) > 0.5 { return "Trending in the right direction!" }
            if movingRight { return "Every bit counts!" }
        }
        return "Logged! You got this!"
    }
}
