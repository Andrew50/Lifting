//
//  WorkoutView.swift
//  Lifting
//
//  Created by Andrew Billings on 1/31/26.
//

import SwiftUI

private struct WorkoutSheetItem: Identifiable {
    let workoutId: String
    var id: String { workoutId }
}

struct WorkoutView: View {
    @ObservedObject var templateStore: TemplateStore
    @ObservedObject var workoutStore: WorkoutStore
    @ObservedObject var exerciseStore: ExerciseStore
    @ObservedObject var authStore: AuthStore

    enum Route: Hashable {
        case template(String)
        case workout(String)
    }

    @State private var path: [Route] = []
    @State private var errorMessage: String?
    @State private var activeWorkoutSheetItem: WorkoutSheetItem?

    private var greetingTitle: String {
        if let name = authStore.currentUser?.name {
            let firstName = name.split(separator: " ").first.map(String.init) ?? name
            return "Hi, \(firstName)!"
        }
        return "Hi there!"
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    Button {
                        do {
                            let workoutId = try workoutStore.startOrResumePendingWorkout()
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                activeWorkoutSheetItem = WorkoutSheetItem(workoutId: workoutId)
                            }
                        } catch {
                            errorMessage = "Start Workout failed: \(error)"
                            print(errorMessage ?? "")
                        }
                    } label: {
                        Text("Start Workout")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(BouncyProminentButtonStyle())
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
                        } catch {
                            errorMessage = "Create Template failed: \(error)"
                            print(errorMessage ?? "")
                        }
                    } label: {
                        Label("Create Template", systemImage: "plus")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.white)
            .navigationTitle(greetingTitle)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .template(let templateId):
                    WorkoutEditorView(
                        templateStore: templateStore,
                        workoutStore: workoutStore,
                        exerciseStore: exerciseStore,
                        subject: .template(id: templateId),
                        onFinish: { path.removeAll() },
                        restTimeSeconds: .constant(120)
                    )

                case .workout(let workoutId):
                    WorkoutEditorView(
                        templateStore: templateStore,
                        workoutStore: workoutStore,
                        exerciseStore: exerciseStore,
                        subject: .workout(id: workoutId),
                        onFinish: { path.removeAll() },
                        restTimeSeconds: .constant(120)
                    )
                }
            }
            .alert(
                "Error",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { isPresented in
                        if !isPresented { errorMessage = nil }
                    }
                )
            ) {
                Button("OK", role: .cancel) {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .sheet(item: $activeWorkoutSheetItem) { item in
            ActiveWorkoutSheetView(
                templateStore: templateStore,
                workoutStore: workoutStore,
                exerciseStore: exerciseStore,
                workoutId: item.workoutId,
                onDismiss: {
                    withAnimation(.easeOut(duration: 0.25)) {
                        activeWorkoutSheetItem = nil
                    }
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }
}

private struct BouncyProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.accentColor)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct WorkoutView_Previews: PreviewProvider {
    static var previews: some View {
        let container = AppContainer()
        WorkoutView(
            templateStore: container.templateStore,
            workoutStore: container.workoutStore,
            exerciseStore: container.exerciseStore,
            authStore: container.authStore
        )
    }
}
