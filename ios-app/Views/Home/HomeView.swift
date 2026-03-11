import SwiftUI
import Charts
import SwiftData

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var auth: AuthViewModel
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    @Query(filter: #Predicate<Goal> { $0.isActive }, sort: \Goal.createdAt) private var activeGoals: [Goal]
    @Binding var showWeighIn: Bool

    private var latest: WeightEntry? { weights.first }
    private var activeGoal: Goal? { activeGoals.first }
    private var goalDirection: Goal.Direction? {
        guard let goal = activeGoal else { return nil }
        return goal.targetWeight < goal.startWeight ? .lose : .gain
    }

    private var streak: Int {
        guard !weights.isEmpty else { return 0 }
        let uniqueDates = Array(Set(weights.map(\.date))).sorted(by: >)
        let today = DateHelpers.todayString()
        let yesterday = DateHelpers.daysAgo(1)
        guard !uniqueDates.isEmpty, uniqueDates[0] == today || uniqueDates[0] == yesterday else { return 0 }
        var count = 1
        for i in 1..<uniqueDates.count {
            guard let prev = DateHelpers.date(from: uniqueDates[i - 1]),
                  let curr = DateHelpers.date(from: uniqueDates[i]) else { break }
            if Calendar.current.dateComponents([.day], from: curr, to: prev).day == 1 { count += 1 }
            else { break }
        }
        return count
    }

    private var last30Change: Double? {
        let cutoff = DateHelpers.daysAgo(30)
        let filtered = weights.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }
        guard filtered.count >= 2 else { return nil }
        return filtered.last!.weight - filtered.first!.weight
    }

    private var chartData: [(date: String, weight: Double)] {
        let cutoff = DateHelpers.daysAgo(7)
        let recent = weights.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }
        // Aggregate to one per day
        var byDate: [String: Double] = [:]
        for entry in recent {
            if entry.isMorning || byDate[entry.date] == nil {
                byDate[entry.date] = entry.weight
            }
        }
        return byDate.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    // Use up to 30 days of data to seed the EMA, then show last 7 days
    private var emaData: [(date: String, ema: Double)] {
        let cutoff = DateHelpers.daysAgo(30)
        let recent = weights.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }
        var byDate: [String: Double] = [:]
        for entry in recent {
            if entry.isMorning || byDate[entry.date] == nil {
                byDate[entry.date] = entry.weight
            }
        }
        let sorted = byDate.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
        let allEma = WeightViewModel.ema(data: sorted)
        // Only show EMA points that overlap with the 7-day chart
        let chartDates = Set(chartData.map(\.date))
        return allEma.filter { chartDates.contains($0.date) }
    }

    private var currentEma: Double? { emaData.last?.ema }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Greeting
                    greetingSection

                    // Current weight card
                    weightCard

                    // Stats row
                    statsRow

                    // Weekly chart
                    if chartData.count > 1 {
                        weeklyChart
                    }

                    // Quick actions
                    quickActions
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Sections

    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(DateHelpers.greeting(for: auth.user?.displayName ?? "there"))
                .font(.title2)
                .fontWeight(.bold)
            if streak > 0 {
                Text(StreakMessages.message(for: streak))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var weightCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Weight")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let latest {
                HStack(alignment: .lastTextBaseline, spacing: 12) {
                    Text(WeightConverter.format(latest.weight, unit: appState.unit))
                        .font(.system(size: 44, weight: .black, design: .rounded))

                    VStack(alignment: .leading, spacing: 4) {
                        if let change = last30Change {
                            Text("\(change > 0 ? "+" : "")\(String(format: "%.1f", change)) \(appState.unit.rawValue)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(AppColors.changeColor(change, goalDirection: goalDirection))
                            + Text(" 30d")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if let ema = currentEma {
                            Text("Trend: \(WeightConverter.format(ema, unit: appState.unit))")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(AppColors.accent)
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("No entries yet")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("Tap the + button to log your first entry!")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatCard(title: "Streak", value: "\(streak)", subtitle: streak == 1 ? "day" : "days", color: AppColors.accent)
            StatCard(title: "Entries", value: "\(weights.count)", subtitle: "logged", color: .primary)

            if let goal = activeGoal, let latest {
                let progress = goal.calculateProgress(currentWeight: latest.weight)
                StatCard(title: "Goal", value: "\(progress.percentage)%", subtitle: "\(String(format: "%.1f", abs(progress.remaining))) to go", color: AppColors.accent)
            } else {
                StatCard(title: "Goal", value: "—", subtitle: "Set one!", color: AppColors.accent)
            }
        }
    }

    private var weeklyChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Week")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Chart {
                // Raw weight data points
                ForEach(chartData, id: \.date) { point in
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Weight", point.weight)
                    )
                    .foregroundStyle(AppColors.accent.opacity(0.4))
                    .symbolSize(point.date == chartData.last?.date ? 50 : 20)
                }

                // 7-day EMA trend line
                ForEach(emaData, id: \.date) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Weight", point.ema)
                    )
                    .foregroundStyle(AppColors.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Weight", point.ema)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColors.accent.opacity(0.2), AppColors.accent.opacity(0)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { value in
                    AxisValueLabel {
                        if let str = value.as(String.self) {
                            Text(DateHelpers.formatShort(str))
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .frame(height: 200)

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    SwiftUI.Circle().fill(AppColors.accent.opacity(0.4)).frame(width: 6, height: 6)
                    Text("Weigh-ins").font(.caption2).foregroundStyle(.tertiary)
                }
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 1).fill(AppColors.accent).frame(width: 14, height: 2)
                    Text("7d Trend (EMA)").font(.caption2).foregroundStyle(.tertiary)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var quickActions: some View {
        HStack(spacing: 12) {
            Button {
                // Navigate to progress — handled by tab
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("My Progress")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Charts, goals & history")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            Button {
                showWeighIn = true
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quick Log")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.accent)
                    Text("Tap to weigh in now")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(AppColors.accent.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.accent.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .fontDesign(.rounded)
                .foregroundStyle(color)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
