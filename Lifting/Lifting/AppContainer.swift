//
//  AppContainer.swift
//  Lifting
//
//  Created by Andrew Billings on 1/31/26.
//

import Combine
import Foundation

@MainActor
final class AppContainer: ObservableObject {
    let db: AppDatabase

    let templateStore: TemplateStore
    let workoutStore: WorkoutStore
    let historyStore: HistoryStore
    let exerciseStore: ExerciseStore
    let authStore: AuthStore
    let csvImporter: CSVImporter
    let bodyWeightStore: BodyWeightStore
    let onboardingStore: OnboardingStore
    let tabNavigationCoordinator = TabNavigationCoordinator()

    private var cancellables = Set<AnyCancellable>()

    init() {
        do {
            db = try AppDatabase()
        } catch {
            fatalError("Failed to initialize database: \(error)")
        }

        templateStore = TemplateStore(db: db)
        workoutStore = WorkoutStore(db: db)
        historyStore = HistoryStore(db: db)
        exerciseStore = ExerciseStore(db: db)
        authStore = AuthStore(db: db)
        csvImporter = CSVImporter(db: db)
        bodyWeightStore = BodyWeightStore(db: db)
        onboardingStore = OnboardingStore()

        // Nested stores are not @Published on this type; forward their changes so
        // views using @ObservedObject AppContainer (e.g. ContentView) refresh when
        // onboarding or auth state changes.
        onboardingStore.objectWillChange
            .sink { [weak self] (_: Void) in self?.objectWillChange.send() }
            .store(in: &cancellables)
        authStore.objectWillChange
            .sink { [weak self] (_: Void) in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }
}
