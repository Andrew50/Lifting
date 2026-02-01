//
//  WorkoutEditorPlaceholderView.swift
//  Lifting
//
//  Created by Andrew Billings on 1/31/26.
//

import SwiftUI

enum WorkoutEditorEntryPoint: String, Identifiable {
    case startWorkout
    case createTemplate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .startWorkout:
            return "Start Workout"
        case .createTemplate:
            return "Create Template"
        }
    }
}

struct WorkoutEditorPlaceholderView: View {
    let entryPoint: WorkoutEditorEntryPoint

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("Workout Editor")
                    .font(.title2.weight(.semibold))

                Text("TODO: Implement workout edit modal.")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle(entryPoint.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct WorkoutEditorPlaceholderView_Previews: PreviewProvider {
    static var previews: some View {
        WorkoutEditorPlaceholderView(entryPoint: .startWorkout)
    }
}

