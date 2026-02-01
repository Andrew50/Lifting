//
//  ExerciseListView.swift
//  Lifting
//

import SwiftUI

struct ExerciseListView: View {
    @State private var exercises: [String] = []

    var body: some View {
        List(exercises, id: \.self) { name in
            Text(name)
        }
        .listStyle(.plain)
        .navigationTitle("Exercises")
        .onAppear {
            exercises = ExerciseDatabase.shared.getAllExercises()
        }
    }
}

#Preview {
    ExerciseListView()
}
