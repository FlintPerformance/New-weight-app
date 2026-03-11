import SwiftUI
import Supabase

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = true
    @Published var user: AppUser?
    @Published var errorMessage: String?

    private var authListener: Task<Void, Never>?

    init() {
        Task { await checkSession() }
        listenForAuthChanges()
    }

    deinit {
        authListener?.cancel()
    }

    // MARK: - Session

    private func checkSession() async {
        do {
            let session = try await SupabaseService.client.auth.session
            setUser(from: session.user)
        } catch {
            isAuthenticated = false
        }
        isLoading = false
    }

    private func listenForAuthChanges() {
        authListener = Task {
            for await (_, session) in SupabaseService.client.auth.authStateChanges {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    if let session {
                        self.setUser(from: session.user)
                    } else {
                        self.user = nil
                        self.isAuthenticated = false
                    }
                }
            }
        }
    }

    private func setUser(from supabaseUser: User) {
        let metadata = supabaseUser.userMetadata
        let displayName = metadata["display_name"]?.stringValue
            ?? supabaseUser.email?.components(separatedBy: "@").first
            ?? "User"
        user = AppUser(
            id: supabaseUser.id.uuidString,
            email: supabaseUser.email ?? "",
            displayName: displayName
        )
        isAuthenticated = true
    }

    // MARK: - Auth actions

    func signUp(name: String, email: String, password: String) async {
        errorMessage = nil
        do {
            let result = try await SupabaseService.client.auth.signUp(
                email: email,
                password: password,
                data: ["display_name": .string(name)]
            )
            if let session = result.session {
                setUser(from: session.user)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signIn(email: String, password: String) async {
        errorMessage = nil
        do {
            let session = try await SupabaseService.client.auth.signIn(
                email: email,
                password: password
            )
            setUser(from: session.user)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        Task {
            try? await SupabaseService.client.auth.signOut()
            user = nil
            isAuthenticated = false
        }
    }

    func resetPassword(email: String) async {
        errorMessage = nil
        do {
            try await SupabaseService.client.auth.resetPasswordForEmail(email)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct AppUser {
    let id: String
    let email: String
    let displayName: String
}
