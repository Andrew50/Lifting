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
                ScrollView {
                    LazyVStack(spacing: 16) {
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
                    .padding()
                }
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
            HistoryBubbleHeader(
                title: workout.name,
                subtitle: "\(workout.completedAt.formatted(.dateTime.month(.defaultDigits).day(.defaultDigits).year(.twoDigits))) \(workout.duration.formattedDuration)"
            )

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

