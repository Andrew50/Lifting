//
//  KeyLifts.swift
//  Lifting
//
//  Exercise `id` values match the `name` column in `exercises` (seeded from strong.json).
//

import Foundation

struct KeyLiftDefinition: Identifiable, Hashable {
    let id: String
    let displayName: String
    let isPrimary: Bool
}

enum KeyLifts {
    /// Primary lifts — always shown on Strength segment, even if empty
    static let primary: [KeyLiftDefinition] = [
        KeyLiftDefinition(id: "Bench Press (Barbell)", displayName: "Bench", isPrimary: true),
        KeyLiftDefinition(id: "Squat (Barbell)", displayName: "Squat", isPrimary: true),
        KeyLiftDefinition(id: "Deadlift (Barbell)", displayName: "Deadlift", isPrimary: true),
        KeyLiftDefinition(id: "Overhead Press (Barbell)", displayName: "OHP", isPrimary: true),
    ]

    /// Secondary lifts — only shown if user has logged sets for them
    static let secondary: [KeyLiftDefinition] = [
        KeyLiftDefinition(id: "Incline Bench Press (Barbell)", displayName: "Incline Bench", isPrimary: false),
        KeyLiftDefinition(id: "Front Squat (Barbell)", displayName: "Front Squat", isPrimary: false),
        KeyLiftDefinition(id: "Romanian Deadlift (Barbell)", displayName: "RDL", isPrimary: false),
        KeyLiftDefinition(id: "Bent Over Row (Barbell)", displayName: "Barbell Row", isPrimary: false),
        KeyLiftDefinition(id: "Pull Up", displayName: "Pull-up", isPrimary: false),
        KeyLiftDefinition(id: "Chest Dip", displayName: "Dip", isPrimary: false),
    ]

    static var all: [KeyLiftDefinition] { primary + secondary }
}

struct KeyLiftCardData: Identifiable {
    let id: String
    let displayName: String
    let exerciseName: String
    let currentOneRM: Double?
    let previousOneRM: Double?
    let lastTrainedAt: TimeInterval?

    var change: Double? {
        guard let current = currentOneRM, let previous = previousOneRM else { return nil }
        return current - previous
    }

    var hasData: Bool { currentOneRM != nil }
}

struct PRFeedItem: Identifiable {
    let id: String
    let exerciseName: String
    let weight: Double
    let reps: Int
    let estimatedOneRM: Double
    let achievedAt: TimeInterval
}
