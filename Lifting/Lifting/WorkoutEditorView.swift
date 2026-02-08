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

    @Environment(\.dismiss) private var dismiss

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
    @State private var setCompletedIds: Set<String> = []
    @State private var restTimeEditText: String = ""
    @State private var isEditingRestTime: Bool = false
    /// For sheet workout: previous set (weight, reps) per exercise, from most recent completed workout.
    @State private var previousPerformanceByExerciseId: [String: [(weight: Double?, reps: Int?)]] =
        [:]

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
                } else {
                    if shouldRefreshTitle {
                        title = "Workout"
                    }
                    lastLoadedTitle = "Workout"
                    isPendingWorkout = false
                    workoutStartedAt = nil
                    workoutCompletedAt = nil
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
        var result: [String: [(weight: Double?, reps: Int?)]] = [:]
        for exercise in workoutExercises {
            guard
                let entries = try? workoutStore.fetchExerciseHistory(
                    exerciseId: exercise.exerciseId),
                !entries.isEmpty
            else {
                result[exercise.exerciseId] = []
                continue
            }
            // Take sets from the most recent workout (first workoutId in DESC order)
            let mostRecentWorkoutId = entries[0].workoutId
            let latestSets =
                entries
                .filter { $0.workoutId == mostRecentWorkoutId }
                .sorted(by: { $0.sortOrder < $1.sortOrder })
            result[exercise.exerciseId] = latestSets.map { ($0.weight, $0.reps) }
        }
        previousPerformanceByExerciseId = result
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
            VStack(alignment: .leading, spacing: 20) {
                // Workout overview: title + menu, date, duration
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center) {
                        TextField("", text: $title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                        Spacer()
                        Button {
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.body)
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(Color(red: 0.4, green: 0.6, blue: 1.0))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let dateStr = workoutDateFormatted {
                            Text(dateStr)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
                .padding(.horizontal, 20)
                .padding(.top, 8)

                // Exercises with table layout
                ForEach(workoutExercises) { exercise in
                    sheetExerciseBlock(exercise: exercise, workoutId: workoutId)
                }

                // Add Exercises button (compact)
                Button {
                    isShowingExercisePicker = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.caption)
                        Text("Add Exercises")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(Color(red: 0.2, green: 0.4, blue: 1.0))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(red: 0.2, green: 0.4, blue: 1.0).opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.horizontal, 20)
                .padding(.top, 8)

                if isPendingWorkout {
                    // Cancel Workout button (pending only)
                    Button {
                        discardAndClose(workoutId: workoutId)
                        onFinish?()
                    } label: {
                        Text("Cancel Workout")
                            .font(.headline)
                            .foregroundStyle(Color(red: 0.9, green: 0.3, blue: 0.3))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(red: 1.0, green: 0.9, blue: 0.9))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .padding(.horizontal, 20)
                } else {
                    // Save + Delete for completed workouts
                    Button {
                        saveAndClose()
                    } label: {
                        Text("Save Changes")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.green)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .padding(.horizontal, 20)

                    Button {
                        deleteAndClose()
                    } label: {
                        Text("Delete Workout")
                            .font(.headline)
                            .foregroundStyle(Color(red: 0.9, green: 0.3, blue: 0.3))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(red: 1.0, green: 0.9, blue: 0.9))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .padding(.horizontal, 20)
                }

                Spacer().frame(height: 32)
            }
        }
    }

    private func sheetExerciseBlock(exercise: WorkoutExerciseDetail, workoutId: String) -> some View
    {
        VStack(alignment: .leading, spacing: 12) {
            // Exercise name (blue) + icons
            HStack {
                Text(exercise.exerciseName)
                    .font(.headline)
                    .foregroundStyle(Color(red: 0.2, green: 0.4, blue: 1.0))
                Spacer()
                Button {
                } label: {
                    Image(systemName: "link")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                Button {
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)

            // Table header
            HStack(spacing: 0) {
                Text("Set")
                    .frame(width: 36, alignment: .leading)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Previous")
                    .frame(maxWidth: .infinity)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("+lbs")
                    .frame(width: 56, alignment: .center)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Reps")
                    .frame(width: 48, alignment: .center)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Image(systemName: "checkmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 28, alignment: .trailing)
            }
            .padding(.horizontal, 20)

            // Set rows with rest bars between
            let previousSets = previousPerformanceByExerciseId[exercise.exerciseId] ?? []
            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                if index > 0 {
                    // Rest timer bar between sets — editable inline
                    ZStack {
                        // Blue line spanning full width
                        Rectangle()
                            .fill(Color(red: 0.2, green: 0.4, blue: 1.0).opacity(0.3))
                            .frame(height: 2)

                        // Centered editable rest time
                        TextField(
                            "0:00", text: $restTimeEditText,
                            onCommit: {
                                commitRestTimeEdit()
                            }
                        )
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color(red: 0.2, green: 0.4, blue: 1.0))
                        .multilineTextAlignment(.center)
                        .keyboardType(.numbersAndPunctuation)
                        .frame(width: 48)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white)
                        .onTapGesture {
                            isEditingRestTime = true
                            restTimeEditText = restTimeFormatted
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 4)
                }

                let previousSet = index < previousSets.count ? previousSets[index] : nil
                SheetSetRow(
                    set: set,
                    previousText: formatPreviousSet(previousSet),
                    isCompleted: setCompletedIds.contains(set.id),
                    onToggleComplete: {
                        if setCompletedIds.contains(set.id) {
                            setCompletedIds.remove(set.id)
                        } else {
                            setCompletedIds.insert(set.id)
                        }
                    },
                    onChange: { weight, reps, _, _ in
                        do {
                            try workoutStore.updateSet(
                                setId: set.id, weight: weight, reps: reps, rir: nil, isWarmUp: nil)
                        } catch {}
                        reloadPreservingTitleEdits()
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
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.caption)
                    Text("Add Set")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundStyle(Color(.systemGray))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
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
        .background(Color.white)
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
        .onChange(of: restTimeSeconds) { _ in
            if !isEditingRestTime {
                restTimeEditText = restTimeFormatted
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

private struct SheetSetRow: View {
    let set: WorkoutSetDetail
    /// Previous performance for this set (e.g. "50 × 10" or "—").
    let previousText: String
    let isCompleted: Bool
    let onToggleComplete: () -> Void
    let onChange: (Double?, Int?, Double?, Bool?) -> Void

    @State private var weightText: String = ""
    @State private var repsText: String = ""

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

    var body: some View {
        HStack(spacing: 0) {
            Text("\(set.sortOrder + 1)")
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(width: 36, alignment: .leading)

            Text(previousText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)

            TextField("", text: $weightText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.subheadline)
                .frame(width: 56)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            TextField("", text: $repsText)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.subheadline)
                .frame(width: 48)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Button(action: onToggleComplete) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundStyle(
                        isCompleted ? Color(red: 0.2, green: 0.4, blue: 1.0) : .secondary)
            }
            .buttonStyle(.plain)
            .frame(width: 28, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
        .onAppear {
            weightText =
                set.weight.map { $0 == Double(Int($0)) ? String(Int($0)) : String($0) } ?? ""
            repsText = set.reps.map { String($0) } ?? ""
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

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
