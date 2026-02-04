//
//  CreateAccountView.swift
//  Lifting
//

import SwiftUI

struct CreateAccountView: View {
    var dismissSheet: (() -> Void)?

    @State private var name: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
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
                        LoginView(dismissSheet: dismissSheet)
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(AuthTheme.primary)
                }
                .padding(.bottom, 28)

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

                Button("Sign up") {
                    // Create account
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
        CreateAccountView()
    }
}
