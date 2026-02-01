//
//  WorkoutEditorView.swift
//  Lifting
//
//  Created by Andrew Billings on 1/31/26.
//

import SwiftUI

struct WorkoutEditorView: View {
    enum Subject: Hashable {
        case template(id: String)
        case workout(id: String)
    }

    @ObservedObject var templateStore: TemplateStore
    @ObservedObject var workoutStore: WorkoutStore
    @ObservedObject var exerciseStore: ExerciseStore

    let subject: Subject
    var onFinish: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var isPendingWorkout: Bool = false

    @State private var templateExercises: [TemplateExerciseDetail] = []
    @State private var workoutExercises: [WorkoutExerciseDetail] = []

    @State private var activeWorkoutIdToPush: String?
    @State private var isShowingExercisePicker: Bool = false

    // MARK: - Load

    private func reload() {
        switch subject {
        case .template(let templateId):
            do {
                if let template = try templateStore.fetchTemplate(templateId: templateId) {
                    title = template.name
                } else {
                    title = "Template"
                }
                templateExercises = try templateStore.fetchTemplateExercises(templateId: templateId)
                isPendingWorkout = false
            } catch {
                templateExercises = []
                isPendingWorkout = false
            }

        case .workout(let workoutId):
            do {
                if let workout = try workoutStore.fetchWorkout(workoutId: workoutId) {
                    title = workout.name
                    isPendingWorkout = (workout.status == .pending)
                } else {
                    title = "Workout"
                    isPendingWorkout = false
                }
                workoutExercises = try workoutStore.fetchWorkoutExercises(workoutId: workoutId)
            } catch {
                title = "Workout"
                isPendingWorkout = false
                workoutExercises = []
            }
        }
    }

    // MARK: - Header actions

    private func saveAndClose() {
        switch subject {
        case .template(let templateId):
            do {
                try templateStore.updateTemplateName(templateId: templateId, name: title)
            } catch { }
            onFinish?() ?? dismiss()

        case .workout(let workoutId):
            do {
                try workoutStore.updateWorkoutName(workoutId: workoutId, name: title)
            } catch { }
            onFinish?() ?? dismiss()
        }
    }

    private func deleteAndClose() {
        switch subject {
        case .template(let templateId):
            do {
                try templateStore.deleteTemplate(templateId: templateId)
            } catch { }
            onFinish?() ?? dismiss()

        case .workout(let workoutId):
            do {
                try workoutStore.deleteWorkout(workoutId: workoutId)
            } catch { }
            onFinish?() ?? dismiss()
        }
    }

    private func completeAndClose(workoutId: String) {
        do {
            try workoutStore.completeWorkout(workoutId: workoutId)
        } catch { }
        onFinish?() ?? dismiss()
    }

    private func discardAndClose(workoutId: String) {
        do {
            try workoutStore.discardPendingWorkout(workoutId: workoutId)
        } catch { }
        onFinish?() ?? dismiss()
    }

    // MARK: - Exercise adding

    private func didPickExercise(_ exercise: ExerciseRecord) {
        switch subject {
        case .template(let templateId):
            do {
                try templateStore.addTemplateExercise(templateId: templateId, exerciseId: exercise.id)
            } catch { }
            reload()

        case .workout(let workoutId):
            do {
                try workoutStore.addWorkoutExercise(workoutId: workoutId, exerciseId: exercise.id)
            } catch { }
            reload()
        }
    }

    // MARK: - Body

