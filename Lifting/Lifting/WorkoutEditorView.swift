//
//  WorkoutEditorView.swift
//  Lifting
//
//  Created by Andrew Billings on 1/31/26.
//

import SwiftUI
import UIKit

// MARK: - Hosts row content and adds UISwipeGestureRecognizer (does not block ScrollView vertical scrolling)
private struct SetRowWithSwipe<Content: View>: UIViewRepresentable {
    let content: Content
    let onSwipeLeft: () -> Void

    func makeUIView(context: Context) -> UIView {
        let host = UIHostingController(rootView: content)
        host.view.backgroundColor = .clear
        let swipe = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.didSwipeLeft(_:)))
        swipe.direction = .left
        host.view.addGestureRecognizer(swipe)
        context.coordinator.host = host
        return host.view!
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.host?.rootView = content
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onSwipeLeft: onSwipeLeft)
    }

    class Coordinator: NSObject {
        var onSwipeLeft: () -> Void
        weak var host: UIHostingController<Content>?

        init(onSwipeLeft: @escaping () -> Void) {
            self.onSwipeLeft = onSwipeLeft
        }

        @objc func didSwipeLeft(_: UISwipeGestureRecognizer) {
            onSwipeLeft()
        }
    }
}

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
    /// Set id whose rest bar is currently being edited (nil = none).
    @State private var editingRestSetId: String?
    @State private var workoutNotes: String = ""
    @State private var isShowingNoteEditor: Bool = false
    @State private var showRestTimePicker: Bool = false
    @State private var replacingExerciseId: String?
    @State private var isShowingReplacePicker: Bool = false
    /// Incremented when display unit/intensity is saved so the sheet (e.g. previous column) re-renders.
    @State private var displayPrefsVersion: Int = 0
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

    /// Set weight unit for all exercises in the current workout (per-exercise storage) and app-wide default.
    private func saveWeightUnitForCurrentWorkout(unit: String) {
        let exerciseIds = workoutExercises.map(\.exerciseId)
        DisplayPreferences.setWeightUnit(unit, forExerciseIds: exerciseIds)
        displayPrefsVersion += 1
    }

    /// Set intensity display for all exercises in the current workout (per-exercise storage) and app-wide default.
    private func saveIntensityDisplayForCurrentWorkout(display: String) {
        let exerciseIds = workoutExercises.map(\.exerciseId)
        DisplayPreferences.setIntensityDisplay(display, forExerciseIds: exerciseIds)
        displayPrefsVersion += 1
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

    /// Date and time the workout was started (e.g. "Feb 10, 2025 at 2:30 PM").
    private var workoutStartedAtFormatted: String? {
        guard let startedAt = workoutStartedAt else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
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
        if let setId = editingRestSetId {
            if let seconds = parseRestTime(restTimeEditText), seconds > 0 {
                try? workoutStore.updateSet(setId: setId, weight: nil, reps: nil, restTimerSeconds: seconds)
            }
            editingRestSetId = nil
            reloadPreservingTitleEdits()
        } else {
            if let seconds = parseRestTime(restTimeEditText), seconds > 0 {
                restTimeSeconds = seconds
            }
            restTimeEditText = restTimeFormatted
        }
        isEditingRestTime = false
    }

    private func formatRestSeconds(_ seconds: Int?) -> String {
        guard let s = seconds, s > 0 else { return "0:00" }
        let min = s / 60
        let sec = s % 60
        return String(format: "%d:%02d", min, sec)
    }

    @ViewBuilder
    private func restTimerBar(setAbove: WorkoutSetDetail) -> some View {
        RestTimerBarView(
            setAbove: setAbove,
            restTimeEditText: $restTimeEditText,
            editingRestSetId: $editingRestSetId,
            formatRestSeconds: formatRestSeconds,
            onTap: {
                editingRestSetId = setAbove.id
                restTimeEditText = formatRestSeconds(setAbove.restTimerSeconds)
                isEditingRestTime = true
            },
            onCommit: commitRestTimeEdit
        )
    }

    /// Rounds to nearest tenth for display.
    private func roundedToTenth(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }

    /// Formats previous set for display; weight is in lbs, converted to displayUnit, rounded to nearest tenth. "50 × 10", "50 lbs", "10 reps", or "—".
    private func formatPreviousSet(_ previous: (weight: Double?, reps: Int?)?, displayWeightUnit: String) -> String {
        guard let prev = previous else { return "—" }
        let hasWeight = prev.weight != nil && prev.weight! > 0
        let hasReps = prev.reps != nil && prev.reps! > 0
        let unitSuffix = displayWeightUnit == "kg" ? " kg" : " lbs"
        if hasWeight && hasReps {
            let lbs = prev.weight!
            let raw = displayWeightUnit == "kg" ? lbs / 2.20462 : lbs
            let displayW = roundedToTenth(raw)
            let r = prev.reps!
            let wStr = displayW == Double(Int(displayW)) ? String(Int(displayW)) : String(format: "%.1f", displayW)
            return "\(wStr) × \(r)"
        }
        if hasWeight {
            let lbs = prev.weight!
            let raw = displayWeightUnit == "kg" ? lbs / 2.20462 : lbs
            let displayW = roundedToTenth(raw)
            let wStr = displayW == Double(Int(displayW)) ? String(Int(displayW)) : String(format: "%.1f", displayW)
            return wStr + unitSuffix
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

                if case .workout = subject, let dateTimeStr = workoutStartedAtFormatted {
                    Text(dateTimeStr)
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
                // Workout overview: title, date & duration inline
                // TODO: Notes will eventually need to be re-added here (e.g. menu or note entry).
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .center) {
                        TextField("", text: $title)
                            .font(.system(size: 25, weight: .bold))
                            .foregroundStyle(.primary)
                        Spacer()
                    }

                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            if let dateTimeStr = workoutStartedAtFormatted {
                                Text(dateTimeStr)
                                    .font(.system(size: 15))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            if isPendingWorkout {
                                TimelineView(.periodic(from: .now, by: 1.0)) { _ in
                                    Text(workoutDurationFormatted ?? "0:00")
                                        .font(.system(size: 15))
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                Text(workoutDurationFormatted ?? "0:00")
                                    .font(.system(size: 15))
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
                            .font(.system(size: 12))
                            .foregroundStyle(Color(red: 0.4, green: 0.6, blue: 1.0))
                            .padding(.top, 1)
                        Text(workoutNotes)
                            .font(.system(size: 15))
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

                // Exercises with table layout (id includes displayPrefsVersion so previous column and headers update when unit/RIR-RPE toggled)
                ForEach(workoutExercises) { exercise in
                    sheetExerciseBlock(exercise: exercise, workoutId: workoutId)
                        .id("\(exercise.id)-\(displayPrefsVersion)")
                }

                // Add Exercises button (compact)
                Button {
                    isShowingExercisePicker = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12))
                        Text("Add Exercises")
                            .font(.system(size: 15, weight: .medium))
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
                    // Cancel is in the active workout header (ActiveWorkoutSheetView), not here.
                } else {
                    Button {
                        saveAndClose()
                    } label: {
                        Text("Save Changes")
                            .font(.system(size: 19, weight: .medium))
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
                            .font(.system(size: 19, weight: .medium))
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
        let exerciseWeightUnit = DisplayPreferences.displayWeightUnit(for: exercise.exerciseId)
        let exerciseIntensityDisplay = DisplayPreferences.displayIntensityDisplay(for: exercise.exerciseId)
        return VStack(alignment: .leading, spacing: 2) {
            // Exercise name (blue) + icons
            HStack(spacing: 6) {
                Button {
                    selectedExerciseForHistory = ExerciseHistorySelection(
                        id: exercise.exerciseId, name: exercise.exerciseName)
                } label: {
                    Text(exercise.exerciseName)
                        .font(.system(size: 15, weight: .semibold))
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
                        saveWeightUnitForCurrentWorkout(unit: "lbs")
                    } label: {
                        Label(exerciseWeightUnit == "lbs" ? "Use lbs (current)" : "Use lbs", systemImage: "scalemass")
                    }
                    Button {
                        saveWeightUnitForCurrentWorkout(unit: "kg")
                    } label: {
                        Label(exerciseWeightUnit == "kg" ? "Use kg (current)" : "Use kg", systemImage: "scalemass")
                    }
                    Divider()
                    Button {
                        saveIntensityDisplayForCurrentWorkout(display: "rpe")
                    } label: {
                        Label(exerciseIntensityDisplay == "rpe" ? "Use RPE (current)" : "Use RPE", systemImage: "gauge.with.dots.needle.67percent")
                    }
                    Button {
                        saveIntensityDisplayForCurrentWorkout(display: "rir")
                    } label: {
                        Label(exerciseIntensityDisplay == "rir" ? "Use RIR (current)" : "Use RIR", systemImage: "gauge.with.dots.needle.33percent")
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
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 2)
            .padding(.bottom, 8)

            // Table header (widths and spacing must match SheetSetRow for alignment)
            HStack(spacing: 6) {
                Text("Set")
                    .frame(width: 24, alignment: .leading)
                Text("Previous")
                    .frame(maxWidth: .infinity)
                Text(exerciseWeightUnit)
                    .frame(width: 48, alignment: .center)
                Text("Reps")
                    .frame(width: 40, alignment: .center)
                Text(exerciseIntensityDisplay == "rpe" ? "RPE" : "RIR")
                    .frame(width: 40, alignment: .center)
            }
            .font(.system(size: 12))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 16)

            // Set rows with rest bars between
            let previousSets = previousPerformanceByExerciseId[exercise.exerciseId] ?? []
            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                if index > 0 {
                    let setAbove = exercise.sets[index - 1]
                    restTimerBar(setAbove: setAbove)
                }

                let previousSet = index < previousSets.count ? previousSets[index] : nil
                SheetSetRow(
                    set: set,
                    previousText: formatPreviousSet(previousSet, displayWeightUnit: exerciseWeightUnit),
                    useRPE: exerciseIntensityDisplay == "rpe",
                    weightInLbs: set.weight,
                    displayWeightUnit: exerciseWeightUnit,
                    onChange: { weight, reps, intensity, isWarmUp in
                        let weightLbs = weight.map { w in
                            exerciseWeightUnit == "kg" ? w * 2.20462 : w
                        }
                        let rpe = intensity.map { val in
                            exerciseIntensityDisplay == "rpe" ? val : 10 - val
                        }
                        do {
                            try workoutStore.updateSet(
                                setId: set.id,
                                weight: weightLbs,
                                reps: reps,
                                rpe: rpe,
                                isWarmUp: isWarmUp ?? set.isWarmUp
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
                                    rpe: nil, isWarmUp: false)
                            case .warmUp:
                                try workoutStore.updateSet(
                                    setId: set.id, weight: set.weight, reps: set.reps,
                                    rpe: set.rpe, isWarmUp: true)
                            case .failure:
                                try workoutStore.updateSet(
                                    setId: set.id, weight: set.weight, reps: set.reps,
                                    rpe: 10, isWarmUp: false)
                            }
                        } catch {}
                        reloadPreservingTitleEdits()
                    },
                    onDelete: {
                        var t = Transaction()
                        t.disablesAnimations = true
                        withTransaction(t) {
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
                var t = Transaction()
                t.disablesAnimations = true
                withTransaction(t) {
                    do {
                        try workoutStore.addSet(workoutExerciseId: exercise.id)
                    } catch {}
                    reloadPreservingTitleEdits()
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "plus")
                        .font(.system(size: 11))
                    Text("Add Set (\(restTimeFormatted))")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundStyle(Color(.systemGray))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 16)
            .padding(.top, 10)
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
    let useRPE: Bool
    /// Weight in lbs (DB canonical).
    let weightInLbs: Double?
    let displayWeightUnit: String
    let onChange: (Double?, Int?, Double?, Bool?) -> Void
    /// Called when the set type (warm-up / failure) changes.
    let onSetTypeChanged: (SetType) -> Void
    /// Called when the user swipes to delete this set.
    let onDelete: () -> Void

    private enum Field: Hashable {
        case weight, reps, intensity
    }

    /// Display weight (kg or lbs depending on preference).
    private var displayWeight: Double? {
        guard let lbs = weightInLbs else { return nil }
        return displayWeightUnit == "kg" ? lbs / 2.20462 : lbs
    }
    /// Display intensity (RPE or RIR depending on preference).
    private var displayIntensity: Double? {
        guard let rpe = set.rpe else { return nil }
        return useRPE ? rpe : 10 - rpe
    }

    @State private var weightText: String = ""
    @State private var repsText: String = ""
    @State private var intensityText: String = ""
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
        onChange(parseDouble(weightText), parseInt(repsText), parseDouble(intensityText), nil)
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

    private var setRowContent: some View {
        HStack(spacing: 6) {
            Button {
                setType = setType.next
                onSetTypeChanged(setType)
            } label: {
                Text(setLabel)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(setLabelColor)
                    .frame(width: 20, height: 20)
                    .background(setLabelBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
            .buttonStyle(.plain)
            .frame(width: 24, alignment: .leading)

            Text(previousText)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)

            TextField("", text: $weightText)
                .focused($focusedField, equals: .weight)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 15))
                .frame(width: 48, height: 32)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(focusedField == .weight ? Color.accentColor : Color.clear, lineWidth: 2)
                )
                .onSubmit { focusedField = nil }

            TextField("", text: $repsText)
                .focused($focusedField, equals: .reps)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 15))
                .frame(width: 40, height: 32)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(focusedField == .reps ? Color.accentColor : Color.clear, lineWidth: 2)
                )
                .onSubmit { focusedField = nil }

            TextField("", text: $intensityText)
                .focused($focusedField, equals: .intensity)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 15))
                .frame(width: 40, height: 32)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(focusedField == .intensity ? Color.accentColor : Color.clear, lineWidth: 2)
                )
                .onSubmit { focusedField = nil }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 0)
        .background(Color(UIColor.systemBackground))
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete background revealed on swipe
            Button {
                onDelete()
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

            // Main row content (spacing and widths must match table header); swipe lives on hosting view so scroll is not blocked
            SetRowWithSwipe(
                content: setRowContent,
                onSwipeLeft: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        swipeOffset = -70
                    }
                }
            )
            .offset(x: swipeOffset)

            if swipeOffset < 0 {
                Color.clear
                    .contentShape(.rect)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            swipeOffset = 0
                        }
                    }
            }
        }
        .clipped()
        .onAppear {
            refreshDisplayFromPreferences()
            // Restore set type from model
            if set.isWarmUp == true {
                setType = .warmUp
            } else if set.rpe == 10 {
                setType = .failure
            } else {
                setType = .normal
            }
        }
        .onChange(of: displayWeightUnit) { _, _ in refreshDisplayFromPreferences() }
        .onChange(of: useRPE) { _, _ in refreshDisplayFromPreferences() }
        .onChange(of: weightText) { _, _ in commit() }
        .onChange(of: repsText) { _, _ in commit() }
        .onChange(of: intensityText) { _, _ in commit() }
    }

    /// Rounds to nearest tenth for display.
    private func roundedToTenth(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }

    private func refreshDisplayFromPreferences() {
        if let w = displayWeight {
            let r = roundedToTenth(w)
            weightText = r == Double(Int(r)) ? String(Int(r)) : String(format: "%.1f", r)
        } else {
            weightText = ""
        }
        repsText = set.reps.map { String($0) } ?? ""
        if let i = displayIntensity {
            let r = roundedToTenth(i)
            intensityText = r == Double(Int(r)) ? String(Int(r)) : String(format: "%.1f", r)
        } else {
            intensityText = ""
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
                            restTimeSeconds = seconds
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

// MARK: - Rest timer bar (between sets, highlight when selected)

private struct RestTimerBarView: View {
    let setAbove: WorkoutSetDetail
    @Binding var restTimeEditText: String
    @Binding var editingRestSetId: String?
    let formatRestSeconds: (Int?) -> String
    let onTap: () -> Void
    let onCommit: () -> Void

    private var isSelected: Bool {
        editingRestSetId == setAbove.id
    }

    private var displayText: String {
        isSelected ? restTimeEditText : formatRestSeconds(setAbove.restTimerSeconds)
    }

    var body: some View {
        HStack {
            ZStack {
                Rectangle()
                    .fill(
                        isSelected
                            ? Color(red: 0.2, green: 0.4, blue: 1.0).opacity(0.35)
                            : Color(red: 0.2, green: 0.4, blue: 1.0).opacity(0.15)
                    )
                    .frame(height: 0.5)

                if isSelected {
                    TextField("0:00", text: $restTimeEditText, onCommit: onCommit)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(red: 0.2, green: 0.4, blue: 1.0))
                        .multilineTextAlignment(.center)
                        .keyboardType(.numbersAndPunctuation)
                        .frame(width: 36)
                        .padding(.horizontal, 2)
                        .padding(.vertical, 4)
                        .background(Color(UIColor.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                } else {
                    Text(displayText)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(red: 0.2, green: 0.4, blue: 1.0))
                        .frame(width: 36)
                        .contentShape(Rectangle())
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 18)
            .onTapGesture {
                onTap()
            }
        }
        .padding(.horizontal, 16)
        .background(Color(UIColor.systemBackground))
        .frame(height: 18)
    }
}

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}
