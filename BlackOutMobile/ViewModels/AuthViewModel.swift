import Foundation
import SwiftUI

@MainActor
class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var name = ""
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
                self.errorMessage = "No account found with that email. Please sign up first."
            }
        }
    }

    func signUp() {
        errorMessage = nil
        guard !name.isEmpty else {
            errorMessage = "Please enter your name"
            return
        }
        guard !email.isEmpty else {
            errorMessage = "Please enter your email"
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
            let success = self.store.signUp(name: self.name, email: self.email, password: self.password)
            self.isLoading = false
            if !success {
                self.errorMessage = "An account with that email already exists."
            }
        }
    }

    func clearFields() {
        email = ""
        password = ""
        name = ""
        errorMessage = nil
    }
}
