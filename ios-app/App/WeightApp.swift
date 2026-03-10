import SwiftUI
import SwiftData

@main
struct WeightApp: App {
    let container: ModelContainer

    @StateObject private var authVM = AuthViewModel()
    @StateObject private var appState = AppState()

    init() {
        do {
            let schema = Schema([
                WeightEntry.self,
                Goal.self,
                UserProfile.self,
            ])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authVM)
                .environmentObject(appState)
                .modelContainer(container)
                .onAppear {
                    appState.configure(container: container)
                }
        }
    }
}
