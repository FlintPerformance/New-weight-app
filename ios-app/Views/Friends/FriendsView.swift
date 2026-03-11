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
                }
            }
        }
    }
}

// MARK: - Tab Views (stubs to be implemented)

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
            // Avatar
            Circle()
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

struct PredictionsTabView: View {
    let predictions: [Prediction]
    var body: some View {
        ContentUnavailableView("Predictions", systemImage: "chart.bar.xaxis", description: Text("Make weight predictions and challenge friends"))
            .padding()
    }
}

struct MembersTabView: View {
    let members: [CircleMember]
    var body: some View {
        ContentUnavailableView("Squad", systemImage: "person.3.fill", description: Text("Your circle members will appear here"))
            .padding()
    }
}

struct CompareTabView: View {
    var body: some View {
        ContentUnavailableView("Compare", systemImage: "chart.xyaxis.line", description: Text("Compare weight trends with friends"))
            .padding()
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
