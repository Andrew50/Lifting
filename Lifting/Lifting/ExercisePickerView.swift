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

    var body: some View {
        CommonExerciseSearchView(
            exerciseStore: exerciseStore,
            onSelect: { exercise in
                onSelect(exercise)
                dismiss()
            },
            navigationTitle: "Add Exercise"
        )
        .navigationBarTitleDisplayMode(.inline)
    }
}
