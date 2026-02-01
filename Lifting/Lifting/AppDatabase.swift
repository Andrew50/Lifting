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

                let id = Self.stableID(for: name)
                try db.execute(
                    sql: """
                    INSERT OR IGNORE INTO exercises (id, name)
                    VALUES (?, ?)
                    """,
                    arguments: [id, name]
                )
            }
        }
    }

    /// Stable identifier so re-seeding does not break foreign keys.
    static func stableID(for exerciseName: String) -> String {
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

