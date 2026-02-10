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
    /// Rest time in seconds between sets (e.g. 120 for "2:00").
    @Binding var restTimeSeconds: Int
    /// Called when a set is marked completed — used to auto-start rest timer.
    var onSetCompleted: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @AppStorage("weightUnit") private var weightUnit: String = "lbs"

    @State private var title: String = ""
    @State private var lastLoadedTitle: String = ""
    @State private var hasLoadedInitialTitle: Bool = false
    @State private var isPendingWorkout: Bool = false

    @State private var templateExercises: [TemplateExerciseDetail] = []
    @State private var workoutExercises: [WorkoutExerciseDetail] = []

    @State private var workoutStartedAt: TimeInterval?
    @State private var workoutCompletedAt: TimeInterval?

    @State private var activeWorkoutIdToPush: String?
    @State private var isShowingExercisePicker: Bool = false
    @State private var restTimeEditText: String = ""
    @State private var isEditingRestTime: Bool = false
    @State private var workoutNotes: String = ""
    @State private var isShowingNoteEditor: Bool = false
    @State private var showRestTimePicker: Bool = false
    @State private var showCancelConfirmation: Bool = false
    @State private var replacingExerciseId: String?
    @State private var isShowingReplacePicker: Bool = false
    /// For sheet workout: previous set (weight, reps) per exercise, from most recent completed workout.
    @State private var previousPerformanceByExerciseId: [String: [(weight: Double?, reps: Int?)]] =
        [:]

    struct ExerciseHistorySelection: Identifiable {
        let id: String
        let name: String
    }
    @State private var selectedExerciseForHistory: ExerciseHistorySelection?

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
                    workoutStartedAt = workout.startedAt
                    workoutCompletedAt = workout.completedAt
                    workoutNotes = workout.notes ?? ""
                } else {
                    if shouldRefreshTitle {
                        title = "Workout"
                    }
                    lastLoadedTitle = "Workout"
                    isPendingWorkout = false
                    workoutStartedAt = nil
                    workoutCompletedAt = nil
                    workoutNotes = ""
                }
                workoutExercises = try workoutStore.fetchWorkoutExercises(workoutId: workoutId)
                loadPreviousPerformanceForWorkoutExercises()
            } catch {
                if shouldRefreshTitle {
                    title = "Workout"
                }
                lastLoadedTitle = "Workout"
                isPendingWorkout = false
                workoutExercises = []
                workoutStartedAt = nil
                workoutCompletedAt = nil
                previousPerformanceByExerciseId = [:]
            }
        }
    }

    /// Populates previousPerformanceByExerciseId from exercise history (most recent workout per exercise).
    private func loadPreviousPerformanceForWorkoutExercises() {
        let exerciseIds = workoutExercises.map { $0.exerciseId }
        do {
            previousPerformanceByExerciseId = try workoutStore.fetchLatestSetsForExercises(
                exerciseIds: exerciseIds)
        } catch {
            previousPerformanceByExerciseId = [:]
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

    private var workoutDateFormatted: String? {
        guard let startedAt = workoutStartedAt else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: Date(timeIntervalSince1970: startedAt))
    }

    private var workoutDurationSeconds: Int? {
        guard let started = workoutStartedAt else { return nil }
        let end = workoutCompletedAt ?? Date().timeIntervalSince1970
        return max(0, Int(end - started))
    }

    private var workoutDurationFormatted: String? {
        guard let total = workoutDurationSeconds else { return nil }
        let min = total / 60
        let sec = total % 60
        if min == 0 {
            return "\(sec)s"
        }
        return String(format: "%d:%02d", min, sec)
    }

    private var restTimeFormatted: String {
        let min = restTimeSeconds / 60
        let sec = restTimeSeconds % 60
        return String(format: "%d:%02d", min, sec)
    }

    /// Parse a "M:SS" string into total seconds, returns nil if invalid.
    private func parseRestTime(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.split(separator: ":")
        if parts.count == 2, let min = Int(parts[0]), let sec = Int(parts[1]), sec >= 0, sec < 60 {
            return min * 60 + sec
        }
        if parts.count == 1, let totalSec = Int(parts[0]) {
            return totalSec
        }
        return nil
    }

    private func commitRestTimeEdit() {
        if let seconds = parseRestTime(restTimeEditText), seconds > 0 {
            restTimeSeconds = seconds
        }
        restTimeEditText = restTimeFormatted
        isEditingRestTime = false
    }

    /// Formats previous set for display: "50 × 10", "50 lbs", "10 reps", or "—".
    private func formatPreviousSet(_ previous: (weight: Double?, reps: Int?)?) -> String {
        guard let prev = previous else { return "—" }
        let hasWeight = prev.weight != nil && prev.weight! > 0
        let hasReps = prev.reps != nil && prev.reps! > 0
        if hasWeight && hasReps {
            let w = prev.weight!
            let r = prev.reps!
            return w == Double(Int(w)) ? "\(Int(w)) × \(r)" : "\(w) × \(r)"
        }
        if hasWeight {
            return prev.weight! == Double(Int(prev.weight!))
                ? "\(Int(prev.weight!)) lbs" : "\(prev.weight!) lbs"
        }
        if hasReps { return "\(prev.reps!) reps" }
        return "—"
    }

    private var listContent: some View {
        List {
            Section {
                TextField("Name", text: $title)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()

                if case .workout = subject, let dateStr = workoutDateFormatted {
                    Text(dateStr)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if case .workout = subject, workoutDurationFormatted != nil {
                    if isPendingWorkout {
                        TimelineView(.periodic(from: .now, by: 1.0)) { _ in
                            Text(workoutDurationFormatted ?? "0:00")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text(workoutDurationFormatted ?? "0:00")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            switch subject {
            case .template(let templateId):
                templateSection(templateId: templateId)
            case .workout(let workoutId):
                workoutSection(workoutId: workoutId)
            }
        }
    }

    @ViewBuilder
    private func sheetWorkoutContent(workoutId: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                // Workout overview: title + menu, date & duration inline
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .center) {
                        TextField("", text: $title)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                        Spacer()
                        Menu {
                            Button {
                                isShowingNoteEditor = true
                            } label: {
                                Label("Note", systemImage: "note.text")
                            }
                            Button {
                                showRestTimePicker = true
                            } label: {
                                Label("Update Rest Timer", systemImage: "clock.arrow.circlepath")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.caption)
                                .foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(Color(red: 0.4, green: 0.6, blue: 1.0))
                                .clipShape(Circle())
                        }
                    }

                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            if let dateStr = workoutDateFormatted {
                                Text(dateStr)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            if isPendingWorkout {
                                TimelineView(.periodic(from: .now, by: 1.0)) { _ in
                                    Text(workoutDurationFormatted ?? "0:00")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                Text(workoutDurationFormatted ?? "0:00")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)

                // Workout notes (shown if not empty)
                if !workoutNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "note.text")
                            .font(.caption2)
                            .foregroundStyle(Color(red: 0.4, green: 0.6, blue: 1.0))
                            .padding(.top, 1)
                        Text(workoutNotes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(.horizontal, 16)
                    .onTapGesture {
                        isShowingNoteEditor = true
                    }
                }

                // Exercises with table layout
                ForEach(workoutExercises) { exercise in
                    sheetExerciseBlock(exercise: exercise, workoutId: workoutId)
                }

                // Add Exercises button (compact)
                Button {
                    isShowingExercisePicker = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.caption2)
                        Text("Add Exercises")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(Color.accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.horizontal, 16)
                .padding(.top, 4)

                if isPendingWorkout {
                    Button {
                        showCancelConfirmation = true
                    } label: {
                        Text("Cancel Workout")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .padding(.horizontal, 16)
                    .alert(
                        "Cancel Workout?",
                        isPresented: $showCancelConfirmation
                    ) {
                        Button("Cancel Workout", role: .destructive) {
                            if case .workout(let workoutId) = subject {
                                discardAndClose(workoutId: workoutId)
                            }
                        }
                        Button("Keep Working", role: .cancel) {}
                    } message: {
                        Text(
                            "Are you sure you want to cancel this workout? All progress will be lost."
                        )
                    }
                } else {
                    Button {
                        saveAndClose()
                    } label: {
                        Text("Save Changes")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.green)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .padding(.horizontal, 16)

                    Button {
                        deleteAndClose()
                    } label: {
                        Text("Delete Workout")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .padding(.horizontal, 16)
                }

                Spacer().frame(height: 16)
            }
            .onTapGesture {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func sheetExerciseBlock(exercise: WorkoutExerciseDetail, workoutId: String) -> some View
    {
        VStack(alignment: .leading, spacing: 2) {
            // Exercise name (blue) + icons
            HStack(spacing: 6) {
                Button {
                    selectedExerciseForHistory = ExerciseHistorySelection(
                        id: exercise.exerciseId, name: exercise.exerciseName)
                } label: {
                    Text(exercise.exerciseName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color(red: 0.2, green: 0.4, blue: 1.0))
                }
                .buttonStyle(.plain)

                Spacer()
                Menu {
                    Button {
                        isShowingNoteEditor = true
                    } label: {
                        Label("Note", systemImage: "note.text")
                    }
                    Button {
                        showRestTimePicker = true
                    } label: {
                        Label("Update Rest Timer", systemImage: "clock.arrow.circlepath")
                    }
                    Divider()
                    Button {
                        replacingExerciseId = exercise.id
                        isShowingReplacePicker = true
                    } label: {
                        Label("Replace Exercise", systemImage: "arrow.triangle.2.circlepath")
                    }
                    Button(role: .destructive) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            do {
                                try workoutStore.deleteWorkoutExercise(
                                    workoutExerciseId: exercise.id)
                            } catch {}
                            reloadPreservingTitleEdits()
                        }
                    } label: {
                        Label("Delete Exercise", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 2)

            // Table header
            HStack(spacing: 2) {
                Text("Set")
                    .frame(width: 24, alignment: .leading)
                Text("Previous")
                    .frame(maxWidth: .infinity)
                Text(weightUnit)
                    .frame(width: 48, alignment: .center)
                Text("Reps")
                    .frame(width: 40, alignment: .center)
                Image(systemName: "checkmark")
                    .frame(width: 28, alignment: .trailing)
            }
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 16)

            // Set rows with rest bars between
            let previousSets = previousPerformanceByExerciseId[exercise.exerciseId] ?? []
            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                if index > 0 {
                    // Rest timer bar between sets — editable inline
                    ZStack {
                        Rectangle()
                            .fill(Color(red: 0.2, green: 0.4, blue: 1.0).opacity(0.15))
                            .frame(height: 0.5)

                        TextField(
                            "0:00", text: $restTimeEditText,
                            onCommit: {
                                commitRestTimeEdit()
                            }
                        )
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color(red: 0.2, green: 0.4, blue: 1.0))
                        .multilineTextAlignment(.center)
                        .keyboardType(.numbersAndPunctuation)
                        .frame(width: 36)
                        .padding(.horizontal, 2)
                        .background(Color(UIColor.systemBackground))
                        .onTapGesture {
                            isEditingRestTime = true
                            restTimeEditText = restTimeFormatted
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 14)
                }

                let previousSet = index < previousSets.count ? previousSets[index] : nil
                SheetSetRow(
                    set: set,
                    previousText: formatPreviousSet(previousSet),
                    isCompleted: set.isCompleted == true,
                    onToggleComplete: {
                        let newValue = !(set.isCompleted == true)
                        do {
                            try workoutStore.toggleSetCompleted(setId: set.id, completed: newValue)
                        } catch {}
                        reloadPreservingTitleEdits()
                        if newValue {
                            onSetCompleted?()
                        }
                    },
                    onChange: { weight, reps, _, _ in
                        do {
                            try workoutStore.updateSet(
                                setId: set.id,
                                weight: weight,
                                reps: reps,
                                rir: set.rir,
                                isWarmUp: set.isWarmUp
                            )
                        } catch {}
                        reloadPreservingTitleEdits()
                    },
                    onSetTypeChanged: { newType in
                        do {
                            switch newType {
                            case .normal:
                                try workoutStore.updateSet(
                                    setId: set.id, weight: set.weight, reps: set.reps,
                                    rir: nil, isWarmUp: false)
                            case .warmUp:
                                try workoutStore.updateSet(
                                    setId: set.id, weight: set.weight, reps: set.reps,
                                    rir: set.rir, isWarmUp: true)
                            case .failure:
                                try workoutStore.updateSet(
                                    setId: set.id, weight: set.weight, reps: set.reps,
                                    rir: 0, isWarmUp: false)
                            }
                        } catch {}
                        reloadPreservingTitleEdits()
                    },
                    onDelete: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            do {
                                try workoutStore.deleteSet(setId: set.id)
                            } catch {}
                            reloadPreservingTitleEdits()
                        }
                    }
                )
            }

            // Add Set
            Button {
                do {
                    try workoutStore.addSet(workoutExerciseId: exercise.id)
                } catch {}
                reloadPreservingTitleEdits()
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "plus")
                        .font(.system(size: 9))
                    Text("Add Set (\(restTimeFormatted))")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(Color(.systemGray))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 16)
            .padding(.top, 1)
        }
    }

    var body: some View {
        Group {
            switch subject {
            case .workout(let workoutId):
                sheetWorkoutContent(workoutId: workoutId)
            case .template:
                listContent
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(UIColor.systemBackground))
        .navigationTitle(
            {
                switch subject {
                case .workout: return ""
                case .template: return "Edit"
                }
            }()
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if case .template = subject {
                toolbarItems
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if case .template = subject {
                bottomActionBar
            }
        }
        .sheet(isPresented: $isShowingExercisePicker) {
            NavigationStack {
                ExercisePickerView(exerciseStore: exerciseStore, onSelect: didPickExercise)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                isShowingExercisePicker = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $isShowingNoteEditor) {
            WorkoutNoteEditorSheet(
                notes: $workoutNotes,
                onSave: {
                    if case .workout(let workoutId) = subject {
                        try? workoutStore.updateWorkoutNotes(
                            workoutId: workoutId,
                            notes: workoutNotes.trimmingCharacters(in: .whitespacesAndNewlines)
                                .isEmpty
                                ? nil : workoutNotes
                        )
                    }
                    isShowingNoteEditor = false
                },
                onCancel: {
                    isShowingNoteEditor = false
                }
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showRestTimePicker) {
            RestTimePickerSheet(
                restTimeSeconds: $restTimeSeconds,
                onDone: {
                    restTimeEditText = restTimeFormatted
                    showRestTimePicker = false
                }
            )
            .presentationDetents([.height(260)])
        }
        .sheet(isPresented: $isShowingReplacePicker) {
            NavigationStack {
                ExercisePickerView(exerciseStore: exerciseStore) { newExercise in
                    if let replaceId = replacingExerciseId {
                        do {
                            try workoutStore.replaceWorkoutExercise(
                                workoutExerciseId: replaceId,
                                newExerciseId: newExercise.id
                            )
                        } catch {}
                        reloadPreservingTitleEdits()
                    }
                    replacingExerciseId = nil
                    isShowingReplacePicker = false
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            replacingExerciseId = nil
                            isShowingReplacePicker = false
                        }
                    }
                }
                .navigationTitle("Replace Exercise")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .navigationDestination(item: $activeWorkoutIdToPush) { workoutId in
            WorkoutEditorView(
                templateStore: templateStore,
                workoutStore: workoutStore,
                exerciseStore: exerciseStore,
                subject: .workout(id: workoutId),
                onFinish: onFinish,
                restTimeSeconds: $restTimeSeconds
            )
        }
        .onAppear {
            reload(shouldRefreshTitle: true)
            hasLoadedInitialTitle = true
            restTimeEditText = restTimeFormatted
        }
        .onChange(of: restTimeSeconds) { oldValue, newValue in
            if !isEditingRestTime {
                restTimeEditText = restTimeFormatted
            }
        }
        .sheet(item: $selectedExerciseForHistory) { selection in
            NavigationStack {
                ExerciseHistoryView(
                    exerciseId: selection.id,
                    exerciseName: selection.name,
                    workoutStore: workoutStore
                )
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button("Save") { saveAndClose() }
        }
    }

    @ViewBuilder
    private var bottomActionBar: some View {
        if case .template(let templateId) = subject {
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
                        Button {
                            selectedExerciseForHistory = ExerciseHistorySelection(
                                id: exercise.exerciseId, name: exercise.exerciseName)
                        } label: {
                            Text(exercise.exerciseName)
                                .font(.headline)
                        }
                        .buttonStyle(.plain)

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

/// Represents the type of a set: normal, warm-up, or failure.
private enum SetType: CaseIterable {
    case normal, warmUp, failure

    var next: SetType {
        switch self {
        case .normal: return .warmUp
        case .warmUp: return .failure
        case .failure: return .normal
        }
    }
}

private struct SheetSetRow: View {
    let set: WorkoutSetDetail
    /// Previous performance for this set (e.g. "50 × 10" or "—").
    let previousText: String
    let isCompleted: Bool
    let onToggleComplete: () -> Void
    let onChange: (Double?, Int?, Double?, Bool?) -> Void
    /// Called when the set type (warm-up / failure) changes.
    let onSetTypeChanged: (SetType) -> Void
    /// Called when the user swipes to delete this set.
    let onDelete: () -> Void

    private enum Field: Hashable {
        case weight, reps
    }

    @State private var weightText: String = ""
    @State private var repsText: String = ""
    @State private var swipeOffset: CGFloat = 0
    @State private var showDeleteConfirm: Bool = false
    @State private var setType: SetType = .normal
    @FocusState private var focusedField: Field?

    private func parseDouble(_ text: String) -> Double? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        return Double(t.replacingOccurrences(of: ",", with: "."))
    }

    private func parseInt(_ text: String) -> Int? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        return Int(t)
    }

    private func commit() {
        onChange(parseDouble(weightText), parseInt(repsText), nil, nil)
    }

    /// The label shown in the set number column.
    private var setLabel: String {
        switch setType {
        case .normal: return "\(set.sortOrder + 1)"
        case .warmUp: return "W"
        case .failure: return "F"
        }
    }

    /// Color for the set label.
    private var setLabelColor: Color {
        switch setType {
        case .normal: return .primary
        case .warmUp: return Color(red: 0.2, green: 0.72, blue: 0.4)
        case .failure: return Color(red: 0.9, green: 0.25, blue: 0.25)
        }
    }

    /// Background color for the set label badge.
    private var setLabelBackground: Color {
        switch setType {
        case .normal: return .clear
        case .warmUp: return Color(red: 0.2, green: 0.72, blue: 0.4).opacity(0.15)
        case .failure: return Color(red: 0.9, green: 0.25, blue: 0.25).opacity(0.15)
        }
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete background revealed on swipe
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    onDelete()
                }
            } label: {
                Rectangle()
                    .fill(Color(red: 0.9, green: 0.25, blue: 0.25))
                    .overlay(
                        HStack {
                            Spacer()
                            Image(systemName: "trash.fill")
                                .font(.body)
                                .foregroundStyle(.white)
                                .frame(width: 70)
                        }
                    )
            }
            .buttonStyle(.plain)

            // Main row content
            HStack(spacing: 2) {
                // Tappable set type badge
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        setType = setType.next
                    }
                    onSetTypeChanged(setType)
                } label: {
                    Text(setLabel)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(setLabelColor)
                        .frame(width: 20, height: 20)
                        .background(setLabelBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
                .buttonStyle(.plain)
                .frame(width: 24, alignment: .leading)

                Text(previousText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)

                TextField("", text: $weightText)
                    .focused($focusedField, equals: .weight)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 12))
                    .frame(width: 48)
                    .padding(.vertical, 3)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(focusedField == .weight ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
                    .onSubmit { focusedField = nil }

                Spacer().frame(width: 8)

                TextField("", text: $repsText)
                    .focused($focusedField, equals: .reps)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 12))
                    .frame(width: 40)
                    .padding(.vertical, 3)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(focusedField == .reps ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
                    .onSubmit { focusedField = nil }

                Button {
                    focusedField = nil
                    onToggleComplete()
                } label: {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.body)
                        .foregroundStyle(
                            isCompleted ? Color.green : .secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 28, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 0)
            .background(Color(UIColor.systemBackground))
            .offset(x: swipeOffset)
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { value in
                        if value.translation.width < 0 {
                            swipeOffset = max(value.translation.width, -80)
                        } else if swipeOffset < 0 {
                            swipeOffset = min(0, swipeOffset + value.translation.width)
                        }
                    }
                    .onEnded { value in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            if swipeOffset < -50 {
                                swipeOffset = -70
                            } else {
                                swipeOffset = 0
                            }
                        }
                    }
            )
        }
        .clipped()
        .onAppear {
            weightText =
                set.weight.map { $0 == Double(Int($0)) ? String(Int($0)) : String($0) } ?? ""
            repsText = set.reps.map { String($0) } ?? ""
            // Restore set type from model
            if set.isWarmUp == true {
                setType = .warmUp
            } else if set.rir == 0 {
                setType = .failure
            } else {
                setType = .normal
            }
        }
        .onChange(of: weightText) { _, _ in commit() }
        .onChange(of: repsText) { _, _ in commit() }
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

// MARK: - Note Editor Sheet

private struct WorkoutNoteEditorSheet: View {
    @Binding var notes: String
    let onSave: () -> Void
    let onCancel: () -> Void

    @State private var draft: String = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Workout Note")
                    .font(.headline)
                    .padding(.horizontal, 20)

                TextEditor(text: $draft)
                    .font(.body)
                    .padding(12)
                    .scrollContentBackground(.hidden)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 20)
                    .frame(minHeight: 120)

                Spacer()
            }
            .padding(.top, 20)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        notes = draft
                        onSave()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            draft = notes
        }
    }
}

// MARK: - Rest Time Picker Sheet

private struct RestTimePickerSheet: View {
    @Binding var restTimeSeconds: Int
    let onDone: () -> Void

    private let options = [30, 45, 60, 90, 120, 150, 180, 240, 300]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Rest Time Between Sets")
                    .font(.headline)
                    .padding(.horizontal, 20)

                LazyVGrid(
                    columns: [
                        GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()),
                    ], spacing: 12
                ) {
                    ForEach(options, id: \.self) { seconds in
                        let isSelected = restTimeSeconds == seconds
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                restTimeSeconds = seconds
                            }
                        } label: {
                            Text(
                                seconds < 60
                                    ? "\(seconds)s"
                                    : "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
                            )
                            .font(.body)
                            .fontWeight(isSelected ? .bold : .regular)
                            .foregroundStyle(isSelected ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                isSelected
                                    ? Color(red: 0.2, green: 0.4, blue: 1.0)
                                    : Color(.systemGray6)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
            .padding(.top, 20)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onDone() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
