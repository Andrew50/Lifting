//
//  HistoryView.swift
//  Lifting
//
//  Created by Andrew Billings on 1/31/26.
//

import SwiftUI

struct HistoryView: View {
    @ObservedObject var historyStore: HistoryStore
    @ObservedObject var workoutStore: WorkoutStore
    @ObservedObject var templateStore: TemplateStore
    @ObservedObject var exerciseStore: ExerciseStore
    @ObservedObject var tabReselect: TabReselectCoordinator

    enum Route: Hashable {
        case workout(String)
    }

    @State private var path: [Route] = []

    private enum ScrollAnchor {
        static let top = "historyTop"
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollViewReader { proxy in
                Group {
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
                                    ProgressView()
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
                }
                .background(AppTheme.background)
                .navigationTitle("History")
                .onChange(of: tabReselect.historyReselectCount) { _, _ in
                    if !path.isEmpty {
                        path.removeAll()
                    } else {
                        withAnimation(.snappy) {
                            proxy.scrollTo(ScrollAnchor.top, anchor: .top)
                        }
                    }
                }
            }
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
        }
    }
}

struct WorkoutHistoryBubble: View {
    let workout: WorkoutSummary

    private var subtitleText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy · h:mm a"
        let dateStr = formatter.string(
            from: Date(timeIntervalSince1970: workout.completedAt)
        )
        if let duration = workout.duration, duration > 0 {
            let mins = Int(duration) / 60
            return "\(dateStr) · \(mins) min"
        }
        return dateStr
    }

    private func formatVolume(_ lbs: Double) -> String {
        if lbs >= 1000 {
            return String(format: "%.0fk lbs", lbs / 1000)
        }
        return String(format: "%.0f lbs", lbs)
    }

    var body: some View {
        HistoryBubble {
            HStack(alignment: .top) {
                HistoryBubbleHeader(
                    title: workout.name,
                    subtitle: subtitleText
                )
                Spacer()
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
                Text("\(workout.exercises.count) exercises")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.accentText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.accentLight)
                    .clipShape(Capsule())
                if workout.totalVolume > 0 {
                    Text(formatVolume(workout.totalVolume))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }

            HistoryDivider()

            HistoryWorkoutSummaryContent(exercises: workout.exercises)
        }
    }
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        let container = AppContainer()
        HistoryView(
            historyStore: container.historyStore,
            workoutStore: container.workoutStore,
            templateStore: container.templateStore,
            exerciseStore: container.exerciseStore,
            tabReselect: TabReselectCoordinator()
        )
    }
}
