//
//  WorkoutEditorPlaceholderView.swift
//  Lifting
//
//  Created by Andrew Billings on 1/31/26.
//

import SwiftUI

enum WorkoutEditorEntryPoint: Identifiable, Hashable {
    case startWorkout
    case createTemplate
    case editTemplate(WorkoutTemplate)
    case editHistoryWorkout(WorkoutHistoryItem)

    var id: String {
        switch self {
        case .startWorkout:
            return "startWorkout"
        case .createTemplate:
            return "createTemplate"
        case .editTemplate(let template):
            return "editTemplate-\(template.id.uuidString)"
        case .editHistoryWorkout(let workout):
            return "editHistoryWorkout-\(workout.id.uuidString)"
        }
    }

    var title: String {
        switch self {
        case .startWorkout:
            return "Start Workout"
        case .createTemplate:
            return "Create Template"
        case .editTemplate(let template):
            return template.name
        case .editHistoryWorkout(let workout):
            return workout.name
        }
    }
}

/// Reusable placeholder content for the workout editor.
/// Present it either in a `NavigationStack` (sheet) or as a pushed destination (navigation).
struct WorkoutEditorPlaceholderScreen: View {
    let entryPoint: WorkoutEditorEntryPoint

    var body: some View {
        VStack(spacing: 12) {
            Text("Workout Editor")
                .font(.title2.weight(.semibold))

            Text("TODO: Implement workout edit modal.")
                .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle(entryPoint.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Sheet wrapper so the placeholder editor can be dismissed.
struct WorkoutEditorPlaceholderSheet: View {
    let entryPoint: WorkoutEditorEntryPoint

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            WorkoutEditorPlaceholderScreen(entryPoint: entryPoint)
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

struct WorkoutEditorPlaceholderScreen_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            WorkoutEditorPlaceholderScreen(entryPoint: .startWorkout)
        }
    }
}

struct WorkoutEditorPlaceholderSheet_Previews: PreviewProvider {
    static var previews: some View {
        WorkoutEditorPlaceholderSheet(entryPoint: .startWorkout)
    }
}

