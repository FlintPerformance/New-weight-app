import SwiftUI
import SwiftData

struct ProfileView: View {
    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    @Query(sort: \Goal.createdAt, order: .reverse) private var goals: [Goal]
    @Query(sort: \BodyComposition.date, order: .reverse) private var bodyComps: [BodyComposition]
    @Query(sort: \WeeklyCheckIn.createdAt, order: .reverse) private var checkIns: [WeeklyCheckIn]

    @State private var showLogout = false
    @State private var showStartFresh = false
    @State private var isSyncing = false
    @State private var showImporter = false
    @State private var healthKitConnected = false
    @State private var showColorPicker = false
    @AppStorage("daily-reminders-enabled") private var remindersEnabled = false

    private var streak: Int {
        StreakCalculator.calculate(from: weights.map(\.date))
    }

    private var daysTracked: Int {
        guard let first = weights.last else { return 0 }
        guard let date = DateHelpers.date(from: first.date) else { return 0 }
        return max(1, Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 1)
    }

    var body: some View {
        List {
            // Profile card
            Section {
                profileCard
            }

                // Quick stats
                if !weights.isEmpty {
                    Section {
                        statsGrid
                    }
                }

                // Preferences
                Section("Preferences") {
                    unitPicker
                    graphColorPicker
                }

                // Health
                Section("Health Integration") {
                    healthKitRow
                    notificationsRow
                }

                // Data
                Section("Data") {
                    Button(isSyncing ? "Syncing..." : "Sync Now") { Task { await sync() } }
                        .disabled(isSyncing)
                    Button("Back Up My Data") { exportData() }
                    Button("Restore From Backup") { importData() }
                    Button("Start Fresh", role: .destructive) { showStartFresh = true }
                }

                // Account
                Section {
                    Button("Log Out", role: .destructive) {
                        showLogout = true
                    }
                }

                // Footer
                Section {
                    Text("v1.0.0")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }
            }
        .navigationTitle("Settings")
        .alert("Log Out?", isPresented: $showLogout) {
            Button("Log Out", role: .destructive) { auth.signOut() }
            Button("Cancel", role: .cancel) { }
        }
        .alert("Start Fresh?", isPresented: $showStartFresh) {
            Button("Delete Everything", role: .destructive) { startFresh() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete all your weight entries, goals, body composition data, and check-ins from this device. This cannot be undone.")
        }
    }

    // MARK: - Sections

    private var profileCard: some View {
        HStack(spacing: 16) {
            SwiftUI.Circle()
                .fill(AppColors.accent.opacity(0.2))
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.title2)
                        .foregroundStyle(AppColors.accent)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(auth.user?.displayName ?? "User")
                    .font(.title3)
                    .fontWeight(.bold)
                Text(auth.user?.email ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var consistencyScore: Int {
        InsightsEngine.consistencyScore(dates: weights.map(\.date)).score
    }

    private var statsGrid: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                StatCard(title: "Entries", value: "\(weights.count)", subtitle: "logged", color: .primary)
                StatCard(title: "Streak", value: "\(streak)", subtitle: "days", color: AppColors.accent)
                StatCard(title: "Consistency", value: "\(consistencyScore)%", subtitle: "30d", color: consistencyScore >= 80 ? AppColors.success : AppColors.accent)
            }
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .padding(.vertical, 4)
    }

    private var unitPicker: some View {
        Picker("Unit", selection: Binding(
            get: { appState.unit },
            set: { appState.changeUnit($0) }
        )) {
            ForEach(WeightUnit.allCases, id: \.self) { unit in
                Text(unit.label).tag(unit)
            }
        }
    }

    private var graphColorPicker: some View {
        Button {
            showColorPicker = true
        } label: {
            HStack {
                Text("Chart Color")
                    .foregroundStyle(.primary)
                Spacer()
                HStack(spacing: 6) {
                    SwiftUI.Circle()
                        .fill(appState.chartColor)
                        .frame(width: 24, height: 24)
                        .overlay(
                            SwiftUI.Circle()
                                .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                        )
                    Text(AppColors.graphColors.first(where: { $0.hex == appState.chartColorHex })?.label ?? "Custom")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .sheet(isPresented: $showColorPicker) {
            chartColorPickerSheet
        }
    }

    private var chartColorPickerSheet: some View {
        NavigationStack {
            List {
                ForEach(AppColors.graphColors, id: \.hex) { item in
                    Button {
                        appState.changeChartColor(hex: item.hex, color: item.color)
                        showColorPicker = false
                    } label: {
                        HStack(spacing: 12) {
                            SwiftUI.Circle()
                                .fill(item.color)
                                .frame(width: 28, height: 28)
                            Text(item.label)
                                .foregroundStyle(.primary)
                            Spacer()
                            if appState.chartColorHex == item.hex {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(AppColors.accent)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Chart Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showColorPicker = false }
                        .fontWeight(.medium)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var healthKitRow: some View {
        Button {
            Task { await connectHealthKit() }
        } label: {
            HStack {
                Label("Apple Health", systemImage: "heart.fill")
                    .foregroundStyle(.pink)
                Spacer()
                Text(healthKitConnected ? "Connected" : "Connect")
                    .font(.caption)
                    .foregroundStyle(healthKitConnected ? AppColors.success : AppColors.accent)
            }
        }
        .task {
            // Check if already authorized on appear
            let available = await HealthKitService.shared.isAvailable
            if available {
                let hasData = try? await HealthKitService.shared.latestWeight()
                healthKitConnected = hasData != nil
            }
        }
    }

    private var notificationsRow: some View {
        HStack {
            Label("Daily Reminders", systemImage: "bell.fill")
                .foregroundStyle(AppColors.warning)
            Spacer()
            Toggle("", isOn: Binding(
                get: { remindersEnabled },
                set: { newValue in
                    Task { await toggleReminders(newValue) }
                }
            ))
            .tint(AppColors.accent)
        }
    }

    // MARK: - Actions

    private func sync() async {
        guard let userId = auth.user?.id else { return }
        isSyncing = true
        appState.syncError = nil
        defer { isSyncing = false }
        do {
            try await SyncService.shared.sync(userId: userId, modelContext: modelContext)
        } catch {
            appState.syncError = "Sync failed. Check your connection and try again."
        }
    }

    private func startFresh() {
        for entry in weights { modelContext.delete(entry) }
        for goal in goals { modelContext.delete(goal) }
        for comp in bodyComps { modelContext.delete(comp) }
        for checkIn in checkIns { modelContext.delete(checkIn) }
        try? modelContext.save()
    }

    private func exportData() {
        let weightData = weights.map { entry in
            [
                "id": entry.id,
                "date": entry.date,
                "weight": String(entry.weight),
                "unit": entry.unit,
                "notes": entry.notes,
                "isMorning": entry.isMorning ? "true" : "false"
            ]
        }
        let goalData = goals.map { goal in
            [
                "id": goal.id,
                "targetWeight": String(goal.targetWeight),
                "startWeight": String(goal.startWeight),
                "unit": goal.unit,
                "startDate": goal.startDate,
                "targetDate": goal.targetDate,
                "active": goal.isActive ? "true" : "false"
            ]
        }
        let bodyCompData: [[String: String]] = bodyComps.map { entry in
            var dict: [String: String] = [
                "id": entry.id,
                "date": entry.date,
            ]
            dict["bodyFatPercent"] = entry.bodyFatPercent.map { String($0) } ?? ""
            dict["muscleMass"] = entry.muscleMass.map { String($0) } ?? ""
            dict["waist"] = entry.waist.map { String($0) } ?? ""
            dict["hips"] = entry.hips.map { String($0) } ?? ""
            dict["chest"] = entry.chest.map { String($0) } ?? ""
            dict["arms"] = entry.arms.map { String($0) } ?? ""
            dict["thighs"] = entry.thighs.map { String($0) } ?? ""
            return dict
        }
        let checkInData = checkIns.map { entry in
            [
                "id": entry.id,
                "weekOf": entry.weekOf,
                "energy": String(entry.energyLevel),
                "sleep": String(entry.sleepQuality),
                "hunger": String(entry.hungerRating),
                "stress": String(entry.stressLevel),
                "notes": entry.notes,
            ]
        }
        let export: [String: Any] = [
            "weights": weightData,
            "goals": goalData,
            "bodyComposition": bodyCompData,
            "weeklyCheckIns": checkInData,
        ]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: export, options: .prettyPrinted) else { return }

        let dateStr = DateHelpers.todayString()
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("subtle-backup-\(dateStr).json")
        try? jsonData.write(to: tempURL)

        let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }

    private func importData() {
        showImporter = true
    }

    private func connectHealthKit() async {
        do {
            try await HealthKitService.shared.requestAuthorization()
            healthKitConnected = true
        } catch {
            print("HealthKit auth failed: \(error)")
        }
    }

    private func toggleReminders(_ enabled: Bool) async {
        if enabled {
            do {
                let granted = try await NotificationService.shared.requestPermission()
                if granted {
                    await NotificationService.shared.scheduleDailyReminder()
                    await NotificationService.shared.scheduleStreakReminder()
                    remindersEnabled = true
                } else {
                    remindersEnabled = false
                }
            } catch {
                remindersEnabled = false
            }
        } else {
            await NotificationService.shared.cancelDailyReminder()
            remindersEnabled = false
        }
    }
}
