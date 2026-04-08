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
        case profile
    }

    private let preferredWorkoutTabIconName = "figure.strengthtraining.traditional"
    private let fallbackWorkoutTabIconName = "dumbbell"

    private let preferredHistoryTabIconName = "clock.arrow.circlepath"
    private let fallbackHistoryTabIconName = "clock"

    private let preferredExercisesTabIconName = "list.bullet"
    private let fallbackExercisesTabIconName = "list.bullet"

    private let preferredProfileTabIconName = "person.circle"
    private let fallbackProfileTabIconName = "person"

    @State private var selectedTab: AppTab = .workout
    @StateObject private var tabReselect = TabReselectCoordinator()

    private func resolvedIconName(preferred: String, fallback: String) -> String {
        #if canImport(UIKit)
            return UIImage(systemName: preferred) != nil ? preferred : fallback
        #else
            return fallback
        #endif
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            WorkoutView(
                templateStore: container.templateStore,
                workoutStore: container.workoutStore,
                exerciseStore: container.exerciseStore,
                authStore: container.authStore
            )
            .tabItem {
                Label("Workout", systemImage: resolvedIconName(preferred: preferredWorkoutTabIconName, fallback: fallbackWorkoutTabIconName))
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
                Label("History", systemImage: resolvedIconName(preferred: preferredHistoryTabIconName, fallback: fallbackHistoryTabIconName))
            }
            .tag(AppTab.history)

            NavigationStack {
                ExerciseListView(container: container)
            }
            .tabItem {
                Label("Exercises", systemImage: resolvedIconName(preferred: preferredExercisesTabIconName, fallback: fallbackExercisesTabIconName))
            }
            .tag(AppTab.exercises)

            NavigationStack {
                ProfileView(container: container, authStore: container.authStore)
            }
            .tabItem {
                Label("Profile", systemImage: resolvedIconName(preferred: preferredProfileTabIconName, fallback: fallbackProfileTabIconName))
            }
            .tag(AppTab.profile)
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
