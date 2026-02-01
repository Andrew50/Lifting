//
//  ExercisePickerView.swift
//  Lifting
//
//  Created by Andrew Billings on 1/31/26.
//

import SwiftUI

struct ExercisePickerView: View {
    @ObservedObject var exerciseStore: ExerciseStore
    let onSelect: (ExerciseRecord) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""

    private var filteredExercises: [ExerciseRecord] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return exerciseStore.exercises }
        return exerciseStore.exercises.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        List(filteredExercises) { exercise in
            Button {
                onSelect(exercise)
                dismiss()
            } label: {
                Text(exercise.name)
            }
        }
        .navigationTitle("Add Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText)
        .task {
            if exerciseStore.exercises.isEmpty {
                await exerciseStore.loadAll()
            }
        }
    }
}

