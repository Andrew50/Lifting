//
//  LoginView.swift
//  Lifting
//

import SwiftUI

struct LoginView: View {
    var dismissSheet: (() -> Void)?

    @State private var email: String = ""
    @State private var password: String = ""
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
                        CreateAccountView(dismissSheet: dismissSheet)
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

                Button("Log in") {
                    // Log in
                }
                .buttonStyle(PrimaryAuthButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
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
}

#Preview {
    NavigationStack {
        LoginView()
    }
}
