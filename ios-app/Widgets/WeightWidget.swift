import WidgetKit
import SwiftUI

/// Home screen widget showing current weight, streak, and goal progress.
///
/// Setup: Add Widget Extension target in Xcode.
/// Share data between app and widget via App Group container.
///
/// Widget sizes:
/// - Small: Current weight + streak
/// - Medium: Current weight + streak + 7-day sparkline
/// - Large: Current weight + streak + chart + goal progress

// MARK: - Timeline Provider

struct WeightTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeightWidgetEntry {
        WeightWidgetEntry(date: Date(), weight: 175.0, unit: "lb", streak: 5, goalProgress: 45, trend: [175, 174.5, 174.8, 174.2, 173.9])
    }

    func getSnapshot(in context: Context, completion: @escaping (WeightWidgetEntry) -> Void) {
        // Read from shared App Group UserDefaults
        let entry = readLatestData() ?? placeholder(in: context)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeightWidgetEntry>) -> Void) {
        let entry = readLatestData() ?? placeholder(in: Context())
        // Refresh every hour
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func readLatestData() -> WeightWidgetEntry? {
        // TODO: Read from App Group shared container
        // let defaults = UserDefaults(suiteName: "group.com.yourapp.steady")
        // let weight = defaults?.double(forKey: "widget-weight")
        // etc.
        return nil
    }
}

// MARK: - Entry

struct WeightWidgetEntry: TimelineEntry {
    let date: Date
    let weight: Double
    let unit: String
    let streak: Int
    let goalProgress: Int?
    let trend: [Double]
}

// MARK: - Widget Views

struct WeightWidgetSmallView: View {
    let entry: WeightWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("steady")
                .font(.caption2)
                .fontWeight(.black)
                .foregroundStyle(Color(hex: "#2B9B8F"))

            Spacer()

            Text(String(format: "%.1f", entry.weight))
                .font(.system(size: 32, weight: .black, design: .rounded))

            Text(entry.unit)
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.caption2)
                    .foregroundStyle(Color(hex: "#2B9B8F"))
                Text("\(entry.streak) day streak")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}

struct WeightWidgetMediumView: View {
    let entry: WeightWidgetEntry

    var body: some View {
        HStack(spacing: 16) {
            // Left: weight + streak
            VStack(alignment: .leading, spacing: 8) {
                Text("steady")
                    .font(.caption2)
                    .fontWeight(.black)
                    .foregroundStyle(Color(hex: "#2B9B8F"))

                Text(String(format: "%.1f %@", entry.weight, entry.unit))
                    .font(.system(size: 28, weight: .black, design: .rounded))

                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(Color(hex: "#2B9B8F"))
                    Text("\(entry.streak)d streak")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let goal = entry.goalProgress {
                    HStack(spacing: 4) {
                        Image(systemName: "target")
                            .foregroundStyle(Color(hex: "#2B9B8F"))
                        Text("\(goal)% to goal")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            // Right: sparkline
            if entry.trend.count > 1 {
                MiniSparkline(data: entry.trend)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding()
    }
}

struct MiniSparkline: View {
    let data: [Double]

    var body: some View {
        GeometryReader { geo in
            let minVal = data.min() ?? 0
            let maxVal = data.max() ?? 1
            let range = max(maxVal - minVal, 0.1)

            Path { path in
                for (i, value) in data.enumerated() {
                    let x = geo.size.width * CGFloat(i) / CGFloat(max(1, data.count - 1))
                    let y = geo.size.height * (1 - CGFloat((value - minVal) / range))
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(Color(hex: "#2B9B8F"), lineWidth: 2)
        }
    }
}

// MARK: - Widget Configuration

// Note: This would be in the Widget Extension target, not the main app.
// Included here as a scaffold reference.
//
// @main
// struct SteadyWidget: Widget {
//     let kind = "SteadyWidget"
//
//     var body: some WidgetConfiguration {
//         StaticConfiguration(kind: kind, provider: WeightTimelineProvider()) { entry in
//             if #available(iOS 17.0, *) {
//                 WeightWidgetSmallView(entry: entry)
//                     .containerBackground(.fill.tertiary, for: .widget)
//             } else {
//                 WeightWidgetSmallView(entry: entry)
//                     .padding()
//                     .background()
//             }
//         }
//         .configurationDisplayName("Weight Tracker")
//         .description("See your current weight and streak at a glance.")
//         .supportedFamilies([.systemSmall, .systemMedium])
//     }
// }
