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
                        restTimeSeconds: .constant(120)
                    )
                }
            }
        }
    }
}

struct WorkoutHistoryBubble: View {
    let workout: WorkoutSummary

    var body: some View {
        HistoryBubble {
            HStack(alignment: .top) {
                HistoryBubbleHeader(
                    title: workout.name,
                    subtitle:
                        "\(workout.completedAt.formatted(.dateTime.month(.defaultDigits).day(.defaultDigits).year(.twoDigits))) \(workout.duration.formattedDuration)"
                )
                Spacer()
                Text("\(workout.exercises.count) exercises")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.accentText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.accentLight)
                    .clipShape(Capsule())
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
