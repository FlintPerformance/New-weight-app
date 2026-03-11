import SwiftUI
import Charts

/// Shows correlations between weight trends and HealthKit data (steps, calories, sleep).
struct HealthCorrelationCard: View {
    @EnvironmentObject var appState: AppState
    @State private var steps: [(date: Date, steps: Int)] = []
    @State private var calories: [(date: Date, calories: Int)] = []
    @State private var sleep: [(date: Date, hours: Double)] = []
    @State private var isLoading = true
    @State private var hasAccess = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.pink)
                Text("Health Insights")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if !hasAccess {
                HStack {
                    Text("Connect Apple Health to see activity correlations")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Connect") {
                        Task { await connectAndLoad() }
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(AppColors.accent)
                }
            } else if !isLoading {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    // Average steps
                    if !steps.isEmpty {
                        let avg = steps.map(\.steps).reduce(0, +) / max(1, steps.count)
                        healthStat("Steps", "\(formatNumber(avg))", icon: "figure.walk", color: .orange)
                    }

                    // Average calories
                    if !calories.isEmpty {
                        let avg = calories.map(\.calories).reduce(0, +) / max(1, calories.count)
                        healthStat("Calories", "\(formatNumber(avg))", icon: "flame.fill", color: AppColors.danger)
                    }

                    // Average sleep
                    if !sleep.isEmpty {
                        let avg = sleep.map(\.hours).reduce(0, +) / Double(max(1, sleep.count))
                        healthStat("Sleep", String(format: "%.1fh", avg), icon: "moon.fill", color: .indigo)
                    }
                }

                // Mini sparkline of steps vs time
                if steps.count > 3 {
                    Chart {
                        ForEach(Array(steps.suffix(7).enumerated()), id: \.offset) { _, point in
                            BarMark(
                                x: .value("Date", point.date, unit: .day),
                                y: .value("Steps", point.steps)
                            )
                            .foregroundStyle(.orange.opacity(0.6))
                            .cornerRadius(3)
                        }
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .frame(height: 40)
                }

                Text("7-day averages from Apple Health")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task {
            await loadData()
        }
    }

    private func healthStat(_ title: String, _ value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.callout)
                .fontWeight(.bold)
                .fontDesign(.rounded)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 10000 {
            return String(format: "%.1fk", Double(n) / 1000)
        }
        return "\(n)"
    }

    private func connectAndLoad() async {
        do {
            try await HealthKitService.shared.requestAuthorization()
            hasAccess = true
            await loadData()
        } catch {
            // User denied
        }
    }

    private func loadData() async {
        let hk = HealthKitService.shared
        guard await hk.isAvailable else {
            isLoading = false
            return
        }

        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()

        do {
            // Try to fetch — if fails, user hasn't authorized
            async let stepsResult = hk.dailySteps(from: sevenDaysAgo)
            async let calsResult = hk.dailyCalories(from: sevenDaysAgo)
            async let sleepResult = hk.dailySleep(from: sevenDaysAgo)

            let (s, c, sl) = try await (stepsResult, calsResult, sleepResult)
            steps = s
            calories = c
            sleep = sl
            hasAccess = true
        } catch {
            hasAccess = false
        }

        isLoading = false
    }
}
