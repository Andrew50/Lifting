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
    @State private var lastLoadedTitle: String = ""
    @State private var hasLoadedInitialTitle: Bool = false
    @State private var isPendingWorkout: Bool = false

    @State private var templateExercises: [TemplateExerciseDetail] = []
    @State private var workoutExercises: [WorkoutExerciseDetail] = []

    @State private var activeWorkoutIdToPush: String?
    @State private var isShowingExercisePicker: Bool = false

    // MARK: - Load

    private func reload(shouldRefreshTitle: Bool) {
        switch subject {
        case .template(let templateId):
            do {
                if let template = try templateStore.fetchTemplate(templateId: templateId) {
                    if shouldRefreshTitle {
                        title = template.name
                    }
                    lastLoadedTitle = template.name
                } else {
                    if shouldRefreshTitle {
                        title = "Template"
                    }
                    lastLoadedTitle = "Template"
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
                    if shouldRefreshTitle {
                        title = workout.name
                    }
                    lastLoadedTitle = workout.name
                    isPendingWorkout = (workout.status == .pending)
                } else {
                    if shouldRefreshTitle {
                        title = "Workout"
                    }
                    lastLoadedTitle = "Workout"
                    isPendingWorkout = false
                }
                workoutExercises = try workoutStore.fetchWorkoutExercises(workoutId: workoutId)
            } catch {
                if shouldRefreshTitle {
                    title = "Workout"
                }
                lastLoadedTitle = "Workout"
                isPendingWorkout = false
                workoutExercises = []
            }
        }
    }

    private func reloadPreservingTitleEdits() {
        // Only overwrite the draft title if the user hasn't changed it.
        let userHasEditedTitle = hasLoadedInitialTitle && (title != lastLoadedTitle)
        reload(shouldRefreshTitle: !userHasEditedTitle)
        hasLoadedInitialTitle = true
    }

    // MARK: - Header actions

    private func saveAndClose() {
        switch subject {
        case .template(let templateId):
            do {
                try templateStore.updateTemplateName(templateId: templateId, name: title)
            } catch {}
            onFinish?() ?? dismiss()

        case .workout(let workoutId):
            do {
                try workoutStore.updateWorkoutName(workoutId: workoutId, name: title)
            } catch {}
            onFinish?() ?? dismiss()
        }
    }

    private func deleteAndClose() {
        switch subject {
        case .template(let templateId):
            do {
                try templateStore.deleteTemplate(templateId: templateId)
            } catch {}
            onFinish?() ?? dismiss()

        case .workout(let workoutId):
            do {
                try workoutStore.deleteWorkout(workoutId: workoutId)
            } catch {}
            onFinish?() ?? dismiss()
        }
    }

    private func completeAndClose(workoutId: String) {
        do {
            try workoutStore.completeWorkout(workoutId: workoutId)
        } catch {}
        onFinish?() ?? dismiss()
    }

    private func discardAndClose(workoutId: String) {
        do {
            try workoutStore.discardPendingWorkout(workoutId: workoutId)
        } catch {}
        onFinish?() ?? dismiss()
    }

    // MARK: - Exercise adding

    private func didPickExercise(_ exercise: ExerciseRecord) {
        switch subject {
        case .template(let templateId):
            do {
                try templateStore.addTemplateExercise(
                    templateId: templateId, exerciseId: exercise.id)
            } catch {}
            reloadPreservingTitleEdits()

        case .workout(let workoutId):
            do {
                try workoutStore.addWorkoutExercise(workoutId: workoutId, exerciseId: exercise.id)
            } catch {}
            reloadPreservingTitleEdits()
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomActionBar
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
            reload(shouldRefreshTitle: true)
            hasLoadedInitialTitle = true
        }
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        switch subject {
        case .template:
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Save") { saveAndClose() }
            }

        case .workout:
            if !isPendingWorkout {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Save") { saveAndClose() }
                }
            }
        }
    }

    @ViewBuilder
    private var bottomActionBar: some View {
        switch subject {
        case .template(let templateId):
            actionBar {
                Button("Start") {
                    do {
                        let workoutId = try workoutStore.startPendingWorkout(
                            fromTemplate: templateId)
                        activeWorkoutIdToPush = workoutId
                    } catch {}
                }
                .buttonStyle(.borderedProminent)

                Spacer()

                Button("Delete", role: .destructive) { deleteAndClose() }
                    .buttonStyle(.bordered)
            }

        case .workout(let workoutId):
            if isPendingWorkout {
                actionBar {
                    Button("Complete") { completeAndClose(workoutId: workoutId) }
                        .buttonStyle(.borderedProminent)

                    Spacer()

                    Button("Discard", role: .destructive) { discardAndClose(workoutId: workoutId) }
                        .buttonStyle(.bordered)
                }
            } else {
                actionBar {
                    Spacer()
                    Button("Delete", role: .destructive) { deleteAndClose() }
                        .buttonStyle(.bordered)
                }
            }
        }
    }

    private func actionBar(@ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                content()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
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
                    Stepper(
                        value: Binding(
                            get: { item.plannedSetsCount },
                            set: { newValue in
                                let clamped = max(0, newValue)
                                do {
                                    try templateStore.updatePlannedSets(
                                        templateExerciseId: item.id, plannedSetsCount: clamped)
                                } catch {}
                                reloadPreservingTitleEdits()
                            }
                        ), in: 0...20
                    ) {
                        Text("\(item.plannedSetsCount) sets")
                            .foregroundStyle(.secondary)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        do {
                            try templateStore.deleteTemplateExercise(templateExerciseId: item.id)
                        } catch {}
                        reloadPreservingTitleEdits()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }

        Section {
            Button {
                isShowingExercisePicker = true
            } label: {
                Label("Add Exercise", systemImage: "plus")
            }
        }
    }

    @ViewBuilder
    private func workoutSection(workoutId: String) -> some View {
        if workoutExercises.isEmpty {
            Section("Exercises") {
                Text("No exercises yet.")
                    .foregroundStyle(.secondary)
            }
        } else {
            ForEach(workoutExercises) { exercise in
                Section {
                    HStack {
                        Text(exercise.exerciseName)
                            .font(.headline)
                        Spacer()
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            do {
                                try workoutStore.deleteWorkoutExercise(
                                    workoutExerciseId: exercise.id)
                            } catch {}
                            reloadPreservingTitleEdits()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }

                    ForEach(exercise.sets) { set in
                        WorkoutSetRow(
                            set: set,
                            onChange: { weight, reps, rir, isWarmUp in
                                do {
                                    try workoutStore.updateSet(
                                        setId: set.id, weight: weight, reps: reps, rir: rir,
                                        isWarmUp: isWarmUp)
                                } catch {}
                            }
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                do {
                                    try workoutStore.deleteSet(setId: set.id)
                                } catch {}
                                reloadPreservingTitleEdits()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }

                    Button {
                        do {
                            try workoutStore.addSet(workoutExerciseId: exercise.id)
                        } catch {}
                        reloadPreservingTitleEdits()
                    } label: {
                        Label("Add Set", systemImage: "plus")
                    }
                }
            }
        }

        Section {
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
    let onChange: (_ weight: Double?, _ reps: Int?, _ rir: Double?, _ isWarmUp: Bool?) -> Void

    @State private var weightText: String = ""
    @State private var repsText: String = ""
    @State private var rirText: String = ""
    @State private var isWarmUp: Bool = false

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

    private func commit() {
        onChange(parseDouble(weightText), parseInt(repsText), parseDouble(rirText), isWarmUp)
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

            Toggle("Warm-up", isOn: $isWarmUp)
                .labelsHidden()
                .toggleStyle(.button)
        }
        .onAppear {
            weightText = set.weight.map { String($0) } ?? ""
            repsText = set.reps.map { String($0) } ?? ""
            rirText = set.rir.map { String($0) } ?? ""
            isWarmUp = set.isWarmUp ?? false
        }
        .onChange(of: weightText) { _, _ in commit() }
        .onChange(of: repsText) { _, _ in commit() }
        .onChange(of: rirText) { _, _ in commit() }
        .onChange(of: isWarmUp) { _, _ in commit() }
    }
}
