import SwiftUI
import Charts
import SwiftData

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var auth: AuthViewModel
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    @Query(filter: #Predicate<Goal> { $0.isActive }, sort: \Goal.createdAt) private var activeGoals: [Goal]
    @Binding var showWeighIn: Bool
    var onNavigateToProgress: (() -> Void)?
    @State private var selectedChartDate: Date?
    @State private var appeared = false
    @State private var showProfile = false

    private var latest: WeightEntry? { weights.first }
    private var activeGoal: Goal? { activeGoals.first }
    private var goalDirection: WeightGoalDirection? {
        guard let goal = activeGoal else { return nil }
        return goal.targetWeight < goal.startWeight ? .lose : .gain
    }

    private var streak: Int {
        StreakCalculator.calculate(from: weights.map(\.date))
    }

    private var last30Change: Double? {
        let cutoff = DateHelpers.daysAgo(30)
        let filtered = weights.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }
        guard filtered.count >= 2 else { return nil }
        return filtered.last!.weight - filtered.first!.weight
    }

    /// Daily average weight (Date-based for smooth scrubbing)
    private var chartData: [(date: Date, weight: Double)] {
        let cutoff = DateHelpers.daysAgo(7)
        let recent = weights.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }
        var sums: [String: Double] = [:]
        var counts: [String: Int] = [:]
        for entry in recent {
            sums[entry.date, default: 0] += entry.weight
            counts[entry.date, default: 0] += 1
        }
        return sums.keys.sorted().compactMap { dateStr in
            guard let d = DateHelpers.date(from: dateStr) else { return nil }
            return (d, sums[dateStr]! / Double(counts[dateStr]!))
        }
    }

    // Use up to 30 days of data to seed the EMA (daily averages), then show last 7 days
    private var emaData: [(date: Date, ema: Double)] {
        let cutoff = DateHelpers.daysAgo(30)
        let recent = weights.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }
        var sums: [String: Double] = [:]
        var counts: [String: Int] = [:]
        for entry in recent {
            sums[entry.date, default: 0] += entry.weight
            counts[entry.date, default: 0] += 1
        }
        let sorted: [(String, Double)] = sums.keys.sorted().map { date in
            (date, sums[date]! / Double(counts[date]!))
        }
        let allEma = WeightViewModel.ema(data: sorted)
        let chartDateStrs = Set(self.chartData.map { DateHelpers.formatDate($0.date) })
        return allEma.compactMap { point in
            guard chartDateStrs.contains(point.date),
                  let d = DateHelpers.date(from: point.date) else { return nil }
            return (d, point.ema)
        }
    }

    private var currentEma: Double? { emaData.last?.ema }

    private var chartYDomain: ClosedRange<Double> {
        let allValues = chartData.map(\.weight) + emaData.map(\.ema)
        return ChartHelpers.yDomain(for: allValues)
    }

    private var chartXDomain: ClosedRange<Date> {
        guard let first = chartData.first?.date, let last = chartData.last?.date else {
            return Date()...Date()
        }
        let pad: TimeInterval = 86400 * 0.5
        return first.addingTimeInterval(-pad)...last.addingTimeInterval(pad)
    }

    /// Official weight per day (morning or first entry) for progress calculations
    private var officialWeightByDate: [String: Double] {
        let sorted = weights.sorted { $0.date < $1.date }
        var byDate: [String: Double] = [:]
        for entry in sorted {
            if entry.isMorning || byDate[entry.date] == nil {
                byDate[entry.date] = entry.weight
            }
        }
        return byDate
    }

    private var latestOfficialWeight: Double? {
        let dates = officialWeightByDate.keys.sorted()
        guard let last = dates.last else { return nil }
        return officialWeightByDate[last]
    }

    private var predictedDate: (date: Date, daysAway: Int, ratePerWeek: Double)? {
        guard let goal = activeGoal else { return nil }
        let data = officialWeightByDate.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
        return InsightsEngine.predictedGoalDate(weights: data, goal: (target: goal.targetWeight, start: goal.startWeight))
    }

    // MARK: - Selection helpers

    private var selectedChartWeight: Double? {
        guard let sel = selectedChartDate else { return nil }
        return chartData.min(by: { abs($0.date.timeIntervalSince(sel)) < abs($1.date.timeIntervalSince(sel)) })?.weight
    }

    private var selectedChartEma: Double? {
        guard let sel = selectedChartDate else { return nil }
        return emaData.min(by: { abs($0.date.timeIntervalSince(sel)) < abs($1.date.timeIntervalSince(sel)) })?.ema
    }

    private var selectedDateString: String? {
        guard let sel = selectedChartDate else { return nil }
        return DateHelpers.formatShort(DateHelpers.formatDate(sel))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    greetingSection
                        .offset(y: appeared ? 0 : 20)
                        .opacity(appeared ? 1 : 0)

                    weightCard
                        .offset(y: appeared ? 0 : 20)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.05), value: appeared)

                    statsRow
                        .offset(y: appeared ? 0 : 20)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.1), value: appeared)

                    if chartData.count > 1 {
                        weeklyChart
                            .offset(y: appeared ? 0 : 20)
                            .opacity(appeared ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.15), value: appeared)
                    }

                    if let prediction = predictedDate {
                        predictedGoalCard(prediction)
                            .offset(y: appeared ? 0 : 20)
                            .opacity(appeared ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.2), value: appeared)
                    }

                    quickActions
                        .offset(y: appeared ? 0 : 20)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.25), value: appeared)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showProfile = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showProfile) {
                NavigationStack {
                    ProfileView()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { showProfile = false }
                                    .fontWeight(.medium)
                            }
                        }
                }
            }
            .onAppear { appeared = true }
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

    private var consistencyScore: Int {
        InsightsEngine.consistencyScore(dates: weights.map(\.date)).score
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatCard(title: "Streak", value: "\(streak)", subtitle: streak == 1 ? "day" : "days", color: AppColors.accent)
            StatCard(title: "Consistency", value: "\(consistencyScore)%", subtitle: "30d", color: consistencyScore >= 80 ? AppColors.success : consistencyScore >= 50 ? AppColors.accent : AppColors.warning)

            if let goal = activeGoal, let officialWeight = latestOfficialWeight {
                let progress = goal.calculateProgress(currentWeight: officialWeight)
                StatCard(title: "Goal", value: "\(progress.percentage)%", subtitle: "\(String(format: "%.1f", abs(progress.remaining))) to go", color: AppColors.accent)
            } else {
                StatCard(title: "Goal", value: "—", subtitle: "Set one!", color: AppColors.accent)
            }
        }
    }

    private var weeklyChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your Week")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if selectedChartDate != nil {
                    HStack(spacing: 8) {
                        if let w = selectedChartWeight {
                            Text(WeightConverter.format(w, unit: appState.unit))
                                .font(.caption)
                                .fontWeight(.bold)
                                .fontDesign(.rounded)
                        }
                        if let ema = selectedChartEma {
                            Text("Trend \(WeightConverter.format(ema, unit: appState.unit))")
                                .font(.caption2)
                                .foregroundStyle(appState.chartColor)
                        }
                        if let ds = selectedDateString {
                            Text(ds)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .transition(.opacity)
                }
            }

            Chart {
                // Oscillation bars: thin RuleMarks from EMA to daily average
                ForEach(Array(chartData.enumerated()), id: \.offset) { _, point in
                    if let ema = emaData.min(by: { abs($0.date.timeIntervalSince(point.date)) < abs($1.date.timeIntervalSince(point.date)) })?.ema {
                        RuleMark(
                            x: .value("Date", point.date),
                            yStart: .value("EMA", ema),
                            yEnd: .value("Weight", point.weight)
                        )
                        .foregroundStyle(appState.chartColor.opacity(0.35))
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    }

                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Weight", point.weight)
                    )
                    .foregroundStyle(appState.chartColor.opacity(0.5))
                    .symbolSize(point.date == chartData.last?.date ? 40 : 16)
                }

                // 7-day EMA trend line
                ForEach(Array(emaData.enumerated()), id: \.offset) { _, point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Weight", point.ema)
                    )
                    .foregroundStyle(appState.chartColor)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Weight", point.ema)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [appState.chartColor.opacity(0.2), appState.chartColor.opacity(0)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }

                // Selection vertical rule
                if let sel = selectedChartDate {
                    RuleMark(x: .value("Selected", sel))
                        .foregroundStyle(appState.chartColor.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
            }
            .chartXSelection(value: $selectedChartDate)
            .chartXAxis {
                AxisMarks(values: .automatic) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(DateHelpers.formatShort(DateHelpers.formatDate(date)))
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartYScale(domain: chartYDomain)
            .chartXScale(domain: chartXDomain)
            .frame(height: 200)
            .animation(.smooth(duration: 0.3), value: chartData.count)

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 1).fill(appState.chartColor.opacity(0.35)).frame(width: 3, height: 10)
                    Text("Daily Avg").font(.caption2).foregroundStyle(.tertiary)
                }
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 1).fill(appState.chartColor).frame(width: 14, height: 2)
                    Text("7d Trend (EMA)").font(.caption2).foregroundStyle(.tertiary)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func predictedGoalCard(_ prediction: (date: Date, daysAway: Int, ratePerWeek: Double)) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.title2)
                .foregroundStyle(AppColors.accent)

            VStack(alignment: .leading, spacing: 4) {
                Text("Predicted Goal Date")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(DateHelpers.format(DateHelpers.formatDate(prediction.date)))
                    .font(.subheadline)
                    .fontWeight(.bold)
                Text("\(prediction.daysAway) days at \(String(format: "%.1f", abs(prediction.ratePerWeek))) \(appState.unit.rawValue)/wk")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var quickActions: some View {
        HStack(spacing: 12) {
            Button {
                onNavigateToProgress?()
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
