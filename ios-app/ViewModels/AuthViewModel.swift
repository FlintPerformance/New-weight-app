import SwiftUI
import Combine

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = true
    @Published var user: AppUser?
    @Published var errorMessage: String?

    init() {
        // TODO: Check Supabase session on launch
        // For now, simulate loading
        Task {
            try? await Task.sleep(for: .seconds(0.5))
            isLoading = false
        }
    }

    // MARK: - Auth actions

    func signUp(name: String, email: String, password: String) async {
        errorMessage = nil
        do {
            // TODO: Supabase auth
            // let result = try await supabase.auth.signUp(email: email, password: password)
            // user = AppUser(from: result)
            // isAuthenticated = true
            throw AuthError.notImplemented
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signIn(email: String, password: String) async {
        errorMessage = nil
        do {
            // TODO: Supabase auth
            throw AuthError.notImplemented
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signInWithApple() async {
        errorMessage = nil
        // TODO: Implement Sign in with Apple
        // Required for App Store if you offer any social login
    }

    func signOut() {
        // TODO: Supabase sign out
        user = nil
        isAuthenticated = false
    }

    func resetPassword(email: String) async {
        errorMessage = nil
        do {
            // TODO: Supabase password reset
            throw AuthError.notImplemented
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

enum AuthError: LocalizedError {
    case notImplemented

    var errorDescription: String? {
        switch self {
        case .notImplemented: return "Auth not yet connected — wire up Supabase or Sign in with Apple"
        }
    }
}
