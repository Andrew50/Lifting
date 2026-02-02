//
//  ContentView.swift
//  Lifting
//
//  Created by Andrew Billings on 1/31/26.
//

import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

struct ContentView: View {
    @ObservedObject var container: AppContainer

    private enum AppTab: Hashable {
        case workout
        case history
        case exercises
    }

    private let preferredWorkoutTabIconName = "figure.strengthtraining.traditional"
    private let fallbackWorkoutTabIconName = "dumbbell"

    private let preferredHistoryTabIconName = "clock.arrow.circlepath"
    private let fallbackHistoryTabIconName = "clock"

    private let preferredExercisesTabIconName = "list.bullet"
    private let fallbackExercisesTabIconName = "list.bullet"

    @State private var selectedTab: AppTab = .workout
    @StateObject private var tabReselect = TabReselectCoordinator()

    private var workoutTabIconName: String {
        #if canImport(UIKit)
            if UIImage(systemName: preferredWorkoutTabIconName) != nil {
                return preferredWorkoutTabIconName
            }
            return fallbackWorkoutTabIconName
        #else
            return fallbackWorkoutTabIconName
        #endif
    }

    private var historyTabIconName: String {
        #if canImport(UIKit)
            if UIImage(systemName: preferredHistoryTabIconName) != nil {
                return preferredHistoryTabIconName
            }
            return fallbackHistoryTabIconName
        #else
            return fallbackHistoryTabIconName
        #endif
    }

    private var exercisesTabIconName: String {
        #if canImport(UIKit)
            if UIImage(systemName: preferredExercisesTabIconName) != nil {
                return preferredExercisesTabIconName
            }
            return fallbackExercisesTabIconName
        #else
            return fallbackExercisesTabIconName
        #endif
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            WorkoutView(
                templateStore: container.templateStore,
                workoutStore: container.workoutStore,
                exerciseStore: container.exerciseStore
            )
            .tabItem {
                Label("Workout", systemImage: workoutTabIconName)
            }
            .tag(AppTab.workout)

            HistoryView(
                historyStore: container.historyStore,
                workoutStore: container.workoutStore,
                templateStore: container.templateStore,
                exerciseStore: container.exerciseStore,
                tabReselect: tabReselect
            )
            .tabItem {
                Label("History", systemImage: historyTabIconName)
            }
            .tag(AppTab.history)

            NavigationStack {
                ExerciseListView(container: container)
            }
            .tabItem {
                Label("Exercises", systemImage: exercisesTabIconName)
            }
            .tag(AppTab.exercises)
        }
        .background {
            #if canImport(UIKit)
                TabBarReselectObserver(coordinator: tabReselect, historyIndex: 1)
                    .frame(width: 0, height: 0)
                    .allowsHitTesting(false)
            #endif
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(container: AppContainer())
    }
}
