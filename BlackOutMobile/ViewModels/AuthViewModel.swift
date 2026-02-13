import Foundation
import SwiftUI

@MainActor
class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var name = ""
    @Published var username = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    /// After signup with email confirmation enabled, show a "check your email" alert.
    @Published var showEmailVerificationAlert = false

    /// Credentials saved after signup so we can auto-login once verified.
    private var pendingEmail: String?
    private var pendingPassword: String?

    private let store = DataStore.shared

    var isAuthenticated: Bool {
        store.isAuthenticated
    }

    func login() {
        errorMessage = nil
        guard !email.isEmpty else {
            errorMessage = "Please enter your email"
            return
        }
        guard isValidEmail(email) else {
            errorMessage = "Please enter a valid email address (must contain @)"
            return
        }
        guard !password.isEmpty else {
            errorMessage = "Please enter your password"
            return
        }

        isLoading = true
        Task { [weak self] in
            guard let self else { return }
            let success = await self.store.login(email: self.email, password: self.password)
            self.isLoading = false
            if !success {
                self.errorMessage = "Invalid email or password."
            }
        }
    }

    func signUp() {
        errorMessage = nil
        guard !name.isEmpty else {
            errorMessage = "Please enter your name"
            return
        }
        guard !username.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter a username"
            return
        }
        guard !email.isEmpty else {
            errorMessage = "Please enter your email"
            return
        }
        guard isValidEmail(email) else {
            errorMessage = "Please enter a valid email address (must contain @)"
            return
        }
        guard !password.isEmpty else {
            errorMessage = "Please enter a password"
            return
        }
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters"
            return
        }

        isLoading = true
        Task { [weak self] in
            guard let self else { return }
            let result = await self.store.signUp(name: self.name, username: self.username, email: self.email, password: self.password)
            self.isLoading = false

            switch result {
            case .loggedIn:
                // Email confirmation disabled — user is already signed in.
                break
            case .needsEmailVerification:
                // Email confirmation enabled — save creds so we can auto-login later.
                self.pendingEmail = self.email
                self.pendingPassword = self.password
                self.showEmailVerificationAlert = true
            case .failed:
                self.errorMessage = "Unable to create account. Check email/username and try again."
            }
        }
    }

    /// Call after user dismisses the verification alert. Attempt to auto-login
    /// (in case they already verified in the browser / mail app).
    func attemptAutoLoginAfterVerification() {
        guard let email = pendingEmail, let password = pendingPassword else { return }
        isLoading = true
        Task { [weak self] in
            guard let self else { return }
            let success = await self.store.login(email: email, password: password)
            self.isLoading = false
            if success {
                self.pendingEmail = nil
                self.pendingPassword = nil
            }
            // If it fails silently, the user can tap Sign In manually.
        }
    }

    func clearFields() {
        email = ""
        password = ""
        name = ""
        username = ""
        errorMessage = nil
    }

    /// Email must contain @ for verification codes and valid format.
    private func isValidEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("@") else { return false }
        let parts = trimmed.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false)
        return parts.count == 2 && !parts[0].isEmpty && !parts[1].isEmpty
    }
}
