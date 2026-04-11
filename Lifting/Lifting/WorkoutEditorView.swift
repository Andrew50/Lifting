//
//  WorkoutEditorView.swift
//  Lifting
//
//  Created by Andrew Billings on 1/31/26.
//

import SwiftUI
import UIKit

// MARK: - Color hex extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - App Theme

enum AppTheme {
    static let background = Color(hex: "#F8F9FA")
    static let cardBackground = Color.white
    static let cardBorder = Color(hex: "#F3F4F6")
    static let accent = Color(hex: "#059669")
    static let accentLight = Color(hex: "#D1FAE5")
    static let accentLighter = Color(hex: "#F0FDF4")
    static let accentText = Color(hex: "#065F46")
    static let accentMuted = Color(hex: "#6EE7B7")
    static let textPrimary = Color(hex: "#111827")
    static let textSecondary = Color(hex: "#9CA3AF")
    static let textTertiary = Color(hex: "#D1D5DB")
    static let fieldBackground = Color(hex: "#F9FAFB")
    static let fieldBorder = Color(hex: "#F3F4F6")
    static let cancelBackground = Color(hex: "#FEE2E2")
    static let cancelText = Color(hex: "#DC2626")
    static let finishBackground = Color(hex: "#D1FAE5")
    static let finishText = Color(hex: "#065F46")
    static let warmupBackground = Color(hex: "#FEF3C7")
    static let warmupText = Color(hex: "#D97706")
    static let dropSetBackground = Color(hex: "#EDE9FE")
    static let dropSetText = Color(hex: "#7C3AED")
    static let inactiveOpacity = 0.6
    static let doneOpacity = 0.5
}

// MARK: - Hosts row content and adds UISwipeGestureRecognizer (does not block ScrollView vertical scrolling)
private struct SetRowWithSwipe<Content: View>: UIViewRepresentable {
    let content: Content
    let onSwipeLeft: () -> Void

