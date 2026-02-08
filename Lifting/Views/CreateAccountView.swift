//
//  CreateAccountView.swift
//  Lifting
//

import SwiftUI

struct CreateAccountView: View {
    @ObservedObject var authStore: AuthStore
    var dismissSheet: (() -> Void)?

    @State private var name: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case name, email, password
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("Create New Account")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(AuthTheme.primary)
                    .padding(.top, 32)
                    .padding(.bottom, 8)

                HStack(spacing: 4) {
                    Text("Already Registered?")
                        .foregroundStyle(AuthTheme.subtitleGray)
                        .font(.subheadline)
                    NavigationLink("Log in here.") {
                        LoginView(authStore: authStore, dismissSheet: dismissSheet)
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(AuthTheme.primary)
                }
                .padding(.bottom, 28)

                if let errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(errorMessage)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(Color.red.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("NAME")
                        .modifier(AuthLabelStyle())
                    TextField("", text: $name)
                        .textContentType(.name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .name)
                        .modifier(AuthTextFieldStyle())
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

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
                    Text("PASSWORD")
                        .modifier(AuthLabelStyle())
                    SecureField("", text: $password)
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .password)
                        .modifier(AuthTextFieldStyle())
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)

                Button("Sign in with Google") {
                    // Sign with Google
                }
                .buttonStyle(SocialAuthButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 12)

                Button("Sign in with Apple") {
                    // Sign with Apple
                }
                .buttonStyle(SocialAuthButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 20)

                Button {
                    handleSignUp()
                } label: {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Sign up")
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

    private func handleSignUp() {
        focusedField = nil
        isLoading = true
        errorMessage = nil

        do {
            try authStore.signUp(name: name, email: email, password: password)
            dismissSheet?()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        CreateAccountView(authStore: AppContainer().authStore)
    }
}
