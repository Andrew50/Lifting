//
//  ExerciseListView.swift
//  Lifting
//

import SwiftUI

struct ExerciseListView: View {
    @ObservedObject var container: AppContainer
    @State private var selectedExercise: ExerciseRecord?

    var body: some View {
        CommonExerciseSearchView(
            exerciseStore: container.exerciseStore,
            onSelect: { exercise in
                selectedExercise = exercise
            },
            navigationTitle: "Exercises"
        )
        .sheet(item: $selectedExercise) { exercise in
            NavigationStack {
                ExerciseHistoryView(
                    exerciseId: exercise.id,
                    exerciseName: exercise.name,
                    workoutStore: container.workoutStore
                )
            }
        }
    }
}

#Preview {
    NavigationStack {
        ExerciseListView(container: AppContainer())
    }
}