    func makeUIView(context: Context) -> UIView {
        let host = UIHostingController(rootView: content)
        host.view.backgroundColor = .clear
        let swipe = UISwipeGestureRecognizer(
            target: context.coordinator, action: #selector(Coordinator.didSwipeLeft(_:)))
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

private enum SetRowMetrics {
    static let gap: CGFloat = 6
    static let midGap: CGFloat = 16
    static let checkCol: CGFloat = 44
    /// Wider than `col` for the Previous column.
    static let previousCol: CGFloat = 88
    /// Nudges lbs + reps headers and fields right without moving the check column.
    static let lbsRepsLeadingNudge: CGFloat = 8
    static var addSetWidth: CGFloat {
        col + gap + previousCol + midGap + lbsRepsLeadingNudge + col + gap + col
    }
    static let horizontalPadding: CGFloat = 16

    // Total row width = 4 * dataCol + 3 * gap (between data cols) + gap + checkCol + 2 * horizontalPadding
    // On a 390pt wide screen (iPhone 15): 4*76 + 3*6 + 6 + 44 + 32 = 304 + 18 + 6 + 44 + 32 = 404 ❌
    // Adjust dataCol so it fits: (390 - 32 - 44 - 5*6) / 4 = (390 - 32 - 44 - 30) / 4 = 284 / 4 = 71; use 68 for edge breathing room
    static let col: CGFloat = 60

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
                try workoutStore.addWorkoutExercise(
                    workoutId: workoutId, exerciseId: exercise.id,
                    defaultRestTimerSeconds: restTimeSeconds)
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
        return min == 0 ? "\(total % 60)s" : total.formattedAsMinutesSeconds
    }

    private var restTimeFormatted: String {
        restTimeSeconds.formattedAsMinutesSeconds
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
                try? workoutStore.updateSet(
                    setId: setId, weight: nil, reps: nil, restTimerSeconds: seconds)
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
        return s.formattedAsMinutesSeconds
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
    private func formatPreviousSet(
        _ previous: (weight: Double?, reps: Int?)?, displayWeightUnit: String
    ) -> String {
        guard let prev = previous else { return "—" }
        let hasWeight = prev.weight != nil && prev.weight! > 0
        let hasReps = prev.reps != nil && prev.reps! > 0
        let unitSuffix = displayWeightUnit == "kg" ? " kg" : " lbs"
        if hasWeight && hasReps {
            let lbs = prev.weight!
            let raw = displayWeightUnit == "kg" ? lbs / 2.20462 : lbs
            let displayW = roundedToTenth(raw)
            let r = prev.reps!
            let wStr =
                displayW == Double(Int(displayW))
                ? String(Int(displayW)) : String(format: "%.1f", displayW)
            return "\(wStr) × \(r)"
        }
        if hasWeight {
            let lbs = prev.weight!
            let raw = displayWeightUnit == "kg" ? lbs / 2.20462 : lbs
            let displayW = roundedToTenth(raw)
            let wStr =
                displayW == Double(Int(displayW))
                ? String(Int(displayW)) : String(format: "%.1f", displayW)
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
        let exercisesDone = workoutExercises.filter { ex in
            !ex.sets.isEmpty && ex.sets.allSatisfy { $0.isCompleted == true }
        }.count
        let firstIncompleteExerciseIndex = workoutExercises.firstIndex { ex in
            ex.sets.contains { $0.isCompleted != true }
        }

        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .center) {
                        TextField("", text: $title)
                            .font(.system(size: 23, weight: .heavy))
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                    }

                    if let dateTimeStr = workoutStartedAtFormatted {
                        Text(
                            "\(dateTimeStr) · \(exercisesDone) of \(workoutExercises.count) exercises done"
                        )
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)

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

                ForEach(Array(workoutExercises.enumerated()), id: \.element.id) { index, exercise in
                    let completedCount = exercise.sets.filter { $0.isCompleted == true }.count
                    let isInactive = completedCount == 0 && index != firstIncompleteExerciseIndex
                    sheetExerciseBlock(
                        exercise: exercise, workoutId: workoutId, isInactive: isInactive
                    )
                    .id("\(exercise.id)-\(displayPrefsVersion)")
                }

                Button {
                    isShowingExercisePicker = true
                } label: {
                    Text("Add Exercises")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.accentLight.opacity(0.07))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                                .foregroundStyle(AppTheme.accent.opacity(0.25))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.horizontal, 12)
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
        .background(AppTheme.background)
    }

    private func sheetExerciseBlock(
        exercise: WorkoutExerciseDetail, workoutId: String, isInactive: Bool
    ) -> some View {
        let exerciseWeightUnit = DisplayPreferences.displayWeightUnit(for: exercise.exerciseId)
        let exerciseIntensityDisplay = DisplayPreferences.displayIntensityDisplay(
            for: exercise.exerciseId)
        let completedSets = exercise.sets.filter { $0.isCompleted == true }.count
        let totalSets = exercise.sets.count
        let muscleGroup =
            exerciseStore.exercises.first { $0.id == exercise.exerciseId }?.muscleGroup ?? ""
        let previousSets = previousPerformanceByExerciseId[exercise.exerciseId] ?? []

        let firstIncompleteSetIndex: Int? = {
            for (i, s) in exercise.sets.enumerated() {
                if s.isCompleted != true {
                    let allPreviousCompleted = exercise.sets[0..<i].allSatisfy {
                        $0.isCompleted == true
                    }
                    if allPreviousCompleted { return i }
                    return nil
                }
            }
            return nil
        }()

        return VStack(alignment: .leading, spacing: 0) {
            // Card header
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 4) {
                    Button {
                        selectedExerciseForHistory = ExerciseHistorySelection(
                            id: exercise.exerciseId, name: exercise.exerciseName)
                    } label: {
                        Text(exercise.exerciseName)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(AppTheme.accent)
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 6) {
                        if !muscleGroup.isEmpty {
                            Text(muscleGroup)
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.textSecondary)
                        }

                        Text("\(completedSets) / \(totalSets) sets")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(AppTheme.accentText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(AppTheme.accentLight)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                }

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
                        Label(
                            exerciseWeightUnit == "lbs" ? "Use lbs (current)" : "Use lbs",
                            systemImage: "scalemass")
                    }
                    Button {
                        saveWeightUnitForCurrentWorkout(unit: "kg")
                    } label: {
                        Label(
                            exerciseWeightUnit == "kg" ? "Use kg (current)" : "Use kg",
                            systemImage: "scalemass")
                    }
                    Divider()
                    Button {
                        saveIntensityDisplayForCurrentWorkout(display: "rpe")
                    } label: {
                        Label(
                            exerciseIntensityDisplay == "rpe" ? "Use RPE (current)" : "Use RPE",
                            systemImage: "gauge.with.dots.needle.67percent")
                    }
                    Button {
                        saveIntensityDisplayForCurrentWorkout(display: "rir")
                    } label: {
                        Label(
                            exerciseIntensityDisplay == "rir" ? "Use RIR (current)" : "Use RIR",
                            systemImage: "gauge.with.dots.needle.33percent")
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
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textTertiary)
                        .frame(width: 32, height: 32)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 8)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppTheme.fieldBorder)
                        .frame(height: 3)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppTheme.accent)
                        .frame(
                            width: geo.size.width * CGFloat(completedSets)
                                / CGFloat(max(totalSets, 1)),
                            height: 3
                        )
                }
            }
            .frame(height: 3)
            .padding(.horizontal, 14)
            .padding(.bottom, 10)

            // Column header
            HStack(spacing: 0) {
                Text("SET")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .multilineTextAlignment(.center)
                    .frame(width: SetRowMetrics.col)

                Text("PREVIOUS")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .multilineTextAlignment(.center)
                    .frame(width: SetRowMetrics.previousCol)
                    .padding(.leading, 16)

                Text(exerciseWeightUnit)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .multilineTextAlignment(.center)
                    .frame(width: SetRowMetrics.col)

                Text("REPS")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .multilineTextAlignment(.center)
                    .frame(width: SetRowMetrics.col)

                Spacer(minLength: 0)

                Spacer().frame(width: SetRowMetrics.checkCol)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 6)

            // Set rows
            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                if index > 0 {
                    let setAbove = exercise.sets[index - 1]
                    restTimerBar(setAbove: setAbove)
                }

                let previousSet = index < previousSets.count ? previousSets[index] : nil
                let isActiveSet = (index == firstIncompleteSetIndex)
                SheetSetRow(
                    set: set,
                    previousText: formatPreviousSet(
                        previousSet, displayWeightUnit: exerciseWeightUnit),
                    useRPE: exerciseIntensityDisplay == "rpe",
                    weightInLbs: set.weight,
                    displayWeightUnit: exerciseWeightUnit,
                    isActiveSet: isActiveSet,
                    onChange: { weight, reps, intensity, isWarmUp in
                        let weightLbs = weight.map { w in
                            exerciseWeightUnit == "kg" ? w * 2.20462 : w
                        }
                        let rpe = intensity.map { val in
                            exerciseIntensityDisplay == "rpe" ? val : 10 - val
                        }

                        let wasCompleted = set.isCompleted ?? false
                        let bothFieldsFilled = (weightLbs != nil && reps != nil)

                        let restSecondsToSet: Int? =
                            (bothFieldsFilled && !wasCompleted && set.restTimerSeconds == nil)
                            ? restTimeSeconds : nil

                        do {
                            try workoutStore.updateSet(
                                setId: set.id,
                                weight: weightLbs,
                                reps: reps,
                                rpe: rpe,
                                isWarmUp: isWarmUp ?? set.isWarmUp,
                                isCompleted: bothFieldsFilled ? true : nil,
                                restTimerSeconds: restSecondsToSet
                            )
                        } catch {}

                        if bothFieldsFilled && !wasCompleted {
                            onSetCompleted?()
                        }

                        reloadPreservingTitleEdits()
                    },
                    onSetTypeChanged: { newType in
                        do {
                            switch newType {
                            case .normal:
                                try workoutStore.updateSet(
                                    setId: set.id, weight: set.weight, reps: set.reps,
                                    rpe: nil, isWarmUp: false, isDropSet: false)
                            case .warmUp:
                                try workoutStore.updateSet(
                                    setId: set.id, weight: set.weight, reps: set.reps,
                                    rpe: set.rpe, isWarmUp: true, isDropSet: false)
                            case .dropSet:
                                try workoutStore.updateSet(
                                    setId: set.id, weight: set.weight, reps: set.reps,
                                    rpe: set.rpe, isWarmUp: false, isDropSet: true)
                            case .failure:
                                try workoutStore.updateSet(
                                    setId: set.id, weight: set.weight, reps: set.reps,
                                    rpe: 10, isWarmUp: false, isDropSet: false)
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
                    },
                    onToggleCompleted: { completed in
                        let wasCompleted = set.isCompleted ?? false
                        let restSecondsToSet: Int? =
                            (completed && set.restTimerSeconds == nil) ? restTimeSeconds : nil
                        do {
                            try workoutStore.updateSet(
                                setId: set.id,
                                weight: nil,
                                reps: nil,
                                rpe: nil,
                                isWarmUp: nil,
                                isCompleted: completed,
                                restTimerSeconds: restSecondsToSet
                            )
                        } catch {}

                        if completed && !wasCompleted {
                            onSetCompleted?()
                        }

                        reloadPreservingTitleEdits()
                    }
                )
            }

            // Card footer
            Button {
                var t = Transaction()
                t.disablesAnimations = true
                withTransaction(t) {
                    do {
                        try workoutStore.addSet(
                            workoutExerciseId: exercise.id, restTimerSeconds: restTimeSeconds)
                    } catch {}
                    reloadPreservingTitleEdits()
                }
            } label: {
                Text("+ Add Set (\(restTimeFormatted))")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(AppTheme.fieldBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                            .foregroundStyle(AppTheme.textTertiary)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
        .opacity(isInactive ? AppTheme.inactiveOpacity : 1.0)
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
                            fromTemplate: templateId, defaultRestTimerSeconds: restTimeSeconds)
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
    case normal, warmUp, dropSet, failure
}

private struct SheetSetRow: View {
    let set: WorkoutSetDetail
    let previousText: String
    let useRPE: Bool
    let weightInLbs: Double?
    let displayWeightUnit: String
    let isActiveSet: Bool
    let onChange: (Double?, Int?, Double?, Bool?) -> Void
    let onSetTypeChanged: (SetType) -> Void
    let onDelete: () -> Void
    let onToggleCompleted: (Bool) -> Void

    private enum Field: Hashable {
        case weight, reps
    }

    private var displayWeight: Double? {
        guard let lbs = weightInLbs else { return nil }
        return displayWeightUnit == "kg" ? lbs / 2.20462 : lbs
    }

    @State private var weightText: String = ""
    @State private var repsText: String = ""
    @State private var swipeOffset: CGFloat = 0
    @State private var showDeleteConfirm: Bool = false
    @State private var localCompleted: Bool = false
    @FocusState private var focusedField: Field?

    private var isCompleted: Bool { localCompleted || (set.isCompleted ?? false) }

    private var setType: SetType {
        if set.isWarmUp == true { return .warmUp }
        if set.isDropSet == true { return .dropSet }
        if set.rpe == 10 { return .failure }
        return .normal
    }

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
        let weight = parseDouble(weightText)
        let reps = parseInt(repsText)
        if weight != nil && reps != nil {
            localCompleted = true
        }
        onChange(weight, reps, nil, nil)
    }

    private var setLabel: String {
        switch setType {
        case .normal: return "\(set.sortOrder + 1)"
        case .warmUp: return "W"
        case .dropSet: return "D"
        case .failure: return "F"
        }
    }

    private var badgeBackground: Color {
        switch setType {
        case .warmUp: return AppTheme.warmupBackground
        case .dropSet: return AppTheme.dropSetBackground
        case .failure: return Color.red.opacity(0.15)
        case .normal:
            if isActiveSet { return AppTheme.accent }
            if localCompleted { return AppTheme.accentLight }
            return AppTheme.fieldBackground
        }
    }

    private var badgeForeground: Color {
        switch setType {
        case .warmUp: return AppTheme.warmupText
        case .dropSet: return AppTheme.dropSetText
        case .failure: return Color.red
        case .normal:
            if isActiveSet { return .white }
            if localCompleted { return AppTheme.accent }
            return AppTheme.textSecondary
        }
    }

    @ViewBuilder
    private func weightField() -> some View {
        let height: CGFloat = isActiveSet ? 42 : 36
        let cornerR: CGFloat = isActiveSet ? 10 : 8

        TextField("", text: $weightText)
            .focused($focusedField, equals: .weight)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.center)
            .font(.system(size: isActiveSet ? 20 : 16, weight: .bold))
            .foregroundStyle(isCompleted ? AppTheme.accent : AppTheme.textPrimary)
            .frame(width: SetRowMetrics.col, height: height)
            .background(
                isCompleted
                    ? AppTheme.accentLight : isActiveSet ? Color.white : AppTheme.fieldBackground
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerR, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerR, style: .continuous)
                    .stroke(
                        isCompleted
                            ? Color.clear
                            : (focusedField == .weight || isActiveSet)
                                ? AppTheme.accent : AppTheme.fieldBorder,
                        lineWidth: isActiveSet ? 2 : 1.5
                    )
            )
            .shadow(
                color: isActiveSet ? AppTheme.accent.opacity(0.08) : .clear, radius: 0, x: 0, y: 0
            )
            .shadow(color: isActiveSet ? AppTheme.accent.opacity(0.08) : .clear, radius: 4)
            .onSubmit { focusedField = nil }
    }

    @ViewBuilder
    private func repsField() -> some View {
        let height: CGFloat = isActiveSet ? 42 : 36
        let cornerR: CGFloat = isActiveSet ? 10 : 8

        TextField("", text: $repsText)
            .focused($focusedField, equals: .reps)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(.system(size: isActiveSet ? 20 : 16, weight: .bold))
            .foregroundStyle(isCompleted ? AppTheme.accent : AppTheme.textPrimary)
            .frame(width: SetRowMetrics.col, height: height)
            .background(
                isCompleted
                    ? AppTheme.accentLight : isActiveSet ? Color.white : AppTheme.fieldBackground
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerR, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerR, style: .continuous)
                    .stroke(
                        isCompleted
                            ? Color.clear
                            : (focusedField == .reps || isActiveSet)
                                ? AppTheme.accent : AppTheme.fieldBorder,
                        lineWidth: isActiveSet ? 2 : 1.5
                    )
            )
            .shadow(
                color: isActiveSet ? AppTheme.accent.opacity(0.08) : .clear, radius: 0, x: 0, y: 0
            )
            .shadow(color: isActiveSet ? AppTheme.accent.opacity(0.08) : .clear, radius: 4)
            .onSubmit { focusedField = nil }
    }

    @ViewBuilder
    private var checkmarkButton: some View {
        Button {
            let newValue = !isCompleted
            localCompleted = newValue
            onToggleCompleted(newValue)
        } label: {
            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(AppTheme.accent)
                    .clipShape(Circle())
            } else if isActiveSet {
                Circle()
                    .stroke(AppTheme.accent, lineWidth: 2)
                    .frame(width: 30, height: 30)
            } else {
                Circle()
                    .stroke(AppTheme.textTertiary, lineWidth: 1.5)
                    .frame(width: 24, height: 24)
            }
        }
        .buttonStyle(.plain)
        .frame(width: SetRowMetrics.checkCol, height: 36)
    }

    private var rowCells: some View {
        HStack(spacing: 0) {
            Menu {
                Button { onSetTypeChanged(.normal) } label: {
                    HStack {
                        Text("Normal")
                        if setType == .normal { Image(systemName: "checkmark") }
                    }
                }
                Button { onSetTypeChanged(.warmUp) } label: {
                    HStack {
                        Text("Warm-up")
                        if setType == .warmUp { Image(systemName: "checkmark") }
                    }
                }
                Button { onSetTypeChanged(.dropSet) } label: {
                    HStack {
                        Text("Drop Set")
                        if setType == .dropSet { Image(systemName: "checkmark") }
                    }
                }
                Button { onSetTypeChanged(.failure) } label: {
                    HStack {
                        Text("Failure")
                        if setType == .failure { Image(systemName: "checkmark") }
                    }
                }
            } label: {
                Text(setLabel)
                    .font(.system(size: 13, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(badgeForeground)
                    .frame(width: 26, height: 26)
                    .background(badgeBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .frame(width: SetRowMetrics.col, height: 36, alignment: .center)

            Text(previousText)
                .font(.system(size: 14, weight: isActiveSet ? .semibold : .medium))
                .foregroundStyle(isActiveSet ? AppTheme.accentMuted : AppTheme.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.center)
                .frame(width: SetRowMetrics.previousCol, height: 36, alignment: .center)
                .padding(.leading, 16)

            weightField()

            repsField()

            Spacer(minLength: 0)

            checkmarkButton
        }
    }

    private var setRowContent: some View {
        Group {
            if isActiveSet {
                ZStack {
                    AppTheme.accentLighter
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    rowCells
                        .padding(.horizontal, 8)
                }
                .padding(.horizontal, 6)
            } else {
                rowCells
                    .padding(.horizontal, 14)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var body: some View {
        ZStack(alignment: .trailing) {
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
        .opacity(isCompleted ? AppTheme.doneOpacity : 1.0)
        .onAppear {
            localCompleted = set.isCompleted ?? false
            refreshDisplayFromPreferences()
        }
        .onChange(of: set.isCompleted) { _, newValue in
            localCompleted = newValue ?? false
        }
        .onChange(of: displayWeightUnit) { _, _ in refreshDisplayFromPreferences() }
        .onChange(of: useRPE) { _, _ in refreshDisplayFromPreferences() }
        .onChange(of: weightText) { _, _ in commit() }
        .onChange(of: repsText) { _, _ in commit() }
    }

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
