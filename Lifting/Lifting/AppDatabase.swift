//
//  AppDatabase.swift
//  Lifting
//
//  Created by Andrew Billings on 1/31/26.
//

import CryptoKit
import Foundation
import GRDB

final class AppDatabase {
    let dbQueue: DatabaseQueue

    init() throws {
        let dbURL = try Self.databaseURL()

        var config = Configuration()
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }

        dbQueue = try DatabaseQueue(path: dbURL.path, configuration: config)
        try DatabaseMigrations.migrator.migrate(dbQueue)

        try seedExercisesFromStrongJSONIfNeeded()
    }

    /// Test/support initializer.
    init(dbQueue: DatabaseQueue, seedExercises: Bool) throws {
        self.dbQueue = dbQueue
        try DatabaseMigrations.migrator.migrate(dbQueue)
        if seedExercises {
            try seedExercisesFromStrongJSONIfNeeded()
        }
    }

    private static func databaseURL() throws -> URL {
        let documentsURL = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return documentsURL.appendingPathComponent("lifting.sqlite")
    }

    private func seedExercisesFromStrongJSONIfNeeded() throws {
        let strong = try StrongJSON.loadFromBundle()

        try dbQueue.write { db in
            for exercise in strong.exercises {
                let name = exercise.exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { continue }
                let category = ExerciseCategoryInference.categorize(name: name)

                let id = Self.stableID(for: name)
                try db.execute(
                    sql: """
                    INSERT INTO exercises (id, name, equipment, muscle_group)
                    VALUES (?, ?, ?, ?)
                    ON CONFLICT(id) DO UPDATE SET
                        name = excluded.name,
                        equipment = excluded.equipment,
                        muscle_group = excluded.muscle_group
                    """,
                    arguments: [id, name, category.equipment.rawValue, category.muscleGroup.rawValue]
                )
            }
        }
    }

    /// Stable identifier so re-seeding does not break foreign keys.
    nonisolated static func stableID(for exerciseName: String) -> String {
        let digest = SHA256.hash(data: Data(exerciseName.utf8))
        var bytes = Array(digest.prefix(16))

        // Set UUID version (5) and variant bits to produce a valid UUID string.
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80

        let uuid = UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5],
            bytes[6], bytes[7],
            bytes[8], bytes[9],
            bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
        return uuid.uuidString
    }
}

private enum ExerciseEquipment: String {
    case dumbbell
    case machine
    case barbell
}

private enum MuscleGroup: String {
    case chest
    case shoulder
    case back
    case legs
    case abs
    case arms
}

private struct ExerciseCategory {
    let equipment: ExerciseEquipment
    let muscleGroup: MuscleGroup
}

private enum ExerciseCategoryInference {
    static func categorize(name: String) -> ExerciseCategory {
        let normalized = normalize(name)
        return ExerciseCategory(
            equipment: inferEquipment(from: normalized),
            muscleGroup: inferMuscleGroup(from: normalized)
        )
    }

    private static func inferEquipment(from name: String) -> ExerciseEquipment {
        if containsAny(name, ["dumbbell", "dumbell", " db "]) {
            return .dumbbell
        }
        if containsAny(name, ["barbell", " barbel", "smith machine", "trap bar", "hex bar"]) {
            return .barbell
        }
        return .machine
    }

    private static func inferMuscleGroup(from name: String) -> MuscleGroup {
        if containsAny(name, ["curl", "tricep", "triceps", "bicep", "biceps", "dip", "skullcrusher", "wrist"]) {
            return .arms
        }
        if containsAny(name, ["squat", "deadlift", "rdl", "leg", "lunge", "calf", "glute", "hip", "ham", "adductor", "abductor"]) {
            return .legs
        }
        if containsAny(name, ["crunch", "plank", "sit up", "sit-up", "knee raise", "leg raise", "v up", "twist", "abs", "ab "]) {
            return .abs
        }
        if containsAny(name, ["bench", "chest", "pec", "crossover", "fly", "push up", "push-up", "press"]) {
            return .chest
        }
        if containsAny(name, ["shoulder", "lateral raise", "front raise", "upright row", "overhead press", "full can"]) {
            return .shoulder
        }
        return .back
    }

    private static func normalize(_ input: String) -> String {
        " " + input
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "-", with: " ") + " "
    }

    private static func containsAny(_ input: String, _ tokens: [String]) -> Bool {
        tokens.contains { input.contains($0) }
    }
}

private struct StrongJSON: Decodable {
    struct ExerciseEntry: Decodable {
        let exerciseName: String

        private enum CodingKeys: String, CodingKey {
            case exerciseName = "Exercise Name"
        }
    }

    let version: String
    let exercises: [ExerciseEntry]

    static func loadFromBundle() throws -> StrongJSON {
        guard let url = Bundle.main.url(forResource: "strong", withExtension: "json") else {
            throw NSError(
                domain: "Lifting.StrongJSON",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Missing strong.json in app bundle."]
            )
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(StrongJSON.self, from: data)
    }
}

