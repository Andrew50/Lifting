//
//  WorkoutView.swift
//  Lifting
//
//  Created by Andrew Billings on 1/31/26.
//

import SwiftUI

struct WorkoutView: View {
    @ObservedObject var templateStore: TemplateStore
    @ObservedObject var workoutStore: WorkoutStore
    @ObservedObject var exerciseStore: ExerciseStore

    enum Route: Hashable {
        case template(String)
        case workout(String)
    }

    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    Button {
                        do {
                            let workoutId = try workoutStore.startOrResumePendingWorkout()
                            path.append(.workout(workoutId))
                        } catch { }
                    } label: {
                        Text("Start Workout")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(.borderedProminent)
                }

                Section("Templates") {
                    ForEach(templateStore.templates) { template in
                        NavigationLink(value: Route.template(template.id)) {
                            Text(template.name)
                        }
                    }
                }

                Section {
                    Button {
                        do {
                            let templateId = try templateStore.createTemplate(name: "New Template")
                            path.append(.template(templateId))
                        } catch { }
                    } label: {
                        Label("Create Template", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Workout")
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .template(let templateId):
                    WorkoutEditorView(
                        templateStore: templateStore,
                        workoutStore: workoutStore,
                        exerciseStore: exerciseStore,
                        subject: .template(id: templateId),
                        onFinish: { path.removeAll() }
                    )

                case .workout(let workoutId):
                    WorkoutEditorView(
                        templateStore: templateStore,
                        workoutStore: workoutStore,
                        exerciseStore: exerciseStore,
                        subject: .workout(id: workoutId),
                        onFinish: { path.removeAll() }
                    )
                }
            }
        }
    }
}

struct WorkoutView_Previews: PreviewProvider {
    static var previews: some View {
        WorkoutView(
            templateStore: AppContainer().templateStore,
            workoutStore: AppContainer().workoutStore,
            exerciseStore: AppContainer().exerciseStore
        )
    }
}

