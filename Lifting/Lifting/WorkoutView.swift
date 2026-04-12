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
    @State private var stats: WorkoutStats = WorkoutStats(streak: 0, thisWeekCount: 0, weeklyVolume: 0)
    @State private var showWeightLogSheet: Bool = false
    @State private var weightLogText: String = ""

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

    private func loadStats() {
        stats = (try? workoutStore.fetchWorkoutStats()) ?? WorkoutStats(streak: 0, thisWeekCount: 0, weeklyVolume: 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            NavigationStack(path: $path) {
                ScrollView {
                    VStack(spacing: 16) {
                        // Header
                        VStack(alignment: .leading, spacing: 2) {
                            Text(greetingTitle)
                                .font(.system(size: 28, weight: .heavy))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(dateSubtitle)
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                        // Stat cards
                        HStack(spacing: 10) {
                            StatCard(label: "STREAK", value: "\(stats.streak)", unit: "days")
                            StatCard(label: "THIS WEEK", value: "\(stats.thisWeekCount)", unit: "workouts")
                            StatCard(label: "VOLUME", value: formatVolume(stats.weeklyVolume), unit: "lbs lifted")
                        }
                        .padding(.horizontal, 16)

                        // Body Weight card
                        BodyWeightCard(
                            bodyWeightStore: bodyWeightStore,
                            showLogSheet: $showWeightLogSheet,
                            weightLogText: $weightLogText
                        )
                        .padding(.horizontal, 16)

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
                    loadStats()
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
            loadStats()
        }
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

// MARK: - Stat Card

private struct StatCard: View {
    let label: String
    let value: String
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .tracking(0.3)
            Text(value)
                .font(.system(size: 24, weight: .heavy))
                .foregroundStyle(AppTheme.textPrimary)
            Text(unit)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Body Weight Card

private struct BodyWeightCard: View {
    @ObservedObject var bodyWeightStore: BodyWeightStore
    @Binding var showLogSheet: Bool
    @Binding var weightLogText: String

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

                        if let change = bodyWeightStore.weeklyChange {
                            HStack(spacing: 3) {
                                Image(systemName: change < 0 ? "arrowtriangle.down.fill" : "arrowtriangle.up.fill")
                                    .font(.system(size: 9))
                                Text("\(abs(change), specifier: "%.1f") lbs this week")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundStyle(change < 0 ? AppTheme.accent : Color(hex: "#DC2626"))
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
            if bodyWeightStore.last7DaysEntries.count >= 2 {
                BodyWeightChartView(entries: bodyWeightStore.last7DaysEntries)
                    .frame(height: 80)
            }
        }
        .padding(14)
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
        (entries.map(\.weight).min() ?? 0) - 1
    }
    private var maxWeight: Double {
        (entries.map(\.weight).max() ?? 0) + 1
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

                if entry.id == entries.last?.id {
                    PointMark(
                        x: .value("Day", shortDay(entry.date)),
                        y: .value("Weight", entry.weight)
                    )
                    .foregroundStyle(AppTheme.accent)
                    .symbolSize(36)
                }
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
    @State private var workoutStartedAt: TimeInterval?

    var body: some View {
        HStack(spacing: 12) {
            Text(workoutName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 8)

            TimelineView(.periodic(from: .now, by: 1.0)) { _ in
                Text(TimeInterval.elapsed(since: workoutStartedAt))
                    .font(.system(size: 15, weight: .medium).monospacedDigit())
                    .foregroundStyle(AppTheme.accent)
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
                workoutStartedAt = workout.startedAt
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
            bodyWeightStore: container.bodyWeightStore
        )
    }
}
