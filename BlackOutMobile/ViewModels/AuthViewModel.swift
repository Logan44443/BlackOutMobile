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

        // Simulate brief network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            let success = self.store.login(email: self.email, password: self.password)
            self.isLoading = false
            if !success {
                let hasUser = self.store.users.contains { $0.email.lowercased() == self.email.trimmingCharacters(in: .whitespaces).lowercased() }
                self.errorMessage = hasUser ? "Wrong password." : "No account found with that email. Please sign up first."
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

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            let success = self.store.signUp(name: self.name, username: self.username, email: self.email, password: self.password)
            self.isLoading = false
            if !success {
                self.errorMessage = "That email or username is already taken."
            }
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
