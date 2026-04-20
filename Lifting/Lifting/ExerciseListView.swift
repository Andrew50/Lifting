//
//  ExerciseListView.swift
//  Lifting
//

import SwiftUI

struct ExerciseListView: View {
    @ObservedObject var container: AppContainer
    @State private var selectedExercise: ExerciseRecord?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Exercises")
                .font(.system(size: 32, weight: .heavy))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)

            CommonExerciseSearchView(
                exerciseStore: container.exerciseStore,
                onSelect: { exercise in
                    selectedExercise = exercise
                },
                navigationTitle: "Exercises",
                usesNavigationTitle: false
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
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
