import SwiftUI
import SwiftData

struct ProfileView: View {
    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    @Query(sort: \Goal.createdAt, order: .reverse) private var goals: [Goal]

    @State private var showLogout = false
    @State private var isSyncing = false
    @State private var showImporter = false

    private var streak: Int {
        let uniqueDates = Array(Set(weights.map(\.date))).sorted(by: >)
        guard !uniqueDates.isEmpty else { return 0 }
        let today = DateHelpers.todayString()
        let yesterday = DateHelpers.daysAgo(1)
        guard uniqueDates[0] == today || uniqueDates[0] == yesterday else { return 0 }
        var count = 1
        for i in 1..<uniqueDates.count {
            guard let prev = DateHelpers.date(from: uniqueDates[i - 1]),
                  let curr = DateHelpers.date(from: uniqueDates[i]) else { break }
            if Calendar.current.dateComponents([.day], from: curr, to: prev).day == 1 { count += 1 }
            else { break }
        }
        return count
    }

    private var daysTracked: Int {
        guard let first = weights.last else { return 0 }
        guard let date = DateHelpers.date(from: first.date) else { return 0 }
        return max(1, Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 1)
    }

    var body: some View {
        NavigationStack {
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
                    Button("Start Fresh", role: .destructive) { }
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
            .navigationTitle("Profile")
            .alert("Log Out?", isPresented: $showLogout) {
                Button("Log Out", role: .destructive) { auth.signOut() }
                Button("Cancel", role: .cancel) { }
            }
        }
    }

    // MARK: - Sections

    private var profileCard: some View {
        HStack(spacing: 16) {
            Circle()
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

    private var statsGrid: some View {
        HStack(spacing: 12) {
            StatCard(title: "Entries", value: "\(weights.count)", subtitle: "logged", color: .primary)
            StatCard(title: "Streak", value: "\(streak)", subtitle: "days", color: AppColors.accent)
            StatCard(title: "Tracking", value: "\(daysTracked)", subtitle: "days", color: .primary)
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
        HStack {
            Text("Chart Color")
            Spacer()
            HStack(spacing: 6) {
                ForEach(AppColors.graphColors.prefix(4), id: \.hex) { item in
                    Circle()
                        .fill(item.color)
                        .frame(width: 24, height: 24)
                }
                Text("+\(AppColors.graphColors.count - 4)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var healthKitRow: some View {
        HStack {
            Label("Apple Health", systemImage: "heart.fill")
                .foregroundStyle(.pink)
            Spacer()
            Text("Connect")
                .font(.caption)
                .foregroundStyle(AppColors.accent)
        }
    }

    private var notificationsRow: some View {
        HStack {
            Label("Daily Reminders", systemImage: "bell.fill")
                .foregroundStyle(AppColors.warning)
            Spacer()
            Toggle("", isOn: .constant(false))
                .tint(AppColors.accent)
        }
    }

    // MARK: - Actions

    private func sync() async {
        guard let userId = auth.user?.id else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            try await SyncService.shared.sync(userId: userId, modelContext: modelContext)
        } catch {
            print("Sync failed: \(error)")
        }
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
        let export: [String: Any] = ["weights": weightData, "goals": goalData]
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
}
