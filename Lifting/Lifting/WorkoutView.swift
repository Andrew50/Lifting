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

    @State private var editorEntryPoint: WorkoutEditorEntryPoint?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        editorEntryPoint = .startWorkout
                    } label: {
                        Text("Start Workout")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(.borderedProminent)
                }

                Section("Templates") {
                    ForEach(templates) { template in
                        HStack {
                            Text(template.name)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                }

                Section {
                    Button {
                        editorEntryPoint = .createTemplate
                    } label: {
                        Label("Create Template", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Workout")
            .sheet(item: $editorEntryPoint) { entryPoint in
                WorkoutEditorPlaceholderView(entryPoint: entryPoint)
            }
        }
    }
}

struct WorkoutView_Previews: PreviewProvider {
    static var previews: some View {
        WorkoutView()
    }
}

