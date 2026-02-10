//
//  CSVImporter.swift
//  Lifting
//
//  Imports Strong-style CSV exports into the GRDB database.
//

import Foundation
import GRDB

final class CSVImporter {
    struct ImportResult: Sendable {
        var workoutsInserted: Int
        var workoutExercisesInserted: Int
        var setsInserted: Int
        var exercisesInsertedOrIgnored: Int
        var skippedBecauseAlreadyImported: Bool
    }

    enum ImportError: LocalizedError {
        case csvNotFound
        case invalidHeader(expected: [String], actual: [String])
        case invalidRow(columnCount: Int, rowPreview: String)
        case invalidDate(String)

        var errorDescription: String? {
            switch self {
            case .csvNotFound:
                return "Could not find the CSV file to import."
            case let .invalidHeader(expected, actual):
                let expectedStr = expected.joined(separator: ", ")
                let actualStr = actual.joined(separator: ", ")
                return "CSV header mismatch. Expected \(expectedStr), got \(actualStr)."
            case let .invalidRow(columnCount, rowPreview):
                return "Invalid CSV row (expected 12 columns, got \(columnCount)). Row: \(rowPreview)"
            case let .invalidDate(value):
                return "Could not parse Date field: \(value)"
            }
        }
    }

    private let dbQueue: DatabaseQueue
    private let importedDefaultsKey = "CSVImporter.didImportWorkouts"

    init(db: AppDatabase) {
        self.dbQueue = db.dbQueue
    }

    /// Imports a specific CSV file.
    func importCSV(at url: URL) async throws -> ImportResult {
        // Heavy work off the main actor.
        let result: ImportResult = try await Task.detached(priority: .userInitiated) { [dbQueue] in
            try Self.importCSV(at: url, dbQueue: dbQueue)
        }.value

        // Mark success so we don't duplicate-import automatically later.
        UserDefaults.standard.set(true, forKey: importedDefaultsKey)
        return result
    }

