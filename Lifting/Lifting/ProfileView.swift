//
//  ProfileView.swift
//  Lifting
//

import SwiftUI

struct ProfileView: View {
    @ObservedObject var authStore: AuthStore
    @State private var isAuthSheetPresented = false

    var body: some View {
        Group {
            if let user = authStore.currentUser {
                loggedInContent(user: user)
            } else {
                loggedOutContent
            }
        }
        .navigationTitle("Profile")
        .sheet(isPresented: $isAuthSheetPresented) {
            NavigationStack {
                LoginView(
                    authStore: authStore,
                    dismissSheet: { isAuthSheetPresented = false }
                )
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    private func loggedInContent(user: UserRecord) -> some View {
        List {
            Section {
                HStack(spacing: 16) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(AuthTheme.primary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.name)
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text(user.email)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }

            Section {
                HStack {
                    Label("Member since", systemImage: "calendar")
                    Spacer()
                    Text(memberSinceFormatted(user.createdAt))
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button(role: .destructive) {
                    withAnimation {
                        authStore.logOut()
                    }
                } label: {
                    HStack {
                        Spacer()
                        Text("Log out")
                            .fontWeight(.medium)
                        Spacer()
                    }
                }
            }
        }
    }

    private var loggedOutContent: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "person.circle")
                .font(.system(size: 64))
                .foregroundStyle(AuthTheme.primary.opacity(0.6))

            Text("Profile")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Sign in to sync your data and access your account on all devices.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                isAuthSheetPresented = true
            } label: {
                Text("Log in here")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AuthTheme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)

            Spacer()
        }
    }

    private func memberSinceFormatted(_ timestamp: TimeInterval) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: Date(timeIntervalSince1970: timestamp))
    }
}

#Preview {
    NavigationStack {
        ProfileView(authStore: AppContainer().authStore)
    }
}
