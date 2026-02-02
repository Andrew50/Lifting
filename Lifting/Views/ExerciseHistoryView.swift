//
//  ExerciseHistoryView.swift
//  Lifting
//

import SwiftUI

struct ExerciseHistoryView: View {
    let exerciseId: String
    let exerciseName: String
    let workoutStore: WorkoutStore

    @State private var entries: [ExerciseHistorySetEntry] = []
    @State private var loadError: Bool = false

    private var groupedByWorkout: [(workoutId: String, name: String, date: Date, sets: [ExerciseHistorySetEntry])] {
        var result: [(String, String, Date, [ExerciseHistorySetEntry])] = []
        var currentWorkoutId: String?
        var currentName: String?
        var currentDate: Date?
        var currentSets: [ExerciseHistorySetEntry] = []

        for entry in entries {
            if entry.workoutId != currentWorkoutId {
                if let id = currentWorkoutId, let name = currentName, let date = currentDate, !currentSets.isEmpty {
                    result.append((id, name, date, currentSets))
                }
                currentWorkoutId = entry.workoutId
                currentName = entry.workoutName
                currentDate = entry.completedAt
                currentSets = [entry]
            } else {
                currentSets.append(entry)
            }
        }
        if let id = currentWorkoutId, let name = currentName, let date = currentDate, !currentSets.isEmpty {
            result.append((id, name, date, currentSets))
        }
        return result
    }

    var body: some View {
        Group {
            if loadError {
                ContentUnavailableView(
                    "Unable to load history",
                    systemImage: "exclamationmark.triangle",
                    description: Text("There was a problem loading exercise history.")
                )
            } else if entries.isEmpty {
                ContentUnavailableView(
                    "No history yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Complete workouts with this exercise to see sets, weights, and dates here.")
                )
            } else {
                List {
                    ForEach(groupedByWorkout, id: \.workoutId) { group in
                        Section {
                            ForEach(group.sets) { set in
                                HistorySetRow(entry: set)
                            }
                        } header: {
                            HStack {
                                Text(group.name)
                                Spacer()
                                Text(formatDate(group.date))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadHistory()
        }
    }

    private func loadHistory() {
        do {
            entries = try workoutStore.fetchExerciseHistory(exerciseId: exerciseId)
            loadError = false
        } catch {
            entries = []
            loadError = true
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

private struct HistorySetRow: View {
    let entry: ExerciseHistorySetEntry

    private var isFailure: Bool {
        guard let rir = entry.rir else { return false }
        return rir == 0
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Set \(entry.sortOrder + 1)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .leading)

            if let w = entry.weight {
                Text(String(format: "%.1f kg", w))
                    .font(.body.monospacedDigit())
            } else {
                Text("—")
                    .foregroundStyle(.tertiary)
            }

            if let r = entry.reps {
                Text("× \(r) reps")
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if entry.isWarmUp == true {
                Text("Warm-up")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.orange.opacity(0.2))
                    .clipShape(Capsule())
            }
            if isFailure {
                Text("Failure")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.red.opacity(0.2))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        ExerciseHistoryView(
            exerciseId: "preview-id",
            exerciseName: "Bench Press",
            workoutStore: try! AppContainer().workoutStore
        )
    }
}
