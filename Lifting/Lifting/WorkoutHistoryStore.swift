//
//  WorkoutHistoryStore.swift
//  Lifting
//
//  Created by Andrew Billings on 1/31/26.
//

import Combine
import Foundation

@MainActor
final class WorkoutHistoryStore: ObservableObject {
    @Published var workouts: [WorkoutHistoryItem]

    init(workouts: [WorkoutHistoryItem] = WorkoutHistoryStore.makeMockWorkouts()) {
        self.workouts = workouts.sorted { $0.date > $1.date }
    }

    nonisolated private static func makeMockWorkouts() -> [WorkoutHistoryItem] {
        let calendar = Calendar.current
        let now = Date()

        func daysAgo(_ days: Int) -> Date {
            calendar.date(byAdding: .day, value: -days, to: now) ?? now
        }

        return [
            WorkoutHistoryItem(name: "Push Day", date: daysAgo(0)),
            WorkoutHistoryItem(name: "Pull Day", date: daysAgo(2)),
            WorkoutHistoryItem(name: "Leg Day", date: daysAgo(4)),
            WorkoutHistoryItem(name: "Upper Body", date: daysAgo(7)),
            WorkoutHistoryItem(name: "Full Body", date: daysAgo(10)),
        ]
    }
}

