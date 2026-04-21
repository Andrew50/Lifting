//
//  CreateAccountView.swift
//  Lifting
//

import SwiftUI

struct CreateAccountView: View {
    @ObservedObject var authStore: AuthStore
    var dismissSheet: (() -> Void)? = nil

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
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if dismissSheet != nil {
                        Button {
                            dismissSheet?()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                                .frame(width: 36, height: 36)
                                .background(AppTheme.cardBackground)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(AppTheme.cardBorder, lineWidth: 1))
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Create account")
                            .font(.system(size: 28, weight: .heavy))
                            .foregroundStyle(AppTheme.textPrimary)
                            .tracking(-0.4)
                        Text("Start tracking your lifts in seconds")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(.bottom, 32)

                    if let errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 13))
                            Text(errorMessage)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(Color(hex: "#DC2626"))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(hex: "#FEE2E2"))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .padding(.bottom, 16)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("NAME")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppTheme.textTertiary)
                            .tracking(0.5)
                        TextField("Your name", text: $name)
                            .textContentType(.name)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .name)
                            .font(.system(size: 15))
                            .foregroundStyle(AppTheme.textPrimary)
                            .padding(14)
                            .background(AppTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(focusedField == .name ? AppTheme.accent : AppTheme.cardBorder,
                                            lineWidth: focusedField == .name ? 1.5 : 1)
                            )
                    }
                    .padding(.bottom, 14)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("EMAIL")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppTheme.textTertiary)
                            .tracking(0.5)
                        TextField("you@email.com", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .email)
                            .font(.system(size: 15))
                            .foregroundStyle(AppTheme.textPrimary)
                            .padding(14)
                            .background(AppTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(focusedField == .email ? AppTheme.accent : AppTheme.cardBorder,
                                            lineWidth: focusedField == .email ? 1.5 : 1)
                            )
                    }
                    .padding(.bottom, 14)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("PASSWORD")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppTheme.textTertiary)
                            .tracking(0.5)
                        SecureField("", text: $password)
                            .textContentType(.newPassword)
                            .focused($focusedField, equals: .password)
                            .font(.system(size: 15))
                            .foregroundStyle(AppTheme.textPrimary)
                            .padding(14)
                            .background(AppTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(focusedField == .password ? AppTheme.accent : AppTheme.cardBorder,
                                            lineWidth: focusedField == .password ? 1.5 : 1)
                            )
                    }
                    .padding(.bottom, 24)

                    Button {
                        handleSignUp()
                    } label: {
                        ZStack {
                            if isLoading {
                                SwiftUI.ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Create Account")
                                    .font(.system(size: 16, weight: .bold))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(isLoading)

                    HStack(spacing: 12) {
                        Rectangle().fill(AppTheme.fieldBorder).frame(height: 1)
                        Text("OR")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.textTertiary)
                        Rectangle().fill(AppTheme.fieldBorder).frame(height: 1)
                    }
                    .padding(.vertical, 20)

                    Button {
                        // Sign in with Apple
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 16))
                            Text("Continue with Apple")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    Spacer().frame(height: 32)

                    HStack(spacing: 4) {
                        Text("Already have an account?")
                            .foregroundStyle(AppTheme.textSecondary)
                        NavigationLink {
                            LoginView(authStore: authStore, dismissSheet: dismissSheet)
                        } label: {
                            Text("Log in")
                                .fontWeight(.bold)
                                .foregroundStyle(AppTheme.accent)
                        }
                    }
                    .font(.system(size: 14))
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 24)
                .animation(.easeInOut(duration: 0.25), value: errorMessage)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationBarHidden(true)
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
