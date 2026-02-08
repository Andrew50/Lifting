//
//  ProfileView.swift
//  Lifting
//

import SwiftUI

struct ProfileView: View {
    @ObservedObject var authStore: AuthStore
    @State private var isAuthSheetPresented = false

    @AppStorage("weightUnit") private var weightUnit: String = "lbs"
    @AppStorage("distanceUnit") private var distanceUnit: String = "mi"
    @AppStorage("timerSound") private var timerSound: Bool = true
    @AppStorage("timerVibration") private var timerVibration: Bool = true
    @AppStorage("defaultRestTime") private var defaultRestTime: Int = 120

    private let weightOptions = ["lbs", "kg"]
    private let distanceOptions = ["mi", "km"]
    private let restTimeOptions = [60, 90, 120, 150, 180, 240, 300]

    private func restTimeLabel(_ seconds: Int) -> String {
        let min = seconds / 60
        let sec = seconds % 60
        return sec == 0 ? "\(min) min" : "\(min):\(String(format: "%02d", sec))"
    }

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

    // MARK: - Settings Sections (shared between logged-in and logged-out)

    private var settingsSections: some View {
        Group {
            Section("Units") {
                HStack {
                    Label("Weight", systemImage: "scalemass")
                    Spacer()
                    Picker("", selection: $weightUnit) {
                        ForEach(weightOptions, id: \.self) { unit in
                            Text(unit).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                }

                HStack {
                    Label("Distance", systemImage: "figure.run")
                    Spacer()
                    Picker("", selection: $distanceUnit) {
                        ForEach(distanceOptions, id: \.self) { unit in
                            Text(unit).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                }
            }

            Section("Rest Timer") {
                Picker(selection: $defaultRestTime) {
                    ForEach(restTimeOptions, id: \.self) { seconds in
                        Text(restTimeLabel(seconds)).tag(seconds)
                    }
                } label: {
                    Label("Default Rest Time", systemImage: "clock")
                }

                Toggle(isOn: $timerSound) {
                    Label("Timer Sound", systemImage: "speaker.wave.2")
                }

                Toggle(isOn: $timerVibration) {
                    Label("Vibration", systemImage: "iphone.radiowaves.left.and.right")
                }
            }

            Section("About") {
                HStack {
                    Label("Version", systemImage: "info.circle")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }
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

            settingsSections

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
        List {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "person.circle")
                        .font(.system(size: 52))
                        .foregroundStyle(AuthTheme.primary.opacity(0.6))

                    Text("Sign in to sync your data across devices.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button {
                        isAuthSheetPresented = true
                    } label: {
                        Text("Log in here")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AuthTheme.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(.vertical, 12)
            }

            settingsSections
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
