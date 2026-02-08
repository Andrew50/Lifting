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
    }
}

