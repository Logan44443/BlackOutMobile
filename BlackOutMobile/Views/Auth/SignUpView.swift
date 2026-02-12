import SwiftUI

struct SignUpView: View {
    @ObservedObject var viewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.cardBlack.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    Spacer().frame(height: 20)

                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 44))
                            .foregroundColor(.accentPurple)

                        Text("Create Account")
                            .font(.title.bold())
                            .foregroundColor(.white)

                        Text("Join the game. Don't miss out.")
                            .font(.subheadline)
                            .foregroundColor(.textSecondary)
                    }

                    // Form
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Name")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                            TextField("", text: $viewModel.name)
                                .textFieldStyle(.plain)
                                .textContentType(.name)
                                .padding()
                                .background(Color.surfaceMedium)
                                .cornerRadius(12)
                                .foregroundColor(.white)
                        }

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
                                .textContentType(.newPassword)
                                .padding()
                                .background(Color.surfaceMedium)
                                .cornerRadius(12)
                                .foregroundColor(.white)

                            Text("Minimum 6 characters")
                                .font(.caption2)
                                .foregroundColor(.textSecondary)
                        }

                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.dangerRed)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 4)

                    // Sign Up Button
                    Button(action: viewModel.signUp) {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Create Account")
                        }
                    }
                    .buttonStyle(BlackoutButtonStyle())
                    .disabled(viewModel.isLoading)

                    // Back to Login
                    Button {
                        viewModel.clearFields()
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Text("Already have an account?")
                                .foregroundColor(.textSecondary)
                            Text("Sign In")
                                .foregroundColor(.accentPurple)
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    viewModel.clearFields()
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white)
                }
            }
        }
    }
}
