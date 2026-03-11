import SwiftUI

struct FriendsView: View {
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var vm = CircleViewModel()
    @State private var showCreate = false
    @State private var showJoin = false

    var body: some View {
        NavigationStack {
            Group {
                if vm.circles.isEmpty && !vm.isLoading {
                    emptyState
                } else {
                    circleContent
                }
            }
            .navigationTitle("Friends")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Start a Circle", systemImage: "plus.circle") { showCreate = true }
                        Button("Join Friends", systemImage: "person.badge.plus") { showJoin = true }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreate) { CreateCircleSheet(vm: vm, userId: auth.user?.id ?? "") }
            .sheet(isPresented: $showJoin) { JoinCircleSheet(vm: vm, userId: auth.user?.id ?? "") }
            .task {
                if let userId = auth.user?.id {
                    await vm.loadCircles(userId: userId)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.3")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("No circles yet")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Text("Create a circle and invite friends to share your progress, react to entries, and make predictions!")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(spacing: 12) {
                Button {
                    showCreate = true
                } label: {
                    Label("Start a Circle", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.accent)

                Button {
                    showJoin = true
                } label: {
                    Label("Join Friends", systemImage: "person.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 40)
        }
        .frame(maxHeight: .infinity)
    }

    private var circleContent: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("Tab", selection: $vm.selectedTab) {
                ForEach(CircleViewModel.CircleTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            // Tab content
            ScrollView {
                switch vm.selectedTab {
                case .feed:
                    FeedTabView(feed: vm.feed)
                case .predictions:
                    PredictionsTabView(predictions: vm.predictions)
                case .members:
                    MembersTabView(members: vm.members)
                case .compare:
                    CompareTabView()
                        .environmentObject(vm)
                }
            }
        }
    }
}

// MARK: - Feed Tab

struct FeedTabView: View {
    let feed: [FeedEntry]

    var body: some View {
        if feed.isEmpty {
            ContentUnavailableView("No activity yet", systemImage: "list.bullet", description: Text("Entries from your circle will show up here"))
        } else {
            LazyVStack(spacing: 12) {
                ForEach(feed) { entry in
                    FeedEntryCard(entry: entry)
                }
            }
            .padding()
        }
    }
}

struct FeedEntryCard: View {
    let entry: FeedEntry

    var body: some View {
        HStack(spacing: 12) {
            SwiftUI.Circle()
                .fill(AppColors.accent.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(entry.displayName.prefix(1)).uppercased())
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(AppColors.accent)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(DateHelpers.timeAgo(from: entry.createdAt))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text(WeightConverter.format(entry.weight, unit: WeightUnit(rawValue: entry.unit) ?? .lb))
                .font(.headline)
                .fontWeight(.semibold)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Squad Tab

struct MembersTabView: View {
    let members: [CircleMember]

    var body: some View {
        if members.isEmpty {
            ContentUnavailableView("No members yet", systemImage: "person.3.fill", description: Text("Invite friends to join your circle"))
                .padding()
        } else {
            LazyVStack(spacing: 12) {
                ForEach(members) { member in
                    MemberCard(member: member)
                }
            }
            .padding()
        }
    }
}

struct MemberCard: View {
    let member: CircleMember

    private var avatarColor: Color {
        let colors: [Color] = [AppColors.accent, AppColors.success, AppColors.warning, .purple, .orange, .pink]
        let index = abs(member.userId.hashValue) % colors.count
        return colors[index]
    }

    var body: some View {
        HStack(spacing: 14) {
            // Avatar
            SwiftUI.Circle()
                .fill(avatarColor.opacity(0.2))
                .frame(width: 52, height: 52)
                .overlay(
                    Text(String(member.displayName.prefix(1)).uppercased())
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(avatarColor)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(member.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    if member.role == "owner" {
                        Text("OWNER")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppColors.accent.opacity(0.15))
                            .foregroundStyle(AppColors.accent)
                            .clipShape(Capsule())
                    }
                }

                Text("Joined \(member.joinedAt.formatted(.relative(presentation: .named)))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.quaternary)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Predictions Tab

struct PredictionsTabView: View {
    let predictions: [Prediction]

    var body: some View {
        if predictions.isEmpty {
            ContentUnavailableView("No predictions yet", systemImage: "chart.bar.xaxis", description: Text("Predictions from your circle will show up here"))
                .padding()
        } else {
            LazyVStack(spacing: 12) {
                ForEach(predictions) { prediction in
                    PredictionCard(prediction: prediction)
                }
            }
            .padding()
        }
    }
}

struct PredictionCard: View {
    let prediction: Prediction

    private var isExpired: Bool { prediction.deadline < Date() }
    private var daysLeft: Int { max(0, Calendar.current.dateComponents([.day], from: Date(), to: prediction.deadline).day ?? 0) }
    private var weightChange: Double { prediction.predictedWeight - prediction.startWeight }
    private var isLoss: Bool { weightChange < 0 }
    private var unitLabel: String { WeightUnit(rawValue: prediction.unit)?.rawValue ?? prediction.unit }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 10) {
                SwiftUI.Circle()
                    .fill(AppColors.accent.opacity(0.2))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(String(prediction.displayName.prefix(1)).uppercased())
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(AppColors.accent)
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(prediction.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(prediction.resolved ? "Resolved" : isExpired ? "Expired" : "\(daysLeft)d left")
                        .font(.caption2)
                        .foregroundStyle(prediction.resolved ? AppColors.success : isExpired ? AppColors.danger : .secondary)
                }

                Spacer()

                // Status badge
                if prediction.resolved {
                    Label("Done", systemImage: "checkmark.circle.fill")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(AppColors.success)
                }
            }

            // Prediction details
            HStack(spacing: 0) {
                VStack(spacing: 2) {
                    Text("Start")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(WeightConverter.format(prediction.startWeight, unit: WeightUnit(rawValue: prediction.unit) ?? .lb))
                        .font(.callout)
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                }
                .frame(maxWidth: .infinity)

                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                VStack(spacing: 2) {
                    Text("Predicted")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(WeightConverter.format(prediction.predictedWeight, unit: WeightUnit(rawValue: prediction.unit) ?? .lb))
                        .font(.callout)
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                        .foregroundStyle(AppColors.accent)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 2) {
                    Text("Change")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text("\(isLoss ? "" : "+")\(String(format: "%.1f", weightChange)) \(unitLabel)")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                        .foregroundStyle(isLoss ? AppColors.success : AppColors.warning)
                }
                .frame(maxWidth: .infinity)
            }

            // Message
            if let message = prediction.message, !message.isEmpty {
                Text("\"\(message)\"")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
            }

            // Deadline bar
            HStack {
                Image(systemName: "calendar")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text("Deadline: \(prediction.deadline.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                if let actual = prediction.actualWeight, prediction.resolved {
                    Text("Actual: \(WeightConverter.format(actual, unit: WeightUnit(rawValue: prediction.unit) ?? .lb))")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(AppColors.accent)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Compare Tab

struct CompareTabView: View {
    @EnvironmentObject var vm: CircleViewModel

    var body: some View {
        if vm.members.count < 2 {
            ContentUnavailableView("Need more members", systemImage: "chart.xyaxis.line", description: Text("Invite at least one friend to compare trends"))
                .padding()
        } else {
            VStack(spacing: 16) {
                // Header
                Text("MEMBER COMPARISON")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .tracking(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(vm.members) { member in
                    CompareMemberRow(member: member, feed: vm.feed)
                }
            }
            .padding()
        }
    }
}

struct CompareMemberRow: View {
    let member: CircleMember
    let feed: [FeedEntry]

    private var memberEntries: [FeedEntry] {
        feed.filter { $0.userId == member.userId }.sorted { $0.date > $1.date }
    }

    private var latestWeight: Double? { memberEntries.first?.weight }
    private var entryCount: Int { memberEntries.count }
    private var unitLabel: String { memberEntries.first.map { WeightUnit(rawValue: $0.unit)?.rawValue ?? $0.unit } ?? "lb" }

    private var change: Double? {
        guard memberEntries.count >= 2 else { return nil }
        let sorted = memberEntries.sorted { $0.date < $1.date }
        return sorted.last!.weight - sorted.first!.weight
    }

    private var avatarColor: Color {
        let colors: [Color] = [AppColors.accent, AppColors.success, AppColors.warning, .purple, .orange, .pink]
        let index = abs(member.userId.hashValue) % colors.count
        return colors[index]
    }

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            SwiftUI.Circle()
                .fill(avatarColor.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(String(member.displayName.prefix(1)).uppercased())
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(avatarColor)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(member.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                if entryCount > 0 {
                    Text("\(entryCount) entries logged")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                } else {
                    Text("No entries yet")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Stats
            VStack(alignment: .trailing, spacing: 4) {
                if let weight = latestWeight {
                    Text(WeightConverter.format(weight, unit: WeightUnit(rawValue: unitLabel) ?? .lb))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                } else {
                    Text("--")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }

                if let change {
                    Text("\(change > 0 ? "+" : "")\(String(format: "%.1f", change)) \(unitLabel)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(change < 0 ? AppColors.success : change > 0 ? AppColors.danger : .secondary)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Create / Join sheets

struct CreateCircleSheet: View {
    @ObservedObject var vm: CircleViewModel
    let userId: String
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var isCreating = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Circle name (e.g. Gym Buddies)", text: $name)
            }
            .navigationTitle("Start a Circle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        isCreating = true
                        Task {
                            try? await vm.createCircle(name: name.trimmingCharacters(in: .whitespaces), userId: userId)
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
                }
            }
        }
    }
}

struct JoinCircleSheet: View {
    @ObservedObject var vm: CircleViewModel
    let userId: String
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var isJoining = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Enter 6-character code", text: $code)
                    .textInputAutocapitalization(.characters)
                    .font(.system(.title2, design: .monospaced))
                    .multilineTextAlignment(.center)

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
            .navigationTitle("Join Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Join") {
                        isJoining = true
                        errorMessage = nil
                        Task {
                            do {
                                try await vm.joinCircle(code: code, userId: userId)
                                dismiss()
                            } catch {
                                errorMessage = error.localizedDescription
                                isJoining = false
                            }
                        }
                    }
                    .disabled(code.count != 6 || isJoining)
                }
            }
        }
    }
}
