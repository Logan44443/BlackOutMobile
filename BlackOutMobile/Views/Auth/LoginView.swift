import SwiftUI

struct LoginView: View {
    @ObservedObject var viewModel: AuthViewModel
    @State private var showSignUp = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cardBlack.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        Spacer().frame(height: 60)

                        // Logo / Branding
                        VStack(spacing: 12) {
                            Image(systemName: "suit.spade.fill")
                                .font(.system(size: 64))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.accentPurple, .accentGlow],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: .accentPurple.opacity(0.5), radius: 20)

                            Text("BLACKOUT")
                                .font(.system(size: 36, weight: .black, design: .rounded))
                                .foregroundColor(.white)

                            Text("Pull your card. Show up.")
                                .font(.subheadline)
                                .foregroundColor(.textSecondary)
                        }

                        // Form
                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email")
                                    .font(.caption)
                                    .foregroundColor(.textSecondary)
                                TextField("", text: $viewModel.email)
                                    .textFieldStyle(.plain)
                                    .keyboardType(.emailAddress)
                                    .textContentType(.emailAddress)
                                    .autocapitalization(.none)
                                    .padding()
                                    .background(Color.surfaceMedium)
                                    .cornerRadius(12)
                                    .foregroundColor(.white)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password")
                                    .font(.caption)
                                    .foregroundColor(.textSecondary)
                                SecureField("", text: $viewModel.password)
                                    .textFieldStyle(.plain)
                                    .textContentType(.password)
                                    .padding()
                                    .background(Color.surfaceMedium)
                                    .cornerRadius(12)
                                    .foregroundColor(.white)
                            }

                            if let error = viewModel.errorMessage {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.dangerRed)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.horizontal, 4)

                        // Login Button
                        Button(action: viewModel.login) {
                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Sign In")
                            }
                        }
                        .buttonStyle(BlackoutButtonStyle())
                        .disabled(viewModel.isLoading)

                        // Sign Up Link
                        Button {
                            viewModel.clearFields()
                            showSignUp = true
                        } label: {
                            HStack(spacing: 4) {
                                Text("Don't have an account?")
                                    .foregroundColor(.textSecondary)
                                Text("Sign Up")
                                    .foregroundColor(.accentPurple)
                                    .fontWeight(.semibold)
                            }
                            .font(.subheadline)
                        }

                        // Demo Data Button (for development)
                        Button {
                            DataStore.shared.seedDemoData()
                            DataStore.shared.login(email: "alice@demo.com", password: "password")
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "play.fill")
                                Text("Load Demo Data")
                            }
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                            .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationDestination(isPresented: $showSignUp) {
                SignUpView(viewModel: viewModel)
            }
        }
    }
}
