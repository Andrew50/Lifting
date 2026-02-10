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

    private var groupedByWorkout: [(workoutId: String, name: String, startedAt: Date, sets: [ExerciseHistorySetEntry])] {
        var result: [(String, String, Date, [ExerciseHistorySetEntry])] = []
        var currentWorkoutId: String?
        var currentName: String?
        var currentStartedAt: Date?
        var currentSets: [ExerciseHistorySetEntry] = []

        for entry in entries {
            if entry.workoutId != currentWorkoutId {
                if let id = currentWorkoutId, let name = currentName, let startedAt = currentStartedAt, !currentSets.isEmpty {
                    result.append((id, name, startedAt, currentSets))
                }
                currentWorkoutId = entry.workoutId
                currentName = entry.workoutName
                currentStartedAt = entry.startedAt
                currentSets = [entry]
            } else {
                currentSets.append(entry)
            }
        }
        if let id = currentWorkoutId, let name = currentName, let startedAt = currentStartedAt, !currentSets.isEmpty {
            result.append((id, name, startedAt, currentSets))
        }
        return result
    }

    @Environment(\.dismiss) private var dismiss

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
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(groupedByWorkout, id: \.workoutId) { group in
                            HistoryBubble {
                                HistoryBubbleHeader(
                                    title: group.name,
                                    subtitle: "Started \(formatDate(group.startedAt))"
                                )

                                HistoryDivider()

                                VStack(spacing: 0) {
                                    ForEach(group.sets) { set in
                                        HistorySetRow(
                                            setNumber: set.sortOrder + 1,
                                            weight: set.weight,
                                            reps: set.reps,
                                            rir: set.rir,
                                            isWarmUp: set.isWarmUp,
                                            restTimerSeconds: set.restTimerSeconds,
                                            displayWeightUnit: DisplayPreferences.displayWeightUnit(for: exerciseId),
                                            displayIntensityDisplay: DisplayPreferences.displayIntensityDisplay(for: exerciseId)
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
            }
        }
        .onAppear {
            loadHistory()
        }
    }

    private func loadHistory() {
        if let results = try? workoutStore.fetchExerciseHistory(exerciseId: exerciseId) {
            entries = results
            loadError = false
        } else {
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

#Preview {
    NavigationStack {
        ExerciseHistoryView(
            exerciseId: "preview-id",
            exerciseName: "Bench Press",
            workoutStore: AppContainer().workoutStore
        )
    }
}
