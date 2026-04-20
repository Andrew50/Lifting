//
//  ProgressView.swift
//  Lifting
//
//  Created by Andrew Billings on 1/31/26.
//

import SwiftUI

enum ProgressSegment: String, CaseIterable {
    case workouts = "Workouts"
    case bodyWeight = "Body Weight"
    case strength = "Strength"
}

struct ProgressView: View {
    @ObservedObject var historyStore: HistoryStore
    @ObservedObject var workoutStore: WorkoutStore
    @ObservedObject var templateStore: TemplateStore
    @ObservedObject var exerciseStore: ExerciseStore
    @ObservedObject var bodyWeightStore: BodyWeightStore
    @ObservedObject var tabReselect: TabReselectCoordinator
    @ObservedObject var tabNav: TabNavigationCoordinator

    @State private var selectedSegment: ProgressSegment = .workouts

    enum Route: Hashable {
        case workout(String)
    }

    @State private var path: [Route] = []

    private enum ScrollAnchor {
        static let top = "progressTop"
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Progress")
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                Picker("Segment", selection: $selectedSegment) {
                    ForEach(ProgressSegment.allCases, id: \.self) { segment in
                        Text(segment.rawValue).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)

                ScrollViewReader { proxy in
                    Group {
                        switch selectedSegment {
                        case .workouts:
                            if historyStore.workouts.isEmpty {
                                VStack(spacing: 12) {
                                    Spacer()
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.system(size: 44))
                                        .foregroundStyle(AppTheme.textTertiary)
                                    Text("No workouts yet")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(AppTheme.textSecondary)
                                    Text("Complete a workout to see it here")
                                        .font(.system(size: 14))
                                        .foregroundStyle(AppTheme.textTertiary)
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity)
                            } else {
                                ScrollView {
                                    LazyVStack(spacing: 10) {
                                        Color.clear
                                            .frame(height: 1)
                                            .id(ScrollAnchor.top)
                                            .accessibilityHidden(true)

                                        ForEach(historyStore.workouts) { workout in
                                            NavigationLink(value: Route.workout(workout.id)) {
                                                WorkoutHistoryBubble(workout: workout)
                                            }
                                            .buttonStyle(.plain)
                                        }

                                        if historyStore.canLoadMore {
                                            SwiftUI.ProgressView()
                                                .padding()
                                                .onAppear {
                                                    historyStore.loadMore()
                                                }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                }
                            }

                        case .bodyWeight:
                            BodyWeightProgressView(bodyWeightStore: bodyWeightStore)

                        case .strength:
                            VStack {
                                Spacer()
                                Text("Coming soon")
                                    .foregroundStyle(AppTheme.textTertiary)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .background(AppTheme.background)
                    .onChange(of: tabReselect.historyReselectCount) { _, _ in
                        if !path.isEmpty {
                            path.removeAll()
                        } else if selectedSegment == .workouts {
                            withAnimation(.snappy) {
                                proxy.scrollTo(ScrollAnchor.top, anchor: .top)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationBarHidden(true)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .workout(let workoutId):
                    WorkoutEditorView(
                        templateStore: templateStore,
                        workoutStore: workoutStore,
                        exerciseStore: exerciseStore,
                        subject: .workout(id: workoutId),
                        onFinish: { path.removeAll() },
                        restTimeSeconds: .constant(120),
                        isReadOnly: true
                    )
                }
            }
            .onChange(of: tabNav.pendingProgressSegment) { _, newSegment in
                if let segment = newSegment {
                    selectedSegment = segment
                    tabNav.clearPendingSegment()
                }
            }
            .onAppear {
                if let segment = tabNav.pendingProgressSegment {
                    selectedSegment = segment
                    tabNav.clearPendingSegment()
                }
            }
        }
    }
}

struct WorkoutHistoryBubble: View {
    let workout: WorkoutSummary

    private var displayVolumeUnit: String {
        DisplayPreferences.displayWeightUnit(for: workout.exercises.first?.exerciseId ?? "")
    }

    private static let historyTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    private static func formatCompletedSubtitle(_ completedAt: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: completedAt)
        let calendar = Calendar.current
        let now = Date()
        let time = Self.historyTimeFormatter.string(from: date)

        if calendar.isDateInToday(date) {
            return "Today · \(time)"
        }
        if calendar.isDateInYesterday(date) {
            return "Yesterday · \(time)"
        }

        let yNow = calendar.component(.year, from: now)
        let yDate = calendar.component(.year, from: date)
        if yNow == yDate {
            let f = DateFormatter()
            f.dateFormat = "EEEE, MMM d · h:mm a"
            return f.string(from: date)
        }

        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String? {
        guard seconds > 0 else { return nil }
        let rounded = Int(seconds.rounded(.toNearestOrAwayFromZero))
        guard rounded > 0 else { return nil }

        let hours = rounded / 3600
        let minutes = (rounded % 3600) / 60
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
        if minutes > 0 {
            return "\(minutes) min"
        }
        return "\(rounded)s"
    }

    private func formatVolumeForDisplay(lbs: Double) -> String? {
        guard lbs > 0 else { return nil }
        let unit = displayVolumeUnit
        let value = unit == "kg" ? lbs / 2.20462 : lbs
        let suffix = unit == "kg" ? " kg" : " lbs"
        if value >= 10_000 {
            return String(format: "%.1fk", value / 1000) + suffix
        }
        if value >= 1000 {
            let rounded = (value / 1000)
            let str = rounded == Double(Int(rounded)) ? String(Int(rounded)) : String(format: "%.1f", rounded)
            return str + "k" + suffix
        }
        let str = value == Double(Int(value)) ? String(Int(value)) : String(format: "%.0f", value)
        return str + suffix
    }

    private var durationVolumeLine: String? {
        let d = workout.duration.flatMap { formatDuration($0) }
        let v = formatVolumeForDisplay(lbs: workout.totalVolume)
        switch (d, v) {
        case let (dur?, vol?):
            return "\(dur) · \(vol)"
        case let (dur?, nil):
            return dur
        case let (nil, vol?):
            return vol
        case (nil, nil):
            return nil
        }
    }

    var body: some View {
        HistoryBubble {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text(Self.formatCompletedSubtitle(workout.completedAt))
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textSecondary)

                    if let line = durationVolumeLine {
                        Text(line)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 8) {
                    if workout.hasPR {
                        HStack(spacing: 4) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 10))
                            Text("PR")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(Color(hex: "#D97706"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: "#FEF3C7"))
                        .clipShape(Capsule())
                    }

                    Text("\(workout.exercises.count) \(workout.exercises.count == 1 ? "exercise" : "exercises")")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.accentText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.accentLight)
                        .clipShape(Capsule())
                }
            }

            HistoryDivider()

            HistoryWorkoutSummaryContent(exercises: workout.exercises)
        }
    }
}

struct ProgressView_Previews: PreviewProvider {
    static var previews: some View {
        let container = AppContainer()
        ProgressView(
            historyStore: container.historyStore,
            workoutStore: container.workoutStore,
            templateStore: container.templateStore,
            exerciseStore: container.exerciseStore,
            bodyWeightStore: container.bodyWeightStore,
            tabReselect: TabReselectCoordinator(),
            tabNav: container.tabNavigationCoordinator
        )
    }
}
