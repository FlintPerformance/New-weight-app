import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @EnvironmentObject var auth: AuthViewModel

    @State private var mode: AuthMode = .signUp
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""

    enum AuthMode {
        case signUp, signIn, resetPassword
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Brand
                VStack(spacing: 8) {
                    Text("subtle")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundStyle(AppColors.accent)

                    Text("Your friendly weight companion")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 60)

                // Features
                HStack(spacing: 20) {
                    featureIcon("scalemass", "Track")
                    featureIcon("chart.xyaxis.line", "Trend")
                    featureIcon("target", "Goal")
                    featureIcon("person.3", "Friends")
                }

                // Form
                VStack(spacing: 16) {
                    if mode == .signUp {
                        TextField("Your name", text: $name)
                            .textContentType(.name)
                            .textInputAutocapitalization(.words)
                    }

                    if mode != .resetPassword {
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)

                        SecureField("Password", text: $password)
                            .textContentType(mode == .signUp ? .newPassword : .password)
                    } else {
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                    }
                }
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 24)

                // Error
                if let error = auth.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(AppColors.danger)
                        .padding(.horizontal)
                }

                // Submit
                VStack(spacing: 12) {
                    Button {
                        Task { await submit() }
                    } label: {
                        Text(submitLabel)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.accent)
                    .padding(.horizontal, 24)

                    // Sign in with Apple
                    if mode != .resetPassword {
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
                            handleAppleSignIn(result)
                        }
                        .signInWithAppleButtonStyle(.whiteOutline)
                        .frame(height: 50)
                        .padding(.horizontal, 24)
                    }
                }

                // Toggle mode
                VStack(spacing: 8) {
                    if mode == .signIn {
                        Button("Need help getting in?") { mode = .resetPassword }
                            .font(.caption)
                    }

                    Button(toggleLabel) {
                        withAnimation { mode = mode == .signUp ? .signIn : .signUp }
                    }
                    .font(.subheadline)
                    .foregroundStyle(AppColors.accent)
                }

                Spacer()
            }
        }
    }

    // MARK: - Helpers

    private var submitLabel: String {
        switch mode {
        case .signUp: return "Get Started"
        case .signIn: return "Let's Go"
        case .resetPassword: return "Send Reset Link"
        }
    }

    private var toggleLabel: String {
        mode == .signUp ? "Already have an account? Sign In" : "New here? Create Account"
    }

    private func submit() async {
        switch mode {
        case .signUp: await auth.signUp(name: name, email: email, password: password)
        case .signIn: await auth.signIn(email: email, password: password)
        case .resetPassword: await auth.resetPassword(email: email)
        }
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityToken = credential.identityToken,
                  let tokenString = String(data: identityToken, encoding: .utf8) else {
                auth.errorMessage = "Failed to get Apple credential"
                return
            }

            let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")

            Task {
                await auth.signInWithApple(idToken: tokenString, displayName: fullName.isEmpty ? nil : fullName)
            }

        case .failure(let error):
            // User cancelled is not a real error
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                auth.errorMessage = error.localizedDescription
            }
        }
    }

    private func featureIcon(_ icon: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(AppColors.accent)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
