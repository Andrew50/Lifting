//
//  WorkoutView.swift
//  Lifting
//
//  Created by Andrew Billings on 1/31/26.
//

import Charts
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
    @ObservedObject var bodyWeightStore: BodyWeightStore
    @ObservedObject var onboardingStore: OnboardingStore

    enum Route: Hashable {
        case template(String)
        case workout(String)
    }

    @State private var path: [Route] = []
    @State private var errorMessage: String?
    @State private var newTemplateIds: Set<String> = []
    @State private var activeWorkoutSheetItem: WorkoutSheetItem?
    @State private var activeWorkoutSheetDetent: PresentationDetent = .large
    @State private var collapsedActiveWorkoutId: String?
    @State private var showWeightLogSheet: Bool = false
    @State private var weightLogText: String = ""
    @State private var latestPR: PersonalRecordRecord? = nil
    @State private var latestPRExerciseName: String = ""
    @State private var isPRDismissed: Bool = false

    private let activeWorkoutCollapsedHeight: CGFloat = 72

    private var greetingTitle: String {
        if let name = authStore.currentUser?.name {
            let firstName = name.split(separator: " ").first.map(String.init) ?? name
            return "Hi, \(firstName)!"
        }
        return "Hi there!"
    }

    private var dateSubtitle: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE · MMM d, yyyy"
        return f.string(from: Date())
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            let k = volume / 1000
            return k == Double(Int(k)) ? "\(Int(k))k" : String(format: "%.1fk", k)
        }
        return "\(Int(volume))"
    }

    var body: some View {
        VStack(spacing: 0) {
            NavigationStack(path: $path) {
                ScrollView {
                    VStack(spacing: 12) {
                        // Header
                        VStack(alignment: .leading, spacing: 2) {
                            Text(greetingTitle)
                                .font(.system(size: 28, weight: .heavy))
                                .foregroundStyle(AppTheme.textPrimary)
                            HStack(spacing: 10) {
                                Text(dateSubtitle)
                                    .font(.system(size: 13))
                                    .foregroundStyle(AppTheme.textSecondary)

                                if workoutStore.stats.weeklyVolume > 0 {
                                    HStack(spacing: 4) {
                                        Image(systemName: "figure.strengthtraining.traditional")
                                            .font(.system(size: 11))
                                        Text("\(formatVolume(workoutStore.stats.weeklyVolume)) lbs this week")
                                            .font(.system(size: 12, weight: .bold))
                                    }
                                    .foregroundStyle(AppTheme.accent)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(AppTheme.accentLighter)
                                    .overlay(
                                        Capsule()
                                            .stroke(AppTheme.accentLight, lineWidth: 1)
                                    )
                                    .clipShape(Capsule())
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                        // Body Weight card
                        BodyWeightCard(
                            bodyWeightStore: bodyWeightStore,
                            showLogSheet: $showWeightLogSheet,
                            weightLogText: $weightLogText,
                            fitnessGoal: onboardingStore.fitnessGoal
                        )
                        .padding(.horizontal, 16)

                        // PR strip
                        if let pr = latestPR, !isPRDismissed {
                            HStack(spacing: 10) {
                                Image(systemName: "trophy.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Color(hex: "#D97706"))
                                    .frame(width: 28, height: 28)
                                    .background(Color(hex: "#FEF3C7"))
                                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("New PR — \(latestPRExerciseName)")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(Color(hex: "#065F46"))
                                    Text(prDetailText(pr))
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(AppTheme.accent)
                                }

                                Spacer()

                                Button("Share") {
                                    // share sheet — implement later
                                }
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(AppTheme.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                                Button {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        isPRDismissed = true
                                    }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(AppTheme.textTertiary)
                                }
                            }
                            .padding(14)
                            .background(AppTheme.accentLighter)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(AppTheme.accentLight, lineWidth: 1.5)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .padding(.horizontal, 16)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        // Start Workout CTA
                        Button {
                            do {
                                let workoutId = try workoutStore.startOrResumePendingWorkout()
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                    activeWorkoutSheetDetent = .large
                                    activeWorkoutSheetItem = WorkoutSheetItem(workoutId: workoutId)
                                }
                            } catch {
                                errorMessage = "Start Workout failed: \(error)"
                            }
                        } label: {
                            Text("Start Workout")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(AppTheme.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .padding(.horizontal, 16)

                        // Templates
                        VStack(alignment: .leading, spacing: 12) {
                            Text("TEMPLATES")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                                .tracking(0.5)
                                .padding(.horizontal, 16)

                            if !templateStore.templates.isEmpty {
                                VStack(spacing: 0) {
                                    ForEach(Array(templateStore.templates.enumerated()), id: \.element.id) { index, template in
                                        NavigationLink(value: Route.template(template.id)) {
                                            HStack {
                                                Text(template.name)
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundStyle(AppTheme.textPrimary)
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundStyle(AppTheme.textTertiary)
                                            }
                                            .padding(14)
                                        }
                                        .buttonStyle(.plain)

                                        if index < templateStore.templates.count - 1 {
                                            Divider()
                                                .overlay(AppTheme.fieldBorder)
                                                .padding(.horizontal, 14)
                                        }
                                    }
                                }
                                .background(AppTheme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                                )
                                .padding(.horizontal, 16)
                            }

                            Button {
                                do {
                                    let templateId = try templateStore.createTemplate(name: "New Template")
                                    newTemplateIds.insert(templateId)
                                    path.append(.template(templateId))
                                } catch {
                                    errorMessage = "Create Template failed: \(error)"
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus")
                                    Text("Create Template")
                                }
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(AppTheme.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(AppTheme.accent, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                                )
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                }
                .background(AppTheme.background)
                .navigationBarHidden(true)
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .template(let templateId):
                        WorkoutEditorView(
                            templateStore: templateStore,
                            workoutStore: workoutStore,
                            exerciseStore: exerciseStore,
                            subject: .template(id: templateId),
                            onFinish: { path.removeAll() },
                            restTimeSeconds: .constant(120),
                            isNewTemplate: newTemplateIds.contains(templateId)
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
        .sheet(isPresented: $showWeightLogSheet) {
            WeightLogSheet(
                bodyWeightStore: bodyWeightStore,
                weightText: $weightLogText,
                onDone: { showWeightLogSheet = false }
            )
            .presentationDetents([.height(220)])
        }
        .onAppear {
            resumePendingWorkoutIfNeeded()
            if let pr = try? workoutStore.fetchLatestPR() {
                latestPR = pr
                latestPRExerciseName = (try? workoutStore.fetchExerciseName(exerciseId: pr.exerciseId)) ?? ""
            }
            isPRDismissed = false
        }
        .onChange(of: workoutStore.latestPR) { _, newPR in
            if newPR != nil {
                isPRDismissed = false
                if let pr = try? workoutStore.fetchLatestPR() {
                    latestPR = pr
                    latestPRExerciseName = (try? workoutStore.fetchExerciseName(exerciseId: pr.exerciseId)) ?? ""
                }
            }
        }
    }

    private func prDetailText(_ pr: PersonalRecordRecord) -> String {
        let weightStr = String(format: "%.0f", pr.weight)
        var text = "\(weightStr) lbs × \(pr.reps) · Est. 1RM \(String(format: "%.0f", pr.estimated1RM)) lbs"
        if let improvement = pr.improvement {
            text += " (+\(String(format: "%.0f", improvement)) lbs)"
        }
        return text
    }

    private func resumePendingWorkoutIfNeeded() {
        guard activeWorkoutSheetItem == nil, collapsedActiveWorkoutId == nil else { return }
        if let pendingId = try? workoutStore.fetchPendingWorkoutID() {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                collapsedActiveWorkoutId = pendingId
            }
        }
    }
}

// MARK: - Body Weight Card

private struct BodyWeightCard: View {
    @ObservedObject var bodyWeightStore: BodyWeightStore
    @Binding var showLogSheet: Bool
    @Binding var weightLogText: String
    var fitnessGoal: FitnessGoal?

    private func weightTrendColor(change: Double) -> Color {
        guard let goal = fitnessGoal else {
            return AppTheme.textSecondary
        }
        switch goal {
        case .buildMuscle, .getStronger:
            if change > 0.3 { return AppTheme.accent }
            if change < -0.3 { return Color(hex: "#DC2626") }
            return Color(hex: "#F59E0B")

        case .loseWeight:
            if change < -0.3 { return AppTheme.accent }
            if change > 0.3 { return Color(hex: "#DC2626") }
            return Color(hex: "#F59E0B")

        case .maintain:
            if abs(change) <= 0.5 { return AppTheme.accent }
            return Color(hex: "#F59E0B")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("BODY WEIGHT")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .tracking(0.3)

                    if let latest = bodyWeightStore.latestEntry {
                        Text("\(latest.weight, specifier: "%.1f") lbs")
                            .font(.system(size: 26, weight: .heavy))
                            .foregroundStyle(AppTheme.textPrimary)

                        if let weeklyChange = bodyWeightStore.weeklyChange {
                            Text("\(weeklyChange > 0 ? "▲" : "▼") \(String(format: "%.1f", abs(weeklyChange))) lbs this week")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(weightTrendColor(change: weeklyChange))
                        } else if bodyWeightStore.recentEntries.count == 1 {
                            Text("Log more days to see trend")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    } else {
                        Text("No data")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                }

                Spacer()

                Button {
                    if let latest = bodyWeightStore.latestEntry {
                        let r = (latest.weight * 10).rounded() / 10
                        weightLogText = r == Double(Int(r)) ? String(Int(r)) : String(format: "%.1f", r)
                    } else {
                        weightLogText = ""
                    }
                    showLogSheet = true
                } label: {
                    Text("+ Log")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(AppTheme.accentLight)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            // Mini chart
            if !bodyWeightStore.last7DaysEntries.isEmpty {
                let entryCount = bodyWeightStore.last7DaysEntries.count
                BodyWeightChartView(entries: bodyWeightStore.last7DaysEntries)
                    .frame(height: entryCount == 1 ? 44 : 80)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Body Weight Chart

private struct BodyWeightChartView: View {
    let entries: [BodyWeightEntryRecord]

    private var minWeight: Double {
        let lowest = entries.map(\.weight).min() ?? 0
        let highest = entries.map(\.weight).max() ?? 0
        if lowest == highest { return lowest - 2 }
        return lowest - 1
    }
    private var maxWeight: Double {
        let lowest = entries.map(\.weight).min() ?? 0
        let highest = entries.map(\.weight).max() ?? 0
        if lowest == highest { return highest + 2 }
        return highest + 1
    }

    private func shortDay(_ dateStr: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: dateStr) else { return dateStr }
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Now" }
        let dayF = DateFormatter()
        dayF.dateFormat = "EEE"
        return dayF.string(from: date)
    }

    var body: some View {
        Chart {
            ForEach(entries, id: \.id) { entry in
                if entries.count > 1 {
                    AreaMark(
                        x: .value("Day", shortDay(entry.date)),
                        yStart: .value("Min", minWeight),
                        yEnd: .value("Weight", entry.weight)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.accent.opacity(0.15), AppTheme.accent.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Day", shortDay(entry.date)),
                        y: .value("Weight", entry.weight)
                    )
                    .foregroundStyle(AppTheme.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }

                PointMark(
                    x: .value("Day", shortDay(entry.date)),
                    y: .value("Weight", entry.weight)
                )
                .foregroundStyle(AppTheme.accent)
                .symbolSize(entry.id == entries.last?.id ? 48 : 24)
            }
        }
        .chartYScale(domain: minWeight...maxWeight)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisValueLabel()
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }
}

// MARK: - Weight Log Sheet

private struct WeightLogSheet: View {
    @ObservedObject var bodyWeightStore: BodyWeightStore
    @Binding var weightText: String
    let onDone: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Log Body Weight")
                    .font(.headline)

                HStack(spacing: 12) {
                    TextField("0.0", text: $weightText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 28, weight: .bold))
                        .multilineTextAlignment(.center)
                        .padding(12)
                        .background(AppTheme.fieldBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(AppTheme.fieldBorder, lineWidth: 1)
                        )
                        .focused($isFocused)

                    Text("lbs")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)

                    Button {
                        guard let weight = Double(weightText.replacingOccurrences(of: ",", with: ".")),
                              weight > 0 else { return }
                        try? bodyWeightStore.logWeight(weight)
                        onDone()
                    } label: {
                        Text("Log today")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(AppTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)

                Spacer()
            }
            .padding(.top, 24)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDone() }
                }
            }
        }
        .onAppear { isFocused = true }
    }
}

// MARK: - Collapsed workout bar (above tab bar; tap to expand sheet)
private struct CollapsedWorkoutBarView: View {
    let workoutId: String
    @ObservedObject var workoutStore: WorkoutStore
    let onTap: () -> Void

    @State private var workoutName: String = "Workout"

    var body: some View {
        HStack(spacing: 12) {
            Text(workoutName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 8)

            TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
                let now = timeline.date
                let matches = workoutStore.activeRestTimerWorkoutId == workoutId
                let end = workoutStore.activeRestTimerEndDate
                let remaining: Int = {
                    guard matches, let end else { return 0 }
                    return max(0, Int(ceil(end.timeIntervalSince(now))))
                }()
                let isLiveRestCountdown = matches && remaining > 0
                let displaySeconds = isLiveRestCountdown
                    ? remaining
                    : workoutStore.activeWorkoutRestPresetSeconds

                HStack(spacing: 6) {
                    Text("Rest")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    Text(displaySeconds.formattedAsMinutesSeconds)
                        .font(.system(size: 15, weight: .medium).monospacedDigit())
                        .foregroundStyle(isLiveRestCountdown ? AppTheme.accent : AppTheme.textPrimary)
                }
                .onChange(of: isLiveRestCountdown) { wasLive, isLive in
                    if wasLive && !isLive,
                       workoutStore.activeRestTimerWorkoutId == workoutId,
                       workoutStore.activeRestTimerEndDate != nil {
                        workoutStore.setActiveRestTimer(workoutId: workoutId, endDate: nil)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(AppTheme.cardBackground)
        .overlay(alignment: .top) {
            Rectangle().fill(AppTheme.cardBorder).frame(height: 1)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onAppear {
            if let workout = try? workoutStore.fetchWorkout(workoutId: workoutId) {
                workoutName = workout.name
            }
            if workoutStore.activeRestTimerWorkoutId == workoutId,
               let end = workoutStore.activeRestTimerEndDate,
               end <= Date() {
                workoutStore.setActiveRestTimer(workoutId: workoutId, endDate: nil)
            }
        }
    }
}

struct WorkoutView_Previews: PreviewProvider {
    static var previews: some View {
        let container = AppContainer()
        WorkoutView(
            templateStore: container.templateStore,
            workoutStore: container.workoutStore,
            exerciseStore: container.exerciseStore,
            authStore: container.authStore,
            bodyWeightStore: container.bodyWeightStore,
            onboardingStore: container.onboardingStore
        )
    }
}
