//
//  ProfileView.swift
//  Lifting
//

import SwiftUI
import UniformTypeIdentifiers

struct ProfileView: View {
    @ObservedObject var container: AppContainer
    @ObservedObject var authStore: AuthStore
    @State private var isAuthSheetPresented = false
    @State private var isImporting = false
    @State private var importMessage: String?
    @State private var showImportAlert = false
    @State private var showClearConfirmation = false
    @State private var isFileImporterPresented = false

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
        .alert("Import Status", isPresented: $showImportAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            if let importMessage {
                Text(importMessage)
            }
        }
        .confirmationDialog(
            "Are you sure you want to delete all workout history?",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All Data", role: .destructive) {
                clearData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            handleFilePicker(result: result)
        }
    }

    // MARK: - Settings Cards (shared between logged-in and logged-out)

    private var settingsCards: some View {
        VStack(spacing: 20) {
            // Units section
            VStack(alignment: .leading, spacing: 8) {
                Text("UNITS")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .tracking(0.5)
                    .padding(.horizontal, 16)

                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "scalemass")
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 24)
                        Text("Weight")
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        Picker("", selection: $weightUnit) {
                            ForEach(weightOptions, id: \.self) { unit in
                                Text(unit).tag(unit)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 120)
                        .tint(AppTheme.accent)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    Divider().overlay(AppTheme.fieldBorder).padding(.horizontal, 16)

                    HStack {
                        Image(systemName: "figure.run")
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 24)
                        Text("Distance")
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        Picker("", selection: $distanceUnit) {
                            ForEach(distanceOptions, id: \.self) { unit in
                                Text(unit).tag(unit)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 120)
                        .tint(AppTheme.accent)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                )
                .padding(.horizontal, 16)
            }

            // Rest Timer section
            VStack(alignment: .leading, spacing: 8) {
                Text("REST TIMER")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .tracking(0.5)
                    .padding(.horizontal, 16)

                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 24)
                        Text("Default Rest Time")
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        Picker("", selection: $defaultRestTime) {
                            ForEach(restTimeOptions, id: \.self) { seconds in
                                Text(restTimeLabel(seconds)).tag(seconds)
                            }
                        }
                        .tint(AppTheme.accent)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    Divider().overlay(AppTheme.fieldBorder).padding(.horizontal, 16)

                    HStack {
                        Image(systemName: "speaker.wave.2")
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 24)
                        Toggle("Timer Sound", isOn: $timerSound)
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.textPrimary)
                            .tint(AppTheme.accent)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    Divider().overlay(AppTheme.fieldBorder).padding(.horizontal, 16)

                    HStack {
                        Image(systemName: "iphone.radiowaves.left.and.right")
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 24)
                        Toggle("Vibration", isOn: $timerVibration)
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.textPrimary)
                            .tint(AppTheme.accent)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                )
                .padding(.horizontal, 16)
            }

            Text("Version 1.0.0")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textTertiary)
        }
    }

    private func loggedInContent(user: UserRecord) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Profile card
                HStack(spacing: 16) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(AppTheme.accent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.name)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(user.email)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                )
                .padding(.horizontal, 16)

                // Member since
                HStack {
                    Image(systemName: "calendar")
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 24)
                    Text("Member since")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Text(memberSinceFormatted(user.createdAt))
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                )
                .padding(.horizontal, 16)

                settingsCards

                // Import
                Button {
                    isFileImporterPresented = true
                } label: {
                    HStack {
                        Image(systemName: "doc.badge.plus")
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 24)
                        Text("Import Workouts")
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        if isImporting {
                            ProgressView()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .disabled(isImporting)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                )
                .padding(.horizontal, 16)

                // Danger zone
                VStack(alignment: .leading, spacing: 8) {
                    Text("DANGER ZONE")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .tracking(0.5)
                        .padding(.horizontal, 16)

                    Button(role: .destructive) {
                        showClearConfirmation = true
                    } label: {
                        HStack {
                            Label("Clear All Workout Data", systemImage: "trash")
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppTheme.cardBorder, lineWidth: 1)
                    )
                    .padding(.horizontal, 16)

                    Text("This will permanently delete all your workout history. Your exercise list will be preserved.")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textTertiary)
                        .padding(.horizontal, 16)
                }

                // Log out
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
                    .padding(.vertical, 12)
                }
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                )
                .padding(.horizontal, 16)
            }
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .background(AppTheme.background)
    }

    private func handleFilePicker(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            isImporting = true


            Task {
                let accessed = url.startAccessingSecurityScopedResource()
                defer {
                    if accessed {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                
                do {
                    let importResult = try await container.csvImporter.importCSV(at: url)
                    handleImportResult(importResult)
                } catch {
                    importMessage = "Import failed: \(error.localizedDescription)"
                    showImportAlert = true
                }
                isImporting = false
            }
        case .failure(let error):
            importMessage = "Selection failed: \(error.localizedDescription)"
            showImportAlert = true
        }
    }

    private func handleImportResult(_ result: CSVImporter.ImportResult) {
        if result.skippedBecauseAlreadyImported {
            importMessage = "Already imported previously."
        } else {
            importMessage =
                "Successfully imported:\n\(result.workoutsInserted) Workouts\n\(result.setsInserted) Sets\n\(result.exercisesInsertedOrIgnored) Exercises"
        }
        showImportAlert = true
    }

    private func clearData() {
        do {
            try container.workoutStore.deleteAllWorkouts()
            importMessage = "All workout history cleared."
            showImportAlert = true
        } catch {
            importMessage = "Failed to clear data: \(error.localizedDescription)"
            showImportAlert = true
        }
    }

    private var loggedOutContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Sign-in card
                VStack(spacing: 16) {
                    Image(systemName: "person.circle")
                        .font(.system(size: 44))
                        .foregroundStyle(AppTheme.textTertiary)

                    Text("Sign in to sync your data across devices.")
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)

                    Button {
                        isAuthSheetPresented = true
                    } label: {
                        Text("Log in here")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(20)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                )
                .padding(.horizontal, 16)

                settingsCards
            }
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .background(AppTheme.background)
    }

    private func memberSinceFormatted(_ timestamp: TimeInterval) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: Date(timeIntervalSince1970: timestamp))
    }
}

#Preview {
    let container = AppContainer()
    return NavigationStack {
        ProfileView(container: container, authStore: container.authStore)
    }
}
