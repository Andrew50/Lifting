//
//  LoginView.swift
//  Lifting
//

import SwiftUI

struct LoginView: View {
    @ObservedObject var authStore: AuthStore
    var dismissSheet: (() -> Void)?

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case email, password
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("Log in")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(AuthTheme.primary)
                    .padding(.top, 32)
                    .padding(.bottom, 16)

                Text("Do you already have an account?")
                    .font(.subheadline)
                    .foregroundStyle(AuthTheme.subtitleGray)
                    .padding(.bottom, 12)

                HStack(spacing: 16) {
                    Text("Yes")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(AuthTheme.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AuthTheme.primary.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    NavigationLink {
                        CreateAccountView(authStore: authStore, dismissSheet: dismissSheet)
                    } label: {
                        Text("No")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(AuthTheme.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AuthTheme.socialButtonBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("EMAIL")
                        .modifier(AuthLabelStyle())
                    TextField("", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .email)
                        .modifier(AuthTextFieldStyle())
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("PASSWORD")
                            .modifier(AuthLabelStyle())
                        Spacer()
                        Button("Forgot Password?") {
                            // Forgot password flow
                        }
                        .font(.caption)
                        .foregroundStyle(AuthTheme.primary)
                    }
                    SecureField("", text: $password)
                        .textContentType(.password)
                        .focused($focusedField, equals: .password)
                        .modifier(AuthTextFieldStyle())
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)

                Button("Sign with Google") {
                    // Sign with Google
                }
                .buttonStyle(SocialAuthButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 12)

                Button("Sign with Apple") {
                    // Sign with Apple
                }
                .buttonStyle(SocialAuthButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 20)

                Button {
                    handleLogIn()
                } label: {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Log in")
                    }
                }
                .buttonStyle(PrimaryAuthButtonStyle())
                .disabled(isLoading)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .animation(.easeInOut(duration: 0.25), value: errorMessage)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if dismissSheet != nil {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismissSheet?()
                    }
                }
            }
        }
    }

    private func handleLogIn() {
        focusedField = nil
        isLoading = true
        errorMessage = nil

        do {
            try authStore.logIn(email: email, password: password)
            dismissSheet?()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        LoginView(authStore: AppContainer().authStore)
    }
}
