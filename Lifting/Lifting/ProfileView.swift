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
                Button {
                    isFileImporterPresented = true
                } label: {
                    HStack {
                        Label("Import Workouts", systemImage: "doc.badge.plus")
                        Spacer()
                        if isImporting {
                            ProgressView()
                        }
                    }
                }
                .disabled(isImporting)
            }

            Section {
                Button(role: .destructive) {
                    showClearConfirmation = true
                } label: {
                    HStack {
                        Label("Clear All Workout Data", systemImage: "trash")
                        Spacer()
                    }
                }
            } header: {
                Text("Danger Zone")
            } footer: {
                Text("This will permanently delete all your workout history. Your exercise list will be preserved.")
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

    private func handleFilePicker(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            isImporting = true
            
            Task {
                // Gain access to the file if it's from outside the app sandbox (e.g. iCloud)
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
            importMessage = "Successfully imported:\n\(result.workoutsInserted) Workouts\n\(result.setsInserted) Sets\n\(result.exercisesInsertedOrIgnored) Exercises"
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
    let container = AppContainer()
    return NavigationStack {
        ProfileView(container: container, authStore: container.authStore)
    }
}
