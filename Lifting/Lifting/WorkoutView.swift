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
    @State private var activeWorkoutSheetDetent: PresentationDetent = .large
    /// When set, the sheet is dismissed and this bar is shown above the tab bar (app bar unchanged).
    @State private var collapsedActiveWorkoutId: String?

    private let activeWorkoutCollapsedHeight: CGFloat = 72

    private var greetingTitle: String {
        if let name = authStore.currentUser?.name {
            let firstName = name.split(separator: " ").first.map(String.init) ?? name
            return "Hi, \(firstName)!"
        }
        return "Hi there!"
    }

    var body: some View {
        VStack(spacing: 0) {
            NavigationStack(path: $path) {
                List {
                Section {
                    Button {
                        do {
                            let workoutId = try workoutStore.startOrResumePendingWorkout()
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                activeWorkoutSheetDetent = .large
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
            .background(Color(UIColor.systemBackground))
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
            .frame(maxHeight: .infinity)

            if let workoutId = collapsedActiveWorkoutId {
                CollapsedWorkoutBarView(
                    workoutId: workoutId,
                    workoutStore: workoutStore,
                    onTap: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            collapsedActiveWorkoutId = nil
                            activeWorkoutSheetDetent = .large
                            activeWorkoutSheetItem = WorkoutSheetItem(workoutId: workoutId)
                        }
                    }
                )
            }
        }
        .sheet(item: $activeWorkoutSheetItem) { item in
            ActiveWorkoutSheetView(
                templateStore: templateStore,
                workoutStore: workoutStore,
                exerciseStore: exerciseStore,
                workoutId: item.workoutId,
                selectedDetent: $activeWorkoutSheetDetent,
                onDismiss: {
                    withAnimation(.easeOut(duration: 0.25)) {
                        activeWorkoutSheetItem = nil
                        collapsedActiveWorkoutId = nil
                    }
                },
                onCollapseToBar: {
                    if let current = activeWorkoutSheetItem {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            collapsedActiveWorkoutId = current.workoutId
                            activeWorkoutSheetItem = nil
                        }
                    }
                }
            )
            .presentationDetents([.height(activeWorkoutCollapsedHeight), .large], selection: $activeWorkoutSheetDetent)
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled(true)
        }
        .onAppear {
            resumePendingWorkoutIfNeeded()
        }
    }

    /// Check for a pending workout in the database; show collapsed bar (no sheet) so app bar stays visible.
    private func resumePendingWorkoutIfNeeded() {
        guard activeWorkoutSheetItem == nil, collapsedActiveWorkoutId == nil else { return }
        if let pendingId = try? workoutStore.fetchPendingWorkoutID() {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                collapsedActiveWorkoutId = pendingId
            }
        }
    }
}

// MARK: - Collapsed workout bar (above tab bar; tap to expand sheet)
private struct CollapsedWorkoutBarView: View {
    let workoutId: String
    @ObservedObject var workoutStore: WorkoutStore
    let onTap: () -> Void

    @State private var workoutName: String = "Workout"
    @State private var workoutStartedAt: TimeInterval?

    private func formatElapsed(_ startedAt: TimeInterval?) -> String {
        guard let start = startedAt else { return "0:00" }
        let total = max(0, Int(Date().timeIntervalSince1970 - start))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(workoutName)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 8)

            TimelineView(.periodic(from: .now, by: 1.0)) { _ in
                Text(formatElapsed(workoutStartedAt))
                    .font(.subheadline.monospacedDigit())
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemBackground))
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onAppear {
            if let workout = try? workoutStore.fetchWorkout(workoutId: workoutId) {
                workoutName = workout.name
                workoutStartedAt = workout.startedAt
            }
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
