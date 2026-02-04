//
//  ProfileView.swift
//  Lifting
//

import SwiftUI

struct ProfileView: View {
    @State private var isAuthSheetPresented = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

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
        .navigationTitle("Profile")
        .sheet(isPresented: $isAuthSheetPresented) {
            NavigationStack {
                LoginView(dismissSheet: { isAuthSheetPresented = false })
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}

#Preview {
    ProfileView()
}
