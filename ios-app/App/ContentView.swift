import SwiftUI

struct ContentView: View {
    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @State private var showWeighIn = false
    @State private var celebrationData: CelebrationData?

    var body: some View {
        Group {
            if auth.isLoading {
                LaunchScreen()
            } else if !auth.isAuthenticated {
                AuthView()
            } else if appState.showOnboarding {
                OnboardingView {
                    appState.completeOnboarding()
                }
            } else {
                MainTabView(
                    showWeighIn: $showWeighIn,
                    celebrationData: $celebrationData
                )
            }
        }
        .sheet(isPresented: $showWeighIn) {
            WeighInSheet { data in
                showWeighIn = false
                // Brief delay so sheet dismisses before celebration
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    celebrationData = data
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(item: $celebrationData) { data in
            CelebrationView(data: data) {
                celebrationData = nil
            }
        }
        .onChange(of: auth.isAuthenticated) { _, isAuth in
            if isAuth, let userId = auth.user?.id {
                Task {
                    try? await SyncService.shared.sync(userId: userId, modelContext: modelContext)
                }
            }
        }
    }
}

struct LaunchScreen: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            VStack(spacing: 8) {
                Text("subtle")
                    .font(.custom("System", size: 36, relativeTo: .largeTitle))
                    .fontWeight(.black)
                    .foregroundStyle(.accent)
                Text("Loading...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct MainTabView: View {
    @Binding var showWeighIn: Bool
    @Binding var celebrationData: CelebrationData?
    @State private var selectedTab: Tab = .home

    enum Tab: String, CaseIterable {
        case home, progress, weighIn, friends, profile
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView(showWeighIn: $showWeighIn)
                    .tag(Tab.home)

                ProgressView()
                    .tag(Tab.progress)

                // Placeholder — FAB handles this
                Color.clear
                    .tag(Tab.weighIn)

                FriendsView()
                    .tag(Tab.friends)

                ProfileView()
                    .tag(Tab.profile)
            }

            // Custom Tab Bar with FAB
            CustomTabBar(
                selectedTab: $selectedTab,
                onWeighIn: { showWeighIn = true }
            )
        }
    }
}
