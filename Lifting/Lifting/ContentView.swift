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
    @ObservedObject var tabNav: TabNavigationCoordinator

    private let preferredWorkoutTabIconName = "figure.strengthtraining.traditional"
    private let fallbackWorkoutTabIconName = "dumbbell"

    private let preferredProgressTabIconName = "chart.line.uptrend.xyaxis"
    private let fallbackProgressTabIconName = "chart.xyaxis.line"

    private let preferredExercisesTabIconName = "list.bullet"
    private let fallbackExercisesTabIconName = "list.bullet"

    private let preferredProfileTabIconName = "person.circle"
    private let fallbackProfileTabIconName = "person"

    @StateObject private var tabReselect = TabReselectCoordinator()

    private func resolvedIconName(preferred: String, fallback: String) -> String {
        #if canImport(UIKit)
            return UIImage(systemName: preferred) != nil ? preferred : fallback
        #else
            return fallback
        #endif
    }

    var body: some View {
        Group {
            if !container.onboardingStore.hasCompletedOnboarding {
                OnboardingView(store: container.onboardingStore, authStore: container.authStore) {
                }
                .transition(.opacity)
            } else {
                mainTabView
            }
        }
        .animation(.easeInOut(duration: 0.3), value: container.onboardingStore.hasCompletedOnboarding)
    }

    private var mainTabView: some View {
        TabView(selection: $tabNav.selectedTab) {
            WorkoutView(
                templateStore: container.templateStore,
                workoutStore: container.workoutStore,
                exerciseStore: container.exerciseStore,
                authStore: container.authStore,
                bodyWeightStore: container.bodyWeightStore,
                onboardingStore: container.onboardingStore,
                tabNav: tabNav
            )
            .tabItem {
                Label("Workout", systemImage: resolvedIconName(preferred: preferredWorkoutTabIconName, fallback: fallbackWorkoutTabIconName))
            }
            .tag(AppTab.workout)

            ProgressView(
                historyStore: container.historyStore,
                workoutStore: container.workoutStore,
                templateStore: container.templateStore,
                exerciseStore: container.exerciseStore,
                bodyWeightStore: container.bodyWeightStore,
                tabReselect: tabReselect,
                tabNav: tabNav
            )
            .tabItem {
                Label("Progress", systemImage: resolvedIconName(preferred: preferredProgressTabIconName, fallback: fallbackProgressTabIconName))
            }
            .tag(AppTab.progress)

            NavigationStack {
                ExerciseListView(container: container)
            }
            .tabItem {
                Label("Exercises", systemImage: resolvedIconName(preferred: preferredExercisesTabIconName, fallback: fallbackExercisesTabIconName))
            }
            .tag(AppTab.exercises)

            NavigationStack {
                ProfileView(container: container, authStore: container.authStore, onboardingStore: container.onboardingStore)
            }
            .tabItem {
                Label("Profile", systemImage: resolvedIconName(preferred: preferredProfileTabIconName, fallback: fallbackProfileTabIconName))
            }
            .tag(AppTab.profile)
        }
        .tint(AppTheme.accent)
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
        let container = AppContainer()
        return ContentView(container: container, tabNav: container.tabNavigationCoordinator)
    }
}
