import SwiftUI
import Charts
import SwiftData

struct HealthView: View {
    @EnvironmentObject var appState: AppState
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]

    @State private var isLoading = true
    @State private var hasAccess = false

    // HealthKit data
    @State private var steps: [(date: Date, steps: Int)] = []
    @State private var calories: [(date: Date, calories: Int)] = []
    @State private var sleep: [(date: Date, hours: Double)] = []
    @State private var heartRate: [(date: Date, bpm: Double)] = []
    @State private var latestBMI: Double?
    @State private var latestBodyFat: Double?
    @State private var latestRestingHR: Double?
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if !hasAccess && !isLoading {
                        connectCard
                            .offset(y: appeared ? 0 : 20)
                            .opacity(appeared ? 1 : 0)
                    } else if isLoading {
                        ProgressView("Loading health data...")
                            .padding(.top, 60)
                    } else {
                        // Summary cards
                        summaryGrid
                            .offset(y: appeared ? 0 : 20)
                            .opacity(appeared ? 1 : 0)

                        // Steps chart
                        if !steps.isEmpty {
                            stepsChart
                                .offset(y: appeared ? 0 : 20)
                                .opacity(appeared ? 1 : 0)
                                .animation(.easeOut(duration: 0.4).delay(0.05), value: appeared)
                        }

                        // Heart rate chart
                        if !heartRate.isEmpty {
                            heartRateChart
                                .offset(y: appeared ? 0 : 20)
                                .opacity(appeared ? 1 : 0)
                                .animation(.easeOut(duration: 0.4).delay(0.1), value: appeared)
                        }

                        // Calories chart
                        if !calories.isEmpty {
                            caloriesChart
                                .offset(y: appeared ? 0 : 20)
                                .opacity(appeared ? 1 : 0)
                                .animation(.easeOut(duration: 0.4).delay(0.15), value: appeared)
                        }

                        // Sleep chart
                        if !sleep.isEmpty {
                            sleepChart
                                .offset(y: appeared ? 0 : 20)
                                .opacity(appeared ? 1 : 0)
                                .animation(.easeOut(duration: 0.4).delay(0.2), value: appeared)
                        }

                        // Body metrics
                        if latestBMI != nil || latestBodyFat != nil {
                            bodyMetricsCard
                                .offset(y: appeared ? 0 : 20)
                                .opacity(appeared ? 1 : 0)
                                .animation(.easeOut(duration: 0.4).delay(0.25), value: appeared)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Health")
            .onAppear { appeared = true }
            .task { await loadData() }
        }
    }

    // MARK: - Connect Card

    private var connectCard: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 56))
                .foregroundStyle(.pink)

            Text("Connect Apple Health")
                .font(.title3)
                .fontWeight(.bold)

            Text("See your steps, heart rate, sleep, calories, BMI, and body fat — all in one place alongside your weight journey.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task { await connectAndLoad() }
            } label: {
                Label("Connect", systemImage: "heart.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.pink)
            .padding(.horizontal, 40)
        }
        .padding(.top, 40)
    }

    // MARK: - Summary Grid

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            // Daily steps average
            if !steps.isEmpty {
                let avg = steps.map(\.steps).reduce(0, +) / max(1, steps.count)
                summaryTile("Steps", value: formatNumber(avg), icon: "figure.walk", color: .orange, subtitle: "7d avg")
            }

            // Resting HR
            if let hr = latestRestingHR {
                summaryTile("Heart Rate", value: "\(Int(hr))", icon: "heart.fill", color: .red, subtitle: "resting bpm")
            }

            // Sleep average
            if !sleep.isEmpty {
                let avg = sleep.map(\.hours).reduce(0, +) / Double(max(1, sleep.count))
                summaryTile("Sleep", value: String(format: "%.1f", avg), icon: "moon.fill", color: .indigo, subtitle: "hrs avg")
            }

            // Active calories average
            if !calories.isEmpty {
                let avg = calories.map(\.calories).reduce(0, +) / max(1, calories.count)
                summaryTile("Calories", value: formatNumber(avg), icon: "flame.fill", color: AppColors.danger, subtitle: "7d avg")
            }

            // BMI
            if let bmi = latestBMI {
                summaryTile("BMI", value: String(format: "%.1f", bmi), icon: "scalemass.fill", color: AppColors.accent, subtitle: bmiCategory(bmi))
            }

            // Body fat
            if let bf = latestBodyFat {
                summaryTile("Body Fat", value: "\(String(format: "%.1f", bf))%", icon: "figure.arms.open", color: AppColors.warning, subtitle: "latest")
            }
        }
    }

    private func summaryTile(_ title: String, value: String, icon: String, color: Color, subtitle: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .fontDesign(.rounded)
            Text(title)
                .font(.caption2)
                .fontWeight(.medium)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Steps Chart

    private var stepsChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "figure.walk")
                    .foregroundStyle(.orange)
                Text("Daily Steps")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                let total = steps.map(\.steps).reduce(0, +)
                Text("\(formatNumber(total)) this week")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Chart {
                ForEach(Array(steps.enumerated()), id: \.offset) { _, point in
                    BarMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Steps", point.steps)
                    )
                    .foregroundStyle(
                        LinearGradient(colors: [.orange, .orange.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                    )
                    .cornerRadius(4)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(shortDay(date))
                                .font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 160)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Heart Rate Chart

    private var heartRateChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                Text("Resting Heart Rate")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                if let latest = heartRate.last {
                    Text("\(Int(latest.bpm)) bpm")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.red)
                }
            }

            Chart {
                ForEach(Array(heartRate.enumerated()), id: \.offset) { _, point in
                    LineMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("BPM", point.bpm)
                    )
                    .foregroundStyle(.red)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("BPM", point.bpm)
                    )
                    .foregroundStyle(
                        LinearGradient(colors: [.red.opacity(0.15), .clear], startPoint: .top, endPoint: .bottom)
                    )
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(shortDay(date))
                                .font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 140)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Calories Chart

    private var caloriesChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundStyle(AppColors.danger)
                Text("Active Calories")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                let avg = calories.map(\.calories).reduce(0, +) / max(1, calories.count)
                Text("\(formatNumber(avg)) avg/day")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Chart {
                ForEach(Array(calories.enumerated()), id: \.offset) { _, point in
                    BarMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Calories", point.calories)
                    )
                    .foregroundStyle(
                        LinearGradient(colors: [AppColors.danger, AppColors.danger.opacity(0.5)], startPoint: .top, endPoint: .bottom)
                    )
                    .cornerRadius(4)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(shortDay(date))
                                .font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 140)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Sleep Chart

    private var sleepChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "moon.fill")
                    .foregroundStyle(.indigo)
                Text("Sleep")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                if let latest = sleep.last {
                    Text(String(format: "%.1fh last night", latest.hours))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Chart {
                ForEach(Array(sleep.enumerated()), id: \.offset) { _, point in
                    BarMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Hours", point.hours)
                    )
                    .foregroundStyle(
                        LinearGradient(colors: [.indigo, .indigo.opacity(0.5)], startPoint: .top, endPoint: .bottom)
                    )
                    .cornerRadius(4)
                }

                // 8-hour recommended line
                RuleMark(y: .value("Recommended", 8))
                    .foregroundStyle(.indigo.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(shortDay(date))
                                .font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 140)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Body Metrics

    private var bodyMetricsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "figure.arms.open")
                    .foregroundStyle(AppColors.accent)
                Text("Body Metrics")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            HStack(spacing: 16) {
                if let bmi = latestBMI {
                    VStack(spacing: 4) {
                        Text(String(format: "%.1f", bmi))
                            .font(.title2)
                            .fontWeight(.bold)
                            .fontDesign(.rounded)
                            .foregroundStyle(bmiColor(bmi))
                        Text("BMI")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(bmiCategory(bmi))
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(bmiColor(bmi))
                    }
                    .frame(maxWidth: .infinity)
                }

                if let bf = latestBodyFat {
                    VStack(spacing: 4) {
                        Text(String(format: "%.1f%%", bf))
                            .font(.title2)
                            .fontWeight(.bold)
                            .fontDesign(.rounded)
                            .foregroundStyle(AppColors.warning)
                        Text("Body Fat")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }

                if let weight = weights.first {
                    VStack(spacing: 4) {
                        Text(WeightConverter.format(weight.weight, unit: appState.unit))
                            .font(.title2)
                            .fontWeight(.bold)
                            .fontDesign(.rounded)
                        Text("Weight")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helpers

    private func formatNumber(_ n: Int) -> String {
        if n >= 10000 { return String(format: "%.1fk", Double(n) / 1000) }
        return "\(n)"
    }

    private func shortDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    private func bmiCategory(_ bmi: Double) -> String {
        if bmi < 18.5 { return "Underweight" }
        if bmi < 25 { return "Normal" }
        if bmi < 30 { return "Overweight" }
        return "Obese"
    }

    private func bmiColor(_ bmi: Double) -> Color {
        if bmi < 18.5 { return AppColors.warning }
        if bmi < 25 { return AppColors.success }
        if bmi < 30 { return AppColors.warning }
        return AppColors.danger
    }

    // MARK: - Data Loading

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
            async let stepsResult = hk.dailySteps(from: sevenDaysAgo)
            async let calsResult = hk.dailyCalories(from: sevenDaysAgo)
            async let sleepResult = hk.dailySleep(from: sevenDaysAgo)
            async let hrResult = hk.dailyRestingHeartRate(from: sevenDaysAgo)
            async let bmiResult = hk.latestBMI()
            async let bfResult = hk.latestBodyFat()
            async let restHRResult = hk.latestRestingHeartRate()

            let (s, c, sl, hr, bmi, bf, rhr) = try await (stepsResult, calsResult, sleepResult, hrResult, bmiResult, bfResult, restHRResult)
            steps = s
            calories = c
            sleep = sl
            heartRate = hr
            latestBMI = bmi?.value
            latestBodyFat = bf?.value
            latestRestingHR = rhr?.value
            hasAccess = true
        } catch {
            hasAccess = false
        }

        isLoading = false
    }
}
