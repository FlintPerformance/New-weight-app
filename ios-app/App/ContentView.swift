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
        .animation(.easeInOut(duration: 0.3), value: auth.isLoading)
        .animation(.easeInOut(duration: 0.3), value: auth.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: appState.showOnboarding)
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
                    do {
                        try await SyncService.shared.sync(userId: userId, modelContext: modelContext)
                        appState.syncError = nil
                    } catch {
                        appState.syncError = "Couldn't sync your data. Changes are saved locally."
                    }
                }
            }
        }
        .overlay(alignment: .top) {
            if let syncError = appState.syncError {
                HStack(spacing: 8) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.caption)
                    Text(syncError)
                        .font(.caption)
                    Spacer()
                    Button {
                        withAnimation { appState.syncError = nil }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption2)
                            .fontWeight(.bold)
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AppColors.warning)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.syncError)
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
                    .foregroundStyle(AppColors.accent)
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
        case home, progress, weighIn, friends, health
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView(showWeighIn: $showWeighIn, onNavigateToProgress: {
                    withAnimation { selectedTab = .progress }
                })
                    .tag(Tab.home)

                ProgressView()
                    .tag(Tab.progress)

                // Placeholder — FAB handles this
                Color.clear
                    .tag(Tab.weighIn)

                FriendsView()
                    .tag(Tab.friends)

                HealthView()
                    .tag(Tab.health)
            }
            .animation(.snappy(duration: 0.25), value: selectedTab)

            // Custom Tab Bar with FAB
            CustomTabBar(
                selectedTab: $selectedTab,
                onWeighIn: { showWeighIn = true }
            )
        }
    }
}