    var body: some View {
        List {
            Section {
                TextField("Name", text: $title)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
            }

            switch subject {
            case .template(let templateId):
                templateSection(templateId: templateId)
            case .workout(let workoutId):
                workoutSection(workoutId: workoutId)
            }
        }
        .navigationTitle(isPendingWorkout ? "Pending" : "Edit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarItems
        }
        .navigationDestination(isPresented: $isShowingExercisePicker) {
            ExercisePickerView(exerciseStore: exerciseStore, onSelect: didPickExercise)
        }
        .navigationDestination(item: $activeWorkoutIdToPush) { workoutId in
            WorkoutEditorView(
                templateStore: templateStore,
                workoutStore: workoutStore,
                exerciseStore: exerciseStore,
                subject: .workout(id: workoutId),
                onFinish: onFinish
            )
        }
        .onAppear {
            reload()
        }
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        switch subject {
        case .template(let templateId):
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Save") { saveAndClose() }
            }
            ToolbarItemGroup(placement: .bottomBar) {
                Button("Start") {
                    do {
                        let workoutId = try workoutStore.startPendingWorkout(fromTemplate: templateId)
                        activeWorkoutIdToPush = workoutId
                    } catch { }
                }
                Spacer()
                Button("Delete", role: .destructive) { deleteAndClose() }
            }

        case .workout(let workoutId):
            if isPendingWorkout {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("Complete") { completeAndClose(workoutId: workoutId) }
                    Spacer()
                    Button("Discard", role: .destructive) { discardAndClose(workoutId: workoutId) }
                }
            } else {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Save") { saveAndClose() }
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("Delete", role: .destructive) { deleteAndClose() }
                }
            }
        }
    }

    @ViewBuilder
    private func templateSection(templateId: String) -> some View {
        Section("Exercises") {
            if templateExercises.isEmpty {
                Text("No exercises yet.")
                    .foregroundStyle(.secondary)
            }

            ForEach(templateExercises) { item in
                HStack {
                    Text(item.exerciseName)
                    Spacer()
                    Stepper(value: Binding(
                        get: { item.plannedSetsCount },
                        set: { newValue in
                            let clamped = max(0, newValue)
                            do {
                                try templateStore.updatePlannedSets(templateExerciseId: item.id, plannedSetsCount: clamped)
                            } catch { }
                            reload()
                        }
                    ), in: 0...20) {
                        Text("\(item.plannedSetsCount) sets")
                            .foregroundStyle(.secondary)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        do {
                            try templateStore.deleteTemplateExercise(templateExerciseId: item.id)
                        } catch { }
                        reload()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }

            Button {
                isShowingExercisePicker = true
            } label: {
                Label("Add Exercise", systemImage: "plus")
            }
        }
    }

    @ViewBuilder
    private func workoutSection(workoutId: String) -> some View {
        Section("Exercises") {
            if workoutExercises.isEmpty {
                Text("No exercises yet.")
                    .foregroundStyle(.secondary)
            }

            ForEach(workoutExercises) { exercise in
                Section(exercise.exerciseName) {
                    ForEach(exercise.sets) { set in
                        WorkoutSetRow(
                            set: set,
                            onChange: { weight, reps, rir in
                                do {
                                    try workoutStore.updateSet(setId: set.id, weight: weight, reps: reps, rir: rir)
                                } catch { }
                            }
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                do {
                                    try workoutStore.deleteSet(setId: set.id)
                                } catch { }
                                reload()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }

                    Button {
                        do {
                            try workoutStore.addSet(workoutExerciseId: exercise.id)
                        } catch { }
                        reload()
                    } label: {
                        Label("Add Set", systemImage: "plus")
                    }
                }
            }

            Button {
                isShowingExercisePicker = true
            } label: {
                Label("Add Exercise", systemImage: "plus")
            }
        }
    }
}

private struct WorkoutSetRow: View {
    let set: WorkoutSetDetail
    let onChange: (_ weight: Double?, _ reps: Int?, _ rir: Double?) -> Void

    @State private var weightText: String = ""
    @State private var repsText: String = ""
    @State private var rirText: String = ""

    private func parseDouble(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Double(trimmed.replacingOccurrences(of: ",", with: "."))
    }

    private func parseInt(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Int(trimmed)
    }

    var body: some View {
        HStack(spacing: 12) {
            Text("#\(set.sortOrder + 1)")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .leading)

            TextField("Weight", text: $weightText)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)

            TextField("Reps", text: $repsText)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)

            TextField("RIR", text: $rirText)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
        }
        .onAppear {
            weightText = set.weight.map { String($0) } ?? ""
            repsText = set.reps.map { String($0) } ?? ""
            rirText = set.rir.map { String($0) } ?? ""
        }
        .onChange(of: weightText) { _, _ in
            onChange(parseDouble(weightText), parseInt(repsText), parseDouble(rirText))
        }
        .onChange(of: repsText) { _, _ in
            onChange(parseDouble(weightText), parseInt(repsText), parseDouble(rirText))
        }
        .onChange(of: rirText) { _, _ in
            onChange(parseDouble(weightText), parseInt(repsText), parseDouble(rirText))
        }
    }
}