    nonisolated private static func importCSV(at url: URL, dbQueue: DatabaseQueue) throws -> ImportResult {
        let data = try Data(contentsOf: url)
        let contents = String(decoding: data, as: UTF8.self)

        var rows = parseCSV(contents)
        guard !rows.isEmpty else {
            // Nothing to import.
            return ImportResult(
                workoutsInserted: 0,
                workoutExercisesInserted: 0,
                setsInserted: 0,
                exercisesInsertedOrIgnored: 0,
                skippedBecauseAlreadyImported: false
            )
        }

        let expectedHeader = [
            "Date",
            "Workout Name",
            "Duration",
            "Exercise Name",
            "Set Order",
            "Weight",
            "Reps",
            "Distance",
            "Seconds",
            "Notes",
            "Workout Notes",
            "RPE",
        ]

        let header = rows.removeFirst()
        if header != expectedHeader {
            throw ImportError.invalidHeader(expected: expectedHeader, actual: header)
        }

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = .current
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"

        var workoutsInserted = 0
        var workoutExercisesInserted = 0
        var setsInserted = 0
        var exercisesInsertedOrIgnored = 0

        struct WorkoutCache {
            var workoutId: String
            var exerciseNameToWorkoutExerciseId: [String: String]
            var lastSetIdPerExercise: [String: String]
            var nextSetSortOrderPerExercise: [String: Int]
            var nextExerciseSortOrder: Int
            var hasNotes: Bool
        }

        var workoutCacheByKey: [String: WorkoutCache] = [:]
        var uniqueExercisesInFile = Set<String>()

        try dbQueue.write { db in
            for row in rows {
                if row.count != 12 {
                    let preview = row.joined(separator: ",").prefix(200)
                    throw ImportError.invalidRow(columnCount: row.count, rowPreview: String(preview))
                }

                let dateStr = row[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let workoutName = row[1].trimmingCharacters(in: .whitespacesAndNewlines)
                let durationStr = row[2].trimmingCharacters(in: .whitespacesAndNewlines)
                let exerciseName = row[3].trimmingCharacters(in: .whitespacesAndNewlines)

                let setOrderRaw = row[4].trimmingCharacters(in: .whitespacesAndNewlines)
                let weightRaw = row[5].trimmingCharacters(in: .whitespacesAndNewlines)
                let repsRaw = row[6].trimmingCharacters(in: .whitespacesAndNewlines)
                let distanceRaw = row[7].trimmingCharacters(in: .whitespacesAndNewlines)
                let secondsRaw = row[8].trimmingCharacters(in: .whitespacesAndNewlines)
                let setNotesRaw = row[9].trimmingCharacters(in: .whitespacesAndNewlines)
                let workoutNotesRaw = row[10].trimmingCharacters(in: .whitespacesAndNewlines)
                let rpeRaw = row[11].trimmingCharacters(in: .whitespacesAndNewlines)

                guard let date = df.date(from: dateStr) else {
                    throw ImportError.invalidDate(dateStr)
                }
                let startedAt = date.timeIntervalSince1970
                let durationSeconds = parseDurationSeconds(durationStr)
                let completedAt = startedAt + (durationSeconds ?? 0)

                let workoutKey = "\(dateStr)|\(workoutName)"

                // Ensure workout exists (completed).
                if workoutCacheByKey[workoutKey] == nil {
                    let nowish = completedAt > 0 ? completedAt : startedAt
                    let workout = WorkoutRecord(
                        id: UUID().uuidString,
                        name: workoutName.isEmpty ? WorkoutStore.defaultWorkoutName(for: date) : workoutName,
                        status: .completed,
                        sourceTemplateId: nil,
                        startedAt: startedAt,
                        completedAt: (durationSeconds == nil ? startedAt : completedAt),
                        notes: workoutNotesRaw.nilIfEmpty,
                        createdAt: nowish,
                        updatedAt: nowish
                    )
                    try workout.insert(db)
                    workoutsInserted += 1

                    workoutCacheByKey[workoutKey] = WorkoutCache(
                        workoutId: workout.id,
                        exerciseNameToWorkoutExerciseId: [:],
                        lastSetIdPerExercise: [:],
                        nextSetSortOrderPerExercise: [:],
                        nextExerciseSortOrder: 0,
                        hasNotes: workout.notes != nil
                    )
                } else if let existing = workoutCacheByKey[workoutKey],
                          !existing.hasNotes,
                          let workoutNotes = workoutNotesRaw.nilIfEmpty {
                    // If we created the workout from a row that didn't include notes, backfill once.
                    try db.execute(
                        sql: "UPDATE workouts SET notes = ?, updated_at = ? WHERE id = ?",
                        arguments: [workoutNotes, completedAt, existing.workoutId]
                    )
                    workoutCacheByKey[workoutKey]?.hasNotes = true
                }

                guard var cache = workoutCacheByKey[workoutKey] else { continue }

                // Ensure exercise exists.
                let cleanExerciseName = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleanExerciseName.isEmpty {
                    uniqueExercisesInFile.insert(cleanExerciseName)
                    
                    let exerciseId = AppDatabase.stableID(for: cleanExerciseName)
                    try db.execute(
                        sql: "INSERT OR IGNORE INTO exercises (id, name) VALUES (?, ?)",
                        arguments: [exerciseId, cleanExerciseName]
                    )

                    // Ensure workout_exercise exists for this workout/exerciseName.
                    let workoutExerciseId: String
                    if let existingWE = cache.exerciseNameToWorkoutExerciseId[cleanExerciseName] {
                        workoutExerciseId = existingWE
                    } else {
                        let we = WorkoutExerciseRecord(
                            id: UUID().uuidString,
                            workoutId: cache.workoutId,
                            exerciseId: exerciseId,
                            sortOrder: cache.nextExerciseSortOrder
                        )
                        try we.insert(db)
                        workoutExercisesInserted += 1
                        cache.exerciseNameToWorkoutExerciseId[cleanExerciseName] = we.id
                        cache.nextExerciseSortOrder += 1
                        workoutExerciseId = we.id
                    }

                    if setOrderRaw == "Rest Timer" {
                        // Attach rest timer to the previous set of this exercise
                        if let lastSetId = cache.lastSetIdPerExercise[cleanExerciseName] {
                            let restSeconds = Int(parseDurationSeconds(secondsRaw + "s") ?? 0)
                            if restSeconds > 0 {
                                try db.execute(
                                    sql: "UPDATE workout_sets SET rest_timer_seconds = ? WHERE id = ?",
                                    arguments: [restSeconds, lastSetId]
                                )
                            }
                        }
                    } else {
                        // Insert set.
                        let isWarmUp = setOrderRaw.uppercased() == "W"
                        let isFailure = setOrderRaw.uppercased() == "F"
                        
                        let weight = Double(weightRaw)
                        let reps = parseIntLossy(repsRaw)
                        let distance = Double(distanceRaw)
                        let seconds = Double(secondsRaw)
                        let rpe = Double(rpeRaw)
                        
                        let nextSortOrder = cache.nextSetSortOrderPerExercise[cleanExerciseName] ?? 0
                        let setId = UUID().uuidString

                        let set = WorkoutSetRecord(
                            id: setId,
                            workoutExerciseId: workoutExerciseId,
                            sortOrder: nextSortOrder,
                            weight: weight,
                            reps: reps,
                            distance: distance,
                            seconds: seconds,
                            notes: setNotesRaw.nilIfEmpty,
                            rpe: rpe,
                            rir: isFailure ? 0 : nil,
                            isWarmUp: isWarmUp,
                            restTimerSeconds: nil
                        )
                        try set.insert(db)
                        setsInserted += 1
                        
                        cache.lastSetIdPerExercise[cleanExerciseName] = setId
                        cache.nextSetSortOrderPerExercise[cleanExerciseName] = nextSortOrder + 1
                    }
                }

                workoutCacheByKey[workoutKey] = cache
            }
            exercisesInsertedOrIgnored = uniqueExercisesInFile.count
        }

        return ImportResult(
            workoutsInserted: workoutsInserted,
            workoutExercisesInserted: workoutExercisesInserted,
            setsInserted: setsInserted,
            exercisesInsertedOrIgnored: exercisesInsertedOrIgnored,
            skippedBecauseAlreadyImported: false
        )
    }

    /// Minimal CSV parser with support for quoted fields and newlines inside quotes.
    nonisolated private static func parseCSV(_ input: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false

        var i = input.startIndex
        while i < input.endIndex {
            let ch = input[i]

            if inQuotes {
                if ch == "\"" {
                    let next = input.index(after: i)
                    if next < input.endIndex, input[next] == "\"" {
                        field.append("\"")
                        i = next
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(ch)
                }
            } else {
                switch ch {
                case "\"":
                    inQuotes = true
                case ",":
                    row.append(field)
                    field = ""
                case "\n":
                    row.append(field)
                    field = ""
                    if !(row.count == 1 && row[0].isEmpty) {
                        rows.append(row)
                    }
                    row = []
                case "\r":
                    // Handle CRLF by ignoring CR (LF will end the row).
                    break
                default:
                    field.append(ch)
                }
            }

            i = input.index(after: i)
        }

        // Trailing field/row if file doesn't end with newline.
        if inQuotes == false {
            if !field.isEmpty || !row.isEmpty {
                row.append(field)
                if !(row.count == 1 && row[0].isEmpty) {
                    rows.append(row)
                }
            }
        }

        return rows
    }

    nonisolated private static func parseDurationSeconds(_ raw: String) -> TimeInterval? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !s.isEmpty else { return nil }

        // Strong exports commonly look like: "55s", "12m", "1h 5m", "1h 5m 10s"
        let parts = s.split(separator: " ").map(String.init)
        let tokens = parts.isEmpty ? [s] : parts

        var total: Double = 0
        var parsedAny = false

        for token in tokens {
            let t = token.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { continue }

            if t.hasSuffix("h"), let v = Double(t.dropLast()) {
                total += v * 3600
                parsedAny = true
            } else if t.hasSuffix("m"), let v = Double(t.dropLast()) {
                total += v * 60
                parsedAny = true
            } else if t.hasSuffix("s"), let v = Double(t.dropLast()) {
                total += v
                parsedAny = true
            }
        }

        return parsedAny ? total : nil
    }

    nonisolated private static func parseIntLossy(_ raw: String) -> Int? {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        if let i = Int(t) { return i }
        if let d = Double(t) { return Int(d.rounded()) }
        return nil
    }
}

private extension String {
    nonisolated var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

