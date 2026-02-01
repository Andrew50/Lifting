//
//  WorkoutView.swift
//  Lifting
//
//  Created by Andrew Billings on 1/31/26.
//

import SwiftUI

struct WorkoutView: View {
    @State private var templates: [WorkoutTemplate] = [
        WorkoutTemplate(name: "Push Day"),
        WorkoutTemplate(name: "Pull Day"),
        WorkoutTemplate(name: "Leg Day"),
    ]

    @State private var path: [WorkoutEditorEntryPoint] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    Button {
                        path.append(.startWorkout)
                    } label: {
                        Text("Start Workout")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(.borderedProminent)
                }

                Section("Templates") {
                    ForEach(templates) { template in
                        NavigationLink(value: WorkoutEditorEntryPoint.editTemplate(template)) {
                            Text(template.name)
                        }
                    }
                }

                Section {
                    Button {
                        path.append(.createTemplate)
                    } label: {
                        Label("Create Template", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Workout")
            .navigationDestination(for: WorkoutEditorEntryPoint.self) { entryPoint in
                WorkoutEditorPlaceholderScreen(entryPoint: entryPoint)
            }
        }
    }
}

struct WorkoutView_Previews: PreviewProvider {
    static var previews: some View {
        WorkoutView()
    }
}

